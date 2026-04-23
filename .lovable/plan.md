
## v6.76 — กัน “เปิด INIT ซ้ำ” หลังปลด hedge ของชุดเดิม แต่ยังมีออเดอร์ orphan/gen เก่าค้างอยู่

### อาการจากภาพล่าสุด
เคสที่คุณเจอรอบนี้คือ “ชุดที่ 2 กลับมารับออเดอร์ซ้ำอีก” ซึ่งจากภาพและ log มันชี้ไปที่อาการนี้ชัดมาก:

- มี `GM2_GL#6/#7/#8` ฝั่ง buy ค้างอยู่
- มี `GM_Hedge_D2` ของ Gen2 ยังอยู่/เพิ่งผ่าน flow มาก่อน
- จากนั้นระบบไปเปิด `GM3_INIT`, `GM3_GL#1`, `GM3_GL#2`
- แล้วต่อด้วย `GM_Hedge_D3`
- สุดท้ายยังเปิด `GM4_INIT` ซ้ำอีก

ใน log มีจุดสำคัญ:
```text
SELL cycle ended (broker SL). Resetting g_initialSellPrice.
GetHedgeLotCap: skip set#1 boundGen=3 != currentGen=4
v6.50 InstantTP: INIT order preTP=...
Order opened: GM4_INIT ...
```

สรุปคือระบบ “มองว่าฝั่ง sell ว่างแล้ว” เลยยอมเปิด INIT ของ generation ใหม่ ทั้งที่ในบัญชียังมี cycle เก่าและ hedge flow ของชุดก่อนค้างอยู่จริง

### Root cause
ปัญหาไม่ได้อยู่ที่ DD hedge trigger อย่างเดียวแล้ว แต่ไปอยู่ที่ “entry gating” ของ INIT ใหม่

ตอนนี้ logic เปิด INIT ใช้ข้อมูลจาก `CountPositions()` ซึ่งนับเฉพาะ:
- non-hedge
- non-bound
- และเฉพาะ `orderGen == g_cycleGeneration`

ผลข้างเคียงคือ:
- ถ้า Gen2/Gen3 ยังมีออเดอร์เก่าค้างอยู่ แต่ `g_cycleGeneration` ถูกดันไปเป็น Gen4 แล้ว
- `buyCount/sellCount` ของ current gen จะกลายเป็น 0
- `g_initialBuyPrice/g_initialSellPrice` ก็อาจถูก reset เป็น 0 ตาม broker SL / side-end logic
- entry block จึงคิดว่า “พร้อมเปิด INIT ใหม่” ทั้งที่จริงยังไม่ควรเปิด

ดังนั้นปัญหารอบนี้คือ:
- mutex กัน hedge ซ้อนบางส่วนแล้ว
- one-per-gen กัน hedge ซ้ำแล้ว
- แต่ **INIT entry ของ generation ใหม่ยังไม่มี guard กันการ re-entry ข้าม generation**

### สิ่งที่จะปรับ
ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1) เพิ่ม helper สำหรับเช็ค “ยังมีออเดอร์ปกติของ side นี้ค้างอยู่ไหม” แบบข้ามทุก generation
จะเพิ่ม helper ใหม่ เช่น:
- `HasAnyActiveNormalOrderOnSide(ENUM_POSITION_TYPE side)`
- หรือ `CountAllActiveNormalOrdersOnSide(...)`

นิยาม:
- นับเฉพาะออเดอร์ของ EA / symbol นี้
- ตัด hedge comments ออก
- ตัด bound tickets ออกตาม pattern เดิมของ normal-cycle
- แต่ **ไม่กรองด้วย `g_cycleGeneration`**

จุดประสงค์คือให้ entry logic รู้ว่า:
- แม้ current gen จะว่าง
- แต่ถ้ายังมี `GM2_*`, `GM3_*` ฝั่งเดียวกันค้างอยู่
- ห้ามเปิด `GM4_INIT` / `GM5_INIT` ซ้ำ

#### 2) เพิ่ม “cross-generation re-entry guard” ก่อนเปิด INIT
จะเสริม guard ในจุดเปิด INIT ของทั้ง:
- SMA mode
- Instant mode
- และถ้ามี branch อื่นที่เปิด INIT ตรงๆ จะผูกให้เหมือนกัน

แนวคิด:
```cpp
bool buySideHasLegacyOrders  = HasAnyActiveNormalOrderOnSide(POSITION_TYPE_BUY);
bool sellSideHasLegacyOrders = HasAnyActiveNormalOrderOnSide(POSITION_TYPE_SELL);
```

ก่อนเปิด BUY INIT:
- ต้องไม่มี order buy ปกติค้างอยู่เลย ไม่ว่าจะเป็น gen ไหน

ก่อนเปิด SELL INIT:
- ต้องไม่มี order sell ปกติค้างอยู่เลย ไม่ว่าจะเป็น gen ไหน

นี่จะบล็อกเคสแบบในภาพที่:
- ชุดเก่ายังมี `GM2_GL#...` หรือ `GM3_GL#...`
- แต่ระบบกลับเปิด `GM4_INIT`

#### 3) แยก helper “entry-safe” ออกจาก logic อื่น เพื่อลดผลกระทบ
จะไม่ไปแก้ `CountPositions()` เดิมตรงๆ เพราะมันถูกใช้กับหลายโมดูล และออกแบบมาให้ current-generation only โดยตั้งใจ

ดังนั้นจะใช้แนวทาง:
- คง `CountPositions()` ไว้เหมือนเดิม
- เพิ่ม helper ใหม่เฉพาะสำหรับ “ห้ามเปิด INIT ซ้ำข้าม generation”

วิธีนี้กระทบน้อยที่สุดและตรง bug ที่คุณแจ้ง

#### 4) เพิ่ม diagnostic log ให้เห็นเหตุผลที่โดน block
เพิ่ม log แบบ throttle เช่น:
```text
v6.76 INIT BLOCKED: SELL re-entry denied — legacy normal orders still active on older generation
v6.76 INIT BLOCKED: BUY re-entry denied — found open normal orders from Gen2/Gen3
```

เพื่อให้ trace ได้ชัดในรอบต่อไปว่า:
- ไม่ได้ติด signal
- ไม่ได้ติด news
- แต่ติด guard “ยังมีชุดเดิมค้างอยู่”

#### 5) เพิ่ม dashboard row สั้นๆ สำหรับดูสถานะ re-entry guard
เช่น:
- `ReEntryGuard: BUY legacy=1 | SELL legacy=0`
หรือ
- `LegacySideLock: B=ON S=OFF`

เพื่อให้ดูบน chart ได้ทันทีว่าทำไม INIT ใหม่ไม่ออก

#### 6) bump version เป็น v6.76
อัปเดตทุกจุดตามกฎไฟล์ `.mq5`:
- `#property version`
- `#property description`
- header comment block
- init/deinit print
- dashboard version text

### สิ่งที่ไม่เปลี่ยนแปลง
ตามกฎเหล็ก MQL5 ของโปรเจกต์ จะไม่แตะส่วนเหล่านี้:
- ไม่แก้ Order Execution Logic (`trade.Buy`, `trade.Sell`, `PositionClose`, `OrderSend`)
- ไม่แก้ Trading Strategy Logic
- ไม่แก้ signal SMA / ZigZag / Entry direction
- ไม่แก้ Grid entry/exit สูตรเดิม
- ไม่แก้ TP/SL/Trailing/Breakeven calculations
- ไม่แก้ DD threshold calculation
- ไม่แก้ hedge lot sizing
- ไม่แก้ orphan auto-heal v6.73
- ไม่แก้ one-per-gen v6.72
- ไม่แก้ current-gen mutex exception v6.75
- ไม่แก้ news/license/data sync core logic

### ผลที่คาดหวัง
หลังแก้ v6.76:
- ถ้ายังมี `GM2_*` / `GM3_*` ฝั่งเดิมค้างอยู่ ระบบจะไม่เปิด `GM4_INIT` ซ้ำ
- จะหยุดอาการ “ชุดที่ 2 ตัวเดิมกลับมารับออเดอร์ซ้ำ”
- hedge เดิมยังทำงานตาม flow ปกติ
- DD hedge ของ current gen ยังออกได้เมื่อถึงเกณฑ์เหมือน v6.75
- ระบบจะเริ่ม generation ใหม่ได้ก็ต่อเมื่อ side นั้นไม่มี normal orders เก่าค้างจริง

### ความเสี่ยงและการกันผลข้างเคียง
- Risk: block เข้มเกินไปจน user อยากให้เปิด cycle ใหม่ทั้งที่ยังมี orphan เก่า  
  Mitigation: ใช้ guard เฉพาะ INIT entry เท่านั้น ไม่ไป block grid/recovery/hedge flow อื่น

- Risk: ถ้า `bound` tickets ควรถูก ignore แต่ helper ไปนับรวม  
  Mitigation: helper จะยึด pattern เดิมของ normal-cycle และตัด hedge/bound ออกเหมือน `CountPositions()`

- Risk: current generation ว่างจริง แต่มี older-gen ค้างเพียงอีกฝั่งหนึ่ง  
  Mitigation: block แยกเป็นราย side เท่านั้น BUY ดู BUY, SELL ดู SELL ไม่ปิดทั้งระบบ

- Risk: log/dashboard noisy  
  Mitigation: ใช้ throttled logs และ dashboard row แบบสั้น
