---
name: Kuy3 v1.58 Handoff Reserve + Conditional Alternation Lock
description: Opposite side may pre-arm Hero Reserve while owner is BE_GUARD so next basket TP keeps a Hero set; Next-Allowed lock auto-clears when both sides under threshold (no forced alternation)
type: feature
---

## Bugs v1.57
1. Single-Side Lock blocked opposite side from ARMing while owner was BE_GUARD → when owner basket got TP, BUY/SELL was closed entirely without keeping any Hero for the next cycle (3rd round closed all)
2. `g_heroNextAllowedSide` was always stamped at CloseHeroOnSide regardless of whether opposite side could actually become Hero → if both sides were under threshold, system stayed locked to one side instead of resetting fresh
3. `CloseHeroOnSide()` reset `g_heroTicketCount=0` → opposite-side Reserve disappeared from `IsHeroProtectedTicket` for one tick (race window)

## Fix v1.58
- **Handoff Reserve**: Removed STRICT Single-Side Lock activation gate. Both sides can ARMED simultaneously. Owner = BE_GUARD only (unchanged). When owner is BE_GUARD, opposite side ARMED tickets are treated as Reserve and protected by `IsHeroProtectedTicket` so basket TP doesn't sweep them.
- **Conditional Alt Block**: `g_heroNextAllowedSide` gate now self-clears at activation-time check if designated side has `phase==NONE && active < threshold`.
- **Conditional Reset (every tick)**: New block at end of `BuildHeroTicketCache` — if both sides idle (`phase==NONE && active<threshold`), force `g_heroNextAllowedSide=-1` and `g_heroLastClosedSide=-1`. Behaves like fresh start.
- **Conditional Stamp on Close**: `CloseHeroOnSide` only stamps Next-Allowed=opposite when opp has `phase>0 OR active>=threshold`; otherwise leaves `=-1` (ANY).
- **Surviving Reserve**: `CloseHeroOnSide` rebuilds `g_heroTickets[]` from the REMAINING stable set (opposite side) immediately after closing, so opposite-side Hero Reserve never leaks `IsHeroProtectedTicket=false` mid-tick.
- **Dashboard**: Adds `Handoff Reserve` row (`BUY armed (reserve)` / `SELL armed (reserve)` / `-`); `Next Allowed` shows `ANY (no lock)` in green when unlocked. Mode label = `HANDOFF`. Lock label = `COND`.

## Unchanged (Rules of Steel)
- `trade.Buy/Sell/PositionClose`, OrderSend, Grid entry/exit, lot multiplier
- Per-Order BE/Trail/SL/TP, Avg-TP/Avg-Trail strict-2-cross, TP modes, Accumulate, Cost-Hit
- Hero price-extreme selection (BUY lowest N / SELL highest N), `InpHero_OrderCount`, `InpHero_MinOrdersToActivate`
- `IsHeroProtectedTicket` 9 guards, `ApplyHeroLockProfitSL`/`ComputeHeroLockProfitSL`/`StripBrokerTPSLFromHeroTickets`
- v1.57 TP-event latch, v1.51 Avg-TP intent gate, v1.50 opp-realized accumulator, v1.46 alternation lock
- `InpHero_Enabled=false` → Hero subsystem inert
