# แผนแก้ Auto Refill ไม่ทำงาน — Gold Miner EA v6.88

ผมตรวจโค้ด v6.87 แล้วเจอสาเหตุหลักที่ทำให้ Auto Refill เหมือนยังไม่ทำงาน:

1. `TryRefillGridSlot()` ถูกเรียกเฉพาะตอน `CheckGridLoss()` / `CheckGridProfit()` ถูกเรียกเท่านั้น
2. แต่ใน `OnTick` ก่อนจะเข้า `CheckGridLoss/Profit` มี gate บังคับว่า `gridLossBuy < GridLoss_MaxTrades`, `gridProfitBuy < GridProfit_MaxTrades`, `buyCount > 0` ฯลฯ
3. ดังนั้นถ้ากริดยัง “เต็ม” ตามจำนวน MaxTrades หรืออยู่ในช่วงที่ gate ไม่ผ่าน ฟังก์ชัน Refill จะไม่ถูกเรียกเลย แม้ราคาจะกลับมาถึงช่องว่างแล้ว
4. ในโหมด ZigZag MTF ยังไม่ได้ hook `TryRefillGridSlot()` เข้าไปใน `CheckGridLossTF()` / `CheckGridProfitTF()` ทำให้บางโหมดไม่เข้า refill path

## สิ่งที่จะทำ

### 1. เพิ่มตัวเรียก Refill แยกจาก Grid Gate
เพิ่ม helper ใหม่ เช่น `ManageGridRefill()` ให้รันทุก tick หลัง `RefillScanAndDetectCloses()` โดยตรง ไม่ต้องรอ `CheckGridLoss/Profit()`

หน้าที่:
- ตรวจ slot ที่ถูกปิดไว้
- ถ้าราคากลับมาถึงระดับเดิมภายใน tolerance ให้เปิดออเดอร์ refill
- ยังคงใช้เงื่อนไข safety เดิม เช่น `EnableGridRefill`, `GridRefill_GL/GP`, `g_newOrderBlocked`, `MaxOpenOrders`, anti-overlap

### 2. แก้ปัญหา MaxTrades gate บล็อก Refill
Refill จะถูกตรวจ “ก่อน” gate `gridCount < MaxTrades` ในระดับ `OnTick` จริง ๆ ไม่ใช่แค่ใน `CheckGridLoss/Profit()`

ผลลัพธ์:
- ถ้าออเดอร์เดิมโดน BE/SL ปิดไป แล้วเกิดช่องว่าง ระบบสามารถเติมกลับที่จุดเดิมได้
- ไม่ถือว่าเป็นการเปิดกริดใหม่เกินระบบ แต่เป็นการ “คืนไม้ที่หายไปในช่องว่าง”

### 3. เพิ่ม Refill hook ให้ ZigZag MTF
เพิ่มการเรียก Refill ใน `CheckGridLossTF()` และ `CheckGridProfitTF()` หรือให้ `ManageGridRefill()` ครอบคลุม comment แบบ TF เช่น `GM_M15_GL#...`

### 4. ปรับการนับ level/comment ให้รักษาเลขเดิมเมื่อเป็น Refill
ตอนนี้โค้ดมีโอกาสเปลี่ยน level เป็นเลขใหม่ถ้า `lvl <= maxLvl`:
```text
closed GL#3 -> refill อาจกลายเป็น GL#6
```
จะปรับให้ Refill ใช้ level เดิมของ slot เป็นหลัก เพื่อให้ชัดว่าเป็นการเติมตำแหน่งที่โดนปิดไป ไม่ใช่กริดใหม่

### 5. เพิ่ม log วินิจฉัยแบบชัดเจน
เพิ่ม log เมื่อ:
- มี slot ถูกสร้างจาก ticket ที่โดนปิด
- slot ยังรอราคาอยู่
- slot ถูกบล็อกเพราะมี order ซ้อนอยู่แล้ว
- slot ถูกบล็อกเพราะ MaxOpenOrders / g_newOrderBlocked / filter อื่น
- slot ยิง refill สำเร็จ

จะช่วยให้ดูใน Journal ได้ทันทีว่า “ไม่ทำงาน” เพราะไม่มี slot, ราคาไม่ถึง, หรือถูก gate ไหนบล็อก

### 6. อัปเดต Dashboard
ปรับแถว `Refill Slots` ให้เห็นสถานะละเอียดขึ้น เช่น:
```text
Refill Slots   B:2 S:0 | Near:1 | Wait:1
```
เพื่อยืนยันบนชาร์ตว่า EA จำ slot ที่ปิดไปแล้วจริง

### 7. อัปเดต Version
เพิ่มเวอร์ชันจาก v6.87 เป็น **v6.88** ในทุกจุดที่เกี่ยวข้อง:
- header comment
- `#property version`
- `#property description`
- log `OnInit/OnDeinit`
- Dashboard title/version

## สิ่งที่ไม่เปลี่ยนแปลง

- ไม่แก้ logic การคำนวณ Breakeven
- ไม่แก้ logic การคำนวณ Per-Order Trailing
- ไม่แก้สูตร Grid Loss / Grid Profit เดิม
- ไม่แก้ `OrderSend`, `trade.Buy`, `trade.Sell`, `trade.PositionClose` โดยตรง
- ไม่แก้ Hedge / Triple Gate / Recovery / Match Close
- ไม่แก้ License / News / Sync core logic
- ค่า default ยังเป็น `EnableGridRefill=false` เพื่อ backward compatibility

## ผลลัพธ์ที่คาดหวัง

เมื่อเปิดเฉพาะ Breakeven แล้ว order GL/GP โดน broker SL ปิด:
1. EA บันทึก slot ของ order ที่หายไป
2. Dashboard แสดงจำนวน Refill Slots
3. เมื่อราคากลับมาจุดเดิมของ slot และไม่มี order ซ้อนอยู่ในช่องนั้น
4. EA เปิด order ขนาด lot เดิม ด้วย comment/level เดิม เพื่อเติมช่องว่างกลับ

หลังอนุมัติ ผมจะลงมือแก้ไฟล์ `public/docs/mql5/Gold_Miner_EA.mq5` เป็น v6.88 พร้อมบันทึก memory ของการเปลี่ยนแปลงนี้