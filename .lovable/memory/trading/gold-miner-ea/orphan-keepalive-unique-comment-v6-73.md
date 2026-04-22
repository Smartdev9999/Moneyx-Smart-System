---
name: Orphan KeepAlive + Unique Recovery Comment + AvgTP Hedge Residue v6.73
description: v6.73 prevents recovery orphans (set kept alive), guarantees unique recovery comments, and pulls hedge partial-close residue into AVG_TP basket
type: feature
---
v6.73 fixes three bugs in v6.72 surfaced by image-915 (six identical GM_HD3_05 sells with TP=0.00 and stuck GM3/GM4 cycle):

1. **Unique recovery comment**: ManageHedgeGridMode now derives suffix from monotonic `g_hedgeSets[idx].recoveryGridCount + 1` and runs a collision-bump loop scanning all open positions for the same comment string. Suffix never repeats even if previous tickets get partial-closed or comments stripped.

2. **KEEP-ALIVE on hedge release**: When `mainHedgeExists` becomes false, the set first tries `PositionClose` on every recovery ticket; THEN re-scans positions. If any recovery orphan still exists, the set stays `active=true`, only `hedgeTicket/hedgeLots` are cleared, and `ManageRecoveryAvgTP` (or `SyncRecoveryBasketTP`) is called immediately so orphans always have a broker TP. Only when stillOpen==0 does the set deactivate and `g_hedgeSetCount--`.

3. **AvgTP hedge residue**: `ManageRecoveryAvgTP` adds Section 5 — scans positions matching hedge side + magic + symbol with empty/stripped comments (excludes `GM_HEDGE_*`, `GM_HD*`, `GM_HG*`, `_GL#`, `_GP#`, `_INIT`) and folds them into the weighted-avg basket. Single broker TP now covers recovery + hedge residue.

OnTick adds a 60s-throttled "v6.73 ORPHAN" warn log when no active sets remain but positions block cycle reset. Log prefix bumped to `v6.73 AVGTP-S2`.
