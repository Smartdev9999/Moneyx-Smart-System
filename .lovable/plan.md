
## v6.69 — เพิ่ม Sequential Unlock Delay แบบกำหนดได้ เพื่อกันปลดล็อคชุดถัดไปเร็วเกินไป

### ปัญหาที่ต้องแก้
จากอาการที่คุณเจอ ตอนชุดแรกปิดหมดแล้ว ชุดถัดไปถูกปลดล็อคเร็วมากจนเหมือนระบบคำนวณ state/owner/handoff ยังไม่ทัน ทำให้บางครั้งเห็นการปลดชุดที่ 2 และ 3 ติดกันเกินไป แม้ v6.68 จะกัน “หลายชุดใน tick เดียว” แล้ว แต่ตอนนี้ยังเหลือช่องโหว่แบบ “tick ถัดไปมาเร็วมาก” จนพฤติกรรมยังดูเหมือนปลดพร้อมกัน

จากโค้ดปัจจุบัน:
- `sequentialActed` บังคับได้แค่ “1 ชุดต่อ tick”
- `g_sequentialRecoveryCompletedThisTick` กันได้แค่ “1 tick หลัง owner flat”
- แต่ไม่มี **time-based delay** ระหว่าง set ก่อนหน้าที่เพิ่งปิด กับ set ถัดไปที่จะเริ่ม unlock/recovery

### แนวทางแก้
จะเพิ่ม “ตัวหน่วงเวลาเฉพาะการปลดล็อคชุดถัดไป” แบบตั้งค่าได้เป็นนาที เช่น 1 หรือ 2 นาที โดยเป็น **time-based guard** ไม่ใช่ `Sleep(60000)` เพราะการใช้ `Sleep` นานๆ จะค้าง EA ทั้งตัวและไม่ปลอดภัย

## แผนแก้ v6.69 (Fix-only)

ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

### 1) เพิ่ม Input ใหม่สำหรับหน่วงการ unlock
เพิ่มในกลุ่ม `=== Sequential Hedge Recovery ===`

```cpp
input int InpHedge_SequentialUnlockDelayMin = 1; // Delay before next hedge set unlock after previous set/owner completes (minutes, 0=Off)
```

พฤติกรรม:
- `0` = ปิดระบบ delay ใช้พฤติกรรมเดิม
- `1` = รอ 1 นาที
- `2` = รอ 2 นาที
- ใช้กับ “ชุดถัดไป” เท่านั้น ไม่ไปแช่/block EA ทั้งระบบ

### 2) เพิ่ม state + helper สำหรับ cooldown การปลดล็อค
เพิ่ม global state เช่น:
- `datetime g_sequentialUnlockBlockedUntil = 0;`
- optional debug fields เช่นเหตุผล/ชุดต้นทาง

เพิ่ม helper:
- `ArmSequentialUnlockDelay(...)`
- `IsSequentialUnlockDelayActive()`
- `GetSequentialUnlockRemainSec()`

หน้าที่:
- เมื่อ set ใด set หนึ่ง “ปิด/ปล่อย bound/release จบ” ให้เริ่มจับเวลา block การปลด set ถัดไป
- เมื่อ owner generation flat แล้ว queue จะไม่ปล่อยชุดใหม่ทันที แต่จะรอตาม delay นี้ก่อน

### 3) บังคับ delay ใน `ManageHedgeSets()`
แก้ที่ loop หลักของ `ManageHedgeSets()` ให้ตรวจ delay ก่อนเข้า logic:
- oldest-set sequential path
- profit-bypass path
- matching/release ของ set ถัดไป

หลักการ:
- ถ้ายังอยู่ในช่วง cooldown → set ที่รออยู่ทั้งหมดต้อง `continue`
- reset `matchingDone = false` เพื่อให้เมื่อครบเวลาแล้วคำนวณใหม่บน state ล่าสุด
- ดังนั้นแม้ตลาดวิ่งเร็วมาก ก็จะไม่ปลด set ใหม่ทันทีหลัง set ก่อนหน้าเพิ่งหาย

### 4) Arm delay ใน “ทุกจุดที่ปิด hedge set / handoff queue”
ตอนนี้มีหลายทางที่ set ถูกปิดหรือ release เช่น:
- external close path
- AvgTP release
- matching close
- release close
- shred hedge full
- grid cleanup / cleanup path
- owner clear path

จะรวมให้ทุก path ใช้ helper เดียวกัน เพื่อไม่ให้มีบางเส้นทางลืมเริ่ม delay

จุดสำคัญ:
- หลัง `SetSequentialRecoveryOwner(...)` จะมี delay สำหรับ set ถัดไป
- หลัง `ClearSequentialRecoveryOwner(...)` จะเปลี่ยนจาก “unlock next tick” เป็น “unlock หลังครบ N นาที”
- `g_sequentialRecoveryCompletedThisTick` จะยังคงไว้เป็น guard ระดับ tick แต่เสริม time-based delay ทับอีกชั้น

### 5) Dashboard / Log ให้เห็นเวลารอจริง
ปรับแถว `Hedge Recovery` ให้เห็นสถานะชัดขึ้น เช่น:
- `Sequential | Cooldown: 1m32s | Next Unlock: H2 | Wait: 2 set(s)`
- หรือถ้า owner flat แล้วกำลังรอ delay:
  `Sequential | Owner cleared | Cooldown: 0m58s`

เพิ่ม log ประเภท:
- `v6.69 SEQ DELAY ARM: ...`
- `v6.69 SEQ DELAY HOLD: Set#... deferred, remain XX sec`
เพื่อ debug ได้ว่าระบบตั้งเวลารอเมื่อไร และกำลัง hold ชุดไหนอยู่

### 6) Version bump → v6.69
อัปเดตทุกจุดของเวอร์ชันตามกฎ:
- `#property version "6.69"`
- `#property description`
- Header comment block
- Dashboard display บนชาร์ต

## สิ่งที่ไม่เปลี่ยนแปลง
ยืนยันว่าเป็นการแก้แบบ fix-only และ **ไม่กระทบ trading logic หลัก**
- ไม่แก้ `trade.Buy / trade.Sell / trade.PositionClose / OpenOrder`
- ไม่แก้ signal strategy
- ไม่แก้ grid entry/exit logic
- ไม่แก้ TP/SL/Trailing/Breakeven
- ไม่แก้ Triple Gate (`IsHedgeCloseAllowed`)
- ไม่แก้ Match-Close pool (v6.61)
- ไม่แก้ Sequential Recovery Owner core concept
- ไม่แก้ DD hedge trigger/opening logic
- ไม่แก้ generation recycle logic
- ไม่แก้ News / Time Filter / License / Data Sync

## ผลลัพธ์ที่คาดหวัง
1. หลัง Hedge#1 ปิดหมด จะ **ไม่ปล่อย Hedge#2 ทันที**
2. ระบบจะรอเวลาตามที่ตั้ง เช่น 1–2 นาที ก่อนเริ่มปลดชุดถัดไป
3. Hedge#2 และ Hedge#3 จะไม่ดูเหมือนปลดติดกันเร็วเกินไปอีก
4. profit-bypass จะยังทำงาน แต่ต้องเคารพ delay ใหม่ด้วย
5. ระบบมีเวลา “settle state” หลังการปิด set ก่อนคำนวณคิวชุดถัดไป

## รายละเอียดเทคนิค
แนวแก้จะใช้ **timestamp guard** ไม่ใช้ `Sleep` ระดับนาที เพราะ:
- `Sleep` นานจะค้าง EA
- เสี่ยงพลาด event / dashboard / management อื่น
- time-based cooldown ปลอดภัยกว่าและควบคุมได้ละเอียดกว่า

ลำดับใหม่โดยสรุป:
```text
Set A close/release
-> arm sequential unlock delay (N min)
-> during cooldown: block all next hedge-set recovery/unlock
-> cooldown expires
-> allow oldest waiting set only
-> if that set closes too, arm delay again
```

## ความเสี่ยงและ Mitigation
- Risk: ถ้าตั้ง delay นานเกินไป การลด exposure ของชุดถัดไปจะช้าลง
- Mitigation: ทำเป็น input ปรับได้ (`0=Off`, `1`, `2` นาทีตามต้องการ)

- Risk: บาง path ของการปิด set อาจลืม arm delay
- Mitigation: รวมการเริ่ม cooldown เข้า helper กลาง แล้วเรียกจากทุก release/cleanup path

- Risk: Dashboard เดิมแสดงแค่ `1/tick` อาจทำให้สับสน
- Mitigation: เปลี่ยนให้แสดง countdown จริงของ cooldown
