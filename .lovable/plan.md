## Implemented: v6.34 — แก้ Max DD ให้แสดงเป็น % เสมอทุกโหมด

### ปัญหา
โหมด Dollar แปลง `g_maxDD` (%) กลับเป็น $ ด้วย `g_maxDD / 100.0 * balance` → ค่าผิดเพราะ balance เปลี่ยนตลอด

### แก้ไข (v6.34)
1. **Version bump**: v6.33 → v6.34
2. **Dashboard line 3151-3152**: เปลี่ยนจากแสดง `$` เป็นแสดง `%` เหมือนโหมด Percent — ทุกโหมดแสดง Max DD% เป็น % เหมือนกัน

### สิ่งที่ไม่เปลี่ยนแปลง
- `g_maxDD` tracking logic — ยังคำนวณ % เหมือนเดิม
- Order Execution Logic, Trading Strategy Logic, Core Module Logic
- DD trigger / Triple-gate / Matching close
- OpenDDHedge / binding / generation logic
- Balance Guard (v6.33)
- Daily Target Profit (v6.32)
