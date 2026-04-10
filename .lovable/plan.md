

## v6.41 — เพิ่ม Max Grid Average Trailing Stop

### หลักการ

ระบบ Trailing Stop ใหม่ที่ทำงาน **เฉพาะเมื่อ** ชุดออเดอร์ถึง Max Grid Loss เท่านั้น — เป็นระบบแยกจาก Average Trailing Stop ที่มีอยู่ (ซึ่งทำงานกับทุกชุดออเดอร์)

**Flow:**
1. ออเดอร์ BUY INIT + GL ครบ `GridLoss_MaxTrades` → ระบบ activate monitoring
2. ราคาวิ่งกลับถึงค่าเฉลี่ย + Activation points → เริ่ม trailing
3. ราคาวิ่งต่อ → trailing SL กันหน้าทุนลงไปเรื่อยๆ
4. ราคาย้อนกลับ hit trailing SL → ปิดชุดออเดอร์ generation นั้น
5. ระบบขยับไป monitor generation ถัดไป (GM→GM1→GM2) ที่ยังมีชุดที่ถึง max grid
6. เมื่อไม่มีออเดอร์เหลือ → reset ทั้งหมด

### ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Version bump → v6.41

#### 2. เพิ่ม input parameters (group ใหม่)

```cpp
input group "=== Max Grid Average Trailing Stop ==="
input bool   MaxGrid_TrailEnable     = false;  // Enable Max Grid Avg Trailing
input int    MaxGrid_TrailActivation = 100;    // Activation (points from average, 0=Off)
input int    MaxGrid_TrailStep       = 50;     // Trailing Step (points)
input int    MaxGrid_BreakevenBuffer = 10;     // Breakeven Buffer (points above/below avg)
```

#### 3. เพิ่ม global variables

```cpp
// Max Grid Trailing State — per side
double   g_maxGridTrailSL_Buy  = 0;
double   g_maxGridTrailSL_Sell = 0;
bool     g_maxGridTrailActive_Buy  = false;
bool     g_maxGridTrailActive_Sell = false;
int      g_maxGridMonitorGen = 0;  // generation ที่กำลัง monitor อยู่
```

#### 4. เพิ่ม helper functions

- **`CountGenGridLoss(int gen, ENUM_POSITION_TYPE side)`** — นับ GL orders ของ generation + side ที่ระบุ
- **`CalcGenAveragePrice(int gen, ENUM_POSITION_TYPE side)`** — คำนวณราคาเฉลี่ยเฉพาะ generation + side (INIT+GL, ไม่รวม hedge/bound)
- **`CloseGenSide(int gen, ENUM_POSITION_TYPE side)`** — ปิดออเดอร์ทั้งหมดของ generation + side
- **`ManageMaxGridTrailing()`** — function หลักที่ monitor และจัดการ trailing

#### 5. Logic หลักของ `ManageMaxGridTrailing()`

```text
1. หา generation ที่กำลัง monitor (g_maxGridMonitorGen)
2. สำหรับแต่ละ side (BUY/SELL):
   a. นับ GL orders ของ gen นี้ → ถ้าไม่ถึง GridLoss_MaxTrades → skip
   b. คำนวณ avg price ของ gen นี้
   c. ถ้า price ถึง avg + activation → activate trailing
   d. ถ้า trailing active → คำนวณ new SL, lock profit
   e. ถ้า price hit trailing SL → ปิดชุด gen นั้นทั้ง side
3. ถ้า gen ปัจจุบันไม่มีออเดอร์แล้ว → ขยับไป gen ถัดไป
4. ถ้า TotalOrderCount() == 0 → reset ทั้งหมด
```

#### 6. เรียกใช้ใน OnTick (ก่อน/หลัง existing trailing)

```cpp
if(MaxGrid_TrailEnable)
   ManageMaxGridTrailing();
```

#### 7. Dashboard แสดงสถานะ

- "MaxGrid Trail: ON/OFF"
- "Monitoring: GM/GM1/GM2"  
- "BUY/SELL MaxGrid Trail Active" + SL level

### ตัวอย่าง

- GM มี SELL INIT + 10 GL (max=10) → ราคาลงถึง avg + 100 pts → trailing activate → ราคาลงต่อ → SL กันหน้าทุนลงเรื่อยๆ → ราคากลับตัว hit SL → ปิดชุด GM SELL ทั้งหมด
- GM ถูก hedge → ระบบขยับไป monitor GM1 → GM1 ถึง max grid → activate trailing เหมือนกัน

### สิ่งที่ไม่เปลี่ยนแปลง

- Order Execution Logic — ไม่แก้
- Trading Strategy Logic — ไม่แก้ (เป็น trailing เสริมเฉพาะ max grid)
- Core Module Logic — ไม่แก้
- Existing Average Trailing Stop / Per-Order Trailing — ไม่แก้
- Grid distance / min gap / new candle / candle confirm — ไม่แก้
- DD trigger / Hedge / Balance Guard — ไม่แก้
- Gen Race fix (v6.37), Orphan fix (v6.38), Side Pause (v6.39), GL CandleConfirm (v6.40) — ไม่แก้

