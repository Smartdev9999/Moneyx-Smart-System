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

### สิ่งที่ไม่เปลี่ยนแปลงใน Gold Miner (งาน #6)
- Order Execution Logic (trade.Buy/Sell/PositionClose ใช้ OpenOrder ที่มีอยู่)
- Trading Strategy Logic (SMA/ZigZag/Instant signals, Grid calculations, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Matching Close ปกติ (แยกกัน ไม่กวนกัน — เพิ่มแค่ skip hedge orders)
- DirectionalBlock logic (ยังทำงานเหมือนเดิม)
- Accumulate/Drawdown logic (ปิดทุก order รวม hedge)
- เมื่อ `InpHedge_Enable = false` → behavior เหมือน v4.3 100%
