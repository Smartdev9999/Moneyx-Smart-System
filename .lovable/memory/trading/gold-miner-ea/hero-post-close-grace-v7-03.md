---
name: Gold Miner EA v7.03 — Hero Post-Close Grace + Per-Side Gen Isolation
description: Fixes phantom Hero-like orders after CloseHeroOnSide by hard-resetting phase + setting InpHero_PostCloseGraceSec (default 5s) timer that suppresses re-tag in BuildHeroTicketCache. Adds GetCommentPrefixForSide and optional InpHero_PerSideGenIsolation that bumps g_sideGen_<side> on transition to BE_GUARD so post-Hero entries on the surviving side use GM(N+1) while opposite side stays on GM(N). Default OFF for safety (current-gen filters across the EA still target g_cycleGeneration).
type: feature
---

# v7.03

## Bug
After `CloseHeroOnSide(side, "OppositeBasketFlatTick")` Hero phase stayed at 3 (BE_GUARD) until ResetHeroStateIfFlat ran. Because the Hero close is async at the broker, new INIT/GL entries opening in the same/next tick were re-tagged via v7.01 sticky logic (take=min(N,nGL)) and StripBrokerTPSLFromHeroTickets removed their TP — looked like phantom Hero orders.

## Fix
- `CloseHeroOnSide` now hard-resets `g_heroPhase_<side>=0`, `g_heroBE_Applied_<side>=false`, `g_sideGen_<side>=0`, and stamps `g_heroJustClosed_<side>=TimeCurrent()`.
- `BuildHeroTicketCache` checks `(TimeCurrent()-g_heroJustClosed_<side>) < InpHero_PostCloseGraceSec` and bypasses tagging on that side during the grace window — even resets phase to NONE if anything tries to set it.
- New input `InpHero_PostCloseGraceSec` (default 5).

## Per-Side Generation Isolation (Experimental, default OFF)
- `GetCommentPrefixForSide(side)` returns `GM<g_sideGen_<side>>` when set, else falls back to `GetCommentPrefix()` (global gen).
- All INIT/GL/GP `OpenOrder` call sites now pass per-side prefix.
- On transition to BE_GUARD inside `ManageHeroOppositeClose`, if `InpHero_PerSideGenIsolation` is true, `g_sideGen_<side>` is set to `(currentGlobalGen+1)` so new entries on that side use the higher GM number while Hero keeps the original.
- Reset to 0 in `CloseHeroOnSide` so once Hero exits the side returns to global gen.
- Default OFF because gen filters across the EA (`orderGen != g_cycleGeneration` in ~12 places) still anchor to global; enabling iso requires those to allow multiple gens per side. Fixing that is a follow-up.

## Not Changed
OrderSend / trade.Buy/Sell/PositionClose, entry conditions (SMA/EMA/ZigZag/BB/Squeeze), GL/GP lot/distance/candle confirm, Avg TP/Trail, Hedge/Triple-Gate/Recovery, DD% TP, Daily Target, Balance Guard, License/News/Sync, ComputeHeroLockProfitSL formula, ValidateHeroLockProfitSL (v7.02 fix), IsHeroTicket exclusion guards.
