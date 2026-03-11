

## แก้ไข TP/SL Spread Compensation — คำนวณผิดทำให้ไม่ปิดพร้อมกัน

### สาเหตุ (Root Cause)

ปัจจุบันโค้ดใส่ `spreadComp` เท่ากันทั้ง 4 ค่า:
```cpp
g_buyTP  = buyEntry + zone + spreadComp   // ✗
g_sellSL = buyEntry + zone + spreadComp   // ✗ buyTP == sellSL → ราคาเดียวกัน!
```

แต่ **Buy TP/SL ตรวจกับ Bid** ส่วน **Sell TP/SL ตรวจกับ Ask** (Ask = Bid + Spread):

```text
จุด Cross-Over ด้านบน (crossUp = buyEntry + zone):
  Buy TP:  Bid >= crossUp      → triggers ที่ Bid = crossUp
  Sell SL: Ask >= crossUp      → Bid + spread >= crossUp → triggers ที่ Bid = crossUp - spread
  → Sell SL โดนก่อน Buy TP ถึง 65 points! ❌

จุด Cross-Over ด้านล่าง (crossDown = sellEntry - zone):
  Buy SL:  Bid <= crossDown    → triggers ที่ Bid = crossDown  
  Sell TP: Ask <= crossDown    → Bid + spread <= crossDown → triggers ที่ Bid = crossDown - spread
  → Buy SL โดนก่อน Sell TP ถึง 65 points! ❌
```

การใส่ `±spreadComp` ให้ทั้ง 4 ค่าเท่ากัน **ไม่ช่วยแก้ปัญหา** เพราะทั้ง TP และ SL ขยับไปในทิศเดียวกัน → ยังคงห่างกัน spread เท่าเดิม

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Jutlameasu_EA.mq5`

**หลักการ:** ให้ Sell SL/TP ชดเชย spread เพื่อให้ trigger พร้อม Buy TP/SL ที่ Bid เดียวกัน

```cpp
double spreadComp = InpSpreadCompensation * point;
double crossUp   = g_buyEntryLevel + zonePrice;    // จุด cross-over ด้านบน
double crossDown = g_sellEntryLevel - zonePrice;    // จุด cross-over ด้านล่าง

// Buy TP/SL ตรวจกับ Bid → ใช้ค่าตรงๆ
g_buyTP  = NormalizeDouble(crossUp, digits);         // Bid >= crossUp
g_buySL  = NormalizeDouble(crossDown, digits);       // Bid <= crossDown

// Sell TP/SL ตรวจกับ Ask (= Bid + spread) → ต้อง +spreadComp เพื่อชดเชย
g_sellSL = NormalizeDouble(crossUp + spreadComp, digits);    // Ask >= crossUp+spread → Bid >= crossUp ✓
g_sellTP = NormalizeDouble(crossDown + spreadComp, digits);  // Ask <= crossDown+spread → Bid <= crossDown ✓
```

**ผลลัพธ์:**
```text
Sell TP (crossDown + 65pts) อยู่สูงกว่า Buy SL (crossDown) = 65 points ✓
Buy TP (crossUp) อยู่ต่ำกว่า Sell SL (crossUp + 65pts) = 65 points ✓
ทั้งคู่ trigger ที่ Bid level เดียวกัน → ปิดพร้อมกัน ✓
```

**อัปเดต adjustment section ด้วย (line 556-570):**
- เมื่อ adjust buyEntry: `g_buyTP = crossUp_new; g_sellSL = crossUp_new + spreadComp;`
- เมื่อ adjust sellEntry: `g_sellTP = crossDown_new + spreadComp; g_buySL = crossDown_new;`

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic, Martingale level/lot calculation
- STATE 1, STATE 2, STATE 2.5, STATE 3, STATE 4 flow
- StartNewCycle order placement (แก้เฉพาะ TP/SL values)
- License / News / Time Filter / Data Sync / Dashboard / OnChartEvent

