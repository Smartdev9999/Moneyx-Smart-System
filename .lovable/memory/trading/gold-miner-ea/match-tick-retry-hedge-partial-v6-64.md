---
name: Match Tick Retry + Hedge Partial Fallback v6.64
description: ManageHedgeSets resets matchingDone every tick; ManageHedgeMatchingClose adds partial hedge close fallback when budget cannot cover any full loss ticket
type: feature
---

Gold Miner EA v6.64 fixes the "frozen Set#2" symptom where a hedge set that
already attempted matching once would not re-evaluate on subsequent ticks.

Two changes:

1. `ManageHedgeSets()` resets `g_hedgeSets[h].matchingDone = false` every tick
   for any active set that passes the close gate. Because v6.62 strict in-set
   pooling guarantees no cross-set leakage, it is safe to re-run
   `ManageHedgeMatchingClose`, `ManageHedgeBoundAvgTP`, and
   `ManageHedgePartialClose` continuously while floating P/L moves the budget.

2. `ManageHedgeMatchingClose()` no longer returns when greedy matching cannot
   fit any full-loss ticket. Instead, after closing whatever full-loss tickets
   the budget covers (Phase C1 + C2), the leftover `remainingBudget` is used
   to partially close the main hedge ticket via `trade.PositionClosePartial()`.
   The shred amount uses the same pattern as `ManageHedgeGridMode`:
   `closeLots = remainingBudget / hedgeLossPerLot`, normalized to lot step.
   When `lossUsed == 0` the fallback first realizes profit tickets (excluding
   the hedge itself) so the budget becomes real cash before the partial.

This lets every secondary hedge set (Set#2, Set#3, ...) progressively shred
its hedge ticket using its own in-set profits each tick, even while the
sequential recovery owner of an older generation still holds the grid lock.
