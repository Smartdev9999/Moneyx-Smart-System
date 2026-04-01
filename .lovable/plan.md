

## Implemented: v6.25 — Sequential Hedge Recovery (oldest first, one at a time)

### Changes Made

1. **New input: `InpHedge_SequentialClose`** (bool, default: true)
   - In group "=== Counter-Trend Hedging ==="
   - When `true`: only ONE hedge set processes recovery per tick (oldest eligible)
   - When `false`: all sets process simultaneously (legacy behavior)

2. **New field: `HedgeSet.openTime`** (datetime)
   - Set at hedge creation time (`TimeCurrent()`)
   - Recovered from hedge ticket's `POSITION_TIME` on EA restart

3. **`ManageHedgeSets()` sequential logic**
   - Before the main loop: scan all active sets that pass `IsHedgeCloseAllowed()`
   - Select the one with the earliest `openTime` → `seqActiveIdx`
   - In the loop: sets that are NOT `seqActiveIdx` still do maintenance (RefreshBoundTickets, expansion tracking, external close detection) but skip matching/grid recovery
   - When the active set deactivates → next tick picks the new oldest eligible set

4. **Version bump**: v6.24 → v6.25

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Grid/TP/SL)
- Core Module Logic (License, News, Time, Data sync)
- Triple-gate exit logic (still the gate — just limits WHO can pass per tick)
- Matching close / Grid recovery logic ภายใน (ไม่แก้)
- DD trigger / generation-aware isolation (v6.23/v6.24)
- OpenDDHedge / CheckAndOpenHedgeByDD logic
- Generation reset logic (v6.24)
- MAX_HEDGE_SETS = 10 (v6.24)
