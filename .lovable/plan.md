
## Fix v6.18 — แยก DD Hedge ตาม Generation ให้ชัด และไม่นับ order ของชุดเก่า

### ปัญหาที่พบ
ตอนนี้ `CheckAndOpenHedgeByDD()` กับ `CountUnboundOrders()` ตัดแค่ hedge/bound ticket ออก แต่ยังมีโอกาสเอา order ที่เป็น generation เก่า (`GM`, `GM1`, `GM2`) มารวมคิด DD ถ้ามันไม่ได้อยู่ใน `boundTickets` แล้ว

ผลคือ:
- หลังชุด hedge เก่าปิดบางส่วน/ปล่อยบาง order ออกมา
- order รุ่นเก่ายังติดลบอยู่
- ระบบมองว่าเป็น “unbound loss” แล้วเปิด hedge ใหม่ทันที
- ทำให้ Hedging2 ไปยุ่งกับ order ของ Hedging1 ซึ่งผิดจากโครงสร้างที่ต้องการ

### แผนแก้ไข
1. เพิ่ม helper สำหรับคัด order ที่ “มีสิทธิ์” ถูกนำไปคิด hedge ใหม่
   - ต้องไม่ใช่ hedge / hedge grid / reverse
   - ต้องไม่ใช่ bound ticket ของ active set ใดๆ
   - ต้องเป็น comment generation ปัจจุบันเท่านั้น (`ExtractGeneration(comment) == g_cycleGeneration`)
   - ถ้าไม่ใช่ format `GM...` จะไม่เอามาคิด

2. ปรับ logic นับ DD ใน `CheckAndOpenHedgeByDD()`
   - คิด BUY DD / SELL DD จาก “current generation only”
   - ไม่นับ order generation เก่า แม้จะยังติดลบอยู่
   - ทำให้ Hedging2 โฟกัสเฉพาะ `GM1`, Hedging3 โฟกัสเฉพาะ `GM2`

3. ปรับตัวนับ order สำหรับการเปิด hedge
   - แยก/ปรับ `CountUnboundOrders()` ให้เป็น generation-aware
   - ใช้เงื่อนไขเดียวกันทั้งตอน “คำนวณ DD” และ “bind order เข้า set ใหม่”
   - ป้องกันไม่ให้ set ใหม่ไป bind order ของชุดเก่า

4. คงการทำงานของชุดเก่าไว้ตามเดิม
   - order ที่ยัง bound อยู่ → ให้ set เดิมจัดการเอง
   - order generation เก่าที่หลุดจาก set แล้ว → ให้ recovery/orphan logic เดิมจัดการต่อด้วย prefix เดิม
   - ไม่ให้ trigger hedge ใหม่ดึง order กลุ่มนี้กลับมาปน

5. เพิ่มความชัดเจนบน dashboard/log
   - แสดงว่า DD mode ตอนนี้กำลังดู generation ไหน เช่น `DD Scope: GM1`
   - ถ้าจำเป็น แสดง DD ของ current generation เพื่อเช็กได้ทันทีว่าระบบคิดจากชุดไหน

6. bump version `v6.17 -> v6.18`
   - อัปเดต `#property version`
   - `#property description`
   - header comment
   - จุดที่แสดง version/log บน EA

### Technical details
```text
หลักการใหม่:
- Hedge Set#1 bind order ของ GM
- หลังเปิด hedge แล้ว cycle ขยับไป GM1
- DD hedge รอบถัดไปจะดูเฉพาะ GM1 ที่ยังไม่ bound
- GM เดิมจะไม่ถูกเอามาคิดเปิด Hedging2 อีก

ตัวอย่าง:
GM   = ชุดเก่า กำลัง recovery ของตัวเอง
GM1  = ชุดใหม่ที่ใช้วัด DD เพื่อเปิด Hedging2
GM2  = ชุดถัดไปสำหรับ Hedging3
```

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (`trade.Buy`, `trade.Sell`, `trade.PositionClose`) ไม่แก้
- Trading Strategy Logic หลัก (entry, SMA/ZigZag, grid หลัก, TP/SL, trailing, accumulate close) ไม่แก้
- Core Module Logic (license, news, time filter, data sync) ไม่แก้
- Triple-gate close ของ hedge set (Expansion + Zone + TP Distance) ไม่เปลี่ยน
- Orphan recovery framework ไม่เปลี่ยนแนวคิดหลัก
- การแก้ครั้งนี้โฟกัสเฉพาะ “scope ของ order ที่เอามาคิด DD และเปิด hedge ใหม่” เพื่อให้แต่ละชุดแยกกันจริง และไม่กระทบ trading logic หลัก
