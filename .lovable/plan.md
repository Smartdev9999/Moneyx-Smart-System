

## v6.59 — Lock Sequential Recovery Until Each Released Set Fully Closes

### ปัญหาที่เจอจริงตอนนี้

จากโค้ด v6.58 ปัจจุบัน ระบบบังคับแค่ส่วน `ManageHedgeSets()` ให้ “ปลด hedge ทีละชุดต่อ tick” เท่านั้น แต่หลังจาก H1 ถูก release แล้ว ชุดนั้นจะกลายเป็น **orphan recovery** และ `ManageOrphanGrid()` ยังวิ่งจัดการ **ทุก generation พร้อมกัน** ได้อยู่

ผลคือ:
1. Dashboard ดูเหมือน sequential
2. แต่ภาคปฏิบัติ H1 กับ H2 ยังถูกแก้พร้อมกันผ่าน orphan recovery
3. ผู้ใช้จึงเห็นเหมือน “ปลดพร้อมกันทั้ง 2 ชุด”
4. ความต้องการจริงคือ:
   - ปลด H1 ก่อน
   - หลังปลดแล้ว ต้องให้ **GM/H1 recovery grid** ทำงานจน order ของชุดนั้นปิดหมดทั้งชุดก่อน
   - จากนั้นค่อยอนุญาตให้ H2 ปลด
   - H3/H4/H5 ทำต่อแบบ FIFO ทีละชุด

### สาเหตุหลักในโค้ดปัจจุบัน

1. `ManageHedgeSets()` มี `sequentialActed` จริง แต่คุมเฉพาะ hedge-set close/release
2. `ManageOrphanGrid()` ไม่รู้ว่า generation ไหนเป็น “ชุด recovery ที่กำลัง active ตามลำดับ”
3. `ScanOrphanGenerations()` + `ManageOrphanGrid()` ยังเปิด recovery grid ให้หลาย gen พร้อมกัน
4. Dashboard ใช้ `FindOldestActiveHedgeSet()` แสดง “Acting” แต่ไม่ได้สะท้อนว่า recovery ownership ถูก lock อยู่ที่ gen ไหนจริง

---

## แผนแก้ไข — `public/docs/mql5/Gold_Miner_EA.mq5`

### 1) Version bump → v6.59
อัปเดตทุกจุด:
- `#property version`
- `#property description`
- header comment
- init/deinit log
- dashboard version label

### 2) เพิ่ม “Sequential Recovery Owner” แยกจาก hedge set
เพิ่ม state ใหม่เพื่อบอกว่าตอนนี้ระบบกำลังแก้ generation ไหนอยู่แบบ exclusive

ตัวอย่าง state:
```cpp
int g_sequentialRecoveryGen = -1;     // generation currently owning recovery lock
int g_sequentialRecoverySet = -1;     // originating hedge set index (for dashboard/log)
bool g_sequentialRecoveryActive = false;
```

หลักการ:
- ตอน H1 ถูก release จาก `ManageHedgeMatchingClose()` / `ManageHedgeBoundAvgTP()` / external hedge close path
- ถ้า `InpHedge_SequentialRecovery=true`
- และยังไม่มี recovery owner อยู่
- ให้ assign owner เป็น `boundGeneration` ของ set นั้น

ผล:
- H1 release แล้ว → owner = GM / GM3 / GM5 ตามชุดจริง
- H2/H3 ยังรอ แม้ hedge set จะยัง active อยู่หรือ gate จะผ่านแล้วก็ตาม

### 3) เพิ่ม helper สำหรับ sequential ownership
เพิ่ม helper ใหม่:
```cpp
bool HasSequentialRecoveryOwner();
void SetSequentialRecoveryOwner(int hedgeSetIdx, int gen);
void ClearSequentialRecoveryOwner(string reason);
bool IsSequentialRecoveryGen(int gen);
bool IsSequentialRecoveryComplete();
int  FindNextSequentialCandidateSet();
```

พฤติกรรม:
- `SetSequentialRecoveryOwner(...)` เรียกทันทีตอน set แรกถูก release
- `IsSequentialRecoveryComplete()` ตรวจว่า generation owner ไม่มีออเดอร์เหลือแล้วจริง
- ถ้าปิดหมดแล้วค่อย `ClearSequentialRecoveryOwner(...)`
- จากนั้น tick ถัดไปค่อยให้ `ManageHedgeSets()` ปลด set ถัดไปได้

### 4) ล็อค `ManageHedgeSets()` ไม่ให้ปลด H2/H3 ถ้า H1 recovery ยังไม่จบ
แก้ guard ใน `ManageHedgeSets()`:

พฤติกรรมใหม่:
- ถ้ามี `g_sequentialRecoveryActive=true`
- ห้ามทุก set อื่นทำ release / matching / avgTP / partial / combined-grid transition
- ระบบจะรอจน owner generation ปิดหมดก่อน
- หลัง owner ปิดหมดแล้ว จึงปลดล็อคให้ `FindOldestActiveHedgeSet()` ทำงานต่อกับ H2

ลำดับใหม่:
```text
Tick A: H1 ผ่าน gate → release H1 → set owner = Gen(H1)
Tick B..N: block H2/H3 release ทั้งหมด, ให้ทำ recovery เฉพาะ owner gen
Tick N+1: owner gen ปิดหมด → clear owner
Tick N+2: H2 ถ้า gate ผ่าน → release H2 → set owner = Gen(H2)
```

### 5) ล็อค `ManageOrphanGrid()` ให้ทำ recovery เฉพาะ owner gen
นี่คือจุดสำคัญที่สุดของบั๊ก

แก้ `ManageOrphanGrid()`:
- ถ้า `InpHedge_SequentialRecovery=true` และ `g_sequentialRecoveryActive=true`
- ให้ข้าม orphan groups ทั้งหมดที่ `generation != g_sequentialRecoveryGen`
- เปิด recovery grid ได้เฉพาะ gen ที่เป็น owner เท่านั้น

ผล:
- H1 ถูกปลดแล้ว → only H1 generation gets recovery grid
- H2/H3 ถึงจะเป็น orphan หรือ scan เจอ ก็ยังไม่ถูกแก้
- ตรงกับ requirement ที่ว่า “ต้องแก้ชุดแรกจนหมดก่อน”

### 6) ตั้ง owner ตอน release/deactivate ทุกเส้นทางที่ทำให้ bound orders หลุดเป็น recovery
ต้องใส่ในทุก path ที่ปลด hedge set แล้วเหลือ bound orders เปิดอยู่ เช่น:
- `ManageHedgeMatchingClose()`
- `ManageHedgeBoundAvgTP()`
- external hedge missing path ใน `ManageHedgeSets()`
- path อื่นที่ `SaveBoundTicketsToPrevHedged()` + `active=false`

กติกา:
- ถ้าชุดนั้นยังมี bound orders เปิดอยู่ก่อน clear array
- และ sequential mode เปิดอยู่
- ให้ assign owner = `boundGeneration`
- ห้าม clear owner จนกว่าชุดนั้นปิดจริงหมด

### 7) ป้องกันการปลด set ถัดไปใน tick เดียวกับที่ owner จบ
เพิ่ม one-tick handoff guard:
```cpp
bool g_sequentialRecoveryCompletedThisTick;
```

เหตุผล:
- ถ้า H1 ปิดครบใน tick เดียวกับที่ระบบกำลัง loop อยู่
- ไม่ควรไปปลด H2 ทันทีใน tick เดียวกัน
- ให้รอ tick ถัดไปก่อน เพื่อคงพฤติกรรม “ทีละชุดจริง”

### 8) Dashboard ให้แสดงสถานะตรงกับ behavior จริง
เปลี่ยนจากแค่ “oldest active hedge” เป็นสถานะ 2 ชั้น:

ตัวอย่าง:
```text
Hedge Recovery | Sequential | Next Unlock: H2
Recovery Owner | Gen: GM3 | Source: H1 | LOCKED until flat
ORPHAN RECOVERY | 2 group(s)
Gen3 (GM3) | ACTIVE OWNER
Gen4 (GM4) | WAITING
```

หรือถ้ายังไม่มี owner:
```text
Hedge Recovery | Sequential | Ready to release: H1
```

### 9) Logging เพิ่มเฉพาะจุด debug สำคัญ
เพิ่ม log แบบจำกัดเฉพาะ event:
- owner assigned
- owner completed
- next set unlocked
- orphan group skipped because not owner

ตัวอย่าง:
```cpp
Print("v6.59 SEQ OWNER: Gen", gen, " locked from Set#", h+1);
Print("v6.59 SEQ WAIT: Skip orphan Gen", gen, " (owner=Gen", g_sequentialRecoveryGen, ")");
Print("v6.59 SEQ COMPLETE: Gen", gen, " fully closed → unlocking next hedge set");
```

### 10) ยืนยัน behavior ที่ได้หลังแก้
เมื่อมี H1 + H2 พร้อมกัน:
1. H1 ผ่าน gate → release ก่อน
2. H1 กลายเป็น recovery owner
3. H2 แม้จะผ่าน gate แล้ว ก็ยังไม่ถูกปลด
4. ระบบออก recovery grid เฉพาะ H1
5. เมื่อ H1 order ปิดหมดจริงทั้งชุด
6. clear owner
7. tick ถัดไปค่อยให้ H2 release ได้
8. ทำต่อ H3/H4/H5 แบบเดียวกัน

---

## สิ่งที่ไม่เปลี่ยนแปลง

- Order Execution Logic (`trade.Buy`, `trade.Sell`, `trade.PositionClose`) — ไม่แก้
- Trading Strategy Logic — ไม่แก้
- Initial/Grid Loss/Grid Profit ของออเดอร์ปกติ — ไม่แก้
- Hedge trigger conditions / Expansion / DD trigger thresholds — ไม่แก้
- Triple Gate logic ภายใน `IsHedgeCloseAllowed()` — ไม่แก้
- Matching Close / BoundAvgTP / PartialClose ตรรกะภายใน — ไม่แก้ แก้เฉพาะ sequencing ownership
- Balance Guard / News / License / Time Filter / Data Sync — ไม่แก้
- Re-hedge guard `IsPrevHedgedTicket()` ของ v6.58 — คงไว้
- Recovery settings แยกจาก GridLoss ของ v6.57 — คงไว้

## ผลลัพธ์ที่คาดหวัง

1. Sequential recovery จะไม่ใช่แค่ “ปลดทีละ tick” แต่เป็น “ปลดทีละชุดจนกว่าจะปิดหมด”
2. หลัง release H1 แล้ว ระบบจะ recovery เฉพาะชุด H1 เท่านั้น
3. H2/H3/H4/H5 จะไม่ถูกปลดหรือแก้พร้อมกันก่อนคิว
4. Dashboard จะสะท้อน owner/waiting state ตรงกับ behavior จริง
5. ไม่กระทบ trading logic หลัก และเป็น fix-only ตาม scope ปัญหานี้

