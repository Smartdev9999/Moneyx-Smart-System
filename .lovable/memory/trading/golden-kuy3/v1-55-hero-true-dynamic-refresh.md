---
name: Kuy3 v1.55 Hero TRUE Dynamic Refresh
description: InpHero_StickySet deprecated/ignored; BuildHeroTicketCache Branch A always rebuilds Hero set every tick by price-extreme so new better-priced tickets immediately replace stale ones; demote-restore + post-entry refresh preserved
type: feature
---

v1.55 fixes the stale-Hero-ticket lock that occurred when `.set` files (or v1.52 fallback) forced `InpHero_StickySet=true`. The sticky-freeze branch in `BuildHeroTicketCache()` Branch A is now removed entirely. Hero set is ALWAYS rebuilt every tick from current price-extreme:

- BUY: lowest N open prices win Hero
- SELL: highest N open prices win Hero

Demoted tickets get `RestoreInitialTPOnDemoted()` (Initial TP back, lock-SL cleared) so they re-join normal basket and close with Avg-TP/per-order rules. New entrants in BE_GUARD reset `g_heroBE_Applied_*` so `ApplyHeroLockProfitSL()` writes lock-profit SL to them next tick.

`InpHero_StickySet` input remains for `.set` backward compatibility but is now a no-op. Dashboard shows `Mode=DYNAMIC`. v1.54 post-entry refresh (BuildHeroTicketCache + ManageHeroOppositeClose called twice in OnTick) preserved. v1.46 Side-Alternation, v1.45 Single-Side Lock (BE_GUARD owner only), and v1.50/1.51 Avg-TP-only opposite-close gate untouched.
