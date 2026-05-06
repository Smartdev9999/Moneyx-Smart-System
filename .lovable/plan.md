Do I know what the issue is? Yes.

ปัญหาหลักไม่ได้อยู่ที่การคำนวณ TP โดยตรง แต่เกิดจาก Hero cache ปัจจุบัน “rebuild ใหม่ทุก tick” จากออเดอร์ที่ยังเปิดอยู่ ทำให้เมื่อ Hero/Candidate ฝั่ง BUY ถูกปิดบางส่วนหรือปิดหมดด้วย SL/TP/broker/manual ก่อนที่ฝั่ง SELL จะชน TP ระบบไม่จำว่า BUY เคยถูกกันเป็น Hero แล้ว และสามารถเลือกออเดอร์ BUY ชุดใหม่มาเป็น Hero ซ้ำได้อีกครั้ง

นอกจากนี้ v1.46 stamp `g_heroLastClosedSide` เฉพาะตอน `CloseHeroOnSide()` เท่านั้น ถ้า Hero ถูกปิดด้วยทางอื่น เช่น broker SL/TP หรือ candidate SL โดนก่อน ระบบอาจไม่ stamp ฝั่งที่เพิ่งปิด Hero จึงยัง re-arm ฝั่งเดิมได้

## แผนแก้ v1.47 — Strict Hero Ticket Ownership + No Same-Side Re-arm

### 1. ทำ Hero ticket ให้เป็น “ชุดที่ล็อคแล้ว” ไม่ใช่เลือกใหม่ทุก tick
เพิ่ม state แยกฝั่งเพื่อจำ ticket ที่ถูก tag เป็น Hero/Candidate ตั้งแต่แรก เช่น
- `g_heroBuyTickets[]`, `g_heroBuyTicketCount`
- `g_heroSellTickets[]`, `g_heroSellTicketCount`

หลักการใหม่:
```text
phase == NONE:
  ถ้าผ่าน threshold และไม่ติด alternation guard -> เลือก Hero candidates ครั้งเดียว แล้วจำ ticket ชุดนั้น

phase == ARMED/BE_GUARD:
  ห้าม top-up / ห้ามเลือก ticket ใหม่แทนตัวที่ปิดไป
  ใช้เฉพาะ ticket ชุดเดิมที่ยังรอดอยู่เท่านั้น
```

ผลลัพธ์:
- ถ้า Hero BUY ปิดไปบาง ticket -> BUY จะเหลือ Hero เท่าที่รอด ไม่ดึง BUY ticket ใหม่มาแทน
- ถ้า Hero BUY ปิดหมด -> BUY phase reset + stamp ว่า BUY เพิ่งปิด Hero แล้ว
- BUY จะไม่ออก Hero ซ้ำจนกว่า SELL จะได้เป็น Hero candidate/owner หรือ BUY flat สนิท

### 2. ขยาย Alternation Guard ให้ครอบคลุม broker/manual/SL/TP close
แก้ logic ใน `BuildHeroTicketCache()`:
- ถ้า side มี `phase > 0` แต่ stable Hero ticket ของฝั่งนั้นเหลือ 0:
  - reset phase ฝั่งนั้นเป็น NONE
  - clear BE flag
  - stamp `g_heroJustClosed_<side>`
  - stamp `g_heroLastClosedSide = side`
  - ไม่เลือก ticket ใหม่ใน tick เดียวกัน
- ถ้า `g_heroLastClosedSide == side` และฝั่งตรงข้ามยังไม่ ARMED/BE_GUARD และ side เดิมยังไม่ flat:
  - block side เดิมจากการ tag Hero ใหม่

### 3. เพิ่ม guard ใน `OnTradeTransaction()` เพื่อจับ Hero close ทันที
เพิ่มเฉพาะ state detection ไม่เปลี่ยน order execution:
- เมื่อมี closed deal (`DEAL_ENTRY_OUT/INOUT/OUT_BY`)
- ตรวจว่า position ที่ปิดตรงกับ stable Hero ticket ฝั่งไหนหรือไม่
- ถ้าใช่ ให้ prune ticket และถ้า Hero ฝั่งนั้นหมด ให้ stamp `g_heroLastClosedSide`

ตัวนี้ช่วยกรณีที่ broker ปิด Hero ด้วย SL/TP ก่อน `BuildHeroTicketCache()` รอบถัดไป

### 4. บังคับ “มี Hero owner ได้ฝั่งเดียวจริงๆ” หลัง BE_GUARD
คงกติกาเดิม:
- ARMED = candidate ยังไม่ใช่ owner
- owner เกิดเมื่อ non-Hero basket ฝั่งเดียวกันปิดหมด (`BE_GUARD`)

แต่เมื่อฝั่งใดฝั่งหนึ่งเข้า `BE_GUARD` แล้ว:
- clear candidate ฝั่งตรงข้ามที่ยังเป็น ARMED อยู่
- restore ให้ฝั่งตรงข้ามกลับเป็น normal order set ที่สามารถเข้า Average TP ตามระบบปกติใน tick ถัดไป
- ไม่ปิดออเดอร์ฝั่งตรงข้าม และไม่แก้สูตร TP/SL

### 5. Align เส้น Average/TP บนชาร์ตให้ไม่รวม Hero/Candidate
Trading TP จริง (`ManageTakeProfit`) ใช้ `CalcSideAvgPrice_NonHero()` อยู่แล้ว แต่เส้นบนชาร์ตตอนนี้ยังใช้ `CalcSideAvgPrice()` ที่รวม Hero ด้วย

จะแก้เฉพาะ display line:
- `DrawAvgAndTPLines()` ใช้ `CalcSideAvgPrice_NonHero()`
- เพื่อให้เส้น Average/TP ที่เห็นบนชาร์ตตรงกับ logic ที่ไม่เอา Hero/Candidate ไปคำนวณ

ไม่กระทบการเปิด/ปิดออเดอร์

### 6. Dashboard + audit log
เพิ่มข้อมูลช่วย debug:
- `Last Closed: BUY/SELL/-`
- `Stable BUY/SELL hero tickets`
- log เมื่อ block re-arm ฝั่งเดิม เช่น
```text
v1.47 Hero ALT-BLOCK BUY: lastClosed=BUY, waiting SELL hero or BUY flat
v1.47 Hero TICKET-SET LOST BUY: all stable hero tickets closed externally -> lock same side
```

### 7. Version + memory
อัปเดตทุกจุดตามกฎ version:
- header comment: v1.47
- `#property version "1.47"`
- `#property description`
- OnInit/OnDeinit logs
- Dashboard title/version
- สร้าง memory ใหม่ `golden-kuy3/v1-47-strict-hero-ticket-ownership`
- อัปเดต plan/memory index

## สิ่งที่ไม่เปลี่ยนแปลง
- ไม่แก้ `OrderSend`, `trade.Buy`, `trade.Sell`
- ไม่แก้บรรทัด `trade.PositionClose()` หรือพฤติกรรมการปิดออเดอร์เดิม
- ไม่แก้สูตร Grid entry / lot / distance / candle condition
- ไม่แก้สูตร Per-order BE/Trailing
- ไม่แก้สูตร Average Trailing strict-2-cross
- ไม่แก้ TP mode / Accumulate Close / Cost-Hit Restart
- ไม่แก้ `ComputeHeroLockProfitSL()` หรือ `ApplyHeroLockProfitSL()`
- ไม่แก้หลักการ v1.44: Candidate ถอดเฉพาะ TP และคง SL เดิมไว้
- ไม่แก้หลักการ v1.45: ARMED เป็นแค่ Candidate, BE_GUARD เท่านั้นคือ Owner
- ถ้า `InpHero_Enabled=false` พฤติกรรมเดิมเหมือนเดิม

## หมายเหตุจากภาพ Invalid Stops
ภาพมี log `Invalid stops` จากการ modify TP ฝั่ง SELL ด้วย ราคาที่ broker มองว่า TP ไม่ valid แล้ว กรณีนี้อาจเป็นอีกประเด็นของ TP broker-sync แยกจาก Hero alternation ผมจะยังไม่แตะ execution/TP-close logic ในรอบ v1.47 นี้ เพื่อไม่กระทบ trading logic ตามกฎเหล็ก เว้นแต่คุณสั่งให้แก้ส่วนนั้นแยกต่างหาก