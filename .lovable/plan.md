

## Implemented: v6.26 — ป้องกัน DD Hedge Re-trigger บนออเดอร์ที่เคยอยู่ใน Hedge Set

### Changes Made

1. **Version bump**: v6.25 → v6.26
2. **`g_prevHedgedTickets[200]` + `g_prevHedgedCount`** — global array to track previously-hedged tickets
3. **Helper functions**: `AddPrevHedgedTicket()`, `IsPrevHedgedTicket()`, `ClearPrevHedgedTickets()`, `SaveBoundTicketsToPrevHedged()`
4. **`CheckAndOpenHedgeByDD()`** — added `IsPrevHedgedTicket(ticket)` guard after `IsTicketBound()` check
5. **7 deactivation points** — `SaveBoundTicketsToPrevHedged(idx)` called before boundTickets cleared (only for DD-triggered sets)
6. **All generation reset points** — `ClearPrevHedgedTickets()` called when `g_cycleGeneration` resets to 0

### Deactivation Points (SaveBoundTicketsToPrevHedged)
```text
✓ External close (hedge ticket gone)
✓ AvgTP full close
✓ Matching close (loss+profit paired)
✓ Release close (no matchable losses)
✓ Batch partial close (full)
✓ Grid mode recover (full)
✓ Grid mode cleanup (main hedge gone)
```

### Generation Reset Points (ClearPrevHedgedTickets)
```text
✓ All positions cleared (standalone)
✓ Accumulate reset
✓ ZZ accumulate reset
✓ All 7 deactivation points (when hedgeSetCount <= 0)
```

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Grid/TP/SL)
- Core Module Logic (License, News, Time, Data sync)
- Generation-aware isolation logic (v6.24)
- Triple-gate exit logic
- OpenDDHedge / binding logic
- Matching close / grid recovery ทำงานเหมือนเดิม
