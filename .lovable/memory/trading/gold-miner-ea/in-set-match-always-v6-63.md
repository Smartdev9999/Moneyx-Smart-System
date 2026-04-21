---
name: In-Set Match Always + Persistent Hedge Slot v6.63
description: Sequential owner blocks recovery grid only; in-set matching runs every tick on every set. Hedge slot numbers (GM_HEDGE_N) never reuse until all sets flat.
type: feature
---

Gold Miner EA v6.63 changes the semantics of the Sequential Recovery Owner lock.
Because v6.62 strict in-set pooling guarantees that ManageHedgeMatchingClose only touches
tickets belonging to the same hedge set (hedge + reverse + bound of one generation),
it is safe to let every active set run its own matching, AvgTP, and PartialClose every
tick — even while a recovery owner generation is locked.

The owner lock now blocks only RECOVERY GRID expansion (TryEnterCombinedGridMode and
ManageHedgeGridMode) for non-owner sets, via a per-iteration `blockGridForThisSet` flag
instead of `continue`. The one-tick handoff (`g_sequentialRecoveryCompletedThisTick`)
still fully pauses every set for one tick after the owner clears.

`FindFreeHedgeSlot()` was rewritten to assign slot = maxActiveSlot + 1, so once H1 closes
while H2 is still alive, the next hedge becomes H3 (not reused H1). The numbering only
resets to slot 0 (GM_HEDGE_1) when every hedge set is simultaneously flat. A fallback
scans for middle gaps if the tail of the MAX_HEDGE_SETS array is exhausted.
