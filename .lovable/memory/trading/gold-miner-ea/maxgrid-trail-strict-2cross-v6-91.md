---
name: MaxGrid Trail Strict 2-Cross ARM v6.91
description: ManageMaxGridTrailing now requires price to first cross BELOW avg (BUY) or ABOVE avg (SELL) before ARM is allowed when price crosses BACK through avg+activation; prevents instant-ARM-then-instant-close when count threshold opens while price is already past activation; toggle InpMaxGridArm_Strict2Cross
type: feature
---

## Why
MaxGridTrail is a **safety net for deeply stuck baskets**, not a normal trailing stop. Pre-v6.91 it ARMed the moment two conditions met:
1. `glCount >= requiredOrders`
2. `bid >= avgPrice + MaxGrid_TrailActivation`

If the count threshold became true while price was already above activation (e.g. lots of `_GP` orders on a winning side), it ARMed immediately and the next small pullback closed the basket — opposite of the intended behavior.

## Fix (v6.91)
Adds a "STEP 1: armReady" flag per side. ARM (STEP 2) is gated on armReady=true.

- **BUY**: `g_maxGridArmReady_Buy = true` only when `bid <= avgPrice - InpMaxGridArm_UnderAvgBuffer * point`
- **SELL**: `g_maxGridArmReady_Sell = true` only when `ask >= avgPrice + InpMaxGridArm_UnderAvgBuffer * point`
- **Reset triggers**: gen change, count drops below threshold, SL hit (CloseGenSide), Squeeze pause edge

## State
- `g_maxGridArmReady_Buy / _Sell` (bool)
- `g_maxGridArmReadyGen` (int) — auto-clears flags when monitored gen changes

## Inputs
- `InpMaxGridArm_Strict2Cross` (default `true`) — set `false` to revert to v6.90 ARM behavior
- `InpMaxGridArm_UnderAvgBuffer` (default `0` points) — extra distance below/above avg required to mark ARM-READY

## Untouched (no trading-logic risk)
- ❌ No change to `OrderSend` / `trade.Buy/Sell/PositionClose`.
- ❌ No change to grid entry, hedge trigger/release, Triple-Gate, Avg TP, DD% TP, Daily Target.
- ❌ No change to per-order trailing or TF trailing.
- ❌ No change to `CalcGenAveragePrice` / `CountGenGridAll` / `CloseGenSide` (v6.86, v6.90).
- ❌ No change to Squeeze Pause Trailing v6.87-89 — `IsSqueezePausingTrailing()` guard at top of `ManageMaxGridTrailing()` still gates the entire function.
- ✅ Only the ARM gate inside `ManageMaxGridTrailing()` changed; trailing-SL movement and SL-hit close are byte-identical.

## Squeeze interaction
- Squeeze in pause → entire MaxGridTrail skipped (v6.87+) → armReady cannot flip.
- v6.89 Strip-SL edge handler now also resets `g_maxGridArmReady_Buy/Sell` so post-pause re-arm requires a fresh cross.

## Backward compatibility
- `InpMaxGridArm_Strict2Cross = false` → exact v6.90 behavior.
- Existing `.set` files keep working; new defaults are safer (Strict2Cross ON).

## Dashboard
New row when `Strict2Cross=true` and side is armReady but not yet active:
- `MG BUY Trail | READY (waiting cross-up) | yellow`
- `MG SELL Trail | READY (waiting cross-down) | yellow`
