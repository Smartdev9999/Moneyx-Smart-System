

## v6.64 — Fix Set#2 “ค้างเหมือนโดนล็อค”: ให้คำนวณใหม่ทุก tick และซอยปิด hedge ได้เมื่อ budget ไม่พอปิดทั้งใบ

### ปัญหาจริงที่ยังเหลืออยู่

จากโค้ด v6.63 ตอนนี้อาการของ Set#2 ไม่ได้มาจาก owner lock อย่างเดียวแล้ว แต่มี 2 จุดที่ทำให้ดูเหมือน “ล็อคค้าง”:

1. `matchingDone` ค้างเป็น `true`
- ใน `ManageHedgeSets()` ถ้า Set#2 เคยลอง matching ไป 1 ครั้งแล้ว แต่ครั้งนั้น “ปิดอะไรไม่ได้”
- ระบบจะเซ็ต `matchingDone = true`
- หลังจากนั้นจะไม่กลับมาคำนวณ matching ใหม่ใน tick ถัดไป เว้นแต่ close gate จะปิดแล้วเปิดใหม่
- ผลคือ dashboard ดูเหมือนยังรอ/ค้าง ทั้งที่ราคาวิ่งต่อและเงื่อนไขเปลี่ยนแล้ว

2. `ManageHedgeMatchingClose()` ปิดได้เฉพาะ “เต็มใบ”
- logic v6.62/v6.63 จะเลือกเฉพาะ loss ที่ `budget` ครอบได้ทั้งก้อน
- ถ้าใน set มี profit pool แต่ยังไม่พอปิด hedge ตัวใหญ่ทั้งใบ ระบบจะ `return` ทันที
- ทั้งที่ concept ที่คุยกันคือ “ซอยปิด” hedge ได้ตาม budget ที่มี ไม่ใช่ต้องรอปิดเต็มใบอย่างเดียว

กรณี image-890 ตรงกับอาการนี้พอดี:
- มี profit ใน set
- แต่ hedge loss ใหญ่กว่า budget
- จึงไม่เข้าเงื่อนไขปิดเต็มใบ
- แล้ว `matchingDone` ค้าง → Set#2 ไม่ทำงานต่อ

---

## แผนแก้ไข — `public/docs/mql5/Gold_Miner_EA.mq5`

### 1) Version bump → v6.64
อัปเดต:
- `#property version`
- `#property description`
- header comment
- init/deinit log
- dashboard label

### 2) แก้ `ManageHedgeSets()` ให้ matching re-evaluate ทุก tick สำหรับ set ที่ยัง active และยังไม่เข้า grid mode
เป้าหมาย:
- ไม่ให้ Set#2 “ลองครั้งเดียวแล้วหยุด”
- matching / AvgTP / partial-close ต้องกลับมาประเมินใหม่ทุก tick ตราบใดที่ set ยัง active

แนวทาง:
- reset `matchingDone` สำหรับ active set ใน normal recovery phase ก่อนเข้า STEP 1
- แต่ยังคง one-tick handoff ของ `g_sequentialRecoveryCompletedThisTick` ตาม v6.60/v6.63
- และยังคง `blockGridForThisSet` ตาม v6.63 เหมือนเดิม

ผล:
- Set#2 จะไม่ค้างเพราะ state เก่า
- ถ้า budget เปลี่ยนจาก floating P/L ที่ขยับ ระบบจะลองใหม่อัตโนมัติทุก tick

### 3) เพิ่ม “partial hedge close fallback” ใน `ManageHedgeMatchingClose(idx)`
แก้เฉพาะ decision logic ของ matching close โดยใช้แนวทางเดิมของระบบ ไม่ไปแตะ strategy/open-order logic

#### พฤติกรรมใหม่
หลังจาก Phase C แบบ greedy ปกติ:
- ถ้ามี loss เต็มใบที่ปิดได้ → ปิดตามเดิมก่อน
- จากนั้นถ้ายังมี `remainingBudget` เหลือ และ hedge หลักยังติดลบอยู่ → ใช้ budget ที่เหลือ “ซอยปิด hedge”
- ถ้า `lossUsed == 0` แต่มี budget และ hedge ติดลบ → ให้เข้าทาง partial-close hedge ทันที

#### วิธีคำนวณ
ใช้ pattern เดียวกับที่มีอยู่แล้วใน `ManageHedgeGridMode()`:
- `hedgeLossPerLot = abs(hedgePnL) / hedgeLots`
- `closeLots = remainingBudget / hedgeLossPerLot`
- ปรับตาม `SYMBOL_VOLUME_MIN` และ `SYMBOL_VOLUME_STEP`
- ใช้ `trade.PositionClosePartial()` เฉพาะกับ hedge ticket

ผล:
- ไม่ต้องรอ budget ให้พอปิด hedge ทั้งใบ
- Set#2 จะ “ค่อยๆ ถูกซอย” ตามกำไรใน set ตาม concept ที่คุยกัน

### 4) ลำดับการปิดใหม่ใน matching
คง strict in-set เหมือนเดิม แต่เพิ่ม step สุดท้ายเพื่อ “ปิดให้ได้มากที่สุด”

ลำดับใหม่:
1. รวม profit pool เฉพาะใน set เดิม
2. greedy ปิด full-loss tickets ที่ budget ครอบได้
3. ถ้ามี budget เหลือ → partial-close hedge หลัก
4. อัปเดต state:
   - hedge ปิดหมด → `hedgeTicket = 0`
   - bound ปิดแล้ว → `RemoveBoundTicket()`
   - reverse ปิดแล้ว → remove จาก reverse array
5. ถ้ายังมีอะไรเหลือ → set ยัง active ต่อ
6. recovery grid ทำงานต่อใน tick ถัดไปตาม v6.63

### 5) เพิ่ม logging ให้แยกชัดว่า “ค้างเพราะอะไร”
เพิ่ม log ใหม่ เช่น:
- `v6.64 MATCH RETRY Set#2 ...`
- `v6.64 MATCH NO FULL-FIT ... fallback to hedge partial`
- `v6.64 HEDGE PARTIAL Set#2: budget=$X closeLots=Y remainingLots=Z`

เป้าหมาย:
- แยกให้ชัดว่า set ไม่ได้โดน owner lock
- แต่กำลัง re-evaluate และ partial-close ตาม budget

### 6) Dashboard ปรับข้อความสถานะเล็กน้อย
เพิ่มข้อความที่ช่วยลดความสับสน เช่น:
```text
Hedge Recovery | LOCKED | Owner Gen1 (Src H2)
Match Engine   | Active every tick | Budget:$4148 | Hedge partial enabled
```
หรืออย่างน้อยให้เห็นว่า set ยัง “คำนวณอยู่” ไม่ใช่ค้างรอ unlock อย่างเดียว

---

## สิ่งที่ไม่เปลี่ยนแปลง

- ไม่แก้ OrderSend / `trade.Buy` / `trade.Sell`
- ไม่แก้ hedge trigger logic
- ไม่แก้ Trading Strategy / entry signal / grid entry หลัก
- ไม่แก้ Accumulate Close
- ไม่แก้ cross-set behavior — ยัง strict in-set 100%
- ไม่แก้ Sequential Recovery Owner concept v6.59-v6.63
- ไม่แก้ slot numbering v6.63
- ไม่แก้ News / License / Time Filter / Data Sync
- ไม่แก้ low-level execution wrapper; ใช้แนว partial close pattern ที่มีอยู่แล้วในไฟล์เดิม

---

## Validation Checklist

1. Scenario ปัจจุบันของ Set#2:
- หลัง set ยัง active อยู่ ระบบต้องกลับมาคำนวณ matching ใหม่ทุก tick
- ห้ามค้างเพราะ `matchingDone` จาก tick เก่า

2. ถ้า budget < hedge loss ทั้งใบ:
- ต้องเกิด `PositionClosePartial()` กับ hedge หลัก
- hedge lots ต้องลดลงจริง

3. ถ้ามี full-loss tickets ที่ปิดได้ก่อน:
- ปิด full-loss ตาม greedy ก่อน
- budget ที่เหลือค่อยซอย hedge ต่อ

4. หลัง partial close:
- set ต้องยัง active
- ไม่ claim owner ใหม่ก่อน flat จริง
- recovery grid ยังทำงานต่อได้ตาม v6.63

5. ไม่มี cross-set leak:
- Set#2 ใช้เฉพาะ order ใน set เดียวกัน
- ไม่แตะ order ของ set อื่น

6. Dashboard/log:
- ต้องเห็นว่า matching re-run ทุก tick
- ต้องมี log ชัดว่ากำลัง partial-close hedge ไม่ใช่รอเฉยๆ

