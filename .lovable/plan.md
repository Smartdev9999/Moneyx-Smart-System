

## แผนแก้ไข: เพิ่ม History Metrics + Spread Compensation สำหรับ TP/SL

**ไฟล์:** `public/docs/mql5/Jutlameasu_EA.mq5`

---

### 1. เพิ่ม Input Parameter ใหม่ 2 ตัว

```cpp
input group "=== Rebate Settings ==="
input double   InpRebatePerLot      = 4.5;     // Rebate per Lot ($)

input group "=== Spread Compensation ==="
input double   InpSpreadCompensation = 65;      // Spread Compensation (points) สำหรับขยาย TP/SL
```

### 2. แก้ไข TP/SL Calculation ใน StartNewCycle (line 532-536)

ปัญหาปัจจุบัน: Buy TP = Sell SL อยู่ **จุดเดียวกัน** → เมื่อราคาวิ่งถึงจุดนั้น spread ทำให้โดนแค่ SL (Bid price) แต่ไม่โดน TP (Ask price) หรือกลับกัน

**แก้ไข:** ขยาย TP ออกเพิ่มอีก `InpSpreadCompensation` points เพื่อให้ TP อยู่ **ไกลกว่า** SL ของฝั่งตรงข้ามเล็กน้อย → เมื่อราคาวิ่งถึง SL ของฝั่งหนึ่ง TP ของอีกฝั่งจะโดนด้วยแน่นอน

```cpp
double spreadComp = InpSpreadCompensation * point;

// Cross-Over TP/SL with spread compensation
g_buyTP  = NormalizeDouble(g_buyEntryLevel + zonePrice + spreadComp, digits);
g_buySL  = NormalizeDouble(g_sellEntryLevel - zonePrice - spreadComp, digits);
g_sellTP = NormalizeDouble(g_sellEntryLevel - zonePrice - spreadComp, digits);
g_sellSL = NormalizeDouble(g_buyEntryLevel + zonePrice + spreadComp, digits);
```

ตัวอย่าง: ถ้า Zone=1000 points, Spread Comp=65 points
- Buy TP = Buy Entry + 1065 points (ไกลกว่า Sell SL 65 points)
- เมื่อราคา Bid ถึง Sell SL → Ask จะอยู่สูงกว่า Bid อีก ~65 points → Buy TP ก็โดนด้วย ✓

### 3. เพิ่ม 3 ฟังก์ชัน History (คัดลอกจาก Gold_Miner_EA)

- `CalcDailyClosedLots()` — sum closed volumes วันนี้
- `CalcTotalClosedOrders()` — count closed deals ทั้งหมด
- `CalcMonthlyPL()` — sum profit เดือนนี้

### 4. อัปเดต DisplayDashboard — เพิ่ม History Section

เพิ่มหลัง "Cycles (W/T)" row:

```text
── HISTORY SECTION (สีน้ำเงิน) ──
Total Cur. Lot    | 0.30 L
Total Closed Lot  | 12.50 L
── REBATE SECTION (สีทอง) ──
Daily Closed Lot  | 1.20 L
Daily Rebate      | $5.40
Total Rebate      | $56.25
── HISTORY SECTION (ต่อ) ──
Total Closed Ord  | 45 orders
Monthly P/L       | $120.50
Daily P/L         | $25.00     ← ย้ายมาอยู่ในกลุ่มนี้
Total P/L         | $450.00    ← ย้ายมาอยู่ในกลุ่มนี้
```

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (BuyStop, SellStop, PlaceNextPendingOrder)
- STATE 1, STATE 2, STATE 2.5, STATE 3, STATE 4 flow logic
- Martingale level/lot calculation
- License / News / Time Filter / Data Sync
- OnChartEvent buttons
- StartNewCycle order placement logic (แก้เฉพาะ TP/SL values)

