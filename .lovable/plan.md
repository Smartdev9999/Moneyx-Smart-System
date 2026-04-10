


## v6.42 — Broker-Level TP/SL (PositionModify) + Dashboard Cache

### หลักการ

1. **Broker-Level TP/SL**: เปลี่ยน TP/SL Points mode จาก "EA เช็คราคาแล้วปิดเอง" → "EA เซ็ต TP/SL ลงในออเดอร์ผ่าน `trade.PositionModify()`" ให้ Broker เป็นคนปิดแทน ทำให้ปิดได้ทันทีแม้ EA ช้า
2. **Dashboard Cache**: Cache history metrics ทุก 5 วินาที แทนที่จะคำนวณทุก tick ลด CPU load จาก ~15,000 iterations/tick → 0

### ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

#### Changes
- Version bump → v6.42
- เพิ่ม `SyncBrokerTPSL()` — คำนวณ avg + TP/SL Points → set ลงทุก position ทุก 2 วินาที
- เพิ่ม `ClearBrokerTPSL()` — clear TP/SL เมื่อ hedge lock active
- แก้ `ManageTPSL()` + `ManageTPSL_TF()` — skip Points check (broker จัดการ)
- แก้ `DisplayDashboard()` — cache history functions ทุก 5 วินาที
- เพิ่ม dashboard แสดง Broker TP/SL price
- เรียก `SyncBrokerTPSL()` ใน OnTick ทุก 2 วินาที

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic — ไม่แก้
- Trading Strategy Logic — ไม่แก้
- Core Module Logic — ไม่แก้
- Dollar/Percent/DD% TP modes — ยังทำงานผ่าน EA เหมือนเดิม
- Accumulate Close / Drawdown Exit — ไม่แก้
- Grid distance / min gap / new candle / candle confirm — ไม่แก้
- DD trigger / Hedge / Balance Guard — ไม่แก้
- v6.37-v6.41 features — ไม่แก้
