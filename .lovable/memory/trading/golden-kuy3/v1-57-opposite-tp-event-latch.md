---
name: Golden Kuy3 v1.57 Opposite TP-Event Latch
description: Hero closes via TP-event latch armed in OnTradeTransaction even when AutoReEntry/Grid opens new opposite ticket same tick; strict-alt consumed only at Hero CLOSE not activation.
type: feature
---

## Bug v1.56
`ManageHeroOppositeClose` required `CountNonHeroMainOnSide(opp)==0`. After BUY basket TP, AutoReEntry/Grid re-opened a BUY ticket the same tick, so SELL Hero never released. Also `g_heroNextAllowedSide` was cleared on activation, breaking the alternation gate.

## Fix v1.57
- New globals `g_oppTPEvent_HeroBuy/Sell` (+ time). Set in `OnTradeTransaction` when an opp non-Hero deal closes with `DEAL_REASON_TP` or while `g_oppCloseIntent_AvgTP_*` is active AND Hero phase==BE_GUARD.
- New first pass in `ManageHeroOppositeClose`: phase==BE_GUARD + latch true + `oppRealized>InpHero_OppCloseMinProfit` -> `CloseHeroOnSide` (reason `OppositeTPEventLatch`). No `CountNonHeroMainOnSide(opp)==0` check.
- v1.56 flat-basket gate kept as fallback.
- `g_heroNextAllowedSide` no longer cleared at activation — only `CloseHeroOnSide`/external close/auto-release rotates it.
- Dashboard: new `TP Event` row (`SELL->BUY (waiting close)` / `BUY->SELL` / `BOTH`).
- Header changelog trimmed; full history lives in `mem://trading/golden-kuy3/*`.

## Unchanged
- All trade.* / OrderSend / Grid / Per-Order BE/Trail / Avg-TP/Avg-Trail strict-2-cross / TP modes / Accumulate / Cost-Hit / `IsHeroProtectedTicket` / `ApplyHeroLockProfitSL` / Side-Alternation v1.46 / Single-Side Lock v1.45.
- `InpHero_Enabled=false` => v1.56 inert.
