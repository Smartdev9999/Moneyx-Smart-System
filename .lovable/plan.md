


## v6.51 — เพิ่ม Input เปิด/ปิด Hedge Matching Close

### หลักการ

1. **ปัญหา**: `ManageHedgeMatchingClose()` บางครั้งปิดออเดอร์ในจังหวะไม่เหมาะสม
2. **Fix**: เพิ่ม `input bool InpHedge_UseMatchingClose = true;` เพื่อเปิด/ปิดฟังก์ชันนี้
3. **ถ้าปิด**: ข้ามขั้นตอน Matching Close → ระบบจะไปทำ Grid Recovery / Bound Avg TP / Partial Close แทน
4. **Version bump**: v6.50 → v6.51

### ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic — ไม่แก้
- Trading Strategy Logic — ไม่แก้
- Core Module Logic — ไม่แก้
- `ManageHedgeMatchingClose()` function body — ไม่แก้
- Triple Gate logic — ไม่แก้
- Grid Recovery / Bound Avg TP / Partial Close — ไม่แก้
- Deferred Data Sync (v6.49) / InstantTP (v6.50) — ไม่แก้
- v6.37-v6.50 features — ไม่แก้
