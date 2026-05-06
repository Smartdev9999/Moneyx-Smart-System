## สรุปปัญหาที่แท้จริง

ตอนนี้ v1.56 แก้เรื่อง “ฝั่งเดิมเป็น Hero ซ้ำทันที” ได้บางส่วนแล้ว แต่ปัญหาใหม่คือจังหวะสลับรอบยังไม่ครบ:

```text
รอบก่อน: BUY Hero ปิดจบ
-> ระบบบังคับ Next Allowed = SELL
-> SELL กลายเป็น Hero และถูก lock ไว้แล้ว
-> ราคาดีดขึ้น ทำให้ BUY basket ชุดใหม่ปิด TP
-> สิ่งที่ควรเกิด: SELL Hero ต้องปิดพร้อมการปิด TP ของ BUY basket
-> จากนั้นจึงอนุญาตให้ BUY กลับมาเป็น Hero รอบถัดไป
```

แต่จากภาพ Dashboard ตอนนี้ `Hero Owner = SELL (locked)` และ SELL Hero ยังไม่ปิด แม้ BUY ฝั่งตรงข้ามชน TP แล้ว สาเหตุหลักมี 2 จุด:

1. `ManageHeroOppositeClose()` ปิด Hero เฉพาะเมื่อ `CountNonHeroMainOnSide(opp) == 0` เท่านั้น  
   แต่หลัง BUY basket ชน TP ระบบ `AutoReEntry/Grid` เปิด BUY ชุดใหม่เร็วมาก ทำให้ตอนตรวจ Hero ฝั่งตรงข้ามกลับเห็นว่า BUY มี order ใหม่แล้ว จึงไม่เข้าเงื่อนไข `opp basket flat` และ SELL Hero ค้าง

2. v1.56 ล้าง `g_heroNextAllowedSide` ทันทีเมื่อ SELL “activate Hero” (`ALT-CONSUMED`)  
   ทำให้สถานะการสลับฝั่งหมดเร็วเกินไป ทั้งที่ requirement ใหม่คือ ฝั่งตรงข้ามต้อง “เป็น Hero และปิด Hero จบ” ก่อน จึงถือว่ารอบสลับสมบูรณ์

## แผนแก้ไข v1.57

### 1. เพิ่ม Version เป็น v1.57 ทุกจุด
แก้ใน `public/docs/mql5/Golden_Kuy3_EA.mq5`:

- `#property version` เป็น `1.57`
- `#property description`
- Dashboard `Golden Kuy3 v1.57` / `HERO ORDER (v1.57)`
- Init/Deinit logs
- Log prefix ที่เกี่ยวข้องกับ Hero cycle เป็น v1.57

### 2. ลดประวัติ version ใน Header ตามที่ขอ
จะไม่เก็บ changelog ยาวทุกเวอร์ชันไว้บนหัวไฟล์อีกแล้ว โดยจะย่อให้เหลือเฉพาะ:

- ชื่อ EA / version ปัจจุบัน
- สรุป v1.57 แบบสั้น
- หมายเหตุว่า previous detailed changelog ถูกเก็บไว้ใน project memory/docs แล้ว

จะไม่ลบ memory เก่าในระบบ แต่จะทำให้หัวไฟล์ `.mq5` ไม่ยาวขึ้นเรื่อยๆ

### 3. เพิ่ม “Opposite TP Event” latch เพื่อไม่พลาดจังหวะ TP ที่ถูกเปิด order ใหม่ทับ
เพิ่ม state ใหม่สำหรับ Hero closure:

```text
g_oppTPEventForHeroBuy
g_oppTPEventForHeroSell
```

หลักการ:

- ถ้า Hero ฝั่ง SELL อยู่ใน `BE_GUARD`
- แล้วมี BUY non-Hero close ด้วย TP / Avg-TP intent / Master TP points / Avg-trailing intent
- ให้ latch ว่า “BUY basket TP event สำหรับ SELL Hero เกิดขึ้นแล้ว”
- `ManageHeroOppositeClose()` จะปิด SELL Hero จาก latch นี้ได้ ถึงแม้ BUY order ใหม่จะถูกเปิดเข้ามาแล้วก็ตาม

ผลคือ SELL Hero จะไม่ค้างเพราะ `AutoReEntry` หรือ grid เปิด BUY ชุดใหม่เร็วกว่า tick ที่ Hero closure ตรวจเจอ

### 4. แก้ `ManageHeroOppositeClose()` ให้ปิด Hero จาก TP-event latch
ปรับลำดับตรวจปิด Hero:

- ถ้า `phase == BE_GUARD` และมี Hero ticket อยู่
- ถ้ามี TP-event latch ของฝั่งตรงข้าม และ realized profit ผ่านเงื่อนไข `InpHero_OppCloseMinProfit`
- ให้ `CloseHeroOnSide(side, "OppositeTPEventClose")` ทันที
- ไม่ต้องรอ `CountNonHeroMainOnSide(opp) == 0` อีกในเคส latch เพราะ event ยืนยันแล้วว่า basket ฝั่งตรงข้ามถูก TP/AvgTP ปิดจริง

ส่วน behavior เดิมยังคงอยู่เป็น fallback สำหรับกรณีที่ basket flat และ intent flag ยังอยู่

### 5. แก้ strict alternation ให้ “consume” ตอนปิด Hero ไม่ใช่ตอน activate
เปลี่ยนกติกาของ `g_heroNextAllowedSide`:

- หลัง BUY Hero ปิด: `NextAllowed = SELL`
- SELL activate Hero: ยังไม่ล้าง NextAllowed
- SELL Hero ปิดจบจริง: ค่อยเปลี่ยนเป็น `NextAllowed = BUY`
- BUY activate Hero: ยังไม่ล้าง NextAllowed
- BUY Hero ปิดจบจริง: ค่อยเปลี่ยนเป็น `NextAllowed = SELL`

ดังนั้นคำว่า “สลับรอบ” จะหมายถึงฝั่งตรงข้ามต้องปิด Hero จบจริง ไม่ใช่แค่เริ่มเป็น Hero

### 6. กัน order ใหม่ฝั่งเดียวกันหลัง BE_GUARD ไม่ให้กลายเป็น Hero รอบใหม่ก่อน cycle จบ
คงกฎ v1.56 เดิม:

- `ARMED` = Hero set dynamic refresh ได้
- `BE_GUARD` = Hero set freeze
- order ใหม่หลัง BE_GUARD เป็น non-Hero ปกติ

แต่จะเพิ่ม log/dashboard ให้เห็นว่า SELL locked อยู่เพราะรอ BUY TP-event หรือกำลังปิดจาก BUY TP-event

### 7. ปรับ Dashboard ให้เห็นสถานะ cycle ชัดขึ้น
เพิ่ม/แก้ row ใน Hero panel:

- `Next Allowed`: แสดงฝั่งที่ต้องจบรอบถัดไป
- `TP Event`: แสดง `BUY->SELL` หรือ `SELL->BUY` เมื่อมี latch ที่กำลังรอปิด Hero
- `Hero BUY/SELL`: แสดง phase เดิม (`WAIT/ARMED/BE_GUARD`) แต่ถ้าถูก block ด้วย cycle จะขึ้น `ALT-BLOCK`

## สิ่งที่ไม่เปลี่ยนแปลง / ยืนยันไม่กระทบ Trading Logic

แผนนี้จะไม่แก้สิ่งต่อไปนี้:

- ไม่แก้ `trade.Buy`, `trade.Sell`, `OrderSend`
- ไม่แก้เงื่อนไขเปิด order หลัก
- ไม่แก้ Grid entry / Grid distance / Grid lot multiplier
- ไม่แก้ Per-Order BE/Trailing calculation
- ไม่แก้ Average TP / Average Trailing strict 2-cross calculation
- ไม่แก้ TP price calculation
- ไม่แก้ Accumulate close target calculation
- ไม่แก้ Cost-Hit Restart entry logic

จุดที่จะแตะ `trade.PositionClose` มีเฉพาะ flow ปิด Hero เดิม (`CloseHeroOnSide`) โดยเพิ่ม trigger ให้เรียกในจังหวะ TP-event ที่ถูกต้องเท่านั้น ไม่ใช่การเปลี่ยน strategy เปิด/ปิด order หลัก

## ผลลัพธ์ที่คาดหวังหลัง v1.57

- หลัง SELL เป็น Hero และ BUY basket ชน TP: SELL Hero จะปิดตาม TP-event นั้น แม้ระบบจะเปิด BUY order ใหม่ทันที
- หลัง SELL Hero ปิดจบ: รอบถัดไปจะอนุญาต BUY Hero ได้
- ถัดไปเมื่อ BUY Hero ปิดจบ: รอบถัดไปจะต้องเป็น SELL อีกครั้ง
- ระบบจะสลับ BUY/SELL/BUY/SELL ตามรอบ Hero close จริง ไม่ใช่ล็อคฝั่งเดียวค้าง
- Header code จะไม่ยาวจากการบันทึก changelog ทุกเวอร์ชันอีกต่อไป