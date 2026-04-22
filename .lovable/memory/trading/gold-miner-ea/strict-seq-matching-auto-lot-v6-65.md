---
name: Strict Sequential Matching + Auto Recovery Lot v6.65
description: ManageHedgeSets picks ONE matcher per tick (others fully skip); Recovery_AutoLot computes recovery grid lots from remaining hedge lots
type: feature
---

Gold Miner EA v6.65 fixes the v6.64 regression where every active hedge set
was allowed to run matching every tick, causing two sets to shred their main
hedges in parallel and leaving uncommented partial remnants on the chart.

## Strict Sequential Matching

`ManageHedgeSets()` now selects exactly ONE `activeMatcherIdx` at the top of
the function:

- If `g_sequentialRecoveryActive` → matcher = `g_sequentialRecoverySetIdx`
  (fallback to oldest active if owner index is no longer active)
- Otherwise → matcher = `FindOldestActiveHedgeSet()`

In the per-set loop, any set with `h != activeMatcherIdx` calls `continue`
immediately after the gate check. It does NOT run:
`ManageHedgeMatchingClose`, `ManageHedgeBoundAvgTP`,
`ManageHedgePartialClose`, `TryEnterCombinedGridMode`, or
`ManageHedgeGridMode`. Its `matchingDone` flag is reset so it is ready
when its turn comes after the current matcher fully closes.

A 30s throttled log prints `v6.65 STRICT SEQ: matcher=Set#N | other K
set(s) waiting`.

## Auto Recovery Lot Sizing

New inputs: `Recovery_AutoLot` (default false), `Recovery_AutoInitLot=0.05`,
`Recovery_AutoMult=1.4`.

`ComputeAutoRecoveryLot(remHedge, existing, lastLot)`:
- `baseLot = (lastLot > 0) ? lastLot * Recovery_AutoMult : Recovery_AutoInitLot`
- `nextLot = floor(baseLot / lotStep) * lotStep`
- If `existing + nextLot > remHedge` → cap `nextLot = floor((remHedge − existing)
  / lotStep) * lotStep`
- If `nextLot < minLot` → return 0 (budget full, do not open)

Wired into:
- `ManageHedgeGridMode(idx)` — uses `g_hedgeSets[idx].hedgeLots` as remHedge,
  `SumHedgeGridLots(idx)` as existing, `FindLastHedgeGridLot(idx)` as last
- `ManageOrphanGrid()` BUY + SELL — uses `GetHedgeLotsForGen(gen)` as
  remHedge, `SumOrphanGridLots(gen, side)` as existing,
  `FindMaxLotOrphan(gen, side)` as last

When `Recovery_AutoLot = false` the original GridLoss/Recovery lot logic
runs unchanged (regression-safe).

## Dashboard

- `Hedge Recovery | Strict Seq | Active Matcher: HX | Wait: N set(s)`
- `Recovery Grid  | Auto:ON Init=0.05 Mult=1.40 | HX used 0.36/0.50`
