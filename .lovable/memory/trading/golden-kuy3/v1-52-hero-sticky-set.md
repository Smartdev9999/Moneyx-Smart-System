---
name: Golden Kuy3 v1.52 Hero Sticky Set
description: Hero ticket set frozen at activation; BuildHeroTicketCache Branch A no longer re-selects from price-extreme during ARMED/BE_GUARD. Orders opened after activation remain normal basket. Fixes Hero overlap, silent ticket replacement, missing side-alternation. Toggle InpHero_StickySet (default true). false=v1.51 dynamic refresh.
type: feature
---

## Bug v1.48–v1.51
Branch A re-selected Hero set every tick by current price-extreme. When grid added new lower-price (BUY) / higher-price (SELL) tickets after BE_GUARD, those replaced the original Heroes in `g_heroBuyStable[]/g_heroSellStable[]`. Pushed-out tickets:
- ยังถูก strip TP จากเดิม
- SL lock-profit ที่เคยใส่ยังคาอยู่ ถูก Per-Order Trail/BE จัดการ → ปิดพร้อมไม้ปกติ
- `g_heroLastClosedSide` ไม่ถูก stamp (ไม่ใช่การปิดยกชุด) → Side-Alternation Lock v1.46 ใช้ไม่ได้
- Owner ยัง BE_GUARD → ฝั่งตรงข้ามไม่ได้สลับเป็น Hero

## Fix v1.52
- New input `InpHero_StickySet` (default true).
- Branch A เมื่อ phase != 0 + StickySet=true: คง stable set เดิม (PruneStableSet ใน STEP 1 จัดการ ticket ที่ปิดแล้ว); `sideHeroTagged = stableN`; continue.
- ไม้ใหม่หลัง ARMED = ไม้ basket ปกติ ทำงานกับ Per-Order Trail/BE/Avg-TP ตามปกติ
- Stable set drained (`stableN==0` ขณะ BE_GUARD) → STEP 5 auto-release stamp `g_heroLastClosedSide` → Alternation Lock บังคับสลับฝั่ง
- StickySet=false → fallback v1.51 dynamic refresh พร้อม clear `g_heroBE_Applied_*` เมื่อ set เปลี่ยน

## ไม่เปลี่ยน (กฎเหล็ก)
- ❌ trade.Buy/Sell/PositionClose/OrderSend / Grid entry/exit / lot multiplier
- ❌ Per-Order BE/Trail / Avg-TP/Avg-Trail strict-2-cross / TP modes / Cost-Hit Restart / Accumulate
- ❌ ApplyHeroLockProfitSL / ComputeHeroLockProfitSL / StripBrokerTPSLFromHeroTickets
- ❌ STEP 1 prune + external-close detect / STEP 2 dual BE_GUARD pre-guard / STEP 4 flat rebuild / STEP 5 auto-release / STEP 6 audit log
- ❌ Side-Alternation v1.46 / Single-Side Lock v1.45 / Post-close grace
- ❌ v1.50 oppRealized gate / v1.51 Avg-TP intent (5 set sites + Master TP safety net + 60s expiry)
- ❌ IsHeroProtectedTicket 9 guards
- `InpHero_Enabled=false` → behavior เดิม
- `InpHero_StickySet=false` → v1.51 dynamic refresh เป๊ะ ๆ
