---
name: Golden2 EA v2.7.6 INSTANT/SMA Per-Side Re-entry
description: New ManageInitialMarketReEntry refills closed side at market when other side still active in same group; PENDING mode untouched
type: feature
---
v2.7.6 fixes INSTANT/SMA mid-cycle gap: when one side closes by TP/SL but the
other side still has a live main position, the closed side now reopens at
market immediately in the same group instead of waiting for the whole group
to flush. New helper `ManageInitialMarketReEntry(g)` runs in OnTick after
`ManageInitialReArm`. Guards: skip PENDING mode, accum cooldown, hedge matched,
hedge position present, pending hedge present, g_blockNewOrders, g_stripped,
and group with zero main positions on both sides (PlaceInitialFrame handles
that). Uses existing PlaceInitialMarket so per-group 5s cooldown, per-side
Squeeze block, SMA filter, and stops-level guard are all reused. PENDING mode
behaviour is 100% unchanged.
