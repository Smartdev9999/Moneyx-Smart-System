

## ปรับปรุง Matching Close Logic — รองรับ Profit-Only + เรียงลำดับ Loss จากไกลสุด

### ปัญหา 2 จุด

1. **บรรทัด 5357**: `if(profitCount == 0 || lossCount == 0) break;` — ถ้าไม่มี loss order เลย (มีแต่ profit) ระบบจะ break ทันที ไม่ปิดอะไรเลย แม้ profit รวมกันเกิน MinProfit
2. **Loss order เรียงจาก loss น้อยสุดก่อน** (บรรทัด 5368-5375) — user ต้องการเรียงจาก order ที่ห่างที่สุด (เก่าที่สุด/เปิดก่อน) มาก่อน เพื่อปิด order ที่ติดลบหนักสุดก่อน

### วิธีแก้ไข

**จุดที่ 1 — Profit-Only Matching**: หลังจากรวบรวม profit/loss orders แล้ว ถ้า `lossCount == 0` แต่ `profitCount > 0`:
- รวม profit ทุก order → ถ้ารวมกัน ≥ `MatchingMinProfit` → ปิดทั้งหมด
- หรือหา subset ที่เล็กที่สุดที่รวมกันถึง MinProfit → ปิดชุดนั้น

**จุดที่ 2 — เรียง Loss จากเก่าสุด (ห่างสุด)**: เปลี่ยน sort order ของ loss orders:
- เรียงตาม **open time** จากเก่าที่สุดก่อน (ascending) แทนที่จะเรียงตาม absolute loss น้อยสุด
- Order ที่เปิดก่อน = Grid level ไกลสุด = ติดลบหนักสุด → ปิดตัวนี้ก่อนเพื่อลด floating loss สูงสุด

**จุดที่ 3 — Multi-Profit Matching**: ปรับ logic ให้สะสม profit จากหลาย order ได้:
- แทนที่จะใช้ profit order เดียวจับคู่กับ loss 1-3 → สะสม profit จากหลาย order แล้วจับคู่กับ loss orders ตามลำดับเก่าสุดก่อน
- ตัวอย่าง: Order#10 (+$10) + Order#8 (+$9) = $19 → จับคู่กับ Order#1 (-$10) + Order#5 (-$8) = -$18 → Net $1 ≥ MinProfit → ปิด 4 orders

### Algorithm ใหม่

```text
1. รวบรวม profit orders (เรียงจากกำไรมากสุด)
2. รวบรวม loss orders (เรียงจาก open time เก่าสุดก่อน)
3. ถ้าไม่มี loss orders:
   - รวม profit ทุก order → ถ้า ≥ MinProfit → ปิดทั้งหมด
4. ถ้ามี loss orders:
   - สะสม profit จาก profit orders ทีละตัว (มากสุดก่อน)
   - สะสม loss จาก loss orders ทีละตัว (เก่าสุดก่อน, สูงสุด maxLoss ตัว)
   - หา combination ที่ net ≥ MinProfit แล้วปิดชุดนั้น
   - ลบ maxLoss limit สำหรับจำนวน profit orders (ใช้ได้หลายตัว)
```

### ไฟล์ที่แก้ไข
`public/docs/mql5/Gold_Miner_EA.mq5` — เขียน `ManageMatchingClose()` ใหม่ (~170 บรรทัด)

### สิ่งที่ไม่เปลี่ยนแปลง (กฎเหล็ก)
- Order Execution Logic — ไม่แตะ
- Grid Entry/Exit Logic — ไม่แตะ
- TP/SL/Trailing/Breakeven — ไม่แตะ
- SMA Signal / ZigZag MTF — ไม่แตะ
- License / News / Time Filter — ไม่แตะ
- Accumulate Close Logic — ไม่แตะ
- Input parameters เดิม (`UseMatchingClose`, `MatchingMinProfit`, `MatchingMaxLossOrders`) — ยังใช้เหมือนเดิม แต่ `MatchingMaxLossOrders` จะหมายถึง max loss orders ต่อ 1 รอบ matching

