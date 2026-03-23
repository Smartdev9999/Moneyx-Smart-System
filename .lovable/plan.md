


## รีเซ็ต Comment Generation เมื่อ Order เคลียร์หมด — Gold Miner SQ EA (v6.0 → v6.1)

### สิ่งที่แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. เพิ่ม standalone reset หลัง CountPositions (line 1128)
- เมื่อ totalPositions == 0 && g_hedgeSetCount == 0 → reset g_cycleGeneration = 0

#### 2. เพิ่ม reset ใน Accumulate reset (SMA mode, line 1765)
- ก่อน reset baseline → reset g_cycleGeneration = 0

#### 3. เพิ่ม reset ใน Accumulate reset (ZigZag mode, line 4009)
- ก่อน reset baseline → reset g_cycleGeneration = 0

#### 4. Version bump: v6.0 → v6.1

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge system logic ทั้งหมด
- Comment Generation logic ตอน hedge เปิด (ยัง increment ตามปกติ)
