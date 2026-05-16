---
name: Golden2 EA v2.8.7 Purge Inputs + Reserve Profit Fix
description: Removes deprecated multi-confirm Squeeze inputs/globals/handles, and fixes Triple-Gate to use ReserveProfitUSD as actual KEEP floor (was MinNetUSD=$1) so matching close shreds losses correctly before Recovery
type: feature
---

## Part A — Purge Deprecated Squeeze Inputs
- Deleted inputs: `InpSQ_UseBBBreakout`, `InpSQ_UseADX`, `InpSQ_ADXPeriod`, `InpSQ_ADXThreshold`, `InpSQ_UseATRConfirm`, `InpSQ_ATRMAPeriod`, `InpSQ_ATRMult`, `InpSQ_UseEMA`, `InpSQ_EMAPeriod`, `InpSQ_EMAPrice`
- Deleted globals: `g_sqADX[3]`, `g_sqEMA[3]`, `g_sqPassBB/ADX/ATR/EMA[3]`, `g_sqADXVal[3]`
- Removed no-op assignments in `ComputeSqueezeForTF`; removed init + IndicatorRelease for ADX/EMA
- Legacy `.set` files: MT5 warns "unknown parameter" but EA loads fine

## Part B — Triple-Gate Reserve-Profit Fix
**Bug:** `InpExit_MinGainUSD=100` was a HOLD-Gate on `netCheck - baseline`. When a group is deeply negative, netCheck barely moves so matching close NEVER fires → orders never close. Separately, shred passes used `pool + p >= InpExitMinNetUSD($1)` as floor → reserve was effectively $0.

**Fix:**
- New input `InpExit_ReserveProfitUSD = 50.0` — actual profit floor kept after shred
- `InpExit_MinGainUSD` redefined: headroom above reserve required to START shredding (default 10)
- Gate becomes `if(winProfit < ReserveProfitUSD + MinGainUSD) return;` (no more baseline-delta block)
- `ShredCloseLosingSide` + `ShredAllNegativeFromAllProfit` both use `reserve = max(ReserveProfitUSD, MinNetUSD)` as pool floor
- Recovery Grid runs only after shred leaves residual losing tickets

## Dashboard
TripleGrid row now shows: `Win:$X need:$Y (resv:$Z) [RECOV RC#n/N]`

## Files
`public/docs/mql5/Golden2_EA.mq5` — version → 2.87
