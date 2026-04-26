# Gold Miner EA v6.83 — Trailing Stop Throttle (DONE)

ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

## ปัญหา
ทุก tick ระบบยิง PositionModify ทุก ticket (24 ticket × หลาย tick/วินาที) — โหลด server หนัก

## แก้ไข
1. `ManageTrailingStop` (Average-Based) BUY/SELL: push SL เฉพาะเมื่อขยับครบ `TrailingStep` points
2. `ApplyTrailingSL`: skip ticket ที่ broker SL ตรงกับ target อยู่แล้ว (`MathAbs(currentSL-slPrice) < point`)
3. `ManagePerOrderTrailing` Breakeven BUY/SELL: เสริม epsilon guard กัน round-trip ที่เท่ากัน

## Version
v6.82 → v6.83 (header, #property version+description, OnInit log, Deinit log, Dashboard headerVersion)

## Memory
`mem://trading/gold-miner-ea/trailing-modify-throttle-v6-83.md`
