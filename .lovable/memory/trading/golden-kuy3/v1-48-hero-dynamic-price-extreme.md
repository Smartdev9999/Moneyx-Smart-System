---
name: Golden Kuy3 v1.48 Dynamic Price-Extreme Hero
description: Branch A in BuildHeroTicketCache rewrites the stable Hero set every tick to current price-extreme top-N (BUY ascending / SELL descending) instead of v1.47 sticky freeze. Side-alternation lock + Single-Side Lock + post-close grace untouched. BE_GUARD clears g_heroBE_Applied_<side> on diff so ApplyHeroLockProfitSL re-applies SL to new entrants.
type: feature
---

## Bug v1.47
Stable Hero set was frozen at first activation. New orders opened at more-extreme prices (BUY lower, SELL higher) never replaced existing Hero tickets → Hero often locked on a non-extreme ticket (e.g. SELL Hero stuck on #28@3313.63 while #742@3319.17 existed and was higher).

## Fix v1.48
- `BuildHeroTicketCache` Branch A (curPhase != 0): no longer keeps existing set blindly. Sorts current side pool by price-extreme, takes `min(InpHero_OrderCount, nPool-1)` and rebuilds stable set every tick.
- Diff against previous set; if changed → audit log `v1.48 Hero REFRESH side=… phase=… new set: #t@px …`
- If phase==BE_GUARD and set changed → clear `g_heroBE_Applied_<side>` so the next `ApplyHeroLockProfitSL` pass writes BE-SL onto new entrants.
- Branch B (NONE→activate) still does the same price-extreme freeze with all alt/single-side guards.

## ไม่เปลี่ยน
- ❌ OrderSend / trade.* / OpenInitial / OpenGrid / Manage*Entry / CalcGridLot
- ❌ Per-Order BE/Trail / Avg-Trail strict-2-cross / TP modes / Accumulate / Cost-Hit Restart
- ❌ ComputeHeroLockProfitSL / ApplyHeroLockProfitSL formula
- ❌ Side-Alternation Lock (v1.46/v1.47), Single-Side Lock (v1.45 BE_GUARD-only owner), post-close grace
- ❌ STEP 1 prune + external-close detect, STEP 2 dual BE_GUARD pre-guard, STEP 5 auto-release
- ❌ DrawAvgAndTPLines using `CalcSideAvgPrice_NonHero`
- `InpHero_Enabled=false` → behavior = v1.47
