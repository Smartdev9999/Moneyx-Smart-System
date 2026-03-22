

## Fix: Grid Loss ไม่ออกออเดอร์ใน Cycle B เมื่อมี Cycle A ถูก Hedge — Skip Bound Orders (v5.7 → v5.8)

### สิ่งที่แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. `CountPositions()` — เพิ่ม `IsTicketBound(ticket) continue`
- Grid count (GL/GP/INIT) ไม่รวม order ที่ผูกกับ hedge set → Cycle B นับแยกจาก Cycle A

#### 2. `FindLastOrder()` — เพิ่ม skip hedge + bound
- หา last order price จากเฉพาะ order ที่ไม่ถูกผูก → ระยะ grid ถูกต้องสำหรับ cycle ปัจจุบัน

#### 3. `FindMaxLotOnSide()` — เพิ่ม `IsTicketBound(ticket) continue`
- Max lot คำนวณจาก order ที่ active ใน cycle ปัจจุบันเท่านั้น

#### 4. Version bump: v5.7 → v5.8

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge logic ทั้งหมด (Partial/Matching/Grid Close)
- Grid Profit / Grid Loss calculation formula
- Normal Matching Close logic
- Dashboard / Hedge Cycle Monitor
