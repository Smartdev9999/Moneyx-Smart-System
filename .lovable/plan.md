

## Net Hedge + Cycle Labeling — Gold Miner SQ EA (v5.1 → v5.2)

### สิ่งที่แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### Phase 1: Net Lot Hedge Calculation + Cross-Set Matching

1. **เพิ่ม `CalculateNetHedgeLots()` helper** — สแกนทุก position (buy+sell+hedge+grid hedge) แล้วคำนวณ `|totalBuyLots - totalSellLots|` เป็นขนาด Hedge
2. **แก้ `CheckAndOpenHedge()`** — ใช้ Net Lot แทน `CountUnboundOrders()` เพื่อคำนวณขนาด hedge ที่ถูกต้องสำหรับ Hedge #2, #3, #4
3. **แก้ `ManageHedgeMatchingClose()`** — สแกน loss orders ข้าม Set (global) เรียงเก่าสุดก่อน แทนที่จะดูเฉพาะ `boundTickets[]`
4. **แก้ `ManageHedgePartialClose()`** — สแกน profit orders ข้าม Set (global) แทนที่จะดูเฉพาะ `boundTickets[]`

#### Phase 2: Cycle Labeling (A, B, C, D)

1. **เพิ่ม `g_currentCycleIndex` global** + `GetCycleSuffix()` helper
2. **Comment scheme**: `GM_INIT_A`, `GM_GL#1_A`, `GM_GP#1_A` → หลัง hedge → `_B`, `_C`, `_D`
3. **StringFind ยังทำงานได้** เพราะ `GM_INIT` ยังเป็น substring ของ `GM_INIT_A`
4. **Increment cycle** เมื่อ hedge เปิด; **Reset** เมื่อ `CloseAllPositions()`
5. **Dashboard** แสดง Cycle ปัจจุบัน (A/B/C/D) + จำนวน active sets

#### Version bump: v5.1 → v5.2
- `#property version "5.20"`
- `#property description`
- Header comment
- Dashboard header
- Print messages

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Normal Matching Close logic
- Hedge Grid distance/lot calculation logic
- Accumulate/Drawdown close logic
- DirectionalBlock logic
- `boundTickets[]` ยังใช้สำหรับ track orders ใน set
