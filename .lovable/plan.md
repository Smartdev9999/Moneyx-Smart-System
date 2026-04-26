## Gold Miner EA v6.81 — Grid Profit Candle Confirmation

ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`
มิเรอร์ logic ของ `GridLoss_CandleConfirm` (v6.40) มาฝั่ง Grid Profit แบบสมมาตร

### Input ใหม่
ใต้ group `=== Grid Profit Side ===` (ถัดจาก `GridProfit_OnlyNewCandle`):
```cpp
input int  GridProfit_CandleConfirm = 0;  // v6.81: Require N confirming candles before GP (0=Off)
```
- BUY GP ต้องมีแท่งเขียว (close>open) ติดกัน N แท่งปิดแล้ว
- SELL GP ต้องมีแท่งแดง (close<open) ติดกัน N แท่งปิดแล้ว
- ใช้ฟังก์ชัน `HasCandleConfirmation()` เดิมที่มีอยู่แล้ว (ไม่สร้างใหม่)

### จุดที่แทรกเช็ค (2 จุด สมมาตรกับ GL)
1. `CheckGridProfit()` ราว line 3650 — หลัง `OnlyNewCandle` ก่อน Find last order
2. `CheckGridProfitTF()` ราว line 5471 — หลัง `OnlyNewCandle` ก่อน FindLastOrderTF
```cpp
if(GridProfit_CandleConfirm > 0)
{
   if(!HasCandleConfirmation(side, <tf>, GridProfit_CandleConfirm)) return;
}
```

### Dashboard
เพิ่มแถวใต้ "GL CandleConfirm" (ราว line 4651):
```cpp
if(GridProfit_CandleConfirm > 0)
   DrawTableRow(row, "GP CandleConfirm", IntegerToString(GridProfit_CandleConfirm) + " candle(s)", clrCyan, COLOR_SECTION_GRID); row++;
```

### Versioning
- `#property version` → "6.81"
- `#property description` + header comment → +"v6.81: Grid Profit Candle Confirmation"
- Dashboard title + `OnInit` log → v6.81

### สิ่งที่ไม่เปลี่ยน (ยืนยัน)
- ❌ ไม่แตะ Order execution (`trade.Buy/Sell/PositionClose`)
- ❌ ไม่แตะ Strategy logic: SMA/EMA, Grid entry/exit, TP/SL, Trailing, Accumulate, Drawdown, Hedge triple-gate
- ❌ ไม่แตะ License / News / Time filter / Sync modules
- ❌ ไม่แตะ `HasCandleConfirmation()` (reuse เดิม)
- ❌ ไม่แตะ `GridLoss_CandleConfirm` / Recovery
- ✅ ปิดด้วย `GridProfit_CandleConfirm = 0` = พฤติกรรม v6.80 100%
