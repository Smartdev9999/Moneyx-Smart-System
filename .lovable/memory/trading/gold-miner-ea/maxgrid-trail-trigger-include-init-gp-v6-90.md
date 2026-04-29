---
name: MaxGrid Trail Trigger incl. INIT+GP v6.90
description: ManageMaxGridTrailing trigger gate now counts INIT+GL+GP (was GL only) via new CountGenGridAll, aligning with CalcGenAveragePrice basket; toggle InpMaxGridTrail_IncludeINITGP (default ON) to revert to v6.89 GL-only behavior
type: feature
---

## Problem (pre-v6.90)
- `ManageMaxGridTrailing()` used `CountGenGridLoss(gen, side)` as activation gate.
- `CountGenGridLoss` only counts comments containing `_GL`.
- But `CalcGenAveragePrice()` (v6.86) computes the basket avg from `_INIT + _GL + _GP`.
- → A generation with many `_INIT`/`_GP` but few `_GL` would NEVER activate trailing even though the real basket size + avg-price risk had reached the threshold.

## Fix (v6.90)
1. New helper `CountGenGridAll(gen, side)` — same scan loop as `CountGenGridLoss` but accepts `_INIT || _GL || _GP`.
2. New input `InpMaxGridTrail_IncludeINITGP` (default `true`).
3. Both BUY + SELL trigger blocks in `ManageMaxGridTrailing()` now select counter via the toggle:
   ```cpp
   int glCount = InpMaxGridTrail_IncludeINITGP
                    ? CountGenGridAll(gen, side)
                    : CountGenGridLoss(gen, side);
   ```
4. ACTIVATED log upgraded to `v6.90` with `count` + `mode=ALL|GL_ONLY`.

## Untouched (no trading-logic risk)
- No change to `OrderSend`/`trade.Buy/Sell/PositionClose`.
- Strategy entry (SMA/INSTANT/ZZ), Grid Loss/Profit entry, Hedge trigger/release, Triple-Gate, Accumulate, DD% TP, Daily Target — all untouched.
- `CountGenGridLoss` itself unchanged (still used by other Grid trigger paths).
- `CalcGenAveragePrice`, `CountGenOrders`, `CloseGenSide` — unchanged (already INIT+GL+GP since v6.86).
- Squeeze Pause Trailing v6.87/v6.88/v6.89 — unchanged.

## Backward compatibility
- Toggle = `false` → exact v6.89 behavior (GL-only counting).
- Existing `.set` files keep working (new input has safe default).
