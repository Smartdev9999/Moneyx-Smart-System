

## แผนแก้ไข Grid Profit Lot Initialization - Harmony Dream EA v1.8.8 Hotfix 5

### สาเหตุของปัญหา

จากภาพที่ส่งมา:
| Order | Comment | Volume | ที่ควรจะเป็น | สาเหตุ |
|-------|---------|--------|--------------|--------|
| Initial | `XU-XE_BUY_20` | 0.4 | 0.4 ✅ | - |
| GP#1 | `XU-XE_GP#1_BUY_20` | 0.4 | **0.8** ❌ | ใช้ initialLotA แทน lotA |
| GP#2 | `XU-XE_GP#2_BUY_20` | 0.8 | **1.6** ❌ | ควร compound จาก 0.8 |
| GL#1 | `XU-XE_GL#1_BUY_20` | 0.8 | 0.8 ✅ | ใช้ lastGridLotBuyA ถูกต้อง |

**Root Cause:** เมื่อเปิด Main Entry:
- `lastGridLotBuyA = lotA` (0.4) → Grid Loss ใช้ค่านี้เป็น base ✅
- `lastProfitGridLotBuyA = 0` (ไม่ได้ set!) → Grid Profit fallback ไป `initialLotA` (0.2) ❌

---

### การแก้ไข

#### 1. Initialize lastProfitGridLot ใน OpenBuySideTrade() (บรรทัด 6613-6621)

**เดิม:**
```mql5
// v3.5.3 HF1: Initialize Last Grid Lots for Compounding (first level = main entry lot)
g_pairs[pairIndex].lastGridLotBuyA = lotA;
g_pairs[pairIndex].lastGridLotBuyB = lotB;

// v3.6.0: Store initial entry price for Grid Profit Side
g_pairs[pairIndex].initialEntryPriceBuy = SymbolInfoDouble(symbolA, SYMBOL_ASK);
g_pairs[pairIndex].lastProfitPriceBuy = 0;
g_pairs[pairIndex].gridProfitCountBuy = 0;
g_pairs[pairIndex].gridProfitZLevelBuy = 0;
```

**แก้ไขเป็น:**
```mql5
// v3.5.3 HF1: Initialize Last Grid Lots for Compounding (first level = main entry lot)
g_pairs[pairIndex].lastGridLotBuyA = lotA;
g_pairs[pairIndex].lastGridLotBuyB = lotB;

// v1.8.8 HF5: Initialize Grid Profit lots to main entry lot (GP#1 will multiply from this)
g_pairs[pairIndex].lastProfitGridLotBuyA = lotA;
g_pairs[pairIndex].lastProfitGridLotBuyB = lotB;

// v3.6.0: Store initial entry price for Grid Profit Side
g_pairs[pairIndex].initialEntryPriceBuy = SymbolInfoDouble(symbolA, SYMBOL_ASK);
g_pairs[pairIndex].lastProfitPriceBuy = 0;
g_pairs[pairIndex].gridProfitCountBuy = 0;
g_pairs[pairIndex].gridProfitZLevelBuy = 0;
```

---

#### 2. Initialize lastProfitGridLot ใน OpenSellSideTrade() (บรรทัด 6792-6800)

**เดิม:**
```mql5
// v3.5.3 HF1: Initialize Last Grid Lots for Compounding (first level = main entry lot)
g_pairs[pairIndex].lastGridLotSellA = lotA;
g_pairs[pairIndex].lastGridLotSellB = lotB;

// v3.6.0: Store initial entry price for Grid Profit Side
g_pairs[pairIndex].initialEntryPriceSell = SymbolInfoDouble(symbolA, SYMBOL_BID);
g_pairs[pairIndex].lastProfitPriceSell = 0;
g_pairs[pairIndex].gridProfitCountSell = 0;
g_pairs[pairIndex].gridProfitZLevelSell = 0;
```

**แก้ไขเป็น:**
```mql5
// v3.5.3 HF1: Initialize Last Grid Lots for Compounding (first level = main entry lot)
g_pairs[pairIndex].lastGridLotSellA = lotA;
g_pairs[pairIndex].lastGridLotSellB = lotB;

// v1.8.8 HF5: Initialize Grid Profit lots to main entry lot (GP#1 will multiply from this)
g_pairs[pairIndex].lastProfitGridLotSellA = lotA;
g_pairs[pairIndex].lastProfitGridLotSellB = lotB;

// v3.6.0: Store initial entry price for Grid Profit Side
g_pairs[pairIndex].initialEntryPriceSell = SymbolInfoDouble(symbolA, SYMBOL_BID);
g_pairs[pairIndex].lastProfitPriceSell = 0;
g_pairs[pairIndex].gridProfitCountSell = 0;
g_pairs[pairIndex].gridProfitZLevelSell = 0;
```

---

### สรุปไฟล์ที่ต้องแก้ไข

| ไฟล์ | การเปลี่ยนแปลง |
|------|----------------|
| `public/docs/mql5/Harmony_Dream_EA.mq5` | 1. เพิ่ม `lastProfitGridLotBuyA/B = lotA/lotB` ใน `OpenBuySideTrade()` |
| | 2. เพิ่ม `lastProfitGridLotSellA/B = lotA/lotB` ใน `OpenSellSideTrade()` |

---

### ผลลัพธ์ที่คาดหวัง

**Flow หลังแก้ไข:**

```text
1. Main Entry เปิด:
   lotA = 0.4 (scaledBaseLot × multiplier)
   lastProfitGridLotBuyA = 0.4 ✅ (เพิ่มใหม่)

2. GP#1 คำนวณ:
   isProfitSide = true
   lastProfitGridLotBuyA = 0.4 → effectiveBaseLotA = 0.4
   0.4 × 2 (multiplier) = 0.8 lot ✅

3. GP#1 เปิดสำเร็จ:
   lastProfitGridLotBuyA = 0.8 (update หลังเปิด)

4. GP#2 คำนวณ:
   lastProfitGridLotBuyA = 0.8 → effectiveBaseLotA = 0.8
   0.8 × 2 = 1.6 lot ✅

5. GP#3 คำนวณ:
   1.6 × 2 = 3.2 → cap at 3.0 lot (Max Lot) ✅
```

**เปรียบเทียบก่อน/หลัง:**

| Order | ก่อนแก้ | หลังแก้ |
|-------|--------|--------|
| Initial | 0.4 | 0.4 |
| GP#1 | 0.4 ❌ | 0.8 ✅ |
| GP#2 | 0.8 ❌ | 1.6 ✅ |
| GP#3 | 1.6 ❌ | 3.0 ✅ |

---

### สิ่งที่ไม่แตะต้อง

- Grid Loss lot calculation (ทำงานถูกต้องอยู่แล้ว)
- Compounding logic ใน `CalculateTrendBasedLots()` (HF4 แก้ไปแล้ว)
- Close order logic (HF3 แก้ไปแล้ว)
- Comment format (#1, #2...)
- Floating P/L calculation (HF2 แก้ไปแล้ว)

---

### เหตุผลทางเทคนิค

**ทำไม Grid Loss ทำงานถูกต้อง:**
- `lastGridLotBuyA = lotA` (0.4) ถูก set ตั้งแต่ Main Entry
- GL#1 คำนวณ: `effectiveBaseLotA = lastGridLotBuyA = 0.4`
- ผลลัพธ์: 0.4 × 2 = 0.8 ✅

**ทำไม Grid Profit ไม่ทำงาน (ก่อน HF5):**
- `lastProfitGridLotBuyA = 0` (ไม่เคย set)
- GP#1 คำนวณ: condition `lastProfitGridLotBuyA > 0` = false
- Fallback: `effectiveBaseLotA = initialLotA = 0.2`
- ผลลัพธ์: 0.2 × 2 = 0.4 ❌

**หลัง HF5:**
- `lastProfitGridLotBuyA = lotA = 0.4` (set ตอน Main Entry)
- GP#1 คำนวณ: condition `lastProfitGridLotBuyA > 0` = true
- ใช้: `effectiveBaseLotA = 0.4`
- ผลลัพธ์: 0.4 × 2 = 0.8 ✅

