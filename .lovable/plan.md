## แผนแก้ Hero Order v7.00 → v7.01

ปัญหาที่เห็นจากภาพ/คำอธิบาย: ตอนนี้ SELL Hero ถูกกัน TP ออกถูกต้องแล้ว แต่เมื่อ SELL basket ปกติปิดด้วย Average TP / Average Trailing ตัว Hero SELL ถูกปิดตามไปด้วย ทั้งที่ควรเหลืออยู่ก่อน และจะปิดได้เฉพาะเมื่อ BUY ฝั่งตรงข้ามปิด หรือโดน SL กันทุนของตัวเองเท่านั้น

### สาเหตุหลักที่พบในโค้ด

1. `CloseAllSide(side)`, `CloseGenSide(gen, side)`, และ `CloseAllSideTF(tfIdx, side)` เรียก `CloseOppositeHeroOnBasketClose(side)` ตอนเริ่มปิด basket
2. ฟังก์ชัน `CloseOppositeHeroOnBasketClose()` ใช้ตรรกะ `oppSide = opposite(closingSide)` เสมอ
3. แต่ใน flow จริงของ Hero แบบใหม่ เมื่อ SELL basket ปกติปิด ควรให้ SELL Hero อยู่ต่อ แล้วเปลี่ยนเป็น `BE_GUARD` + ใส่ SL กันทุน ไม่ใช่ไปปิด Hero ทันที
4. อีกจุดที่ต้องระวังคือ `BuildHeroTicketCache()` ยัง rebuild แบบ rolling ทุก tick; หลัง basket ฝั่งเดียวกันเหลือน้อย/ปิดแล้ว อาจทำให้ phase/ticket list ไม่คงที่พอสำหรับ Hero survivor

### สิ่งที่จะปรับ

#### 1. เปลี่ยนกฎการปิด Hero ให้ถูกทิศทาง

Hero ฝั่งเดียวกับ basket ที่ปิด จะไม่ถูกปิดทันที

ตัวอย่างตามที่คุณอธิบาย:
- SELL มี Hero 3 ตัว
- ราคาไหลลงจน SELL order ปกติปิดด้วย Average TP / Average Trailing
- SELL Hero ต้องยังอยู่
- EA ค่อยเปลี่ยน SELL Hero เป็น `BE_GUARD` และใส่ SL กันทุน
- SELL Hero จะปิดก็ต่อเมื่อ BUY basket ปกติปิด หรือ SL กันทุนของ SELL Hero ถูกชน

#### 2. ทำให้การปิด “พร้อมฝั่งตรงข้าม” ทำงานหลัง Hero อยู่ใน BE_GUARD เท่านั้น

จะปรับ hook ก่อนปิด basket ดังนี้:
- เมื่อ `CloseAllSide(BUY)` ทำงาน → ถ้ามี SELL Hero ที่อยู่ `BE_GUARD` ให้ปิด SELL Hero พร้อม BUY basket
- เมื่อ `CloseAllSide(SELL)` ทำงาน → ถ้ามี BUY Hero ที่อยู่ `BE_GUARD` ให้ปิด BUY Hero พร้อม SELL basket
- แต่ถ้าเป็น Hero ฝั่งเดียวกับ basket ที่กำลังปิด → skip เสมอ

#### 3. เพิ่ม guard กันปิด Hero ใน close path ทั้งหมดที่เป็น basket/trailing/recovery

ตรวจและเพิ่ม `IsHeroTicket(ticket)` skip ในจุดที่อาจปิด position โดยตรง เช่น:
- `CloseAllSide`
- `CloseGenSide`
- `CloseAllSideTF`
- Recovery owner average TP loop
- Opposite survivor cleanup
- Squeeze strip/trailing clear ที่แก้ SL/TP ของ order ปกติ

ยกเว้น path ที่ตั้งใจให้ปิดทั้งหมดจริง ๆ:
- Accumulate/global close (`CloseAllPositions`)
- ปุ่ม Close All / manual close all
- Balance guard / hard global reset ถ้าเป็นการปิดทั้งระบบ

#### 4. เพิ่มสถานะ Hero Survivor ให้ชัดใน Dashboard

ปรับข้อความ Dashboard ให้บอกว่า Hero อยู่ phase ไหน และรออะไร:

```text
Hero SELL: 21/20 GL:18 Hero:3 ARMED
Hero SELL: 3 survivor BE_GUARD SL@BE
Hero SELL wait: BUY basket close / Lock-SL
```

เพื่อให้ดูได้ทันทีว่า:
- Hero ถูก tag อยู่ไหม
- เป็น GL-only จริงไหม
- อยู่ ARMED หรือ BE_GUARD
- กำลังรอฝั่งตรงข้ามปิด หรือรอ SL กันทุน

#### 5. เพิ่ม log audit ให้จับเหตุปิด Hero ได้ชัดกว่าเดิม

เพิ่ม log prefix v7.01 เช่น:

```text
v7.01 Hero SAME-SIDE BASKET CLEARED: side=SELL -> BE_GUARD
v7.01 Hero HOLD: side=SELL reason=SameSideBasketClosed waitOpposite=BUY
v7.01 Hero CLOSE: heroSide=SELL triggerBasket=BUY reason=OppositeBasketClose
v7.01 Hero CLOSED ticket=#... reason=LockProfitSL_HIT|OppositeBasketClose|GlobalClose|UNKNOWN_PATH
```

ถ้ายังมี Hero ปิดผิดทาง จะเห็น `UNKNOWN_PATH` หรือ trigger side ผิดจาก Journal ได้ทันที

### Version bump

ตามกฎโปรเจกต์ จะเพิ่ม minor version:
- `#property version` จาก `7.00` เป็น `7.01`
- `#property description`
- header comment block
- dashboard version/header text
- log prefix ที่เกี่ยวข้องกับ Hero

### สิ่งที่ไม่เปลี่ยนแปลง

ยืนยันว่าจะไม่แก้ logic เหล่านี้:
- ไม่แก้เงื่อนไขเปิดออเดอร์ `OrderSend`, `trade.Buy`, `trade.Sell`
- ไม่แก้ entry signal: SMA/EMA/ZigZag/BB/Squeeze
- ไม่แก้ Grid Loss / Grid Profit lot calculation, distance, candle confirmation
- ไม่แก้สูตร Average TP / Average Trailing Stop เดิม ยกเว้นเพิ่ม guard ไม่ให้ Hero ถูกนำไปปิด/แก้ TPSL ผิดทาง
- ไม่แก้ Hedge / Triple-Gate / Matching Close core logic
- ไม่แก้ License / News / Time / Sync module
- ไม่แก้ Accumulate/global close เพราะเป็นเงื่อนไขปิดทั้งหมดที่อนุญาตไว้

### ผลลัพธ์ที่คาดหวังหลังแก้

กรณี SELL Hero:
1. SELL active ถึง threshold → latest `_GL` 3 ตัวเป็น Hero และ TP/SL ถูกถอด
2. SELL basket ปกติปิดด้วย Avg TP หรือ Avg Trail → SELL Hero ไม่ปิด
3. EA ใส่ SL กันทุนให้ SELL Hero เมื่อเข้าสู่ `BE_GUARD`
4. SELL Hero ปิดได้แค่:
   - BUY basket ปกติปิด แล้ว SELL Hero ปิดพร้อมกัน
   - หรือ SELL Hero โดน SL กันทุน
   - หรือ Accumulate/global close ทั้งระบบ