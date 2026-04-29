# Gold Miner EA v6.88 — Independent Squeeze Pause Trailing (DONE)

ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

## เปลี่ยน
- เพิ่ม `InpSqueeze_PauseTrail_MinTF` (default 1, range 1-3) ในกลุ่ม Volatility Squeeze Filter
- `IsSqueezePausingTrailing()` rewrite: นับ EXPANSION TF เอง (`g_squeeze[sq].state == 2`)
- ตัดการพึ่งพา `g_squeezeBlocked / Buy / Sell` → ทำงานแม้ปิด Block New Orders

## พฤติกรรม
- Pause Trailing แยกขาดจาก Block New Orders (มี TF threshold ของตัวเอง)
- Expansion TF >= MinTF → trailing/breakeven หยุด PositionModify
- กลับ Normal → trailing ทำงานต่อ

## ไม่เปลี่ยน
- Block New Orders / Hedge / Strategy / TP / Grid / Accumulate / Order execution

## Version
v6.87 → v6.88

## Memory
`mem://trading/gold-miner-ea/squeeze-pause-trailing-independent-v6-88.md`
