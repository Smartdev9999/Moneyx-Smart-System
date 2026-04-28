# Gold Miner EA v6.88 — Grid Refill Decoupled (DONE)

ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

## ปัญหา
v6.87 Refill ไม่ทำงาน เพราะ `TryRefillGridSlot()` ถูกเรียกใน `CheckGridLoss/Profit()` ซึ่งถูก gate โดย `MaxTrades`, `buyCount>0`

## แก้
- เพิ่ม `ManageGridRefill()` ใน OnTick หลัง `RefillScanAndDetectCloses()` — รัน refill ทุก tick ไม่สนใจ grid gate
- `TryRefillGridSlot()`: preserve original level# (`useLvl = lvl > 0 ? lvl : maxLvl+1`)
- Verbose reject logs throttled 30s: MaxOpenOrders, g_newOrderBlocked, overlap, OpenOrder failed
- Version bump v6.87 → **v6.88** (header, #property, OnInit/Deinit, Dashboard)

## Memory
`mem://trading/gold-miner-ea/grid-refill-decoupled-v6-88.md`
