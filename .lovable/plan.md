

## v6.16 — เพิ่ม Hedge Trigger Mode: Expansion vs DD%

### ปัญหา
v6.15 implement แค่ระบบ triple-gate สำหรับ **ปิด** hedge แต่ยังไม่ได้เพิ่มตัวเลือกสำหรับ **เปิด** hedge แบบ DD% ตามที่เคย plan ไว้ ปัจจุบันมีแค่โหมด Expansion เท่านั้น

### แผนแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. เพิ่ม Enum + Input Parameters ใน Hedging Settings

```cpp
enum ENUM_HEDGE_TRIGGER
{
   HEDGE_TRIGGER_EXPANSION  = 0,  // Squeeze Expansion (Original)
   HEDGE_TRIGGER_DD_PERCENT = 1   // Drawdown % per Side
};

// เพิ่มใน group Counter-Trend Hedging:
input ENUM_HEDGE_TRIGGER InpHedge_TriggerMode = HEDGE_TRIGGER_EXPANSION; // Hedge Trigger Mode
input double   InpHedge_DDTriggerPct    = 5.0;    // DD% to trigger first hedge
input double   InpHedge_DDStepPct       = 5.0;    // DD% step for next hedge level
input int      InpHedge_DDCooldownSec   = 60;     // Min seconds between DD hedges
```

#### 2. เพิ่ม Global Variables

```cpp
double   g_nextBuyDDTrigger;    // DD% threshold ถัดไปสำหรับ BUY side
double   g_nextSellDDTrigger;   // DD% threshold ถัดไปสำหรับ SELL side
datetime g_lastDDHedgeTime;     // cooldown tracker
```

Initialize ใน `OnInit()`: `g_nextBuyDDTrigger = InpHedge_DDTriggerPct` เป็นต้น

#### 3. เพิ่ม `triggerType` ใน HedgeSet struct

```cpp
int triggerType;  // 0 = expansion, 1 = DD
```

#### 4. สร้างฟังก์ชัน `CheckAndOpenHedgeByDD()`

- สแกน orders ปกติ (ไม่รวม hedge/reverse) → คำนวณ floating loss แยก BUY/SELL
- `lossPct = |sideLoss| / balance * 100`
- ถ้า `lossPct >= g_nextBuyDDTrigger` (หรือ sell) + cooldown ผ่าน → เปิด hedge ฝั่งนั้น
- อัปเดต `g_nextXxxDDTrigger += InpHedge_DDStepPct`
- Set `triggerType = 1` ใน hedge set ใหม่

#### 5. แก้ OnTick flow

```cpp
if(InpHedge_Enable && InpUseSqueezeFilter) {
   if(InpHedge_TriggerMode == HEDGE_TRIGGER_EXPANSION)
      CheckAndOpenHedge();        // เดิม — ใช้ Squeeze expansion
   else
      CheckAndOpenHedgeByDD();    // ใหม่ — ใช้ DD%
   ManageHedgeSets();
}
```

#### 6. แก้ `IsHedgeCloseAllowed()` — DD sets ข้าม Expansion Cycle gate

```cpp
// Gate 1: Expansion Cycle — ข้ามสำหรับ DD-triggered sets
if(g_hedgeSets[h].triggerType == 0) {
   // expansion hedge → ต้องผ่าน cycle gate เหมือนเดิม
   if(!seenExpansion...) return false;
   if(!IsAllSqueezeTFNormalStrict()) return false;
} 
// DD hedge → ข้าม gate 1 ไปเลย (ไม่มี expansion context)

// Gate 2 + 3: Price Zone + TP Distance → ยังบังคับทั้ง 2 โหมด
```

#### 7. Reset DD triggers เมื่อ hedge sets หมด

เมื่อ deactivate hedge set สุดท้ายของฝั่งนั้น → reset `g_nextXxxDDTrigger = InpHedge_DDTriggerPct`

#### 8. Recovery — `RecoverHedgeSets()`

- ใช้ comment prefix แยก: `GM_HEDGE_D` = DD triggered, `GM_HEDGE_` = Expansion
- Recover `triggerType` + recalculate `g_nextXxxDDTrigger` จากจำนวน DD sets ที่มี

#### 9. Dashboard

- แสดง "Trigger: Expansion" หรือ "Trigger: DD%"
- ถ้า DD mode → แสดง "Next BUY DD: 10.0% | SELL DD: 5.0%"
- แสดง current floating loss% per side

#### 10. Reverse Hedge ยังปิดเมื่อ DD mode (เหมือนเดิม ปิดอยู่แล้วใน v6.15)

#### 11. Version bump: v6.15 → v6.16

### สิ่งที่ไม่เปลี่ยนแปลง

- **Order Execution Logic** (trade.Buy/Sell/PositionClose) — ไม่แก้
- **Trading Strategy Logic** (SMA/ZigZag/Instant, Grid entry/exit, TP/SL) — ไม่แก้
- **Core Module Logic** (License, News filter, Time filter, Data sync) — ไม่แก้
- **Expansion Hedge logic** — ยังทำงานเหมือนเดิมเมื่อเลือกโหมด EXPANSION
- **Triple-gate close logic (v6.15)** — Gate 2+3 ยังบังคับทุกโหมด, Gate 1 ข้ามเฉพาะ DD sets
- **Matching Close / Grid Mode ภายใน** — ไม่แก้ logic
- **Accumulate Close** — ทำงานรวมเหมือนเดิม
- **Orphan Recovery / Squeeze detection** — ไม่แก้

