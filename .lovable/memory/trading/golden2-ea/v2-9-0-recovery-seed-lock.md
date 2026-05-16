---
name: Golden2 EA v2.9.0 Recovery Seed Lock
description: Locks PlaceRecoveryGridIfNeeded seedLot once per group (excluding RC# tickets from scan) so Multiplier^level applies to a stable base; fixes RC lot exponential explosion where each RC#N picked the previous RC ticket as its seed
type: feature
---

## Bug
With `InpRecovery_Multiplier=1.4`, observed ladder RC#1=0.20, RC#2=0.30, RC#3=0.67, RC#4=2.26, RC#5=11.44 — far above geometric expectation (0.20, 0.28, 0.39, 0.55, 0.77).

## Root Cause
`PlaceRecoveryGridIfNeeded` re-scanned losing-side positions every call for `seedLot = max(volume)`, which included previously placed RC# tickets. Each RC#N therefore used the freshly-placed RC#(N-1) lot as its base, then multiplied again → exponential compounding.

## v2.9.0 Fix
- New global `double g_groupRecoverySeedLot[51]`.
- In `PlaceRecoveryGridIfNeeded`: if `g_groupRecoverySeedLot[g] <= 0` compute seed once, **skipping tickets whose tag starts with "RC"**, then lock it. Subsequent RC#N reuse the locked value.
- Reset locked seed alongside `g_groupRecoveryLevel` in OnInit (line ~3775) and group-flat housekeeping (line ~3949).
- Log line now prints `lockedSeed` for verification.

## Result
seed = 0.20 lock + mult 1.4 → 0.20, 0.28, 0.39, 0.55, 0.77 (clean geometric ladder).

## Untouched
- `trade.Buy/Sell` execution
- Multiplier formula, MaxLevels, distance trigger, OnlyNewCandle, `TryPlaceRecoveryGridContinuation` body
- All v2.8.x logic (Recovery Order Lock, Prior-Advance Bypass, Reserve-Profit, Hedge Orphan Offset, Post-Match Avg TP)
- Entry/Squeeze/License/News/Time/Sync

## Files
`public/docs/mql5/Golden2_EA.mq5` → version 2.90
