

## Fix: Matching Close Logic — คำนวณแบบ "Budget" + ทำงานทุก Tick

### ปัญหาปัจจุบัน
1. **Logic ผิด**: Algorithm ไล่เพิ่ม profit ทีละตัว แล้วพยายาม match loss → ซับซ้อนเกินจำเป็นและมี bug (`else if(netIfAdd >= 0)` ทำให้ net ต่ำกว่า MinProfit)
2. **Timing**: รอปิดแท่งเทียนก่อนคำนวณ → ช้าเกินไป

### Logic ใหม่ตามที่ผู้ใช้อธิบาย

**ตัวอย่าง**: 10 orders, MinProfitOrders=3, MinProfit=$5, MaxLossOrders=10

```text
Step 1: นับ profit orders → #8(+2), #9(+10), #10(+30) = 3 ตัว ≥ 3 → ผ่าน
Step 2: รวมกำไร = 2+10+30 = $42
Step 3: คำนวณ budget = 42 - 5 = $37 (ยอดที่เอาไปหักล้าง loss ได้)
Step 4: ไล่ loss จากเก่าสุด:
   #1(-18): สะสม = 18 ≤ 37 → รวม ✓
   #2(-12): สะสม = 30 ≤ 37 → รวม ✓
   #3(-9):  สะสม = 39 > 37 → ข้าม ✗
   #4(-8):  สะสม = 38 > 37 → ข้าม ✗
   #5(-2):  สะสม = 32 ≤ 37 → รวม ✓
   #6(-1):  สะสม = 33 ≤ 37 → รวม ✓
   #7(-1):  สะสม = 34 ≤ 37 → รวม ✓
Step 5: ปิด = #1,#2,#5,#6,#7 (loss) + #8,#9,#10 (profit)
         Net = 42-34 = $8 ≥ $5 ✓
```

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. เปลี่ยน Timing (line 854-864)
ลบ new-bar check → เรียก `ManageMatchingClose()` ทุก tick เมื่อ `UseMatchingClose` เปิด

```cpp
//--- Every tick: Matching Close
if(UseMatchingClose)
   ManageMatchingClose();
```

#### 2. เขียน Case 2 ใหม่ (line 5630-5703)
แทนที่ logic เดิมทั้งหมดด้วย:

```cpp
// Step 1: รวมกำไรทุกตัว (ใช้ทั้งหมด ไม่ไล่ทีละตัว)
double totalProfit = 0;
for(int p = 0; p < profitCount; p++)
   totalProfit += profitValues[p];

// Step 2: คำนวณ budget
double budget = totalProfit - MatchingMinProfit;
if(budget <= 0) break; // กำไรไม่พอแม้แต่ MinProfit

// Step 3: ไล่ loss จากเก่าสุด สะสมจนกว่าจะเกิน budget
double cumLoss = 0;
int lossUsed = 0;
int closeLossIdx[];

for(int l = 0; l < lossCount && lossUsed < maxLoss; l++)
{
   double absLoss = MathAbs(lossValues[l]);
   if(cumLoss + absLoss <= budget)
   {
      ArrayResize(closeLossIdx, lossUsed + 1);
      closeLossIdx[lossUsed] = l;
      cumLoss += absLoss;
      lossUsed++;
   }
   // else: ตัวนี้หนักเกิน → ข้ามไปตัวถัดไปที่อาจเบากว่า
}

// Step 4: ปิดถ้ามี loss ที่ match ได้
if(lossUsed > 0)
{
   double finalNet = totalProfit - cumLoss;
   // ปิดทุก profit + loss ที่ match ได้
   for(int cp = 0; cp < profitCount; cp++)
      trade.PositionClose(profitTickets[cp]);
   for(int cl = 0; cl < lossUsed; cl++)
      trade.PositionClose(lossTickets[closeLossIdx[cl]]);
   
   matchFound = true;
   Sleep(100);
}
else break;
```

**จุดสำคัญ**: เมื่อ loss ตัวเก่าสุดหนักเกิน budget → **ข้ามไปตัวถัดไป** ที่อาจเบากว่า (ตามตัวอย่าง #3 ข้าม → #5 เข้า)

#### 3. Case 1 (Profit-only) — คงเดิม
ไม่มี loss → ปิด profit ทั้งหมดถ้ารวมกัน ≥ MinProfit

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic, Grid entry/exit, TP/SL/Trailing/Breakeven
- Accumulate/Basket close, Drawdown exit
- Entry conditions (SMA/ZigZag/Instant)
- License / News / Time Filter / Data Sync / Dashboard

