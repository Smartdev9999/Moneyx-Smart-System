import { Link } from 'react-router-dom';
import { ArrowLeft, Settings, TrendingUp, TrendingDown, Shield, AlertTriangle, Download, FileCode, Info, Filter } from 'lucide-react';
import CodeBlock from '@/components/CodeBlock';
import StepCard from '@/components/StepCard';

const MT5EAGuide = () => {
  const fullEACode = `//+------------------------------------------------------------------+
//|                   ZigZag++ CDC Structure EA v4.0                   |
//|           Based on DevLucem ZigZag++ with CDC Action Zone          |
//|           + Grid Trading System (Loss & Profit Side)               |
//+------------------------------------------------------------------+
#property copyright "Trading Education"
#property link      ""
#property version   "4.00"
#property strict

// *** Include CTrade ***
#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| ===================== INPUT PARAMETERS ========================= |
//+------------------------------------------------------------------+

//--- [ ZIGZAG++ SETTINGS ] -----------------------------------------
input string   InpZigZagHeader = "=== ZIGZAG++ SETTINGS ===";  // ___
input ENUM_TIMEFRAMES InpZigZagTimeframe = PERIOD_CURRENT;  // ZigZag Timeframe
input int      InpDepth        = 12;          // ZigZag Depth
input int      InpDeviation    = 5;           // ZigZag Deviation (pips)
input int      InpBackstep     = 2;           // ZigZag Backstep
input color    InpBullColor    = clrLime;     // Bull Color (HL labels)
input color    InpBearColor    = clrRed;      // Bear Color (HH, LH labels)
input bool     InpShowLabels   = true;        // Show HH/HL/LH/LL Labels
input bool     InpShowLines    = true;        // Show ZigZag Lines

// ZigZag Signal Mode
enum ENUM_ZIGZAG_SIGNAL_MODE
{
   ZIGZAG_BOTH = 0,     // Both Signals (LL,HL=BUY | HH,LH=SELL)
   ZIGZAG_SINGLE = 1    // Single Signal (LL=BUY | HH=SELL)
};
input ENUM_ZIGZAG_SIGNAL_MODE InpZigZagSignalMode = ZIGZAG_BOTH;  // ZigZag Signal Mode

//--- [ CDC ACTION ZONE SETTINGS ] ----------------------------------
input string   InpCDCHeader    = "=== CDC ACTION ZONE SETTINGS ===";  // ___
input bool     InpUseCDCFilter = true;        // Use CDC Action Zone Filter
input ENUM_TIMEFRAMES InpCDCTimeframe = PERIOD_D1;  // CDC Filter Timeframe
input int      InpCDCFastPeriod = 12;         // CDC Fast EMA Period
input int      InpCDCSlowPeriod = 26;         // CDC Slow EMA Period
input bool     InpShowCDCLines = true;        // Show CDC Lines on Chart

//--- [ TRADE MODE SETTINGS ] ---------------------------------------
input string   InpTradeModeHeader = "=== TRADE MODE SETTINGS ===";  // ___
enum ENUM_TRADE_MODE
{
   TRADE_BUY_SELL = 0,  // Buy and Sell
   TRADE_BUY_ONLY = 1,  // Buy Only
   TRADE_SELL_ONLY = 2  // Sell Only
};
input ENUM_TRADE_MODE InpTradeMode = TRADE_BUY_SELL;  // Trade Mode

//--- [ TRADING SETTINGS ] ------------------------------------------
input string   InpTradingHeader = "=== TRADING SETTINGS ===";  // ___
enum ENUM_LOT_MODE
{
   LOT_FIXED = 0,       // Fixed Lot
   LOT_RISK_PERCENT = 1,  // Risk % of Balance
   LOT_RISK_DOLLAR = 2    // Fixed Dollar Risk
};
input ENUM_LOT_MODE InpLotMode = LOT_FIXED;  // Lot Mode
input double   InpInitialLot   = 0.01;       // Initial Lot Size
input double   InpRiskPercent  = 1.0;        // Risk % of Balance (for Risk Mode)
input double   InpRiskDollar   = 50.0;       // Fixed Dollar Risk (for Risk Mode)
input int      InpMagicNumber  = 123456;     // Magic Number

//--- [ GRID LOSS SIDE SETTINGS ] -----------------------------------
input string   InpGridLossHeader = "----- Grid Loss Side -----";  // ___
input int      InpGridLossMaxTrades = 5;     // Max Grid Trades (0 - Disable Grid Trade)

// Grid Lot Mode
enum ENUM_GRID_LOT_MODE
{
   GRID_LOT_CUSTOM = 0,    // Custom Lot (use string)
   GRID_LOT_ADD = 1        // Add Lot (InitialLot + AddLot*Level)
};
input ENUM_GRID_LOT_MODE InpGridLossLotMode = GRID_LOT_ADD;  // Grid Lot Mode
input string   InpGridLossCustomLot = "0.01;0.02;0.03;0.04;0.05";  // Custom Lot (separate by semicolon ;)
input double   InpGridLossAddLot = 0.4;      // Add Lot per Level (0 = Same as Initial)

// Grid Gap Mode
enum ENUM_GRID_GAP_TYPE
{
   GAP_FIXED_POINTS = 0,    // Fixed Points
   GAP_CUSTOM_DISTANCE = 1  // Custom Distance
};
input ENUM_GRID_GAP_TYPE InpGridLossGapType = GAP_FIXED_POINTS;  // Grid Gap Type
input int      InpGridLossPoints = 50;       // Grid Points (points)
input string   InpGridLossCustomDist = "100;200;300;400;500";  // Custom Grid Distance (separate by semicolon ;)

input bool     InpGridLossOnlySignal = false;  // Grid Trade Only in Signal
input bool     InpGridLossNewCandle = true;    // Grid Trade Only New Candle
input bool     InpGridLossDontOpenSameCandle = true;  // Don't Open in Same Initial Candle

//--- [ GRID PROFIT SIDE SETTINGS ] ---------------------------------
input string   InpGridProfitHeader = "----- Grid Profit Side -----";  // ___
input bool     InpUseGridProfit = true;      // Use Profit Grid
input int      InpGridProfitMaxTrades = 3;   // Max Grid Trades (0 - Disable Grid Trade)

// Grid Lot Mode
input ENUM_GRID_LOT_MODE InpGridProfitLotMode = GRID_LOT_ADD;  // Grid Lot Mode
input string   InpGridProfitCustomLot = "0.01;0.02;0.03;0.04;0.05";  // Custom Lot (separate by semicolon ;)
input double   InpGridProfitAddLot = 0.4;    // Add Lot per Level (0 = Same as Initial)

// Grid Gap Mode
input ENUM_GRID_GAP_TYPE InpGridProfitGapType = GAP_CUSTOM_DISTANCE;  // Grid Gap Type
input int      InpGridProfitPoints = 100;    // Grid Points (points)
input string   InpGridProfitCustomDist = "100;200;500";  // Custom Grid Distance (separate by semicolon ;)

input bool     InpGridProfitOnlySignal = false;  // Grid Trade Only in Signal
input bool     InpGridProfitNewCandle = true;    // Grid Trade Only New Candle
input bool     InpGridProfitDontOpenSameCandle = true;  // Don't Open in Same Initial Candle
//--- [ TAKE PROFIT SETTINGS ] --------------------------------------
input string   InpTPHeader = "=== TAKE PROFIT SETTINGS ===";  // ___

// TP Fixed Dollar
input bool     InpUseTPDollar = true;        // Use TP Fixed Dollar
input double   InpTPDollarAmount = 100.0;    // TP Dollar Amount ($)

// TP in Points
input bool     InpUseTPPoints = false;       // Use TP in Points (from Average Price)
input int      InpTPPoints = 2000;           // TP Points (points)

// TP Percent of Balance
input bool     InpUseTPPercent = false;      // Use TP % of Balance
input double   InpTPPercent = 5.0;           // TP Percent of Balance (%)

// Group TP (Accumulated Profit)
input bool     InpUseGroupTP = false;        // Use Group TP (Accumulated)
input double   InpGroupTPAmount = 3000.0;    // Group TP Target ($)

// Visual Lines
input bool     InpShowAverageLine = true;    // Show Average Price Line
input bool     InpShowTPLine = true;         // Show TP Line
input color    InpAverageLineColor = clrYellow;  // Average Line Color
input color    InpTPLineColor = clrLime;     // TP Line Color

//--- [ STOP LOSS SETTINGS ] ----------------------------------------
input string   InpSLHeader = "=== STOP LOSS SETTINGS ===";  // ___

// SL Fixed Dollar
input bool     InpUseSLDollar = true;        // Use SL Fixed Dollar
input double   InpSLDollarAmount = 50.0;     // SL Dollar Amount ($)

// SL in Points
input bool     InpUseSLPoints = false;       // Use SL in Points (from Average Price)
input int      InpSLPoints = 1000;           // SL Points (points)

// SL Percent of Balance
input bool     InpUseSLPercent = false;      // Use SL % of Balance
input double   InpSLPercent = 3.0;           // SL Percent of Balance (%)

// Visual Lines
input bool     InpShowSLLine = true;         // Show SL Line
input color    InpSLLineColor = clrRed;      // SL Line Color

//--- [ TIME FILTER ] -----------------------------------------------
input string   InpTimeHeader   = "=== TIME FILTER ===";  // ___
input bool     InpUseTimeFilter = false;      // Use Time Filter
input int      InpStartHour    = 8;           // Start Hour
input int      InpEndHour      = 20;          // End Hour

//+------------------------------------------------------------------+
//| ===================== GLOBAL VARIABLES ========================= |
//+------------------------------------------------------------------+

// ZigZag++ Structure (based on DevLucem ZigZag++)
struct ZigZagPoint
{
   double    price;
   datetime  time;
   int       barIndex;
   int       direction;  // 1 = High, -1 = Low
   string    label;      // "HH", "HL", "LH", "LL"
};

ZigZagPoint ZZPoints[];
int ZZPointCount = 0;
string LastZZLabel = "";       // Latest closed ZigZag label
int CurrentDirection = 0;       // Current ZigZag direction

// Trade Objects
CTrade trade;

// CDC Action Zone Variables
string CDCTrend = "NEUTRAL";
double CDCFast = 0;
double CDCSlow = 0;
double CDCAP = 0;
color CDCZoneColor = clrWhite;

// Chart Objects Prefix
string ZZPrefix = "ZZ_";
string CDCPrefix = "CDC_";
string TPPrefix = "TP_";

// ZigZag tracking for confirmed points
datetime LastConfirmedZZTime = 0;

// Grid Tracking
datetime InitialBuyBarTime = 0;
datetime InitialSellBarTime = 0;
int GridBuyCount = 0;
int GridSellCount = 0;
datetime LastGridBuyTime = 0;
datetime LastGridSellTime = 0;

// Group TP Accumulated Profit Tracking
double AccumulatedProfit = 0.0;
double LastClosedProfit = 0.0;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("===========================================");
   Print("ZigZag++ CDC Structure EA v4.0 + Grid");
   Print("Symbol: ", _Symbol);
   Print("Entry TF: ", EnumToString(Period()));
   Print("CDC Filter TF: ", EnumToString(InpCDCTimeframe));
   Print("Trade Mode: ", EnumToString(InpTradeMode));
   Print("Lot Mode: ", EnumToString(InpLotMode));
   Print("Grid Loss Max: ", InpGridLossMaxTrades);
   Print("Grid Profit Max: ", InpGridProfitMaxTrades);
   Print("===========================================");
   
   trade.SetExpertMagicNumber(InpMagicNumber);
   
   // Reset counters
   LastConfirmedZZTime = 0;
   GridBuyCount = 0;
   GridSellCount = 0;
   InitialBuyBarTime = 0;
   InitialSellBarTime = 0;
   
   Print("EA Started Successfully!");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Remove all chart objects
   ObjectsDeleteAll(0, ZZPrefix);
   ObjectsDeleteAll(0, CDCPrefix);
   ObjectsDeleteAll(0, TPPrefix);
   
   Comment("");
   Print("EA Stopped - Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Parse semicolon-separated string to array                          |
//+------------------------------------------------------------------+
void ParseStringToDoubleArray(string inputStr, double &arr[])
{
   string parts[];
   ushort sep = StringGetCharacter(";", 0);
   int count = StringSplit(inputStr, sep, parts);
   ArrayResize(arr, count);
   for(int i = 0; i < count; i++)
   {
      arr[i] = StringToDouble(parts[i]);
   }
}

void ParseStringToIntArray(string inputStr, int &arr[])
{
   string parts[];
   ushort sep = StringGetCharacter(";", 0);
   int count = StringSplit(inputStr, sep, parts);
   ArrayResize(arr, count);
   for(int i = 0; i < count; i++)
   {
      arr[i] = (int)StringToInteger(parts[i]);
   }
}

//+------------------------------------------------------------------+
//| Get Lot Size for Grid based on level                               |
//| gridLevel = 0 is the FIRST order (uses InitialLot)                |
//| gridLevel = 1,2,3... are GRID orders                              |
//+------------------------------------------------------------------+
double GetGridLotSize(bool isLossSide, int gridLevel)
{
   ENUM_GRID_LOT_MODE lotMode = isLossSide ? InpGridLossLotMode : InpGridProfitLotMode;
   double calculatedLot = InpInitialLot;
   
   if(lotMode == GRID_LOT_CUSTOM)
   {
      // Custom Lot Mode: Use the lot array from string
      double lots[];
      if(isLossSide)
         ParseStringToDoubleArray(InpGridLossCustomLot, lots);
      else
         ParseStringToDoubleArray(InpGridProfitCustomLot, lots);
      
      if(gridLevel < ArraySize(lots))
         calculatedLot = lots[gridLevel];
      else if(ArraySize(lots) > 0)
         calculatedLot = lots[ArraySize(lots) - 1];  // Use last value for levels beyond array
   }
   else  // GRID_LOT_ADD
   {
      // Add Lot Mode: InitialLot + (AddLot * gridLevel)
      double addLot = isLossSide ? InpGridLossAddLot : InpGridProfitAddLot;
      
      // Grid level 0 = First order = Initial Lot
      // Grid level 1 = Second order = Initial Lot + AddLot
      // Grid level 2 = Third order = Initial Lot + AddLot*2
      calculatedLot = InpInitialLot + (addLot * gridLevel);
   }
   
   // Normalize lot size to broker requirements
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   calculatedLot = MathMax(minLot, calculatedLot);
   calculatedLot = MathMin(maxLot, calculatedLot);
   calculatedLot = MathFloor(calculatedLot / lotStep) * lotStep;
   
   return NormalizeDouble(calculatedLot, 2);
}

//+------------------------------------------------------------------+
//| Get Grid Distance for level                                        |
//+------------------------------------------------------------------+
int GetGridDistance(bool isLossSide, int gridLevel)
{
   ENUM_GRID_GAP_TYPE gapType = isLossSide ? InpGridLossGapType : InpGridProfitGapType;
   int fixedPoints = isLossSide ? InpGridLossPoints : InpGridProfitPoints;
   string customDist = isLossSide ? InpGridLossCustomDist : InpGridProfitCustomDist;
   
   if(gapType == GAP_FIXED_POINTS)
      return fixedPoints;
   
   // Custom Distance
   int distances[];
   ParseStringToIntArray(customDist, distances);
   
   if(gridLevel < ArraySize(distances))
      return distances[gridLevel];
   else if(ArraySize(distances) > 0)
      return distances[ArraySize(distances) - 1];
   
   return fixedPoints;
}

//+------------------------------------------------------------------+
//| ZigZag++ Algorithm (Based on DevLucem Pine Script)                |
//+------------------------------------------------------------------+
void CalculateZigZagPP()
{
   // Clear previous points
   ArrayResize(ZZPoints, 0);
   ZZPointCount = 0;
   
   // Remove old objects
   ObjectsDeleteAll(0, ZZPrefix);
   
   int barsToAnalyze = 200;
   
   // Buffers for ZigZag calculation
   double zigzagVal[];
   int zigzagDir[];      // 1 = high point, -1 = low point
   datetime zigzagTime[];
   int zigzagBar[];
   
   ArrayResize(zigzagVal, barsToAnalyze);
   ArrayResize(zigzagDir, barsToAnalyze);
   ArrayResize(zigzagTime, barsToAnalyze);
   ArrayResize(zigzagBar, barsToAnalyze);
   
   ArrayInitialize(zigzagVal, 0);
   ArrayInitialize(zigzagDir, 0);
   
   // Find swing highs and lows using Depth, Deviation, Backstep
   double lastHigh = 0, lastLow = DBL_MAX;
   int lastHighBar = 0, lastLowBar = 0;
   int direction = 0;  // 0 = unknown, 1 = up, -1 = down
   
   double deviationPips = InpDeviation * _Point * 10;
   
   // First pass: Find potential swing points
   double swingHigh[], swingLow[];
   int swingHighBar[], swingLowBar[];
   ArrayResize(swingHigh, 0);
   ArrayResize(swingLow, 0);
   ArrayResize(swingHighBar, 0);
   ArrayResize(swingLowBar, 0);
   
   for(int i = InpDepth; i < barsToAnalyze - InpDepth; i++)
   {
      // Check for swing high
      double high = iHigh(_Symbol, InpZigZagTimeframe, i);
      bool isSwingHigh = true;
      for(int j = 1; j <= InpDepth; j++)
      {
         if(iHigh(_Symbol, InpZigZagTimeframe, i - j) >= high || 
            iHigh(_Symbol, InpZigZagTimeframe, i + j) >= high)
         {
            isSwingHigh = false;
            break;
         }
      }
      
      if(isSwingHigh)
      {
         int size = ArraySize(swingHigh);
         ArrayResize(swingHigh, size + 1);
         ArrayResize(swingHighBar, size + 1);
         swingHigh[size] = high;
         swingHighBar[size] = i;
      }
      
      // Check for swing low
      double low = iLow(_Symbol, InpZigZagTimeframe, i);
      bool isSwingLow = true;
      for(int j = 1; j <= InpDepth; j++)
      {
         if(iLow(_Symbol, InpZigZagTimeframe, i - j) <= low || 
            iLow(_Symbol, InpZigZagTimeframe, i + j) <= low)
         {
            isSwingLow = false;
            break;
         }
      }
      
      if(isSwingLow)
      {
         int size = ArraySize(swingLow);
         ArrayResize(swingLow, size + 1);
         ArrayResize(swingLowBar, size + 1);
         swingLow[size] = low;
         swingLowBar[size] = i;
      }
   }
   
   // Build ZigZag from swing points (alternating high-low-high-low)
   double zzPrices[];
   int zzBars[];
   int zzDirs[];
   ArrayResize(zzPrices, 0);
   ArrayResize(zzBars, 0);
   ArrayResize(zzDirs, 0);
   
   int hiIdx = 0, loIdx = 0;
   int lastDir = 0;
   
   // Merge swing highs and lows in time order (newest first)
   while(hiIdx < ArraySize(swingHighBar) || loIdx < ArraySize(swingLowBar))
   {
      bool useHigh = false;
      
      if(hiIdx >= ArraySize(swingHighBar))
         useHigh = false;
      else if(loIdx >= ArraySize(swingLowBar))
         useHigh = true;
      else
         useHigh = (swingHighBar[hiIdx] < swingLowBar[loIdx]);
      
      if(useHigh)
      {
         if(lastDir != 1)  // Can add high after low or at start
         {
            int size = ArraySize(zzPrices);
            ArrayResize(zzPrices, size + 1);
            ArrayResize(zzBars, size + 1);
            ArrayResize(zzDirs, size + 1);
            zzPrices[size] = swingHigh[hiIdx];
            zzBars[size] = swingHighBar[hiIdx];
            zzDirs[size] = 1;
            lastDir = 1;
         }
         else if(ArraySize(zzPrices) > 0 && swingHigh[hiIdx] > zzPrices[ArraySize(zzPrices)-1])
         {
            // Replace last high with higher high
            zzPrices[ArraySize(zzPrices)-1] = swingHigh[hiIdx];
            zzBars[ArraySize(zzBars)-1] = swingHighBar[hiIdx];
         }
         hiIdx++;
      }
      else
      {
         if(lastDir != -1)  // Can add low after high or at start
         {
            int size = ArraySize(zzPrices);
            ArrayResize(zzPrices, size + 1);
            ArrayResize(zzBars, size + 1);
            ArrayResize(zzDirs, size + 1);
            zzPrices[size] = swingLow[loIdx];
            zzBars[size] = swingLowBar[loIdx];
            zzDirs[size] = -1;
            lastDir = -1;
         }
         else if(ArraySize(zzPrices) > 0 && swingLow[loIdx] < zzPrices[ArraySize(zzPrices)-1])
         {
            // Replace last low with lower low
            zzPrices[ArraySize(zzPrices)-1] = swingLow[loIdx];
            zzBars[ArraySize(zzBars)-1] = swingLowBar[loIdx];
         }
         loIdx++;
      }
      
      if(ArraySize(zzPrices) >= 20) break;  // Limit points
   }
   
   // Now label the points as HH, HL, LH, LL
   double lastHighPoint = 0;
   double lastLowPoint = DBL_MAX;
   
   // Process from oldest to newest for proper labeling
   for(int i = ArraySize(zzPrices) - 1; i >= 0; i--)
   {
      ZigZagPoint zp;
      zp.price = zzPrices[i];
      zp.barIndex = zzBars[i];
      zp.time = iTime(_Symbol, InpZigZagTimeframe, zzBars[i]);
      zp.direction = zzDirs[i];
      
      if(zzDirs[i] == 1)  // High point
      {
         if(lastHighPoint > 0)
         {
            if(zzPrices[i] > lastHighPoint)
               zp.label = "HH";
            else
               zp.label = "LH";
         }
         else
            zp.label = "HH";  // First high
            
         lastHighPoint = zzPrices[i];
      }
      else  // Low point
      {
         if(lastLowPoint < DBL_MAX)
         {
            if(zzPrices[i] < lastLowPoint)
               zp.label = "LL";
            else
               zp.label = "HL";
         }
         else
            zp.label = "LL";  // First low
            
         lastLowPoint = zzPrices[i];
      }
      
      int size = ArraySize(ZZPoints);
      ArrayResize(ZZPoints, size + 1);
      ZZPoints[size] = zp;
      ZZPointCount++;
   }
   
   // Reverse to have newest first
   ZigZagPoint tempPoints[];
   ArrayResize(tempPoints, ZZPointCount);
   for(int i = 0; i < ZZPointCount; i++)
      tempPoints[i] = ZZPoints[ZZPointCount - 1 - i];
   
   ArrayResize(ZZPoints, ZZPointCount);
   for(int i = 0; i < ZZPointCount; i++)
      ZZPoints[i] = tempPoints[i];
   
   // Draw ZigZag lines and labels
   if(InpShowLines || InpShowLabels)
   {
      DrawZigZagOnChart();
   }
   
   // Set last label for trading signal
   if(ZZPointCount > 0)
   {
      LastZZLabel = ZZPoints[0].label;
      CurrentDirection = ZZPoints[0].direction;
   }
}

//+------------------------------------------------------------------+
//| Draw ZigZag++ Lines and Labels on Chart                           |
//+------------------------------------------------------------------+
void DrawZigZagOnChart()
{
   for(int i = 0; i < ZZPointCount - 1; i++)
   {
      ZigZagPoint p1 = ZZPoints[i];
      ZigZagPoint p2 = ZZPoints[i + 1];
      
      // Draw line
      if(InpShowLines)
      {
         string lineName = ZZPrefix + "Line_" + IntegerToString(i);
         color lineColor = (p1.direction == 1) ? InpBearColor : InpBullColor;
         
         ObjectCreate(0, lineName, OBJ_TREND, 0, p2.time, p2.price, p1.time, p1.price);
         ObjectSetInteger(0, lineName, OBJPROP_COLOR, lineColor);
         ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, lineName, OBJPROP_BACK, false);
      }
      
      // Draw label on p1 (current point)
      if(InpShowLabels)
      {
         string labelName = ZZPrefix + "Label_" + IntegerToString(i);
         color labelColor = (p1.label == "LL" || p1.label == "HL") ? InpBullColor : InpBearColor;
         ENUM_ANCHOR_POINT anchor = (p1.direction == 1) ? ANCHOR_LOWER : ANCHOR_UPPER;
         
         ObjectCreate(0, labelName, OBJ_TEXT, 0, p1.time, p1.price);
         ObjectSetString(0, labelName, OBJPROP_TEXT, p1.label);
         ObjectSetInteger(0, labelName, OBJPROP_COLOR, labelColor);
         ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);
         ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
         ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, anchor);
      }
   }
   
   // Draw label for last point
   if(InpShowLabels && ZZPointCount > 0)
   {
      int last = ZZPointCount - 1;
      string labelName = ZZPrefix + "Label_" + IntegerToString(last);
      color labelColor = (ZZPoints[last].label == "LL" || ZZPoints[last].label == "HL") ? 
                          InpBullColor : InpBearColor;
      ENUM_ANCHOR_POINT anchor = (ZZPoints[last].direction == 1) ? ANCHOR_LOWER : ANCHOR_UPPER;
      
      ObjectCreate(0, labelName, OBJ_TEXT, 0, ZZPoints[last].time, ZZPoints[last].price);
      ObjectSetString(0, labelName, OBJPROP_TEXT, ZZPoints[last].label);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, labelColor);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, anchor);
   }
}

//+------------------------------------------------------------------+
//| Calculate CDC Action Zone Values                                   |
//+------------------------------------------------------------------+
void CalculateCDC()
{
   if(!InpUseCDCFilter)
   {
      CDCTrend = "NEUTRAL";
      CDCZoneColor = clrWhite;
      return;
   }
   
   double closeArr[], highArr[], lowArr[], openArr[];
   datetime timeArr[];
   ArraySetAsSeries(closeArr, true);
   ArraySetAsSeries(highArr, true);
   ArraySetAsSeries(lowArr, true);
   ArraySetAsSeries(openArr, true);
   ArraySetAsSeries(timeArr, true);
   
   int barsNeeded = InpCDCSlowPeriod * 3 + 50;
   
   if(CopyClose(_Symbol, InpCDCTimeframe, 0, barsNeeded, closeArr) < barsNeeded) return;
   if(CopyHigh(_Symbol, InpCDCTimeframe, 0, barsNeeded, highArr) < barsNeeded) return;
   if(CopyLow(_Symbol, InpCDCTimeframe, 0, barsNeeded, lowArr) < barsNeeded) return;
   if(CopyOpen(_Symbol, InpCDCTimeframe, 0, barsNeeded, openArr) < barsNeeded) return;
   if(CopyTime(_Symbol, InpCDCTimeframe, 0, barsNeeded, timeArr) < barsNeeded) return;
   
   double ohlc4[];
   ArrayResize(ohlc4, barsNeeded);
   for(int i = 0; i < barsNeeded; i++)
   {
      ohlc4[i] = (openArr[i] + highArr[i] + lowArr[i] + closeArr[i]) / 4.0;
   }
   
   double ap[];
   ArrayResize(ap, barsNeeded);
   CalculateEMA(ohlc4, ap, 2, barsNeeded);
   
   double fast[];
   ArrayResize(fast, barsNeeded);
   CalculateEMA(ap, fast, InpCDCFastPeriod, barsNeeded);
   
   double slow[];
   ArrayResize(slow, barsNeeded);
   CalculateEMA(ap, slow, InpCDCSlowPeriod, barsNeeded);
   
   CDCAP = ap[0];
   CDCFast = fast[0];
   CDCSlow = slow[0];
   
   // Simple CDC: Fast above Slow = BULLISH, Fast below Slow = BEARISH
   if(CDCFast > CDCSlow)
   {
      CDCTrend = "BULLISH";
      CDCZoneColor = clrLime;
   }
   else if(CDCFast < CDCSlow)
   {
      CDCTrend = "BEARISH";
      CDCZoneColor = clrRed;
   }
   else
   {
      CDCTrend = "NEUTRAL";
      CDCZoneColor = clrWhite;
   }
   
   if(InpShowCDCLines)
   {
      DrawCDCOnChart(fast, slow, timeArr, barsNeeded);
   }
}

//+------------------------------------------------------------------+
//| Calculate EMA Array                                                |
//+------------------------------------------------------------------+
void CalculateEMA(double &src[], double &result[], int period, int size)
{
   if(size < period) return;
   
   double multiplier = 2.0 / (period + 1);
   
   double sum = 0;
   for(int i = size - period; i < size; i++)
   {
      sum += src[i];
   }
   result[size - 1] = sum / period;
   
   for(int i = size - 2; i >= 0; i--)
   {
      result[i] = (src[i] - result[i + 1]) * multiplier + result[i + 1];
   }
}

//+------------------------------------------------------------------+
//| Draw CDC Lines on Chart                                            |
//+------------------------------------------------------------------+
void DrawCDCOnChart(double &fast[], double &slow[], datetime &time[], int size)
{
   ObjectsDeleteAll(0, CDCPrefix);
   
   int maxBars = MathMin(100, size - 1);
   
   for(int i = 0; i < maxBars; i++)
   {
      string lineName = CDCPrefix + "Fast_" + IntegerToString(i);
      datetime t1 = time[i + 1];
      datetime t2 = time[i];
      
      ObjectCreate(0, lineName, OBJ_TREND, 0, t1, fast[i + 1], t2, fast[i]);
      ObjectSetInteger(0, lineName, OBJPROP_COLOR, clrOrangeRed);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
   }
   
   for(int i = 0; i < maxBars; i++)
   {
      string lineName = CDCPrefix + "Slow_" + IntegerToString(i);
      datetime t1 = time[i + 1];
      datetime t2 = time[i];
      
      ObjectCreate(0, lineName, OBJ_TREND, 0, t1, slow[i + 1], t2, slow[i]);
      ObjectSetInteger(0, lineName, OBJPROP_COLOR, clrDodgerBlue);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 3);
      ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
   }
   
   string labelName = CDCPrefix + "Status_Label";
   ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, 50);
   ObjectSetString(0, labelName, OBJPROP_TEXT, "CDC (" + EnumToString(InpCDCTimeframe) + "): " + CDCTrend);
   ObjectSetInteger(0, labelName, OBJPROP_COLOR, CDCZoneColor);
   ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 12);
   ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
}

//+------------------------------------------------------------------+
//| Check if trade is allowed based on Trade Mode and CDC             |
//+------------------------------------------------------------------+
bool IsTradeAllowed(string tradeType)
{
   if(tradeType == "BUY")
   {
      if(InpTradeMode == TRADE_SELL_ONLY)
         return false;
   }
   else if(tradeType == "SELL")
   {
      if(InpTradeMode == TRADE_BUY_ONLY)
         return false;
   }
   
   if(InpUseCDCFilter)
   {
      if(tradeType == "BUY" && CDCTrend != "BULLISH")
         return false;
      if(tradeType == "SELL" && CDCTrend != "BEARISH")
         return false;
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Get Trade Mode description                                         |
//+------------------------------------------------------------------+
string GetTradeModeString()
{
   switch(InpTradeMode)
   {
      case TRADE_BUY_ONLY:  return "BUY ONLY";
      case TRADE_SELL_ONLY: return "SELL ONLY";
      default:              return "BUY/SELL";
   }
}

//+------------------------------------------------------------------+
//| Calculate Lot Size based on Lot Mode                               |
//+------------------------------------------------------------------+
double CalculateLotSize()
{
   double lot = InpInitialLot;
   
   if(InpLotMode == LOT_RISK_PERCENT)
   {
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskAmount = balance * InpRiskPercent / 100.0;
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double pipValue = tickValue * (10 * _Point / tickSize);
      lot = riskAmount / (InpSLPoints * pipValue);
   }
   else if(InpLotMode == LOT_RISK_DOLLAR)
   {
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double pipValue = tickValue * (10 * _Point / tickSize);
      lot = InpRiskDollar / (InpSLPoints * pipValue);
   }
   
   // Normalize lot size
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lot = MathMax(minLot, MathMin(maxLot, lot));
   lot = MathFloor(lot / lotStep) * lotStep;
   
   return lot;
}

//+------------------------------------------------------------------+
//| Get Total Floating Profit/Loss for this EA                         |
//+------------------------------------------------------------------+
double GetTotalFloatingPL()
{
   double totalPL = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            totalPL += PositionGetDouble(POSITION_PROFIT);
         }
      }
   }
   return totalPL;
}

//+------------------------------------------------------------------+
//| Get Floating PL by Position Type (BUY/SELL)                        |
//+------------------------------------------------------------------+
double GetFloatingPLByType(ENUM_POSITION_TYPE posType)
{
   double pl = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            if(PositionGetInteger(POSITION_TYPE) == posType)
            {
               pl += PositionGetDouble(POSITION_PROFIT);
            }
         }
      }
   }
   return pl;
}

//+------------------------------------------------------------------+
//| Get Average Price and Total Lots by Position Type                  |
//+------------------------------------------------------------------+
void GetAveragePriceAndLots(ENUM_POSITION_TYPE posType, double &avgPrice, double &totalLots)
{
   double sumPriceLot = 0;
   totalLots = 0;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            if(PositionGetInteger(POSITION_TYPE) == posType)
            {
               double price = PositionGetDouble(POSITION_PRICE_OPEN);
               double lot = PositionGetDouble(POSITION_VOLUME);
               sumPriceLot += price * lot;
               totalLots += lot;
            }
         }
      }
   }
   
   if(totalLots > 0)
      avgPrice = sumPriceLot / totalLots;
   else
      avgPrice = 0;
}

//+------------------------------------------------------------------+
//| Calculate TP Price based on Average Price and TP Points            |
//+------------------------------------------------------------------+
double CalculateTPPrice(ENUM_POSITION_TYPE posType, double avgPrice)
{
   if(!InpUseTPPoints || avgPrice == 0) return 0;
   
   if(posType == POSITION_TYPE_BUY)
      return avgPrice + InpTPPoints * _Point;
   else
      return avgPrice - InpTPPoints * _Point;
}

//+------------------------------------------------------------------+
//| Calculate SL Price based on Average Price and SL Points            |
//+------------------------------------------------------------------+
double CalculateSLPrice(ENUM_POSITION_TYPE posType, double avgPrice)
{
   if(!InpUseSLPoints || avgPrice == 0) return 0;
   
   if(posType == POSITION_TYPE_BUY)
      return avgPrice - InpSLPoints * _Point;
   else
      return avgPrice + InpSLPoints * _Point;
}

//+------------------------------------------------------------------+
//| Draw Average Price, TP and SL Lines                                |
//+------------------------------------------------------------------+
void DrawTPSLLines()
{
   // Remove old lines
   ObjectsDeleteAll(0, TPPrefix);
   
   double avgBuy, lotsBuy, avgSell, lotsSell;
   GetAveragePriceAndLots(POSITION_TYPE_BUY, avgBuy, lotsBuy);
   GetAveragePriceAndLots(POSITION_TYPE_SELL, avgSell, lotsSell);
   
   datetime startTime = iTime(_Symbol, PERIOD_D1, 10);
   datetime endTime = TimeCurrent() + 86400 * 5;
   
   // Draw BUY Average Line and TP/SL
   if(avgBuy > 0 && InpShowAverageLine)
   {
      string lineName = TPPrefix + "AvgBuy";
      ObjectCreate(0, lineName, OBJ_HLINE, 0, 0, avgBuy);
      ObjectSetInteger(0, lineName, OBJPROP_COLOR, InpAverageLineColor);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetString(0, lineName, OBJPROP_TEXT, "AVG BUY: " + DoubleToString(avgBuy, _Digits));
      
      // TP Line for BUY
      if(InpShowTPLine && InpUseTPPoints)
      {
         double tpPrice = CalculateTPPrice(POSITION_TYPE_BUY, avgBuy);
         string tpLineName = TPPrefix + "TPBuy";
         ObjectCreate(0, tpLineName, OBJ_HLINE, 0, 0, tpPrice);
         ObjectSetInteger(0, tpLineName, OBJPROP_COLOR, InpTPLineColor);
         ObjectSetInteger(0, tpLineName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, tpLineName, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetString(0, tpLineName, OBJPROP_TEXT, "TP BUY: " + DoubleToString(tpPrice, _Digits));
      }
      
      // SL Line for BUY
      if(InpShowSLLine && InpUseSLPoints)
      {
         double slPrice = CalculateSLPrice(POSITION_TYPE_BUY, avgBuy);
         string slLineName = TPPrefix + "SLBuy";
         ObjectCreate(0, slLineName, OBJ_HLINE, 0, 0, slPrice);
         ObjectSetInteger(0, slLineName, OBJPROP_COLOR, InpSLLineColor);
         ObjectSetInteger(0, slLineName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, slLineName, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetString(0, slLineName, OBJPROP_TEXT, "SL BUY: " + DoubleToString(slPrice, _Digits));
      }
   }
   
   // Draw SELL Average Line and TP/SL
   if(avgSell > 0 && InpShowAverageLine)
   {
      string lineName = TPPrefix + "AvgSell";
      ObjectCreate(0, lineName, OBJ_HLINE, 0, 0, avgSell);
      ObjectSetInteger(0, lineName, OBJPROP_COLOR, InpAverageLineColor);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetString(0, lineName, OBJPROP_TEXT, "AVG SELL: " + DoubleToString(avgSell, _Digits));
      
      // TP Line for SELL
      if(InpShowTPLine && InpUseTPPoints)
      {
         double tpPrice = CalculateTPPrice(POSITION_TYPE_SELL, avgSell);
         string tpLineName = TPPrefix + "TPSell";
         ObjectCreate(0, tpLineName, OBJ_HLINE, 0, 0, tpPrice);
         ObjectSetInteger(0, tpLineName, OBJPROP_COLOR, InpTPLineColor);
         ObjectSetInteger(0, tpLineName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, tpLineName, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetString(0, tpLineName, OBJPROP_TEXT, "TP SELL: " + DoubleToString(tpPrice, _Digits));
      }
      
      // SL Line for SELL
      if(InpShowSLLine && InpUseSLPoints)
      {
         double slPrice = CalculateSLPrice(POSITION_TYPE_SELL, avgSell);
         string slLineName = TPPrefix + "SLSell";
         ObjectCreate(0, slLineName, OBJ_HLINE, 0, 0, slPrice);
         ObjectSetInteger(0, slLineName, OBJPROP_COLOR, InpSLLineColor);
         ObjectSetInteger(0, slLineName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, slLineName, OBJPROP_STYLE, STYLE_DOT);
         ObjectSetString(0, slLineName, OBJPROP_TEXT, "SL SELL: " + DoubleToString(slPrice, _Digits));
      }
   }
}

//+------------------------------------------------------------------+
//| Close positions by type                                            |
//+------------------------------------------------------------------+
double ClosePositionsByType(ENUM_POSITION_TYPE posType)
{
   double closedProfit = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            if(PositionGetInteger(POSITION_TYPE) == posType)
            {
               closedProfit += PositionGetDouble(POSITION_PROFIT);
               ulong ticket = PositionGetInteger(POSITION_TICKET);
               trade.PositionClose(ticket);
            }
         }
      }
   }
   
   // Reset grid counters for this side
   if(posType == POSITION_TYPE_BUY)
   {
      GridBuyCount = 0;
      InitialBuyBarTime = 0;
   }
   else
   {
      GridSellCount = 0;
      InitialSellBarTime = 0;
   }
   
   return closedProfit;
}

//+------------------------------------------------------------------+
//| Close All Positions                                                |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetSymbol(i) == _Symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            ulong ticket = PositionGetInteger(POSITION_TICKET);
            trade.PositionClose(ticket);
         }
      }
   }
   
   // Reset all counters
   GridBuyCount = 0;
   GridSellCount = 0;
   InitialBuyBarTime = 0;
   InitialSellBarTime = 0;
   AccumulatedProfit = 0;
}

//+------------------------------------------------------------------+
//| Check TP/SL Conditions (Advanced Close Logic)                      |
//+------------------------------------------------------------------+
void CheckTPSLConditions()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double totalPL = GetTotalFloatingPL();
   double buyPL = GetFloatingPLByType(POSITION_TYPE_BUY);
   double sellPL = GetFloatingPLByType(POSITION_TYPE_SELL);
   
   int buyCount = CountPositions(POSITION_TYPE_BUY);
   int sellCount = CountPositions(POSITION_TYPE_SELL);
   
   double avgBuy, lotsBuy, avgSell, lotsSell;
   GetAveragePriceAndLots(POSITION_TYPE_BUY, avgBuy, lotsBuy);
   GetAveragePriceAndLots(POSITION_TYPE_SELL, avgSell, lotsSell);
   
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   // ========== TAKE PROFIT LOGIC ==========
   
   // 1. TP Fixed Dollar - Close each side when reaches target
   if(InpUseTPDollar)
   {
      if(buyPL >= InpTPDollarAmount && buyCount > 0)
      {
         Print("TP Dollar - BUY side reached $", buyPL);
         double closed = ClosePositionsByType(POSITION_TYPE_BUY);
         if(InpUseGroupTP) AccumulatedProfit += closed;
      }
      if(sellPL >= InpTPDollarAmount && sellCount > 0)
      {
         Print("TP Dollar - SELL side reached $", sellPL);
         double closed = ClosePositionsByType(POSITION_TYPE_SELL);
         if(InpUseGroupTP) AccumulatedProfit += closed;
      }
   }
   
   // 2. TP in Points - Close when price reaches TP from average
   if(InpUseTPPoints)
   {
      if(buyCount > 0 && avgBuy > 0)
      {
         double tpPrice = CalculateTPPrice(POSITION_TYPE_BUY, avgBuy);
         if(currentBid >= tpPrice)
         {
            Print("TP Points - BUY side hit TP at ", tpPrice);
            double closed = ClosePositionsByType(POSITION_TYPE_BUY);
            if(InpUseGroupTP) AccumulatedProfit += closed;
         }
      }
      if(sellCount > 0 && avgSell > 0)
      {
         double tpPrice = CalculateTPPrice(POSITION_TYPE_SELL, avgSell);
         if(currentAsk <= tpPrice)
         {
            Print("TP Points - SELL side hit TP at ", tpPrice);
            double closed = ClosePositionsByType(POSITION_TYPE_SELL);
            if(InpUseGroupTP) AccumulatedProfit += closed;
         }
      }
   }
   
   // 3. TP Percent of Balance
   if(InpUseTPPercent)
   {
      double tpAmount = balance * InpTPPercent / 100.0;
      if(buyPL >= tpAmount && buyCount > 0)
      {
         Print("TP Percent - BUY side reached ", InpTPPercent, "% ($", buyPL, ")");
         double closed = ClosePositionsByType(POSITION_TYPE_BUY);
         if(InpUseGroupTP) AccumulatedProfit += closed;
      }
      if(sellPL >= tpAmount && sellCount > 0)
      {
         Print("TP Percent - SELL side reached ", InpTPPercent, "% ($", sellPL, ")");
         double closed = ClosePositionsByType(POSITION_TYPE_SELL);
         if(InpUseGroupTP) AccumulatedProfit += closed;
      }
   }
   
   // 4. Group TP (Accumulated Profit)
   if(InpUseGroupTP)
   {
      double combinedProfit = AccumulatedProfit + totalPL;
      if(combinedProfit >= InpGroupTPAmount)
      {
         Print("Group TP Reached! Accumulated: $", AccumulatedProfit, " + Current: $", totalPL, " = $", combinedProfit);
         CloseAllPositions();
         AccumulatedProfit = 0;  // Reset after closing all
         return;
      }
   }
   
   // ========== STOP LOSS LOGIC ==========
   
   // 1. SL Fixed Dollar
   if(InpUseSLDollar)
   {
      if(buyPL <= -InpSLDollarAmount && buyCount > 0)
      {
         Print("SL Dollar - BUY side hit $", -InpSLDollarAmount);
         ClosePositionsByType(POSITION_TYPE_BUY);
      }
      if(sellPL <= -InpSLDollarAmount && sellCount > 0)
      {
         Print("SL Dollar - SELL side hit $", -InpSLDollarAmount);
         ClosePositionsByType(POSITION_TYPE_SELL);
      }
   }
   
   // 2. SL in Points
   if(InpUseSLPoints)
   {
      if(buyCount > 0 && avgBuy > 0)
      {
         double slPrice = CalculateSLPrice(POSITION_TYPE_BUY, avgBuy);
         if(currentBid <= slPrice)
         {
            Print("SL Points - BUY side hit SL at ", slPrice);
            ClosePositionsByType(POSITION_TYPE_BUY);
         }
      }
      if(sellCount > 0 && avgSell > 0)
      {
         double slPrice = CalculateSLPrice(POSITION_TYPE_SELL, avgSell);
         if(currentAsk >= slPrice)
         {
            Print("SL Points - SELL side hit SL at ", slPrice);
            ClosePositionsByType(POSITION_TYPE_SELL);
         }
      }
   }
   
   // 3. SL Percent of Balance
   if(InpUseSLPercent)
   {
      double slAmount = balance * InpSLPercent / 100.0;
      if(totalPL <= -slAmount)
      {
         Print("SL Percent - Total loss reached ", InpSLPercent, "% ($", totalPL, ")");
         CloseAllPositions();
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| Count positions by type                                            |
//+------------------------------------------------------------------+
int CountPositions(ENUM_POSITION_TYPE posType)
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            if(PositionGetInteger(POSITION_TYPE) == posType)
               count++;
         }
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Get Last Position Price by type                                    |
//+------------------------------------------------------------------+
double GetLastPositionPrice(ENUM_POSITION_TYPE posType)
{
   double lastPrice = 0;
   datetime lastTime = 0;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            if(PositionGetInteger(POSITION_TYPE) == posType)
            {
               datetime posTime = (datetime)PositionGetInteger(POSITION_TIME);
               if(posTime > lastTime)
               {
                  lastTime = posTime;
                  lastPrice = PositionGetDouble(POSITION_PRICE_OPEN);
               }
            }
         }
      }
   }
   return lastPrice;
}

//+------------------------------------------------------------------+
//| Get First Position Price by type                                   |
//+------------------------------------------------------------------+
double GetFirstPositionPrice(ENUM_POSITION_TYPE posType)
{
   double firstPrice = 0;
   datetime firstTime = D'2099.01.01';
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            if(PositionGetInteger(POSITION_TYPE) == posType)
            {
               datetime posTime = (datetime)PositionGetInteger(POSITION_TIME);
               if(posTime < firstTime)
               {
                  firstTime = posTime;
                  firstPrice = PositionGetDouble(POSITION_PRICE_OPEN);
               }
            }
         }
      }
   }
   return firstPrice;
}

//+------------------------------------------------------------------+
//| Check and Execute Grid Loss Side                                   |
//+------------------------------------------------------------------+
void CheckGridLossSide()
{
   if(InpGridLossMaxTrades <= 0) return;
   
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Check BUY Grid (when price goes down = loss side for BUY)
   int buyCount = CountPositions(POSITION_TYPE_BUY);
   // Grid Loss count = buyCount - 1 (excluding Initial Order)
   // Max Grid = Initial Order + Max Grid Loss orders
   int buyGridLossCount = buyCount - 1;
   if(buyCount > 0 && buyGridLossCount < InpGridLossMaxTrades)
   {
      // Check if should skip same candle
      if(InpGridLossDontOpenSameCandle && currentBarTime == InitialBuyBarTime)
         return;
      
      // Check new candle requirement
      if(InpGridLossNewCandle && currentBarTime == LastGridBuyTime)
         return;
      
      // Check signal requirement
      if(InpGridLossOnlySignal && !IsTradeAllowed("BUY"))
         return;
      
      double lastBuyPrice = GetLastPositionPrice(POSITION_TYPE_BUY);
      int gridLevel = buyCount;
      int distance = GetGridDistance(true, gridLevel - 1);
      
      // Price went DOWN from last buy by grid distance
      if(lastBuyPrice - currentPrice >= distance * _Point)
      {
         double lot = GetGridLotSize(true, gridLevel);
         double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         
         Print("Grid Loss BUY #", gridLevel, " | Lot: ", lot, " | Distance: ", distance);
         
         if(trade.Buy(lot, _Symbol, price, 0, 0, "Grid Loss BUY #" + IntegerToString(gridLevel)))
         {
            LastGridBuyTime = currentBarTime;
            GridBuyCount = buyCount + 1;
         }
      }
   }
   
   // Check SELL Grid (when price goes up = loss side for SELL)
   int sellCount = CountPositions(POSITION_TYPE_SELL);
   // Grid Loss count = sellCount - 1 (excluding Initial Order)
   int sellGridLossCount = sellCount - 1;
   if(sellCount > 0 && sellGridLossCount < InpGridLossMaxTrades)
   {
      // Check if should skip same candle
      if(InpGridLossDontOpenSameCandle && currentBarTime == InitialSellBarTime)
         return;
      
      // Check new candle requirement
      if(InpGridLossNewCandle && currentBarTime == LastGridSellTime)
         return;
      
      // Check signal requirement
      if(InpGridLossOnlySignal && !IsTradeAllowed("SELL"))
         return;
      
      double lastSellPrice = GetLastPositionPrice(POSITION_TYPE_SELL);
      int gridLevel = sellCount;
      int distance = GetGridDistance(true, gridLevel - 1);
      
      // Price went UP from last sell by grid distance
      if(currentPrice - lastSellPrice >= distance * _Point)
      {
         double lot = GetGridLotSize(true, gridLevel);
         double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         
         Print("Grid Loss SELL #", gridLevel, " | Lot: ", lot, " | Distance: ", distance);
         
         if(trade.Sell(lot, _Symbol, price, 0, 0, "Grid Loss SELL #" + IntegerToString(gridLevel)))
         {
            LastGridSellTime = currentBarTime;
            GridSellCount = sellCount + 1;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check and Execute Grid Profit Side                                 |
//+------------------------------------------------------------------+
void CheckGridProfitSide()
{
   if(!InpUseGridProfit || InpGridProfitMaxTrades <= 0) return;
   
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Check BUY Grid Profit (when price goes up = profit side for BUY)
   int buyCount = CountPositions(POSITION_TYPE_BUY);
   if(buyCount > 0)
   {
      // Count profit grid orders by checking comment (more reliable than price comparison)
      int profitGridCount = 0;
      
      for(int i = 0; i < PositionsTotal(); i++)
      {
         if(PositionGetSymbol(i) == _Symbol)
         {
            if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            {
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
               {
                  string comment = PositionGetString(POSITION_COMMENT);
                  if(StringFind(comment, "Grid Profit") >= 0)
                     profitGridCount++;
               }
            }
         }
      }
      
      if(profitGridCount < InpGridProfitMaxTrades)
      {
         // Check new candle requirement
         if(InpGridProfitNewCandle && currentBarTime == LastGridBuyTime)
            return;
         
         // Check signal requirement
         if(InpGridProfitOnlySignal && !IsTradeAllowed("BUY"))
            return;
          
          // Get initial order price and last buy price
          double initialBuyPrice = GetFirstPositionPrice(POSITION_TYPE_BUY);
          double lastBuyPrice = GetLastPositionPrice(POSITION_TYPE_BUY);
          int distance = GetGridDistance(false, profitGridCount);
          
          // Grid Profit only triggers when:
          // 1. Current price is ABOVE initial order price (profit zone for BUY)
          // 2. Price went UP from last buy by grid distance
          if(currentPrice > initialBuyPrice && currentPrice - lastBuyPrice >= distance * _Point)
          {
            // Grid Profit uses gridLevel starting from 1 (Initial Order is the base)
            // profitGridCount=0 means first Grid Profit order, which should use level 1
            double lot = GetGridLotSize(false, profitGridCount + 1);
            double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            
            Print("Grid Profit BUY #", profitGridCount, " | Lot: ", lot, " | Distance: ", distance);
            
            if(trade.Buy(lot, _Symbol, price, 0, 0, "Grid Profit BUY #" + IntegerToString(profitGridCount)))
            {
               LastGridBuyTime = currentBarTime;
            }
         }
      }
   }
   
   // Check SELL Grid Profit (when price goes down = profit side for SELL)
   int sellCount = CountPositions(POSITION_TYPE_SELL);
   if(sellCount > 0)
   {
      // Count profit grid orders by checking comment (more reliable than price comparison)
      int profitGridCount = 0;
      
      for(int i = 0; i < PositionsTotal(); i++)
      {
         if(PositionGetSymbol(i) == _Symbol)
         {
            if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            {
               if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
               {
                  string comment = PositionGetString(POSITION_COMMENT);
                  if(StringFind(comment, "Grid Profit") >= 0)
                     profitGridCount++;
               }
            }
         }
      }
      
      if(profitGridCount < InpGridProfitMaxTrades)
      {
         // Check new candle requirement
         if(InpGridProfitNewCandle && currentBarTime == LastGridSellTime)
            return;
         
         // Check signal requirement
         if(InpGridProfitOnlySignal && !IsTradeAllowed("SELL"))
            return;
          
          // Get initial order price and last sell price
          double initialSellPrice = GetFirstPositionPrice(POSITION_TYPE_SELL);
          double lastSellPrice = GetLastPositionPrice(POSITION_TYPE_SELL);
          int distance = GetGridDistance(false, profitGridCount);
          
          // Grid Profit only triggers when:
          // 1. Current price is BELOW initial order price (profit zone for SELL)
          // 2. Price went DOWN from last sell by grid distance
          if(currentPrice < initialSellPrice && lastSellPrice - currentPrice >= distance * _Point)
          {
            // Grid Profit uses gridLevel starting from 1 (Initial Order is the base)
            // profitGridCount=0 means first Grid Profit order, which should use level 1
            double lot = GetGridLotSize(false, profitGridCount + 1);
            double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            
            Print("Grid Profit SELL #", profitGridCount, " | Lot: ", lot, " | Distance: ", distance);
            
            if(trade.Sell(lot, _Symbol, price, 0, 0, "Grid Profit SELL #" + IntegerToString(profitGridCount)))
            {
               LastGridSellTime = currentBarTime;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check TP/SL conditions first (every tick)
   CheckTPSLConditions();
   
   // Draw TP/SL lines (every tick for real-time update)
   DrawTPSLLines();
   
   // Check Grid conditions (every tick for real-time)
   CheckGridLossSide();
   CheckGridProfitSide();
   
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   if(lastBarTime == currentBarTime)
      return;
      
   lastBarTime = currentBarTime;
   
   // Calculate CDC Action Zone (higher timeframe)
   CalculateCDC();
   
   // Calculate ZigZag++ (custom implementation)
   CalculateZigZagPP();
   
   if(InpUseTimeFilter && !IsWithinTradingHours())
   {
      UpdateChartComment("WAIT", "Outside trading hours");
      return;
   }
   
   if(ZZPointCount < 4)
   {
      UpdateChartComment("WAIT", "Calculating ZigZag...");
      return;
   }
   
   string signal = AnalyzeSignal();
   string reason = "";
   
   if(signal == "BUY")
   {
      if(CountPositions(POSITION_TYPE_BUY) > 0)
      {
         reason = "BUY position already open";
         signal = "WAIT";
      }
      else if(!IsTradeAllowed("BUY"))
      {
         if(InpTradeMode == TRADE_SELL_ONLY)
            reason = "Trade Mode: SELL ONLY";
         else if(InpUseCDCFilter && CDCTrend != "BULLISH")
            reason = "CDC not Bullish (" + CDCTrend + ") - BUY blocked";
         signal = "WAIT";
      }
      else
      {
         ExecuteBuy();
         reason = "BUY executed | CDC: " + CDCTrend;
      }
   }
   else if(signal == "SELL")
   {
      if(CountPositions(POSITION_TYPE_SELL) > 0)
      {
         reason = "SELL position already open";
         signal = "WAIT";
      }
      else if(!IsTradeAllowed("SELL"))
      {
         if(InpTradeMode == TRADE_BUY_ONLY)
            reason = "Trade Mode: BUY ONLY";
         else if(InpUseCDCFilter && CDCTrend != "BEARISH")
            reason = "CDC not Bearish (" + CDCTrend + ") - SELL blocked";
         signal = "WAIT";
      }
      else
      {
         ExecuteSell();
         reason = "SELL executed | CDC: " + CDCTrend;
      }
   }
   
   UpdateChartComment(signal, reason);
}

//+------------------------------------------------------------------+
//| Analyze Signal - Based on ZigZag++ Labels                          |
//+------------------------------------------------------------------+
string AnalyzeSignal()
{
   if(ZZPointCount < 2)
      return "WAIT";
   
   // Get the newest confirmed ZigZag point (index 0 is newest)
   datetime newestPointTime = ZZPoints[0].time;
   
   // Check if this is a NEW confirmed point
   if(newestPointTime == LastConfirmedZZTime)
   {
      return "WAIT";
   }
   
   // NEW ZigZag point confirmed!
   LastConfirmedZZTime = newestPointTime;
   
   Print("*** NEW ZigZag++ Point Confirmed! ***");
   Print("Label: ", LastZZLabel, " | Time: ", TimeToString(newestPointTime), " | CDC: ", CDCTrend);
   
   // BUY Signal: Based on ZigZag Signal Mode
   if(InpZigZagSignalMode == ZIGZAG_BOTH)
   {
      // Both Signals: LL or HL triggers BUY
      if(LastZZLabel == "LL" || LastZZLabel == "HL")
      {
         Print(">>> NEW LOW point (", LastZZLabel, ") - Triggering BUY signal! [Both Mode]");
         return "BUY";
      }
      // Both Signals: HH or LH triggers SELL
      if(LastZZLabel == "HH" || LastZZLabel == "LH")
      {
         Print(">>> NEW HIGH point (", LastZZLabel, ") - Triggering SELL signal! [Both Mode]");
         return "SELL";
      }
   }
   else // ZIGZAG_SINGLE
   {
      // Single Signal: Only LL triggers BUY
      if(LastZZLabel == "LL")
      {
         Print(">>> NEW LL point - Triggering BUY signal! [Single Mode]");
         return "BUY";
      }
      // Single Signal: Only HH triggers SELL
      if(LastZZLabel == "HH")
      {
         Print(">>> NEW HH point - Triggering SELL signal! [Single Mode]");
         return "SELL";
      }
   }
   
   return "WAIT";
}

//+------------------------------------------------------------------+
//| Execute BUY order                                                  |
//+------------------------------------------------------------------+
void ExecuteBuy()
{
   double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double lot = CalculateLotSize();
   
   Print("Executing BUY - CDC: ", CDCTrend, " | Mode: ", GetTradeModeString(), " | Lot Mode: ", EnumToString(InpLotMode));
   
   // Grid orders have no SL/TP - will use Close All
   if(trade.Buy(lot, _Symbol, price, 0, 0, "ZigZag++ Initial BUY"))
   {
      Print("BUY Success! Ticket: ", trade.ResultOrder());
      InitialBuyBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
      GridBuyCount = 1;
   }
   else
   {
      Print("BUY Failed! Error: ", trade.ResultRetcode());
   }
}

//+------------------------------------------------------------------+
//| Execute SELL order                                                 |
//+------------------------------------------------------------------+
void ExecuteSell()
{
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double lot = CalculateLotSize();
   
   Print("Executing SELL - CDC: ", CDCTrend, " | Mode: ", GetTradeModeString(), " | Lot Mode: ", EnumToString(InpLotMode));
   
   // Grid orders have no SL/TP - will use Close All
   if(trade.Sell(lot, _Symbol, price, 0, 0, "ZigZag++ Initial SELL"))
   {
      Print("SELL Success! Ticket: ", trade.ResultOrder());
      InitialSellBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
      GridSellCount = 1;
   }
   else
   {
      Print("SELL Failed! Error: ", trade.ResultRetcode());
   }
}

//+------------------------------------------------------------------+
//| Count open orders for this EA                                      |
//+------------------------------------------------------------------+
int CountOpenOrders()
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Check if within trading hours                                      |
//+------------------------------------------------------------------+
bool IsWithinTradingHours()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.hour >= InpStartHour && dt.hour < InpEndHour);
}

//+------------------------------------------------------------------+
//| Update chart comment                                               |
//+------------------------------------------------------------------+
void UpdateChartComment(string signal, string reason = "")
{
   string nl = "\\n";
   string text = "";
   
   text = text + "=================================" + nl;
   text = text + " ZigZag++ CDC EA v4.0 + Grid" + nl;
   text = text + "=================================" + nl;
   text = text + "Symbol: " + _Symbol + nl;
   text = text + "Entry TF: " + EnumToString(Period()) + nl;
   text = text + "Trade Mode: " + GetTradeModeString() + nl;
   text = text + "Lot Mode: " + EnumToString(InpLotMode) + nl;
   text = text + "---------------------------------" + nl;
   
   text = text + "ZIGZAG++ STATUS:" + nl;
   text = text + "  Last Point: " + LastZZLabel + nl;
   text = text + "  Total Points: " + IntegerToString(ZZPointCount) + nl;
   
   if(ZZPointCount >= 4)
   {
      text = text + "  Recent: ";
      for(int i = 0; i < 4 && i < ZZPointCount; i++)
      {
         text = text + ZZPoints[i].label;
         if(i < 3) text = text + " > ";
      }
      text = text + nl;
   }
   
   text = text + "---------------------------------" + nl;
   text = text + "CDC FILTER (" + EnumToString(InpCDCTimeframe) + "):" + nl;
   text = text + "  Zone: " + CDCTrend + nl;
   
   string zoneSymbol = "";
   if(CDCTrend == "BULLISH") zoneSymbol = "[GREEN - BUY ONLY]";
   else if(CDCTrend == "BEARISH") zoneSymbol = "[RED - SELL ONLY]";
   else zoneSymbol = "[" + CDCTrend + "]";
   text = text + "  Status: " + zoneSymbol + nl;
   
   text = text + "---------------------------------" + nl;
   text = text + "GRID STATUS:" + nl;
   text = text + "  BUY Positions: " + IntegerToString(CountPositions(POSITION_TYPE_BUY)) + nl;
   text = text + "  SELL Positions: " + IntegerToString(CountPositions(POSITION_TYPE_SELL)) + nl;
   text = text + "  Floating P/L: $" + DoubleToString(GetTotalFloatingPL(), 2) + nl;
   
   // Average Price Info
   double avgBuy, lotsBuy, avgSell, lotsSell;
   GetAveragePriceAndLots(POSITION_TYPE_BUY, avgBuy, lotsBuy);
   GetAveragePriceAndLots(POSITION_TYPE_SELL, avgSell, lotsSell);
   
   if(avgBuy > 0)
      text = text + "  AVG BUY: " + DoubleToString(avgBuy, _Digits) + nl;
   if(avgSell > 0)
      text = text + "  AVG SELL: " + DoubleToString(avgSell, _Digits) + nl;
   
   // Group TP Info
   if(InpUseGroupTP)
      text = text + "  Accumulated: $" + DoubleToString(AccumulatedProfit, 2) + nl;
   
   text = text + "---------------------------------" + nl;
   text = text + "SIGNAL: " + signal + nl;
   if(reason != "") text = text + "Reason: " + reason + nl;
   text = text + "Total Orders: " + IntegerToString(CountOpenOrders()) + nl;
   text = text + "=================================" + nl;
   
   Comment(text);
}
//+------------------------------------------------------------------+`;

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="sticky top-0 z-50 border-b border-border bg-background/95 backdrop-blur">
        <div className="container py-4 flex items-center justify-between">
          <Link 
            to="/trading-bot-guide" 
            className="inline-flex items-center gap-2 text-muted-foreground hover:text-foreground transition-colors"
          >
            <ArrowLeft className="w-4 h-4" />
            กลับหน้า Trading Bot Guide
          </Link>
        </div>
      </header>

      {/* Hero */}
      <section className="container pt-12 pb-8">
        <div className="max-w-4xl mx-auto text-center">
          <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-primary/10 border border-primary/30 mb-6">
            <FileCode className="w-4 h-4 text-primary" />
            <span className="text-sm font-mono text-primary">MQL5 Expert Advisor v4.0 + Grid</span>
          </div>
          
          <h1 className="text-3xl md:text-4xl font-bold text-foreground mb-4">
            ZigZag++ <span className="text-primary">CDC Action Zone</span> EA + Grid
          </h1>
          
          <p className="text-lg text-muted-foreground">
            EA ที่ใช้ ZigZag++ (DevLucem) พร้อม CDC Trend Filter และ Grid Trading System
          </p>
        </div>
      </section>

      {/* Warning */}
      <section className="container pb-8">
        <div className="max-w-4xl mx-auto">
          <div className="p-6 rounded-2xl bg-destructive/10 border border-destructive/30 flex items-start gap-4">
            <AlertTriangle className="w-6 h-6 text-destructive shrink-0 mt-1" />
            <div>
              <h3 className="font-bold text-destructive mb-2">คำเตือนสำคัญ!</h3>
              <ul className="text-sm text-muted-foreground space-y-1">
                <li>โค้ดนี้เป็นตัวอย่างเพื่อ<strong>การศึกษาเท่านั้น</strong></li>
                <li><strong>ทดสอบบน Demo Account</strong> อย่างน้อย 1-3 เดือนก่อนใช้เงินจริง</li>
                <li>ไม่มี EA ใดรับประกันกำไร - การเทรดมีความเสี่ยง</li>
              </ul>
            </div>
          </div>
        </div>
      </section>

      {/* Features */}
      <section className="container py-8">
        <div className="max-w-4xl mx-auto">
          <h2 className="text-2xl font-bold text-foreground mb-6 text-center">คุณสมบัติของ EA v4.0</h2>
          
          <div className="grid md:grid-cols-2 lg:grid-cols-5 gap-4">
            <div className="glass-card rounded-xl p-5 text-center border-2 border-primary/30">
              <div className="w-12 h-12 rounded-xl bg-primary/20 text-primary flex items-center justify-center mx-auto mb-3">
                <TrendingUp className="w-6 h-6" />
              </div>
              <h3 className="font-semibold text-foreground mb-1">ZigZag++</h3>
              <p className="text-sm text-muted-foreground">พร้อม Labels HH/HL/LH/LL</p>
            </div>
            
            <div className="glass-card rounded-xl p-5 text-center border-2 border-bull/30">
              <div className="w-12 h-12 rounded-xl bg-bull/20 text-bull flex items-center justify-center mx-auto mb-3">
                <Filter className="w-6 h-6" />
              </div>
              <h3 className="font-semibold text-foreground mb-1">CDC Trend Filter</h3>
              <p className="text-sm text-muted-foreground">ฟิลเตอร์เทรนด์จาก TradingView</p>
            </div>
            
            <div className="glass-card rounded-xl p-5 text-center border-2 border-purple-500/30">
              <div className="w-12 h-12 rounded-xl bg-purple-500/20 text-purple-500 flex items-center justify-center mx-auto mb-3">
                <Settings className="w-6 h-6" />
              </div>
              <h3 className="font-semibold text-foreground mb-1">Grid Trading</h3>
              <p className="text-sm text-muted-foreground">Loss Side & Profit Side พร้อม Custom Lot</p>
            </div>
            
            <div className="glass-card rounded-xl p-5 text-center">
              <div className="w-12 h-12 rounded-xl bg-bear/20 text-bear flex items-center justify-center mx-auto mb-3">
                <Shield className="w-6 h-6" />
              </div>
              <h3 className="font-semibold text-foreground mb-1">Risk Management</h3>
              <p className="text-sm text-muted-foreground">คำนวณ Lot Size ตาม % เสี่ยง</p>
            </div>
            
            <div className="glass-card rounded-xl p-5 text-center">
              <div className="w-12 h-12 rounded-xl bg-secondary text-muted-foreground flex items-center justify-center mx-auto mb-3">
                <Settings className="w-6 h-6" />
              </div>
              <h3 className="font-semibold text-foreground mb-1">Visual Display</h3>
              <p className="text-sm text-muted-foreground">แสดงเส้น MA และโซนสีบน chart</p>
            </div>
          </div>
        </div>
      </section>

      {/* CDC Action Zone Explanation */}
      <section className="container py-8">
        <div className="max-w-4xl mx-auto">
          <h2 className="text-2xl font-bold text-foreground mb-6 text-center">CDC Action Zone Logic</h2>
          
          <div className="glass-card rounded-2xl p-6 mb-6">
            <h3 className="font-semibold text-foreground mb-4">สูตรการคำนวณ (จาก TradingView)</h3>
            <div className="bg-secondary/50 rounded-xl p-4 font-mono text-sm space-y-2">
              <p><span className="text-primary">AP</span> = EMA(OHLC4, 2)</p>
              <p><span className="text-bear">Fast</span> = EMA(AP, 12)</p>
              <p><span className="text-bull">Slow</span> = EMA(AP, 26)</p>
            </div>
          </div>
          
          <div className="grid md:grid-cols-2 gap-6">
            <div className="glass-card rounded-xl p-6 border-2 border-bull/50">
              <div className="flex items-center gap-3 mb-4">
                <div className="w-10 h-10 rounded-lg bg-bull flex items-center justify-center">
                  <TrendingUp className="w-5 h-5 text-white" />
                </div>
                <div>
                  <h3 className="font-bold text-bull">Green Zone</h3>
                  <p className="text-xs text-muted-foreground">BUY ONLY</p>
                </div>
              </div>
              <div className="space-y-2 text-sm">
                <p className="text-muted-foreground">เงื่อนไข:</p>
                <ul className="space-y-1 text-muted-foreground">
                  <li className="flex items-center gap-2">
                    <span className="w-2 h-2 rounded-full bg-bull"></span>
                    Fast EMA {">"} Slow EMA (Bullish)
                  </li>
                  <li className="flex items-center gap-2">
                    <span className="w-2 h-2 rounded-full bg-bull"></span>
                    AP {">"} Fast EMA (Strong momentum)
                  </li>
                </ul>
              </div>
            </div>
            
            <div className="glass-card rounded-xl p-6 border-2 border-bear/50">
              <div className="flex items-center gap-3 mb-4">
                <div className="w-10 h-10 rounded-lg bg-bear flex items-center justify-center">
                  <TrendingDown className="w-5 h-5 text-white" />
                </div>
                <div>
                  <h3 className="font-bold text-bear">Red Zone</h3>
                  <p className="text-xs text-muted-foreground">SELL ONLY</p>
                </div>
              </div>
              <div className="space-y-2 text-sm">
                <p className="text-muted-foreground">เงื่อนไข:</p>
                <ul className="space-y-1 text-muted-foreground">
                  <li className="flex items-center gap-2">
                    <span className="w-2 h-2 rounded-full bg-bear"></span>
                    Fast EMA {"<"} Slow EMA (Bearish)
                  </li>
                  <li className="flex items-center gap-2">
                    <span className="w-2 h-2 rounded-full bg-bear"></span>
                    AP {"<"} Fast EMA (Strong momentum)
                  </li>
                </ul>
              </div>
            </div>
          </div>
          
          <div className="grid md:grid-cols-2 gap-6 mt-6">
            <div className="glass-card rounded-xl p-5 border border-yellow-500/30">
              <h4 className="font-semibold text-yellow-500 mb-2">Yellow Zone (Weak Bull)</h4>
              <p className="text-sm text-muted-foreground">
                Fast {">"} Slow แต่ AP {"<"} Fast - เทรนด์ขาขึ้นแต่โมเมนตัมอ่อน
              </p>
            </div>
            
            <div className="glass-card rounded-xl p-5 border border-blue-500/30">
              <h4 className="font-semibold text-blue-500 mb-2">Blue Zone (Weak Bear)</h4>
              <p className="text-sm text-muted-foreground">
                Fast {"<"} Slow แต่ AP {">"} Fast - เทรนด์ขาลงแต่โมเมนตัมอ่อน
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Parameters Explanation */}
      <section className="container py-8">
        <div className="max-w-4xl mx-auto">
          <h2 className="text-2xl font-bold text-foreground mb-6 text-center">Parameters ทั้งหมด</h2>
          
          {/* ZigZag++ Settings */}
          <div className="glass-card rounded-2xl overflow-hidden mb-6">
            <div className="bg-primary/20 px-4 py-3 border-b border-border">
              <h3 className="font-bold text-primary flex items-center gap-2">
                <TrendingUp className="w-4 h-4" />
                ZigZag++ Settings (Based on DevLucem)
              </h3>
            </div>
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border bg-secondary/50">
                  <th className="px-4 py-3 text-left font-semibold text-foreground">Parameter</th>
                  <th className="px-4 py-3 text-left font-semibold text-foreground">ค่าเริ่มต้น</th>
                  <th className="px-4 py-3 text-left font-semibold text-foreground">คำอธิบาย</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                <tr>
                  <td className="px-4 py-3 font-mono text-primary">InpDepth</td>
                  <td className="px-4 py-3">12</td>
                  <td className="px-4 py-3 text-muted-foreground">ZigZag Depth - จำนวนแท่งสำหรับหา Swing</td>
                </tr>
                <tr>
                  <td className="px-4 py-3 font-mono text-primary">InpDeviation</td>
                  <td className="px-4 py-3">5</td>
                  <td className="px-4 py-3 text-muted-foreground">ZigZag Deviation (pips)</td>
                </tr>
                <tr>
                  <td className="px-4 py-3 font-mono text-primary">InpBackstep</td>
                  <td className="px-4 py-3">2</td>
                  <td className="px-4 py-3 text-muted-foreground">ZigZag Backstep</td>
                </tr>
                <tr>
                  <td className="px-4 py-3 font-mono text-primary">InpBullColor</td>
                  <td className="px-4 py-3 text-bull">clrLime</td>
                  <td className="px-4 py-3 text-muted-foreground">สี Labels LL/HL (Low points)</td>
                </tr>
                <tr>
                  <td className="px-4 py-3 font-mono text-primary">InpBearColor</td>
                  <td className="px-4 py-3 text-bear">clrRed</td>
                  <td className="px-4 py-3 text-muted-foreground">สี Labels HH/LH (High points)</td>
                </tr>
                <tr>
                  <td className="px-4 py-3 font-mono text-primary">InpShowLabels</td>
                  <td className="px-4 py-3">true</td>
                  <td className="px-4 py-3 text-muted-foreground">แสดง HH/HL/LH/LL labels บน chart</td>
                </tr>
                <tr>
                  <td className="px-4 py-3 font-mono text-primary">InpShowLines</td>
                  <td className="px-4 py-3">true</td>
                  <td className="px-4 py-3 text-muted-foreground">แสดงเส้น ZigZag บน chart</td>
                </tr>
              </tbody>
            </table>
            <div className="p-4 bg-secondary/30">
              <p className="text-sm text-muted-foreground">
                <span className="text-primary font-semibold">ZigZag++ </span>
                อ้างอิงจาก TradingView indicator โดย DevLucem - แสดง Labels อัตโนมัติ:
              </p>
              <div className="flex flex-wrap gap-2 mt-2">
                <span className="px-3 py-1 rounded-full text-xs font-medium bg-bear/20 text-bear">HH - Higher High</span>
                <span className="px-3 py-1 rounded-full text-xs font-medium bg-bear/20 text-bear">LH - Lower High</span>
                <span className="px-3 py-1 rounded-full text-xs font-medium bg-bull/20 text-bull">HL - Higher Low</span>
                <span className="px-3 py-1 rounded-full text-xs font-medium bg-bull/20 text-bull">LL - Lower Low</span>
              </div>
            </div>
          </div>
          
          {/* CDC Action Zone Settings */}
          <div className="glass-card rounded-2xl overflow-hidden mb-6">
            <div className="bg-bull/20 px-4 py-3 border-b border-border">
              <h3 className="font-bold text-bull flex items-center gap-2">
                <Filter className="w-4 h-4" />
                CDC Action Zone Settings
              </h3>
            </div>
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border bg-secondary/50">
                  <th className="px-4 py-3 text-left font-semibold text-foreground">Parameter</th>
                  <th className="px-4 py-3 text-left font-semibold text-foreground">ค่าเริ่มต้น</th>
                  <th className="px-4 py-3 text-left font-semibold text-foreground">คำอธิบาย</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                <tr className="bg-bull/5">
                  <td className="px-4 py-3 font-mono text-bull">InpUseCDCFilter</td>
                  <td className="px-4 py-3">true</td>
                  <td className="px-4 py-3 text-muted-foreground">เปิด/ปิดการใช้ CDC Action Zone Filter</td>
                </tr>
                <tr className="bg-bull/5">
                  <td className="px-4 py-3 font-mono text-bull">InpCDCTimeframe</td>
                  <td className="px-4 py-3">D1</td>
                  <td className="px-4 py-3 text-muted-foreground">Timeframe สำหรับคำนวณ CDC (D1, H4, H1, etc.)</td>
                </tr>
                <tr className="bg-bull/5">
                  <td className="px-4 py-3 font-mono text-bull">InpCDCFastPeriod</td>
                  <td className="px-4 py-3">12</td>
                  <td className="px-4 py-3 text-muted-foreground">Period ของ Fast EMA</td>
                </tr>
                <tr className="bg-bull/5">
                  <td className="px-4 py-3 font-mono text-bull">InpCDCSlowPeriod</td>
                  <td className="px-4 py-3">26</td>
                  <td className="px-4 py-3 text-muted-foreground">Period ของ Slow EMA</td>
                </tr>
                <tr className="bg-bull/5">
                  <td className="px-4 py-3 font-mono text-bull">InpShowCDCLines</td>
                  <td className="px-4 py-3">true</td>
                  <td className="px-4 py-3 text-muted-foreground">แสดงเส้น EMA และแถบสีบน chart</td>
                </tr>
              </tbody>
            </table>
          </div>
          
          {/* Trade Mode Settings */}
          <div className="glass-card rounded-2xl overflow-hidden mb-6">
            <div className="bg-yellow-500/20 px-4 py-3 border-b border-border">
              <h3 className="font-bold text-yellow-500 flex items-center gap-2">
                <Settings className="w-4 h-4" />
                Trade Mode Settings
              </h3>
            </div>
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border bg-secondary/50">
                  <th className="px-4 py-3 text-left font-semibold text-foreground">Parameter</th>
                  <th className="px-4 py-3 text-left font-semibold text-foreground">ค่าเริ่มต้น</th>
                  <th className="px-4 py-3 text-left font-semibold text-foreground">คำอธิบาย</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                <tr className="bg-yellow-500/5">
                  <td className="px-4 py-3 font-mono text-yellow-500">InpTradeMode</td>
                  <td className="px-4 py-3">Buy and Sell</td>
                  <td className="px-4 py-3 text-muted-foreground">เลือก Buy/Sell, Buy Only, หรือ Sell Only</td>
                </tr>
              </tbody>
            </table>
            <div className="p-4 bg-secondary/30">
              <p className="text-sm text-muted-foreground mb-2">ตัวเลือก Trade Mode:</p>
              <div className="flex flex-wrap gap-2">
                <span className="px-3 py-1 rounded-full text-xs font-medium bg-foreground/10 text-foreground">Buy and Sell - เทรดทั้ง 2 ทิศทาง</span>
                <span className="px-3 py-1 rounded-full text-xs font-medium bg-bull/20 text-bull">Buy Only - ซื้อเท่านั้น</span>
                <span className="px-3 py-1 rounded-full text-xs font-medium bg-bear/20 text-bear">Sell Only - ขายเท่านั้น</span>
              </div>
            </div>
          </div>
          
          {/* Re-Entry Settings */}
          <div className="glass-card rounded-2xl overflow-hidden mb-6">
            <div className="bg-purple-500/20 px-4 py-3 border-b border-border">
              <h3 className="font-bold text-purple-500 flex items-center gap-2">
                <TrendingUp className="w-4 h-4" />
                Re-Entry Settings
              </h3>
            </div>
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border bg-secondary/50">
                  <th className="px-4 py-3 text-left font-semibold text-foreground">Parameter</th>
                  <th className="px-4 py-3 text-left font-semibold text-foreground">ค่าเริ่มต้น</th>
                  <th className="px-4 py-3 text-left font-semibold text-foreground">คำอธิบาย</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                <tr className="bg-purple-500/5">
                  <td className="px-4 py-3 font-mono text-purple-500">InpUseReEntry</td>
                  <td className="px-4 py-3">true</td>
                  <td className="px-4 py-3 text-muted-foreground">เปิด/ปิดฟีเจอร์ Re-Entry</td>
                </tr>
                <tr className="bg-purple-500/5">
                  <td className="px-4 py-3 font-mono text-purple-500">InpReEntryMaxCount</td>
                  <td className="px-4 py-3">3</td>
                  <td className="px-4 py-3 text-muted-foreground">จำนวน Re-Entry สูงสุดต่อทิศทาง</td>
                </tr>
              </tbody>
            </table>
            <div className="p-4 bg-secondary/30">
              <p className="text-sm font-semibold text-foreground mb-3">Re-Entry Logic:</p>
              <div className="grid md:grid-cols-2 gap-4">
                <div className="p-3 rounded-lg bg-bull/10 border border-bull/30">
                  <p className="font-semibold text-bull mb-2">BUY Re-Entry</p>
                  <ul className="text-xs text-muted-foreground space-y-1">
                    <li>• ออเดอร์เดิมปิด (TP/SL)</li>
                    <li>• Swing Point ล่าสุด = LL หรือ LH</li>
                    <li>• CDC Zone = BULLISH (สีเขียว)</li>
                    <li>→ เปิด BUY ใหม่</li>
                  </ul>
                </div>
                <div className="p-3 rounded-lg bg-bear/10 border border-bear/30">
                  <p className="font-semibold text-bear mb-2">SELL Re-Entry</p>
                  <ul className="text-xs text-muted-foreground space-y-1">
                    <li>• ออเดอร์เดิมปิด (TP/SL)</li>
                    <li>• Swing Point ล่าสุด = HH หรือ HL</li>
                    <li>• CDC Zone = BEARISH (สีแดง)</li>
                    <li>→ เปิด SELL ใหม่</li>
                  </ul>
                </div>
              </div>
            </div>
          </div>
          
          {/* Trading Settings */}
          <div className="glass-card rounded-2xl overflow-hidden mb-6">
            <div className="bg-secondary px-4 py-3 border-b border-border">
              <h3 className="font-bold text-foreground flex items-center gap-2">
                <TrendingDown className="w-4 h-4" />
                Trading Settings
              </h3>
            </div>
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border bg-secondary/50">
                  <th className="px-4 py-3 text-left font-semibold text-foreground">Parameter</th>
                  <th className="px-4 py-3 text-left font-semibold text-foreground">ค่าเริ่มต้น</th>
                  <th className="px-4 py-3 text-left font-semibold text-foreground">คำอธิบาย</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                <tr>
                  <td className="px-4 py-3 font-mono text-foreground">InpLotSize</td>
                  <td className="px-4 py-3">0.01</td>
                  <td className="px-4 py-3 text-muted-foreground">Lot Size เริ่มต้น</td>
                </tr>
                <tr>
                  <td className="px-4 py-3 font-mono text-foreground">InpStopLoss</td>
                  <td className="px-4 py-3">50</td>
                  <td className="px-4 py-3 text-muted-foreground">Stop Loss (pips)</td>
                </tr>
                <tr>
                  <td className="px-4 py-3 font-mono text-foreground">InpTakeProfit</td>
                  <td className="px-4 py-3">100</td>
                  <td className="px-4 py-3 text-muted-foreground">Take Profit (pips)</td>
                </tr>
                <tr>
                  <td className="px-4 py-3 font-mono text-foreground">InpMagicNumber</td>
                  <td className="px-4 py-3">123456</td>
                  <td className="px-4 py-3 text-muted-foreground">Magic Number สำหรับระบุ Order</td>
                </tr>
              </tbody>
            </table>
          </div>
          
          {/* Risk Management */}
          <div className="glass-card rounded-2xl overflow-hidden mb-6">
            <div className="bg-bear/20 px-4 py-3 border-b border-border">
              <h3 className="font-bold text-bear flex items-center gap-2">
                <Shield className="w-4 h-4" />
                Risk Management
              </h3>
            </div>
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border bg-secondary/50">
                  <th className="px-4 py-3 text-left font-semibold text-foreground">Parameter</th>
                  <th className="px-4 py-3 text-left font-semibold text-foreground">ค่าเริ่มต้น</th>
                  <th className="px-4 py-3 text-left font-semibold text-foreground">คำอธิบาย</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                <tr className="bg-bear/5">
                  <td className="px-4 py-3 font-mono text-bear">InpMaxRiskPercent</td>
                  <td className="px-4 py-3">2.0</td>
                  <td className="px-4 py-3 text-muted-foreground">% ความเสี่ยงสูงสุดต่อออเดอร์</td>
                </tr>
                <tr className="bg-bear/5">
                  <td className="px-4 py-3 font-mono text-bear">InpMaxOrders</td>
                  <td className="px-4 py-3">1</td>
                  <td className="px-4 py-3 text-muted-foreground">จำนวนออเดอร์สูงสุดที่เปิดได้</td>
                </tr>
              </tbody>
            </table>
          </div>
          
          {/* Time Filter */}
          <div className="glass-card rounded-2xl overflow-hidden">
            <div className="bg-blue-500/20 px-4 py-3 border-b border-border">
              <h3 className="font-bold text-blue-500 flex items-center gap-2">
                <Info className="w-4 h-4" />
                Time Filter
              </h3>
            </div>
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border bg-secondary/50">
                  <th className="px-4 py-3 text-left font-semibold text-foreground">Parameter</th>
                  <th className="px-4 py-3 text-left font-semibold text-foreground">ค่าเริ่มต้น</th>
                  <th className="px-4 py-3 text-left font-semibold text-foreground">คำอธิบาย</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                <tr className="bg-blue-500/5">
                  <td className="px-4 py-3 font-mono text-blue-500">InpUseTimeFilter</td>
                  <td className="px-4 py-3">false</td>
                  <td className="px-4 py-3 text-muted-foreground">เปิด/ปิดฟิลเตอร์เวลา</td>
                </tr>
                <tr className="bg-blue-500/5">
                  <td className="px-4 py-3 font-mono text-blue-500">InpStartHour</td>
                  <td className="px-4 py-3">8</td>
                  <td className="px-4 py-3 text-muted-foreground">ชั่วโมงเริ่มเทรด</td>
                </tr>
                <tr className="bg-blue-500/5">
                  <td className="px-4 py-3 font-mono text-blue-500">InpEndHour</td>
                  <td className="px-4 py-3">20</td>
                  <td className="px-4 py-3 text-muted-foreground">ชั่วโมงหยุดเทรด</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </section>

      {/* Trading Logic */}
      <section className="container py-8">
        <div className="max-w-4xl mx-auto">
          <h2 className="text-2xl font-bold text-foreground mb-6 text-center">กลยุทธ์การเทรด (รวม CDC Filter)</h2>
          
          <div className="grid md:grid-cols-2 gap-6">
            <div className="glass-card rounded-xl p-6 border-2 border-bull/30">
              <div className="flex items-center gap-3 mb-4">
                <div className="w-10 h-10 rounded-lg bg-bull/20 flex items-center justify-center">
                  <TrendingUp className="w-5 h-5 text-bull" />
                </div>
                <h3 className="text-lg font-bold text-bull">สัญญาณ BUY</h3>
              </div>
              <ol className="space-y-2 text-sm text-muted-foreground">
                <li className="flex items-start gap-2">
                  <span className="font-mono text-bull">1.</span>
                  <span>Structure: มี <strong className="text-bull">HH + HL</strong></span>
                </li>
                <li className="flex items-start gap-2">
                  <span className="font-mono text-bull">2.</span>
                  <span>Swing Point ล่าสุดเป็น <strong className="text-bull">HL</strong></span>
                </li>
                <li className="flex items-start gap-2 text-bull font-semibold">
                  <span className="font-mono">3.</span>
                  <span>CDC Zone = <strong>GREEN</strong> (Bullish + Strong)</span>
                </li>
                <li className="flex items-start gap-2">
                  <span className="font-mono text-bull">→</span>
                  <span>ส่งคำสั่ง <strong className="text-bull">BUY</strong></span>
                </li>
              </ol>
            </div>
            
            <div className="glass-card rounded-xl p-6 border-2 border-bear/30">
              <div className="flex items-center gap-3 mb-4">
                <div className="w-10 h-10 rounded-lg bg-bear/20 flex items-center justify-center">
                  <TrendingDown className="w-5 h-5 text-bear" />
                </div>
                <h3 className="text-lg font-bold text-bear">สัญญาณ SELL</h3>
              </div>
              <ol className="space-y-2 text-sm text-muted-foreground">
                <li className="flex items-start gap-2">
                  <span className="font-mono text-bear">1.</span>
                  <span>Structure: มี <strong className="text-bear">LL + LH</strong></span>
                </li>
                <li className="flex items-start gap-2">
                  <span className="font-mono text-bear">2.</span>
                  <span>Swing Point ล่าสุดเป็น <strong className="text-bear">LH</strong></span>
                </li>
                <li className="flex items-start gap-2 text-bear font-semibold">
                  <span className="font-mono">3.</span>
                  <span>CDC Zone = <strong>RED</strong> (Bearish + Strong)</span>
                </li>
                <li className="flex items-start gap-2">
                  <span className="font-mono text-bear">→</span>
                  <span>ส่งคำสั่ง <strong className="text-bear">SELL</strong></span>
                </li>
              </ol>
            </div>
          </div>
        </div>
      </section>

      {/* Installation */}
      <section className="container py-8">
        <div className="max-w-5xl mx-auto">
          <StepCard
            step={1}
            title="วิธีติดตั้ง EA"
            description="ทำตามขั้นตอนเหล่านี้เพื่อติดตั้ง EA บน MetaTrader 5"
            icon={<Download className="w-6 h-6" />}
          >
            <div className="space-y-4">
              <div className="p-4 rounded-xl bg-secondary/50">
                <ol className="space-y-2 text-sm text-muted-foreground">
                  <li><span className="font-mono text-primary">1.</span> เปิด MetaTrader 5</li>
                  <li><span className="font-mono text-primary">2.</span> กด <kbd className="px-2 py-0.5 rounded bg-secondary text-foreground">File</kbd> → <kbd className="px-2 py-0.5 rounded bg-secondary text-foreground">Open Data Folder</kbd></li>
                  <li><span className="font-mono text-primary">3.</span> ไปที่โฟลเดอร์ <code className="text-primary">MQL5 → Experts</code></li>
                  <li><span className="font-mono text-primary">4.</span> สร้างไฟล์ใหม่ชื่อ <code className="text-primary">ZigZag_CDC_Structure_EA.mq5</code></li>
                  <li><span className="font-mono text-primary">5.</span> วางโค้ดด้านล่างลงไป แล้วบันทึก</li>
                  <li><span className="font-mono text-primary">6.</span> กลับไป MT5 กด <kbd className="px-2 py-0.5 rounded bg-secondary text-foreground">F7</kbd> เพื่อ Compile</li>
                  <li><span className="font-mono text-primary">7.</span> ลาก EA ไปวางบน Chart</li>
                  <li><span className="font-mono text-primary">8.</span> ตั้งค่าพารามิเตอร์ → กด <kbd className="px-2 py-0.5 rounded bg-secondary text-foreground">OK</kbd></li>
                </ol>
              </div>
              
              <div className="flex items-start gap-3 p-4 rounded-xl bg-primary/10 border border-primary/30">
                <Info className="w-5 h-5 text-primary shrink-0 mt-0.5" />
                <div className="text-sm text-muted-foreground">
                  <strong className="text-foreground">สำคัญ:</strong> ต้องเปิด Auto Trading บน MT5 ด้วย (ปุ่ม AutoTrading บน toolbar)
                </div>
              </div>
            </div>
          </StepCard>
        </div>
      </section>

      {/* Full Code */}
      <section className="container py-8">
        <div className="max-w-5xl mx-auto">
          <h2 className="text-2xl font-bold text-foreground mb-6 text-center">โค้ด EA ฉบับเต็ม (v4.0 + Grid Trading)</h2>
          <CodeBlock
            code={fullEACode}
            language="MQL5"
            filename="ZigZag_CDC_Structure_EA.mq5"
          />
        </div>
      </section>

      {/* Tips */}
      <section className="container py-12">
        <div className="max-w-4xl mx-auto">
          <h2 className="text-2xl font-bold text-foreground mb-6 text-center">เคล็ดลับการใช้งาน</h2>
          
          <div className="grid md:grid-cols-2 gap-4">
            <div className="glass-card rounded-xl p-5">
              <h3 className="font-semibold text-foreground mb-3">ควรทำ</h3>
              <ul className="space-y-2 text-sm text-muted-foreground">
                <li>- ใช้ CDC Filter TF ที่สูงกว่า Entry TF (เช่น Entry H1, Filter D1)</li>
                <li>- Backtest บน Strategy Tester ดูแถบสีและเส้น MA</li>
                <li>- ทดสอบบน Demo Account อย่างน้อย 1 เดือน</li>
                <li>- ปรับ Fast/Slow Period ให้เหมาะกับคู่เงิน</li>
              </ul>
            </div>
            
            <div className="glass-card rounded-xl p-5">
              <h3 className="font-semibold text-foreground mb-3">ไม่ควรทำ</h3>
              <ul className="space-y-2 text-sm text-muted-foreground">
                <li>- เปิด CDC Filter TF เดียวกับ Entry TF</li>
                <li>- ใช้เงินจริงโดยไม่ทดสอบ</li>
                <li>- เทรดเมื่อ Zone เป็น Yellow/Blue (โมเมนตัมอ่อน)</li>
                <li>- ปล่อยทิ้งไว้โดยไม่ตรวจสอบ</li>
              </ul>
            </div>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-border py-8">
        <div className="container text-center text-sm text-muted-foreground">
          <p>โค้ดนี้เป็นตัวอย่างเพื่อการศึกษา - ไม่รับประกันผลกำไร กรุณาศึกษาและทดสอบอย่างละเอียด</p>
        </div>
      </footer>
    </div>
  );
};

export default MT5EAGuide;