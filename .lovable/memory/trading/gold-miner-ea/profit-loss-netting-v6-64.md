---
name: Profit-Loss Netting v6.64
description: Within allowed generation, bound profits shred oldest losses (greedy budget = totalProfit − MatchMinProfit); profit-only locks; runs even when hedge is in loss
type: feature
---
Gold Miner EA v6.64 introduces `RunBoundProfitLossNetting(int gen)` which scans all bound positions of `gen` (excludes `GM_HEDGE_*`), splits into profit/loss buckets, and uses the profit pool to close oldest losses via greedy match where `budget = totalProfit − InpHedge_MatchMinProfit`. If no losses exist it locks profits ("profit-only" close). If losses exist but none fit the budget, it does nothing (waits for more profit / orphan grid).

Integration:
- `ManageOrphanGrid()` — call netting before recount/expansion so grid only expands on residual losses.
- `ManageHedgeSets()` — after Triple Gate passes, if `boundGeneration == g_seqAllowedGen` call netting + `RefreshBoundTickets(h)`. Runs regardless of hedge PnL sign (fixes case where hedge in loss blocked all bound profit-taking).

Safety:
- Disabled when `InpHedge_UseMatchingClose = false`.
- In sequential mode (`InpHedge_SequentialRelease = true`) only operates on `g_seqAllowedGen`.
- Uses existing `InpHedge_MatchMinProfit` as buffer; no new inputs.
- Uses `trade.PositionClose()` + `Sleep(50)` (existing pattern).

Dashboard: new "Netting" row shows `Last GenN (GMx): closed PP+LL net $X @ HH:MM:SS`.
