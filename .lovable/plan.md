

## Fix: Dashboard กระพริบ — เปลี่ยนจาก Delete All เป็น Delete Stale Rows Only (v5.1)

### สิ่งที่แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

1. เพิ่ม `g_lastDashboardRowCount` global variable
2. ลบ `ObjectsDeleteAll` 4 บรรทัดออกจากต้น `DisplayDashboard()` → แทนด้วย comment
3. เพิ่ม stale row cleanup loop ท้าย function (ก่อน bottom border) — ลบเฉพาะ rows ที่เกินจาก tick ก่อนหน้า

### ผลลัพธ์
- Dashboard ไม่กระพริบ (rows ที่ใช้อยู่ถูก update ทับ ไม่ถูกลบแล้วสร้างใหม่)
- Hedge rows ที่ไม่ active จะถูกลบเฉพาะเมื่อ row count ลดลง

### สิ่งที่ไม่เปลี่ยนแปลง
- Hedge logic ทั้งหมด
- Dashboard content, layout, สี
- Trading logic ทั้งหมด
