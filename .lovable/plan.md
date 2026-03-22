

## เพิ่ม Hedge Cycle Dashboard — Gold Miner SQ EA (v5.4 → v5.5)

### สิ่งที่แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. HedgeSet struct เพิ่ม 2 fields
- `cycleIndex` — เก็บ cycle (0=A, 1=B...) ตอนสร้าง set
- `hedgeNumber` — เก็บลำดับ hedge ภายใน cycle (1=H1, 2=H2...)

#### 2. CheckAndOpenHedge() — tag cycle/hedge number
- เมื่อเปิด hedge สำเร็จ → set `cycleIndex = g_currentCycleIndex`
- นับ hedge ที่มี cycleIndex เดียวกัน → กำหนด `hedgeNumber`

#### 3. DisplayHedgeCycleDashboard() — ฟังก์ชันใหม่
- ตาราง 4 คอลัมน์ (Group A-D) × 4 แถว (H1-H4)
- Group A = STANDBY เสมอ, B/C/D = OFF จนกว่า group ก่อนหน้ามี hedge
- แสดง Side + Lots + PnL สีเขียว/แดงตามกำไร
- Object prefix `GM_HC_` แยกจาก dashboard หลัก

#### 4. Input Parameters ใหม่
- `HedgeDashX` (default 10), `HedgeDashY` (default 500)

#### 5. Version bump: v5.4 → v5.5

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Net Lot Calculation, Hedge Guards, Cross-Set Matching
- Hedge Partial/Matching Close, Grid Mode logic
- Normal Matching Close logic
- Dashboard หลัก (ยังคงแสดงเหมือนเดิม)
