
## v6.66 — Auto Recovery: Reverse-Walk Seed + Combined Avg TP + Max Grid Cap

### ความเข้าใจที่ถูกต้อง (สรุปจาก user ทั้ง 2 ข้อความ)

**A. Reverse-Walk Seed Lot** (จากข้อความก่อน)
- hedge เหลือ 0.50, init=0.05, mult=1.4
- Series: `0.05+0.07+0.10+0.14+0.20 = 0.56` → เกิน 0.50 ที่ตัว `0.20`
- **seed = 0.20** → `GM_HG1_GL1 = 0.20`
- ไม้ถัดไป = `0.20 × 1.4 = 0.28` (`GM_HG1_GL2`) คูณต่อไปเรื่อยๆ

**B. One-Time Shred + Combined Avg TP** (จากข้อความก่อน)
- ซอยปิด hedge ทำครั้งเดียวตอน matching ปลด set
- หลังจากนั้น hedge ที่เหลือ + recovery grid → คำนวณ avg price รวม → ตั้ง TP เดียวตาม `TP_Points/Dollar/PercentBalance`

**C. Max Grid Cap จาก `Recovery_MaxGridTrades`** (จากข้อความล่าสุด + image-900)
- input ที่มีอยู่แล้ว `Recovery_MaxGridTrades = 10` (กลุ่ม Recovery Grid)
- ใช้เป็นเพดานจำนวนไม้สูงสุดของ recovery grid ทั้ง **Auto Recovery** และ **Manual mode** (GridLoss_*)
- เมื่อจำนวน HG_GL ของ set ครบ `Recovery_MaxGridTrades` → ห้ามออกเพิ่ม

---

## แผนแก้ไข — `public/docs/mql5/Gold_Miner_EA.mq5`

### 1) Version bump → v6.66
อัปเดต `#property version`, `#property description`, header, init/deinit log, dashboard label

### 2) Reverse-Walk Seed Lot (Auto Recovery)

#### Helper ใหม่: `ComputeAutoSeedLot(double remHedgeLots)`
```cpp
// คืน seed = ไม้ใน series init*mult^n ที่ทำให้ cumulative เกิน remHedgeLots ครั้งแรก
double ComputeAutoSeedLot(double remHedgeLots)
{
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(remHedgeLots < minLot) return minLot;

   double curLot = Recovery_AutoInitLot;
   double cum    = 0.0;
   double prev   = curLot;
   int    safety = 0;
   while(safety++ < 200)
   {
      double normLot = MathFloor(curLot / lotStep) * lotStep;
      if(normLot < minLot) normLot = minLot;
      cum += normLot;
      if(cum > remHedgeLots) return normLot;   // seed
      prev   = normLot;
      curLot = normLot * Recovery_AutoMult;
   }
   return prev;
}
```

#### Helper: `ComputeAutoNextLot(double lastGridLot)`
```cpp
double next = MathFloor((lastGridLot * Recovery_AutoMult) / lotStep) * lotStep;
return MathMax(next, minLot);
```

#### เชื่อม 2 จุด (แทน budget-cap ของ v6.65 ทิ้ง)

**A. `ManageHedgeGridMode(idx)`**
```cpp
double lastGridLot = FindLastHedgeGridLot(idx);
double nextLot = (lastGridLot <= 0)
                 ? ComputeAutoSeedLot(g_hedgeSets[idx].hedgeLots)
                 : ComputeAutoNextLot(lastGridLot);
```

**B. `ManageOrphanGrid()` BUY/SELL** — เหมือนกัน ใช้ `GetHedgeLotsForGen(gen)` + `maxExisting`

### 3) Max Grid Cap — บังคับใช้ทั้ง Auto + Manual

ก่อนเปิดไม้ recovery grid ทุกจุด เพิ่ม guard:
```cpp
int gridCount = CountHedgeGridOrders(idx);   // นับ GM_HG{idx+1}_GL*
if(gridCount >= Recovery_MaxGridTrades)
{
   // throttled log: "v6.66 MAX GRID Set#X reached N/N — wait for TP"
   return;
}
```

ใส่ใน:
- `ManageHedgeGridMode(idx)` (Auto + Manual mode ใช้ทางเดียวกัน)
- `ManageOrphanGrid()` BUY + SELL (นับ HG_GL ของ gen ที่ผูก)

ไม่แก้ logic ของ `Recovery_MaxGridTrades` เดิม — เพียงให้บังคับใช้กับ Auto mode ด้วย (ก่อนหน้านี้ Auto skip cap นี้)

### 4) One-Time Shred Flag

เพิ่ม field ใน `HedgeSet`:
```cpp
bool shredCompleted;
```

แก้ `ManageHedgeMatchingClose(idx)`:
- หลัง partial-close hedge สำเร็จครั้งแรก → `g_hedgeSets[idx].shredCompleted = true`
- รอบถัดไป ถ้า `shredCompleted == true` → **skip partial close** ของ hedge → ไป Combined TP path
- Full-loss matching greedy ยังทำได้ (ล้าง bound/reverse profit)

Persist: `GlobalVariableSet("GME_HEDGE_SHRED_" + idx, 1)`

### 5) Combined Average TP

#### Input ใหม่
```cpp
input bool Recovery_UseCombinedTP = true;
```

#### Helper `SyncRecoveryBasketTP(int idx)`
1. เก็บ tickets: hedge ticket หลักที่เหลือ + ทุก position ที่ comment ขึ้นต้น `GM_HG{idx+1}_GL`
2. Weighted avg: `avg = Σ(price × lots) / Σ(lots)`
3. คำนวณ TP target ฝั่ง `hedgeSide`:
   - `UseTP_Points` → `avg ± TP_Points × point`
   - `UseTP_Dollar` → ระยะ `= TP_DollarAmount / (totalLots × tickValue / tickSize)`
   - `UseTP_PercentBalance` → `balance × TP_PercentBalance / 100` แปลงเป็นระยะ
4. `trade.PositionModify(ticket, sl, tpNew)` ทุก ticket ใน basket → TP เดียวกัน

เรียกใน `ManageHedgeSets()` หลัง matching cycle เฉพาะ `activeMatcherIdx` ที่:
- `shredCompleted == true` หรือมี HG_GL อยู่แล้ว
- มี `hedgeLots > 0` หรือ `SumHedgeGridLots(idx) > 0`

ไม่กระทบ `SyncBrokerTPSL()` ของ basket หลัก

### 6) Comment Residue Fallback
- `OpenHedge()` → `GlobalVariableSet("GME_HEDGE_TICKET_" + idx, (double)ticket)`
- `RecoverHedgeSetsFromOpenPositions()` → อ่าน GlobalVar ก่อน scan comment
- Scan loops fallback: `ticket == g_hedgeSets[h].hedgeTicket`

### 7) Dashboard
```text
Recovery Grid | Auto:ON Init=0.05 Mult=1.40 | H1 seed=0.20 next=0.28 lvl=2/10
Recovery TP   | Combined ON | H1 avg=4763.21 lots=0.68 TP=4768.45
Shred Status  | H1 DONE | H2 PENDING
```

### 8) Logging
```text
v6.66 SEED Set#1: rem=0.50 series=0.05+0.07+0.10+0.14+0.20=0.56 -> seed=0.20
v6.66 NEXT Set#1: last=0.20 -> 0.28
v6.66 MAX GRID Set#1 reached 10/10 — wait for TP
v6.66 SHRED DONE Set#1: shred locked, switching to Combined TP
v6.66 RECOVERY TP Set#1: avg=4763.21 totalLots=0.68 tp=4768.45
```

---

## สิ่งที่ไม่เปลี่ยนแปลง

- Order Execution wrapper / `trade.Buy` / `trade.Sell` / `trade.PositionClose` / `trade.PositionClosePartial` — ไม่แก้
- Trading Strategy / Signal / Initial Grid / Grid Loss / Grid Profit (basket หลัก) — ไม่แก้
- `SyncBrokerTPSL()` ของ basket หลัก — ไม่แก้
- `ManageHedgeMatchingClose()` greedy logic v6.62 strict in-set — ไม่แก้ (เพิ่มแค่ shred flag guard)
- `ManageHedgeBoundAvgTP()` / `ManageHedgePartialClose()` — ไม่แก้
- Hedge open trigger / Triple Gate / DD threshold / Reverse — ไม่แก้
- Strict Sequential Matching v6.65 (one matcher per tick) — ไม่แก้
- Sequential Recovery Owner v6.59-v6.60 — ไม่แก้
- `FindFreeHedgeSlot()` v6.63 persistent numbering — ไม่แก้
- BB Filter / Recovery distance / candle confirm / Re-hedge guard — ไม่แก้
- Accumulate Close / Balance Guard / News / License / Time Filter — ไม่แก้
- input `Recovery_MaxGridTrades` เดิม — ไม่เปลี่ยนค่า/ความหมาย เพียงบังคับใช้กับ Auto mode

## Validation Checklist

1. hedge 0.50, init 0.05, mult 1.4 → series sum 0.56 → seed=0.20, ถัดไป 0.28, 0.392 ...
2. ไม้ recovery ครบ `Recovery_MaxGridTrades` → หยุด ไม่ว่า Auto หรือ Manual
3. Max cap log ขึ้นแบบ throttled (ไม่ spam)
4. Partial close ครั้งแรก → `shredCompleted=true` → ไม่ซอยซ้ำ
5. Combined TP: hedge + HG_GL ทุกตัวมี TP เดียวกันบน broker; แตะ TP → broker ปิด basket ทั้งก้อน
6. เปลี่ยน `TP_Points` ระหว่างทาง → recovery basket TP อัปเดตใน tick ถัดไป
7. `Recovery_AutoLot=false` → regression เหมือน v6.65 (Manual) แต่บังคับ MaxGrid เหมือนเดิม
8. `Recovery_UseCombinedTP=false` → ไม่ตั้ง TP รวม
9. Strict sequential v6.65 ยังทำงาน — Set#2 ไม่ทำขณะ Set#1 ยัง active
10. Restart EA → อ่าน `GME_HEDGE_TICKET_*` + `GME_HEDGE_SHRED_*` → state กลับมาตรง
