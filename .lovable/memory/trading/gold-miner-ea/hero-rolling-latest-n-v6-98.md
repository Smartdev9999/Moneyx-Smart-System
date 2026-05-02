---
name: Gold Miner EA v6.98 — Hero Rolling Latest-N + Hard Real-Time Protection
description: BuildHeroTicketCache rebuilds every tick (no throttle), sorts by POSITION_TIME_MSC + ticket; locked side always protects newest N active orders. EnsureHeroProtection() wraps SyncBrokerTPSL (timed + InstantTP) so basket Avg TP can't reach Hero. Hero skip added to CloseAllSideTF; CloseAllSide/CloseGenSide refresh cache before flatten.
type: feature
---

# v6.98

- BuildHeroTicketCache: throttle removed; sort by POSITION_TIME_MSC desc, ticket desc tiebreak; latest N tagged every tick (rolling).
- EnsureHeroProtection(reason): rebuild cache + StripBrokerTPSLFromHeroTickets. Called pre+post SyncBrokerTPSL in OnTick timed sync and in OpenOrder InstantTP path.
- CloseAllSide / CloseGenSide / CloseAllSideTF: BuildHeroTicketCache() at top; CloseAllSideTF also gets CloseOppositeHeroOnBasketClose hook + IsHeroTicket skip.
- Single-side exclusive lock + lock-profit BE-SL + opposite-basket close hook preserved.
- Version bumped: #property version 6.98, description updated, OnInit/OnDeinit Print, dashboard headerVersion.

## Not changed
OrderSend / trade.Buy/Sell, SMA/ZigZag entry conditions, GL/GP logic, Avg TP/SL formulas, hedge/triple-gate/recovery, drawdown/balance guard, news/license/sync.
