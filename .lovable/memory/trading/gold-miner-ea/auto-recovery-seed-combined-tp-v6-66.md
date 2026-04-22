---
name: Gold Miner v6.66 Auto Recovery + Combined TP + Max Grid Cap
description: Reverse-walk seed lot from cumulative init*mult^n; one-time shred lock; combined avg TP across hedge+HG_GL; Recovery_MaxGridTrades enforced on Auto+Manual
type: feature
---
Gold Miner EA v6.66 implements three coupled mechanics for hedge recovery:

1. **Reverse-Walk Seed Lot** (`ComputeAutoSeedLot`): when `Recovery_AutoLot=true` and no recovery grid exists yet, builds the series init*mult^n and returns the FIRST lot whose cumulative sum exceeds remaining hedge lots. Example: hedge=0.50, init=0.05, mult=1.4 → 0.05+0.07+0.10+0.14+0.20=0.56 → seed=0.20. Subsequent grids use `ComputeAutoNextLot` = lastGridLot * mult.

2. **One-Time Shred** (`shredCompleted` flag, persisted via `GME_HEDGE_SHRED_<idx>`): hedge partial-close runs ONCE during matching; afterwards `ManageHedgeMatchingClose` skips partial-shred and the system relies on Combined TP. Restored on EA restart from GlobalVariable.

3. **Combined Avg TP** (`SyncRecoveryBasketTP`, gated by `Recovery_UseCombinedTP`): collects remaining hedge ticket + all `GM_HG{idx+1}_GL` positions, computes weighted-average open price, then applies a single TP to all tickets respecting `UseTP_Points/Dollar/PercentBalance` priority. Called once per matcher set per tick when shred is done OR HG_GL exists.

4. **Max Grid Cap**: `Recovery_MaxGridTrades` (originally Manual-only) now enforced on BOTH Auto and Manual recovery in `ManageHedgeGridMode` and `ManageOrphanGrid` BUY/SELL via `CountHedgeGridOrders(idx)`.

5. **Comment Residue Fallback**: `OpenHedge` and `RecoverHedgeSets` write `GME_HEDGE_TICKET_<idx>` so partial-close residues that lose comments stay bound.
