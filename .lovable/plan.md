

## แก้ไข STATE 2 Detection Logic — Martingale Level กระโดดไม่หยุด

### สาเหตุที่แท้จริง (Root Cause)

จากภาพ: **Martingale Lv = 5502 / 10**, **Next Lot = 100.00** → Level กระโดดขึ้นทุก tick!

ปัญหาอยู่ที่ **เงื่อนไขตรวจจับ activation ใน STATE 2** ใช้ `g_lastActivatedSide` ซึ่งสลับไปมาทุก tick เมื่อทั้ง Buy และ Sell position เปิดอยู่พร้อมกัน:

```text
Tick N:   buyCount=1, sellCount=1, lastActivated="SELL"
  → Buy check: lastActivated!="BUY" → TRUE → level++, lastActivated="BUY", return
Tick N+1: buyCount=1, sellCount=1, lastActivated="BUY"  
  → Sell check: lastActivated!="SELL" → TRUE → level++, lastActivated="SELL", return
Tick N+2: ซ้ำเดิม → level กระโดดไม่หยุด (5502 ใน backtest)
```

`return` ป้องกัน double-fire ใน tick เดียวกันได้ แต่ **ไม่ป้องกัน tick ถัดไป** ที่เงื่อนไขฝั่งตรงข้ามยังคงเป็น TRUE

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Jutlameasu_EA.mq5`

**เปลี่ยนวิธี detect activation** จาก `g_lastActivatedSide` เป็น **นับจำนวน position ที่คาดหวัง** (`g_expectedBuyCount`, `g_expectedSellCount`)

1. **เพิ่ม global variables:**
```cpp
int g_expectedBuyCount = 0;
int g_expectedSellCount = 0;
```

2. **StartNewCycle:** reset เป็น 0 ทั้งคู่

3. **STATE 2 detection เปลี่ยนเป็น:**
```cpp
// ตรวจจับ activation ใหม่จริงๆ โดยเทียบกับจำนวนที่คาดหวัง
if(buyCount > g_expectedBuyCount)
{
   g_expectedBuyCount = buyCount;
   g_lastActivatedSide = "BUY";
   g_currentLevel++;
   g_currentLot = InpInitialLot * MathPow(InpLotMultiplier, g_currentLevel);
   
   if(sellStopCount > 0) DeletePendingByType(ORDER_TYPE_SELL_STOP);
   if(g_currentLevel < InpMaxLevel) PlaceNextPendingOrder("SELL");
   if(ShowDashboard) DisplayDashboard();
   return;
}

if(sellCount > g_expectedSellCount)
{
   g_expectedSellCount = sellCount;
   g_lastActivatedSide = "SELL";
   g_currentLevel++;
   g_currentLot = InpInitialLot * MathPow(InpLotMultiplier, g_currentLevel);
   
   if(buyStopCount > 0) DeletePendingByType(ORDER_TYPE_BUY_STOP);
   if(g_currentLevel < InpMaxLevel) PlaceNextPendingOrder("BUY");
   if(ShowDashboard) DisplayDashboard();
   return;
}
```

4. **STATE 3 (cycle reset):** reset `g_expectedBuyCount = 0; g_expectedSellCount = 0;`

5. **STATE 2.5, Drawdown exit, NEW CYCLE button:** reset ทั้งคู่เป็น 0 เช่นกัน

### ทำไมวิธีนี้ถูกต้อง

```text
Cycle Start: expectedBuy=0, expectedSell=0
  Sell Stop triggered → sellCount=1 > expectedSell(0) → TRUE → expectedSell=1, level=1
  Buy Stop triggered → buyCount=1 > expectedBuy(0) → TRUE → expectedBuy=1, level=2
  Tick ถัดไป → buyCount=1 == expectedBuy(1) → FALSE ✓
                sellCount=1 == expectedSell(1) → FALSE ✓ → ไม่ fire ซ้ำ!
  Sell Stop triggered → sellCount=2 > expectedSell(1) → TRUE → expectedSell=2, level=3
  ... ทำงานถูกต้องทุก level
```

### สิ่งที่ไม่เปลี่ยนแปลง
- StartNewCycle order placement logic, PlaceNextPendingOrder, DeletePendingByType
- Cross-Over TP/SL calculation, DrawChartLines
- STATE 1, STATE 2.5, STATE 3, STATE 4 flow
- License / News / Time Filter / Dashboard / OnChartEvent

