---
name: Golden2 v2.8.1 Squeeze-Based Exit Gate + TesterHideIndicators
description: Hedge Exit gate now uses Volatility Squeeze TF3 latch (per-group seenExp + expToNormal) instead of duplicate Exit BB/Keltner inputs; TesterHideIndicators(true) called BEFORE iATR/iADX/iBands/iMA so ATR/ADX never attach to backtest chart; Right Panel adds Gold-Miner-style Gate (T:SQ Cy:.. Z:..) + TripleGrid (G:gain/need RECOV) rows per hedge-active group
type: feature
---

## Fixes
1. **ATR/ADX still showing in Tester** — root cause: ChartIndicatorDelete fires AFTER iATR/iADX handles created. v2.8.1 calls `TesterHideIndicators(true)` in OnInit BEFORE any handle creation. Per MQL5 docs every handle created after that call is flagged hide. Cleanup + aux-chart sweep retained as safety.
2. **Duplicate Exit Expansion settings** — `InpExitTF/BBPeriod/BBDev/KeltnerATR/KeltnerMult` removed from input panel (kept as `const` for log/.set compat). Hedge-exit gate now reuses Squeeze state on largest TF (`InpSQ_TF3` = `g_sqExpansion[2]`). g_bbHandle/g_atrHandle no longer created (also stops Tester from spawning that ATR subwindow).
3. **Per-group latch** — new `g_groupSeenExp[51]` + `g_groupExpToNormal[51]`; `RefreshGroupExpansionLatch(g)` called every tick when hedge active; latched state survives until group flat. `IsExpansionToNormalForGroup(g)` replaces snapshot-only `IsExpansionToNormal()`.
4. **Hedging dashboard** — for every hedge-active group, Right Panel adds:
   - `Gate    T:SQ Cy:Wait Exp/Wait Norm/Ready Z:IN ZONE/OUT n/needpts/OUT OK npts`
   - `TripleGrid  G:$gainNow/$MinGain[ RECOV]`

## Not changed
- trade.Buy/Sell/PositionClose/OrderModify/Send, Entry SMA/INSTANT/PENDING
- Squeeze BB/KC/ADX/EMA/ATR computation, Grid Loss/Profit, Hedge mirror, Avg TP/SL
- v2.8.0 Sequential Queue + MinGainUSD + RecoveryAdvanceUnblock logic intact
- ParseComment/MakeComment B_/S_ side tags
