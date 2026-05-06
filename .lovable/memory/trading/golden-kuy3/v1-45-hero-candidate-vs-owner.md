---
name: Golden Kuy3 v1.45 Hero CANDIDATE vs OWNER Separation
description: ARMED = CANDIDATE (ทั้งสองฝั่งพร้อมกันได้); OWNER lock เกิดเฉพาะเมื่อ phase==BE_GUARD (basket ปกติฝั่งเดียวกันปิดหมดแล้ว) — port v7.07 จาก Gold Miner
type: feature
---

## Bug v1.44
`GetHeroOwnerSide()` ใช้ `phase != 0` (รวม ARMED) → พอฝั่งใดถึงเกณฑ์ก่อน Dashboard ก็โชว์ `Hero Owner = SIDE (locked)` ทันที, PRE-GUARD ลบสถานะอีกฝั่ง, STRICT activeOwner immediate-update บล็อกฝั่งที่สองในรอบเดียวกัน. ผิดสเปก — owner ต้องเกิดหลัง basket ปกติฝั่งนั้นปิดหมดเท่านั้น

## Fix v1.45
- `GetHeroOwnerSide()`: `buyOwns/sellOwns = (phase == 3)` เท่านั้น (BE_GUARD)
- `BuildHeroTicketCache()` PRE-GUARD: trigger เฉพาะ dual BE_GUARD (ARMED+ARMED, ARMED+BE_GUARD ปล่อยไป)
- ลบ `activeOwner = sideId` immediate-update — side B ใน loop เดียวกันยังเข้า ARMED ได้
- STRICT Single-Side Lock บล็อกฝั่งที่ยังไม่ ARMED ก็ต่อเมื่อมี OWNER จริง (BE_GUARD)

## Flow ที่ถูกต้อง
1. SELL ถึงเกณฑ์ → `phase=ARMED`, tag Hero, strip TP only → `Hero Owner: NONE (waiting close)` (เหลือง)
2. BUY ถึงเกณฑ์ → `phase=ARMED` ได้พร้อมกัน → ทั้งคู่ CANDIDATE
3. ถ้า basket ปกติ SELL ปิดหมด (Avg-TP/per-order TP) → `DetectSameSideBasketClearedForHero(SELL)` → `phase=BE_GUARD` → `ApplyHeroLockProfitSL` → `Hero Owner: SELL (locked)` (gold)
4. STRICT lock kicks in: BUY ARMED ที่ค้างอยู่จะถูก clear ในรอบถัดไป (curPhase==0 และมี owner)

## ไม่เปลี่ยน (กฎเหล็ก)
- ❌ OrderSend / trade.* / OpenInitial / OpenGrid / Manage*Entry / CalcGridLot
- ❌ Per-Order BE/Trail / Avg-Trail strict-2-cross / TP modes / Accumulate Close v1.42 / Cost-Hit Restart
- ❌ StripBrokerTPSLFromHeroTickets v1.44 (TP only, SL kept)
- ❌ ComputeHeroLockProfitSL / ApplyHeroLockProfitSL (BE_GUARD path)
- ❌ BuildHeroTicketCache price-extreme sort v1.43
- ❌ DetectSameSideBasketClearedForHero / ManageHeroOppositeClose
- ❌ v7.09 Auto-release (BE_GUARD with Hero tickets=0 → release)
- `InpHero_Enabled=false` → พฤติกรรม = v1.44
