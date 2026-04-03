## Implemented: v6.33 — แก้ Dynamic Balance Guard ให้อัปเดต target เฉพาะเมื่อไม่มีออเดอร์เท่านั้น

### ปัญหา
`UpdateDynamicBalanceGuardTarget()` อัปเดต target ทุกครั้งที่ balance เปลี่ยน แม้ยังมีออเดอร์อยู่ → target วิ่งหนี → ชุด hedge ไม่มีทาง trigger Balance Guard

### แก้ไข (v6.33)
1. **Version bump**: v6.32 → v6.33
2. **เพิ่ม `if(TotalOrderCount() != 0) return;`** ใน `UpdateDynamicBalanceGuardTarget()` — อัปเดตเฉพาะเมื่อ flat เท่านั้น

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic, Trading Strategy Logic, Core Module Logic
- DD trigger / Triple-gate / Matching close
- OpenDDHedge / binding / generation logic
- Balance Guard trigger/close logic
- Daily Target Profit (v6.32)
