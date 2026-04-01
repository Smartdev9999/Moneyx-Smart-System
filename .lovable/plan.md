

## Implemented: v6.26 — Sequential Close Lock (process one set until fully deactivated)

### Changes Made

1. **New input: `InpHedge_SeqCooldownSec`** (int, default: 30)
   - In group "=== Counter-Trend Hedging ==="
   - Seconds to wait after one set deactivates before starting next

2. **New globals: `g_seqLockedIdx`, `g_seqLastCloseTime`**
   - `g_seqLockedIdx`: index of set currently being processed (-1 = none)
   - `g_seqLastCloseTime`: timestamp when last set was deactivated

3. **`ManageHedgeSets()` lock-based sequential logic**
   - Priority 1: If locked set is still active → keep processing it (no switching)
   - Priority 2: If lock released → check cooldown timer
   - Priority 3: If cooldown expired → find oldest eligible set → lock it
   - Other sets do maintenance only (refresh bounds, track expansion)

4. **All 7 deactivation points + full close** → reset lock + set cooldown timestamp

5. **`RecoverHedgeSets()`** → recover lock on restart if a set is in gridMode/matchingDone

6. **Version bump**: v6.25 → v6.26

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Grid/TP/SL)
- Core Module Logic (License, News, Time, Data sync)
- Triple-gate exit logic (still the gate — lock just prevents switching)
- Matching close / Grid recovery logic ภายใน (ไม่แก้)
- DD trigger / generation-aware isolation (v6.23/v6.24)
- OpenDDHedge / CheckAndOpenHedgeByDD logic
- Generation reset logic (v6.24)
- MAX_HEDGE_SETS = 10 (v6.24)
- Orphan recovery (แยก system)
