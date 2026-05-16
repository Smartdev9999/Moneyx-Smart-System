---
name: Golden2 v2.8.5 One-Hedge-Per-Group + Post-Match-Only Avg Broker TP/SL + Orphan-Inclusive Match
description: Locks each group to ONE hedge round, continuously strips TP/SL on every ticket (incl. orphan main) while hedge-used, gates SyncPostMatchAvgTPSL strictly on g_groupPostMatchAvgActive (set only after Matching Close closed >=1 ticket and residual remains). MATCH-PREP log proves orphan main is included via gp==g scan.
type: feature
---

## Bugs fixed
1. Hedge broker TP/SL was put back too early — `SyncPostMatchAvgTPSL` fired on `g_stripped || IsGroupHedgeMatched`, so the moment strip ran, broker re-armed Avg TP and could close hedge before the 3 Gate fired.
2. Each group could re-hedge: after a hedge ticket closed by TP, `ManageGroupHedgeArm` saw "no hedge position" and re-armed. Violates "1 group = 1 hedge".
3. Orphan main on the opposite side of the loss (e.g. SELL main opened before BUY hedge fires) had its Initial TP rewritten by the pre-match v1.3 `SyncSideTPSLToBroker` right after `StripBrokerTPSL_OnHedgeMatch` cleared it, because the v1.3 manager only checked `g_stripped/IsGroupHedgeMatched`.

## v2.8.5 changes (`public/docs/mql5/Golden2_EA.mq5`)

### New per-group state
- `bool g_groupHedgeUsed[51]` — `true` the first tick the group has ever held a hedge position.
- `bool g_groupPostMatchAvgActive[51]` — `true` ONLY after `TryMatchingCloseForGroup` actually closed >=1 ticket and residual positions remain.
Both reset to `false` only when the group is fully flat (no positions and no pendings).

### Wiring
1. `ManageGroupHedgeArm(g)` — early-return + delete stray hedge pendings when `g_groupHedgeUsed[g]==true`. Re-hedge LOCKED.
2. `SyncSideTPSLToBroker(g, side)` — added guard `if(g_groupHedgeUsed[g]) return;` so orphan main never gets Initial/Avg TP back after strip.
3. `SyncPostMatchAvgTPSL(g)` — gate changed to `if(!g_groupPostMatchAvgActive[g]) return;` (was `!g_stripped && !IsGroupHedgeMatched`). Post-3-Gate-only.
4. OnTick group loop:
   - Stamp `g_groupHedgeUsed[g]=true` the first tick a hedge position is observed.
   - Replaced one-shot `if(IsGroupHedgeMatched && !g_stripped) Strip…` with continuous `if(g_groupHedgeUsed && !g_groupPostMatchAvgActive) StripBrokerTPSL_OnHedgeMatch(g);` — catches new hedge tickets, orphan main, mirror top-ups. `ModifyIfDifferent` short-circuits when TP/SL already 0.
   - Reset both flags inside the `flat` branch.
5. `TryMatchingCloseForGroup(g)` — captures `totalBefore`/`totalAfter`; after shred passes, if `closedAny>0 && GroupHasAnyPositions(g)` → sets `g_groupPostMatchAvgActive[g]=true` then resets cache + calls `SyncPostMatchAvgTPSL(g)` immediately. Adds `MATCH-PREP G%d totalTickets=N (main=N hedge=N) winSide=...` log so journal proves orphan main was counted (all scans use `gp==g`). New summary log includes `ticketsClosed=N`.

### Orphan main coverage
All existing scans (`ShredCloseLosingSide`, `ShredAllNegativeFromAllProfit`, `StripBrokerTPSL_OnHedgeMatch`, `GroupAveragePrice`, `GroupFloatingPL`) already filter by `gp==g` — orphan main was always included in the math; v2.8.5 only fixes the TP-write path that bypassed it.

### Dashboard (Right panel hedging table)
- New row per hedge-active group: `  Hedge   USED/LOCKED  PostAvg:WAITING/ACTIVE`.
- `Avg TP B:/S:` row now gated on `g_groupPostMatchAvgActive` (not `g_stripped || matched`).
- Removed dependence on `g_stripped` from dashboard.

### Version
- `#property version "2.85"` + new description.
- Header banner + dashboard title + init log → `Golden2 EA v2.8.5`.
- Init log adds `OneHedgePerGroup=ON | PostMatchAvgTP=PostMatch-Active-Only`.

## Rules of Steel — UNTOUCHED
- ❌ trade.Buy/Sell/Send/Modify wrappers (existing strip + sync helpers reused)
- ❌ Entry SMA/INSTANT/PENDING, Squeeze BB/KC/ADX/EMA/ATR
- ❌ Grid Loss/Profit lot/distance/candle confirm/ATR snapshot
- ❌ Hedge mirror 1:1 / pending hedge / arm/disarm / Block percent — only ADD re-hedge lock
- ❌ Triple-Gate logic (WinPool, MinGain, Squeeze TF3 latch, breakout)
- ❌ Match-close shred algorithm (winning-pool + cross-side pool from v2.8.3/v2.8.4)
- ❌ Recovery Grid placement + multiplier
- ❌ ParseComment / MakeComment B_/S_ tags
- ❌ ATR/ADX TesterHideIndicators (v2.8.1)
- ❌ Prior-group advance guard (v2.8.2)
- ❌ Sequential Queue / Per-order trail / Bar-close trail / Cost-Hit / Accumulate / Force-close opp unhedged

## Rule
**Hedge once. Strip continuously while hedge is used and pre-Matching-Close. Re-arm broker Avg TP/SL ONLY through `g_groupPostMatchAvgActive` after `TryMatchingCloseForGroup` actually closed >=1 ticket. Never let pre-match v1.3 sync write TP/SL after `g_groupHedgeUsed` is set.**
