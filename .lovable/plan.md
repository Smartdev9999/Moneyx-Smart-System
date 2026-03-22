


## Fix: Hedge Guards ต้องเป็น Cycle-Aware — HedgeC1 ไม่เปิดเพราะ Guards เช็คแบบ Global (v5.8 → v5.9)

### สิ่งที่แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Guard 2 — เพิ่ม `cycleIndex == g_currentCycleIndex`
- เช็คเฉพาะ hedge ใน cycle เดียวกัน → HedgeA1 BUY ไม่ block HedgeC1 BUY

#### 2. Guard 3 — เปลี่ยนจาก `g_lastHedgeExpansionDir` เป็นสแกน hedge ใน cycle ปัจจุบัน
- H2+ ต้องเปลี่ยนทิศจาก H1 **ภายใน cycle เดียวกัน** เท่านั้น

#### 3. Version bump: v5.8 → v5.9

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Guard 1 (hasCounterOrders) — ยังเช็คแบบ global ถูกต้องแล้ว
- Hedge Partial/Matching/Grid Close logic
- Net Lot / Unbound Counter Lots calculation
- Dashboard / Hedge Cycle Monitor
- Cycle increment logic (g_cycleHedged)
