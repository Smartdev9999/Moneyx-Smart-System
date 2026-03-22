

## Fix: Hedge เปิดผิดฝั่ง — SELL Hedge เปิดขณะ Expansion BUY (v5.10 → v5.11)

### สิ่งที่แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. เพิ่ม Squeeze Directional Block Guard ใน CheckAndOpenHedge()
- ถ้า `g_squeezeSellBlocked` (expansion BUY) → ห้ามเปิด SELL hedge
- ถ้า `g_squeezeBuyBlocked` (expansion SELL) → ห้ามเปิด BUY hedge
- ป้องกัน hedge เปิดผิดฝั่งเมื่อ TF ต่ำเข้า expansion ก่อน TF สูง

#### 2. Version bump: v5.10 → v5.11

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge Partial/Matching/Grid Close logic
- Net Lot Calculation, Cycle Labeling
- Dashboard / Hedge Cycle Monitor
