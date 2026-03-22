

## เพิ่ม Hedge Cycle Dashboard แยกต่างหาก — Gold Miner SQ EA (v5.4 → v5.5)

### สิ่งที่ต้องการ

สร้าง **Dashboard ที่ 2** แยกจาก Dashboard หลัก เฉพาะสำหรับแสดงสถานะ Hedge ของทุก Group (A-D) ในรูปแบบตาราง 4 คอลัมน์

### ออกแบบ Layout

```text
┌──────────────────────────────────────────────────────────────────┐
│                    HEDGE CYCLE MONITOR                           │
├───────────────┬───────────────┬───────────────┬─────────────────┤
│   Group A     │   Group B     │   Group C     │   Group D       │
├───────────────┼───────────────┼───────────────┼─────────────────┤
│ H1: SELL 0.5L │ H1: STANDBY   │    OFF        │    OFF          │
│ H2: BUY  0.3L │               │               │                 │
│ H3: ---       │               │               │                 │
│ H4: ---       │               │               │                 │
└───────────────┴───────────────┴───────────────┴─────────────────┘
```

### สถานะแต่ละ Group

| สถานะ | ความหมาย | สี |
|---|---|---|
| **OFF** | Group ยังไม่เริ่ม (Group ก่อนหน้ายังไม่มี Hedge) | สีเทาเข้ม |
| **STANDBY** | Group พร้อมทำงาน (Group ก่อนหน้ามี Hedge แล้ว) | สีเหลือง |
| **H1-H4 detail** | แสดง Side + Lots + PnL | สีเขียว/แดงตามกำไร |
| **---** | Hedge slot ว่าง (ยังไม่เกิด) | สีเทา |

### เงื่อนไข Flow

- **Group A**: เริ่ม STANDBY เสมอ (พร้อมทำงานตั้งแต่ EA เริ่ม)
- **Group B**: OFF → เปลี่ยนเป็น STANDBY เมื่อ Group A มี Hedge #1 active
- **Group C**: OFF → STANDBY เมื่อ Group B มี Hedge #1
- **Group D**: OFF → STANDBY เมื่อ Group C มี Hedge #1
- **H2, H3, H4** ในแต่ละ Group: แสดง "---" จนกว่ากราฟจะกลับทิศฉับพลันแล้วเปิด hedge ถัดไปได้

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. เพิ่ม Input Parameters

```cpp
input int  HedgeDashX = 10;    // Hedge Dashboard X Position
input int  HedgeDashY = 500;   // Hedge Dashboard Y Position
```

#### 2. เพิ่มฟังก์ชัน `DisplayHedgeCycleDashboard()`

ฟังก์ชันใหม่ที่สร้าง dashboard แยก วาดเป็นตาราง 4 คอลัมน์:
- Header: "HEDGE CYCLE MONITOR" พื้นหลังม่วงเข้ม
- Column headers: Group A, B, C, D แต่ละอันมีสีแยกกัน (A=น้ำเงิน, B=เขียว, C=ส้ม, D=แดง)
- แต่ละ column แสดง 4 rows (H1-H4)
- ใช้ `CreateDashRect()` + `CreateDashText()` ที่มีอยู่แล้ว
- Object names ใช้ prefix `GM_HC_` เพื่อไม่ชนกับ dashboard หลัก

#### 3. Logic กำหนดสถานะแต่ละ Group

```text
สำหรับแต่ละ Group (g = 0..3):
  - ถ้า g == 0 (Group A): สถานะ = STANDBY เสมอ (พร้อมทำงาน)
  - ถ้า g > 0: ดูว่า Group ก่อนหน้า (g-1) มี hedge active ไหม
    → ถ้ามี: สถานะ = STANDBY
    → ถ้าไม่มี: สถานะ = OFF

สำหรับ Hedge H1-H4 ในแต่ละ Group:
  - สแกน g_hedgeSets[] หา set ที่ตรงกับ group นี้ (cycle index ตอนที่สร้าง)
  - ถ้ามี active set: แสดง "BUY/SELL 0.50L PnL:$123"
  - ถ้าไม่มี: แสดง "---"
```

#### 4. เพิ่ม field ใน HedgeSet struct

```cpp
int cycleIndex;  // cycle index (0=A, 1=B...) ตอนที่สร้าง set นี้
int hedgeNumber; // hedge number ภายใน cycle (1=H1, 2=H2...)
```

เมื่อเปิด hedge ใน `CheckAndOpenHedge()`:
- `g_hedgeSets[slot].cycleIndex = g_currentCycleIndex;`
- `g_hedgeSets[slot].hedgeNumber = count hedge ที่มี cycleIndex เดียวกัน + 1;`

#### 5. เรียก `DisplayHedgeCycleDashboard()` ใน OnTick

เพิ่มการเรียกหลัง `DisplayDashboard()` เฉพาะเมื่อ `InpHedge_Enable`

#### 6. Cleanup ใน OnDeinit

ลบ objects prefix `GM_HC_` ทั้งหมด

#### 7. Stale cleanup แบบเดียวกับ dashboard หลัก

ใช้ `g_lastHedgeDashRowCount` เก็บ row count เดิมเพื่อลบ objects ที่เกินออก

### Version bump: v5.4 → v5.5

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Net Lot Calculation, Hedge Guards, Cross-Set Matching
- Hedge Partial/Matching Close, Grid Mode logic
- Normal Matching Close logic
- Dashboard หลัก (ยังคงแสดงเหมือนเดิม)

