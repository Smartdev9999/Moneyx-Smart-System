---
name: Golden2 EA v2.8.8 Recovery Grid Continuation
description: Adds TryPlaceRecoveryGridContinuation so RC#2..N auto-fire at GridLoss distance while g_groupInRecovery is true; fixes freeze where RC#1 sat alone because TryPlaceGridLoss was blocked by IsGroupHedgeMatched (losing side still carries hedge-orphan-offset)
type: feature
---

## Bug
After Triple-Gate Matching Close + RC#1 placement, no further recovery orders were ever placed even when price kept moving against the losing side.

## Root Cause
- `PlaceRecoveryGridIfNeeded()` runs ONCE inside `TryMatchingCloseForGroup()` — no per-tick loop.
- `TryPlaceGridLoss()` bails on `IsGroupHedgeMatched(g)`. Post match-close the losing side still has BOTH main and hedge-orphan-offset tickets, so the guard stays TRUE → GL#N never fires either.
- Result: RC#1 stranded with no averaging.

## Fix (v2.8.8)
New `TryPlaceRecoveryGridContinuation(int g)` called every tick after `TryPlaceGridProfit(g)`:
- Guards: `InpRecovery_Enable`, `g_groupInRecovery[g]`, `g_groupRecoveryLevel[g] < InpRecovery_MaxLevels`
- Detects `losSide` as the side that still has positions (winning side fully closed at match)
- Reads `LastEntryPrice(g, losSide, false)` (RC tickets have hd=false so they're included)
- gap = `InpRecovery_DistancePips > 0 ? InpRecovery_DistancePips : GridLoss_Points`
- Triggers when ask/bid moves `gap*point` past last entry
- New input `InpRecovery_OnlyNewCandle = true` + global `g_lastRecoveryCandle[51]` ensure at most one RC fire per bar
- Delegates the actual order to existing `PlaceRecoveryGridIfNeeded()` so seed lot / multiplier ladder / RC#N comment tag are unchanged

## Untouched
- `PlaceRecoveryGridIfNeeded` body (lot formula, comment, trade calls)
- `TryMatchingCloseForGroup`, Reserve-Profit gate (v2.8.7), shred passes
- `TryPlaceGridLoss` / `IsGroupHedgeMatched` semantics
- Hedge Orphan Offset (v2.8.6), One-Hedge-Per-Group (v2.8.5), Post-Match Avg TP (v2.8.4)

## Files
`public/docs/mql5/Golden2_EA.mq5` → version 2.88
