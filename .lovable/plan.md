## Issue (Gold Miner EA v7.04 → v7.05)

Dashboard shows `Side Gen SELL: GM2 (Hero owns GM1)` + `Hero SELL: BE_GUARD` with 5 Hero tickets surviving on SELL. Per the spec, the SELL side should now open new `GM2_INIT` / `GM2_GL` / `GM2_GP` to keep trading. **It does not.** Tracing `OpenOrder()`, two guards still scope to the **global** `g_cycleGeneration` (= GM1) and falsely block any new GM2 entry on the Hero-owning side:

### Root Cause

1. **`ShouldBlockSameSideGridForHero(side)`** (line 2538) → calls `CountNonHeroMainOnSide(side)` which filters with `g != g_cycleGeneration` (line 2530). It only sees GM1, finds 0 non-Hero main → returns `block=true`. New `GM2_INIT/GL/GP` is rejected at `OpenOrder` line 2183.

2. **`CountFreeOlderGenOnSide(side)`** (line 9400, used by `InpCrossGen_InitGuard` at line 2147) counts Hero GL tickets as "older-gen still free" (Hero is not bound, not _HEDGE) → `legacyFree > 0` → `GM2_INIT BLOCKED` log fires.

These two guards predate per-side gen isolation and were not updated in v7.04.

## Fix (v7.05)

### Code changes — `public/docs/mql5/Gold_Miner_EA.mq5`

1. **`ShouldBlockSameSideGridForHero(side)`** — bypass when this side has a side-gen override:
   ```cpp
   if(InpHero_PerSideGenIsolation &&
      ((side==POSITION_TYPE_BUY  && g_sideGen_Buy  > 0) ||
       (side==POSITION_TYPE_SELL && g_sideGen_Sell > 0))) return false;
   ```
   Rationale: once side-gen is bumped, GM(N+1) IS the new basket — Hero (GM(N)) lives separately under BE_GUARD lock.

2. **`CountNonHeroMainOnSide(side)`** — replace global gen filter with per-side active gen so its semantics stay correct everywhere it's reused:
   ```cpp
   if(g >= 0 && g != GetActiveGenForSide(side)) continue;
   ```

3. **`CountFreeOlderGenOnSide(side)`** — exclude Hero tickets (they are NOT "free older-gen orders that can self-close"; they are intentionally locked at BE-profit waiting for opposite-basket clear):
   ```cpp
   if(IsHeroTicket(tk)) continue;
   ```

4. **Version bump** — `#property version "7.05"`, `#property description`, header comment, dashboard title (`Gold Miner EA v7.05 [INST]`), Init log line.

### Files / memory
- Edit `public/docs/mql5/Gold_Miner_EA.mq5` (4 sites + version markers).
- Add `mem://trading/gold-miner-ea/hero-side-gen-unblock-v7-05.md`.
- Update `mem://index.md`.

## What is NOT changed (per project hard rules)

- OrderSend / `trade.Buy` / `trade.Sell` / `trade.PositionClose` — untouched.
- Entry conditions (SMA / EMA / Squeeze / BB / ZigZag) — untouched.
- Grid lot / distance / candle-confirm / MaxGrid trailing math — untouched.
- TP / SL / Trailing / Breakeven / Avg-TP — untouched.
- Hedge / Triple-Gate / Recovery / DD% TP / Daily Target / Balance Guard activation — untouched.
- Hero formula: `ComputeHeroLockProfitSL`, `ValidateHeroLockProfitSL` (v7.02), `BE_GUARD` apply path, Post-Close Grace (v7.03), Single-Side Lock (v7.04), `OnTradeTransaction` audit — untouched.
- License / News / Sync modules — untouched.

Only two **block-condition helpers** are widened so the GM(N+1) entries the v7.03/v7.04 plan already promised can actually reach `trade.Buy/Sell`.

## Expected behavior after fix

When SELL owns Hero on GM1:
- Dashboard keeps showing `Side Gen SELL: GM2 (Hero owns GM1)`.
- New SELL entries open as `GM2_INIT`, then `GM2_GL#1..N` / `GM2_GP#1..N` — fully independent of the GM1 Hero, which keeps its lock-profit BE-SL.
- BUY side keeps trading on GM1 unchanged.
- When the SELL GM2 basket closes (TP/match/etc.) AND the Hero closes via opposite-basket-clear hook, `CloseHeroOnSide` resets `g_sideGen_Sell=0` → next cycle returns to global gen.
