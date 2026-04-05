## Implemented: v6.35 — เพิ่ม Profit for Balance Guard

### หลักการ
เพิ่ม `InpBalanceGuard_Profit` เพื่อกำหนดกำไรขั้นต่ำ ($) ที่ต้องบวกเข้ากับ target ของ Balance Guard
เช่น Balance ตอน flat = $102,000, Profit = $2,000 → ระบบปิดเมื่อ Equity >= $104,000

### แก้ไข (v6.35)
1. **Version bump**: v6.34 → v6.35
2. **Input parameter ใหม่**: `InpBalanceGuard_Profit` (default 0.0) — อยู่หลัง `InpBalanceGuard_Target`
3. **CheckBalanceGuard()**: `effectiveTarget += InpBalanceGuard_Profit`
4. **Dashboard**: `bgTarget` รวม profit แล้วแสดงยอดรวม

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic, Trading Strategy Logic, Core Module Logic
- DD trigger / Triple-gate / Matching close
- OpenDDHedge / binding / generation logic
- Balance Guard dynamic update logic (v6.33)
- Daily Target Profit (v6.32)
- Max DD% display fix (v6.34)
