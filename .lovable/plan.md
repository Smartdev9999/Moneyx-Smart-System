
## v6.74 — กัน “Recovery Grid + DD Hedge ซ้อนในเจนเดียวกัน” หลังปลด/เคลียร์ชุดเดิม

### ปัญหาที่เกิดขึ้นจาก log + รูป
จากภาพและ log ล่าสุด เหตุการณ์เป็นลำดับนี้:

1. `GM2_GL#8` ถูกเปิดเพิ่มก่อน
2. จากนั้นมี `GM2_GL#1` ฝั่ง sell ถูกเปิดเป็น recovery/orphan grid
3. ต่อมามีการปิดบางไม้ของชุดเดิม
4. สุดท้ายระบบเปิด `GM_Hedge_D2` ขึ้นมาอีก

ผลคือ **generation 2 โดนทั้ง recovery grid และ DD hedge พร้อมกัน** ซึ่งเป็นพฤติกรรมที่ user บอกว่า “สิ่งที่ใส่ไปยังแก้ไม่หาย”

### Root cause ที่ชัดเจน
ปัญหาไม่ได้อยู่ที่ guard `OnePerGenSide` อย่างเดียว แต่เกิดจาก “ช่องว่างของสถานะ generation” ดังนี้:

#### A. `ManageOrphanGrid()` ยังเปิดไม้ recovery ของ Gen2 ได้
ใน log มี:
- `v6.64 RECOV TP RECALC: Gen2 ...`
- `v6.71 GRID NEXT-LEVEL ... comment=GM2_GL#8`
- ต่อด้วย `v6.71 GRID NEXT-LEVEL ... comment=GM2_GL#1`
- และมี `ORPHAN SCAN: No orphan generations found.` อยู่ใกล้กัน

แปลว่า order ของ Gen2 ถูกมองเป็น “owner/recovery basket” และยังถูก feed ผ่าน recovery path ได้ แม้กำลังอยู่ในช่วงเปลี่ยนผ่านหลัง hedge/release

#### B. `CheckAndOpenHedgeByDD()` คำนวณ DD ของ `g_cycleGeneration` จาก order ที่ “ไม่ bound แล้ว”
โค้ดปัจจุบันนับ DD จาก:
- ไม่ใช่ hedge
- ไม่ใช่ bound
- ไม่ใช่ prevHedged
- `orderGen == curGen`

ดังนั้นถ้า order ของ Gen2 หลุดมาเป็น unbound/recovery owner แล้ว แต่ยังอยู่ generation เดิม ระบบ DD hedge ยังเห็นพวกนี้เป็น candidate สำหรับ hedge ได้อีก

#### C. ระบบยังไม่มี “generation-level mutual exclusion”
ตอนนี้มีแค่:
- ห้าม hedge ซ้ำถ้ายังมี active hedge set เดิม (`HasActiveHedgeForGenSide`)
- cooldown หลังปิด hedge (`g_lastHedgeCloseTime`)
- prevHedged lock เฉพาะ ticket เดิม

แต่ยัง **ไม่มี guard ว่า**
- ถ้า generation นี้กำลังอยู่ใน recovery owner flow / orphan recovery flow
- ห้ามเปิด DD hedge ใหม่สำหรับ generation เดียวกัน
- และในทางกลับกัน ถ้า generation นี้ยังมี/เพิ่งมี DD hedge set
- ห้าม recovery grid ของ generation เดียวกันวิ่งแทรก

นี่คือสาเหตุที่ทำให้เกิด “GM2_GL เพิ่ม แล้ว GM_Hedge_D2 ซ้ำ”

---

## แผนแก้

ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

### 1) เพิ่ม helper ระดับ generation เพื่อกัน flow ชนกัน
เพิ่ม helper ใหม่ เช่น:

```cpp
bool HasAnyActiveHedgeForGen(int gen);
bool IsGenerationInRecoveryFlow(int gen);
bool ShouldBlockDDHedgeForGen(int gen, ENUM_POSITION_TYPE counterSide);
bool ShouldBlockRecoveryGridForGen(int gen);
```

หน้าที่:
- `HasAnyActiveHedgeForGen(gen)` → มี hedge set active ผูกกับ gen นี้ไหม
- `IsGenerationInRecoveryFlow(gen)` → gen นี้เป็น sequential owner / recovery seed / recovery set tracker / orphan group active อยู่ไหม
- `ShouldBlockDDHedgeForGen(...)` → รวม guard ว่า gen นี้อยู่ใน recovery flow หรือเพิ่งถูกปล่อยจาก hedge หรือไม่
- `ShouldBlockRecoveryGridForGen(gen)` → ถ้า gen นี้ยังเป็น source/target ของ active DD hedge หรืออยู่ใน post-release cooldown ให้ recovery grid หยุด

### 2) ปิด DD hedge สำหรับ generation ที่อยู่ใน recovery flow
แก้ `CheckAndOpenHedgeByDD()` และ `OpenDDHedge()` ให้ block ไม่ใช่แค่ “มี hedge เดิมไหม” แต่รวมถึง:

- ถ้า `curGen` เป็น `g_sequentialRecoveryGen`
- หรือ `curGen` มี recovery seed/recovery set ยังไม่ flat
- หรือ `curGen` อยู่ใน orphan recovery flow
- หรือ gen นี้เพิ่งถูก release จาก DD hedge และยังอยู่ cooldown window

ให้ **skip การเปิด DD hedge ทันที**

ตัวอย่างแนวคิด:
```cpp
if(ShouldBlockDDHedgeForGen(curGen, POSITION_TYPE_BUY)) return;
```

ผลที่ต้องการ:
- Gen2 ที่กำลัง recover อยู่ จะไม่ถูก hedge ซ้ำเป็น `GM_Hedge_D2` อีกรอบ

### 3) ปิด recovery/orphan grid สำหรับ generation ที่ยังไม่ควร recover
แก้ `ManageOrphanGrid()` ให้เพิ่ม guard ก่อนเปิด `prefix_GL#N`:

- ถ้า gen นี้ยังมี active hedge set ผูกอยู่ → ห้ามเปิด orphan/recovery grid
- ถ้า gen นี้เพิ่งถูกปล่อยจาก hedge ในรอบเดียวกัน / ยังอยู่ cooldown → ห้ามเปิด orphan/recovery grid
- ถ้า gen นี้เป็น `g_cycleGeneration` และยังเข้าข่าย DD hedge domain → ไม่ให้ recovery flow มาวิ่งชน normal flow

เป้าคือกันเคสแบบใน log:
- recovery path เปิด `GM2_GL#1`
- แล้ว DD path เห็น Gen2 ยังติดลบ จึง hedge รอบสอง

### 4) เพิ่ม “post-release generation cooldown” แบบผูกกับ gen ไม่ใช่แค่ global
ปัจจุบันมี `g_lastHedgeCloseTime` เป็น global ทั้งระบบ ซึ่งยังหยาบเกินไป

เพิ่ม state ใหม่ระดับ generation เช่น:
```cpp
int      g_lastReleasedGen = -1;
datetime g_lastReleasedGenTime = 0;
input int InpHedge_PostReleaseGenBlockSec = 60;
```

แล้วอัปเดตทุกจุดที่ deactive DD hedge set:
- matching close
- release close
- shred hedge full
- external close
- orphan auto-close cleanup ที่เกี่ยวกับ DD set

ใช้เพื่อ block ทั้ง:
- DD hedge reopen ของ gen เดิม
- orphan/recovery grid ของ gen เดิม
ในช่วงเปลี่ยนผ่าน

### 5) เพิ่ม log diagnostic ให้รู้ชัดว่า “ถูก block เพราะอะไร”
ตอนนี้ log บอกได้แค่ blocked by active hedge บางกรณี
ควรเพิ่ม log แยกสาเหตุ เช่น:

```cpp
v6.74 DD HEDGE BLOCKED: Gen2 in recovery-owner flow
v6.74 DD HEDGE BLOCKED: Gen2 within post-release cooldown 42s
v6.74 RECOVERY GRID BLOCKED: Gen2 still associated with active/recent DD hedge
```

จะช่วยตอบคำถาม user ในรอบถัดไปได้ทันทีว่า
- ทำไมไม่ hedge
- ทำไมไม่เปิด recovery grid
- หรือ flow ไหนเป็นคน block

### 6) Dashboard เพิ่มสถานะ debug สั้น ๆ
เพิ่มในส่วน Hedge/Recovery เช่น:
- `GenFlowBlock`
- `ReleasedGen`
- `ReleaseCD`
- `RecoveryOwnerGen`

เพื่อดูบนชาร์ตว่า generation ไหนกำลังถูก lock อยู่

### 7) bump version เป็น v6.74
อัปเดต:
- `#property version`
- `#property description`
- header comment
- dashboard/version display

---

## สิ่งที่ไม่เปลี่ยนแปลง
- ไม่แก้ trading strategy logic
- ไม่แก้ signal entry
- ไม่แก้สูตร lot ของ grid ปกติ
- ไม่แก้ order execution primitives (`OpenOrder`, `trade.Buy`, `trade.Sell`, `trade.PositionClose`) นอกจากเรียกใช้ตาม flow เดิม
- ไม่แก้ TP/SL core logic
- ไม่แก้ news filter core
- ไม่แก้ license/data sync
- ไม่แก้ matching-close budget logic หลัก
- ไม่แก้ one-per-gen v6.72 แต่จะเสริม guard ระดับ generation ให้ครบ
- ไม่แก้ orphan auto-heal v6.73 หลัก แต่จะผูกสถานะ release/cooldown ให้สอดคล้อง

---

## ผลลัพธ์ที่คาดหวัง
กรณีเดียวกับที่ user เจอ:
1. ชุดเดิมถูกเคลียร์/ปล่อยบางส่วน
2. Gen2 เข้าช่วง recovery transition
3. ถ้า recovery grid จะเปิดเพิ่ม หรือ DD hedge จะเปิดซ้ำ
   ระบบจะให้ **ผ่านได้ทางเดียวเท่านั้น**
4. จะไม่เกิดเหตุการณ์:
   - `GM2_GL#...` เปิดเพิ่ม
   - แล้วตามด้วย `GM_Hedge_D2` ซ้ำใน generation เดิม

---

## ความเสี่ยง & Mitigation
- Risk: block มากเกินไปจน recovery ช้าลง  
  Mitigation: ใช้ gen-based cooldown ระยะสั้นและ log ชัดเจน ไม่ block ถาวร

- Risk: orphan generation เก่าที่ควร recover ถูก block ผิด  
  Mitigation: guard จะผูกเฉพาะ gen ที่ active/recently-released จาก DD hedge ไม่กระทบ orphan gen อื่น

- Risk: state ค้างหลัง restart EA  
  Mitigation: helper จะอิงสถานะจริงจาก `g_hedgeSets`, `g_sequentialRecovery*`, recovery seeds/tracker เป็นหลัก และใช้ released-gen state เป็นตัวเสริม

- Risk: user ยังเจอเคสพิเศษจาก transaction timing  
  Mitigation: เพิ่ม diagnostic logs ระบุเหตุผล block ทุกทาง เพื่อให้ trace รอบถัดไปได้ตรงจุด
