# Hero Order v6.96 — Opposite-Side Helper + Lock-Profit BE-SL

## หลักการ (สรุปจากผู้ใช้ ครั้งสุดท้าย)

**Hero Order** = ตัวช่วยปิดฝั่งตรงข้าม + ทำกำไรก้อนใหญ่
**BE-SL** = lock-profit (วางฝั่งกำไรเทียบ openPrice) ไม่ใช่ stop loss

หลังจาก same-side basket ปิดด้วย Avg TP/Trail แล้ว Hero จะมีกำไรอยู่แล้ว
→ ตรึง SL ฝั่งกำไรเพื่อป้องกันราคาดีดกลับมากินกำไร
→ "รอ" opposite-side basket ปิด แล้วปิด Hero พร้อมกัน เพื่อทำกำไรสูงสุด

---

## Lock-Profit BE-SL (สูตรถูกต้อง)

| Hero Side | ราคาเคลื่อนทำกำไรไปทาง | BE-SL วางที่ | ตรรกะ |
|---|---|---|---|
| **SELL** | ลง | `openPrice - offset` (**ใต้** เปิด) | เด้งขึ้นชน SL = ปิดได้กำไรเล็กน้อย |
| **BUY** | ขึ้น | `openPrice + offset` (**เหนือ** เปิด) | ย่อลงชน SL = ปิดได้กำไรเล็กน้อย |

**Sanity guard ก่อนใส่ SL** (ป้องกัน broker reject):
- SELL: ต้อง `newSL < ask - stops_level` และ `newSL < ask` (อยู่ฝั่งกำไรของ SELL จริง)
- BUY: ต้อง `newSL > bid + stops_level` และ `newSL > bid`
- ถ้าราคาดีดกลับเร็วเกินจน sanity fail → skip + retry tick ถัดไป (จะไม่บังคับใส่ SL ฝั่งขาดทุน)

---

## State Machine

| Phase | Trigger | Hero TP/SL | ตัวปิด Hero |
|---|---|---|---|
| **NONE** | side count < `MinActivate` | – | – |
| **PRE_STAGE** | count > basketCount, basket alive | strip ทั้ง TP+SL | – |
| **ARMED_WAITING** | count ≥ `MinActivate`, basket alive | strip (จำไว้) | – |
| **BE_GUARD** | same-side basket = 0 (basket หลักปิดเสร็จ) | ✅ ใส่ lock-profit BE-SL | **opposite-close** OR BE-SL hit (fallback) |

---

## เงื่อนไขปิด Hero

### Primary: Opposite-Side Basket Close
1. Hero อยู่ใน BE_GUARD (มี lock-profit SL แล้ว)
2. ฝั่งตรงข้าม (opposite) basket ชน Avg TP / MaxGrid Trail / Profit$ TP
3. Hook ก่อน `CloseGenSide(closingSide)`: ถ้า `g_heroLockedSide == oppositeSide && phase == BE_GUARD`
   → `PositionClose()` ทุก Hero ของ oppositeSide ก่อน
4. กำไร Hero (ก้อนใหญ่ + lock profit ที่สะสมเพิ่มเรื่อยๆ จากราคาที่วิ่งต่อ) → ทบรวมในยอดรวม

### Fallback: BE-SL Hit
- ถ้าราคาเด้งกลับเร็วผิดคาด ก่อน opposite ปิด → broker ปิดที่ lock-profit price
- Hero แต่ละตัวยังได้ "กำไรขั้นต่ำ" ตาม OffsetPoints

---

## Rolling Hero Slot

`basketCount = totalOnSide - InpHero_OrderCount`
`heroCount   = MathMin(InpHero_OrderCount, totalOnSide - 0)` ถ้า count ≥ MinActivate

- order index > basketCount → tag เป็น Hero (strip TP/SL)
- order index ≤ basketCount → basket ปกติ (มี broker TP/SL)
- เมื่อมี order ใหม่เปิด → ตัวเก่าสุดของ "Hero zone" คืนสู่ basket (restore TP/SL), ตัวใหม่เป็น Hero

หมายเหตุ: rolling นี้ทำงานใน phase PRE_STAGE / ARMED_WAITING เท่านั้น
ใน BE_GUARD: lock Hero set เดิม ไม่มี rolling อีก (เพราะ basket = 0 แล้ว, ไม่มีอะไรให้ promote)

---

## Single-Side Exclusive Lock

- `g_heroLockedSide ∈ {-1, BUY, SELL}`
- ตั้งค่าเมื่อฝั่งใดฝั่งหนึ่งเข้า PRE_STAGE ครั้งแรก
- ฝั่งตรงข้ามจะไม่มี Hero (ทำงาน basket ปกติ → จะเป็นตัวปิด Hero ภายหลัง)
- ปลด lock เมื่อ Hero side flat สมบูรณ์

---

## Inputs (v6.96)

```cpp
input group "═══════ Hero Order ═══════"
input bool InpHero_Enable              = false;
input int  InpHero_MinOrdersToActivate = 10;
input int  InpHero_OrderCount          = 3;
input int  InpHero_BE_OffsetPoints     = 50;   // lock-profit offset (points)
```

**Deprecate (no-op, เก็บ .set compat):**
`InpHero_TrailStartPips`, `InpHero_TrailStepPips`, `InpHero_CloseWithOpposite`

---

## Technical (`public/docs/mql5/Gold_Miner_EA.mq5`)

### Globals ใหม่
```cpp
int  g_heroLockedSide    = -1;
int  g_heroPhase_Buy     = 0;   // 0=NONE 1=PRE 2=ARMED 3=BE_GUARD
int  g_heroPhase_Sell    = 0;
bool g_heroBE_Applied_Buy  = false;
bool g_heroBE_Applied_Sell = false;
ulong g_heroTickets_Buy[];
ulong g_heroTickets_Sell[];
```

### Helpers ใหม่
```cpp
void  BuildHeroTicketCache();                       // rolling tag, single-side guard
void  StripBrokerTPSLFromHeroTickets();             // PRE/ARMED → strip
void  RestoreBasketTPSLForExHeroTickets();          // rolling: ex-Hero คืน TP/SL
bool  DetectSameSideBasketClearedForHero(int side); // basket=0, hero>0 → BE_GUARD
void  ApplyHeroLockProfitSL(int side);              // ใส่ lock-profit SL ครั้งเดียว
double ComputeHeroLockProfitSL(int posType, double openPrice); // SELL: open-offset, BUY: open+offset
bool  ValidateLockProfitSL(int posType, double sl, double ask, double bid, int stopsLevel);
void  CloseOppositeHeroOnBasketClose(int closingSide); // PositionClose() Hero ฝั่งตรงข้าม
void  ResetHeroStateIfFlat(int side);
```

### OnTick flow
```cpp
BuildHeroTicketCache();                  // rolling + single-side lock
StripBrokerTPSLFromHeroTickets();        // PRE/ARMED phase
RestoreBasketTPSLForExHeroTickets();     // rolling restore

for(side in {BUY, SELL}) {
   if(DetectSameSideBasketClearedForHero(side) && !g_heroBE_Applied[side]) {
      ApplyHeroLockProfitSL(side);       // SELL→under, BUY→above
      g_heroPhase[side]      = BE_GUARD;
      g_heroBE_Applied[side] = true;
   }
   ResetHeroStateIfFlat(side);           // unlock when fully closed
}
```

### Hook ก่อน opposite-side basket close
```cpp
// ทุกจุดที่จะเรียก CloseGenSide(closingSide):
if(InpHero_Enable) {
   int opp = (closingSide == 0/*BUY*/) ? 1/*SELL*/ : 0/*BUY*/;
   if(g_heroLockedSide == opp && g_heroPhase[opp] == BE_GUARD) {
      CloseOppositeHeroOnBasketClose(closingSide);  // ปิด Hero ฝั่ง opp ก่อน
   }
}
CloseGenSide(closingSide);  // logic เดิม ห้ามแตะ
```

### จุดอื่นที่ต้องแก้ (existing functions)
1. `SyncBrokerTPSL()` — `if(IsHeroTicket(t)) continue;` (ไม่ overwrite lock-profit SL)
2. `CalculateTotalLots()` / avg helpers — exclude Hero
3. `CountGenGridLoss()` / MaxGrid trail trigger — exclude Hero
4. `ApplyTrailingSL` / `ApplyTrailingSL_TF` — Hero skip (จาก v6.93 — คงไว้)
5. `ShouldBlockSameSideGridForHero` — block same-side new INIT/GL/GP เฉพาะตอน BE_GUARD (Hero รออย่างเดียว ไม่ขยาย grid)
6. `BuildHeroTicketCache` — guard `side != g_heroLockedSide` ห้าม tag

### Dashboard
```text
Hero  : Lock=SELL  phase=ARMED   basket=7  hero=3   BE: WAITING
Hero  : Lock=SELL  phase=BE_GUARD basket=0  hero=3   BE @ 1999.50/1999.30/1999.10  (lock-profit)
        ↳ Waiting for BUY basket to close
```

### Version: `#property version "6.96"` + header + dashboard + log prefix

---

## ตัวอย่าง Flow (SELL Hero, เปิดที่ 2000, offset=50pt=0.50)

```text
T1-T3: SELL 1..10 → ARMED, Hero #8(2000.00) #9(2000.40) #10(2000.80) — strip TP/SL
T4: ราคา 1995 → SELL basket #1..#7 ชน Avg TP → ปิด
T5: phase → BE_GUARD
    Lock-profit SL:
      Hero #8  @ 2000.00 - 0.50 = 1999.50
      Hero #9  @ 2000.40 - 0.50 = 1999.90
      Hero #10 @ 2000.80 - 0.50 = 2000.30
    (ทุกตัวอยู่ใต้ราคาตลาด 1995 → sanity ผ่าน)
T6: ราคาลงต่อ 1985 → Hero กำไรเพิ่ม, BUY เปิด grid เพิ่ม
T7: ราคาเด้งขึ้น 1992 → BUY basket ชน Avg TP
T8: Hook → CloseOppositeHeroOnBasketClose(BUY)
    ปิด Hero SELL ทั้ง 3 ตัว @ 1992 → กำไรเต็ม ๆ
    ปิด BUY basket → กำไรรวมสูงสุด
T9: flat → reset state, unlock

Edge case: T5→T6 ราคาเด้งจาก 1995 ขึ้น 1999.50 ทันที
  → Hero #8 ชน lock-profit SL → broker ปิดที่ 1999.50 (กำไร 0.50)
  → Hero #9, #10 ยังอยู่ รอต่อ
```

---

## สิ่งที่ไม่เปลี่ยน (กฎเหล็ก)

- ❌ OrderSend / trade.Buy/Sell/PositionClose execution semantics
- ❌ Entry conditions / SMA / Squeeze / BB / Z-Score
- ❌ Grid Loss/Profit lot/distance/candle confirm
- ❌ Hedge / Triple-Gate / Matching close / Recovery
- ❌ DD% TP / Daily Target / Balance Guard
- ❌ Trailing-stop value calculation (ของ basket หลัก)
- ❌ License / News / Time / Sync
- ❌ Squeeze Pause Trailing v6.87–v6.91
- ❌ MaxGrid Strict 2-Cross v6.91
- ❌ `CloseGenSide()` body (แค่เพิ่ม pre-call hook)

---

## Memory Updates
- ใหม่: `mem://trading/gold-miner-ea/hero-opposite-helper-lockprofit-v6-96`
- Deprecate: v6.92/v6.93/v6.94/v6.95 (logic Hero เปลี่ยนหมด)

---

## Test Checklist

`MinActivate=10, OrderCount=3, BE_OffsetPoints=50`

**Path A — Primary (opposite close)**:
1. ราคาขึ้น → SELL 1..10 → ARMED, Hero #8/#9/#10 ไม่มี SL
2. BUY มีออเดอร์รออยู่ติดลบ
3. ราคาดีดลง → SELL basket #1..#7 ปิดด้วย Avg TP
4. log `BE_GUARD applied: SL=1999.50/1999.90/2000.30 (lock-profit)`
5. ตรวจในตลาด — SL ทุกตัวอยู่ **ใต้** open price ของ SELL ✅
6. ราคาลงต่อ → Hero กำไรเพิ่ม, BUY grid ขยาย
7. ราคาเด้งขึ้น → BUY basket ชน Avg TP
8. log `Hero CLOSE: opposite-basket close (BUY) → close 3 SELL Heroes`
9. ปิดพร้อมกัน → flat → unlock

**Path B — Fallback (lock-profit hit)**:
1. ทำซ้ำ 1-5 → BE_GUARD ใส่ SL เสร็จ
2. ราคาเด้งกลับขึ้นแรง → ชน lock-profit SL ทีละตัว
3. แต่ละตัวปิดด้วยกำไร = OffsetPoints × lot value (ไม่ใช่ขาดทุน) ✅

**Path C — Sanity guard**:
1. T4-T5 ราคาเด้งจาก 1995 → 2001 ทันที (เร็วเกิน)
2. ComputeLockProfitSL ของ Hero #8 = 1999.50 < ask 2001 → ผ่าน → ใส่ SL
3. ของ Hero #10 = 2000.30 < 2001 → ผ่าน → ใส่ SL
4. ถ้าเร็วเกินจน 1999.50 > ask แล้ว → skip ตัวนั้น, retry tick ถัดไป (ไม่บังคับใส่ฝั่งขาดทุน)

**Single-Side Lock**:
- SELL ARMED → BUY เปิดเพิ่ม → BUY ทุกตัวเป็น basket ปกติ ไม่มี Hero
- SELL flat ทั้งหมด → unlock

---

ขออนุมัติแผนเวอร์ชันแก้ทิศ BE-SL ให้เป็น lock-profit ครับ