

## แผนรวม: เพิ่ม 2 ฟีเจอร์ให้ Jutlameasu EA

**ไฟล์:** `public/docs/mql5/Jutlameasu_EA.mq5`

---

### ฟีเจอร์ 1: Custom TP/SL Distance (แยก TP/SL ออกจาก Zone)

**ปัญหา:** ตอนนี้ TP/SL ใช้ `InpZonePoints` เดียวกับ Entry → ถ้า Zone แคบ, TP/SL ก็แคบตาม

**เพิ่ม Input Parameters:**
```cpp
input group "=== TP/SL Distance Settings ==="
input bool     InpUseCustomTPSL     = false;    // Use Custom TP/SL Distance
input double   InpTPDistance         = 1500;     // TP Distance from Entry (points)
input double   InpSLDistance         = 1500;     // SL Distance from Entry (points)
```

**แก้ไข `StartNewCycle()` — คำนวณ crossUp/crossDown:**
```cpp
double tpDist = InpUseCustomTPSL ? (InpTPDistance * point) : zonePrice;
double slDist = InpUseCustomTPSL ? (InpSLDistance * point) : zonePrice;

double crossUp   = g_buyEntryLevel + tpDist;      // TP ด้านบน
double crossDown = g_sellEntryLevel - tpDist;      // TP ด้านล่าง

g_buyTP  = NormalizeDouble(crossUp, digits);
g_buySL  = NormalizeDouble(g_buyEntryLevel - slDist, digits);
g_sellSL = NormalizeDouble(g_sellEntryLevel + slDist + spreadComp, digits);
g_sellTP = NormalizeDouble(crossDown + spreadComp, digits);
```

**อัปเดต Adjustment section + Dashboard** ให้ใช้ `tpDist/slDist` แทน `zonePrice` ด้วย

---

### ฟีเจอร์ 2: Accumulate Close (ปิดทั้งหมดเมื่อกำไรรวมถึงเป้า)

**เพิ่ม Input Parameters:**
```cpp
input group "=== Accumulate Close ==="
input bool     InpUseAccumulate     = false;    // Enable Accumulate Close
input int      InpAccMinOrders      = 4;        // Minimum Orders to Activate
input double   InpAccTarget         = 5.0;      // Accumulate Target ($)
```

**เพิ่มฟังก์ชัน `CheckAccumulateClose()`:**
- นับ positions ที่มี MagicNumber ตรง
- ถ้าจำนวน < `InpAccMinOrders` → return
- คำนวณ floating P/L รวม (ใช้ `CalculateTotalFloatingPL()` ที่มีอยู่แล้ว)
- ถ้า P/L >= `InpAccTarget` → `CloseAllPositions()` + `DeleteAllPendingOrders()` + รีเซ็ต cycle

**เรียกใน `OnTick()` — หลัง `CheckDrawdownExit()` (line ~694):**
```cpp
if(InpUseAccumulate) CheckAccumulateClose();
```

**อัปเดต Dashboard** เพิ่มแสดง: `Acc: ON | Min:4 | Target:$5.00 | Float:$2.30`

---

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (BuyStop, SellStop, PlaceNextPendingOrder)
- STATE 1-4 flow logic, Martingale level/lot calculation
- Spread Compensation logic (ยังคง +spreadComp ให้ Sell)
- License / News / Time Filter / Data Sync
- OnChartEvent buttons / Drawdown Protection

