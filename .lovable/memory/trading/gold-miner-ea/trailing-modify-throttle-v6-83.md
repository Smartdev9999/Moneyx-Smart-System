---
name: Gold Miner EA v6.83 — Trailing Stop Throttle
description: v6.83 stops PositionModify spam by gating Average-Based trailing SL pushes by TrailingStep and skipping per-ticket modifies when broker SL already equals target. Symptoms before fix were ~24 PositionModify per tick across all open positions.
type: feature
---

# Gold Miner EA v6.83 — Trailing Modify Throttle

ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

## ปัญหา
ทุก tick ที่ราคาขยับเพียง 1 point, `ManageTrailingStop()` (Average-Based) ส่ง `ApplyTrailingSL()` → loop modify ทุก ticket → log:
```
position modified [#24 buy 0.37 XAUUSD sl: 4467.93, tp: 4512.37]
position modified [#23 buy 0.34 XAUUSD sl: 4467.93, tp: 4512.37]
...  (×24 ticket × หลาย tick/วินาที)
```
สาเหตุ:
1. `ManageTrailingStop` push SL ทันทีที่ `newSL > g_trailingSL_Buy` ไม่มี TrailingStep buffer
2. `ApplyTrailingSL` ไม่ตรวจว่า broker SL บน ticket ตรงกับ target อยู่แล้วหรือเปล่า

## แก้ไข (v6.83)
1. **ManageTrailingStop BUY/SELL**: push SL เฉพาะเมื่อ `newSL >= g_trailingSL_Buy + TrailingStep*point` (BUY) หรือ `newSL <= g_trailingSL_Sell - TrailingStep*point` (SELL) — ครั้งแรกที่ activate ส่ง modify ปกติ
2. **ApplyTrailingSL**: ก่อน `trade.PositionModify()` เช็ค `MathAbs(currentSL - slPrice) < point` → skip
3. **ManagePerOrderTrailing Breakeven (BUY/SELL)**: เสริม guard `MathAbs(currentSL - finalBE) >= point` กัน floating-point round เท่ากันแต่ผ่าน `>` check

## ✅ ไม่กระทบ trading logic
- ค่า SL ที่คำนวณเหมือนเดิมทุกจุด
- เงื่อนไข Activation / Breakeven / TrailingActivation คงเดิม
- ไม่แตะ Hedge / Triple-Gate / DD / Squeeze / News / License / OrderSend / PositionClose
