## Implemented: v6.30 — แก้ Dynamic Balance Guard ไม่อัปเดต target เมื่อ flat

### สาเหตุ
`CheckBalanceGuard()` มี early return `if(!g_balanceGuardActive) return;` อยู่ก่อน dynamic update block → เมื่อ guard deactivate แล้ว target ไม่เคยอัปเดต

### แก้ไข
1. **Version bump**: v6.29 → v6.30
2. **ย้าย Dynamic update block** ขึ้นมาก่อน early return — ทำงานทุก tick ที่ `TotalOrderCount()==0` โดยไม่ขึ้นกับ `g_balanceGuardActive`
3. **ลบ dynamic update ออกจาก flat deactivation block** (ย้ายขึ้นไปแล้ว)

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic
- Trading Strategy Logic
- Core Module Logic
- DD trigger / Triple-gate / Matching close
- OpenDDHedge / binding / generation logic
- Safe Cycle Reset (v6.27)
- Balance Guard trigger/close logic (แค่ย้ายตำแหน่ง dynamic update)
