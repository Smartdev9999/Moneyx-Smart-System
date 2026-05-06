---
name: Golden Kuy3 v1.47 Strict Hero Ticket Ownership + Hard Side-Alternation
description: Hero ticket sets per side becomes STICKY/STABLE — chosen ONCE at first activation and never re-selected from price-extremes again. Broker/SL/TP/manual close of Hero tickets stamps g_heroLastClosedSide so same side cannot re-arm Hero until opposite side activates or self goes flat.
type: feature
---

## Bug v1.46
1. `BuildHeroTicketCache` rebuilt the Hero pool from scratch every tick using price-extreme sort. If Hero BUY ticket(s) closed externally (broker SL/TP race, manual, etc.), the next tick simply re-selected another BUY ticket as Hero — same side stayed locked in Hero forever.
2. `g_heroLastClosedSide` was only stamped inside `CloseHeroOnSide()`. External close paths (broker TP/SL, partial Hero close before opposite TP, manual) never stamped it → alternation guard never engaged → BUY kept becoming Hero again after price walked back down.

## Fix v1.47
- New per-side **stable sticky sets** `g_heroBuyStable[]` / `g_heroSellStable[]`; helpers `PruneStableSet`, `ClearStableSet`, `AddToStableSet`, `IsInStableSet`, `GetStableCount`.
- `BuildHeroTicketCache` rewritten:
  - **STEP 1** Prune dead tickets from each stable set; if `prevN>0 && nowN==0` while phase>0 → external close detected → reset phase + stamp `g_heroJustClosed_*` + stamp `g_heroLastClosedSide`.
  - **STEP 2** Dual BE_GUARD pre-guard (rare safety).
  - **STEP 3** Per-side: if `phase != 0 && stableN > 0` → KEEP existing set, never re-select. Only when `phase == 0` consider FREEZING a new set (post-grace + alt-lock + single-side lock + threshold + price-extreme sort, take=min(N, nPool-1)).
  - **STEP 4** Rebuild flat `g_heroTickets[]` from both stable sets.
  - **STEP 5** Auto-release stale BE_GUARD when stable set empty + stamp last-closed.
- `CloseHeroOnSide(side)` clears that side's stable set.
- Throttled 30s `ALT-BLOCK` log when same-side re-arm attempt is blocked.
- `DrawAvgAndTPLines()` now uses `CalcSideAvgPrice_NonHero()` so chart Average/TP lines exclude Hero/Candidate (matches real TP logic which already used `CalcSideAvgPrice_NonHero`).
- Audit log v1.47 prints `stable=` counts per side instead of dynamic `hero=` count.
- Version bump 1.46 → 1.47 everywhere.

## Flow ที่คาดหวัง
1. BUY ถึง threshold ครั้งแรก → freeze stable set BUY (เลือก price-extreme ครั้งเดียว) → phase=ARMED, strip TP only
2. ราคาวิ่งขึ้นต่อ → BUY orders ใหม่เปิด แต่ stable set ไม่เปลี่ยน → Hero ตัวเดิมยังเป็น Hero ตัวเดิม
3. ฝั่ง SELL ถูก TP ปิด basket → BUY phase → BE_GUARD → owner BUY → ApplyHeroLockProfitSL
4. ราคากลับลง → Hero BUY ทีละตัวอาจถูกปิดด้วย SL ที่ล็อก → stable set BUY drain
5. เมื่อ stable set BUY = 0 (ทั้งที่ phase ยัง > 0): STEP 1 จับได้ → reset BUY phase + stamp lastClosed=BUY
6. ราคาลงต่อ → SELL เปิด orders เพิ่ม → ถึง threshold
7. Alt guard เห็น lastClosed=BUY → BUY ห้าม re-arm; SELL มาเป็น Hero ฝั่งใหม่ตามสเปก

## ไม่เปลี่ยน (กฎเหล็ก)
- ❌ OrderSend / `trade.Buy/Sell/PositionClose`
- ❌ OpenInitial / OpenGrid / Manage*Entry / CalcGridLot
- ❌ Per-Order BE/Trail / Avg-Trail strict-2-cross / TP modes / Accumulate v1.42 / Cost-Hit Restart
- ❌ `StripBrokerTPSLFromHeroTickets` v1.44 (TP only, SL kept)
- ❌ `ComputeHeroLockProfitSL` / `ApplyHeroLockProfitSL` (BE_GUARD path)
- ❌ Hero price-extreme sort (BUY ascending / SELL descending) v1.43 — แค่ใช้ครั้งเดียวตอน freeze
- ❌ `DetectSameSideBasketClearedForHero` / `ManageHeroOppositeClose`
- ❌ v1.45 CANDIDATE-vs-OWNER (`GetHeroOwnerSide` BE_GUARD-only)
- ❌ v1.46 alternation guard เงื่อนไข (oppActive || selfFlat) — ยังเหมือนเดิม
- `InpHero_Enabled=false` → behavior = v1.46
