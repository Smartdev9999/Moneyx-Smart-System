


## v6.48 — Fix: Broker TP/SL Delay หลังเปิดออเดอร์ใหม่ (Cache Bug + Throttle Reset)

### หลักการ

1. **Root Cause #1**: `SyncBrokerTPSL()` มี throttle 2 วินาที — หลังเปิดออเดอร์ใหม่ต้องรอจนกว่า throttle หมด
2. **Root Cause #2 (ตัวการจริง)**: Cache (`g_lastBrokerTP_Buy` ฯลฯ) ถูกอัปเดตทุกครั้ง ไม่ว่า `PositionModify` จะสำเร็จหรือไม่ → ถ้า broker busy → modify ล้มเหลว → cache คิดว่า set แล้ว → ไม่ retry อีกเลย
3. **Fix #1**: ใน `OpenOrder()` หลัง trade สำเร็จ → reset `g_lastBrokerTPSLSync = 0` + invalidate cache (`= -1`) → tick ถัดไป SyncBrokerTPSL รันทันที
4. **Fix #2**: ลบ `buyChanged/sellChanged` gate → เช็คจาก actual order TP/SL แทน → ไม่มี cache bug
5. **Fix #3**: Cache อัปเดตเฉพาะเมื่อ ALL modifies สำเร็จจริง → ถ้าล้มเหลวจะ retry ทุก 2 วินาที
6. **Version bump**: v6.47 → v6.48

### ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic — ไม่แก้
- Trading Strategy Logic — ไม่แก้
- Core Module Logic — ไม่แก้
- SyncBrokerTPSL TP/SL calculation — ไม่แก้
- ClearBrokerTPSL — ไม่แก้
- HasActiveBoundHedgeSet — ไม่แก้
- Hedge recovery / Triple Gate / Matching Close — ไม่แก้
- Per-Order Trailing / DD trigger — ไม่แก้
- v6.37-v6.47 features — ไม่แก้
