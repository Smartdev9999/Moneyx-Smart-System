---
name: Gold Miner EA v6.86 — Max Grid Avg Trailing includes Grid Profit
description: MaxGridTrailing avg-price + close set now includes _INIT + _GL + _GP of the same gen+side (was INIT+GL only). CountGenGridLoss unchanged (still gates trigger).
type: feature
---

# Gold Miner EA v6.86

ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

## เปลี่ยน
- `CalcGenAveragePrice(gen, side)` → รวม `_INIT + _GL + _GP` ของ gen+side เดียวกัน (weighted avg)
- `CountGenOrders(gen, side)` → นับ `_INIT + _GL + _GP` (auto-advance gen ไม่ข้าม gen ที่เหลือแต่ GP)
- `CloseGenSide(gen, side)` → ปิด `_INIT + _GL + _GP` เมื่อ trailing SL ยิง

## ไม่เปลี่ยน
- `CountGenGridLoss()` — ยังนับเฉพาะ `_GL` (ใช้เป็นเกณฑ์ trigger trailing เมื่อถึง MaxGridTrades)
- `CalculateAveragePrice()` (avg ระบบหลัก) ไม่แตะ
- `ManageMaxGridTrailing()` flow / activation / step / breakeven buffer ไม่แตะ
- ไม่แตะ Order Execution / Strategy / Hedge / TripleGate / License / News / Sync

## Version
v6.85 → v6.86 (header, #property, OnInit/Deinit log, Dashboard headerVersion)
