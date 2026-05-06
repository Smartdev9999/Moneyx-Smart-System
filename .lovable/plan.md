## ปัญหาที่พบ (v1.45)

จากภาพ: หลัง Hero BUY ตัวเก่าปิดไปแล้ว (ราคาวิ่งลง → SELL TP + Hero BUY ปิด) ระบบกลับ **tag Hero BUY ใหม่อีกรอบ** แทนที่จะสลับให้ SELL เป็น Hero ฝั่งใหม่ (เพราะตอนนี้ SELL คือฝั่งที่กำลังถือออเดอร์เพิ่มจากราคาวิ่งลงต่อ)

สาเหตุ: หลัง `CloseHeroOnSide(BUY)` ระบบแค่ stamp `g_heroJustClosed_Buy` + grace 5 วินาที. เมื่อพ้น grace แล้ว BUY ฝั่งเดิมยังเข้าเกณฑ์ activation ได้ทันทีถ้าจำนวน BUY orders ≥ threshold → BUY กลายเป็น Hero ซ้ำ. ไม่มีกลไก "ฝั่งที่เพิ่งปิด Hero ต้องรอให้ฝั่งตรงข้ามได้เป็น Hero ก่อน หรือรอให้ตัวเองกลับมา flat สนิท"

## สเปกที่ถูกต้อง (ยืนยัน)

```
Hero ทำงานฝั่งเดียวในเวลาเดียวกัน
หลัง Hero side X ปิด (CloseHeroOnSide):
  → side X ห้าม re-arm เป็น Hero candidate อีก
  → จนกว่าจะเกิดเหตุการณ์ใดเหตุการณ์หนึ่ง:
     (a) side Y (ตรงข้าม) ถึงเกณฑ์ → กลายเป็น Hero candidate / owner
     (b) side X กลับมา flat สนิท (no positions both Hero+normal) → reset
```

## แผนแก้ไข v1.46 (Hero Side-Alternation Lock — port v7.09 + เพิ่ม alternation guard)

### 1. State ใหม่
- `int g_heroLastClosedSide = -1;` — จำว่า Hero ฝั่งไหนเพิ่งปิดล่าสุด (0=BUY, 1=SELL, -1=none)
- ตั้งค่าใน `CloseHeroOnSide(side, ...)` ทันทีหลัง stamp `g_heroJustClosed_*`

### 2. Activation guard ใน `BuildHeroTicketCache()` (หลัง Post-close grace บรรทัด 415–418, ก่อน activation gate บรรทัด 420)
```
// v1.46 Side-Alternation Lock — ฝั่งที่เพิ่งปิด Hero ห้าม re-arm
//        จนกว่าฝั่งตรงข้ามจะ ARMED/BE_GUARD หรือฝั่งนี้ flat สนิท
if(InpHero_AlternateSides && g_heroLastClosedSide >= 0
   && sideId == g_heroLastClosedSide && curPhase == 0)
{
   int oppSideId = (sideId == POSITION_TYPE_BUY) ? POSITION_TYPE_SELL : POSITION_TYPE_BUY;
   int oppPhase  = (oppSideId == POSITION_TYPE_BUY) ? g_heroPhase_Buy : g_heroPhase_Sell;
   bool oppActive = (oppPhase == 2 || oppPhase == 3);
   bool selfFlat  = (CountHeroOnSide((ENUM_POSITION_TYPE)sideId) == 0
                  && CountNonHeroMainOnSide((ENUM_POSITION_TYPE)sideId) == 0);
   if(!oppActive && !selfFlat) {
      if(sideId == POSITION_TYPE_BUY) g_heroPhase_Buy = 0; else g_heroPhase_Sell = 0;
      continue;
   }
   // เคลียร์ alternation เมื่อเงื่อนไขปลด lock เกิดขึ้น
   if(oppActive || selfFlat) g_heroLastClosedSide = -1;
}
```

### 3. Input ใหม่
```
input bool InpHero_AlternateSides = true; // v1.46 — บังคับสลับฝั่ง Hero หลังปิด
```

### 4. Reset `g_heroLastClosedSide`
- ใน `ResetHeroStateIfFlat(side)`: ถ้า side == g_heroLastClosedSide และทั้งคู่ flat → `g_heroLastClosedSide = -1`
- ใน Cost-Hit Restart cycle reset (ถ้ามี) — เคลียร์ด้วย

### 5. Dashboard "Hero Cfg" row (บรรทัด ~1395)
- เพิ่มสตริง `Alt=ON/OFF` ต่อท้าย `Lock=STRICT`
- เพิ่มแถวใหม่ "Last Closed: BUY/SELL/-" (สีเทา) เมื่อ `g_heroLastClosedSide >= 0`

### 6. Audit log (บรรทัด 482–488)
- เพิ่ม `lastClosed=BUY/SELL/-` ใน Print ทุก 30 วิ

### 7. Version bump → v1.46
- `#property version "1.46"`, `#property description`, header, OnInit/OnDeinit, Dashboard title

### 8. Memory + Plan
- สร้าง `.lovable/memory/trading/golden-kuy3/v1-46-hero-side-alternation.md`
- อัปเดต `mem://index.md` + `.lovable/plan.md`

## Flow ที่คาดหวัง
1. SELL ปกติเปิดเยอะ → ราคาวิ่งขึ้น → SELL ARMED → BE_GUARD → BUY ปกติโดน TP → Hero SELL ปิด → `g_heroLastClosedSide = SELL`
2. ราคาวิ่งกลับลง → BUY orders เปิดเพิ่ม → ถึง threshold
3. **SELL ห้าม re-arm** (lastClosed=SELL, opp BUY ไม่ active, SELL ยัง flat ไม่สนิท ถ้ายังเหลือ orders) → BUY กลายเป็น Hero candidate ตามสเปก
4. ถ้า BUY ARMED/BE_GUARD → เคลียร์ `g_heroLastClosedSide = -1`

## ไม่เปลี่ยน (กฎเหล็ก)
- ❌ OrderSend / `trade.*` / OpenInitial / OpenGrid / Manage*Entry / CalcGridLot
- ❌ Per-Order BE/Trail / Avg-Trail strict-2-cross / TP modes / Accumulate Close v1.42 / Cost-Hit Restart
- ❌ `StripBrokerTPSLFromHeroTickets` v1.44 (TP only, SL kept)
- ❌ `ComputeHeroLockProfitSL` / `ApplyHeroLockProfitSL` (BE_GUARD path)
- ❌ `BuildHeroTicketCache` price-extreme sort v1.43
- ❌ `DetectSameSideBasketClearedForHero` / `ManageHeroOppositeClose` flow
- ❌ v1.45 CANDIDATE-vs-OWNER separation (GetHeroOwnerSide BE_GUARD-only)
- `InpHero_Enabled=false` หรือ `InpHero_AlternateSides=false` → พฤติกรรม = v1.45
