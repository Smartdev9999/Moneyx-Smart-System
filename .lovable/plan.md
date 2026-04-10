
ปัญหาจริงเจอแล้ว: ไม่ใช่แค่ `ClearBrokerTPSL()` ข้าม bound order แต่เป็นเพราะ “เงื่อนไขที่ใช้สั่ง clear ไม่เคย active จริง” ใน flow ปัจจุบัน

1. สาเหตุหลัก
- `SyncBrokerTPSL()` จะเรียก `ClearBrokerTPSL()` เฉพาะตอน `g_hedgeBalancedLock && g_hedgeSetCount > 0`
- แต่ใน `ManageHedgeSets()` มีการบังคับ `g_hedgeBalancedLock = false;` ทุก tick
- และ `UpdateHedgeBalancedLock()` มีอยู่จริง แต่ไม่ได้ถูกเรียกใช้งาน
- ผลคือ ถึง order จะถูก hedge/bound แล้ว ระบบก็ไม่เข้า clear path เลย ทำให้ bound orders ยังค้าง broker TP/SL อยู่

2. ความหมายของปัญหา
- แผน v6.45 ที่ลบ `IsTicketBound` ออกจาก `ClearBrokerTPSL()` ถูกต้อง “เฉพาะปลายทาง”
- แต่ต้นทางยังไม่ส่งคำสั่งเข้า `ClearBrokerTPSL()`
- ดังนั้น bound orders ที่ถูก hedge แล้วจึงยังเก็บ TP เดิมไว้ตามภาพที่คุณเจอ

3. แผนแก้ไขที่ถูกจุด
- แก้ที่ trigger ของการ clear ไม่ใช่ไปพึ่ง `g_hedgeBalancedLock`
- เปลี่ยน `SyncBrokerTPSL()` ให้ตรวจ “มี active hedge set ที่ยังมี bound orders อยู่หรือไม่” โดยตรง
- ถ้ามี hedge set active และ `boundTicketCount > 0` ให้ clear broker TP/SL ของชุดที่ถูก hedge ทันที
- ไม่ใช้ balanced-lock เป็นตัวตัดสินอีกต่อไปสำหรับการ clear bound orders

4. แนวทาง implementation
- เพิ่ม helper เช่น `HasActiveBoundHedgeSet()` หรือ `HasBoundOrdersUnderActiveHedge()`
- ใน helper ให้ loop `g_hedgeSets[]` แล้ว return true เมื่อเจอ:
  - `active == true`
  - และ `boundTicketCount > 0`
- แก้ต้น `SyncBrokerTPSL()` จาก
  - `if(g_hedgeBalancedLock && g_hedgeSetCount > 0)`
  เป็น
  - `if(HasActiveBoundHedgeSet())`
- จากนั้นเรียก `ClearBrokerTPSL()` เหมือนเดิม
- คง logic ที่ skip hedge orders ไว้ แต่ bound orders ต้องถูก clear

5. เพิ่มความแม่นยำของ Clear
- ถ้าต้องการ fix แบบปลอดภัยกว่าเดิม จะให้ `ClearBrokerTPSL()` clear เฉพาะ:
  - non-hedge orders
  - ที่ `IsTicketBound(ticket) == true`
- แบบนี้ order ปกติที่ยังไม่ถูก hedge จะไม่โดนล้าง TP/SL โดยไม่จำเป็น
- ถือว่าแม่นกว่า “clear ทุก non-hedge order” เวลา active hedge บางชุด

6. เวอร์ชันที่ควรอัปเดต
- bump จาก v6.45 → v6.46
- อัปเดตทุกจุดที่แสดงเวอร์ชันตามกฎ EA:
  - `#property version`
  - `#property description`
  - header comment
  - dashboard label

7. สิ่งที่ไม่เปลี่ยนแปลง
- ไม่แก้ Order Execution Logic
- ไม่แก้ Trading Strategy Logic
- ไม่แก้ Hedge recovery / Matching / Grid sequencing
- ไม่แก้ TP/SL calculation formulas
- ไม่แก้ core module อื่น
- เป็น fix เฉพาะ trigger การปลด Broker TP/SL ของ bound orders ที่ถูก hedge แล้วเท่านั้น

8. ผลลัพธ์ที่คาดหวัง
- ทันทีที่ order ชุดใดถูก bind เข้า active hedge set
- broker TP/SL ของ bound orders ชุดนั้นจะถูกล้างออก
- เส้น TP ของ EA ยังแสดงเป็น logic ภายในได้ แต่ broker-side TP/SL ของ bound orders จะไม่ค้าง
- จึงไม่เกิดการ “หลุด hedge” เพราะ broker ปิด bound orders ก่อนระบบ recovery ทำงาน
