---
name: Golden2 EA v2.9.5 Stranded HD-Pending Sweep + MaxDD Always-On + Diagnostic
description: Fixes advance-queue freeze when a group has 0 positions but stale hedge pendings remain (main TP'd before price hit hedge pending) by adding unconditional HD-pending sweep at top of OnTick group loop independent of g_groupHedgeUsed flag. Moves ManageMaxDDClose() ABOVE the InpAllowTrade guard so kill switch fires even when AutoTrading is disabled. Adds 30s-throttled MAX-DD-CHK diagnostic log showing curEA vs threshold vs AccountInfoDouble(ACCOUNT_PROFIT) for misconfiguration debugging.
type: feature
---

## Bugs fixed
**A) Stranded hedge pendings + frozen advance queue.** Group N had losing SELL main → BUY_STOP hedge pendings armed → price reversed → SELL main closed at TP before any BUY_STOP filled → group ends with 0 positions but 8 stranded BUY_STOP pendings. `g_groupHedgeUsed[N]` stayed FALSE (no hedge POSITION ever existed, only pendings) so the v2.9.2 full-sweep at `OnTick` (which requires `g_groupHedgeUsed==true`) never fired. `IsPriorGroupSafeForAdvance(N)` returned `reason=5 block-pending-only` → `FindBlockingPriorGroup` → `TryAdvanceToNextGroup` held forever → no new orders system-wide.

**B) Max DD kill switch silently disabled.** `ManageMaxDDClose()` was called AFTER `if(!InpAllowTrade) return;` — if the user disabled AutoTrading on the EA or terminal, the kill switch stopped running. Also no diagnostic log existed to show what the EA computed vs the configured threshold, making it impossible to debug "why didn't it fire" complaints (e.g. user set `InpMaxDDValue=2,500,000` and floating loss was only $171k).

## v2.9.5 Fixes (`public/docs/mql5/Golden2_EA.mq5`)

### A) Stranded HD-Pending Sweep (~line 4144, OnTick group loop)
Inserted BEFORE the `if(!hasPos && !hasPend)` flat-reset branch:
```cpp
if(!hasPos && hasPend){
   if(CountGroupPendingsByTagPrefix(g, true, "") > 0){
      DeleteGroupPendings(g, 1);
      hasPend = GroupHasAnyPendings(g); // refresh so flat-branch can fire same tick
   }
}
```
Unconditional — does not consult `g_groupHedgeUsed`, `g_groupPostMatchAvgActive`, or `pct`. `DeleteGroupPendings(g, 1)` filters `hedgeFilter==1` so main `G_IN` pendings (PENDING entry mode) are never touched. After sweep, `hasPend` is refreshed so the flat-reset branch can fire the same tick and the group becomes truly empty → next-tick advance check returns safe-flat (`reason=0`).

### B) Max DD Always-On (~line 4115, OnTick top)
Reordered:
```cpp
ManageMaxDDClose();                    // [v2.9.5] moved BEFORE AllowTrade gate
if(!InpAllowTrade){ RenderDashboardThrottled(); return; }
RefreshSqueezeStateThrottled();
```
Kill switch now runs every tick even when `InpAllowTrade==false`.

### C) MAX-DD-CHK Diagnostic (~line 4055, inside ManageMaxDDClose)
Added 30s-throttled verbose log BEFORE the `if(!trig) return;` early-exit:
```
Golden2 v2.9.5: MAX-DD-CHK mode=DOLLAR curEA=$171234.50 (22.34%) threshold=$2500000.00 bal=$766408.04 acctFloat=$-171099.20 trig=no
```
- `curEA` = EA-only sum of `POSITION_PROFIT + POSITION_SWAP` (matches kill-switch math)
- `acctFloat` = `AccountInfoDouble(ACCOUNT_PROFIT)` — total account floating P/L incl. all other EAs and commission accounting. Lets user diff and detect threshold misconfig.
- New global: `datetime g_lastMaxDDLog = 0;`

### D) Metadata
- `#property version "2.95"` + new description
- Header banner v2.9.4 → v2.9.5
- Dashboard title `Golden2 EA v2.9.5`
- Init log prefix `Golden2 EA v2.9.5 initialized | StrandedHDPendingSweep=ON | MaxDDAlwaysOn=ON(runs-before-AllowTrade) | MaxDDDiagLog=30s | ...`

## Untouched (Rules of Steel)
- ❌ `trade.Buy/Sell/PositionClose/OrderSend/OrderModify/BuyStop/SellStop` — reuses existing `DeleteGroupPendings` + `trade.PositionClose/OrderDelete` from ManageMaxDDClose
- ❌ Entry SMA/INSTANT/PENDING, Grid Loss/Profit, ATR snapshot, candle confirm
- ❌ Hedge **arm** logic (`InpHedgeArmPercent`, BlockNewOrderPercent, delay, ClaimMutex, `PlaceHedgePendingSet`, `MirrorLossSideToHedgePendings`) — sweep is purely cleanup
- ❌ ManageGroupHedgeArm disarm logic — sweep runs BEFORE it, sweep target (zero-position case) overlaps but is now guaranteed regardless of flag state
- ❌ One-Hedge-Per-Group (v2.8.5), Hedge Orphan Offset (v2.8.6), Stale-side sweep (v2.9.2), Disarm Partial-Fill (v2.9.3)
- ❌ Triple-Gate / Recovery Grid / Seed Lock / Order Lock / Prior Advance Bypass
- ❌ Post-Match Avg TP/SL (v2.8.4), v2.9.1 Backtest Perf Pack, v2.9.4 Max Lot Caps
- ❌ Max DD trigger formula, 30s close cooldown, flatten loop — only added the diagnostic log and moved the call site
- ❌ License / News / Time / Sync / Dashboard layout / ParseComment / MakeComment

## Rule
**Hedge-pending cleanup must be flag-independent.** Any state where a group holds ZERO positions but stale hedge pendings remain must be cleaned every tick, regardless of `g_groupHedgeUsed`, `g_groupPostMatchAvgActive`, DD%, or loss-side state — otherwise the advance queue can deadlock on `block-pending-only`. **Kill switches must run before the AutoTrading gate.** A safety mechanism that stops working when the user disables trading defeats its purpose.
