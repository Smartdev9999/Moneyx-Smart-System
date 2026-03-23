


## Fix: Hedge ไม่ปิดเมื่อ Normal ทั้งที่กำไร — Gold Miner SQ EA (v5.5 → v5.6)

### สิ่งที่แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. เปลี่ยนลำดับใน ManageHedgeSets() — Matching Close ก่อน Average TP
- Hedge กำไร → ManageHedgeMatchingClose ทำงานก่อน (ปิด hedge + match losses)
- Hedge ขาดทุน → ManageHedgeBoundAvgTP → ManageHedgePartialClose

#### 2. แก้ "no matchable losses" fallback — Release bound orders แทน Grid Mode
- เมื่อ hedge ถูกปิดแล้ว → bound orders กลับเป็น order ปกติ
- ไม่เข้า Grid Mode ทั้งที่ hedge ไม่มีแล้ว

#### 3. Version bump: v5.5 → v5.6

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter, Time filter, Data sync)
- ManageHedgePartialClose, ManageHedgeGridMode logic
- ManageHedgeBoundAvgTP logic (เปลี่ยนแค่ลำดับเรียก)
- Bound ticket management, Lot Cap
- Accumulate/Drawdown close logic
