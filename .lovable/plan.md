

## Implemented: v6.25 — แก้ Hedge Re-trigger หลังปิด Set + เพิ่ม DD Dollar Mode

### Changes Made

1. **Version bump**: v6.24 → v6.25
2. **`HEDGE_TRIGGER_DD_DOLLAR` enum value** added (value 2)
3. **`InpHedge_DDTriggerDollar`** input (default $500) for dollar-based DD threshold
4. **`g_lastHedgeCloseTime`** global — cooldown timer after hedge set close
5. **`CheckAndOpenHedgeByDD()`** updated:
   - Accepts both DD% and DD$ modes
   - Cooldown guard: checks both `g_lastDDHedgeTime` and `g_lastHedgeCloseTime`
   - Dollar mode compares `MathAbs(loss) >= InpHedge_DDTriggerDollar` directly
6. **OnTick routing**: `HEDGE_TRIGGER_DD_DOLLAR` routes to `CheckAndOpenHedgeByDD()`
7. **`g_lastHedgeCloseTime = TimeCurrent()`** added at all 7 deactivation points
8. **Dashboard DD display**: shows $ or % based on active mode

### Cooldown Points (g_lastHedgeCloseTime)
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
- Generation-aware isolation logic (v6.24)
- DD% trigger threshold logic — unchanged, dollar mode added separately
- Triple-gate exit logic
- OpenDDHedge / binding logic
