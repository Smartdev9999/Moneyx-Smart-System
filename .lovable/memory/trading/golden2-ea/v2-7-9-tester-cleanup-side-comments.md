---
name: Golden2 EA v2.7.9 Tester Chart Cleanup + Side-Tagged Comments
description: Auto strips ATR/ADX/BB/KC/EMA/MA chart graphics + closes aux per-TF charts in Strategy Tester (no input — hardcoded ON in tester); MakeComment now embeds B_/S_ side tag (G2_B_IN, G2_S_GL#1, G3_B_HD_IN); ParseComment peels optional B_/S_ for backward compat
type: feature
---

# v2.7.9

## Tester chart cleanup (no new input)
- New `CleanupChartIndicatorsInTester()` — `ChartIndicatorDelete` every indicator across main + all sub-windows; disables grid/period-sep/volumes; in non-visual tester also disables trade-levels + autoscroll. Called once in `OnInit` after tester detection.
- New `HideAuxiliaryTesterCharts()` — `ChartClose` every chart whose id != `ChartID()`; called once in `OnInit` and re-swept every 60s in `OnTick` via `g_lastAuxChartSweep` throttle.
- Both are no-op when `MQLInfoInteger(MQL_TESTER) == 0` (live trading untouched).
- All indicator HANDLES (`g_atrHandle`, `g_sqATR`, `g_sqADX`, `g_sqBB`, `g_sqKCEMA`, `g_sqEMA`) bind to (symbol,TF) and keep computing — only chart graphics removed. Squeeze/Grid/Exit/Hedge logic identical.

## Side-tagged comments
- `MakeComment(int g, ENUM_SIDE side, bool hedge, string tag)` now produces `G{n}_{B|S}_{tag}` or `G{n}_{B|S}_HD_{tag}`. Examples: `G2_B_IN`, `G2_S_GL#1`, `G3_B_HD_IN`, `G3_S_HD_GL#2`.
- `ParseComment` peels optional `B_` / `S_` between `G{n}_` and `[HD_]tag`. Legacy comments without side tag still parse (backward-compat).
- All 11 callsites updated (Initial Buy/Sell, Initial Market, ReArm Buy/Sell, GL, GP, Hedge mirror loss tags, Hedge IN legacy, Hedge GL legacy, Continuation grid).
- Tag matching downstream (`StringFind(tag, "GL")`, `tag=="IN"`, etc.) untouched — `tag` returned from ParseComment is identical to v2.7.8.

## Not changed
OrderSend / trade.Buy/Sell/PositionClose/OrderModify/BuyStop/SellStop/OrderDelete; Entry SMA/INSTANT/PENDING; Squeeze BB/KC/ADX/EMA/ATR multi-TF; Grid Loss/Profit lot/distance/candle confirm/ATR snapshot; Hedge mirror / Triple-Gate / Pending hedge / Block percent; Avg TP/SL / Per-order trail / Bar-close trail / Cost-Hit / Accumulate; Daily target / Drawdown / News / License / Sync; Force-close opp unhedged (v2.7.8); Squeeze pause trailing.
