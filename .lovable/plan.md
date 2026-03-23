

## เพิ่ม Input กำหนดจำนวน TF Expansion สำหรับ Hedge Entry — Gold Miner SQ EA (v5.9 → v6.0)

### สิ่งที่แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. เพิ่ม Input `InpHedge_MinTFConfirm` (line 323)
- กำหนดจำนวน TF ที่ต้องเป็น Expansion ก่อนเปิด Hedge (1-3)

#### 2. แก้ `CheckAndOpenHedge()` (line 6063)
- เปลี่ยนจาก `InpSqueeze_MinTFExpansion` → `InpHedge_MinTFConfirm`

#### 3. Version bump: v5.9 → v6.0

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge system logic ทั้งหมด (Matching/Partial/AvgTP/Grid)
- Squeeze filter logic สำหรับ entry ปกติ (ยังใช้ InpSqueeze_MinTFExpansion เหมือนเดิม)
