


## Fix: Hedge System Guards + Dashboard Improvements (v5.5 → v5.6)

### สิ่งที่แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Normal Matching Close — skip bound tickets
- เพิ่ม `IsTicketBound(ticket)` guard ใน `ManageMatchingClose()` ป้องกัน normal matching ปิด order ที่ reserve ไว้ให้ hedge system

#### 2. Hedge Lot Calculation — ใช้ Unbound Counter Lots
- เปลี่ยนจาก `CalculateNetHedgeLots()` เป็นสแกน counter-side orders ที่ไม่ bound + ไม่ใช่ hedge order → hedge lot ครบถ้วน

#### 3. hasCounterOrders Guard — filter unbound non-hedge only
- เพิ่ม filter ใน Guard 1: skip hedge comments + bound tickets → hedge เปิดเฉพาะเมื่อมี order ฝั่งผิดที่ยังไม่ถูก protect

#### 4. Expansion Guard for ALL hedge closing
- Grid Mode, Partial Close, Matching Close ทั้งหมดถูก guard ด้วย `!isExpansion`
- ระหว่าง expansion: เช็คเฉพาะ bound orders หมดหรือยัง → flag gridMode (ไม่ execute)

#### 5. Expansion Direction Label
- Dashboard แสดง "EXPANSION ▲ BUY" หรือ "EXPANSION ▼ SELL" แทน "EXPANSION" เฉยๆ

#### 6. Dashboard Default Values
- DashboardX: 50, DashboardY: 60, DashboardWidth: 400, HedgeDashY: 65

#### 7. Version bump: v5.5 → v5.6

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Net Lot Calculation, Hedge Guards, Cross-Set Matching
- Hedge Partial/Matching Close, Grid Mode logic (เพิ่มแค่ expansion guard)
- Normal Matching Close logic (เพิ่มแค่ bound ticket guard)
- Hedge Cycle Monitor dashboard
