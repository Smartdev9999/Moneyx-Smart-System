## ปัญหาที่พบ
จาก log ในภาพ: `hold G2->G3 (cur safe=1 priors safe=0 ... recovery=OFF)` หมายความว่า **G2 พร้อมจะไป G3 แล้ว** แต่ระบบถูกบล็อกโดย `AreAllPriorGroupsSafe(cur)` เพราะยังมีกลุ่มก่อนหน้า เช่น G1 ที่มี position ค้างและยังไม่ถูกนับว่า `safe`.

สาเหตุหลักในโค้ดตอนนี้คือ `TryAdvanceToNextGroup()` เลือก `cur` เป็น **กลุ่ม active ล่าสุด/สูงสุด** แล้วเช็กว่า prior groups ทุกกลุ่มต้อง safe ก่อน แต่หาก prior group ยังรอ Triple-Gate/MinGain/Expansion→Normal หรือยังไม่ถูก flag เป็น recovery ระบบจะ block การเปิดกลุ่มถัดไปตลอด จึงเกิดอาการ “นิ่ง ไม่ออกออเดอร์ต่อ”.

## แผนแก้ไข

### 1) แยกสถานะ “safe สำหรับเปิดกลุ่มถัดไป” ออกจาก “รอปิด Matching Close”
- เพิ่ม helper ใหม่สำหรับตรวจ prior group แบบไม่เข้มเกินไป เช่น `IsPriorGroupSafeForAdvance()`
- ถ้ากลุ่มก่อนหน้ามี hedge position แล้ว และ main side ที่ติดลบมี hedge ครอบอยู่ ให้ถือว่า “ปลอดภัยพอสำหรับให้ G ถัดไปเปิดต่อ”
- ไม่ต้องรอให้ Triple-Gate ปิดสำเร็จหรือเข้า `g_groupInRecovery` ก่อน เพราะนั่นคือ logic ปิด/ฟื้นตัว ไม่ใช่เงื่อนไขเปิดกลุ่มใหม่

### 2) ปรับ `AreAllPriorGroupsSafe()` ให้ไม่ deadlock
- เปลี่ยนให้ใช้ helper ใหม่แทน `IsGroupSafeToAdvance()` แบบเดิม
- ยังคงบล็อกกรณีอันตรายจริง:
  - prior group มี main position แต่ไม่มี hedge เลย
  - prior group ยังมี pending initial/main ที่ยังไม่ hedge-lock
  - prior group ยังไม่เข้า hedge state
- แต่ไม่บล็อกกรณีที่ prior group hedge-lock แล้ว แม้ยังมี floating loss และยังรอ MinGain/Expansion gate อยู่

### 3) เพิ่ม diagnostic log ให้ชี้กลุ่มที่เป็นตัวบล็อกจริง
- แก้ log `hold G%d->G%d ... priors safe=0` ให้บอกเลขกลุ่ม prior ที่ block เช่น `blockPrior=G1 reason=unhedged-main/no-hedge/wait-lock`
- จะช่วยให้ดู Journal แล้วรู้ทันทีว่าติดที่ G ไหน ไม่ใช่เห็นแค่ `priors safe=0`

### 4) อัปเดต version ตามกฎ EA
- เพิ่มจาก v2.8.1 เป็น v2.8.2
- อัปเดต:
  - header comment
  - `#property version`
  - `#property description`
  - dashboard title
  - init log / hold log version ที่เกี่ยวข้อง

### 5) บันทึก memory หลังแก้
- เพิ่ม memory ใหม่สำหรับ Golden2 v2.8.2 ว่า prior-group advance guard ต้องไม่ผูกกับ Triple-Gate/Recovery close state จนทำให้ queue deadlock

## สิ่งที่ไม่เปลี่ยนแปลง
- ไม่แก้ `trade.Buy`, `trade.Sell`, `trade.PositionClose`, `OrderSend`, `OrderModify`, `OrderDelete`
- ไม่แก้ Entry Mode: PENDING / SMA / INSTANT
- ไม่แก้ Grid Loss / Grid Profit lot, distance, candle confirm, ATR snapshot
- ไม่แก้ Hedge mirror 1:1, pending hedge, arm/disarm, block percent
- ไม่แก้ Average TP/SL, MaxGrid trailing, per-order trailing, accumulate close
- ไม่แก้ Force-close opposite unhedged
- ไม่แก้ ParseComment/MakeComment side-tag format
- ไม่แก้ ATR/ADX hide logic ในรอบนี้ นอกจากคงของเดิมไว้

## ผลลัพธ์ที่คาดหวัง
เมื่อ G2 ขึ้น `cur safe=1` แต่ prior group ยังมี hedge-lock ค้างอยู่ ระบบจะไม่หยุดที่ `priors safe=0` แบบเดิม และสามารถเปิด G3 ต่อได้ โดยยังรักษา guard ไม่ให้ข้ามกลุ่มที่ยังเป็น unhedged exposure จริง