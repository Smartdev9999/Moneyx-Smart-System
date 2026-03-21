

## Fix Hedge Grid รัว + เพิ่ม Min Profit Orders สำหรับ Hedge Partial Close (v4.7 → v4.8)

### สรุปสิ่งที่ต้องแก้ 3 จุด

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

---

### 1. Fix Hedge Grid ออกรัว — ใช้ Directional Distance แทน MathAbs

**ปัญหา (line 6390):** `MathAbs(currentPrice - lastPrice)` ทำให้ grid เปิดทั้งสองทิศทาง

**แก้ไข:** เช็คทิศทางตรง ไม่ใช้ MathAbs
- Hedge **SELL** → grid เปิดเมื่อราคา **ขึ้น** เท่านั้น: `(Bid - lastPrice) / point >= requiredGap`
- Hedge **BUY** → grid เปิดเมื่อราคา **ลง** เท่านั้น: `(lastPrice - Ask) / point >= requiredGap`

---

### 2. เพิ่ม Input: ขั้นต่ำออเดอร์บวกสำหรับ Hedge Partial Close

**Input ใหม่ (line 319):**
```cpp
input int      InpHedge_PartialMinProfitOrders = 3;  // Min Profit Orders for Partial Close
```

**แก้ `ManageHedgePartialClose()` (line 6141):** เพิ่ม guard condition:
```cpp
if(InpHedge_PartialMinProfitOrders > 0 && profitCount < InpHedge_PartialMinProfitOrders) return;
```

**ผล:** ตัว Hedge Partial Close (Scenario 2 — ราคากลับตัว order เดิมบวก → ซอย Hedge) จะเริ่มทำงานก็ต่อเมื่อมี order บวกถึงจำนวนขั้นต่ำ → สะสมกำไรได้เยอะกว่า → ซอย Hedge ได้ทีละเยอะกว่า → ลด Hedge เร็วขึ้น

**หมายเหตุ:** input ตัวนี้ใช้เฉพาะกับ Hedge Partial Close เท่านั้น ไม่กระทบ Matching Close ปกติ หรือ Hedge Matching Close (Scenario 1) แต่อย่างใด

**Hedge Grid Matching (line 6263):** ใช้ `InpHedge_MatchMinProfitOrders` ที่มีอยู่แล้ว → ไม่ต้องแก้

---

### 3. Version bump: v4.7 → v4.8
อัปเดต: `#property version "4.80"`, description, header, Dashboard

### อัปเดต `.lovable/plan.md`

---

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL/Trailing)
- Core Module Logic (License, News, Time, Data sync, Squeeze)
- Matching Close ปกติ, Hedge Matching Close (Scenario 1)
- `GetGridDistance()` ยังคืนค่า Fixed 80 points ตามปกติ
- เมื่อ `InpHedge_PartialMinProfitOrders = 0` → ทำงานเหมือนเดิม

