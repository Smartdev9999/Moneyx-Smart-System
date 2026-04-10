

## v6.45 — Fix: Broker TP ไม่ถูก Clear จาก Bound Orders เมื่อ Hedge Active

### หลักการ

1. **Remove Bound Order Skip**: ลบ `if(IsTicketBound(ticket)) continue;` จาก `ClearBrokerTPSL()` → bound orders ถูก clear TP/SL เมื่อ hedge active
2. **Debug Print**: เพิ่ม Print log เมื่อ clear bound order TP สำเร็จ
3. **Version bump**: v6.44 → v6.45

### ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

#### Changes
- Version bump → v6.45
- ลบ `if(IsTicketBound(ticket)) continue;` จาก `ClearBrokerTPSL()`
- เพิ่ม Print log เมื่อ PositionModify clear TP/SL สำเร็จ

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic — ไม่แก้
- Trading Strategy Logic — ไม่แก้
- Core Module Logic — ไม่แก้
- SyncBrokerTPSL (set TP logic) — ไม่แก้
- Hedge recovery / Triple Gate / Matching Close — ไม่แก้
- Per-Order Trailing / DD trigger — ไม่แก้
- v6.37-v6.44 features — ไม่แก้
