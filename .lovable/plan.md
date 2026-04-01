

## v6.24 — แก้ MAX_HEDGE_SETS = 4 และ Generation Counter ไม่ Reset

### ปัญหาที่ 1: MAX_HEDGE_SETS hardcoded = 4

```cpp
#define MAX_HEDGE_SETS 4              // line 488 — แค่ 4 ช่อง
HedgeSet g_hedgeSets[MAX_HEDGE_SETS]; // array มีแค่ 4 slots
```

แม้ตั้ง `InpHedge_MaxSets = 6` แต่ `FindFreeHedgeSlot()` ลูปแค่ 4 ช่อง → return -1 หลัง H4 → H5 ไม่เปิด

### ปัญหาที่ 2: Generation Counter (GM13) ไม่ Reset

`g_cycleGeneration` เพิ่มทุกครั้งที่ hedge เปิด (ทั้ง Expansion และ DD) แต่ **reset เฉพาะเมื่อ ALL positions = 0**:

```cpp
// line 1324: reset เมื่อทุกอย่างปิดหมด
if(g_hadPositions && totalPositions == 0 && g_hedgeSetCount == 0 && g_cycleGeneration > 0)
   g_cycleGeneration = 0;
```

ถ้ามี order ค้างอยู่ตลอด (ไม่เคยปิดหมดพร้อมกัน) → generation ไม่เคย reset → ขึ้นไปเรื่อยๆ (GM→GM1→...→GM13)

ปัญหาจริง: เมื่อ hedge set ทั้งหมดปิด (triple-gate / matching close) แต่ยังมี normal orders ค้างจาก gen เก่า → generation ไม่ reset → order ใหม่ใช้ prefix GM13 → ดูสับสนและ gen number พุ่งไม่หยุด

### แผนแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. เพิ่ม `MAX_HEDGE_SETS` จาก 4 เป็น 10

```cpp
#define MAX_HEDGE_SETS 10  // รองรับ H1-H10
```

ทุก loop ที่ใช้ `MAX_HEDGE_SETS` จะขยายอัตโนมัติ — ไม่ต้องแก้ loop

#### 2. เพิ่ม Generation Reset เมื่อ Hedge Sets ปิดหมด

เมื่อ `g_hedgeSetCount` ลดเหลือ 0 (hedge set สุดท้ายปิด) → reset generation เป็น 0 ทันที แม้ยังมี normal orders ค้าง:

```cpp
// ทุกจุดที่ g_hedgeSetCount-- ลดลง ตรวจสอบเพิ่ม:
if(g_hedgeSetCount <= 0 && g_cycleGeneration > 0)
{
   g_cycleGeneration = 0;
   g_hedgeSetCount = 0;
   Print("CYCLE GENERATION reset to 0 — all hedge sets closed");
}
```

เหตุผล: เมื่อไม่มี hedge set active แล้ว ไม่จำเป็นต้องแยก generation อีก — order ที่ค้างอยู่ (ถ้ามี) จะถูก system ปิดตามปกติ (TP/trailing) และ order ใหม่ควรเริ่มจาก GM ใหม่

#### 3. Version bump: v6.23 → v6.24

### Technical details

```text
ปัญหา 1:
  MAX_HEDGE_SETS = 4 → FindFreeHedgeSlot() return -1 หลัง 4 active sets
  แก้: เพิ่มเป็น 10 → รองรับ InpHedge_MaxSets สูงสุด 10

ปัญหา 2:
  g_cycleGeneration increments ทุก hedge open (line 6641, 6847)
  Reset condition: totalPositions == 0 && hedgeSetCount == 0
  ถ้า positions ไม่เคยปิดหมด → gen ไม่ reset → GM13, GM14...
  
  แก้: reset เมื่อ hedgeSetCount ลดเหลือ 0 
  (ทุกจุดที่ g_hedgeSetCount-- มีประมาณ 7 จุด)
```

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose) — ไม่แก้
- Trading Strategy Logic (SMA/ZigZag/Grid/TP/SL) — ไม่แก้
- Core Module Logic (License, News, Time, Data sync) — ไม่แก้
- Generation-aware isolation (v6.23) — ไม่แก้ logic, แค่ขยาย array + reset
- DD trigger threshold (v6.21) — ไม่แก้
- Triple-gate exit logic — ไม่แก้
- OpenDDHedge / CheckAndOpenHedgeByDD — ไม่แก้ logic

