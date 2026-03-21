## สรุปงานทั้งหมด

### งานที่ 1: Jutlameasu EA — Volatility Squeeze Filter ✅
- เสร็จแล้ว — เพิ่ม Squeeze Filter (2 TFs) แบบ block เมื่อไม่มี Expansion

### งานที่ 2: Gold Miner SQ EA — Directional Squeeze Block ✅
- เพิ่ม `InpSqueeze_DirectionalBlock` input (bool)
- เพิ่ม `g_squeezeBuyBlocked` / `g_squeezeSellBlocked` globals
- เพิ่ม `direction` field ใน SqueezeState struct (Close vs EMA → 1=Bull, -1=Bear)
- แก้ OnTick squeeze check: ถ้า directional on → block เฉพาะฝั่งสวนเทรนด์
- แทรก directional block checks ในทุก entry point (SMA, Instant, ZigZag + Grid)
- อัปเดต Dashboard แสดง BUY BLOCKED / SELL BLOCKED / OK
- Version bump: v4.0 → v4.1

### งานที่ 3: เพิ่มกฎ Version Bumping ใน rules.md ✅
- เพิ่มหัวข้อ #6: ทุกครั้งที่แก้ไข EA ต้องเพิ่ม minor version
- อัปเดตทุกจุด: `#property version`, `#property description`, header comment, Dashboard

### งานที่ 4: Gold Miner SQ EA — Max Lot Size ✅
- เพิ่ม `InpMaxLotSize` input (double, 0=No Limit)
- แก้ OpenOrder() → cap maxLot ด้วย InpMaxLotSize ก่อน normalize
- ครอบคลุมทุกออเดอร์ (Initial, Grid Loss, Grid Profit) ผ่านจุดเดียว
- Version bump: v4.1 → v4.2

### งานที่ 5: Gold Miner SQ EA — Matching Close Min Total Orders ✅
- เพิ่ม `MatchingMinTotalOrders` input (int, 0=Always)
- เพิ่ม guard condition ใน ManageMatchingClose() → เช็ค totalSideOrders ก่อนเข้า matching logic
- เมื่อออเดอร์ฝั่งเดียวกันยังไม่ถึงเกณฑ์ → ปล่อยให้ TP ทำงานปกติ
- Version bump: v4.2 → v4.3

### งานที่ 6: Gold Miner SQ EA — Counter-Trend Hedging Mode ✅
- เพิ่ม Input group: `InpHedge_Enable`, `InpHedge_MatchMinProfit`, `InpHedge_MatchMinProfitOrders`, `InpHedge_PartialMinProfit`
- เพิ่ม `HedgeSet` struct รองรับ 4 ชุดพร้อมกัน (Multi-Hedge)
- เพิ่ม `CheckAndOpenHedge()`: เปิด Hedge เมื่อ Expansion + มี orders ติดฝั่งสวนเทรน
- เพิ่ม `ManageHedgeSets()`: วนจัดการทุก Hedge set ทุก tick
- เพิ่ม `ManageHedgeMatchingClose()`: Scenario 1 — Hedge กำไร + Normal → ปิดคู่กับ loss เก่าสุด
- เพิ่ม `ManageHedgePartialClose()`: Scenario 2 — Hedge ขาดทุน + original orders บวก → partial close
- เพิ่ม `ManageHedgeGridMode()`: เมื่อ original orders หมด → แปลง Hedge เป็น Grid
- แก้ `ManageMatchingClose()`: ข้าม orders ที่เป็น GM_HEDGE / GM_HG
- แก้ `CloseAllPositions()`: reset Hedge sets ทั้งหมด
- อัปเดต Dashboard แสดง Hedge Mode section
- Version bump: v4.3 → v4.4

### งานที่ 7: Gold Miner SQ EA — Fix Hedge Isolation Bugs ✅
- แก้ `CountPositions()`: ข้าม hedge orders → ฝั่งถูกเทรนออกออเดอร์ได้ปกติ
- แก้ `CalculateAveragePrice()`: ข้าม hedge orders → basket TP/SL ไม่รวม hedge
- แก้ `CalculateFloatingPL()`: ข้าม hedge orders → floating PL คำนวณเฉพาะ normal orders
- แก้ `CloseAllSide()`: ข้าม hedge orders → basket close ไม่ปิด hedge (ให้ hedge system จัดการเอง)
- Hedge orders ไม่มี TP/SL → ปิดเฉพาะผ่าน Hedge Matching/Partial Close system
- Version bump: v4.4 → v4.5

### สิ่งที่ไม่เปลี่ยนแปลงใน Gold Miner (งาน #7)
- Order Execution Logic (trade.Buy/Sell/PositionClose ใช้ OpenOrder ที่มีอยู่)
- Trading Strategy Logic (SMA/ZigZag/Instant signals, Grid calculations, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Matching Close ปกติ (มี skip hedge อยู่แล้ว)
- Hedge system logic (CheckAndOpenHedge, ManageHedgeSets — ไม่เปลี่ยน)
- DirectionalBlock logic (ยังทำงานเหมือนเดิม)
- Accumulate/Drawdown logic (ปิดทุก order รวม hedge)
- เมื่อ `InpHedge_Enable = false` → behavior เหมือน v4.3 100%

### งานที่ 8: Gold Miner SQ EA — Fix Hedge Lot Cap by MaxLotSize ✅
- แก้ `OpenOrder()`: ข้าม `InpMaxLotSize` cap สำหรับ Hedge orders (`IsHedgeComment`)
- ออเดอร์ปกติ (GM_INIT, GM_GL, GM_GP) ยังถูก cap เหมือนเดิม
- Version bump: v4.5 → v4.6

### งานที่ 9: Gold Miner SQ EA — Fix Hedge Grid Rapid-Fire Orders ✅
- แก้ `ManageHedgeGridMode()`: ใช้ `GetGridDistance()` แทน `GridLoss_Points` ตรงๆ
- เพิ่ม `g_lastHedgeGridTime` cooldown 5 วินาทีป้องกันออก order รัว
- เพิ่ม Print log แสดง gap/requiredGap เพื่อ debug
- Version bump: v4.6 → v4.7

### งานที่ 10: Gold Miner SQ EA — Fix Hedge Grid รัว + Min Profit Orders ✅
- แก้ `ManageHedgeGridMode()`: ใช้ Directional Distance แทน `MathAbs` — Sell Hedge grid เปิดเมื่อราคาขึ้นเท่านั้น, Buy Hedge เมื่อราคาลงเท่านั้น
- เพิ่ม `InpHedge_PartialMinProfitOrders` input (int, default 3) — ขั้นต่ำออเดอร์บวกก่อนเริ่ม Hedge Partial Close
- เพิ่ม guard ใน `ManageHedgePartialClose()`: ต้องมี profitCount >= InpHedge_PartialMinProfitOrders
- Version bump: v4.7 → v4.8

### งานที่ 11: Gold Miner SQ EA — Unify Hedge Grid Min Profit Orders ✅
- แก้ `ManageHedgeGridMode()`: เปลี่ยนจาก `InpHedge_MatchMinProfitOrders` เป็น `InpHedge_PartialMinProfitOrders`
- ทำให้ Hedge Partial Close + Hedge Grid Matching ใช้ input ตัวเดียวกัน
- Version bump: v4.8 → v4.9

### งานที่ 12: Gold Miner SQ EA — Hedge Partial Close Batch Mode ✅
- แก้ `ManageHedgePartialClose()`: เปลี่ยนจาก 1-per-tick (break) เป็น Batch mode
- รวมกำไรทุก profitable orders → คำนวณ closeLots รวม → ปิดทีเดียว
- Guard `InpHedge_PartialMinProfitOrders` ยังเป็นกฎเหล็ก
- Version bump: v4.9 → v5.0

### งานที่ 13: Gold Miner SQ EA — Hedge Set Isolation System ✅
- เพิ่ม `boundTickets[]` + `boundTicketCount` ใน HedgeSet struct
- เพิ่ม helper functions: `IsTicketBound()`, `CountUnboundOrders()`, `RemoveBoundTicket()`, `RefreshBoundTickets()`
- แก้ `CheckAndOpenHedge()`: ใช้ `CountUnboundOrders()` แทน `CountNormalOrders()` + ผูก tickets เข้า set
- ลบ `HedgeExistsForSide()` → อนุญาตหลาย set ฝั่งเดียวกัน (ใช้ unbound check แทน)
- แก้ `ManageHedgeSets()`: เพิ่ม `RefreshBoundTickets()` ทุก tick + ใช้ `boundTicketCount == 0` เช็ค grid mode
- แก้ `ManageHedgeMatchingClose()`: สแกนเฉพาะ `boundTickets[]` แทน global scan
- แก้ `ManageHedgePartialClose()`: สแกนเฉพาะ `boundTickets[]` แทน global scan
- อัปเดต Dashboard แสดง bound ticket count (B:N)
- Version bump: v5.0 → v5.1

### สิ่งที่ไม่เปลี่ยนแปลงใน Gold Miner (งาน #13)
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Normal Matching Close logic
- Hedge Grid order opening/distance logic
- Accumulate/Drawdown close logic
- DirectionalBlock logic
