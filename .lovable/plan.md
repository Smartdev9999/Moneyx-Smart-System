

## เพิ่มระบบ Orphan Recovery Grid — Gold Miner SQ EA (v6.1 → v6.2)

### สิ่งที่แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. เพิ่ม Input Parameters
- `InpOrphan_Enable` (default: true) — เปิด/ปิดระบบ Orphan Recovery
- `InpOrphan_ScanIntervalMin` (default: 15) — ความถี่ในการสแกน (นาที)

#### 2. เพิ่ม OrphanGenGroup struct + global variables
- `g_orphanGroups[5]` — ติดตาม orphan generation สูงสุด 5 กลุ่ม
- `g_activeOrphanGroupCount` — จำนวน orphan groups ที่ active
- `g_lastOrphanScanTime` — timestamp ของการสแกนครั้งล่าสุด

#### 3. เพิ่ม Helper Functions
- `GenPrefix(int gen)` — สร้าง prefix ตาม generation (0→"GM", 1→"GM1")
- `CountOrphanPositions()` — นับ orders เฉพาะ generation ที่กำหนด
- `FindLastOrphanOrder()` — หา order ล่าสุดของ orphan gen
- `FindMaxLotOrphan()` — หา max lot ของ orphan gen

#### 4. เพิ่ม Core Functions
- `ScanOrphanGenerations()` — สแกนทุก 15 นาทีหา orders จาก gen เก่าที่ไม่ bound
- `ManageOrphanGrid()` — ออก grid loss orders ให้ orphan groups (ใช้ comment ของ gen เก่า)

#### 5. เรียกใน OnTick หลัง ManageHedgeSets
- Scan ทุก 15 นาที + Manage ทุก tick

#### 6. Dashboard แสดง Orphan Recovery Status
- แสดง active orphan groups พร้อมจำนวน orders + grid level

#### 7. Version bump: v6.1 → v6.2

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge system logic ทั้งหมด (Matching/Partial/AvgTP/Grid)
- Comment Generation logic สำหรับ cycle ปัจจุบัน
- Squeeze filter logic
