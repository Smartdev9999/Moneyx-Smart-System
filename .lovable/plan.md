

## Implemented: v6.15 — Hedge Close Gate: Expansion Cycle + Price Zone + TP Distance

### Changes Made

1. **`IsHedgeCloseAllowed(int h)`**: New triple-gate function that checks per hedge set:
   - **Gate 1: Expansion Cycle** — Case A (hedged during expansion → wait Normal) / Case B (hedged during Normal → wait expansion TF2 + Normal)
   - **Gate 2: Price Zone** — price must exit zone between oldest bound order and hedge order
   - **Gate 3: TP Distance** — after exiting zone, must be ≥ `InpHedge_CloseMinPoints` from zone edge

2. **`HedgeSet` struct expanded** with: `seenExpansionSinceHedge`, `hedgedDuringExpansion`, `zoneUpperPrice`, `zoneLowerPrice`, `hedgeOpenPrice`, `oldestBoundPrice`

3. **`CheckAndOpenHedge()`** — records expansion state and zone prices at hedge open time

4. **`ManageHedgeSets()`** — replaced old `allTFNormal` gate with per-set `IsHedgeCloseAllowed(h)`:
   - Tracks TF2 expansion every tick per set
   - All recovery (matching, partial, avg TP, grid) blocked until gate passes
   - Reverse Hedge calls removed entirely

5. **`TryEnterCombinedGridMode()`** — removed reverse hedge gates and reverse lot calculations

6. **`RecoverHedgeSets()`** — recovers zone prices from position data, defaults expansion flags to `true` (conservative)

7. **Dashboard** — shows per-set gate status: Cycle (Wait Expansion/Wait Normal/Ready) + Zone (IN ZONE/OUT pts/OUT OK)

8. **Reverse Hedge disabled** — `ManageReverseHedge()`, `CheckAndOpenReverseHedge()`, `UpdateHedgeBalancedLock()` no longer called

9. **Input changes**: Added `InpHedge_CloseMinPoints`, commented out Reverse Hedge inputs

10. **Version bump**: v6.14 → v6.15 (all locations)

### กฎที่บังคับใช้

```text
Hedge Set ปิดออเดอร์ได้เมื่อ:
1. ผ่าน Expansion Cycle ใน TF ใหญ่ (index 2) อย่างน้อย 1 รอบ + กลับ Normal
2. ราคาออกจากกรอบ (oldest bound ↔ hedge order)
3. ราคาห่างจากขอบกรอบ ≥ InpHedge_CloseMinPoints
→ ต้องผ่านครบ 3 ข้อ ถึงจะ matching close / grid ได้
→ แต่ละ set ทำงานแยกกัน
→ Accumulate Close ยังทำงานรวมเหมือนเดิม
```

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Matching Close logic ภายใน — เพียงเพิ่ม gate ก่อนเรียก
- Grid Mode logic — เพียงเพิ่ม gate ก่อนรัน
- Accumulate Close — ทำงานรวมเหมือนเดิม ไม่สน gate
- Orphan Recovery — ไม่แก้
- Squeeze state detection (BB/KC) — ไม่แก้
