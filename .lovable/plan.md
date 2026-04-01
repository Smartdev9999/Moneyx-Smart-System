
## v6.23 — แก้ order หายหลัง H1/H2: lot-cap และ helper หลายจุดยังไม่ Generation-Aware

### สิ่งที่ตรวจพบแบบละเอียด
อาการที่คุณเจอ “หลัง H1/H2 แล้วฝั่งใหม่ไม่ออกต่อ หรือสุดท้ายไม่มี order เลย” ไม่ได้มาจาก DD trigger อย่างเดียวแล้ว แต่มี 2 กลุ่มปัญหาซ้อนกัน:

1. `OpenOrder()` ยังใช้ `GetHedgeLotCap()` แบบนับทุก active hedge set ของ side นั้น  
   - ตอนนี้ lot cap ไม่ได้ filter ตาม `g_cycleGeneration`
   - หลัง H1 เปิด ชุด H1 จะยังไปจำกัด order ฝั่ง counter-side ของรอบใหม่
   - หลัง H2 เปิด จะมี cap คนละฝั่งจากคนละ set → สุดท้ายทั้ง BUY และ SELL มีโอกาสโดน block พร้อมกัน

2. helper หลายตัวที่ใช้หา “order ล่าสุด / lot ล่าสุด / initial state” ยังมองข้าม generation
   - `FindLastOrder()`
   - `FindMaxLotOnSide()`
   - `RecoverInitialPrices()`
   - ฝั่ง ZigZag TF:
     - `CountPositionsTF()`
     - `FindLastOrderTF()`
     - `RecoverTFInitialPrices()`
   ผลคือแม้ entry count จะแยก gen แล้ว แต่บางจุดยังอ้างอิง order เก่าคนละ generation ทำให้ grid/initial state เพี้ยน และอาจทำให้ระบบเหมือน “ไม่กล้าออก order ใหม่”

### Root cause หลัก
ตอนนี้ v6.22 แก้ “การนับจำนวน order เพื่อเข้าใหม่” แล้ว แต่ยังไม่ได้แก้ “การจำกัด lot / การหา state อ้างอิง” ให้แยก generation ตามไปด้วย

ภาพรวมตอนนี้เลยเป็นแบบนี้:
```text
CountPositions / NormalOrderCount = current gen only  ✓
GetHedgeLotCap / FindLastOrder / FindMaxLotOnSide = all gens mixed  ✗
```

นี่คือเหตุผลที่อาการดู “แปลกกว่าเดิม”:
- บางฝั่ง count บอกว่าเปิดได้
- แต่ตอนจะเปิดจริง `OpenOrder()` ไปโดน lot-cap จาก hedge set เก่า
- หรือ grid logic ไปอ้างอิง last order / max lot ของ generation เก่า
- สุดท้ายเห็นว่าระบบไม่เดินต่อ หรือเดินข้างเดียว

### แผนแก้ไข
**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1) ทำ `GetHedgeLotCap()` ให้ generation-aware
เปลี่ยนให้ cap เฉพาะกรณีที่ hedge set นั้นผูกกับ generation ปัจจุบันจริงเท่านั้น  
แนวทาง:
- ตรวจ `g_hedgeSets[h].boundGeneration`
- หรือเทียบกับ generation ของชุดที่ควรคุม current cycle
- ข้าม hedge set เก่าที่เป็นคนละ generation

เป้าหมาย:
- หลัง H1 เปิด ชุดใหม่ยังออกต่อได้
- หลัง H2 เปิด ชุดก่อนหน้าไม่มาล็อครอบใหม่ผิดๆ
- ไม่ทำให้ทั้ง 2 ฝั่งโดน cap พร้อมกันโดยไม่ตั้งใจ

#### 2) ทำ helper ฝั่ง main cycle ให้ generation-aware
เพิ่ม filter `ExtractGeneration(comment) == g_cycleGeneration` ใน:
- `FindLastOrder()`
- `FindMaxLotOnSide()`
- `RecoverInitialPrices()`

ผล:
- grid loss / grid profit ของรอบใหม่จะอิง order ของรอบใหม่จริง
- ไม่ไปดึง lot/price ของ GM หรือ GM1 มาใช้ตอนอยู่ GM2

#### 3) ทำ helper ฝั่ง ZigZag TF ให้ generation-aware ด้วย
เพิ่ม filter เดียวกันใน:
- `CountPositionsTF()`
- `FindLastOrderTF()`
- `RecoverTFInitialPrices()`

เพราะตอนนี้ TF path ยังนับ/หา order จากทุก generation อยู่ ซึ่งอาจทำให้ TF side ถูกมองว่ายังมี cycle ค้าง ทั้งที่ current gen ไม่มีแล้ว

#### 4) เพิ่ม log debug ให้เห็นสาเหตุการ block ชัดขึ้น
เพิ่ม log เฉพาะจุดที่ปลอดภัย เช่น:
- ตอน `GetHedgeLotCap()` คืนค่า cap
- ตอน entry ไม่ผ่านเพราะ `g_initialBuyPrice/g_initialSellPrice`
- ตอน helper เจอแต่ order เก่าคนละ generation

เพื่อให้รอบถัดไป trace ง่ายว่า blocked เพราะ:
- squeeze block
- max orders
- lot cap
- initial price ค้าง
- current gen ไม่มี reference order

#### 5) bump version เป็น v6.23
อัปเดตทุกจุดตามกฎ:
- `#property version`
- `#property description`
- header comment block
- dashboard version
- init/deinit log

### Technical details
```text
ปัญหาหลักรอบนี้ไม่ใช่ “entry condition” อย่างเดียว
แต่เป็น “post-entry guards / state reference” ที่ยังข้าม generation

Flow ที่ควรเป็น:
H1 เปิด -> bind gen0 -> cycle ไป gen1 -> gen1 เปิด order ใหม่ได้
H2 เปิด -> bind gen1 -> cycle ไป gen2 -> gen2 เปิด order ใหม่ได้

แต่ตอนนี้เกิด:
gen2 count = 0 ✓
แต่ OpenOrder() ยังโดน cap จาก hedge set เก่า ✗
หรือ FindLastOrder / FindMaxLotOnSide ยังดึง GM/GM1 มาอ้างอิง ✗
```

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (`trade.Buy`, `trade.Sell`, `trade.PositionClose`) ไม่แก้
- Trading Strategy Logic หลัก (SMA/ZigZag signal, entry direction, Grid entry/exit, TP/SL, trailing, breakeven, accumulate close) ไม่แก้
- Core Module Logic (License, News filter, Time filter, Data sync) ไม่แก้
- DD trigger threshold แบบคงที่ต่อ generation (v6.21) ไม่แก้
- Triple-gate hedge recovery (Expansion + Zone + TP Distance) ไม่แก้
- แนวคิด generation-aware isolation เดิมไม่เปลี่ยน แค่ทำให้ครบทุก helper ที่ยังรั่วอยู่

### ผลลัพธ์ที่คาดหวังหลังแก้
- หลัง H1 ฝั่งตรงข้ามยังเปิด cycle ใหม่ได้ตามปกติ
- หลัง H2 ระบบจะยัง standby รอ H3 ได้จริง พร้อมเปิด order ใหม่ของ current generation
- ไม่เกิดอาการ “มีแต่ฝั่งเดียว”, “ไม่มี order ต่อเลย”, หรือ “count ดูเปิดได้แต่เปิดจริงไม่ได้” จาก state ของ generation เก่า
