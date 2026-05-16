---
name: Golden2 EA v2.9.2 Hedge-Used Advance Bypass + Stale Opposite-Side Pending Cleanup
description: Fixes two related freezes — (A) IsPriorGroupSafeForAdvance / IsGroupSafeToAdvance now safe-pass on g_groupHedgeUsed alone (no longer requires g_groupPostMatchAvgActive), unblocking advance queue when every prior group sits in Hedge USED/LOCKED PostAvg:WAITING; (B) MirrorLossSideToHedgePendings cleanup now filters by order-type so opposite-side legacy hedge pendings are deleted on side flip, ManageGroupHedgeArm sweeps stale opposite-side pendings before early-return, and OnTick group loop full-sweeps hedge pendings once group is post-match-active or hedge positions all closed
type: feature
---

## Bug A — Advance queue freeze
Visual: G1-G4 all `ACTIVE Hedge USED/LOCKED PostAvg:WAITING`, every Triple-Gate row showed `Cy:Wait Z:OUT OK Win:$X need:$200` — gates green but G5 never opened, no new orders for the entire system.

Root cause in `IsPriorGroupSafeForAdvance`:
```cpp
if(g_groupHedgeUsed[g] && g_groupPostMatchAvgActive[g]){ reason=1; return true; }
```
Required BOTH flags. During the gap between hedge fill and PostMatch activation (Squeeze TF3 latch waiting Expansion→Normal), every prior group failed safe-pass → `FindBlockingPriorGroup` returned > 0 → `TryAdvanceToNextGroup` held forever.

## Bug B — Stale opposite-side hedge pendings
G6 had main SELL ladder + hedge BUY filled (B_HD_GL#3..#12) AND stale SELL_STOP pendings (G6_S_HD_GL#3..#11) at 3363.47, while G7 was already active.

Root cause: `MirrorLossSideToHedgePendings()` cleanup matched by tag only (`lossTags[k] == tag`). When the losing side flipped (BUY-loss → SELL-loss), the new mirror call placed BUY_STOP hedge pendings with same `GL#N` tags. Old SELL_STOP pendings shared the same tag strings → cleanup kept them by accident. Then `ManageGroupHedgeArm` early-returns on `hedgePosExists` → legacy SELL_STOP pendings persisted forever.

## v2.9.2 Fixes (`public/docs/mql5/Golden2_EA.mq5`)

### A) Hedge-Used Advance Bypass
- `IsPriorGroupSafeForAdvance` (~line 3198-3210): replaced `(g_groupHedgeUsed && g_groupPostMatchAvgActive)` with simple `if(g_groupHedgeUsed[g]) { reason=2; return true; }`. Safe-pass independent of PostMatch — One-Hedge-Per-Group (v2.8.5) guarantees no re-hedge can arm; Triple-Gate / Recovery resolves the group on its own.
- `IsGroupSafeToAdvance` (~line 3158-3175): added early-return `if(g_groupHedgeUsed[g]) return true;` for the current group with the same rationale.
- Hold-log reason mapping (~line 3344) added `case 2: reasonLbl = "hedge-locked";`.

### B) Stale Opposite-Side Pending Cleanup — 3 layers
1. **`MirrorLossSideToHedgePendings` (~line 1945-1977)** — cleanup loop now reads `ENUM_ORDER_TYPE`. If `order-type` doesn't match current `hedgeSide` (BUY hedge ↔ BUY_STOP/BUY_LIMIT, SELL hedge ↔ SELL_STOP/SELL_LIMIT), delete unconditionally before tag-keep check. Logs `Golden2 v2.9.2: HD stale-opposite-side delete G%d %s`.
2. **`ManageGroupHedgeArm` (~line 2069-2098)** — before early-return on `hedgePosExists`, detects `activeHedgeSide` from positions and sweeps any hedge pending whose order-type does not match. Logs `Golden2 v2.9.2: G%d post-hedge stale-side sweep %s`.
3. **OnTick group loop (~line 4068-4078)** — after `ManageGroupHedgeArm(g)`, if `g_groupHedgeUsed[g] && (g_groupPostMatchAvgActive[g] || CountGroupPositions(g,-1,1)==0)` AND any hedge pending remains, call `DeleteGroupPendings(g, 1)` for a full sweep. Catches edge case where `activeHedgeSide==-1` (hedge positions all closed but stale pendings remain).

### Version bump
- Header banner v2.9.1 → v2.9.2
- `#property version "2.92"` + new `#property description`
- Dashboard title `Golden2 EA v2.9.2`
- Init log: `HedgeUsedAdvanceBypass=ON | StalePendingCleanup=ON(MirrorSideFilter+ArmStaleSweep+PostMatchFullSweep) | PriorAdvBypass=HedgeUsed+RecLvl>0`

## Untouched (Rules of Steel)
- ❌ `trade.Buy/Sell/PositionClose/OrderSend/OrderModify/BuyStop/SellStop` — only `trade.OrderDelete` for stale pendings
- ❌ Entry SMA/INSTANT/PENDING (PlaceInitialMarket / PlaceInitialFrame / Re-Arm / Re-Entry)
- ❌ Grid Loss/Profit lot/distance/candle confirm/ATR snapshot
- ❌ Hedge **arm** logic (DD%, Arm/Disarm threshold, delay, BlockNewOrderPercent) — only added cleanup branches
- ❌ One-Hedge-Per-Group (v2.8.5) / Hedge Orphan Offset (v2.8.6) — extended cleanup only
- ❌ Triple-Gate (WinPool / MinGain / Reserve-Profit / Squeeze TF3 latch / shred passes)
- ❌ Recovery Grid + Continuation + Seed Lock (v2.8.8/v2.9.0), Recovery Order Lock (v2.8.9)
- ❌ Post-Match Avg TP/SL formula + timing (v2.8.4)
- ❌ Backtest Performance Pack (v2.9.1)
- ❌ `TryAdvanceToNextGroup` body, `FindBlockingPriorGroup`, `IsSideEffectivelySafeForAdvance`
- ❌ ParseComment / MakeComment B_/S_/HD_ tags
- ❌ License / News / Time / Sync / Dashboard layout

## Rule
**Advance safe-pass for prior groups must depend on hedge-lock state (no re-hedge possible), NOT on PostMatch activation state.** Tying the advance queue to PostMatch creates a deadlock window during the Triple-Gate wait. Stale opposite-side hedge pendings must be cleaned by order-type, not tag-only — tags are shared across both hedge sides.
