

## Fix: Grid หยุดทำงานหลังเปลี่ยน Parameter กลางคัน — Gold Miner SQ EA (v6.4 → v6.5)

### สิ่งที่แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. แก้ `RecoverInitialPrices()` — เพิ่ม fallback กู้คืนจาก GL order เก่าสุด
- Pass 1: หา INIT orders เหมือนเดิม
- Pass 2: ถ้าไม่เจอ INIT → สแกนหา GL order เก่าสุด → ใช้ราคาเปิดเป็น fallback initial price
- Print log เมื่อใช้ fallback

#### 2. เพิ่ม fallback condition ใน OnTick (4 จุด)
- เพิ่ม `|| gridLossBuy > 0` และ `|| gridLossSell > 0` ในเงื่อนไข grid
- ถ้ามี GL orders อยู่แล้ว → grid ทำงานต่อได้แม้ไม่มี INIT

#### 3. Version bump: v6.4 → v6.5

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge system logic ทั้งหมด (รวม Reverse Hedge)
- Orphan Recovery system, Comment Generation logic
