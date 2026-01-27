

## แผนแก้ไข Grid Profit Lot Calculation - Harmony Dream EA v1.8.8 Hotfix 4

### สาเหตุของปัญหา

จากภาพที่ส่งมา:
| Order | Comment | Volume | ที่ควรจะเป็น |
|-------|---------|--------|--------------|
| Initial | `XU-XE_BUY_20` | 0.4 | 0.4 ✅ |
| GP#1 | `XU-XE_GP#1_BUY_20` | 3.0 | 0.2 × multiplier ❌ |
| GP#2 | `XU-XE_GP#2_BUY_20` | 3.0 | compound from GP#1 ❌ |
| GL#1 | `XU-XE_GL#1_BUY_20` | 0.8 | ✅ |
| GL#2 | `XU-XE_GL#2_BUY_20` | 1.6 | ✅ |

**ปัญหาหลัก:** Grid Profit (GP) ไม่ compound ถูกต้องและข้ามไปใช้ Maximum Lot (3.0) ทันที

---

### การวิเคราะห์โค้ด

#### บรรทัด 5774 - ไม่ส่ง isProfitSide
```mql5
case GRID_LOT_TYPE_TREND_BASED:
   // v1.2: Force CDC Trend logic regardless of InpGridLotMode
   CalculateTrendBasedLots(pairIndex, side, baseLotA, baseLotB, outLotA, outLotB, isGridOrder, true);
   //                                                                              ↑ ไม่มี isProfitSide!
   break;
```

#### บรรทัด 5937-5951 - ใช้ Grid Loss variable สำหรับ Grid Profit
```mql5
if(isGridOrder && InpLotProgression == LOT_PROG_COMPOUNDING)
{
   if(side == "BUY")
   {
      // ← ใช้ lastGridLotBuyA ซึ่งเป็น Grid Loss!
      if(isTrendAlignedA && g_pairs[pairIndex].lastGridLotBuyA > 0)
         effectiveBaseLotA = g_pairs[pairIndex].lastGridLotBuyA;
   }
}
```

**ผลลัพธ์:** 
- `lastGridLotBuyA = 0` (เพราะ Grid Profit ไม่ได้อัพเดท variable นี้)
- Fallback ไปใช้ `initialLotA`
- แต่ Multiplier คูณเข้าไปทำให้พุ่งไปสูงสุด

---

### รายละเอียดการแก้ไข

#### 1. เพิ่ม Parameter isProfitSide ใน CalculateTrendBasedLots()

**เดิม (บรรทัด 5837-5841):**
```mql5
void CalculateTrendBasedLots(int pairIndex, string side, 
                              double baseLotA, double baseLotB,
                              double &adjustedLotA, double &adjustedLotB,
                              bool isGridOrder = false,
                              bool forceTrendLogic = false)
```

**แก้ไขเป็น:**
```mql5
void CalculateTrendBasedLots(int pairIndex, string side, 
                              double baseLotA, double baseLotB,
                              double &adjustedLotA, double &adjustedLotB,
                              bool isGridOrder = false,
                              bool forceTrendLogic = false,
                              bool isProfitSide = false)  // v1.8.8 HF4: Add Profit Side flag
```

---

#### 2. แก้ไข Compounding Logic แยก Grid Loss vs Grid Profit (บรรทัด 5934-5951)

**เดิม:**
```mql5
if(isGridOrder && InpLotProgression == LOT_PROG_COMPOUNDING)
{
   if(side == "BUY")
   {
      if(isTrendAlignedA && g_pairs[pairIndex].lastGridLotBuyA > 0)
         effectiveBaseLotA = g_pairs[pairIndex].lastGridLotBuyA;
      if(isTrendAlignedB && g_pairs[pairIndex].lastGridLotBuyB > 0)
         effectiveBaseLotB = g_pairs[pairIndex].lastGridLotBuyB;
   }
   else
   {
      if(isTrendAlignedA && g_pairs[pairIndex].lastGridLotSellA > 0)
         effectiveBaseLotA = g_pairs[pairIndex].lastGridLotSellA;
      if(isTrendAlignedB && g_pairs[pairIndex].lastGridLotSellB > 0)
         effectiveBaseLotB = g_pairs[pairIndex].lastGridLotSellB;
   }
}
```

**แก้ไขเป็น:**
```mql5
// v1.8.8 HF4: Separate Grid Loss vs Grid Profit compounding
if(isGridOrder && InpLotProgression == LOT_PROG_COMPOUNDING)
{
   if(side == "BUY")
   {
      if(isProfitSide)
      {
         // Grid Profit: Use lastProfitGridLot
         if(isTrendAlignedA && g_pairs[pairIndex].lastProfitGridLotBuyA > 0)
            effectiveBaseLotA = g_pairs[pairIndex].lastProfitGridLotBuyA;
         if(isTrendAlignedB && g_pairs[pairIndex].lastProfitGridLotBuyB > 0)
            effectiveBaseLotB = g_pairs[pairIndex].lastProfitGridLotBuyB;
      }
      else
      {
         // Grid Loss: Use lastGridLot
         if(isTrendAlignedA && g_pairs[pairIndex].lastGridLotBuyA > 0)
            effectiveBaseLotA = g_pairs[pairIndex].lastGridLotBuyA;
         if(isTrendAlignedB && g_pairs[pairIndex].lastGridLotBuyB > 0)
            effectiveBaseLotB = g_pairs[pairIndex].lastGridLotBuyB;
      }
   }
   else
   {
      if(isProfitSide)
      {
         // Grid Profit: Use lastProfitGridLot
         if(isTrendAlignedA && g_pairs[pairIndex].lastProfitGridLotSellA > 0)
            effectiveBaseLotA = g_pairs[pairIndex].lastProfitGridLotSellA;
         if(isTrendAlignedB && g_pairs[pairIndex].lastProfitGridLotSellB > 0)
            effectiveBaseLotB = g_pairs[pairIndex].lastProfitGridLotSellB;
      }
      else
      {
         // Grid Loss: Use lastGridLot
         if(isTrendAlignedA && g_pairs[pairIndex].lastGridLotSellA > 0)
            effectiveBaseLotA = g_pairs[pairIndex].lastGridLotSellA;
         if(isTrendAlignedB && g_pairs[pairIndex].lastGridLotSellB > 0)
            effectiveBaseLotB = g_pairs[pairIndex].lastGridLotSellB;
      }
   }
}
```

---

#### 3. อัพเดท Caller ให้ส่ง isProfitSide (บรรทัด 5772-5775)

**เดิม:**
```mql5
case GRID_LOT_TYPE_TREND_BASED:
   // v1.2: Force CDC Trend logic regardless of InpGridLotMode
   CalculateTrendBasedLots(pairIndex, side, baseLotA, baseLotB, outLotA, outLotB, isGridOrder, true);
   break;
```

**แก้ไขเป็น:**
```mql5
case GRID_LOT_TYPE_TREND_BASED:
   // v1.8.8 HF4: Pass isProfitSide to differentiate Grid Loss vs Grid Profit
   CalculateTrendBasedLots(pairIndex, side, baseLotA, baseLotB, outLotA, outLotB, isGridOrder, true, isProfitSide);
   break;
```

---

### สรุปไฟล์ที่ต้องแก้ไข

| ไฟล์ | การเปลี่ยนแปลง |
|------|----------------|
| `public/docs/mql5/Harmony_Dream_EA.mq5` | 1. เพิ่ม `isProfitSide` parameter ใน `CalculateTrendBasedLots()` |
| | 2. แก้ Compounding logic แยก Grid Loss/Profit variables |
| | 3. อัพเดท `CalculateGridLots()` ให้ส่ง `isProfitSide` |

---

### ผลลัพธ์ที่คาดหวัง

**หลังแก้ไข - Grid Profit จะ Compound แยกจาก Grid Loss:**

```text
Initial Order: 0.4 lot (lotBuyA)

Grid Loss Side:
GL#1: lastGridLotBuyA = 0 → ใช้ initialLotA = 0.2
      0.2 × multA = 0.4 → บันทึก lastGridLotBuyA = 0.4
GL#2: lastGridLotBuyA = 0.4 → 0.4 × multA = 0.8

Grid Profit Side (แยก track):
GP#1: lastProfitGridLotBuyA = 0 → ใช้ initialLotA = 0.2
      0.2 × multA = 0.4 → บันทึก lastProfitGridLotBuyA = 0.4
GP#2: lastProfitGridLotBuyA = 0.4 → 0.4 × multA = 0.8
```

---

### สิ่งที่ไม่แตะต้อง

- Grid Loss lot calculation (ยังใช้ `lastGridLotBuyA/B` เหมือนเดิม)
- GRID_LOT_TYPE_MULTIPLIER logic (มี isProfitSide อยู่แล้ว)
- Comment format (#1, #2...)
- Close order logic (แก้ไขแล้วใน HF3)
- Floating P/L calculation (แก้ไขแล้วใน HF2)

