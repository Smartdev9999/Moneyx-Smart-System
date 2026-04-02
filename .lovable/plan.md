


## Implemented: v6.27 — Safe Cycle Reset (ป้องกัน DD Hedge Re-trigger หลัง Matching Close)

### ปัญหา
v6.26 เพิ่ม prevHedgedTickets แต่ deactivation points ทั้ง 7 จุดยังเรียก `ClearPrevHedgedTickets()` ทันทีเมื่อ `g_hedgeSetCount <= 0` แม้ยังมี released orders ค้างอยู่ → DD checker กลับมาเห็นออเดอร์เดิมและเปิด Hedge รอบ 2

### แนวทางแก้
สร้าง `TryResetCycleStateIfFlat(reason)` helper ที่เช็ค `TotalOrderCount() == 0` ก่อน reset → ป้องกันการล้าง prevHedged ก่อนเวลา

### Changes Made

1. **Version bump**: v6.26 → v6.27
2. **`TryResetCycleStateIfFlat(string reason)`** — helper ที่ reset เฉพาะเมื่อ:
   - `g_hedgeSetCount <= 0`
   - `g_cycleGeneration > 0`  
   - `TotalOrderCount() == 0` (account flat จริง)
3. **แก้ 7 deactivation points** — แทนที่ inline reset block ด้วย `TryResetCycleStateIfFlat()`
4. **แก้ 3 standalone reset points** — ใช้ helper เดียวกัน

### Deactivation Points (ใช้ TryResetCycleStateIfFlat)
```text
✓ External close
✓ AvgTP full close
✓ Matching close
✓ Release close (no matchable losses)
✓ Batch partial close (full)
✓ Grid mode recover (full)
✓ Grid mode cleanup (main hedge gone)
```

### Standalone Reset Points
```text
✓ All positions cleared (standalone)
✓ Accumulate reset
✓ ZZ accumulate reset
```

### ผลลัพธ์
```text
Matching Close → set ปิด → released orders ยังค้าง
→ prevHedged ยังอยู่ (ไม่ถูก clear)
→ cycleGeneration ยังไม่ reset
→ DD checker skip released orders
→ ไม่มี Hedge รอบ 2
→ reset จริงเมื่อ flat ทั้งหมดเท่านั้น
```

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Grid/TP/SL)
- Core Module Logic (License, News, Time, Data sync)
- Generation-aware isolation logic (v6.24)
- Triple-gate exit logic
- OpenDDHedge / binding logic
- Matching close / grid recovery ทำงานเหมือนเดิม
- SaveBoundTicketsToPrevHedged / IsPrevHedgedTicket (v6.26)
