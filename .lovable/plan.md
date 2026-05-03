## Issues (Gold Miner EA v7.05 → v7.06)

User reports two related defects in Hero ownership / per-side gen isolation:

### Bug A — Owner is locked too early (at threshold, not at TP-close)
Spec: ownership of "Hero" should lock to a side ONLY after that side closes its non-Hero basket via TP / Avg-trailing (i.e. transitions to **BE_GUARD**). Both sides may reach the order-count threshold simultaneously and run **ARMED** in parallel; the **first side to actually clear its basket** becomes the Hero owner.

Current code (`BuildHeroTicketCache`, lines 2342-2352):
```cpp
bool buyOwns  = (CountHeroOnSide(BUY)  > 0) || (g_heroPhase_Buy  != 0); // counts ARMED too
bool sellOwns = (CountHeroOnSide(SELL) > 0) || (g_heroPhase_Sell != 0);
```
`phase != 0` includes **ARMED (=2)**, so whichever side hits the threshold first becomes `activeOwner` and the other side's phase is force-cleared every tick (line 2418-2421). The opposite side can never even reach ARMED.

### Bug B — When `InpHero_PerSideGenIsolation` is ON, Hero gets stripped/closed once GM(N+1) opens
After BE_GUARD bumps `g_sideGen_<side>` to GM(N+1), new GM(N+1) `_GL` orders open on the same side. `BuildHeroTicketCache` pool selection (lines 2360-2396) collects **ALL** unbound `_GL` tickets on the side regardless of generation, then sorts by `POSITION_TIME_MSC` desc and keeps the **newest N**. The new GM2 GL tickets are newer → they replace the original GM1 Hero tickets in `g_heroTickets[]`. Consequences:
- `IsHeroTicket(oldGM1ticket)` now returns false → `SyncBrokerTPSL` / `ManagePerOrderTrailing` push basket TP onto them and `ApplyTrailingSL` overwrites the lock-profit SL → Hero closes.
- The new GM2 GL gets the lock-profit-BE-SL applied incorrectly (or no protection at all).

Turning isolation OFF avoids this because no GM(N+1) entries open on the Hero side, but then Bug A locks the wrong side first.

## Fix (v7.06)

### Code changes — `public/docs/mql5/Gold_Miner_EA.mq5`

1. **`BuildHeroTicketCache` — owner detection (lines 2345-2352)**
   Owner only when a side is in **BE_GUARD (phase==3)**. ARMED (phase==2) does not lock.
   ```cpp
   int activeOwner = -1;
   if(InpHero_SingleSideLock) {
      bool buyOwns  = (g_heroPhase_Buy  == 3); // BE_GUARD only
      bool sellOwns = (g_heroPhase_Sell == 3);
      if(buyOwns && !sellOwns)      activeOwner = (int)POSITION_TYPE_BUY;
      else if(sellOwns && !buyOwns) activeOwner = (int)POSITION_TYPE_SELL;
   }
   ```
   Both sides are now allowed to enter ARMED in parallel. The single-side block at line 2418 still applies — but only fires once one side reaches BE_GUARD.

2. **`BuildHeroTicketCache` — pool gen-lock for BE_GUARD (around lines 2371-2382)**
   When the side is already past first activation AND has a recorded `g_heroOwnedGen_<side> > 0`, restrict the `_GL` pool to that owned gen only. New GM(N+1) GL orders are excluded from Hero rolling.
   ```cpp
   int ownedGen = (sideId==POSITION_TYPE_BUY) ? g_heroOwnedGen_Buy : g_heroOwnedGen_Sell;
   bool gateOwnedGenOnly = (ownedGen > 0); // set after BE_GUARD bump
   ...
   if(isGL) {
      if(gateOwnedGenOnly) {
         int og = ExtractGeneration(c);
         if(og >= 0 && og != ownedGen) { /* exclude — belongs to GM(N+1) basket */ }
         else if(nGL < 200) { tkGL[nGL]=ticket; ttGLMs[nGL]=...; nGL++; }
      } else if(nGL < 200) {
         tkGL[nGL]=ticket; ttGLMs[nGL]=...; nGL++;
      }
   }
   ```
   Note: `g_heroOwnedGen_<side>` is already stamped to the original gen at the BE_GUARD transition (lines 2793 / 2799). It is reset to 0 by `CloseHeroOnSide` (lines 2593 / 2597) and by cycle reset (lines 9658 / 9758) — no other state plumbing needed.

3. **`BuildHeroTicketCache` — also gate `nAll` activation count (line 2375 area)**
   For sides still in phase NONE (first activation), keep `nAll` cross-gen as today. For sides already in BE_GUARD with an `ownedGen`, also count only that owned-gen basket — purely for the dashboard `Hero Owner` / counters; does not affect already-tagged Heroes since `take` uses sticky path.

4. **Version bump**
   `#property version "7.06"`, `#property description`, header comment block, dashboard title (`Gold Miner EA v7.06 [INST]`), Init log line.

### Files / memory
- Edit `public/docs/mql5/Gold_Miner_EA.mq5` (4 spots + version markers).
- Add `mem://trading/gold-miner-ea/hero-owner-on-be-guard-and-genlock-pool-v7-06.md`.
- Update `mem://index.md`.

## What is NOT changed (per project hard rules)
- OrderSend / `trade.Buy` / `trade.Sell` / `trade.PositionClose` — untouched.
- Entry conditions (SMA / EMA / Squeeze / BB / ZigZag) — untouched.
- Grid lot / distance / candle-confirm / MaxGrid trailing math — untouched.
- TP / SL / Trailing / Breakeven / Avg-TP — untouched.
- Hedge / Triple-Gate / Recovery / DD% TP / Daily Target / Balance Guard — untouched.
- Hero formula: `ComputeHeroLockProfitSL`, `ValidateHeroLockProfitSL` (v7.02), `ApplyHeroLockProfitSL`, `BE_GUARD` apply path, Post-Close Grace (v7.03), `OnTradeTransaction` audit — untouched.
- All v7.05 unblock helpers (`ShouldBlockSameSideGridForHero`, `CountNonHeroMainOnSide`, `CountFreeOlderGenOnSide`) — untouched.
- License / News / Sync modules — untouched.

Only **two semantics in `BuildHeroTicketCache`** are tightened: (1) owner = BE_GUARD instead of any active phase, (2) Hero pool is gen-locked to the originally owned generation once BE_GUARD has bumped `g_sideGen_*`. This lets `InpHero_PerSideGenIsolation` stay ON while preserving the original Hero tickets unchanged.

## Expected behavior after fix
- Both BUY and SELL can sit at READY/ARMED simultaneously while their baskets are still open.
- The first side whose non-Hero basket flattens (TP / Avg-trailing) transitions to **BE_GUARD** and becomes Hero owner; the opposite side is then blocked from new Hero activation until owner clears.
- With `InpHero_PerSideGenIsolation = true`, GM(N+1) entries on the Hero-owning side open and trade normally, while the original GM(N) Hero tickets keep their lock-profit BE-SL untouched (no strip, no premature close).
- Dashboard `Hero Owner` row reads NONE while both sides are ARMED, and switches to BUY/SELL only at the BE_GUARD transition.
