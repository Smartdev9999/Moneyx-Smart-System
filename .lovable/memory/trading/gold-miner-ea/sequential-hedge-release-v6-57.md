---
name: sequential-hedge-release-v6-57
description: Gold Miner EA v6.57 — InpHedge_SequentialRelease releases hedge sets oldest-first; freezes others' recovery while keeping hedge orders intact
type: feature
---

Gold Miner EA v6.57 adds `InpHedge_SequentialRelease` (default false). When enabled, `ManageHedgeSets()` allows recovery (matching close, bound avg TP, partial close, grid mode) only on the oldest active hedge set — identified by the lowest slot index via `GetOldestActiveHedgeSetIndex()` (consistent with v6.68 generation-locked slot rule).

Frozen sets keep:
- their hedge order open (untouched)
- their bound tickets bound (no close, no rebind change)
- expansion tracking (`seenExpansionSinceHedge`) updated so they are gate-ready when promoted
- `matchingDone` reset to false so recovery re-runs on promotion

Frozen sets skip: Triple-Gate evaluation downstream, ManageHedgeMatchingClose, ManageHedgeBoundAvgTP, ManageHedgePartialClose, ManageHedgeGridMode, TryEnterCombinedGridMode.

Auto-progression: when the oldest set's `active` flips false (existing deactivation paths), the next tick's `GetOldestActiveHedgeSetIndex()` returns the next slot, which becomes the sole recovery owner. When all sets close, the system simply waits for new hedges and restarts oldest-first.

Hedge open triggers, Balance Guard, MaxSets cap, and BB filter are unchanged — only recovery scheduling is gated.
