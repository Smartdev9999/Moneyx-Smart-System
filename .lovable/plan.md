## Fix: Hedge เปิดรัวๆ + H2 เปิดก่อนเวลา (v5.21 → v5.22)

### สิ่งที่แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. เพิ่ม Cooldown 60 วินาทีหลังเปิด Hedge
- เพิ่ม `g_lastHedgeOpenTime` global variable
- ต้น `CheckAndOpenHedge()` เช็ค `TimeCurrent() - g_lastHedgeOpenTime < 60` → return
- Set ค่าหลัง `OpenOrder()` สำเร็จ

#### 2. เพิ่ม Guard 4: H2+ ต้องรอ bound orders เคลียร์
- หลัง Guard 3: สแกนทุก active set ใน cycle เดียวกัน
- ถ้ายังมี `boundTicketCount > 0` → return (ไม่เปิด hedge ใหม่)
- H2 เปิดได้เมื่อ: expansion เปลี่ยนทิศ + bound orders หมด + ยังมี imbalance

#### 3. Version bump: v5.21 → v5.22

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge/Grid Recovery logic ทั้งหมด
- Normal Matching Close logic
- Dashboard / Hedge Cycle Monitor layout
