

## แก้ไข Pending Order ที่ 3 ไม่ถูกวางหลัง Order ที่ 2 ถูกกระตุ้น

### สาเหตุ (Root Cause)

จากภาพ: Buy 0.2 lot + Sell 0.1 lot เปิดอยู่ แต่ **Pending Orders = BS:0 SS:0** → ไม่มี order ที่ 3

**ปัญหาอยู่ที่ STATE 2 double-fire:** เมื่อทั้ง Buy และ Sell position มีอยู่พร้อมกัน ทั้งสอง block ทำงานใน tick เดียวกัน

**ตัวอย่างการทำงานผิด:**
1. Sell Stop ถูกกระตุ้น (order #1) → `g_lastActivatedSide = "SELL"`, level=1, วาง Buy Stop 0.2
2. Buy Stop 0.2 ถูกกระตุ้น (order #2) → ตอนนี้ `buyCount=1, sellCount=1`
3. **Buy check** (line 704): `buyCount>0 && lastActivated!="BUY"` → TRUE → `lastActivated="BUY"`, level=2, lot=0.4, วาง Sell Stop ✓
4. **Sell check** (line 717): `sellCount>0 && lastActivated!="SELL"` → TRUE เช่นกัน! (เพราะ lastActivated เพิ่งเปลี่ยนเป็น "BUY") → level=3, lot=0.8, **ลบ Sell Stop ที่เพิ่งวาง** แล้วพยายามวาง Buy Stop ซึ่งอาจล้มเหลว (ราคาไม่ถูกต้อง)

→ ผลลัพธ์: pending ที่เพิ่งวางถูกลบทิ้ง + level/lot กระโดดผิด

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Jutlameasu_EA.mq5`

**STATE 2 (line 700-727):** เพิ่ม `return` หลังจัดการ activation แต่ละฝั่ง เพื่อป้องกัน double-fire ใน tick เดียวกัน

```cpp
// STATE 2: Check if a pending order was activated
// Check if Buy Stop was triggered
if(buyCount > 0 && g_lastActivatedSide != "BUY")
{
   g_lastActivatedSide = "BUY";
   g_currentLevel++;
   g_currentLot = InpInitialLot * MathPow(InpLotMultiplier, g_currentLevel);
   Print("BUY STOP ACTIVATED → Level ", g_currentLevel, " Lot ", g_currentLot);

   if(sellStopCount > 0) DeletePendingByType(ORDER_TYPE_SELL_STOP);
   if(g_currentLevel < InpMaxLevel) PlaceNextPendingOrder("SELL");
   
   if(ShowDashboard) DisplayDashboard();
   return;  // ← ป้องกัน Sell check fire ใน tick เดียวกัน
}

// Check if Sell Stop was triggered
if(sellCount > 0 && g_lastActivatedSide != "SELL")
{
   g_lastActivatedSide = "SELL";
   g_currentLevel++;
   g_currentLot = InpInitialLot * MathPow(InpLotMultiplier, g_currentLevel);
   Print("SELL STOP ACTIVATED → Level ", g_currentLevel, " Lot ", g_currentLot);

   if(buyStopCount > 0) DeletePendingByType(ORDER_TYPE_BUY_STOP);
   if(g_currentLevel < InpMaxLevel) PlaceNextPendingOrder("BUY");
   
   if(ShowDashboard) DisplayDashboard();
   return;  // ← ป้องกัน double processing
}
```

### ผลลัพธ์ที่คาดหวัง

```text
Cycle Start: Buy Stop 0.1 + Sell Stop 0.1
  ↓ Sell triggered (order #1)
Level 1: Sell 0.1 open, Buy Stop 0.2 วาง
  ↓ Buy triggered (order #2)  
Level 2: Buy 0.2 + Sell 0.1 open, Sell Stop 0.4 วาง ← order #3
  ↓ Sell Stop triggered (order #3)
Level 3: Buy 0.2 + Sell 0.1 + Sell 0.4 open, Buy Stop 0.8 วาง ← order #4
  ... สลับไปมาจนกว่า TP/SL จะ hit
```

### สิ่งที่ไม่เปลี่ยนแปลง
- StartNewCycle, PlaceNextPendingOrder, DeletePendingByType
- STATE 1, STATE 2.5, STATE 3, STATE 4
- Cross-Over TP/SL calculation, DrawChartLines, Dashboard logic

