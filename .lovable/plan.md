## Golden2 EA v2.7.9 — Tester Chart Cleanup + Side-Tagged Comments

ไฟล์: `public/docs/mql5/Golden2_EA.mq5`  (อย่างเดียว)

### 1) ซ่อน ATR/ADX/อื่นๆ บน chart ตอน Backtest (ไม่มี input ใหม่)

เพิ่มฟังก์ชัน 2 ตัว เปิดอัตโนมัติเฉพาะใน Strategy Tester (`MQL_TESTER`):

- `CleanupChartIndicatorsInTester()` — เรียกใน `OnInit()` หลัง detect tester:
  - วน sub-window ทั้งหมดของ `ChartID()` แล้ว `ChartIndicatorDelete` ทุกตัว (ลบ ATR/ADX/BB/KC/EMA/MA/ZigZag ที่โผล่บน chart)
  - ปิด `CHART_SHOW_GRID`, `CHART_SHOW_PERIOD_SEP`, `CHART_SHOW_VOLUMES`
  - ใน non-visual tester ปิด `CHART_SHOW_TRADE_LEVELS`, `CHART_AUTOSCROLL` ด้วย
- `HideAuxiliaryTesterCharts()` — เรียกใน `OnInit()` + sweep ทุก ~60s ใน `OnTick()`:
  - `ChartClose` ทุก chart ที่ `id != ChartID()` (กัน Tester เปิด tab M5/M15/H1 จาก iBands/iATR/iADX/iMA handles)

หมายเหตุ: handles ทั้งหมด (`g_atrHandle`, `g_sqATR`, `g_sqADX`, `g_sqBB`, `g_sqKCEMA`, `g_sqEMA`) ยังคงทำงานเหมือนเดิม — ลบ "กราฟิก" บน chart เท่านั้น ไม่กระทบการคำนวณ Squeeze / Grid / Exit / Hedge

### 2) เพิ่ม B/S ใน Order Comment ทุก Set

แก้ `MakeComment()` ให้รับ `ENUM_SIDE` แล้วฝัง `B_` / `S_` หลัง group และก่อน tag:

```cpp
string MakeComment(int g, ENUM_SIDE side, bool hedge, string tag){
   string sd   = (side==SIDE_BUY ? "B_" : "S_");
   string base = StringFormat("G%d_%s", g, sd);
   if(hedge) base += "HD_";
   return base + tag;
}
```

ตัวอย่างผลลัพธ์:
- Initial:    `G2_B_IN`,  `G2_S_IN`
- Grid Loss:  `G2_B_GL#1`,`G2_S_GL#1`
- Grid Profit:`G2_B_GP#3`,`G2_S_GP#3`
- Hedge:      `G3_B_HD_IN`, `G3_S_HD_GL#2`

อัปเดต callsites ทุกจุดที่เรียก `MakeComment(...)`:
- 872/873, 1052/1053 (initial): ส่ง `SIDE_BUY` / `SIDE_SELL` ตามตัวแปร
- 1405/1415 (re-arm initial): ส่งตาม side ปัจจุบัน
- 1676 (GL), 1726 (GP): ส่ง side ของ basket
- 1900, 1916, 1925, 2499 (hedge / mirror): ส่ง side ของ hedge ที่กำลังวาง

อัปเดต `ParseComment()` ให้ peel `B_` / `S_` หลัง `G{n}_` (และหลัง `HD_` กรณี hedge) คืน `tag` แบบเดิม (`IN`, `GL#1`, ...) เพื่อ compat กับ `StringFind(tag, tagPrefix)` ที่ใช้อยู่ทั่วโค้ด — และเพิ่ม `ENUM_SIDE &side` out param แต่ไม่บังคับ caller ใช้ (callers ปัจจุบันยังคง logic เดิมเพราะใช้ `POSITION_TYPE` จากตัว position เป็นหลัก)

Backward-compat scan: history positions เก่า (ก่อน v2.7.9) ที่มี comment รูปแบบ `G{n}_IN` ยังถูก parse ได้ (peel B_/S_ เป็น optional)

### 3) Version bump v2.7.8 → v2.7.9

อัปเดตทุกจุด: `#property version`, `#property description`, header comment block, `OnInit/OnDeinit` Print, dashboard `headerVersion`

### Rules of Steel — ไม่เปลี่ยนแปลง
- ❌ OrderSend / trade.Buy / trade.Sell / trade.PositionClose / trade.OrderModify
- ❌ Entry conditions / SMA / Squeeze (BB/KC/ADX/EMA/ATR) / ZigZag
- ❌ Grid Loss/Profit lot/distance/candle confirm/ATR snapshot
- ❌ Hedge mirror / Triple-Gate / Pending hedge / Block percent
- ❌ Avg TP/SL / Per-order trail / Bar-close trail / Cost-Hit / Accumulate
- ❌ Daily target / Drawdown / News / License / Sync
- ❌ Squeeze pause trailing / Strip SL
- Comment อ่านได้ง่ายขึ้น แต่ tag matching เดิมทำงานครบ (StringFind tagPrefix หา `IN`/`GL#`/`GP#` ได้ปกติ)
- ATR/ADX กราฟิกหายเฉพาะใน Tester — บัญชีจริงไม่กระทบ
