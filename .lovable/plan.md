

## v6.65 — Strict Sequential Matching: Only Oldest Set Shreds at a Time + Auto Recovery Lot Sizing

### ปัญหาจริง (จาก image-895)

v6.64 อนุญาตให้ **ทุก set รัน matching ทุก tick** → Set#1 (GM_HEDGE_1 +554) และ Set#2 (GM_HEDGE_2 -4359) **ซอยปิดพร้อมกัน** → เกิดเศษ partial SELL 0.03 / 0.11 ที่ไม่มี comment (ผลของ `PositionClosePartial` คงไว้)

ที่ user ต้องการคือ **strict sequential**:
1. ปิด/ซอย **เฉพาะ Set#1 (oldest)** จนกว่าจะ flat สมบูรณ์
2. Set#2 รอเงียบๆ ห้าม matching, ห้ามซอย hedge
3. Set#1 flat → ปลด owner → tick ถัดไป Set#2 ค่อยเริ่มทำงาน

นอกจากนี้ user ขอเพิ่ม **Auto Recovery Lot Sizing** สำหรับ Recovery Grid:
- คำนวณ lot อัตโนมัติจาก hedge lots ที่เหลือ
- Series: `InitLot × Multiplier^n` สะสมไปจนใกล้เต็ม remaining hedge lots
- ไม้ที่จะเกิน → cap = `remainingHedgeLots − cumulative` (แต่ห้ามเล็กกว่า minLot)
- ตัวอย่าง: hedge เหลือ 0.5, init 0.05, mult 1.4 → 0.05 + 0.07 + 0.10 + 0.14 = 0.36 → ไม้ถัดไป 0.196 จะเกิน → cap = 0.14

---

## แผนแก้ไข — `public/docs/mql5/Gold_Miner_EA.mq5`

### 1) Version bump → v6.65
อัปเดต `#property version`, `#property description`, header, init/deinit log, dashboard label

### 2) Revert v6.64 "matching every set every tick" → Strict Sequential Matching

แก้ `ManageHedgeSets()` (line 9175-9234):

**กฎใหม่ v6.65:**
- หาว่า set ไหนคือ "active matcher" = `oldest active set` (= set แรกที่ active ตามลำดับ slot/generation)
- เฉพาะ **active matcher set เดียว** เท่านั้นที่รัน:
  - `ManageHedgeMatchingClose()` (รวม partial-hedge fallback ของ v6.64)
  - `ManageHedgeBoundAvgTP()`
  - `ManageHedgePartialClose()`
  - Recovery grid (`TryEnterCombinedGridMode` / `ManageHedgeGridMode`)
- Set อื่นทั้งหมด → **skip ทุกอย่าง** (continue) — รอเงียบๆ ไม่ซอย hedge

วิธีทำ:
```cpp
int activeMatcherIdx = -1;
if(g_sequentialRecoveryActive)
   activeMatcherIdx = g_sequentialRecoverySetIdx;  // owner-locked → owner set
else
   activeMatcherIdx = FindOldestActiveHedgeSet();   // no lock → oldest active

for(int h = 0; h < MAX_HEDGE_SETS; h++)
{
   if(!g_hedgeSets[h].active) continue;
   RefreshBoundTickets(h);
   // ... existing hedge-exists check ...
   
   if(h != activeMatcherIdx)
   {
      // v6.65: Non-active set — wait silently, no matching, no shred, no grid
      g_hedgeSets[h].matchingDone = false;  // ready when its turn comes
      continue;
   }
   
   // === Only active matcher reaches here ===
   if(!IsHedgeCloseAllowed(h)) { g_hedgeSets[h].matchingDone = false; continue; }
   
   // tick retry (v6.64) — keep
   g_hedgeSets[h].matchingDone = false;
   
   if(g_hedgeSets[h].gridMode) { ManageHedgeGridMode(h); continue; }
   
   // Matching cycle (v6.62 strict in-set + v6.64 partial fallback)
   // ... existing STEP 1 + STEP 2 unchanged ...
}
```

ผล:
- Set#1 ซอยจน hedge เหลือ 0 + bound=0 → set deactivate → `SetSequentialRecoveryOwner` ถ้ามี released gen ค้าง → next tick `g_sequentialRecoveryCompletedThisTick` หน่วง 1 tick → tick ถัดไปอีก Set#2 กลายเป็น oldest → เริ่มทำงาน
- ไม่มี Set#2 ซอยพร้อม Set#1 อีกต่อไป → ไม่มี partial remnant ปะปน

### 3) Auto Recovery Lot Sizing — Input Parameters ใหม่
ในกลุ่ม Recovery Grid:
```cpp
input bool   Recovery_AutoLot      = false;  // Auto: คำนวณ lot จาก hedge lots ที่เหลือ
input double Recovery_AutoInitLot  = 0.05;   // Initial lot (Auto mode)
input double Recovery_AutoMult     = 1.4;    // Multiplier (Auto mode)
```

### 4) Helper `ComputeAutoRecoveryLot()` ใหม่
```cpp
// คืน lot ของไม้ recovery ถัดไป; คืน 0 ถ้า budget เต็ม
double ComputeAutoRecoveryLot(double remainingHedgeLots,
                              double existingTotalLots,
                              double lastLot)
{
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double budget  = remainingHedgeLots - existingTotalLots;
   if(budget < minLot) return 0.0;
   
   double baseLot = (lastLot > 0) ? lastLot * Recovery_AutoMult : Recovery_AutoInitLot;
   double nextLot = MathFloor(baseLot / lotStep) * lotStep;
   
   if(existingTotalLots + nextLot > remainingHedgeLots)
   {
      nextLot = MathFloor(budget / lotStep) * lotStep;
      if(nextLot < minLot) return 0.0;
   }
   return nextLot;
}
```

+ helpers: `SumHedgeGridLots(idx)`, `FindLastHedgeGridLot(idx)`, `GetHedgeLotsForGen(gen)`, `SumOrphanGridLots(gen,side)`

### 5) เชื่อม Auto Mode 2 จุด

**A. `ManageHedgeGridMode(idx)`** — ตรงจุดคำนวณ lot ของไม้ถัดไป:
```cpp
double nextLot;
if(Recovery_AutoLot)
{
   double existingLots = SumHedgeGridLots(idx);
   double lastGridLot  = FindLastHedgeGridLot(idx);
   nextLot = ComputeAutoRecoveryLot(g_hedgeSets[idx].hedgeLots,
                                    existingLots, lastGridLot);
   if(nextLot <= 0) return;  // budget เต็ม → รอ
}
else { /* logic เดิม v6.x */ }
```

**B. `ManageOrphanGrid()`** — แทน `ComputeRecoveryGridLot(maxExisting, glb)` เมื่อ auto:
```cpp
double lots;
if(Recovery_AutoLot)
{
   double remHedge = GetHedgeLotsForGen(gen);
   double exist    = SumOrphanGridLots(gen, side);
   lots = ComputeAutoRecoveryLot(remHedge, exist, maxExisting);
   if(lots <= 0) continue;
}
else { lots = ComputeRecoveryGridLot(maxExisting, glb); }
```

### 6) Dashboard ปรับให้ user เห็นชัด
```text
Hedge Recovery | Active Matcher: H1 | Waiting: H2, H3
Recovery Grid  | Auto:ON Init=0.05 Mult=1.4 | H1 used 0.36/0.50
```
(เมื่อ `Recovery_AutoLot=false` → แสดงแบบเดิม)

### 7) Logging
```text
v6.65 STRICT SEQ: matcher=Set#1 H1 | other 2 set(s) waiting
v6.65 AUTO LOT Set#1: rem=0.50 used=0.36 last=0.14 -> next=0.14 (capped)
v6.65 AUTO LOT Set#1: BUDGET FULL (0.50/0.50) -> skip
```

---

## สิ่งที่ไม่เปลี่ยนแปลง

- Order Execution: `OpenOrder` / `trade.PositionClose` / `trade.PositionClosePartial` — ไม่แก้
- Trading Strategy / Signal / Initial Grid / Grid Loss / Grid Profit (normal) — ไม่แก้
- `ManageHedgeMatchingClose()` v6.62 strict in-set + v6.64 partial fallback — ไม่แก้ logic ภายใน
- `ManageHedgeBoundAvgTP()` / `ManageHedgePartialClose()` — ไม่แก้
- Hedge open trigger / Triple Gate / DD threshold / Reverse — ไม่แก้
- Sequential Recovery Owner v6.59-v6.60 (claim/clear) — ไม่แก้ (แค่ scope ขยายไป cover matching ด้วย)
- `FindFreeHedgeSlot()` v6.63 persistent numbering — ไม่แก้
- Re-hedge guard / BB Filter / Existing recovery distance/candle confirm — ไม่แก้
- Accumulate Close / Balance Guard / News / License / Time Filter — ไม่แก้

## Validation Checklist

1. มี Set#1 + Set#2 active พร้อมกัน → log ต้องแสดง `matcher=Set#1` และ Set#2 ห้ามมี matching/partial log
2. Set#1 hedge ถูกซอยลงเรื่อยๆ → Set#2 hedge lots ห้ามเปลี่ยน
3. Set#1 flat → ปลด owner → tick ถัดไป Set#2 กลายเป็น matcher → เริ่มซอย
4. ห้ามมีเศษ partial SELL/BUY ไม่มี comment เกิดจาก 2 set พร้อมกัน
5. `Recovery_AutoLot=false` → behavior เหมือน v6.64 (regression)
6. `Recovery_AutoLot=true`, hedge 0.5/init 0.05/mult 1.4 → ออก grid 0.05→0.07→0.10→0.14→0.14(cap)→stop
7. ผลรวม recovery grid lots ≤ remaining hedge lots ทุกขณะ
8. ถ้า hedge ถูกซอยลงระหว่างทาง → ไม้ recovery ใหม่คำนวณจาก remainingHedgeLots ปัจจุบัน

