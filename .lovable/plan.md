
## v6.63 — Strict Sequential Unlock by GM Order Only

### ปัญหาจริงตอนนี้
จากโค้ด v6.62 ที่อ่านอยู่ ปัญหาที่ทำให้ยัง “ปลดหลายชุดพร้อมกัน” มี 2 จุดหลัก:

1. `GetSequentialAllowedGeneration()` ตอนนี้ scan เฉพาะ comment hedge แบบ `GM_HEDGE_`
   - ทำให้ queue อิงจาก “hedge ที่ยังค้าง” ไม่ใช่ “generation ต่ำสุดที่ยังมีออเดอร์จริง”
   - ใน screenshot จึงได้ `Allowed Hedge: Gen5 (GM_HEDGE_6)` ทั้งที่ยังมี `GM`, `GM1`, `GM2`, `GM3`, `GM4` ค้างอยู่

2. `ManageOrphanGrid()` ใช้เงื่อนไข
   ```cpp
   if(seqAllowed != -1 && gen > seqAllowed) continue;
   ```
   แปลว่า orphan ที่ gen ต่ำกว่า allowed จะวิ่งพร้อมกันหมด
   - ถ้า allowed = Gen5 → Gen0..Gen5 recover พร้อมกันได้
   - นี่คือสาเหตุที่ user เห็นหลายชุดถูกปลดพร้อมกัน

มีจุดเสริมที่ควรแก้พร้อมกัน:
3. comment hedge แบบ DD คือ `GM_HEDGE_D<n>` ยังไม่ถูก parse ใน sequential helper ปัจจุบัน
   - ถ้ามี DD hedge จะหลุดคิวได้

---

## พฤติกรรมที่จะแก้ให้ตรงตามที่ user ต้องการ
ให้ระบบปลดล็อคตามลำดับ generation จริง:
```text
GM  → GM1 → GM2 → GM3 → ...
```

กติกาใหม่:
- ถ้ายังมีออเดอร์ของ `GM` อยู่แม้แต่ 1 ตัว → อนุญาตเฉพาะ Gen0
- เมื่อ Gen0 ปิดหมดทุกออเดอร์ → ขยับไป Gen1
- เมื่อ Gen1 ปิดหมด → ขยับไป Gen2
- ทำแบบนี้ทีละ generation จนหมด
- ไม่มีการ recover หลาย GM พร้อมกันอีก

ตัวอย่างจาก screenshot:
```text
มีออเดอร์: GM, GM1, GM2, GM3, GM4, GM5, GM6, GM_HEDGE_6
ผลที่ต้องได้: allowed = Gen0 ไม่ใช่ Gen5
```

---

## แนวทางแก้ไขใน `public/docs/mql5/Gold_Miner_EA.mq5`

### 1) เปลี่ยน `GetSequentialAllowedGeneration()` เป็น “lowest live generation” แบบ strict
ให้ scan ออเดอร์จริงทุกตัวของ symbol + magic แล้วหา generation ต่ำสุดจาก comment ทั้งหมดที่เป็นของระบบ เช่น:
- `GM`
- `GM_INIT`
- `GM_GL#`
- `GM_GP#`
- `GM1_INIT`
- `GM1_GL#`
- `GM_HEDGE_6`
- `GM_HEDGE_D6`

ผลลัพธ์:
- คืน generation ต่ำสุดที่ยังมีออเดอร์ค้างจริง
- ไม่ใช่ lowest active hedge only

### 2) ขยาย `ParseGenerationFromComment()` ให้รองรับครบ
รองรับให้ชัดเจน:
- `GM`, `GM_*` → Gen0
- `GM1_*`, `GM2_*`, ... → Gen1, Gen2, ...
- `GM_HEDGE_1` → Gen0
- `GM_HEDGE_D1` → Gen0
- `GM_HEDGE_6` / `GM_HEDGE_D6` → Gen5

เพื่อไม่ให้ DD hedge หลุด sequential queue

### 3) แก้ `ManageOrphanGrid()` ให้ strict generation เดียว
เปลี่ยน guard จาก:
```cpp
if(seqAllowed != -1 && gen > seqAllowed) continue;
```
เป็น:
```cpp
if(seqAllowed != -1 && gen != seqAllowed) continue;
```

ผลคือ:
- orphan recover ได้เฉพาะ generation ที่กำลังถูกอนุญาต
- Gen0 ยังไม่หมด → Gen1/Gen2/Gen3 จะไม่ recover

### 4) คง gate ใน `ManageHedgeSets()` แบบ strict เหมือนเดิม
ส่วนนี้แนวคิดถูกอยู่แล้ว:
```cpp
g_hedgeSets[h].boundGeneration != seqAllowedGen
```
แต่จะได้ผลถูกต้องเมื่อ `seqAllowedGen` ถูกคำนวณใหม่จาก lowest live GM generation จริง

### 5) ปรับ Dashboard ให้สะท้อนกติกาใหม่
เปลี่ยนจากข้อความแบบ:
```text
Allowed Hedge: Gen5 (GM_HEDGE_6)
```
เป็นข้อความที่สื่อว่า queue ตอนนี้อิง generation จริง เช่น:
```text
Seq Release | ON | Allowed Gen: Gen0 (GM) | Strict one-by-one
Seq Release | ON | Allowed Gen: Gen1 (GM1) | Strict one-by-one
```
เพื่อให้เห็นชัดว่า “ปลดตาม GM” ไม่ใช่ “ปลดตาม hedge ที่ยังค้าง”

### 6) Version bump
ตามกฎ version ของโปรเจกต์:
- bump จาก v6.62 → v6.63
- อัปเดตทุกจุด:
  - `#property version`
  - `#property description`
  - header comment
  - dashboard/version log

---

## Technical details
ลำดับการทำงานหลังแก้:
```text
1. OnTick -> scan live comments ทั้งหมด
2. หา generation ต่ำสุดที่ยังมี order ค้าง
3. ตั้ง g_seqAllowedGen = generation นั้น
4. ManageHedgeSets() ทำงานเฉพาะ set ที่ boundGeneration == g_seqAllowedGen
5. ManageOrphanGrid() ทำงานเฉพาะ orphan group ที่ generation == g_seqAllowedGen
6. เมื่อ generation นั้น flat ทั้งหมด -> tick ถัดไปเลื่อนไป generation ถัดไป
```

ตัวอย่าง:
```text
Live orders:
GM_INIT
GM1_INIT
GM1_GL#1
GM2_INIT
GM3_INIT
GM_HEDGE_6

Result:
Allowed = Gen0

After GM closes completely:
Allowed = Gen1

After GM1 closes completely:
Allowed = Gen2
```

---

## สิ่งที่ไม่เปลี่ยนแปลง
- ไม่แก้ Order Execution Logic (`OpenOrder`, `trade.Buy`, `trade.Sell`, `PositionClose`)
- ไม่แก้ Trading Strategy Logic
- ไม่แก้สัญญาณเข้า Buy/Sell
- ไม่แก้ Grid distance / lot calculation
- ไม่แก้ TP/SL / trailing / basket logic
- ไม่แก้ License / News / Time / Sync modules
- ไม่แก้ Hedge trigger conditions
- ไม่แก้ Matching-close formula นอกจากให้มันถูก gate ตาม generation ที่อนุญาตเท่านั้น
- ไม่แก้ Initial entry rule ของ cycle ใหม่ เว้นแต่ติด sequential recovery gate ฝั่ง recovery เท่านั้น

---

## ผลลัพธ์ที่คาดหวังหลังแก้
- ระบบจะปลดทีละ GM ตามลำดับจริง
- ไม่มี orphan หลาย generation วิ่งพร้อมกัน
- ไม่มีหลาย hedging set เข้า recovery พร้อมกัน
- DD hedge จะไม่หลุด queue
- dashboard จะอ่านสถานะได้ตรงกับพฤติกรรมจริงบน chart
