## Plan v7.07 — จัด Hero flow ใหม่เป็น 2 ขั้น: Candidate ก่อน, Owner ทีหลัง

จากภาพตอนนี้ปัญหาหลักคือ Dashboard แสดง `Hero Owner = BUY (locked)` ทั้งที่ BUY/SELL ยังเป็นแค่ `ARMED` และยังไม่มีฝั่งไหนปิด basket order ธรรมดาออกไปจริง ๆ ดังนั้นระบบยังล็อค owner เร็วเกินไปในเชิงสถานะ/การแสดงผล และอาจทำให้ logic ฝั่งตรงข้ามถูกตีความผิด

### Flow ใหม่ที่ต้องการ

```text
1) Scan threshold
   BUY ถึงเกณฑ์ไหม?  SELL ถึงเกณฑ์ไหม?

2) ถ้าถึงเกณฑ์: ตั้งเป็น Candidate / ARMED เท่านั้น
   - ยังไม่ตั้ง Owner
   - BUY และ SELL สามารถ ARMED พร้อมกันได้
   - ยังไม่แสดงว่า locked

3) รอ basket ธรรมดาของฝั่งใดฝั่งหนึ่งปิดหมดก่อน
   - เช่น ถ้า SELL basket ธรรมดาปิด TP / Average Trailing ก่อน
   - SELL จึงเปลี่ยนจาก ARMED -> BE_GUARD
   - SELL จึงเป็น Hero Owner จริง

4) หลังมี Owner จริงแล้ว
   - Single-side lock จึงเริ่มทำงาน
   - ฝั่งตรงข้ามจะไม่สามารถสร้าง Hero owner ใหม่ จนกว่า Hero owner เดิมจะปิดหมด/reset
   - ถ้าเปิด PerSideGenIsolation: เฉพาะฝั่ง owner เปิด GM(N+1) เพื่อเทรดต่อ โดยไม่เอา GM(N+1) ไปปนกับ Hero เดิม
```

## จุดที่จะแก้ใน `public/docs/mql5/Gold_Miner_EA.mq5`

### 1. แก้ Dashboard `Hero Owner`
ตอนนี้ Dashboard ยังใช้ logic เก่า:
```cpp
if(g_heroPhase_Buy != 0 || CountHeroOnSide(BUY) > 0) ownerStr = "BUY";
```
ซึ่ง `phase != 0` รวม `ARMED` ด้วย จึงแสดง `BUY (locked)` ทันทีเมื่อ BUY ถึงเกณฑ์ก่อน

จะแก้ให้ Owner แสดงเฉพาะเมื่อ `phase == 3` เท่านั้น:
```cpp
if(g_heroPhase_Buy == 3) ownerStr = "BUY";
else if(g_heroPhase_Sell == 3) ownerStr = "SELL";
else ownerStr = "NONE";
```
และเปลี่ยน tag เป็น:
- `WAIT OWNER` หรือ `unlocked` เมื่อยังไม่มี BE_GUARD
- `locked` เฉพาะเมื่อมี owner จริงแล้ว

ผลที่คาดหวังจากภาพตัวอย่าง:
- `Hero BUY ... ARMED`
- `Hero SELL ... ARMED`
- `Hero Owner = NONE (waiting close)`
ไม่ใช่ `BUY (locked)`

### 2. แยกสถานะ “Candidate” ออกจาก “Owner” ให้ชัดเจน
ใน `BuildHeroTicketCache()` จะคง logic ที่ให้ทั้งสองฝั่งเข้า `ARMED` ได้พร้อมกัน แต่จะปรับ comment/audit และ guard ให้ชัดว่า:
- `phase == 2` = Candidate / ARMED only
- `phase == 3` = Owner / BE_GUARD only

Single-side lock จะใช้เฉพาะ `phase == 3` เท่านั้น

### 3. เพิ่ม helper สำหรับ owner จริง
เพิ่ม helper เล็ก ๆ เช่น:
```cpp
int GetHeroOwnerSide()
```
ให้คืนค่า:
- BUY เฉพาะ `g_heroPhase_Buy == 3`
- SELL เฉพาะ `g_heroPhase_Sell == 3`
- `-1` ถ้ายังไม่มี owner

แล้วใช้ helper นี้ใน:
- Dashboard owner row
- `BuildHeroTicketCache()` activeOwner calculation
- future-safe guard จุดที่ต้องรู้ owner จริง

เพื่อลดโอกาส logic เก่าแบบ `phase != 0` กลับมาอีก

### 4. ตรวจ `DetectSameSideBasketClearedForHero()` ให้ owner ถูกเลือกจากฝั่งที่ basket ธรรมดาปิดก่อนจริง
ตอนนี้ BE_GUARD ถูกตั้งเมื่อ:
```cpp
CountHeroOnSide(side) > 0
CountNonHeroMainOnSide(side) == 0
```
จะคงแนวคิดนี้ แต่จะทำให้ flow ปลอดภัยขึ้นโดย:
- ฝั่งที่จะเข้า BE_GUARD ต้องมี Hero candidate อยู่แล้ว (`phase == 2` หรือมี tagged Hero)
- ถ้าอีกฝั่งยังเป็นแค่ ARMED ไม่ถือว่าเป็น owner และไม่ block การชนะของฝั่งที่ basket ปิดก่อน
- ถ้าฝั่ง SELL basket ปิดก่อนตามตัวอย่าง SELL จะกลายเป็น owner แม้ BUY จะถึงเกณฑ์ก่อน

### 5. เพิ่ม audit log เพื่อไล่ flow ได้เป็นระบบ
เพิ่ม log แบบ throttle เมื่อสถานะเปลี่ยน:
- `Hero CANDIDATE: side=BUY active=15 threshold=15 hero=2`
- `Hero CANDIDATE: side=SELL active=21 threshold=15 hero=4`
- `Hero OWNER SET: side=SELL reason=BasketCleared phase=BE_GUARD`
- `Hero OWNER WAIT: BUY/SELL armed, no basket cleared yet`

สิ่งนี้ช่วย debug รอบต่อไปได้ทันทีว่าระบบกำลังอยู่ขั้น Candidate หรือ Owner จริง

### 6. Version bump
อัปเดตเป็น `v7.07` ทุกจุดตามกฎโปรเจกต์:
- `#property version`
- `#property description`
- header comment block
- dashboard title/log init/deinit ที่แสดง version
- memory note สำหรับ v7.07

## สิ่งที่ไม่เปลี่ยนแปลง

ยืนยันว่าจะไม่แตะส่วนต่อไปนี้:
- ไม่แก้ `OrderSend`, `trade.Buy`, `trade.Sell`, `trade.PositionClose`
- ไม่แก้ entry strategy: SMA/EMA/Squeeze/BB/ZigZag
- ไม่แก้ grid entry/exit, lot, distance, candle confirm
- ไม่แก้ TP/SL/Trailing/Breakeven/Average trailing formula
- ไม่แก้ Hedge / Triple-Gate / Recovery / DD% TP / Daily Target / Balance Guard
- ไม่แก้ License / News / Sync modules
- ไม่เปลี่ยนสูตร Hero lock-profit SL (`ComputeHeroLockProfitSL`, `ValidateHeroLockProfitSL`, `ApplyHeroLockProfitSL`)
- ไม่ยกเลิก v7.05/v7.06 เรื่อง GM(N+1) isolation และ gen-locked Hero pool

## Expected behavior หลังแก้

จากภาพที่ส่งมา:
- BUY ถึงเกณฑ์และมี Hero candidate 2 order
- SELL ถึงเกณฑ์และมี Hero candidate 4 order
- ยังไม่มีฝั่งไหนปิด basket ธรรมดาหมด

Dashboard ต้องแสดง:
```text
Hero Owner   NONE (waiting close)
Hero BUY     15/15 GL:2  Hero:2  ARMED
Hero SELL    21/15 GL:12 Hero:4  ARMED
```

ถ้าต่อมา SELL ปิด basket ธรรมดาก่อน:
```text
Hero Owner   SELL (locked)
Hero SELL    ... BE_GUARD
```

ถ้าต่อมา BUY ปิด basket ธรรมดาก่อน:
```text
Hero Owner   BUY (locked)
Hero BUY     ... BE_GUARD
```

สรุปคือ “ถึงเกณฑ์ก่อน” จะเป็นแค่ Candidate เท่านั้น ส่วน “ปิด order ธรรมดาก่อน” เท่านั้นที่เป็น Owner จริง