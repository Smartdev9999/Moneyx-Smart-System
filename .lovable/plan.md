

## v6.57 — Sequential Recovery Manager + Comment Reset Fix

### ภาพรวม

แยก **Recovery Grid** ออกจาก **Grid Loss** ปกติ พร้อมเพิ่มโหมด **Sequential Recovery** (ปลด Hedge ทีละชุด เริ่มจาก H1 ก่อน) และแก้บั๊ก comment ที่ไม่รีเซ็ตกลับเป็น `GM` เมื่อ account flat

---

### 1. แยก Recovery Grid Settings ออกจาก Grid Loss

เพิ่ม input group ใหม่ `=== Recovery Grid (Bound Orders) ===` พร้อมพารามิเตอร์ชุดเดียวกับ Grid Loss แต่ใช้กับ **bound/orphan orders เท่านั้น**:

```cpp
input bool           Recovery_UseSeparate    = false;  // false = ใช้ค่า GridLoss_* (เดิม)
input int            Recovery_MaxTrades      = 5;
input ENUM_LOT_MODE  Recovery_LotMode        = LOT_ADD;
input string         Recovery_CustomLots     = "0.01;0.02;0.03;0.04;0.05";
input double         Recovery_AddLotPerLevel = 0.4;
input double         Recovery_MultiplyFactor = 2.0;
input ENUM_GAP_TYPE  Recovery_GapType        = GAP_FIXED;
input int            Recovery_Points         = 500;
input string         Recovery_CustomDistance = "100;200;300;400;500";
input ENUM_TIMEFRAMES Recovery_ATR_TF        = PERIOD_H1;
input int            Recovery_ATR_Period     = 14;
input double         Recovery_ATR_Multiplier = 1.5;
input ENUM_ATR_REF   Recovery_ATR_Reference  = ATR_REF_DYNAMIC;
input int            Recovery_MinGapPoints   = 100;
input int            Recovery_CandleConfirm  = 0;
```

เพิ่ม helper getters: `GetRecoveryMaxTrades()`, `GetRecoveryGridDistance(level)`, `GetRecoveryLot(level, maxExisting)` — ถ้า `Recovery_UseSeparate=false` คืนค่า `GridLoss_*` เพื่อ backward compat

แก้ฟังก์ชัน orphan grid (lines ~8575-8702) ให้ใช้ getter เหล่านี้แทน `GridLoss_*` โดยตรง — **ไม่แตะ Grid Loss ของออเดอร์ปกติ**

---

### 2. Sequential Hedge Recovery Mode

เพิ่ม input:
```cpp
input bool   InpHedge_SequentialRecovery = true;   // true = แก้ทีละชุดเริ่ม H1, false = แก้ทุกชุดพร้อมกัน (เดิม)
```

#### Logic ใน `ManageHedgeSets()` loop (line 8766)

เพิ่ม guard ก่อน เรียก `ManageHedgeMatchingClose(h)` / `ManageHedgeBoundAvgTP(h)` / `ManageHedgePartialClose(h)`:

```cpp
if(InpHedge_SequentialRecovery)
{
   int oldestActiveIdx = FindOldestActiveHedgeSet();  // ดูจาก hedgeOpenTime
   if(h != oldestActiveIdx) continue;  // skip closing ชุดอื่น แต่ยังให้เปิด hedge ใหม่ได้
}
```

**สำคัญ:** guard นี้ block เฉพาะ **closing logic** ของ hedge set ที่ไม่ใช่ตัวเก่าสุดเท่านั้น —
- **ไม่ block** การเปิด hedge ชุดใหม่ (ยังเปิด H2, H3 ได้ตามเงื่อนไข)
- **ไม่ block** การออก orphan recovery grid ของ generation อื่น (grid recovery ยังทำงานทุก gen)
- **ไม่ block** Balance Guard / Daily Target / Squeeze Safety closes

เพิ่ม helper:
```cpp
int FindOldestActiveHedgeSet()
{
   int oldest = -1;
   datetime oldestTime = 0;
   for(int h=0; h<MAX_HEDGE_SETS; h++)
   {
      if(!g_hedgeSets[h].active) continue;
      datetime t = (datetime)PositionGetInteger(POSITION_TIME);  // จาก hedgeTicket
      if(oldest < 0 || t < oldestTime) { oldest = h; oldestTime = t; }
   }
   return oldest;
}
```

จัดเก็บ `g_hedgeSets[h].hedgeOpenTime` ตอนเปิด hedge และตอน `RecoverHedgeSets()` เพื่อให้ FIFO ถูกต้องหลัง restart

#### Dashboard
แสดงโหมดและชุดที่กำลังถูกแก้:
```
Hedge Recovery | Sequential | Active Set: H1 | Pending: H2,H3
```

---

### 3. Bug Fix: Comment ไม่รีเซ็ตเป็น GM เมื่อ Account Flat

#### ปัญหา
`g_cycleGeneration` ถูก persist ใน GlobalVariable (v6.53) แต่การรีเซ็ตอยู่ใน:
- `TryResetCycleStateIfFlat()` — เรียกเฉพาะหลัง matching close / partial close / avg TP
- `CheckBalanceGuard()` — รีเซ็ตเมื่อ balance guard trigger

ถ้า user ปิด hedge เอง / SL ลั่นเอง / ออเดอร์หมดด้วยเหตุอื่น → ไม่มีใครเรียก `TryResetCycleStateIfFlat` → `g_cycleGeneration` ค้างอยู่ → ออเดอร์ใหม่ใช้ `GMx` ที่ไม่ใช่ `GM`

#### แก้ไข
เพิ่มการตรวจสอบใน `OnTick()` (top-level guard ก่อน entry logic):

```cpp
// v6.57: Auto-reset cycle generation when account fully flat
if(g_cycleGeneration > 0 && g_hedgeSetCount == 0 && TotalOrderCount() == 0)
{
   TryResetCycleStateIfFlat("OnTick flat-detect");
}
```

วางตรงต้น `OnTick()` หลัง license/news guards เพื่อให้รันทุก tick เมื่อจริงๆ flat แล้ว

เพิ่ม cleanup ใน `RecoverHedgeSets()` ตอนเริ่ม:
```cpp
// v6.57: ถ้าไม่มี position เลย → reset GlobalVariable ทันที
if(PositionsTotal() == 0 || TotalOrderCount() == 0)
{
   if(GlobalVariableCheck(GV_CycleGenKey()))
      GlobalVariableDel(GV_CycleGenKey());
   g_cycleGeneration = 0;
   Print("v6.57 RecoverHedgeSets: account flat → reset cycle gen to 0");
   return;
}
```

---

### 4. Version Bump → v6.57

อัปเดต: `#property version`, `#property description`, header comment, `OnInit` log, `OnDeinit` log, dashboard version label

---

### สิ่งที่ไม่เปลี่ยนแปลง

- Order Execution Logic (`trade.Buy/Sell/PositionClose`) — ไม่แก้
- Trading Strategy (SMA/EMA, signal, TP/SL) — ไม่แก้
- **Grid Loss ของออเดอร์ปกติ** — ไม่แก้ (แยก Recovery ออกมาใหม่)
- Hedge open logic / trigger modes / Triple Gate — ไม่แก้
- Balance Guard / Daily Target / News Filter / License — ไม่แก้
- Matching Close / BoundAvgTP / PartialClose **ตรรกะภายใน** — ไม่แก้ (แค่เพิ่ม sequential guard ก่อนเรียก)
- Generation persistence v6.53 / BB Filter v6.56 / MaxGrid Trail v6.54 — ไม่แก้
- v6.37–v6.56 features — ไม่แก้

### ผลลัพธ์

1. **Recovery Grid ปรับแยก**: ตั้ง max trades / lot / distance / ATR ของ recovery ได้ไม่ผูกกับ grid ปกติ
2. **Sequential Recovery**: H1 ปิดก่อน → H2 → H3 ตามลำดับ → ลด DD แบบควบคุมได้, ระหว่างรอ H1 ระบบยังเปิด H2/H3 ใหม่ได้ตามปกติ ปิด toggle = พฤติกรรมเดิม
3. **Comment Reset Fix**: account flat → comment กลับเป็น `GM` ทันทีทุก scenario (manual close, SL, BG, matching close)

