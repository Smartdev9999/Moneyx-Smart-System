---
name: sequential-comment-scan-v6-60
description: Gold Miner EA v6.60 — Sequential Release uses live-comment gen scan; matching close pools profitable bound orders into budget
type: feature
---

Gold Miner EA v6.60 replaces the struct-based sequential gate (v6.57–v6.59) with a deterministic **comment-based scan**. `GetSequentialAllowedGeneration()` walks `PositionsTotal()` filtered by symbol+magic and parses each `POSITION_COMMENT` via `ParseGenerationFromComment()`:

- `"GM"` or `"GM_*"` (e.g. `GM_GL#3`, `GM_GP#1`) → Gen 0
- `"GMN_*"` (e.g. `GM1_GL#2`, `GM5_GP#1`) → Gen N
- `"GM_HDn"` → Gen (n - 1)  (hedge of cycle n-1)

It returns the **lowest** generation that still has any open order, or `-1` when nothing is live. This becomes `g_seqAllowedGen` and is the single source of truth for sequential gating.

`ManageHedgeSets()` freezes every active set whose `boundGeneration != g_seqAllowedGen` (matching/avgTP/partial/grid recovery only — hedge order, bound tickets, expansion tracking remain intact). `ManageOrphanGrid()` and per-gen grid loss/profit loops use the same `g_seqAllowedGen`. Initial entry of new cycles is **never** blocked (v6.59 rule preserved) — trading continues while older generations recover one-at-a-time.

`ManageHedgeMatchingClose()` now pools profitable bound orders (counterSide, pnl > 0) into `boundProfitPool` and adds it to `totalBudgetProfit = hedgeProfit + reverseProfit + boundProfitPool`. After closing the hedge and profitable reverse tickets, the matched profitable bound tickets are also closed so the entire set settles in balance instead of leaving profitable bounds open.

Dashboard row shows `Seq Release | ON | Allowed: GenN (GMN_*+GM_HD(N+1)) | New cycles: ALLOWED | Frozen Hedge: X | Frozen Orphans: Y`. With `InpHedge_SequentialRelease = false` the helper returns -1 and behavior matches pre-v6.57.
