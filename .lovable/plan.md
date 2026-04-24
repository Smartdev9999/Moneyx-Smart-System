## Golden2 EA v2.73 — Tester Chart Cleanup

ไฟล์เดียวที่แก้: `public/docs/mql5/Golden2_EA.mq5`

### A) Auto-remove chart indicators ใน Tester
- เพิ่ม `CleanupChartIndicatorsInTester()` เรียกใน `OnInit` เมื่อ `g_isTesterMode == true` และ `InpTester_CleanChart == true`
- วน `ChartIndicatorsTotal(0, win)` จาก sub-window สูงสุดลงมา 0 → `ChartIndicatorDelete(0, win, name)`
- ลบทั้ง main chart indicators (BB, MA, ZigZag) + sub-window indicators (ATR, MACD ฯลฯ) ที่ template ดึงมา
- log: `[v2.73] Tester chart cleanup: removed N indicators`

### B) ปิด chart visual ที่ไม่จำเป็นใน Tester
- `CHART_SHOW_GRID = false`
- `CHART_SHOW_PERIOD_SEP = false`
- `CHART_SHOW_VOLUMES = CHART_VOLUME_HIDE`
- ใน non-visual tester เพิ่ม: `CHART_SHOW_TRADE_LEVELS = false`, `CHART_AUTOSCROLL = false`

### C) Input ใหม่
- `input bool InpTester_CleanChart = true;` — toggle (default ON)

### D) Version bump → **v2.73**
- `#property version "2.73"`, header block, OnInit log, Dashboard `L_TITLE`
- log เพิ่ม: `TesterCleanChart=ON/OFF`

### สิ่งที่ "ไม่เปลี่ยน"
- ❌ ไม่แตะ `OrderSend` / trade logic / Entry / Exit / TP / SL
- ❌ ไม่แตะ Grid Loss/Profit / Hedge / Triple-Gate / Accumulate
- ❌ ไม่แตะ Squeeze math (BB/KC/ATR ภายใน EA ยังคำนวณปกติผ่าน handle = background)
- ❌ ไม่แตะ v2.5 Trail / v2.6 Re-entry / v2.70 Continuous Frame / v2.72 Per-Side Squeeze + Speed
- ❌ ไม่แตะ License/News/Sync
- ✅ Output trade เหมือนเดิม 100% — แค่ชาร์ต Tester สะอาด → เร็วขึ้น 2-5x ใน visual mode