
# Golden Kuy3 v1.4 — Port Hero v7.09 (No-Gen / Cycle-Based / Single-Side Only)

## หลักคิด
Kuy3 ไม่มี gen → **ตัด gen-isolation ออกทั้งหมด** ใช้แค่ `InpHero_SingleSideLock = true` ของ Gold Miner ก็ได้พฤติกรรมตรงสเปก:

> "ฝั่งใดเข้าเงื่อนไข Hero ได้ก่อน → lock เป็น Hero owner. อีกฝั่งเดินเป็น grid ธรรมดา (ไม่มี Hero). จนกว่า Hero ชุดนั้นจะปิด → ฝั่งใดเข้าเงื่อนไขใหม่ก็ค่อยเป็น Hero รอบถัดไป (สลับได้)."

= ตรงกับ `InpHero_SingleSideLock=true` + `GetHeroOwnerSide()` (phase==BE_GUARD) ของ v7.04/v7.07 พอดี

## ไฟล์ต้นฉบับ
`public/docs/mql5/Gold_Miner_EA.mq5` v7.09

## Inputs ที่ port มา (ตัด gen-related ออก)
ตามรูปที่ user แนบ แต่ตัด `InpHero_PerSideGenIsolation` ทิ้ง:
- `InpHero_Enabled` = false
- `InpHero_OrderCount` = 2
- `InpHero_MinOrdersToActivate` = 5
- `InpHero_BE_OffsetPoints` = 50
- `InpHero_BlockSameSideGrid` = true
- `InpHero_IncludeInMaxOrders` = true
- `InpHero_PostCloseGraceSec` = 5
- `InpHero_SingleSideLock` = **true** (บังคับเปิด — เพราะนี่คือสเปก user)
- `InpHero_CloseWithOpposite` = true (deprecated, .set compat)
- `InpHero_RequireNetProfit` = false (deprecated, .set compat)

ตัดออก: `InpHero_PerSideGenIsolation` (ไม่มี gen ใน Kuy3)

## ฟังก์ชันที่ port (เอาแบบ Gold Miner v7.09 เป๊ะ ยกเว้น gen)

| ฟังก์ชัน | สถานะการ port |
|---|---|
| `GetHeroOwnerSide()` | ✅ port ตรง — owner = side ที่ phase==BE_GUARD |
| `BuildHeroTicketCache()` | ✅ port + ตัด `g_heroOwnedGen_*` / `GetActiveGenForSide` / per-gen pool-lock ออก. เก็บ rolling latest-N + sticky tag + auto-release v7.09 + Single-Side Lock |
| `EnsureHeroProtection(reason)` | ✅ port ตรง |
| `IsHeroTicket / CountHeroOnSide / CountNonHeroMainOnSide` | ✅ port ตรง (ไม่มี filter gen) |
| `ShouldBlockSameSideGridForHero` | ✅ port ตรง — block side ที่มี Hero survivor (basket=0) |
| `SumHeroLotsOnSide / SumHeroProfitOnSide` | ✅ port ตรง |
| `CloseHeroOnSide(side, reason)` | ✅ port ตรง — hard reset phase + stamp `g_heroJustClosed_<side>` |
| `DetectSameSideBasketClearedForHero` | ✅ port ตรง |
| `ComputeHeroLockProfitSL / ValidateHeroLockProfitSL / ApplyHeroLockProfitSL` | ✅ port ตรง (สูตร BE-Lock SL ที่ v7.02 แก้ไว้) |
| `StripBrokerTPSLFromHeroTickets` | ✅ port ตรง |
| `CloseOppositeHeroOnBasketClose / ManageHeroOppositeClose` | ✅ port ตรง |
| `ResetHeroStateIfFlat` | ✅ port ตรง |

**ตัดออกทั้งฟังก์ชัน:**
- `MaintainSideGenAfterHeroClose()` — ไม่จำเป็น ไม่มี gen
- `GetActiveGenForSide()` — ไม่ต้อง stub แค่ลบ caller

## Globals (ตัด gen ออก)
เอามาทั้งหมดยกเว้น:
- ❌ `g_sideGen_Buy / g_sideGen_Sell` — ลบ
- ❌ `g_heroOwnedGen_Buy / g_heroOwnedGen_Sell` — ลบ
- ✅ คงไว้: `g_heroTickets[200]`, `g_heroPhase_*`, `g_heroBE_Applied_*`, `g_heroDash_*`, `g_heroJustClosed_*`, `g_heroLockedSide` (deprecated)

## Adapter (Kuy3 ไม่มี hedge / multi-set)
ใน Gold Miner ฟังก์ชัน Hero เรียก:
- `IsHedgeComment(c)` → Kuy3 wrapper return `false` ตลอด
- `GM_HEDGE_*` prefix scan → เปลี่ยนเป็น "all positions same magic" (Kuy3 ใช้ comment เดียว)
- comment scan รูปแบบ `_INIT/_GL/_GP` → Kuy3 มี comment ของตัวเอง: ถือว่า "ทุก position ของ magic เดียวกันคือ basket" (ไม่แยก INIT/GL ในการ tag — pool ครบทุกออเดอร์)

> เนื่องจาก Kuy3 มี order pattern เดียว (Initial + Grid ฝั่งเดียวกัน) ไม่ต้อง filter prefix ก็ได้ — ทุก position ของฝั่งเดียวกันเข้า pool รวม

## Hooks ใน OnTick (ลำดับตาม Gold Miner)
เพิ่ม **ที่ต้นสุด** ของ OnTick (ก่อน module ทุกอัน):
```cpp
BuildHeroTicketCache();
ManageHeroOppositeClose();
```
ตัด `MaintainSideGenAfterHeroClose()` ออก

## Skip-Hero ใน module เดิม
- `ManagePerOrderTrailing` → `if(IsHeroTicket(tk)) continue;`
- `EnforceClearTPIfDisabled` → skip Hero
- `CloseAllOurs` / Accumulate close → skip Hero (Hero ปิดผ่าน `CloseHeroOnSide` เท่านั้น)
- `CalcSideAvgPrice` (ใช้ใน Avg-Trail / AvgTP / TP Points) → skip Hero
- Cost-Hit Restart → skip ถ้า ticket ที่ปิดเป็น Hero / อยู่ใน `PostCloseGraceSec`
- `MaxOpenOrders` cap → skip Hero ถ้า `InpHero_IncludeInMaxOrders=false`

## Dashboard (เพิ่ม section ใหม่ ตาม v7.07)
```
=== HERO ORDER ===
Hero Cfg          ON  N=2 minAct=5 BE=50pt
Hero Owner        NONE / BUY (locked) / SELL (locked)
Hero BUY          active=12/5  Hero=2  PHASE=ARMED
Tix BUY           #1234 #1235
Hero SELL         active=3/5   Hero=0  PHASE=WAIT
Tix SELL          —
```

ตัดแถว `Side Gen BUY/SELL` ออก (ไม่มี gen)

## ลบของเก่า v1.3 ทั้งหมด
- inputs: `InpHero_AvgTP_Points`, `InpHero_AvgTP_MinOrders`, `InpHero_KeepLatestN_Opp`, `InpHero_StripBE_OnSurvivor`, `InpHero_BE_OffsetPips`, `InpHero_MinSideOrders`, `InpHero_Count`
- globals: `g_hero_Active`, `g_hero_Side`, `g_hero_Tickets[]`, `g_hero_LastCloseTime`, `g_hero_LastOppAvg/Cnt`
- functions: `RefreshHero`, `ManageHeroAvgTP`, `CloseAllExceptHeroAndOppSurvivor`, `CalcSideAvg/Floating_NonHero`

## Version
- `#property version "1.40"`
- `#property description` → "Hero v7.09 ported (single-side lock, no gen, cycle-based)"
- Header + Dashboard title bump → `Golden Kuy3 v1.4`

## ไม่เปลี่ยน (กฎเหล็ก)
- ไม่แตะ `OrderSend` / `trade.*` ของ Kuy3 v1.2
- ไม่แตะ Grid distance / `CalcGridLot` v1.2 / Cost-Hit core (เพิ่มแค่ guard)
- ไม่แตะ Per-Order BE สูตร / Avg-Trail strict-2-cross / TP modes / Accumulate (เพิ่มแค่ skip-Hero)
- ไม่มี License / News / Sync / Hedge / Squeeze module
- `InpHero_Enabled=false` → พฤติกรรม EA = v1.2 ทุกบรรทัด

## ไฟล์ที่จะแก้
- `public/docs/mql5/Golden_Kuy3_EA.mq5` (1353 → ~1750 lines, v1.30 → v1.40)
- สร้าง `.lovable/memory/trading/golden-kuy3/v1-4-hero-port-no-gen-single-side.md`
- อัปเดต `mem://index.md` (แทน entry v1.3)
- อัปเดต `.lovable/plan.md`

---

ยืนยันแบบนี้ใช่ไหมครับ? (ตัด gen ทิ้ง, เก็บแค่ Single-Side Lock = สลับฝั่ง ทีละฝั่ง)
