
## v6.70 — Recovery TP Sync Fix + Start Comments at GM1 + Hard Flat Reset

### ปัญหาที่ต้องแก้จากรอบนี้

1. **Recovery orders ไม่ถูกเอาเข้าคำนวณ Avg TP / ไม่ได้ broker TP**
   - จากภาพ: main hedge มี TP แต่ `GM_HD9_01..04` ยังเป็น `T/P = 0.00`
   - ในโค้ดตอนนี้ `SyncRecoveryBasketTP()` ถูกเรียกจาก flow หลักหลัง matching เท่านั้น แต่ **ตอนเปิด recovery order ใหม่ใน `ManageHedgeGridMode()` ยังไม่ได้ sync TP ทันที**
   - ทำให้มีช่วงที่ recovery order ถูกเปิดแล้ว แต่ยังไม่ถูก modify TP หรือบาง set หลุดจากจังหวะ sync

2. **ชื่อ comment เริ่มที่ `GM` ทำให้อ่านยาก**
   - ตอนนี้ generation แรกยังเป็น `GM`
   - ต้องการให้ **รอบแรกเริ่มที่ `GM1`** เพื่อให้ map ง่าย:
     - `GM1_INIT`
     - `GM_HEDGE_1` ผูกกับ `GM1`
     - `GM_HD1_01` ผูกกับ `GM1`

3. **เวลาบัญชีไม่มีออเดอร์แล้ว ระบบยังไม่ reset กลับไปเริ่มที่ GM1**
   - ตอนนี้ `g_cycleGeneration` ยังมีโอกาสค้างและนับต่อ
   - ต้องทำให้เมื่อ **flat จริงทั้งบัญชี** ระบบ reset state ทั้งหมดและรอบใหม่กลับไป `GM1`

---

## แผนแก้ไข — `public/docs/mql5/Gold_Miner_EA.mq5`

### 1) Version bump → v6.70
อัปเดต:
- `#property version`
- `#property description`
- header comment
- init/deinit log
- dashboard label

### 2) แยก “internal generation” ออกจาก “comment label”
คง internal index เดิมเพื่อไม่กระทบ logic/set array แต่เปลี่ยน **label ที่ user เห็น** เป็นเริ่มจาก 1

เพิ่ม helper ใหม่ เช่น:
```cpp
int GenLabel(int gen) { return gen + 1; }
string GenPrefixLabel(int gen) { return "GM" + IntegerToString(GenLabel(gen)); }
string GetCommentPrefix() { return GenPrefixLabel(g_cycleGeneration); }
```

แล้วเปลี่ยนจุดสร้าง comment ให้ใช้ label ใหม่:
- `GM_INIT` → `GM1_INIT`
- `GM1_INIT` เดิม → `GM2_INIT`
- recovery comment:
  - `GM_HD<boundGen+1>_<NN>`
- orphan generation label / dashboard / logs ใช้แบบเดียวกัน

### 3) Backward-compatible parser สำหรับ comment เก่าและใหม่
แก้ `ExtractGeneration()` ให้รองรับทั้ง:
- legacy: `GM_INIT`, `GM_GL#1` → internal gen `0`
- new: `GM1_INIT`, `GM1_GL#1` → internal gen `0`
- `GM2_*` → internal gen `1`

ผลคือ:
- order เก่าที่ยังลอยอยู่ยังอ่านได้
- order ใหม่หลังอัปเดตจะเริ่มที่ `GM1`

### 4) Fix Recovery comment mapping ให้ตรงกับ GM1-based label
ตอนนี้ `GM_HD<gen>_<NN>` ยังอิงเลข internal อยู่  
ปรับเป็น:
```cpp
string comment = "GM_HD" + IntegerToString(g_hedgeSets[idx].boundGeneration + 1) + "_"
               + StringFormat("%02d", currentGridCount + 1);
```

และ matcher:
```cpp
bool IsRecoveryGridForSet(const string c, int idx, int gen)
{
   if(StringFind(c, "GM_HG" + IntegerToString(idx + 1)) >= 0) return true; // legacy
   if(StringFind(c, "GM_HD" + IntegerToString(gen + 1) + "_") >= 0) return true; // new label
   return false;
}
```

### 5) บังคับ sync Avg TP / broker TP ทันทีหลังเปิด recovery order
จุดสำคัญสุดของ bug รอบนี้

ใน `ManageHedgeGridMode(idx)` หลัง `OpenOrder(...)` สำเร็จ:
- track ticket เหมือนเดิม
- **เรียก `SyncRecoveryBasketTP(idx)` ทันที**
- จากนั้น reselect ticket และ log ว่า TP ถูก apply แล้วหรือไม่

แนวคิด:
```cpp
if(OpenOrder(orderType, nextLot, comment))
{
   ...
   TrackRecoveryGridTicket(idx, newTk);
   SyncRecoveryBasketTP(idx);   // new in v6.70
}
```

เพื่อให้ recovery order ใหม่:
- ถูกนำเข้าคิด weighted average ทันที
- ได้ broker TP ทันทีใน tick เดียวกัน
- ไม่ต้องรอ flow matching รอบถัดไป

### 6) Harden `SyncRecoveryBasketTP()` ให้รวม recovery tickets ได้ชัวร์กว่าเดิม
เสริม guard ใน `SyncRecoveryBasketTP(idx)`:
- เรียก `CompactRecoveryGridTickets(idx)` ก่อนสร้าง basket
- union จาก 3 แหล่ง:
  1. main hedge ticket
  2. comment-match (`GM_HD...` + legacy)
  3. `recoveryGridTickets[]`
- dedupe ด้วย ticket
- ถ้า `cnt >= 2` หรือมี hedge+recovery อย่างน้อย 1 ตัว ให้ modify TP ทั้งหมด

เพิ่ม log ชัดเจน:
```text
v6.70 RECOVERY TP Set#1: hedge=1 gridByComment=3 ticketOnly=1 total=5 avg=...
```

### 7) ให้ orphan recovery ใช้ comment scheme เดียวกัน
ตอนนี้ `ManageOrphanGrid()` ยังมีจุดที่เปิด comment แบบ `prefix + "_GL#"`  
ปรับให้ใช้ scheme เดียวกับ recovery set:
- `GM_HD<label>_<NN>`
- และถ้ามี ticket mapping ที่โยงเข้า hedge set ได้ ให้ track ticket ด้วย

เพื่อไม่ให้มี 2 รูปแบบ comment ปะปนใน recovery path ใหม่

### 8) Flat reset ให้รีเซ็ตกลับไป GM1 แบบชัวร์
เพิ่ม helper reset กลาง เช่น:
```cpp
void ForceResetCycleState(string reason)
```
ให้ทำทั้งหมดเมื่อ `TotalOrderCount()==0`:
- `g_cycleGeneration = 0`
- `SaveCycleGeneration()` หรือ delete GV
- `g_hedgeSetCount = 0`
- clear ทุก `g_hedgeSets[h]`
- clear `recoveryGridTickets[]`
- delete `GME_REC_TK_*`
- clear sequential owner / orphan groups / prev hedged tickets
- reset side-pause state

แล้วเปลี่ยนจุด reset หลักทั้งหมดให้เรียก helper กลางนี้เมื่อ flat จริง:
- `TryResetCycleStateIfFlat()`
- `OnTick flat-detect`
- close-all / balance-guard reset path
- external-close cleanup path

ผลลัพธ์:
- พอบัญชีไม่มีออเดอร์แล้ว รอบถัดไปจะเริ่มใหม่ที่ `GM1`
- ไม่ค้างเป็น `GM9`, `GM10`, `GM11` ต่อไปเรื่อยๆ

### 9) Recovery on init ให้ respect GM1 label scheme
ใน `RecoverHedgeSets()`:
- ถ้า flat → ล้าง cycle GV + state ทั้งหมด
- ถ้ามี order ค้าง:
  - legacy `GM` = gen0
  - `GM1` = gen0
  - `GM2` = gen1
- dashboard/log แสดงเป็น label แบบ 1-based ทั้งหมด

### 10) Dashboard / Logging ปรับให้อ่านตามเลขเดียวกัน
ตัวอย่าง:
```text
Cycle: GM1
Hedge #1 | Gen=GM1
Recovery Grid | next=GM_HD1_03
v6.70 RECOVERY TP Set#1: total=5 avg=4851.22 tp=4723.56 modified=5/5
v6.70 FLAT RESET: all states cleared -> next cycle starts at GM1
```

---

## สิ่งที่ไม่เปลี่ยนแปลง

- Order execution logic (`OrderSend`, `trade.Buy`, `trade.Sell`, `trade.PositionClose`, `trade.PositionClosePartial`) — ไม่แก้
- Trading strategy / signal / initial entry conditions — ไม่แก้
- Grid distance / lot formula / reverse-walk seed logic — ไม่แก้
- Hedge trigger rules (Expansion / DD% / Dollar) — ไม่แก้
- Triple Gate exit / matching rules / one-time shred / combined TP formula — ไม่แก้สูตร
- News / License / Time filter / Sync modules — ไม่แก้
- Max active hedge sets / generation-locked hedge slot concept — ไม่แก้

---

## Validation Checklist

1. เปิด cycle ใหม่ตอนบัญชีว่าง → comment แรกเป็น `GM1_INIT` ไม่ใช่ `GM_INIT`
2. Hedge ชุดแรกยังเป็น `GM_HEDGE_1` แต่ bound กับ `GM1` ชัดเจน
3. Recovery ชุดแรกเป็น `GM_HD1_01`, `GM_HD1_02`, ...
4. เมื่อ recovery order เปิดใหม่ใน `ManageHedgeGridMode()` → ได้ broker TP ใน tick เดียวกัน
5. `SyncRecoveryBasketTP()` log แสดงจำนวน tickets รวม hedge + recovery ครบ
6. ภาพแบบเดิมที่มี hedge 1 ตัว + recovery 4 ตัว → TP ถูก set ครบทั้ง 5 ตัว ไม่ใช่เฉพาะ hedge
7. Order comment เก่าแบบ `GM_*` หรือ `GM_HG*` ยัง recover/manage ได้
8. เมื่อปิดทุกออเดอร์หมดทั้งบัญชี → cycle reset กลับ 0 ภายใน state และรอบใหม่เริ่ม `GM1`
9. หลัง flat reset แล้ว ไม่มี `GM9/GM10/GM11` ต่อเนื่องข้ามรอบอีก
10. Restart EA ระหว่างมี order เก่า/ใหม่ปะปน → parser ยัง bind generation ถูกต้อง
