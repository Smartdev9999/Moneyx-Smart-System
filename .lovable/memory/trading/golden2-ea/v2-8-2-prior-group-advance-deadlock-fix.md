---
name: Golden2 v2.8.2 Prior-Group Advance Deadlock Fix
description: AreAllPriorGroupsSafe rewritten via IsPriorGroupSafeForAdvance — hedge-locked prior groups no longer block G(N+1); Triple-Gate/MinGain/Expansion gates are CLOSE conditions only, not advancement gates. Hold-log identifies blocking prior + reason.
type: feature
---

## Bug
Log spam `Golden2 v2.8.0: hold G2->G3 (cur safe=1 priors safe=0 ... recovery=OFF)` looped forever and EA stopped placing new orders. Root cause: `AreAllPriorGroupsSafe()` called `IsGroupSafeToAdvance(prior)`, which only returned true when the prior group was either flat OR `g_groupInRecovery==true`. A prior group that was hedge-locked but still waiting on Triple-Gate (Squeeze Expansion→Normal latch + MinGain USD + Sequential Queue) never satisfied either branch → permanent block.

## v2.8.2 changes (`public/docs/mql5/Golden2_EA.mq5`)

### New helpers
- `bool IsPriorGroupSafeForAdvance(int g, int &reason)` — returns true when:
  1. group flat with no pendings, OR
  2. `InpExit_RecoveryAdvanceUnblock && g_groupInRecovery[g]`, OR
  3. group has hedge AND each surviving main side passes `IsSideEffectivelySafeForAdvance` (empty / hedge-covered / profitable bypass).
  Reason codes: 0=flat, 1=recovery, 2=hedge-locked, 3=block-no-hedge, 4=block-unhedged-main, 5=block-pending-only.
- `int FindBlockingPriorGroup(int curG, int &reason)` — first 1..curG-1 that fails, or -1.

### Rewrites
- `AreAllPriorGroupsSafe(curG)` now delegates to `FindBlockingPriorGroup`. **No longer waits for Triple-Gate / MinGain / Expansion gates of prior groups.**
- `TryAdvanceToNextGroup` hold-log upgraded → `Golden2 v2.8.2: hold G%d->G%d ... blockPrior=G%d reason=<no-hedge|unhedged-main|pending-only>` so the journal pinpoints the offending older group.

### Version bump
- Header / `#property version "2.82"` / `#property description` / dashboard title / init log all updated to v2.8.2.

## Rules of Steel — UNTOUCHED
- ❌ trade.Buy/Sell/PositionClose/OrderModify/Send
- ❌ Entry SMA/INSTANT/PENDING flow
- ❌ Squeeze BB/KC/ADX/EMA/ATR computation
- ❌ Grid Loss/Profit lot/distance/candle confirm/ATR snapshot
- ❌ Hedge mirror 1:1 / pending hedge / arm/disarm / Block percent / Force-close opp unhedged
- ❌ Avg TP/SL / Per-order trail / Bar-close trail / Cost-Hit / Accumulate
- ❌ ParseComment / MakeComment B_/S_ side tags
- ❌ ATR/ADX TesterHideIndicators wiring (v2.8.1)
- ❌ Triple-Gate matching close logic (v2.8.0/v2.8.1) — only the *advancement guard* changed, not the *close gate*.

## Rule
**Advancement guards (open next group) and Close gates (Triple-Gate / MinGain / Squeeze TF3 latch) MUST stay independent.** Mixing them deadlocks the queue when a prior hedge-locked group sits in normal floating-loss state.
