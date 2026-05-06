---
name: Golden Kuy3 v1.51 Hero AvgTP-Trigger Only
description: Hero closes ONLY when opposite basket is flattened by Avg-TP/Avg-Trail/Master TP Dollar/%Bal/Accumulate (intent flag set just before CloseAllSide/CloseAllOurs). Per-Order Trail / SL / Cost-Hit / manual close DO NOT trigger Hero close — Hero holds at BE-SL. Master TP Points safety net auto-sets intent when ≥InpAvgTP_MinOrders broker TP closes occur on a side within 2s. Toggle InpHero_OppCloseRequireAvgTP (default true).
type: feature
---

## Bug v1.50
`ManageHeroOppositeClose` closed Hero whenever `opp basket = 0 AND oppRealized > 0`. Per-Order Trail closing 1-2 small profit tickets satisfied both → Hero closed prematurely without true Avg-TP hit.

## Fix v1.51
- New globals: `g_oppCloseIntent_AvgTP_<Buy|Sell>` + timestamp + `g_oppTPDealCount_*` window counter.
- Set intent = true just BEFORE `CloseAllSide/CloseAllOurs` from: Accumulate (both sides), TP Dollar, TP %Bal, Avg-Trail BUY HIT, Avg-Trail SELL HIT.
- Master TP Points safety net in `OnTradeTransaction`: when ≥`InpAvgTP_MinOrders` non-Hero tickets of the same side close with `DEAL_REASON_TP` within 2s → auto-set intent.
- `ManageHeroOppositeClose` v1.51 gate: `intentFlag == true` required (primary) + v1.50 `oppRealized > MinProfit` (secondary).
- Stale intent expiry: cleared after 60s if basket re-armed without consuming.
- Cleared on `CloseHeroOnSide` (consumed).
- Toggle `InpHero_OppCloseRequireAvgTP` (default true). False → exact v1.50 behavior.

## ไม่เปลี่ยน (กฎเหล็ก)
- ❌ trade.Buy/Sell/PositionClose/OrderSend / Grid entry/exit / lot multiplier
- ❌ Per-Order BE/Trail / Avg-Trail strict-2-cross / TP modes / Cost-Hit Restart
- ❌ Hero price-extreme select v1.48 / Branch A v1.49 / IsHeroProtectedTicket guards
- ❌ ApplyHeroLockProfitSL / StripBrokerTPSLFromHeroTickets
- ❌ Side-Alternation Lock v1.46 / Single-Side Lock v1.45 / Post-close grace
- `InpHero_Enabled=false` → v1.50 behavior
- `InpHero_OppCloseRequireAvgTP=false` → exact v1.50 behavior
