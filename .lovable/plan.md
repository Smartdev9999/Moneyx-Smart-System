

## Fix: Orphan Recovery Grid ไม่เช็ค OnlyNewCandle — Gold Miner SQ EA (v6.2 → v6.3)

### ปัญหา

`ManageOrphanGrid()` (line 6687) ไม่มีการเช็ค `GridLoss_OnlyNewCandle` → ออก grid ทุก tick ที่ราคาถึง → order ออกถี่เกินไปในแท่งเดียว

ในขณะที่ `CheckGridLoss()` ปกติ (line 2241) มีการเช็ค:
```cpp
if(GridLoss_OnlyNewCandle) {
   datetime barTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(barTime == lastGridLossCandleTime) return;
}
```

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. เพิ่ม Global Variable สำหรับ track orphan grid candle time

```cpp
datetime g_lastOrphanGridCandleTime = 0;  // Track candle time for orphan grid
```

#### 2. เพิ่ม OnlyNewCandle check ใน `ManageOrphanGrid()` (หลัง line 6703)

```cpp
// OnlyNewCandle check — same rule as normal grid
if(GridLoss_OnlyNewCandle)
{
   datetime barTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(barTime == g_lastOrphanGridCandleTime) return;
}
```

#### 3. Update `g_lastOrphanGridCandleTime` เมื่อเปิด order สำเร็จ

ทั้ง BUY side (line 6770) และ SELL side (~line 6810) หลัง `OpenOrder()` สำเร็จ:
```cpp
if(OpenOrder(...))
{
   g_lastOrphanGridCandleTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   Print("ORPHAN GRID: Opened ...");
}
```

#### 4. Version bump: v6.2 → v6.3

### ผลลัพธ์
- `GridLoss_OnlyNewCandle = true` → Orphan grid ออกได้สูงสุด 1 order ต่อแท่งเทียน (เหมือน grid ปกติ)
- `GridLoss_OnlyNewCandle = false` → ทำงานเหมือนเดิม (ออกทุก tick ที่ถึงระยะ)

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge system logic ทั้งหมด
- Orphan scan/recovery logic อื่นๆ (ScanOrphanGenerations, CountOrphanPositions)

