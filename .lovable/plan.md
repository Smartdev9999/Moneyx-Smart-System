

## แก้ไข Pending Orders ถูก Cancel และสร้างใหม่ซ้ำตลอดเวลา - Jutlameasu EA

### สาเหตุ
**STATE 1 (line 675)** ไม่ได้เช็ค `g_cycleActive`:
```cpp
if(totalPositions == 0 && totalPending == 0 && !g_newOrderBlocked)
```

ทำให้เมื่อ pending orders หายไป (เช่น ถูก trigger แล้วปิดในแท่งเดียวกันใน backtest, หรือ broker reject) → STATE 1 เรียก `StartNewCycle()` ซ้ำ คำนวณ `g_midPrice` ใหม่จากราคาปัจจุบัน → ออเดอร์ขยับ

นอกจากนี้ **STATE 3 (line 720)** ใช้แค่ `CountMyPendingOrders` เพื่อตรวจสอบว่า pending หมดหรือยัง ซึ่งอาจมี timing issue ใน backtester — ควรตรวจสอบซ้ำด้วย stored ticket numbers (`g_buyStopTicket`, `g_sellStopTicket`)

### การแก้ไข
**ไฟล์:** `public/docs/mql5/Jutlameasu_EA.mq5`

**1. STATE 1 (line 675):** เพิ่มเงื่อนไข `!g_cycleActive` เพื่อป้องกัน cycle ซ้ำซ้อน:
```cpp
if(totalPositions == 0 && totalPending == 0 && !g_cycleActive && !g_newOrderBlocked)
```
→ ถ้า cycle เริ่มแล้ว (`g_cycleActive = true`) จะไม่เริ่มใหม่ ต้องรอ STATE 3 จัดการก่อน

**2. STATE 3 (line 720):** เพิ่ม ticket verification เพื่อ double-check ว่า pending orders หมดจริงๆ:
```cpp
bool buyStopExists = (g_buyStopTicket > 0 && OrderSelect(g_buyStopTicket));
bool sellStopExists = (g_sellStopTicket > 0 && OrderSelect(g_sellStopTicket));

if(totalPositions == 0 && totalPending == 0 && !buyStopExists && !sellStopExists && g_cycleActive)
```

**3. STATE 3 (line 727):** ลบ `DeleteAllPendingOrders()` ที่ซ้ำซ้อน — เพราะ totalPending == 0 อยู่แล้ว เปลี่ยนเป็น clear stored tickets แทน:
```cpp
g_buyStopTicket = 0;
g_sellStopTicket = 0;
```

**4. `DeleteAllPendingOrders()` function:** เพิ่ม reset stored tickets หลัง delete:
```cpp
g_buyStopTicket = 0;
g_sellStopTicket = 0;
```

### ผลลัพธ์ที่คาดหวัง
- Pending orders จะคงที่ ไม่ขยับ ไม่ถูก cancel/recreate จนกว่าจะถูก trigger โดยราคา
- Cycle จะจบเฉพาะเมื่อ TP/SL hit จริงๆ (ไม่มี false cycle end)
- ราคา Mid, Buy Entry, Sell Entry คงที่ตลอด cycle

### สิ่งที่ไม่เปลี่ยนแปลง
- Cross-Over TP/SL calculation logic
- Martingale lot doubling
- PlaceNextPendingOrder (วาง pending ฝั่งตรงข้ามหลัง activation)
- License / News / Time Filter / Dashboard / DrawChartLines

