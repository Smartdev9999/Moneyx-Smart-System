---
name: Gold Miner EA v7.05 — Hero Side-Gen Unblock
description: Fixes v7.04 silent block where Hero-owning side never opened GM(N+1) INIT/GL/GP. ShouldBlockSameSideGridForHero now early-returns false when InpHero_PerSideGenIsolation is ON and that side has g_sideGen_<side> > 0 (GM(N+1) IS the new basket; Hero on GM(N) lives separately under BE_GUARD lock). CountNonHeroMainOnSide gen filter switched from g_cycleGeneration to GetActiveGenForSide(side). CountFreeOlderGenOnSide excludes IsHeroTicket so InpCrossGen_InitGuard no longer treats locked-profit Heroes as "free older-gen" orders that block new-gen INIT.
type: feature
---

# v7.05

## Bug Fixed
After v7.04 bumped `g_sideGen_<side>` on BE_GUARD transition and dashboard correctly showed `Side Gen SELL: GM2 (Hero owns GM1)`, no GM2_INIT/GL/GP ever opened. Two `OpenOrder()` guards still scoped to global `g_cycleGeneration` (=GM1) and rejected GM2 entries on the Hero-owning side:
1. `ShouldBlockSameSideGridForHero` → `CountNonHeroMainOnSide` filtered by `g != g_cycleGeneration`, only saw GM1, found 0 non-Hero main → returned block=true.
2. `CountFreeOlderGenOnSide` (used by `InpCrossGen_InitGuard`) counted Hero GL tickets as "free older-gen" → printed `v6.73 INIT BLOCKED`.

## Fix (3 helper edits + version bump)
- **`ShouldBlockSameSideGridForHero(side)`**: early-return `false` when `InpHero_PerSideGenIsolation && g_sideGen_<side> > 0`.
- **`CountNonHeroMainOnSide(side)`**: gen filter now `GetActiveGenForSide(side)` instead of `g_cycleGeneration`.
- **`CountFreeOlderGenOnSide(side)`**: skip `IsHeroTicket(tk)` — Heroes are intentionally locked at BE-profit, not free orders.

## Not Touched
- OrderSend / `trade.Buy` / `trade.Sell` / `trade.PositionClose`
- Entry conditions (SMA/EMA/Squeeze/BB/ZigZag)
- Grid lot/distance/candle-confirm/MaxGrid trailing math
- TP/SL/Trailing/Breakeven/Avg-TP
- Hedge/Triple-Gate/Recovery/DD% TP/Daily Target/Balance Guard activation
- Hero formula: `ComputeHeroLockProfitSL`, `ValidateHeroLockProfitSL` (v7.02), `BE_GUARD` apply path, Post-Close Grace (v7.03), Single-Side Lock (v7.04), `OnTradeTransaction` audit
- License/News/Sync modules
- All 11 v7.04 `GetActiveGenForSide` filter sites
