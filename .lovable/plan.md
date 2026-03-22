


## Fix: Dashboard "Label" Bug + Recovery Grid Blocked During Expansion (v5.15 → v5.16)

### สิ่งที่แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Dashboard "Label" Bug
- เปลี่ยน empty string `""` เป็น space `" "` ใน cellText/plText เมื่อ groupStatus == 0
- ป้องกัน MQL5 OBJ_LABEL แสดง "Label" เป็นค่าเริ่มต้น

#### 2. Recovery Grid Decoupled จาก Expansion Guard
- ย้าย `ManageHedgeGridMode()` และ `ManageGridRecoveryMode()` ออกจาก `if(!isExpansion)` block
- Grid recovery เปิด orders ได้ทุกสถานะตลาด
- เพิ่ม expansion guard ภายใน ManageGridRecoveryMode() และ ManageHedgeGridMode() สำหรับ matching close เท่านั้น

#### 3. Group Status Logic — Non-Sequential Groups
- เปลี่ยนจากเช็ค `groupHasHedge[g-1]` เป็น `g_hedgeSetCount > 0`
- STANDBY แสดงเมื่อมี hedge ใดๆ active (ไม่ใช่แค่ group ก่อนหน้า)

#### 4. Version bump: v5.15 → v5.16

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge Guards (cycle-aware, squeeze directional block)
- Normal Matching Close logic
- Grid Recovery lot calculation + direction logic
