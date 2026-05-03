---
name: Gold Miner EA v7.02 — Hero Lock-Profit SL Validate Fix + Tick Opp-Clear
description: Fix 1 — ValidateHeroLockProfitSL had inverted sl-vs-bid/ask checks (SELL used `sl<ask-stops`, BUY used `sl>bid+stops`) so PositionModify was always skipped → BE_GUARD ticket SL stayed 0. Now SELL requires `sl>ask+stops`, BUY requires `sl<bid-stops`. Fix 2 — added tick-based opposite-clear detector in ManageHeroOppositeClose that closes Hero when opposite non-Hero basket reaches 0 via Broker TP/SL (not only via EA CloseAllSide hooks).
type: feature
---

# v7.02

## Bugs
1. `ValidateHeroLockProfitSL` SELL/BUY checks were swapped vs broker semantics → returned false → SL=0 on Hero tickets despite phase=BE_GUARD on dashboard.
2. `CloseOppositeHeroOnBasketClose` only fired from `CloseAllSide` / `CloseGenSide` / `CloseAllSideTF` — when the opposite basket cleared via per-ticket Broker TP, Hero stayed open indefinitely.

## Fix
- Inverted the comparisons; added 30s throttled diagnostic log when validation fails.
- Added tick loop at end of `ManageHeroOppositeClose()`: for each side in BE_GUARD with Hero alive, if opp non-Hero basket count = 0 AND opp has no Hero → `CloseHeroOnSide(side, "OppositeBasketFlatTick")`.

## Not Changed
OrderSend / trade.Buy/Sell/PositionClose, entry conditions, GL/GP lot/distance/candle, Avg TP/Trail formulas, Hedge/Triple-Gate/Recovery, ComputeHeroLockProfitSL formula, BuildHeroTicketCache (Sticky Tag v7.01), IsHeroTicket guards, License/News/Sync.
