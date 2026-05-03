---
name: Gold Miner EA v7.00 — Hero GL-Only + BE_GUARD Bugfix + Close-Path Audit
description: Hero pool now ONLY _GL orders (INIT/GP excluded from tagging but still counted in threshold). Fixed BE_GUARD never triggering (v6.99 dead g_heroLockedSide check). ManagePerOrderTrailing skips Hero. OnTradeTransaction emits 'Hero CLOSED reason=' audit. Dashboard adds GL pool counter.
type: feature
---

# v7.00

## Bugs Fixed
- **BE_GUARD never fired (v6.99)**: `DetectSameSideBasketClearedForHero` checked `(int)side != g_heroLockedSide` which was always -1 (deprecated) → BE_GUARD never set → lock-profit SL never applied → Hero had no protection.
- **INIT/GP wrongly tagged as Hero**: spec says only _GL is eligible; Hero pool now filtered to _GL only.
- **Per-order trailing modified Hero SL**: added `IsHeroTicket()` skip at top of `ManagePerOrderTrailing` loop.

## Hero Spec (Final)
- Tag = N newest **_GL** orders per side (POSITION_TIME_MSC desc + ticket tiebreak)
- Activation gate = side TOTAL active (INIT+GL+GP) ≥ `InpHero_MinOrdersToActivate`
- Close conditions ONLY:
  1. Lock-profit SL hit
  2. Opposite-side basket clears (CloseOppositeHeroOnBasketClose hook)
  3. Accumulate / global close
- Per-order trailing, breakeven, basket trailing SL never touch Hero

## New
- `g_heroDash_BuyGLPool / SellGLPool` — dashboard shows `36/20 GL:30 Hero:3 ARMED`
- OnTradeTransaction Hero audit log: `v7.00 Hero CLOSED ticket=#653 reason=LockProfitSL_HIT|BrokerTP_HIT|EA_PositionClose|Manual|Other profit=...`

## Not Changed
OrderSend / trade.Buy / Sell, entry conditions, GL/GP lot calc, Avg TP/Trail formulas, hedge / triple-gate / recovery, drawdown / daily target / balance guard, news / license / sync.
