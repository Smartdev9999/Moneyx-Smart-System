
สาเหตุที่เจอจากโค้ดตอนนี้ชัดเจนแล้ว: `SaveBoundTicketsToPrevHedged(idx)` ถูกเรียกถูกที่ก่อน clear bound tickets แต่ทันทีหลัง deactivation ของ set เดียวสุดท้าย โค้ดกลับ `g_cycleGeneration = 0` และ `ClearPrevHedgedTickets()` ทันทีที่ `g_hedgeSetCount <= 0` แม้ยังมีออเดอร์ released ค้างอยู่ จึงทำให้ DD checker กลับมามองออเดอร์เดิมและเปิด Hedge รอบ 2 ใน chain เดิมได้อีกครั้ง

## v6.27 — แก้ cycle reset เร็วเกินไปหลัง Matching Close

### แนวทางแก้
เปลี่ยนจาก “reset เมื่อไม่มี active hedge set” เป็น “reset เมื่อไม่มี EA positions ค้างแล้วจริง ๆ” เพื่อให้ released/bound chain เดิมยังถูกกัน DD re-trigger ต่อไปจนกว่าจะ flat/reset จริง

### แผนแก้ไข
1. เพิ่ม minor version เป็น `v6.27`
- อัปเดต `#property version`
- อัปเดต `#property description`
- อัปเดต header comment block
- อัปเดต dashboard/version display

2. สร้าง helper กลางสำหรับ reset cycle แบบปลอดภัย
- เช่น `TryResetCycleStateIfFlat(reason)` หรือชื่อใกล้เคียง
- เช็คจาก `TotalOrderCount()` / สถานะ positions ของ EA ก่อน reset
- ทำ reset เฉพาะเมื่อ “ไม่มี position ค้างแล้วจริง ๆ” เท่านั้น
- ภายใน helper ค่อยทำ:
  - `g_cycleGeneration = 0`
  - `g_hedgeSetCount = 0`
  - `ClearPrevHedgedTickets()`

3. แก้ deactivation points ทั้ง 7 จุด
- แทน block เดิมที่ reset ทันทีเมื่อ `g_hedgeSetCount <= 0`
- ให้เหลือแค่:
  - ปิด set
  - `SaveBoundTicketsToPrevHedged(idx)`
  - ลด `g_hedgeSetCount`
  - เรียก helper reset แบบ “reset only if flat”
- จุดสำคัญคือ matching close / release close / batch close / grid recover / grid cleanup จะไม่ล้าง `prevHedged` ถ้ายังมีออเดอร์ released ค้างอยู่

4. คง logic `SaveBoundTicketsToPrevHedged(idx)` ไว้ แต่ไม่ให้โดนลบทันที
- กลไก skip ใน `CheckAndOpenHedgeByDD()` ใช้ของเดิมต่อ:
```text
if(IsPrevHedgedTicket(ticket)) continue;
```
- ผลลัพธ์คือ order เดิมใน bound chain จะไม่ถูกใช้ trigger DD hedge ซ้ำหลัง matching close

5. คง reset paths ที่ “flat จริง” ไว้
- all positions cleared
- accumulate reset
- ZZ accumulate reset
- full close/reset flow
จุดเหล่านี้ยังเป็นที่ถูกต้องสำหรับการ clear `prevHedged` และ reset generation

### ผลลัพธ์ที่คาดหวัง
```text
Matching Close
-> Hedge set ปิด
-> released orders ยังเปิดค้าง
-> prevHedged ยังอยู่
-> cycleGeneration ยังไม่ reset
-> DD checker ไม่หยิบ order chain เดิมไปเปิด Hedge รอบ 2
-> ระบบปล่อยให้ recovery ต่อด้วย grid/order flow เดิม
-> reset จริงเมื่อ flat ทั้งหมดเท่านั้น
```

### Technical details
- แก้เฉพาะ lifecycle/reset guard ของ hedge set
- ไม่แตะ `trade.Buy / trade.Sell / PositionClose`
- ไม่เปลี่ยน DD threshold logic (% / $)
- ไม่เปลี่ยน matching formula
- ไม่เปลี่ยน grid spacing / lot progression
- ไม่เปลี่ยน generation-aware isolation หลัก เพียงแก้ timing ของการ reset generation ให้ถูกจังหวะ

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic
- Trading Strategy Logic
- Core Module Logic
- Triple-gate exit logic
- Matching close calculation
- Hedging grid / bound grid calculation
- OpenDDHedge / binding logic หลัก
- ระบบ generation-aware isolation หลัก
