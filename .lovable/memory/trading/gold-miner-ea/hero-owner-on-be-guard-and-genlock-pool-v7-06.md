---
name: Gold Miner EA v7.06 — Hero Owner on BE_GUARD + Gen-Locked Pool
description: Two BuildHeroTicketCache fixes. (1) Single-Side Lock owner detection now uses phase==BE_GUARD only — both sides may sit ARMED in parallel until one's non-Hero basket actually flattens via TP/Avg-trail. The first to reach BE_GUARD becomes Hero owner; opposite side's first-time activation is then blocked. (2) GL pool collection is gen-locked to g_heroOwnedGen_<side> after BE_GUARD bump, so new GM(N+1) GL orders opened by InpHero_PerSideGenIsolation are NEVER rolled into Hero — original GM(N) Heroes keep their lock-profit BE-SL untouched while GM(N+1) basket gets normal trailing/TP. Lets InpHero_PerSideGenIsolation stay ON without stripping/closing the surviving Hero.
type: feature
---

# v7.06

## Bugs Fixed

### Bug A — Owner locks at threshold instead of basket-clear
v7.04 `BuildHeroTicketCache` computed `buyOwns/sellOwns` as `phase != 0`, which includes ARMED (=2). The first side to reach the order-count threshold became `activeOwner` and the opposite side's phase was force-cleared every tick, so it could never even reach ARMED. Spec is: owner locks only when one side **closes its non-Hero basket via TP / Avg-trailing** (BE_GUARD transition).

### Bug B — Hero stripped/closed when GM(N+1) opens with PerSideGenIsolation ON
After BE_GUARD bumped `g_sideGen_<side>` and new GM(N+1) `_GL` orders opened on the same side, the pool collection loop took ALL unbound `_GL` cross-gen, then sorted newest-first and kept N. The new GM2 GL tickets were newer → replaced the original GM1 Hero set. `IsHeroTicket(oldGM1)` then returned false → SyncBrokerTPSL/ManagePerOrderTrailing pushed basket TP/SL onto the originals → Hero closed. Disabling isolation worked but reintroduced Bug A.

## Fix
- **Owner = BE_GUARD only**: `buyOwns = (g_heroPhase_Buy == 3); sellOwns = (g_heroPhase_Sell == 3);` Both sides can run ARMED in parallel. The single-side block at the per-side activation gate still applies, but only after one side reaches BE_GUARD.
- **GL pool gen-lock**: inside the per-side loop, read `ownedGen = g_heroOwnedGen_<side>`. When `ownedGen > 0`, skip GL tickets whose `ExtractGeneration(comment) != ownedGen`. `g_heroOwnedGen_<side>` is already stamped at the BE_GUARD transition (v7.03/v7.04) and reset by `CloseHeroOnSide` + cycle reset — no extra plumbing.
- Version → **7.06** at `#property`, header, init/deinit logs, dashboard title.

## Not Touched
- OrderSend / `trade.Buy` / `trade.Sell` / `trade.PositionClose`
- Entry conditions (SMA / EMA / Squeeze / BB / ZigZag)
- Grid lot/distance/candle-confirm/MaxGrid trailing math
- TP/SL/Trailing/Breakeven/Avg-TP
- Hedge / Triple-Gate / Recovery / DD% TP / Daily Target / Balance Guard activation
- Hero formula: `ComputeHeroLockProfitSL`, `ValidateHeroLockProfitSL` (v7.02), `ApplyHeroLockProfitSL`, BE_GUARD apply path, Post-Close Grace (v7.03), `OnTradeTransaction` audit
- v7.05 unblock helpers (`ShouldBlockSameSideGridForHero`, `CountNonHeroMainOnSide`, `CountFreeOlderGenOnSide`)
- License / News / Sync modules
