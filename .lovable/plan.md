## v6.64 — Match Tick Retry + Hedge Partial Fallback

### ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

### สิ่งที่แก้
1. `ManageHedgeSets()`: เซ็ต `g_hedgeSets[h].matchingDone = false` ทุก tick สำหรับ active set ที่ผ่าน gate → matching/AvgTP/PartialClose re-evaluate ใหม่ทุก tick (ปลอดภัย เพราะ v6.62 strict in-set แล้ว)
2. `ManageHedgeMatchingClose()`:
   - ลบ early-return ตอน `lossUsed == 0` → ให้ตกลงไป fallback
   - ถ้า greedy ปิด full-loss ได้ → ปิด profit + matched losses ตามเดิม แล้วเหลือ `remainingBudget = budget - cumLoss`
   - C2.5 ใหม่: ถ้า hedge หลักยังเปิดอยู่และติดลบ และมี `remainingBudget > 0` → คำนวณ `closeLots = remainingBudget / hedgeLossPerLot` (normalized ตาม minLot/lotStep) แล้ว `PositionClosePartial()` ซอย hedge
   - ถ้า `lossUsed == 0` แต่ fallback จะใช้ → ปิด profit tickets ก่อน (ยกเว้น hedge เอง) เพื่อ realize budget
3. Log ใหม่: `v6.64 MATCH RETRY` / `v6.64 MATCH NO FULL-FIT` / `v6.64 HEDGE PARTIAL`
4. Version bump v6.62/v6.63 → v6.64 ทุกจุด (#property, header, init/deinit log, tag list)

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution wrapper / Trading Strategy / Signal / Initial Grid / Loss Grid / Profit Grid — ไม่แก้
- Hedge open trigger / Triple Gate / DD threshold / Reverse logic — ไม่แก้
- `ManageHedgeBoundAvgTP()` / `ManageHedgePartialClose()` / `ProbeSetProfit()` — ไม่แก้
- v6.63 Sequential Recovery Owner scope (block grid only) — ไม่แก้
- v6.63 `FindFreeHedgeSlot()` persistent slot numbering — ไม่แก้
- v6.62 strict in-set pool building (Phase A/B/C) — ไม่แก้
- `RecoverHedgeSetsFromOpenPositions()` / Re-hedge Guard / BB Filter / Recovery Grid — ไม่แก้
- Accumulate Close / Balance Guard / News / License / Time Filter — ไม่แก้
