---
name: Gold Miner EA v7.07 — Hero Candidate vs Owner Separation
description: Reaching the order-count threshold makes a side a Hero CANDIDATE (ARMED) only — both BUY and SELL may sit ARMED in parallel without locking. The first side whose non-Hero basket actually closes (TP / Avg-trailing) transitions to BE_GUARD and becomes the Hero OWNER. New helper GetHeroOwnerSide() unifies owner detection (BUY / SELL / -1). Dashboard 'Hero Owner' now shows NONE (waiting close) while only ARMED, and BUY/SELL with (locked) tag only after a real BE_GUARD owner exists. Audit log adds CANDIDATE/OWNER role + OWNER side per cycle.
type: feature
---

# v7.07

## Bug
Dashboard read `Hero Owner = BUY (locked)` whenever BUY merely reached the order-count threshold (ARMED), even though no side had actually closed its non-Hero basket. The owner row used `g_heroPhase_Buy != 0` (which includes ARMED=2), so the first side to hit the threshold appeared "locked" and the user couldn't tell whether ownership had really transferred. v7.06 had already fixed `BuildHeroTicketCache` to gate `activeOwner` on BE_GUARD, but the dashboard owner row + audit log still showed the old semantics.

## Fix
- New `GetHeroOwnerSide()` helper: returns `(int)POSITION_TYPE_BUY` / `POSITION_TYPE_SELL` only when that side's `g_heroPhase_*` == 3 (BE_GUARD). Returns `-1` if both sides are NONE/ARMED or both BE_GUARD (rare). Single source of truth for "real" Hero owner.
- `BuildHeroTicketCache` `activeOwner` now calls `GetHeroOwnerSide()` instead of inlining the check — guarantees Single-Side Lock activation gate fires only at real ownership.
- Dashboard "Hero Owner" row uses `GetHeroOwnerSide()` and renders:
  - `NONE (waiting close)` in yellow when at least one side is ARMED but no BE_GUARD yet
  - `BUY/SELL (locked)` in gold once an owner exists
  - `NONE` plain when no candidates at all
- Audit log (every 30s) now prints per-side ROLE = NONE/CANDIDATE/OWNER plus the unified `OWNER=BUY|SELL|NONE` so flow is debuggable.
- Version bumped to **7.07** at `#property`, header, init/deinit logs, dashboard title.

## Flow After Fix
```
1) Threshold scan (per side)
2) Side reaches threshold -> phase ARMED -> CANDIDATE only (no owner lock)
3) Either side may sit ARMED in parallel; both can have Hero tickets tagged
4) First side whose non-Hero basket flattens (TP / Avg-trailing) ->
   DetectSameSideBasketClearedForHero -> phase BE_GUARD -> OWNER
5) GetHeroOwnerSide() returns that side -> Single-Side Lock blocks opposite
   side's first-time activation; PerSideGenIsolation bumps owner's gen
```

## Not Touched
- OrderSend / `trade.Buy` / `trade.Sell` / `trade.PositionClose`
- Entry strategy (SMA/EMA/Squeeze/BB/ZigZag), grid lot/distance/candle confirm
- TP/SL/Trailing/Breakeven/Average trailing formulae
- Hedge / Triple-Gate / Recovery / DD% TP / Daily Target / Balance Guard
- License / News / Sync modules
- Hero formula: `ComputeHeroLockProfitSL`, `ValidateHeroLockProfitSL`, `ApplyHeroLockProfitSL`, BE_GUARD apply path, Post-Close Grace, `OnTradeTransaction` audit
- v7.05 unblock helpers, v7.06 GL-pool gen-lock
