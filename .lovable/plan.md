## ปัญหา 2 จุด (v2.8.8 → v2.8.9)

### ปัญหา A — GL ปกติยังออกพร้อม RC หลัง Matching Close
หลัง Triple-Gate Matching Close ฝั่งกำไรถูกปิดหมด → `IsGroupHedgeMatched(g)` กลับเป็น FALSE (เพราะต้องมีทั้ง main BUY + main SELL พร้อมกัน) → guard ใน `TryPlaceGridLoss` / `TryPlaceGridProfit` ปลดล็อก → ระบบกลับมายิง **GL#N ปกติบนฝั่งติดลบพร้อมกับ RC#N** ใน group เดียวกัน

ผู้ใช้ต้องการ: เมื่อ group อยู่ใน Recovery → **หยุดยิง GL/GP/Hedge/Initial ปกติทั้งหมด** เหลือเฉพาะ RC ladder ที่ต่อจาก GL ตัวล่าสุด

### ปัญหา B — Prior-Group Advance ค้าง (G4 ติด G1 ตลอด)
Log: `hold G4->G5 ... blockPrior=G1 reason=unhedged-main ... recovery=OFF` ยิงทุกนาทีไม่หยุด

G1 หลัง match-close + RC ladder เหลือฝั่ง SELL ติดลบอย่างเดียว (ไม่มี hedge แล้วเพราะฝั่งชนะปิดหมด) → ใน `IsPriorGroupSafeForAdvance(1)`:
- `hedgeAny = CountGroupPositions(1,-1,1) > 0` → FALSE (hedge ปิดไปกับ match-close)
- `reason=3 block-no-hedge` หรือถ้ามี hedge-orphan-offset เหลือก็ตก `unhedged-main`
- guard `g_groupInRecovery[1]` ควรผ่าน แต่ flag อาจถูกเคลียร์ (group เคย flat ชั่วขณะระหว่าง shred pass) หรือ `InpExit_RecoveryAdvanceUnblock=false`

ผลคือ G4 ที่ hedge-active แล้วถูกค้างไม่ขยับไป G5 ได้ตลอดกาล

## แผน v2.8.9 — Recovery-Mode Order Lock + Prior-Advance Bypass

### A) Block GL/GP/Hedge/Initial ปกติเมื่ออยู่ใน Recovery

ใส่ guard `if(g_groupInRecovery[g]) return;` ทันทีต้นฟังก์ชันทั้งหมดนี้ (สาย entry ใหม่):
- `TryPlaceGridLoss(int g)` ~line 1620 (ต่อจาก `IsGroupHedgeMatched`)
- `TryPlaceGridProfit(int g)` ~line 1690
- `TryPlaceHedge` / `ManageGroupHedgeArm` ~line 1148, 1250
- `TryPlaceInitial` / `TryPlaceSqueezeEntries` ~line 1374, 1427

→ เหลือเฉพาะ `TryPlaceRecoveryGridContinuation(g)` ที่ทำงาน RC ladder

### B) แก้ Prior-Group Advance ให้ผ่าน "post-match group"

ใน `IsPriorGroupSafeForAdvance(int g, int &reason)` (line 3124) เพิ่ม 2 เงื่อนไข safe-pass ก่อน hedge check:

1. `if(g_groupHedgeUsed[g] && g_groupPostMatchAvgActive[g]){ reason=1; return true; }`
   — กลุ่มที่ผ่าน hedge + match-close แล้ว (Avg-TP broker คุมอยู่) → ไม่ block prior ถัดไป
2. `if(g_groupRecoveryLevel[g] > 0){ reason=1; return true; }`
   — มี RC อย่างน้อย 1 ตั๋ว → ถือว่าอยู่ในสถานะ recovery แม้ `g_groupInRecovery` ถูกเคลียร์ชั่วคราว

(เก็บ default ของ `InpExit_RecoveryAdvanceUnblock` ให้ ON)

### C) ป้องกัน `g_groupInRecovery` ถูกเคลียร์ผิดพลาด

ใน OnTick housekeeping ที่เคลียร์ flag เมื่อ group flat (line ~3920) — เคลียร์เฉพาะเมื่อ `!GroupHasAnyPositions(g) && !GroupHasAnyPendings(g)` (เงื่อนไขเดิมเก็บไว้) แต่เพิ่มกัน: ห้ามเคลียร์ขณะที่ `g_groupRecoveryLevel[g] > 0 && GroupHasAnyPositions(g)` (กันเคสที่ shred pass ปิดแล้วเปิดใหม่ใน tick เดียวกัน)

### D) Dashboard + Log

- แถว group ใน recovery → tag `[GL-LOCK RC#n/N]` ข้าง `TripleGrid`
- `hold G%d->G%d` log: เพิ่ม `priorRecLvl=N` เพื่อเห็นว่า G1 มี RC อยู่เท่าไหร่

### E) Version

- `#property version "2.89"`
- `#property description` → "v2.8.9: Recovery-Mode Order Lock + Prior-Advance Bypass — freezes GL/GP/Hedge/Initial when g_groupInRecovery; prior-group advance treats post-match (g_groupHedgeUsed && g_groupPostMatchAvgActive) or g_groupRecoveryLevel>0 as safe-pass to unblock queue."
- Dashboard title + init log → v2.8.9

## Avg TP + Broker TP สำหรับ RC (ตรวจแล้ว — ไม่ต้องแก้)

`SyncPostMatchAvgTPSL` (line 2813) ใช้ `CountGroupPositions(g,side,-1)` + `GroupAveragePrice(g,side,-1)` ซึ่งรวม main(hd=false) + hedge(hd=true). RC# ถูกสร้างด้วย `hd=false` → เข้า avg อัตโนมัติและถูก push TP ลง broker ทุก tick ✓

## สิ่งที่ไม่เปลี่ยนแปลง (Rules of Steel)

- ❌ Order execution (`trade.Buy/Sell/PositionClose`)
- ❌ `PlaceRecoveryGridIfNeeded` / `TryPlaceRecoveryGridContinuation` ladder (v2.8.8)
- ❌ Triple-Gate Matching Close + Reserve-Profit (v2.8.7) + shred passes
- ❌ Hedge Orphan Offset (v2.8.6), One-Hedge-Per-Group (v2.8.5)
- ❌ Post-Match Avg Broker TP/SL (v2.8.4) — สูตร/timing ของเดิม
- ❌ Squeeze BB/KC ratio, Entry SMA/INSTANT/PENDING
- ❌ License/News/Time/Sync
- ❌ `IsGroupHedgeMatched` / `IsGroupSafeToAdvance` (current group) semantics — แก้เฉพาะ `IsPriorGroupSafeForAdvance`
- ❌ `CountBlockingMainPositionsForAdvance` / `IsSideEffectivelySafeForAdvance`

## ไฟล์ที่แก้

- `public/docs/mql5/Golden2_EA.mq5` (version → 2.89)
- สร้าง `.lovable/memory/trading/golden2-ea/v2-8-9-recovery-lock-and-prior-advance-bypass.md`
- อัปเดต `.lovable/memory/index.md`