---
name: Gold Miner EA v7.04 — Single-Side Hero Lock + Active Per-Side Gen Isolation
description: Hero now activates only on ONE side at a time via InpHero_SingleSideLock (default ON) — non-owner side gets phase forced to NONE in BuildHeroTicketCache until owner clears (CountHero==0 && phase==0). Per-side gen isolation default ON; new GetActiveGenForSide(side) helper rewires 11 orderGen filter sites (CountOrders/NormalOrderCount/RecoverInitialPrices/FindMaxLot/FindMaxGridLevel/FindLatestGridPrice + TF variants) so GM(N+1) orders on Hero-owning side are fully visible to grid/TP/trailing. CloseHeroOnSide reset (v7.03) + Cycle reset (v6.66) extended to clear g_sideGen_Buy/Sell + g_heroOwnedGen_Buy/Sell. Dashboard adds Hero Owner + Side Gen BUY/SELL rows (gold when overridden). Hero formula, OrderSend, OnTradeTransaction audit, BE_GUARD logic, ValidateHeroLockProfitSL (v7.02), Post-Close Grace (v7.03) untouched.
type: feature
---

# v7.04

## Bugs Fixed
1. v6.99/v7.03 allowed Hero to activate on BOTH sides simultaneously — when BUY had Hero (e.g. tickets 145, 146) and price moved up causing SELL basket to grow past threshold, SELL also got Hero tagged → opposite-side close blocked → BUY couldn't unwind.
2. v7.03 InpHero_PerSideGenIsolation existed but `if(orderGen != g_cycleGeneration) continue;` filter at 11 sites made any GM(N+1) entry invisible to counters/grid logic.

## Fix
- **Single-Side Lock** (`InpHero_SingleSideLock`, default ON): in `BuildHeroTicketCache` compute `activeOwner = side with CountHero>0 OR phase!=0`. Inside the per-side loop, when `curPhase==0 && sideId != activeOwner`, hard-skip and force phase=NONE. Auto-releases when owner's `CloseHeroOnSide` runs.
- **Per-Side Gen Default ON**: `InpHero_PerSideGenIsolation` now default `true`.
- **`GetActiveGenForSide(side)`** new helper returns `g_sideGen_<side>` if set else global `g_cycleGeneration`.
- **Filter rewire** (11 sites via global replace): RecoverInitialPrices ×2, CountOrders, NormalOrderCount, FindMaxLotOnSide, FindMaxGridLevelOnSide, FindLatestGridPrice, RecoverTFInitialPrices, CountOrdersTF, FindLatestGridPriceTF, FindMaxGridLevelOnSideTF — each now reads `(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE)` and gates on `GetActiveGenForSide(...)`.
- **Cycle reset extension** (TryResetCycleStateIfFlat + Balance Guard reset path): also zeros `g_sideGen_Buy/Sell` + `g_heroOwnedGen_Buy/Sell`.

## Dashboard
HERO Monitor adds 3 rows under "Hero Cfg":
- `Hero Owner: BUY/SELL/NONE (locked|dual)` — gold when owned
- `Side Gen BUY: GM2 (Hero owns GM1)` — gold when overridden
- `Side Gen SELL: GM1 (Hero owns GM…)` — same

## Not Touched
- OrderSend / trade.Buy / trade.Sell / trade.PositionClose
- Entry conditions (SMA/EMA/ZigZag/BB/Squeeze)
- Grid loss/profit lot/distance/candle-confirm/MaxGrid trailing math
- TP/SL/Trailing/Breakeven/Avg TP calculations
- Hedge/Triple-Gate/Recovery/DD% TP/Daily Target/Balance Guard activation logic
- Accumulate Close logic
- License/News/Sync modules
- Hero formula: ComputeHeroLockProfitSL, ValidateHeroLockProfitSL (v7.02), BE_GUARD apply path, Post-Close Grace (v7.03), OnTradeTransaction Hero audit
- Hedge/recovery/orphan filter sites at L9378, L10282, L10790, L11162 (intentionally global-gen anchored)
