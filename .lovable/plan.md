
## v6.74 — ล็อกทั้ง Generation+Side หลัง Release เพื่อห้าม Hedge ซ้ำชุดเดิม

### ปัญหาที่แท้จริง
อาการที่คุณอธิบายยังเกิดได้แม้ v6.73 มี `prevHedged ticket` แล้ว เพราะตอนนี้โค้ดกันได้แค่ “ตั๋วเดิมที่เคยถูก bind แล้วถูกปล่อย” ไม่ให้ถูก bind ซ้ำ แต่ยัง **ไม่ได้กันทั้งชุดของ generation+side** ที่เคยปลด hedge ไปแล้ว

ผลคือหลังปลดล็อคครั้งแรก:
- ไม้เดิมบางใบของ GM1 ฝั่งเดิมยังค้างอยู่และยังปิดด้วย grid/TP ไม่ได้
- ถ้าระหว่างนั้นระบบเปิด GL/GP ใหม่เพิ่มใน **gen เดิม side เดิม**
- ไม้ใหม่เหล่านี้ยังไม่อยู่ใน `g_prevHedgedTickets`
- `CountUnboundOrders()` จึงยังนับได้ และ `CheckAndOpenHedge()/OpenDDHedge()` ยังเปิด hedge ใหม่ได้อีก
- เพราะ comment hedge ผูกกับ generation (`GM_Hedge_E1`, `GM_Hedge_D1`) เลยดูเหมือน “ชุดเดิมกลับมาอีก” ทั้งที่จริงคือระบบเปิด hedge ซ้ำใน **GM1 side เดิม** อีกรอบ

สรุป: bug นี้เป็น **gen-side level**, ไม่ใช่แค่ ticket level

ไฟล์ที่จะปรับ:
- `public/docs/mql5/Gold_Miner_EA.mq5`

### แผนแก้
#### 1) เพิ่มสถานะ “Released Hedge Lock” ระดับ Generation+Side
เพิ่ม registry ใหม่เก็บว่า
- generation ไหน
- side ไหน (`BUY`/`SELL`)
- ถูก release จาก hedge ไปแล้วหรือยัง

ตัวอย่าง:
- `GM1 BUY` เคย hedge แล้วถูก release → mark เป็น “ห้าม hedge ซ้ำ”
- หลังจากนั้นไม่ว่ามีไม้เก่า/ไม้ใหม่ของ `GM1 BUY` เพิ่มเข้ามา ก็ยัง **ห้าม hedge ซ้ำ**
- ต้องปล่อยให้ grid/avg TP/recovery เดิมแก้จน side นั้น flat เอง

#### 2) mark lock ทุกจุดที่ “set ถูกปล่อยกลับไป recovery”
ปัจจุบันมี `SaveBoundTicketsToPrevHedged(idx)` อยู่แล้วหลายจุด  
จะแยก/ขยายเป็น wrapper ที่ทำ 2 อย่างพร้อมกัน:
1. mark ตั๋วคงค้างเป็น `prevHedged`
2. mark `boundGeneration + counterSide` เป็น `releasedGenSideLocked`

ใส่ในทุก full-release path ที่มีอยู่แล้ว เช่น:
- external/manual hedge disappearance
- Avg TP release
- matching close release
- no-match release
- shred hedge full close
- grid recover full close / cleanup

หมายเหตุ:
- **ไม่ mark ตอน partial close ที่ set ยัง active อยู่**
- mark เฉพาะตอน “hedge set จบแล้ว และ bound orders ถูกปล่อยให้ไปแก้ต่อเอง”

#### 3) บล็อก hedge ใหม่ตั้งแต่ชั้นนับสิทธิ์เปิด
เพิ่ม helper เช่น:
- `IsReleasedGenSideBlocked(gen, side)`
- `CountLiveOrdersForGenSide(gen, side)`
- `PruneReleasedGenSideLocks()`

แล้วใส่ guard ใน `CountUnboundOrders(...)` ก่อนนับ lot:
```text
ถ้า genFilter >= 0 และ side นี้ของ gen นี้เคยถูก release แล้ว
=> return 0 ทันที
```

ผลลัพธ์:
- `CheckAndOpenHedge()` จะไม่เห็น lot ที่ hedge ได้
- `OpenDDHedge()` ก็จะไม่เห็น lot ที่ hedge ได้
- ไม่ต้องไปแก้ execution logic ของ `trade.Buy/Sell`
- บล็อกที่ระดับ “eligibility” ตามกฎ fix-only

เสริม log throttle:
```text
v6.74 RE-HEDGE BLOCKED: Gen1 BUY was already released once -> grid recovery only
```

#### 4) auto-clear lock เมื่อ gen-side นั้น flat จริง
lock นี้ไม่ควรค้างถาวร  
จะปลดเมื่อ:
- ฝั่งนั้นของ generation นั้นไม่มี normal/recovery order เหลือแล้ว
หรือ
- บัญชี flat ทั้งหมด / cycle reset

ดังนั้นหลัง `GM1 BUY` ปิดหมดจริง ระบบจึงค่อยอนุญาต flow ใหม่ตามปกติ

#### 5) คง `prevHedged ticket` ของเดิมไว้
ของเดิมยังมีประโยชน์อยู่:
- กันตั๋วเดิมไม่ให้ถูก bind ซ้ำ
- ส่วนของใหม่ที่ต้องเพิ่มคือ guard ระดับ **generation+side**
- ทั้งสองชั้นทำงานคู่กัน:
  - ticket guard = กันรายตั๋ว
  - gen-side lock = กันทั้งชุดเดิมไม่ให้ hedge ซ้ำอีกรอบ

#### 6) Dashboard / log
เพิ่มสถานะให้อ่านง่าย:
- `NoReHedgeLock: GM1 BUY`
- หรือจำนวน lock ที่ active เช่น `ReleasedLocks=1`

เพื่อให้เห็นชัดว่าเหตุใดระบบไม่เปิด hedge ใหม่ ทั้งที่ DD/expansion เข้าเงื่อนไขแล้ว

#### 7) Version bump
อัปเดตเป็น **v6.74** ทุกจุด:
- `#property version`
- `#property description`
- header comment block
- `OnInit/OnDeinit` prints
- dashboard header

### สิ่งที่ไม่เปลี่ยนแปลง
- ไม่แก้ `trade.Buy`, `trade.Sell`, `trade.PositionClose`, `trade.PositionClosePartial`, `OrderSend`
- ไม่แก้ logic กลยุทธ์เข้า Buy/Sell
- ไม่แก้ Grid Loss / Grid Profit เงื่อนไขเปิด
- ไม่แก้ TP/SL/Trailing/Breakeven formula
- ไม่แก้ DD threshold / Triple Gate / lot sizing / Matching budget
- ไม่แตะ License / News / Time filter / data sync
- แก้เฉพาะ “guard การอนุญาตเปิด hedge ซ้ำ” หลัง release เท่านั้น

### ผลลัพธ์ที่คาดหวัง
หลัง hedge ของ `GM1 BUY` ถูกปลดครั้งแรกแล้ว:
- แม้ราคาไปต่อทางเสีย
- แม้ระบบจะมี GL/GP ใหม่ใน `GM1 BUY`
- ระบบจะ **ไม่เปิด `GM_Hedge_E1` / `GM_Hedge_D1` ซ้ำอีก**
- จะปล่อยให้ฝั่งนั้นใช้ grid/recovery เดิมแก้ต่อจนจบ
- จึงไม่เกิดอาการ “ชุดเดิมโดน hedge ซ้ำแล้ว state เพี้ยน”

### ความเสี่ยง & Mitigation
- ความเสี่ยง: DD อาจยาวขึ้น เพราะ side ที่เคย release แล้วจะไม่ hedge ซ้ำ
- Mitigation: นี่เป็น behavior ที่คุณต้องการโดยตรง และ grid/avg TP/recovery เดิมยังทำงานครบ

- ความเสี่ยง: lock ค้างแม้ side นั้นปิดหมดแล้ว
- Mitigation: เพิ่ม prune/auto-clear ตาม `generation+side flat` และ clear ตอน cycle reset

- ความเสี่ยง: ยังเห็นว่าเป็น “ซ้ำชุดเดิม” จาก comment generation เดิม
- Mitigation: เมื่อ guard ใหม่นี้ทำงาน จะไม่มี hedge ใหม่ของ gen-side เดิมถูกเปิดขึ้นมาอีก จึงตัดปัญหาที่ต้นทาง

### Technical detail
แกนของ fix นี้คือเปลี่ยนจาก:
```text
"ห้าม hedge ซ้ำเฉพาะ ticket ที่เคยโดน bind"
```
เป็น:
```text
"เมื่อ gen-side นี้เคย hedge แล้วถูก release ไป recovery แล้ว
ห้าม hedge ซ้ำทั้ง gen-side นี้อีก
จนกว่าฝั่งนั้นของ gen นั้นจะ flat จริง"
```
