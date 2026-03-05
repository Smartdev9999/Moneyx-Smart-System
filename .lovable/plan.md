

## Gold Miner EA v3.0 - เพิ่ม Matching Close + แก้ Accumulate Close

### ฟีเจอร์ที่ 1: Matching Close (ปิดคู่ กำไร vs ขาดทุน)

**แนวคิด**: ทุกครั้งที่แท่งเทียนปิด (new bar) ระบบจะสแกน order ทั้งหมดแต่ละฝั่ง (Buy/Sell แยกกัน) แล้วหา "ชุดที่ดีที่สุด" ที่ปิดแล้วได้กำไรสุทธิ ≥ 0

**Logic**:
1. รวบรวม order ที่กำไร (profit > 0) และ order ที่ขาดทุน (profit < 0) แยกกัน
2. สำหรับแต่ละ order ที่กำไรมากที่สุด → หา combination ของ order ขาดทุน (1-3 ตัว) ที่รวมกันแล้ว net profit ≥ `MatchingMinProfit` (default $0.5)
3. ปิดทั้งชุด (1 profit + N loss orders)
4. ทำซ้ำจนไม่มีคู่ที่ match ได้อีก
5. ระบบจะยังสะสม accumulate ตามปกติ (matching close profit จะเข้า history)

**เพิ่ม Input Parameters**:
```text
input group "=== Matching Close ==="
input bool     UseMatchingClose     = false;    // Enable Matching Close
input double   MatchingMinProfit    = 0.50;     // Min Net Profit per Match ($)
input int      MatchingMaxLossOrders = 3;       // Max Loss Orders per Match (1-3)
```

**เพิ่ม Function**:
- `ManageMatchingClose()` — เรียกเมื่อ new bar เท่านั้น (ไม่ใช่ทุก tick เพื่อประสิทธิภาพ)
- Buy side และ Sell side ทำแยกกัน
- ใช้ `trade.PositionClose()` ปิดทีละ ticket

**เรียกใน OnTick**: หลัง ManageTPSL / ManagePerOrderTrailing แต่ก่อน Accumulate Close

---

### ฟีเจอร์ที่ 2: แก้ Accumulate Close — ลบ guard `g_accumulatedProfit > 0`

**ปัญหา**: บรรทัด 1347 และ 3385 มี guard `g_accumulatedProfit > 0` ทำให้ถ้ายังไม่มี closed profit เลย (floating อย่างเดียว) ระบบจะไม่ trigger

**แก้ไข**: ลบ condition `g_accumulatedProfit > 0` ออก ให้เหลือแค่:
```text
if(accumTotal >= AccumulateTarget && accumTotal > 0)
```
แก้ทั้ง 2 จุด: `ManageTPSL()` (SMA mode) และ `ManageAccumulateShared()` (ZigZag mode)

---

### ไฟล์ที่แก้ไข
`public/docs/mql5/Gold_Miner_EA.mq5` (ไฟล์เดียว)

### สิ่งที่ไม่เปลี่ยนแปลง (กฎเหล็ก)
- Order Execution Logic — ไม่แตะ (ใช้ `trade.PositionClose()` ที่มีอยู่แล้ว)
- Grid Entry/Exit Logic — ไม่แตะ
- TP/SL/Trailing/Breakeven calculations — ไม่แตะ
- SMA Signal / ZigZag MTF Signal — ไม่แตะ
- License / News / Time Filter — ไม่แตะ
- Drawdown Exit — ไม่แตะ

