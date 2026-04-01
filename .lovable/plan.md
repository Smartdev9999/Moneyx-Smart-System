

## Implemented: v6.20 — NormalOrderCount() แยก Hedge/Bound ออกจาก MaxOpenOrders

### Changes Made

1. **`NormalOrderCount()`**: สร้างฟังก์ชันใหม่ที่นับเฉพาะ order ปกติ (ข้าม IsHedgeComment + IsTicketBound)

2. **เปลี่ยน 8 จุด** ที่ใช้ `TotalOrderCount()` เป็น `NormalOrderCount()`:
   - SMA/ZigZag entry, Instant entry, TF ZigZag entry (3 จุด)
   - CheckGridLoss, CheckGridProfit, TF GridLoss, TF GridProfit (4 จุด)
   - Orphan recovery (2 จุด)

3. **คง `TotalOrderCount()` ไว้** สำหรับ: OnInit detection (line 696), cycle reset (line 2019), accumulate baseline (line 4394)

4. **Version bump**: v6.19 → v6.20 (header, property, OnInit, OnDeinit, Dashboard)

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Triple-gate close (Expansion + Zone + TP Distance)
- DD% trigger / Generation-aware isolation (v6.18/v6.19)
- CountPositions() — ไม่แก้
