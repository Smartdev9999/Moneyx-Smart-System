---
name: Gold Miner EA v7.08 — Deferred SideGen Revert
description: CloseHeroOnSide no longer wipes g_sideGen_<side> / g_heroOwnedGen_<side>. Surviving GM(N+1) basket on that side keeps being managed by grid/TP/Avg-trail/Accumulate. New per-tick MaintainSideGenAfterHeroClose() reverts side-gen to 0 (= GM1) only when CountHeroOnSide==0 AND CountNonHeroMainOnSide==0, so the next INIT on that side opens as GM1 and the Hero subsystem can re-arm. Fixes "GM2 frozen after Hero closes" caused by v7.03's eager reset.
type: feature
---

# v7.08

## Bug
v7.03 `CloseHeroOnSide` immediately zeroed `g_sideGen_<side>` and `g_heroOwnedGen_<side>` on Hero close. If GM(N+1) basket was still alive on that side, next tick `GetActiveGenForSide(side)` returned GM1 → 11+ counter sites filtered GM(N+1) out as "older gen" → grid/TP/Avg-trail/Accumulate stopped touching surviving basket. Result: GM2 frozen, no path to re-arm Hero.

## Fix
- `CloseHeroOnSide` now only resets phase + BE flag + post-close grace timer; leaves `g_sideGen_<side>` / `g_heroOwnedGen_<side>` intact.
- New `MaintainSideGenAfterHeroClose()` called once per tick in `OnTick` right after `BuildHeroTicketCache()`. Per-side check: if `g_sideGen_<side> > 0 && CountHeroOnSide==0 && CountNonHeroMainOnSide==0` → clear both side-gen + owned-gen and log REVERT.
- `CountNonHeroMainOnSide` (v7.05) already filters by `GetActiveGenForSide(side)`, so it correctly sees the GM(N+1) basket while side-gen is still set.
- Cycle-reset paths (line 9697, 9797) still wipe `g_sideGen_*` for full-cycle resets — unchanged.
- Version bumped to **v7.08** at `#property`, header, OnInit/OnDeinit Print, dashboard title.

## Flow
```
1. SELL becomes Hero OWNER (BE_GUARD). g_sideGen_Sell: GM1->GM2, g_heroOwnedGen_Sell=1.
2. Hero SELL closes -> phase reset + grace timer. g_sideGen_Sell stays GM2.
3. GM2 SELL basket continues normal grid/TP/Avg-trail.
4. GM2 SELL basket flattens (TP / Avg-trail / Accumulate).
5. MaintainSideGenAfterHeroClose detects flat -> g_sideGen_Sell=0, g_heroOwnedGen_Sell=0.
6. Next SELL INIT opens as GM1_INIT -> Hero subsystem can re-arm.
```

## Not Touched
- OrderSend / `trade.Buy/Sell/PositionClose`
- Entry strategy (SMA/EMA/Squeeze/BB/ZigZag), grid lot/distance/candle confirm
- TP/SL/Trailing/Breakeven/Avg-TP formulae
- Hedge / Triple-Gate / Recovery / DD% TP / Daily Target / Balance Guard
- License / News / Sync modules
- Hero formula (`ComputeHeroLockProfitSL`, `ValidateHeroLockProfitSL`, `ApplyHeroLockProfitSL`, BE_GUARD apply, Post-Close Grace, OnTradeTransaction audit)
- v7.04 `GetActiveGenForSide` filter sites, v7.05 unblock helpers, v7.06 GL-pool gen-lock, v7.07 candidate-vs-owner
