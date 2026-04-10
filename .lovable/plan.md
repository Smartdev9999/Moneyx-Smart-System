

## v6.50 — Set TP ตอนเปิดออเดอร์ทันที + Immediate Modify หลัง Grid

### หลักการ

1. **Root Cause**: แม้ v6.49 จะ defer sync แล้ว แต่ `SyncBrokerTPSL()` ยังมี 2-second throttle และต้องรอ tick ถัดไป → TP ยังช้า
2. **Fix #1 (INIT)**: Pre-calculate TP ก่อนส่ง OrderSend → ใส่ TP ไปใน `trade.Buy/Sell()` โดยตรง → TP ติดมาตั้งแต่เปิด (0 delay)
3. **Fix #2 (Grid)**: หลังเปิด Grid order สำเร็จ → เรียก `SyncBrokerTPSL()` ทันทีภายใน `OpenOrder()` → modify ทุกออเดอร์ทันที (< 100ms)
4. **Version bump**: v6.49 → v6.50

### ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic — ไม่แก้ (เพิ่มแค่ pre-calculated TP/SL parameters)
- Trading Strategy Logic — ไม่แก้
- Core Module Logic — ไม่แก้
- SyncBrokerTPSL calculation — ไม่แก้ (ใช้สูตรเดิม แค่เรียกเร็วขึ้น)
- Hedge / Bound / Matching Close — ไม่แก้
- Deferred Data Sync (v6.49) — ยังทำงานเหมือนเดิม
- v6.37-v6.49 features — ไม่แก้
