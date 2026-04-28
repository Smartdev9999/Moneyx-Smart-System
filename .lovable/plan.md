# Gold Miner EA v6.87 — Grid Refill Fix (DONE)

ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

## ปัญหา
v6.86 Refill ไม่ทำงานเมื่อเปิดเฉพาะ Breakeven เพราะ:
- กรอง `genPrefix` ทำให้ track เฉพาะ gen ปัจจุบัน
- กรอง `IsTicketBound` ทำให้ออเดอร์ bound ไม่ถูก track
- ไม่มี fallback เมื่อ tick diff พลาด

## แก้
- ลบ filter ทั้ง 2 ใน `RefillScanAndDetectCloses()`
- เพิ่ม `genPrefix` field ใน `GridRefillSlot` + tracking arrays
- `TryRefillGridSlot()` ใช้ `slot.genPrefix` ในการ re-open
- `OnTradeTransaction` เพิ่ม `RefillCaptureFromHistory()` fallback (DEAL_REASON_SL/TP/EXPERT)
- Diagnostic logs: `v6.87 RefillSlot ADD`, `v6.87 RefillFire`, `v6.87 RefillFire FAILED`

## Version
v6.86 → **v6.87** (header, #property version+description, OnInit/Deinit log, Dashboard headerVersion)

## Memory
`mem://trading/gold-miner-ea/grid-refill-fix-v6-87.md`
