# Gold Miner EA v6.84 — Per-Side Trailing Reset Fix (DONE)

ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

## บั๊ก
- `ResetTrailingState()` ล้างทั้ง Buy + Sell พร้อมกัน → ฝั่งที่เหลือถูกรีเซ็ตเมื่ออีกฝั่ง trail-out
- `return;` หลัง BUY hit ทำให้ SELL section ไม่ถูกประมวลผลใน tick เดียวกัน
- บั๊กเดียวกันใน MTF (`ResetTrailingStateTF` + `ManageTrailingStop_TF`)

## แก้
- เพิ่ม `ResetTrailingStateBuy/Sell()` + `ResetTrailingStateTFBuy/Sell(idx)` (per-side)
- `ManageTrailingStop()` BUY hit: ใช้ Buy reset และลบ `return;` / SELL hit: ใช้ Sell reset
- `ManageTrailingStop_TF()`: เช่นเดียวกัน
- ตัวเก่า (`ResetTrailingState`/`ResetTrailingStateTF`) ยังอยู่ครบสำหรับ cycle reset

## Version
v6.83 → v6.84 (header, #property version+description, OnInit/Deinit log, Dashboard headerVersion)
