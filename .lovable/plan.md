

## แผนอัปเดต Harmony Dream EA v2.2.8

---

### ฟีเจอร์ใหม่ 2 รายการ

| ฟีเจอร์ | คำอธิบาย |
|---------|----------|
| **1. Correlation Type Filter** | เลือกเทรดเฉพาะ Positive Only, Negative Only หรือ Both |
| **2. Fast Backtest Chart Mode** | เปลี่ยน chart เป็น Candlestick สำหรับ Strategy Tester Visualization |

---

### Part A: อัปเดต Version

**ไฟล์:** `public/docs/mql5/Harmony_Dream_EA.mq5`  
**บรรทัด:** 7, 10

```cpp
#property version   "2.28"
#property description "v2.2.8: Add Correlation Type Filter + Candlestick Chart Mode for Backtest"
```

---

### Part B: เพิ่ม Enum สำหรับ Correlation Type Filter

**ไฟล์:** `public/docs/mql5/Harmony_Dream_EA.mq5`  
**ตำแหน่ง:** หลังบรรทัด 260 (หลัง ENUM_ENTRY_MODE)

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

### Part C: เพิ่ม Enum สำหรับ Chart Mode (Backtest)

**ไฟล์:** `public/docs/mql5/Harmony_Dream_EA.mq5`  
**ตำแหน่ง:** หลัง ENUM_CORR_TYPE_FILTER

```cpp
//+------------------------------------------------------------------+
//| BACKTEST CHART MODE ENUM (v2.2.8)                                  |
//+------------------------------------------------------------------+
enum ENUM_BACKTEST_CHART_MODE
{
   BACKTEST_CHART_DEFAULT = 0,    // Default (No Change)
   BACKTEST_CHART_CANDLES,        // Candlestick
   BACKTEST_CHART_BARS,           // Bars
   BACKTEST_CHART_LINE            // Line
};
```

---

### Part D: เพิ่ม Input Parameters

**ไฟล์:** `public/docs/mql5/Harmony_Dream_EA.mq5`  
**ตำแหน่ง:** บรรทัด 657 (ใน group "Entry Mode Settings")

```cpp
input group "=== Entry Mode Settings (v1.8.8) ==="
input ENUM_ENTRY_MODE InpEntryMode = ENTRY_MODE_ZSCORE;    // Entry Mode
input ENUM_CORR_TYPE_FILTER InpCorrTypeFilter = CORR_FILTER_BOTH;  // v2.2.8: Correlation Type Filter
input double   InpCorrOnlyPositiveThreshold = 0.60;        // Correlation Only: Positive Threshold (0.60 = 60%)
input double   InpCorrOnlyNegativeThreshold = -0.60;       // Correlation Only: Negative Threshold (-0.60 = -60%)
```

**เพิ่มใน group "Fast Backtest Mode" (~บรรทัด 245):**
```cpp
input group "=== Fast Backtest Mode (v3.2.5) ==="
input bool     InpFastBacktest = false;           // Enable Fast Backtest Mode
input int      InpBacktestUiUpdateSec = 5;        // UI Update Interval (seconds) in Tester
input bool     InpDisableDashboardInTester = false;  // Disable Dashboard in Tester
input bool     InpDisableDebugInTester = true;    // Disable Debug Logs in Tester
input bool     InpSkipADXChartInTester = true;    // Skip ADX Chart Rendering in Tester
input bool     InpSkipATRInTester = false;        // Skip ATR Indicator in Tester
input ENUM_BACKTEST_CHART_MODE InpBacktestChartMode = BACKTEST_CHART_CANDLES;  // v2.2.8: Backtest Chart Mode
```

---

### Part E: สร้างฟังก์ชัน Helper - CheckCorrelationTypeFilter

**ไฟล์:** `public/docs/mql5/Harmony_Dream_EA.mq5`  
**ตำแหน่ง:** หลัง `CheckCorrelationOnlyEntry()` (~บรรทัด 5815)

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

### Part F: เพิ่มฟังก์ชัน SetBacktestChartMode

**ไฟล์:** `public/docs/mql5/Harmony_Dream_EA.mq5`  
**ตำแหน่ง:** ก่อน OnInit()

```cpp
//+------------------------------------------------------------------+
//| Set Chart Mode for Backtest Visualization (v2.2.8)                 |
//+------------------------------------------------------------------+
void SetBacktestChartMode()
{
   // Only apply in tester mode
   if(!MQLInfoInteger(MQL_TESTER)) return;
   
   // Skip if default (no change)
   if(InpBacktestChartMode == BACKTEST_CHART_DEFAULT) return;
   
   // Map to MT5 CHART_MODE values
   ENUM_CHART_MODE chartMode;
   switch(InpBacktestChartMode)
   {
      case BACKTEST_CHART_CANDLES:
         chartMode = CHART_CANDLES;
         break;
      case BACKTEST_CHART_BARS:
         chartMode = CHART_BARS;
         break;
      case BACKTEST_CHART_LINE:
         chartMode = CHART_LINE;
         break;
      default:
         return;
   }
   
   // Apply to current chart
   ChartSetInteger(0, CHART_MODE, chartMode);
   ChartRedraw(0);
   
   Print("[v2.2.8] Backtest Chart Mode set to: ", EnumToString(chartMode));
}
```

---

### Part G: เรียก SetBacktestChartMode ใน OnInit

**ไฟล์:** `public/docs/mql5/Harmony_Dream_EA.mq5`  
**ตำแหน่ง:** บรรทัด ~1125 (หลังจาก tester mode detection)

```cpp
// Detect tester mode first
g_isTesterMode = (bool)MQLInfoInteger(MQL_TESTER);

// v2.2.8: Set chart mode for backtest visualization
if(g_isTesterMode)
{
   SetBacktestChartMode();
}

// v3.2.5: Configure dashboard based on tester mode
if(g_isTesterMode)
{
```

---

### Part H: อัปเดต Correlation Only Mode Entry Logic

**ไฟล์:** `public/docs/mql5/Harmony_Dream_EA.mq5`  
**ตำแหน่ง:** บรรทัด ~6002-6027 (ใน `ENTRY_MODE_CORRELATION_ONLY` block)

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
         string reason = StringFormat("SKIP - Corr Type Filter (%s) blocked %s pair", filterName, corrTypeName);
         datetime now = TimeCurrent();
         if(g_firstAnalyzeRun || reason != g_pairs[i].lastBlockReason || 
            now - g_pairs[i].lastBlockLogTime >= DEBUG_LOG_INTERVAL)
         {
            PrintFormat("[CORR ONLY] Pair %d %s/%s: %s",
                        i + 1, g_pairs[i].symbolA, g_pairs[i].symbolB, reason);
            g_pairs[i].lastBlockReason = reason;
            g_pairs[i].lastBlockLogTime = now;
         }
      }
      continue;
   }
   
   // Step 1: Check Correlation Threshold
   if(!CheckCorrelationOnlyEntry(i))
   {
   // ... existing code continues
```

---

### Part I: อัปเดต Z-Score Mode Entry Logic

**ไฟล์:** `public/docs/mql5/Harmony_Dream_EA.mq5`  
**ตำแหน่ง:** บรรทัด ~6185-6190 (ก่อน BUY SIDE ENTRY Z-Score)

```cpp
// ================================================================
// ORIGINAL Z-SCORE MODE (unchanged)
// ================================================================

// v2.2.8: Check Correlation Type Filter for Z-Score Mode
if(!CheckCorrelationTypeFilter(i))
{
   if(InpDebugMode && (!g_isTesterMode || !InpDisableDebugInTester))
   {
      string filterName = (InpCorrTypeFilter == CORR_FILTER_POSITIVE_ONLY) ? "Positive Only" : "Negative Only";
      string corrTypeName = (g_pairs[i].correlationType == 1) ? "Positive" : "Negative";
      string reason = StringFormat("SKIP - Corr Type Filter (%s) blocked %s pair", filterName, corrTypeName);
      datetime now = TimeCurrent();
      if(g_firstAnalyzeRun || reason != g_pairs[i].lastBlockReason || 
         now - g_pairs[i].lastBlockLogTime >= DEBUG_LOG_INTERVAL)
      {
         PrintFormat("[Z-SCORE] Pair %d %s/%s: %s",
                     i + 1, g_pairs[i].symbolA, g_pairs[i].symbolB, reason);
         g_pairs[i].lastBlockReason = reason;
         g_pairs[i].lastBlockLogTime = now;
      }
   }
   continue;  // Skip this pair entirely
}

// === BUY SIDE ENTRY (Z-SCORE MODE) ===
```

---

### สรุปไฟล์ที่แก้ไข

| ไฟล์ | ส่วนที่แก้ไข | รายละเอียด |
|------|-------------|------------|
| `Harmony_Dream_EA.mq5` | Version | อัปเดตเป็น v2.28 |
| `Harmony_Dream_EA.mq5` | Enums | เพิ่ม `ENUM_CORR_TYPE_FILTER` และ `ENUM_BACKTEST_CHART_MODE` |
| `Harmony_Dream_EA.mq5` | Inputs | เพิ่ม `InpCorrTypeFilter` และ `InpBacktestChartMode` |
| `Harmony_Dream_EA.mq5` | Functions | เพิ่ม `CheckCorrelationTypeFilter()` และ `SetBacktestChartMode()` |
| `Harmony_Dream_EA.mq5` | OnInit | เรียก `SetBacktestChartMode()` |
| `Harmony_Dream_EA.mq5` | Entry Logic | เพิ่ม filter check ใน Correlation Only และ Z-Score mode |

---

### ผลลัพธ์ที่คาดหวัง

| ฟีเจอร์ | ค่าเริ่มต้น | พฤติกรรม |
|---------|------------|----------|
| **Correlation Type Filter** | Both | เทรดทุกคู่ (เหมือนเดิม) |
| | Positive Only | เทรดเฉพาะ Positive Correlation pairs |
| | Negative Only | เทรดเฉพาะ Negative Correlation pairs |
| **Backtest Chart Mode** | Candlestick | แสดง chart แบบ candlestick ใน Strategy Tester |
| | Bars | แสดง chart แบบ bars |
| | Line | แสดง chart แบบ line |
| | Default | ไม่เปลี่ยนแปลง |

---

### ตัวอย่างการใช้งาน Correlation Type Filter

```text
ตัวอย่าง 1: ตั้ง "Positive Only"
- Pair 1 (EURUSD/GBPUSD): Corr = +0.85 → Positive → เทรด
- Pair 2 (EURUSD/USDCHF): Corr = -0.72 → Negative → ข้าม
- Pair 3 (AUDUSD/NZDUSD): Corr = +0.91 → Positive → เทรด

ตัวอย่าง 2: ตั้ง "Negative Only"
- Pair 1 (EURUSD/GBPUSD): Corr = +0.85 → Positive → ข้าม
- Pair 2 (EURUSD/USDCHF): Corr = -0.72 → Negative → เทรด
- Pair 3 (XAUUSD/USDX): Corr = -0.65 → Negative → เทรด
```

---

### หมายเหตุ

- ทั้งสองฟีเจอร์ทำงานร่วมกับ v2.2.7 (Grid ATR Fix) ได้สมบูรณ์
- Backtest Chart Mode จะเปลี่ยนแปลงเฉพาะใน Strategy Tester เท่านั้น ไม่กระทบ Live Trading
- Correlation Type Filter ทำงานกับทั้ง Z-Score Mode และ Correlation Only Mode
- มี Debug Log แจ้งเตือนเมื่อคู่ถูก skip เนื่องจาก filter

