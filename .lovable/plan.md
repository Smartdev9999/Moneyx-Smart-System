

## Implemented: v6.22 — CountPositions & NormalOrderCount Generation-Aware

### Changes Made

1. **`CountPositions()` — เพิ่ม generation filter**
   - `ExtractGeneration(comment)` → ข้าม orders ที่ gen ≠ `g_cycleGeneration`
   - ทำให้ orders ฝั่งกำไรของ gen เก่า (เช่น GM SELL, GM1 BUY) ไม่บล็อก entry ใหม่

2. **`NormalOrderCount()` — เพิ่ม generation filter เดียวกัน**
   - สอดคล้องกับ CountPositions — นับเฉพาะ current gen

3. **Version bump**: v6.21 → v6.22

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Triple-gate close (Expansion + Zone + TP Distance)
- Generation-aware binding/counting ใน hedge system (v6.18/v6.19)
- DD trigger threshold logic (v6.21)
- `TotalOrderCount()` — ไม่แก้
- OpenDDHedge() binding logic — ไม่แก้
