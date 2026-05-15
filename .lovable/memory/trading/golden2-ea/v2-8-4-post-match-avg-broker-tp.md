---
name: Golden2 v2.8.4 Post-Match Avg Broker TP/SL + Cross-Side Shred + Slim Hedge Dashboard
description: After Triple-Gate partial close residual+RC#N had no broker TP/SL (g_stripped early-returned v1.3 sync). v2.8.4 adds SyncPostMatchAvgTPSL pushing per-side avg TP/SL onto every residual+hedge+RC ticket; ShredAllNegativeFromAllProfit second pass closes losses using ALL profitable orders before placing Recovery; dashboard removes per-grid Grid#N rows + verbose Recovery row, adds compact Avg TP B/S row.
type: feature
---

## Bug
v2.8.3 placed RC#N successfully but residual main+hedge+RC orders all had naked TP/SL — `g_stripped[g]=true` makes `SyncSideTPSLToBroker` early-return, so broker never closed the group. Match-Close only re-fires on Squeeze TF3 latch + winProfit gate, which may never repeat.

## v2.8.4 changes (`public/docs/mql5/Golden2_EA.mq5`)

### New input
- `InpPostMatch_AvgBrokerTP=true` — after hedge match, push per-side avg-price TP/SL onto every residual+RC ticket
- `InpDashGridPairsMax` demoted to `const=0` (deprecated, .set backward-compat)

### New globals
- `double g_postMatchTP[51][2]` / `g_postMatchSL[51][2]` — cached prices per (group,side); reset on group-flat + on every fresh post-match cycle

### New functions
1. **`SyncPostMatchAvgTPSL(int g)`** — runs every tick when `g_stripped[g] || IsGroupHedgeMatched(g)`. Per side: `avg = GroupAveragePrice(g, side, -1)` (main+hedge), `tp = avg ± InpTP_PointsFromAvg*g_point`, optional SL via `InpSL_PointsFromAvg`. Honors `SYMBOL_TRADE_STOPS_LEVEL`. Pushes same tp/sl to every ticket on that side via `ModifyIfDifferent`. Tolerance 1pt cache.
2. **`ShredAllNegativeFromAllProfit(int g)`** — second pass after `CloseAllGroupSide(winSide)+ShredCloseLosingSide`. Collects every profitable position group-wide (any side, main or hedge) → closes them all (locks budget into realized) → uses pool to close losing tickets cheapest-first while `pool+p ≥ InpExitMinNetUSD`.

### Wiring
- `TryMatchingCloseForGroup`: after `ShredCloseLosingSide` calls `ShredAllNegativeFromAllProfit(g)`. After Recovery placement, force-resets `g_postMatchTP/SL` cache and calls `SyncPostMatchAvgTPSL(g)` immediately so RC#N gets broker TP same tick.
- OnTick group loop: `SyncPostMatchAvgTPSL(g)` runs after `TryMatchingCloseForGroup(g)`.

### Dashboard simplification (Right Panel)
- **Removed**: per-grid `Grid#N L:.. H:.. N:..` loop + verbose Recovery row
- **Added**: compact `Avg TP  B:<price>  S:<price>` row (only when `g_stripped || matched`)
- Recovery state collapsed into `TripleGrid` row: `G:$gain/$need RECOV RC#N/Max`

### Versioning
- `#property version "2.84"` + description updated
- Header banner, dashboard title, init log → v2.8.4
- Init log adds `PostMatchAvgBrokerTP=ON/OFF` and `ExitGate=...+CrossSideShred`

## Rules of Steel — UNTOUCHED
- ❌ trade.Buy/Sell/Send (Recovery RC#N reuses v2.8.3 placement)
- ❌ Entry SMA/INSTANT/PENDING flow, Squeeze BB/KC/ADX/EMA/ATR
- ❌ Grid Loss/Profit lot/distance/candle confirm
- ❌ Hedge mirror 1:1, pending hedge, arm/disarm, block percent
- ❌ Pre-hedge Avg TP/SL `SyncSideTPSLToBroker` (v1.3) — new sync function is separate
- ❌ Per-order trail / Bar-close trail / Cost-Hit / Accumulate / Force-close opp
- ❌ ParseComment / MakeComment B_/S_ tags
- ❌ ATR/ADX TesterHideIndicators (v2.8.1)
- ❌ Win-Pool gate + Sequential Queue + MinGain (v2.8.0/v2.8.1/v2.8.3) — all retained
- ❌ Prior-group advance guard (v2.8.2)

## Rule
**Once `g_stripped[g]` is set, broker TP/SL must come from `SyncPostMatchAvgTPSL` not `SyncSideTPSLToBroker`. Recovery RC#N orders inherit per-side avg TP/SL automatically — never let them stay naked.**
