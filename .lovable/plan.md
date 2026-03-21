

## Fix: Dashboard กระพริบ — เปลี่ยนจาก Delete All เป็น Delete Stale Rows Only

### สาเหตุ

`ObjectsDeleteAll` ทุก tick ลบ objects ทั้งหมดแล้วสร้างใหม่ → ทำให้เกิดการกระพริบ (flicker)

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. เพิ่ม global variable เก็บ row count ครั้งก่อน
```cpp
int g_lastDashboardRowCount = 0;
```

#### 2. แก้ `DisplayDashboard()` — ลบ `ObjectsDeleteAll` ออก

แทนที่ 4 บรรทัด `ObjectsDeleteAll` (line 2633-2636) ด้วย logic ลบเฉพาะ stale rows หลังจากวาดเสร็จ:

```text
เดิม (ต้น function):
  ObjectsDeleteAll(0, "GM_TBL_R");  ← ลบทั้งหมดทุก tick = กระพริบ
  ObjectsDeleteAll(0, "GM_TBL_S");
  ObjectsDeleteAll(0, "GM_TBL_L");
  ObjectsDeleteAll(0, "GM_TBL_V");

ใหม่ (ท้าย function ก่อน bottom border):
  // ลบเฉพาะ rows ที่เกินจาก tick ก่อนหน้า
  for(int r = row; r < g_lastDashboardRowCount; r++) {
     ObjectDelete(0, "GM_TBL_R" + IntegerToString(r));
     ObjectDelete(0, "GM_TBL_S" + IntegerToString(r));
     ObjectDelete(0, "GM_TBL_L" + IntegerToString(r));
     ObjectDelete(0, "GM_TBL_V" + IntegerToString(r));
  }
  g_lastDashboardRowCount = row;
```

วิธีนี้: rows ที่ยังใช้อยู่จะถูก **update ทับ** (ไม่ลบ-สร้างใหม่) → ไม่กระพริบ, rows ที่เกินจะถูกลบเฉพาะส่วนที่เกิน

### สิ่งที่ไม่เปลี่ยนแปลง
- Dashboard content, layout, สี ทั้งหมด
- Hedge visibility logic (ซ่อนเมื่อไม่ active)
- Trading logic ทั้งหมด

