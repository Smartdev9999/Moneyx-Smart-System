

## แก้ไขปัญหา Session ซ้ำ + ปรับปรุงการค้นหา Session

### ปัญหาที่พบ

EA Tracker ส่งข้อมูลมาสำเร็จแล้ว แต่ระบบสร้าง session ใหม่แทนที่จะอัปเดต session เดิม เนื่องจาก:
- Session เดิมมี `account_number = null` 
- EA ส่ง `account_number = "2080636"` มาด้วย
- Query ใช้ `.eq("account_number", "2080636")` จึงหา session เดิมไม่เจอ

### สิ่งที่จะแก้ไข

#### 1. Edge Function: ปรับ Session Lookup Logic

เปลี่ยนจากการค้นหาด้วย `session_name + account_number` เป็นค้นหาด้วย `session_name` อย่างเดียวก่อน แล้วค่อยอัปเดต `account_number` และ `broker` ทีหลัง

#### 2. Database Cleanup: ลบ Session ซ้ำที่ว่าง

ลบ session เดิมที่ไม่มีข้อมูล (`id: 5d747fa5-...`, account_number = null, total_orders = 0) ออก เหลือแค่ session ที่มีข้อมูลจริง

### ไฟล์ที่แก้ไข

| ไฟล์ | การเปลี่ยนแปลง |
|------|----------------|
| `supabase/functions/sync-tracked-orders/index.ts` | ปรับ query ให้ค้นหา session ด้วยชื่ออย่างเดียว |
| SQL Migration | ลบ session ซ้ำที่ว่างออก |

### รายละเอียดทางเทคนิค

**Edge Function - Session Lookup (เดิม):**
```
.eq("session_name", session_name)
.eq("account_number", account_number || "")
```

**Edge Function - Session Lookup (ใหม่):**
```
.eq("session_name", session_name)
.order("created_at", { ascending: false })
.limit(1)
```

จากนั้นอัปเดต `account_number` และ `broker` ถ้ายังว่างอยู่

**SQL Cleanup:**
ลบ session ที่ซ้ำและไม่มีข้อมูล (id: 5d747fa5-998d-4d4a-a52a-c1947c769fb9)

