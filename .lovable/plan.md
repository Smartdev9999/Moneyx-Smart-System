## Fix: Directional Block ไม่ทำงานเมื่อ Expansion เกิดใน TF เดียว (v5.19 → v5.20)

### สิ่งที่แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. แยก Directional Block ออกจาก MinTFExpansion threshold (line 1038-1055)
- เดิม: Directional block อยู่ภายใต้ `if(expCount >= InpSqueeze_MinTFExpansion)` → ถ้า MinTF=2 แต่มี expansion แค่ 1 TF → ไม่ block
- ใหม่: Directional block ใช้ `expCount >= 1` → **แค่ 1 TF ก็ block ฝั่งตรงข้ามทันที**
- Full block (non-directional mode) ยังใช้ MinTFExpansion threshold เดิม

#### 2. Version bump: v5.19 → v5.20

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge/Grid Recovery logic ทั้งหมด
- Normal Matching Close logic
- Dashboard layout/styling
