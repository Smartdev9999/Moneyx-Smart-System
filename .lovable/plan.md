# Gold Miner EA v6.85 — Avg Trailing as Broker SL (DONE)

ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

## บั๊ก
ภาพแสดง S/L = 0.00 ทุก ticket → `SyncBrokerTPSL()` เขียนทับ broker SL ที่ `ApplyTrailingSL()` เพิ่ง push ด้วย 0 ทุก ~2s

## แก้
1. `SyncBrokerTPSL()` BUY/SELL — ใช้ `g_trailingSL_Buy/Sell` แทน slBuy/Sell เมื่อ trailing active; preserve `curSL` เมื่อ slBuy/Sell=0 และ ticket มี SL อยู่
2. `ApplyTrailingSL()` — sync `g_lastBrokerSL_Buy/Sell` cache หลัง modify สำเร็จ

## Version
v6.84 → v6.85 (header, #property version+description, OnInit/Deinit log, Dashboard headerVersion)

## Memory
`mem://trading/gold-miner-ea/avg-trailing-broker-sl-v6-85.md`
