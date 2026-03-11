

## แก้ไข Cycle ไม่ Reset หลัง TP/SL Hit — Jutlameasu EA

### สาเหตุ

เมื่อ Position ปิดด้วย TP หรือ SL → `totalPositions = 0` แต่ Pending Order ฝั่งตรงข้ามยังคงอยู่ → `totalPending = 1`

STATE 3 (line 734) ต้องการ:
```
totalPositions == 0 && totalPending == 0
```
→ ไม่เป็นจริงเพราะ pending ยังเหลือ → **cycle ไม่ reset** → ไม่เริ่ม cycle ใหม่

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Jutlameasu_EA.mq5`

**เพิ่ม STATE ใหม่ระหว่าง STATE 2 กับ STATE 3 (หลัง line 727):**

เมื่อไม่มี Position แต่ยังมี Pending อยู่ และ cycle กำลังทำงาน → แสดงว่า Position ถูกปิดด้วย TP/SL แล้ว → ลบ Pending ที่เหลือ → ให้ STATE 3 จัดการ reset ใน tick ถัดไป

```cpp
// STATE 2.5: Position closed (TP/SL hit) but opposite pending still exists
// → Delete remaining pending orders to allow cycle reset
if(totalPositions == 0 && totalPending > 0 && g_cycleActive)
{
    Print("Jutlameasu: All positions closed, cleaning remaining pending orders for cycle reset");
    DeleteAllPendingOrders();
    return; // Next tick → STATE 3 will detect cycle end and reset
}
```

### ผลลัพธ์ที่คาดหวัง
- เมื่อ TP/SL hit → Position ปิด → Pending ที่เหลือถูกลบ → Cycle reset → เริ่ม cycle ใหม่จากราคาปัจจุบัน
- Martingale level กลับเป็น 0, lot กลับเป็น InpInitialLot

### สิ่งที่ไม่เปลี่ยนแปลง
- STATE 1, STATE 2, STATE 3, STATE 4 logic เดิม
- StartNewCycle, PlaceNextPendingOrder, DeletePendingByType
- Cross-Over TP/SL calculation, DrawChartLines, Dashboard

