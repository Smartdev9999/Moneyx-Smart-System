---
name: Gold Miner EA v6.84 — Per-Side Trailing Reset Fix
description: v6.84 fixes Average-Based Trailing Stop not working when both Buy and Sell are open. Root cause was ResetTrailingState() wiping both sides' state when one side hit SL, plus an early return blocking the other side's processing in the same tick. Now uses ResetTrailingStateBuy/Sell helpers and removes the early return. Mirror fix applied to MTF (ResetTrailingStateTFBuy/Sell).
type: feature
---

# Gold Miner EA v6.84 — Per-Side Trailing Reset Fix

ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

## 🐛 บั๊ก (v6.83 และก่อนหน้า)
1. `ResetTrailingState()` ล้างทั้ง Buy + Sell พร้อมกัน — เมื่อฝั่งใดฝั่งหนึ่ง trail-out ฝั่งที่เหลือถูกรีเซ็ตทิ้ง
2. `return;` หลัง `CloseAllSide(BUY)` block SELL section ใน function เดียวกัน
3. มีบั๊กเดียวกันใน MTF: `ResetTrailingStateTF()` + `ManageTrailingStop_TF()`

## ✅ แก้ไข (v6.84)
- เพิ่ม `ResetTrailingStateBuy()` / `ResetTrailingStateSell()` (single-pair)
- เพิ่ม `ResetTrailingStateTFBuy(idx)` / `ResetTrailingStateTFSell(idx)` (MTF)
- `ManageTrailingStop()`: BUY hit → `ResetTrailingStateBuy()` (ลบ return), SELL hit → `ResetTrailingStateSell()`
- `ManageTrailingStop_TF()`: เช่นเดียวกัน per-TF
- `ResetTrailingState()` / `ResetTrailingStateTF()` ตัวเดิมยังอยู่ครบสำหรับ cycle reset / OnInit

## ผลลัพธ์
Buy และ Sell trailing ทำงาน **อิสระต่อกัน 100%** — ฝั่งหนึ่ง trail-out ไม่กระทบ state อีกฝั่ง

## ✅ ไม่กระทบ trading logic
- ไม่แตะ OrderSend / trade.Buy / trade.Sell / trade.PositionClose / CloseAllSide
- ไม่แตะสูตร newSL, TrailingStep, TrailingActivation, BreakevenBuffer, BreakevenActivation
- ไม่แตะ ApplyTrailingSL (v6.83 throttle ครบเหมือนเดิม)
- ไม่แตะ Hedge / Triple-Gate / DD / Squeeze / News / License / Grid / Accumulate
