

## แก้ไข Martingale Lot ไม่เพิ่มขึ้นเมื่อ Pending ฝั่งตรงข้ามถูกกระตุ้น

### สาเหตุ
เมื่อเริ่ม cycle → วาง Buy Stop 0.1 **และ** Sell Stop 0.1 พร้อมกัน (level 0)

เมื่อ Sell Stop ถูกกระตุ้น (line 706-717):
```cpp
if(buyStopCount == 0 && g_currentLevel < InpMaxLevel)
{
    g_currentLevel++;
    g_currentLot = InpInitialLot * MathPow(InpLotMultiplier, g_currentLevel);
    PlaceNextPendingOrder("BUY");
}
```

เงื่อนไข `buyStopCount == 0` เป็น **FALSE** เพราะ Buy Stop เดิม (0.1 lot) ยังอยู่ → ข้ามการเพิ่ม level/lot ทั้งหมด → Buy Stop ยังคงเป็น 0.1

### การแก้ไข
**ไฟล์:** `public/docs/mql5/Jutlameasu_EA.mq5`

**STATE 2 — Buy activated (line 686-702):**
เมื่อ Buy ถูกกระตุ้น → ถ้ามี Sell Stop เดิมอยู่ → **ลบทิ้ง** → เพิ่ม level/lot → วาง Sell Stop ใหม่ด้วย lot ที่เพิ่มแล้ว

```cpp
if(buyCount > 0 && g_lastActivatedSide != "BUY")
{
    g_lastActivatedSide = "BUY";
    g_currentLevel++;
    g_currentLot = InpInitialLot * MathPow(InpLotMultiplier, g_currentLevel);
    
    // ลบ Sell Stop เดิม (ถ้ามี) แล้ววางใหม่ด้วย lot ที่เพิ่ม
    if(sellStopCount > 0) DeletePendingByType(ORDER_TYPE_SELL_STOP);
    if(g_currentLevel < InpMaxLevel) PlaceNextPendingOrder("SELL");
}
```

**STATE 2 — Sell activated (line 706-717):**
เช่นเดียวกัน เมื่อ Sell ถูกกระตุ้น → ลบ Buy Stop เดิม → วางใหม่ด้วย lot x2

```cpp
if(sellCount > 0 && g_lastActivatedSide != "SELL")
{
    g_lastActivatedSide = "SELL";
    g_currentLevel++;
    g_currentLot = InpInitialLot * MathPow(InpLotMultiplier, g_currentLevel);
    
    if(buyStopCount > 0) DeletePendingByType(ORDER_TYPE_BUY_STOP);
    if(g_currentLevel < InpMaxLevel) PlaceNextPendingOrder("BUY");
}
```

**เพิ่ม function ใหม่: `DeletePendingByType()`** — ลบ pending orders ตาม type ที่ระบุ (เฉพาะ Magic Number ของ EA)

### ข้อสังเกต
- `g_currentLevel` เริ่มจาก 0 ตอน cycle start → ครั้งแรกที่ pending ถูกกระตุ้นจะเป็น level 1 → lot = `0.1 * 2^1 = 0.2` ✓
- ระดับราคา (entry, TP, SL) ยังคงที่ตาม `g_midPrice` เดิม — ไม่เปลี่ยน

### สิ่งที่ไม่เปลี่ยนแปลง
- StartNewCycle, DrawChartLines, Dashboard
- Cross-Over TP/SL calculation
- STATE 1, STATE 3, STATE 4
- License / News / Time Filter

