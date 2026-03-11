

## แก้ไข Pending Orders ขยับตามราคาตลอดเวลา - Jutlameasu EA

### สาเหตุ
**Line 720:** `if(totalPositions == 0 && g_cycleActive)` — เงื่อนไขนี้ตรวจแค่ว่าไม่มี Position แต่ **ไม่ได้เช็คว่ายังมี Pending Orders อยู่หรือไม่**

ผลคือทุก Tick ที่ยังไม่มี Position ถูกเปิด (Pending ยังไม่โดนกระตุ้น):
1. STATE 3 ถูกเรียก → `DeleteAllPendingOrders()` ลบ Pending เดิม
2. `StartNewCycle()` ถูกเรียก → คำนวณ `g_midPrice` ใหม่จากราคาปัจจุบัน → วาง Pending ใหม่
3. Tick ถัดไปก็ทำซ้ำอีก → Pending ขยับตามราคาตลอด

### การแก้ไข
**ไฟล์:** `public/docs/mql5/Jutlameasu_EA.mq5`

**Line 720:** เพิ่มเงื่อนไข `totalPending == 0` เพื่อให้ STATE 3 ทำงานเฉพาะเมื่อทั้ง Position และ Pending Orders หมดแล้วจริงๆ (หมายความว่า cycle จบแล้ว):

```cpp
// STATE 3: Check if cycle ended (all positions AND pending orders gone)
if(totalPositions == 0 && totalPending == 0 && g_cycleActive)
```

**เพิ่ม STATE เสริม:** กรณีมี Pending แต่ไม่มี Position (รอ Pending ถูกกระตุ้น) → ไม่ทำอะไร ปล่อยให้ Pending คงที่

### สิ่งที่ไม่เปลี่ยนแปลง
- StartNewCycle logic, PlaceNextPendingOrder, Cross-Over TP/SL calculation
- License / News / Time Filter
- Dashboard, DrawChartLines
- Martingale lot calculation
- CheckDrawdownExit, RecoverState

