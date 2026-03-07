

## เพิ่ม Input: Minimum Profit Orders สำหรับ Matching Close

### สิ่งที่เพิ่ม

**Input parameter ใหม่ 1 ตัว**:
```text
input int MatchingMinProfitOrders = 1; // Min Profit Orders to Start Matching
```
ค่า default = 1 (ทำงานเหมือนเดิม), ถ้าตั้ง 2 = ต้องรอให้มี profit orders อย่างน้อย 2 ตัวก่อนจึงจะเริ่มคำนวณ matching

### Logic ที่แก้ไข (ManageMatchingClose)

**จุดที่ 1** — บรรทัด 5360: เปลี่ยน guard จาก `profitCount == 0` เป็น `profitCount < MatchingMinProfitOrders`
```text
// ก่อน
if(profitCount == 0) break;
// หลัง
int minPO = MathMax(MatchingMinProfitOrders, 1);
if(profitCount < minPO) break;
```

**จุดที่ 2** — Profit-Only case (บรรทัด 5384): เพิ่ม guard เดียวกัน — ต้องมี profit orders ≥ minPO ก่อนจะรวมปิด

**จุดที่ 3** — Multi-profit+loss case (บรรทัด 5415): loop เริ่มสะสม profit ตั้งแต่ตัวแรก แต่จะเริ่มพยายาม match กับ loss orders ก็ต่อเมื่อ `usedProfitCount >= minPO` เท่านั้น

### ไฟล์ที่แก้ไข
`public/docs/mql5/Gold_Miner_EA.mq5` — 4 จุด (1 input + 3 logic guards)

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution / Grid / TP/SL/Trailing — ไม่แตะ
- Accumulate Close — ไม่แตะ
- Loss order sorting (oldest first) — ไม่แตะ
- Profit order sorting (highest first) — ไม่แตะ
- Matching Close algorithm core — ไม่แตะ (เพิ่มแค่ minimum count guard)

