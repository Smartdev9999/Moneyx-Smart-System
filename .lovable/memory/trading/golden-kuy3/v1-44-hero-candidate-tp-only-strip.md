---
name: Golden Kuy3 v1.44 Hero CANDIDATE Strip TP Only
description: ระหว่าง Hero ARMED/CANDIDATE — StripBrokerTPSLFromHeroTickets ถอดเฉพาะ TP, คง SL เดิม (BE/cost-lock) เพื่อกันราคาวิ่งกลับทะลุทุน. SL ใหม่ (lock-profit BE-SL) จะ apply ทับเฉพาะตอน phase->BE_GUARD เท่านั้น (basket ฝั่งเดียวกันปิดหมดแล้ว).
type: feature
---

## Bug v1.43
`StripBrokerTPSLFromHeroTickets()` เรียก `trade.PositionModify(ticket, 0, 0)` — **ลบทั้ง TP และ SL** ตั้งแต่ phase=ARMED → SL ที่ Per-Order BE/Trail ตั้งล็อกทุนไว้หาย; ราคาวิ่งกลับทะลุทุน → กำไรหายฟรี ก่อน basket ปกติจะปิดด้วยซ้ำ

## Fix v1.44
- `StripBrokerTPSLFromHeroTickets()` เปลี่ยนเป็น `trade.PositionModify(ticket, curSL, 0)` — คง SL เดิม ถอดเฉพาะ TP
- skip ถ้า `curTP == 0` อยู่แล้ว (ไม่ต้องแตะ SL ทุก tick)
- diag log throttled 30s แสดง `#ticket(SL=...)` ที่ถูก strip
- Phase machine ไม่เปลี่ยน: 0=NONE / 2=ARMED (CANDIDATE) / 3=BE_GUARD
- BE_GUARD path (`ApplyHeroLockProfitSL`) เหมือนเดิม — ตั้ง SL ใหม่ทับเมื่อ basket ฝั่งเดียวกันปิดครบ

## Flow ที่ถูกต้อง
1. Side ถึง threshold → tag Hero candidates → phase=ARMED
2. **Strip TP only** บน Hero tickets (กัน Avg-TP/per-order TP มาปิด candidate); SL เดิมยังอยู่
3. ราคาวิ่งกลับทะลุทุน → SL เดิมปิดเองได้ (Hero ยังไม่ confirm)
4. ถ้า basket ปกติฝั่งเดียวกันโดน TP ปิดหมด (`DetectSameSideBasketClearedForHero`) → phase=BE_GUARD
5. `ApplyHeroLockProfitSL` ตั้ง lock-profit BE-SL ใหม่ทับ → confirm Hero
6. รอ basket ฝั่งตรงข้ามปิด → `CloseHeroOnSide`

## ไม่เปลี่ยน (กฎเหล็ก)
- ❌ OrderSend / trade.Buy/Sell/PositionClose
- ❌ OpenInitial / OpenGrid / Manage*Entry / CalcGridLot
- ❌ Per-Order BE/Trail สูตร, Avg-Trail strict-2-cross
- ❌ TP modes / Accumulate Close + cycle-reset v1.42 / Cost-Hit Restart
- ❌ ComputeHeroLockProfitSL / ApplyHeroLockProfitSL (BE_GUARD path)
- ❌ BuildHeroTicketCache (v1.43 PRICE_EXTREME + STRICT lock)
- `InpHero_Enabled=false` → พฤติกรรม = v1.43 ทุกบรรทัด
