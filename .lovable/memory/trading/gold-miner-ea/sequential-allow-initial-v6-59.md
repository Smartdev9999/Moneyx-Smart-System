---
name: sequential-allow-initial-v6-59
description: Gold Miner EA v6.59 — Sequential Release no longer blocks new cycle initial entries; only recovery grids are gated
type: feature
---

Gold Miner EA v6.59 fixes a regression introduced in v6.58 where Sequential Release set `g_newOrderBlocked = true` whenever `g_seqAllowedGen != g_cycleGeneration`. This blocked every initial entry once the first hedge fired, halting trading entirely.

v6.59 removes that global block. `g_seqAllowedGen` is still computed each tick (for dashboard + `ManageOrphanGrid()` gating) but no longer toggles `g_newOrderBlocked`. Behavior:

- New cycle initial entries (SMA/ZigZag/Instant) — always allowed.
- Recovery grids on orphan generations — still gated to the single oldest allowed generation via `ManageOrphanGrid()`.
- Hedge open/close, matching, BoundAvgTP, partial close, BB filter, balance guard, news/time/license — untouched.

Dashboard "Seq Release" row now reads `ON | Allowed Recovery: GenN | New cycle entries: ALLOWED | Frozen Hedge: X | Frozen Orphans: Y` to make the split explicit.

When `InpHedge_SequentialRelease = false`, behavior is identical to pre-v6.57.
