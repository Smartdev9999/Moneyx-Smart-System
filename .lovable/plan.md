

## Implemented: v6.21 — DD Trigger Threshold คงที่ต่อ Generation

### Changes Made

1. **DD Trigger ใช้ `InpHedge_DDTriggerPct` คงที่** (ไม่สะสม 5→10→15 อีก)
   - `CheckAndOpenHedgeByDD()`: เปลี่ยนจาก `g_nextBuyDDTrigger` / `g_nextSellDDTrigger` เป็น `InpHedge_DDTriggerPct` ตรงๆ
   - ลบ `g_nextBuyDDTrigger += InpHedge_DDStepPct` หลังเปิด hedge

2. **Recovery logic ไม่คำนวณ cumulative threshold อีก** (2 จุด: line ~7081, ~7676)

3. **Dashboard แสดง DD จริง vs threshold คงที่**: "BUY DD:2.3/5.0% | SELL DD:4.1/5.0%"

4. **`InpHedge_DDStepPct` marked as LEGACY** — คงไว้เพื่อ backward compatibility

5. **Version bump**: v6.20 → v6.21

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Triple-gate close (Expansion + Zone + TP Distance)
- Generation-aware binding/counting (v6.18/v6.19)
- NormalOrderCount() logic (v6.20)
- Expansion hedge trigger — ไม่แก้
- OpenDDHedge() binding logic — ไม่แก้
- CountPositions() — ไม่แก้
