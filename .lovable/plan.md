

## แก้ไข: Gold Miner EA v6.6 → v6.7 (DD% TP Feature)

### สิ่งที่แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. เพิ่ม TP แบบ % ของ Max Drawdown ต่อฝั่ง
- Input ใหม่: `UseTP_DDPercent` (default: false), `TP_DDPercent` (default: 10.0)
- Global ใหม่: `g_maxDDBuy`, `g_maxDDSell` — ติดตาม max DD ของแต่ละฝั่ง
- OnTick: ทุก tick จะ track max drawdown ของ BUY/SELL แยกกัน
- ManageTPSL + ManageTPSL_TF: เช็ค DD% TP — ปิดเมื่อ PL >= (X% ของ |MaxDD|) **และ PL > 0** เสมอ
- Reset: เมื่อ CloseAllSide/CloseAllPositions → reset g_maxDDBuy/g_maxDDSell = 0
- Dashboard: แสดง MaxDD, Target, Current PL ของทั้ง 2 ฝั่ง

#### 2. Version bump: v6.6 → v6.7

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge system logic ทั้งหมด (Matching/Partial/AvgTP/Grid/Reverse)
- Orphan Recovery system
- TP/SL เดิมทั้งหมด (Dollar, Points, %Balance, Accumulate) ยังทำงานเหมือนเดิม
