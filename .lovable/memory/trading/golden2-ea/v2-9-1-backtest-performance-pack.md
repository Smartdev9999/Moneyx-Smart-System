---
name: Golden2 EA v2.9.1 Backtest Performance Pack
description: Tester-aware silencing of Print/PrintFormat (g_verboseEffective derived from InpVerboseLog && !(tester && InpTester_SilenceLogs)), DrawAverageAndTPLinesForGroup skipped in Tester via InpTester_DisableChartDraw, aux-chart sweep limited to visual Tester only, optional InpTester_TickStrideMs throttle. Zero trading-logic changes.
type: feature
---

# v2.9.1

## New inputs
- `InpTester_SilenceLogs = true` — silences every `if(InpVerboseLog) PrintFormat(...)` site in Tester
- `InpTester_DisableChartDraw = true` — early-return in `DrawAverageAndTPLinesForGroup` when in Tester
- `InpTester_TickStrideMs = 0` — optional OnTick stride throttle (default off → full accuracy)

## Mechanism
1. Renamed every read of `InpVerboseLog` to global `g_verboseEffective` (58 sites, sed replace). Input declaration kept intact. `g_verboseEffective = InpVerboseLog && !(g_isTesterMode && InpTester_SilenceLogs)` set once in OnInit.
2. OnTick top guard: if Tester + stride>0 + `GetTickCount()-g_lastTickMs<stride` → return.
3. Aux-chart sweep: `if(g_isTesterMode && g_isVisualMode && ...)` (was `g_isTesterMode` only).
4. `DrawAverageAndTPLinesForGroup`: existing non-visual-Tester guard kept; added `InpTester_DisableChartDraw` guard.

## Untouched (Rules of Steel)
- `trade.Buy/Sell/PositionClose/OrderModify/OrderSend/BuyStop/SellStop/OrderDelete`
- Entry SMA/INSTANT/PENDING, Grid Loss/Profit, Recovery Grid ladder, Hedge mirror, Triple-Gate, Avg TP/SL, Trailing, Squeeze BB/KC, License/News/Time/Sync, MakeComment/ParseComment.

## Expected
30-60% faster backtest with verbose+dashboard previously enabled. Live trading identical.
