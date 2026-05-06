---
name: Golden Kuy3 v1.50 Hero TP-Only Opposite Close
description: Hero closes only when opposite basket flattens with realized profit (TP); SL/loss = Hero holds at BE-SL waiting next opp TP cycle. New per-side opp realized accumulator g_oppBasketRealized_Hero<Buy/Sell>, reset on hero ARM/CLOSE and on HOLD (so each opposite basket cycle judged independently). InpHero_OppCloseRequireTP toggle (default true) + InpHero_OppCloseMinProfit threshold.
type: feature
---

## Bug v1.49
- `ManageHeroOppositeClose` v7.02 detector closed Hero whenever opp basket=0, regardless of close reason. Per-Order Trail / SL / Cost-Hit on opposite basket caused Hero to close immediately, breaking the lock-profit hedge.

## Fix v1.50
- New globals: `g_oppBasketRealized_HeroBuy/Sell` + `g_oppBasketLastDealTime_*`.
- `OnTradeTransaction` (DEAL_ENTRY_OUT branch) attributes non-Hero deal P/L to opp Hero accumulator if that Hero side is ARMED/BE_GUARD. Hero-protected tickets (`IsHeroProtectedTicket`) skipped.
- `BuildHeroTicketCache` Branch B promotion (NONE→ARMED) zeros the accumulator so the hedge window starts fresh.
- `CloseHeroOnSide` zeros the accumulator on close.
- v7.02 detector now requires `oppRealized > InpHero_OppCloseMinProfit` (default 0). If false → log throttled HOLD message + reset accumulator (so next opp basket cycle is judged independently); Hero stays locked at BE-SL.
- New inputs:
  - `InpHero_OppCloseRequireTP` (default true) — false reverts to v1.49 behavior.
  - `InpHero_OppCloseMinProfit` (default 0.0) — minimum opp realized $ to qualify as TP.

## ไม่เปลี่ยน (กฎเหล็ก)
- ❌ trade.Buy/Sell/PositionClose / OrderSend / OpenInitial / OpenGrid / CalcGridLot
- ❌ Per-Order BE/Trail / Avg-Trail strict-2-cross / TP modes / Accumulate / Cost-Hit Restart
- ❌ Hero price-extreme selection (BUY lowest / SELL highest) v1.48
- ❌ BuildHeroTicketCache Branch A v1.49 take=min(N,nPool) / IsHeroProtectedTicket guards
- ❌ ComputeHeroLockProfitSL / ApplyHeroLockProfitSL / StripBrokerTPSLFromHeroTickets
- ❌ Side-Alternation Lock v1.46 / Single-Side Lock v1.45 / Post-close grace
- `InpHero_Enabled=false` → behavior = v1.49
- `InpHero_OppCloseRequireTP=false` → exact v1.49 close behavior
