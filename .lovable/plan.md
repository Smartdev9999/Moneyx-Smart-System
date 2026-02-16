

## แก้ไข Error: Duplicate Ticket ใน History Batch

### ปัญหา

EA ส่ง history batch ทีละ 50 รายการ แต่ใน batch เดียวกันมี ticket ซ้ำ (เช่น deal เข้า-ออกของ position เดียวกัน ใช้ position ticket เดียวกัน) ทำให้ PostgreSQL upsert ล้มเหลวเพราะพยายามอัปเดต row เดียวกัน 2 ครั้งใน statement เดียว

### วิธีแก้ไข

| ไฟล์ | การเปลี่ยนแปลง |
|------|----------------|
| `supabase/functions/sync-tracked-orders/index.ts` | เพิ่มการ deduplicate orders ก่อน upsert โดยเก็บเฉพาะรายการสุดท้ายของแต่ละ ticket+event_type |

### รายละเอียดทางเทคนิค

**Edge Function - เพิ่ม Deduplication:**

หลังจาก map orders เป็น orderRows แล้ว จะ deduplicate โดยใช้ Map กับ key = `ticket:event_type` เก็บเฉพาะรายการสุดท้าย:

```text
// Deduplicate: keep last occurrence per ticket+event_type
const deduped = new Map();
for (const row of orderRows) {
  deduped.set(`${row.ticket}:${row.event_type}`, row);
}
const uniqueRows = [...deduped.values()];
```

จากนั้นใช้ `uniqueRows` แทน `orderRows` ใน upsert

วิธีนี้แก้ปัญหาได้ตรงจุดโดยไม่ต้องแก้ไขฝั่ง EA เลย
