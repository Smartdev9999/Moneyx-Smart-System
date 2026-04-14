

## v6.54 — เพิ่มโหมด "Start Order Grid" สำหรับ Max Grid Average Trailing Stop

### หลักการ

1. **ปัญหา**: Max Grid Trailing ทำงานเมื่อ `glCount >= GridLoss_MaxTrades` เท่านั้น → ต้องรอจนถึง max orders
2. **Fix**: เพิ่ม `MaxGrid_TrailMode` (0=Max Order Grid, 1=Start Order Grid) + `MaxGrid_StartOrders` → trailing เริ่มได้เร็วขึ้น
3. **Version bump**: v6.53 → v6.54

### ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic — ไม่แก้
- Trading Strategy Logic — ไม่แก้
- Core Module Logic — ไม่แก้
- Grid entry/exit logic — ไม่แก้
- Hedge Matching Close / Balance Guard — ไม่แก้
- ManageMaxGridTrailing trailing/activation/close logic — ไม่แก้ (แก้แค่เงื่อนไขเริ่มต้น)
- v6.37-v6.53 features — ไม่แก้
