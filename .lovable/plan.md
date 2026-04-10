


## v6.49 — Fix: Broker TP/SL Delay เกิดจาก Sync Data บล็อก OnTick

### หลักการ

1. **Root Cause**: `OnTradeTransaction()` เรียก `SyncAccountDataWithEvent()` ทันทีหลังเปิด/ปิดออเดอร์ → ทำ blocking HTTP WebRequest → EA ถูกบล็อก → OnTick ไม่ทำงาน → SyncBrokerTPSL() ไม่ได้รัน → TP ดีเลย์
2. **Fix**: เปลี่ยนเป็น Deferred Sync — ตั้ง flag ใน OnTradeTransaction แล้วให้ sync ทำงานท้าย OnTick() หลัง TP/SL ถูก set เรียบร้อยแล้ว
3. **ลำดับใหม่**: Order opened → SyncBrokerTPSL (set TP) → Deferred Sync (HTTP)
4. **Version bump**: v6.48 → v6.49

### ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic — ไม่แก้
- Trading Strategy Logic — ไม่แก้
- Core Module Logic — ไม่แก้
- SyncBrokerTPSL calculation — ไม่แก้
- ข้อมูลที่ sync ยัง sync เหมือนเดิม แค่เปลี่ยนจังหวะ
- v6.37-v6.48 features — ไม่แก้
