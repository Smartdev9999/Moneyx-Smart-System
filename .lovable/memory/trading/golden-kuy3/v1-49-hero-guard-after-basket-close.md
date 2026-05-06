---
name: Golden Kuy3 v1.49 Hero Guard After Basket Close
description: BuildHeroTicketCache Branch A (active phase) take=min(N, nPool) instead of (nPool-1) so Hero set never shrinks when non-Hero basket is closed; new IsHeroProtectedTicket helper covers both flat array and stable sets and replaces IsHeroTicket guard in CountNonHeroMainOnSide, CloseAllSide, CloseAllOurs, CalcSideFloating_NonHero, CalcSideAvgPrice_NonHero, EnforceClearTPIfDisabled, ManageTakeProfit, ManageAverageTrailing, ManagePerOrderTrailing.
type: feature
---

## Bug v1.48
- Branch A used `min(N, nPool-1)` even after Hero was active. When non-Hero basket closed (TP/AvgTrail), nPool dropped to N or below and Hero tickets were dropped from the stable set one by one, becoming "non-Hero" and getting closed by TP/AvgTrail/CloseAll.
- Dashboard showed `Hero Owner = NONE (waiting close)` because surviving Hero tickets were re-tagged as basket and basket-clear detection never fired → BE_GUARD never engaged.

## Fix v1.49
- Branch A take = `min(InpHero_OrderCount, nPool)` (Branch B / activation still uses `nPool-1`).
- `IsHeroProtectedTicket(ticket)`: true if ticket is in `g_heroTickets[]` OR `g_heroBuyStable[]` OR `g_heroSellStable[]`. Used as the universal "skip Hero" guard.
- All 9 management call sites swapped from `IsHeroTicket` to `IsHeroProtectedTicket`:
  CountNonHeroMainOnSide, ManagePerOrderTrailing, CloseAllSide, CloseAllOurs, CalcSideFloating_NonHero, CalcSideAvgPrice_NonHero, EnforceClearTPIfDisabled, ManageTakeProfit (push TP loop), ManageAverageTrailing (apply SL loop).
- Effect: when basket closes by TP/AvgTrail and only Hero remain, CountNonHeroMainOnSide returns 0 → DetectSameSideBasketClearedForHero fires → phase → BE_GUARD → ApplyHeroLockProfitSL writes lock-profit SL.

## ไม่เปลี่ยน (กฎเหล็ก)
- ❌ trade.Buy/Sell/PositionClose / OrderSend / OpenInitial / OpenGrid / CalcGridLot
- ❌ Per-Order BE/Trail / Avg-Trail strict-2-cross / TP modes / Accumulate / Cost-Hit Restart
- ❌ Hero price-extreme selection (BUY lowest / SELL highest)
- ❌ ComputeHeroLockProfitSL / ApplyHeroLockProfitSL
- ❌ Side-Alternation Lock (v1.46/v1.47), Single-Side Lock (v1.45 BE_GUARD-only owner), post-close grace
- ❌ STEP 1 prune + external-close detect, STEP 2 dual BE_GUARD pre-guard, STEP 5 auto-release
- `InpHero_Enabled=false` → behavior = v1.48
