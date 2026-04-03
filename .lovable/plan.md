## Implemented: v6.31 — แก้ Dynamic Balance Guard ให้อัปเดต target ทันทีเมื่อ flat

### สาเหตุ
v6.30 อัปเดต dynamic target เฉพาะใน `CheckBalanceGuard()` (1 ครั้ง/tick) → ถ้า order ปิดแล้วเปิดใหม่ภายใน tick เดียวกัน ระบบไม่เห็น flat state → target ไม่อัปเดต

### แก้ไข
1. **Version bump**: v6.30 → v6.31
2. **สร้าง helper `UpdateDynamicBalanceGuardTarget()`** — ฟังก์ชันกลางสำหรับอัปเดต target จาก ACCOUNT_BALANCE
3. **เรียก helper ทุกจุดที่ตรวจพบ flat**:
   - `TryResetCycleStateIfFlat()` — Truly flat block
   - Standalone clear (all positions cleared)
   - Accumulate reset
   - ZZ accumulate reset
4. **คง fallback ใน `CheckBalanceGuard()`** — เรียก helper เดียวกัน

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic
- Trading Strategy Logic
- Core Module Logic
- DD trigger / Triple-gate / Matching close
- OpenDDHedge / binding / generation logic
- Safe Cycle Reset (v6.27) — เพิ่มเรียก helper เท่านั้น
- Balance Guard trigger/close logic — ไม่แก้
