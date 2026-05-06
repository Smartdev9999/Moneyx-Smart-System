## ปัญหาที่พบ (v1.44)

จากภาพ Dashboard: `Hero Owner = SELL (locked)` ตั้งแต่ฝั่ง SELL ถึงเกณฑ์จำนวนออเดอร์ (active=44/15) — แต่ basket ปกติของ SELL **ยังไม่ปิด** เลย ฝั่งนั้นยังไม่ควรถูกล็อกเป็น Hero Owner ตามสเปกของผู้ใช้

สาเหตุอยู่ที่ `GetHeroOwnerSide()` (บรรทัด 263–268) และ STRICT dual-side guard ใน `BuildHeroTicketCache()` (บรรทัด 352–368): ทั้งสองตัวถือว่า `phase != 0` (รวม `ARMED=2`) คือเจ้าของ → พอฝั่งใดถึงเกณฑ์ก่อนก็ลบสถานะอีกฝั่งทิ้ง และล็อกว่าเป็น OWNER ทันที

## สเปกที่ถูกต้อง (ยืนยัน)

```
ARMED  (CANDIDATE) = side ถึงเกณฑ์ → tag Hero, strip TP only (SL เดิมคงอยู่)
                     → ทั้ง BUY และ SELL อาจอยู่ ARMED พร้อมกันได้
                     → ยังไม่ใช่ Owner, ยังไม่ล็อกฝั่งใด
BE_GUARD (OWNER)   = basket ปกติฝั่งเดียวกันปิดหมดแล้ว → apply lock-profit BE-SL
                     → ตอนนี้เท่านั้นที่ Single-Side Lock บล็อกอีกฝั่ง
```

## แผนแก้ไข v1.45 (Hero CANDIDATE vs OWNER Separation — port v7.07)

### 1. `GetHeroOwnerSide()` (บรรทัด 263–275)
- เปลี่ยน `buyOwns = (g_heroPhase_Buy != 0)` → `buyOwns = (g_heroPhase_Buy == 3)`
- เปลี่ยน `sellOwns = (g_heroPhase_Sell != 0)` → `sellOwns = (g_heroPhase_Sell == 3)`
- คืน `-1` ถ้าไม่มีฝั่งใดถึง BE_GUARD (แม้ว่าจะมีฝั่งหนึ่งหรือทั้งคู่เป็น ARMED)

### 2. `BuildHeroTicketCache()` PRE-GUARD dual-side (บรรทัด 350–368)
- **ลบ** บล็อก PRE-GUARD ที่บังคับ `g_heroPhase_*=0` เมื่อทั้งสองฝั่ง `phase != 0`
- ทั้ง BUY และ SELL **อยู่ ARMED พร้อมกันได้** จนกว่าฝั่งใดฝั่งหนึ่งจะถึง BE_GUARD
- คงเฉพาะ guard กรณีทั้งสองฝั่ง `phase == 3` พร้อมกัน (เคสหายาก) → keep ฝั่งที่มี orders มากกว่า

### 3. STRICT activeOwner gate (บรรทัด 370–371, 429–432, 458–459)
- `activeOwner = GetHeroOwnerSide()` (ตอนนี้คืน BE_GUARD only ตามข้อ 1)
- บรรทัด 458–459: **ลบ** การ "อัปเดต activeOwner ทันที" เมื่อ side ถึงเกณฑ์ (เพราะแค่ ARMED ยังไม่ได้เป็น owner)
- → side ที่สองยังเข้าถึงเกณฑ์และ tag Hero ได้ตามปกติ จนกว่าฝั่งใดฝั่งหนึ่งจะ BE_GUARD จริง

### 4. Dashboard Hero Owner row (บรรทัด 1406–1410)
- แสดง `NONE (waiting close)` (สีเหลือง) เมื่อมี side ใด ARMED แต่ยังไม่มีใคร BE_GUARD
- แสดง `BUY/SELL (locked)` (สี gold) เฉพาะเมื่อมี real OWNER (BE_GUARD)
- (ตอนนี้ logic ใน 1409–1410 ใช้ helper `GetHeroOwnerSide()` อยู่แล้ว — แค่ helper คืนค่าใหม่ก็ทำงานถูกอัตโนมัติ)

### 5. Audit log (บรรทัด 486–488)
- คงรูปแบบ `roleB/roleS = OWNER/CANDIDATE/NONE` เดิม — ตอนนี้จะถูกต้องตามสเปก

### 6. Version bump → v1.45
- `#property version "1.45"`, `#property description`, header comment, OnInit/OnDeinit Print, Dashboard title, "Hero Cfg" row

### 7. Memory + Plan
- สร้าง `.lovable/memory/trading/golden-kuy3/v1-45-hero-candidate-vs-owner.md`
- อัปเดต `mem://index.md`
- อัปเดต `.lovable/plan.md`

## สิ่งที่ไม่เปลี่ยน (กฎเหล็ก)
- ❌ OrderSend / `trade.Buy` / `trade.Sell` / `trade.PositionClose`
- ❌ `OpenInitial` / `OpenGrid` / `Manage*Entry` / `CalcGridLot`
- ❌ Per-Order BE/Trail สูตร, Avg-Trail strict-2-cross
- ❌ TP modes / Accumulate Close + cycle-reset v1.42 / Cost-Hit Restart
- ❌ `StripBrokerTPSLFromHeroTickets` (v1.44 — strip TP only, keep SL)
- ❌ `ComputeHeroLockProfitSL` / `ApplyHeroLockProfitSL` (BE_GUARD path)
- ❌ `BuildHeroTicketCache` price-extreme sort (v1.43)
- ❌ `DetectSameSideBasketClearedForHero` / `ManageHeroOppositeClose` flow
- ❌ v7.09 Auto-release block (BE_GUARD with 0 tickets → release)
- `InpHero_Enabled=false` → พฤติกรรม = v1.44 ทุกบรรทัด

## ผลลัพธ์ที่คาดหวัง
SELL active=44/15 ถึงเกณฑ์ → `phase=ARMED`, Hero #N tagged, TP stripped → Dashboard:
- `Hero Owner: NONE (waiting close)` (เหลือง)
- `Hero SELL: active=44/15  Hero=5  ARMED`
- BUY ยังเข้า ARMED ได้พร้อมกันถ้าถึงเกณฑ์

หลังจาก SELL basket ปกติ (39 normal orders ที่เหลือหลัง Hero) ปิดหมดด้วย Avg-TP/per-order TP → `DetectSameSideBasketClearedForHero(SELL)` → `phase=BE_GUARD` → `ApplyHeroLockProfitSL(SELL)` → Dashboard:
- `Hero Owner: SELL (locked)` (gold)
- BUY ARMED ถ้ามีจะถูก clear (Single-Side Lock kicks in)
