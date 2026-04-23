

## v6.75 — แก้ปัญหา DD Hedge ไม่ออกแม้ถึงเกณฑ์ (Mutex over-blocking)

### วินิจฉัยจาก image-956/957/958

จาก log:
```
v6.74 DD$ HEDGE BLOCKED: SELL side of Gen1 — DD blocked: Gen1 in recovery flow
```

จากภาพ orders: Gen1 มีไม้ sell `GM1_GL#2..#7` รวม 0.97 lot ขาดทุน -4,808 USD  
จาก Dashboard: `DD Scope: GM1 (Gen 1)` และ `SELL DD: $4767/$1000` (เกินเกณฑ์ 4.7 เท่า)  
แต่ `GenMutex: ON CD:60s LastGen:1` — **mutex บล็อก hedge ทั้งที่ควรออก**

### Root cause

ใน `IsGenerationInRecoveryFlow(Gen1)` คืนค่า `true` เพราะ `g_sequentialRecoveryActive && g_sequentialRecoveryGen == 1`

นั่นแปลว่า Gen1 ถูกตั้งเป็น "sequential recovery owner" จาก hedge set ก่อนหน้าที่ปลดมา ซึ่งเป็น **สถานะปกติของ generation ปัจจุบัน** ไม่ใช่ "อยู่ระหว่าง recovery flow ที่ไม่ควร hedge ซ้ำ"

ผลคือ DD hedge ของ Gen1 ถูก block **ตลอดไป** จนกว่า Gen1 จะ flat — ซึ่งจะไม่มีวันเกิดถ้าไม่มี hedge ช่วย

นอกจากนี้เงื่อนไข `!IsRecoverySetFlat(gen)` ก็คืน true ตราบใดที่ยังมีไม้ของ gen นั้นเปิดอยู่ ซึ่งทับซ้อนกับการเทรดปกติเช่นกัน

v6.74 ตั้งใจจะกัน "recovery grid + DD hedge ซ้อนใน gen เดียว" แต่:
- **OnePerGenSide guard (v6.72)** กัน hedge ซ้ำต่อ gen+side อยู่แล้ว
- **Post-release cooldown (v6.74)** กันการ re-hedge ทันทีหลังปลด hedge อยู่แล้ว
- เงื่อนไข `IsGenerationInRecoveryFlow` เป็น guard ที่กว้างเกินจน **ทับซ้อนกับการเทรดปกติของ generation ปัจจุบัน**

### แผนแก้

ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. ปรับ `ShouldBlockDDHedgeForGen()` ให้ไม่ block "current generation"

เพิ่ม early-exit: ถ้า `gen == g_cycleGeneration` (คือ generation ที่กำลังเทรดปกติอยู่) ไม่ต้องเช็ค `IsGenerationInRecoveryFlow` เพราะ:
- ไม้ใหม่ของ generation นี้คือไม้เทรดปกติ ไม่ใช่ recovery grid
- หาก DD ถึงเกณฑ์ ต้องสามารถ hedge ได้
- การกัน "hedge ซ้ำ" ปล่อยให้ `OnePerGenSide` + `HasActiveHedgeForGenSide` จัดการ
- การกัน "เพิ่ง release แล้วเด้งกลับ" ปล่อยให้ `IsGenInPostReleaseCooldown` จัดการ (ยังคงเช็คอยู่)

```cpp
bool ShouldBlockDDHedgeForGen(int gen, ENUM_POSITION_TYPE counterSide)
{
   if(!InpHedge_GenFlowMutex) return false;
   
   // v6.75: current trading generation — recovery-flow check ไม่ apply
   //        (OnePerGenSide กัน hedge ซ้ำ + post-release cooldown กัน re-hedge ทันที)
   bool isCurrentGen = (gen == g_cycleGeneration);
   
   if(!isCurrentGen && IsGenerationInRecoveryFlow(gen))
   {
      g_lastGenBlockReason = "...";
      return true;
   }
   if(IsGenInPostReleaseCooldown(gen)) { ... return true; }
   return false;
}
```

#### 2. ปรับ `ShouldBlockRecoveryGridForGen()` ให้สอดคล้อง

เงื่อนไข `HasAnyActiveHedgeForGen` + `IsGenInPostReleaseCooldown` ยังคงไว้ (ตามเดิม) — ส่วนนี้ทำงานถูกแล้ว เพราะ recovery grid ไม่ควรเปิดถ้ามี hedge active หรืออยู่ใน cooldown หลังปล่อย hedge

#### 3. เพิ่ม diagnostic log + dashboard

- Log แยกชัดเมื่อ skip recovery-flow check เพราะเป็น current gen:  
  `v6.75 GenMutex: skip recovery-flow check for current gen (Gen1)`
- Dashboard เพิ่ม indicator: `GenMutex` row แสดง `CurGen:1 (skip RF)` เมื่อ apply rule นี้

#### 4. Bump version → v6.75

อัปเดต:
- `#property version "6.75"`
- `#property description`
- Header comment block
- Dashboard version display

---

### สิ่งที่ไม่เปลี่ยนแปลง
- ไม่แก้ trading strategy / signal entry / grid logic
- ไม่แก้ order execution (`OpenOrder`, `trade.*`)
- ไม่แก้ TP/SL/news/license/data sync
- ไม่แก้ DD threshold computation
- ไม่แก้ `OnePerGenSide` guard (v6.72) — ยังกัน hedge ครั้งที่ 2
- ไม่แก้ orphan auto-heal (v6.73)
- ไม่แก้ post-release cooldown (v6.74) — ยังทำงานเต็มรูปแบบ
- ไม่แก้ `ShouldBlockRecoveryGridForGen` — ยังกัน recovery grid ตามเดิม

### ผลที่คาดหวัง
- เคสในภาพ: Gen1 SELL DD = $4767 → DD hedge ออกได้ตามเกณฑ์
- ยังคงป้องกัน hedge ครั้งที่ 2 ผ่าน OnePerGenSide
- ยังคงป้องกัน re-hedge ทันทีหลังปลดผ่าน post-release cooldown
- Recovery grid (orphan) ของ generation เก่ายังถูก mutex จัดการตามเดิม

### ความเสี่ยง & Mitigation
- **Risk:** ถ้า user ต้องการพฤติกรรมเก่า → toggle `InpHedge_GenFlowMutex = false` หรือเปิด input ใหม่ `InpHedge_MutexBlockCurrentGen` (default false) สำหรับใครอยาก strict
- **Risk:** Recovery seeds/orphan groups ที่อยู่ใน current gen อาจชน → ในความเป็นจริง orphan groups จะใช้กับ gen ที่ไม่ใช่ current เท่านั้น (gen ที่ผ่านไปแล้ว) จึงไม่กระทบ

