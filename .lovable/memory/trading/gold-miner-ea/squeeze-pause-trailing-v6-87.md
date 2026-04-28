---
name: Gold Miner EA v6.87 — Squeeze Pause Trailing
description: When Volatility Squeeze Filter triggers Expansion (per InpSqueeze_ExpThreshold + InpSqueeze_MinTFExpansion), all trailing/breakeven SL updates pause and auto-resume on Normal. Does NOT block new orders / grid / hedge / TP / accumulate.
type: feature
---

# Gold Miner EA v6.87

ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

## เพิ่ม
- Input `InpSqueeze_PauseTrailing` (default `true`) ในกลุ่ม `=== Volatility Squeeze Filter ===`
- Helper `IsSqueezePausingTrailing()` → true เมื่อ `InpUseSqueezeFilter && InpSqueeze_PauseTrailing && (g_squeezeBlocked || g_squeezeBuyBlocked || g_squeezeSellBlocked)`
- Early-return guard ที่:
  - `ManagePerOrderTrailing()`
  - `ManageMaxGridTrailing()`
  - `ManageTrailingStop_TF(int tfIdx)`
  - `ApplyTrailingSL()` + `ApplyTrailingSL_TF()` (defense-in-depth)

## พฤติกรรม
- เข้า Expansion (อย่างน้อย `InpSqueeze_MinTFExpansion` TF) → trailing/breakeven หยุดยิง `PositionModify`
- กลับเป็น Normal → trailing ทำงานต่ออัตโนมัติทันที (state ไม่รีเซ็ต — ใช้ค่าก่อนหยุดต่อ)
- SL ที่ส่งโบรกไว้แล้วก่อนหยุดยังคงอยู่บนเซิร์ฟเวอร์

## ไม่เปลี่ยน
- ไม่แตะ Order Execution / Trading Strategy / TP / Accumulate Close / Grid / Hedge / DD exit
- ไม่แตะ guard การเปิดออเดอร์ใหม่ (`g_squeezeBlocked*` ฝั่ง grid/initial)
- ไม่แตะ `UpdateSqueezeState` / BB / KC / ATR / SMA
- ไม่แตะ License / News / Time / Sync
- ไม่แตะ v6.86 (`CalcGenAveragePrice` / `CountGenOrders` / `CloseGenSide`)

## Version
v6.86 → v6.87 (header, `#property version`, `#property description`, `OnInit`/`OnDeinit` log, Dashboard headerVersion)
