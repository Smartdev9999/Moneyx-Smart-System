

## Fix: Dashboard Hedge Objects ค้างหลังปิด Hedge — Gold Miner SQ EA

### สาเหตุ

Dashboard ใช้ `DrawTableRow(rowIndex, ...)` ซึ่งสร้าง chart objects ชื่อ `GM_TBL_R12`, `GM_TBL_L12` ฯลฯ ตาม row index เมื่อ Hedge active → สร้าง objects ที่ row 12-13 (ตัวอย่าง) เมื่อ Hedge ปิด → row count ลดลง แต่ **objects เก่าไม่ถูกลบ** → ค้างอยู่บนหน้าจอ

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. เพิ่ม cleanup ต้น `DisplayDashboard()` — ลบ objects ทั้งหมดก่อนวาดใหม่

เพิ่มที่ต้นฟังก์ชัน `DisplayDashboard()` (หลัง line 2632):
```cpp
// Clean all table objects before redraw to prevent stale rows
ObjectsDeleteAll(0, "GM_TBL_R");
ObjectsDeleteAll(0, "GM_TBL_S");
ObjectsDeleteAll(0, "GM_TBL_L");
ObjectsDeleteAll(0, "GM_TBL_V");
```

วิธีนี้จะลบทุก row objects แล้ววาดใหม่ทุก tick → ไม่มี objects ค้างจาก row ที่ไม่ได้ใช้แล้ว

#### 2. อัปเดต version header เป็น v5.1 (ถ้ายังเป็น v5.0)

### สิ่งที่ไม่เปลี่ยนแปลง
- Hedge logic ทั้งหมด
- Dashboard layout / สี / ตำแหน่ง
- Header, buttons, bottom border objects

