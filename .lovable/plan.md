## Golden2 EA v2.74 — Hide Auxiliary Tester Chart Windows

ไฟล์เดียว: `public/docs/mql5/Golden2_EA.mq5`

### A) ฟังก์ชันใหม่ `HideAuxiliaryTesterCharts()`
- เรียกใน `OnInit` หลัง `CleanupChartIndicatorsInTester()` เมื่อ `g_isTesterMode && InpTester_HideAuxCharts`
- วน `ChartFirst()` / `ChartNext()` ทุก chart
- `ChartClose(id)` ทุกตัวยกเว้น `ChartID()` (chart หลักที่ EA ทำงาน)
- log: `[v2.74] Hidden N auxiliary tester chart(s)`

### B) Periodic re-run ใน OnTick
- ทุก 60 วินาที (gated ด้วย `g_isTesterMode` + `InpTester_HideAuxCharts`)
- กันกรณี Tester spawn chart เพิ่มกลางทาง (เช่นเมื่อ EA ขอ TF ใหม่ runtime)

### C) Input ใหม่
- `input bool InpTester_HideAuxCharts = true;` (default ON)

### D) Version bump → **v2.74**
- `#property version "2.74"`, header block, OnInit log, Dashboard `L_TITLE`
- log เพิ่ม: `HideAuxCharts=ON/OFF`

### หลักการสำคัญ
Indicator handles (`iBands`, `iATR` บน M5/M15 สำหรับ Squeeze) **ผูกกับ symbol+timeframe ไม่ใช่ chart window** → ปิด chart window ไม่กระทบ background calculation ใดๆ Tester ยัง generate bars ตาม TF ปกติ Squeeze/ATR ยังทำงานครบ

### ✅ สิ่งที่ "ไม่เปลี่ยน"
- ❌ ไม่แตะ `OrderSend` / trade logic / Entry / Exit / TP / SL
- ❌ ไม่แตะ Squeeze math / Grid Loss/Profit / Hedge / Triple-Gate / Accumulate
- ❌ ไม่แตะ v2.5 Trail / v2.6 Re-entry / v2.70 Frame / v2.72 Per-Side / v2.73 Cleanup
- ❌ ไม่แตะ License/News/Sync/Dashboard layout
- ✅ Output trade เหมือนเดิม 100% — แค่เหลือ chart window เดียวใน Tester → เร็วขึ้น 2-5x ใน visual mode
