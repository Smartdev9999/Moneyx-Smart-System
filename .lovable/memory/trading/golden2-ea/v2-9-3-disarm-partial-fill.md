---
name: Golden2 EA v2.9.3 Disarm Partial-Fill + DD Diagnostic
description: Extends HD pending disarm to also fire when some hedge positions are already filled — remaining hedge pendings are deleted as soon as DD% drops below InpHedgeDisarmPercent (filled positions kept for Triple-Gate/Recovery). Adds per-group 10s-throttled DISARM-CHK verbose log showing pct vs arm/disarm thresholds, hedge pending/position counts, and current loss side
type: feature
---

## Bug
User set `InpHedgeDisarmPercent = 70`. Expected: when loss-side DD% drops below 70, ALL pending hedge orders are cancelled. Observed: pendings stayed armed even after DD recovered.

## Root cause
`ManageGroupHedgeArm` disarm branch (line ~2063) guarded by `!hedgePosExists && hedgePendingExists`. If even one HD level filled (price spike → bounce), `hedgePosExists==true` and flow fell through to the v2.9.2 stale-opposite-side sweep (which only deletes pendings whose order-type mismatches the active hedge side). Same-side hedge pendings remained forever, regardless of DD recovery.

Additionally there was no log of the disarm check itself, so the user could not see pct/threshold to debug.

## v2.9.3 Fix (`public/docs/mql5/Golden2_EA.mq5`)

### A) Partial-Fill Disarm (~line 2096)
Inside the existing `if(hedgePosExists)` block, **before** the stale-opposite-side sweep:
```cpp
if(hedgePendingExists && pct < InpHedgeDisarmPercent){
   DeleteGroupPendings(g, 1);
   if(g_verboseEffective)
      PrintFormat("Golden2 v2.9.3: HD DISARM(partial-fill) G%d pct=%.1f<%.1f — kept %d filled HD pos", ...);
}
```
- Deletes only pendings (`DeleteGroupPendings(g, 1)` = hedge-side pendings). Filled HD positions remain — Triple-Gate / Recovery Grid handle them.
- Falls through to stale-side sweep afterwards (usually no-op since pendings just deleted).

### B) DISARM-CHK diagnostic (~line 2063)
Per-group throttle `g_lastDisarmChkLog[51]` — verbose-only PrintFormat every 10s:
```
Golden2 v2.9.3: HD DISARM-CHK G%d pct=%.1f arm=%.1f disarm=%.1f hPend=%d hPos=%d lossSide=%d
```
Lets user see why disarm did/didn't trigger.

### C) Metadata
- Header banner v2.9.2 → v2.9.3
- `#property version "2.93"` + description
- Dashboard title `Golden2 EA v2.9.3`
- Init log prefix `DisarmPartialFill=ON | HedgeUsedAdvanceBypass=ON | ...`
- New global: `datetime g_lastDisarmChkLog[51]`

## Untouched (Rules of Steel)
- ❌ `trade.Buy/Sell/PositionClose/OrderSend/OrderModify/BuyStop/SellStop` — only existing `DeleteGroupPendings` and `trade.OrderDelete` reused
- ❌ Hedge **arm** logic (`InpHedgeArmPercent`, BlockNewOrderPercent, delay, ClaimMutex, `PlaceHedgePendingSet`, `MirrorLossSideToHedgePendings`)
- ❌ Filled HD positions — only pendings touched on partial-fill disarm
- ❌ Entry SMA/INSTANT/PENDING, Grid Loss/Profit, ATR snapshot, candle confirm
- ❌ One-Hedge-Per-Group (v2.8.5), Hedge Orphan Offset (v2.8.6)
- ❌ Triple-Gate (WinPool / MinGain / Reserve-Profit / Squeeze TF3 latch / shred passes)
- ❌ Recovery Grid + Continuation + Seed Lock (v2.8.8/v2.9.0), Recovery Order Lock (v2.8.9)
- ❌ Post-Match Avg TP/SL (v2.8.4)
- ❌ v2.9.1 Backtest Performance Pack
- ❌ v2.9.2 Hedge-Used Advance Bypass + Stale Opposite-Side Pending Cleanup
- ❌ ParseComment / MakeComment, Dashboard layout, License / News / Time / Sync

## Rule
**Hedge disarm must be evaluated even when partial fills exist.** The disarm condition (`pct < InpHedgeDisarmPercent`) is symmetric — DD recovery should always trigger pending cleanup regardless of whether any hedge ladder level already filled. Only the filled positions are protected (handed off to Triple-Gate/Recovery).
