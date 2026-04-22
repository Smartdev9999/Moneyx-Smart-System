## v6.65 — Strict Sequential Matching + Auto Recovery Lot Sizing

### ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

### สิ่งที่แก้
1. **Strict Sequential Matching** ใน `ManageHedgeSets()`:
   - เลือก `activeMatcherIdx` เพียง 1 set ต่อ tick (= owner ถ้า locked, ไม่งั้น oldest active)
   - set ที่ไม่ใช่ matcher → `continue` ทันที (ห้าม matching/AvgTP/PartialClose/Grid)
   - แก้บั๊ก v6.64 ที่ทุก set ซอย hedge พร้อมกัน → เกิดเศษ partial ไม่มี comment
2. **Auto Recovery Lot Sizing** (toggle `Recovery_AutoLot`):
   - Inputs ใหม่: `Recovery_AutoLot`, `Recovery_AutoInitLot=0.05`, `Recovery_AutoMult=1.4`
   - `ComputeAutoRecoveryLot(remHedge, existing, lastLot)` — series `init × mult^n` รวมไม่เกิน `remHedge`
   - ไม้ที่จะเกิน → cap = `floor((remHedge − existing) / lotStep) × lotStep`
   - ถ้าน้อยกว่า minLot → คืน 0 (หยุดออก grid)
3. Helpers ใหม่: `SumHedgeGridLots`, `FindLastHedgeGridLot`, `GetHedgeLotsForGen`, `SumOrphanGridLots`
4. เชื่อม Auto Mode 2 จุด:
   - `ManageHedgeGridMode()` — ใช้ hedge lots ของ set
   - `ManageOrphanGrid()` (BUY+SELL) — ใช้ hedge lots รวมของ gen
5. Dashboard: `Hedge Recovery → Active Matcher: HX | Wait: N set(s)` + `Recovery Grid → Auto:ON | HX used X.XX/Y.YY`
6. Logs ใหม่: `v6.65 STRICT SEQ`, `v6.65 AUTO LOT`, `BUDGET FULL`
7. Version bump v6.64 → v6.65 ทุกจุด

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution wrapper / Trading Strategy / Signal / Initial Grid — ไม่แก้
- `ManageHedgeMatchingClose()` v6.62 strict in-set + v6.64 partial fallback — logic ภายในไม่แก้
- `ManageHedgeBoundAvgTP()` / `ManageHedgePartialClose()` / `ProbeSetProfit()` — ไม่แก้
- Hedge open trigger / Triple Gate / DD threshold / Reverse — ไม่แก้
- Sequential Recovery Owner v6.59-v6.60 (claim/clear) — ไม่แก้ (แค่ scope ขยาย cover matching)
- `FindFreeHedgeSlot()` v6.63 persistent numbering — ไม่แก้
- Re-hedge Guard / BB Filter / Recovery distance/candle confirm — ไม่แก้
- Accumulate Close / Balance Guard / News / License / Time Filter — ไม่แก้
