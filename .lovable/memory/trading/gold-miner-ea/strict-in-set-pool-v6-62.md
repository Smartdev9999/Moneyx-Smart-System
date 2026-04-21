---
name: Strict In-Set Pool v6.62
description: ManageHedgeMatchingClose treats hedge/reverse/bound uniformly within ONE set; no cross-set leak; partial close keeps set active for recovery grid
type: feature
---
v6.62 of Gold Miner EA enforces strict in-set profit pooling for `ManageHedgeMatchingClose(idx)`:

- Members of a set = hedge ticket + reverseHedge tickets + boundTickets[]
- Phase A: every member with pnl>0 → profit pool (budget)
- Phase B: every member with pnl<0 → loss pool (sorted by |loss| desc)
- Phase C: greedy match — if budget covers losses, close profits + matched losses
- Hedge ticket can be in EITHER pool (no more `MathMax(hedgeProfit,0)` discrimination)
- Trigger gate uses new `ProbeSetProfit(idx)` so matching enters even when hedge is in loss but bound on other side is profit
- Strict in-set: never touches tickets belonging to other sets / generations (Accumulate Close remains the only cross-set mechanism)
- Partial close keeps set ACTIVE → recovery grid continues; full flat → claim sequential recovery owner
