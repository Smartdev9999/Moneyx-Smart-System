


## Fix: Orphan Recovery Grid ไม่เช็ค OnlyNewCandle — Gold Miner SQ EA (v6.2 → v6.3)

### สิ่งที่แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. เพิ่ม `g_lastOrphanGridCandleTime` global variable
#### 2. เพิ่ม `GridLoss_OnlyNewCandle` guard ใน `ManageOrphanGrid()`
#### 3. Update candle time หลัง OpenOrder สำเร็จ (ทั้ง BUY และ SELL)
#### 4. Version bump: v6.2 → v6.3

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge system logic ทั้งหมด
- Orphan scan/recovery logic อื่นๆ (ScanOrphanGenerations, CountOrphanPositions)
