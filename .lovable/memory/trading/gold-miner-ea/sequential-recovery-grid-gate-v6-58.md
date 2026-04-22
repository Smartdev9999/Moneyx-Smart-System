---
name: sequential-recovery-grid-gate-v6-58
description: Gold Miner EA v6.58 — Sequential Release blocks new orders for non-allowed generations across orphan grid, main grid, and initial entry
type: feature
---

Gold Miner EA v6.58 closes the gap left by v6.57 (which only froze `ManageHedgeSets()` recovery). New helper `GetSequentialAllowedGeneration()` returns the single generation permitted to open new initial / grid loss / grid profit / orphan-grid orders when `InpHedge_SequentialRelease = true`:

1. Oldest active hedge set's slot index (slot === bound generation per v6.68 generation-locked slot rule).
2. If no hedge sets are active, the oldest active orphan group's generation.
3. Otherwise `-1` (unrestricted — current `g_cycleGeneration` may open freely).

OnTick computes `g_seqAllowedGen` immediately after resetting `g_newOrderBlocked`. If `allowedGen != -1 && allowedGen != g_cycleGeneration`, `g_newOrderBlocked` is forced true — this stops every per-current-gen entry path (SMA, ZigZag, Instant initial, grid loss, grid profit, max-grid trail) without touching their internal logic.

`ManageOrphanGrid()` independently skips orphan groups whose generation != allowed, so released bound orders from frozen sets stop accumulating recovery levels.

Hedge orders, matching close, bound average TP, partial close, triple gate, broker TP/SL sync, balance guard, news/time filters, and BB filter are all untouched. Only the new-order side is gated. Dashboard now shows `Seq Release | ON | Allowed: GenN | Frozen Hedge: X | Frozen Orphans: Y`.

When `InpHedge_SequentialRelease = false` the helper short-circuits to `-1` and behavior is identical to pre-v6.57.
