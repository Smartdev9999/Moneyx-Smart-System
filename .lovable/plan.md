

## Gold Miner EA v3.0 - เพิ่ม Multi-Timeframe ZigZag Entry + CDC Trend Filter

### สรุปฟีเจอร์

1. **Entry Mode เลือกได้**: SMA (เดิม) หรือ ZigZag Multi-Timeframe (ใหม่)
2. **ZigZag MTF Logic**: H4 เป็น confirm direction → M30/M15/M5 เป็น execution (แต่ละ TF มี initial order แยกกัน)
3. **แยก Grid/TP/SL ต่อ TF**: แต่ละ sub-TF มี grid, TP/SL, trailing แยกกัน แต่ใช้ค่า setting ชุดเดียวกัน
4. **Accumulate รวม**: ทุก TF สะสมรวมกันเพื่อปิดรวบ
5. **CDC Action Zone**: trend filter กรองทิศทางก่อนเปิดออเดอร์

### ไฟล์ที่แก้ไข

`public/docs/mql5/Gold_Miner_EA.mq5` (ไฟล์เดียว)

---

### สถาปัตยกรรม

```text
Entry Mode Selection (input)
├── SMA Mode (เดิม - ไม่แตะ)
│   └── SMA 20 → BUY/SELL entry (เดิมทั้งหมด)
└── ZigZag MTF Mode (ใหม่)
    ├── CDC Trend Filter (optional) → BULLISH/BEARISH/NEUTRAL
    ├── H4 ZigZag Confirm → Swing Low = BUY direction, Swing High = SELL direction
    └── Sub-TF Execution (M30, M15, M5 - เลือกเปิด/ปิดได้)
        ├── M30: ZigZag confirm same direction → GM_M30_INIT / GM_M30_GL# / GM_M30_GP#
        ├── M15: ZigZag confirm same direction → GM_M15_INIT / GM_M15_GL# / GM_M15_GP#
        └── M5:  ZigZag confirm same direction → GM_M5_INIT  / GM_M5_GL#  / GM_M5_GP#
        
TP/SL/Trailing → แยกต่อ TF (ใช้ setting ชุดเดียวกัน)
Accumulate → รวมทุก TF
```

---

### 1. เพิ่ม Enums

```text
enum ENUM_ENTRY_MODE
{
   ENTRY_SMA      = 0,  // SMA Mode (Original)
   ENTRY_ZIGZAG   = 1   // ZigZag Multi-Timeframe Mode
};
```

### 2. เพิ่ม Input Parameters

```text
input group "=== Entry Mode ==="
input ENUM_ENTRY_MODE  EntryMode = ENTRY_SMA;  // Entry Mode

input group "=== ZigZag Multi-Timeframe Settings ==="
input int      ZZ_Depth       = 12;          // ZigZag Depth
input int      ZZ_Deviation   = 5;           // ZigZag Deviation
input int      ZZ_Backstep    = 3;           // ZigZag Backstep
input ENUM_TIMEFRAMES ZZ_ConfirmTF = PERIOD_H4;   // Confirm Timeframe (H4)
input bool     ZZ_UseM30      = true;        // Use M30 for Entry
input bool     ZZ_UseM15      = true;        // Use M15 for Entry
input bool     ZZ_UseM5       = false;       // Use M5 for Entry
input bool     ZZ_UseConfirmTFEntry = false; // Also Enter on Confirm TF directly

input group "=== CDC Action Zone Trend Filter ==="
input bool     InpUseCDCFilter     = false;          // Enable CDC Trend Filter
input ENUM_TIMEFRAMES InpCDCTimeframe = PERIOD_D1;   // CDC Timeframe
input int      InpCDCFastPeriod    = 12;             // CDC Fast EMA Period
input int      InpCDCSlowPeriod    = 26;             // CDC Slow EMA Period
input bool     InpCDCRequireCross  = false;          // Require Crossover (not just position)
```

### 3. Per-TF State Struct + Globals

```text
struct TFState
{
   ENUM_TIMEFRAMES tf;
   string          tfLabel;        // "M30", "M15", "M5", "H4"
   bool            enabled;
   int             handleZZ;       // iCustom handle for ZigZag
   double          lastSwingPrice; // Last confirmed swing price
   string          lastSwingType;  // "HIGH" or "LOW"
   datetime        lastSwingTime;  // Time of last confirmed swing
   double          initialBuyPrice;
   double          initialSellPrice;
   datetime        lastInitialCandle;
   datetime        lastGridLossCandle;
   datetime        lastGridProfitCandle;
   bool            justClosedBuy;
   bool            justClosedSell;
   // Per-TF trailing state
   double          trailSL_Buy;
   double          trailSL_Sell;
   bool            trailActive_Buy;
   bool            trailActive_Sell;
   bool            beDone_Buy;
   bool            beDone_Sell;
};

#define MAX_SUB_TF 4  // H4, M30, M15, M5

TFState g_tfStates[MAX_SUB_TF];
int     g_activeTFCount = 0;

// H4 direction
string  g_h4Direction = "NONE";  // "BUY", "SELL", "NONE"

// CDC state
string  g_cdcTrend = "NEUTRAL";  // "BULLISH", "BEARISH", "NEUTRAL"
double  g_cdcFast = 0, g_cdcSlow = 0;
bool    g_cdcReady = false;
datetime g_lastCdcCandle = 0;
```

### 4. OnInit() - เพิ่ม ZigZag handles + CDC init

- สร้าง iCustom handle สำหรับ ZigZag แต่ละ TF ที่เปิดใช้
- ใช้ `iCustom(_Symbol, tf, "Examples\\ZigZag", ZZ_Depth, ZZ_Deviation, ZZ_Backstep)` (ZigZag มาตรฐาน MT5)
- Init CDC (port `CalculateCDC_EMA` + `CalculateCDCForSymbol` จาก Harmony Dream แต่ simplified สำหรับ single symbol)

### 5. ZigZag Signal Detection Function

```text
// Detect latest ZigZag swing on a specific TF
// Returns: "LOW" (buy signal), "HIGH" (sell signal), "NONE"
string DetectZigZagSwing(int tfIndex)
{
   double zzBuf[];
   ArraySetAsSeries(zzBuf, true);
   if(CopyBuffer(g_tfStates[tfIndex].handleZZ, 0, 0, 100, zzBuf) < 100)
      return "NONE";
   
   // Find first non-zero value (latest swing point)
   for(int i = 1; i < 100; i++)
   {
      if(zzBuf[i] != 0.0)
      {
         double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         // If swing is below current price = Swing Low = BUY
         // If swing is above current price = Swing High = SELL
         if(zzBuf[i] < price)
         {
            g_tfStates[tfIndex].lastSwingPrice = zzBuf[i];
            g_tfStates[tfIndex].lastSwingType = "LOW";
            g_tfStates[tfIndex].lastSwingTime = iTime(_Symbol, g_tfStates[tfIndex].tf, i);
            return "LOW";
         }
         else
         {
            g_tfStates[tfIndex].lastSwingPrice = zzBuf[i];
            g_tfStates[tfIndex].lastSwingType = "HIGH";
            g_tfStates[tfIndex].lastSwingTime = iTime(_Symbol, g_tfStates[tfIndex].tf, i);
            return "HIGH";
         }
      }
   }
   return "NONE";
}
```

### 6. CDC Functions (port จาก Harmony Dream)

Port 3 functions:
- `CalculateCDC_EMA()` - EMA helper (คัดลอกจาก Harmony Dream บรรทัด 5448-5463)
- `CalculateCDC()` - simplified สำหรับ single symbol (ดัดแปลงจาก `CalculateCDCForSymbol`)
- `UpdateCDC()` - เรียกใน OnTick เมื่อมีแท่งเทียนใหม่ของ CDC TF

### 7. OnTick() - ZigZag MTF Logic

เพิ่ม block ใหม่ภายใต้ `if(EntryMode == ENTRY_ZIGZAG)`:

```text
// === ZigZag MTF Mode ===
if(EntryMode == ENTRY_ZIGZAG)
{
   // Step 1: Update CDC (if enabled)
   if(InpUseCDCFilter) UpdateCDC();
   
   // Step 2: Check H4 ZigZag direction
   // (only recalculate on new H4 bar)
   string h4Swing = DetectZigZagSwing(h4Index);
   if(h4Swing == "LOW") g_h4Direction = "BUY";
   else if(h4Swing == "HIGH") g_h4Direction = "SELL";
   
   // Step 3: CDC filter check
   if(InpUseCDCFilter && g_cdcReady)
   {
      if(g_h4Direction == "BUY" && g_cdcTrend == "BEARISH") g_h4Direction = "NONE";
      if(g_h4Direction == "SELL" && g_cdcTrend == "BULLISH") g_h4Direction = "NONE";
   }
   
   // Step 4: For each enabled sub-TF
   for(int t = 0; t < g_activeTFCount; t++)
   {
      if(!g_tfStates[t].enabled) continue;
      
      // Check new bar for this TF
      datetime tfBar = iTime(_Symbol, g_tfStates[t].tf, 0);
      
      // Per-TF position counting (by comment prefix)
      int buyCount, sellCount, glBuy, glSell, gpBuy, gpSell;
      bool hasInitBuy, hasInitSell;
      CountPositionsTF(t, buyCount, sellCount, ...);
      
      // Per-TF Grid management
      if(!g_newOrderBlocked)
      {
         CheckGridLossTF(t, ...);
         CheckGridProfitTF(t, ...);
      }
      
      // Per-TF TP/SL management
      ManageTPSL_TF(t);
      
      // Per-TF trailing
      ManageTrailing_TF(t);
      
      // Entry: check sub-TF ZigZag agrees with H4
      if(!g_newOrderBlocked && g_h4Direction != "NONE")
      {
         string subSwing = DetectZigZagSwing(t);
         if(g_h4Direction == "BUY" && subSwing == "LOW" && buyCount == 0)
            OpenOrderTF(t, ORDER_TYPE_BUY, InitialLotSize);
         if(g_h4Direction == "SELL" && subSwing == "HIGH" && sellCount == 0)
            OpenOrderTF(t, ORDER_TYPE_SELL, InitialLotSize);
      }
   }
   
   // Accumulate (shared) - uses ALL positions across all TFs
   // (existing Accumulate logic works as-is because it checks MagicNumber)
}
```

### 8. Per-TF Position Management Functions

ฟังก์ชันใหม่ที่ต้องสร้าง (ดัดแปลงจากฟังก์ชันเดิม แต่ filter ด้วย comment prefix):

| Function | ทำอะไร |
|----------|--------|
| `CountPositionsTF(int tfIdx, ...)` | นับ positions โดย filter comment "GM_M30_", "GM_M15_" etc. |
| `OpenOrderTF(int tfIdx, type, lots)` | เปิด order ด้วย comment prefix ตาม TF |
| `CheckGridLossTF(int tfIdx, ...)` | Grid Loss logic แยก TF (ใช้ setting เดียวกัน) |
| `CheckGridProfitTF(int tfIdx, ...)` | Grid Profit logic แยก TF |
| `ManageTPSL_TF(int tfIdx)` | TP/SL basket แยก TF |
| `ManageTrailing_TF(int tfIdx)` | Trailing/Breakeven แยก TF |
| `CloseAllSideTF(int tfIdx, side)` | ปิด positions ของ TF + side นั้น |
| `FindLastOrderTF(int tfIdx, ...)` | หา last order ของ TF นั้น |
| `CalculateAveragePriceTF(int tfIdx, side)` | Average price แยก TF |
| `CalculateFloatingPL_TF(int tfIdx, side)` | Floating PL แยก TF |

### 9. Comment Convention

| TF | Initial | Grid Loss | Grid Profit |
|----|---------|-----------|-------------|
| H4 | GM_H4_INIT | GM_H4_GL#1 | GM_H4_GP#1 |
| M30 | GM_M30_INIT | GM_M30_GL#1 | GM_M30_GP#1 |
| M15 | GM_M15_INIT | GM_M15_GL#1 | GM_M15_GP#1 |
| M5 | GM_M5_INIT | GM_M5_GL#1 | GM_M5_GP#1 |

**SMA Mode เดิม**: ยังใช้ "GM_INIT", "GM_GL#", "GM_GP#" เหมือนเดิม (ไม่แตะ)

### 10. Dashboard Update

เพิ่มแถวแสดงผล:
- Entry Mode: SMA / ZigZag MTF
- CDC Trend: BULLISH/BEARISH/NEUTRAL (ถ้าเปิดใช้)
- H4 Direction: BUY / SELL / NONE
- แต่ละ Sub-TF: M30 [2B/1S] | M15 [0B/3S] | M5 [OFF]

### 11. OnDeinit Cleanup

เพิ่มลบ ZigZag handles (`IndicatorRelease`) และ CDC-related objects

---

### ขนาดโดยประมาณ

| ส่วน | บรรทัด |
|------|--------|
| Enums + Inputs + Struct + Globals | ~80 |
| OnInit (ZZ handles + CDC) | ~60 |
| CDC functions (port) | ~100 |
| ZigZag detection | ~40 |
| Per-TF management functions (10 functions) | ~350 |
| OnTick ZigZag MTF block | ~80 |
| Dashboard additions | ~30 |
| OnDeinit cleanup | ~15 |
| **รวม** | **~750 บรรทัด** |

---

### สิ่งที่ไม่เปลี่ยนแปลง (ยืนยัน 100% ตามกฎเหล็ก)

- **SMA Mode ทั้งหมด**: entry logic เดิม (บรรทัด 775-851) ไม่แตะเลย -- ทำงานเหมือนเดิมเมื่อ `EntryMode == ENTRY_SMA`
- **Order Execution**: `OpenOrder()`, `trade.Buy()`, `trade.Sell()`, `trade.PositionClose()` ไม่แตะ
- **Grid Logic**: `CheckGridLoss()`, `CheckGridProfit()`, `GetGridDistance()`, `CalculateGridLot()` ไม่แตะ (ฟังก์ชัน TF ใหม่จะ **เรียกใช้** logic เดียวกันนี้)
- **TP/SL/Trailing calculations**: `ManageTPSL()`, `ManageTrailingStop()`, `ManagePerOrderTrailing()` ไม่แตะ
- **Accumulate Close**: ไม่แตะ (ใช้ร่วมกันทุก TF เพราะ filter ด้วย MagicNumber อยู่แล้ว)
- **Drawdown Exit**: ไม่แตะ
- **License / News Filter / Time Filter**: ไม่แตะ
- **shouldEnterBuy / shouldEnterSell**: ไม่แตะ (ใช้ใน SMA mode เท่านั้น)

### หมายเหตุสำคัญ

เนื่องจากฟีเจอร์นี้เพิ่มโค้ดประมาณ 750 บรรทัด ไฟล์จะขยายจาก ~4000 เป็น ~4750 บรรทัด โค้ดใหม่ทั้งหมดอยู่ใน **block แยก** ภายใต้ `EntryMode == ENTRY_ZIGZAG` เท่านั้น ไม่กระทบการทำงานของ SMA mode เดิมแม้แต่บรรทัดเดียว

