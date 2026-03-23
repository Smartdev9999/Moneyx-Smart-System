


## Fix: Order Buy ชุดใหม่ไม่ออก เมื่อมี Hedge Set Active — Gold Miner SQ EA (v5.7 → v5.8)

### สิ่งที่แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. เพิ่ม `IsTicketBound` skip ใน `CountPositions()`
- Bound orders จะไม่ถูกนับใน buyCount/sellCount → ระบบปกติเปิด Buy/Sell ชุดใหม่ได้

#### 2. Version bump: v5.7 → v5.8

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge system logic ทั้งหมด (Matching/Partial/AvgTP/Grid)
- Squeeze filter logic
