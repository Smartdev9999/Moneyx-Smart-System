

## v6.63 — Fix Set#2 Frozen Under Owner Lock + Persistent Hedge Slot Numbering

### ปัญหาที่เจอจริง (จาก image-888, image-889)

**ปัญหา 1: Set#2 ค้าง ไม่คำนวณ ไม่ปิด แม้เงื่อนไขครบ**
- Dashboard แสดง `Hedge Recovery | Sequential | Next Unlock: H2 (1/tick) | Wait: 1 set(s)` แต่ Set#2 ไม่เคยรัน matching เลย
- จาก image-888: Set#2 มี GM1_INIT +$1060, GM1_GL#1 +$1609, GM1_GL#2 +$3755 (profit รวม +$6424) vs GM_HEDGE_2 -$10193 → in-set pool พอจะซอยปิดได้บางส่วน แต่ระบบไม่ทำอะไร

**Root Cause 1:** ที่ `ManageHedgeSets()` line 9146-9150 (v6.59 owner lock):
```cpp
if(g_sequentialRecoveryActive) {
   g_hedgeSets[h].matchingDone = false;
   continue;   // ← block ทุก set รวมทั้ง Set#2
}
```
Logic นี้ block ทุก set เมื่อมี owner — แต่หลัง v6.62 ที่ user ยืนยัน "strict in-set" → Set#2 ต้องรัน matching ของตัวเองได้อิสระ ไม่ขึ้นกับ owner ของ Set#1 (เพราะ matching v6.62 แตะเฉพาะ in-set อยู่แล้ว ไม่ leak)

**ปัญหา 2: Hedge slot reuse → comment GM_HEDGE_1 ซ้ำ**
- หลัง Set#1 ปิด → slot 0 ว่าง
- เปิด hedge ใหม่ → `FindFreeHedgeSlot()` คืน slot 0 → comment `GM_HEDGE_1` ซ้ำ ทั้งที่ Set#2 (GM_HEDGE_2) ยังอยู่
- User ต้องการเลขเรียงไม่รีเซ็ต: H2 → H3 → H4 จนกว่าทุก set จะ flat แล้วค่อยกลับเป็น H1

**Root Cause 2:** `FindFreeHedgeSlot()` หาช่องว่างจาก index 0 เสมอ → reuse ตัวเลขเก่าทันที

---

## แผนแก้ไข — `public/docs/mql5/Gold_Miner_EA.mq5`

### 1) Version bump → v6.63
อัปเดต `#property version`, `#property description`, header, init/deinit log, dashboard label

### 2) ปลด Block ของ Owner Lock สำหรับ Matching (Strict In-Set ของแต่ละ set)

แก้ที่ `ManageHedgeSets()` line 9143-9172 — เปลี่ยน semantics ของ owner lock:

**เดิม:** owner active → block ทุก set
**ใหม่ v6.63:** owner active → **อนุญาตให้ทุก set รัน matching/AvgTP/PartialClose ของตัวเองได้** (เพราะ v6.62 strict in-set แล้ว) แต่ **ยัง block grid recovery (TryEnterCombinedGridMode + ManageHedgeGridMode) ของ non-owner set** เพื่อให้ owner gen ปิดให้หมดก่อน

วิธีทำ: แทนที่ block แบบ continue ด้วย flag:
```cpp
bool blockGridForThisSet = false;
if(InpHedge_SequentialRecovery)
{
   if(g_sequentialRecoveryCompletedThisTick) {
      g_hedgeSets[h].matchingDone = false;
      continue;  // คง one-tick handoff
   }
   if(g_sequentialRecoveryActive) {
      // v6.63: matching อนุญาต (in-set) แต่ block grid ของ set ที่ไม่ใช่ owner
      int boundGenH = g_hedgeSets[h].boundGeneration;
      if(boundGenH != g_sequentialRecoveryGen)
         blockGridForThisSet = true;
   } else if(sequentialActed) {
      blockGridForThisSet = true;
   } else {
      int oldestActiveIdx = FindOldestActiveHedgeSet();
      if(oldestActiveIdx >= 0 && h != oldestActiveIdx)
         blockGridForThisSet = true;
      else
         sequentialActed = true;
   }
}
```

จากนั้นใน STEP 2 (line 9223-9224) เพิ่ม guard:
```cpp
if(!blockGridForThisSet)
   TryEnterCombinedGridMode(h);
```
และ grid mode (line 9175-9179):
```cpp
if(g_hedgeSets[h].gridMode) {
   if(!blockGridForThisSet)
      ManageHedgeGridMode(h);
   continue;
}
```

ผล: Set#2 จะรัน matching ของตัวเองทุก tick (in-set safe) → ปิดได้เมื่อ pool พอ; แต่ recovery grid ของ Set#2 จะรอจนกว่า owner Gen ของ Set#1 จะ flat

### 3) Hedge Slot Numbering แบบไม่ Reuse จนกว่าจะ Flat ทุก Set

แก้ `FindFreeHedgeSlot()` (line 7910-7917):

```cpp
int FindFreeHedgeSlot()
{
   // v6.63: หาเลขสูงสุดที่เคยใช้ใน active sets → ใช้เลขถัดไป
   //        ถ้าไม่มี active set ใดเลย (flat ทั้งหมด) → reset กลับ slot 0 = H1
   int maxActiveSlot = -1;
   bool anyActive = false;
   for(int h = 0; h < MAX_HEDGE_SETS; h++)
   {
      if(g_hedgeSets[h].active)
      {
         anyActive = true;
         if(h > maxActiveSlot) maxActiveSlot = h;
      }
   }
   
   if(!anyActive)
   {
      return 0;   // flat → reset เลขเริ่มที่ H1 ใหม่ตามที่ user ต้องการ
   }
   
   // มี active set อยู่ → ใช้ slot ถัดจากตัวสูงสุดเสมอ ไม่ reuse ช่องว่างกลาง
   int next = maxActiveSlot + 1;
   if(next < MAX_HEDGE_SETS) return next;
   
   // ถ้าเต็ม MAX_HEDGE_SETS แล้ว → fallback หาช่องว่างกลาง (กัน overflow)
   for(int h = 0; h < MAX_HEDGE_SETS; h++)
      if(!g_hedgeSets[h].active) return h;
   
   return -1;
}
```

ผลกับ scenario user:
- Set#1 (slot 0 = H1) ปิด, Set#2 (slot 1 = H2) ยังอยู่ → maxActiveSlot=1 → hedge ใหม่ = slot 2 → comment `GM_HEDGE_3` ✓
- ถ้า Set#3 (H3) ก็มี → ตัวต่อไป slot 3 = `GM_HEDGE_4` ✓
- เมื่อทุก set flat → reset เริ่ม slot 0 = `GM_HEDGE_1` ใหม่

### 4) ผลกระทบกับ Recovery / RECOVER ตอน restart

`RecoverHedgeSetsFromOpenPositions()` ที่ line 8373-8413 อ่าน comment `GM_HEDGE_N` แล้วใช้ `h` ตาม index → ยังทำงานถูกต้อง เพราะ comment number = slot+1 ตรงกับ array index → ไม่ต้องแก้

### 5) Dashboard ปรับให้สะท้อน behavior ใหม่
ที่ section `Hedge Recovery` (~line 4404):
```text
Hedge Recovery | LOCKED | Owner Gen0 (Src H1) | 3 order(s) left
                | Match: ALL sets allowed (in-set) | Grid: H2/H3 paused
```

### 6) Logging v6.63
```cpp
Print("v6.63 IN-SET MATCH ALLOWED: Set#", h+1, " Gen", boundGenH,
      " (owner=Gen", g_sequentialRecoveryGen, " — grid blocked but matching active)");
Print("v6.63 SLOT ASSIGN: maxActiveSlot=", maxActiveSlot,
      " → new slot=", next, " (comment=GM_HEDGE_", next+1, ")");
```

---

## สิ่งที่ไม่เปลี่ยนแปลง

- Order Execution (`trade.PositionClose`, `OpenOrder`) — ไม่แก้
- Trading Strategy / Signal / Initial Grid / Grid Loss / Grid Profit — ไม่แก้
- `ManageHedgeMatchingClose()` v6.62 strict in-set pool — ไม่แก้
- `ManageHedgeBoundAvgTP()` / `ManageHedgePartialClose()` — ไม่แก้
- Hedge open trigger / Triple Gate / DD threshold — ไม่แก้
- Sequential Recovery Owner concept v6.59-v6.60 — คงไว้ (ปรับเฉพาะ scope: owner block grid ของ non-owner เท่านั้น ไม่ block matching)
- `RecoverHedgeSetsFromOpenPositions()` — ไม่แก้ (ยัง parse comment number → array index)
- Re-hedge guard v6.58 / BB Filter v6.56 / Recovery Grid v6.57 — ไม่แก้
- Accumulate Close / Balance Guard / News / License / Time Filter — ไม่แก้
- v6.37–v6.62 features — ไม่แก้

## Validation Checklist

1. Scenario image-888: Set#2 ต้องรัน matching → ใช้ +$6424 ปิด GM_HEDGE_2 -$10193 บางส่วน (ซอยปิดเท่าที่ pool พอ)
2. Owner Gen0 (Src H1) lock active → Set#2 matching ทำงานได้ แต่ recovery grid ของ Set#2 รอ
3. หลัง Set#1 ปิด, Set#2 ยังอยู่ → hedge trigger ใหม่ → comment ต้องเป็น `GM_HEDGE_3` (ไม่ใช่ `GM_HEDGE_1`)
4. ถ้า Set#3 (H3) ก็มี → hedge ตัวถัดไป = `GM_HEDGE_4`
5. เมื่อทุก set flat → hedge ใหม่ = `GM_HEDGE_1` (reset)
6. ไม่มี cross-set leak: log ของ Set#2 matching ต้องไม่แตะ ticket ของ Gen อื่น
7. Restart EA mid-recovery → recovery จาก comment number → array slot ตรง → hedge ใหม่ต่อจาก max ที่มี

