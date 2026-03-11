

## แก้ไข Pending Orders ถูก Cancel ทันทีหลังเริ่ม Cycle ใหม่

### สาเหตุ (Root Cause)

จาก Journal log ในภาพ:
1. `NEW CYCLE STARTED: Mid=3333.7 BuyEntry=3336.2 SellEntry=3331.2` — วาง Buy Stop + Sell Stop สำเร็จ
2. **ทันที** → `Jutlameasu: All positions closed (TP/SL hit), cleaning remaining pending orders for cycle reset` → ลบ pending ทั้งหมด!

**STATE 2.5 (line 731)** เป็นต้นเหตุ:
```cpp
if(totalPositions == 0 && totalPending > 0 && g_cycleActive)
```

เงื่อนไขนี้เป็น **TRUE ทันทีหลัง StartNewCycle()** เพราะ:
- `totalPositions = 0` ✓ (ยังไม่มี position ถูกกระตุ้น)
- `totalPending = 2` ✓ (เพิ่งวาง Buy Stop + Sell Stop)
- `g_cycleActive = true` ✓ (เพิ่ง set ใน StartNewCycle)

→ EA คิดว่า "position ปิดแล้ว แต่ pending ยังเหลือ" ทั้งที่จริงๆคือ **cycle เพิ่งเริ่ม ยังไม่มี position เลย**

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Jutlameasu_EA.mq5`

**STATE 2.5 (line 731):** เพิ่มเงื่อนไข `g_lastActivatedSide != ""` เพื่อให้ cleanup ทำงานเฉพาะเมื่อมี position ถูกกระตุ้นไปแล้วก่อนหน้า:

```cpp
// STATE 2.5: Position closed (TP/SL hit) but opposite pending still exists
// Only trigger if a side was previously activated (not at cycle start)
if(totalPositions == 0 && totalPending > 0 && g_cycleActive && g_lastActivatedSide != "")
{
   Print("Jutlameasu: All positions closed (TP/SL hit), cleaning remaining pending orders for cycle reset");
   DeleteAllPendingOrders();
   return;
}
```

เมื่อ cycle เพิ่งเริ่ม → `g_lastActivatedSide = ""` (reset ใน STATE 3 line 765) → STATE 2.5 จะ **ไม่ทำงาน** → pending orders คงอยู่รอ trigger ตามปกติ

เมื่อ position ถูกกระตุ้นแล้วปิดด้วย TP/SL → `g_lastActivatedSide = "BUY"` หรือ `"SELL"` → STATE 2.5 ทำงานลบ pending ที่เหลือ → cycle reset ได้ถูกต้อง

### ผลลัพธ์ที่คาดหวัง
- Pending orders จะไม่ถูกลบทันทีหลังเริ่ม cycle ใหม่
- Cycle reset ยังทำงานถูกต้องหลัง TP/SL hit (เพราะ g_lastActivatedSide มีค่าแล้ว)

### สิ่งที่ไม่เปลี่ยนแปลง
- StartNewCycle, PlaceNextPendingOrder, DeletePendingByType
- Cross-Over TP/SL calculation, DrawChartLines
- Martingale lot logic (STATE 2)
- STATE 1, STATE 3, STATE 4
- License / News / Time Filter / Dashboard

