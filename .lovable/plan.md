

## Fix New Cycle Block + Max Hedge Sets — Gold Miner SQ EA (v5.2 → v5.3)

### สิ่งที่แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Fix GetHedgeLotCap() — ไม่ block new cycle
- เมื่อ `allowed <= 0` (bound lots ≥ hedge lots) → `continue` skip set นี้แทนที่จะ cap = 0
- Order ใหม่เป็น independent cycle → ไม่ต้อง cap

#### 2. เพิ่ม InpHedge_MaxSets input
- `input int InpHedge_MaxSets = 10` — จำกัดจำนวน hedge sets สูงสุด
- Guard ใน `CheckAndOpenHedge()` → block เมื่อ active sets ≥ limit

#### 3. Version bump: v5.2 → v5.3

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter, Time filter, Data sync, Squeeze)
- Hedge Matching/Partial Close/Grid Mode logic
- Bound ticket management
- Accumulate/Drawdown close logic
