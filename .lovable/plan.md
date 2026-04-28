# Gold Miner EA v6.86 — Grid Refill After Per-Order Trailing Close (DONE)

ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

## ฟีเจอร์ใหม่
ระบบเติมออเดอร์ Grid Loss / Grid Profit ใน "ช่องว่าง" ที่ Per-Order Trailing / Breakeven ปิดออกไป — เมื่อราคาเด้งกลับมาที่จุดเดิม จะออกออเดอร์ทดแทนขนาดเท่าเดิม โดยไม่ออกซ้อนกับออเดอร์ที่ยังเปิดอยู่

## Inputs ใหม่ (Per-Order Trailing Stop group)
- `EnableGridRefill` (default false)
- `GridRefill_GL`, `GridRefill_GP`
- `GridRefill_TolerancePts`, `GridRefill_MaxSlots`, `GridRefill_ExpireMin`

## เพิ่ม
- struct `GridRefillSlot` + arrays globals
- `RefillScanAndDetectCloses()` — diff tracked tickets แต่ละ tick → push ที่หายไปเข้า slot buffer
- `TryRefillGridSlot(side, kind)` — เช็ค tolerance + anti-overlap → OpenOrder ด้วย lot/level เดิม
- `RefillResetSide()`, `RefillCleanupSlots()`, `ExtractGridLevel()`, `IsGridKindComment()`
- Hook ใน OnTick (ก่อน trailing), CheckGridLoss/Profit (ก่อน MaxTrades gate), ResetTrailingState Buy/Sell
- Dashboard row "Refill Slots: B:n S:n" (เฉพาะเมื่อ enabled)

## Version
v6.85 → **v6.86** (header, #property version+description, OnInit/Deinit log, Dashboard headerVersion)

## Memory
`mem://trading/gold-miner-ea/grid-refill-after-trailing-v6-86.md`
