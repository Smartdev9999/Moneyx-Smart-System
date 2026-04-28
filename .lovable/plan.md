# Gold Miner EA v6.87 — Squeeze Pause Trailing (DONE)

ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

## เพิ่ม
- `InpSqueeze_PauseTrailing` (default true) ในกลุ่ม Volatility Squeeze Filter
- Helper `IsSqueezePausingTrailing()` (อ่าน `g_squeezeBlocked/Buy/Sell`)
- Guard ใน 5 จุด:
  - `ManagePerOrderTrailing()`
  - `ManageMaxGridTrailing()`
  - `ManageTrailingStop_TF()`
  - `ApplyTrailingSL()` + `ApplyTrailingSL_TF()` (defense-in-depth)

## พฤติกรรม
- Expansion → trailing/breakeven หยุดยิง `PositionModify` (state preserved)
- Normal → trailing ทำงานต่ออัตโนมัติ
- ไม่กระทบการเปิดออเดอร์ใหม่ / Grid / Hedge / TP / Accumulate

## Version
v6.86 → v6.87 ทุกจุด

## Memory
`mem://trading/gold-miner-ea/squeeze-pause-trailing-v6-87.md`
