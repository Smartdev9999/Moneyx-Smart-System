---
name: Golden2 EA v2.8.9 Recovery-Mode Order Lock + Prior-Advance Bypass
description: Freezes normal GL/GP/Initial-trail/IN-rearm/IN-market-reentry the instant g_groupInRecovery[g] is true so only RC ladder fires; IsPriorGroupSafeForAdvance now treats post-match (g_groupHedgeUsed && g_groupPostMatchAvgActive) or g_groupRecoveryLevel>0 as safe-pass, unblocking the advance queue when an early group sits in recovery
type: feature
---

## Bugs
**A) GL+RC double-fire.** After Triple-Gate Matching Close, winning side fully closed → `IsGroupHedgeMatched(g)` flips FALSE (needs main BUY + main SELL both present). Guards in `TryPlaceGridLoss`/`TryPlaceGridProfit` unlock → normal GL#N fires on the losing side alongside RC#N from the recovery ladder. Same group ended up with two parallel ladders.

**B) Prior-group advance deadlock.** Log: `hold G4->G5 ... blockPrior=G1 reason=unhedged-main ... recovery=OFF` repeating forever. G1 finished match-close (no hedge left, only losing side + RC) so `hedgeAny = CountGroupPositions(1,-1,1) > 0` was FALSE → `IsPriorGroupSafeForAdvance` returned `reason=3 no-hedge` or `reason=4 unhedged-main`. Queue froze.

## v2.8.9 Fixes
### A) Recovery-mode entry lock (single guard pattern)
Added `if(g_groupInRecovery[g]) return;` at top of:
- `TryPlaceGridLoss` (after `IsGroupHedgeMatched`)
- `TryPlaceGridProfit`
- `ManageInitialTrailOnBarClose`
- `ManageInitialTrail` (opposite-side trail)
- `ManageInitialReArm`
- `ManageInitialMarketReEntry`

`ManageGroupHedgeArm` was already locked by `g_groupHedgeUsed[g]` (v2.8.5) so no new hedge can arm.

### B) Prior-advance safe-pass
`IsPriorGroupSafeForAdvance(g, &reason)` adds two safe-pass conditions before the hedge check:
1. `g_groupHedgeUsed[g] && g_groupPostMatchAvgActive[g]` → `reason=1` (post-match group managed by per-side Avg-TP)
2. `g_groupRecoveryLevel[g] > 0` → `reason=1` (RC ladder alive even if `g_groupInRecovery` momentarily cleared)

### C) Defensive flag restore
OnTick housekeeping (group loop): if `hasPos && g_groupRecoveryLevel[g] > 0 && !g_groupInRecovery[g]` → restore flag. Guards against shred passes that briefly clear positions between close calls within a single tick.

### D) Dashboard / Logs
- TripleGrid row tag: `[GL-LOCK RC#n/N]` (was `RECOV RC#n/N`)
- Header title + init log → `Golden2 EA v2.8.9`
- Init log adds `RecoveryOrderLock=ON | PriorAdvBypass=PostMatch+RecLvl>0`

## Avg TP + Broker TP includes RC (verified, no code change)
`SyncPostMatchAvgTPSL` uses `CountGroupPositions(g,side,-1)` and `GroupAveragePrice(g,side,-1)` (main+hedge). RC orders created with `hd=false` → counted as main → included in avg automatically and TP pushed to broker every tick.

## Untouched (Rules of Steel)
- `trade.Buy/Sell/PositionClose` execution
- `PlaceRecoveryGridIfNeeded` + `TryPlaceRecoveryGridContinuation` ladder (v2.8.8)
- Triple-Gate + Reserve-Profit (v2.8.7) + shred passes
- Hedge Orphan Offset (v2.8.6), One-Hedge-Per-Group (v2.8.5)
- Post-Match Avg Broker TP/SL formula + timing (v2.8.4)
- Squeeze BB/KC ratio, Entry SMA/INSTANT/PENDING
- `IsGroupHedgeMatched` / `IsGroupSafeToAdvance` (current group) — only `IsPriorGroupSafeForAdvance` extended
- License/News/Time/Sync

## Files
`public/docs/mql5/Golden2_EA.mq5` → version 2.89
