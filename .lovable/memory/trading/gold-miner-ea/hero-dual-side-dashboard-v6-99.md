---
name: Gold Miner EA v6.99 — Hero Dual-Side Independent + Dashboard Monitor
description: Removes single-side g_heroLockedSide gate; both BUY and SELL independently protect their own newest N when side TOTAL >= InpHero_MinOrdersToActivate. Adds purple HERO Monitor section to dashboard showing per-side active/threshold/Hero count/phase + protected ticket IDs. Rolling latest-N preserved (POSITION_TIME_MSC + ticket).
type: feature
---

# v6.99
- BuildHeroTicketCache: removed `g_heroLockedSide` lock — both sides eligible simultaneously when each meets threshold.
- New globals: g_heroDash_{Buy,Sell}{Active,Tagged,Tickets,TicketN} for dashboard monitor.
- CloseOppositeHeroOnBasketClose: no longer requires lockedSide match; any side in BE_GUARD phase qualifies.
- Dashboard adds HERO section (purple): Hero Cfg / Hero BUY / Tix BUY / Hero SELL / Tix SELL with phase WAIT/READY/ARMED/BE_GUARD.
- g_heroLockedSide kept (deprecated, unused) for .set/state compat.
- Version bumped: 6.98 -> 6.99 in #property version, description, header, init/deinit Print, dashboard headerVersion, audit log prefix.

## Not changed
OrderSend / trade.PositionClose, entry/SMA/ZigZag, GL/GP, Avg TP/SL, hedge, triple-gate, drawdown, news/license/sync, lock-profit BE-SL formula, EnsureHeroProtection wrapping.
