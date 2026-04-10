


## v6.47 — Fix: Non-Bound Orders (GM1, GM2) ไม่ได้ตั้ง TP/SL เพราะ Early Return

### หลักการ

1. **Root Cause**: v6.46 แก้ trigger ให้ `ClearBrokerTPSL()` ทำงานได้ แต่ `SyncBrokerTPSL()` มี `return;` หลัง clear → ออเดอร์ชุดใหม่ (GM1, GM2) ที่ไม่ใช่ bound orders ไม่เคยถูกตั้ง TP/SL
2. **Same Issue**: `ManageTPSL()`, `ManageTPSL_TF()`, `ManageMatchingClose()` ก็ return early เหมือนกัน → TP/SL management + matching close หยุดทำงานทั้งหมดเมื่อ hedge active
3. **Fix**: ลบ early return ออกจากทั้ง 4 ฟังก์ชัน — `CalculateAveragePrice()` / `CalculateFloatingPL()` / `CalculateTotalLots()` skip bound+hedge orders อยู่แล้ว จึงคำนวณเฉพาะ non-bound orders ได้ถูกต้อง
4. **Version bump**: v6.46 → v6.47

### ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic — ไม่แก้
- Trading Strategy Logic — ไม่แก้
- Core Module Logic — ไม่แก้
- SyncBrokerTPSL TP/SL calculation — ไม่แก้
- ClearBrokerTPSL (bound-only clear) — ไม่แก้
- HasActiveBoundHedgeSet helper — ไม่แก้
- Hedge recovery / Triple Gate / Matching Close logic — ไม่แก้
- Per-Order Trailing / DD trigger — ไม่แก้
- v6.37-v6.46 features — ไม่แก้
