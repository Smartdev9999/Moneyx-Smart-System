

## v6.55 — Matching Close ไม่ปิด Bound Orders (ปล่อยเป็น Recovery แทน)

### หลักการ

1. **ปัญหา**: ManageHedgeMatchingClose / BoundAvgTP / PartialClose ปิด bound orders ทิ้ง → ไม่ถูกต้อง
2. **Fix**: ทั้ง 3 ฟังก์ชัน ไม่ปิด bound orders อีกต่อไป → ปิดแค่ hedge + release bounds เป็น recovery
3. **Version bump**: v6.54 → v6.55

### ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic — ไม่แก้
- Trading Strategy Logic — ไม่แก้
- Core Module Logic — ไม่แก้
- Grid entry/exit logic — ไม่แก้
- Balance Guard — ยังทำงานปกติ
- Triple Gate logic — ไม่แก้
- IsTicketBound / IsHedgeComment guards — ไม่แก้
- v6.37-v6.54 features — ไม่แก้
