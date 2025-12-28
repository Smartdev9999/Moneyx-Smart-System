import { Link } from 'react-router-dom';
import { ArrowLeft, Download, FileCode, Info, Eye, Settings, TrendingUp } from 'lucide-react';
import CodeBlock from '@/components/CodeBlock';
import StepCard from '@/components/StepCard';

const MT5IndicatorGuide = () => {
  const fullIndicatorCode = `//+------------------------------------------------------------------+
//|                   Moneyx Smart Indicator v2.0                    |
//|         Combined: EMA, Bollinger, ZigZag, PA, CDC, SMC           |
//|         + EA Integration via Global Variables                     |
//+------------------------------------------------------------------+
#property copyright "MoneyX Trading"
#property link      ""
#property version   "2.00"
#property indicator_chart_window
#property indicator_buffers 15
#property indicator_plots   12

//+------------------------------------------------------------------+
//| ======================= ENUMERATIONS =========================== |
//+------------------------------------------------------------------+

// Bollinger Bands MA Type
enum ENUM_BB_MA_TYPE
{
   BB_MA_SMA = 0,    // SMA
   BB_MA_EMA = 1,    // EMA
   BB_MA_SMMA = 2,   // SMMA (RMA)
   BB_MA_WMA = 3     // WMA
};

// ZigZag Display Mode
enum ENUM_ZIGZAG_MODE
{
   ZZ_LINES_ONLY = 0,     // Lines Only
   ZZ_LABELS_ONLY = 1,    // Labels Only
   ZZ_BOTH = 2            // Lines and Labels
};

// Price Action Pattern Type
enum ENUM_PA_PATTERN
{
   PA_BULLISH = 1,   // Bullish Pattern
   PA_BEARISH = -1,  // Bearish Pattern
   PA_NEUTRAL = 0    // No Pattern
};

// PA Display Mode
enum ENUM_PA_MODE
{
   PA_MODE_ALL = 0,        // Show All PA Patterns
   PA_MODE_EA_ONLY = 1     // Show Only EA Trade Signals (via Global Variables)
};

//+------------------------------------------------------------------+
//| ===================== INPUT PARAMETERS ========================= |
//+------------------------------------------------------------------+

//--- [ INDICATOR VISIBILITY SETTINGS ] -----------------------------
input string   InpVisibilityHeader = "=== INDICATOR VISIBILITY ===";  // ___
input bool     InpShowEMA = true;              // Show EMA Lines
input bool     InpShowBollinger = true;        // Show Bollinger Bands
input bool     InpShowZigZag = true;           // Show ZigZag Indicator
input bool     InpShowPA = true;               // Show Price Action Patterns
input bool     InpShowCDC = true;              // Show CDC Action Zone
input bool     InpShowSMC = true;              // Show SMC Order Blocks

//--- [ EMA SETTINGS ] ----------------------------------------------
input string   InpEMAHeader = "=== EMA SETTINGS ===";  // ___
input int      InpEMA1Period = 20;             // EMA 1 Period
input int      InpEMA2Period = 50;             // EMA 2 Period
input int      InpEMA3Period = 200;            // EMA 3 Period
input color    InpEMA1Color = clrDodgerBlue;   // EMA 1 Color
input color    InpEMA2Color = clrOrange;       // EMA 2 Color
input color    InpEMA3Color = clrMagenta;      // EMA 3 Color
input int      InpEMAWidth = 2;                // EMA Line Width
input ENUM_APPLIED_PRICE InpEMAPrice = PRICE_CLOSE;  // EMA Applied Price

//--- [ BOLLINGER BANDS SETTINGS ] ----------------------------------
input string   InpBBHeader = "=== BOLLINGER BANDS SETTINGS ===";  // ___
input int      InpBBPeriod = 20;               // BB Period (Length)
input double   InpBBDeviation = 2.0;           // BB Deviation (StdDev Multiplier)
input ENUM_BB_MA_TYPE InpBBMAType = BB_MA_SMA; // BB MA Type
input color    InpBBUpperColor = clrRed;       // BB Upper Band Color
input color    InpBBLowerColor = clrGreen;     // BB Lower Band Color
input color    InpBBBasisColor = clrGray;      // BB Basis (Middle) Color
input int      InpBBWidth = 1;                 // BB Line Width
input bool     InpBBFillBands = false;         // Fill Between Bands

//--- [ ZIGZAG SETTINGS ] -------------------------------------------
input string   InpZigZagHeader = "=== ZIGZAG SETTINGS ===";  // ___
input int      InpZZDepth = 12;                // ZigZag Depth
input int      InpZZDeviation = 5;             // ZigZag Deviation (pips)
input int      InpZZBackstep = 3;              // ZigZag Backstep
input color    InpZZBullColor = clrLime;       // Bull Color (HL, HH)
input color    InpZZBearColor = clrRed;        // Bear Color (LH, LL)
input int      InpZZLineWidth = 2;             // ZigZag Line Width
input ENUM_ZIGZAG_MODE InpZZMode = ZZ_BOTH;    // ZigZag Display Mode
input bool     InpZZShowLabels = true;         // Show HH/HL/LH/LL Labels

//--- [ PRICE ACTION SETTINGS ] -------------------------------------
input string   InpPAHeader = "=== PRICE ACTION PATTERNS ===";  // ___

// Bullish Patterns
input bool     InpPAHammer = true;             // Hammer / Pin Bar (Bullish)
input bool     InpPABullEngulfing = true;      // Bullish Engulfing
input bool     InpPATweezerBottom = true;      // Tweezer Bottom
input bool     InpPAMorningStar = true;        // Morning Star (3-Candle)
input bool     InpPAInsideCandleBull = true;   // Inside Candle (Bullish)
input bool     InpPABullHotdog = true;         // Bullish Hotdog Pattern

// Bearish Patterns
input bool     InpPAShootingStar = true;       // Shooting Star (Bearish)
input bool     InpPABearEngulfing = true;      // Bearish Engulfing
input bool     InpPATweezerTop = true;         // Tweezer Top
input bool     InpPAEveningStar = true;        // Evening Star (3-Candle)
input bool     InpPAInsideCandleBear = true;   // Inside Candle (Bearish)
input bool     InpPABearHotdog = true;         // Bearish Hotdog Pattern

// PA Detection Settings
input double   InpPAPinRatio = 2.0;            // Pin Bar Tail/Body Ratio (min)
input double   InpPABodyMinRatio = 0.3;        // Engulfing Body Min Ratio
input color    InpPABullColor = clrLime;       // Bullish Pattern Color
input color    InpPABearColor = clrRed;        // Bearish Pattern Color

//--- [ CDC ACTION ZONE SETTINGS ] ----------------------------------
input string   InpCDCHeader = "=== CDC ACTION ZONE ===";  // ___
input int      InpCDCFastPeriod = 12;          // CDC Fast EMA Period
input int      InpCDCSlowPeriod = 26;          // CDC Slow EMA Period
input color    InpCDCBullColor = clrLime;      // CDC Bull Zone Color
input color    InpCDCBearColor = clrRed;       // CDC Bear Zone Color
input int      InpCDCWidth = 3;                // CDC Line Width
input bool     InpCDCShowHistogram = true;     // Show CDC Histogram

//--- [ SMC ORDER BLOCK SETTINGS ] ----------------------------------
input string   InpSMCHeader = "=== SMC ORDER BLOCKS ===";  // ___
input int      InpSMCSwingLength = 50;         // Swing Detection Length (bars)
input int      InpSMCInternalLength = 5;       // Internal Structure Length
input int      InpSMCMaxOrderBlocks = 5;       // Max Order Blocks to Display
input color    InpSMCBullOBColor = clrDodgerBlue;   // Bullish OB Color (Support)
input color    InpSMCBearOBColor = clrCrimson;      // Bearish OB Color (Resistance)

//--- [ PRICE ACTION / EA INTEGRATION SETTINGS ] --------------------
input string   InpPAModeHeader = "=== PA / EA INTEGRATION ===";  // ___
input ENUM_PA_MODE InpPAMode = PA_MODE_EA_ONLY;  // PA Display Mode
input int      InpEAMagicNumber = 123456;      // EA Magic Number (for signal reading)

//+------------------------------------------------------------------+
//| ===================== INDICATOR BUFFERS ======================== |
//+------------------------------------------------------------------+

// EMA Buffers
double EMA1Buffer[];
double EMA2Buffer[];
double EMA3Buffer[];

// Bollinger Bands Buffers
double BBUpperBuffer[];
double BBMiddleBuffer[];
double BBLowerBuffer[];

// ZigZag Buffer
double ZigZagBuffer[];
double ZigZagHighBuffer[];
double ZigZagLowBuffer[];

// Price Action Buffer
double PAPatternBuffer[];

// CDC Buffers
double CDCFastBuffer[];
double CDCSlowBuffer[];
double CDCHistBuffer[];

// Handle for built-in indicators
int handleEMA1, handleEMA2, handleEMA3;
int handleBB;
int handleCDCFast, handleCDCSlow;

// ZigZag Variables
double lastZigZagHigh = 0;
double lastZigZagLow = 0;
int lastZigZagHighBar = 0;
int lastZigZagLowBar = 0;

// SMC Order Block Structure
struct OrderBlock
{
   double high;
   double low;
   datetime time;
   int barIndex;
   int bias;      // 1 = Bullish (support), -1 = Bearish (resistance)
   bool mitigated;
   string objName;
};

OrderBlock BullishOBs[20];
OrderBlock BearishOBs[20];
int BullishOBCount = 0;
int BearishOBCount = 0;

// SMC Variables
double SMCSwingHigh = 0;
double SMCSwingLow = 0;
datetime SMCSwingHighTime = 0;
datetime SMCSwingLowTime = 0;
int SMCTrend = 0;  // 1 = Bullish, -1 = Bearish, 0 = Neutral

// Object Prefixes
string SMCPrefix = "INDI_SMC_";
string PAPrefix = "INDI_PA_";

// EA Signal Global Variable Names (for communication with EA)
string GV_EA_BUY_SIGNAL = "MONEYX_EA_BUY_SIGNAL";
string GV_EA_SELL_SIGNAL = "MONEYX_EA_SELL_SIGNAL";
string GV_EA_BUY_PA = "MONEYX_EA_BUY_PA";
string GV_EA_SELL_PA = "MONEYX_EA_SELL_PA";
string GV_EA_BUY_TIME = "MONEYX_EA_BUY_TIME";
string GV_EA_SELL_TIME = "MONEYX_EA_SELL_TIME";

// SMC Settings Sync Global Variables (EA writes, Indicator reads)
string GV_SMC_ENABLED = "MONEYX_SMC_ENABLED";
string GV_SMC_SWING_LENGTH = "MONEYX_SMC_SWING_LENGTH";
string GV_SMC_INTERNAL_LENGTH = "MONEYX_SMC_INTERNAL_LENGTH";
string GV_SMC_MAX_OB = "MONEYX_SMC_MAX_OB";
string GV_SMC_BULL_OB_COLOR = "MONEYX_SMC_BULL_OB_COLOR";
string GV_SMC_BEAR_OB_COLOR = "MONEYX_SMC_BEAR_OB_COLOR";

// Synced SMC Settings (overwritten from EA if available)
int SyncedSMCSwingLength = 0;
int SyncedSMCInternalLength = 0;
int SyncedSMCMaxOrderBlocks = 0;
color SyncedSMCBullOBColor = clrDodgerBlue;
color SyncedSMCBearOBColor = clrCrimson;
bool SMCSyncedFromEA = false;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                          |
//+------------------------------------------------------------------+
int OnInit()
{
   // Set indicator short name
   IndicatorSetString(INDICATOR_SHORTNAME, "Moneyx Smart Indicator");
   
   // Initialize buffers index
   int bufferIndex = 0;
   
   //--- EMA Buffers ---
   SetIndexBuffer(bufferIndex++, EMA1Buffer, INDICATOR_DATA);
   SetIndexBuffer(bufferIndex++, EMA2Buffer, INDICATOR_DATA);
   SetIndexBuffer(bufferIndex++, EMA3Buffer, INDICATOR_DATA);
   
   //--- Bollinger Buffers ---
   SetIndexBuffer(bufferIndex++, BBUpperBuffer, INDICATOR_DATA);
   SetIndexBuffer(bufferIndex++, BBMiddleBuffer, INDICATOR_DATA);
   SetIndexBuffer(bufferIndex++, BBLowerBuffer, INDICATOR_DATA);
   
   //--- ZigZag Buffers ---
   SetIndexBuffer(bufferIndex++, ZigZagBuffer, INDICATOR_DATA);
   SetIndexBuffer(bufferIndex++, ZigZagHighBuffer, INDICATOR_CALCULATIONS);
   SetIndexBuffer(bufferIndex++, ZigZagLowBuffer, INDICATOR_CALCULATIONS);
   
   //--- PA Buffer ---
   SetIndexBuffer(bufferIndex++, PAPatternBuffer, INDICATOR_DATA);
   
   //--- CDC Buffers ---
   SetIndexBuffer(bufferIndex++, CDCFastBuffer, INDICATOR_DATA);
   SetIndexBuffer(bufferIndex++, CDCSlowBuffer, INDICATOR_DATA);
   SetIndexBuffer(bufferIndex++, CDCHistBuffer, INDICATOR_DATA);
   
   // Set plot properties
   int plotIndex = 0;
   
   //--- EMA Plots ---
   if(InpShowEMA)
   {
      PlotIndexSetInteger(plotIndex, PLOT_DRAW_TYPE, DRAW_LINE);
      PlotIndexSetInteger(plotIndex, PLOT_LINE_COLOR, InpEMA1Color);
      PlotIndexSetInteger(plotIndex, PLOT_LINE_WIDTH, InpEMAWidth);
      PlotIndexSetString(plotIndex, PLOT_LABEL, "EMA " + IntegerToString(InpEMA1Period));
      plotIndex++;
      
      PlotIndexSetInteger(plotIndex, PLOT_DRAW_TYPE, DRAW_LINE);
      PlotIndexSetInteger(plotIndex, PLOT_LINE_COLOR, InpEMA2Color);
      PlotIndexSetInteger(plotIndex, PLOT_LINE_WIDTH, InpEMAWidth);
      PlotIndexSetString(plotIndex, PLOT_LABEL, "EMA " + IntegerToString(InpEMA2Period));
      plotIndex++;
      
      PlotIndexSetInteger(plotIndex, PLOT_DRAW_TYPE, DRAW_LINE);
      PlotIndexSetInteger(plotIndex, PLOT_LINE_COLOR, InpEMA3Color);
      PlotIndexSetInteger(plotIndex, PLOT_LINE_WIDTH, InpEMAWidth);
      PlotIndexSetString(plotIndex, PLOT_LABEL, "EMA " + IntegerToString(InpEMA3Period));
      plotIndex++;
   }
   else
   {
      PlotIndexSetInteger(0, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetInteger(2, PLOT_DRAW_TYPE, DRAW_NONE);
      plotIndex += 3;
   }
   
   //--- BB Plots ---
   if(InpShowBollinger)
   {
      PlotIndexSetInteger(plotIndex, PLOT_DRAW_TYPE, DRAW_LINE);
      PlotIndexSetInteger(plotIndex, PLOT_LINE_COLOR, InpBBUpperColor);
      PlotIndexSetInteger(plotIndex, PLOT_LINE_WIDTH, InpBBWidth);
      PlotIndexSetString(plotIndex, PLOT_LABEL, "BB Upper");
      plotIndex++;
      
      PlotIndexSetInteger(plotIndex, PLOT_DRAW_TYPE, DRAW_LINE);
      PlotIndexSetInteger(plotIndex, PLOT_LINE_COLOR, InpBBBasisColor);
      PlotIndexSetInteger(plotIndex, PLOT_LINE_WIDTH, InpBBWidth);
      PlotIndexSetString(plotIndex, PLOT_LABEL, "BB Middle");
      plotIndex++;
      
      PlotIndexSetInteger(plotIndex, PLOT_DRAW_TYPE, DRAW_LINE);
      PlotIndexSetInteger(plotIndex, PLOT_LINE_COLOR, InpBBLowerColor);
      PlotIndexSetInteger(plotIndex, PLOT_LINE_WIDTH, InpBBWidth);
      PlotIndexSetString(plotIndex, PLOT_LABEL, "BB Lower");
      plotIndex++;
   }
   else
   {
      PlotIndexSetInteger(3, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetInteger(4, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetInteger(5, PLOT_DRAW_TYPE, DRAW_NONE);
      plotIndex += 3;
   }
   
   //--- ZigZag Plot ---
   if(InpShowZigZag)
   {
      PlotIndexSetInteger(plotIndex, PLOT_DRAW_TYPE, DRAW_SECTION);
      PlotIndexSetInteger(plotIndex, PLOT_LINE_COLOR, clrWhite);
      PlotIndexSetInteger(plotIndex, PLOT_LINE_WIDTH, InpZZLineWidth);
      PlotIndexSetString(plotIndex, PLOT_LABEL, "ZigZag");
   }
   else
   {
      PlotIndexSetInteger(6, PLOT_DRAW_TYPE, DRAW_NONE);
   }
   plotIndex++;
   
   //--- PA Plot ---
   if(InpShowPA)
   {
      PlotIndexSetInteger(plotIndex, PLOT_DRAW_TYPE, DRAW_ARROW);
      PlotIndexSetInteger(plotIndex, PLOT_ARROW, 233);  // Arrow up/down
      PlotIndexSetString(plotIndex, PLOT_LABEL, "PA Pattern");
   }
   else
   {
      PlotIndexSetInteger(7, PLOT_DRAW_TYPE, DRAW_NONE);
   }
   plotIndex++;
   
   //--- CDC Plots ---
   if(InpShowCDC)
   {
      PlotIndexSetInteger(plotIndex, PLOT_DRAW_TYPE, DRAW_LINE);
      PlotIndexSetInteger(plotIndex, PLOT_LINE_COLOR, InpCDCBullColor);
      PlotIndexSetInteger(plotIndex, PLOT_LINE_WIDTH, InpCDCWidth);
      PlotIndexSetString(plotIndex, PLOT_LABEL, "CDC Fast");
      plotIndex++;
      
      PlotIndexSetInteger(plotIndex, PLOT_DRAW_TYPE, DRAW_LINE);
      PlotIndexSetInteger(plotIndex, PLOT_LINE_COLOR, InpCDCBearColor);
      PlotIndexSetInteger(plotIndex, PLOT_LINE_WIDTH, InpCDCWidth);
      PlotIndexSetString(plotIndex, PLOT_LABEL, "CDC Slow");
      plotIndex++;
      
      if(InpCDCShowHistogram)
      {
         PlotIndexSetInteger(plotIndex, PLOT_DRAW_TYPE, DRAW_HISTOGRAM);
         PlotIndexSetString(plotIndex, PLOT_LABEL, "CDC Histogram");
      }
      else
      {
         PlotIndexSetInteger(plotIndex, PLOT_DRAW_TYPE, DRAW_NONE);
      }
   }
   else
   {
      PlotIndexSetInteger(8, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetInteger(9, PLOT_DRAW_TYPE, DRAW_NONE);
      PlotIndexSetInteger(10, PLOT_DRAW_TYPE, DRAW_NONE);
   }
   
   // Create indicator handles
   if(InpShowEMA)
   {
      handleEMA1 = iMA(_Symbol, PERIOD_CURRENT, InpEMA1Period, 0, MODE_EMA, InpEMAPrice);
      handleEMA2 = iMA(_Symbol, PERIOD_CURRENT, InpEMA2Period, 0, MODE_EMA, InpEMAPrice);
      handleEMA3 = iMA(_Symbol, PERIOD_CURRENT, InpEMA3Period, 0, MODE_EMA, InpEMAPrice);
      
      if(handleEMA1 == INVALID_HANDLE || handleEMA2 == INVALID_HANDLE || handleEMA3 == INVALID_HANDLE)
      {
         Print("Error creating EMA handles");
         return(INIT_FAILED);
      }
   }
   
   if(InpShowBollinger)
   {
      ENUM_MA_METHOD maMethod;
      switch(InpBBMAType)
      {
         case BB_MA_EMA: maMethod = MODE_EMA; break;
         case BB_MA_SMMA: maMethod = MODE_SMMA; break;
         case BB_MA_WMA: maMethod = MODE_LWMA; break;
         default: maMethod = MODE_SMA; break;
      }
      
      handleBB = iBands(_Symbol, PERIOD_CURRENT, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
      
      if(handleBB == INVALID_HANDLE)
      {
         Print("Error creating Bollinger Bands handle");
         return(INIT_FAILED);
      }
   }
   
   if(InpShowCDC)
   {
      handleCDCFast = iMA(_Symbol, PERIOD_CURRENT, InpCDCFastPeriod, 0, MODE_EMA, PRICE_CLOSE);
      handleCDCSlow = iMA(_Symbol, PERIOD_CURRENT, InpCDCSlowPeriod, 0, MODE_EMA, PRICE_CLOSE);
      
      if(handleCDCFast == INVALID_HANDLE || handleCDCSlow == INVALID_HANDLE)
      {
         Print("Error creating CDC handles");
         return(INIT_FAILED);
      }
   }
   
   // Initialize arrays
   ArraySetAsSeries(EMA1Buffer, true);
   ArraySetAsSeries(EMA2Buffer, true);
   ArraySetAsSeries(EMA3Buffer, true);
   ArraySetAsSeries(BBUpperBuffer, true);
   ArraySetAsSeries(BBMiddleBuffer, true);
   ArraySetAsSeries(BBLowerBuffer, true);
   ArraySetAsSeries(ZigZagBuffer, true);
   ArraySetAsSeries(ZigZagHighBuffer, true);
   ArraySetAsSeries(ZigZagLowBuffer, true);
   ArraySetAsSeries(PAPatternBuffer, true);
   ArraySetAsSeries(CDCFastBuffer, true);
   ArraySetAsSeries(CDCSlowBuffer, true);
   ArraySetAsSeries(CDCHistBuffer, true);
   
   // *** TRY TO SYNC SMC SETTINGS FROM EA VIA GLOBAL VARIABLES ***
   SyncSMCSettingsFromEA();
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                        |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Release indicator handles
   if(handleEMA1 != INVALID_HANDLE) IndicatorRelease(handleEMA1);
   if(handleEMA2 != INVALID_HANDLE) IndicatorRelease(handleEMA2);
   if(handleEMA3 != INVALID_HANDLE) IndicatorRelease(handleEMA3);
   if(handleBB != INVALID_HANDLE) IndicatorRelease(handleBB);
   if(handleCDCFast != INVALID_HANDLE) IndicatorRelease(handleCDCFast);
   if(handleCDCSlow != INVALID_HANDLE) IndicatorRelease(handleCDCSlow);
   
   // Delete all indicator objects
   ObjectsDeleteAll(0, "ZZ_Label_");
   ObjectsDeleteAll(0, PAPrefix);
   ObjectsDeleteAll(0, SMCPrefix);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                               |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   // Set arrays as series
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   int start = prev_calculated > 0 ? prev_calculated - 1 : 0;
   int limit = rates_total - start;
   
   // ========== Calculate EMA ==========
   if(InpShowEMA)
   {
      if(CopyBuffer(handleEMA1, 0, 0, limit, EMA1Buffer) <= 0) return(0);
      if(CopyBuffer(handleEMA2, 0, 0, limit, EMA2Buffer) <= 0) return(0);
      if(CopyBuffer(handleEMA3, 0, 0, limit, EMA3Buffer) <= 0) return(0);
   }
   
   // ========== Calculate Bollinger Bands ==========
   if(InpShowBollinger)
   {
      if(CopyBuffer(handleBB, 1, 0, limit, BBUpperBuffer) <= 0) return(0);   // Upper band
      if(CopyBuffer(handleBB, 0, 0, limit, BBMiddleBuffer) <= 0) return(0);  // Middle band
      if(CopyBuffer(handleBB, 2, 0, limit, BBLowerBuffer) <= 0) return(0);   // Lower band
   }
   
   // ========== Calculate ZigZag ==========
   if(InpShowZigZag)
   {
      CalculateZigZag(rates_total, prev_calculated, time, high, low);
   }
   
   // ========== Calculate Price Action ==========
   if(InpShowPA)
   {
      CalculatePriceAction(rates_total, prev_calculated, time, open, high, low, close);
   }
   
   // ========== Calculate CDC ==========
   if(InpShowCDC)
   {
      if(CopyBuffer(handleCDCFast, 0, 0, limit, CDCFastBuffer) <= 0) return(0);
      if(CopyBuffer(handleCDCSlow, 0, 0, limit, CDCSlowBuffer) <= 0) return(0);
      
      // Calculate histogram
      for(int i = 0; i < limit; i++)
      {
         CDCHistBuffer[i] = CDCFastBuffer[i] - CDCSlowBuffer[i];
      }
   }
   
   // ========== Calculate SMC Order Blocks ==========
   if(InpShowSMC)
   {
      CalculateSMC(rates_total, prev_calculated, time, open, high, low, close);
   }
   
   // ========== Check EA Trade Signals (via Global Variables) ==========
   if(InpShowPA && InpPAMode == PA_MODE_EA_ONLY)
   {
      CheckEATradeSignals(time, open, high, low, close);
   }
   
   return(rates_total);
}

//+------------------------------------------------------------------+
//| Calculate ZigZag                                                   |
//+------------------------------------------------------------------+
void CalculateZigZag(const int rates_total,
                     const int prev_calculated,
                     const datetime &time[],
                     const double &high[],
                     const double &low[])
{
   int depth = InpZZDepth;
   int deviation = InpZZDeviation;
   int backstep = InpZZBackstep;
   
   // Initialize buffer
   if(prev_calculated == 0)
   {
      ArrayInitialize(ZigZagBuffer, 0.0);
      ArrayInitialize(ZigZagHighBuffer, 0.0);
      ArrayInitialize(ZigZagLowBuffer, 0.0);
      lastZigZagHigh = 0;
      lastZigZagLow = 0;
      lastZigZagHighBar = 0;
      lastZigZagLowBar = 0;
   }
   
   int limit = rates_total - depth;
   
   for(int i = limit; i >= 0; i--)
   {
      // Find highest high in depth bars
      int highestBar = i;
      double highestValue = high[i];
      for(int j = i + 1; j < i + depth && j < rates_total; j++)
      {
         if(high[j] > highestValue)
         {
            highestValue = high[j];
            highestBar = j;
         }
      }
      
      // Find lowest low in depth bars
      int lowestBar = i;
      double lowestValue = low[i];
      for(int j = i + 1; j < i + depth && j < rates_total; j++)
      {
         if(low[j] < lowestValue)
         {
            lowestValue = low[j];
            lowestBar = j;
         }
      }
      
      ZigZagHighBuffer[i] = (highestBar == i) ? highestValue : 0.0;
      ZigZagLowBuffer[i] = (lowestBar == i) ? lowestValue : 0.0;
   }
   
   // Connect ZigZag points
   double lastPrice = 0;
   int lastBar = 0;
   int lastType = 0;  // 1 = high, -1 = low
   
   for(int i = rates_total - 1; i >= 0; i--)
   {
      if(ZigZagHighBuffer[i] != 0)
      {
         if(lastType != 1)
         {
            ZigZagBuffer[i] = ZigZagHighBuffer[i];
            
            // Determine pattern (HH or LH)
            string pattern = "";
            if(lastZigZagHigh > 0)
            {
               pattern = (ZigZagHighBuffer[i] > lastZigZagHigh) ? "HH" : "LH";
            }
            else
            {
               pattern = "HH";
            }
            
            // Draw label
            if(InpZZShowLabels && InpZZMode != ZZ_LINES_ONLY)
            {
               DrawZigZagLabel(i, time[i], ZigZagHighBuffer[i], pattern, true);
            }
            
            lastZigZagHigh = ZigZagHighBuffer[i];
            lastZigZagHighBar = i;
            lastType = 1;
         }
      }
      
      if(ZigZagLowBuffer[i] != 0)
      {
         if(lastType != -1)
         {
            ZigZagBuffer[i] = ZigZagLowBuffer[i];
            
            // Determine pattern (HL or LL)
            string pattern = "";
            if(lastZigZagLow > 0)
            {
               pattern = (ZigZagLowBuffer[i] > lastZigZagLow) ? "HL" : "LL";
            }
            else
            {
               pattern = "HL";
            }
            
            // Draw label
            if(InpZZShowLabels && InpZZMode != ZZ_LINES_ONLY)
            {
               DrawZigZagLabel(i, time[i], ZigZagLowBuffer[i], pattern, false);
            }
            
            lastZigZagLow = ZigZagLowBuffer[i];
            lastZigZagLowBar = i;
            lastType = -1;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Draw ZigZag Label                                                  |
//+------------------------------------------------------------------+
void DrawZigZagLabel(int bar, datetime time, double price, string pattern, bool isHigh)
{
   string objName = "ZZ_Label_" + IntegerToString(bar);
   
   if(ObjectFind(0, objName) >= 0)
      ObjectDelete(0, objName);
   
   ObjectCreate(0, objName, OBJ_TEXT, 0, time, price);
   ObjectSetString(0, objName, OBJPROP_TEXT, pattern);
   ObjectSetInteger(0, objName, OBJPROP_COLOR, isHigh ? InpZZBearColor : InpZZBullColor);
   ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, objName, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, objName, OBJPROP_ANCHOR, isHigh ? ANCHOR_LOWER : ANCHOR_UPPER);
}

//+------------------------------------------------------------------+
//| Calculate Price Action Patterns                                    |
//| When PA_MODE_EA_ONLY: Only detect patterns, don't draw labels     |
//| Labels are drawn via CheckEATradeSignals when EA sends signal     |
//+------------------------------------------------------------------+
void CalculatePriceAction(const int rates_total,
                          const int prev_calculated,
                          const datetime &time[],
                          const double &open[],
                          const double &high[],
                          const double &low[],
                          const double &close[])
{
   // If EA_ONLY mode, skip automatic PA label drawing
   // Labels will be drawn by CheckEATradeSignals() when EA opens orders
   if(InpPAMode == PA_MODE_EA_ONLY)
   {
      return;
   }
   
   int start = prev_calculated > 0 ? prev_calculated - 1 : 3;
   
   for(int i = MathMin(rates_total - 4, start); i >= 0; i--)
   {
      PAPatternBuffer[i] = 0.0;
      
      ENUM_PA_PATTERN pattern = PA_NEUTRAL;
      string patternName = "";
      
      // Check Bullish Patterns
      if(InpPAHammer && IsHammer(i, open, high, low, close))
      {
         pattern = PA_BULLISH;
         patternName = "Hammer";
      }
      else if(InpPABullEngulfing && IsBullishEngulfing(i, open, high, low, close))
      {
         pattern = PA_BULLISH;
         patternName = "Bull Engulf";
      }
      else if(InpPATweezerBottom && IsTweezerBottom(i, open, high, low, close))
      {
         pattern = PA_BULLISH;
         patternName = "Tweezer Bot";
      }
      else if(InpPAMorningStar && IsMorningStar(i, open, high, low, close))
      {
         pattern = PA_BULLISH;
         patternName = "Morning Star";
      }
      else if(InpPABullHotdog && IsBullishHotdog(i, open, high, low, close))
      {
         pattern = PA_BULLISH;
         patternName = "Bull Hotdog";
      }
      
      // Check Bearish Patterns
      else if(InpPAShootingStar && IsShootingStar(i, open, high, low, close))
      {
         pattern = PA_BEARISH;
         patternName = "Shooting Star";
      }
      else if(InpPABearEngulfing && IsBearishEngulfing(i, open, high, low, close))
      {
         pattern = PA_BEARISH;
         patternName = "Bear Engulf";
      }
      else if(InpPATweezerTop && IsTweezerTop(i, open, high, low, close))
      {
         pattern = PA_BEARISH;
         patternName = "Tweezer Top";
      }
      else if(InpPAEveningStar && IsEveningStar(i, open, high, low, close))
      {
         pattern = PA_BEARISH;
         patternName = "Evening Star";
      }
      else if(InpPABearHotdog && IsBearishHotdog(i, open, high, low, close))
      {
         pattern = PA_BEARISH;
         patternName = "Bear Hotdog";
      }
      
      // Set buffer and draw label (only in PA_MODE_ALL)
      if(pattern != PA_NEUTRAL)
      {
         PAPatternBuffer[i] = (pattern == PA_BULLISH) ? low[i] : high[i];
         DrawPALabel(time[i], (pattern == PA_BULLISH) ? low[i] : high[i], patternName, pattern == PA_BULLISH);
      }
   }
}

//+------------------------------------------------------------------+
//| Draw Price Action Label (Arrow + Text)                             |
//+------------------------------------------------------------------+
void DrawPALabel(datetime barTime, double price, string pattern, bool isBull)
{
   string uniqueId = IntegerToString((long)barTime);
   
   // Get average candle range for dynamic offset
   double avgRange = 0;
   for(int i = 1; i <= 10; i++)
   {
      avgRange += iHigh(_Symbol, PERIOD_CURRENT, i) - iLow(_Symbol, PERIOD_CURRENT, i);
   }
   avgRange /= 10;
   
   // Dynamic offsets
   double arrowOffset = avgRange * 0.3;
   double labelOffset = avgRange * 0.8;
   
   // Create Arrow Object
   string arrowName = PAPrefix + "Arrow_" + uniqueId;
   
   if(isBull)
   {
      double arrowPrice = price - arrowOffset;
      ObjectCreate(0, arrowName, OBJ_ARROW_UP, 0, barTime, arrowPrice);
      ObjectSetInteger(0, arrowName, OBJPROP_COLOR, InpPABullColor);
   }
   else
   {
      double arrowPrice = price + arrowOffset;
      ObjectCreate(0, arrowName, OBJ_ARROW_DOWN, 0, barTime, arrowPrice);
      ObjectSetInteger(0, arrowName, OBJPROP_COLOR, InpPABearColor);
   }
   ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 2);
   ObjectSetInteger(0, arrowName, OBJPROP_SELECTABLE, false);
   
   // Create Text Label
   string labelName = PAPrefix + "Label_" + uniqueId;
   double labelPrice = isBull ? price - labelOffset : price + labelOffset;
   
   ObjectCreate(0, labelName, OBJ_TEXT, 0, barTime, labelPrice);
   ObjectSetString(0, labelName, OBJPROP_TEXT, pattern);
   ObjectSetInteger(0, labelName, OBJPROP_COLOR, isBull ? InpPABullColor : InpPABearColor);
   ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, isBull ? ANCHOR_UPPER : ANCHOR_LOWER);
   ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Price Action Pattern Detection Functions                           |
//+------------------------------------------------------------------+

// Hammer / Pin Bar (Bullish)
bool IsHammer(int i, const double &open[], const double &high[], const double &low[], const double &close[])
{
   double body = MathAbs(close[i] - open[i]);
   double range = high[i] - low[i];
   double lowerWick = MathMin(open[i], close[i]) - low[i];
   double upperWick = high[i] - MathMax(open[i], close[i]);
   
   if(range == 0) return false;
   
   // Hammer: small body, long lower wick, small upper wick
   return (body / range < 0.3 && lowerWick / body >= InpPAPinRatio && upperWick < body);
}

// Shooting Star (Bearish)
bool IsShootingStar(int i, const double &open[], const double &high[], const double &low[], const double &close[])
{
   double body = MathAbs(close[i] - open[i]);
   double range = high[i] - low[i];
   double lowerWick = MathMin(open[i], close[i]) - low[i];
   double upperWick = high[i] - MathMax(open[i], close[i]);
   
   if(range == 0 || body == 0) return false;
   
   // Shooting Star: small body, long upper wick, small lower wick
   return (body / range < 0.3 && upperWick / body >= InpPAPinRatio && lowerWick < body);
}

// Bullish Engulfing
bool IsBullishEngulfing(int i, const double &open[], const double &high[], const double &low[], const double &close[])
{
   if(i + 1 >= ArraySize(open)) return false;
   
   bool prevBearish = close[i+1] < open[i+1];
   bool currBullish = close[i] > open[i];
   bool engulfs = open[i] < close[i+1] && close[i] > open[i+1];
   
   double currBody = MathAbs(close[i] - open[i]);
   double currRange = high[i] - low[i];
   
   return prevBearish && currBullish && engulfs && (currBody / currRange >= InpPABodyMinRatio);
}

// Bearish Engulfing
bool IsBearishEngulfing(int i, const double &open[], const double &high[], const double &low[], const double &close[])
{
   if(i + 1 >= ArraySize(open)) return false;
   
   bool prevBullish = close[i+1] > open[i+1];
   bool currBearish = close[i] < open[i];
   bool engulfs = open[i] > close[i+1] && close[i] < open[i+1];
   
   double currBody = MathAbs(close[i] - open[i]);
   double currRange = high[i] - low[i];
   
   return prevBullish && currBearish && engulfs && (currBody / currRange >= InpPABodyMinRatio);
}

// Tweezer Bottom
bool IsTweezerBottom(int i, const double &open[], const double &high[], const double &low[], const double &close[])
{
   if(i + 1 >= ArraySize(open)) return false;
   
   double tolerance = (high[i] - low[i]) * 0.1;
   bool sameLow = MathAbs(low[i] - low[i+1]) <= tolerance;
   bool prevBearish = close[i+1] < open[i+1];
   bool currBullish = close[i] > open[i];
   
   return sameLow && prevBearish && currBullish;
}

// Tweezer Top
bool IsTweezerTop(int i, const double &open[], const double &high[], const double &low[], const double &close[])
{
   if(i + 1 >= ArraySize(open)) return false;
   
   double tolerance = (high[i] - low[i]) * 0.1;
   bool sameHigh = MathAbs(high[i] - high[i+1]) <= tolerance;
   bool prevBullish = close[i+1] > open[i+1];
   bool currBearish = close[i] < open[i];
   
   return sameHigh && prevBullish && currBearish;
}

// Morning Star (3-Candle)
bool IsMorningStar(int i, const double &open[], const double &high[], const double &low[], const double &close[])
{
   if(i + 2 >= ArraySize(open)) return false;
   
   bool firstBearish = close[i+2] < open[i+2];
   double secondBody = MathAbs(close[i+1] - open[i+1]);
   double secondRange = high[i+1] - low[i+1];
   bool secondSmall = (secondRange > 0) && (secondBody / secondRange < 0.3);
   bool thirdBullish = close[i] > open[i];
   bool closes_above_mid = close[i] > (open[i+2] + close[i+2]) / 2;
   
   return firstBearish && secondSmall && thirdBullish && closes_above_mid;
}

// Evening Star (3-Candle)
bool IsEveningStar(int i, const double &open[], const double &high[], const double &low[], const double &close[])
{
   if(i + 2 >= ArraySize(open)) return false;
   
   bool firstBullish = close[i+2] > open[i+2];
   double secondBody = MathAbs(close[i+1] - open[i+1]);
   double secondRange = high[i+1] - low[i+1];
   bool secondSmall = (secondRange > 0) && (secondBody / secondRange < 0.3);
   bool thirdBearish = close[i] < open[i];
   bool closes_below_mid = close[i] < (open[i+2] + close[i+2]) / 2;
   
   return firstBullish && secondSmall && thirdBearish && closes_below_mid;
}

// Bullish Hotdog Pattern
bool IsBullishHotdog(int i, const double &open[], const double &high[], const double &low[], const double &close[])
{
   if(i + 1 >= ArraySize(open)) return false;
   
   // Hotdog: Current candle completely engulfs previous candle including wicks
   bool engulfsBody = close[i] > open[i] && open[i] <= low[i+1] && close[i] >= high[i+1];
   bool longBody = (close[i] - open[i]) > (high[i+1] - low[i+1]);
   
   return engulfsBody && longBody;
}

// Bearish Hotdog Pattern
bool IsBearishHotdog(int i, const double &open[], const double &high[], const double &low[], const double &close[])
{
   if(i + 1 >= ArraySize(open)) return false;
   
   // Hotdog: Current candle completely engulfs previous candle including wicks
   bool engulfsBody = close[i] < open[i] && open[i] >= high[i+1] && close[i] <= low[i+1];
   bool longBody = (open[i] - close[i]) > (high[i+1] - low[i+1]);
   
   return engulfsBody && longBody;
}

//+------------------------------------------------------------------+
//| ===================== SMC ORDER BLOCKS ========================= |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Sync SMC Settings from EA via Global Variables                     |
//| If EA is running with SMC strategy, use its settings               |
//+------------------------------------------------------------------+
void SyncSMCSettingsFromEA()
{
   SMCSyncedFromEA = false;
   
   // Check if EA has written SMC_ENABLED = 1.0
   if(GlobalVariableCheck(GV_SMC_ENABLED))
   {
      double smcEnabled = GlobalVariableGet(GV_SMC_ENABLED);
      if(smcEnabled == 1.0)
      {
         // EA is using SMC strategy - sync all settings
         if(GlobalVariableCheck(GV_SMC_SWING_LENGTH))
            SyncedSMCSwingLength = (int)GlobalVariableGet(GV_SMC_SWING_LENGTH);
         else
            SyncedSMCSwingLength = InpSMCSwingLength;
         
         if(GlobalVariableCheck(GV_SMC_INTERNAL_LENGTH))
            SyncedSMCInternalLength = (int)GlobalVariableGet(GV_SMC_INTERNAL_LENGTH);
         else
            SyncedSMCInternalLength = InpSMCInternalLength;
         
         if(GlobalVariableCheck(GV_SMC_MAX_OB))
            SyncedSMCMaxOrderBlocks = (int)GlobalVariableGet(GV_SMC_MAX_OB);
         else
            SyncedSMCMaxOrderBlocks = InpSMCMaxOrderBlocks;
         
         if(GlobalVariableCheck(GV_SMC_BULL_OB_COLOR))
            SyncedSMCBullOBColor = (color)GlobalVariableGet(GV_SMC_BULL_OB_COLOR);
         else
            SyncedSMCBullOBColor = InpSMCBullOBColor;
         
         if(GlobalVariableCheck(GV_SMC_BEAR_OB_COLOR))
            SyncedSMCBearOBColor = (color)GlobalVariableGet(GV_SMC_BEAR_OB_COLOR);
         else
            SyncedSMCBearOBColor = InpSMCBearOBColor;
         
         SMCSyncedFromEA = true;
         Print(">>> SMC Settings SYNCED from EA: SwingLen=", SyncedSMCSwingLength, 
               " | InternalLen=", SyncedSMCInternalLength, 
               " | MaxOB=", SyncedSMCMaxOrderBlocks);
      }
   }
   
   // If not synced, use indicator's own input parameters
   if(!SMCSyncedFromEA)
   {
      SyncedSMCSwingLength = InpSMCSwingLength;
      SyncedSMCInternalLength = InpSMCInternalLength;
      SyncedSMCMaxOrderBlocks = InpSMCMaxOrderBlocks;
      SyncedSMCBullOBColor = InpSMCBullOBColor;
      SyncedSMCBearOBColor = InpSMCBearOBColor;
      Print(">>> SMC Settings using Indicator's own inputs (EA not synced)");
   }
}

//+------------------------------------------------------------------+
//| Get SMC Swing Length (synced or local)                             |
//+------------------------------------------------------------------+
int GetSMCSwingLength()
{
   return SMCSyncedFromEA ? SyncedSMCSwingLength : InpSMCSwingLength;
}

int GetSMCInternalLength()
{
   return SMCSyncedFromEA ? SyncedSMCInternalLength : InpSMCInternalLength;
}

int GetSMCMaxOrderBlocks()
{
   return SMCSyncedFromEA ? SyncedSMCMaxOrderBlocks : InpSMCMaxOrderBlocks;
}

color GetSMCBullOBColor()
{
   return SMCSyncedFromEA ? SyncedSMCBullOBColor : InpSMCBullOBColor;
}

color GetSMCBearOBColor()
{
   return SMCSyncedFromEA ? SyncedSMCBearOBColor : InpSMCBearOBColor;
}

//+------------------------------------------------------------------+
//| Calculate SMC Order Blocks                                         |
//+------------------------------------------------------------------+
void CalculateSMC(const int rates_total,
                  const int prev_calculated,
                  const datetime &time[],
                  const double &open[],
                  const double &high[],
                  const double &low[],
                  const double &close[])
{
   // Re-sync from EA on each calculation (in case EA settings changed)
   SyncSMCSettingsFromEA();
   
   int lookback = GetSMCInternalLength();
   int barsNeeded = GetSMCSwingLength() + 20;
   
   if(rates_total < barsNeeded) return;
   
   // Detect Swing High and Swing Low
   for(int i = lookback; i < barsNeeded - lookback; i++)
   {
      // Check for Swing High
      bool isSwingHigh = true;
      for(int j = 1; j <= lookback; j++)
      {
         if(high[i] <= high[i-j] || high[i] <= high[i+j])
         {
            isSwingHigh = false;
            break;
         }
      }
      
      if(isSwingHigh && high[i] > SMCSwingHigh)
      {
         SMCSwingHigh = high[i];
         SMCSwingHighTime = time[i];
      }
      
      // Check for Swing Low
      bool isSwingLow = true;
      for(int j = 1; j <= lookback; j++)
      {
         if(low[i] >= low[i-j] || low[i] >= low[i+j])
         {
            isSwingLow = false;
            break;
         }
      }
      
      if(isSwingLow && (SMCSwingLow == 0 || low[i] < SMCSwingLow))
      {
         SMCSwingLow = low[i];
         SMCSwingLowTime = time[i];
      }
   }
   
   // Determine trend based on structure
   double currentClose = close[0];
   if(currentClose > SMCSwingHigh && SMCSwingHigh > 0)
   {
      SMCTrend = 1;  // Bullish
   }
   else if(currentClose < SMCSwingLow && SMCSwingLow > 0)
   {
      SMCTrend = -1; // Bearish
   }
   
   // Detect Order Blocks
   DetectOrderBlocks(rates_total, time, open, high, low, close);
   
   // Draw Order Blocks on chart
   DrawOrderBlocks();
}

//+------------------------------------------------------------------+
//| Detect Order Blocks based on structure breaks                      |
//+------------------------------------------------------------------+
void DetectOrderBlocks(const int rates_total,
                       const datetime &time[],
                       const double &open[],
                       const double &high[],
                       const double &low[],
                       const double &close[])
{
   int lookback = GetSMCInternalLength();
   int scanLimit = MathMin(50, rates_total - lookback - 1);
   
   for(int i = lookback; i < scanLimit; i++)
   {
      // Check for Bullish Order Block
      // Condition: Bearish candle followed by strong bullish move
      if(close[i] < open[i])  // Bearish candle
      {
         bool strongBullishMove = false;
         for(int j = i - 1; j >= 1; j--)
         {
            if(close[j] > high[i] + (high[i] - low[i]))
            {
               strongBullishMove = true;
               break;
            }
            if(j < i - 3) break;
         }
         
         if(strongBullishMove)
         {
            AddBullishOB(high[i], low[i], time[i], i);
         }
      }
      
      // Check for Bearish Order Block
      // Condition: Bullish candle followed by strong bearish move
      if(close[i] > open[i])  // Bullish candle
      {
         bool strongBearishMove = false;
         for(int j = i - 1; j >= 1; j--)
         {
            if(close[j] < low[i] - (high[i] - low[i]))
            {
               strongBearishMove = true;
               break;
            }
            if(j < i - 3) break;
         }
         
         if(strongBearishMove)
         {
            AddBearishOB(high[i], low[i], time[i], i);
         }
      }
   }
   
   // Check mitigation of existing Order Blocks
   double currentLow = low[0];
   double currentHigh = high[0];
   double currentClose = close[0];
   
   for(int i = 0; i < BullishOBCount; i++)
   {
      if(!BullishOBs[i].mitigated)
      {
         // Bullish OB mitigated when price closes below
         if(currentClose < BullishOBs[i].low)
         {
            BullishOBs[i].mitigated = true;
            ObjectDelete(0, BullishOBs[i].objName);
         }
      }
   }
   
   for(int i = 0; i < BearishOBCount; i++)
   {
      if(!BearishOBs[i].mitigated)
      {
         // Bearish OB mitigated when price closes above
         if(currentClose > BearishOBs[i].high)
         {
            BearishOBs[i].mitigated = true;
            ObjectDelete(0, BearishOBs[i].objName);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Add Bullish Order Block                                            |
//+------------------------------------------------------------------+
void AddBullishOB(double high, double low, datetime time, int barIndex)
{
   // Check if already exists
   for(int i = 0; i < BullishOBCount; i++)
   {
      if(BullishOBs[i].time == time) return;
   }
   
   // FIFO rotation
   if(BullishOBCount >= GetSMCMaxOrderBlocks())
   {
      ObjectDelete(0, BullishOBs[0].objName);
      for(int k = 0; k < BullishOBCount - 1; k++)
      {
         BullishOBs[k] = BullishOBs[k + 1];
      }
      BullishOBCount--;
   }
   
   BullishOBs[BullishOBCount].high = high;
   BullishOBs[BullishOBCount].low = low;
   BullishOBs[BullishOBCount].time = time;
   BullishOBs[BullishOBCount].barIndex = barIndex;
   BullishOBs[BullishOBCount].bias = 1;
   BullishOBs[BullishOBCount].mitigated = false;
   BullishOBs[BullishOBCount].objName = SMCPrefix + "BullOB_" + IntegerToString((long)time);
   BullishOBCount++;
}

//+------------------------------------------------------------------+
//| Add Bearish Order Block                                            |
//+------------------------------------------------------------------+
void AddBearishOB(double high, double low, datetime time, int barIndex)
{
   // Check if already exists
   for(int i = 0; i < BearishOBCount; i++)
   {
      if(BearishOBs[i].time == time) return;
   }
   
   // FIFO rotation
   if(BearishOBCount >= GetSMCMaxOrderBlocks())
   {
      ObjectDelete(0, BearishOBs[0].objName);
      for(int k = 0; k < BearishOBCount - 1; k++)
      {
         BearishOBs[k] = BearishOBs[k + 1];
      }
      BearishOBCount--;
   }
   
   BearishOBs[BearishOBCount].high = high;
   BearishOBs[BearishOBCount].low = low;
   BearishOBs[BearishOBCount].time = time;
   BearishOBs[BearishOBCount].barIndex = barIndex;
   BearishOBs[BearishOBCount].bias = -1;
   BearishOBs[BearishOBCount].mitigated = false;
   BearishOBs[BearishOBCount].objName = SMCPrefix + "BearOB_" + IntegerToString((long)time);
   BearishOBCount++;
}

//+------------------------------------------------------------------+
//| Draw Order Blocks on Chart                                         |
//+------------------------------------------------------------------+
void DrawOrderBlocks()
{
   datetime endTime = TimeCurrent() + 86400 * 5;  // Extend 5 days forward
   
   // Draw Bullish Order Blocks (Support - Blue)
   for(int i = 0; i < BullishOBCount; i++)
   {
      if(BullishOBs[i].mitigated) continue;
      
      string objName = BullishOBs[i].objName;
      
      if(ObjectFind(0, objName) < 0)
      {
         ObjectCreate(0, objName, OBJ_RECTANGLE, 0, 
                     BullishOBs[i].time, BullishOBs[i].high,
                     endTime, BullishOBs[i].low);
      }
      else
      {
         ObjectSetInteger(0, objName, OBJPROP_TIME, 1, endTime);
      }
      
      ObjectSetInteger(0, objName, OBJPROP_COLOR, GetSMCBullOBColor());
      ObjectSetInteger(0, objName, OBJPROP_FILL, true);
      ObjectSetInteger(0, objName, OBJPROP_BACK, true);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 0);  // Remove border lines
   }
   
   // Draw Bearish Order Blocks (Resistance - Red)
   for(int i = 0; i < BearishOBCount; i++)
   {
      if(BearishOBs[i].mitigated) continue;
      
      string objName = BearishOBs[i].objName;
      
      if(ObjectFind(0, objName) < 0)
      {
         ObjectCreate(0, objName, OBJ_RECTANGLE, 0,
                     BearishOBs[i].time, BearishOBs[i].high,
                     endTime, BearishOBs[i].low);
      }
      else
      {
         ObjectSetInteger(0, objName, OBJPROP_TIME, 1, endTime);
      }
      
      ObjectSetInteger(0, objName, OBJPROP_COLOR, GetSMCBearOBColor());
      ObjectSetInteger(0, objName, OBJPROP_FILL, true);
      ObjectSetInteger(0, objName, OBJPROP_BACK, true);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 0);  // Remove border lines
   }
}

//+------------------------------------------------------------------+
//| =================== EA INTEGRATION ============================= |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check EA Trade Signals via Global Variables                        |
//| EA writes signals when it opens orders, Indicator reads them      |
//+------------------------------------------------------------------+
void CheckEATradeSignals(const datetime &time[],
                         const double &open[],
                         const double &high[],
                         const double &low[],
                         const double &close[])
{
   // Check for BUY signal from EA
   if(GlobalVariableCheck(GV_EA_BUY_SIGNAL))
   {
      double buySignal = GlobalVariableGet(GV_EA_BUY_SIGNAL);
      
      if(buySignal == 1.0)
      {
         // Get PA pattern name from EA
         string paPattern = "BUY";
         if(GlobalVariableCheck(GV_EA_BUY_PA))
         {
            // Read pattern name (stored as encoded value)
            double paCode = GlobalVariableGet(GV_EA_BUY_PA);
            paPattern = DecodePattern((int)paCode);
         }
         
         // Get signal time
         datetime signalTime = TimeCurrent();
         if(GlobalVariableCheck(GV_EA_BUY_TIME))
         {
            signalTime = (datetime)GlobalVariableGet(GV_EA_BUY_TIME);
         }
         
         // Find the bar for this signal
         int signalBar = iBarShift(_Symbol, PERIOD_CURRENT, signalTime, false);
         if(signalBar >= 0 && signalBar < ArraySize(low))
         {
            DrawPALabel(time[signalBar], low[signalBar], paPattern, true);
         }
         
         // Reset signal after drawing
         GlobalVariableSet(GV_EA_BUY_SIGNAL, 0.0);
      }
   }
   
   // Check for SELL signal from EA
   if(GlobalVariableCheck(GV_EA_SELL_SIGNAL))
   {
      double sellSignal = GlobalVariableGet(GV_EA_SELL_SIGNAL);
      
      if(sellSignal == 1.0)
      {
         // Get PA pattern name from EA
         string paPattern = "SELL";
         if(GlobalVariableCheck(GV_EA_SELL_PA))
         {
            double paCode = GlobalVariableGet(GV_EA_SELL_PA);
            paPattern = DecodePattern((int)paCode);
         }
         
         // Get signal time
         datetime signalTime = TimeCurrent();
         if(GlobalVariableCheck(GV_EA_SELL_TIME))
         {
            signalTime = (datetime)GlobalVariableGet(GV_EA_SELL_TIME);
         }
         
         // Find the bar for this signal
         int signalBar = iBarShift(_Symbol, PERIOD_CURRENT, signalTime, false);
         if(signalBar >= 0 && signalBar < ArraySize(high))
         {
            DrawPALabel(time[signalBar], high[signalBar], paPattern, false);
         }
         
         // Reset signal after drawing
         GlobalVariableSet(GV_EA_SELL_SIGNAL, 0.0);
      }
   }
}

//+------------------------------------------------------------------+
//| Decode PA Pattern from numeric code                                |
//+------------------------------------------------------------------+
string DecodePattern(int code)
{
   switch(code)
   {
      case 1: return "Hammer";
      case 2: return "Bull Engulf";
      case 3: return "Tweezer Bot";
      case 4: return "Morning Star";
      case 5: return "Inside Bull";
      case 6: return "Bull Hotdog";
      case 7: return "Pullback Buy";
      case 8: return "Outside Bull";
      case 11: return "Shooting Star";
      case 12: return "Bear Engulf";
      case 13: return "Tweezer Top";
      case 14: return "Evening Star";
      case 15: return "Inside Bear";
      case 16: return "Bear Hotdog";
      case 17: return "Pullback Sell";
      case 18: return "Outside Bear";
      default: return "PA Signal";
   }
}

//+------------------------------------------------------------------+`;

  const downloadIndicatorCode = () => {
    const element = document.createElement('a');
    const file = new Blob([fullIndicatorCode], { type: 'text/plain' });
    element.href = URL.createObjectURL(file);
    element.download = 'MoneyxSmartIndicator.mq5';
    document.body.appendChild(element);
    element.click();
    document.body.removeChild(element);
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-slate-900 via-slate-800 to-slate-900">
      {/* Header */}
      <div className="bg-slate-800/50 border-b border-slate-700/50 sticky top-0 z-50 backdrop-blur-sm">
        <div className="max-w-5xl mx-auto px-4 py-4">
          <div className="flex items-center justify-between">
            <Link to="/mt5-ea-guide" className="flex items-center gap-2 text-cyan-400 hover:text-cyan-300 transition-colors">
              <ArrowLeft className="w-5 h-5" />
              <span>กลับ EA Guide</span>
            </Link>
            <h1 className="text-xl font-bold text-white">Moneyx Smart Indicator</h1>
            <button
              onClick={downloadIndicatorCode}
              className="flex items-center gap-2 px-4 py-2 bg-cyan-500 hover:bg-cyan-400 text-slate-900 font-semibold rounded-lg transition-colors"
            >
              <Download className="w-5 h-5" />
              <span>Download .mq5</span>
            </button>
          </div>
        </div>
      </div>

      <div className="max-w-5xl mx-auto px-4 py-8">
        {/* Hero Section */}
        <div className="text-center mb-12">
          <div className="inline-flex items-center gap-2 px-4 py-2 bg-cyan-500/20 text-cyan-400 rounded-full text-sm font-medium mb-6">
            <TrendingUp className="w-4 h-4" />
            MT5 Indicator Guide
          </div>
          <h1 className="text-4xl md:text-5xl font-bold text-white mb-4">
            Moneyx Smart Indicator
          </h1>
          <p className="text-xl text-slate-400 max-w-2xl mx-auto">
            รวม Indicators 6 ตัวในตัวเดียว: EMA, Bollinger Band, ZigZag, Price Action, CDC Action Zone และ SMC Order Block
            พร้อม Settings เลือกเปิด/ปิดแต่ละตัว + เชื่อมต่อ EA ผ่าน Global Variables
          </p>
        </div>

        {/* Features Grid */}
        <div className="grid md:grid-cols-5 gap-4 mb-12">
          <div className="bg-slate-800/50 border border-slate-700/50 rounded-xl p-4 text-center">
            <div className="w-12 h-12 bg-blue-500/20 rounded-lg flex items-center justify-center mx-auto mb-3">
              <TrendingUp className="w-6 h-6 text-blue-400" />
            </div>
            <h3 className="font-semibold text-white mb-1">EMA</h3>
            <p className="text-sm text-slate-400">3 เส้น EMA ปรับ Period ได้</p>
          </div>
          <div className="bg-slate-800/50 border border-slate-700/50 rounded-xl p-4 text-center">
            <div className="w-12 h-12 bg-purple-500/20 rounded-lg flex items-center justify-center mx-auto mb-3">
              <Settings className="w-6 h-6 text-purple-400" />
            </div>
            <h3 className="font-semibold text-white mb-1">Bollinger</h3>
            <p className="text-sm text-slate-400">Upper, Middle, Lower Bands</p>
          </div>
          <div className="bg-slate-800/50 border border-slate-700/50 rounded-xl p-4 text-center">
            <div className="w-12 h-12 bg-green-500/20 rounded-lg flex items-center justify-center mx-auto mb-3">
              <TrendingUp className="w-6 h-6 text-green-400" />
            </div>
            <h3 className="font-semibold text-white mb-1">ZigZag</h3>
            <p className="text-sm text-slate-400">HH, HL, LH, LL Labels</p>
          </div>
          <div className="bg-slate-800/50 border border-slate-700/50 rounded-xl p-4 text-center">
            <div className="w-12 h-12 bg-orange-500/20 rounded-lg flex items-center justify-center mx-auto mb-3">
              <Eye className="w-6 h-6 text-orange-400" />
            </div>
            <h3 className="font-semibold text-white mb-1">Price Action</h3>
            <p className="text-sm text-slate-400">12 รูปแบบ Candlestick</p>
          </div>
          <div className="bg-slate-800/50 border border-slate-700/50 rounded-xl p-4 text-center">
            <div className="w-12 h-12 bg-cyan-500/20 rounded-lg flex items-center justify-center mx-auto mb-3">
              <TrendingUp className="w-6 h-6 text-cyan-400" />
            </div>
            <h3 className="font-semibold text-white mb-1">CDC</h3>
            <p className="text-sm text-slate-400">Action Zone Filter</p>
          </div>
        </div>

        {/* Visibility Settings Section */}
        <StepCard
          step={1}
          title="Indicator Visibility Settings"
          description="เลือกว่าจะแสดง Indicator ตัวไหนบ้าง"
          icon={<Eye className="w-5 h-5" />}
        >
          <div className="text-slate-300 mb-4">
            <div className="bg-slate-800/50 rounded-lg p-4 mb-4">
              <h4 className="text-cyan-400 font-semibold mb-2">INDICATOR VISIBILITY</h4>
              <ul className="space-y-2 text-sm">
                <li className="flex items-center gap-2">
                  <span className="w-3 h-3 bg-green-500 rounded-sm"></span>
                  <span className="text-slate-400">Show EMA Lines</span>
                  <span className="text-green-400 ml-auto">true/false</span>
                </li>
                <li className="flex items-center gap-2">
                  <span className="w-3 h-3 bg-purple-500 rounded-sm"></span>
                  <span className="text-slate-400">Show Bollinger Bands</span>
                  <span className="text-green-400 ml-auto">true/false</span>
                </li>
                <li className="flex items-center gap-2">
                  <span className="w-3 h-3 bg-white rounded-sm"></span>
                  <span className="text-slate-400">Show ZigZag Indicator</span>
                  <span className="text-green-400 ml-auto">true/false</span>
                </li>
                <li className="flex items-center gap-2">
                  <span className="w-3 h-3 bg-orange-500 rounded-sm"></span>
                  <span className="text-slate-400">Show Price Action Patterns</span>
                  <span className="text-green-400 ml-auto">true/false</span>
                </li>
                <li className="flex items-center gap-2">
                  <span className="w-3 h-3 bg-cyan-500 rounded-sm"></span>
                  <span className="text-slate-400">Show CDC Action Zone</span>
                  <span className="text-green-400 ml-auto">true/false</span>
                </li>
              </ul>
            </div>
          </div>
          <CodeBlock
            language="mql5"
            filename="Visibility Settings"
            code={`//--- [ INDICATOR VISIBILITY SETTINGS ] -----------------------------
input string   InpVisibilityHeader = "=== INDICATOR VISIBILITY ===";  // ___
input bool     InpShowEMA = true;              // Show EMA Lines
input bool     InpShowBollinger = true;        // Show Bollinger Bands
input bool     InpShowZigZag = true;           // Show ZigZag Indicator
input bool     InpShowPA = true;               // Show Price Action Patterns
input bool     InpShowCDC = true;              // Show CDC Action Zone`}
          />
        </StepCard>

        {/* EMA Settings */}
        <StepCard
          step={2}
          title="EMA (Exponential Moving Average)"
          description="แสดง 3 เส้น EMA พร้อม Settings ปรับแต่ง Period และสีได้"
          icon={<TrendingUp className="w-5 h-5" />}
        >
          <div className="text-slate-300 mb-4">
            <ul className="list-disc list-inside space-y-1 text-sm text-slate-400 mb-4">
              <li>EMA 1: ค่า Default 20 (สีฟ้า) - Short-term trend</li>
              <li>EMA 2: ค่า Default 50 (สีส้ม) - Medium-term trend</li>
              <li>EMA 3: ค่า Default 200 (สีม่วง) - Long-term trend</li>
            </ul>
          </div>
          <CodeBlock
            language="mql5"
            filename="EMA Settings"
            code={`//--- [ EMA SETTINGS ] ----------------------------------------------
input int      InpEMA1Period = 20;             // EMA 1 Period
input int      InpEMA2Period = 50;             // EMA 2 Period
input int      InpEMA3Period = 200;            // EMA 3 Period
input color    InpEMA1Color = clrDodgerBlue;   // EMA 1 Color
input color    InpEMA2Color = clrOrange;       // EMA 2 Color
input color    InpEMA3Color = clrMagenta;      // EMA 3 Color`}
          />
        </StepCard>

        {/* Bollinger Bands Settings */}
        <StepCard
          step={3}
          title="Bollinger Bands"
          description="แสดง Bollinger Bands (Upper, Middle, Lower)"
          icon={<Settings className="w-5 h-5" />}
        >
          <div className="text-slate-300 mb-4">
            <ul className="list-disc list-inside space-y-1 text-sm text-slate-400 mb-4">
              <li>Period: จำนวนแท่งเทียนที่ใช้คำนวณ (Default: 20)</li>
              <li>Deviation: ตัวคูณ Standard Deviation (Default: 2.0)</li>
              <li>MA Type: เลือกประเภท MA (SMA, EMA, SMMA, WMA)</li>
            </ul>
          </div>
          <CodeBlock
            language="mql5"
            filename="Bollinger Bands Settings"
            code={`//--- [ BOLLINGER BANDS SETTINGS ] ----------------------------------
input int      InpBBPeriod = 20;               // BB Period (Length)
input double   InpBBDeviation = 2.0;           // BB Deviation (StdDev Multiplier)
input color    InpBBUpperColor = clrRed;       // BB Upper Band Color
input color    InpBBLowerColor = clrGreen;     // BB Lower Band Color`}
          />
        </StepCard>

        {/* ZigZag Settings */}
        <StepCard
          step={4}
          title="ZigZag Indicator"
          description="แสดง ZigZag พร้อม Labels แสดง Market Structure (HH, HL, LH, LL)"
          icon={<TrendingUp className="w-5 h-5" />}
        >
          <div className="text-slate-300 mb-4">
            <ul className="list-disc list-inside space-y-1 text-sm text-slate-400 mb-4">
              <li><span className="text-green-400">HH/HL</span> - Bullish Structure</li>
              <li><span className="text-red-400">LH/LL</span> - Bearish Structure</li>
            </ul>
          </div>
          <CodeBlock
            language="mql5"
            filename="ZigZag Settings"
            code={`//--- [ ZIGZAG SETTINGS ] -------------------------------------------
input int      InpZZDepth = 12;                // ZigZag Depth
input int      InpZZDeviation = 5;             // ZigZag Deviation (pips)
input color    InpZZBullColor = clrLime;       // Bull Color (HL, HH)
input color    InpZZBearColor = clrRed;        // Bear Color (LH, LL)`}
          />
        </StepCard>

        {/* Price Action Settings */}
        <StepCard
          step={5}
          title="Price Action Patterns"
          description="ตรวจจับรูปแบบ Candlestick 12 รูปแบบ"
          icon={<Eye className="w-5 h-5" />}
        >
          <div className="text-slate-300 mb-4">
            <div className="grid md:grid-cols-2 gap-4 mb-4">
              <div className="bg-green-500/10 rounded-lg p-3 border border-green-500/30">
                <h4 className="text-green-400 font-semibold mb-2">Bullish (6)</h4>
                <ul className="text-sm text-slate-400 space-y-1">
                  <li>• Hammer, Engulfing, Tweezer Bottom</li>
                  <li>• Morning Star, Inside Candle, Hotdog</li>
                </ul>
              </div>
              <div className="bg-red-500/10 rounded-lg p-3 border border-red-500/30">
                <h4 className="text-red-400 font-semibold mb-2">Bearish (6)</h4>
                <ul className="text-sm text-slate-400 space-y-1">
                  <li>• Shooting Star, Engulfing, Tweezer Top</li>
                  <li>• Evening Star, Inside Candle, Hotdog</li>
                </ul>
              </div>
            </div>
          </div>
          <CodeBlock
            language="mql5"
            filename="Price Action Settings"
            code={`//--- [ PRICE ACTION SETTINGS ] -------------------------------------
input bool     InpPAHammer = true;             // Hammer / Pin Bar
input bool     InpPABullEngulfing = true;      // Bullish Engulfing
input bool     InpPAShootingStar = true;       // Shooting Star
input bool     InpPABearEngulfing = true;      // Bearish Engulfing`}
          />
        </StepCard>

        {/* CDC Settings */}
        <StepCard
          step={6}
          title="CDC Action Zone"
          description="ใช้ EMA 2 เส้นเพื่อระบุ Trend"
          icon={<TrendingUp className="w-5 h-5" />}
        >
          <div className="text-slate-300 mb-4">
            <ul className="list-disc list-inside space-y-1 text-sm text-slate-400 mb-4">
              <li><span className="text-green-400">Bull Zone:</span> Fast EMA {">"} Slow EMA</li>
              <li><span className="text-red-400">Bear Zone:</span> Fast EMA {"<"} Slow EMA</li>
            </ul>
          </div>
          <CodeBlock
            language="mql5"
            filename="CDC Settings"
            code={`//--- [ CDC ACTION ZONE SETTINGS ] ----------------------------------
input int      InpCDCFastPeriod = 12;          // CDC Fast EMA Period
input int      InpCDCSlowPeriod = 26;          // CDC Slow EMA Period
input color    InpCDCBullColor = clrLime;      // CDC Bull Zone Color
input color    InpCDCBearColor = clrRed;       // CDC Bear Zone Color`}
          />
        </StepCard>

        {/* Full Code Section */}
        <div className="mt-12">
          <div className="flex items-center justify-between mb-6">
            <h2 className="text-2xl font-bold text-white flex items-center gap-3">
              <FileCode className="w-6 h-6 text-cyan-400" />
              Full Indicator Code
            </h2>
            <button
              onClick={downloadIndicatorCode}
              className="flex items-center gap-2 px-4 py-2 bg-cyan-500 hover:bg-cyan-400 text-slate-900 font-semibold rounded-lg transition-colors"
            >
              <Download className="w-5 h-5" />
              <span>Download .mq5</span>
            </button>
          </div>
          <CodeBlock
            language="mql5"
            filename="MoneyxSmartIndicator.mq5"
            code={fullIndicatorCode}
          />
        </div>

        {/* Installation Guide */}
        <div className="mt-12 bg-slate-800/50 border border-cyan-500/30 rounded-xl p-6">
          <h3 className="text-xl font-bold text-white mb-4 flex items-center gap-2">
            <Info className="w-5 h-5 text-cyan-400" />
            วิธีติดตั้ง Indicator
          </h3>
          <ol className="list-decimal list-inside space-y-2 text-slate-300">
            <li>Download ไฟล์ <span className="text-cyan-400">MoneyxSmartIndicator.mq5</span></li>
            <li>เปิด MetaTrader 5 แล้วไปที่ <span className="text-cyan-400">File → Open Data Folder</span></li>
            <li>ไปที่โฟลเดอร์ <span className="text-cyan-400">MQL5 → Indicators</span></li>
            <li>วางไฟล์ .mq5 ลงในโฟลเดอร์</li>
            <li>กลับไปที่ MT5 แล้ว Compile (กด F7) หรือ Restart MT5</li>
            <li>ลาก Indicator ไปวางบน Chart</li>
            <li>ปรับ Settings ตามต้องการ</li>
          </ol>
        </div>

        {/* Link to EA Guide */}
        <div className="mt-8">
          <Link
            to="/mt5-ea-guide"
            className="block bg-slate-800/50 border border-cyan-500/30 rounded-xl p-6 hover:bg-slate-800/80 transition-colors group"
          >
            <div className="flex items-center gap-4">
              <div className="w-12 h-12 bg-cyan-500/20 rounded-lg flex items-center justify-center">
                <FileCode className="w-6 h-6 text-cyan-400" />
              </div>
              <div className="flex-1">
                <h3 className="text-lg font-semibold text-white group-hover:text-cyan-400 transition-colors">
                  ต้องการใช้กับ EA?
                </h3>
                <p className="text-slate-400">
                  ดูโค้ด EA (Expert Advisor) ฉบับเต็มสำหรับ MetaTrader 5 พร้อมใช้งาน
                </p>
              </div>
              <div className="text-cyan-400">→</div>
            </div>
          </Link>
        </div>

        {/* Footer */}
        <footer className="mt-16 text-center text-slate-500 text-sm pb-8">
          คู่มือนี้เป็นตัวอย่างเพื่อการศึกษา - กรุณาทดสอบอย่างละเอียดก่อนใช้งานจริง
        </footer>
      </div>
    </div>
  );
};

export default MT5IndicatorGuide;