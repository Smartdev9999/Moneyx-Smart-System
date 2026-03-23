


## เพิ่ม Hedge Average Bound TP — Gold Miner SQ EA (v5.4 → v5.5)

### สิ่งที่แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. เพิ่ม Input: InpHedge_BoundAvgTPPoints
- `input int InpHedge_BoundAvgTPPoints = 0` — Average TP Points สำหรับ bound orders (0=ปิด)

#### 2. เพิ่มฟังก์ชัน ManageHedgeBoundAvgTP(int idx)
- คำนวณ weighted avg price ของ bound orders
- เมื่อราคาถึง avg ± TP points → ปิด bound orders ที่บวก → ซอย hedge ตามกำไร
- ถ้า bound หมด → เข้า Grid Mode

#### 3. แก้ ManageHedgeSets() — เพิ่ม Grid Mode transition ใน Normal state
- เมื่อ bound orders = 0 + hedge ยังอยู่ → เข้า Grid Mode ได้ทั้งใน Normal และ Expansion
- เรียก ManageHedgeBoundAvgTP() ก่อน Matching/Partial Close

#### 4. Version bump: v5.4 → v5.5

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter, Time filter, Data sync)
- ManageHedgeMatchingClose, ManageHedgePartialClose, ManageHedgeGridMode logic
- Bound ticket management, Lot Cap
- Accumulate/Drawdown close logic
