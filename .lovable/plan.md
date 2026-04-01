

## Implemented: v6.24 — MAX_HEDGE_SETS 10 + Generation Reset on Hedge Clear

### Changes Made

1. **`MAX_HEDGE_SETS` expanded from 4 to 10**
   - `#define MAX_HEDGE_SETS 10` — supports H1-H10
   - All loops already use `MAX_HEDGE_SETS` → auto-expanded

2. **Generation reset when all hedge sets close**
   - Added check at all 7 `g_hedgeSetCount--` locations
   - When `g_hedgeSetCount <= 0 && g_cycleGeneration > 0` → reset to 0
   - Prevents GM number from climbing indefinitely (GM13, GM14...)
   - Each reset point has unique log label for tracing

3. **Version bump**: v6.23 → v6.24

### Generation Reset Points
```text
✓ External close (hedge ticket gone)
✓ AvgTP full close
✓ Matching close (loss+profit paired)
✓ Release close (no matchable losses)
✓ Batch partial close (full)
✓ Grid mode recover (full)
✓ Grid mode cleanup (main hedge gone)
```

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Grid/TP/SL)
- Core Module Logic (License, News, Time, Data sync)
- Generation-aware isolation logic (v6.23)
- DD trigger threshold logic (v6.21)
- Triple-gate exit logic
- OpenDDHedge / CheckAndOpenHedgeByDD logic
