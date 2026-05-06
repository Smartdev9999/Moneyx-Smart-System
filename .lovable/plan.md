## สรุปที่ตรวจเจอ

จากโค้ด `Golden_Kuy3_EA.mq5` ปัญหาหลักอยู่ใน `BuildHeroTicketCache()` ของ v1.48 ฝั่ง Branch A ตอน Hero active แล้ว:

```text
int takeA = MathMin(InpHero_OrderCount, nPool - 1);
```

เงื่อนไข `nPool - 1` นี้ถูกต้องเฉพาะตอน “เริ่ม activate” เพราะต้องเหลือ non-Hero อย่างน้อย 1 ตัวไว้เป็น basket ปกติ แต่พอ Hero active อยู่แล้ว และ basket ปกติถูกปิดด้วย TP/Avg/เงื่อนไขปิด ระบบยังบังคับ `nPool - 1` ทำให้ Hero หลุดออกจากชุด Hero ทีละตัว กลายเป็น non-Hero ชั่วคราว จากนั้นระบบ TP/Avg/Close ต่าง ๆ สามารถไปปิดตัวที่หลุดนี้ได้ จึงเกิดอาการ “Hero ไม่ถูกกัน / ปิดหมด” และ Dashboard ยังขึ้น `Hero Owner = NONE (waiting close)` เพราะระบบยังเห็นว่ามี non-Hero เหลืออยู่ จึงไม่เข้า `BE_GUARD` ให้ Hero จริง

## แผนแก้ v1.49 — Hero Guard After Basket Close

### 1. แก้ Branch A ของ `BuildHeroTicketCache()`
- ตอน `curPhase != 0` หรือ Hero active แล้ว จะเปลี่ยนจาก:

```text
takeA = min(N, nPool - 1)
```

เป็น:

```text
takeA = min(N, nPool)
```

ผลลัพธ์:
- ตอนยังมี basket ปกติอยู่: Hero ยังเลือก N ตัว extreme ตามเดิม และ non-Hero ยังเหลือถ้าจำนวน order มากกว่า N
- ตอน basket ปกติปิดหมด เหลือแต่ Hero: ระบบจะไม่ปล่อย Hero ออกมาเป็น non-Hero อีก
- `CountNonHeroMainOnSide()` จะเห็นเป็น 0 แล้ว `DetectSameSideBasketClearedForHero()` จะเปลี่ยน phase เป็น `BE_GUARD`
- Dashboard จะเปลี่ยนจาก `NONE (waiting close)` เป็น owner ฝั่งที่ควรล็อกจริง เช่น `BUY (locked)` หรือ `SELL (locked)`

### 2. เพิ่ม helper กัน Hero แบบแข็งแรงขึ้น
เพิ่ม helper เช่น:

```text
IsHeroProtectedTicket(ticket)
```

ให้เช็คทั้ง:
- `g_heroTickets[]`
- `g_heroBuyStable[]`
- `g_heroSellStable[]`

เพื่อกันช่วง cache ยังไม่ rebuild หรือ flat array ยังไม่ตรงกับ stable set

### 3. ใช้ helper ใหม่นี้กับทุกจุดที่ “ไม่ควรแตะ Hero”
จะเปลี่ยนเฉพาะ guard จาก `IsHeroTicket(ticket)` เป็น `IsHeroProtectedTicket(ticket)` ในจุดเหล่านี้:
- `CountNonHeroMainOnSide()`
- `CloseAllSide()`
- `CloseAllOurs()`
- `CalcSideFloating_NonHero()`
- `CalcSideAvgPrice_NonHero()`
- `EnforceClearTPIfDisabled()`
- `ManageTakeProfit()` ตอน push broker TP
- `ManageAverageTrailing()`
- `ManagePerOrderTrailing()`

เป้าหมายคือ ถ้า ticket เคยอยู่ใน stable Hero set จะไม่ถูกนับเป็น non-Hero และไม่ถูก TP/AvgTrail/CloseAll ปิดผิดฝั่ง

### 4. เพิ่ม log ตรวจสอบให้เห็นชัด
เพิ่ม audit log เฉพาะจุดสำคัญ เช่น:

```text
v1.49 Hero ACTIVE-KEEP side=BUY nPool=5 take=5 phase=ARMED/BE_GUARD
v1.49 Hero BASKET-CLEARED side=BUY -> BE_GUARD protected=5
```

เพื่อให้เวลา backtest เห็นว่าเมื่อ basket ปกติปิดแล้ว Hero ยังถูกกันอยู่ครบ ไม่หลุดไปเป็น non-Hero

### 5. อัปเดต Version และ Memory
ตามกฎเวอร์ชัน EA จะอัปเดตทั้งหมดจาก v1.48 เป็น v1.49:
- Header comment block
- `#property version`
- `#property description`
- Dashboard title / Hero section
- `Print()` init/deinit/audit logs ที่เกี่ยวกับ version
- เพิ่ม memory: `Golden Kuy3 v1.49 Hero Guard After Basket Close`

## สิ่งที่ไม่เปลี่ยนแปลง

ยืนยันว่าจะไม่แก้ logic เหล่านี้:
- ไม่แก้ `trade.Buy`, `trade.Sell`, `trade.PositionClose`, `OrderSend` วิธีส่งคำสั่ง
- ไม่แก้สูตร grid entry, lot multiplier, initial entry
- ไม่แก้ TP/SL/Trailing/Breakeven calculation เดิม
- ไม่แก้ Accumulate / AvgTrailing strategy เดิม
- ไม่แก้สูตรเลือก Hero แบบ price-extreme: BUY = order ราคาต่ำสุด, SELL = order ราคาสูงสุด
- ไม่แก้ Side-Alternation Lock เดิม: Hero ต้องสลับฝั่ง ไม่ออกซ้ำฝั่งเดิมจนกว่าเงื่อนไขปลดล็อกจะครบ
- `InpHero_Enabled=false` จะยังทำงานเหมือนเดิม

## ผลที่คาดหวังหลังแก้

- เมื่อ BUY Hero active และ BUY basket ปกติชน TP ปิด เหลือแต่ BUY Hero: ระบบจะไม่ปล่อย Hero ตัวใดออกจาก Hero set
- Dashboard จะไม่ค้าง `NONE (waiting close)` ในจุดที่ควรเป็น owner แล้ว แต่จะเข้า `BE_GUARD`
- TP/AvgTrail/CloseAll จะไม่ปิด Hero ผิดพลาด
- ถ้า Hero ถูกปิดตามเงื่อนไขของ Hero จริง จึงค่อย stamp `Last Closed` และบังคับให้รอบถัดไปต้องสลับฝั่ง