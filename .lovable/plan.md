

## เพิ่มระบบ Rebate + Dashboard ปรับขนาดได้ ใน Gold Miner EA

### สิ่งที่ต้องเพิ่ม

**1. Input Parameters ใหม่:**
```text
=== Rebate Settings ===
input double   InpRebatePerLot = 4.5;   // Rebate per Lot ($)

=== Dashboard ===
input double   DashboardScale = 1.0;    // Dashboard Scale (0.8-1.5)
```

**2. Helper Functions ใหม่:**
- `CalcDailyClosedLots()` — คำนวณ lot ที่ปิดไปวันนี้ (filter by today's date)
- ใช้ Logic เหมือน `CalcTotalClosedLots()` แต่ใส่ date filter เหมือน `CalcDailyPL()`

**3. Dashboard แถวใหม่ (History Section):**
| แถว | ค่าที่แสดง |
|-----|----------|
| Daily Closed Lot | `CalcDailyClosedLots()` L |
| Daily Rebate | Daily Lot × InpRebatePerLot |
| Total Rebate | Total Closed Lot × InpRebatePerLot |

**4. Dashboard Scale (ปรับขนาด):**
- เพิ่ม `DashboardScale` input (default 1.0)
- คูณ scale เข้ากับ: `tableWidth`, `headerHeight`, font size, row height, button size
- ใช้ `int(value * DashboardScale)` ทุกจุดที่เกี่ยวกับ dimension

### Layout Dashboard หลังแก้ไข
```text
┌──────────────────────────────────────┐
│ Gold Miner EA v3.0 [SMA]  Mode: Both │
├──────────────────────────────────────┤
│ Balance          $102,798.57         │
│ Equity           $102,778.29         │
│ Floating P/L     $-20.28            │
│ ...existing rows...                  │
├── History ───────────────────────────┤
│ Total Cur. Lot   0.14 L             │
│ Total Closed Lot 5300.58 L          │
│ Daily Closed Lot 12.50 L         ← NEW
│ Daily Rebate     $56.25          ← NEW
│ Total Rebate     $23,852.61      ← NEW
│ Total Closed Ord 2837 orders        │
│ Monthly P/L      $13,839.84         │
│ Total P/L        $133,939.84        │
├──────────────────────────────────────┤
```

### ไฟล์ที่แก้ไข
`public/docs/mql5/Gold_Miner_EA.mq5`

### การแก้ไขหลัก
1. **Lines ~196-200**: เพิ่ม `DashboardScale` input
2. **Lines ~232-238**: เพิ่ม `InpRebatePerLot` input ใน group ใหม่
3. **Lines ~620-640**: เพิ่ม function `CalcDailyClosedLots()`
4. **Lines ~2255-2260**: ใช้ scale กับ tableWidth, headerHeight
5. **Lines ~2396-2410**: เพิ่ม 3 แถว (Daily Closed Lot, Daily Rebate, Total Rebate)
6. **DrawTableRow / CreateDashButton**: ปรับ font size และ row height ตาม scale

### สิ่งที่ไม่เปลี่ยนแปลง
- Trading Strategy Logic (SMA, ZigZag, Grid entry/exit)
- Order Execution (trade.Buy/Sell/PositionClose)
- TP/SL/Trailing/Breakeven calculations
- License / News / Time Filter core logic
- Accumulate / Matching Close logic

