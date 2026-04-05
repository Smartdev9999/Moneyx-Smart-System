## Implemented: v6.36 — เพิ่ม Max Hedge Sets จาก 10 เป็น 50

### แก้ไข (v6.36)
1. **Version bump**: v6.35 → v6.36
2. **`#define MAX_HEDGE_SETS`**: 10 → 50
3. **Input comment**: `(1-10)` → `(1-50)` — default ยังเป็น 10

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic, Trading Strategy Logic, Core Module Logic
- DD trigger / Triple-gate / Matching close
- OpenDDHedge / binding / generation logic
- Balance Guard (v6.33/v6.35)
- Daily Target Profit (v6.32)
- Loop logic ทั้งหมดใช้ `MAX_HEDGE_SETS` อยู่แล้ว จึงรองรับอัตโนมัติ
