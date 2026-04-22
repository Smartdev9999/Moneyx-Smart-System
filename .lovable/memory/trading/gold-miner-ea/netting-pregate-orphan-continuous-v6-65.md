---
name: Netting Pre-Gate + Orphan Continuous GL v6.65
description: Profit-loss netting now runs BEFORE Triple Gate in ManageHedgeSets; per-tick fallback for allowed gen; orphan GL can open multiple layers per candle
type: feature
---
Gold Miner EA v6.65 fixes two blockers that prevented Set#2+ from clearing after Set#1 closed:

1. **Netting pre-gate**: `RunBoundProfitLossNetting(boundGen)` was previously called only after `IsHedgeCloseAllowed(h)` passed in `ManageHedgeSets()`. Since netting only touches bound orders (skips `GM_HEDGE_*`), it doesn't violate Triple Gate semantics. Moved before the gate so the allowed-gen profit-only lock / loss shred runs even while the hedge waits for expansion/zone/distance criteria.

2. **Per-tick fallback**: Added a single `RunBoundProfitLossNetting(seqAllowedGen)` call at the top of `ManageHedgeSets()` (before per-set loop). This catches bound orders of the allowed gen that may be split between an active hedge set and an orphan group.

3. **Orphan continuous GL**: Removed the global `g_lastOrphanGridCandleTime` candle gate (and its two assignments) in `ManageOrphanGrid()`. Orphan GL expansion is now governed by the existing per-side distance check (`currentPrice vs lastPrice ± distance*point`) plus `MaxOpenOrders` and `GridLoss_MaxTrades` caps. Multiple GL layers can now open within the same candle if price moves far enough — required to "shred" a deeply-bound hedge like GM_HEDGE_2.

Safety / unchanged:
- Triple Gate logic itself untouched — still guards hedge matching/avgTP/grid close
- Netting algorithm itself unchanged from v6.64
- `InpHedge_SequentialRelease = false` → behavior identical to v6.64 (netting skipped, orphan distance gate already worked the same)
