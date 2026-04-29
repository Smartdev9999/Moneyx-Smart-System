---
name: Gold Miner EA v6.88 — Independent Squeeze Pause Trailing
description: Pause Trailing นับ EXPANSION TF เองจาก g_squeeze[].state โดยใช้ InpSqueeze_PauseTrail_MinTF (1-3) แยกขาดจาก Block New Orders / InpSqueeze_BlockOnExpansion / InpSqueeze_MinTFExpansion / g_squeezeBlocked*
type: feature
---

# Gold Miner EA v6.88

ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

## ปัญหา v6.87
`IsSqueezePausingTrailing()` อ่าน `g_squeezeBlocked / Buy / Sell` ซึ่ง flag เหล่านี้ตั้งค่าใน `UpdateSqueezeState` ภายใต้ `if(InpSqueeze_BlockOnExpansion)` เท่านั้น → ถ้า user ปิด Block New Orders แต่เปิด Pause Trailing → ไม่ทำงาน

## เปลี่ยน v6.88
- เพิ่ม Input `InpSqueeze_PauseTrail_MinTF` (default 1, range 1-3)
- `IsSqueezePausingTrailing()` rewrite: นับ TF ที่ `g_squeeze[sq].state == 2` (EXPANSION) ตรงๆ จาก array, ไม่อ่าน `g_squeezeBlocked*` อีก
- ทำงานแม้ `InpSqueeze_BlockOnExpansion = false`

## ไม่เปลี่ยน
- `UpdateSqueezeState` / BB / KC / ATR / state machine
- Block New Orders logic (`g_squeezeBlocked*`, `InpSqueeze_BlockOnExpansion`, `InpSqueeze_MinTFExpansion`, `InpSqueeze_DirectionalBlock`, `InpSqueeze_CloseOnExpansion`)
- Hedge Trigger Expansion
- Guard 5 จุดของ v6.87 (`ManagePerOrderTrailing`, `ManageMaxGridTrailing`, `ManageTrailingStop_TF`, `ApplyTrailingSL`, `ApplyTrailingSL_TF`) — เปลี่ยนแค่ "ใจ" ของ helper
- v6.86 (`CalcGenAveragePrice` / `CountGenOrders` / `CloseGenSide`)
- Order execution / Strategy / TP / Hedge / Accumulate / DD exit / License / News / Time / Sync

## Version
v6.87 → v6.88 (header, `#property version`, `#property description`, `OnInit`/`OnDeinit` log, Dashboard headerVersion ทุก mode)
