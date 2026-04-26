---
name: Gold Miner EA v6.82 — Grid Profit Candle Confirmation
description: v6.82 mirrors v6.40's GL CandleConfirm into Grid Profit. Input GridProfit_CandleConfirm (default 0=off) requires N consecutive confirming candles (green for BUY GP, red for SELL GP) before placing the next Grid Profit order. Reuses existing HasCandleConfirmation(). Applied in CheckGridProfit (single-TF) and CheckGridProfitTF (MTF). Dashboard shows "GP CandleConfirm" row when active.
type: feature
---

# Gold Miner EA v6.82 — Grid Profit Candle Confirmation

ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

## Input ใหม่
```cpp
input int GridProfit_CandleConfirm = 0;  // 0=Off
```
ใต้ `=== Grid Profit Side ===` หลัง `GridProfit_OnlyNewCandle`

## Logic
- BUY GP → ต้องมีแท่งเขียว (close>open) ปิดติดกัน N แท่ง
- SELL GP → ต้องมีแท่งแดง (close<open) ปิดติดกัน N แท่ง
- ใช้ฟังก์ชันเดิม `HasCandleConfirmation(side, tf, N)` (สร้างไว้แล้วในยุค v6.40 สำหรับ GL)
- เช็คหลัง `OnlyNewCandle` ก่อน `FindLastOrder`/`FindLastOrderTF`

## จุดที่ใส่
- `CheckGridProfit()` — ใช้ `PERIOD_CURRENT`
- `CheckGridProfitTF()` — ใช้ `g_tfStates[tfIdx].tf`

## Dashboard
แถวใหม่ "GP CandleConfirm: N candle(s)" (cyan) ใต้ "GL CandleConfirm" — แสดงเฉพาะเมื่อ > 0

## ไม่เปลี่ยน
- ไม่แตะ Order execution / SMA-EMA / Grid entry/exit math / TP/SL / Trailing / Accumulate / Hedge / Triple-Gate / License / News / Time / Sync
- ไม่แตะ `HasCandleConfirmation()` / `GridLoss_CandleConfirm` / Recovery
- `GridProfit_CandleConfirm = 0` = พฤติกรรม v6.81 100%
