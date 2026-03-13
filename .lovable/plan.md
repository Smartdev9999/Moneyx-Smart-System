

## Fix: Lot Calculation ใน STATE 2 ต้องใช้แค่ Lot ของออเดอร์ที่เพิ่ง Activate

### ปัญหา
ตอนนี้ `ModifyOppositePendingAfterGP()` ใช้ `CalculateTotalLots()` (รวมทุกตัว) ซึ่งถูกต้องสำหรับ GP เพราะเป็นการเพิ่มออเดอร์ใหม่ในฝั่งเดิม

แต่เมื่อ **Stop ถูก activate** (STATE 2) ออเดอร์เก่าของฝั่งที่ activate เคยถูก "หักล้าง" โดย pending ตัวก่อนแล้ว → ไม่ควรนำมาคำนวณซ้ำ

**ตัวอย่าง:**
- Sell 0.5 + Sell 1.0 → ถูกหักล้างโดย Buy Stop L1 = 3 lot แล้ว
- Sell GP 18 lot เปิดใหม่ → Modify Buy Stop เป็น (0.5+1+18) × 2 = 39 ✓ (ถูกต้องตอน GP เปิด)
- Buy Stop 39 lot ถูก activate → ตอนนี้ต้องวาง Sell Stop ใหม่
- **ผิด**: totalBuyLots = (Buy เก่า + 39) × 2 → ซ้ำซ้อน
- **ถูก**: Sell Stop = 39 × 2 = 78 (ใช้แค่ lot ตัวที่เพิ่ง activate)

### หลักการ
> **Lot ของ pending ถัดไป = lot ของออเดอร์ตัวล่าสุดที่เพิ่ง activate × InpLotMultiplier**

เหตุผล: pending ตัวก่อนหน้าถูกคำนวณให้ครอบคลุมออเดอร์เก่าทั้งหมดแล้ว → เมื่อมันถูก activate ก็แค่ต่อ martingale จาก lot ของมันเอง

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Jutlameasu_EA.mq5`

#### 1. เพิ่ม Helper: `FindLastActivatedLot(side)`
หา lot ของ position ล่าสุดที่เพิ่งเปิด (open time ใหม่สุด) บนฝั่งที่ระบุ

#### 2. แก้ STATE 2 (line 984-1016)
เมื่อ GP เปิดอยู่ → ใช้ lot ของออเดอร์ที่เพิ่ง activate (ตัวล่าสุด) × multiplier แทน level-based:

```cpp
// Buy Stop Activated
if(InpGP_Enable) {
   double lastLot = FindLastActivatedLot(POSITION_TYPE_BUY);
   g_currentLot = NormalizeLot(lastLot * InpLotMultiplier);
} else {
   g_currentLot = InpInitialLot * MathPow(InpLotMultiplier, g_currentLevel);
}
```

เหมือนกันสำหรับ Sell Stop Activated

#### 3. `ModifyOppositePendingAfterGP()` — คงเดิม
สูตร `totalLots × multiplier` ยังถูกต้องสำหรับ GP เพราะเป็นการเพิ่มออเดอร์ใหม่ในฝั่งเดิมที่ pending ยังไม่เคยหักล้าง

### ผลลัพธ์จากตัวอย่าง
- Sell 18 lot activate → Buy Stop = (0.5+1+18) × 2 = 39 ✓ (จาก GP modify)
- Buy Stop 39 lot activate → Sell Stop = 39 × 2 = 78 ✓ (จาก last activated lot)

### สิ่งที่ไม่เปลี่ยนแปลง
- GP logic (CheckGridProfit, ModifyOppositePendingAfterGP)
- Order Execution, Strategy, TP/SL, Accumulate, Drawdown
- License / News / Time Filter / Data Sync / Dashboard

