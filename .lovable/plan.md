


## Fix: Dashboard แสดงข้อมูล Stale + PnL เฉพาะ Hedge Order (v5.18 → v5.19)

### สิ่งที่แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Reset `hedgeLots = 0` เมื่อ hedge position หายไป (line 6315)
- ป้องกัน dashboard แสดง lot ค่าเก่าหลัง order ปิด

#### 2. Dashboard แสดงสถานะจริงตาม hedgeTicket (line 7752-7790)
- `hedgeTicket > 0` + position exists → แสดง volume จริงจาก `POSITION_VOLUME`
- `gridMode = true` → แสดง "REC" (Recovery)
- `boundTicketCount > 0` → แสดง "H1:-- S"
- ไม่มีอะไรเลย → แสดง "CLR"

#### 3. PnL แสดงเฉพาะ Hedge Order เท่านั้น
- ลบ loop grid tickets PnL และ bound orders PnL ออก
- เหลือแค่ hedgeTicket PnL

#### 4. Version bump: v5.18 → v5.19

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge/Grid Recovery logic ทั้งหมด
- Hedge Guards, Normal Matching Close logic
- Dashboard layout/styling
