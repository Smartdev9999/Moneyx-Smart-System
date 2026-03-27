

## Implemented: v6.13 — Strict 3-TF Normal Gate + Matching-First Sequencing

### Changes Made

1. **Stable Squeeze State (closed bar)**: `UpdateSqueezeState()` now uses index 1 (closed bar) instead of index 0 to prevent state flickering between ticks

2. **`IsAllSqueezeTFNormalStrict()`**: Central helper that checks ALL 3 TFs are not in EXPANSION state

3. **`TryEnterCombinedGridMode(h)`**: Single centralized gate for entering grid mode with 5 gates:
   - All 3 TFs must be Normal
   - No bound orders remaining
   - No profitable reverse orders (need matching first)
   - Matching phase must be complete (`matchingDone` flag)
   - Hedge or reverse orders must still exist

4. **`matchingDone` flag**: Added to HedgeSet struct, reset when expansion detected, set after matching cycle completes

5. **`ManageHedgeSets()` rewritten**: Strict flow — expansion resets matchingDone → all TFs normal → matching first → grid entry via central gate

6. **Removed direct `gridMode = true`** from: ManageHedgeBoundAvgTP, ManageHedgePartialClose, CheckAndSetupDualTrackRecovery

7. **Recovery (OnInit)**: Only sets gridMode directly when resuming existing grid orders from previous session

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Orphan Recovery system
- Grid Mode logic ตัวเอง (ManageHedgeGridMode)
- Reverse Hedge opening logic (NET calculation)
- Squeeze Filter / Directional Block
