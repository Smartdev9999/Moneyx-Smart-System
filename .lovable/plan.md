## แผนแก้ไข v1.56 — Hero ต้องสลับฝั่งแบบครบวงจร และห้าม BUY ล็อคซ้ำเอง

จากภาพและโค้ดปัจจุบัน จุดที่ผิดมี 2 ส่วนหลัก:

1. `BuildHeroTicketCache()` v1.55 ใช้เงื่อนไข `curPhase != 0` ทำให้ Dynamic Refresh ทำงานทั้งตอน `ARMED` และ `BE_GUARD`  
   ผลคือเมื่อ BUY เข้า `BE_GUARD` แล้ว หากมี BUY order ใหม่/ราคาดีกว่าเข้ามา ระบบยังเอา order ใหม่มาแทนชุด Hero เดิมได้ ทำให้ BUY Hero ถูกต่ออายุเองไม่จบ และ Dashboard ยังขึ้น `Hero Owner = BUY (locked)` ต่อเนื่อง

2. `Side-Alternation Lock` เดิมยังปลดล็อคง่ายเกินไป เพราะดูแค่ opposite side active หรือ self flat ในบางจังหวะ  
   แต่ requirement ที่ต้องการคือ: หลัง Hero ฝั่ง BUY ปิดแล้ว ต้องรอให้ SELL ได้เป็น Hero และ SELL Hero ต้องปิดก่อนเท่านั้น BUY ถึงจะมีสิทธิ์เป็น Hero รอบใหม่ได้

## พฤติกรรมใหม่ที่จะแก้ให้ถูกต้อง

ลำดับจะเป็นแบบนี้:

```text
BUY Hero active/armed
  -> BUY non-Hero basket ปิดกำไรปกติ
  -> BUY Hero เข้า BE_GUARD และล็อค ticket ชุดสุดท้ายไว้
  -> BUY Hero ปิดตามกฎ Opposite AvgTP/TP gate
  -> ระบบตั้งสถานะ: รอบถัดไปอนุญาตเฉพาะ SELL Hero เท่านั้น
  -> SELL Hero ต้องเกิดขึ้นและปิดจบก่อน
  -> จากนั้นจึงอนุญาต BUY Hero รอบใหม่
```

ดังนั้นจะไม่มีกรณี `Hero Owner = BUY (locked)` ซ้ำต่อเนื่องหลังจาก BUY Hero cycle จบแล้ว โดยยังไม่ได้ผ่าน SELL Hero cycle ก่อน

## สิ่งที่จะเปลี่ยนใน `public/docs/mql5/Golden_Kuy3_EA.mq5`

### 1. เพิ่ม Version เป็น v1.56 ทุกจุด
- `#property version` 1.55 -> 1.56
- `#property description`
- Header comment block
- Dashboard title `Golden Kuy3 v1.56`
- Hero panel `HERO ORDER (v1.56)`
- Init/Deinit logs และ Hero audit logs ที่เกี่ยวข้อง

### 2. แยก Dynamic Refresh ให้ทำเฉพาะช่วง `ARMED` เท่านั้น
แก้ใน `BuildHeroTicketCache()`:

- ถ้า `curPhase == 2` (`ARMED`):
  - ยังคง Dynamic Price-Extreme เหมือน v1.55
  - BUY เลือก ticket ราคาเปิดต่ำสุด N ใบ
  - SELL เลือก ticket ราคาเปิดสูงสุด N ใบ
  - อัปเดต Dashboard และ `IsHeroProtectedTicket()` จากชุดเดียวกัน

- ถ้า `curPhase == 3` (`BE_GUARD`):
  - ห้าม rebuild จาก order ใหม่อีก
  - ทำได้แค่ prune ticket ที่ปิดไปแล้วจากชุด Hero เดิม
  - order ใหม่ฝั่งเดียวกันหลังเข้า BE_GUARD จะถือเป็น non-Hero ตามปกติ ไม่ได้มาต่ออายุ Hero owner

นี่ตรงกับ requirement เดิมที่ว่า Hero ควรอัปเดตไปเรื่อยๆ “จนกว่าจะมีการปิดกำไรแบบปกติของ non-Hero” — หลังจาก non-Hero basket ปิดแล้วและเข้า BE_GUARD จะไม่ refresh ต่อแล้ว

### 3. เพิ่ม Alternation State แบบบังคับรอบถัดไป
เพิ่มตัวแปรสถานะใหม่ เช่น:

```text
g_heroNextAllowedSide = -1 / BUY / SELL
```

กติกา:

- ตอนเริ่ม EA หรือยังไม่เคยมี Hero close: `-1` = ฝั่งไหนก็เริ่มได้ตามเงื่อนไข
- เมื่อ `CloseHeroOnSide(BUY)` หรือ BUY Hero ถูกปิด/auto-release จริง:
  - ตั้ง `g_heroNextAllowedSide = SELL`
- เมื่อ `CloseHeroOnSide(SELL)` หรือ SELL Hero ถูกปิด/auto-release จริง:
  - ตั้ง `g_heroNextAllowedSide = BUY`
- ตอนจะ activate Hero ใหม่ใน Branch B:
  - ถ้า `g_heroNextAllowedSide` ถูกตั้งไว้ และ side ปัจจุบันไม่ใช่ฝั่งที่อนุญาต -> block
  - ฝั่งเดิมจึงไม่สามารถเป็น Hero ซ้ำได้จนกว่าฝั่งตรงข้ามจะเป็น Hero และปิดจบก่อน

### 4. ทำให้ Dashboard แสดงสถานะรอฝั่งถัดไปชัดเจน
เพิ่ม/แก้ row ใน Hero panel:

- `Hero Owner`: แสดง owner จริงเฉพาะ phase `BE_GUARD`
- `Next Allowed`: แสดง `BUY`, `SELL`, หรือ `ANY`
- `Last Closed`: แสดงฝั่ง Hero ที่เพิ่งปิดล่าสุด
- ถ้า BUY ถูก block เพราะต้องรอ SELL ก่อน ให้ Dashboard แสดงประมาณ:

```text
Next Allowed    SELL
Hero BUY        active=... Hero=0 WAIT/ALT-BLOCK
Hero SELL       active=... Hero=... ARMED/BE_GUARD
```

### 5. Harden Reset/Recovery สำหรับเคสที่ state ค้างจากเวอร์ชันเก่า
เพิ่ม logic recovery แบบปลอดภัย:

- ถ้า phase เป็น `BE_GUARD` แต่ stable set ว่างจริง -> reset phase และตั้ง next allowed เป็นฝั่งตรงข้าม
- ถ้า stable ticket ถูกปิดจาก broker/manual/SL/TP -> stamp last closed + next allowed เหมือน `CloseHeroOnSide()`
- ถ้า Dashboard owner ยังเป็น BUY แต่ BUY Hero tickets หมดแล้ว -> ไม่ให้ค้าง owner หลอก

### 6. ปรับ log เพื่อ debug ได้ชัด
เพิ่ม log แบบ throttle:

```text
v1.56 Hero ALT-STATE lastClosed=BUY nextAllowed=SELL owner=NONE/BUY/SELL
v1.56 Hero ALT-BLOCK side=BUY waitingNext=SELL
v1.56 Hero BE_GUARD FREEZE side=BUY heroTickets=...
```

จะช่วยยืนยันว่า EA ไม่ได้เลือก BUY Hero ซ้ำเอง และกำลังรอ SELL ตามกฎใหม่

## สิ่งที่ไม่เปลี่ยนแปลง / ไม่กระทบ Trading Logic

ยืนยันว่าแผนนี้ไม่แก้ logic เทรดหลัก:

- ไม่แก้ `trade.Buy`, `trade.Sell`, `trade.PositionClose`, `OrderSend`
- ไม่แก้เงื่อนไขเปิด order
- ไม่แก้ Grid entry / Grid distance / Grid lot multiplier
- ไม่แก้ TP/SL/Trailing/Breakeven calculation
- ไม่แก้ Average TP / Average Trailing strict 2-cross
- ไม่แก้ Accumulate close / Cost-Hit Restart
- ไม่แก้ Master TP / TP mode
- ไม่แก้ logic ปิด Hero ด้วย Opposite AvgTP/TP gate v1.50/v1.51
- ไม่แก้ `InpHero_MinOrdersToActivate` ดังนั้นถ้า SELL ยัง active `8/15` ตาม Dashboard จะยังไม่ activate จนถึง threshold 15 เว้นแต่ผู้ใช้ปรับ input เอง

## ผลลัพธ์ที่คาดหวัง

หลังแก้ v1.56:

- BUY Hero จะไม่ต่ออายุตัวเองด้วย order BUY ใหม่หลังเข้า `BE_GUARD`
- เมื่อ BUY Hero ปิดจบ ระบบจะบังคับรอ SELL Hero ก่อน
- BUY จะไม่สามารถกลับมาเป็น Hero รอบใหม่ได้จนกว่า SELL Hero จะเกิดขึ้นและปิดจบ
- Dashboard จะไม่ขึ้น `Hero Owner = BUY (locked)` ค้างผิดจังหวะ
- Dashboard จะแสดง `Next Allowed` ให้เห็นชัดว่าตอนนี้ระบบกำลังรอฝั่งไหน
- ถ้า SELL ยังไม่ถึง `minAct` Dashboard จะบอกว่า SELL ยังรอจำนวน order ไม่ใช่ปล่อยให้ BUY lock ซ้ำ