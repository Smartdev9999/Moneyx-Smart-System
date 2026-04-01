


## Implemented: v6.23 — Lot-Cap & Helper Functions Generation-Aware

### Changes Made

1. **`GetHedgeLotCap()` — generation filter added**
   - Skip hedge sets where `boundGeneration != g_cycleGeneration`
   - Old hedge sets (H1/H2) no longer cap lot size for current generation orders
   - Added debug log when cap is applied or skipped

2. **`FindLastOrder()` — generation filter added**
   - `ExtractGeneration(comment)` → skip orders from previous gens
   - Grid loss/profit spacing now references only current gen orders

3. **`FindMaxLotOnSide()` — generation filter added**
   - Same filter — max lot calculation only considers current gen

4. **`RecoverInitialPrices()` — generation filter added (both passes)**
   - First pass (INIT orders): skip non-current gen
   - Second pass (GL fallback): skip non-current gen
   - Log includes generation info

5. **`CountPositionsTF()` — generation filter added**
   - TF position counting now skips previous gen orders

6. **`FindLastOrderTF()` — generation filter added**
   - TF grid spacing references only current gen

7. **`RecoverTFInitialPrices()` — generation filter added**
   - TF initial price recovery only from current gen

8. **Version bump**: v6.22 → v6.23

### Generation-Aware Coverage Summary
```text
✓ CountPositions()         (v6.22)
✓ NormalOrderCount()       (v6.22)
✓ GetHedgeLotCap()         (v6.23) ← NEW
✓ FindLastOrder()          (v6.23) ← NEW
✓ FindMaxLotOnSide()       (v6.23) ← NEW
✓ RecoverInitialPrices()   (v6.23) ← NEW
✓ CountPositionsTF()       (v6.23) ← NEW
✓ FindLastOrderTF()        (v6.23) ← NEW
✓ RecoverTFInitialPrices() (v6.23) ← NEW
✗ TotalOrderCount()        — intentionally not filtered (global system use)
```

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Triple-gate close (Expansion + Zone + TP Distance)
- Generation-aware binding/counting ใน hedge system (v6.18/v6.19)
- DD trigger threshold logic (v6.21)
- CountPositions / NormalOrderCount gen filter (v6.22)
- `TotalOrderCount()` — ไม่แก้
- OpenDDHedge() binding logic — ไม่แก้
