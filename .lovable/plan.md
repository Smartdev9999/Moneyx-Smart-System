
## แผนแก้ไข v2.2.10 - Fix Progressive Mode + Add Correlation Type Filter

---

### สรุปปัญหาที่พบ

| ปัญหา | สถานะ | ความรุนแรง |
|-------|--------|-----------|
| 1. Correlation Type Filter หายไป | ❌ ไม่มี Code | สูง |
| 2. Progressive ATR Distance restore ผิดพลาด | ⚠️ Logic ไม่ครบ | สูง |
| 3. Grid orders อาจเปิดถี่เกินไป | ⚠️ ขึ้นกับ Min Distance | ปานกลาง |

---

### Part A: อัปเดต Version

**ไฟล์:** `public/docs/mql5/Harmony_Dream_EA.mq5`

```cpp
#property version   "2.30"
#property description "v2.3.0: Fix Progressive ATR Restore + Add Correlation Type Filter"
```

---

### Part B: เพิ่ม Correlation Type Filter Enum (v2.2.8 - หายไป)

**ตำแหน่ง:** หลังบรรทัด 269 (หลัง `ENUM_ENTRY_MODE`)

```cpp
//+------------------------------------------------------------------+
//| CORRELATION TYPE FILTER ENUM (v2.2.8)                              |
//+------------------------------------------------------------------+
enum ENUM_CORR_TYPE_FILTER
{
   CORR_FILTER_BOTH = 0,          // Both (Positive + Negative)
   CORR_FILTER_POSITIVE_ONLY,     // Positive Only
   CORR_FILTER_NEGATIVE_ONLY      // Negative Only
};
```

---

### Part C: เพิ่ม Input Parameter สำหรับ Correlation Filter

**ตำแหน่ง:** หลังบรรทัด 668 (ใน group "Entry Mode Settings")

```cpp
input group "=== Entry Mode Settings (v1.8.8) ==="
input ENUM_ENTRY_MODE InpEntryMode = ENTRY_MODE_ZSCORE;    // Entry Mode
input ENUM_CORR_TYPE_FILTER InpCorrTypeFilter = CORR_FILTER_BOTH;  // v2.2.8: Correlation Type Filter
input double   InpCorrOnlyPositiveThreshold = 0.60;        // Correlation Only: Positive Threshold (0.60 = 60%)
input double   InpCorrOnlyNegativeThreshold = -0.60;       // Correlation Only: Negative Threshold (-0.60 = -60%)
```

---

### Part D: เพิ่ม Helper Function `CheckCorrelationTypeFilter()`

**ตำแหน่ง:** หลังฟังก์ชัน `CheckCorrelationOnlyEntry()`

```cpp
//+------------------------------------------------------------------+
//| Check Correlation Type Filter (v2.2.8)                             |
//| Returns: true = Pair's correlation type matches the filter         |
//+------------------------------------------------------------------+
bool CheckCorrelationTypeFilter(int pairIndex)
{
   int corrType = g_pairs[pairIndex].correlationType;
   
   switch(InpCorrTypeFilter)
   {
      case CORR_FILTER_BOTH:
         return true;  // Allow both types
         
      case CORR_FILTER_POSITIVE_ONLY:
         return (corrType == 1);  // Only Positive Correlation
         
      case CORR_FILTER_NEGATIVE_ONLY:
         return (corrType == -1);  // Only Negative Correlation
         
      default:
         return true;
   }
}
```

---

### Part E: เพิ่ม Max Grid Level Tracking ใน PairInfo struct

**ตำแหน่ง:** ประมาณบรรทัด 180 (ใน struct PairInfo)

```cpp
   // v2.3.0: Track max grid level for Progressive Mode restoration
   int maxGridLossBuyLevel;
   int maxGridLossSellLevel;
   int maxGridProfitBuyLevel;
   int maxGridProfitSellLevel;
```

---

### Part F: เพิ่ม Helper Function `ExtractGridLevelFromComment()`

```cpp
//+------------------------------------------------------------------+
//| Extract Grid Level from Comment (v2.3.0)                           |
//| Example: "_GL#3_" → returns 3, "_GP#2_" → returns 2               |
//+------------------------------------------------------------------+
int ExtractGridLevelFromComment(string comment, string prefix)
{
   int pos = StringFind(comment, prefix);
   if(pos < 0) return 0;
   
   // Find the number after prefix (e.g., "_GL#" → find "3" in "_GL#3_")
   int startPos = pos + StringLen(prefix);
   string numStr = "";
   
   for(int k = startPos; k < StringLen(comment); k++)
   {
      ushort ch = StringGetCharacter(comment, k);
      if(ch >= '0' && ch <= '9')
         numStr += CharToString((uchar)ch);
      else
         break;
   }
   
   return (StringLen(numStr) > 0) ? (int)StringToInteger(numStr) : 0;
}
```

---

### Part G: แก้ไข RestoreOpenPositions() - ใช้ Grid Level สูงสุด

**ตำแหน่ง:** บรรทัด 1740-1760 (ส่วน Grid Loss BUY)

**แทนที่:**
```cpp
if(StringFind(comment, "_GL") >= 0)
{
   g_pairs[i].avgOrderCountBuy++;
   
   // v2.2.3: Update lastAvgPriceBuy to latest Grid Loss price (lowest for BUY)
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   if(g_pairs[i].lastAvgPriceBuy == 0 || openPrice < g_pairs[i].lastAvgPriceBuy)
   {
      g_pairs[i].lastAvgPriceBuy = openPrice;
   }
```

**เป็น:**
```cpp
if(StringFind(comment, "_GL") >= 0)
{
   g_pairs[i].avgOrderCountBuy++;
   
   // v2.3.0: Extract grid level from comment for Progressive Mode
   int extractedLevel = ExtractGridLevelFromComment(comment, "_GL#");
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   
   // v2.3.0: For Progressive Mode, use HIGHEST level's price (not just lowest price)
   if(extractedLevel > g_pairs[i].maxGridLossBuyLevel)
   {
      g_pairs[i].maxGridLossBuyLevel = extractedLevel;
      g_pairs[i].lastAvgPriceBuy = openPrice;
      
      if(InpDebugMode)
      {
         PrintFormat("[v2.3.0 RESTORE] Pair %d GL_BUY: Level %d price=%.5f (MaxLevel=%d)",
                     i + 1, extractedLevel, openPrice, g_pairs[i].maxGridLossBuyLevel);
      }
   }
   else if(g_pairs[i].lastAvgPriceBuy == 0 || openPrice < g_pairs[i].lastAvgPriceBuy)
   {
      // Fallback for old comment format or first restore
      g_pairs[i].lastAvgPriceBuy = openPrice;
   }
```

---

### Part H: แก้ไข RestoreOpenPositions() - Grid Profit BUY

**ตำแหน่ง:** บรรทัด 1762-1783 (ส่วน Grid Profit BUY)

**แทนที่:**
```cpp
else if(StringFind(comment, "_GP") >= 0)
{
   g_pairs[i].gridProfitCountBuy++;
   
   // v2.2.3: Update lastProfitPriceBuy to latest Grid Profit price (highest for BUY)
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   if(g_pairs[i].lastProfitPriceBuy == 0 || openPrice > g_pairs[i].lastProfitPriceBuy)
   {
      g_pairs[i].lastProfitPriceBuy = openPrice;
   }
```

**เป็น:**
```cpp
else if(StringFind(comment, "_GP") >= 0)
{
   g_pairs[i].gridProfitCountBuy++;
   
   // v2.3.0: Extract grid level from comment for Progressive Mode
   int extractedLevel = ExtractGridLevelFromComment(comment, "_GP#");
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   
   // v2.3.0: For Progressive Mode, use HIGHEST level's price
   if(extractedLevel > g_pairs[i].maxGridProfitBuyLevel)
   {
      g_pairs[i].maxGridProfitBuyLevel = extractedLevel;
      g_pairs[i].lastProfitPriceBuy = openPrice;
      
      if(InpDebugMode)
      {
         PrintFormat("[v2.3.0 RESTORE] Pair %d GP_BUY: Level %d price=%.5f (MaxLevel=%d)",
                     i + 1, extractedLevel, openPrice, g_pairs[i].maxGridProfitBuyLevel);
      }
   }
   else if(g_pairs[i].lastProfitPriceBuy == 0 || openPrice > g_pairs[i].lastProfitPriceBuy)
   {
      // Fallback for old comment format
      g_pairs[i].lastProfitPriceBuy = openPrice;
   }
```

---

### Part I: แก้ไข RestoreOpenPositions() - Grid Loss SELL

**ตำแหน่ง:** ประมาณบรรทัด 1860-1880 (ส่วน Grid Loss SELL)

**เพิ่มเช่นเดียวกับ BUY แต่:**
```cpp
// v2.3.0: For SELL, Grid Loss is HIGHEST price
if(extractedLevel > g_pairs[i].maxGridLossSellLevel)
{
   g_pairs[i].maxGridLossSellLevel = extractedLevel;
   g_pairs[i].lastAvgPriceSell = openPrice;
}
else if(g_pairs[i].lastAvgPriceSell == 0 || openPrice > g_pairs[i].lastAvgPriceSell)
{
   // Fallback
   g_pairs[i].lastAvgPriceSell = openPrice;
}
```

---

### Part J: แก้ไข RestoreOpenPositions() - Grid Profit SELL

**ตำแหน่ง:** ประมาณบรรทัด 1880-1900 (ส่วน Grid Profit SELL)

```cpp
// v2.3.0: For SELL, Grid Profit is LOWEST price
if(extractedLevel > g_pairs[i].maxGridProfitSellLevel)
{
   g_pairs[i].maxGridProfitSellLevel = extractedLevel;
   g_pairs[i].lastProfitPriceSell = openPrice;
}
else if(g_pairs[i].lastProfitPriceSell == 0 || openPrice < g_pairs[i].lastProfitPriceSell)
{
   // Fallback
   g_pairs[i].lastProfitPriceSell = openPrice;
}
```

---

### Part K: เพิ่ม Correlation Type Filter ใน Entry Logic

**ตำแหน่ง 1:** ใน `ENTRY_MODE_CORRELATION_ONLY` block (~บรรทัด 6013)

```cpp
if(InpEntryMode == ENTRY_MODE_CORRELATION_ONLY)
{
   bool debugLog = InpDebugMode && (!g_isTesterMode || !InpDisableDebugInTester);
   
   // v2.2.8: Check Correlation Type Filter FIRST
   if(!CheckCorrelationTypeFilter(i))
   {
      if(debugLog)
      {
         string filterName = (InpCorrTypeFilter == CORR_FILTER_POSITIVE_ONLY) ? "Positive Only" : "Negative Only";
         string corrTypeName = (g_pairs[i].correlationType == 1) ? "Positive" : "Negative";
         PrintFormat("[CORR FILTER] Pair %d %s/%s: SKIP - %s filter blocked %s pair",
                     i + 1, g_pairs[i].symbolA, g_pairs[i].symbolB, filterName, corrTypeName);
      }
      continue;
   }
   
   // ... existing Correlation Only logic ...
```

**ตำแหน่ง 2:** ใน `ENTRY_MODE_ZSCORE` block (~บรรทัด 6185)

```cpp
// v2.2.8: Check Correlation Type Filter for Z-Score Mode
if(!CheckCorrelationTypeFilter(i))
{
   if(InpDebugMode && (!g_isTesterMode || !InpDisableDebugInTester))
   {
      string filterName = (InpCorrTypeFilter == CORR_FILTER_POSITIVE_ONLY) ? "Positive Only" : "Negative Only";
      string corrTypeName = (g_pairs[i].correlationType == 1) ? "Positive" : "Negative";
      PrintFormat("[Z-SCORE] Pair %d %s/%s: SKIP - %s filter blocked %s pair",
                  i + 1, g_pairs[i].symbolA, g_pairs[i].symbolB, filterName, corrTypeName);
   }
   continue;  // Skip this pair entirely
}

// === BUY SIDE ENTRY (Z-SCORE MODE) ===
```

---

### Part L: Reset Max Level ใน ResetPairState()

**ตำแหน่ง:** ในฟังก์ชัน `ResetPairState()`

```cpp
   // v2.3.0: Reset max grid levels
   g_pairs[index].maxGridLossBuyLevel = 0;
   g_pairs[index].maxGridLossSellLevel = 0;
   g_pairs[index].maxGridProfitBuyLevel = 0;
   g_pairs[index].maxGridProfitSellLevel = 0;
```

---

### สรุปไฟล์ที่แก้ไข

| ไฟล์ | ส่วนที่แก้ไข | รายละเอียด |
|------|-------------|------------|
| `Harmony_Dream_EA.mq5` | Version | อัปเดตเป็น v2.30 |
| `Harmony_Dream_EA.mq5` | Enums | เพิ่ม `ENUM_CORR_TYPE_FILTER` |
| `Harmony_Dream_EA.mq5` | Inputs | เพิ่ม `InpCorrTypeFilter` |
| `Harmony_Dream_EA.mq5` | PairInfo struct | เพิ่ม `maxGridLoss/ProfitBuy/SellLevel` |
| `Harmony_Dream_EA.mq5` | Helper Functions | เพิ่ม `CheckCorrelationTypeFilter()` และ `ExtractGridLevelFromComment()` |
| `Harmony_Dream_EA.mq5` | `RestoreOpenPositions()` | ใช้ Grid Level สูงสุดในการ restore lastAvgPrice |
| `Harmony_Dream_EA.mq5` | Entry Logic | เพิ่ม Correlation Type Filter check |
| `Harmony_Dream_EA.mq5` | `ResetPairState()` | Reset max level |

---

### ผลที่คาดหวังหลังแก้ไข

| ปัญหา | ก่อนแก้ | หลังแก้ |
|-------|---------|---------|
| Correlation Type Filter | ไม่มี | มีตัวเลือก Both/Positive Only/Negative Only |
| Progressive Mode Restore | ใช้ราคาต่ำ/สูงสุด | ใช้ราคาของ Grid Level สูงสุด |
| Grid Distance หลัง restart | อาจคำนวณผิด | ตรงกับสถานะจริง |
| Backtest/Live Parity | อาจต่างกัน | เหมือนกัน |

---

### ตัวอย่างการทำงาน Progressive Mode หลังแก้ไข

**สถานการณ์:** มี GL#1, GL#3 เปิดอยู่ (GL#2 ถูกปิดไปแล้ว)

| ก่อน v2.3.0 | หลัง v2.3.0 |
|-------------|-------------|
| `avgOrderCountBuy = 2` | `avgOrderCountBuy = 2` |
| `lastAvgPriceBuy = ราคา GL#1` (ต่ำสุด) | `lastAvgPriceBuy = ราคา GL#3` (Level สูงสุด) |
| Distance ถัดไป = base × 2^2 | Distance ถัดไป = base × 2^2 |
| **ปัญหา:** ระยะวัดจาก GL#1 | **แก้ไข:** ระยะวัดจาก GL#3 (ถูกต้อง) |

---

### หมายเหตุสำคัญ

1. **Default = Both**: Correlation Type Filter ค่าเริ่มต้นเป็น "Both" เพื่อให้ระบบทำงานเหมือนเดิม
2. **Backward Compatible**: ถ้า Comment ไม่มี Level number (format เก่า) จะ fallback ไปใช้ logic เดิม (ราคาต่ำ/สูงสุด)
3. **Debug Logs**: มี log แจ้งเตือนเมื่อ Correlation Filter block คู่และเมื่อ restore Grid Level
4. **Minimum Distance**: แนะนำให้เพิ่ม Minimum Grid Distance เป็น 30-50 pips สำหรับ Forex เพื่อลดความถี่ของ Grid orders
