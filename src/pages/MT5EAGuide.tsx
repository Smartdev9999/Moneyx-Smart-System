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
//| ======================= ENUMERATIONS =========================== |
//+------------------------------------------------------------------+

// Signal Strategy Selection
enum ENUM_SIGNAL_STRATEGY
{
   STRATEGY_ZIGZAG = 0,      // ZigZag++ Structure
   STRATEGY_EMA_CHANNEL = 1, // EMA Channel (High/Low)
   STRATEGY_BOLLINGER = 2,   // Bollinger Bands
   STRATEGY_SMC = 3          // Smart Money Concepts (Order Block)
};

// Bollinger Bands MA Type
enum ENUM_BB_MA_TYPE
{
   BB_MA_SMA = 0,    // SMA
   BB_MA_EMA = 1,    // EMA
   BB_MA_SMMA = 2,   // SMMA (RMA)
   BB_MA_WMA = 3     // WMA
};

// ZigZag Signal Mode
enum ENUM_ZIGZAG_SIGNAL_MODE
{
   ZIGZAG_BOTH = 0,     // Both Signals (LL,HL=BUY | HH,LH=SELL)
   ZIGZAG_SINGLE = 1    // Single Signal (LL=BUY | HH=SELL)
};

// EMA Signal Bar Index
enum ENUM_EMA_SIGNAL_BAR
{
   EMA_CURRENT_BAR = 0,    // Current Bar (Real-time)
   EMA_LAST_BAR_CLOSED = 1 // Last Bar Closed (Confirmed)
};

// Trade Mode
enum ENUM_TRADE_MODE
{
   TRADE_BUY_SELL = 0,  // Buy and Sell
   TRADE_BUY_ONLY = 1,  // Buy Only
   TRADE_SELL_ONLY = 2  // Sell Only
};

// Lot Calculation Mode
enum ENUM_LOT_MODE
{
   LOT_FIXED = 0,       // Fixed Lot
   LOT_RISK_PERCENT = 1,  // Risk % of Balance
   LOT_RISK_DOLLAR = 2    // Fixed Dollar Risk
};

// Grid Lot Mode
enum ENUM_GRID_LOT_MODE
{
   GRID_LOT_CUSTOM = 0,    // Custom Lot (use string)
   GRID_LOT_ADD = 1        // Add Lot (InitialLot + AddLot*Level)
};

// Grid Gap Type
enum ENUM_GRID_GAP_TYPE
{
   GAP_FIXED_POINTS = 0,    // Fixed Points
   GAP_CUSTOM_DISTANCE = 1  // Custom Distance
};

// Stop Loss Action Mode
enum ENUM_SL_ACTION_MODE
{
   SL_ACTION_CLOSE = 0,     // Close Positions (Stop Loss)
   SL_ACTION_HEDGE = 1      // Hedge Positions (Lock Loss)
};

//+------------------------------------------------------------------+
//| ===================== INPUT PARAMETERS ========================= |
//+------------------------------------------------------------------+

//--- [ SIGNAL STRATEGY SETTINGS ] ----------------------------------
input string   InpSignalHeader = "=== SIGNAL STRATEGY SETTINGS ===";  // ___
input ENUM_SIGNAL_STRATEGY InpSignalStrategy = STRATEGY_ZIGZAG;  // Signal Strategy

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
input ENUM_ZIGZAG_SIGNAL_MODE InpZigZagSignalMode = ZIGZAG_BOTH;  // ZigZag Signal Mode

//--- [ EMA CHANNEL SETTINGS ] --------------------------------------
input string   InpEMAHeader = "=== EMA CHANNEL SETTINGS ===";  // ___
input ENUM_TIMEFRAMES InpEMATimeframe = PERIOD_CURRENT;  // EMA Channel Timeframe
input int      InpEMAHighPeriod = 20;         // EMA High Period
input int      InpEMALowPeriod = 20;          // EMA Low Period
input color    InpEMAHighColor = clrDodgerBlue;  // EMA High Line Color
input color    InpEMALowColor = clrOrangeRed;    // EMA Low Line Color
input bool     InpShowEMALines = true;        // Show EMA Lines on Chart
input ENUM_EMA_SIGNAL_BAR InpEMASignalBar = EMA_LAST_BAR_CLOSED;  // Signal Bar Index

//--- [ BOLLINGER BANDS SETTINGS ] ----------------------------------
input string   InpBBHeader = "=== BOLLINGER BANDS SETTINGS ===";  // ___
input ENUM_TIMEFRAMES InpBBTimeframe = PERIOD_CURRENT;  // Bollinger Bands Timeframe
input int      InpBBPeriod = 20;              // BB Period (Length)
input double   InpBBDeviation = 2.0;          // BB Deviation (StdDev Multiplier)
input ENUM_BB_MA_TYPE InpBBMAType = BB_MA_SMA;  // BB MA Type
input color    InpBBUpperColor = clrRed;      // BB Upper Band Color
input color    InpBBLowerColor = clrGreen;    // BB Lower Band Color
input color    InpBBBasisColor = clrBlue;     // BB Basis (Middle) Color
input bool     InpShowBBLines = true;         // Show BB Lines on Chart
input ENUM_EMA_SIGNAL_BAR InpBBSignalBar = EMA_LAST_BAR_CLOSED;  // BB Signal Bar Index

//--- [ SMART MONEY CONCEPTS SETTINGS ] -----------------------------
input string   InpSMCHeader = "=== SMART MONEY CONCEPTS (ORDER BLOCK) ===";  // ___
input ENUM_TIMEFRAMES InpSMCTimeframe = PERIOD_CURRENT;  // SMC Timeframe
input int      InpSMCSwingLength = 50;        // Swing Detection Length (bars)
input int      InpSMCInternalLength = 5;      // Internal Structure Length
input int      InpSMCMaxOrderBlocks = 5;      // Max Order Blocks to Display
input bool     InpSMCShowBullishOB = true;    // Show Bullish Order Blocks
input bool     InpSMCShowBearishOB = true;    // Show Bearish Order Blocks
input color    InpSMCBullOBColor = clrDodgerBlue;   // Bullish OB Color
input color    InpSMCBearOBColor = clrCrimson;      // Bearish OB Color
input bool     InpSMCRequireTouch = true;     // Require Price Touch OB (for signal)
input ENUM_EMA_SIGNAL_BAR InpSMCSignalBar = EMA_LAST_BAR_CLOSED;  // SMC Signal Bar Index

input string   InpCDCHeader    = "=== CDC ACTION ZONE SETTINGS ===";  // ___
input bool     InpUseCDCFilter = true;        // Use CDC Action Zone Filter
input ENUM_TIMEFRAMES InpCDCTimeframe = PERIOD_D1;  // CDC Filter Timeframe
input int      InpCDCFastPeriod = 12;         // CDC Fast EMA Period
input int      InpCDCSlowPeriod = 26;         // CDC Slow EMA Period
input bool     InpShowCDCLines = true;        // Show CDC Lines on Chart

//--- [ TRADE MODE SETTINGS ] ---------------------------------------
input string   InpTradeModeHeader = "=== TRADE MODE SETTINGS ===";  // ___
input ENUM_TRADE_MODE InpTradeMode = TRADE_BUY_SELL;  // Trade Mode

//--- [ TRADING SETTINGS ] ------------------------------------------
input string   InpTradingHeader = "=== TRADING SETTINGS ===";  // ___
input ENUM_LOT_MODE InpLotMode = LOT_FIXED;  // Lot Mode
input double   InpInitialLot   = 0.01;       // Initial Lot Size
input double   InpRiskPercent  = 1.0;        // Risk % of Balance (for Risk Mode)
input double   InpRiskDollar   = 50.0;       // Fixed Dollar Risk (for Risk Mode)
input int      InpMagicNumber  = 123456;     // Magic Number

//--- [ GRID LOSS SIDE SETTINGS ] -----------------------------------
input string   InpGridLossHeader = "----- Grid Loss Side -----";  // ___
input int      InpGridLossMaxTrades = 5;     // Max Grid Trades (0 - Disable Grid Trade)
input ENUM_GRID_LOT_MODE InpGridLossLotMode = GRID_LOT_ADD;  // Grid Lot Mode
input string   InpGridLossCustomLot = "0.01;0.02;0.03;0.04;0.05";  // Custom Lot (separate by semicolon ;)
input double   InpGridLossAddLot = 0.4;      // Add Lot per Level (0 = Same as Initial)
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
input ENUM_GRID_LOT_MODE InpGridProfitLotMode = GRID_LOT_ADD;  // Grid Lot Mode
input string   InpGridProfitCustomLot = "0.01;0.02;0.03;0.04;0.05";  // Custom Lot (separate by semicolon ;)
input double   InpGridProfitAddLot = 0.4;    // Add Lot per Level (0 = Same as Initial)
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
input bool     InpUseSLSettings = true;      // Enable Stop Loss Settings
input ENUM_SL_ACTION_MODE InpSLActionMode = SL_ACTION_CLOSE;  // SL Action Mode

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

//--- [ PRICE ACTION CONFIRMATION SETTINGS ] ------------------------
input string   InpPAHeader = "=== PRICE ACTION CONFIRMATION ===";  // ___
input bool     InpUsePAConfirm = false;       // Use Price Action Confirmation
input int      InpPALookback = 3;             // Max Candles to Wait for PA (1-10)

// Bullish PA Patterns
input string   InpPABullHeader = "----- Bullish Patterns -----";  // ___
input bool     InpPAHammer = true;            // Hammer / Pin Bar (Bullish)
input bool     InpPABullEngulfing = true;     // Bullish Engulfing
input bool     InpPATweezerBottom = true;     // Tweezer Bottom
input bool     InpPAMorningStar = true;       // Morning Star (3-Candle)
input bool     InpPAOutsideCandleBull = true; // Outside Candle Reversal (Bullish)
input bool     InpPAPullbackBuy = true;       // Pullback Buy Pattern
input bool     InpPAInsideCandleBull = true;  // Inside Candle Reversal (Bullish)
input bool     InpPABullHotdog = true;        // Bullish Hotdog Pattern

// Bearish PA Patterns
input string   InpPABearHeader = "----- Bearish Patterns -----";  // ___
input bool     InpPAShootingStar = true;      // Shooting Star / Pin Bar (Bearish)
input bool     InpPABearEngulfing = true;     // Bearish Engulfing
input bool     InpPATweezerTop = true;        // Tweezer Top
input bool     InpPAEveningStar = true;       // Evening Star (3-Candle)
input bool     InpPAOutsideCandleBear = true; // Outside Candle Reversal (Bearish)
input bool     InpPAPullbackSell = true;      // Pullback Sell Pattern
input bool     InpPAInsideCandleBear = true;  // Inside Candle Reversal (Bearish)
input bool     InpPABearHotdog = true;        // Bearish Hotdog Pattern

// PA Detection Settings
input string   InpPASettingsHeader = "----- PA Detection Settings -----";  // ___
input double   InpPAPinRatio = 2.0;           // Pin Bar Tail/Body Ratio (min)
input double   InpPABodyMinRatio = 0.3;       // Engulfing Body Min Ratio (of range)
input double   InpPADojiMaxRatio = 0.2;       // Doji Max Body Ratio (for indecision)
input double   InpPASpinningTopRatio = 0.3;   // Spinning Top Max Body Ratio

//--- [ TIME FILTER ] -----------------------------------------------
input string   InpTimeHeader   = "=== TIME FILTER ===";  // ___
input bool     InpUseTimeFilter = false;      // Use Time Filter

// Tradable Time Sessions [Server Time] (format: hh:mm-hh:mm)
input string   InpSession1 = "03:10-12:40";   // Tradable Session #1 [hh:mm-hh:mm]
input string   InpSession2 = "15:10-22:00";   // Tradable Session #2 [hh:mm-hh:mm]
input string   InpSession3 = "";              // Tradable Session #3 [hh:mm-hh:mm]

// Friday Special Sessions (if empty, use normal sessions)
input string   InpFridayHeader = "----- Friday Sessions -----";  // ___
input string   InpFridaySession1 = "03:10-12:40";  // Friday Session #1 [hh:mm-hh:mm]
input string   InpFridaySession2 = "";             // Friday Session #2 [hh:mm-hh:mm]
input string   InpFridaySession3 = "";             // Friday Session #3 [hh:mm-hh:mm]

// Tradable Day Settings
input string   InpDayHeader = "----- Tradable Days -----";  // ___
input bool     InpTradeMonday = true;         // Monday
input bool     InpTradeTuesday = true;        // Tuesday
input bool     InpTradeWednesday = true;      // Wednesday
input bool     InpTradeThursday = true;       // Thursday
input bool     InpTradeFriday = true;         // Friday
input bool     InpTradeSaturday = false;      // Saturday
input bool     InpTradeSunday = false;        // Sunday

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
string EMAPrefix = "EMA_";
string PAPrefix = "PA_";  // Price Action arrows and labels

// Track which candle (shift) produced the most recent PA confirmation
int g_lastPABuyShift = 1;
int g_lastPASellShift = 1;

// EMA Channel Variables
double EMAHigh = 0;
double EMALow = 0;
string EMASignal = "NONE";  // "BUY", "SELL", "NONE"
datetime LastEMASignalTime = 0;

// Bollinger Bands Variables
double BBUpper = 0;
double BBLower = 0;
double BBBasis = 0;
string BBSignal = "NONE";  // "BUY", "SELL", "NONE"
datetime LastBBSignalTime = 0;
string BBPrefix = "BB_";
int BBHandle = INVALID_HANDLE;  // Bollinger Bands indicator handle

// Bollinger Bands Signal Reset
bool g_bbBuyResetPhaseBelowBand = false;   // Price has touched/closed above upper band
bool g_bbSellResetPhaseAboveBand = false;  // Price has touched/closed below lower band

// Smart Money Concepts (Order Block) Variables
string SMCPrefix = "SMC_";
string SMCSignal = "NONE";  // "BUY", "SELL", "NONE"
datetime LastSMCSignalTime = 0;
bool g_smcBuyResetRequired = false;
bool g_smcSellResetRequired = false;
bool g_smcBuyResetPhaseComplete = false;
bool g_smcSellResetPhaseComplete = false;
bool g_smcBuyTouchedOB = false;   // Price touched Bullish OB (support)
bool g_smcSellTouchedOB = false;  // Price touched Bearish OB (resistance)

// Track if price is CURRENTLY touching an OB zone (this tick)
// (Needed for reset logic: "move away" should mean "not touching now")
bool g_smcBuyTouchingNow = false;
bool g_smcSellTouchingNow = false;

// Order Block Structure
struct OrderBlockData
{
   double   high;           // OB High price
   double   low;            // OB Low price
   datetime time;           // OB formation time
   int      barIndex;       // Bar index when OB formed
   int      bias;           // +1 = Bullish, -1 = Bearish
   bool     mitigated;      // True if price has broken through OB
   string   objName;        // Chart object name
};

// Order Block Arrays
OrderBlockData BullishOBs[];
OrderBlockData BearishOBs[];
int BullishOBCount = 0;
int BearishOBCount = 0;

// SMC Touch State - Persist across ticks for PA confirmation
bool g_smcBuyTouchedOBPersist = false;   // Persists until used or reset
bool g_smcSellTouchedOBPersist = false;  // Persists until used or reset
string g_smcBuyTouchedOBName = "";       // Which Bullish OB is currently active for PA
string g_smcSellTouchedOBName = "";      // Which Bearish OB is currently active for PA
datetime g_smcBuyTouchTime = 0;          // Time when buy touch detected (TimeCurrent)
datetime g_smcSellTouchTime = 0;         // Time when sell touch detected (TimeCurrent)

// SMC Swing Points
double SMCSwingHigh = 0;
double SMCSwingLow = 0;
datetime SMCSwingHighTime = 0;
datetime SMCSwingLowTime = 0;
int SMCTrend = 0;  // +1 = Bullish, -1 = Bearish, 0 = Neutral

long ZZTFChartId = 0;

// ZigZag tracking for confirmed points
datetime LastConfirmedZZTime = 0;

// Grid Tracking
datetime InitialBuyBarTime = 0;
datetime InitialSellBarTime = 0;
int GridBuyCount = 0;
int GridSellCount = 0;

// Hedge Lock Flags (prevent multiple hedge orders and stop all trading)
bool g_isHedgedBuy = false;   // True when BUY side is already hedged
bool g_isHedgedSell = false;  // True when SELL side is already hedged
bool g_isHedgeLocked = false; // True when ANY hedge is active - stops ALL new orders
datetime LastGridBuyTime = 0;
datetime LastGridSellTime = 0;

// Group TP Accumulated Profit Tracking
double AccumulatedProfit = 0.0;
double LastClosedProfit = 0.0;

// Price Action Confirmation Tracking
string g_pendingSignal = "NONE";       // "BUY", "SELL", or "NONE"
datetime g_signalBarTime = 0;          // Time when signal was detected
datetime g_signalTouchTime = 0;        // Time when OB/signal touch occurred (PA must come AFTER this)
int g_paWaitCount = 0;                 // Number of candles waited for PA

// *** SIGNAL RESET TRACKING ***
// After closing positions, require signal to reset before allowing new entries
// BUY Reset: Price must close BELOW EMA first, then close ABOVE EMA again
// SELL Reset: Price must close ABOVE EMA first, then close BELOW EMA again
bool g_waitBuySignalReset = false;     // True when waiting for BUY signal to reset
bool g_waitSellSignalReset = false;    // True when waiting for SELL signal to reset
bool g_buyResetPhaseBelowEMA = false;  // True when price has closed below EMA (step 1 of BUY reset)
bool g_sellResetPhaseAboveEMA = false; // True when price has closed above EMA (step 1 of SELL reset)

// For ZigZag Strategy Reset
bool g_buyResetWaitOppositeSignal = false;  // Wait for HH/LH before allowing BUY again
bool g_sellResetWaitOppositeSignal = false; // Wait for LL/HL before allowing SELL again

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("===========================================");
   Print("ZigZag++ CDC Structure EA v4.0 + Grid");
   Print("Symbol: ", _Symbol);
   Print("Entry TF: ", EnumToString(Period()));
   Print("ZigZag TF: ", EnumToString(InpZigZagTimeframe));
   Print("CDC Filter TF: ", EnumToString(InpCDCTimeframe));
   Print("Trade Mode: ", EnumToString(InpTradeMode));
   Print("Lot Mode: ", EnumToString(InpLotMode));
   Print("Grid Loss Max: ", InpGridLossMaxTrades);
   Print("Grid Profit Max: ", InpGridProfitMaxTrades);
   Print("===========================================");
   
   trade.SetExpertMagicNumber(InpMagicNumber);
   
   // Open a chart for the selected ZigZag timeframe (so you can SEE the objects there)
   ZZTFChartId = 0;
   if(InpZigZagTimeframe != PERIOD_CURRENT && InpZigZagTimeframe != Period())
   {
      ZZTFChartId = ChartOpen(_Symbol, InpZigZagTimeframe);
      if(ZZTFChartId > 0)
         Print("ZigZag TF chart opened: ", ZZTFChartId, " (", EnumToString(InpZigZagTimeframe), ")");
      else
         Print("WARNING: Could not open ZigZag TF chart for ", EnumToString(InpZigZagTimeframe));
   }
   
   // Reset counters
   LastConfirmedZZTime = 0;
   LastEMASignalTime = 0;
   LastBBSignalTime = 0;
   LastSMCSignalTime = 0;
   GridBuyCount = 0;
   GridSellCount = 0;
   InitialBuyBarTime = 0;
   InitialSellBarTime = 0;
   
   // Initialize SMC Order Block arrays
   if(InpSignalStrategy == STRATEGY_SMC)
   {
      ArrayResize(BullishOBs, InpSMCMaxOrderBlocks);
      ArrayResize(BearishOBs, InpSMCMaxOrderBlocks);
      BullishOBCount = 0;
      BearishOBCount = 0;
      Print("Smart Money Concepts initialized - Swing Length: ", InpSMCSwingLength, " | Max OBs: ", InpSMCMaxOrderBlocks);
   }
   
   // Initialize Bollinger Bands indicator handle
   if(InpSignalStrategy == STRATEGY_BOLLINGER)
   {
      // Get MA method for iBands
      ENUM_MA_METHOD maMethod = MODE_SMA;
      if(InpBBMAType == BB_MA_EMA) maMethod = MODE_EMA;
      else if(InpBBMAType == BB_MA_SMMA) maMethod = MODE_SMMA;
      else if(InpBBMAType == BB_MA_WMA) maMethod = MODE_LWMA;
      
      BBHandle = iBands(_Symbol, InpBBTimeframe, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
      
      if(BBHandle == INVALID_HANDLE)
      {
         Print("ERROR: Failed to create Bollinger Bands indicator handle!");
      }
      else
      {
         Print("Bollinger Bands indicator initialized - Period: ", InpBBPeriod, " | Deviation: ", InpBBDeviation);
         
         // Add BB indicator to chart for visual display
         if(InpShowBBLines)
         {
            ChartIndicatorAdd(0, 0, BBHandle);
            Print("Bollinger Bands indicator added to chart");
         }
      }
   }
   
   Print("Signal Strategy: ", EnumToString(InpSignalStrategy));
   Print("EA Started Successfully!");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Remove all chart objects (current chart)
   ObjectsDeleteAll(0, ZZPrefix);
   ObjectsDeleteAll(0, CDCPrefix);
   ObjectsDeleteAll(0, TPPrefix);
   ObjectsDeleteAll(0, EMAPrefix);
   ObjectsDeleteAll(0, PAPrefix);  // Remove PA arrows and labels
   ObjectsDeleteAll(0, BBPrefix);  // Remove BB objects
   ObjectsDeleteAll(0, SMCPrefix); // Remove SMC Order Block objects
   
   // Release Bollinger Bands indicator handle
   if(BBHandle != INVALID_HANDLE)
   {
      // Remove indicator from chart before releasing handle
      ChartIndicatorDelete(0, 0, ChartIndicatorName(0, 0, ChartIndicatorsTotal(0, 0) - 1));
      IndicatorRelease(BBHandle);
      BBHandle = INVALID_HANDLE;
   }
   
   // Clear SMC arrays
   ArrayFree(BullishOBs);
   ArrayFree(BearishOBs);
   BullishOBCount = 0;
   BearishOBCount = 0;
   
   // Remove ZigZag objects from the ZigZag timeframe chart (if opened)
   if(ZZTFChartId > 0)
   {
      ObjectsDeleteAll(ZZTFChartId, ZZPrefix);
      ChartClose(ZZTFChartId);
      ZZTFChartId = 0;
   }
   
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
//| *** Grid Loss และ Grid Profit แยกนับ level กันอิสระ ***            |
//|                                                                    |
//| Initial Order = level 0 = InpInitialLot (เป็นตัวกลาง)               |
//|                                                                    |
//| Grid Loss Side:                                                    |
//|   - gridLevel = 1 = First Grid Loss = InitialLot + AddLotLoss      |
//|   - gridLevel = 2 = Second Grid Loss = InitialLot + AddLotLoss*2   |
//|                                                                    |
//| Grid Profit Side:                                                  |
//|   - gridLevel = 1 = First Grid Profit = InitialLot + AddLotProfit  |
//|   - gridLevel = 2 = Second Grid Profit = InitialLot + AddLotProfit*2|
//|                                                                    |
//| ตัวอย่าง: InitialLot=1, AddLotLoss=1, AddLotProfit=0.5            |
//|   Initial Order: 1.0 lot                                           |
//|   Grid Profit #1: 1.0 + 0.5*1 = 1.5 lot                            |
//|   Grid Loss #1: 1.0 + 1.0*1 = 2.0 lot                              |
//|   Grid Profit #2: 1.0 + 0.5*2 = 2.0 lot                            |
//|   Grid Loss #2: 1.0 + 1.0*2 = 3.0 lot                              |
//+------------------------------------------------------------------+
double GetGridLotSize(bool isLossSide, int gridLevel)
{
   ENUM_GRID_LOT_MODE lotMode = isLossSide ? InpGridLossLotMode : InpGridProfitLotMode;
   double calculatedLot = InpInitialLot;
   
   // gridLevel = 0 means Initial Order (uses InitialLot only)
   if(gridLevel == 0)
   {
      calculatedLot = InpInitialLot;
   }
   else if(lotMode == GRID_LOT_CUSTOM)
   {
      // Custom Lot Mode: Use the lot array from string
      // Index 0 = First Grid order (not Initial Order)
      double lots[];
      if(isLossSide)
         ParseStringToDoubleArray(InpGridLossCustomLot, lots);
      else
         ParseStringToDoubleArray(InpGridProfitCustomLot, lots);
      
      int idx = gridLevel - 1;  // Adjust for 0-based array
      if(idx < ArraySize(lots))
         calculatedLot = lots[idx];
      else if(ArraySize(lots) > 0)
         calculatedLot = lots[ArraySize(lots) - 1];  // Use last value for levels beyond array
   }
   else  // GRID_LOT_ADD
   {
      // Add Lot Mode: InitialLot + (AddLot * gridLevel)
      // Grid Loss และ Grid Profit ใช้ AddLot ของตัวเอง แยกกันอิสระ
      double addLot = isLossSide ? InpGridLossAddLot : InpGridProfitAddLot;
      
      // gridLevel = 1 = First Grid = InitialLot + AddLot*1
      // gridLevel = 2 = Second Grid = InitialLot + AddLot*2
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
//| Convert ZigZag Timeframe time to Chart Timeframe time             |
//+------------------------------------------------------------------+
datetime ConvertToChartTime(datetime zzTime)
{
   // If using current timeframe, no conversion needed
   if(InpZigZagTimeframe == PERIOD_CURRENT || InpZigZagTimeframe == Period())
      return zzTime;
   
   // Find the bar index on current chart that corresponds to this time
   int chartBar = iBarShift(_Symbol, PERIOD_CURRENT, zzTime, false);
   if(chartBar < 0) chartBar = 0;
   
   // Return the time of that bar on the current chart
   return iTime(_Symbol, PERIOD_CURRENT, chartBar);
}

//+------------------------------------------------------------------+
//| Get price at ZigZag point mapped to Chart Timeframe               |
//+------------------------------------------------------------------+
double GetChartPrice(ZigZagPoint &zp)
{
   // If using current timeframe, use original price
   if(InpZigZagTimeframe == PERIOD_CURRENT || InpZigZagTimeframe == Period())
      return zp.price;
   
   // Find the bar on current chart
   int chartBar = iBarShift(_Symbol, PERIOD_CURRENT, zp.time, false);
   if(chartBar < 0) chartBar = 0;
   
   // For high points, use the high of that bar range
   // For low points, use the low of that bar range
   if(zp.direction == 1)  // High point
      return iHigh(_Symbol, PERIOD_CURRENT, chartBar);
   else  // Low point
      return iLow(_Symbol, PERIOD_CURRENT, chartBar);
}

//+------------------------------------------------------------------+
//| Draw ZigZag++ Lines and Labels on Chart                           |
//+------------------------------------------------------------------+
void DrawZigZagOnChart()
{
   // Draw on BOTH current chart AND ZigZag timeframe for visibility
   bool drawBothTimeframes = (InpZigZagTimeframe != PERIOD_CURRENT && InpZigZagTimeframe != Period());
   
   for(int i = 0; i < ZZPointCount - 1; i++)
   {
      ZigZagPoint p1 = ZZPoints[i];
      ZigZagPoint p2 = ZZPoints[i + 1];
      
      // Convert times to chart timeframe for drawing on current chart
      datetime p1ChartTime = ConvertToChartTime(p1.time);
      datetime p2ChartTime = ConvertToChartTime(p2.time);
      
      // === Draw on CURRENT CHART (converted times) ===
      if(InpShowLines)
      {
         string lineName = ZZPrefix + "Line_" + IntegerToString(i);
         color lineColor = (p1.direction == 1) ? InpBearColor : InpBullColor;
         
         ObjectCreate(0, lineName, OBJ_TREND, 0, p2ChartTime, p2.price, p1ChartTime, p1.price);
         ObjectSetInteger(0, lineName, OBJPROP_COLOR, lineColor);
         ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);
         ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
         ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, lineName, OBJPROP_BACK, false);
      }
      
      if(InpShowLabels)
      {
         string labelName = ZZPrefix + "Label_" + IntegerToString(i);
         color labelColor = (p1.label == "LL" || p1.label == "HL") ? InpBullColor : InpBearColor;
         ENUM_ANCHOR_POINT anchor = (p1.direction == 1) ? ANCHOR_LOWER : ANCHOR_UPPER;
         
         ObjectCreate(0, labelName, OBJ_TEXT, 0, p1ChartTime, p1.price);
         ObjectSetString(0, labelName, OBJPROP_TEXT, p1.label);
         ObjectSetInteger(0, labelName, OBJPROP_COLOR, labelColor);
         ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);
         ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
         ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, anchor);
      }
      
      // === Draw on ZIGZAG TIMEFRAME (original times) - for viewing in that TF ===
      // NOTE: Objects only appear on the chart they are created on.
      // We therefore create them on a dedicated chart for InpZigZagTimeframe.
      if(drawBothTimeframes && ZZTFChartId > 0)
      {
         if(InpShowLines)
         {
            string lineName = ZZPrefix + "TF_Line_" + IntegerToString(i);
            color lineColor = (p1.direction == 1) ? InpBearColor : InpBullColor;
            
            ObjectCreate(ZZTFChartId, lineName, OBJ_TREND, 0, p2.time, p2.price, p1.time, p1.price);
            ObjectSetInteger(ZZTFChartId, lineName, OBJPROP_COLOR, lineColor);
            ObjectSetInteger(ZZTFChartId, lineName, OBJPROP_WIDTH, 2);
            ObjectSetInteger(ZZTFChartId, lineName, OBJPROP_RAY_RIGHT, false);
            ObjectSetInteger(ZZTFChartId, lineName, OBJPROP_SELECTABLE, false);
            ObjectSetInteger(ZZTFChartId, lineName, OBJPROP_BACK, false);
         }
         
         if(InpShowLabels)
         {
            string labelName = ZZPrefix + "TF_Label_" + IntegerToString(i);
            color labelColor = (p1.label == "LL" || p1.label == "HL") ? InpBullColor : InpBearColor;
            ENUM_ANCHOR_POINT anchor = (p1.direction == 1) ? ANCHOR_LOWER : ANCHOR_UPPER;
            
            ObjectCreate(ZZTFChartId, labelName, OBJ_TEXT, 0, p1.time, p1.price);
            ObjectSetString(ZZTFChartId, labelName, OBJPROP_TEXT, p1.label);
            ObjectSetInteger(ZZTFChartId, labelName, OBJPROP_COLOR, labelColor);
            ObjectSetInteger(ZZTFChartId, labelName, OBJPROP_FONTSIZE, 10);
            ObjectSetString(ZZTFChartId, labelName, OBJPROP_FONT, "Arial Bold");
            ObjectSetInteger(ZZTFChartId, labelName, OBJPROP_ANCHOR, anchor);
         }
      }
   }
   
   // Draw label for last point
   if(InpShowLabels && ZZPointCount > 0)
   {
      int last = ZZPointCount - 1;
      datetime lastChartTime = ConvertToChartTime(ZZPoints[last].time);
      
      // Current chart
      string labelName = ZZPrefix + "Label_" + IntegerToString(last);
      color labelColor = (ZZPoints[last].label == "LL" || ZZPoints[last].label == "HL") ? 
                          InpBullColor : InpBearColor;
      ENUM_ANCHOR_POINT anchor = (ZZPoints[last].direction == 1) ? ANCHOR_LOWER : ANCHOR_UPPER;
      
      ObjectCreate(0, labelName, OBJ_TEXT, 0, lastChartTime, ZZPoints[last].price);
      ObjectSetString(0, labelName, OBJPROP_TEXT, ZZPoints[last].label);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, labelColor);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, anchor);
      
      // ZigZag Timeframe
      if(drawBothTimeframes && ZZTFChartId > 0)
      {
         string labelNameTF = ZZPrefix + "TF_Label_" + IntegerToString(last);
         ObjectCreate(ZZTFChartId, labelNameTF, OBJ_TEXT, 0, ZZPoints[last].time, ZZPoints[last].price);
         ObjectSetString(ZZTFChartId, labelNameTF, OBJPROP_TEXT, ZZPoints[last].label);
         ObjectSetInteger(ZZTFChartId, labelNameTF, OBJPROP_COLOR, labelColor);
         ObjectSetInteger(ZZTFChartId, labelNameTF, OBJPROP_FONTSIZE, 10);
         ObjectSetString(ZZTFChartId, labelNameTF, OBJPROP_FONT, "Arial Bold");
         ObjectSetInteger(ZZTFChartId, labelNameTF, OBJPROP_ANCHOR, anchor);
      }
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
//| Calculate EMA Channel Values                                       |
//+------------------------------------------------------------------+
void CalculateEMAChannel()
{
   if(InpSignalStrategy != STRATEGY_EMA_CHANNEL)
      return;
   
   double highArr[], lowArr[], closeArr[];
   datetime timeArr[];
   ArraySetAsSeries(highArr, true);
   ArraySetAsSeries(lowArr, true);
   ArraySetAsSeries(closeArr, true);
   ArraySetAsSeries(timeArr, true);
   
   int barsNeeded = MathMax(InpEMAHighPeriod, InpEMALowPeriod) * 3 + 50;
   
   if(CopyHigh(_Symbol, InpEMATimeframe, 0, barsNeeded, highArr) < barsNeeded) return;
   if(CopyLow(_Symbol, InpEMATimeframe, 0, barsNeeded, lowArr) < barsNeeded) return;
   if(CopyClose(_Symbol, InpEMATimeframe, 0, barsNeeded, closeArr) < barsNeeded) return;
   if(CopyTime(_Symbol, InpEMATimeframe, 0, barsNeeded, timeArr) < barsNeeded) return;
   
   // Calculate EMA of High prices
   double emaHighArr[];
   ArrayResize(emaHighArr, barsNeeded);
   CalculateEMA(highArr, emaHighArr, InpEMAHighPeriod, barsNeeded);
   
   // Calculate EMA of Low prices
   double emaLowArr[];
   ArrayResize(emaLowArr, barsNeeded);
   CalculateEMA(lowArr, emaLowArr, InpEMALowPeriod, barsNeeded);
   
   // Determine signal bar index based on setting
   int signalBar = (InpEMASignalBar == EMA_CURRENT_BAR) ? 0 : 1;
   int prevBar = signalBar + 1;
   
   EMAHigh = emaHighArr[signalBar];
   EMALow = emaLowArr[signalBar];
   
   double signalClose = closeArr[signalBar];
   double prevClose = closeArr[prevBar];
   double prevEMAHigh = emaHighArr[prevBar];
   double prevEMALow = emaLowArr[prevBar];
   
   // Check for EMA Channel crossover
   // BUY Signal: Price is NOW above both EMA lines AND was previously NOT above both (inside or below channel)
   bool nowAboveBoth = (signalClose > EMAHigh && signalClose > EMALow);
   bool prevNotAboveBoth = (prevClose <= prevEMAHigh || prevClose <= prevEMALow);
   
   // SELL Signal: Price is NOW below both EMA lines AND was previously NOT below both (inside or above channel)
   bool nowBelowBoth = (signalClose < EMAHigh && signalClose < EMALow);
   bool prevNotBelowBoth = (prevClose >= prevEMALow || prevClose >= prevEMAHigh);
   
   EMASignal = "NONE";
   
   if(nowAboveBoth && prevNotAboveBoth)
   {
      EMASignal = "BUY";
      Print("EMA Channel: BUY Signal - Price crossed ABOVE channel");
      Print("  Signal Close: ", signalClose, " > EMA High: ", EMAHigh, " & EMA Low: ", EMALow);
      Print("  Prev Close: ", prevClose, " | Prev EMA High: ", prevEMAHigh, " | Prev EMA Low: ", prevEMALow);
   }
   else if(nowBelowBoth && prevNotBelowBoth)
   {
      EMASignal = "SELL";
      Print("EMA Channel: SELL Signal - Price crossed BELOW channel");
      Print("  Signal Close: ", signalClose, " < EMA Low: ", EMALow, " & EMA High: ", EMAHigh);
      Print("  Prev Close: ", prevClose, " | Prev EMA High: ", prevEMAHigh, " | Prev EMA Low: ", prevEMALow);
   }
   
   // Draw EMA lines on chart
   if(InpShowEMALines)
   {
      DrawEMAChannelOnChart(emaHighArr, emaLowArr, timeArr, barsNeeded);
   }
}

//+------------------------------------------------------------------+
//| Draw EMA Channel Lines on Chart                                    |
//+------------------------------------------------------------------+
void DrawEMAChannelOnChart(double &emaHigh[], double &emaLow[], datetime &time[], int size)
{
   ObjectsDeleteAll(0, EMAPrefix);
   
   // Extended to show full chart - use 500 bars for maximum visibility
   int maxBars = MathMin(500, size - 1);
   
   // Draw EMA High line with smooth style
   for(int i = 0; i < maxBars; i++)
   {
      string lineName = EMAPrefix + "High_" + IntegerToString(i);
      datetime t1 = time[i + 1];
      datetime t2 = time[i];
      
      ObjectCreate(0, lineName, OBJ_TREND, 0, t1, emaHigh[i + 1], t2, emaHigh[i]);
      ObjectSetInteger(0, lineName, OBJPROP_COLOR, InpEMAHighColor);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_SOLID);  // Smooth solid line
      ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, lineName, OBJPROP_BACK, true);  // Draw in background for smoother appearance
   }
   
   // Draw EMA Low line with smooth style
   for(int i = 0; i < maxBars; i++)
   {
      string lineName = EMAPrefix + "Low_" + IntegerToString(i);
      datetime t1 = time[i + 1];
      datetime t2 = time[i];
      
      ObjectCreate(0, lineName, OBJ_TREND, 0, t1, emaLow[i + 1], t2, emaLow[i]);
      ObjectSetInteger(0, lineName, OBJPROP_COLOR, InpEMALowColor);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, lineName, OBJPROP_STYLE, STYLE_SOLID);  // Smooth solid line
      ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, lineName, OBJPROP_BACK, true);  // Draw in background for smoother appearance
   }
   
   // Draw status label
   string labelName = EMAPrefix + "Status_Label";
   ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, 10);
   ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, 70);
   
   string signalBarText = (InpEMASignalBar == EMA_CURRENT_BAR) ? "Current" : "LastClosed";
   string statusText = "EMA Channel (" + EnumToString(InpEMATimeframe) + ") [" + signalBarText + "]";
   statusText += " | H: " + DoubleToString(EMAHigh, _Digits) + " L: " + DoubleToString(EMALow, _Digits);
   
   ObjectSetString(0, labelName, OBJPROP_TEXT, statusText);
   ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 10);
   ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
}


//+------------------------------------------------------------------+
//| ================== PRICE ACTION DETECTION ====================== |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check if candle is Bullish                                         |
//+------------------------------------------------------------------+
bool IsBullishCandle(int shift)
{
   double open = iOpen(_Symbol, PERIOD_CURRENT, shift);
   double close = iClose(_Symbol, PERIOD_CURRENT, shift);
   return close > open;
}

//+------------------------------------------------------------------+
//| Check if candle is Bearish                                         |
//+------------------------------------------------------------------+
bool IsBearishCandle(int shift)
{
   double open = iOpen(_Symbol, PERIOD_CURRENT, shift);
   double close = iClose(_Symbol, PERIOD_CURRENT, shift);
   return close < open;
}

//+------------------------------------------------------------------+
//| Get candle body size                                               |
//+------------------------------------------------------------------+
double GetCandleBody(int shift)
{
   double open = iOpen(_Symbol, PERIOD_CURRENT, shift);
   double close = iClose(_Symbol, PERIOD_CURRENT, shift);
   return MathAbs(close - open);
}

//+------------------------------------------------------------------+
//| Get candle range (high - low)                                      |
//+------------------------------------------------------------------+
double GetCandleRange(int shift)
{
   double high = iHigh(_Symbol, PERIOD_CURRENT, shift);
   double low = iLow(_Symbol, PERIOD_CURRENT, shift);
   return high - low;
}

//+------------------------------------------------------------------+
//| Get upper tail size                                                |
//+------------------------------------------------------------------+
double GetUpperTail(int shift)
{
   double high = iHigh(_Symbol, PERIOD_CURRENT, shift);
   double open = iOpen(_Symbol, PERIOD_CURRENT, shift);
   double close = iClose(_Symbol, PERIOD_CURRENT, shift);
   return high - MathMax(open, close);
}

//+------------------------------------------------------------------+
//| Get lower tail size                                                |
//+------------------------------------------------------------------+
double GetLowerTail(int shift)
{
   double low = iLow(_Symbol, PERIOD_CURRENT, shift);
   double open = iOpen(_Symbol, PERIOD_CURRENT, shift);
   double close = iClose(_Symbol, PERIOD_CURRENT, shift);
   return MathMin(open, close) - low;
}

//+------------------------------------------------------------------+
//| Check if candle is a Doji (indecision)                             |
//+------------------------------------------------------------------+
bool IsDoji(int shift)
{
   double range = GetCandleRange(shift);
   if(range <= 0) return false;
   double body = GetCandleBody(shift);
   return (body / range) <= InpPADojiMaxRatio;
}

//+------------------------------------------------------------------+
//| Detect Hammer/Pin Bar (Bullish) - Long lower tail, small body up  |
//+------------------------------------------------------------------+
bool IsHammer(int shift)
{
   if(!InpPAHammer) return false;
   
   double body = GetCandleBody(shift);
   double lowerTail = GetLowerTail(shift);
   double upperTail = GetUpperTail(shift);
   
   if(body <= 0) return false;
   
   // Hammer: long lower tail >= body * ratio, small upper tail
   bool longLowerTail = lowerTail >= body * InpPAPinRatio;
   bool smallUpperTail = upperTail <= body * 0.5;
   bool bullishClose = IsBullishCandle(shift);
   
   return longLowerTail && smallUpperTail && bullishClose;
}

//+------------------------------------------------------------------+
//| Detect Shooting Star/Pin Bar (Bearish) - Long upper tail          |
//+------------------------------------------------------------------+
bool IsShootingStar(int shift)
{
   if(!InpPAShootingStar) return false;
   
   double body = GetCandleBody(shift);
   double lowerTail = GetLowerTail(shift);
   double upperTail = GetUpperTail(shift);
   
   if(body <= 0) return false;
   
   // Shooting Star: long upper tail >= body * ratio, small lower tail
   bool longUpperTail = upperTail >= body * InpPAPinRatio;
   bool smallLowerTail = lowerTail <= body * 0.5;
   bool bearishClose = IsBearishCandle(shift);
   
   return longUpperTail && smallLowerTail && bearishClose;
}

//+------------------------------------------------------------------+
//| Detect Bullish Engulfing Pattern                                   |
//+------------------------------------------------------------------+
bool IsBullishEngulfing(int shift)
{
   if(!InpPABullEngulfing) return false;
   if(shift < 1) return false;
   
   // Current candle must be bullish
   if(!IsBullishCandle(shift)) return false;
   // Previous candle must be bearish
   if(!IsBearishCandle(shift + 1)) return false;
   
   double currOpen = iOpen(_Symbol, PERIOD_CURRENT, shift);
   double currClose = iClose(_Symbol, PERIOD_CURRENT, shift);
   double prevOpen = iOpen(_Symbol, PERIOD_CURRENT, shift + 1);
   double prevClose = iClose(_Symbol, PERIOD_CURRENT, shift + 1);
   
   // Current body engulfs previous body
   bool engulfs = currOpen <= prevClose && currClose >= prevOpen;
   
   // Current body is significant
   double currRange = GetCandleRange(shift);
   double currBody = GetCandleBody(shift);
   bool significantBody = currRange > 0 && (currBody / currRange) >= InpPABodyMinRatio;
   
   return engulfs && significantBody;
}

//+------------------------------------------------------------------+
//| Detect Bearish Engulfing Pattern                                   |
//+------------------------------------------------------------------+
bool IsBearishEngulfing(int shift)
{
   if(!InpPABearEngulfing) return false;
   if(shift < 1) return false;
   
   // Current candle must be bearish
   if(!IsBearishCandle(shift)) return false;
   // Previous candle must be bullish
   if(!IsBullishCandle(shift + 1)) return false;
   
   double currOpen = iOpen(_Symbol, PERIOD_CURRENT, shift);
   double currClose = iClose(_Symbol, PERIOD_CURRENT, shift);
   double prevOpen = iOpen(_Symbol, PERIOD_CURRENT, shift + 1);
   double prevClose = iClose(_Symbol, PERIOD_CURRENT, shift + 1);
   
   // Current body engulfs previous body
   bool engulfs = currOpen >= prevClose && currClose <= prevOpen;
   
   // Current body is significant
   double currRange = GetCandleRange(shift);
   double currBody = GetCandleBody(shift);
   bool significantBody = currRange > 0 && (currBody / currRange) >= InpPABodyMinRatio;
   
   return engulfs && significantBody;
}

//+------------------------------------------------------------------+
//| Detect Tweezer Bottom Pattern (2 candles with same low)           |
//+------------------------------------------------------------------+
bool IsTweezerBottom(int shift)
{
   if(!InpPATweezerBottom) return false;
   if(shift < 1) return false;
   
   double currLow = iLow(_Symbol, PERIOD_CURRENT, shift);
   double prevLow = iLow(_Symbol, PERIOD_CURRENT, shift + 1);
   
   // Lows are approximately equal (within 10 points)
   double tolerance = 10 * _Point;
   bool sameLows = MathAbs(currLow - prevLow) <= tolerance;
   
   // Both candles have long lower tails
   double currLowerTail = GetLowerTail(shift);
   double prevLowerTail = GetLowerTail(shift + 1);
   double currRange = GetCandleRange(shift);
   double prevRange = GetCandleRange(shift + 1);
   
   bool currLongTail = currRange > 0 && (currLowerTail / currRange) >= 0.4;
   bool prevLongTail = prevRange > 0 && (prevLowerTail / prevRange) >= 0.4;
   
   // Current candle should be bullish (reversal confirmation)
   bool bullishCurrent = IsBullishCandle(shift);
   
   return sameLows && currLongTail && prevLongTail && bullishCurrent;
}

//+------------------------------------------------------------------+
//| Detect Tweezer Top Pattern (2 candles with same high)             |
//+------------------------------------------------------------------+
bool IsTweezerTop(int shift)
{
   if(!InpPATweezerTop) return false;
   if(shift < 1) return false;
   
   double currHigh = iHigh(_Symbol, PERIOD_CURRENT, shift);
   double prevHigh = iHigh(_Symbol, PERIOD_CURRENT, shift + 1);
   
   // Highs are approximately equal (within 10 points)
   double tolerance = 10 * _Point;
   bool sameHighs = MathAbs(currHigh - prevHigh) <= tolerance;
   
   // Both candles have long upper tails
   double currUpperTail = GetUpperTail(shift);
   double prevUpperTail = GetUpperTail(shift + 1);
   double currRange = GetCandleRange(shift);
   double prevRange = GetCandleRange(shift + 1);
   
   bool currLongTail = currRange > 0 && (currUpperTail / currRange) >= 0.4;
   bool prevLongTail = prevRange > 0 && (prevUpperTail / prevRange) >= 0.4;
   
   // Current candle should be bearish (reversal confirmation)
   bool bearishCurrent = IsBearishCandle(shift);
   
   return sameHighs && currLongTail && prevLongTail && bearishCurrent;
}

//+------------------------------------------------------------------+
//| Detect Morning Star Pattern (3 candles bullish reversal)          |
//+------------------------------------------------------------------+
bool IsMorningStar(int shift)
{
   if(!InpPAMorningStar) return false;
   if(shift < 2) return false;
   
   // Candle 3 (oldest): Bearish
   if(!IsBearishCandle(shift + 2)) return false;
   
   // Candle 2 (middle): Doji/Indecision (small body)
   if(!IsDoji(shift + 1)) return false;
   
   // Candle 1 (current/newest): Bullish
   if(!IsBullishCandle(shift)) return false;
   
   // Current candle closes above midpoint of first candle
   double firstOpen = iOpen(_Symbol, PERIOD_CURRENT, shift + 2);
   double firstClose = iClose(_Symbol, PERIOD_CURRENT, shift + 2);
   double firstMid = (firstOpen + firstClose) / 2.0;
   double currClose = iClose(_Symbol, PERIOD_CURRENT, shift);
   
   return currClose >= firstMid;
}

//+------------------------------------------------------------------+
//| Detect Evening Star Pattern (3 candles bearish reversal)          |
//+------------------------------------------------------------------+
bool IsEveningStar(int shift)
{
   if(!InpPAEveningStar) return false;
   if(shift < 2) return false;
   
   // Candle 3 (oldest): Bullish
   if(!IsBullishCandle(shift + 2)) return false;
   
   // Candle 2 (middle): Doji/Indecision (small body)
   if(!IsDoji(shift + 1)) return false;
   
   // Candle 1 (current/newest): Bearish
   if(!IsBearishCandle(shift)) return false;
   
   // Current candle closes below midpoint of first candle
   double firstOpen = iOpen(_Symbol, PERIOD_CURRENT, shift + 2);
   double firstClose = iClose(_Symbol, PERIOD_CURRENT, shift + 2);
   double firstMid = (firstOpen + firstClose) / 2.0;
   double currClose = iClose(_Symbol, PERIOD_CURRENT, shift);
   
   return currClose <= firstMid;
}

//+------------------------------------------------------------------+
//| Detect Outside Candle Reversal (Bullish)                           |
//| - Price faked down then broke above 2 previous candle highs       |
//+------------------------------------------------------------------+
bool IsOutsideCandleBullish(int shift)
{
   if(!InpPAOutsideCandleBull) return false;
   if(shift < 2) return false;
   
   // Current candle must be bullish
   if(!IsBullishCandle(shift)) return false;
   
   double currHigh = iHigh(_Symbol, PERIOD_CURRENT, shift);
   double currLow = iLow(_Symbol, PERIOD_CURRENT, shift);
   double prev1High = iHigh(_Symbol, PERIOD_CURRENT, shift + 1);
   double prev2High = iHigh(_Symbol, PERIOD_CURRENT, shift + 2);
   double prev1Low = iLow(_Symbol, PERIOD_CURRENT, shift + 1);
   double prev2Low = iLow(_Symbol, PERIOD_CURRENT, shift + 2);
   
   // Current candle breaks above both previous highs
   bool breakHighs = currHigh > prev1High && currHigh > prev2High;
   
   // Current candle went below at least one previous low (faked down)
   bool fakedDown = currLow < prev1Low || currLow < prev2Low;
   
   return breakHighs && fakedDown;
}

//+------------------------------------------------------------------+
//| Detect Outside Candle Reversal (Bearish)                           |
//| - Price faked up then broke below 2 previous candle lows          |
//+------------------------------------------------------------------+
bool IsOutsideCandleBearish(int shift)
{
   if(!InpPAOutsideCandleBear) return false;
   if(shift < 2) return false;
   
   // Current candle must be bearish
   if(!IsBearishCandle(shift)) return false;
   
   double currHigh = iHigh(_Symbol, PERIOD_CURRENT, shift);
   double currLow = iLow(_Symbol, PERIOD_CURRENT, shift);
   double prev1High = iHigh(_Symbol, PERIOD_CURRENT, shift + 1);
   double prev2High = iHigh(_Symbol, PERIOD_CURRENT, shift + 2);
   double prev1Low = iLow(_Symbol, PERIOD_CURRENT, shift + 1);
   double prev2Low = iLow(_Symbol, PERIOD_CURRENT, shift + 2);
   
   // Current candle breaks below both previous lows
   bool breakLows = currLow < prev1Low && currLow < prev2Low;
   
   // Current candle went above at least one previous high (faked up)
   bool fakedUp = currHigh > prev1High || currHigh > prev2High;
   
   return breakLows && fakedUp;
}

//+------------------------------------------------------------------+
//| Detect Pullback Buy Pattern                                        |
//| - Uptrend with pullback, then broke previous candle highs         |
//+------------------------------------------------------------------+
bool IsPullbackBuy(int shift)
{
   if(!InpPAPullbackBuy) return false;
   // Need at least 3 candles of history from the reference point
   // shift=1 needs shift+1 and shift+2, so minimum shift is 1
   if(shift < 1) return false;
   
   // Current candle (shift) must be bullish
   if(!IsBullishCandle(shift)) return false;
   
   // Check for uptrend with pullback pattern
   // Pattern: Bullish move → Bearish pullback → Bullish continuation (current)
   // Current (shift): Bullish and breaks previous highs
   // Previous (shift+1 or shift+2): Had a bearish pullback candle
   
   double currHigh = iHigh(_Symbol, PERIOD_CURRENT, shift);
   double prev1High = iHigh(_Symbol, PERIOD_CURRENT, shift + 1);
   double prev2High = iHigh(_Symbol, PERIOD_CURRENT, shift + 2);
   
   // Current breaks previous highs (bullish continuation)
   bool breaksHighs = currHigh > prev1High && currHigh > prev2High;
   
   // There was a pullback (bearish candle in recent history)
   bool hadPullback = IsBearishCandle(shift + 1) || IsBearishCandle(shift + 2);
   
   return breaksHighs && hadPullback;
}

//+------------------------------------------------------------------+
//| Detect Pullback Sell Pattern                                       |
//| - Downtrend with pullback, then broke previous candle lows        |
//+------------------------------------------------------------------+
bool IsPullbackSell(int shift)
{
   if(!InpPAPullbackSell) return false;
   // Need at least 3 candles of history from the reference point
   if(shift < 1) return false;
   
   // Current candle (shift) must be bearish
   if(!IsBearishCandle(shift)) return false;
   
   double currLow = iLow(_Symbol, PERIOD_CURRENT, shift);
   double prev1Low = iLow(_Symbol, PERIOD_CURRENT, shift + 1);
   double prev2Low = iLow(_Symbol, PERIOD_CURRENT, shift + 2);
   
   // Current breaks previous lows (bearish continuation)
   bool breaksLows = currLow < prev1Low && currLow < prev2Low;
   
   // There was a pullback (bullish candle in recent history)
   bool hadPullback = IsBullishCandle(shift + 1) || IsBullishCandle(shift + 2);
   
   return breaksLows && hadPullback;
}

//+------------------------------------------------------------------+
//| Detect Inside Candle Reversal (Bullish)                            |
//| - 3 candle pattern: first candle, inside candle, then bullish     |
//+------------------------------------------------------------------+
bool IsInsideCandleBullish(int shift)
{
   if(!InpPAInsideCandleBull) return false;
   if(shift < 2) return false;
   
   // Candle 1 (current): Must be bullish
   if(!IsBullishCandle(shift)) return false;
   
   // Candle 2 (middle): Inside candle - high and low within candle 3
   double midHigh = iHigh(_Symbol, PERIOD_CURRENT, shift + 1);
   double midLow = iLow(_Symbol, PERIOD_CURRENT, shift + 1);
   double firstHigh = iHigh(_Symbol, PERIOD_CURRENT, shift + 2);
   double firstLow = iLow(_Symbol, PERIOD_CURRENT, shift + 2);
   
   // Middle candle is inside first candle
   bool isInside = midHigh <= firstHigh && midLow >= firstLow;
   
   // First candle should be bearish (for bullish reversal)
   bool firstBearish = IsBearishCandle(shift + 2);
   
   return isInside && firstBearish;
}

//+------------------------------------------------------------------+
//| Detect Inside Candle Reversal (Bearish)                            |
//| - 3 candle pattern: first candle, inside candle, then bearish     |
//+------------------------------------------------------------------+
bool IsInsideCandleBearish(int shift)
{
   if(!InpPAInsideCandleBear) return false;
   if(shift < 2) return false;
   
   // Candle 1 (current): Must be bearish
   if(!IsBearishCandle(shift)) return false;
   
   // Candle 2 (middle): Inside candle - high and low within candle 3
   double midHigh = iHigh(_Symbol, PERIOD_CURRENT, shift + 1);
   double midLow = iLow(_Symbol, PERIOD_CURRENT, shift + 1);
   double firstHigh = iHigh(_Symbol, PERIOD_CURRENT, shift + 2);
   double firstLow = iLow(_Symbol, PERIOD_CURRENT, shift + 2);
   
   // Middle candle is inside first candle
   bool isInside = midHigh <= firstHigh && midLow >= firstLow;
   
   // First candle should be bullish (for bearish reversal)
   bool firstBullish = IsBullishCandle(shift + 2);
   
   return isInside && firstBullish;
}

//+------------------------------------------------------------------+
//| Detect Bullish Hotdog Pattern                                      |
//| - Price faked up then moved lower, but broke two previous highs   |
//+------------------------------------------------------------------+
bool IsBullishHotdog(int shift)
{
   if(!InpPABullHotdog) return false;
   // shift=1 is the last CLOSED candle; we need 3 more candles back (shift+3),
   // so minimum shift is 1 (not 3). Using 3 causes a consistent 3-bar delay.
   if(shift < 1) return false;
   
   // Current candle must be bullish
   if(!IsBullishCandle(shift)) return false;
   
   double currHigh = iHigh(_Symbol, PERIOD_CURRENT, shift);
   double prev1High = iHigh(_Symbol, PERIOD_CURRENT, shift + 1);
   double prev2High = iHigh(_Symbol, PERIOD_CURRENT, shift + 2);
   
   // Previous candles had small bodies (indecision)
   bool prev1Small = IsDoji(shift + 1) || IsSpinningTop(shift + 1);
   bool prev2Small = IsDoji(shift + 2) || IsSpinningTop(shift + 2);
   
   // Current candle breaks above previous highs
   bool breaksHighs = currHigh > prev1High && currHigh > prev2High;
   
   // There was a fake move down followed by reversal up
   double prev1Low = iLow(_Symbol, PERIOD_CURRENT, shift + 1);
   double prev2Low = iLow(_Symbol, PERIOD_CURRENT, shift + 2);
   double prev3Low = iLow(_Symbol, PERIOD_CURRENT, shift + 3);
   bool fakedDown = prev1Low < prev2Low || prev1Low < prev3Low;
   
   return breaksHighs && (prev1Small || prev2Small || fakedDown);
}

//+------------------------------------------------------------------+
//| Detect Bearish Hotdog Pattern                                      |
//| - Price faked down then moved higher, but broke two previous lows |
//+------------------------------------------------------------------+
bool IsBearishHotdog(int shift)
{
   if(!InpPABearHotdog) return false;
   // shift=1 is the last CLOSED candle; using 3 forces a 3-bar confirmation delay.
   if(shift < 1) return false;
   
   // Current candle must be bearish
   if(!IsBearishCandle(shift)) return false;
   
   double currLow = iLow(_Symbol, PERIOD_CURRENT, shift);
   double prev1Low = iLow(_Symbol, PERIOD_CURRENT, shift + 1);
   double prev2Low = iLow(_Symbol, PERIOD_CURRENT, shift + 2);
   
   // Previous candles had small bodies (indecision)
   bool prev1Small = IsDoji(shift + 1) || IsSpinningTop(shift + 1);
   bool prev2Small = IsDoji(shift + 2) || IsSpinningTop(shift + 2);
   
   // Current candle breaks below previous lows
   bool breaksLows = currLow < prev1Low && currLow < prev2Low;
   
   // There was a fake move up followed by reversal down
   double prev1High = iHigh(_Symbol, PERIOD_CURRENT, shift + 1);
   double prev2High = iHigh(_Symbol, PERIOD_CURRENT, shift + 2);
   double prev3High = iHigh(_Symbol, PERIOD_CURRENT, shift + 3);
   bool fakedUp = prev1High > prev2High || prev1High > prev3High;
   
   return breaksLows && (prev1Small || prev2Small || fakedUp);
}

//+------------------------------------------------------------------+
//| Check if candle is Spinning Top (indecision with long tails)      |
//+------------------------------------------------------------------+
bool IsSpinningTop(int shift)
{
   double body = GetCandleBody(shift);
   double range = GetCandleRange(shift);
   double upperTail = GetUpperTail(shift);
   double lowerTail = GetLowerTail(shift);
   
   if(range <= 0) return false;
   
   // Small body relative to range
   bool smallBody = (body / range) <= InpPASpinningTopRatio;
   
   // Both tails are significant (at least 20% of range each)
   bool longTails = (upperTail / range) >= 0.2 && (lowerTail / range) >= 0.2;
   
   return smallBody && longTails;
}

//+------------------------------------------------------------------+
//| Check for ANY Bullish PA Pattern on the last closed candle        |
//+------------------------------------------------------------------+
string DetectBullishPA(int shift)
{
   if(IsHammer(shift))
      return "HAMMER";
   if(IsBullishEngulfing(shift))
      return "BULL_ENGULFING";
   if(IsTweezerBottom(shift))
      return "TWEEZER_BOTTOM";
   if(IsMorningStar(shift))
      return "MORNING_STAR";
   if(IsOutsideCandleBullish(shift))
      return "OUTSIDE_CANDLE_BULL";
   if(IsPullbackBuy(shift))
      return "PULLBACK_BUY";
   if(IsInsideCandleBullish(shift))
      return "INSIDE_CANDLE_BULL";
   if(IsBullishHotdog(shift))
      return "BULL_HOTDOG";
   
   return "NONE";
}

//+------------------------------------------------------------------+
//| Check for ANY Bearish PA Pattern on the last closed candle        |
//+------------------------------------------------------------------+
string DetectBearishPA(int shift)
{
   if(IsShootingStar(shift))
      return "SHOOTING_STAR";
   if(IsBearishEngulfing(shift))
      return "BEAR_ENGULFING";
   if(IsTweezerTop(shift))
      return "TWEEZER_TOP";
   if(IsEveningStar(shift))
      return "EVENING_STAR";
   if(IsOutsideCandleBearish(shift))
      return "OUTSIDE_CANDLE_BEAR";
   if(IsPullbackSell(shift))
      return "PULLBACK_SELL";
   if(IsInsideCandleBearish(shift))
      return "INSIDE_CANDLE_BEAR";
   if(IsBearishHotdog(shift))
      return "BEAR_HOTDOG";
   
   return "NONE";
}

//+------------------------------------------------------------------+
//| Draw PA Arrow and Label on Chart                                   |
//+------------------------------------------------------------------+
void DrawPAArrow(string tradeType, string paPattern, datetime barTime, double price)
{
   string uniqueId = IntegerToString((long)barTime);
   
   // Get average candle range for dynamic offset
   double avgRange = 0;
   for(int i = 1; i <= 10; i++)
   {
      avgRange += iHigh(_Symbol, PERIOD_CURRENT, i) - iLow(_Symbol, PERIOD_CURRENT, i);
   }
   avgRange /= 10;
   
   // Dynamic offsets based on average range
   double arrowOffset = avgRange * 0.4;    // Arrow distance from candle
   double labelOffset = avgRange * 1.2;    // Label distance from candle (much further than arrow)
   
   // Create Arrow Object
   string arrowName = PAPrefix + "Arrow_" + uniqueId;
   
   if(tradeType == "BUY")
   {
      // Draw UP arrow below the candle low (price)
      double arrowPrice = price - arrowOffset;
      ObjectCreate(0, arrowName, OBJ_ARROW_UP, 0, barTime, arrowPrice);
      ObjectSetInteger(0, arrowName, OBJPROP_COLOR, clrLime);
      ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 3);
   }
   else // SELL
   {
      // Draw DOWN arrow above the candle high (price)
      double arrowPrice = price + arrowOffset;
      ObjectCreate(0, arrowName, OBJ_ARROW_DOWN, 0, barTime, arrowPrice);
      ObjectSetInteger(0, arrowName, OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 3);
   }
   ObjectSetInteger(0, arrowName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, arrowName, OBJPROP_HIDDEN, false);
   
   // Create Text Label for PA Pattern (further away from candle)
   string labelName = PAPrefix + "Label_" + uniqueId;
   double labelPrice;
   
   if(tradeType == "BUY")
   {
      labelPrice = price - labelOffset;
   }
   else
   {
      labelPrice = price + labelOffset;
   }
   
   ObjectCreate(0, labelName, OBJ_TEXT, 0, barTime, labelPrice);
   ObjectSetString(0, labelName, OBJPROP_TEXT, paPattern);
   ObjectSetInteger(0, labelName, OBJPROP_COLOR, tradeType == "BUY" ? clrLime : clrRed);
   ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, tradeType == "BUY" ? ANCHOR_UPPER : ANCHOR_LOWER);
   ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, labelName, OBJPROP_HIDDEN, false);
   
   Print("PA Arrow drawn: ", tradeType, " | Pattern: ", paPattern, " | Time: ", TimeToString(barTime));
}

//+------------------------------------------------------------------+
//| Get readable PA Pattern name                                       |
//+------------------------------------------------------------------+
string GetPAPatternName(string paCode)
{
   if(paCode == "HAMMER") return "Hammer";
   if(paCode == "BULL_ENGULFING") return "Bull Engulf";
   if(paCode == "TWEEZER_BOTTOM") return "Twzr Bottom";
   if(paCode == "MORNING_STAR") return "Morn Star";
   if(paCode == "OUTSIDE_CANDLE_BULL") return "Outside Bull";
   if(paCode == "PULLBACK_BUY") return "Pullback";
   if(paCode == "INSIDE_CANDLE_BULL") return "Inside Bull";
   if(paCode == "BULL_HOTDOG") return "Bull Hotdog";
   
   if(paCode == "SHOOTING_STAR") return "Shoot Star";
   if(paCode == "BEAR_ENGULFING") return "Bear Engulf";
   if(paCode == "TWEEZER_TOP") return "Twzr Top";
   if(paCode == "EVENING_STAR") return "Even Star";
   if(paCode == "OUTSIDE_CANDLE_BEAR") return "Outside Bear";
   if(paCode == "PULLBACK_SELL") return "Pullback";
   if(paCode == "INSIDE_CANDLE_BEAR") return "Inside Bear";
   if(paCode == "BEAR_HOTDOG") return "Bear Hotdog";
   
   return paCode;
}

//+------------------------------------------------------------------+
//| Check if PA confirmation is satisfied for BUY                      |
//| Returns: pattern name if PA found, "NONE" if not                   |
//| IMPORTANT: PA must occur AFTER the signal touch time               |
//| signalTouchTime = time when OB touch/signal occurred               |
//|                   PA candle must close AFTER this time             |
//+------------------------------------------------------------------+
string CheckBuyPAConfirmationWithPattern(datetime signalTouchTime = 0)
{
   if(!InpUsePAConfirm)
      return "NO_PA_REQUIRED";  // PA not required
   
   // Scan recent closed candles for PA within lookback window.
   // CRITICAL: PA candle time must be >= signalTouchTime (PA must come AFTER signal)
   int maxLookback = MathMax(1, MathMin(InpPALookback, 10));
   
   for(int shift = 1; shift <= maxLookback; shift++)
   {
      datetime candleTime = iTime(_Symbol, PERIOD_CURRENT, shift);
      
      // *** CRITICAL CHECK: PA must occur ON or AFTER the signal touch candle ***
      // Using '<' to allow PA in the SAME candle as touch (touch bar can close as PA)
      // Example: OB touched at bar X, PA forms when bar X closes → valid!
      if(signalTouchTime > 0 && candleTime < signalTouchTime)
      {
         // This PA candle is from BEFORE the touch candle - skip it
         continue;
      }
      
      string paPattern = DetectBullishPA(shift);
      if(paPattern != "NONE")
      {
         g_lastPABuyShift = shift;
         Print(">>> BULLISH PA CONFIRMED: ", paPattern, " | shift=", shift, " | candleTime=", TimeToString(candleTime), " | touchTime=", TimeToString(signalTouchTime));
         return paPattern;
      }
   }
   
   return "NONE";
}

//+------------------------------------------------------------------+
//| Check if PA confirmation is satisfied for SELL                     |
//| Returns: pattern name if PA found, "NONE" if not                   |
//| IMPORTANT: PA must occur AFTER the signal touch time               |
//+------------------------------------------------------------------+
string CheckSellPAConfirmationWithPattern(datetime signalTouchTime = 0)
{
   if(!InpUsePAConfirm)
      return "NO_PA_REQUIRED";  // PA not required
   
   int maxLookback = MathMax(1, MathMin(InpPALookback, 10));
   
   for(int shift = 1; shift <= maxLookback; shift++)
   {
      datetime candleTime = iTime(_Symbol, PERIOD_CURRENT, shift);
      
      // *** CRITICAL CHECK: PA must occur ON or AFTER the signal touch candle ***
      // Using '<' to allow PA in the SAME candle as touch
      if(signalTouchTime > 0 && candleTime < signalTouchTime)
      {
         continue;
      }
      
      string paPattern = DetectBearishPA(shift);
      if(paPattern != "NONE")
      {
         g_lastPASellShift = shift;
         Print(">>> BEARISH PA CONFIRMED: ", paPattern, " | shift=", shift, " | candleTime=", TimeToString(candleTime), " | touchTime=", TimeToString(signalTouchTime));
         return paPattern;
      }
   }
   
   return "NONE";
}

//+------------------------------------------------------------------+
//| Check if PA confirmation is satisfied for BUY                      |
//| Returns: true if PA found OR PA not required                       |
//+------------------------------------------------------------------+
bool CheckBuyPAConfirmation()
{
   string result = CheckBuyPAConfirmationWithPattern();
   return result != "NONE";
}

//+------------------------------------------------------------------+
//| Check if PA confirmation is satisfied for SELL                     |
//| Returns: true if PA found OR PA not required                       |
//+------------------------------------------------------------------+
bool CheckSellPAConfirmation()
{
   string result = CheckSellPAConfirmationWithPattern();
   return result != "NONE";
}

//+------------------------------------------------------------------+
//| Handle Pending Signal with PA Confirmation                         |
//| IMPORTANT: PA must occur AFTER g_signalTouchTime                   |
//| g_signalTouchTime is set when OB touch/signal first occurred       |
//+------------------------------------------------------------------+
void HandlePendingSignal()
{
   if(!InpUsePAConfirm || g_pendingSignal == "NONE")
      return;
   
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   // Check if we've exceeded max wait candles
   if(currentBarTime != g_signalBarTime)
   {
      g_paWaitCount++;
      g_signalBarTime = currentBarTime;
      
      if(g_paWaitCount > InpPALookback)
      {
         Print("PA TIMEOUT: Waited ", InpPALookback, " candles - Signal cancelled | TouchTime=", TimeToString(g_signalTouchTime));
         g_pendingSignal = "NONE";
         g_paWaitCount = 0;
         g_signalTouchTime = 0;  // Reset touch time
         return;
      }
   }
   
   // Check for PA confirmation
   // CRITICAL: Pass g_signalTouchTime to ensure PA occurred AFTER the signal/OB touch
   if(g_pendingSignal == "BUY")
   {
      string paPattern = CheckBuyPAConfirmationWithPattern(g_signalTouchTime);
      if(paPattern != "NONE")
      {
         // Check if trade is still allowed
         if(CountPositions(POSITION_TYPE_BUY) == 0 && IsTradeAllowed("BUY"))
         {
            // Try to execute first; only draw PA + clear pending if success
            if(ExecuteBuy())
            {
               // Draw PA arrow on chart (use the candle where PA was detected)
               int shift = g_lastPABuyShift;
               datetime signalBar = iTime(_Symbol, PERIOD_CURRENT, shift);
               double signalPrice = iLow(_Symbol, PERIOD_CURRENT, shift);
               DrawPAArrow("BUY", GetPAPatternName(paPattern), signalBar, signalPrice);
               
               Print("BUY executed after PA confirmation (", paPattern, ") - waited ", g_paWaitCount, " candles | TouchTime=", TimeToString(g_signalTouchTime));
               g_pendingSignal = "NONE";
               g_paWaitCount = 0;
               g_signalTouchTime = 0;  // Reset touch time
            }
            else
            {
               // Keep pending signal to retry next candle (prevents missing entry due to temporary trade failure)
               Print("BUY execution failed after PA; keeping pending to retry | Retcode=", trade.ResultRetcode());
            }
         }
         else
         {
            // Trade no longer allowed -> keep waiting (do not discard) until timeout
            Print("BUY blocked after PA due to filters; keeping pending | CDC=", CDCTrend);
         }
         
      }
      else
      {
         Print("Waiting for Bullish PA AFTER touch... (", g_paWaitCount, "/", InpPALookback, ") | TouchTime=", TimeToString(g_signalTouchTime));
      }
   }
   else if(g_pendingSignal == "SELL")
   {
      string paPattern = CheckSellPAConfirmationWithPattern(g_signalTouchTime);
      if(paPattern != "NONE")
      {
         // Check if trade is still allowed
         if(CountPositions(POSITION_TYPE_SELL) == 0 && IsTradeAllowed("SELL"))
         {
            // Try to execute first; only draw PA + clear pending if success
            if(ExecuteSell())
            {
               // Draw PA arrow on chart (use the candle where PA was detected)
               int shift = g_lastPASellShift;
               datetime signalBar = iTime(_Symbol, PERIOD_CURRENT, shift);
               double signalPrice = iHigh(_Symbol, PERIOD_CURRENT, shift);
               DrawPAArrow("SELL", GetPAPatternName(paPattern), signalBar, signalPrice);
               
               Print("SELL executed after PA confirmation (", paPattern, ") - waited ", g_paWaitCount, " candles | TouchTime=", TimeToString(g_signalTouchTime));
               g_pendingSignal = "NONE";
               g_paWaitCount = 0;
               g_signalTouchTime = 0;  // Reset touch time
            }
            else
            {
               Print("SELL execution failed after PA; keeping pending to retry | Retcode=", trade.ResultRetcode());
            }
         }
         else
         {
            Print("SELL blocked after PA due to filters; keeping pending | CDC=", CDCTrend);
         }
         
      }
      else
      {
         Print("Waiting for Bearish PA AFTER touch... (", g_paWaitCount, "/", InpPALookback, ") | TouchTime=", TimeToString(g_signalTouchTime));
      }
   }
}

//+------------------------------------------------------------------+
//| ================== END PRICE ACTION DETECTION ================== |
//+------------------------------------------------------------------+

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
   
   // If hedge locked, don't draw any TP/SL lines
   if(g_isHedgeLocked) return;
   
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
   
   // Reset grid counters and hedge flag for this side
   if(posType == POSITION_TYPE_BUY)
   {
      GridBuyCount = 0;
      InitialBuyBarTime = 0;
      g_isHedgedBuy = false;  // Reset hedge flag when positions closed
      
      // *** SET BUY SIGNAL RESET FLAG ***
      g_waitBuySignalReset = true;
      g_buyResetPhaseBelowEMA = false;
      g_buyResetWaitOppositeSignal = true;
      
      // *** RESET SMC TOUCH FLAGS ***
      if(InpSignalStrategy == STRATEGY_SMC)
      {
         g_smcBuyTouchedOBPersist = false;
         g_smcBuyTouchedOB = false;
         g_smcBuyTouchTime = 0;
         g_smcBuyResetRequired = true;
         g_smcBuyResetPhaseComplete = false;
         Print("*** SMC BUY Signal Reset Required - Wait for price to move away then touch OB again ***");
      }
      else
      {
         Print("*** BUY Signal Reset Required - Wait for price to cross below EMA then above ***");
      }
   }
   else
   {
      GridSellCount = 0;
      InitialSellBarTime = 0;
      g_isHedgedSell = false;  // Reset hedge flag when positions closed
      
      // *** SET SELL SIGNAL RESET FLAG ***
      g_waitSellSignalReset = true;
      g_sellResetPhaseAboveEMA = false;
      g_sellResetWaitOppositeSignal = true;
      
      // *** RESET SMC TOUCH FLAGS ***
      if(InpSignalStrategy == STRATEGY_SMC)
      {
         g_smcSellTouchedOBPersist = false;
         g_smcSellTouchedOB = false;
         g_smcSellTouchTime = 0;
         g_smcSellResetRequired = true;
         g_smcSellResetPhaseComplete = false;
         Print("*** SMC SELL Signal Reset Required - Wait for price to move away then touch OB again ***");
      }
      else
      {
         Print("*** SELL Signal Reset Required - Wait for price to cross above EMA then below ***");
      }
   }
   
   // Reset global hedge lock if no more hedge positions
   if(!g_isHedgedBuy && !g_isHedgedSell)
   {
      g_isHedgeLocked = false;
      Print("Hedge lock released - trading resumed");
   }
   
   return closedProfit;
}

//+------------------------------------------------------------------+
//| Hedge positions by type (open opposite position to lock loss)      |
//| Opens exactly ONE hedge order and sets flag to prevent repeats     |
//+------------------------------------------------------------------+
bool HedgePositionsByType(ENUM_POSITION_TYPE posType, double totalLots)
{
   // If global hedge lock is already active - NO MORE HEDGE ORDERS AT ALL
   if(g_isHedgeLocked)
   {
      Print("HEDGE LOCK already active - NO more hedge orders allowed");
      return false;
   }
   
   // Check if this side already hedged - PREVENT MULTIPLE HEDGE ORDERS
   if(posType == POSITION_TYPE_BUY && g_isHedgedBuy)
   {
      Print("BUY side already hedged - skipping");
      return false;
   }
   if(posType == POSITION_TYPE_SELL && g_isHedgedSell)
   {
      Print("SELL side already hedged - skipping");
      return false;
   }
   
   // Calculate opposite order type
   ENUM_ORDER_TYPE hedgeType = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
   string hedgeTypeStr = (hedgeType == ORDER_TYPE_BUY) ? "BUY" : "SELL";
   
   double price = (hedgeType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Open hedge position with total lots - ONLY ONCE
   if(trade.PositionOpen(_Symbol, hedgeType, totalLots, price, 0, 0, "HEDGE_LOCK"))
   {
      Print("HEDGE ", hedgeTypeStr, " opened: ", totalLots, " lots at ", price, " to lock loss");
      Print("*** HEDGE LOCK ACTIVATED - All trading & TP/SL stopped until manual close ***");
      
      // Set hedge flag to prevent further hedge orders
      if(posType == POSITION_TYPE_BUY)
         g_isHedgedBuy = true;
      else
         g_isHedgedSell = true;
      
      // Set global hedge lock - STOPS ALL TRADING AND TP/SL
      g_isHedgeLocked = true;
      
      // Remove all TP/SL lines immediately
      ObjectsDeleteAll(0, TPPrefix);
         
      return true;
   }
   else
   {
      Print("HEDGE ", hedgeTypeStr, " failed: ", trade.ResultRetcodeDescription());
      return false;
   }
}

//+------------------------------------------------------------------+
//| Execute SL Action based on mode (Close or Hedge)                   |
//+------------------------------------------------------------------+
void ExecuteSLAction(ENUM_POSITION_TYPE posType, double totalLots, string reason)
{
   if(InpSLActionMode == SL_ACTION_CLOSE)
   {
      Print(reason, " - Closing positions");
      ClosePositionsByType(posType);
   }
   else // SL_ACTION_HEDGE
   {
      Print(reason, " - Hedging with ", totalLots, " lots");
      HedgePositionsByType(posType, totalLots);
   }
}

//+------------------------------------------------------------------+
//| Execute SL Action for All Positions (Close or Hedge)               |
//+------------------------------------------------------------------+
void ExecuteSLActionAll(double buyLots, double sellLots, string reason)
{
   if(InpSLActionMode == SL_ACTION_CLOSE)
   {
      Print(reason, " - Closing all positions");
      CloseAllPositions();
   }
   else // SL_ACTION_HEDGE
   {
      // Hedge both sides if they exist
      if(buyLots > 0)
      {
         Print(reason, " - Hedging BUY side with ", buyLots, " lots");
         HedgePositionsByType(POSITION_TYPE_BUY, buyLots);
      }
      if(sellLots > 0)
      {
         Print(reason, " - Hedging SELL side with ", sellLots, " lots");
         HedgePositionsByType(POSITION_TYPE_SELL, sellLots);
      }
   }
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
   
   // Reset hedge flags when all positions closed
   g_isHedgedBuy = false;
   g_isHedgedSell = false;
   g_isHedgeLocked = false;  // Reset global hedge lock
   
   // *** SET SIGNAL RESET FLAGS ***
   // After closing all positions, require signal to reset before new entries
   g_waitBuySignalReset = true;
   g_waitSellSignalReset = true;
   g_buyResetPhaseBelowEMA = false;
   g_sellResetPhaseAboveEMA = false;
   g_buyResetWaitOppositeSignal = true;
   g_sellResetWaitOppositeSignal = true;
   
   Print("*** Signal Reset Required - Waiting for new signal cycle ***");
}

//+------------------------------------------------------------------+
//| Check TP/SL Conditions (Advanced Close Logic)                      |
//+------------------------------------------------------------------+
void CheckTPSLConditions()
{
   // If hedge locked, skip ALL TP/SL checks - wait for manual close only
   if(g_isHedgeLocked)
   {
      return;
   }
   
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
   // Skip if SL Settings is disabled
   if(!InpUseSLSettings) return;
   
   // Mode: SL_ACTION_CLOSE = Close positions | SL_ACTION_HEDGE = Open hedge to lock loss
   
   // 1. SL Fixed Dollar
   if(InpUseSLDollar)
   {
      if(buyPL <= -InpSLDollarAmount && buyCount > 0)
      {
         ExecuteSLAction(POSITION_TYPE_BUY, lotsBuy, "SL Dollar - BUY side hit $" + DoubleToString(-InpSLDollarAmount, 2));
      }
      if(sellPL <= -InpSLDollarAmount && sellCount > 0)
      {
         ExecuteSLAction(POSITION_TYPE_SELL, lotsSell, "SL Dollar - SELL side hit $" + DoubleToString(-InpSLDollarAmount, 2));
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
            ExecuteSLAction(POSITION_TYPE_BUY, lotsBuy, "SL Points - BUY side hit SL at " + DoubleToString(slPrice, _Digits));
         }
      }
      if(sellCount > 0 && avgSell > 0)
      {
         double slPrice = CalculateSLPrice(POSITION_TYPE_SELL, avgSell);
         if(currentAsk >= slPrice)
         {
            ExecuteSLAction(POSITION_TYPE_SELL, lotsSell, "SL Points - SELL side hit SL at " + DoubleToString(slPrice, _Digits));
         }
      }
   }
   
   // 3. SL Percent of Balance
   if(InpUseSLPercent)
   {
      double slAmount = balance * InpSLPercent / 100.0;
      if(totalPL <= -slAmount)
      {
         ExecuteSLActionAll(lotsBuy, lotsSell, "SL Percent - Total loss reached " + DoubleToString(InpSLPercent, 1) + "% ($" + DoubleToString(totalPL, 2) + ")");
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
   
   // *** นับ Grid Loss orders แยกจาก Grid Profit โดยดูจาก comment ***
   int buyGridLossCount = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
            {
               string comment = PositionGetString(POSITION_COMMENT);
               if(StringFind(comment, "Grid Loss") >= 0)
                  buyGridLossCount++;
            }
         }
      }
   }
   
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
      
      // *** Grid Loss นับ level แยกจาก Grid Profit ***
      // buyGridLossCount = จำนวน Grid Loss orders ที่มีอยู่แล้ว (นับจาก comment)
      // gridLevel สำหรับ Grid Loss = buyGridLossCount + 1 (ออเดอร์ถัดไป)
      int gridLossLevel = buyGridLossCount + 1;
      int distance = GetGridDistance(true, buyGridLossCount);
      
      // Price went DOWN from last buy by grid distance
      if(lastBuyPrice - currentPrice >= distance * _Point)
      {
         double lot = GetGridLotSize(true, gridLossLevel);
         double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         
         Print("Grid Loss BUY #", gridLossLevel, " | Lot: ", lot, " | Distance: ", distance);
         
         if(trade.Buy(lot, _Symbol, price, 0, 0, "Grid Loss BUY #" + IntegerToString(gridLossLevel)))
         {
            LastGridBuyTime = currentBarTime;
            GridBuyCount = buyCount + 1;
         }
      }
   }
   
   // Check SELL Grid (when price goes up = loss side for SELL)
   int sellCount = CountPositions(POSITION_TYPE_SELL);
   
   // *** นับ Grid Loss orders แยกจาก Grid Profit โดยดูจาก comment ***
   int sellGridLossCount = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
            {
               string comment = PositionGetString(POSITION_COMMENT);
               if(StringFind(comment, "Grid Loss") >= 0)
                  sellGridLossCount++;
            }
         }
      }
   }
   
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
      
      // *** Grid Loss นับ level แยกจาก Grid Profit ***
      // sellGridLossCount = จำนวน Grid Loss orders ที่มีอยู่แล้ว (นับจาก comment)
      // gridLevel สำหรับ Grid Loss = sellGridLossCount + 1 (ออเดอร์ถัดไป)
      int gridLossLevel = sellGridLossCount + 1;
      int distance = GetGridDistance(true, sellGridLossCount);
      
      // Price went UP from last sell by grid distance
      if(currentPrice - lastSellPrice >= distance * _Point)
      {
         double lot = GetGridLotSize(true, gridLossLevel);
         double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         
         Print("Grid Loss SELL #", gridLossLevel, " | Lot: ", lot, " | Distance: ", distance);
         
         if(trade.Sell(lot, _Symbol, price, 0, 0, "Grid Loss SELL #" + IntegerToString(gridLossLevel)))
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
   // Check TP/SL conditions first (every tick) - this still runs even in hedge lock
   CheckTPSLConditions();
   
   // Draw TP/SL lines (every tick for real-time update)
   DrawTPSLLines();
   
   // *** HEDGE LOCK CHECK ***
   // If hedge is active, stop ALL trading activities (no Grid, no new signals)
   if(g_isHedgeLocked)
   {
      UpdateChartComment("HEDGE_LOCKED", "Positions locked - Manual close required");
      return;  // Exit OnTick - no further trading until manual intervention
   }
   
   // Check Grid conditions (every tick for real-time)
   CheckGridLossSide();
   CheckGridProfitSide();
   
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   if(lastBarTime == currentBarTime)
      return;
      
   lastBarTime = currentBarTime;
   
   // *** IMPORTANT: Calculate Indicators FIRST before PA confirmation ***
   // This ensures that SMC OB touch, CDC trend, etc. are already determined
   // before we check for PA confirmation as the final step.
   
   // Calculate CDC Action Zone (higher timeframe)
   CalculateCDC();
   
   // Calculate based on selected Signal Strategy
   if(InpSignalStrategy == STRATEGY_ZIGZAG)
   {
      // Calculate ZigZag++ (custom implementation)
      CalculateZigZagPP();
   }
   else if(InpSignalStrategy == STRATEGY_EMA_CHANNEL)
   {
      // Calculate EMA Channel
      CalculateEMAChannel();
   }
   else if(InpSignalStrategy == STRATEGY_BOLLINGER)
   {
      // Calculate Bollinger Bands
      CalculateBollingerBands();
   }
   else if(InpSignalStrategy == STRATEGY_SMC)
   {
      // Calculate Smart Money Concepts (Order Blocks)
      CalculateSMC();
   }
   
   // *** PRICE ACTION CONFIRMATION CHECK ***
   // Handle pending signals waiting for PA confirmation
   // This runs AFTER indicators are calculated, so we have updated SMC OB touch, CDC trend, etc.
   if(InpUsePAConfirm && g_pendingSignal != "NONE")
   {
      HandlePendingSignal();
   }
   
   if(InpUseTimeFilter && !IsWithinTradingHours())
   {
      UpdateChartComment("WAIT", "Outside trading hours");
      return;
   }
   
   // Check if we have enough data based on strategy
   if(InpSignalStrategy == STRATEGY_ZIGZAG && ZZPointCount < 4)
   {
      UpdateChartComment("WAIT", "Calculating ZigZag...");
      return;
   }
   
   // If we have a pending signal waiting for PA, don't look for new signals
   if(InpUsePAConfirm && g_pendingSignal != "NONE")
   {
      string paInfo = "Waiting PA for " + g_pendingSignal + " (" + IntegerToString(g_paWaitCount) + "/" + IntegerToString(InpPALookback) + ")";
      UpdateChartComment("PA_WAIT", paInfo);
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
         // *** PRICE ACTION CONFIRMATION ***
         if(InpUsePAConfirm)
         {
            // *** IMPORTANT: Do NOT check for old PA patterns ***
            // PA must occur AFTER the signal/OB touch, not before
            // So we always set pending signal and wait for PA to occur on next candle(s)
            
            // Set pending signal - wait for PA to occur AFTER this touch
            g_pendingSignal = "BUY";
            g_signalBarTime = currentBarTime;
            
            // CRITICAL: currentBarTime is the NEW bar open time.
            // The signal/OB touch logically belongs to the previous closed candle (shift=1)
            // (and for SMC we may have an explicit touch timestamp).
            datetime fallbackTouch = iTime(_Symbol, PERIOD_CURRENT, 1);
            g_signalTouchTime = (InpSignalStrategy == STRATEGY_SMC && g_smcBuyTouchTime > 0) ? g_smcBuyTouchTime : fallbackTouch;
            
            g_paWaitCount = 0;
            reason = "BUY signal detected - Waiting for PA confirmation AFTER touch";
            Print(">>> BUY signal stored | TouchTime=", TimeToString(g_signalTouchTime), " | NowBar=", TimeToString(currentBarTime), " - Waiting for Bullish PA AFTER touch...");
            signal = "PA_WAIT";
         }
         else
         {
            if(ExecuteBuy())
               reason = "BUY executed | CDC: " + CDCTrend;
            else
               reason = "BUY failed to execute | CDC: " + CDCTrend;
         }
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
         // *** PRICE ACTION CONFIRMATION ***
         if(InpUsePAConfirm)
         {
            // *** IMPORTANT: Do NOT check for old PA patterns ***
            // PA must occur AFTER the signal/OB touch, not before
            // So we always set pending signal and wait for PA to occur on next candle(s)
            
            // Set pending signal - wait for PA to occur AFTER this touch
            g_pendingSignal = "SELL";
            g_signalBarTime = currentBarTime;
            
            // CRITICAL: currentBarTime is the NEW bar open time.
            // The signal/OB touch logically belongs to the previous closed candle (shift=1)
            // (and for SMC we may have an explicit touch timestamp).
            datetime fallbackTouch = iTime(_Symbol, PERIOD_CURRENT, 1);
            g_signalTouchTime = (InpSignalStrategy == STRATEGY_SMC && g_smcSellTouchTime > 0) ? g_smcSellTouchTime : fallbackTouch;
            
            g_paWaitCount = 0;
            reason = "SELL signal detected - Waiting for PA confirmation AFTER touch";
            Print(">>> SELL signal stored | TouchTime=", TimeToString(g_signalTouchTime), " | NowBar=", TimeToString(currentBarTime), " - Waiting for Bearish PA AFTER touch...");
            signal = "PA_WAIT";
         }
         else
         {
            if(ExecuteSell())
               reason = "SELL executed | CDC: " + CDCTrend;
            else
               reason = "SELL failed to execute | CDC: " + CDCTrend;
         }
      }
   }
   
   UpdateChartComment(signal, reason);
}

//+------------------------------------------------------------------+
//| Analyze Signal - Based on Selected Strategy                        |
//+------------------------------------------------------------------+
string AnalyzeSignal()
{
   // Route to the appropriate signal analysis based on strategy
   if(InpSignalStrategy == STRATEGY_ZIGZAG)
   {
      return AnalyzeZigZagSignal();
   }
   else if(InpSignalStrategy == STRATEGY_EMA_CHANNEL)
   {
      return AnalyzeEMAChannelSignal();
   }
   else if(InpSignalStrategy == STRATEGY_BOLLINGER)
   {
      return AnalyzeBollingerSignal();
   }
   else if(InpSignalStrategy == STRATEGY_SMC)
   {
      return AnalyzeSMCSignal();
   }
   
   return "WAIT";
}

//+------------------------------------------------------------------+
//| Analyze ZigZag Signal                                              |
//+------------------------------------------------------------------+
string AnalyzeZigZagSignal()
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
   
   // *** UPDATE ZIGZAG SIGNAL RESET STATUS ***
   // For ZigZag: BUY reset requires HH/LH point first, then LL/HL
   // For ZigZag: SELL reset requires LL/HL point first, then HH/LH
   if(g_waitBuySignalReset)
   {
      if(LastZZLabel == "HH" || LastZZLabel == "LH")
      {
         // Opposite signal detected - BUY reset phase 1 complete
         g_buyResetWaitOppositeSignal = false;
         Print("*** BUY Reset Phase 1 Complete - Opposite point (", LastZZLabel, ") detected ***");
      }
   }
   
   if(g_waitSellSignalReset)
   {
      if(LastZZLabel == "LL" || LastZZLabel == "HL")
      {
         // Opposite signal detected - SELL reset phase 1 complete
         g_sellResetWaitOppositeSignal = false;
         Print("*** SELL Reset Phase 1 Complete - Opposite point (", LastZZLabel, ") detected ***");
      }
   }
   
   // BUY Signal: Based on ZigZag Signal Mode
   if(InpZigZagSignalMode == ZIGZAG_BOTH)
   {
      // Both Signals: LL or HL triggers BUY
      if(LastZZLabel == "LL" || LastZZLabel == "HL")
      {
         // *** CHECK IF BUY SIGNAL RESET IS REQUIRED ***
         if(g_waitBuySignalReset)
         {
            if(g_buyResetWaitOppositeSignal)
            {
               Print(">>> BUY Signal detected but waiting for opposite signal (HH/LH) first");
               return "WAIT";
            }
            else
            {
               // Reset complete - allow this BUY signal
               g_waitBuySignalReset = false;
               Print("*** BUY Signal Reset Complete - Executing new BUY! ***");
            }
         }
         Print(">>> NEW LOW point (", LastZZLabel, ") - Triggering BUY signal! [Both Mode]");
         return "BUY";
      }
      // Both Signals: HH or LH triggers SELL
      if(LastZZLabel == "HH" || LastZZLabel == "LH")
      {
         // *** CHECK IF SELL SIGNAL RESET IS REQUIRED ***
         if(g_waitSellSignalReset)
         {
            if(g_sellResetWaitOppositeSignal)
            {
               Print(">>> SELL Signal detected but waiting for opposite signal (LL/HL) first");
               return "WAIT";
            }
            else
            {
               // Reset complete - allow this SELL signal
               g_waitSellSignalReset = false;
               Print("*** SELL Signal Reset Complete - Executing new SELL! ***");
            }
         }
         Print(">>> NEW HIGH point (", LastZZLabel, ") - Triggering SELL signal! [Both Mode]");
         return "SELL";
      }
   }
   else // ZIGZAG_SINGLE
   {
      // Single Signal: Only LL triggers BUY
      if(LastZZLabel == "LL")
      {
         // *** CHECK IF BUY SIGNAL RESET IS REQUIRED ***
         if(g_waitBuySignalReset)
         {
            if(g_buyResetWaitOppositeSignal)
            {
               Print(">>> LL detected but waiting for opposite signal (HH) first");
               return "WAIT";
            }
            else
            {
               g_waitBuySignalReset = false;
               Print("*** BUY Signal Reset Complete - Executing new BUY! ***");
            }
         }
         Print(">>> NEW LL point - Triggering BUY signal! [Single Mode]");
         return "BUY";
      }
      // Single Signal: Only HH triggers SELL
      if(LastZZLabel == "HH")
      {
         // *** CHECK IF SELL SIGNAL RESET IS REQUIRED ***
         if(g_waitSellSignalReset)
         {
            if(g_sellResetWaitOppositeSignal)
            {
               Print(">>> HH detected but waiting for opposite signal (LL) first");
               return "WAIT";
            }
            else
            {
               g_waitSellSignalReset = false;
               Print("*** SELL Signal Reset Complete - Executing new SELL! ***");
            }
         }
         Print(">>> NEW HH point - Triggering SELL signal! [Single Mode]");
         return "SELL";
      }
   }
   
   return "WAIT";
}

//+------------------------------------------------------------------+
//| Check and Update Signal Reset Status for EMA Strategy              |
//| Returns true if signal is allowed (reset complete or not required) |
//+------------------------------------------------------------------+
void UpdateEMASignalResetStatus()
{
   // Get current price relative to EMA
   int signalBar = (InpEMASignalBar == EMA_CURRENT_BAR) ? 0 : 1;
   
   double closeArr[];
   ArraySetAsSeries(closeArr, true);
   if(CopyClose(_Symbol, InpEMATimeframe, 0, 10, closeArr) < 10) return;
   
   double signalClose = closeArr[signalBar];
   
   // *** BUY SIGNAL RESET CHECK ***
   // Step 1: Price must close BELOW any EMA line (either one)
   // Step 2: Price must then close ABOVE both EMA lines again
   if(g_waitBuySignalReset)
   {
      bool nowBelowAny = (signalClose < EMAHigh || signalClose < EMALow);
      bool nowAboveBoth = (signalClose > EMAHigh && signalClose > EMALow);
      
      if(!g_buyResetPhaseBelowEMA && nowBelowAny)
      {
         // Step 1 complete: Price closed below any EMA line
         g_buyResetPhaseBelowEMA = true;
         Print("*** BUY Reset Phase 1 Complete - Price closed BELOW EMA line ***");
      }
      else if(g_buyResetPhaseBelowEMA && nowAboveBoth)
      {
         // Step 2 complete: Price closed above EMA again - BUY reset complete!
         g_waitBuySignalReset = false;
         g_buyResetPhaseBelowEMA = false;
         Print("*** BUY Signal Reset Complete - Ready for new BUY signal! ***");
      }
   }
   
   // *** SELL SIGNAL RESET CHECK ***
   // Step 1: Price must close ABOVE any EMA line (either one)
   // Step 2: Price must then close BELOW both EMA lines again
   if(g_waitSellSignalReset)
   {
      bool nowAboveAny = (signalClose > EMAHigh || signalClose > EMALow);
      bool nowBelowBoth = (signalClose < EMAHigh && signalClose < EMALow);
      
      if(!g_sellResetPhaseAboveEMA && nowAboveAny)
      {
         // Step 1 complete: Price closed above any EMA line
         g_sellResetPhaseAboveEMA = true;
         Print("*** SELL Reset Phase 1 Complete - Price closed ABOVE EMA line ***");
      }
      else if(g_sellResetPhaseAboveEMA && nowBelowBoth)
      {
         // Step 2 complete: Price closed below EMA again - SELL reset complete!
         g_waitSellSignalReset = false;
         g_sellResetPhaseAboveEMA = false;
         Print("*** SELL Signal Reset Complete - Ready for new SELL signal! ***");
      }
   }
}

//+------------------------------------------------------------------+
//| Analyze EMA Channel Signal                                         |
//+------------------------------------------------------------------+
string AnalyzeEMAChannelSignal()
{
   datetime currentBarTime = iTime(_Symbol, InpEMATimeframe, 0);
   
   // For Last Bar Closed mode, check if this is a new bar
   if(InpEMASignalBar == EMA_LAST_BAR_CLOSED)
   {
      if(currentBarTime == LastEMASignalTime)
      {
         return "WAIT";
      }
      LastEMASignalTime = currentBarTime;
   }
   
   // *** UPDATE SIGNAL RESET STATUS ***
   UpdateEMASignalResetStatus();
   
   // Return the EMA signal calculated in CalculateEMAChannel()
   if(EMASignal == "BUY")
   {
      // *** CHECK IF BUY SIGNAL RESET IS REQUIRED ***
      if(g_waitBuySignalReset)
      {
         Print(">>> BUY Signal detected but waiting for reset (Phase 1: ", g_buyResetPhaseBelowEMA ? "Complete" : "Pending", ")");
         return "WAIT";
      }
      Print(">>> EMA Channel BUY Signal Confirmed!");
      return "BUY";
   }
   else if(EMASignal == "SELL")
   {
      // *** CHECK IF SELL SIGNAL RESET IS REQUIRED ***
      if(g_waitSellSignalReset)
      {
         Print(">>> SELL Signal detected but waiting for reset (Phase 1: ", g_sellResetPhaseAboveEMA ? "Complete" : "Pending", ")");
         return "WAIT";
      }
      Print(">>> EMA Channel SELL Signal Confirmed!");
      return "SELL";
   }
   
   return "WAIT";
}

//+------------------------------------------------------------------+
//| Calculate Bollinger Bands                                          |
//+------------------------------------------------------------------+
void CalculateBollingerBands()
{
   // Use iBands indicator handle for accurate calculation
   if(BBHandle == INVALID_HANDLE)
   {
      Print("Warning: Bollinger Bands handle not initialized");
      return;
   }
   
   double upperArr[], lowerArr[], basisArr[];
   ArraySetAsSeries(upperArr, true);
   ArraySetAsSeries(lowerArr, true);
   ArraySetAsSeries(basisArr, true);
   
   // Copy buffer data from indicator
   // Buffer 0 = Base (Middle), Buffer 1 = Upper, Buffer 2 = Lower
   if(CopyBuffer(BBHandle, 0, 0, 10, basisArr) < 10) return;
   if(CopyBuffer(BBHandle, 1, 0, 10, upperArr) < 10) return;
   if(CopyBuffer(BBHandle, 2, 0, 10, lowerArr) < 10) return;
   
   // Get values at signal bar
   int signalBar = (InpBBSignalBar == EMA_CURRENT_BAR) ? 0 : 1;
   
   BBBasis = basisArr[signalBar];
   BBUpper = upperArr[signalBar];
   BBLower = lowerArr[signalBar];
   
   // Get close price at signal bar
   double closeArr[];
   ArraySetAsSeries(closeArr, true);
   if(CopyClose(_Symbol, InpBBTimeframe, 0, 10, closeArr) < 10) return;
   
   double signalClose = closeArr[signalBar];
   
   // SELL signal: Price closes ABOVE upper band
   // BUY signal: Price closes BELOW lower band
   if(signalClose > BBUpper)
   {
      BBSignal = "SELL";
   }
   else if(signalClose < BBLower)
   {
      BBSignal = "BUY";
   }
   else
   {
      BBSignal = "NONE";
   }
   
   // Note: Bollinger Bands lines are displayed via ChartIndicatorAdd() in OnInit()
   // No need to draw objects manually - the indicator handle displays the lines automatically
}

//+------------------------------------------------------------------+
//| Check and Update Signal Reset Status for Bollinger Strategy        |
//+------------------------------------------------------------------+
void UpdateBBSignalResetStatus()
{
   // Get current price relative to BB bands
   int signalBar = (InpBBSignalBar == EMA_CURRENT_BAR) ? 0 : 1;
   
   double closeArr[];
   ArraySetAsSeries(closeArr, true);
   if(CopyClose(_Symbol, InpBBTimeframe, 0, 10, closeArr) < 10) return;
   
   double signalClose = closeArr[signalBar];
   
   // *** BUY SIGNAL RESET CHECK ***
   // For BB: After BUY closes, price must go back ABOVE lower band (into channel)
   // then close BELOW lower band again to trigger new BUY
   if(g_waitBuySignalReset)
   {
      bool nowAboveLower = (signalClose > BBLower);
      bool nowBelowLower = (signalClose < BBLower);
      
      if(!g_bbBuyResetPhaseBelowBand && nowAboveLower)
      {
         // Step 1 complete: Price went back into the channel (above lower band)
         g_bbBuyResetPhaseBelowBand = true;
         Print("*** BB BUY Reset Phase 1 Complete - Price returned ABOVE lower band ***");
      }
      else if(g_bbBuyResetPhaseBelowBand && nowBelowLower)
      {
         // Step 2 complete: Price closed below lower band again - BUY reset complete!
         g_waitBuySignalReset = false;
         g_bbBuyResetPhaseBelowBand = false;
         Print("*** BB BUY Signal Reset Complete - Ready for new BUY signal! ***");
      }
   }
   
   // *** SELL SIGNAL RESET CHECK ***
   // For BB: After SELL closes, price must go back BELOW upper band (into channel)
   // then close ABOVE upper band again to trigger new SELL
   if(g_waitSellSignalReset)
   {
      bool nowBelowUpper = (signalClose < BBUpper);
      bool nowAboveUpper = (signalClose > BBUpper);
      
      if(!g_bbSellResetPhaseAboveBand && nowBelowUpper)
      {
         // Step 1 complete: Price went back into the channel (below upper band)
         g_bbSellResetPhaseAboveBand = true;
         Print("*** BB SELL Reset Phase 1 Complete - Price returned BELOW upper band ***");
      }
      else if(g_bbSellResetPhaseAboveBand && nowAboveUpper)
      {
         // Step 2 complete: Price closed above upper band again - SELL reset complete!
         g_waitSellSignalReset = false;
         g_bbSellResetPhaseAboveBand = false;
         Print("*** BB SELL Signal Reset Complete - Ready for new SELL signal! ***");
      }
   }
}

//+------------------------------------------------------------------+
//| Analyze Bollinger Bands Signal                                     |
//+------------------------------------------------------------------+
string AnalyzeBollingerSignal()
{
   datetime currentBarTime = iTime(_Symbol, InpBBTimeframe, 0);
   
   // For Last Bar Closed mode, check if this is a new bar
   if(InpBBSignalBar == EMA_LAST_BAR_CLOSED)
   {
      if(currentBarTime == LastBBSignalTime)
      {
         return "WAIT";
      }
      LastBBSignalTime = currentBarTime;
   }
   
   // *** UPDATE SIGNAL RESET STATUS ***
   UpdateBBSignalResetStatus();
   
   // Return the BB signal calculated in CalculateBollingerBands()
   if(BBSignal == "BUY")
   {
      // *** CHECK IF BUY SIGNAL RESET IS REQUIRED ***
      if(g_waitBuySignalReset)
      {
         Print(">>> BB BUY Signal detected but waiting for reset (Phase 1: ", g_bbBuyResetPhaseBelowBand ? "Complete" : "Pending", ")");
         return "WAIT";
      }
      Print(">>> Bollinger Bands BUY Signal Confirmed! (Price closed BELOW lower band)");
      return "BUY";
   }
   else if(BBSignal == "SELL")
   {
      // *** CHECK IF SELL SIGNAL RESET IS REQUIRED ***
      if(g_waitSellSignalReset)
      {
         Print(">>> BB SELL Signal detected but waiting for reset (Phase 1: ", g_bbSellResetPhaseAboveBand ? "Complete" : "Pending", ")");
         return "WAIT";
      }
      Print(">>> Bollinger Bands SELL Signal Confirmed! (Price closed ABOVE upper band)");
      return "SELL";
   }
   
   return "WAIT";
}

//+------------------------------------------------------------------+
//| Calculate Smart Money Concepts (Order Blocks)                      |
//| Based on swing structure detection and order block identification  |
//+------------------------------------------------------------------+
void CalculateSMC()
{
   // Get price data
   double highArr[], lowArr[], closeArr[], openArr[];
   ArraySetAsSeries(highArr, true);
   ArraySetAsSeries(lowArr, true);
   ArraySetAsSeries(closeArr, true);
   ArraySetAsSeries(openArr, true);
   
   int barsNeeded = InpSMCSwingLength + 20;
   if(CopyHigh(_Symbol, InpSMCTimeframe, 0, barsNeeded, highArr) < barsNeeded) return;
   if(CopyLow(_Symbol, InpSMCTimeframe, 0, barsNeeded, lowArr) < barsNeeded) return;
   if(CopyClose(_Symbol, InpSMCTimeframe, 0, barsNeeded, closeArr) < barsNeeded) return;
   if(CopyOpen(_Symbol, InpSMCTimeframe, 0, barsNeeded, openArr) < barsNeeded) return;
   
   datetime timeArr[];
   ArraySetAsSeries(timeArr, true);
   if(CopyTime(_Symbol, InpSMCTimeframe, 0, barsNeeded, timeArr) < barsNeeded) return;
   
   // Detect Swing High and Swing Low using lookback
   int lookback = InpSMCInternalLength;
   
   // Find current swing points
   for(int i = lookback; i < barsNeeded - lookback; i++)
   {
      // Check for Swing High
      bool isSwingHigh = true;
      for(int j = 1; j <= lookback; j++)
      {
         if(highArr[i] <= highArr[i-j] || highArr[i] <= highArr[i+j])
         {
            isSwingHigh = false;
            break;
         }
      }
      
      if(isSwingHigh && highArr[i] > SMCSwingHigh)
      {
         SMCSwingHigh = highArr[i];
         SMCSwingHighTime = timeArr[i];
      }
      
      // Check for Swing Low
      bool isSwingLow = true;
      for(int j = 1; j <= lookback; j++)
      {
         if(lowArr[i] >= lowArr[i-j] || lowArr[i] >= lowArr[i+j])
         {
            isSwingLow = false;
            break;
         }
      }
      
      if(isSwingLow && (SMCSwingLow == 0 || lowArr[i] < SMCSwingLow))
      {
         SMCSwingLow = lowArr[i];
         SMCSwingLowTime = timeArr[i];
      }
   }
   
   // Determine trend based on structure
   double currentClose = closeArr[0];
   if(currentClose > SMCSwingHigh && SMCSwingHigh > 0)
   {
      SMCTrend = 1;  // Bullish - price broke above swing high
   }
   else if(currentClose < SMCSwingLow && SMCSwingLow > 0)
   {
      SMCTrend = -1; // Bearish - price broke below swing low
   }
   
   // Detect Order Blocks
   // Bullish OB: Last bearish candle before a strong bullish move
   // Bearish OB: Last bullish candle before a strong bearish move
   DetectOrderBlocks(highArr, lowArr, openArr, closeArr, timeArr, barsNeeded);
   
   // Draw Order Blocks on chart
   DrawOrderBlocks();
   
   // Check for price touch on Order Blocks
   CheckOBTouch(closeArr[0], highArr[0], lowArr[0]);
   
   // Generate SMC Signal
   GenerateSMCSignal(closeArr, lowArr, highArr);
}

//+------------------------------------------------------------------+
//| Detect Order Blocks based on structure breaks                      |
//+------------------------------------------------------------------+
void DetectOrderBlocks(double &highArr[], double &lowArr[], double &openArr[], 
                       double &closeArr[], datetime &timeArr[], int barsTotal)
{
   int lookback = InpSMCInternalLength;
   
   // Scan for new Order Blocks (limit to recent bars for performance)
   int scanLimit = MathMin(50, barsTotal - lookback - 1);
   
   for(int i = lookback; i < scanLimit; i++)
   {
      // Check for Bullish Order Block
      // Condition: Bearish candle followed by strong bullish move that breaks structure
      if(closeArr[i] < openArr[i])  // Bearish candle
      {
         // Check if next candles made a strong bullish move
         bool strongBullishMove = false;
         for(int j = i - 1; j >= 1; j--)
         {
            if(closeArr[j] > highArr[i] + (highArr[i] - lowArr[i]))
            {
               strongBullishMove = true;
               break;
            }
            if(j < i - 3) break;  // Only check 3 bars ahead
         }
         
         if(strongBullishMove && InpSMCShowBullishOB)
         {
            AddBullishOB(highArr[i], lowArr[i], timeArr[i], i);
         }
      }
      
      // Check for Bearish Order Block
      // Condition: Bullish candle followed by strong bearish move that breaks structure
      if(closeArr[i] > openArr[i])  // Bullish candle
      {
         // Check if next candles made a strong bearish move
         bool strongBearishMove = false;
         for(int j = i - 1; j >= 1; j--)
         {
            if(closeArr[j] < lowArr[i] - (highArr[i] - lowArr[i]))
            {
               strongBearishMove = true;
               break;
            }
            if(j < i - 3) break;  // Only check 3 bars ahead
         }
         
         if(strongBearishMove && InpSMCShowBearishOB)
         {
            AddBearishOB(highArr[i], lowArr[i], timeArr[i], i);
         }
      }
   }
   
   // Check mitigation of existing Order Blocks
   // IMPORTANT: OB is only mitigated when price FULLY closes through it (not just touches)
   // This ensures OB stays visible until price has completely penetrated and closed beyond it
   double currentLow = lowArr[0];
   double currentHigh = highArr[0];
   double currentClose = closeArr[0];
   
   for(int i = 0; i < BullishOBCount; i++)
   {
      if(!BullishOBs[i].mitigated)
      {
         // Bullish OB (support) is mitigated only when:
         // 1. Price CLOSES below the OB low (completely penetrated)
         // Just touching or dipping into the zone does NOT mitigate it
         if(currentClose < BullishOBs[i].low)
         {
            BullishOBs[i].mitigated = true;
            ObjectDelete(0, BullishOBs[i].objName);
            Print(">>> Bullish OB Mitigated! Price closed below zone: ", BullishOBs[i].low);
         }
      }
   }
   
   for(int i = 0; i < BearishOBCount; i++)
   {
      if(!BearishOBs[i].mitigated)
      {
         // Bearish OB (resistance) is mitigated only when:
         // 1. Price CLOSES above the OB high (completely penetrated)
         // Just touching or spiking into the zone does NOT mitigate it
         if(currentClose > BearishOBs[i].high)
         {
            BearishOBs[i].mitigated = true;
            ObjectDelete(0, BearishOBs[i].objName);
            Print(">>> Bearish OB Mitigated! Price closed above zone: ", BearishOBs[i].high);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Add Bullish Order Block to array                                   |
//+------------------------------------------------------------------+
void AddBullishOB(double high, double low, datetime time, int barIndex)
{
   // Check if this OB already exists
   for(int i = 0; i < BullishOBCount; i++)
   {
      if(BullishOBs[i].time == time) return;  // Already exists
   }
   
   // If array is full, ONLY remove an OB if it's already mitigated.
   // Otherwise, keep existing zones (don't make untouched zones disappear).
   if(BullishOBCount >= InpSMCMaxOrderBlocks)
   {
      int removeIndex = -1;
      for(int i = BullishOBCount - 1; i >= 0; i--)
      {
         if(BullishOBs[i].mitigated)
         {
            removeIndex = i;
            break;
         }
      }
      
      if(removeIndex >= 0)
      {
         ObjectDelete(0, BullishOBs[removeIndex].objName);
         for(int k = removeIndex; k < BullishOBCount - 1; k++)
         {
            BullishOBs[k] = BullishOBs[k + 1];
         }
         BullishOBCount--;
      }
      else
      {
         // No mitigated OBs to free a slot; skip adding new to preserve existing zones
         Print(">>> SMC: Bullish OB limit reached and none mitigated - keeping existing zones (no delete)");
         return;
      }
   }
   
   // Add new OB
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
//| Add Bearish Order Block to array                                   |
//+------------------------------------------------------------------+
void AddBearishOB(double high, double low, datetime time, int barIndex)
{
   // Check if this OB already exists
   for(int i = 0; i < BearishOBCount; i++)
   {
      if(BearishOBs[i].time == time) return;  // Already exists
   }
   
   // If array is full, ONLY remove an OB if it's already mitigated.
   // Otherwise, keep existing zones (don't make untouched zones disappear).
   if(BearishOBCount >= InpSMCMaxOrderBlocks)
   {
      int removeIndex = -1;
      for(int i = BearishOBCount - 1; i >= 0; i--)
      {
         if(BearishOBs[i].mitigated)
         {
            removeIndex = i;
            break;
         }
      }
      
      if(removeIndex >= 0)
      {
         ObjectDelete(0, BearishOBs[removeIndex].objName);
         for(int k = removeIndex; k < BearishOBCount - 1; k++)
         {
            BearishOBs[k] = BearishOBs[k + 1];
         }
         BearishOBCount--;
      }
      else
      {
         Print(">>> SMC: Bearish OB limit reached and none mitigated - keeping existing zones (no delete)");
         return;
      }
   }
   
   // Add new OB
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
//| Draw Order Blocks as rectangles on chart                           |
//+------------------------------------------------------------------+
void DrawOrderBlocks()
{
   datetime currentTime = TimeCurrent();
   datetime endTime = currentTime + PeriodSeconds(InpSMCTimeframe) * 50;
   
   // Draw Bullish Order Blocks
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
      
      ObjectSetInteger(0, objName, OBJPROP_COLOR, InpSMCBullOBColor);
      ObjectSetInteger(0, objName, OBJPROP_FILL, true);
      ObjectSetInteger(0, objName, OBJPROP_BACK, true);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_HIDDEN, false);
   }
   
   // Draw Bearish Order Blocks
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
      
      ObjectSetInteger(0, objName, OBJPROP_COLOR, InpSMCBearOBColor);
      ObjectSetInteger(0, objName, OBJPROP_FILL, true);
      ObjectSetInteger(0, objName, OBJPROP_BACK, true);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_HIDDEN, false);
   }
}

//+------------------------------------------------------------------+
//| Check if price touched an Order Block                              |
//| IMPORTANT: Touch flags PERSIST until used for order or reset       |
//+------------------------------------------------------------------+
void CheckOBTouch(double closePrice, double highPrice, double lowPrice)
{
   // DON'T reset touch flags every tick - let them persist for PA confirmation
   // Flags are only reset when:
   // 1. Order is executed (in ExecuteBuy/ExecuteSell)
   // 2. Signal reset is required (after position closes)

   // Current tick touch detection
   bool currentTickBuyTouch = false;
   bool currentTickSellTouch = false;

   // Check Bullish OB touch (price dipped into support zone)
   for(int i = 0; i < BullishOBCount; i++)
   {
      if(BullishOBs[i].mitigated) continue;

      bool touched = false;

      // Price entered the Bullish OB zone (support)
      if(lowPrice <= BullishOBs[i].high && lowPrice >= BullishOBs[i].low)
      {
         touched = true;
      }
      // Price closed inside the zone
      else if(closePrice <= BullishOBs[i].high && closePrice >= BullishOBs[i].low)
      {
         touched = true;
      }

      if(touched)
      {
         currentTickBuyTouch = true;

         // IMPORTANT: If price moved from OB#1 to OB#2 (or #3) while waiting for PA,
         // we must switch the active OB and stop counting the previous one.
         // So: update the active OB if different from the previous touched OB.
         if(!g_smcBuyTouchedOBPersist || g_smcBuyTouchedOBName != BullishOBs[i].objName)
         {
            g_smcBuyTouchedOBPersist = true;
            g_smcBuyTouchedOB = true;
            g_smcBuyTouchedOBName = BullishOBs[i].objName;
            g_smcBuyTouchTime = iTime(_Symbol, PERIOD_CURRENT, 0);  // Use bar time, not tick time!

            // If we are already waiting for PA on BUY, switch context to this new OB.
            if(InpUsePAConfirm && InpSignalStrategy == STRATEGY_SMC && g_pendingSignal == "BUY")
            {
               g_signalTouchTime = g_smcBuyTouchTime;
               g_signalBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
               g_paWaitCount = 0;
               Print(">>> SWITCH BUY OB: now waiting PA on ", g_smcBuyTouchedOBName, " | TouchTime=", TimeToString(g_signalTouchTime));
            }
            else
            {
               Print(">>> Price touched Bullish Order Block! Zone: ", BullishOBs[i].low, " - ", BullishOBs[i].high, " | Active OB for PA: ", g_smcBuyTouchedOBName);
            }
         }
         break;
      }
   }

   // Check Bearish OB touch (price spiked into resistance zone)
   for(int i = 0; i < BearishOBCount; i++)
   {
      if(BearishOBs[i].mitigated) continue;

      bool touched = false;

      // Price entered the Bearish OB zone (resistance)
      if(highPrice >= BearishOBs[i].low && highPrice <= BearishOBs[i].high)
      {
         touched = true;
      }
      // Price closed inside the zone
      else if(closePrice >= BearishOBs[i].low && closePrice <= BearishOBs[i].high)
      {
         touched = true;
      }

      if(touched)
      {
         currentTickSellTouch = true;

         // Switch active OB if a different box is touched while waiting for PA
         if(!g_smcSellTouchedOBPersist || g_smcSellTouchedOBName != BearishOBs[i].objName)
         {
            g_smcSellTouchedOBPersist = true;
            g_smcSellTouchedOB = true;
            g_smcSellTouchedOBName = BearishOBs[i].objName;
            g_smcSellTouchTime = iTime(_Symbol, PERIOD_CURRENT, 0);  // Use bar time, not tick time!

            if(InpUsePAConfirm && InpSignalStrategy == STRATEGY_SMC && g_pendingSignal == "SELL")
            {
               g_signalTouchTime = g_smcSellTouchTime;
               g_signalBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
               g_paWaitCount = 0;
               Print(">>> SWITCH SELL OB: now waiting PA on ", g_smcSellTouchedOBName, " | TouchTime=", TimeToString(g_signalTouchTime));
            }
            else
            {
               Print(">>> Price touched Bearish Order Block! Zone: ", BearishOBs[i].low, " - ", BearishOBs[i].high, " | Active OB for PA: ", g_smcSellTouchedOBName);
            }
         }
         break;
      }
   }

   // Track CURRENT touch (used by reset logic)
   g_smcBuyTouchingNow = currentTickBuyTouch;
   g_smcSellTouchingNow = currentTickSellTouch;

   // Keep the SMC signal trigger based on persistent touch (so PA can be confirmed after the touch)
   g_smcBuyTouchedOB = g_smcBuyTouchedOBPersist;
   g_smcSellTouchedOB = g_smcSellTouchedOBPersist;
}

//+------------------------------------------------------------------+
//| Generate SMC Signal based on OB touch and trend                    |
//+------------------------------------------------------------------+
void GenerateSMCSignal(double &closeArr[], double &lowArr[], double &highArr[])
{
   SMCSignal = "NONE";
   
   int signalBar = (InpSMCSignalBar == EMA_CURRENT_BAR) ? 0 : 1;
   
   // BUY Signal: Bullish trend + Price touched Bullish OB (support)
   // If PA confirmation is enabled, it will be checked in OnTick
   if(SMCTrend >= 0)  // Bullish or Neutral trend
   {
      if(g_smcBuyTouchedOB)
      {
         if(InpSMCRequireTouch)
         {
            SMCSignal = "BUY";
         }
         else
         {
            SMCSignal = "BUY";
         }
      }
   }
   
   // SELL Signal: Bearish trend + Price touched Bearish OB (resistance)
   if(SMCTrend <= 0)  // Bearish or Neutral trend
   {
      if(g_smcSellTouchedOB)
      {
         if(InpSMCRequireTouch)
         {
            SMCSignal = "SELL";
         }
         else
         {
            SMCSignal = "SELL";
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Update SMC Signal Reset Status                                     |
//+------------------------------------------------------------------+
void UpdateSMCSignalResetStatus()
{
   // For SMC: Reset requires price to move away from OB zone
   // then touch it again for new signal

   if(g_waitBuySignalReset && InpSignalStrategy == STRATEGY_SMC)
   {
      // BUY reset: Wait for price to move above all Bullish OBs
      // then touch one again

      // Phase 1: Price must NOT be touching any OB RIGHT NOW (moved away)
      // NOTE: g_smcBuyTouchedOBPersist means "touched before" (for PA), not "touching now".
      if(g_smcBuyResetRequired && !g_smcBuyTouchingNow)
      {
         g_smcBuyResetPhaseComplete = true;
         Print("*** SMC BUY Reset Phase 1 Complete - Price moved away from OB ***");
      }
      // Phase 2: Price touches OB again after moving away
      else if(g_smcBuyResetPhaseComplete && g_smcBuyTouchedOBPersist)
      {
         g_waitBuySignalReset = false;
         g_smcBuyResetRequired = false;
         g_smcBuyResetPhaseComplete = false;
         Print("*** SMC BUY Signal Reset Complete - Ready for new BUY signal! ***");
      }
   }

   if(g_waitSellSignalReset && InpSignalStrategy == STRATEGY_SMC)
   {
      // SELL reset: Wait for price to move below all Bearish OBs
      // then touch one again

      // Phase 1: Price must NOT be touching any OB RIGHT NOW (moved away)
      // NOTE: g_smcSellTouchedOBPersist means "touched before" (for PA), not "touching now".
      if(g_smcSellResetRequired && !g_smcSellTouchingNow)
      {
         g_smcSellResetPhaseComplete = true;
         Print("*** SMC SELL Reset Phase 1 Complete - Price moved away from OB ***");
      }
      // Phase 2: Price touches OB again after moving away
      else if(g_smcSellResetPhaseComplete && g_smcSellTouchedOBPersist)
      {
         g_waitSellSignalReset = false;
         g_smcSellResetRequired = false;
         g_smcSellResetPhaseComplete = false;
         Print("*** SMC SELL Signal Reset Complete - Ready for new SELL signal! ***");
      }
   }
}

//+------------------------------------------------------------------+
//| Analyze Smart Money Concepts Signal                                |
//+------------------------------------------------------------------+
string AnalyzeSMCSignal()
{
   datetime currentBarTime = iTime(_Symbol, InpSMCTimeframe, 0);
   
   // For Last Bar Closed mode, check if this is a new bar
   if(InpSMCSignalBar == EMA_LAST_BAR_CLOSED)
   {
      if(currentBarTime == LastSMCSignalTime)
      {
         return "WAIT";
      }
      LastSMCSignalTime = currentBarTime;
   }
   
   // *** UPDATE SIGNAL RESET STATUS ***
   UpdateSMCSignalResetStatus();
   
   // Return the SMC signal calculated in CalculateSMC()
   if(SMCSignal == "BUY")
   {
      // *** CHECK IF BUY SIGNAL RESET IS REQUIRED ***
      if(g_waitBuySignalReset)
      {
         Print(">>> SMC BUY Signal detected but waiting for reset (Phase 1: ", g_smcBuyResetPhaseComplete ? "Complete" : "Pending", ")");
         return "WAIT";
      }
      Print(">>> Smart Money Concepts BUY Signal Confirmed! (Price touched Bullish Order Block)");
      return "BUY";
   }
   else if(SMCSignal == "SELL")
   {
      // *** CHECK IF SELL SIGNAL RESET IS REQUIRED ***
      if(g_waitSellSignalReset)
      {
         Print(">>> SMC SELL Signal detected but waiting for reset (Phase 1: ", g_smcSellResetPhaseComplete ? "Complete" : "Pending", ")");
         return "WAIT";
      }
      Print(">>> Smart Money Concepts SELL Signal Confirmed! (Price touched Bearish Order Block)");
      return "SELL";
   }
   
   return "WAIT";
}

bool ExecuteBuy()
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
      
      // *** RESET SMC TOUCH FLAGS AFTER ORDER EXECUTION ***
      if(InpSignalStrategy == STRATEGY_SMC)
      {
         g_smcBuyTouchedOBPersist = false;
         g_smcBuyTouchedOB = false;
         g_smcBuyTouchedOBName = "";
         g_smcBuyTouchTime = 0;
         Print(">>> SMC BUY touch flags reset after order execution");
      }
      return true;
   }
   
   Print("BUY Failed! Retcode: ", trade.ResultRetcode(), " | LastError: ", GetLastError());
   return false;
}

//+------------------------------------------------------------------+
//| Execute SELL order                                                 |
//+------------------------------------------------------------------+
bool ExecuteSell()
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
      
      // *** RESET SMC TOUCH FLAGS AFTER ORDER EXECUTION ***
      if(InpSignalStrategy == STRATEGY_SMC)
      {
         g_smcSellTouchedOBPersist = false;
         g_smcSellTouchedOB = false;
         g_smcSellTouchedOBName = "";
         g_smcSellTouchTime = 0;
         Print(">>> SMC SELL touch flags reset after order execution");
      }
      return true;
   }
   
   Print("SELL Failed! Retcode: ", trade.ResultRetcode(), " | LastError: ", GetLastError());
   return false;
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
//| Parse time string "hh:mm" to minutes from midnight               |
//+------------------------------------------------------------------+
int ParseTimeToMinutes(string timeStr)
{
   if(StringLen(timeStr) < 5) return -1;
   
   int colonPos = StringFind(timeStr, ":");
   if(colonPos < 0) return -1;
   
   string hourStr = StringSubstr(timeStr, 0, colonPos);
   string minStr = StringSubstr(timeStr, colonPos + 1, 2);
   
   int hour = (int)StringToInteger(hourStr);
   int min = (int)StringToInteger(minStr);
   
   if(hour < 0 || hour > 23 || min < 0 || min > 59) return -1;
   
   return hour * 60 + min;
}

//+------------------------------------------------------------------+
//| Parse session string "hh:mm-hh:mm" and check if time is in range |
//+------------------------------------------------------------------+
bool IsTimeInSession(string session, int currentMinutes)
{
   if(StringLen(session) < 11) return false;  // Minimum "00:00-23:59"
   
   int dashPos = StringFind(session, "-");
   if(dashPos < 0) return false;
   
   string startStr = StringSubstr(session, 0, dashPos);
   string endStr = StringSubstr(session, dashPos + 1);
   
   int startMinutes = ParseTimeToMinutes(startStr);
   int endMinutes = ParseTimeToMinutes(endStr);
   
   if(startMinutes < 0 || endMinutes < 0) return false;
   
   // Handle normal case (e.g., 08:00-20:00)
   if(startMinutes <= endMinutes)
   {
      return (currentMinutes >= startMinutes && currentMinutes < endMinutes);
   }
   // Handle overnight case (e.g., 22:00-06:00)
   else
   {
      return (currentMinutes >= startMinutes || currentMinutes < endMinutes);
   }
}

//+------------------------------------------------------------------+
//| Check if current day is allowed for trading                       |
//+------------------------------------------------------------------+
bool IsTradableDay(int dayOfWeek)
{
   switch(dayOfWeek)
   {
      case 0: return InpTradeSunday;
      case 1: return InpTradeMonday;
      case 2: return InpTradeTuesday;
      case 3: return InpTradeWednesday;
      case 4: return InpTradeThursday;
      case 5: return InpTradeFriday;
      case 6: return InpTradeSaturday;
      default: return false;
   }
}

//+------------------------------------------------------------------+
//| Check if within trading hours                                      |
//+------------------------------------------------------------------+
bool IsWithinTradingHours()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   // Check if trading day is allowed
   if(!IsTradableDay(dt.day_of_week))
      return false;
   
   // Calculate current time in minutes from midnight
   int currentMinutes = dt.hour * 60 + dt.min;
   
   // Check if Friday - use Friday sessions if available
   bool isFriday = (dt.day_of_week == 5);
   
   if(isFriday)
   {
      // Check Friday sessions first (if any are set)
      bool hasFridaySessions = (StringLen(InpFridaySession1) >= 5 || 
                                 StringLen(InpFridaySession2) >= 5 || 
                                 StringLen(InpFridaySession3) >= 5);
      
      if(hasFridaySessions)
      {
         // Use Friday sessions
         if(StringLen(InpFridaySession1) >= 5 && IsTimeInSession(InpFridaySession1, currentMinutes))
            return true;
         if(StringLen(InpFridaySession2) >= 5 && IsTimeInSession(InpFridaySession2, currentMinutes))
            return true;
         if(StringLen(InpFridaySession3) >= 5 && IsTimeInSession(InpFridaySession3, currentMinutes))
            return true;
            
         return false;  // Friday has special sessions but not in any
      }
      // If no Friday sessions set, fall through to normal sessions
   }
   
   // Check normal sessions
   if(StringLen(InpSession1) >= 5 && IsTimeInSession(InpSession1, currentMinutes))
      return true;
   if(StringLen(InpSession2) >= 5 && IsTimeInSession(InpSession2, currentMinutes))
      return true;
   if(StringLen(InpSession3) >= 5 && IsTimeInSession(InpSession3, currentMinutes))
      return true;
   
   // If no sessions are set, allow trading all day
   if(StringLen(InpSession1) < 5 && StringLen(InpSession2) < 5 && StringLen(InpSession3) < 5)
      return true;
   
   return false;
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
   text = text + "Signal Strategy: " + EnumToString(InpSignalStrategy) + nl;
   text = text + "Trade Mode: " + GetTradeModeString() + nl;
   text = text + "Lot Mode: " + EnumToString(InpLotMode) + nl;
   text = text + "---------------------------------" + nl;
   
   // Show status based on selected strategy
   if(InpSignalStrategy == STRATEGY_ZIGZAG)
   {
      text = text + "ZIGZAG++ STATUS:" + nl;
      text = text + "  TF: " + EnumToString(InpZigZagTimeframe) + nl;
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
   }
   else if(InpSignalStrategy == STRATEGY_EMA_CHANNEL)
   {
      text = text + "EMA CHANNEL STATUS:" + nl;
      text = text + "  TF: " + EnumToString(InpEMATimeframe) + nl;
      text = text + "  EMA High (" + IntegerToString(InpEMAHighPeriod) + "): " + DoubleToString(EMAHigh, _Digits) + nl;
      text = text + "  EMA Low (" + IntegerToString(InpEMALowPeriod) + "): " + DoubleToString(EMALow, _Digits) + nl;
      string signalBarMode = (InpEMASignalBar == EMA_CURRENT_BAR) ? "Current Bar" : "Last Bar Closed";
      text = text + "  Signal Mode: " + signalBarMode + nl;
      text = text + "  Signal: " + EMASignal + nl;
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