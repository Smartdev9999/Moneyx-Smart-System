---
name: Golden2 v2.8.0 MinGain + Recovery Unblock + Tester Fix
description: Hedge Exit gate adds MinGainUSD; sequential queue; recovery-mode advance unblock fixes stuck-order deadlock; Tester chart cleanup re-run after handle creation + 60s sweep
type: feature
---

## Problems fixed
1. **ATR/ADX subwindows still showed in v2.7.9 backtest** — `CleanupChartIndicatorsInTester()` ran in `OnInit` BEFORE `iATR/iADX/iBands/iMA` handles were created (line 3227 vs 3253), so it had nothing to delete. MT5 Tester then attached subwindows after handles bound.
2. **No "Min Gain" gate on Hedging Exit** — Triple-Gate fired the moment netCheck > InpExitMinNetUSD even if group was still deeply underwater vs. hedge-open snapshot.
3. **Order placement freezes** (log: `hold G3->G4 cur safe=1 priors safe=0 ... plSELL=-14723`) — older group with active hedge but no matching close could never satisfy `IsGroupSafeToAdvance`, deadlocking advance.

## v2.8.0 changes (in `public/docs/mql5/Golden2_EA.mq5`)

### New inputs (`=== Exit Triple Gate ===`)
- `InpExit_MinGainUSD = 100.0` — group net P/L must IMPROVE by ≥ N USD vs. hedge-open baseline before matching close
- `InpExit_SequentialQueue = true` — older active group must be flat before this group can match-close
- `InpExit_RecoveryAdvanceUnblock = true` — groups with post-match residual count as "safe" for advancing G(N+1)

### New globals
- `double g_groupNetAtHedgeStart[51]` — baseline group net P/L stamped first tick a hedge is observed
- `bool g_groupHedgeBaselineSet[51]` — baseline-stamped flag
- `bool g_groupInRecovery[51]` — set after partial matching close leaves residual; cleared when group flat

### Behaviour
1. **OnInit**: `CleanupChartIndicatorsInTester()` + `HideAuxiliaryTesterCharts()` now called AFTER all `iBands/iATR/iADX/iMA/iADX/iEMA` handles created (post-line 3295).
2. **OnTick 60s sweep**: Both `HideAuxiliaryTesterCharts()` AND `CleanupChartIndicatorsInTester()` run periodically.
3. **OnTick group loop**:
   - On group-flat: clear baseline + recovery flag.
   - On hedge first observed: stamp `g_groupNetAtHedgeStart[g] = GroupFloatingPL(g,-1,-1)`.
4. **TryMatchingCloseForGroup**:
   - Sequential queue: bail if older group has any positions.
   - Min Gain gate: bail if `(netCheck - baseline) < InpExit_MinGainUSD`.
   - After CloseAllGroupSide + ShredCloseLosingSide: if group still has positions → set `g_groupInRecovery[g] = true`.
5. **IsGroupSafeToAdvance**: returns `true` immediately when `InpExit_RecoveryAdvanceUnblock && g_groupInRecovery[g]`.
6. **Hold-log** version bumped → `Golden2 v2.8.0: hold G%d->G%d ... recovery=%s`.

### Rules of Steel — UNTOUCHED
- ❌ trade.Buy/Sell/PositionClose/OrderModify/Send
- ❌ Entry SMA/INSTANT/PENDING flow, Squeeze BB/KC/ADX/EMA/ATR logic
- ❌ Grid Loss/Profit lot/distance/candle confirm/ATR snapshot
- ❌ Hedge mirror 1:1 / pending hedge / arm/disarm / Block percent / Force-close opp unhedged
- ❌ Avg TP/SL / Per-order trail / Bar-close trail / Cost-Hit / Accumulate
- ❌ ParseComment / MakeComment (B_/S_ tags from v2.7.9 preserved)

### Deferred to v2.8.1 (from approved plan)
- Full input reorganisation + ~20 inputs → const conversion
- Recovery Grid order placement (`G{n}_{B|S}_RC#N`) with custom multipliers + dedicated TP basket
- Per-group Expansion→Normal latch (currently uses global `IsExpansionToNormal()`)
- Dashboard rows for Recovery / MinGain progress
