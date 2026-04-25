## Golden2 EA v2.73 — Entry Mode (PENDING / SMA / INSTANT)

ไฟล์เดียวที่แก้: `public/docs/mql5/Golden2_EA.mq5`

### Concept (ยืม Gold Miner)
- Gold Miner มี `EntryMode` 3 แบบ: SMA / ZigZag / Instant
- Golden2 v2.73 พอร์ตมา 2 แบบ + เก็บของเดิมไว้เป็น default:
  1. `G2_ENTRY_PENDING` (default) — BuyStop+SellStop frame เดิม (ของ Golden2 ตั้งแต่ v1.0)
  2. `G2_ENTRY_SMA` — Market BUY ถ้า `bid > SMA`, Market SELL ถ้า `bid < SMA`
  3. `G2_ENTRY_INSTANT` — Market BUY+SELL ทันที (ไม่มี indicator)

### Inputs ใหม่ (group: `=== Entry Mode (v2.73) ===`)
- `InpEntryMode = G2_ENTRY_PENDING` — Entry execution mode
- `InpSMA_Period = 20`
- `InpSMA_TF = PERIOD_CURRENT`
- `InpSMA_AppliedPrice = PRICE_CLOSE`

### Implementation
- **Dispatch** ใน `PlaceInitialFrame()` หลัง side-mode validation:
  - ถ้า `InpEntryMode != PENDING` → เรียก `PlaceInitialMarket(g, placeBuy, placeSell)` แล้ว return
  - PENDING flow เดิม (Squeeze per-side, frame, BuyStop/SellStop, recenter trail) ไม่แตะ
- **PlaceInitialMarket** (ใหม่):
  - Per-group cooldown 5s (กัน per-tick spam)
  - Per-side Squeeze block (mirror v2.72 PENDING path)
  - SMA filter เฉพาะตอน mode=SMA (ใช้ `bid` เป็น current price)
  - `trade.Buy(InpInitialLot, ...)` / `trade.Sell(...)` ที่ Ask/Bid
  - Comment ใช้ `MakeComment(g, false, "IN")` เหมือนเดิม → grid/hedge/triple-gate/accumulate ทำงานต่อได้ทันที
  - TP/SL คำนวณจาก `InpInitialTPPips/InpInitialSLPips` และ honour `STOPS_LEVEL`
- **SMA handle**:
  - สร้างใน `OnInit` เฉพาะตอน mode=SMA (ประหยัด resources)
  - Release ใน `OnDeinit`
- **Dashboard L_TITLE** — แสดง `Entry: PENDING/SMA/INSTANT`
- **OnInit log** — เพิ่มฟิลด์ `EntryMode=...`

### Version
- Bump → **2.73** (`#property version`, header block, `OnInit` log, Dashboard `L_TITLE`)

### สิ่งที่ "ไม่เปลี่ยน" (ยืนยัน)
- ❌ ไม่แตะ `OrderSend` ของ pending frame เดิม / grid / hedge
- ❌ ไม่แตะเงื่อนไข Grid Loss / Grid Profit / Hedge / Triple-Gate / Accumulate
- ❌ ไม่แตะ v2.5 Toward-Price Trail, v2.6 Re-entry, v2.70 Continuous Frame, v2.72 Squeeze per-side + Backtest accel
- ❌ ไม่แตะ License/News/Sync modules
- ✅ Default = `G2_ENTRY_PENDING` → backward compatible 100% สำหรับ .set file เดิม
- ✅ Tag `_IN` เหมือนเดิม → downstream logic รับช่วงต่อได้ปกติ
