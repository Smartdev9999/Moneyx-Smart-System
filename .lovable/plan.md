# Gold Miner EA v6.86 — Max Grid Avg Trailing นับ Grid Profit (DONE)

ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

## แก้
- `CalcGenAveragePrice` รวม `_INIT + _GL + _GP` (weighted avg)
- `CountGenOrders` รวม `_GP` (auto-advance ไม่ข้าม gen ที่เหลือแต่ GP)
- `CloseGenSide` ปิด `_GP` ด้วยเมื่อ trailing SL hit
- `CountGenGridLoss` ไม่แตะ (ยังเป็น trigger เฉพาะ GL)

## Version
v6.85 → v6.86 (header, #property, OnInit/Deinit log, Dashboard headerVersion)

## Memory
`mem://trading/gold-miner-ea/maxgrid-trail-include-gp-v6-86.md`
