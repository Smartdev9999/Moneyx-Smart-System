

## เพิ่มระบบ Scan & Recovery Orphan Orders จาก Generation เก่า — Gold Miner SQ EA (v6.1 → v6.2)

### ปัญหา

จากรูป: มี sell orders (GM_GP#2, GM_GL#1, GM_GL#3, GM_GL#6, GM_GL#7) จาก generation 0 ค้างอยู่ด้านล่าง เพราะถูกปิดบางส่วนพร้อม hedge → ส่วนที่เหลือกลายเป็น orphan ไม่มีระบบใดดูแล

ปัจจุบัน `CountPositions()` skip bound orders + hedge orders → orders เหล่านี้ไม่ถูก bound (เพราะ hedge set ถูก deactivate ไปแล้ว) แต่ก็ไม่ถูกนับรวมกับ cycle ปัจจุบัน (เพราะ comment เป็น gen เก่า เช่น `GM_GL` ในขณะที่ cycle ปัจจุบันคือ `GM1_GL`) → ไม่มี grid ต่อ → orders ค้างตลอดไป

### แนวคิด: Orphan Generation Recovery System

สแกนทุก 15 นาทีหา orders จาก generation เก่าที่ไม่มี hedge set ดูแล → เปิด grid ต่อจาก orders เหล่านั้นเพื่อแก้ไข (เหมือน grid ปกติแต่ใช้ comment ของ gen เก่า)

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. เพิ่ม Input Parameter
```cpp
input bool     InpOrphan_Enable             = true;    // Enable Orphan Recovery Grid
input int      InpOrphan_ScanIntervalMin    = 15;      // Scan Interval (Minutes)
```

#### 2. เพิ่ม Global Variables
```cpp
datetime g_lastOrphanScanTime = 0;

// Orphan generation tracker — tracks up to 5 orphan gen groups
struct OrphanGenGroup {
   int    generation;       // e.g. 0 for "GM_GL"
   bool   active;
   int    buySideCount;     // จำนวน orphan buy orders ของ gen นี้
   int    sellSideCount;    // จำนวน orphan sell orders ของ gen นี้
};
#define MAX_ORPHAN_GROUPS 5
OrphanGenGroup g_orphanGroups[MAX_ORPHAN_GROUPS];
```

#### 3. เพิ่มฟังก์ชัน `ScanOrphanGenerations()`

ทุก 15 นาที:
1. สแกน positions ทั้งหมด → แยกตาม generation
2. สำหรับแต่ละ generation ที่ **ไม่ใช่** generation ปัจจุบัน (`g_cycleGeneration`) และ **ไม่ได้** bound กับ hedge set ใดๆ:
   - นับจำนวน buy/sell orders
   - ถ้ามี → mark เป็น active orphan group
3. Print สรุป

#### 4. เพิ่มฟังก์ชัน `ManageOrphanGrid()`

สำหรับแต่ละ active orphan group:
1. Guard: สถานะต้องเป็น Normal หรือ Squeeze (ไม่ใช่ Expansion)
2. Guard: `!g_newOrderBlocked` (News/Time filter)
3. หา last price ของ orphan orders ฝั่งนั้น (จาก comment ที่ match gen เก่า)
4. คำนวณ grid distance เหมือน `CheckGridLoss` ปกติ
5. ถ้าราคาห่างพอ → เปิด grid order ใหม่ **ใช้ comment ของ gen เก่า** (เช่น `GM_GL#8` ถ้า gen=0 และมี #7 อยู่แล้ว)
6. ระบบ TP/SL/Matching Close ปกติจะจัดการปิด orders ของ gen เก่าเหล่านี้ได้ เพราะ `CalculateAveragePrice`/`CalculateFloatingPL` ทำงานกับ orders ที่ไม่ bound

#### 5. เรียกใน OnTick — หลัง ManageHedgeSets

```text
// Orphan Recovery: scan every N minutes, manage grid every tick for active groups
if(InpOrphan_Enable)
{
   datetime now = TimeCurrent();
   if(now - g_lastOrphanScanTime >= InpOrphan_ScanIntervalMin * 60)
   {
      ScanOrphanGenerations();
      g_lastOrphanScanTime = now;
   }
   ManageOrphanGrid();
}
```

#### 6. Orphan Grid Comment Format

ใช้ comment ของ gen เก่า (ไม่ใช่ `GetCommentPrefix()` ปัจจุบัน):
```text
string GenPrefix(int gen) {
   if(gen == 0) return "GM";
   return "GM" + IntegerToString(gen);
}
// Grid order: GenPrefix(orphanGen) + "_GL#" + N
// เช่น gen=0: GM_GL#8, GM_GL#9...
```

#### 7. แยก CountPositions สำหรับ Orphan Group

เพิ่ม `CountOrphanPositions(int gen, ...)` ที่นับเฉพาะ orders ของ gen นั้น:
- นับ buy/sell count, grid loss count, max grid level
- ใช้สำหรับตัดสินใจเปิด grid ต่อ

#### 8. Dashboard: แสดง Orphan Recovery Status

เมื่อมี orphan group active → แสดงแถวใน Dashboard:
```text
ORPHAN GEN0: S:5 GL:2/10 | GEN1: - 
```

#### 9. Auto-cleanup: เมื่อ Orphan Orders ปิดหมด

เมื่อ `CountOrphanPositions` return 0 สำหรับ gen นั้น → deactivate group

#### 10. Version bump: v6.1 → v6.2

### Flow สรุป

```text
ทุก 15 นาที:
  ScanOrphanGenerations()
  → พบ GM_GL#6, GM_GL#7 (gen 0, sell) ← ไม่ bound, ไม่ใช่ gen ปัจจุบัน
  → g_orphanGroups[0] = {gen:0, active:true, sellCount:5}

ทุก tick (ถ้ามี active orphan group):
  ManageOrphanGrid()
  → สถานะ Normal/Squeeze → หา lastPrice จาก GM_GL orders
  → ราคาห่างพอ → เปิด GM_GL#8 (gen 0 prefix)
  → TP/SL/Matching Close ปกติจัดการปิดได้

เมื่อ orphan orders ปิดหมด:
  → deactivate group → Dashboard ซ่อน
```

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge system logic ทั้งหมด (Matching/Partial/AvgTP/Grid)
- Comment Generation logic สำหรับ cycle ปัจจุบัน
- Squeeze filter logic

