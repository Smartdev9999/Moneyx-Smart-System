---
name: Gold Miner v6.67 Unified Recovery Params
description: Auto Recovery shares InitialLotSize + GetRecoveryMultiplyFactor() with Manual; Recovery_AutoInitLot/Mult inputs removed
type: feature
---
Gold Miner EA v6.67 unifies Auto Recovery lot sizing with the existing Grid Recovery params:

1. **Removed inputs**: `Recovery_AutoInitLot` and `Recovery_AutoMult` (introduced in v6.65) are deleted. Old `.set` files referencing them are silently ignored by MT5 on recompile.

2. **Auto Recovery now uses**:
   - Init lot = `InitialLotSize` (the EA's main initial lot)
   - Multiplier = `GetRecoveryMultiplyFactor()` which returns `Recovery_MultiplyFactor` when `Recovery_UseSeparate=true`, else falls back to `GridLoss_MultiplyFactor`.
   - Safety: if multiplier ≤ 1.0, fallback to 1.4 (must grow).

3. **`Recovery_AutoLot`** remains as the single toggle. Label clarified: "Auto Recovery (Reverse-walk seed, uses InitialLotSize + Recovery/GridLoss MultiplyFactor)".

4. **Dashboard** shows `Auto:ON Init=<InitialLotSize> Mult=<GetRecoveryMultiplyFactor()> (shared)`.

5. **Log line**: `v6.67 SEED Set#N: rem=X init=Y mult=Z -> seed=W`.

All other v6.66 mechanics (one-time shred, combined avg TP, max grid cap, persistent ticket/shred state) remain unchanged.
