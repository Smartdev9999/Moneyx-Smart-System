
## แผนแก้ไข Bug: Hedge Lot ไม่เท่า Main Lot (v2.3.1)

---

### สรุปปัญหาที่พบ

| รายการ | ค่าที่ตั้ง | ค่าที่ได้จริง | สาเหตุ |
|--------|-----------|--------------|--------|
| EURJPY (Symbol A) | 0.16 | 0.16 ✓ | Base Lot |
| AUDUSD (Symbol B) | 0.16 | 0.10 ✗ | Dollar-Neutral Formula |

**สาเหตุหลัก:**
1. `CalculateDollarNeutralLots()` ใช้สูตร `lotB = baseLot × beta × (pipA/pipB)` ทำให้ lot ต่างกัน
2. ใน `OnInit` เรียก `CalculateDollarNeutralLots()` โดยไม่เช็ค `InpUseDollarNeutral`
3. ไม่มีตัวเลือกให้ใช้ **Fixed Lot** (lot เท่ากันทั้งคู่) สำหรับ Main Order

---

### โซลูชัน: เพิ่ม Enum สำหรับ Main Order Lot Mode

เพิ่มตัวเลือกให้ผู้ใช้เลือกระหว่าง:
1. **Fixed Lot** (ใหม่): ทั้ง Symbol A และ B ใช้ Base Lot เท่ากัน (0.16 = 0.16)
2. **Dollar-Neutral** (เดิม): คำนวณตาม Beta และ Pip Value

---

### การแก้ไขทั้งหมด

#### Part A: อัปเดต Version

**ไฟล์:** `public/docs/mql5/Harmony_Dream_EA.mq5`

```cpp
#property version   "2.31"
#property description "v2.3.1: Add Fixed Lot Mode for Main Order + Fix InpUseDollarNeutral Check"
```

---

#### Part B: เพิ่ม Enum สำหรับ Main Order Lot Mode

**ตำแหน่ง:** ใกล้กับ Enum อื่น ๆ (ประมาณบรรทัด 240)

```cpp
//+------------------------------------------------------------------+
//| MAIN ORDER LOT MODE ENUM (v2.3.1)                                  |
//+------------------------------------------------------------------+
enum ENUM_MAIN_LOT_MODE
{
   MAIN_LOT_FIXED = 0,          // Fixed (Same Lot for Both Symbols)
   MAIN_LOT_DOLLAR_NEUTRAL      // Dollar-Neutral (Beta × Pip Ratio)
};
```

---

#### Part C: เพิ่ม Input Parameter

**ตำแหน่ง:** ใน group "Lot Sizing (Dollar-Neutral)" (บรรทัด 469)

```cpp
input group "=== Lot Sizing Settings (v2.3.1) ==="
input ENUM_MAIN_LOT_MODE InpMainLotMode = MAIN_LOT_FIXED;  // v2.3.1: Main Order Lot Mode
input bool     InpUseDollarNeutral = true;      // [DEPRECATED] Use Dollar-Neutral (use Mode above)
input double   InpMaxMarginPercent = 50.0;      // Max Margin Usage (%)
```

---

#### Part D: แก้ไข `CalculateDollarNeutralLots()` รองรับ Fixed Mode

**บรรทัด:** 4888-4943

```cpp
void CalculateDollarNeutralLots(int pairIndex)
{
   double baseLot = GetScaledBaseLot();
   string symbolA = g_pairs[pairIndex].symbolA;
   string symbolB = g_pairs[pairIndex].symbolB;
   
   // v2.3.1: Check Main Lot Mode FIRST
   if(InpMainLotMode == MAIN_LOT_FIXED)
   {
      // Fixed Mode: Same lot for both symbols
      double lotA = NormalizeLot(symbolA, baseLot);
      double lotB = NormalizeLot(symbolB, baseLot);
      
      g_pairs[pairIndex].lotBuyA = lotA;
      g_pairs[pairIndex].lotBuyB = lotB;
      g_pairs[pairIndex].lotSellA = lotA;
      g_pairs[pairIndex].lotSellB = lotB;
      
      if(InpDebugMode)
      {
         PrintFormat("[v2.3.1 FIXED LOT] Pair %d: A=%.2f B=%.2f (Both use BaseLot=%.4f)", 
                     pairIndex + 1, lotA, lotB, baseLot);
      }
      return;
   }
   
   // === Dollar-Neutral Mode (Original Logic) ===
   double hedgeRatio = g_pairs[pairIndex].hedgeRatio;
   double pipValueA = GetPipValue(symbolA);
   double pipValueB = GetPipValue(symbolB);
   
   // ... (keep existing validation and calculation) ...
}
```

---

#### Part E: แก้ไข `OnInit` ให้เช็ค Mode ก่อน

**บรรทัด:** 1288-1306

```cpp
for(int i = 0; i < MAX_PAIRS; i++)
{
   if(g_pairs[i].enabled)
   {
      // v2.3.1: Always call this function - it now handles mode internally
      CalculateDollarNeutralLots(i);
      
      // Verify calculation succeeded...
   }
}
```

---

#### Part F: แก้ไข `OpenBuySideTrade()` และ `OpenSellSideTrade()`

ตรวจสอบว่าใช้ lot ที่คำนวณไว้แล้ว (ไม่ต้องแก้ เพราะใช้ `g_pairs[pairIndex].lotBuyA/B` อยู่แล้ว)

---

### สรุปไฟล์ที่แก้ไข

| ไฟล์ | ส่วนที่แก้ไข | รายละเอียด |
|------|-------------|------------|
| `Harmony_Dream_EA.mq5` | Version | อัปเดตเป็น v2.31 |
| `Harmony_Dream_EA.mq5` | Enums | เพิ่ม `ENUM_MAIN_LOT_MODE` |
| `Harmony_Dream_EA.mq5` | Inputs | เพิ่ม `InpMainLotMode` |
| `Harmony_Dream_EA.mq5` | `CalculateDollarNeutralLots()` | เพิ่ม Fixed Mode logic |

---

### ตัวอย่างการทำงานหลังแก้ไข

**Settings:**
- Base Lot = 0.16
- Main Lot Mode = **Fixed**

| Symbol | ก่อนแก้ไข | หลังแก้ไข |
|--------|-----------|-----------|
| EURJPY (A) | 0.16 | 0.16 ✓ |
| AUDUSD (B) | 0.10 | 0.16 ✓ |

**Settings:**
- Base Lot = 0.16
- Main Lot Mode = **Dollar-Neutral**

| Symbol | ก่อนแก้ไข | หลังแก้ไข |
|--------|-----------|-----------|
| EURJPY (A) | 0.16 | 0.16 |
| AUDUSD (B) | 0.10 | 0.10 (คำนวณตาม Beta) |

---

### หมายเหตุสำคัญ

1. **Default = Fixed**: ค่าเริ่มต้นเป็น "Fixed" เพื่อให้ lot เท่ากันทั้งคู่ตามที่ผู้ใช้ต้องการ
2. **Backward Compatible**: ถ้าต้องการ Dollar-Neutral แบบเดิม ให้เลือก Mode เป็น "Dollar-Neutral"
3. **DEPRECATED `InpUseDollarNeutral`**: ตัวแปรเดิมยังคงอยู่แต่ถูกแทนที่ด้วย `InpMainLotMode`
4. **Grid Orders ไม่ได้รับผลกระทบ**: Grid ยังคงใช้ `InpGridLotMode` แยกต่างหาก

---

### ข้อควรระวัง

- ถ้าใช้ **Fixed Lot** กับคู่ที่มี Pip Value ต่างกันมาก (เช่น XAUUSD vs XAUEUR) → ความเสี่ยงอาจไม่ Balance
- แนะนำใช้ **Dollar-Neutral** สำหรับคู่ที่ Pip Value ต่างกันมากเพื่อ Hedge Risk ได้ดีกว่า
