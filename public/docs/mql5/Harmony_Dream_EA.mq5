//+------------------------------------------------------------------+
//|                                         Harmony_Dream_EA.mq5     |
//|                      Harmony Dream (Pairs Trading) v2.0          |
//|                                             MoneyX Trading        |
//+------------------------------------------------------------------+
#property copyright "MoneyX Trading"
#property version   "2.18"
#property strict
#property description "Harmony Dream - Pairs Trading Expert Advisor"
#property description "v2.1.8: Fix License Reload + Duplicate Orders Prevention"
#property description "Full Hedging with Independent Buy/Sell Sides"
#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| LICENSE CONFIGURATION (v3.6.5)                                     |
//+------------------------------------------------------------------+
#define LICENSE_BASE_URL    "https://lkbhomsulgycxawwlnfh.supabase.co"
#define EA_API_SECRET       "moneyx-ea-secret-2024-secure-key-v1"

//+------------------------------------------------------------------+
//| CONSTANTS                                                          |
//+------------------------------------------------------------------+
#define MAX_PAIRS 30
#define MAX_LOOKBACK 200
#define MAX_AVG_LEVELS 10
#define MAX_GROUPS 5
#define PAIRS_PER_GROUP 6
#define MAX_MINI_GROUPS 15     // 15 Mini Groups (numbered 1-15)
#define PAIRS_PER_MINI 2       // 2 pairs per Mini Group
#define MINIS_PER_GROUP 3      // 3 Mini Groups per Main Group

//+------------------------------------------------------------------+
//| PAIR DATA STRUCTURE (with embedded arrays)                         |
//+------------------------------------------------------------------+
struct PairData
{
   double         pricesA[MAX_LOOKBACK];
   double         pricesB[MAX_LOOKBACK];
   double         returnsA[MAX_LOOKBACK];
   double         returnsB[MAX_LOOKBACK];
   double         spreadHistory[MAX_LOOKBACK];
   // v3.3.0: Separate arrays for Z-Score calculation (can use different timeframe)
   double         zScorePricesA[MAX_LOOKBACK];
   double         zScorePricesB[MAX_LOOKBACK];
   double         zScoreSpreadHistory[MAX_LOOKBACK];
};

//+------------------------------------------------------------------+
//| PAIR INFO STRUCTURE (v3.3.0 - Updated)                             |
//+------------------------------------------------------------------+
struct PairInfo
{
   // === Basic Info ===
   string         symbolA;           // Symbol A (Base)
   string         symbolB;           // Symbol B (Hedge)
   bool           enabled;           // Pair On/Off
   bool           dataValid;         // Data available and valid for calculation
   
   // === Statistical Data ===
   double         correlation;       // Current Correlation
   int            correlationType;   // 1 = Positive, -1 = Negative (Auto-detect)
   double         hedgeRatio;        // Beta (Hedge Ratio)
   double         spreadMean;        // Spread Mean
   double         spreadStdDev;      // Spread Std Deviation
   double         currentSpread;     // Current Spread Value
   double         zScore;            // Current Z-Score
   
   // === Beta Smoothing (v3.2.6) ===
   double         prevBeta;          // Previous Beta (for EMA smoothing)
   bool           betaInitialized;   // True after first Beta calculation
   double         manualBeta;        // Manual Beta Override (0 = use auto)
   
   // === BUY SIDE (Main Order Buy) ===
   int            directionBuy;      // 0=Off, -1=Ready, 1=Active
   ulong          ticketBuyA;        // Symbol A ticket for Buy side
   ulong          ticketBuyB;        // Symbol B ticket for Buy side
   double         lotBuyA;           // Lot for Symbol A (Buy side)
   double         lotBuyB;           // Lot for Symbol B (Buy side)
   double         profitBuy;         // Total profit Buy side
   int            orderCountBuy;     // Number of orders Buy side
   int            maxOrderBuy;       // Max orders allowed Buy side (Total: Main + Grid)
   double         targetBuy;         // Target profit Buy side
   datetime       entryTimeBuy;      // Entry time Buy side
   
   // === SELL SIDE (Main Order Sell) ===
   int            directionSell;     // 0=Off, -1=Ready, 1=Active
   ulong          ticketSellA;       // Symbol A ticket for Sell side
   ulong          ticketSellB;       // Symbol B ticket for Sell side
   double         lotSellA;          // Lot for Symbol A (Sell side)
   double         lotSellB;          // Lot for Symbol B (Sell side)
   double         profitSell;        // Total profit Sell side
   int            orderCountSell;    // Number of orders Sell side
   int            maxOrderSell;      // Max orders allowed Sell side (Total: Main + Grid)
   double         targetSell;        // Target profit Sell side
   datetime       entryTimeSell;     // Entry time Sell side
   
   // === Averaging System (v3.2.7) ===
   int            avgOrderCountBuy;  // Averaging orders opened on Buy side
   int            avgOrderCountSell; // Averaging orders opened on Sell side
   double         lastAvgPriceBuy;   // Last averaging price for Buy side
   double         lastAvgPriceSell;  // Last averaging price for Sell side
   double         entryZScoreBuy;    // Entry Z-Score for Buy (for Z-Score grid)
   double         entryZScoreSell;   // Entry Z-Score for Sell (for Z-Score grid)
   
   // === v3.2.9: Same-Tick Protection ===
   bool           justOpenedMainBuy;  // Prevent averaging in same tick as main order
   bool           justOpenedMainSell; // Prevent averaging in same tick as main order
   
   // === v3.2.9: Closed P/L Tracking ===
   double         closedProfitBuy;   // Accumulated closed profit for Buy side
   double         closedProfitSell;  // Accumulated closed profit for Sell side
   
   // === v3.4.0: RSI on Spread ===
   double         rsiSpread;         // Current RSI of Spread (0-100)
   
   // === v3.5.0: CDC Action Zone Trend Filter ===
   string         cdcTrendA;         // CDC Trend for Symbol A ("BULLISH", "BEARISH", "NEUTRAL")
   string         cdcTrendB;         // CDC Trend for Symbol B ("BULLISH", "BEARISH", "NEUTRAL")
   double         cdcFastA;          // CDC Fast EMA value for Symbol A
   double         cdcSlowA;          // CDC Slow EMA value for Symbol A
   double         cdcFastB;          // CDC Fast EMA value for Symbol B
   double         cdcSlowB;          // CDC Slow EMA value for Symbol B
   
   // === v3.7.1: CDC Status per Symbol (for TF-independent refresh) ===
   datetime       lastCdcTimeA;      // Last CDC candle time for Symbol A
   datetime       lastCdcTimeB;      // Last CDC candle time for Symbol B
   bool           cdcReadyA;         // CDC data ready for Symbol A
   bool           cdcReadyB;         // CDC data ready for Symbol B
   
   // === v3.5.3 HF1: Last Grid Lot for Compounding ===
   double         lastGridLotBuyA;   // Last Lot A for BUY side grid
   double         lastGridLotBuyB;   // Last Lot B for BUY side grid
   double         lastGridLotSellA;  // Last Lot A for SELL side grid
   double         lastGridLotSellB;  // Last Lot B for SELL side grid
   
   // === v3.5.3 HF3: ADX for Negative Correlation Pairs ===
   double         adxValueA;         // ADX value for Symbol A
   double         adxValueB;         // ADX value for Symbol B
   
   // === v1.7.0: ADX Winner Tracking for Negative Correlation ===
   int            adxWinner;         // -1=None/Equal, 0=Symbol A wins, 1=Symbol B wins
   double         adxWinnerValue;    // ADX value of Winner
   double         adxLoserValue;     // ADX value of Loser
   
   // === v3.6.0: Grid Profit Side ===
   int            gridProfitCountBuy;    // Profit Grid orders on BUY side
   int            gridProfitCountSell;   // Profit Grid orders on SELL side
   
   // === v3.6.0 HF4: Total Lot Tracking for All Grid Orders ===
   double         avgTotalLotBuy;        // Total lot of all Grid orders (BUY side)
   double         avgTotalLotSell;       // Total lot of all Grid orders (SELL side)
   double         lastProfitPriceBuy;    // Last price for Profit Grid (BUY)
   double         lastProfitPriceSell;   // Last price for Profit Grid (SELL)
   double         lastProfitGridLotBuyA; // Last Profit Grid Lot A (BUY)
   double         lastProfitGridLotBuyB; // Last Profit Grid Lot B (BUY)
   double         lastProfitGridLotSellA; // Last Profit Grid Lot A (SELL)
   double         lastProfitGridLotSellB; // Last Profit Grid Lot B (SELL)
   double         initialEntryPriceBuy;  // Initial entry price (BUY)
   double         initialEntryPriceSell; // Initial entry price (SELL)
   int            gridProfitZLevelBuy;   // Current Z-Score level for Profit Grid (BUY)
   int            gridProfitZLevelSell;  // Current Z-Score level for Profit Grid (SELL)
   
   // === v2.1.6: ATR Caching ===
   double         cachedGridLossATR;      // Cached ATR value for Grid Loss
   double         cachedGridProfitATR;    // Cached ATR value for Grid Profit
   datetime       lastATRBarTime;         // Last bar time ATR was calculated
   
   // === Combined ===
   double         totalPairProfit;   // profitBuy + profitSell
};

//+------------------------------------------------------------------+
//| EXIT MODE ENUM (v3.2.7)                                            |
//+------------------------------------------------------------------+
enum ENUM_EXIT_MODE
{
   EXIT_ZSCORE_ONLY = 0,    // Z-Score Only
   EXIT_PROFIT_ONLY,        // Profit Target Only
   EXIT_ZSCORE_OR_PROFIT,   // Z-Score OR Profit (First met)
   EXIT_ZSCORE_AND_PROFIT   // Z-Score AND Profit (Both required)
};

//+------------------------------------------------------------------+
//| AVERAGING MODE ENUM (v3.2.7)                                       |
//+------------------------------------------------------------------+
enum ENUM_AVERAGING_MODE
{
   AVG_MODE_DISABLED = 0,   // Disabled
   AVG_MODE_ZSCORE,         // Z-Score Based Grid
   AVG_MODE_ATR             // ATR Based Grid
};

//+------------------------------------------------------------------+
//| GRID DISTANCE MODE ENUM (v3.6.0)                                   |
//+------------------------------------------------------------------+
enum ENUM_GRID_DISTANCE_MODE
{
   GRID_DIST_ATR = 0,        // ATR Based
   GRID_DIST_ZSCORE,         // Z-Score Based  
   GRID_DIST_FIXED_POINTS,   // Fixed Points
   GRID_DIST_FIXED_PIPS      // Fixed Pips
};

//+------------------------------------------------------------------+
//| GRID LOT TYPE ENUM (v3.6.0)                                        |
//+------------------------------------------------------------------+
enum ENUM_GRID_LOT_TYPE
{
   GRID_LOT_TYPE_INITIAL = 0,     // Use Initial Order Lot
   GRID_LOT_TYPE_CUSTOM,          // Custom Fixed Lot
   GRID_LOT_TYPE_MULTIPLIER,      // Multiplier from Previous
   GRID_LOT_TYPE_TREND_BASED      // Use Grid Lot Calculation Mode Settings
};

//+------------------------------------------------------------------+
//| GRID LOT CALCULATION MODE ENUM (v3.5.3 HF1)                        |
//+------------------------------------------------------------------+
enum ENUM_GRID_LOT_MODE
{
   GRID_LOT_FIXED = 0,      // Fixed Lot (use Initial Lot for all levels)
   GRID_LOT_BETA,           // Beta Mode (use Hedge Ratio from Beta Settings)
   GRID_LOT_ATR_TREND       // ATR Trend Mode (CDC Trend + Compounding)
};

enum ENUM_GRID_LOT_SCOPE
{
   GRID_SCOPE_GRID_ONLY = 0,  // Grid Orders Only
   GRID_SCOPE_ALL             // Both Main & Grid Orders
};

//+------------------------------------------------------------------+
//| LOT PROGRESSION MODE ENUM (v3.5.3 HF1 - for ATR Trend Mode)        |
//+------------------------------------------------------------------+
enum ENUM_LOT_PROGRESSION
{
   LOT_PROG_MULTIPLIER = 0,  // Multiplier (base × mult each level)
   LOT_PROG_COMPOUNDING      // Compounding (prev × mult each level)
};

//+------------------------------------------------------------------+
//| THEME MODE ENUM (v1.8.5)                                           |
//+------------------------------------------------------------------+
enum ENUM_THEME_MODE
{
   THEME_DARK = 0,    // Dark Mode (Default)
   THEME_LIGHT        // Light Mode
};

//+------------------------------------------------------------------+
//| ENTRY MODE ENUM (v1.8.8)                                           |
//+------------------------------------------------------------------+
enum ENUM_ENTRY_MODE
{
   ENTRY_MODE_ZSCORE = 0,        // Z-Score Based (Original)
   ENTRY_MODE_CORRELATION_ONLY   // Correlation Only (No Z-Score)
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                   |
//+------------------------------------------------------------------+
input group "=== Trading Settings ==="
input double   InpBaseLot = 0.1;                // Base Lot Size (Symbol A)
input double   InpMaxLot = 10.0;                // Maximum Lot Size
input int      InpMagicNumber = 999999;         // Magic Number
input int      InpSlippage = 30;                // Slippage (points)
// (Removed) Trading Timeframe - not needed, trades based on Z-Score/Corr thresholds

input group "=== AUTO BALANCE SCALING (v1.6.5) ==="
input bool     InpEnableAutoScaling = false;        // Enable Auto Balance Scaling
input double   InpBaseAccountSize = 100000.0;       // Base Account Size ($) - scale reference
input bool     InpEnableFixedScale = false;         // Enable Fixed Scale Account (lock scale)
input double   InpFixedScaleAccount = 100000.0;     // Fixed Scale Account ($) - lock at this size
input double   InpScaleMin = 0.1;                   // Minimum Scale Factor (safety limit)
input double   InpScaleMax = 10.0;                  // Maximum Scale Factor (safety limit)

//+------------------------------------------------------------------+
//| CORRELATION METHOD ENUM (v3.2.1)                                   |
//+------------------------------------------------------------------+
enum ENUM_CORR_METHOD
{
   CORR_PRICE_DIRECT = 0,    // Price Direct (like myfxbook)
   CORR_PERCENTAGE_CHANGE,   // Percentage Change
   CORR_LOG_RETURNS          // Log Returns
};

//+------------------------------------------------------------------+
//| BETA CALCULATION MODE ENUM (v3.2.6)                                |
//+------------------------------------------------------------------+
enum ENUM_BETA_MODE
{
   BETA_AUTO_SMOOTH = 0,     // Auto + EMA Smoothing (Recommended)
   BETA_PIP_VALUE_ONLY,      // Pip Value Ratio Only (Most Stable)
   BETA_PERCENTAGE_RAW,      // Percentage Change (Volatile - Current)
   BETA_MANUAL_FIXED         // Manual Fixed Ratio
};

input group "=== Correlation Calculation Settings ==="
input ENUM_TIMEFRAMES InpCorrTimeframe = PERIOD_H4;   // Correlation Timeframe
input int      InpCorrBars = 100;                      // Correlation Bars Count (myfxbook uses 100-200)
input ENUM_CORR_METHOD InpCorrMethod = CORR_PRICE_DIRECT;  // Correlation Method
input bool     InpAutoDownloadData = true;             // Auto Download History Data

input group "=== Statistical Settings ==="
input int      InpLookbackPeriod = 100;         // Lookback Period (bars)
input double   InpEntryZScore = 2.0;            // Entry Z-Score Threshold
input double   InpExitZScore = 0.5;             // Exit Z-Score Threshold
input double   InpMinCorrelation = 0.70;        // Minimum Correlation
input bool     InpDebugMode = false;            // Enable Debug Logs

input group "=== RSI on Spread Filter (v3.4.0) ==="
input bool     InpUseRSISpreadFilter = false;   // Enable RSI on Spread Filter
input int      InpRSISpreadPeriod = 14;         // RSI Period for Spread
input double   InpRSIOverbought = 70.0;         // RSI Overbought Level (SELL Zone)
input double   InpRSIOversold = 30.0;           // RSI Oversold Level (BUY Zone)

input group "=== CDC Action Zone Trend Filter (v3.5.0) ==="
input bool     InpUseCDCTrendFilter = false;    // Enable CDC Trend Filter
input ENUM_TIMEFRAMES InpCDCTimeframe = PERIOD_D1;  // CDC Timeframe (D1 recommended)
input int      InpCDCFastPeriod = 12;           // CDC Fast EMA Period
input int      InpCDCSlowPeriod = 26;           // CDC Slow EMA Period
input bool     InpRequireStrongTrend = false;   // Require Crossover (not just position)

//+------------------------------------------------------------------+
//| Z-SCORE BAR MODE ENUM (v1.6.7)                                     |
//+------------------------------------------------------------------+
enum ENUM_ZSCORE_BAR_MODE
{
   ZSCORE_BAR_CLOSE = 0,     // Close Bar (shift=1, stable - updates on new candle)
   ZSCORE_BAR_CURRENT        // Current Bar (real-time - updates every X minutes)
};

input group "=== Z-Score Timeframe Settings (v1.6.7) ==="
input ENUM_TIMEFRAMES InpZScoreTimeframe = PERIOD_CURRENT;  // Z-Score Timeframe (CURRENT = use Correlation TF)
input int      InpZScoreBars = 0;                            // Z-Score Bars (0 = use Correlation Bars)
input ENUM_ZSCORE_BAR_MODE InpZScoreBarMode = ZSCORE_BAR_CLOSE;  // Z-Score Bar Mode
input int      InpZScoreCurrentUpdateMins = 5;               // Current Bar Update Interval (minutes)

input group "=== Beta Calculation Settings (v3.2.6) ==="
input ENUM_BETA_MODE InpBetaMode = BETA_AUTO_SMOOTH;   // Beta Calculation Mode
input double   InpBetaSmoothFactor = 0.1;              // Beta EMA Smooth Factor (0.05-0.3)
input double   InpManualBetaDefault = 1.0;             // Default Manual Beta (if MANUAL_FIXED)
input double   InpPipBetaWeight = 0.7;                 // Pip-Value Beta Weight in Auto (0.5-0.9)

//+------------------------------------------------------------------+
//| CORRELATION DROP MODE ENUM (v3.2.9 HF2)                            |
//+------------------------------------------------------------------+
enum ENUM_CORR_DROP_MODE
{
   CORR_DROP_CLOSE_ALL = 0,        // Close Both Sides
   CORR_DROP_CLOSE_PROFIT_ONLY,    // Close Only Profitable Side
   CORR_DROP_IGNORE                // Ignore (Don't Close)
};

input group "=== Exit Settings (v3.2.7) ==="
input ENUM_EXIT_MODE InpExitMode = EXIT_ZSCORE_OR_PROFIT;  // Exit Mode
input bool     InpRequirePositiveProfit = true;            // Require Positive Profit for Z-Score Exit
input int      InpMinHoldingBars = 0;                      // Minimum Holding Bars Before Exit
input ENUM_CORR_DROP_MODE InpCorrDropMode = CORR_DROP_CLOSE_PROFIT_ONLY;  // Correlation Drop Behavior

input group "=== Grid Loss Side Settings (v1.6) ==="
input bool     InpEnableGridLoss = true;              // Enable Grid Loss Side
input ENUM_GRID_DISTANCE_MODE InpGridLossDistMode = GRID_DIST_ATR;  // Distance Mode
input ENUM_GRID_LOT_TYPE      InpGridLossLotType = GRID_LOT_TYPE_TREND_BASED;  // Lot Type
input double   InpGridLossFixedPoints = 500;          // Fixed Points (if mode = Fixed Points)
input double   InpGridLossFixedPips = 50;             // Fixed Pips (if mode = Fixed Pips)
input double   InpGridLossATRMultForex = 3.0;         // ATR Multiplier - Forex Pairs (if mode = ATR)
input double   InpGridLossATRMultGold = 1.5;          // ATR Multiplier - Gold/XAU Pairs (if mode = ATR)
input double   InpGridLossMinDistPips = 100.0;        // Minimum Grid Distance (Pips) - Fallback
input ENUM_TIMEFRAMES InpGridLossATRTimeframe = PERIOD_H4;  // ATR Timeframe (if mode = ATR)
input int      InpGridLossATRPeriod = 14;             // ATR Period (if mode = ATR)
input string   InpGridLossZScoreLevels = "2.5;3.0;4.0;5.0"; // Z-Score Levels (if mode = Z-Score)
input double   InpGridLossCustomLot = 0.1;            // Custom Lot (if type = Custom)
input double   InpGridLossLotMultiplier = 1.2;        // Lot Multiplier (if type = Multiplier)
input int      InpMaxGridLossOrders = 5;              // Max Grid Loss Orders (Sub-Limit)

input group "=== Grid Profit Side Settings (v1.6) ==="
input bool     InpEnableGridProfit = false;           // Enable Grid Profit Side
input ENUM_GRID_DISTANCE_MODE InpGridProfitDistMode = GRID_DIST_ATR;  // Distance Mode
input ENUM_GRID_LOT_TYPE      InpGridProfitLotType = GRID_LOT_TYPE_TREND_BASED;  // Lot Type
input double   InpGridProfitFixedPoints = 500;        // Fixed Points (if mode = Fixed Points)
input double   InpGridProfitFixedPips = 50;           // Fixed Pips (if mode = Fixed Pips)
input double   InpGridProfitATRMultForex = 3.0;       // ATR Multiplier - Forex Pairs (if mode = ATR)
input double   InpGridProfitATRMultGold = 1.5;        // ATR Multiplier - Gold/XAU Pairs (if mode = ATR)
input double   InpGridProfitMinDistPips = 100.0;      // Minimum Grid Distance (Pips) - Fallback
input ENUM_TIMEFRAMES InpGridProfitATRTimeframe = PERIOD_H4;  // ATR Timeframe (if mode = ATR)
input int      InpGridProfitATRPeriod = 14;           // ATR Period (if mode = ATR)
input string   InpGridProfitZScoreLevels = "1.5;1.0;0.5"; // Z-Score Levels (if mode = Z-Score)
input double   InpGridProfitCustomLot = 0.1;          // Custom Lot (if type = Custom)
input double   InpGridProfitLotMultiplier = 1.1;      // Lot Multiplier (if type = Multiplier)
input int      InpMaxGridProfitOrders = 3;            // Max Grid Profit Orders (Sub-Limit)

input group "=== Grid Trading Guard (v3.5.1) ==="
input double   InpGridMinCorrelation = 0.60;      // Grid: Minimum Correlation (ต่ำกว่านี้หยุด Grid)
input double   InpGridMinZScore = 0.5;            // Grid: Minimum |Z-Score| (ต่ำกว่านี้หยุด Grid)
input bool     InpGridPauseAffectsMain = true;    // Apply to Main Entry Too (เกณฑ์นี้ใช้กับ Order แรกด้วย)

input group "=== Grid Lot Calculation Mode (v3.5.3 HF1) ==="
input ENUM_GRID_LOT_MODE   InpGridLotMode = GRID_LOT_BETA;         // Grid Lot Calculation Mode
input ENUM_GRID_LOT_SCOPE  InpGridLotScope = GRID_SCOPE_GRID_ONLY; // Apply to Scope

input group "--- ATR Trend Mode Settings (v3.5.3 HF1) ---"
input ENUM_LOT_PROGRESSION InpLotProgression = LOT_PROG_COMPOUNDING; // Lot Progression Mode (ATR Trend only)
input ENUM_TIMEFRAMES InpGridATRTimeframe = PERIOD_D1;  // ATR Timeframe for Ratio Calculation
input int      InpGridATRPeriod = 20;                    // ATR Period for Ratio Calculation
input double   InpTrendSideMultiplier = 1.2;            // Trend-Aligned Side: Fixed Multiplier
input double   InpCounterSideMultiplier = 1.0;          // Counter-Trend Side: Multiplier (Fixed)
input bool     InpUseATRRatioForTrend = false;          // Use ATR Ratio instead of Fixed Mult

input group "--- ADX for Negative Correlation (v3.5.3 HF3) ---"
input bool     InpUseADXForNegative = true;             // Use ADX for Negative Correlation Pairs
input ENUM_TIMEFRAMES InpADXTimeframe = PERIOD_H1;      // ADX Timeframe
input int      InpADXPeriod = 14;                       // ADX Period
input double   InpADXMinStrength = 20.0;                // Minimum ADX for Trend Strength

// v1.1: Global Basket Target Settings REMOVED - now per-group settings below each Pair Configuration
input group "=== Dashboard Settings ==="
input int      InpPanelX = 10;                  // Dashboard X Position
input int      InpPanelY = 30;                  // Dashboard Y Position
input int      InpPanelWidth = 1200;            // Dashboard Width
input int      InpPanelHeight = 820;            // Dashboard Height (for 30 pairs)
input int      InpRowHeight = 18;               // Row Height per Pair
input int      InpFontSize = 8;                 // Font Size

input group "=== Fast Backtest Settings (v3.3.0) ==="
input bool     InpFastBacktest = true;              // Enable Fast Backtest Mode
input bool     InpDisableDashboardInTester = false; // Disable Dashboard in Tester (Fastest)
input int      InpBacktestUiUpdateSec = 30;         // Dashboard Update Interval in Tester (sec)
input bool     InpDisableDebugInTester = true;      // Disable Debug Print in Tester
input int      InpBacktestLogInterval = 60;         // Summary Log Interval in Tester (sec, 0=off)
input int      InpMaxPairsPerTick = 5;              // Max Pairs to Process per Tick (0=all)
input bool     InpUltraFastMode = false;            // Ultra Fast Mode (Skip some calculations)
input int      InpStatCalcInterval = 10;            // Stat Calculation Interval (ticks, 0=every tick)
input bool     InpSkipCorrUpdateInTester = false;   // Skip Correlation Updates in Tester
input bool     InpSkipATRInTester = false;          // Skip ATR Indicator in Tester (use Simplified ATR)
input bool     InpSkipADXChartInTester = true;      // Skip ADX Chart in Tester (v2.1.4 - Logic Still Works)

input group "=== Lot Sizing (Dollar-Neutral) ==="
input bool     InpUseDollarNeutral = true;      // Use Dollar-Neutral Sizing
input double   InpMaxMarginPercent = 50.0;      // Max Margin Usage (%)

input group "=== Risk Management ==="
input double   InpMaxDrawdown = 20.0;           // Max Drawdown (%)
input int      InpMaxHoldingBars = 0;           // Max Holding Time (0=Disabled)
input double   InpEmergencyCloseDD = 30.0;      // Emergency Close Drawdown (0=Disabled)

input group "=== Drawdown Recovery Settings (v3.2.7) ==="
input bool     InpAutoResumeAfterDD = true;     // Auto Resume After DD Close
input double   InpResumeEquityPercent = 95.0;   // Resume When Equity Recovers To (%)

input group "=== Pair 1-6 Configuration (Group 1) ==="
input bool     InpEnablePair1 = true;           // Enable Pair 1
input string   InpPair1_SymbolA = "XAUUSD";     // Pair 1: Symbol A
input string   InpPair1_SymbolB = "XAUEUR";     // Pair 1: Symbol B

input bool     InpEnablePair2 = true;           // Enable Pair 2
input string   InpPair2_SymbolA = "EURUSD";     // Pair 2: Symbol A
input string   InpPair2_SymbolB = "GBPUSD";     // Pair 2: Symbol B

input bool     InpEnablePair3 = true;           // Enable Pair 3
input string   InpPair3_SymbolA = "AUDUSD";     // Pair 3: Symbol A
input string   InpPair3_SymbolB = "NZDUSD";     // Pair 3: Symbol B

input bool     InpEnablePair4 = true;           // Enable Pair 4
input string   InpPair4_SymbolA = "GBPUSD";     // Pair 4: Symbol A
input string   InpPair4_SymbolB = "USDJPY";     // Pair 4: Symbol B

input bool     InpEnablePair5 = true;           // Enable Pair 5
input string   InpPair5_SymbolA = "EURUSD";     // Pair 5: Symbol A
input string   InpPair5_SymbolB = "USDCHF";     // Pair 5: Symbol B

input bool     InpEnablePair6 = false;          // Enable Pair 6
input string   InpPair6_SymbolA = "EURUSD";     // Pair 6: Symbol A
input string   InpPair6_SymbolB = "USDJPY";     // Pair 6: Symbol B

input group "=== Group 1 Target Settings (v2.0) ==="
input double   InpGroup1ClosedTarget = 0;       // Basket Closed Profit Target $ (0=Disable)
input double   InpGroup1FloatingTarget = 0;     // Basket Floating Profit Target $ (0=Disable)
input int      InpGroup1MaxOrderBuy = 5;        // Total Max Orders Buy (Hard Cap: Main + All Grids)
input int      InpGroup1MaxOrderSell = 5;       // Total Max Orders Sell (Hard Cap: Main + All Grids)
input double   InpGroup1TargetBuy = 10.0;       // Default Target (Buy Side) $
input double   InpGroup1TargetSell = 10.0;      // Default Target (Sell Side) $

input group "=== Mini Group Targets (M1-M3) ==="
input double   InpMini1Target = 0;              // Mini 1 (Pair 1-2) Target $ (0=Disable)
input double   InpMini2Target = 0;              // Mini 2 (Pair 3-4) Target $ (0=Disable)
input double   InpMini3Target = 0;              // Mini 3 (Pair 5-6) Target $ (0=Disable)

input group "=== Pair 7-12 Configuration (Group 2) ==="
input bool     InpEnablePair7 = false;          // Enable Pair 7
input string   InpPair7_SymbolA = "GBPUSD";     // Pair 7: Symbol A
input string   InpPair7_SymbolB = "NZDUSD";     // Pair 7: Symbol B

input bool     InpEnablePair8 = false;          // Enable Pair 8
input string   InpPair8_SymbolA = "AUDUSD";     // Pair 8: Symbol A
input string   InpPair8_SymbolB = "EURUSD";     // Pair 8: Symbol B

input bool     InpEnablePair9 = false;          // Enable Pair 9
input string   InpPair9_SymbolA = "USDCAD";     // Pair 9: Symbol A
input string   InpPair9_SymbolB = "USDCHF";     // Pair 9: Symbol B

input bool     InpEnablePair10 = false;         // Enable Pair 10
input string   InpPair10_SymbolA = "EURJPY";    // Pair 10: Symbol A
input string   InpPair10_SymbolB = "GBPJPY";    // Pair 10: Symbol B

input bool     InpEnablePair11 = false;         // Enable Pair 11
input string   InpPair11_SymbolA = "EURGBP";    // Pair 11: Symbol A
input string   InpPair11_SymbolB = "EURCHF";    // Pair 11: Symbol B

input bool     InpEnablePair12 = false;         // Enable Pair 12
input string   InpPair12_SymbolA = "NZDUSD";    // Pair 12: Symbol A
input string   InpPair12_SymbolB = "USDCAD";    // Pair 12: Symbol B

input group "=== Group 2 Target Settings (v2.0) ==="
input double   InpGroup2ClosedTarget = 0;       // Basket Closed Profit Target $ (0=Disable)
input double   InpGroup2FloatingTarget = 0;     // Basket Floating Profit Target $ (0=Disable)
input int      InpGroup2MaxOrderBuy = 5;        // Total Max Orders Buy (Hard Cap: Main + All Grids)
input int      InpGroup2MaxOrderSell = 5;       // Total Max Orders Sell (Hard Cap: Main + All Grids)
input double   InpGroup2TargetBuy = 10.0;       // Default Target (Buy Side) $
input double   InpGroup2TargetSell = 10.0;      // Default Target (Sell Side) $

input group "=== Mini Group Targets (M4-M6) ==="
input double   InpMini4Target = 0;              // Mini 4 (Pair 7-8) Target $ (0=Disable)
input double   InpMini5Target = 0;              // Mini 5 (Pair 9-10) Target $ (0=Disable)
input double   InpMini6Target = 0;              // Mini 6 (Pair 11-12) Target $ (0=Disable)

input group "=== Pair 13-18 Configuration (Group 3) ==="
input bool     InpEnablePair13 = false;         // Enable Pair 13
input string   InpPair13_SymbolA = "AUDJPY";    // Pair 13: Symbol A
input string   InpPair13_SymbolB = "NZDJPY";    // Pair 13: Symbol B

input bool     InpEnablePair14 = false;         // Enable Pair 14
input string   InpPair14_SymbolA = "GBPAUD";    // Pair 14: Symbol A
input string   InpPair14_SymbolB = "GBPNZD";    // Pair 14: Symbol B

input bool     InpEnablePair15 = false;         // Enable Pair 15
input string   InpPair15_SymbolA = "EURAUD";    // Pair 15: Symbol A
input string   InpPair15_SymbolB = "EURNZD";    // Pair 15: Symbol B

input bool     InpEnablePair16 = false;         // Enable Pair 16
input string   InpPair16_SymbolA = "CHFJPY";    // Pair 16: Symbol A
input string   InpPair16_SymbolB = "CADJPY";    // Pair 16: Symbol B

input bool     InpEnablePair17 = false;         // Enable Pair 17
input string   InpPair17_SymbolA = "AUDCAD";    // Pair 17: Symbol A
input string   InpPair17_SymbolB = "AUDNZD";    // Pair 17: Symbol B

input bool     InpEnablePair18 = false;         // Enable Pair 18
input string   InpPair18_SymbolA = "GBPCAD";    // Pair 18: Symbol A
input string   InpPair18_SymbolB = "GBPCHF";    // Pair 18: Symbol B

input group "=== Group 3 Target Settings (v2.0) ==="
input double   InpGroup3ClosedTarget = 0;       // Basket Closed Profit Target $ (0=Disable)
input double   InpGroup3FloatingTarget = 0;     // Basket Floating Profit Target $ (0=Disable)
input int      InpGroup3MaxOrderBuy = 5;        // Total Max Orders Buy (Hard Cap: Main + All Grids)
input int      InpGroup3MaxOrderSell = 5;       // Total Max Orders Sell (Hard Cap: Main + All Grids)
input double   InpGroup3TargetBuy = 10.0;       // Default Target (Buy Side) $
input double   InpGroup3TargetSell = 10.0;      // Default Target (Sell Side) $

input group "=== Mini Group Targets (M7-M9) ==="
input double   InpMini7Target = 0;              // Mini 7 (Pair 13-14) Target $ (0=Disable)
input double   InpMini8Target = 0;              // Mini 8 (Pair 15-16) Target $ (0=Disable)
input double   InpMini9Target = 0;              // Mini 9 (Pair 17-18) Target $ (0=Disable)

input group "=== Pair 19-24 Configuration (Group 4) ==="
input bool     InpEnablePair19 = false;         // Enable Pair 19
input string   InpPair19_SymbolA = "EURCAD";    // Pair 19: Symbol A
input string   InpPair19_SymbolB = "EURCHF";    // Pair 19: Symbol B

input bool     InpEnablePair20 = false;         // Enable Pair 20
input string   InpPair20_SymbolA = "CADCHF";    // Pair 20: Symbol A
input string   InpPair20_SymbolB = "CADJPY";    // Pair 20: Symbol B

input bool     InpEnablePair21 = false;         // Enable Pair 21
input string   InpPair21_SymbolA = "AUDCHF";    // Pair 21: Symbol A
input string   InpPair21_SymbolB = "NZDCHF";    // Pair 21: Symbol B

input bool     InpEnablePair22 = false;         // Enable Pair 22
input string   InpPair22_SymbolA = "GBPJPY";    // Pair 22: Symbol A
input string   InpPair22_SymbolB = "EURJPY";    // Pair 22: Symbol B

input bool     InpEnablePair23 = false;         // Enable Pair 23
input string   InpPair23_SymbolA = "NZDCAD";    // Pair 23: Symbol A
input string   InpPair23_SymbolB = "AUDCAD";    // Pair 23: Symbol B

input bool     InpEnablePair24 = false;         // Enable Pair 24
input string   InpPair24_SymbolA = "EURNZD";    // Pair 24: Symbol A
input string   InpPair24_SymbolB = "GBPNZD";    // Pair 24: Symbol B

input group "=== Group 4 Target Settings (v2.0) ==="
input double   InpGroup4ClosedTarget = 0;       // Basket Closed Profit Target $ (0=Disable)
input double   InpGroup4FloatingTarget = 0;     // Basket Floating Profit Target $ (0=Disable)
input int      InpGroup4MaxOrderBuy = 5;        // Total Max Orders Buy (Hard Cap: Main + All Grids)
input int      InpGroup4MaxOrderSell = 5;       // Total Max Orders Sell (Hard Cap: Main + All Grids)
input double   InpGroup4TargetBuy = 10.0;       // Default Target (Buy Side) $
input double   InpGroup4TargetSell = 10.0;      // Default Target (Sell Side) $

input group "=== Mini Group Targets (M10-M12) ==="
input double   InpMini10Target = 0;             // Mini 10 (Pair 19-20) Target $ (0=Disable)
input double   InpMini11Target = 0;             // Mini 11 (Pair 21-22) Target $ (0=Disable)
input double   InpMini12Target = 0;             // Mini 12 (Pair 23-24) Target $ (0=Disable)

input group "=== Pair 25-30 Configuration (Group 5) ==="
input bool     InpEnablePair25 = false;         // Enable Pair 25
input string   InpPair25_SymbolA = "NZDJPY";    // Pair 25: Symbol A
input string   InpPair25_SymbolB = "CADJPY";    // Pair 25: Symbol B

input bool     InpEnablePair26 = false;         // Enable Pair 26
input string   InpPair26_SymbolA = "AUDSGD";    // Pair 26: Symbol A
input string   InpPair26_SymbolB = "NZDSGD";    // Pair 26: Symbol B

input bool     InpEnablePair27 = false;         // Enable Pair 27
input string   InpPair27_SymbolA = "USDSGD";    // Pair 27: Symbol A
input string   InpPair27_SymbolB = "USDCNH";    // Pair 27: Symbol B

input bool     InpEnablePair28 = false;         // Enable Pair 28
input string   InpPair28_SymbolA = "EURPLN";    // Pair 28: Symbol A
input string   InpPair28_SymbolB = "USDPLN";    // Pair 28: Symbol B

input bool     InpEnablePair29 = false;         // Enable Pair 29
input string   InpPair29_SymbolA = "USDZAR";    // Pair 29: Symbol A
input string   InpPair29_SymbolB = "EURZAR";    // Pair 29: Symbol B

input bool     InpEnablePair30 = false;         // Enable Pair 30
input string   InpPair30_SymbolA = "USDMXN";    // Pair 30: Symbol A
input string   InpPair30_SymbolB = "EURMXN";    // Pair 30: Symbol B

input group "=== Group 5 Target Settings (v2.0) ==="
input double   InpGroup5ClosedTarget = 0;       // Basket Closed Profit Target $ (0=Disable)
input double   InpGroup5FloatingTarget = 0;     // Basket Floating Profit Target $ (0=Disable)
input int      InpGroup5MaxOrderBuy = 5;        // Total Max Orders Buy (Hard Cap: Main + All Grids)
input int      InpGroup5MaxOrderSell = 5;       // Total Max Orders Sell (Hard Cap: Main + All Grids)
input double   InpGroup5TargetBuy = 10.0;       // Default Target (Buy Side) $
input double   InpGroup5TargetSell = 10.0;      // Default Target (Sell Side) $

input group "=== Mini Group Targets (M13-M15) ==="
input double   InpMini13Target = 0;             // Mini 13 (Pair 25-26) Target $ (0=Disable)
input double   InpMini14Target = 0;             // Mini 14 (Pair 27-28) Target $ (0=Disable)
input double   InpMini15Target = 0;             // Mini 15 (Pair 29-30) Target $ (0=Disable)
input string   InpLicenseServer = LICENSE_BASE_URL;    // License Server URL
input int      InpLicenseCheckMinutes = 60;            // License Check Interval (minutes)
input int      InpDataSyncMinutes = 5;                 // Data Sync Interval (minutes)

input group "=== News Filter ==="
input bool     InpEnableNewsFilter = true;      // Enable News Filter
input int      InpNewsBeforeMinutes = 30;       // Minutes Before News
input int      InpNewsAfterMinutes = 30;        // Minutes After News

input group "=== Dashboard Theme (v1.8.5) ==="
input ENUM_THEME_MODE InpThemeMode = THEME_DARK;    // Dashboard Theme

input group "=== Entry Mode Settings (v1.8.8) ==="
input ENUM_ENTRY_MODE InpEntryMode = ENTRY_MODE_ZSCORE;    // Entry Mode
input double   InpCorrOnlyPositiveThreshold = 0.60;        // Correlation Only: Positive Threshold (0.60 = 60%)
input double   InpCorrOnlyNegativeThreshold = -0.60;       // Correlation Only: Negative Threshold (-0.60 = -60%)
// v2.1.7: NEW - Option to skip filters for immediate entry
input bool     InpCorrOnlySkipADXCheck = false;            // Correlation Only: Skip ADX Check (Neg Corr)
input bool     InpCorrOnlySkipRSICheck = false;            // Correlation Only: Skip RSI Confirmation

input group "=== Total Basket Target (v1.8.7) ==="
input bool     InpEnableTotalBasket = false;        // Enable Total Basket Close (All Groups)
input double   InpTotalBasketTarget = 500.0;        // Total Basket Target ($) - Close ALL when hit

//+------------------------------------------------------------------+
//| LICENSE STATUS ENUM (v3.6.5)                                       |
//+------------------------------------------------------------------+
enum ENUM_LICENSE_STATUS
{
   LICENSE_VALID,           // License valid
   LICENSE_EXPIRING_SOON,   // License expiring within 7 days
   LICENSE_EXPIRED,         // License expired
   LICENSE_NOT_FOUND,       // Account not registered
   LICENSE_SUSPENDED,       // License suspended
   LICENSE_ERROR            // Connection error
};

//+------------------------------------------------------------------+
//| SYNC EVENT TYPE ENUM (v3.6.5)                                      |
//+------------------------------------------------------------------+
enum ENUM_SYNC_EVENT
{
   SYNC_SCHEDULED,          // Scheduled sync
   SYNC_ORDER_OPEN,         // Order opened
   SYNC_ORDER_CLOSE         // Order closed
};

//+------------------------------------------------------------------+
//| GROUP TARGET STRUCTURE (v1.1)                                      |
//+------------------------------------------------------------------+
struct GroupTarget
{
   double closedProfit;        // Accumulated closed profit for this group
   double floatingProfit;      // Current floating profit
   double totalProfit;         // Closed + Floating
   
   // Settings from inputs
   double closedTarget;        // Target closed+floating
   double floatingTarget;      // Floating-only target
   int    maxOrderBuy;         // Max orders buy for pairs in this group
   int    maxOrderSell;        // Max orders sell for pairs in this group
   double targetBuy;           // Per-side target buy
   double targetSell;          // Per-side target sell
   
   // Control flags
   bool   targetTriggered;     // Prevent multiple triggers
   bool   closeMode;           // TRUE when group is closing all
};

//+------------------------------------------------------------------+
//| v2.0: MINI GROUP STRUCTURE (2 pairs per mini, numbered 1-15)       |
//+------------------------------------------------------------------+
struct MiniGroupData
{
   double closedProfit;        // Accumulated closed profit
   double floatingProfit;      // Current floating profit
   double totalProfit;         // Closed + Floating
   double closedTarget;        // Target for auto-close (from input)
   bool   targetTriggered;     // Prevent multiple triggers
};

MiniGroupData g_miniGroups[MAX_MINI_GROUPS];
CTrade g_trade;
bool g_isLicenseValid = false;
bool g_isNewsPaused = false;
bool g_isPaused = false;

// === v3.6.8: EA Status for Admin Dashboard ===
string            g_eaStatus = "initializing";     // v1.6.1: Default to initializing (not Working)

// === v3.6.5: License System Variables ===
ENUM_LICENSE_STATUS g_licenseStatus = LICENSE_ERROR;
string            g_customerName = "";
string            g_packageType = "";
string            g_tradingSystem = "";
datetime          g_expiryDate = 0;
int               g_daysRemaining = 0;
bool              g_isLifetime = false;
string            g_lastLicenseError = "";
datetime          g_lastLicenseCheck = 0;
datetime          g_lastDataSync = 0;
datetime          g_lastExpiryPopup = 0;
string            g_licenseServerUrl = "";
int               g_licenseCheckInterval = 60;
int               g_dataSyncInterval = 5;
datetime g_lastCandleTime = 0;
datetime g_lastCorrUpdate = 0;

// === v3.76: Heartbeat Sync Variables ===
datetime          g_lastHeartbeat = 0;            // Last heartbeat sync time
datetime          g_lastSuccessfulSync = 0;       // Last successful sync time (for dashboard display)
int               g_syncFailCount = 0;            // Consecutive sync failure counter
string            g_lastSyncStatus = "Pending";   // "OK", "Failed", "Pending"

// Pairs Data
PairInfo g_pairs[MAX_PAIRS];
PairData g_pairData[MAX_PAIRS];
int g_activePairs = 0;

// Target System (v3.0)
double g_totalTarget = 100.0;
double g_totalCurrentProfit = 0;

// Account Statistics
double g_initialBalance = 0;
double g_maxEquity = 0;
double g_dailyProfit = 0;
double g_weeklyProfit = 0;
double g_monthlyProfit = 0;
datetime g_dayStart = 0;
datetime g_weekStart = 0;
datetime g_monthStart = 0;

// Dashboard Statistics
double g_dailyLot = 0;
double g_weeklyLot = 0;
double g_monthlyLot = 0;
double g_allTimeLot = 0;
double g_allTimeProfit = 0;
double g_maxDrawdownPercent = 0;

// v3.3.0: Closed Order Counts
int g_dailyClosedOrders = 0;
int g_weeklyClosedOrders = 0;
int g_monthlyClosedOrders = 0;
int g_allTimeClosedOrders = 0;

// Dashboard Colors (from theme - v1.8.5)
color COLOR_BG_DARK;
color COLOR_BG_ROW_ODD;
color COLOR_BG_ROW_EVEN;
color COLOR_HEADER_MAIN;
color COLOR_HEADER_BUY;
color COLOR_HEADER_SELL;
color COLOR_HEADER_TXT = clrWhite;
color COLOR_TEXT;                           // v1.8.5: Theme-based text color
color COLOR_TEXT_WHITE = clrWhite;
color COLOR_PROFIT;
color COLOR_LOSS;
color COLOR_ON;
color COLOR_OFF;
color COLOR_GOLD;                           // v1.8.5: Theme-based gold
color COLOR_ACTIVE;                         // v1.8.5: Theme-based active
color COLOR_BORDER;                         // v1.8.5: Theme-based border

// v1.8.5: Extended Theme Colors
color COLOR_TITLE_BG;
color COLOR_BOX_BG;
color COLOR_HEADER_GROUP;
color COLOR_COLHDR_BUY;
color COLOR_COLHDR_CENTER;
color COLOR_COLHDR_SELL;
color COLOR_COLHDR_GROUP;

// v2.1.2: Mini Group specific colors (distinct from Group Info)
color COLOR_HEADER_MINI;
color COLOR_COLHDR_MINI;
color COLOR_MINI_BG;
color COLOR_MINI_BORDER;

// v1.8.7: Theme-aware label color for bottom sections
color COLOR_TEXT_LABEL;

// Dashboard Dimensions (from inputs)
int PANEL_X;
int PANEL_Y;
int PANEL_WIDTH;
int PANEL_HEIGHT;
int ROW_HEIGHT;
int FONT_SIZE;

// v3.2.5: Fast Backtest Mode Variables
bool g_isTesterMode = false;
bool g_dashboardEnabled = true;
datetime g_lastTesterDashboardUpdate = 0;
datetime g_lastTesterLogTime = 0;

// v3.2.7: Auto-Resume System
string g_pauseReason = "";           // Reason for pause (DD_LIMIT, MANUAL, etc.)
double g_equityAtDDClose = 0;        // Equity when DD triggered

// v3.2.7: Z-Score Grid Levels (Grid Loss)
double g_zScoreGridLevels[MAX_AVG_LEVELS];
int g_zScoreGridCount = 0;

// v3.6.0: Z-Score Grid Levels (Grid Profit)
double g_profitZScoreGridLevels[MAX_AVG_LEVELS];
int g_profitZScoreGridCount = 0;

// v3.2.7: Batch Processing
int g_currentPairIndex = 0;

// ATR Handle for averaging
int g_atrHandle = INVALID_HANDLE;

// v3.2.8: Ultra Fast Mode tick counter
int g_tickCounter = 0;

// v3.3.0: Separate Z-Score timeframe tracking
datetime g_lastZScoreUpdate = 0;

// v1.6.4: Z-Score Update Display (actual update time, not candle time)
datetime g_lastZScoreUpdateDisplay = 0;

// v1.6.7: Z-Score Current Bar Mode Timer
datetime g_lastZScoreCurrentUpdate = 0;

// v3.5.0: CDC Action Zone timeframe tracking
// v3.7.2: Last CDC status per pair (for log spam prevention)
string g_lastCDCStatus[];
datetime g_lastCDCUpdate = 0;

// v1.6.2: CDC Initial-Only Retry Timer (per pair)
datetime g_lastCDCRetryTime[];

// v1.6.3: History download attempt tracking
bool g_historyLoadAttempted[];

// === v1.1: Group Target System (replaces single Basket) ===
GroupTarget g_groups[MAX_GROUPS];

// Legacy basket variables (for backward compatibility in functions)
double g_basketClosedProfit = 0;      // Total across all groups (for stats display)
double g_basketFloatingProfit = 0;    // Total floating across all groups
double g_basketTotalProfit = 0;       // Total profit across all groups

// v1.8.7 HF2: Accumulated profit from groups that have already closed their targets
double g_accumulatedBasketProfit = 0;   // Preserved when individual group closes

// === v3.6.0 HF3 Patch 3: Separate Flags for Different Purposes ===
bool   g_orphanCheckPaused = false;   // Pause orphan check during any position closing operation

// === v1.3: Log Throttling (sync from v3.81) ===
datetime g_lastProfitLogTime = 0;
int PROFIT_LOG_INTERVAL = 5;  // Log every 5 seconds

//+------------------------------------------------------------------+
//| v1.8.5: Initialize Theme Colors                                    |
//+------------------------------------------------------------------+
void InitializeThemeColors()
{
   if(InpThemeMode == THEME_LIGHT)
   {
      // === LIGHT MODE COLOR PALETTE ===
      COLOR_BG_DARK      = C'245,247,250';      // Light Gray Background
      COLOR_BG_ROW_ODD   = C'255,255,255';      // White
      COLOR_BG_ROW_EVEN  = C'240,242,245';      // Very Light Gray
      COLOR_HEADER_MAIN  = C'80,100,140';       // Muted Blue
      COLOR_HEADER_BUY   = C'30,110,180';       // Professional Blue
      COLOR_HEADER_SELL  = C'180,50,60';        // Professional Red
      COLOR_PROFIT       = C'0,150,80';         // Dark Green
      COLOR_LOSS         = C'200,40,50';        // Dark Red
      COLOR_ON           = C'0,160,100';        // Teal Green
      COLOR_OFF          = C'140,145,155';      // Medium Gray
      
      // Additional Light Mode colors
      COLOR_TEXT         = C'30,35,45';         // Dark Text
      COLOR_GOLD         = C'200,150,0';        // Dark Gold
      COLOR_ACTIVE       = C'30,120,200';       // Blue
      COLOR_BORDER       = C'200,205,215';      // Light Border
      COLOR_HEADER_TXT   = clrWhite;            // Keep white for headers
      
      // Extended colors for Dashboard elements
      COLOR_TITLE_BG     = C'74,96,128';        // Slate Blue
      COLOR_BOX_BG       = C'232,235,240';      // Subtle Gray
      COLOR_HEADER_GROUP = C'107,90,133';       // Muted Purple
      COLOR_COLHDR_BUY   = C'30,110,180';       // Professional Blue
      COLOR_COLHDR_CENTER= C'80,100,140';       // Muted Blue
      COLOR_COLHDR_SELL  = C'180,50,60';        // Professional Red
      COLOR_COLHDR_GROUP = C'90,75,110';        // Light Purple
      
      // v2.1.2: Mini Group specific colors (distinct blue)
      COLOR_HEADER_MINI  = C'50,80,140';        // Medium Blue Header
      COLOR_COLHDR_MINI  = C'60,90,150';        // Column Header Blue
      COLOR_MINI_BG      = C'210,225,245';      // Light Blue Row Background
      COLOR_MINI_BORDER  = C'100,130,180';      // Blue Border
      
      // v1.8.7: Dark text for light backgrounds (bottom section labels)
      COLOR_TEXT_LABEL   = C'60,65,75';         // Dark Gray for light backgrounds
   }
   else  // THEME_DARK (Default)
   {
      // === DARK MODE COLOR PALETTE (v1.8.3) ===
      COLOR_BG_DARK      = C'18,24,38';         // Dark Navy
      COLOR_BG_ROW_ODD   = C'28,36,52';         // Dark Slate
      COLOR_BG_ROW_EVEN  = C'22,30,46';         // Darker Slate
      COLOR_HEADER_MAIN  = C'45,55,90';         // Muted Indigo
      COLOR_HEADER_BUY   = C'15,75,135';        // Deep Blue
      COLOR_HEADER_SELL  = C'135,45,55';        // Deep Red
      COLOR_PROFIT       = C'50,205,100';       // Bright Green
      COLOR_LOSS         = C'235,70,80';        // Coral Red
      COLOR_ON           = C'0,200,120';        // Teal Green
      COLOR_OFF          = C'90,100,120';       // Cool Gray
      
      // Additional Dark Mode colors
      COLOR_TEXT         = C'200,210,225';      // Light Gray
      COLOR_GOLD         = C'255,200,60';       // Warm Gold
      COLOR_ACTIVE       = C'70,160,250';       // Sky Blue
      COLOR_BORDER       = C'55,65,85';         // Subtle Border
      COLOR_HEADER_TXT   = clrWhite;            // White headers
      
      // Extended colors for Dashboard elements
      COLOR_TITLE_BG     = C'25,45,70';         // Dark Blue
      COLOR_BOX_BG       = C'28,35,50';         // Dark Box
      COLOR_HEADER_GROUP = C'65,50,95';         // Purple
      COLOR_COLHDR_BUY   = C'20,60,100';        // Darker Blue
      COLOR_COLHDR_CENTER= C'35,42,58';         // Dark Center
      COLOR_COLHDR_SELL  = C'100,45,50';        // Dark Red
      COLOR_COLHDR_GROUP = C'50,40,70';         // Dark Purple
      
      // v2.1.2: Mini Group specific colors (distinct blue)
      COLOR_HEADER_MINI  = C'25,45,80';         // Dark Blue Header
      COLOR_COLHDR_MINI  = C'30,50,90';         // Column Header Blue
      COLOR_MINI_BG      = C'20,35,60';         // Row Background Blue
      COLOR_MINI_BORDER  = C'40,60,100';        // Border Blue
      
      // v1.8.7: Light text for dark backgrounds (bottom section labels)
      COLOR_TEXT_LABEL   = C'180,185,195';      // Light Gray for dark backgrounds
   }
}

//+------------------------------------------------------------------+
//| v1.8.6: Get Symbol Abbreviation for Order Comments                 |
//+------------------------------------------------------------------+
string GetSymbolAbbreviation(string symbol)
{
   // Clean symbol - remove suffix (e.g., EURUSD.i, EURUSDm)
   string cleanSymbol = symbol;
   int dotPos = StringFind(symbol, ".");
   if(dotPos > 0) cleanSymbol = StringSubstr(symbol, 0, dotPos);
   
   // Gold pairs
   if(StringFind(cleanSymbol, "XAUUSD") >= 0) return "XU";
   if(StringFind(cleanSymbol, "XAUEUR") >= 0) return "XE";
   
   // Major pairs - use first letters of each currency
   if(StringFind(cleanSymbol, "EURUSD") >= 0) return "EU";
   if(StringFind(cleanSymbol, "GBPUSD") >= 0) return "GU";
   if(StringFind(cleanSymbol, "AUDUSD") >= 0) return "AU";
   if(StringFind(cleanSymbol, "NZDUSD") >= 0) return "NU";
   if(StringFind(cleanSymbol, "USDJPY") >= 0) return "UJ";
   if(StringFind(cleanSymbol, "USDCHF") >= 0) return "UC";
   if(StringFind(cleanSymbol, "USDCAD") >= 0) return "UCd";
   
   // Cross pairs
   if(StringFind(cleanSymbol, "EURGBP") >= 0) return "EG";
   if(StringFind(cleanSymbol, "EURJPY") >= 0) return "EJ";
   if(StringFind(cleanSymbol, "EURCHF") >= 0) return "EC";
   if(StringFind(cleanSymbol, "EURAUD") >= 0) return "EA";
   if(StringFind(cleanSymbol, "EURNZD") >= 0) return "EN";
   if(StringFind(cleanSymbol, "EURCAD") >= 0) return "ECd";
   if(StringFind(cleanSymbol, "GBPJPY") >= 0) return "GJ";
   if(StringFind(cleanSymbol, "GBPCHF") >= 0) return "GC";
   if(StringFind(cleanSymbol, "GBPAUD") >= 0) return "GA";
   if(StringFind(cleanSymbol, "GBPNZD") >= 0) return "GN";
   if(StringFind(cleanSymbol, "GBPCAD") >= 0) return "GCd";
   if(StringFind(cleanSymbol, "AUDJPY") >= 0) return "AJ";
   if(StringFind(cleanSymbol, "AUDNZD") >= 0) return "AN";
   if(StringFind(cleanSymbol, "AUDCAD") >= 0) return "ACd";
   if(StringFind(cleanSymbol, "AUDCHF") >= 0) return "AC";
   if(StringFind(cleanSymbol, "NZDJPY") >= 0) return "NJ";
   if(StringFind(cleanSymbol, "NZDCHF") >= 0) return "NC";
   if(StringFind(cleanSymbol, "NZDCAD") >= 0) return "NCd";
   if(StringFind(cleanSymbol, "CADJPY") >= 0) return "CJ";
   if(StringFind(cleanSymbol, "CADCHF") >= 0) return "CC";
   if(StringFind(cleanSymbol, "CHFJPY") >= 0) return "CHJ";
   
   // Fallback: use first 2 characters
   return StringSubstr(cleanSymbol, 0, 2);
}

//+------------------------------------------------------------------+
//| v1.8.6: Get Pair Comment Prefix (e.g., "EU-GU")                    |
//+------------------------------------------------------------------+
string GetPairCommentPrefix(int pairIndex)
{
   string abbrevA = GetSymbolAbbreviation(g_pairs[pairIndex].symbolA);
   string abbrevB = GetSymbolAbbreviation(g_pairs[pairIndex].symbolB);
   return abbrevA + "-" + abbrevB;
}

//+------------------------------------------------------------------+
//| v1.8.6: Get Total Lot for Pair from actual positions               |
//+------------------------------------------------------------------+
double GetTotalLotForPair(int pairIndex, bool isBuySide)
{
   double totalLot = 0;
   string pairPrefix = GetPairCommentPrefix(pairIndex);
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      
      string comment = PositionGetString(POSITION_COMMENT);
      long magic = PositionGetInteger(POSITION_MAGIC);
      
      if(magic != InpMagicNumber) continue;
      
      // Check if comment starts with pair prefix
      if(StringFind(comment, pairPrefix) < 0) continue;
      
      // Check Buy/Sell side
      if(isBuySide && StringFind(comment, "_BUY") < 0) continue;
      if(!isBuySide && StringFind(comment, "_SELL") < 0) continue;
      
      totalLot += PositionGetDouble(POSITION_VOLUME);
   }
   
   return totalLot;
}

//+------------------------------------------------------------------+
//| v3.3.0: Get Z-Score Timeframe (independent from Correlation)       |
//+------------------------------------------------------------------+
ENUM_TIMEFRAMES GetZScoreTimeframe()
{
   if(InpZScoreTimeframe == PERIOD_CURRENT)
      return InpCorrTimeframe;  // Use correlation timeframe as default
   return InpZScoreTimeframe;
}

//+------------------------------------------------------------------+
//| v3.3.0: Get Z-Score Bars Count                                     |
//+------------------------------------------------------------------+
int GetZScoreBars()
{
   if(InpZScoreBars == 0)
      return InpCorrBars;  // Use correlation bars as default
   return InpZScoreBars;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   // Detect tester mode first
   g_isTesterMode = (bool)MQLInfoInteger(MQL_TESTER);
   
   // v3.2.5: Configure dashboard based on tester mode
   if(g_isTesterMode)
   {
      if(InpDisableDashboardInTester)
      {
         g_dashboardEnabled = false;
         Print("Dashboard DISABLED for faster backtesting");
      }
      
      if(InpFastBacktest)
      {
         Print("Fast Backtest Mode ENABLED - UI updates every ", InpBacktestUiUpdateSec, " seconds");
      }
   }
   
   // v1.8.5: Initialize theme colors
   InitializeThemeColors();
   
   // Dashboard dimensions
   PANEL_X = InpPanelX;
   PANEL_Y = InpPanelY;
   PANEL_WIDTH = InpPanelWidth;
   PANEL_HEIGHT = InpPanelHeight;
   ROW_HEIGHT = InpRowHeight;
   FONT_SIZE = InpFontSize;
   
   // Setup trade object
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(InpSlippage);
   g_trade.SetTypeFilling(ORDER_FILLING_IOC);
   
   // v1.1: Initialize Group Target System (must be before InitializePairs)
   InitializeGroups();
   
   // Initialize pairs
   if(!InitializePairs())
   {
      Print("ERROR: No valid pairs configured!");
      return INIT_FAILED;
   }
   
   // v3.2.7: Warmup symbol data for backtesting
   if(g_isTesterMode)
   {
      WarmupSymbolData();
   }
   
   // v3.2.7: Parse Z-Score Grid levels (Grid Loss Side)
   ParseZScoreGrid(InpGridLossZScoreLevels, g_zScoreGridLevels, g_zScoreGridCount);
   
   // v3.6.0: Parse Z-Score Grid levels (Grid Profit Side)
   ParseZScoreGrid(InpGridProfitZScoreLevels, g_profitZScoreGridLevels, g_profitZScoreGridCount);
   
   // v3.6.0: Initialize ATR handle if needed (for Grid Distance calculations)
   bool needsATR = (InpGridLossDistMode == GRID_DIST_ATR) || (InpGridProfitDistMode == GRID_DIST_ATR);
   if(needsATR)
   {
      if(!(g_isTesterMode && InpSkipATRInTester))
      {
         g_atrHandle = iATR(_Symbol, InpGridATRTimeframe, InpGridATRPeriod);
         if(g_atrHandle == INVALID_HANDLE)
         {
            Print("Warning: Could not create ATR handle for grid system");
         }
      }
      else
      {
         Print("ATR Indicator SKIPPED in Tester for faster backtesting");
      }
   }
   
   // ========== v2.1.8: Force License Reload on TF Change ==========
   Print("=================================================");
   Print("[v2.1.8] EA Restarted - Reloading License...");
   Print("[v2.1.8] Reason: Timeframe Change / Chart Reload");
   Print("=================================================");
   
   // Reset license variables BEFORE verify
   g_isLicenseValid = false;
   g_licenseStatus = LICENSE_ERROR;
   g_lastLicenseCheck = 0;
   // ================================================================
   
   // Verify license
   g_isLicenseValid = VerifyLicense();
   if(!g_isLicenseValid)
   {
      Print("License verification failed - EA will not trade");
   }
   
   // v1.6.1: Force update EA status after license check
   UpdateEAStatus();
   
   // Initialize account tracking
   g_initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_maxEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_dayStart = TimeCurrent();
   g_weekStart = TimeCurrent();
   g_monthStart = TimeCurrent();
   
   // Force initial data update for all pairs
   UpdateAllPairData();
   
   // v3.3.0: Force initial Z-Score data update (may use different TF)
   UpdateZScoreData();
   
   // v3.7.2: Initialize CDC status tracking array
   ArrayResize(g_lastCDCStatus, MAX_PAIRS);
   for(int i = 0; i < MAX_PAIRS; i++)
      g_lastCDCStatus[i] = "";
   
   // v3.7.1: Force initial CDC calculation and initialize per-symbol tracking
   if(InpUseCDCTrendFilter)
   {
      for(int i = 0; i < MAX_PAIRS; i++)
      {
         if(!g_pairs[i].enabled) continue;
         
         // Initialize lastCdcTime for each symbol
         g_pairs[i].lastCdcTimeA = iTime(g_pairs[i].symbolA, InpCDCTimeframe, 0);
         g_pairs[i].lastCdcTimeB = iTime(g_pairs[i].symbolB, InpCDCTimeframe, 0);
         
         // Force initial CDC calculation
         g_pairs[i].cdcReadyA = CalculateCDCForSymbol(
            g_pairs[i].symbolA,
            g_pairs[i].cdcTrendA,
            g_pairs[i].cdcFastA,
            g_pairs[i].cdcSlowA
         );
         g_pairs[i].cdcReadyB = CalculateCDCForSymbol(
            g_pairs[i].symbolB,
            g_pairs[i].cdcTrendB,
            g_pairs[i].cdcFastB,
            g_pairs[i].cdcSlowB
         );
         
         if(InpDebugMode)
            PrintFormat("[OnInit] Pair %d CDC Init: A=%s(%s) B=%s(%s)", 
                        i + 1, 
                        g_pairs[i].symbolA, g_pairs[i].cdcReadyA ? g_pairs[i].cdcTrendA : "LOADING",
                        g_pairs[i].symbolB, g_pairs[i].cdcReadyB ? g_pairs[i].cdcTrendB : "LOADING");
      }
      Print("[OnInit] CDC Action Zone initialized for all pairs");
   }
   
   // v3.3.5: Force lot recalculation after data is loaded with delay for symbol info
   Sleep(100);  // Wait 100ms for symbol data to be available
   
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(g_pairs[i].enabled)
      {
         CalculateDollarNeutralLots(i);
         
         // Verify calculation succeeded - if lots are too small, use InpBaseLot
         double minReasonableLot = InpBaseLot * 0.1;
         if(g_pairs[i].lotBuyA < minReasonableLot)
         {
            PrintFormat("WARNING Pair %d: Initial lot calculation failed (lotA=%.4f) - using InpBaseLot %.2f", 
                        i + 1, g_pairs[i].lotBuyA, InpBaseLot);
            g_pairs[i].lotBuyA = NormalizeLot(g_pairs[i].symbolA, InpBaseLot);
            g_pairs[i].lotBuyB = NormalizeLot(g_pairs[i].symbolB, InpBaseLot);
            g_pairs[i].lotSellA = g_pairs[i].lotBuyA;
            g_pairs[i].lotSellB = g_pairs[i].lotBuyB;
         }
      }
   }
   
   // v3.2.5: Only set timer in non-fast-backtest mode
   if(!g_isTesterMode || !InpFastBacktest)
   {
      EventSetTimer(1);
   }
   
   // Debug output for enabled pairs
   if(InpDebugMode && (!g_isTesterMode || !InpDisableDebugInTester))
   {
      Print("================================");
      Print("Enabled Pairs Configuration:");
      for(int i = 0; i < MAX_PAIRS; i++)
      {
         if(g_pairs[i].enabled)
         {
            PrintFormat("Pair %02d: %s - %s | Data: %s | Corr: %.2f%%", 
                        i + 1, 
                        g_pairs[i].symbolA, 
                        g_pairs[i].symbolB,
                        g_pairs[i].dataValid ? "OK" : "N/A",
                        g_pairs[i].correlation * 100);
         }
      }
      Print("================================");
      // v3.3.0: Log Z-Score settings
      PrintFormat("Z-Score TF: %s, Bars: %d (Correlation TF: %s, Bars: %d)",
                  EnumToString(GetZScoreTimeframe()), GetZScoreBars(),
                  EnumToString(InpCorrTimeframe), InpCorrBars);
   }
   PrintFormat("Total Enabled Pairs: %d", g_activePairs);
   
   // v3.2.5: Create dashboard based on mode
   if(g_dashboardEnabled)
   {
      CreateDashboard();
   }
   
   // v1.3: Restore open positions from previous session (Magic Number-based)
   RestoreOpenPositions();
   
   // v1.6.2: Initialize CDC Retry timer array
   ArrayResize(g_lastCDCRetryTime, MAX_PAIRS);
   ArrayInitialize(g_lastCDCRetryTime, 0);
   
   // v1.6.3: Initialize history load tracking
   ArrayResize(g_historyLoadAttempted, MAX_PAIRS * 2);  // 2 symbols per pair
   ArrayInitialize(g_historyLoadAttempted, false);
   
   // v1.6.3: Pre-load history for all enabled pairs at startup
   if(InpUseCDCTrendFilter)
   {
      int minBars = InpCDCSlowPeriod + 10;
      PrintFormat("[INIT] Pre-loading %s history for CDC filter (%d pairs)...", 
                  EnumToString(InpCDCTimeframe), g_activePairs);
      
      for(int i = 0; i < MAX_PAIRS; i++)
      {
         if(!g_pairs[i].enabled) continue;
         
         // Pre-load Symbol A
         EnsureHistoryLoaded(g_pairs[i].symbolA, InpCDCTimeframe, minBars);
         
         // Pre-load Symbol B
         EnsureHistoryLoaded(g_pairs[i].symbolB, InpCDCTimeframe, minBars);
      }
      
      Print("[INIT] History pre-load request sent. CDC will retry every 5s if needed.");
   }
   
   // v1.8.9: Force immediate P/L and Z-Score calculation after restore
   // This prevents "Pending" state and ensures P/L displays correctly
   UpdateZScoreData();
   g_lastZScoreUpdateDisplay = TimeCurrent();
   CalculateAllRSIonSpread();
   UpdatePairProfits();
   // Note: No UpdateGroupProfits() function exists in this EA version;
   // UpdatePairProfits() already refreshes totals used by the dashboard.
   
   PrintFormat("=== Harmony Dream EA v2.1.8 Initialized - %d Active Pairs | Net Profit Mode ===", g_activePairs);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| v2.1.8: Extract Pair Index from Order Comment                      |
//| Returns 0-based pair index, or -1 if not found/invalid             |
//| Supports: "AU-AJ_BUY_26[M:888888]", "HrmDream_SELL_12", etc.       |
//+------------------------------------------------------------------+
int ExtractPairIndexFromComment(string comment)
{
   // Try to find pattern: "_BUY_XX" or "_SELL_XX" or "_GL#N_BUY_XX" etc.
   // where XX is the pair number (1-based)
   
   int buyPos = StringFind(comment, "_BUY_");
   int sellPos = StringFind(comment, "_SELL_");
   
   int sidePos = (buyPos >= 0) ? buyPos : sellPos;
   if(sidePos < 0) return -1;
   
   // Find the number after "_BUY_" or "_SELL_"
   int numStart = sidePos + 5;  // Skip "_BUY_" (5 chars)
   if(sellPos >= 0 && buyPos < 0) numStart = sellPos + 6;  // Skip "_SELL_" (6 chars)
   
   // Extract digits until non-digit
   string numStr = "";
   for(int i = numStart; i < StringLen(comment); i++)
   {
      ushort ch = StringGetCharacter(comment, i);
      if(ch >= '0' && ch <= '9')
         numStr += CharToString((uchar)ch);
      else
         break;
   }
   
   if(numStr == "") return -1;
   
   int pairNum = (int)StringToInteger(numStr);
   if(pairNum < 1 || pairNum > MAX_PAIRS) return -1;
   
   return pairNum - 1;  // Convert to 0-based index
}

//+------------------------------------------------------------------+
//| v1.4: Check if Comment is a MAIN order (not Grid)                  |
//| Main comments: "HrmDream_BUY_X" or "HrmDream_SELL_X"               |
//| Grid comments contain: "_GL_", "_GP_", "_AVG_"                     |
//+------------------------------------------------------------------+
bool IsMainComment(string comment, string side, int pairIndex)
{
   // v1.8.9: Support BOTH legacy and new comment format
   
   // Format 1 (Legacy): HrmDream_BUY_1
   string legacyPrefix = StringFormat("HrmDream_%s_%d", side, pairIndex + 1);
   
   // Format 2 (New v1.8.6+): EU-GU_BUY_1
   string newPrefix = GetPairCommentPrefix(pairIndex);
   string newSuffix = StringFormat("_%s_%d", side, pairIndex + 1);
   
   bool matchLegacy = (StringFind(comment, legacyPrefix) == 0);
   bool matchNew = (StringFind(comment, newPrefix) == 0 && 
                    StringFind(comment, newSuffix) >= 0);
   
   if(!matchLegacy && !matchNew)
      return false;
   
   // Must NOT contain grid identifiers
   if(StringFind(comment, "_GL") >= 0) return false;
   if(StringFind(comment, "_GP") >= 0) return false;
   if(StringFind(comment, "_AVG_") >= 0) return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| v1.4: Check if Comment is a GRID order                             |
//+------------------------------------------------------------------+
bool IsGridComment(string comment, string side, int pairIndex)
{
   // v1.8.9: Support BOTH legacy and new comment format
   string pairStr = IntegerToString(pairIndex + 1);
   string newPrefix = GetPairCommentPrefix(pairIndex);
   
   // Legacy format: HrmDream_GL_BUY_1
   if(StringFind(comment, "HrmDream_GL_" + side + "_" + pairStr) >= 0) return true;
   if(StringFind(comment, "HrmDream_GP_" + side + "_" + pairStr) >= 0) return true;
   if(StringFind(comment, "HrmDream_AVG_" + side + "_" + pairStr) >= 0) return true;
   
   // New format: EU-GU_GL#1_BUY_1 หรือ EU-GU_GP#1_BUY_1
   string sideSuffix = "_" + side + "_" + pairStr;
   if(StringFind(comment, newPrefix + "_GL") >= 0 && 
      StringFind(comment, sideSuffix) >= 0) return true;
   if(StringFind(comment, newPrefix + "_GP") >= 0 && 
      StringFind(comment, sideSuffix) >= 0) return true;
   
   return false;
}

//+------------------------------------------------------------------+
//| v1.4: Find MAIN Position Ticket by Symbol (exclude Grid)           |
//+------------------------------------------------------------------+
ulong FindMainTicketBySymbol(string symbol, string side, int pairIndex)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      
      if(PositionGetString(POSITION_SYMBOL) != symbol) continue;
      
      string comment = PositionGetString(POSITION_COMMENT);
      
      // Must be main comment, NOT grid
      if(IsMainComment(comment, side, pairIndex))
      {
         return ticket;
      }
   }
   return 0;
}

//+------------------------------------------------------------------+
//| v1.4: Find Position Ticket by Symbol and Comment (Fallback)        |
//| Uses prefix matching + excludes grid comments                      |
//+------------------------------------------------------------------+
ulong FindPositionTicketBySymbolAndComment(string symbol, string commentPattern)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      
      if(PositionGetString(POSITION_SYMBOL) != symbol) continue;
      
      string comment = PositionGetString(POSITION_COMMENT);
      
      // v1.4: Must START with commentPattern (prefix match)
      if(StringFind(comment, commentPattern) != 0) continue;
      
      // v1.4: Exclude grid orders from main ticket recovery
      if(StringFind(comment, "_GL_") >= 0) continue;
      if(StringFind(comment, "_GP_") >= 0) continue;
      if(StringFind(comment, "_AVG_") >= 0) continue;
      
      return ticket;
   }
   return 0;
}

//+------------------------------------------------------------------+
//| v1.4: Recover Missing Tickets by Comment Scan (Main Orders Only)   |
//| Uses IsMainComment to prevent Grid tickets from being assigned     |
//+------------------------------------------------------------------+
void RecoverMissingTickets(int pairIndex, string side, string commentPattern)
{
   string symbolA = g_pairs[pairIndex].symbolA;
   string symbolB = g_pairs[pairIndex].symbolB;
   
   bool foundGridNotMain = false;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      
      string symbol = PositionGetString(POSITION_SYMBOL);
      string comment = PositionGetString(POSITION_COMMENT);
      
      // v1.4: SANITY CHECK - Must be a MAIN comment, NOT a Grid comment
      if(!IsMainComment(comment, side, pairIndex))
      {
         // Check if this is a Grid ticket that would have matched with old logic
         if(IsGridComment(comment, side, pairIndex) && 
            (symbol == symbolA || symbol == symbolB))
         {
            foundGridNotMain = true;
         }
         continue;  // Skip grid orders
      }
      
      if(side == "SELL")
      {
         if(symbol == symbolA && g_pairs[pairIndex].ticketSellA == 0)
         {
            g_pairs[pairIndex].ticketSellA = ticket;
            g_pairs[pairIndex].lotSellA = PositionGetDouble(POSITION_VOLUME);
            PrintFormat("[v1.4 RECOVERED] Pair %d SELL SymbolA: %s ticket=%d comment='%s'", 
                        pairIndex + 1, symbol, ticket, comment);
         }
         else if(symbol == symbolB && g_pairs[pairIndex].ticketSellB == 0)
         {
            g_pairs[pairIndex].ticketSellB = ticket;
            g_pairs[pairIndex].lotSellB = PositionGetDouble(POSITION_VOLUME);
            PrintFormat("[v1.4 RECOVERED] Pair %d SELL SymbolB: %s ticket=%d comment='%s'", 
                        pairIndex + 1, symbol, ticket, comment);
         }
      }
      else if(side == "BUY")
      {
         if(symbol == symbolA && g_pairs[pairIndex].ticketBuyA == 0)
         {
            g_pairs[pairIndex].ticketBuyA = ticket;
            g_pairs[pairIndex].lotBuyA = PositionGetDouble(POSITION_VOLUME);
            PrintFormat("[v1.4 RECOVERED] Pair %d BUY SymbolA: %s ticket=%d comment='%s'", 
                        pairIndex + 1, symbol, ticket, comment);
         }
         else if(symbol == symbolB && g_pairs[pairIndex].ticketBuyB == 0)
         {
            g_pairs[pairIndex].ticketBuyB = ticket;
            g_pairs[pairIndex].lotBuyB = PositionGetDouble(POSITION_VOLUME);
            PrintFormat("[v1.4 RECOVERED] Pair %d BUY SymbolB: %s ticket=%d comment='%s'", 
                        pairIndex + 1, symbol, ticket, comment);
         }
      }
   }
   
   // v1.4: WARN if we found Grid tickets but no Main tickets
   if(foundGridNotMain)
   {
      if(side == "BUY" && (g_pairs[pairIndex].ticketBuyA == 0 || g_pairs[pairIndex].ticketBuyB == 0))
      {
         PrintFormat("[v1.4 WARN] Pair %d BUY: Found Grid tickets but NO Main ticket! A=%d B=%d",
                     pairIndex + 1, g_pairs[pairIndex].ticketBuyA, g_pairs[pairIndex].ticketBuyB);
      }
      else if(side == "SELL" && (g_pairs[pairIndex].ticketSellA == 0 || g_pairs[pairIndex].ticketSellB == 0))
      {
         PrintFormat("[v1.4 WARN] Pair %d SELL: Found Grid tickets but NO Main ticket! A=%d B=%d",
                     pairIndex + 1, g_pairs[pairIndex].ticketSellA, g_pairs[pairIndex].ticketSellB);
      }
   }
}

//+------------------------------------------------------------------+
//| v1.3: Restore Open Positions on EA Restart (Fixed)                 |
//+------------------------------------------------------------------+
void RestoreOpenPositions()
{
   int restoredBuy = 0;
   int restoredSell = 0;
   
   Print("[v1.4] Scanning for existing positions with Magic Number: ", InpMagicNumber);
   
   for(int pos = PositionsTotal() - 1; pos >= 0; pos--)
   {
      ulong ticket = PositionGetTicket(pos);
      if(!PositionSelectByTicket(ticket)) continue;
      
      long magic = PositionGetInteger(POSITION_MAGIC);
      string symbol = PositionGetString(POSITION_SYMBOL);
      string comment = PositionGetString(POSITION_COMMENT);
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      // Check if this is our order (Magic Number match OR legacy comment match)
      bool isOurOrder = (magic == InpMagicNumber) || 
                        (StringFind(comment, "HrmDream_") == 0) ||
                        (StringFind(comment, "HrmFlow_") == 0) ||
                        (StringFind(comment, "StatArb_") == 0);
      
      if(!isOurOrder) continue;
      
      // ========== v2.1.8: Extract pair index from comment first ==========
      int commentPairIndex = ExtractPairIndexFromComment(comment);
      // ===================================================================
      
      // Try to match with configured pairs
      for(int i = 0; i < MAX_PAIRS; i++)
      {
         if(!g_pairs[i].enabled) continue;
         
         string symbolA = g_pairs[i].symbolA;
         string symbolB = g_pairs[i].symbolB;
         
         if(symbol != symbolA && symbol != symbolB) continue;
         
         // ========== v2.1.8: Verify pair index matches ==========
         if(commentPairIndex >= 0 && commentPairIndex != i)
         {
            // Comment explicitly specifies a different pair index - skip this pair
            if(InpDebugMode)
            {
               PrintFormat("[v2.1.8] SKIP Pair %d for %s - Comment says Pair %d (comment: %s)",
                           i + 1, symbol, commentPairIndex + 1, comment);
            }
            continue;
         }
         
         // Also verify pair prefix for new format comments (e.g., "AU-AJ_BUY_26")
         string expectedPrefix = GetPairCommentPrefix(i);
         bool hasNewFormat = (StringFind(comment, "-") > 0 && StringFind(comment, "_") > 0);
         if(hasNewFormat && StringFind(comment, expectedPrefix) != 0)
         {
            // New format but prefix doesn't match this pair - skip
            if(InpDebugMode)
            {
               PrintFormat("[v2.1.8] SKIP Pair %d - Prefix mismatch: Expected '%s', Got '%s'",
                           i + 1, expectedPrefix, StringSubstr(comment, 0, 5));
            }
            continue;
         }
         // ========================================================
         
         // Determine if BUY or SELL side based on comment or position type
         bool isBuySide = false;
         bool isSellSide = false;
         
         // Check comment for explicit side indication
         if(StringFind(comment, "_BUY_") >= 0 || StringFind(comment, "GL_BUY") >= 0 || StringFind(comment, "GP_BUY") >= 0)
         {
            isBuySide = true;
         }
         else if(StringFind(comment, "_SELL_") >= 0 || StringFind(comment, "GL_SELL") >= 0 || StringFind(comment, "GP_SELL") >= 0)
         {
            isSellSide = true;
         }
         else
         {
            // Fallback: use position type for Symbol A
            if(symbol == symbolA)
            {
               isBuySide = (posType == POSITION_TYPE_BUY);
               isSellSide = (posType == POSITION_TYPE_SELL);
            }
         }
         
          // v2.1.6: Fixed - Restore BUY side with correct order counting
          if(isBuySide)
          {
             if(g_pairs[i].directionBuy != 1)
             {
                g_pairs[i].directionBuy = 1;  // Set to Active only once
             }
             
             // v2.1.6: Track if this is Main or Grid order
             bool isMainOrder = (StringFind(comment, "_GL") < 0 && StringFind(comment, "_GP") < 0);
             bool shouldCount = false;
             
             // v2.1.6: Restore both symbols but count only once per pair
             if(symbol == symbolA && g_pairs[i].ticketBuyA == 0)
             {
                g_pairs[i].ticketBuyA = ticket;
                g_pairs[i].lotBuyA = PositionGetDouble(POSITION_VOLUME);
                PrintFormat("[v2.1.6] Restored BUY Pair %d SymbolA: %s ticket=%d lot=%.2f", 
                            i + 1, symbol, ticket, PositionGetDouble(POSITION_VOLUME));
                
                // v2.1.6: Count only when restoring Symbol A (main side) for Main orders
                if(isMainOrder) shouldCount = true;
             }
             else if(symbol == symbolB && g_pairs[i].ticketBuyB == 0)
             {
                g_pairs[i].ticketBuyB = ticket;
                g_pairs[i].lotBuyB = PositionGetDouble(POSITION_VOLUME);
                PrintFormat("[v2.1.6] Restored BUY Pair %d SymbolB: %s ticket=%d lot=%.2f", 
                            i + 1, symbol, ticket, PositionGetDouble(POSITION_VOLUME));
                
                // v2.1.6: Only count if Symbol A was NOT restored yet (orphan case)
                if(isMainOrder && g_pairs[i].ticketBuyA == 0) shouldCount = true;
             }
             
             // v2.1.6: Count Grid orders individually (they have _GL or _GP in comment)
             if(!isMainOrder)
             {
                g_pairs[i].orderCountBuy++;
                if(StringFind(comment, "_GL") >= 0)
                   g_pairs[i].avgOrderCountBuy++;
                else if(StringFind(comment, "_GP") >= 0)
                   g_pairs[i].gridProfitCountBuy++;
             }
             else if(shouldCount)
             {
                // v2.1.6: Count main order only once per pair (not per symbol)
                g_pairs[i].orderCountBuy++;
             }
             
             g_pairs[i].entryTimeBuy = (datetime)PositionGetInteger(POSITION_TIME);
             restoredBuy++;
          }
         
          // v2.1.6: Fixed - Restore SELL side with correct order counting
          if(isSellSide)
          {
             if(g_pairs[i].directionSell != 1)
             {
                g_pairs[i].directionSell = 1;  // Set to Active only once
             }
             
             // v2.1.6: Track if this is Main or Grid order
             bool isMainOrderSell = (StringFind(comment, "_GL") < 0 && StringFind(comment, "_GP") < 0);
             bool shouldCountSell = false;
             
             // v2.1.6: Restore both symbols but count only once per pair
             if(symbol == symbolA && g_pairs[i].ticketSellA == 0)
             {
                g_pairs[i].ticketSellA = ticket;
                g_pairs[i].lotSellA = PositionGetDouble(POSITION_VOLUME);
                PrintFormat("[v2.1.6] Restored SELL Pair %d SymbolA: %s ticket=%d lot=%.2f", 
                            i + 1, symbol, ticket, PositionGetDouble(POSITION_VOLUME));
                
                // v2.1.6: Count only when restoring Symbol A (main side) for Main orders
                if(isMainOrderSell) shouldCountSell = true;
             }
             else if(symbol == symbolB && g_pairs[i].ticketSellB == 0)
             {
                g_pairs[i].ticketSellB = ticket;
                g_pairs[i].lotSellB = PositionGetDouble(POSITION_VOLUME);
                PrintFormat("[v2.1.6] Restored SELL Pair %d SymbolB: %s ticket=%d lot=%.2f", 
                            i + 1, symbol, ticket, PositionGetDouble(POSITION_VOLUME));
                
                // v2.1.6: Only count if Symbol A was NOT restored yet (orphan case)
                if(isMainOrderSell && g_pairs[i].ticketSellA == 0) shouldCountSell = true;
             }
             
             // v2.1.6: Count Grid orders individually (they have _GL or _GP in comment)
             if(!isMainOrderSell)
             {
                g_pairs[i].orderCountSell++;
                if(StringFind(comment, "_GL") >= 0)
                   g_pairs[i].avgOrderCountSell++;
                else if(StringFind(comment, "_GP") >= 0)
                   g_pairs[i].gridProfitCountSell++;
             }
             else if(shouldCountSell)
             {
                // v2.1.6: Count main order only once per pair (not per symbol)
                g_pairs[i].orderCountSell++;
             }
             
             g_pairs[i].entryTimeSell = (datetime)PositionGetInteger(POSITION_TIME);
             restoredSell++;
          }
         
         break;  // Found matching pair, move to next position
      }
   }
   
   if(restoredBuy > 0 || restoredSell > 0)
   {
      PrintFormat("[v1.4] Position Restore Complete: BUY=%d SELL=%d positions restored", restoredBuy, restoredSell);
   }
   else
   {
      Print("[v1.4] No existing positions found to restore");
   }
}

//+------------------------------------------------------------------+
//| v3.2.7: Warmup Symbol Data for Backtesting                         |
//+------------------------------------------------------------------+
void WarmupSymbolData()
{
   Print("Starting symbol data warmup for backtesting...");
   int warmupCount = 0;
   
   // v3.3.0: Use max of correlation bars and Z-score bars
   int maxBars = MathMax(InpCorrBars, GetZScoreBars());
   
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(!g_pairs[i].enabled) continue;
      
      double temp[];
      ArrayResize(temp, maxBars + 10);
      
      // Warmup Symbol A data for correlation timeframe
      int copiedA = SafeCopyClose(g_pairs[i].symbolA, InpCorrTimeframe, 0, InpCorrBars, temp);
      
      // Warmup Symbol B data for correlation timeframe
      int copiedB = SafeCopyClose(g_pairs[i].symbolB, InpCorrTimeframe, 0, InpCorrBars, temp);
      
      // v3.3.0: Also warmup for Z-Score timeframe if different
      ENUM_TIMEFRAMES zTF = GetZScoreTimeframe();
      int zBars = GetZScoreBars();
      if(zTF != InpCorrTimeframe)
      {
         SafeCopyClose(g_pairs[i].symbolA, zTF, 0, zBars, temp);
         SafeCopyClose(g_pairs[i].symbolB, zTF, 0, zBars, temp);
      }
      
      // v3.6.0: Warmup ATR timeframe data if different (and ATR not skipped)
      bool needsATR = (InpGridLossDistMode == GRID_DIST_ATR) || (InpGridProfitDistMode == GRID_DIST_ATR);
      if(needsATR && !InpSkipATRInTester)
      {
         if(InpGridATRTimeframe != InpCorrTimeframe)
         {
            SafeCopyClose(g_pairs[i].symbolA, InpGridATRTimeframe, 0, InpGridATRPeriod + 10, temp);
         }
      }
      
      if(copiedA >= InpCorrBars && copiedB >= InpCorrBars)
      {
         warmupCount++;
      }
      else
      {
         PrintFormat("Pair %d warmup incomplete: %s=%d, %s=%d bars (need %d)",
                     i + 1, g_pairs[i].symbolA, copiedA, g_pairs[i].symbolB, copiedB, InpCorrBars);
      }
   }
   
   PrintFormat("Symbol data warmup completed: %d/%d pairs ready", warmupCount, g_activePairs);
}

//+------------------------------------------------------------------+
//| v3.2.7: Safe CopyClose with retry logic                            |
//+------------------------------------------------------------------+
int SafeCopyClose(string symbol, ENUM_TIMEFRAMES tf, int start, int count, double &buffer[])
{
   int maxRetries = 3;
   int copied = 0;
   
   ArraySetAsSeries(buffer, true);
   
   for(int retry = 0; retry < maxRetries; retry++)
   {
      copied = CopyClose(symbol, tf, start, count, buffer);
      if(copied >= count) return copied;
      
      // Short wait before retry
      if(retry < maxRetries - 1)
      {
         Sleep(10);
      }
   }
   
   return copied;
}

//+------------------------------------------------------------------+
//| v3.6.0: Parse Z-Score Grid String (Generic)                        |
//+------------------------------------------------------------------+
void ParseZScoreGrid(string gridStr, double &levels[], int &count)
{
   count = 0;
   ArrayInitialize(levels, 0);
   
   string parts[];
   int partCount = StringSplit(gridStr, ';', parts);
   
   for(int i = 0; i < partCount && i < MAX_AVG_LEVELS; i++)
   {
      double level = StringToDouble(parts[i]);
      if(level > 0)
      {
         levels[count] = level;
         count++;
      }
   }
   
   if(InpDebugMode)
   {
      Print("Z-Score Grid Levels Parsed: ", count);
      for(int i = 0; i < count; i++)
      {
         PrintFormat("  Level %d: %.2f", i + 1, levels[i]);
      }
   }
}

//+------------------------------------------------------------------+
//| Initialize Trading Pairs (30 pairs)                                |
//+------------------------------------------------------------------+
bool InitializePairs()
{
   g_activePairs = 0;
   
   // Setup all 30 pairs
   SetupPair(0, InpEnablePair1, InpPair1_SymbolA, InpPair1_SymbolB);
   SetupPair(1, InpEnablePair2, InpPair2_SymbolA, InpPair2_SymbolB);
   SetupPair(2, InpEnablePair3, InpPair3_SymbolA, InpPair3_SymbolB);
   SetupPair(3, InpEnablePair4, InpPair4_SymbolA, InpPair4_SymbolB);
   SetupPair(4, InpEnablePair5, InpPair5_SymbolA, InpPair5_SymbolB);
   SetupPair(5, InpEnablePair6, InpPair6_SymbolA, InpPair6_SymbolB);
   SetupPair(6, InpEnablePair7, InpPair7_SymbolA, InpPair7_SymbolB);
   SetupPair(7, InpEnablePair8, InpPair8_SymbolA, InpPair8_SymbolB);
   SetupPair(8, InpEnablePair9, InpPair9_SymbolA, InpPair9_SymbolB);
   SetupPair(9, InpEnablePair10, InpPair10_SymbolA, InpPair10_SymbolB);
   SetupPair(10, InpEnablePair11, InpPair11_SymbolA, InpPair11_SymbolB);
   SetupPair(11, InpEnablePair12, InpPair12_SymbolA, InpPair12_SymbolB);
   SetupPair(12, InpEnablePair13, InpPair13_SymbolA, InpPair13_SymbolB);
   SetupPair(13, InpEnablePair14, InpPair14_SymbolA, InpPair14_SymbolB);
   SetupPair(14, InpEnablePair15, InpPair15_SymbolA, InpPair15_SymbolB);
   SetupPair(15, InpEnablePair16, InpPair16_SymbolA, InpPair16_SymbolB);
   SetupPair(16, InpEnablePair17, InpPair17_SymbolA, InpPair17_SymbolB);
   SetupPair(17, InpEnablePair18, InpPair18_SymbolA, InpPair18_SymbolB);
   SetupPair(18, InpEnablePair19, InpPair19_SymbolA, InpPair19_SymbolB);
   SetupPair(19, InpEnablePair20, InpPair20_SymbolA, InpPair20_SymbolB);
   SetupPair(20, InpEnablePair21, InpPair21_SymbolA, InpPair21_SymbolB);
   SetupPair(21, InpEnablePair22, InpPair22_SymbolA, InpPair22_SymbolB);
   SetupPair(22, InpEnablePair23, InpPair23_SymbolA, InpPair23_SymbolB);
   SetupPair(23, InpEnablePair24, InpPair24_SymbolA, InpPair24_SymbolB);
   SetupPair(24, InpEnablePair25, InpPair25_SymbolA, InpPair25_SymbolB);
   SetupPair(25, InpEnablePair26, InpPair26_SymbolA, InpPair26_SymbolB);
   SetupPair(26, InpEnablePair27, InpPair27_SymbolA, InpPair27_SymbolB);
   SetupPair(27, InpEnablePair28, InpPair28_SymbolA, InpPair28_SymbolB);
   SetupPair(28, InpEnablePair29, InpPair29_SymbolA, InpPair29_SymbolB);
   SetupPair(29, InpEnablePair30, InpPair30_SymbolA, InpPair30_SymbolB);
   
   return (g_activePairs > 0);
}

//+------------------------------------------------------------------+
//| v2.0: Initialize Mini Group System                                 |
//+------------------------------------------------------------------+
void InitializeMiniGroups()
{
   // Mini Group 1-3 (Group 1)
   g_miniGroups[0].closedTarget = InpMini1Target;
   g_miniGroups[1].closedTarget = InpMini2Target;
   g_miniGroups[2].closedTarget = InpMini3Target;
   
   // Mini Group 4-6 (Group 2)
   g_miniGroups[3].closedTarget = InpMini4Target;
   g_miniGroups[4].closedTarget = InpMini5Target;
   g_miniGroups[5].closedTarget = InpMini6Target;
   
   // Mini Group 7-9 (Group 3)
   g_miniGroups[6].closedTarget = InpMini7Target;
   g_miniGroups[7].closedTarget = InpMini8Target;
   g_miniGroups[8].closedTarget = InpMini9Target;
   
   // Mini Group 10-12 (Group 4)
   g_miniGroups[9].closedTarget = InpMini10Target;
   g_miniGroups[10].closedTarget = InpMini11Target;
   g_miniGroups[11].closedTarget = InpMini12Target;
   
   // Mini Group 13-15 (Group 5)
   g_miniGroups[12].closedTarget = InpMini13Target;
   g_miniGroups[13].closedTarget = InpMini14Target;
   g_miniGroups[14].closedTarget = InpMini15Target;
   
   // Reset all Mini Group profits
   for(int m = 0; m < MAX_MINI_GROUPS; m++)
   {
      g_miniGroups[m].closedProfit = 0;
      g_miniGroups[m].floatingProfit = 0;
      g_miniGroups[m].totalProfit = 0;
      g_miniGroups[m].targetTriggered = false;
   }
   
   PrintFormat("v2.0: Mini Group System initialized - 15 Mini Groups (2 pairs each)");
}

//+------------------------------------------------------------------+
//| v2.0: Get Mini Group Index from Pair Index (0-29 → 0-14)           |
//+------------------------------------------------------------------+
int GetMiniGroupIndex(int pairIndex)
{
   return pairIndex / PAIRS_PER_MINI;
}

//+------------------------------------------------------------------+
//| v2.0: Get Parent Group Index from Mini Group Index (0-14 → 0-4)    |
//+------------------------------------------------------------------+
int GetGroupFromMini(int miniIndex)
{
   return miniIndex / MINIS_PER_GROUP;
}

//+------------------------------------------------------------------+
//| v2.0: Get sum of Mini Group targets for a Group                    |
//+------------------------------------------------------------------+
double GetMiniGroupSumTarget(int groupIndex)
{
   double sum = 0;
   int startMini = groupIndex * MINIS_PER_GROUP;
   for(int i = 0; i < MINIS_PER_GROUP; i++)
   {
      sum += g_miniGroups[startMini + i].closedTarget;
   }
   return sum;
}

//+------------------------------------------------------------------+
//| v2.1.2: Get Mini Group Targets as formatted string (1000/1000/1000)|
//+------------------------------------------------------------------+
string GetMiniGroupTargetString(int groupIndex)
{
   int startMini = groupIndex * MINIS_PER_GROUP;
   string result = "";
   
   for(int i = 0; i < MINIS_PER_GROUP; i++)
   {
      double target = GetScaledMiniGroupTarget(startMini + i);
      if(i > 0) result += "/";
      
      if(target > 0)
         result += IntegerToString((int)target);
      else
         result += "0";
   }
   
   return result;  // Format: "1000/1000/1000" or "0/1000/500"
}

//+------------------------------------------------------------------+
//| v2.0: Update Mini Group Profits from Pair P/L                      |
//+------------------------------------------------------------------+
void UpdateMiniGroupProfits()
{
   for(int m = 0; m < MAX_MINI_GROUPS; m++)
   {
      int startPair = m * PAIRS_PER_MINI;
      g_miniGroups[m].floatingProfit = 0;
      
      for(int p = startPair; p < startPair + PAIRS_PER_MINI && p < MAX_PAIRS; p++)
      {
         g_miniGroups[m].floatingProfit += g_pairs[p].profitBuy + g_pairs[p].profitSell;
      }
      
      g_miniGroups[m].totalProfit = g_miniGroups[m].closedProfit + g_miniGroups[m].floatingProfit;
   }
}

//+------------------------------------------------------------------+
//| v2.0: Initialize Group Target System (5 Groups × 6 Pairs)          |
//+------------------------------------------------------------------+
void InitializeGroups()
{
   // v2.0: Initialize Mini Groups first
   InitializeMiniGroups();
   
   // Group 1 (Pairs 1-6)
   g_groups[0].closedTarget = InpGroup1ClosedTarget;
   g_groups[0].floatingTarget = InpGroup1FloatingTarget;
   g_groups[0].maxOrderBuy = InpGroup1MaxOrderBuy;
   g_groups[0].maxOrderSell = InpGroup1MaxOrderSell;
   g_groups[0].targetBuy = InpGroup1TargetBuy;
   g_groups[0].targetSell = InpGroup1TargetSell;
   ResetGroupProfit(0);
   
   // Group 2 (Pairs 7-12)
   g_groups[1].closedTarget = InpGroup2ClosedTarget;
   g_groups[1].floatingTarget = InpGroup2FloatingTarget;
   g_groups[1].maxOrderBuy = InpGroup2MaxOrderBuy;
   g_groups[1].maxOrderSell = InpGroup2MaxOrderSell;
   g_groups[1].targetBuy = InpGroup2TargetBuy;
   g_groups[1].targetSell = InpGroup2TargetSell;
   ResetGroupProfit(1);
   
   // Group 3 (Pairs 13-18)
   g_groups[2].closedTarget = InpGroup3ClosedTarget;
   g_groups[2].floatingTarget = InpGroup3FloatingTarget;
   g_groups[2].maxOrderBuy = InpGroup3MaxOrderBuy;
   g_groups[2].maxOrderSell = InpGroup3MaxOrderSell;
   g_groups[2].targetBuy = InpGroup3TargetBuy;
   g_groups[2].targetSell = InpGroup3TargetSell;
   ResetGroupProfit(2);
   
   // Group 4 (Pairs 19-24)
   g_groups[3].closedTarget = InpGroup4ClosedTarget;
   g_groups[3].floatingTarget = InpGroup4FloatingTarget;
   g_groups[3].maxOrderBuy = InpGroup4MaxOrderBuy;
   g_groups[3].maxOrderSell = InpGroup4MaxOrderSell;
   g_groups[3].targetBuy = InpGroup4TargetBuy;
   g_groups[3].targetSell = InpGroup4TargetSell;
   ResetGroupProfit(3);
   
   // Group 5 (Pairs 25-30)
   g_groups[4].closedTarget = InpGroup5ClosedTarget;
   g_groups[4].floatingTarget = InpGroup5FloatingTarget;
   g_groups[4].maxOrderBuy = InpGroup5MaxOrderBuy;
   g_groups[4].maxOrderSell = InpGroup5MaxOrderSell;
   g_groups[4].targetBuy = InpGroup5TargetBuy;
   g_groups[4].targetSell = InpGroup5TargetSell;
   ResetGroupProfit(4);
   
   // v1.6.6: Log scaling info (show effective values)
   if(InpEnableAutoScaling)
   {
      double scaleFactor = GetScaleFactor();
      PrintFormat("v1.6.6: Auto Scaling ENABLED | Factor=%.2fx | Base=$%.0f | Effective=$%.0f",
                  scaleFactor, InpBaseAccountSize,
                  InpEnableFixedScale ? InpFixedScaleAccount : AccountInfoDouble(ACCOUNT_BALANCE));
      PrintFormat("v1.6.6: Group 1 Targets - Base Closed=$%.0f → Scaled=$%.0f",
                  InpGroup1ClosedTarget, GetScaledGroupClosedTarget(0));
   }
   PrintFormat("v2.0: Group Target System initialized - 5 Groups x 6 Pairs");
}

//+------------------------------------------------------------------+
//| v1.1: Reset Group Profit                                           |
//+------------------------------------------------------------------+
void ResetGroupProfit(int groupIndex)
{
   if(groupIndex < 0 || groupIndex >= MAX_GROUPS) return;
   
   // v2.1.5: Reset all Mini Groups within this Group FIRST (hierarchy: small → big)
   int startMini = groupIndex * MINIS_PER_GROUP;
   for(int m = startMini; m < startMini + MINIS_PER_GROUP && m < MAX_MINI_GROUPS; m++)
   {
      ResetMiniGroupProfit(m);
   }
   
   // Reset Group itself
   g_groups[groupIndex].closedProfit = 0;
   g_groups[groupIndex].floatingProfit = 0;
   g_groups[groupIndex].totalProfit = 0;
   g_groups[groupIndex].targetTriggered = false;
   g_groups[groupIndex].closeMode = false;
   
   PrintFormat("[v2.1.5] Group %d RESET: closedProfit = 0, Mini Groups M%d-M%d also reset",
               groupIndex + 1, startMini + 1, startMini + MINIS_PER_GROUP);
}

//+------------------------------------------------------------------+
//| v2.1.5: Reset Mini Group Profit                                    |
//+------------------------------------------------------------------+
void ResetMiniGroupProfit(int miniIndex)
{
   if(miniIndex < 0 || miniIndex >= MAX_MINI_GROUPS) return;
   
   g_miniGroups[miniIndex].closedProfit = 0;
   g_miniGroups[miniIndex].floatingProfit = 0;
   g_miniGroups[miniIndex].totalProfit = 0;
   g_miniGroups[miniIndex].targetTriggered = false;
   
   PrintFormat("[v2.1.5] Mini Group %d RESET: closedProfit = 0, targetTriggered = false",
               miniIndex + 1);
}

//+------------------------------------------------------------------+
//| v1.1: Get Group Index from Pair Index                              |
//+------------------------------------------------------------------+
int GetGroupIndex(int pairIndex)
{
   return pairIndex / PAIRS_PER_GROUP;  // 0-4 -> 0, 5-9 -> 1, etc.
}

//+------------------------------------------------------------------+
//| Setup Individual Pair (v1.1 - with Group Target System)            |
//+------------------------------------------------------------------+
void SetupPair(int index, bool enabled, string symbolA, string symbolB)
{
   // Basic info
   g_pairs[index].enabled = false;
   g_pairs[index].dataValid = false;
   g_pairs[index].symbolA = symbolA;
   g_pairs[index].symbolB = symbolB;
   
   // Statistical data
   g_pairs[index].correlation = 0;
   g_pairs[index].correlationType = 1;  // Default to positive
   g_pairs[index].hedgeRatio = 1.0;
   g_pairs[index].spreadMean = 0;
   g_pairs[index].spreadStdDev = 0;
   g_pairs[index].currentSpread = 0;
   g_pairs[index].zScore = 0;
   
   // v3.2.6: Beta Smoothing initialization
   g_pairs[index].prevBeta = 1.0;
   g_pairs[index].betaInitialized = false;
   g_pairs[index].manualBeta = 0;  // 0 = use auto calculation
   
   // Buy Side initialization - directionBuy = -1 means Ready to trade
   g_pairs[index].directionBuy = enabled ? -1 : 0;
   g_pairs[index].ticketBuyA = 0;
   g_pairs[index].ticketBuyB = 0;
   // v1.6.5: Use scaled lot for initialization
   double scaledBaseLot = GetScaledBaseLot();
   g_pairs[index].lotBuyA = scaledBaseLot;
   g_pairs[index].lotBuyB = scaledBaseLot;
   g_pairs[index].profitBuy = 0;
   g_pairs[index].orderCountBuy = 0;
   // v1.1: Use Group's max orders and targets
   int groupIdx = GetGroupIndex(index);
   g_pairs[index].maxOrderBuy = g_groups[groupIdx].maxOrderBuy;
   g_pairs[index].targetBuy = g_groups[groupIdx].targetBuy;
   g_pairs[index].entryTimeBuy = 0;
   
   // Sell Side initialization - directionSell = -1 means Ready to trade
   g_pairs[index].directionSell = enabled ? -1 : 0;
   g_pairs[index].ticketSellA = 0;
   g_pairs[index].ticketSellB = 0;
   g_pairs[index].lotSellA = scaledBaseLot;
   g_pairs[index].lotSellB = scaledBaseLot;
   g_pairs[index].profitSell = 0;
   g_pairs[index].orderCountSell = 0;
   // v1.1: Use Group's max orders and targets
   g_pairs[index].maxOrderSell = g_groups[groupIdx].maxOrderSell;
   g_pairs[index].targetSell = g_groups[groupIdx].targetSell;
   g_pairs[index].entryTimeSell = 0;
   
   // v3.2.7: Averaging System initialization
   g_pairs[index].avgOrderCountBuy = 0;
   g_pairs[index].avgOrderCountSell = 0;
   g_pairs[index].lastAvgPriceBuy = 0;
   g_pairs[index].lastAvgPriceSell = 0;
   g_pairs[index].entryZScoreBuy = 0;
   g_pairs[index].entryZScoreSell = 0;
   
   // v3.2.9: Same-Tick Protection initialization
   g_pairs[index].justOpenedMainBuy = false;
   g_pairs[index].justOpenedMainSell = false;
   
   // v3.2.9: Closed P/L tracking
   g_pairs[index].closedProfitBuy = 0;
   g_pairs[index].closedProfitSell = 0;
   
   // v3.4.0: RSI on Spread
   g_pairs[index].rsiSpread = 50;  // Neutral default
   
   // v3.5.0: CDC Action Zone Trend Filter
   g_pairs[index].cdcTrendA = "NEUTRAL";
   g_pairs[index].cdcTrendB = "NEUTRAL";
   g_pairs[index].cdcFastA = 0;
   g_pairs[index].cdcSlowA = 0;
   
   // v3.7.1: CDC Status per Symbol
   g_pairs[index].lastCdcTimeA = 0;
   g_pairs[index].lastCdcTimeB = 0;
   g_pairs[index].cdcReadyA = false;
   g_pairs[index].cdcReadyB = false;
   g_pairs[index].cdcFastB = 0;
   g_pairs[index].cdcSlowB = 0;
   
   // v1.8.1: ADX Value Initialization for Negative Correlation Filter
   g_pairs[index].adxValueA = 0.0;
   g_pairs[index].adxValueB = 0.0;
   g_pairs[index].adxWinner = -1;           // -1 = None/Equal
   g_pairs[index].adxWinnerValue = 0.0;
   g_pairs[index].adxLoserValue = 0.0;
   
   // v3.6.0: Grid Profit Side initialization
   g_pairs[index].gridProfitCountBuy = 0;
   g_pairs[index].gridProfitCountSell = 0;
   g_pairs[index].lastProfitPriceBuy = 0;
   g_pairs[index].lastProfitPriceSell = 0;
   g_pairs[index].lastProfitGridLotBuyA = 0;
   g_pairs[index].lastProfitGridLotBuyB = 0;
   g_pairs[index].lastProfitGridLotSellA = 0;
   g_pairs[index].lastProfitGridLotSellB = 0;
   g_pairs[index].initialEntryPriceBuy = 0;
   g_pairs[index].initialEntryPriceSell = 0;
   g_pairs[index].gridProfitZLevelBuy = 0;
   g_pairs[index].gridProfitZLevelSell = 0;
   
   // Combined
   g_pairs[index].totalPairProfit = 0;
   
   if(!enabled)
   {
      return;
   }
   
   // Validate symbols
   if(symbolA == "" || symbolB == "")
   {
      PrintFormat("Pair %d: Empty symbol(s)", index + 1);
      return;
   }
   
   // Check if symbols are available
   if(!SymbolSelect(symbolA, true))
   {
      PrintFormat("Pair %d: Symbol A '%s' not available", index + 1, symbolA);
      return;
   }
   if(!SymbolSelect(symbolB, true))
   {
      PrintFormat("Pair %d: Symbol B '%s' not available", index + 1, symbolB);
      return;
   }
   
   // Enable pair
   g_pairs[index].enabled = true;
   g_pairs[index].dataValid = true;
   g_activePairs++;
}

//+------------------------------------------------------------------+
//| v1.6.4: Get Reference Symbol for Z-Score Candle Detection         |
//| Returns first enabled pair's symbolA for consistent timing        |
//| FIXED: No longer requires dataValid - uses enabled symbol only    |
//+------------------------------------------------------------------+
string GetZScoreReferenceSymbol()
{
   // v1.6.4: Don't wait for dataValid - we just need an enabled symbol for timing
   // This ensures Z-Score updates work even during initialization
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(g_pairs[i].enabled && g_pairs[i].symbolA != "")
      {
         return g_pairs[i].symbolA;
      }
   }
   return "";  // No active pair found
}

//+------------------------------------------------------------------+
//| v1.5: Get Reference Symbol for Correlation Candle Detection       |
//| Returns first enabled pair's symbolA for consistent timing        |
//+------------------------------------------------------------------+
string GetCorrReferenceSymbol()
{
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(g_pairs[i].enabled && g_pairs[i].dataValid)
      {
         return g_pairs[i].symbolA;
      }
   }
   return "";  // No active pair found
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   ObjectsDeleteAll(0, "STAT_");
   
   if(g_atrHandle != INVALID_HANDLE)
   {
      IndicatorRelease(g_atrHandle);
      g_atrHandle = INVALID_HANDLE;
   }
}

//+------------------------------------------------------------------+
//| Trade Transaction Event Handler (v3.6.8)                           |
//| Triggers immediate sync when orders open/close                     |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   // Skip in tester mode to avoid slowing down backtests
   if(g_isTesterMode) return;
   
   // Only sync on deal added or history update events
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD || 
      trans.type == TRADE_TRANSACTION_HISTORY_ADD)
   {
      // Update EA status based on current state
      UpdateEAStatus();
      
      // Check if it's a trade deal (not balance/credit operation)
      if(trans.deal_type == DEAL_TYPE_BUY || trans.deal_type == DEAL_TYPE_SELL)
      {
         // Determine if order was opened or closed
         ENUM_SYNC_EVENT eventType = SYNC_ORDER_CLOSE;
         
         if(trans.deal_type == DEAL_TYPE_BUY || trans.deal_type == DEAL_TYPE_SELL)
         {
            // Check entry type to determine open vs close
            if(HistoryDealSelect(trans.deal))
            {
               ENUM_DEAL_ENTRY entryType = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
               if(entryType == DEAL_ENTRY_IN)
                  eventType = SYNC_ORDER_OPEN;
               else if(entryType == DEAL_ENTRY_OUT || entryType == DEAL_ENTRY_OUT_BY)
                  eventType = SYNC_ORDER_CLOSE;
            }
         }
         
         // Sync immediately
         Print("[Sync] OnTradeTransaction triggered - Event: ", 
               (eventType == SYNC_ORDER_OPEN ? "ORDER_OPEN" : "ORDER_CLOSE"),
               ", Deal: ", trans.deal);
         
         SyncAccountData(eventType);
      }
   }
}

//+------------------------------------------------------------------+
//| Update EA Status Based on Current State (v1.6.1)                   |
//+------------------------------------------------------------------+
void UpdateEAStatus()
{
   // v1.6.1: Priority: Suspended > Expired > Not Found > Error > Invalid > Paused > Working
   // v3.7.3: Use lowercase to match backend expectation
   if(g_licenseStatus == LICENSE_SUSPENDED)
   {
      g_eaStatus = "suspended";
   }
   else if(g_licenseStatus == LICENSE_EXPIRED)
   {
      g_eaStatus = "expired";
   }
   else if(g_licenseStatus == LICENSE_NOT_FOUND)
   {
      g_eaStatus = "invalid";  // v1.6.1: Account not registered -> invalid
   }
   else if(g_licenseStatus == LICENSE_ERROR)
   {
      g_eaStatus = "error";    // v1.6.1: Connection/Server error -> error
   }
   else if(!g_isLicenseValid)
   {
      g_eaStatus = "invalid";  // v1.6.1: Any other invalid state
   }
   else if(g_isPaused || g_isNewsPaused)
   {
      g_eaStatus = "paused";
   }
   else
   {
      g_eaStatus = "working";
   }
}

//+------------------------------------------------------------------+
//| Expert tick function (v3.3.0 - Separate Z-Score TF check)          |
//+------------------------------------------------------------------+
void OnTick()
{
   // v3.2.8: Ultra Fast Mode - skip calculations on most ticks
   if(g_isTesterMode && InpUltraFastMode)
   {
      g_tickCounter++;
      if(InpStatCalcInterval > 0 && g_tickCounter % InpStatCalcInterval != 0)
      {
         // Only manage positions, skip heavy calculations
         if(g_isLicenseValid && !g_isPaused)
         {
            ManageAllPositions();
            CheckPairTargets();
            CheckTotalTarget();
         }
         return;
      }
   }
   
   // v3.2.9: Reset same-tick protection flags
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      g_pairs[i].justOpenedMainBuy = false;
      g_pairs[i].justOpenedMainSell = false;
   }
   
   // v1.5: Check for new candle on correlation timeframe - USE PAIR SYMBOL, NOT CHART SYMBOL
   string corrRefSymbol = GetCorrReferenceSymbol();
   datetime currentCandleTime = 0;
   
   if(corrRefSymbol != "")
   {
      currentCandleTime = iTime(corrRefSymbol, InpCorrTimeframe, 0);
   }
   else
   {
      // Fallback if no active pair
      currentCandleTime = iTime(_Symbol, InpCorrTimeframe, 0);
   }
   
   bool newCandleCorr = (currentCandleTime != g_lastCandleTime);
   
   if(newCandleCorr)
   {
      g_lastCandleTime = currentCandleTime;
      
      // v3.2.5: Skip correlation update in tester if option enabled
      if(!(g_isTesterMode && InpSkipCorrUpdateInTester))
      {
         UpdateAllPairData();
      }
      
      // v2.1.6: Update ATR cache on new bar for all active pairs
      for(int i = 0; i < MAX_PAIRS; i++)
      {
         if(!g_pairs[i].enabled) continue;
         UpdateATRCache(i);
      }
      
      // v1.5: Debug log for correlation update timing
      if(InpDebugMode && (!g_isTesterMode || !InpDisableDebugInTester))
      {
         PrintFormat("[v1.5] Correlation Update | TF=%s | RefSymbol=%s | CandleTime=%s",
                     EnumToString(InpCorrTimeframe), corrRefSymbol, TimeToString(currentCandleTime));
      }
   }
   
   // v1.5: Check for new candle on Z-Score timeframe - USE PAIR SYMBOL, NOT CHART SYMBOL
   ENUM_TIMEFRAMES zTF = GetZScoreTimeframe();
   string zRefSymbol = GetZScoreReferenceSymbol();
   datetime zCandleTime = 0;
   
   if(zRefSymbol != "")
   {
      zCandleTime = iTime(zRefSymbol, zTF, 0);
   }
   else
   {
      // Fallback if no active pair
      zCandleTime = iTime(_Symbol, zTF, 0);
   }
   
   // v1.6.7: Z-Score Bar Mode handling
   if(InpZScoreBarMode == ZSCORE_BAR_CURRENT)
   {
      // Current Bar Mode: Update every X minutes using real-time data (shift=0)
      datetime currentTime = TimeCurrent();
      int updateIntervalSec = InpZScoreCurrentUpdateMins * 60;
      
      if(g_lastZScoreCurrentUpdate == 0 || 
         (currentTime - g_lastZScoreCurrentUpdate) >= updateIntervalSec)
      {
         g_lastZScoreCurrentUpdate = currentTime;
         UpdateZScoreData();  // Will use shift=0 internally for Current Bar mode
         
         g_lastZScoreUpdateDisplay = TimeCurrent();
         CalculateAllRSIonSpread();
         
         if(InpDebugMode && (!g_isTesterMode || !InpDisableDebugInTester))
         {
            PrintFormat("[Z-SCORE v1.6.7] Current Bar Update at %s (every %d min)",
                        TimeToString(currentTime, TIME_DATE|TIME_MINUTES),
                        InpZScoreCurrentUpdateMins);
         }
      }
   }
   else
   {
      // Close Bar Mode: Update only on new candle (shift=1 - stable)
      bool newCandleZScore = (zCandleTime != g_lastZScoreUpdate);
      
      if(newCandleZScore)
      {
         g_lastZScoreUpdate = zCandleTime;
         UpdateZScoreData();  // Will use shift=1 internally for Close Bar mode
         
         g_lastZScoreUpdateDisplay = TimeCurrent();
         CalculateAllRSIonSpread();
         
         if(InpDebugMode && (!g_isTesterMode || !InpDisableDebugInTester))
         {
            PrintFormat("[v1.6.7] Z-Score Close Bar Update | TF=%s | RefSymbol=%s | CandleTime=%s",
                        EnumToString(zTF), zRefSymbol, TimeToString(zCandleTime));
         }
      }
   }
   
   // v3.7.1: Update CDC Trend Data - per-symbol based (independent from chart TF)
   // Instead of using _Symbol, we check each pair's symbols independently in UpdateAllPairsCDC()
   // This makes CDC refresh independent from chart timeframe changes
   if(InpUseCDCTrendFilter)
   {
      UpdateAllPairsCDC();  // Function now handles per-symbol candle time tracking
   }
   
   // v1.5: Update ADX - USE PAIR SYMBOL, NOT CHART SYMBOL
   string adxRefSymbol = GetZScoreReferenceSymbol();  // Reuse same reference logic
   datetime adxCandleTime = 0;
   
   if(adxRefSymbol != "")
   {
      adxCandleTime = iTime(adxRefSymbol, InpADXTimeframe, 0);
   }
   else
   {
      adxCandleTime = iTime(_Symbol, InpADXTimeframe, 0);
   }
   
   static datetime s_lastADXUpdate = 0;
   bool newCandleADX = (adxCandleTime != s_lastADXUpdate);
   
   if(newCandleADX)
   {
      s_lastADXUpdate = adxCandleTime;
      UpdateAllPairsADX();
   }
   
   // v3.2.7: Check for auto-resume after DD
   CheckAutoResume();
   
   // v3.6.5: Periodic license check and data sync
   PeriodicLicenseCheck();
   
   // Skip trading logic if not licensed or paused
   if(!g_isLicenseValid || g_isPaused)
   {
   // v1.4: Dashboard update with throttling in tester (even when paused)
   if(g_dashboardEnabled)
   {
      if(g_isTesterMode && InpFastBacktest)
      {
         if(TimeCurrent() - g_lastTesterDashboardUpdate >= InpBacktestUiUpdateSec)
         {
            UpdatePairProfits();   // v1.4: Force profit update before dashboard refresh
            UpdateAccountStats();  // v1.4: Force account stats update
            UpdateDashboard();
            g_lastTesterDashboardUpdate = TimeCurrent();
         }
      }
      else
      {
         UpdateDashboard();
      }
   }
   return;
   }
   
   // Main trading logic
   AnalyzeAllPairs();
   CheckAllGridLoss();    // v3.6.0: Grid Loss Side
   CheckAllGridProfit();  // v3.6.0: Grid Profit Side
   
   // v3.3.2: Check for orphan positions before management
   CheckOrphanPositions();
   
   ManageAllPositions();
   CheckPairTargets();
   CheckTotalTarget();
   
   // v2.0: Update Mini Group profits and check targets
   UpdateMiniGroupProfits();
   CheckMiniGroupTargets();
   
   CheckRiskLimits();
   UpdateAccountStats();
   
   // v1.4: Dashboard update with throttling in tester
   // CRITICAL: Call UpdatePairProfits() BEFORE UpdateDashboard() to ensure current values
   if(g_dashboardEnabled)
   {
      if(g_isTesterMode && InpFastBacktest)
      {
         if(TimeCurrent() - g_lastTesterDashboardUpdate >= InpBacktestUiUpdateSec)
         {
            UpdatePairProfits();   // v1.4: Force profit update before dashboard refresh
            UpdateAccountStats();  // v1.4: Force account stats update
            UpdateDashboard();
            g_lastTesterDashboardUpdate = TimeCurrent();
         }
      }
      else
      {
         UpdateDashboard();
      }
   }
   
   // v3.2.5: Periodic logging in tester
   if(g_isTesterMode && InpBacktestLogInterval > 0)
   {
      if(TimeCurrent() - g_lastTesterLogTime >= InpBacktestLogInterval)
      {
         PrintFormat("[TESTER] Profit: %.2f | Pairs Active: %d | DD: %.2f%%",
                     g_totalCurrentProfit, CountActiveTrades(), g_maxDrawdownPercent);
         g_lastTesterLogTime = TimeCurrent();
      }
   }
}

//+------------------------------------------------------------------+
//| Timer function                                                     |
//+------------------------------------------------------------------+
void OnTimer()
{
   if(g_dashboardEnabled)
   {
      UpdateDashboard();
   }
}

//+------------------------------------------------------------------+
//| Chart event handler (v3.3.0 - Dashboard interaction)               |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      string prefix = "STAT_";
      
      // Handle button clicks
      // v1.8.6: Close Buy (per pair) with confirmation
      if(StringFind(sparam, prefix + "_CLOSE_BUY_") >= 0)
      {
         int pairIndex = (int)StringToInteger(StringSubstr(sparam, StringLen(prefix + "_CLOSE_BUY_")));
         
         // v1.8.6: Confirmation popup
         string msg = StringFormat("Close Buy side for Pair %d (%s/%s)?", 
                                   pairIndex + 1, 
                                   g_pairs[pairIndex].symbolA, g_pairs[pairIndex].symbolB);
         int result = MessageBox(msg, "Confirm Close", MB_YESNO | MB_ICONQUESTION);
         if(result != IDYES)
         {
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            return;
         }
         
         CloseBuySide(pairIndex);
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      }
      // v1.8.6: Close Sell (per pair) with confirmation
      else if(StringFind(sparam, prefix + "_CLOSE_SELL_") >= 0)
      {
         int pairIndex = (int)StringToInteger(StringSubstr(sparam, StringLen(prefix + "_CLOSE_SELL_")));
         
         // v1.8.6: Confirmation popup
         string msg = StringFormat("Close Sell side for Pair %d (%s/%s)?", 
                                   pairIndex + 1, 
                                   g_pairs[pairIndex].symbolA, g_pairs[pairIndex].symbolB);
         int result = MessageBox(msg, "Confirm Close", MB_YESNO | MB_ICONQUESTION);
         if(result != IDYES)
         {
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            return;
         }
         
         CloseSellSide(pairIndex);
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      }
      // v1.8.6: Toggle Buy Status with confirmation
      else if(StringFind(sparam, prefix + "_ST_BUY_") >= 0)
      {
         int pairIndex = (int)StringToInteger(StringSubstr(sparam, StringLen(prefix + "_ST_BUY_")));
         
         // v1.8.6: Confirmation popup
         string action = (g_pairs[pairIndex].directionBuy == 0) ? "Enable" : "Disable";
         string msg = StringFormat("%s Buy side for Pair %d (%s/%s)?", 
                                   action, pairIndex + 1, 
                                   g_pairs[pairIndex].symbolA, g_pairs[pairIndex].symbolB);
         int result = MessageBox(msg, "Confirm Toggle", MB_YESNO | MB_ICONQUESTION);
         if(result != IDYES)
         {
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            return;
         }
         
         ToggleBuySide(pairIndex);
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      }
      // v1.8.6: Toggle Sell Status with confirmation
      else if(StringFind(sparam, prefix + "_ST_SELL_") >= 0)
      {
         int pairIndex = (int)StringToInteger(StringSubstr(sparam, StringLen(prefix + "_ST_SELL_")));
         
         // v1.8.6: Confirmation popup
         string action = (g_pairs[pairIndex].directionSell == 0) ? "Enable" : "Disable";
         string msg = StringFormat("%s Sell side for Pair %d (%s/%s)?", 
                                   action, pairIndex + 1, 
                                   g_pairs[pairIndex].symbolA, g_pairs[pairIndex].symbolB);
         int result = MessageBox(msg, "Confirm Toggle", MB_YESNO | MB_ICONQUESTION);
         if(result != IDYES)
         {
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            return;
         }
         
         ToggleSellSide(pairIndex);
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      }
      // v1.8.6: Close All Buy with confirmation
      else if(sparam == prefix + "_CLOSE_ALL_BUY")
      {
         int result = MessageBox("Close ALL Buy positions?", "Confirm Close All", MB_YESNO | MB_ICONWARNING);
         if(result != IDYES)
         {
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            return;
         }
         
         CloseAllBuySides();
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      }
      // v1.8.6: Close All Sell with confirmation
      else if(sparam == prefix + "_CLOSE_ALL_SELL")
      {
         int result = MessageBox("Close ALL Sell positions?", "Confirm Close All", MB_YESNO | MB_ICONWARNING);
         if(result != IDYES)
         {
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            return;
         }
         
         CloseAllSellSides();
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      }
      // v1.8.6: Start All with confirmation
      else if(sparam == prefix + "_START_ALL")
      {
         int result = MessageBox("Start ALL pairs?", "Confirm Start All", MB_YESNO | MB_ICONQUESTION);
         if(result != IDYES)
         {
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            return;
         }
         
         StartAllPairs();
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      }
      // v1.8.6: Stop All with confirmation
      else if(sparam == prefix + "_STOP_ALL")
      {
         int result = MessageBox("Stop ALL pairs?", "Confirm Stop All", MB_YESNO | MB_ICONWARNING);
         if(result != IDYES)
         {
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            return;
         }
         
         StopAllPairs();
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      }
      // v3.7.3: Global Pause/Start Button (v1.8.6: with confirmation)
      else if(sparam == prefix + "_BTN_PAUSE")
      {
         string action = g_isPaused ? "Resume" : "Pause";
         string msg = StringFormat("%s EA trading?", action);
         int result = MessageBox(msg, "Confirm " + action, MB_YESNO | MB_ICONQUESTION);
         if(result != IDYES)
         {
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            return;
         }
         
         g_isPaused = !g_isPaused;
         
         // Update button appearance
         if(g_isPaused)
         {
            ObjectSetString(0, sparam, OBJPROP_TEXT, "Start");
            ObjectSetInteger(0, sparam, OBJPROP_BGCOLOR, clrGreen);
            g_pauseReason = "MANUAL";
         }
         else
         {
            ObjectSetString(0, sparam, OBJPROP_TEXT, "Pause");
            ObjectSetInteger(0, sparam, OBJPROP_BGCOLOR, clrOrangeRed);
            g_pauseReason = "";
         }
         
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         
         // Trigger sync to update backend status
         UpdateEAStatus();
         if(g_isLicenseValid)
            SyncAccountData(SYNC_SCHEDULED);
            
         PrintFormat("[v1.8.6] Global Pause toggled: %s", g_isPaused ? "PAUSED" : "RUNNING");
      }
      // v1.8.7: Close Group button handler
      else if(StringFind(sparam, prefix + "_CLOSE_GRP_") >= 0)
      {
         int grpIdx = (int)StringToInteger(StringSubstr(sparam, StringLen(prefix + "_CLOSE_GRP_")));
         
         // Confirmation popup
         string msg = StringFormat("Close ALL orders in Group %d (Pairs %d-%d)?", 
                                   grpIdx + 1, grpIdx * PAIRS_PER_GROUP + 1, (grpIdx + 1) * PAIRS_PER_GROUP);
         int result = MessageBox(msg, "Confirm Close Group", MB_YESNO | MB_ICONWARNING);
         if(result != IDYES)
         {
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            return;
         }
         
      CloseGroupOrders(grpIdx);
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
   }
   // v2.1: Close Mini Group button handler
   else if(StringFind(sparam, prefix + "_CLOSE_MINI_") >= 0)
   {
      int miniIdx = (int)StringToInteger(StringSubstr(sparam, StringLen(prefix + "_CLOSE_MINI_")));
      
      // Confirmation popup
      int startPair = miniIdx * PAIRS_PER_MINI + 1;
      int endPair = startPair + PAIRS_PER_MINI - 1;
      string msg = StringFormat("Close ALL orders in Mini Group %d (Pairs %d-%d)?", 
                                miniIdx + 1, startPair, endPair);
      int result = MessageBox(msg, "Confirm Close Mini Group", MB_YESNO | MB_ICONWARNING);
      if(result != IDYES)
      {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         return;
      }
      
      CloseMiniGroup(miniIdx);
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      PrintFormat("[v2.1] Manual Close Mini Group %d completed", miniIdx + 1);
   }
}
   else if(id == CHARTEVENT_OBJECT_ENDEDIT)
   {
      string prefix = "STAT_";
      
      // Handle edit field changes
      if(StringFind(sparam, prefix + "_MAX_BUY_") >= 0)
      {
         int pairIndex = (int)StringToInteger(StringSubstr(sparam, StringLen(prefix + "_MAX_BUY_")));
         string value = ObjectGetString(0, sparam, OBJPROP_TEXT);
         int newMax = (int)StringToInteger(value);
         if(newMax >= 1)
         {
            // v3.3.0: Update total max orders (Main + Grid)
            g_pairs[pairIndex].maxOrderBuy = newMax;
         }
      }
      else if(StringFind(sparam, prefix + "_MAX_SELL_") >= 0)
      {
         int pairIndex = (int)StringToInteger(StringSubstr(sparam, StringLen(prefix + "_MAX_SELL_")));
         string value = ObjectGetString(0, sparam, OBJPROP_TEXT);
         int newMax = (int)StringToInteger(value);
         if(newMax >= 1)
         {
            // v3.3.0: Update total max orders (Main + Grid)
            g_pairs[pairIndex].maxOrderSell = newMax;
         }
      }
      else if(StringFind(sparam, prefix + "_TGT_BUY_") >= 0)
      {
         int pairIndex = (int)StringToInteger(StringSubstr(sparam, StringLen(prefix + "_TGT_BUY_")));
         string value = ObjectGetString(0, sparam, OBJPROP_TEXT);
         double newTarget = StringToDouble(value);
         g_pairs[pairIndex].targetBuy = newTarget;
      }
      else if(StringFind(sparam, prefix + "_TGT_SELL_") >= 0)
      {
         int pairIndex = (int)StringToInteger(StringSubstr(sparam, StringLen(prefix + "_TGT_SELL_")));
         string value = ObjectGetString(0, sparam, OBJPROP_TEXT);
         double newTarget = StringToDouble(value);
         g_pairs[pairIndex].targetSell = newTarget;
      }
      else if(sparam == prefix + "_TOTAL_TARGET")
      {
         string value = ObjectGetString(0, sparam, OBJPROP_TEXT);
         g_totalTarget = StringToDouble(value);
      }
   }
}

//+------------------------------------------------------------------+
//| Toggle Buy Side Status                                             |
//+------------------------------------------------------------------+
void ToggleBuySide(int pairIndex)
{
   if(!g_pairs[pairIndex].enabled) return;
   
   if(g_pairs[pairIndex].directionBuy == 0)
   {
      g_pairs[pairIndex].directionBuy = -1;  // Off -> Ready
   }
   else if(g_pairs[pairIndex].directionBuy == -1)
   {
      g_pairs[pairIndex].directionBuy = 0;   // Ready -> Off
   }
   // If directionBuy == 1 (Active), don't toggle - must close first
}

//+------------------------------------------------------------------+
//| Toggle Sell Side Status                                            |
//+------------------------------------------------------------------+
void ToggleSellSide(int pairIndex)
{
   if(!g_pairs[pairIndex].enabled) return;
   
   if(g_pairs[pairIndex].directionSell == 0)
   {
      g_pairs[pairIndex].directionSell = -1;  // Off -> Ready
   }
   else if(g_pairs[pairIndex].directionSell == -1)
   {
      g_pairs[pairIndex].directionSell = 0;   // Ready -> Off
   }
   // If directionSell == 1 (Active), don't toggle - must close first
}

//+------------------------------------------------------------------+
//| Start All Pairs                                                    |
//+------------------------------------------------------------------+
void StartAllPairs()
{
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(g_pairs[i].enabled)
      {
         if(g_pairs[i].directionBuy == 0) g_pairs[i].directionBuy = -1;
         if(g_pairs[i].directionSell == 0) g_pairs[i].directionSell = -1;
      }
   }
   g_isPaused = false;
   g_pauseReason = "";
}

//+------------------------------------------------------------------+
//| Stop All Pairs                                                     |
//+------------------------------------------------------------------+
void StopAllPairs()
{
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(g_pairs[i].directionBuy == -1) g_pairs[i].directionBuy = 0;
      if(g_pairs[i].directionSell == -1) g_pairs[i].directionSell = 0;
   }
}

//+------------------------------------------------------------------+
//| Count Active Trades                                                |
//+------------------------------------------------------------------+
int CountActiveTrades()
{
   int count = 0;
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(g_pairs[i].directionBuy == 1) count++;
      if(g_pairs[i].directionSell == 1) count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| v3.2.7: Check Auto-Resume After DD                                 |
//+------------------------------------------------------------------+
void CheckAutoResume()
{
   if(!g_isPaused) return;
   if(g_pauseReason != "DD_LIMIT") return;
   if(!InpAutoResumeAfterDD) return;
   if(g_equityAtDDClose <= 0) return;
   
   double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double resumeEquity = g_equityAtDDClose * (InpResumeEquityPercent / 100.0);
   
   if(currentEquity >= resumeEquity)
   {
      PrintFormat("Auto-Resume: Equity %.2f >= Resume Level %.2f (%.1f%% of %.2f)",
                  currentEquity, resumeEquity, InpResumeEquityPercent, g_equityAtDDClose);
      
      g_isPaused = false;
      g_pauseReason = "";
      g_maxEquity = currentEquity;
      
      // Reset all Ready pairs
      for(int i = 0; i < MAX_PAIRS; i++)
      {
         if(g_pairs[i].enabled)
         {
            if(g_pairs[i].directionBuy == 0) g_pairs[i].directionBuy = -1;
            if(g_pairs[i].directionSell == 0) g_pairs[i].directionSell = -1;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| ============= LICENSE VERIFICATION SYSTEM (v3.6.5) ============    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Initialize License System                                          |
//+------------------------------------------------------------------+
bool InitLicense()
{
   g_licenseServerUrl = InpLicenseServer;
   g_licenseCheckInterval = InpLicenseCheckMinutes;
   g_dataSyncInterval = InpDataSyncMinutes;
   
   if(StringLen(g_licenseServerUrl) == 0)
   {
      g_lastLicenseError = "License server URL is empty";
      g_licenseStatus = LICENSE_ERROR;
      return false;
   }
   
   g_licenseStatus = VerifyLicenseWithServer();
   g_lastLicenseCheck = TimeCurrent();
   
   g_isLicenseValid = (g_licenseStatus == LICENSE_VALID || 
                       g_licenseStatus == LICENSE_EXPIRING_SOON);
   
   if(g_isLicenseValid)
   {
      SyncAccountData(SYNC_SCHEDULED);
      g_lastDataSync = TimeCurrent();
   }
   
   return g_isLicenseValid;
}

//+------------------------------------------------------------------+
//| Verify License with Server                                         |
//+------------------------------------------------------------------+
ENUM_LICENSE_STATUS VerifyLicenseWithServer()
{
   string url = g_licenseServerUrl + "/functions/v1/verify-license";
   long accountNumber = AccountInfoInteger(ACCOUNT_LOGIN);
   string jsonRequest = "{\"account_number\":\"" + IntegerToString(accountNumber) + "\"}";
   
   Print("[License] Sending request to: ", url);
   Print("[License] Request body: ", jsonRequest);
   
   string response = "";
   int httpCode = SendLicenseRequest(url, jsonRequest, response);
   
   Print("[License] HTTP Code: ", httpCode);
   Print("[License] Response: ", StringSubstr(response, 0, 200));
   
   if(httpCode != 200)
   {
      g_lastLicenseError = "HTTP Error: " + IntegerToString(httpCode);
      return LICENSE_ERROR;
   }
   
   return ParseVerifyResponse(response);
}

//+------------------------------------------------------------------+
//| Send HTTP POST Request                                             |
//+------------------------------------------------------------------+
int SendLicenseRequest(string url, string jsonData, string &response)
{
   char postData[];
   char result[];
   string headers = "Content-Type: application/json\r\nx-api-key: " + 
                    EA_API_SECRET + "\r\n";
   string resultHeaders;
   
   StringToCharArray(jsonData, postData, 0, StringLen(jsonData));
   ArrayResize(postData, StringLen(jsonData));
   
   int timeout = 10000; // 10 seconds
   int httpCode = WebRequest("POST", url, headers, timeout, postData, result, resultHeaders);
   
   if(httpCode == -1)
   {
      int errorCode = GetLastError();
      Print("[License] WebRequest FAILED! Error code: ", errorCode);
      
      g_lastLicenseError = "WebRequest failed. Error: " + IntegerToString(errorCode);
      
      if(errorCode == 4014)
      {
         g_lastLicenseError = "WebRequest not allowed. Add URL to allowed list:\n" + 
                              "Tools > Options > Expert Advisors > Allow WebRequest\n" +
                              "Add: " + g_licenseServerUrl;
         Print("[License] ERROR 4014: WebRequest not allowed for URL: ", g_licenseServerUrl);
      }
      else if(errorCode == 5200)
      {
         Print("[License] ERROR 5200: Invalid URL format");
      }
      else if(errorCode == 5203)
      {
         Print("[License] ERROR 5203: Connection failed - Check internet");
      }
      return -1;
   }
   
   response = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
   return httpCode;
}

//+------------------------------------------------------------------+
//| Parse Verify License Response                                      |
//+------------------------------------------------------------------+
ENUM_LICENSE_STATUS ParseVerifyResponse(string response)
{
   bool valid = JsonGetBool(response, "valid");
   
   if(!valid)
   {
      string message = JsonGetString(response, "message");
      g_lastLicenseError = message;
      
      if(StringFind(message, "not found") >= 0) return LICENSE_NOT_FOUND;
      if(StringFind(message, "suspended") >= 0) return LICENSE_SUSPENDED;
      if(StringFind(message, "expired") >= 0) return LICENSE_EXPIRED;
      
      return LICENSE_ERROR;
   }
   
   g_customerName = JsonGetString(response, "customer_name");
   g_packageType = JsonGetString(response, "package_type");
   g_tradingSystem = JsonGetString(response, "trading_system");
   g_daysRemaining = JsonGetInt(response, "days_remaining");
   g_isLifetime = JsonGetBool(response, "is_lifetime");
   
   string expiryStr = JsonGetString(response, "expiry_date");
   if(StringLen(expiryStr) > 0 && expiryStr != "null")
   {
      g_expiryDate = StringToTime(StringSubstr(expiryStr, 0, 10));
   }
   
   if(!g_isLifetime && g_daysRemaining <= 7 && g_daysRemaining > 0)
   {
      return LICENSE_EXPIRING_SOON;
   }
   
   return LICENSE_VALID;
}

//+------------------------------------------------------------------+
//| JSON Helper - Get String Value                                     |
//+------------------------------------------------------------------+
string JsonGetString(string json, string key)
{
   string searchKey = "\"" + key + "\":";
   int keyPos = StringFind(json, searchKey);
   if(keyPos < 0) return "";
   
   int valueStart = keyPos + StringLen(searchKey);
   while(valueStart < StringLen(json) && 
         (StringGetCharacter(json, valueStart) == ' ' || 
          StringGetCharacter(json, valueStart) == '"'))
      valueStart++;
   
   if(StringGetCharacter(json, valueStart - 1) != '"') return "";
   
   int valueEnd = StringFind(json, "\"", valueStart);
   if(valueEnd < 0) return "";
   
   return StringSubstr(json, valueStart, valueEnd - valueStart);
}

//+------------------------------------------------------------------+
//| JSON Helper - Get Int Value                                        |
//+------------------------------------------------------------------+
int JsonGetInt(string json, string key)
{
   string searchKey = "\"" + key + "\":";
   int keyPos = StringFind(json, searchKey);
   if(keyPos < 0) return 0;
   
   int valueStart = keyPos + StringLen(searchKey);
   while(valueStart < StringLen(json) && StringGetCharacter(json, valueStart) == ' ')
      valueStart++;
   
   string valueStr = "";
   while(valueStart < StringLen(json))
   {
      ushort ch = StringGetCharacter(json, valueStart);
      if((ch >= '0' && ch <= '9') || ch == '-')
         valueStr += ShortToString(ch);
      else
         break;
      valueStart++;
   }
   
   return (int)StringToInteger(valueStr);
}

//+------------------------------------------------------------------+
//| JSON Helper - Get Bool Value                                       |
//+------------------------------------------------------------------+
bool JsonGetBool(string json, string key)
{
   string searchKey = "\"" + key + "\":";
   int keyPos = StringFind(json, searchKey);
   if(keyPos < 0) return false;
   
   int valueStart = keyPos + StringLen(searchKey);
   while(valueStart < StringLen(json) && StringGetCharacter(json, valueStart) == ' ')
      valueStart++;
   
   return (StringFind(json, "true", valueStart) == valueStart);
}

//+------------------------------------------------------------------+
//| Show License Status Popup                                          |
//+------------------------------------------------------------------+
void ShowLicensePopup(ENUM_LICENSE_STATUS status)
{
   string title = "Statistical EA v3.6.5 - License";
   string message = "";
   uint flags = MB_OK;
   
   switch(status)
   {
      case LICENSE_VALID:
         message = "License Verified Successfully!\n\n";
         message += "Customer: " + g_customerName + "\n";
         message += "Package: " + g_packageType + "\n";
         if(g_isLifetime)
            message += "License Type: LIFETIME\n";
         else
            message += "Days Remaining: " + IntegerToString(g_daysRemaining) + "\n";
         flags = MB_OK | MB_ICONINFORMATION;
         break;
         
      case LICENSE_EXPIRING_SOON:
         message = "License Expiring Soon!\n\n";
         message += "Days Remaining: " + IntegerToString(g_daysRemaining) + "\n";
         message += "Please renew your license.\n";
         message += "Contact: support@moneyx-smart.com";
         flags = MB_OK | MB_ICONWARNING;
         break;
         
      case LICENSE_EXPIRED:
         message = "License Expired!\n\n";
         message += "Trading is disabled.\n";
         message += "Please renew your license.\n";
         message += "Contact: support@moneyx-smart.com";
         flags = MB_OK | MB_ICONERROR;
         break;
         
      case LICENSE_NOT_FOUND:
         message = "Account Not Registered!\n\n";
         message += "Account: " + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "\n\n";
         message += "This account is not in our system.\n";
         message += "Please purchase a license.\n";
         message += "Contact: support@moneyx-smart.com";
         flags = MB_OK | MB_ICONERROR;
         break;
         
      case LICENSE_SUSPENDED:
         message = "License Suspended!\n\n";
         message += "Trading is disabled.\n";
         message += "Contact: support@moneyx-smart.com";
         flags = MB_OK | MB_ICONERROR;
         break;
         
      case LICENSE_ERROR:
         message = "License Verification Error!\n\n";
         message += "Error: " + g_lastLicenseError + "\n\n";
         message += "Check:\n";
         message += "1. Internet connection\n";
         message += "2. WebRequest allowed for:\n";
         message += "   " + g_licenseServerUrl;
         flags = MB_OK | MB_ICONWARNING;
         break;
   }
   
   MessageBox(message, title, flags);
}

//+------------------------------------------------------------------+
//| Calculate Portfolio Statistics from Trade History                  |
//+------------------------------------------------------------------+
void CalculatePortfolioStats(double &totalProfit, double &totalDeposit, double &totalWithdrawal,
                             double &initialBalance, double &maxDrawdown, 
                             int &winTrades, int &lossTrades, int &totalTrades)
{
   totalProfit = 0;
   totalDeposit = 0;
   totalWithdrawal = 0;
   initialBalance = 0;
   maxDrawdown = 0;
   winTrades = 0;
   lossTrades = 0;
   totalTrades = 0;
   
   if(!HistorySelect(0, TimeCurrent()))
   {
      Print("[Portfolio Stats] Failed to select history");
      return;
   }
   
   int totalDeals = HistoryDealsTotal();
   double peakBalance = 0;
   double runningBalance = 0;
   bool firstDeposit = true;
   
   for(int i = 0; i < totalDeals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket > 0)
      {
         ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(dealTicket, DEAL_TYPE);
         ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
         double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
         double dealSwap = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
         double dealCommission = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
         
         if(dealType == DEAL_TYPE_BALANCE)
         {
            if(dealProfit > 0)
            {
               totalDeposit += dealProfit;
               if(firstDeposit)
               {
                  initialBalance = dealProfit;
                  firstDeposit = false;
               }
            }
            else
            {
               totalWithdrawal += MathAbs(dealProfit);
            }
            runningBalance += dealProfit;
         }
         else if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_INOUT)
         {
            double netProfit = dealProfit + dealSwap + dealCommission;
            totalProfit += netProfit;
            runningBalance += netProfit;
            totalTrades++;
            
            if(netProfit >= 0)
               winTrades++;
            else
               lossTrades++;
         }
         
         if(runningBalance > peakBalance)
            peakBalance = runningBalance;
         
         if(peakBalance > 0)
         {
            double currentDD = ((peakBalance - runningBalance) / peakBalance) * 100;
            if(currentDD > maxDrawdown)
               maxDrawdown = currentDD;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Build Trade History JSON Array (last 100 deals)                    |
//+------------------------------------------------------------------+
string BuildTradeHistoryJson()
{
   string json = "[";
   bool first = true;
   
   if(!HistorySelect(0, TimeCurrent()))
   {
      Print("[Trade History] Failed to select history");
      return "[]";
   }
   
   int totalDeals = HistoryDealsTotal();
   int startIdx = MathMax(0, totalDeals - 100);
   
   for(int i = startIdx; i < totalDeals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket > 0)
      {
         ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(dealTicket, DEAL_TYPE);
         ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
         
         if(dealType != DEAL_TYPE_BUY && dealType != DEAL_TYPE_SELL && dealType != DEAL_TYPE_BALANCE)
            continue;
         
         string symbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
         ulong orderTicket = HistoryDealGetInteger(dealTicket, DEAL_ORDER);
         double volume = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
         double price = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
         double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
         double swap = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
         double commission = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
         double sl = HistoryDealGetDouble(dealTicket, DEAL_SL);
         double tp = HistoryDealGetDouble(dealTicket, DEAL_TP);
         string comment = HistoryDealGetString(dealTicket, DEAL_COMMENT);
         long magic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
         datetime dealTime = (datetime)HistoryDealGetInteger(dealTicket, DEAL_TIME);
         
         string dealTypeStr = "unknown";
         if(dealType == DEAL_TYPE_BUY) dealTypeStr = "buy";
         else if(dealType == DEAL_TYPE_SELL) dealTypeStr = "sell";
         else if(dealType == DEAL_TYPE_BALANCE) dealTypeStr = "balance";
         
         string entryTypeStr = "unknown";
         if(dealEntry == DEAL_ENTRY_IN) entryTypeStr = "in";
         else if(dealEntry == DEAL_ENTRY_OUT) entryTypeStr = "out";
         else if(dealEntry == DEAL_ENTRY_INOUT) entryTypeStr = "inout";
         else if(dealEntry == DEAL_ENTRY_STATE) entryTypeStr = "state";
         
         if(!first) json += ",";
         first = false;
         
         json += "{";
         json += "\"deal_ticket\":" + IntegerToString(dealTicket) + ",";
         json += "\"order_ticket\":" + IntegerToString(orderTicket) + ",";
         json += "\"symbol\":\"" + symbol + "\",";
         json += "\"deal_type\":\"" + dealTypeStr + "\",";
         json += "\"entry_type\":\"" + entryTypeStr + "\",";
         json += "\"volume\":" + DoubleToString(volume, 4) + ",";
         json += "\"price\":" + DoubleToString(price, 5) + ",";
         json += "\"sl\":" + DoubleToString(sl, 5) + ",";
         json += "\"tp\":" + DoubleToString(tp, 5) + ",";
         json += "\"profit\":" + DoubleToString(profit, 2) + ",";
         json += "\"swap\":" + DoubleToString(swap, 2) + ",";
         json += "\"commission\":" + DoubleToString(commission, 2) + ",";
         json += "\"magic\":" + IntegerToString(magic) + ",";
         json += "\"comment\":\"" + comment + "\",";
         json += "\"time\":\"" + TimeToString(dealTime, TIME_DATE|TIME_SECONDS) + "\"";
         json += "}";
      }
   }
   
   json += "]";
   return json;
}

//+------------------------------------------------------------------+
//| Sync Account Data with Server (Full Portfolio Stats)               |
//+------------------------------------------------------------------+
bool SyncAccountData(ENUM_SYNC_EVENT eventType)
{
   string url = g_licenseServerUrl + "/functions/v1/sync-account-data";
   
   // Basic account info
   long accountNumber = AccountInfoInteger(ACCOUNT_LOGIN);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double floatingPL = AccountInfoDouble(ACCOUNT_PROFIT);
   double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   int openOrders = PositionsTotal();
   
   // Calculate Drawdown
   double drawdown = 0;
   if(balance > 0)
   {
      drawdown = ((balance - equity) / balance) * 100;
      if(drawdown < 0) drawdown = 0;
   }
   
   // Calculate portfolio statistics
   double totalProfit = 0;
   double totalDeposit = 0;
   double totalWithdrawal = 0;
   double initialBalance = 0;
   double maxDrawdown = 0;
   int winTrades = 0;
   int lossTrades = 0;
   int totalTrades = 0;
   
   CalculatePortfolioStats(totalProfit, totalDeposit, totalWithdrawal, initialBalance, 
                           maxDrawdown, winTrades, lossTrades, totalTrades);
   
   // Event type string
   string eventStr = "scheduled";
   if(eventType == SYNC_ORDER_OPEN) eventStr = "order_open";
   else if(eventType == SYNC_ORDER_CLOSE) eventStr = "order_close";
   
   // Build JSON payload
   string json = "{";
   json += "\"account_number\":\"" + IntegerToString(accountNumber) + "\",";
   json += "\"balance\":" + DoubleToString(balance, 2) + ",";
   json += "\"equity\":" + DoubleToString(equity, 2) + ",";
   json += "\"margin_level\":" + DoubleToString(marginLevel, 2) + ",";
   json += "\"drawdown\":" + DoubleToString(drawdown, 2) + ",";
   json += "\"profit_loss\":" + DoubleToString(floatingPL, 2) + ",";
   json += "\"open_orders\":" + IntegerToString(openOrders) + ",";
   json += "\"floating_pl\":" + DoubleToString(floatingPL, 2) + ",";
   json += "\"total_profit\":" + DoubleToString(totalProfit, 2) + ",";
   // Portfolio stats
   json += "\"initial_balance\":" + DoubleToString(initialBalance, 2) + ",";
   json += "\"total_deposit\":" + DoubleToString(totalDeposit, 2) + ",";
   json += "\"total_withdrawal\":" + DoubleToString(totalWithdrawal, 2) + ",";
   json += "\"max_drawdown\":" + DoubleToString(maxDrawdown, 2) + ",";
   json += "\"win_trades\":" + IntegerToString(winTrades) + ",";
   json += "\"loss_trades\":" + IntegerToString(lossTrades) + ",";
   json += "\"total_trades\":" + IntegerToString(totalTrades) + ",";
   // v3.7.5: EA Name for auto-linking trading system
   json += "\"ea_name\":\"Harmony Dream\",";
   // v3.6.8: EA Status for Admin Dashboard
   UpdateEAStatus();
   json += "\"ea_status\":\"" + g_eaStatus + "\",";
   // v1.8: Account Type Detection (real/demo/contest)
   ENUM_ACCOUNT_TRADE_MODE tradeMode = (ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
   string accountTypeStr = (tradeMode == ACCOUNT_TRADE_MODE_DEMO) ? "demo" : 
                           (tradeMode == ACCOUNT_TRADE_MODE_CONTEST) ? "contest" : "real";
   json += "\"account_type\":\"" + accountTypeStr + "\",";
   json += "\"event_type\":\"" + eventStr + "\"";
   
   // Include trade history on all sync events
   string tradeHistoryJson = BuildTradeHistoryJson();
   if(StringLen(tradeHistoryJson) > 2)  // Not empty array "[]"
   {
      json += ",\"trade_history\":" + tradeHistoryJson;
   }
   
   json += "}";
   
   string response = "";
   int httpCode = SendLicenseRequest(url, json, response);
   
   if(httpCode == 200 && JsonGetBool(response, "success"))
   {
      Print("[Data Sync] Success - Balance: ", balance, ", Trades: ", totalTrades);
      // v3.76: Update successful sync tracking
      g_lastSuccessfulSync = TimeCurrent();
      g_syncFailCount = 0;
      g_lastSyncStatus = "OK";
      return true;
   }
   else
   {
      // v3.76: Enhanced error logging with details
      int lastError = GetLastError();
      PrintFormat("!!! SYNC ERROR !!! HTTP: %d | Error: %d | Response: %s", httpCode, lastError, response);
      g_syncFailCount++;
      g_lastSyncStatus = "Failed";
      return false;
   }
}

//+------------------------------------------------------------------+
//| v3.76: Sync Account Data with Heartbeat (Lightweight)              |
//+------------------------------------------------------------------+
bool SyncAccountDataWithHeartbeat()
{
   string url = g_licenseServerUrl + "/functions/v1/sync-account-data";
   
   // Basic account info
   long accountNumber = AccountInfoInteger(ACCOUNT_LOGIN);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double floatingPL = AccountInfoDouble(ACCOUNT_PROFIT);
   double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   int openOrders = PositionsTotal();
   
   // Calculate Drawdown
   double drawdown = 0;
   if(balance > 0)
   {
      drawdown = ((balance - equity) / balance) * 100;
      if(drawdown < 0) drawdown = 0;
   }
   
   // Get EA Status
   UpdateEAStatus();
   
   // Build lightweight JSON payload (no trade history for heartbeat)
   string json = "{";
   json += "\"account_number\":\"" + IntegerToString(accountNumber) + "\",";
   json += "\"balance\":" + DoubleToString(balance, 2) + ",";
   json += "\"equity\":" + DoubleToString(equity, 2) + ",";
   json += "\"margin_level\":" + DoubleToString(marginLevel, 2) + ",";
   json += "\"drawdown\":" + DoubleToString(drawdown, 2) + ",";
   json += "\"profit_loss\":" + DoubleToString(floatingPL, 2) + ",";
   json += "\"open_orders\":" + IntegerToString(openOrders) + ",";
   json += "\"floating_pl\":" + DoubleToString(floatingPL, 2) + ",";
   json += "\"ea_name\":\"Harmony Dream\",";
   json += "\"ea_status\":\"" + g_eaStatus + "\",";
   // v1.8: Account Type Detection (real/demo/contest)
   ENUM_ACCOUNT_TRADE_MODE tradeModeHB = (ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
   string accountTypeHB = (tradeModeHB == ACCOUNT_TRADE_MODE_DEMO) ? "demo" : 
                          (tradeModeHB == ACCOUNT_TRADE_MODE_CONTEST) ? "contest" : "real";
   json += "\"account_type\":\"" + accountTypeHB + "\",";
   json += "\"event_type\":\"heartbeat\"";
   json += "}";
   
   string response = "";
   int httpCode = SendLicenseRequest(url, json, response);
   
   if(httpCode == 200 && JsonGetBool(response, "success"))
   {
      if(InpDebugMode)
         Print("[Heartbeat] Success - Equity: ", equity);
      return true;
   }
   else
   {
      int lastError = GetLastError();
      PrintFormat("!!! HEARTBEAT ERROR !!! HTTP: %d | Error: %d | Response: %s", httpCode, lastError, response);
      return false;
   }
}

//+------------------------------------------------------------------+
//| Periodic License Check (called from OnTick)                        |
//+------------------------------------------------------------------+
void PeriodicLicenseCheck()
{
   if(g_isTesterMode) return;
   
   datetime currentTime = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(currentTime, dt);
   
   // Check license daily at 05:00
   if(dt.hour == 5 && dt.min == 0)
   {
      if(currentTime - g_lastLicenseCheck >= 3600) // At least 1 hour since last check
      {
         g_licenseStatus = VerifyLicenseWithServer();
         g_lastLicenseCheck = currentTime;
         g_isLicenseValid = (g_licenseStatus == LICENSE_VALID || 
                             g_licenseStatus == LICENSE_EXPIRING_SOON);
         
         // Show popup if license expired or suspended
         if(g_licenseStatus == LICENSE_EXPIRED || g_licenseStatus == LICENSE_SUSPENDED)
         {
            ShowLicensePopup(g_licenseStatus);
         }
      }
   }
   
   // Scheduled data sync at 05:00 and 23:00
   if((dt.hour == 5 || dt.hour == 23) && dt.min == 0)
   {
      if(currentTime - g_lastDataSync >= 3600)
      {
         SyncAccountData(SYNC_SCHEDULED);
         g_lastDataSync = currentTime;
      }
   }
   
   // === v3.76: Heartbeat Sync every 5 minutes ===
   // This ensures the Admin Dashboard always shows the EA as "Online"
   if(currentTime - g_lastHeartbeat >= 300)  // 300 seconds = 5 minutes
   {
      if(SyncAccountDataWithHeartbeat())
      {
         g_lastHeartbeat = currentTime;
         g_lastSuccessfulSync = currentTime;
         g_syncFailCount = 0;
         g_lastSyncStatus = "OK";
      }
      else
      {
         g_syncFailCount++;
         g_lastSyncStatus = "Failed";
         PrintFormat("!!! HEARTBEAT SYNC FAILED !!! Consecutive failures: %d", g_syncFailCount);
      }
   }
}

//+------------------------------------------------------------------+
//| Verify License (Main entry point - backward compatible)            |
//+------------------------------------------------------------------+
bool VerifyLicense()
{
   // Bypass in tester/optimizer
   if(MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_OPTIMIZATION))
   {
      g_isLicenseValid = true;
      g_licenseStatus = LICENSE_VALID;
      g_customerName = "Tester Mode";
      Print("[License] Running in Tester/Optimizer - License check bypassed");
      return true;
   }
   
   // For demo accounts - still verify but allow on error (for testing)
   bool isDemo = (AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_DEMO);
   
   // Initialize license system
   Print("[License] Verifying license for account: ", IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)));
   bool result = InitLicense();
   
   // Always show popup first (even for demo accounts)
   ShowLicensePopup(g_licenseStatus);
   
   // Demo accounts can continue even if license fails (for testing)
   if(isDemo && !result)
   {
      Print("[License] Demo account - allowing trading despite license error");
      g_isLicenseValid = true;
      return true;
   }
   
   // Print license details
   if(result)
   {
      Print("[License] Valid - Customer: ", g_customerName, " | Package: ", g_packageType);
      if(g_isLifetime)
         Print("[License] License Type: LIFETIME");
      else
         Print("[License] Days Remaining: ", g_daysRemaining);
   }
   else
   {
      Print("[License] FAILED - ", g_lastLicenseError);
   }
   
   return result;
}

//+------------------------------------------------------------------+
//| ================ STATISTICAL ENGINE (v3.2.6) ================      |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Update All Pair Data (Correlation and Beta)                        |
//+------------------------------------------------------------------+
void UpdateAllPairData()
{
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(!g_pairs[i].enabled) continue;
      
      // Download history data if enabled
      if(InpAutoDownloadData)
      {
         DownloadHistoryData(i);
      }
      
      // Calculate correlation
      CalculatePairCorrelation(i);
      
      // Calculate hedge ratio (Beta)
      CalculateHedgeRatio(i);
      
      // Calculate dollar-neutral lot sizes
      if(InpUseDollarNeutral)
      {
         CalculateDollarNeutralLots(i);
      }
      
      // Note: Spread history and Z-Score now handled separately by UpdateZScoreData()
   }
}

//+------------------------------------------------------------------+
//| v1.6.7: Update Z-Score Data (Separate from Correlation)            |
//|         Now supports Current Bar (shift=0) and Close Bar (shift=1) |
//+------------------------------------------------------------------+
void UpdateZScoreData()
{
   ENUM_TIMEFRAMES zTF = GetZScoreTimeframe();
   int zBars = GetZScoreBars();
   
   // v1.6.7: Determine shift based on Bar Mode
   int shift = (InpZScoreBarMode == ZSCORE_BAR_CURRENT) ? 0 : 1;
   
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(!g_pairs[i].enabled || !g_pairs[i].dataValid) continue;
      
      // Copy price data using Z-Score timeframe
      double closesA[], closesB[];
      ArrayResize(closesA, zBars + 5);
      ArrayResize(closesB, zBars + 5);
      ArraySetAsSeries(closesA, true);
      ArraySetAsSeries(closesB, true);
      
      // v1.6.7: Use dynamic shift based on Bar Mode (0 = Current, 1 = Close)
      int copiedA = CopyClose(g_pairs[i].symbolA, zTF, shift, zBars, closesA);
      int copiedB = CopyClose(g_pairs[i].symbolB, zTF, shift, zBars, closesB);
      
      if(copiedA < zBars || copiedB < zBars)
      {
         continue;  // Not enough data
      }
      
      // Store in Z-Score specific arrays
      for(int j = 0; j < zBars && j < MAX_LOOKBACK; j++)
      {
         g_pairData[i].zScorePricesA[j] = closesA[j];
         g_pairData[i].zScorePricesB[j] = closesB[j];
      }
      
      // Calculate spread history using Z-Score data
      double beta = g_pairs[i].hedgeRatio;
      for(int j = 0; j < zBars && j < MAX_LOOKBACK; j++)
      {
         double priceA = g_pairData[i].zScorePricesA[j];
         double priceB = g_pairData[i].zScorePricesB[j];
         
         if(priceA > 0 && priceB > 0)
         {
            g_pairData[i].zScoreSpreadHistory[j] = MathLog(priceA) - beta * MathLog(priceB);
         }
      }
      
      // Calculate mean and std dev from Z-Score spread history
      double sum = 0;
      for(int j = 0; j < zBars && j < MAX_LOOKBACK; j++)
      {
         sum += g_pairData[i].zScoreSpreadHistory[j];
      }
      double mean = sum / zBars;
      g_pairs[i].spreadMean = mean;
      
      double sumSqDiff = 0;
      for(int j = 0; j < zBars && j < MAX_LOOKBACK; j++)
      {
         double diff = g_pairData[i].zScoreSpreadHistory[j] - mean;
         sumSqDiff += diff * diff;
      }
      g_pairs[i].spreadStdDev = MathSqrt(sumSqDiff / zBars);
      
      // Current spread is at index 0
      g_pairs[i].currentSpread = g_pairData[i].zScoreSpreadHistory[0];
      
      // Calculate Z-Score
      if(g_pairs[i].spreadStdDev > 0)
      {
         g_pairs[i].zScore = (g_pairs[i].currentSpread - g_pairs[i].spreadMean) / g_pairs[i].spreadStdDev;
      }
      else
      {
         g_pairs[i].zScore = 0;
      }
   }
   
   // v1.6.7: Log Z-Score update with timestamp and mode
   if(InpDebugMode && (!g_isTesterMode || !InpDisableDebugInTester))
   {
      string modeStr = (InpZScoreBarMode == ZSCORE_BAR_CURRENT) ? "Current" : "Close";
      PrintFormat("[Z-SCORE v1.6.7] Mode=%s | Shift=%d | TF=%s | Bars=%d | Updated at %s",
                  modeStr, shift, EnumToString(zTF), zBars,
                  TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES));
      
      for(int i = 0; i < MAX_PAIRS; i++)
      {
         if(g_pairs[i].enabled && g_pairs[i].dataValid)
         {
            PrintFormat("  Pair %d: Z=%.4f | Spread=%.6f | Mean=%.6f | StdDev=%.6f",
                        i + 1, g_pairs[i].zScore,
                        g_pairs[i].currentSpread, g_pairs[i].spreadMean, 
                        g_pairs[i].spreadStdDev);
            break;  // Only log first enabled pair for brevity
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Download History Data for Pair                                     |
//+------------------------------------------------------------------+
void DownloadHistoryData(int pairIndex)
{
   string symbolA = g_pairs[pairIndex].symbolA;
   string symbolB = g_pairs[pairIndex].symbolB;
   
   // Copy data for correlation (using correlation timeframe)
   int count = InpCorrBars;
   double closesA[], closesB[];
   ArrayResize(closesA, count + 5);
   ArrayResize(closesB, count + 5);
   ArraySetAsSeries(closesA, true);
   ArraySetAsSeries(closesB, true);
   
   int copiedA = CopyClose(symbolA, InpCorrTimeframe, 0, count, closesA);
   int copiedB = CopyClose(symbolB, InpCorrTimeframe, 0, count, closesB);
   
   if(copiedA < count || copiedB < count)
   {
      g_pairs[pairIndex].dataValid = false;
      return;
   }
   
   g_pairs[pairIndex].dataValid = true;
   
   // Store in correlation arrays
   for(int i = 0; i < count && i < MAX_LOOKBACK; i++)
   {
      g_pairData[pairIndex].pricesA[i] = closesA[i];
      g_pairData[pairIndex].pricesB[i] = closesB[i];
   }
   
   // Calculate returns for correlation calculation
   for(int i = 0; i < count - 1 && i < MAX_LOOKBACK - 1; i++)
   {
      if(InpCorrMethod == CORR_LOG_RETURNS)
      {
         g_pairData[pairIndex].returnsA[i] = MathLog(closesA[i] / closesA[i + 1]);
         g_pairData[pairIndex].returnsB[i] = MathLog(closesB[i] / closesB[i + 1]);
      }
      else
      {
         g_pairData[pairIndex].returnsA[i] = (closesA[i] - closesA[i + 1]) / closesA[i + 1];
         g_pairData[pairIndex].returnsB[i] = (closesB[i] - closesB[i + 1]) / closesB[i + 1];
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate Pair Correlation (v3.2.1)                                |
//+------------------------------------------------------------------+
void CalculatePairCorrelation(int pairIndex)
{
   if(!g_pairs[pairIndex].dataValid) return;
   
   double correlation = 0;
   
   if(InpCorrMethod == CORR_PRICE_DIRECT)
   {
      correlation = CalculatePearsonCorrelation(pairIndex);
   }
   else
   {
      correlation = CalculateReturnCorrelation(pairIndex);
   }
   
   g_pairs[pairIndex].correlation = correlation;
   g_pairs[pairIndex].correlationType = (correlation >= 0) ? 1 : -1;
}

//+------------------------------------------------------------------+
//| Calculate Pearson Correlation (Price Direct)                       |
//+------------------------------------------------------------------+
double CalculatePearsonCorrelation(int pairIndex)
{
   int n = MathMin(InpCorrBars, MAX_LOOKBACK);
   if(n < 10) return 0;
   
   double sumA = 0, sumB = 0;
   double sumA2 = 0, sumB2 = 0;
   double sumAB = 0;
   
   for(int i = 0; i < n; i++)
   {
      double a = g_pairData[pairIndex].pricesA[i];
      double b = g_pairData[pairIndex].pricesB[i];
      
      sumA += a;
      sumB += b;
      sumA2 += a * a;
      sumB2 += b * b;
      sumAB += a * b;
   }
   
   double meanA = sumA / n;
   double meanB = sumB / n;
   
   double numerator = (sumAB / n) - (meanA * meanB);
   double denomA = MathSqrt((sumA2 / n) - (meanA * meanA));
   double denomB = MathSqrt((sumB2 / n) - (meanB * meanB));
   
   if(denomA == 0 || denomB == 0) return 0;
   
   return numerator / (denomA * denomB);
}

//+------------------------------------------------------------------+
//| Calculate Return Correlation (Percentage/Log Returns)              |
//+------------------------------------------------------------------+
double CalculateReturnCorrelation(int pairIndex)
{
   int n = MathMin(InpCorrBars - 1, MAX_LOOKBACK - 1);
   if(n < 10) return 0;
   
   double sumA = 0, sumB = 0;
   double sumA2 = 0, sumB2 = 0;
   double sumAB = 0;
   
   for(int i = 0; i < n; i++)
   {
      double a = g_pairData[pairIndex].returnsA[i];
      double b = g_pairData[pairIndex].returnsB[i];
      
      sumA += a;
      sumB += b;
      sumA2 += a * a;
      sumB2 += b * b;
      sumAB += a * b;
   }
   
   double meanA = sumA / n;
   double meanB = sumB / n;
   
   double numerator = (sumAB / n) - (meanA * meanB);
   double denomA = MathSqrt((sumA2 / n) - (meanA * meanA));
   double denomB = MathSqrt((sumB2 / n) - (meanB * meanB));
   
   if(denomA == 0 || denomB == 0) return 0;
   
   return numerator / (denomA * denomB);
}

//+------------------------------------------------------------------+
//| Calculate Hedge Ratio (Beta) - v3.2.6                              |
//+------------------------------------------------------------------+
void CalculateHedgeRatio(int pairIndex)
{
   if(!g_pairs[pairIndex].dataValid) return;
   
   // Manual Fixed Mode
   if(InpBetaMode == BETA_MANUAL_FIXED)
   {
      double manualBeta = g_pairs[pairIndex].manualBeta;
      if(manualBeta <= 0) manualBeta = InpManualBetaDefault;
      g_pairs[pairIndex].hedgeRatio = manualBeta;
      return;
   }
   
   // Pip Value Only Mode
   if(InpBetaMode == BETA_PIP_VALUE_ONLY)
   {
      double pipBeta = CalculatePipValueBeta(pairIndex);
      g_pairs[pairIndex].hedgeRatio = pipBeta;
      return;
   }
   
   // Percentage Raw Mode
   if(InpBetaMode == BETA_PERCENTAGE_RAW)
   {
      double pctBeta = CalculatePriceBasedBeta(pairIndex);
      g_pairs[pairIndex].hedgeRatio = pctBeta;
      return;
   }
   
   // Auto + EMA Smoothing Mode (Recommended)
   double pipBeta = CalculatePipValueBeta(pairIndex);
   double pctBeta = CalculatePriceBasedBeta(pairIndex);
   
   // Weighted combination
   double rawBeta = (pipBeta * InpPipBetaWeight) + (pctBeta * (1.0 - InpPipBetaWeight));
   
   // Apply EMA smoothing
   double smoothedBeta;
   if(g_pairs[pairIndex].betaInitialized)
   {
      smoothedBeta = (InpBetaSmoothFactor * rawBeta) + ((1.0 - InpBetaSmoothFactor) * g_pairs[pairIndex].prevBeta);
   }
   else
   {
      smoothedBeta = rawBeta;
      g_pairs[pairIndex].betaInitialized = true;
   }
   
   g_pairs[pairIndex].prevBeta = smoothedBeta;
   g_pairs[pairIndex].hedgeRatio = smoothedBeta;
}

//+------------------------------------------------------------------+
//| Calculate Pip-Value Based Beta (Most Stable)                       |
//+------------------------------------------------------------------+
double CalculatePipValueBeta(int pairIndex)
{
   string symbolA = g_pairs[pairIndex].symbolA;
   string symbolB = g_pairs[pairIndex].symbolB;
   
   double pipValueA = GetPipValue(symbolA);
   double pipValueB = GetPipValue(symbolB);
   
   if(pipValueB <= 0) return 1.0;
   
   return pipValueA / pipValueB;
}

//+------------------------------------------------------------------+
//| Calculate Notional Value per Lot for Symbol                        |
//+------------------------------------------------------------------+
double GetNotionalValuePerLot(string symbol)
{
   double price = SymbolInfoDouble(symbol, SYMBOL_BID);
   double contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   
   // Get base currency
   string base = StringSubstr(symbol, 0, 3);
   
   // If base is USD, notional = price * contract
   if(base == "USD" || base == "XAU" || base == "XAG")
   {
      return price * contractSize;
   }
   
   // Convert to USD using base currency rate
   string baseUsdPair = base + "USD";
   double baseUsdRate = 0;
   
   if(SymbolSelect(baseUsdPair, true))
   {
      baseUsdRate = SymbolInfoDouble(baseUsdPair, SYMBOL_BID);
   }
   
   if(baseUsdRate > 0)
   {
      return baseUsdRate * contractSize;  // e.g., GBPUSD(1.26) * 100000 = 126,000 USD
   }
   
   // Fallback: Try USDXXX pair and invert
   string usdBasePair = "USD" + base;
   double usdBaseRate = 0;
   
   if(SymbolSelect(usdBasePair, true))
   {
      usdBaseRate = SymbolInfoDouble(usdBasePair, SYMBOL_BID);
   }
   
   if(usdBaseRate > 0)
   {
      return (1.0 / usdBaseRate) * contractSize;
   }
   
   // Last fallback: use price as-is (may be inaccurate for some exotic pairs)
   return price * contractSize;
}

//+------------------------------------------------------------------+
//| Calculate Price-Based Beta using Percentage Change                 |
//+------------------------------------------------------------------+
double CalculatePriceBasedBeta(int pairIndex)
{
   int n = MathMin(InpCorrBars, MAX_LOOKBACK);
   if(n < 11) return 1.0;  // Need at least 11 bars for 10 changes
   
   string symbolA = g_pairs[pairIndex].symbolA;
   string symbolB = g_pairs[pairIndex].symbolB;
   
   double sumA = 0, sumB = 0;
   double sumA2 = 0;
   double sumAB = 0;
   int count = 0;
   
   // Calculate Beta from Percentage Changes (scale-independent)
   for(int i = 0; i < n - 1; i++)
   {
      double priceA_t = g_pairData[pairIndex].pricesA[i];
      double priceA_t1 = g_pairData[pairIndex].pricesA[i + 1];
      double priceB_t = g_pairData[pairIndex].pricesB[i];
      double priceB_t1 = g_pairData[pairIndex].pricesB[i + 1];
      
      if(priceA_t1 <= 0 || priceB_t1 <= 0) continue;
      
      // Percentage change = (price_t - price_t1) / price_t1
      double pctA = (priceA_t - priceA_t1) / priceA_t1;
      double pctB = (priceB_t - priceB_t1) / priceB_t1;
      
      sumA += pctA;
      sumB += pctB;
      sumA2 += pctA * pctA;
      sumAB += pctA * pctB;
      count++;
   }
   
   if(count < 10) return 1.0;
   
   double meanA = sumA / count;
   double meanB = sumB / count;
   
   // Beta = Cov(A,B) / Var(A) from percentage changes
   double covariance = (sumAB / count) - (meanA * meanB);
   double varianceA = (sumA2 / count) - (meanA * meanA);
   
   if(varianceA <= 0) return 1.0;
   
   // For negative correlation, we still want positive beta for hedge ratio
   double beta = MathAbs(covariance / varianceA);
   
   // Clamp beta to reasonable range (0.1 to 10.0)
   beta = MathMax(0.1, MathMin(10.0, beta));
   
   return beta;
}

//+------------------------------------------------------------------+
//| ================ LOT SIZING ENGINE ================                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Normalize Lot Size for Symbol (v3.3.5)                             |
//+------------------------------------------------------------------+
double NormalizeLot(string symbol, double lot)
{
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   
   // v3.3.5: Validate symbol info is available with warning
   if(minLot == 0 || maxLot == 0)
   {
      minLot = 0.01;
      maxLot = 100.0;
      PrintFormat("WARNING: %s volume info not available, using defaults (min:%.2f max:%.2f)", 
                  symbol, minLot, maxLot);
   }
   
   if(stepLot == 0) stepLot = 0.01;  // Fallback
   
   double originalLot = lot;
   
   // Normalize to step
   lot = MathFloor(lot / stepLot) * stepLot;
   
   // Clamp to min/max
   if(lot < minLot)
   {
      // v3.3.5: Log when forced to use minimum (only if original was larger)
      if(InpDebugMode && originalLot > minLot)
      {
         PrintFormat("WARNING: %s lot %.4f -> %.2f (forced to minLot)", symbol, originalLot, minLot);
      }
      lot = minLot;
   }
   if(lot > maxLot) lot = maxLot;
   
   // v1.6.5: Apply scaled max lot
   double scaledMaxLot = GetScaledMaxLot();
   if(lot > scaledMaxLot) lot = scaledMaxLot;
   
   // Round to avoid floating point issues
   lot = NormalizeDouble(lot, 2);
   
   return lot;
}

//+------------------------------------------------------------------+
//| ================ AUTO BALANCE SCALING (v1.6.5) ================    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Scale Factor (v1.6.5)                                          |
//+------------------------------------------------------------------+
double GetScaleFactor()
{
   // If auto scaling disabled, return 1.0 (no scaling)
   if(!InpEnableAutoScaling || InpBaseAccountSize <= 0)
      return 1.0;
   
   // Determine account size to use for scaling
   double accountSize;
   if(InpEnableFixedScale && InpFixedScaleAccount > 0)
   {
      accountSize = InpFixedScaleAccount;  // Fixed Mode
   }
   else
   {
      accountSize = AccountInfoDouble(ACCOUNT_BALANCE);  // Dynamic Mode
   }
   
   if(accountSize <= 0) return 1.0;
   
   // Calculate scale factor
   double factor = accountSize / InpBaseAccountSize;
   
   // Apply safety limits
   factor = MathMax(InpScaleMin, MathMin(InpScaleMax, factor));
   
   return NormalizeDouble(factor, 4);
}

//+------------------------------------------------------------------+
//| Apply Scale to Lot Size (v1.6.5)                                   |
//+------------------------------------------------------------------+
double ApplyScaleLot(string symbol, double baseLot)
{
   double scaledLot = baseLot * GetScaleFactor();
   return NormalizeLot(symbol, scaledLot);
}

//+------------------------------------------------------------------+
//| Get Scaled Base Lot (v1.6.5)                                       |
//+------------------------------------------------------------------+
double GetScaledBaseLot(string symbol = "")
{
   double scaledLot = InpBaseLot * GetScaleFactor();
   if(symbol != "")
      return NormalizeLot(symbol, scaledLot);
   return NormalizeDouble(scaledLot, 4);
}

//+------------------------------------------------------------------+
//| Get Scaled Max Lot (v1.6.5)                                        |
//+------------------------------------------------------------------+
double GetScaledMaxLot()
{
   return NormalizeDouble(InpMaxLot * GetScaleFactor(), 2);
}

//+------------------------------------------------------------------+
//| Apply Scale to Dollar Value (v1.6.5)                               |
//+------------------------------------------------------------------+
double ApplyScaleDollar(double baseDollar)
{
   if(baseDollar <= 0) return 0;  // 0 = Disabled, keep it disabled
   return NormalizeDouble(baseDollar * GetScaleFactor(), 2);
}

//+------------------------------------------------------------------+
//| Get Scaled Grid Custom Lot (v1.6.5)                                |
//+------------------------------------------------------------------+
double GetScaledGridLossCustomLot(string symbol)
{
   return ApplyScaleLot(symbol, InpGridLossCustomLot);
}

double GetScaledGridProfitCustomLot(string symbol)
{
   return ApplyScaleLot(symbol, InpGridProfitCustomLot);
}

//+------------------------------------------------------------------+
//| Get Scaled Group Target (v1.6.5)                                   |
//+------------------------------------------------------------------+
double GetScaledGroupClosedTarget(int groupIndex)
{
   double baseTarget = 0;
   switch(groupIndex)
   {
      case 0: baseTarget = InpGroup1ClosedTarget; break;
      case 1: baseTarget = InpGroup2ClosedTarget; break;
      case 2: baseTarget = InpGroup3ClosedTarget; break;
      case 3: baseTarget = InpGroup4ClosedTarget; break;
      case 4: baseTarget = InpGroup5ClosedTarget; break;
      // v2.0: Removed case 5 (only 5 groups now)
   }
   return ApplyScaleDollar(baseTarget);
}

double GetScaledGroupFloatingTarget(int groupIndex)
{
   double baseTarget = 0;
   switch(groupIndex)
   {
      case 0: baseTarget = InpGroup1FloatingTarget; break;
      case 1: baseTarget = InpGroup2FloatingTarget; break;
      case 2: baseTarget = InpGroup3FloatingTarget; break;
      case 3: baseTarget = InpGroup4FloatingTarget; break;
      case 4: baseTarget = InpGroup5FloatingTarget; break;
      // v2.0: Removed case 5 (only 5 groups now)
   }
   return ApplyScaleDollar(baseTarget);
}

double GetScaledGroupTargetBuy(int groupIndex)
{
   double baseTarget = 0;
   switch(groupIndex)
   {
      case 0: baseTarget = InpGroup1TargetBuy; break;
      case 1: baseTarget = InpGroup2TargetBuy; break;
      case 2: baseTarget = InpGroup3TargetBuy; break;
      case 3: baseTarget = InpGroup4TargetBuy; break;
      case 4: baseTarget = InpGroup5TargetBuy; break;
      // v2.0: Removed case 5 (only 5 groups now)
   }
   return ApplyScaleDollar(baseTarget);
}

double GetScaledGroupTargetSell(int groupIndex)
{
   double baseTarget = 0;
   switch(groupIndex)
   {
      case 0: baseTarget = InpGroup1TargetSell; break;
      case 1: baseTarget = InpGroup2TargetSell; break;
      case 2: baseTarget = InpGroup3TargetSell; break;
      case 3: baseTarget = InpGroup4TargetSell; break;
      case 4: baseTarget = InpGroup5TargetSell; break;
      // v2.0: Removed case 5 (only 5 groups now)
   }
   return ApplyScaleDollar(baseTarget);
}

//+------------------------------------------------------------------+
//| v1.6.6: Get Real-Time Scaled Closed Target (dynamic calculation)   |
//+------------------------------------------------------------------+
double GetRealTimeScaledClosedTarget(int groupIndex)
{
   // Use BASE value from g_groups and apply current scale factor
   return ApplyScaleDollar(g_groups[groupIndex].closedTarget);
}

//+------------------------------------------------------------------+
//| v1.6.6: Get Real-Time Scaled Floating Target                       |
//+------------------------------------------------------------------+
double GetRealTimeScaledFloatingTarget(int groupIndex)
{
   return ApplyScaleDollar(g_groups[groupIndex].floatingTarget);
}

//+------------------------------------------------------------------+
//| v1.6.6: Get Real-Time Scaled Target Buy                            |
//+------------------------------------------------------------------+
double GetRealTimeScaledTargetBuy(int groupIndex)
{
   return ApplyScaleDollar(g_groups[groupIndex].targetBuy);
}

//+------------------------------------------------------------------+
//| v1.6.6: Get Real-Time Scaled Target Sell                           |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| v2.0: Get Scaled Mini Group Target                                  |
//+------------------------------------------------------------------+
double GetScaledMiniGroupTarget(int miniIndex)
{
   double baseTarget = 0;
   switch(miniIndex)
   {
      case 0:  baseTarget = InpMini1Target;  break;
      case 1:  baseTarget = InpMini2Target;  break;
      case 2:  baseTarget = InpMini3Target;  break;
      case 3:  baseTarget = InpMini4Target;  break;
      case 4:  baseTarget = InpMini5Target;  break;
      case 5:  baseTarget = InpMini6Target;  break;
      case 6:  baseTarget = InpMini7Target;  break;
      case 7:  baseTarget = InpMini8Target;  break;
      case 8:  baseTarget = InpMini9Target;  break;
      case 9:  baseTarget = InpMini10Target; break;
      case 10: baseTarget = InpMini11Target; break;
      case 11: baseTarget = InpMini12Target; break;
      case 12: baseTarget = InpMini13Target; break;
      case 13: baseTarget = InpMini14Target; break;
      case 14: baseTarget = InpMini15Target; break;
   }
   return ApplyScaleDollar(baseTarget);
}

// (v2.0: UpdateMiniGroupProfits moved to line ~1862 - avoid duplicate)

//+------------------------------------------------------------------+
//| v2.0: Check Mini Group Targets and Close if Reached                |
//+------------------------------------------------------------------+
void CheckMiniGroupTargets()
{
   for(int m = 0; m < MAX_MINI_GROUPS; m++)
   {
      double target = GetScaledMiniGroupTarget(m);
      if(target <= 0) continue;  // Target disabled
      if(g_miniGroups[m].targetTriggered) continue;  // Already triggered
      
      double totalProfit = g_miniGroups[m].totalProfit;
      
      if(totalProfit >= target)
      {
         g_miniGroups[m].targetTriggered = true;
         
         PrintFormat("[v2.0] MINI GROUP %d TARGET REACHED! Profit: $%.2f >= Target: $%.2f",
                     m + 1, totalProfit, target);
         
         // Close all positions in this Mini Group (2 pairs)
         CloseMiniGroup(m);
      }
   }
}

//+------------------------------------------------------------------+
//| v2.0: Close All Positions in a Mini Group                          |
//+------------------------------------------------------------------+
void CloseMiniGroup(int miniIndex)
{
   int startPair = miniIndex * PAIRS_PER_MINI;
   int groupIdx = GetGroupFromMini(miniIndex);
   double closedProfit = 0;
   
   PrintFormat("[v2.0] Closing Mini Group %d (Pairs %d-%d) | Parent Group: %d",
               miniIndex + 1, startPair + 1, startPair + PAIRS_PER_MINI, groupIdx + 1);
   
   for(int p = startPair; p < startPair + PAIRS_PER_MINI && p < MAX_PAIRS; p++)
   {
      if(!g_pairs[p].enabled) continue;
      
      // v2.1.3: Close Buy side (profit is added to Mini Group inside CloseBuySide)
      if(g_pairs[p].directionBuy == 1)
      {
         CloseBuySide(p);
      }
      
      // v2.1.3: Close Sell side (profit is added to Mini Group inside CloseSellSide)
      if(g_pairs[p].directionSell == 1)
      {
         CloseSellSide(p);
      }
   }
   
   // v2.1.3: Get total accumulated closed profit from Mini Group (already updated by CloseBuySide/CloseSellSide)
   double finalClosedProfit = g_miniGroups[miniIndex].closedProfit;
   
   // v2.1.3: Note - profit was already added to Group via CloseBuySide/CloseSellSide
   // No need to add again here to avoid double-counting
   
   // v2.1.5: Use dedicated reset function (hierarchy-aware)
   ResetMiniGroupProfit(miniIndex);
   
   PrintFormat("[v2.1.3] Mini Group %d TARGET CLOSED | Accumulated: $%.2f | Mini RESET to $0 for new cycle",
               miniIndex + 1, finalClosedProfit);
}

double GetRealTimeScaledTargetSell(int groupIndex)
{
   return ApplyScaleDollar(g_groups[groupIndex].targetSell);
}

//+------------------------------------------------------------------+
//| Get Pip Value for Symbol (v3.3.5 - Robust)                         |
//+------------------------------------------------------------------+
double GetPipValue(string symbol)
{
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   
   // v3.3.5: Return fallback value instead of 0 to prevent division issues
   if(tickSize == 0 || point == 0)
   {
      // Try alternative calculation
      double contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
      if(contractSize > 0)
      {
         // Approximate pip value for common pairs
         if(InpDebugMode)
         {
            PrintFormat("WARNING: %s tick info not available, using estimate from contract size", symbol);
         }
         return contractSize * 0.0001;  // Rough estimate
      }
      // Return 1.0 instead of 0 to prevent division by zero
      if(InpDebugMode)
      {
         PrintFormat("WARNING: %s pip value unavailable, returning fallback 1.0", symbol);
      }
      return 1.0;
   }
   
   return (tickValue / tickSize) * point;
}

//+------------------------------------------------------------------+
//| Calculate Dollar-Neutral Lot Sizes (v1.6.5 - with Auto Scaling)    |
//+------------------------------------------------------------------+
void CalculateDollarNeutralLots(int pairIndex)
{
   // v1.6.5: Use scaled base lot
   double baseLot = GetScaledBaseLot();
   double hedgeRatio = g_pairs[pairIndex].hedgeRatio;
   
   string symbolA = g_pairs[pairIndex].symbolA;
   string symbolB = g_pairs[pairIndex].symbolB;
   
   double pipValueA = GetPipValue(symbolA);
   double pipValueB = GetPipValue(symbolB);
   
   // v3.3.4: Enhanced validation with warning logs
   if(pipValueA == 0 || pipValueB == 0)
   {
      PrintFormat("WARNING Pair %d: Pip values invalid (A:%.5f B:%.5f) - Using normalized base lot %.4f for both",
                  pairIndex + 1, pipValueA, pipValueB, baseLot);
      
      // Normalize base lot for each symbol
      g_pairs[pairIndex].lotBuyA = NormalizeLot(symbolA, baseLot);
      g_pairs[pairIndex].lotBuyB = NormalizeLot(symbolB, baseLot);
      g_pairs[pairIndex].lotSellA = NormalizeLot(symbolA, baseLot);
      g_pairs[pairIndex].lotSellB = NormalizeLot(symbolB, baseLot);
      return;
   }
   
   // LotA = Base Lot (normalized)
   double lotA = NormalizeLot(symbolA, baseLot);
   
   // LotB = LotA × β × (PipValueA / PipValueB)
   double rawLotB = baseLot * hedgeRatio * (pipValueA / pipValueB);
   double lotB = NormalizeLot(symbolB, rawLotB);
   
   // v3.3.4: Ensure lotB is not too small
   double minLotB = SymbolInfoDouble(symbolB, SYMBOL_VOLUME_MIN);
   if(lotB < minLotB)
   {
      PrintFormat("WARNING Pair %d: Calculated lotB (%.4f) below minimum (%.2f) - Using minimum",
                  pairIndex + 1, rawLotB, minLotB);
      lotB = minLotB;
   }
   
   // Set for both Buy and Sell sides
   g_pairs[pairIndex].lotBuyA = lotA;
   g_pairs[pairIndex].lotBuyB = lotB;
   g_pairs[pairIndex].lotSellA = lotA;
   g_pairs[pairIndex].lotSellB = lotB;
   
   // v1.6.5: Debug log for lot calculation with scaling info
   if(InpDebugMode)
   {
      double scaleFactor = GetScaleFactor();
      PrintFormat("Pair %d Lots: A=%.2f B=%.2f (BaseLot=%.4f [%.2f×%.2fx], Beta=%.4f, PipA=%.5f, PipB=%.5f)", 
                  pairIndex + 1, lotA, lotB, baseLot, InpBaseLot, scaleFactor, hedgeRatio, pipValueA, pipValueB);
   }
}

//+------------------------------------------------------------------+
//| ================ RSI ON SPREAD (v3.4.0) ================           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calculate RSI on Spread for Pair (v3.4.0)                          |
//+------------------------------------------------------------------+
void CalculateRSIonSpread(int pairIndex)
{
   if(!InpUseRSISpreadFilter) return;
   if(!g_pairs[pairIndex].dataValid) return;
   
   int period = InpRSISpreadPeriod;
   int barsNeeded = period + 1;
   
   // Check if we have enough spread history data
   if(barsNeeded > MAX_LOOKBACK)
   {
      g_pairs[pairIndex].rsiSpread = 50;  // Neutral
      return;
   }
   
   // Calculate RSI from Spread History (zScoreSpreadHistory)
   double avgGain = 0;
   double avgLoss = 0;
   int validCount = 0;
   
   for(int i = 0; i < period; i++)
   {
      double currentSpread = g_pairData[pairIndex].zScoreSpreadHistory[i];
      double prevSpread = g_pairData[pairIndex].zScoreSpreadHistory[i + 1];
      
      if(prevSpread == 0) continue;  // Skip invalid data
      
      double change = currentSpread - prevSpread;
      
      if(change > 0)
         avgGain += change;
      else
         avgLoss += MathAbs(change);
      
      validCount++;
   }
   
   if(validCount < period / 2)
   {
      g_pairs[pairIndex].rsiSpread = 50;  // Not enough data, neutral
      return;
   }
   
   avgGain /= period;
   avgLoss /= period;
   
   // Calculate RSI: 100 - (100 / (1 + RS))
   double rs = (avgLoss == 0) ? 100 : avgGain / avgLoss;
   g_pairs[pairIndex].rsiSpread = 100.0 - (100.0 / (1.0 + rs));
   
   // Clamp to 0-100 range
   if(g_pairs[pairIndex].rsiSpread < 0) g_pairs[pairIndex].rsiSpread = 0;
   if(g_pairs[pairIndex].rsiSpread > 100) g_pairs[pairIndex].rsiSpread = 100;
}

//+------------------------------------------------------------------+
//| Calculate RSI on Spread for All Pairs (v3.4.0)                     |
//+------------------------------------------------------------------+
void CalculateAllRSIonSpread()
{
   if(!InpUseRSISpreadFilter) return;
   
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(g_pairs[i].enabled && g_pairs[i].dataValid)
      {
         CalculateRSIonSpread(i);
      }
   }
}

//+------------------------------------------------------------------+
//| Check RSI Entry Confirmation (v3.4.0)                              |
//+------------------------------------------------------------------+
bool CheckRSIEntryConfirmation(int pairIndex, string side)
{
   // If filter is disabled, always confirm
   if(!InpUseRSISpreadFilter) return true;
   
   double rsi = g_pairs[pairIndex].rsiSpread;
   
   if(side == "BUY")
   {
      // BUY: RSI should be in Oversold zone (< InpRSIOversold)
      return (rsi <= InpRSIOversold);
   }
   else if(side == "SELL")
   {
      // SELL: RSI should be in Overbought zone (> InpRSIOverbought)
      return (rsi >= InpRSIOverbought);
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| ================ CDC ACTION ZONE (v3.5.0) ================         |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| v1.6.3: Force historical data download for symbol                  |
//| Returns: true if data is ready, false if still loading            |
//+------------------------------------------------------------------+
bool EnsureHistoryLoaded(string symbol, ENUM_TIMEFRAMES period, int minBars)
{
   // Step 1: Ensure symbol is selected in Market Watch
   if(!SymbolSelect(symbol, true))
   {
      if(InpDebugMode)
         PrintFormat("[HISTORY] %s: Cannot select symbol", symbol);
      return false;
   }
   
   // Step 2: Check if already synchronized
   bool isSynced = (bool)SeriesInfoInteger(symbol, period, SERIES_SYNCHRONIZED);
   int currentBars = Bars(symbol, period);
   
   if(isSynced && currentBars >= minBars)
      return true;  // Already loaded!
   
   // Step 3: Force download by requesting data
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   // Request more bars than needed to trigger server download
   int requestBars = minBars * 2;
   int copied = CopyRates(symbol, period, 0, requestBars, rates);
   
   if(copied >= minBars)
   {
      if(InpDebugMode)
         PrintFormat("[HISTORY] %s: Downloaded %d/%d bars on %s", 
                     symbol, copied, requestBars, EnumToString(period));
      return true;
   }
   
   // Step 4: Still loading - return false
   if(InpDebugMode)
   {
      PrintFormat("[HISTORY] %s: Still loading (%d/%d bars, synced=%s)", 
                  symbol, currentBars, minBars, isSynced ? "true" : "false");
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Calculate EMA for CDC (v3.5.0)                                     |
//+------------------------------------------------------------------+
void CalculateCDC_EMA(double &src[], double &result[], int period, int size)
{
   if(size < period) return;
   
   double multiplier = 2.0 / (period + 1);
   
   // Initial SMA
   double sum = 0;
   for(int i = size - period; i < size; i++)
      sum += src[i];
   result[size - 1] = sum / period;
   
   // EMA calculation from oldest to newest
   for(int i = size - 2; i >= 0; i--)
      result[i] = (src[i] - result[i + 1]) * multiplier + result[i + 1];
}

//+------------------------------------------------------------------+
//| Calculate CDC Action Zone for Single Symbol (v3.7.1)               |
//| Returns: true if calculation succeeded, false if data not ready   |
//+------------------------------------------------------------------+
bool CalculateCDCForSymbol(string symbol, string &trend, double &fastEMA, double &slowEMA)
{
   trend = "NEUTRAL";
   fastEMA = 0;
   slowEMA = 0;
   
   // Check if symbol exists and can be selected
   if(!SymbolSelect(symbol, true))
   {
      if(InpDebugMode)
         Print("[CDC] Symbol not found or cannot be selected: ", symbol);
      return false;  // v3.7.1: Return false for LOADING state
   }
   
   // v1.6.3: Force history download if needed
   int minBarsRequired = InpCDCSlowPeriod + 10;
   if(!EnsureHistoryLoaded(symbol, InpCDCTimeframe, minBarsRequired))
   {
      // Still loading - EnsureHistoryLoaded already printed debug info
      return false;
   }
   
   // v3.7.1: Guard - Check Bars available (should pass after EnsureHistoryLoaded)
   int barsAvailable = Bars(symbol, InpCDCTimeframe);
   
   double closeArr[], highArr[], lowArr[], openArr[];
   // Set as series - index 0 = newest (matches Moneyx Smart System / CalculateCDC_EMA design)
   ArraySetAsSeries(closeArr, true);
   ArraySetAsSeries(highArr, true);
   ArraySetAsSeries(lowArr, true);
   ArraySetAsSeries(openArr, true);
   
   int barsNeeded = InpCDCSlowPeriod * 3 + 50;
   
   // v3.7.1: Copy Close with error checking
   int copied = CopyClose(symbol, InpCDCTimeframe, 0, barsNeeded, closeArr);
   if(copied < 0)
   {
      int err = GetLastError();
      if(InpDebugMode)
         PrintFormat("[CDC] %s: CopyClose failed (error=%d), status=LOADING", symbol, err);
      return false;  // v3.7.1: Return false for LOADING state
   }
   if(copied < minBarsRequired) 
   {
      if(InpDebugMode)
         PrintFormat("[CDC] %s: Insufficient data - got %d/%d bars (min: %d) on %s", 
                     symbol, copied, barsNeeded, minBarsRequired, EnumToString(InpCDCTimeframe));
      return false;  // v3.7.1: Return false for LOADING state
   }
   
   // Use actual copied count if less than requested (fallback)
   int actualBars = MathMin(copied, barsNeeded);
   
   // v3.7.1: Copy other arrays with error checking
   int copiedHigh = CopyHigh(symbol, InpCDCTimeframe, 0, actualBars, highArr);
   if(copiedHigh < 0 || copiedHigh < actualBars) 
   {
      if(InpDebugMode)
         PrintFormat("[CDC] %s: CopyHigh failed (got %d, error=%d)", symbol, copiedHigh, GetLastError());
      return false;
   }
   
   int copiedLow = CopyLow(symbol, InpCDCTimeframe, 0, actualBars, lowArr);
   if(copiedLow < 0 || copiedLow < actualBars) 
   {
      if(InpDebugMode)
         PrintFormat("[CDC] %s: CopyLow failed (got %d, error=%d)", symbol, copiedLow, GetLastError());
      return false;
   }
   
   int copiedOpen = CopyOpen(symbol, InpCDCTimeframe, 0, actualBars, openArr);
   if(copiedOpen < 0 || copiedOpen < actualBars) 
   {
      if(InpDebugMode)
         PrintFormat("[CDC] %s: CopyOpen failed (got %d, error=%d)", symbol, copiedOpen, GetLastError());
      return false;
   }
   
   // Calculate OHLC4
   double ohlc4[];
   ArrayResize(ohlc4, actualBars);
   for(int i = 0; i < actualBars; i++)
      ohlc4[i] = (openArr[i] + highArr[i] + lowArr[i] + closeArr[i]) / 4.0;
   
   // Calculate AP (Smoothed OHLC4 with EMA2)
   double ap[];
   ArrayResize(ap, actualBars);
   CalculateCDC_EMA(ohlc4, ap, 2, actualBars);
   
   // Calculate Fast & Slow EMA
   double fast[], slow[];
   ArrayResize(fast, actualBars);
   ArrayResize(slow, actualBars);
   CalculateCDC_EMA(ap, fast, InpCDCFastPeriod, actualBars);
   CalculateCDC_EMA(ap, slow, InpCDCSlowPeriod, actualBars);
   
   // v3.7.1: Guard - Check array size before access
   if(ArraySize(fast) < 2 || ArraySize(slow) < 2)
   {
      if(InpDebugMode)
         PrintFormat("[CDC] %s: EMA array too small (fast=%d, slow=%d), status=LOADING", 
                     symbol, ArraySize(fast), ArraySize(slow));
      return false;
   }
   
   // Series array: index 0 = newest, index 1 = previous (same as Moneyx Smart System)
   fastEMA = fast[0];
   slowEMA = slow[0];
   
   // Validate EMA values
   if(fastEMA == 0 || slowEMA == 0)
   {
      if(InpDebugMode)
         PrintFormat("[CDC] %s: Invalid EMA values (Fast: %.5f, Slow: %.5f)", symbol, fastEMA, slowEMA);
      return false;  // v3.7.1: Return false for LOADING state
   }
   
   // Get previous values for crossover detection
   double fastPrev = fast[1];
   double slowPrev = slow[1];
   
   // Determine Trend (same logic as Moneyx Smart System)
   if(InpRequireStrongTrend)
   {
      // Require actual crossover
      bool crossUp = (fastPrev <= slowPrev && fastEMA > slowEMA);
      bool crossDown = (fastPrev >= slowPrev && fastEMA < slowEMA);
      
      if(crossUp) trend = "BULLISH";
      else if(crossDown) trend = "BEARISH";
   }
   else
   {
      // Just check relative position (matches Moneyx Smart System)
      if(fastEMA > slowEMA) trend = "BULLISH";
      else if(fastEMA < slowEMA) trend = "BEARISH";
   }
   
   // Always log CDC result for debugging
   if(InpDebugMode)
      PrintFormat("[CDC] %s: %s (Fast: %.5f, Slow: %.5f, FastPrev: %.5f, SlowPrev: %.5f, Bars: %d)", 
                  symbol, trend, fastEMA, slowEMA, fastPrev, slowPrev, actualBars);
   
   return true;  // v3.7.1: Return true = data ready
}

//+------------------------------------------------------------------+
//| Update CDC Trend Data for Single Pair (v3.7.1)                     |
//+------------------------------------------------------------------+
void UpdateCDCForPair(int pairIndex)
{
   if(!InpUseCDCTrendFilter) return;
   if(!g_pairs[pairIndex].enabled) return;
   
   // v3.7.1: Calculate CDC for Symbol A and track ready status
   g_pairs[pairIndex].cdcReadyA = CalculateCDCForSymbol(
      g_pairs[pairIndex].symbolA,
      g_pairs[pairIndex].cdcTrendA,
      g_pairs[pairIndex].cdcFastA,
      g_pairs[pairIndex].cdcSlowA
   );
   
   // v3.7.1: Calculate CDC for Symbol B and track ready status
   g_pairs[pairIndex].cdcReadyB = CalculateCDCForSymbol(
      g_pairs[pairIndex].symbolB,
      g_pairs[pairIndex].cdcTrendB,
      g_pairs[pairIndex].cdcFastB,
      g_pairs[pairIndex].cdcSlowB
   );
}

//+------------------------------------------------------------------+
//| Update CDC for All Enabled Pairs (v1.6.2: Initial-Only Retry)      |
//+------------------------------------------------------------------+
void UpdateAllPairsCDC()
{
   if(!InpUseCDCTrendFilter) return;
   
   datetime currentTime = TimeCurrent();  // v1.6.2: For retry timing
   
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(!g_pairs[i].enabled) continue;
      
      // v3.7.1: Check for new candle on each symbol's CDC timeframe independently
      datetime tA = iTime(g_pairs[i].symbolA, InpCDCTimeframe, 0);
      datetime tB = iTime(g_pairs[i].symbolB, InpCDCTimeframe, 0);
      
      // === Symbol A ===
      if(tA <= 0)
      {
         // iTime failed - data not ready
         g_pairs[i].cdcReadyA = false;
         if(InpDebugMode)
            PrintFormat("[CDC] %s: iTime returned 0, status=LOADING", g_pairs[i].symbolA);
      }
      else if(tA != g_pairs[i].lastCdcTimeA)
      {
         // New candle for Symbol A - recalculate
         g_pairs[i].lastCdcTimeA = tA;
         g_pairs[i].cdcReadyA = CalculateCDCForSymbol(
            g_pairs[i].symbolA,
            g_pairs[i].cdcTrendA,
            g_pairs[i].cdcFastA,
            g_pairs[i].cdcSlowA
         );
      }
      else if(!g_pairs[i].cdcReadyA)
      {
         // v1.6.2: Initial-Only Retry - if still not ready, retry every 5 seconds
         if(currentTime - g_lastCDCRetryTime[i] >= 5)
         {
            g_lastCDCRetryTime[i] = currentTime;
            g_pairs[i].cdcReadyA = CalculateCDCForSymbol(
               g_pairs[i].symbolA,
               g_pairs[i].cdcTrendA,
               g_pairs[i].cdcFastA,
               g_pairs[i].cdcSlowA
            );
            if(InpDebugMode && g_pairs[i].cdcReadyA)
               PrintFormat("[CDC] %s: Initial Retry SUCCESS - status=OK", g_pairs[i].symbolA);
         }
      }
      // If cdcReadyA = true -> no retry needed, wait for next new candle
      
      // === Symbol B ===
      if(tB <= 0)
      {
         // iTime failed - data not ready
         g_pairs[i].cdcReadyB = false;
         if(InpDebugMode)
            PrintFormat("[CDC] %s: iTime returned 0, status=LOADING", g_pairs[i].symbolB);
      }
      else if(tB != g_pairs[i].lastCdcTimeB)
      {
         // New candle for Symbol B - recalculate
         g_pairs[i].lastCdcTimeB = tB;
         g_pairs[i].cdcReadyB = CalculateCDCForSymbol(
            g_pairs[i].symbolB,
            g_pairs[i].cdcTrendB,
            g_pairs[i].cdcFastB,
            g_pairs[i].cdcSlowB
         );
      }
      else if(!g_pairs[i].cdcReadyB)
      {
         // v1.6.2: Initial-Only Retry - if still not ready, retry every 5 seconds
         if(currentTime - g_lastCDCRetryTime[i] >= 5)
         {
            g_lastCDCRetryTime[i] = currentTime;
            g_pairs[i].cdcReadyB = CalculateCDCForSymbol(
               g_pairs[i].symbolB,
               g_pairs[i].cdcTrendB,
               g_pairs[i].cdcFastB,
               g_pairs[i].cdcSlowB
            );
            if(InpDebugMode && g_pairs[i].cdcReadyB)
               PrintFormat("[CDC] %s: Initial Retry SUCCESS - status=OK", g_pairs[i].symbolB);
         }
      }
      // If cdcReadyB = true -> no retry needed, wait for next new candle
   }
}

//+------------------------------------------------------------------+
//| Get CDC Status Text for Dashboard (v3.7.1)                         |
//| Returns: "LOADING" (orange), "BLOCK" (red), or "OK" (green)        |
//+------------------------------------------------------------------+
string GetCDCStatusText(int pairIndex, color &statusColor)
{
   // If filter is disabled
   if(!InpUseCDCTrendFilter)
   {
      statusColor = clrDimGray;
      return "OFF";
   }
   
   // v3.7.1: Check if CDC data is ready for both symbols
   string newStatus = "";
   string trendA = g_pairs[pairIndex].cdcTrendA;
   string trendB = g_pairs[pairIndex].cdcTrendB;
   
   if(!g_pairs[pairIndex].cdcReadyA || !g_pairs[pairIndex].cdcReadyB)
   {
      statusColor = clrOrange;  // Orange = Loading
      newStatus = "LOADING";
   }
   // Check if trends are NEUTRAL (calculation failed but returned true)
   else if(trendA == "NEUTRAL" || trendB == "NEUTRAL")
   {
      statusColor = clrOrange;
      newStatus = "LOADING";
   }
   else
   {
      // Data is ready - check trend confirmation (without logging)
      int corrType = g_pairs[pairIndex].correlationType;
      bool sameTrend = (trendA == trendB);
      bool oppositeTrend = ((trendA == "BULLISH" && trendB == "BEARISH") || 
                            (trendA == "BEARISH" && trendB == "BULLISH"));
      
      bool cdcOK = false;
      if(corrType == 1)  // Positive Correlation
         cdcOK = sameTrend;
      else  // Negative Correlation
         cdcOK = oppositeTrend;
      
      // v1.8.4: Show trend status based on correlation type
      if(cdcOK)
      {
         if(corrType == 1)  // Positive Correlation - ทั้งคู่ไปทางเดียวกัน
         {
            if(trendA == "BULLISH")
            {
               statusColor = clrLime;       // Green = Uptrend
               newStatus = "Up";
            }
            else  // BEARISH
            {
               statusColor = clrOrangeRed;  // Red = Downtrend
               newStatus = "Down";
            }
         }
         else  // Negative Correlation - แสดง A/B แยกกัน
         {
            // trendA = BULLISH, trendB = BEARISH → "Up/Dw"
            // trendA = BEARISH, trendB = BULLISH → "Dw/Up"
            string statusA = (trendA == "BULLISH") ? "Up" : "Dw";
            string statusB = (trendB == "BULLISH") ? "Up" : "Dw";
            newStatus = statusA + "/" + statusB;
            
            // สี: ใช้สีเขียวเพราะ cdcOK = true (อนุญาตเทรด)
            statusColor = clrLime;
         }
      }
      else
      {
         statusColor = clrGray;          // Gray = Block (trend mismatch)
         newStatus = "BLOCK";
      }
   }
   
   // v3.7.2: Log only when status changes
   if(newStatus != g_lastCDCStatus[pairIndex])
   {
      g_lastCDCStatus[pairIndex] = newStatus;
      if(InpDebugMode && (!g_isTesterMode || !InpDisableDebugInTester))
         PrintFormat("CDC STATUS CHANGE: Pair %d - %s (A:%s B:%s CorrType:%d)", 
                     pairIndex + 1, newStatus, trendA, trendB, g_pairs[pairIndex].correlationType);
   }
   
   return newStatus;
}

//+------------------------------------------------------------------+
//| Check CDC Trend Confirmation for Entry (v3.7.1)                    |
//| Logic:                                                             |
//|   - Positive Correlation: Both symbols SAME trend                  |
//|   - Negative Correlation: Both symbols OPPOSITE trend              |
//|   - Returns FALSE if data is not ready (LOADING state)             |
//+------------------------------------------------------------------+
bool CheckCDCTrendConfirmation(int pairIndex, string side)
{
   // If filter is disabled, always confirm
   if(!InpUseCDCTrendFilter) return true;
   
   // v3.7.1: Check if CDC data is ready
   if(!g_pairs[pairIndex].cdcReadyA || !g_pairs[pairIndex].cdcReadyB)
   {
      if(InpDebugMode && (!g_isTesterMode || !InpDisableDebugInTester))
         PrintFormat("CDC: Pair %d - LOADING (A:%s B:%s)", 
                     pairIndex + 1, 
                     g_pairs[pairIndex].cdcReadyA ? "Ready" : "Loading",
                     g_pairs[pairIndex].cdcReadyB ? "Ready" : "Loading");
      return false;  // Block entry during loading
   }
   
   string trendA = g_pairs[pairIndex].cdcTrendA;
   string trendB = g_pairs[pairIndex].cdcTrendB;
   int corrType = g_pairs[pairIndex].correlationType;
   
   // Skip if either trend is NEUTRAL
   if(trendA == "NEUTRAL" || trendB == "NEUTRAL")
   {
      if(InpDebugMode && (!g_isTesterMode || !InpDisableDebugInTester))
         PrintFormat("CDC: Pair %d skipped - NEUTRAL trend (A:%s B:%s)", 
                     pairIndex + 1, trendA, trendB);
      return false;
   }
   
   bool sameTrend = (trendA == trendB);
   bool oppositeTrend = (trendA != trendB);
   
   if(corrType == 1)  // Positive Correlation
   {
      // Require SAME trend for both symbols
      if(!sameTrend)
      {
         // v3.7.2: Removed log spam - status change is logged in GetCDCStatusText()
         return false;
      }
   }
   else  // Negative Correlation (corrType == -1)
   {
      // Require OPPOSITE trends
      if(!oppositeTrend)
      {
         // v3.7.2: Removed log spam - status change is logged in GetCDCStatusText()
         return false;
      }
   }
   
   // v3.7.2: Removed log spam - status change is logged in GetCDCStatusText()
   return true;
}

//+------------------------------------------------------------------+
//| ================ ADX FOR NEGATIVE CORRELATION (v3.5.3 HF3) ================
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get ADX Value for Symbol (v3.5.3 HF3)                              |
//+------------------------------------------------------------------+
double GetADXValue(string symbol, ENUM_TIMEFRAMES timeframe, int period)
{
   // v2.1.4: Use simplified calculation in tester to avoid chart display
   // Trading logic remains 100% the same - only visual chart is skipped
   if(g_isTesterMode && InpSkipADXChartInTester)
   {
      return CalculateSimplifiedADX(symbol, timeframe, period);
   }
   
   int handle = iADX(symbol, timeframe, period);
   if(handle == INVALID_HANDLE)
   {
      if(InpDebugMode && (!g_isTesterMode || !InpDisableDebugInTester))
         PrintFormat("ADX: Failed to create handle for %s", symbol);
      return 0;
   }
   
   double buffer[];
   ArraySetAsSeries(buffer, true);
   
   int copied = CopyBuffer(handle, 0, 0, 1, buffer);
   if(copied < 1)
   {
      // v1.8.1: Debug log when CopyBuffer fails
      if(InpDebugMode && (!g_isTesterMode || !InpDisableDebugInTester))
      {
         PrintFormat("ADX: CopyBuffer failed for %s (TF:%s, Period:%d) - copied=%d, error=%d", 
                     symbol, EnumToString(timeframe), period, copied, GetLastError());
      }
      IndicatorRelease(handle);
      return 0;
   }
   
   double adxValue = buffer[0];
   IndicatorRelease(handle);
   
   return adxValue;
}

//+------------------------------------------------------------------+
//| Simplified ADX Calculation (v2.1.4 - No Indicator Handle)          |
//| Calculates ADX using price data without creating indicator         |
//| Result is equivalent to iADX() but no chart is displayed           |
//+------------------------------------------------------------------+
double CalculateSimplifiedADX(string symbol, ENUM_TIMEFRAMES tf, int period)
{
   int barsNeeded = period * 3;
   
   double plusDM[], minusDM[], tr[];
   ArrayResize(plusDM, barsNeeded);
   ArrayResize(minusDM, barsNeeded);
   ArrayResize(tr, barsNeeded);
   ArrayInitialize(plusDM, 0);
   ArrayInitialize(minusDM, 0);
   ArrayInitialize(tr, 0);
   
   // Calculate +DM, -DM, and True Range for each bar
   for(int i = 0; i < barsNeeded - 1; i++)
   {
      double high = iHigh(symbol, tf, i);
      double low = iLow(symbol, tf, i);
      double prevHigh = iHigh(symbol, tf, i + 1);
      double prevLow = iLow(symbol, tf, i + 1);
      double prevClose = iClose(symbol, tf, i + 1);
      
      if(high == 0 || low == 0 || prevClose == 0) continue;
      
      // +DM and -DM
      double upMove = high - prevHigh;
      double downMove = prevLow - low;
      
      plusDM[i] = (upMove > downMove && upMove > 0) ? upMove : 0;
      minusDM[i] = (downMove > upMove && downMove > 0) ? downMove : 0;
      
      // True Range
      double tr1 = high - low;
      double tr2 = MathAbs(high - prevClose);
      double tr3 = MathAbs(low - prevClose);
      tr[i] = MathMax(tr1, MathMax(tr2, tr3));
   }
   
   // Wilder's Smoothing (EMA-style)
   double smoothPlusDM = 0, smoothMinusDM = 0, smoothTR = 0;
   double dx[];
   ArrayResize(dx, barsNeeded);
   ArrayInitialize(dx, 0);
   
   // First period: simple sum
   for(int i = barsNeeded - 2; i >= barsNeeded - period - 1 && i >= 0; i--)
   {
      smoothPlusDM += plusDM[i];
      smoothMinusDM += minusDM[i];
      smoothTR += tr[i];
   }
   
   // Apply Wilder's smoothing for remaining bars
   int dxCount = 0;
   for(int i = barsNeeded - period - 2; i >= 0; i--)
   {
      smoothPlusDM = smoothPlusDM - (smoothPlusDM / period) + plusDM[i];
      smoothMinusDM = smoothMinusDM - (smoothMinusDM / period) + minusDM[i];
      smoothTR = smoothTR - (smoothTR / period) + tr[i];
      
      if(smoothTR == 0) continue;
      
      double plusDI = 100.0 * smoothPlusDM / smoothTR;
      double minusDI = 100.0 * smoothMinusDM / smoothTR;
      
      double diSum = plusDI + minusDI;
      if(diSum > 0)
      {
         dx[dxCount++] = 100.0 * MathAbs(plusDI - minusDI) / diSum;
      }
   }
   
   // ADX = Smoothed average of DX
   if(dxCount < period) return 0;
   
   double adx = 0;
   for(int i = 0; i < period; i++)
   {
      adx += dx[i];
   }
   adx /= period;
   
   return adx;
}

//+------------------------------------------------------------------+
//| Determine ADX Winner for Negative Correlation Pair (v1.7.0)        |
//+------------------------------------------------------------------+
void DetermineADXWinner(int pairIndex)
{
   if(!InpUseADXForNegative) return;
   if(g_pairs[pairIndex].correlationType != -1) return;  // Only for Negative Correlation
   
   double adxA = g_pairs[pairIndex].adxValueA;
   double adxB = g_pairs[pairIndex].adxValueB;
   
   if(adxA > adxB && adxA >= InpADXMinStrength)
   {
      g_pairs[pairIndex].adxWinner = 0;  // Symbol A wins
      g_pairs[pairIndex].adxWinnerValue = adxA;
      g_pairs[pairIndex].adxLoserValue = adxB;
   }
   else if(adxB > adxA && adxB >= InpADXMinStrength)
   {
      g_pairs[pairIndex].adxWinner = 1;  // Symbol B wins
      g_pairs[pairIndex].adxWinnerValue = adxB;
      g_pairs[pairIndex].adxLoserValue = adxA;
   }
   else
   {
      g_pairs[pairIndex].adxWinner = -1;  // None/Equal (below threshold or equal)
      g_pairs[pairIndex].adxWinnerValue = MathMax(adxA, adxB);
      g_pairs[pairIndex].adxLoserValue = MathMin(adxA, adxB);
   }
}

//+------------------------------------------------------------------+
//| Update ADX Values for Negative Correlation Pair (v1.7.0)           |
//+------------------------------------------------------------------+
void UpdateADXForPair(int pairIndex)
{
   if(!InpUseADXForNegative) return;
   if(g_pairs[pairIndex].correlationType != -1) return;  // Only for Negative Correlation
   if(!g_pairs[pairIndex].enabled) return;
   
   g_pairs[pairIndex].adxValueA = GetADXValue(g_pairs[pairIndex].symbolA, InpADXTimeframe, InpADXPeriod);
   g_pairs[pairIndex].adxValueB = GetADXValue(g_pairs[pairIndex].symbolB, InpADXTimeframe, InpADXPeriod);
   
   // v1.8.1: Validation log if either ADX is zero (potential data issue)
   if(InpDebugMode && (!g_isTesterMode || !InpDisableDebugInTester))
   {
      if(g_pairs[pairIndex].adxValueA == 0 || g_pairs[pairIndex].adxValueB == 0)
      {
         PrintFormat("WARNING: ADX ZERO [Pair %d %s/%s]: A=%.1f, B=%.1f - Check data availability", 
                     pairIndex + 1,
                     g_pairs[pairIndex].symbolA,
                     g_pairs[pairIndex].symbolB,
                     g_pairs[pairIndex].adxValueA,
                     g_pairs[pairIndex].adxValueB);
      }
   }
   
   // v1.7.0: Determine Winner after update
   DetermineADXWinner(pairIndex);
   
   if(InpDebugMode && (!g_isTesterMode || !InpDisableDebugInTester))
   {
      string winnerStr = (g_pairs[pairIndex].adxWinner == 0) ? g_pairs[pairIndex].symbolA :
                         (g_pairs[pairIndex].adxWinner == 1) ? g_pairs[pairIndex].symbolB : "NONE";
      PrintFormat("ADX UPDATE [Pair %d NEG]: A=%.1f, B=%.1f | Winner: %s (Mult: %.1fx)",
                  pairIndex + 1, 
                  g_pairs[pairIndex].adxValueA, g_pairs[pairIndex].adxValueB, 
                  winnerStr, InpTrendSideMultiplier);
   }
}

//+------------------------------------------------------------------+
//| Update ADX for All Negative Correlation Pairs (v3.5.3 HF3)         |
//+------------------------------------------------------------------+
void UpdateAllPairsADX()
{
   if(!InpUseADXForNegative) return;
   
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(g_pairs[i].enabled && g_pairs[i].correlationType == -1)
         UpdateADXForPair(i);
   }
}

//+------------------------------------------------------------------+
//| ================ SIGNAL ENGINE (v3.5.0) ================           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check if Grid/Main Trading is Allowed (v3.5.2)                     |
//| Returns: true = สามารถออก Order ได้                                 |
//|          false = Pause (Correlation, Z-Score, หรือ CDC ไม่ผ่าน)     |
//| v3.5.2: Added direction-aware Z-Score check + CDC Block            |
//+------------------------------------------------------------------+
bool CheckGridTradingAllowed(int pairIndex, string side, string &pauseReason)
{
   pauseReason = "";
   
   // === เงื่อนไข 1: Correlation Check ===
   double absCorr = MathAbs(g_pairs[pairIndex].correlation);
   if(absCorr < InpGridMinCorrelation)
   {
      pauseReason = StringFormat("Corr %.0f%% < %.0f%%", 
                                 absCorr * 100, InpGridMinCorrelation * 100);
      
      if(InpDebugMode && (!g_isTesterMode || !InpDisableDebugInTester))
         PrintFormat("GRID PAUSE [Pair %d %s/%s %s]: %s", pairIndex + 1, 
                     g_pairs[pairIndex].symbolA, g_pairs[pairIndex].symbolB, side, pauseReason);
      
      return false;
   }
   
   // === เงื่อนไข 2: Z-Score Direction-Aware Check (v3.5.2) ===
   // BUY Side: เปิดเมื่อ Z < -Entry → Grid หยุดเมื่อ Z > -MinZ (ใกล้ศูนย์)
   // SELL Side: เปิดเมื่อ Z > +Entry → Grid หยุดเมื่อ Z < +MinZ (ใกล้ศูนย์)
   double zScore = g_pairs[pairIndex].zScore;
   
   if(side == "BUY")
   {
      // BUY Side opened at negative Z-Score
      // Stop grid if Z-Score crosses back toward 0 (becomes > -MinZ)
      if(zScore > -InpGridMinZScore)
      {
         pauseReason = StringFormat("Z=%.2f > -%.2f (BUY)", zScore, InpGridMinZScore);
         
         if(InpDebugMode && (!g_isTesterMode || !InpDisableDebugInTester))
            PrintFormat("GRID PAUSE [Pair %d %s/%s BUY]: %s", pairIndex + 1,
                        g_pairs[pairIndex].symbolA, g_pairs[pairIndex].symbolB, pauseReason);
         
         return false;
      }
   }
   else if(side == "SELL")
   {
      // SELL Side opened at positive Z-Score
      // Stop grid if Z-Score crosses back toward 0 (becomes < +MinZ)
      if(zScore < InpGridMinZScore)
      {
         pauseReason = StringFormat("Z=%.2f < +%.2f (SELL)", zScore, InpGridMinZScore);
         
         if(InpDebugMode && (!g_isTesterMode || !InpDisableDebugInTester))
            PrintFormat("GRID PAUSE [Pair %d %s/%s SELL]: %s", pairIndex + 1,
                        g_pairs[pairIndex].symbolA, g_pairs[pairIndex].symbolB, pauseReason);
         
         return false;
      }
   }
   
   // === เงื่อนไข 3: CDC Trend Block (v3.5.2) ===
   if(InpUseCDCTrendFilter)
   {
      if(!CheckCDCTrendConfirmation(pairIndex, side))
      {
         pauseReason = "CDC BLOCK";
         
         if(InpDebugMode && (!g_isTesterMode || !InpDisableDebugInTester))
            PrintFormat("GRID PAUSE [Pair %d %s/%s %s]: %s", pairIndex + 1,
                        g_pairs[pairIndex].symbolA, g_pairs[pairIndex].symbolB, side, pauseReason);
         
         return false;
      }
   }
   
   return true;  // ผ่านทั้ง 3 เงื่อนไข
}

//+------------------------------------------------------------------+
//| Check Entry for Correlation Only Mode (v1.8.8)                     |
//| Returns: true = Correlation อยู่ในเกณฑ์ที่กำหนด                       |
//+------------------------------------------------------------------+
bool CheckCorrelationOnlyEntry(int pairIndex)
{
   double corr = g_pairs[pairIndex].correlation;
   int corrType = g_pairs[pairIndex].correlationType;
   
   // Positive Correlation: Corr >= Threshold (e.g., >= 0.60)
   if(corrType == 1)
   {
      return (corr >= InpCorrOnlyPositiveThreshold);
   }
   // Negative Correlation: Corr <= Threshold (e.g., <= -0.60)
   else
   {
      return (corr <= InpCorrOnlyNegativeThreshold);
   }
}

//+------------------------------------------------------------------+
//| Determine Trade Direction for Correlation Only Mode (v1.8.8)       |
//| Returns: "BUY" = Open BUY Side (Buy A + action on B)               |
//|          "SELL" = Open SELL Side (Sell A + action on B)            |
//|          "" = No valid direction (CDC not ready or conditions fail)|
//+------------------------------------------------------------------+
string DetermineTradeDirectionForCorrOnly(int pairIndex)
{
   int corrType = g_pairs[pairIndex].correlationType;
   string trendA = g_pairs[pairIndex].cdcTrendA;
   string trendB = g_pairs[pairIndex].cdcTrendB;
   
   // Check CDC data is ready
   if(!g_pairs[pairIndex].cdcReadyA || !g_pairs[pairIndex].cdcReadyB)
      return "";
   
   // Skip if either trend is NEUTRAL
   if(trendA == "NEUTRAL" || trendB == "NEUTRAL")
      return "";
   
   // === POSITIVE CORRELATION ===
   // Both symbols should have SAME trend
   // CDC Up (Both Bullish) → BUY Side (Buy A, Sell B)
   // CDC Down (Both Bearish) → SELL Side (Sell A, Buy B)
   if(corrType == 1)
   {
      if(trendA != trendB)
         return "";  // Positive requires same trend
      
      if(trendA == "BULLISH")
         return "BUY";   // Both Up → Buy A, Sell B
      else
         return "SELL";  // Both Down → Sell A, Buy B
   }
   
   // === NEGATIVE CORRELATION ===
   // Both symbols should have OPPOSITE trends
   // Use ADX to determine which symbol's trend to follow
   else
   {
      if(trendA == trendB)
         return "";  // Negative requires opposite trends
      
      // v2.1.7: Check ADX Winner (with Skip option)
      if(!InpUseADXForNegative || InpCorrOnlySkipADXCheck)
      {
         // Without ADX or Skip ADX: Default to following Symbol A's trend
         return (trendA == "BULLISH") ? "BUY" : "SELL";
      }
      
      double adxA = g_pairs[pairIndex].adxValueA;
      double adxB = g_pairs[pairIndex].adxValueB;
      
      // Determine ADX Winner
      int adxWinner = -1;  // -1 = none, 0 = A, 1 = B
      if(adxA > adxB && adxA >= InpADXMinStrength)
         adxWinner = 0;  // Symbol A wins
      else if(adxB > adxA && adxB >= InpADXMinStrength)
         adxWinner = 1;  // Symbol B wins
      else
      {
         // v2.1.7: Fallback to Symbol A's trend instead of blocking
         return (trendA == "BULLISH") ? "BUY" : "SELL";
      }
      
      // Follow the trend of ADX Winner
      // Winner = A → follow trendA
      // Winner = B → follow trendB
      string winnerTrend = (adxWinner == 0) ? trendA : trendB;
      
      // For Negative Correlation:
      // If Winner's trend is BULLISH → Both should BUY (Buy A + Buy B)
      // If Winner's trend is BEARISH → Both should SELL (Sell A + Sell B)
      return (winnerTrend == "BULLISH") ? "BUY" : "SELL";
   }
}

//+------------------------------------------------------------------+
//| Check if Grid Trading is Allowed - Correlation Only Mode (v1.8.8)  |
//| Returns: true = สามารถออก Grid Order ได้                            |
//|          false = Pause (Correlation หรือ CDC ไม่ผ่าน)               |
//| NOTE: ไม่เช็ค Z-Score เลย                                           |
//+------------------------------------------------------------------+
bool CheckGridTradingAllowedCorrOnly(int pairIndex, string side, string &pauseReason)
{
   pauseReason = "";
   
   // === เงื่อนไข 1: Correlation Check (ใช้ InpGridMinCorrelation เหมือนเดิม) ===
   double absCorr = MathAbs(g_pairs[pairIndex].correlation);
   if(absCorr < InpGridMinCorrelation)
   {
      pauseReason = StringFormat("Corr %.0f%% < %.0f%%", 
                                 absCorr * 100, InpGridMinCorrelation * 100);
      
      if(InpDebugMode && (!g_isTesterMode || !InpDisableDebugInTester))
         PrintFormat("GRID PAUSE [CORR ONLY] [Pair %d %s/%s %s]: %s", pairIndex + 1, 
                     g_pairs[pairIndex].symbolA, g_pairs[pairIndex].symbolB, side, pauseReason);
      
      return false;
   }
   
   // === เงื่อนไข 2: CDC Trend Block (v3.5.2) ===
   if(InpUseCDCTrendFilter)
   {
      if(!CheckCDCTrendConfirmation(pairIndex, side))
      {
         pauseReason = "CDC BLOCK";
         
         if(InpDebugMode && (!g_isTesterMode || !InpDisableDebugInTester))
            PrintFormat("GRID PAUSE [CORR ONLY] [Pair %d %s/%s %s]: %s", pairIndex + 1,
                        g_pairs[pairIndex].symbolA, g_pairs[pairIndex].symbolB, side, pauseReason);
         
         return false;
      }
   }
   
   // ไม่มีเช็ค Z-Score - ผ่านเลย
   return true;
}

//+------------------------------------------------------------------+
//| Analyze All Pairs for Trading Signals (v1.8.8)                     |
//+------------------------------------------------------------------+
void AnalyzeAllPairs()
{
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(!g_pairs[i].enabled) continue;
      
      // === Check Correlation first (always required) ===
      if(MathAbs(g_pairs[i].correlation) < InpMinCorrelation)
         continue;
      
      double zScore = g_pairs[i].zScore;
      
      // ================================================================
      // v1.8.8: CORRELATION ONLY MODE
      // ================================================================
      if(InpEntryMode == ENTRY_MODE_CORRELATION_ONLY)
      {
         // v2.1.7: Debug flag
         bool debugLog = InpDebugMode && (!g_isTesterMode || !InpDisableDebugInTester);
         
         // Step 1: Check Correlation Threshold
         if(!CheckCorrelationOnlyEntry(i))
         {
            if(debugLog)
               PrintFormat("[CORR ONLY] Pair %d %s/%s: SKIP - Corr %.0f%% not in range (Pos>=%.0f%%, Neg<=%.0f%%)",
                           i + 1, g_pairs[i].symbolA, g_pairs[i].symbolB,
                           g_pairs[i].correlation * 100,
                           InpCorrOnlyPositiveThreshold * 100,
                           InpCorrOnlyNegativeThreshold * 100);
            continue;
         }
         
         // Step 2: Determine Trade Direction based on CDC + ADX
         string direction = DetermineTradeDirectionForCorrOnly(i);
         if(direction == "")
         {
            if(debugLog)
            {
               string reason = "";
               if(!g_pairs[i].cdcReadyA || !g_pairs[i].cdcReadyB)
                  reason = "CDC NOT READY";
               else if(g_pairs[i].cdcTrendA == "NEUTRAL" || g_pairs[i].cdcTrendB == "NEUTRAL")
                  reason = StringFormat("CDC NEUTRAL (A=%s, B=%s)", g_pairs[i].cdcTrendA, g_pairs[i].cdcTrendB);
               else if(g_pairs[i].correlationType == 1 && g_pairs[i].cdcTrendA != g_pairs[i].cdcTrendB)
                  reason = StringFormat("POS CORR TREND MISMATCH (A=%s, B=%s)", g_pairs[i].cdcTrendA, g_pairs[i].cdcTrendB);
               else if(g_pairs[i].correlationType == -1 && g_pairs[i].cdcTrendA == g_pairs[i].cdcTrendB)
                  reason = StringFormat("NEG CORR SAME TREND (A=%s, B=%s)", g_pairs[i].cdcTrendA, g_pairs[i].cdcTrendB);
               else if(g_pairs[i].correlationType == -1 && InpUseADXForNegative && !InpCorrOnlySkipADXCheck)
                  reason = StringFormat("ADX FAIL (A=%.1f, B=%.1f, Min=%.1f)", 
                                        g_pairs[i].adxValueA, g_pairs[i].adxValueB, InpADXMinStrength);
               else
                  reason = "UNKNOWN";
               
               PrintFormat("[CORR ONLY] Pair %d %s/%s: SKIP - Direction empty, Reason: %s",
                           i + 1, g_pairs[i].symbolA, g_pairs[i].symbolB, reason);
            }
            continue;
         }
         
         // Step 3: Check Grid Guard (Correlation Only version)
         if(InpGridPauseAffectsMain)
         {
            string pauseReason = "";
            if(!CheckGridTradingAllowedCorrOnly(i, direction, pauseReason))
            {
               if(debugLog)
                  PrintFormat("[CORR ONLY] Pair %d %s/%s: SKIP - Grid Guard: %s",
                              i + 1, g_pairs[i].symbolA, g_pairs[i].symbolB, pauseReason);
               continue;
            }
         }
         
         // Step 4: Check RSI Entry Confirmation (v2.1.7: Optional skip)
         if(!InpCorrOnlySkipRSICheck && !CheckRSIEntryConfirmation(i, direction))
         {
            if(debugLog)
               PrintFormat("[CORR ONLY] Pair %d %s/%s: SKIP - RSI BLOCK (dir=%s, RSI=%.1f, OB=%.0f, OS=%.0f)", 
                           i + 1, g_pairs[i].symbolA, g_pairs[i].symbolB, 
                           direction, g_pairs[i].rsiSpread, InpRSIOverbought, InpRSIOversold);
            continue;
         }
         
         // Step 5: Open Trade based on determined direction
         if(direction == "BUY")
         {
            if(g_pairs[i].directionBuy == -1 && g_pairs[i].orderCountBuy < g_pairs[i].maxOrderBuy)
            {
               if(OpenBuySideTrade(i))
               {
                  g_pairs[i].directionBuy = 1;
                  g_pairs[i].entryZScoreBuy = zScore;
                  g_pairs[i].lastAvgPriceBuy = SymbolInfoDouble(g_pairs[i].symbolA, SYMBOL_ASK);
                  g_pairs[i].justOpenedMainBuy = true;
                  PrintFormat("[CORR ONLY] Pair %d OPENED BUY DATA: Corr=%.2f%%, CDC=%s/%s, ADX=%.0f/%.0f",
                              i + 1, g_pairs[i].correlation * 100,
                              g_pairs[i].cdcTrendA, g_pairs[i].cdcTrendB,
                              g_pairs[i].adxValueA, g_pairs[i].adxValueB);
               }
            }
            else if(debugLog)
            {
               PrintFormat("[CORR ONLY] Pair %d %s/%s: BUY BLOCKED (directionBuy=%d, orderCount=%d/%d)",
                           i + 1, g_pairs[i].symbolA, g_pairs[i].symbolB,
                           g_pairs[i].directionBuy, g_pairs[i].orderCountBuy, g_pairs[i].maxOrderBuy);
            }
         }
         else // direction == "SELL"
         {
            if(g_pairs[i].directionSell == -1 && g_pairs[i].orderCountSell < g_pairs[i].maxOrderSell)
            {
               if(OpenSellSideTrade(i))
               {
                  g_pairs[i].directionSell = 1;
                  g_pairs[i].entryZScoreSell = zScore;
                  g_pairs[i].lastAvgPriceSell = SymbolInfoDouble(g_pairs[i].symbolA, SYMBOL_BID);
                  g_pairs[i].justOpenedMainSell = true;
                  PrintFormat("[CORR ONLY] Pair %d OPENED SELL DATA: Corr=%.2f%%, CDC=%s/%s, ADX=%.0f/%.0f",
                              i + 1, g_pairs[i].correlation * 100,
                              g_pairs[i].cdcTrendA, g_pairs[i].cdcTrendB,
                              g_pairs[i].adxValueA, g_pairs[i].adxValueB);
               }
            }
            else if(debugLog)
            {
               PrintFormat("[CORR ONLY] Pair %d %s/%s: SELL BLOCKED (directionSell=%d, orderCount=%d/%d)",
                           i + 1, g_pairs[i].symbolA, g_pairs[i].symbolB,
                           g_pairs[i].directionSell, g_pairs[i].orderCountSell, g_pairs[i].maxOrderSell);
            }
         }
         
         continue;  // Skip Z-Score logic for this pair
      }
      
      // ================================================================
      // ORIGINAL Z-SCORE MODE (unchanged)
      // ================================================================
      
      // === BUY SIDE ENTRY ===
      // Condition: directionBuy == -1 (Ready) AND Z-Score < -EntryThreshold
      // v3.5.2: Optional Grid Guard check for main entry
      if(g_pairs[i].directionBuy == -1 && g_pairs[i].orderCountBuy < g_pairs[i].maxOrderBuy)
      {
         if(zScore < -InpEntryZScore)
         {
            // v3.5.2: Check Grid Trading Guard for Main Entry (Optional)
            if(InpGridPauseAffectsMain)
            {
               string pauseReason = "";
               if(!CheckGridTradingAllowed(i, "BUY", pauseReason))
                  continue;  // Skip BUY entry
            }
            
            // v3.4.0: Check RSI Entry Confirmation (BUY = RSI in Oversold zone)
            if(CheckRSIEntryConfirmation(i, "BUY"))
            {
               // v3.5.0: Check CDC Trend Confirmation
               if(CheckCDCTrendConfirmation(i, "BUY"))
               {
                  if(OpenBuySideTrade(i))
                  {
                     g_pairs[i].directionBuy = 1;  // Active trade
                     g_pairs[i].entryZScoreBuy = zScore;
                     g_pairs[i].lastAvgPriceBuy = SymbolInfoDouble(g_pairs[i].symbolA, SYMBOL_ASK);
                     g_pairs[i].justOpenedMainBuy = true;
                  }
               }
            }
         }
      }
      
      // === SELL SIDE ENTRY ===
      // Condition: directionSell == -1 (Ready) AND Z-Score > +EntryThreshold
      // v3.5.2: Optional Grid Guard check for main entry
      if(g_pairs[i].directionSell == -1 && g_pairs[i].orderCountSell < g_pairs[i].maxOrderSell)
      {
         if(zScore > InpEntryZScore)
         {
            // v3.5.2: Check Grid Trading Guard for Main Entry (Optional)
            if(InpGridPauseAffectsMain)
            {
               string pauseReason = "";
               if(!CheckGridTradingAllowed(i, "SELL", pauseReason))
                  continue;  // Skip SELL entry
            }
            
            // v3.4.0: Check RSI Entry Confirmation (SELL = RSI in Overbought zone)
            if(CheckRSIEntryConfirmation(i, "SELL"))
            {
               // v3.5.0: Check CDC Trend Confirmation
               if(CheckCDCTrendConfirmation(i, "SELL"))
               {
                  if(OpenSellSideTrade(i))
                  {
                     g_pairs[i].directionSell = 1;  // Active trade
                     g_pairs[i].entryZScoreSell = zScore;
                     g_pairs[i].lastAvgPriceSell = SymbolInfoDouble(g_pairs[i].symbolA, SYMBOL_BID);
                     g_pairs[i].justOpenedMainSell = true;
                  }
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check All Pairs for Grid Loss Side (v1.8.8)                        |
//+------------------------------------------------------------------+
void CheckAllGridLoss()
{
   if(!InpEnableGridLoss) return;
   
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(!g_pairs[i].enabled) continue;
      
      // Check Buy Side - Grid Loss (price going DOWN = losing for BUY)
      if(g_pairs[i].directionBuy == 1 && !g_pairs[i].justOpenedMainBuy)
      {
         // === v1.8.8: Check Grid Trading Guard based on Entry Mode ===
         string pauseReasonBuy = "";
         bool gridAllowed = false;
         if(InpEntryMode == ENTRY_MODE_ZSCORE)
            gridAllowed = CheckGridTradingAllowed(i, "BUY", pauseReasonBuy);
         else
            gridAllowed = CheckGridTradingAllowedCorrOnly(i, "BUY", pauseReasonBuy);
         
         if(!gridAllowed)
         {
            // BUY Grid is PAUSED
         }
         else
         {
            // v1.6: Unified Max Order Check (Hard Cap + Sub-Limit)
            int totalOrders = GetTotalOrderCount(i, "BUY");
            bool hardCapOK = totalOrders < g_pairs[i].maxOrderBuy;
            bool subLimitOK = g_pairs[i].avgOrderCountBuy < InpMaxGridLossOrders;
            
            if(hardCapOK && subLimitOK)
            {
               CheckGridLossForSide(i, "BUY");
            }
         }
      }
      
      // Check Sell Side - Grid Loss (price going UP = losing for SELL)
      if(g_pairs[i].directionSell == 1 && !g_pairs[i].justOpenedMainSell)
      {
         // === v1.8.8: Check Grid Trading Guard based on Entry Mode ===
         string pauseReasonSell = "";
         bool gridAllowed = false;
         if(InpEntryMode == ENTRY_MODE_ZSCORE)
            gridAllowed = CheckGridTradingAllowed(i, "SELL", pauseReasonSell);
         else
            gridAllowed = CheckGridTradingAllowedCorrOnly(i, "SELL", pauseReasonSell);
         
         if(!gridAllowed)
         {
            // SELL Grid is PAUSED
         }
         else
         {
            // v1.6: Unified Max Order Check (Hard Cap + Sub-Limit)
            int totalOrders = GetTotalOrderCount(i, "SELL");
            bool hardCapOK = totalOrders < g_pairs[i].maxOrderSell;
            bool subLimitOK = g_pairs[i].avgOrderCountSell < InpMaxGridLossOrders;
            
            if(hardCapOK && subLimitOK)
            {
               CheckGridLossForSide(i, "SELL");
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check Grid Loss for Specific Side (v3.6.0 HF1)                     |
//+------------------------------------------------------------------+
void CheckGridLossForSide(int pairIndex, string side)
{
   if(InpGridLossDistMode == GRID_DIST_ZSCORE)
   {
      CheckGridLossZScore(pairIndex, side);
   }
   else
   {
      // ATR, Fixed Points, Fixed Pips - v1.6: Use symbol-specific ATR settings
      double gridDist = CalculateGridDistance(pairIndex, InpGridLossDistMode,
                                               InpGridLossATRMultForex,
                                               InpGridLossATRMultGold,
                                               InpGridLossMinDistPips,
                                               InpGridLossFixedPoints,
                                               InpGridLossFixedPips,
                                               InpGridLossATRTimeframe,
                                               InpGridLossATRPeriod);
      if(gridDist <= 0) return;
      
      CheckGridLossPrice(pairIndex, side, gridDist);
   }
}

//+------------------------------------------------------------------+
//| Check Grid Loss by Price Distance (v3.6.0)                         |
//+------------------------------------------------------------------+
void CheckGridLossPrice(int pairIndex, string side, double gridDistance)
{
   double currentPrice = SymbolInfoDouble(g_pairs[pairIndex].symbolA, SYMBOL_BID);
   
   if(side == "BUY")
   {
      // BUY Side: Loss direction = price going DOWN
      double lastPrice = g_pairs[pairIndex].lastAvgPriceBuy;
      if(lastPrice == 0) lastPrice = currentPrice;
      
      if(currentPrice < lastPrice - gridDistance)
      {
         OpenGridLossBuy(pairIndex);
         g_pairs[pairIndex].lastAvgPriceBuy = currentPrice;
      }
   }
   else // SELL
   {
      // SELL Side: Loss direction = price going UP
      double lastPrice = g_pairs[pairIndex].lastAvgPriceSell;
      if(lastPrice == 0) lastPrice = currentPrice;
      
      if(currentPrice > lastPrice + gridDistance)
      {
         OpenGridLossSell(pairIndex);
         g_pairs[pairIndex].lastAvgPriceSell = currentPrice;
      }
   }
}

//+------------------------------------------------------------------+
//| Check Grid Loss by Z-Score (v3.6.0)                                |
//+------------------------------------------------------------------+
void CheckGridLossZScore(int pairIndex, string side)
{
   double currentZ = MathAbs(g_pairs[pairIndex].zScore);
   int currentLevel = 0;
   
   if(side == "BUY")
   {
      currentLevel = g_pairs[pairIndex].avgOrderCountBuy;
   }
   else
   {
      currentLevel = g_pairs[pairIndex].avgOrderCountSell;
   }
   
   // Check if we've hit the next grid level
   if(currentLevel >= g_zScoreGridCount) return;
   
   double nextLevel = g_zScoreGridLevels[currentLevel];
   
   if(currentZ >= nextLevel)
   {
      if(side == "BUY")
      {
         OpenGridLossBuy(pairIndex);
      }
      else
      {
         OpenGridLossSell(pairIndex);
      }
   }
}

//+------------------------------------------------------------------+
//| Check All Pairs for Grid Profit Side (v1.8.8)                      |
//+------------------------------------------------------------------+
void CheckAllGridProfit()
{
   if(!InpEnableGridProfit) return;
   
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(!g_pairs[i].enabled) continue;
      
      // Check BUY Side - Profit Grid (price going UP = profitable for BUY)
      if(g_pairs[i].directionBuy == 1 && !g_pairs[i].justOpenedMainBuy)
      {
         // === v1.8.8: Check Grid Trading Guard based on Entry Mode ===
         string pauseReasonBuy = "";
         bool gridAllowed = false;
         if(InpEntryMode == ENTRY_MODE_ZSCORE)
            gridAllowed = CheckGridTradingAllowed(i, "BUY", pauseReasonBuy);
         else
            gridAllowed = CheckGridTradingAllowedCorrOnly(i, "BUY", pauseReasonBuy);
         
         if(gridAllowed)
         {
            // v1.6: Unified Max Order Check (Hard Cap + Sub-Limit)
            int totalOrders = GetTotalOrderCount(i, "BUY");
            bool hardCapOK = totalOrders < g_pairs[i].maxOrderBuy;
            bool subLimitOK = g_pairs[i].gridProfitCountBuy < InpMaxGridProfitOrders;
            
            if(hardCapOK && subLimitOK)
            {
               CheckGridProfitForSide(i, "BUY");
            }
         }
      }
      
      // Check SELL Side - Profit Grid (price going DOWN = profitable for SELL)
      if(g_pairs[i].directionSell == 1 && !g_pairs[i].justOpenedMainSell)
      {
         // === v1.8.8: Check Grid Trading Guard based on Entry Mode ===
         string pauseReasonSell = "";
         bool gridAllowed = false;
         if(InpEntryMode == ENTRY_MODE_ZSCORE)
            gridAllowed = CheckGridTradingAllowed(i, "SELL", pauseReasonSell);
         else
            gridAllowed = CheckGridTradingAllowedCorrOnly(i, "SELL", pauseReasonSell);
         
         if(gridAllowed)
         {
            // v1.6: Unified Max Order Check (Hard Cap + Sub-Limit)
            int totalOrders = GetTotalOrderCount(i, "SELL");
            bool hardCapOK = totalOrders < g_pairs[i].maxOrderSell;
            bool subLimitOK = g_pairs[i].gridProfitCountSell < InpMaxGridProfitOrders;
            
            if(hardCapOK && subLimitOK)
            {
               CheckGridProfitForSide(i, "SELL");
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check Grid Profit for Specific Side (v3.6.0 HF1)                   |
//+------------------------------------------------------------------+
void CheckGridProfitForSide(int pairIndex, string side)
{
   if(InpGridProfitDistMode == GRID_DIST_ZSCORE)
   {
      CheckGridProfitZScore(pairIndex, side);
   }
   else
   {
      // ATR, Fixed Points, Fixed Pips - v1.6: Use symbol-specific ATR settings
      double gridDist = CalculateGridDistance(pairIndex, InpGridProfitDistMode,
                                               InpGridProfitATRMultForex,
                                               InpGridProfitATRMultGold,
                                               InpGridProfitMinDistPips,
                                               InpGridProfitFixedPoints,
                                               InpGridProfitFixedPips,
                                               InpGridProfitATRTimeframe,
                                               InpGridProfitATRPeriod);
      if(gridDist <= 0) return;
      
      CheckGridProfitPrice(pairIndex, side, gridDist);
   }
}

//+------------------------------------------------------------------+
//| Check Grid Profit by Price Distance (v3.6.0)                       |
//+------------------------------------------------------------------+
void CheckGridProfitPrice(int pairIndex, string side, double gridDistance)
{
   double currentPrice = SymbolInfoDouble(g_pairs[pairIndex].symbolA, SYMBOL_BID);
   
   if(side == "BUY")
   {
      // BUY Side: Profit direction = price going UP from initial entry
      double refPrice = g_pairs[pairIndex].initialEntryPriceBuy;
      if(refPrice == 0) return;
      
      double lastPrice = g_pairs[pairIndex].lastProfitPriceBuy;
      if(lastPrice == 0) lastPrice = refPrice;
      
      // Price goes UP = Profit for BUY side
      if(currentPrice > lastPrice + gridDistance)
      {
         OpenGridProfitBuy(pairIndex);
         g_pairs[pairIndex].lastProfitPriceBuy = currentPrice;
      }
   }
   else // SELL
   {
      // SELL Side: Profit direction = price going DOWN from initial entry
      double refPrice = g_pairs[pairIndex].initialEntryPriceSell;
      if(refPrice == 0) return;
      
      double lastPrice = g_pairs[pairIndex].lastProfitPriceSell;
      if(lastPrice == 0) lastPrice = refPrice;
      
      // Price goes DOWN = Profit for SELL side
      if(currentPrice < lastPrice - gridDistance)
      {
         OpenGridProfitSell(pairIndex);
         g_pairs[pairIndex].lastProfitPriceSell = currentPrice;
      }
   }
}

//+------------------------------------------------------------------+
//| Check Grid Profit by Z-Score (v3.6.0)                              |
//+------------------------------------------------------------------+
void CheckGridProfitZScore(int pairIndex, string side)
{
   double currentZ = g_pairs[pairIndex].zScore;
   
   if(side == "SELL")
   {
      // SELL Side (positive Z-Score): Open Grid Profit when Z-Score decreases toward 0
      int currentCount = g_pairs[pairIndex].gridProfitZLevelSell;
      if(currentCount >= g_profitZScoreGridCount) return;
      
      double targetLevel = g_profitZScoreGridLevels[currentCount];
      
      // Z-Score decreasing = profitable for SELL side
      if(currentZ <= targetLevel)
      {
         OpenGridProfitSell(pairIndex);
         g_pairs[pairIndex].gridProfitZLevelSell++;
      }
   }
   else // BUY Side (negative Z-Score)
   {
      // BUY Side: Open Grid Profit when Z-Score increases toward 0
      int currentCount = g_pairs[pairIndex].gridProfitZLevelBuy;
      if(currentCount >= g_profitZScoreGridCount) return;
      
      double targetLevel = -g_profitZScoreGridLevels[currentCount];
      
      // Z-Score increasing (toward 0) = profitable for BUY side
      if(currentZ >= targetLevel)
      {
         OpenGridProfitBuy(pairIndex);
         g_pairs[pairIndex].gridProfitZLevelBuy++;
      }
   }
}

//+------------------------------------------------------------------+
//| Check if Symbol is Gold/XAU Pair (v1.6)                            |
//+------------------------------------------------------------------+
bool IsGoldPair(string symbol)
{
   string upper = symbol;
   StringToUpper(upper);
   return (StringFind(upper, "XAU") >= 0 || StringFind(upper, "GOLD") >= 0);
}

//+------------------------------------------------------------------+
//| Get Total Order Count for a Pair Side (v1.6)                       |
//| Returns: Main Order (1) + Grid Loss + Grid Profit                  |
//+------------------------------------------------------------------+
int GetTotalOrderCount(int pairIndex, string side)
{
   if(side == "BUY")
   {
      int main = (g_pairs[pairIndex].directionBuy == 1) ? 1 : 0;
      int gridLoss = g_pairs[pairIndex].avgOrderCountBuy;
      int gridProfit = g_pairs[pairIndex].gridProfitCountBuy;
      return main + gridLoss + gridProfit;
   }
   else
   {
      int main = (g_pairs[pairIndex].directionSell == 1) ? 1 : 0;
      int gridLoss = g_pairs[pairIndex].avgOrderCountSell;
      int gridProfit = g_pairs[pairIndex].gridProfitCountSell;
      return main + gridLoss + gridProfit;
   }
}

//+------------------------------------------------------------------+
//| Calculate Grid Distance (v1.6 - Symbol-Specific ATR + Min Dist)    |
//+------------------------------------------------------------------+
double CalculateGridDistance(int pairIndex, ENUM_GRID_DISTANCE_MODE mode, 
                              double atrMultForex, double atrMultGold, double minDistPips,
                              double fixedPoints, double fixedPips,
                              ENUM_TIMEFRAMES atrTimeframe, int atrPeriod)
{
   string symbolA = g_pairs[pairIndex].symbolA;
   double point = SymbolInfoDouble(symbolA, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbolA, SYMBOL_DIGITS);
   double pipSize = (digits == 3 || digits == 5) ? point * 10 : point;
   
   switch(mode)
   {
      case GRID_DIST_ATR:
      {
         // v2.1.6: Use cached ATR (updated once per new bar) for stable grid distance
         double atr = g_pairs[pairIndex].cachedGridLossATR;
         if(atr <= 0)
         {
            // Fallback: calculate if cache empty (first run)
            atr = CalculateSimplifiedATR(symbolA, atrTimeframe, atrPeriod);
            g_pairs[pairIndex].cachedGridLossATR = atr;
         }
         
         // v1.6: Use symbol-specific ATR multiplier
         double mult = IsGoldPair(symbolA) ? atrMultGold : atrMultForex;
         double distance = atr * mult;
         
         // v1.6: Apply minimum distance fallback
         double minDistance = minDistPips * pipSize;
         
         // v2.1.6: Debug log removed from here - now only logs when cache updates (once per bar)
         
         return MathMax(distance, minDistance);
      }
      case GRID_DIST_FIXED_POINTS:
         return fixedPoints * point;
         
      case GRID_DIST_FIXED_PIPS:
         return fixedPips * pipSize;
         
      case GRID_DIST_ZSCORE:
         // Z-Score mode uses level-based triggering, not price distance
         return 0;
   }
   return 0;
}

//+------------------------------------------------------------------+
//| Calculate Grid Lots by Type (v3.6.0)                               |
//+------------------------------------------------------------------+
void CalculateGridLots(int pairIndex, string side, 
                       ENUM_GRID_LOT_TYPE lotType,
                       double customLot, double lotMult,
                       double baseLotA, double baseLotB,
                       double &outLotA, double &outLotB,
                       bool isGridOrder, bool isProfitSide)
{
   string symbolA = g_pairs[pairIndex].symbolA;
   string symbolB = g_pairs[pairIndex].symbolB;
   
   switch(lotType)
   {
      case GRID_LOT_TYPE_INITIAL:
         // Use Initial Order lots
         outLotA = NormalizeLot(symbolA, baseLotA);
         outLotB = NormalizeLot(symbolB, baseLotB);
         break;
         
      case GRID_LOT_TYPE_CUSTOM:
         // Use custom fixed lot (same for both symbols)
         outLotA = NormalizeLot(symbolA, customLot);
         outLotB = NormalizeLot(symbolB, customLot);
         break;
         
      case GRID_LOT_TYPE_MULTIPLIER:
         // Apply multiplier from previous grid order
         if(isProfitSide)
         {
            // Grid Profit Side
            if(side == "BUY")
            {
               double prevA = (g_pairs[pairIndex].lastProfitGridLotBuyA > 0) 
                              ? g_pairs[pairIndex].lastProfitGridLotBuyA : baseLotA;
               double prevB = (g_pairs[pairIndex].lastProfitGridLotBuyB > 0) 
                              ? g_pairs[pairIndex].lastProfitGridLotBuyB : baseLotB;
               outLotA = NormalizeLot(symbolA, prevA * lotMult);
               outLotB = NormalizeLot(symbolB, prevB * lotMult);
            }
            else
            {
               double prevA = (g_pairs[pairIndex].lastProfitGridLotSellA > 0) 
                              ? g_pairs[pairIndex].lastProfitGridLotSellA : baseLotA;
               double prevB = (g_pairs[pairIndex].lastProfitGridLotSellB > 0) 
                              ? g_pairs[pairIndex].lastProfitGridLotSellB : baseLotB;
               outLotA = NormalizeLot(symbolA, prevA * lotMult);
               outLotB = NormalizeLot(symbolB, prevB * lotMult);
            }
         }
         else
         {
            // Grid Loss Side
            if(side == "BUY")
            {
               double prevA = (g_pairs[pairIndex].lastGridLotBuyA > 0) 
                              ? g_pairs[pairIndex].lastGridLotBuyA : baseLotA;
               double prevB = (g_pairs[pairIndex].lastGridLotBuyB > 0) 
                              ? g_pairs[pairIndex].lastGridLotBuyB : baseLotB;
               outLotA = NormalizeLot(symbolA, prevA * lotMult);
               outLotB = NormalizeLot(symbolB, prevB * lotMult);
            }
            else
            {
               double prevA = (g_pairs[pairIndex].lastGridLotSellA > 0) 
                              ? g_pairs[pairIndex].lastGridLotSellA : baseLotA;
               double prevB = (g_pairs[pairIndex].lastGridLotSellB > 0) 
                              ? g_pairs[pairIndex].lastGridLotSellB : baseLotB;
               outLotA = NormalizeLot(symbolA, prevA * lotMult);
               outLotB = NormalizeLot(symbolB, prevB * lotMult);
            }
         }
         break;
         
      case GRID_LOT_TYPE_TREND_BASED:
         // v1.8.8 HF4: Pass isProfitSide to differentiate Grid Loss vs Grid Profit
         CalculateTrendBasedLots(pairIndex, side, baseLotA, baseLotB, outLotA, outLotB, isGridOrder, true, isProfitSide);
         break;
   }
}

//+------------------------------------------------------------------+
//| Simplified ATR Calculation (v3.3.1 - No Indicator Handle)          |
//+------------------------------------------------------------------+
double CalculateSimplifiedATR(string symbol, ENUM_TIMEFRAMES tf, int period)
{
   double sum = 0;
   int validBars = 0;
   
   // v2.1.6: Start from bar 1 (first CLOSED bar) for stable ATR
   // This ensures ATR doesn't change during the current bar
   for(int i = 1; i <= period; i++)
   {
      double high = iHigh(symbol, tf, i);
      double low = iLow(symbol, tf, i);
      double prevClose = iClose(symbol, tf, i + 1);
      
      if(high == 0 || low == 0 || prevClose == 0) continue;
      
      double tr1 = high - low;
      double tr2 = MathAbs(high - prevClose);
      double tr3 = MathAbs(low - prevClose);
      
      sum += MathMax(tr1, MathMax(tr2, tr3));
      validBars++;
   }
   
   if(validBars == 0) return 0;
   return sum / validBars;
}

//+------------------------------------------------------------------+
//| v2.1.6: Update ATR Cache on New Bar                                |
//+------------------------------------------------------------------+
void UpdateATRCache(int pairIndex)
{
   string symbolA = g_pairs[pairIndex].symbolA;
   
   // Check if new bar formed (using Grid ATR timeframe)
   datetime currentBar = iTime(symbolA, InpGridATRTimeframe, 0);
   if(currentBar == g_pairs[pairIndex].lastATRBarTime)
      return;  // Same bar - use cached value
   
   // New bar - recalculate ATR
   g_pairs[pairIndex].lastATRBarTime = currentBar;
   
   // Grid Loss ATR
   g_pairs[pairIndex].cachedGridLossATR = CalculateSimplifiedATR(
      symbolA, InpGridLossATRTimeframe, InpGridLossATRPeriod);
   
   // Grid Profit ATR (may use different settings)
   g_pairs[pairIndex].cachedGridProfitATR = CalculateSimplifiedATR(
      symbolA, InpGridProfitATRTimeframe, InpGridProfitATRPeriod);
   
   if(InpDebugMode && (!g_isTesterMode || !InpDisableDebugInTester))
   {
      PrintFormat("[v2.1.6 ATR CACHE] Pair %d (%s): GridLossATR=%.5f, GridProfitATR=%.5f",
                  pairIndex + 1, symbolA, 
                  g_pairs[pairIndex].cachedGridLossATR,
                  g_pairs[pairIndex].cachedGridProfitATR);
   }
}

//+------------------------------------------------------------------+
//| Calculate ATR Ratio for Pair (v3.5.3)                              |
//| Returns: Ratio = ATR(SymbolA) / ATR(SymbolB)                       |
//+------------------------------------------------------------------+
double CalculateATRRatio(int pairIndex)
{
   string symbolA = g_pairs[pairIndex].symbolA;
   string symbolB = g_pairs[pairIndex].symbolB;
   
   double atrA = CalculateSimplifiedATR(symbolA, InpGridATRTimeframe, InpGridATRPeriod);
   double atrB = CalculateSimplifiedATR(symbolB, InpGridATRTimeframe, InpGridATRPeriod);
   
   if(atrB <= 0) return 1.0;  // Fallback to 1:1
   
   double ratio = atrA / atrB;
   
   if(InpDebugMode && (!g_isTesterMode || !InpDisableDebugInTester))
      PrintFormat("ATR Ratio [Pair %d]: %s=%.5f, %s=%.5f, Ratio=%.3f", 
                  pairIndex + 1, symbolA, atrA, symbolB, atrB, ratio);
   
   return ratio;
}

//+------------------------------------------------------------------+
//| Calculate Trend-Based Lots for Grid Orders (v1.2 Updated)          |
//| side: "BUY" or "SELL" - the hedge side (not individual symbol)     |
//| isGridOrder: true = Grid/Averaging order, false = Main entry       |
//| forceTrendLogic: true = Skip mode checks, always apply CDC logic   |
//| Returns: Adjusted lotA and lotB via reference                       |
//+------------------------------------------------------------------+
void CalculateTrendBasedLots(int pairIndex, string side, 
                              double baseLotA, double baseLotB,
                              double &adjustedLotA, double &adjustedLotB,
                              bool isGridOrder = false,
                              bool forceTrendLogic = false,
                              bool isProfitSide = false)  // v1.8.8 HF4: Add Profit Side flag
{
   string symbolA = g_pairs[pairIndex].symbolA;
   string symbolB = g_pairs[pairIndex].symbolB;
   
   // Default: no adjustment
   adjustedLotA = baseLotA;
   adjustedLotB = baseLotB;
   
   // === v1.2: Skip mode checks if forceTrendLogic is true ===
   // When called from GRID_LOT_TYPE_TREND_BASED, always apply CDC Trend logic
   if(!forceTrendLogic)
   {
      // === Mode 1: Fixed Lot (v3.5.3 HF1) - ใช้ Initial Lot เดิมตลอดทุก Level ===
      if(InpGridLotMode == GRID_LOT_FIXED)
      {
         // ใช้ Lot จาก Main Entry เท่าเดิมทุก Grid Level
         if(side == "BUY")
         {
            adjustedLotA = NormalizeLot(symbolA, g_pairs[pairIndex].lotBuyA);
            adjustedLotB = NormalizeLot(symbolB, g_pairs[pairIndex].lotBuyB);
         }
         else
         {
            adjustedLotA = NormalizeLot(symbolA, g_pairs[pairIndex].lotSellA);
            adjustedLotB = NormalizeLot(symbolB, g_pairs[pairIndex].lotSellB);
         }
         
         if(InpDebugMode && (!g_isTesterMode || !InpDisableDebugInTester))
            PrintFormat("FIXED LOT [Pair %d %s]: A=%.2f, B=%.2f (Initial Lot)", 
                        pairIndex + 1, side, adjustedLotA, adjustedLotB);
         return;
      }
      
      // === Mode 2: Beta Mode (เดิม) - ใช้ Hedge Ratio ===
      if(InpGridLotMode == GRID_LOT_BETA)
      {
         // Beta mode uses existing hedge ratio from lot calculation
         // Lots are already calculated with hedge ratio in CalculateDollarNeutralLots
         adjustedLotA = NormalizeLot(symbolA, baseLotA);
         adjustedLotB = NormalizeLot(symbolB, baseLotB);
         return;
      }
   }
   
   // === Mode 3: ATR Trend Mode (v3.5.3 HF2 - Fixed Initial Lot) ===
   if(InpGridLotMode == GRID_LOT_ATR_TREND)
   {
      // Requires CDC to be enabled
      if(!InpUseCDCTrendFilter)
      {
         // CDC not enabled, fallback to 1:1
         adjustedLotA = NormalizeLot(symbolA, baseLotA);
         adjustedLotB = NormalizeLot(symbolB, baseLotB);
         return;
      }
      
      string trendA = g_pairs[pairIndex].cdcTrendA;
      string trendB = g_pairs[pairIndex].cdcTrendB;
      int corrType = g_pairs[pairIndex].correlationType;
      
      // === Determine Direction for Each Symbol ===
      // BUY Side (Positive Corr): Buy A, Sell B
      // BUY Side (Negative Corr): Buy A, Buy B
      // SELL Side (Positive Corr): Sell A, Buy B
      // SELL Side (Negative Corr): Sell A, Sell B
      
      string directionA = (side == "BUY") ? "BUY" : "SELL";
      string directionB;
      if(corrType == 1)  // Positive Correlation
         directionB = (side == "BUY") ? "SELL" : "BUY";
      else  // Negative Correlation
         directionB = (side == "BUY") ? "BUY" : "SELL";
      
      // === Check Trend Alignment ===
      // BUY + BULLISH = Trend-Aligned
      // SELL + BEARISH = Trend-Aligned
      bool isTrendAlignedA = ((directionA == "BUY" && trendA == "BULLISH") ||
                              (directionA == "SELL" && trendA == "BEARISH"));
      bool isTrendAlignedB = ((directionB == "BUY" && trendB == "BULLISH") ||
                              (directionB == "SELL" && trendB == "BEARISH"));
      
      // === v1.6.5: Use GetScaledBaseLot as foundation for ATR Trend Mode ===
      // This fixes the issue where lotBuyA/B and lotSellA/B were influenced by Beta × Pip Ratio
      double scaledBaseLot = GetScaledBaseLot();
      double initialLotA = NormalizeLot(symbolA, scaledBaseLot);
      double initialLotB = NormalizeLot(symbolB, scaledBaseLot);
      
      // === Calculate Effective Base Lots ===
      double effectiveBaseLotA = initialLotA;
      double effectiveBaseLotB = initialLotB;
      
      // For Grid Orders with Compounding (Trend-Aligned side only)
      // v1.8.8 HF4: Separate Grid Loss vs Grid Profit compounding
      if(isGridOrder && InpLotProgression == LOT_PROG_COMPOUNDING)
      {
         // Use LAST Grid Lot as base for compounding (Trend-Aligned side only)
         // Counter-Trend side will be reset to initialLot below
         if(side == "BUY")
         {
            if(isProfitSide)
            {
               // Grid Profit: Use lastProfitGridLot variables
               if(isTrendAlignedA && g_pairs[pairIndex].lastProfitGridLotBuyA > 0)
                  effectiveBaseLotA = g_pairs[pairIndex].lastProfitGridLotBuyA;
               if(isTrendAlignedB && g_pairs[pairIndex].lastProfitGridLotBuyB > 0)
                  effectiveBaseLotB = g_pairs[pairIndex].lastProfitGridLotBuyB;
            }
            else
            {
               // Grid Loss: Use lastGridLot variables
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
               // Grid Profit: Use lastProfitGridLot variables
               if(isTrendAlignedA && g_pairs[pairIndex].lastProfitGridLotSellA > 0)
                  effectiveBaseLotA = g_pairs[pairIndex].lastProfitGridLotSellA;
               if(isTrendAlignedB && g_pairs[pairIndex].lastProfitGridLotSellB > 0)
                  effectiveBaseLotB = g_pairs[pairIndex].lastProfitGridLotSellB;
            }
            else
            {
               // Grid Loss: Use lastGridLot variables
               if(isTrendAlignedA && g_pairs[pairIndex].lastGridLotSellA > 0)
                  effectiveBaseLotA = g_pairs[pairIndex].lastGridLotSellA;
               if(isTrendAlignedB && g_pairs[pairIndex].lastGridLotSellB > 0)
                  effectiveBaseLotB = g_pairs[pairIndex].lastGridLotSellB;
            }
         }
      }
      
      // === Calculate Multipliers ===
      double multA = 1.0;
      double multB = 1.0;
      
      // === v3.5.3 HF3: ADX for Negative Correlation Pairs ===
      // เมื่อทั้งสองฝั่งเป็น Trend-Aligned (Negative Correlation) → ใช้ ADX ตัดสิน
      if(corrType == -1 && InpUseADXForNegative && isTrendAlignedA && isTrendAlignedB)
      {
         double adxA = g_pairs[pairIndex].adxValueA;
         double adxB = g_pairs[pairIndex].adxValueB;
         
         if(adxA > adxB && adxA >= InpADXMinStrength)
         {
            // Symbol A มี ADX สูงกว่า → A ได้ Trend Multiplier + Compounding, B ได้ Counter (Fixed)
            multA = InpTrendSideMultiplier;
            multB = InpCounterSideMultiplier;
            
            // For Compounding: Only A compounds, B stays fixed
            if(isGridOrder && InpLotProgression == LOT_PROG_COMPOUNDING)
            {
               // A continues compounding from last lot
               // B resets to initial lot
               effectiveBaseLotB = initialLotB;
            }
            
            if(InpDebugMode && (!g_isTesterMode || !InpDisableDebugInTester))
            {
               PrintFormat("ADX DECISION [Pair %d NEG]: %s ADX=%.1f > %s ADX=%.1f | Winner: %s (Compound), Loser: %s (Fixed)",
                           pairIndex + 1, symbolA, adxA, symbolB, adxB, symbolA, symbolB);
            }
         }
         else if(adxB > adxA && adxB >= InpADXMinStrength)
         {
            // Symbol B มี ADX สูงกว่า → B ได้ Trend Multiplier + Compounding, A ได้ Counter (Fixed)
            multA = InpCounterSideMultiplier;
            multB = InpTrendSideMultiplier;
            
            // For Compounding: Only B compounds, A stays fixed
            if(isGridOrder && InpLotProgression == LOT_PROG_COMPOUNDING)
            {
               // B continues compounding from last lot
               // A resets to initial lot
               effectiveBaseLotA = initialLotA;
            }
            
            if(InpDebugMode && (!g_isTesterMode || !InpDisableDebugInTester))
            {
               PrintFormat("ADX DECISION [Pair %d NEG]: %s ADX=%.1f > %s ADX=%.1f | Winner: %s (Compound), Loser: %s (Fixed)",
                           pairIndex + 1, symbolB, adxB, symbolA, adxA, symbolB, symbolA);
            }
         }
         else
         {
            // ADX เท่ากันหรือต่ำกว่า threshold → ใช้ Counter ทั้งคู่ (Conservative)
            multA = InpCounterSideMultiplier;
            multB = InpCounterSideMultiplier;
            effectiveBaseLotA = initialLotA;
            effectiveBaseLotB = initialLotB;
            
            if(InpDebugMode && (!g_isTesterMode || !InpDisableDebugInTester))
            {
               PrintFormat("ADX DECISION [Pair %d NEG]: ADX A=%.1f, B=%.1f both below threshold %.1f | Both use Counter (Fixed)",
                           pairIndex + 1, adxA, adxB, InpADXMinStrength);
            }
         }
      }
      else if(InpUseATRRatioForTrend)
      {
         // ATR Ratio Mode: เพิ่ม lot ของฝั่งที่ถูกเทรน ตาม ATR Ratio
         double atrRatio = CalculateATRRatio(pairIndex);
         
         if(isTrendAlignedA && !isTrendAlignedB)
         {
            multA = atrRatio;
            multB = InpCounterSideMultiplier;
         }
         else if(isTrendAlignedB && !isTrendAlignedA)
         {
            multA = InpCounterSideMultiplier;
            multB = atrRatio;
         }
         else
         {
            multA = isTrendAlignedA ? InpTrendSideMultiplier : InpCounterSideMultiplier;
            multB = isTrendAlignedB ? InpTrendSideMultiplier : InpCounterSideMultiplier;
         }
      }
      else
      {
         // Fixed Multiplier Mode (for Positive Correlation or ADX disabled)
         multA = isTrendAlignedA ? InpTrendSideMultiplier : InpCounterSideMultiplier;
         multB = isTrendAlignedB ? InpTrendSideMultiplier : InpCounterSideMultiplier;
      }
      
      // === v3.5.3 HF2: Counter-Trend Side uses Fixed Initial Lot ===
      // Counter-Trend: ใช้ InpBaseLot × CounterSideMultiplier เท่าเดิม (ไม่ compound)
      // Note: For Negative Correlation with ADX, this is already handled above
      if(!(corrType == -1 && InpUseADXForNegative && isTrendAlignedA && isTrendAlignedB))
      {
         if(!isTrendAlignedA)
         {
            effectiveBaseLotA = initialLotA;  // Reset to InpBaseLot
            multA = InpCounterSideMultiplier;  // Apply counter multiplier
         }
         
         if(!isTrendAlignedB)
         {
            effectiveBaseLotB = initialLotB;  // Reset to InpBaseLot
            multB = InpCounterSideMultiplier;  // Apply counter multiplier
         }
      }
      
      adjustedLotA = NormalizeLot(symbolA, effectiveBaseLotA * multA);
      adjustedLotB = NormalizeLot(symbolB, effectiveBaseLotB * multB);
      
      if(InpDebugMode && (!g_isTesterMode || !InpDisableDebugInTester))
      {
         string progMode = (isGridOrder && InpLotProgression == LOT_PROG_COMPOUNDING) ? "Compound" : "Mult";
         string corrStr = (corrType == -1) ? "NEG" : "POS";
         double scaleFactor = GetScaleFactor();
         PrintFormat("TREND LOT [Pair %d %s %s %s]: A(%s)=%.2f×%.2f=%.2f [%s:%s] | B(%s)=%.2f×%.2f=%.2f [%s:%s] [ScaledBase=%.4f (%.2f×%.2fx)]",
                     pairIndex + 1, corrStr, side, progMode,
                     symbolA, effectiveBaseLotA, multA, adjustedLotA, directionA, isTrendAlignedA ? "TREND" : "COUNTER",
                     symbolB, effectiveBaseLotB, multB, adjustedLotB, directionB, isTrendAlignedB ? "TREND" : "COUNTER",
                     scaledBaseLot, InpBaseLot, scaleFactor);
      }
   }
}

//+------------------------------------------------------------------+
//| Open Grid Loss Buy Position (v3.6.0)                               |
//+------------------------------------------------------------------+
void OpenGridLossBuy(int pairIndex)
{
   string symbolA = g_pairs[pairIndex].symbolA;
   string symbolB = g_pairs[pairIndex].symbolB;
   int corrType = g_pairs[pairIndex].correlationType;
   
   // v3.6.0: Calculate lots based on selected Lot Type
   double baseLotA = g_pairs[pairIndex].lotBuyA;
   double baseLotB = g_pairs[pairIndex].lotBuyB;
   double lotA, lotB;
   // v1.6.5: Use scaled custom lot
   CalculateGridLots(pairIndex, "BUY", InpGridLossLotType,
                     GetScaledGridLossCustomLot(symbolA), InpGridLossLotMultiplier,
                     baseLotA, baseLotB, lotA, lotB, true, false);
   
   // v3.5.3 HF4: Force update ADX before opening trade for Negative Correlation
   if(corrType == -1 && InpUseADXForNegative)
   {
      UpdateADXForPair(pairIndex);
   }
   
    // v1.8.8 HF: Build comment with Grid Level number (#1, #2, #3...)
    int gridLevel = g_pairs[pairIndex].avgOrderCountBuy + 1;
    string pairPrefix = GetPairCommentPrefix(pairIndex);
    string comment;
    if(corrType == -1 && InpUseADXForNegative)
    {
         comment = StringFormat("%s_GL#%d_BUY_%d[ADX:%.0f/%.0f][M:%d]", 
                                pairPrefix, gridLevel, pairIndex + 1,
                                g_pairs[pairIndex].adxValueA,
                                g_pairs[pairIndex].adxValueB, InpMagicNumber);
    }
    else
    {
       comment = StringFormat("%s_GL#%d_BUY_%d[M:%d]", pairPrefix, gridLevel, pairIndex + 1, InpMagicNumber);
    }
   
   // Open Buy on Symbol A
   double askA = SymbolInfoDouble(symbolA, SYMBOL_ASK);
   if(!g_trade.Buy(lotA, symbolA, askA, 0, 0, comment))
   {
      PrintFormat("GL BUY %s failed: %d", symbolA, GetLastError());
      return;
   }
   ulong ticketA = g_trade.ResultOrder();
   
   // Open position on Symbol B based on correlation type
   bool successB = false;
   if(corrType == 1)  // Positive correlation: Sell B
   {
      double bidB = SymbolInfoDouble(symbolB, SYMBOL_BID);
      successB = g_trade.Sell(lotB, symbolB, bidB, 0, 0, comment);
   }
   else  // Negative correlation: Buy B
   {
      double askB = SymbolInfoDouble(symbolB, SYMBOL_ASK);
      successB = g_trade.Buy(lotB, symbolB, askB, 0, 0, comment);
   }
   
   // Rollback if Symbol B fails
   if(!successB)
   {
      PrintFormat("GL BUY %s failed: %d - ROLLING BACK %s", symbolB, GetLastError(), symbolA);
      g_trade.PositionClose(ticketA);
      return;
   }
   
   // Update Last Grid Lots for next compounding
   g_pairs[pairIndex].lastGridLotBuyA = lotA;
   g_pairs[pairIndex].lastGridLotBuyB = lotB;
   
   g_pairs[pairIndex].avgOrderCountBuy++;
   g_pairs[pairIndex].orderCountBuy++;
   
   // v3.6.0 HF4: Track total grid lot for history
   g_pairs[pairIndex].avgTotalLotBuy += lotA + lotB;
   
   string modeStr = EnumToString(InpGridLossLotType);
   
   PrintFormat("Pair %d GRID LOSS BUY #%d: Z=%.2f (A:%.2f B:%.2f) [%s]", 
               pairIndex + 1, g_pairs[pairIndex].avgOrderCountBuy, 
               g_pairs[pairIndex].zScore, lotA, lotB, modeStr);
}

//+------------------------------------------------------------------+
//| Open Grid Loss Sell Position (v3.6.0)                              |
//+------------------------------------------------------------------+
void OpenGridLossSell(int pairIndex)
{
   string symbolA = g_pairs[pairIndex].symbolA;
   string symbolB = g_pairs[pairIndex].symbolB;
   int corrType = g_pairs[pairIndex].correlationType;
   
   // v3.6.0: Calculate lots based on selected Lot Type
   double baseLotA = g_pairs[pairIndex].lotSellA;
   double baseLotB = g_pairs[pairIndex].lotSellB;
   double lotA, lotB;
   // v1.6.5: Use scaled custom lot
   CalculateGridLots(pairIndex, "SELL", InpGridLossLotType,
                     GetScaledGridLossCustomLot(symbolA), InpGridLossLotMultiplier,
                     baseLotA, baseLotB, lotA, lotB, true, false);
   
   // v3.5.3 HF4: Force update ADX before opening trade for Negative Correlation
   if(corrType == -1 && InpUseADXForNegative)
   {
      UpdateADXForPair(pairIndex);
   }
   
   // v1.8.8 HF: Build comment with Grid Level number (#1, #2, #3...)
   int gridLevel = g_pairs[pairIndex].avgOrderCountSell + 1;
   string pairPrefix = GetPairCommentPrefix(pairIndex);
   string comment;
   if(corrType == -1 && InpUseADXForNegative)
   {
        comment = StringFormat("%s_GL#%d_SELL_%d[ADX:%.0f/%.0f][M:%d]", 
                               pairPrefix, gridLevel, pairIndex + 1,
                               g_pairs[pairIndex].adxValueA,
                               g_pairs[pairIndex].adxValueB, InpMagicNumber);
   }
   else
   {
      comment = StringFormat("%s_GL#%d_SELL_%d[M:%d]", pairPrefix, gridLevel, pairIndex + 1, InpMagicNumber);
   }
   
   // Open Sell on Symbol A
   double bidA = SymbolInfoDouble(symbolA, SYMBOL_BID);
   if(!g_trade.Sell(lotA, symbolA, bidA, 0, 0, comment))
   {
      PrintFormat("GL SELL %s failed: %d", symbolA, GetLastError());
      return;
   }
   ulong ticketA = g_trade.ResultOrder();
   
   // Open position on Symbol B based on correlation type
   bool successB = false;
   if(corrType == 1)  // Positive correlation: Buy B
   {
      double askB = SymbolInfoDouble(symbolB, SYMBOL_ASK);
      successB = g_trade.Buy(lotB, symbolB, askB, 0, 0, comment);
   }
   else  // Negative correlation: Sell B
   {
      double bidB = SymbolInfoDouble(symbolB, SYMBOL_BID);
      successB = g_trade.Sell(lotB, symbolB, bidB, 0, 0, comment);
   }
   
   // Rollback if Symbol B fails
   if(!successB)
   {
      PrintFormat("GL SELL %s failed: %d - ROLLING BACK %s", symbolB, GetLastError(), symbolA);
      g_trade.PositionClose(ticketA);
      return;
   }
   
   // Update Last Grid Lots for next compounding
   g_pairs[pairIndex].lastGridLotSellA = lotA;
   g_pairs[pairIndex].lastGridLotSellB = lotB;
   
   g_pairs[pairIndex].avgOrderCountSell++;
   g_pairs[pairIndex].orderCountSell++;
   
   // v3.6.0 HF4: Track total grid lot for history
   g_pairs[pairIndex].avgTotalLotSell += lotA + lotB;
   
   string modeStr = EnumToString(InpGridLossLotType);
   
   PrintFormat("Pair %d GRID LOSS SELL #%d: Z=%.2f (A:%.2f B:%.2f) [%s]", 
               pairIndex + 1, g_pairs[pairIndex].avgOrderCountSell, 
               g_pairs[pairIndex].zScore, lotA, lotB, modeStr);
}

//+------------------------------------------------------------------+
//| Open Grid Profit Buy Position (v3.6.0)                             |
//+------------------------------------------------------------------+
void OpenGridProfitBuy(int pairIndex)
{
   string symbolA = g_pairs[pairIndex].symbolA;
   string symbolB = g_pairs[pairIndex].symbolB;
   int corrType = g_pairs[pairIndex].correlationType;
   
   // v3.6.0: Calculate lots based on selected Lot Type
   double baseLotA = g_pairs[pairIndex].lotBuyA;
   double baseLotB = g_pairs[pairIndex].lotBuyB;
   double lotA, lotB;
   // v1.6.5: Use scaled custom lot
   CalculateGridLots(pairIndex, "BUY", InpGridProfitLotType,
                     GetScaledGridProfitCustomLot(symbolA), InpGridProfitLotMultiplier,
                     baseLotA, baseLotB, lotA, lotB, true, true);
   
   // v3.5.3 HF4: Force update ADX before opening trade for Negative Correlation
   if(corrType == -1 && InpUseADXForNegative)
   {
      UpdateADXForPair(pairIndex);
   }
   
   // v1.8.8 HF: Build comment with Grid Level number (#1, #2, #3...)
   int gridLevel = g_pairs[pairIndex].gridProfitCountBuy + 1;
   string pairPrefix = GetPairCommentPrefix(pairIndex);
   string comment;
   if(corrType == -1 && InpUseADXForNegative)
   {
        comment = StringFormat("%s_GP#%d_BUY_%d[ADX:%.0f/%.0f][M:%d]", 
                               pairPrefix, gridLevel, pairIndex + 1,
                               g_pairs[pairIndex].adxValueA,
                               g_pairs[pairIndex].adxValueB, InpMagicNumber);
   }
   else
   {
      comment = StringFormat("%s_GP#%d_BUY_%d[M:%d]", pairPrefix, gridLevel, pairIndex + 1, InpMagicNumber);
   }
   
   // Open BUY on Symbol A (same direction as Initial)
   double askA = SymbolInfoDouble(symbolA, SYMBOL_ASK);
   if(!g_trade.Buy(lotA, symbolA, askA, 0, 0, comment))
   {
      PrintFormat("GP BUY %s failed: %d", symbolA, GetLastError());
      return;
   }
   ulong ticketA = g_trade.ResultOrder();
   
   // Open position on Symbol B based on correlation type
   bool successB = false;
   if(corrType == 1)  // Positive: Sell B
   {
      double bidB = SymbolInfoDouble(symbolB, SYMBOL_BID);
      successB = g_trade.Sell(lotB, symbolB, bidB, 0, 0, comment);
   }
   else  // Negative: Buy B
   {
      double askB = SymbolInfoDouble(symbolB, SYMBOL_ASK);
      successB = g_trade.Buy(lotB, symbolB, askB, 0, 0, comment);
   }
   
   if(!successB)
   {
      PrintFormat("GP BUY %s failed: %d - ROLLING BACK", symbolB, GetLastError());
      g_trade.PositionClose(ticketA);
      return;
   }
   
   g_pairs[pairIndex].gridProfitCountBuy++;
   g_pairs[pairIndex].orderCountBuy++;
   
   // Update Last Profit Grid Lots
   g_pairs[pairIndex].lastProfitGridLotBuyA = lotA;
   g_pairs[pairIndex].lastProfitGridLotBuyB = lotB;
   
   // v3.6.0 HF4: Track total grid lot for history
   g_pairs[pairIndex].avgTotalLotBuy += lotA + lotB;
   
   PrintFormat("Pair %d GRID PROFIT BUY #%d: (A:%.2f B:%.2f)", 
               pairIndex + 1, g_pairs[pairIndex].gridProfitCountBuy, lotA, lotB);
}

//+------------------------------------------------------------------+
//| Open Grid Profit Sell Position (v3.6.0)                            |
//+------------------------------------------------------------------+
void OpenGridProfitSell(int pairIndex)
{
   string symbolA = g_pairs[pairIndex].symbolA;
   string symbolB = g_pairs[pairIndex].symbolB;
   int corrType = g_pairs[pairIndex].correlationType;
   
   // v3.6.0: Calculate lots based on selected Lot Type
   double baseLotA = g_pairs[pairIndex].lotSellA;
   double baseLotB = g_pairs[pairIndex].lotSellB;
   double lotA, lotB;
   // v1.6.5: Use scaled custom lot
   CalculateGridLots(pairIndex, "SELL", InpGridProfitLotType,
                     GetScaledGridProfitCustomLot(symbolA), InpGridProfitLotMultiplier,
                     baseLotA, baseLotB, lotA, lotB, true, true);
   // v3.5.3 HF4: Force update ADX before opening trade for Negative Correlation
   if(corrType == -1 && InpUseADXForNegative)
   {
      UpdateADXForPair(pairIndex);
   }
   
   // v1.8.8 HF: Build comment with Grid Level number (#1, #2, #3...)
   int gridLevel = g_pairs[pairIndex].gridProfitCountSell + 1;
   string pairPrefix = GetPairCommentPrefix(pairIndex);
   string comment;
   if(corrType == -1 && InpUseADXForNegative)
   {
        comment = StringFormat("%s_GP#%d_SELL_%d[ADX:%.0f/%.0f][M:%d]", 
                               pairPrefix, gridLevel, pairIndex + 1,
                               g_pairs[pairIndex].adxValueA,
                               g_pairs[pairIndex].adxValueB, InpMagicNumber);
   }
   else
   {
      comment = StringFormat("%s_GP#%d_SELL_%d[M:%d]", pairPrefix, gridLevel, pairIndex + 1, InpMagicNumber);
   }
   
   // Open SELL on Symbol A
   double bidA = SymbolInfoDouble(symbolA, SYMBOL_BID);
   if(!g_trade.Sell(lotA, symbolA, bidA, 0, 0, comment))
   {
      PrintFormat("GP SELL %s failed: %d", symbolA, GetLastError());
      return;
   }
   ulong ticketA = g_trade.ResultOrder();
   
   // Open position on Symbol B based on correlation type
   bool successB = false;
   if(corrType == 1)  // Positive: Buy B
   {
      double askB = SymbolInfoDouble(symbolB, SYMBOL_ASK);
      successB = g_trade.Buy(lotB, symbolB, askB, 0, 0, comment);
   }
   else  // Negative: Sell B
   {
      double bidB = SymbolInfoDouble(symbolB, SYMBOL_BID);
      successB = g_trade.Sell(lotB, symbolB, bidB, 0, 0, comment);
   }
   
   if(!successB)
   {
      PrintFormat("GP SELL %s failed: %d - ROLLING BACK", symbolB, GetLastError());
      g_trade.PositionClose(ticketA);
      return;
   }
   
   g_pairs[pairIndex].gridProfitCountSell++;
   g_pairs[pairIndex].orderCountSell++;
   
   // Update Last Profit Grid Lots
   g_pairs[pairIndex].lastProfitGridLotSellA = lotA;
   g_pairs[pairIndex].lastProfitGridLotSellB = lotB;
   
   // v3.6.0 HF4: Track total grid lot for history
   g_pairs[pairIndex].avgTotalLotSell += lotA + lotB;
   
   PrintFormat("Pair %d GRID PROFIT SELL #%d: (A:%.2f B:%.2f)", 
               pairIndex + 1, g_pairs[pairIndex].gridProfitCountSell, lotA, lotB);
}


//+------------------------------------------------------------------+
//| ================ EXECUTION ENGINE ================                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Open Buy Side Trade (v3.5.3 HF1 - with Compounding Init)           |
//+------------------------------------------------------------------+
bool OpenBuySideTrade(int pairIndex)
{
   string symbolA = g_pairs[pairIndex].symbolA;
   string symbolB = g_pairs[pairIndex].symbolB;
   int corrType = g_pairs[pairIndex].correlationType;
   
   // v3.5.3: Get base lots
   double baseLotA = g_pairs[pairIndex].lotBuyA;
   double baseLotB = g_pairs[pairIndex].lotBuyB;
   double lotA, lotB;
   
   // v3.5.3: Apply Trend-Based Lots if scope is ALL and not Fixed mode
   if(InpGridLotScope == GRID_SCOPE_ALL && InpGridLotMode == GRID_LOT_ATR_TREND)
   {
      CalculateTrendBasedLots(pairIndex, "BUY", baseLotA, baseLotB, lotA, lotB, false);
   }
   else
   {
      // Original behavior: just normalize
      lotA = NormalizeLot(symbolA, baseLotA);
      lotB = NormalizeLot(symbolB, baseLotB);
   }
   
   // v3.3.5: Validate lots are reasonable before trading
   double minReasonableLot = InpBaseLot * 0.1;  // At least 10% of Base Lot
   
   if(lotA < minReasonableLot || lotB < minReasonableLot)
   {
      // Re-calculate lots because current values are too small
      PrintFormat("WARNING Pair %d BUY: Lots too small (A:%.2f B:%.2f, Base:%.2f) - Recalculating...", 
                  pairIndex + 1, lotA, lotB, InpBaseLot);
      
      // Force recalculation
      CalculateDollarNeutralLots(pairIndex);
      
      lotA = NormalizeLot(symbolA, g_pairs[pairIndex].lotBuyA);
      lotB = NormalizeLot(symbolB, g_pairs[pairIndex].lotBuyB);
      
      // If still too small after recalculation, use InpBaseLot directly
      if(lotA < minReasonableLot)
      {
         PrintFormat("CRITICAL Pair %d: lotA still too small after recalc - using InpBaseLot %.2f", pairIndex + 1, InpBaseLot);
         lotA = NormalizeLot(symbolA, InpBaseLot);
         g_pairs[pairIndex].lotBuyA = lotA;
      }
      if(lotB < minReasonableLot)
      {
         PrintFormat("CRITICAL Pair %d: lotB still too small after recalc - using InpBaseLot %.2f", pairIndex + 1, InpBaseLot);
         lotB = NormalizeLot(symbolB, InpBaseLot);
         g_pairs[pairIndex].lotBuyB = lotB;
      }
   }
   
   // v3.5.3 HF1: Mode string for logging
   string modeStr = (InpGridLotMode == GRID_LOT_FIXED) ? "Fixed" :
                    (InpGridLotMode == GRID_LOT_BETA) ? "Beta" : "ATR-Trend";
   
   PrintFormat("Pair %d OPENING BUY: lotA=%.2f lotB=%.2f (stored: A=%.2f B=%.2f, Base=%.2f) [Mode:%s]", 
               pairIndex + 1, lotA, lotB, 
               g_pairs[pairIndex].lotBuyA, g_pairs[pairIndex].lotBuyB, InpBaseLot, modeStr);
   
   // v3.5.3 HF4: Force update ADX before opening trade for Negative Correlation
   if(corrType == -1 && InpUseADXForNegative)
   {
      UpdateADXForPair(pairIndex);
   }
   
   // v1.8.7: ADX comment with pair abbreviation prefix AND set number
   string pairPrefix = GetPairCommentPrefix(pairIndex);
   string comment;
   if(corrType == -1 && InpUseADXForNegative)
   {
      comment = StringFormat("%s_BUY_%d[ADX:%.0f/%.0f][M:%d]", 
                             pairPrefix, pairIndex + 1,
                             g_pairs[pairIndex].adxValueA,
                             g_pairs[pairIndex].adxValueB, InpMagicNumber);
   }
   else
   {
      comment = StringFormat("%s_BUY_%d[M:%d]", pairPrefix, pairIndex + 1, InpMagicNumber);
   }
   
   ulong ticketA = 0;
   ulong ticketB = 0;
   
   // Open Buy on Symbol A
   double askA = SymbolInfoDouble(symbolA, SYMBOL_ASK);
   if(g_trade.Buy(lotA, symbolA, askA, 0, 0, comment))
   {
      ticketA = g_trade.ResultOrder();
      
      // v1.3: Validate ticket was recorded - fallback scan if failed
      if(ticketA == 0)
      {
         ticketA = FindPositionTicketBySymbolAndComment(symbolA, comment);
         PrintFormat("[v1.3 FALLBACK] BUY SymbolA ticket scan: found=%d", ticketA);
      }
   }
   else
   {
      PrintFormat("Failed to open BUY on %s: %d", symbolA, GetLastError());
      return false;
   }
   
   // v1.3: Short delay to ensure first order is processed
   Sleep(50);
   
   // Open position on Symbol B based on correlation type
   if(corrType == 1)  // Positive correlation: Sell B
   {
      double bidB = SymbolInfoDouble(symbolB, SYMBOL_BID);
      if(g_trade.Sell(lotB, symbolB, bidB, 0, 0, comment))
      {
         ticketB = g_trade.ResultOrder();
         
         // v1.3: Validate ticket was recorded - fallback scan if failed
         if(ticketB == 0)
         {
            ticketB = FindPositionTicketBySymbolAndComment(symbolB, comment);
            PrintFormat("[v1.3 FALLBACK] BUY SymbolB (SELL hedge) ticket scan: found=%d", ticketB);
         }
      }
      else
      {
         PrintFormat("Failed to open SELL on %s: %d - Rolling back", symbolB, GetLastError());
         g_trade.PositionClose(ticketA);
         return false;
      }
   }
   else  // Negative correlation: Buy B
   {
      double askB = SymbolInfoDouble(symbolB, SYMBOL_ASK);
      if(g_trade.Buy(lotB, symbolB, askB, 0, 0, comment))
      {
         ticketB = g_trade.ResultOrder();
         
         // v1.3: Validate ticket was recorded - fallback scan if failed
         if(ticketB == 0)
         {
            ticketB = FindPositionTicketBySymbolAndComment(symbolB, comment);
            PrintFormat("[v1.3 FALLBACK] BUY SymbolB ticket scan: found=%d", ticketB);
         }
      }
      else
      {
         PrintFormat("Failed to open BUY on %s: %d - Rolling back", symbolB, GetLastError());
         g_trade.PositionClose(ticketA);
         return false;
      }
   }
   
   // Record trade info
   g_pairs[pairIndex].ticketBuyA = ticketA;
   g_pairs[pairIndex].ticketBuyB = ticketB;
   g_pairs[pairIndex].orderCountBuy++;
   g_pairs[pairIndex].entryTimeBuy = TimeCurrent();
   
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
   
   // v2.1: Reset Mini Group target trigger when new position opened
   int miniIdx = GetMiniGroupIndex(pairIndex);
   if(g_miniGroups[miniIdx].targetTriggered)
   {
      g_miniGroups[miniIdx].targetTriggered = false;
      PrintFormat("[v2.1] Mini Group %d target trigger RESET (new BUY position opened)", miniIdx + 1);
   }
   
   PrintFormat("Pair %d BUY SIDE OPENED: BUY %s | %s %s | Z=%.2f | Corr=%s",
      pairIndex + 1, symbolA,
      corrType == 1 ? "SELL" : "BUY", symbolB,
      g_pairs[pairIndex].zScore,
      corrType == 1 ? "Positive" : "Negative");
   
   return true;
}

//+------------------------------------------------------------------+
//| Open Sell Side Trade (v3.5.3 HF1 - with Compounding Init)          |
//+------------------------------------------------------------------+
bool OpenSellSideTrade(int pairIndex)
{
   string symbolA = g_pairs[pairIndex].symbolA;
   string symbolB = g_pairs[pairIndex].symbolB;
   int corrType = g_pairs[pairIndex].correlationType;
   
   // v3.5.3: Get base lots
   double baseLotA = g_pairs[pairIndex].lotSellA;
   double baseLotB = g_pairs[pairIndex].lotSellB;
   double lotA, lotB;
   
   // v3.5.3: Apply Trend-Based Lots if scope is ALL and ATR Trend mode
   if(InpGridLotScope == GRID_SCOPE_ALL && InpGridLotMode == GRID_LOT_ATR_TREND)
   {
      CalculateTrendBasedLots(pairIndex, "SELL", baseLotA, baseLotB, lotA, lotB, false);
   }
   else
   {
      // Original behavior: just normalize
      lotA = NormalizeLot(symbolA, baseLotA);
      lotB = NormalizeLot(symbolB, baseLotB);
   }
   
   // v3.3.5: Validate lots are reasonable before trading
   double minReasonableLot = InpBaseLot * 0.1;  // At least 10% of Base Lot
   
   if(lotA < minReasonableLot || lotB < minReasonableLot)
   {
      // Re-calculate lots because current values are too small
      PrintFormat("WARNING Pair %d SELL: Lots too small (A:%.2f B:%.2f, Base:%.2f) - Recalculating...", 
                  pairIndex + 1, lotA, lotB, InpBaseLot);
      
      // Force recalculation
      CalculateDollarNeutralLots(pairIndex);
      
      lotA = NormalizeLot(symbolA, g_pairs[pairIndex].lotSellA);
      lotB = NormalizeLot(symbolB, g_pairs[pairIndex].lotSellB);
      
      // If still too small after recalculation, use InpBaseLot directly
      if(lotA < minReasonableLot)
      {
         PrintFormat("CRITICAL Pair %d: lotA still too small after recalc - using InpBaseLot %.2f", pairIndex + 1, InpBaseLot);
         lotA = NormalizeLot(symbolA, InpBaseLot);
         g_pairs[pairIndex].lotSellA = lotA;
      }
      if(lotB < minReasonableLot)
      {
         PrintFormat("CRITICAL Pair %d: lotB still too small after recalc - using InpBaseLot %.2f", pairIndex + 1, InpBaseLot);
         lotB = NormalizeLot(symbolB, InpBaseLot);
         g_pairs[pairIndex].lotSellB = lotB;
      }
   }
   
   // v3.5.3 HF1: Mode string for logging
   string modeStr = (InpGridLotMode == GRID_LOT_FIXED) ? "Fixed" :
                    (InpGridLotMode == GRID_LOT_BETA) ? "Beta" : "ATR-Trend";
   
   PrintFormat("Pair %d OPENING SELL: lotA=%.2f lotB=%.2f (stored: A=%.2f B=%.2f, Base=%.2f) [Mode:%s]", 
               pairIndex + 1, lotA, lotB, 
               g_pairs[pairIndex].lotSellA, g_pairs[pairIndex].lotSellB, InpBaseLot, modeStr);
   
   // v3.5.3 HF4: Force update ADX before opening trade for Negative Correlation
   if(corrType == -1 && InpUseADXForNegative)
   {
      UpdateADXForPair(pairIndex);
   }
   
   // v1.8.7: ADX comment with pair abbreviation prefix AND set number
   string pairPrefix = GetPairCommentPrefix(pairIndex);
   string comment;
   if(corrType == -1 && InpUseADXForNegative)
   {
      comment = StringFormat("%s_SELL_%d[ADX:%.0f/%.0f][M:%d]", 
                             pairPrefix, pairIndex + 1,
                             g_pairs[pairIndex].adxValueA,
                             g_pairs[pairIndex].adxValueB, InpMagicNumber);
   }
   else
   {
      comment = StringFormat("%s_SELL_%d[M:%d]", pairPrefix, pairIndex + 1, InpMagicNumber);
   }
   
   ulong ticketA = 0;
   ulong ticketB = 0;
   
   // Open Sell on Symbol A
   double bidA = SymbolInfoDouble(symbolA, SYMBOL_BID);
   if(g_trade.Sell(lotA, symbolA, bidA, 0, 0, comment))
   {
      ticketA = g_trade.ResultOrder();
      
      // v1.3: Validate ticket was recorded - fallback scan if failed
      if(ticketA == 0)
      {
         ticketA = FindPositionTicketBySymbolAndComment(symbolA, comment);
         PrintFormat("[v1.3 FALLBACK] SELL SymbolA ticket scan: found=%d", ticketA);
      }
   }
   else
   {
      PrintFormat("Failed to open SELL on %s: %d", symbolA, GetLastError());
      return false;
   }
   
   // v1.3: Short delay to ensure first order is processed
   Sleep(50);
   
   // Open position on Symbol B based on correlation type
   if(corrType == 1)  // Positive correlation: Buy B
   {
      double askB = SymbolInfoDouble(symbolB, SYMBOL_ASK);
      if(g_trade.Buy(lotB, symbolB, askB, 0, 0, comment))
      {
         ticketB = g_trade.ResultOrder();
         
         // v1.3: Validate ticket was recorded - fallback scan if failed
         if(ticketB == 0)
         {
            ticketB = FindPositionTicketBySymbolAndComment(symbolB, comment);
            PrintFormat("[v1.3 FALLBACK] SELL SymbolB (BUY hedge) ticket scan: found=%d", ticketB);
         }
      }
      else
      {
         PrintFormat("Failed to open BUY on %s: %d - Rolling back", symbolB, GetLastError());
         g_trade.PositionClose(ticketA);
         return false;
      }
   }
   else  // Negative correlation: Sell B
   {
      double bidB = SymbolInfoDouble(symbolB, SYMBOL_BID);
      if(g_trade.Sell(lotB, symbolB, bidB, 0, 0, comment))
      {
         ticketB = g_trade.ResultOrder();
         
         // v1.3: Validate ticket was recorded - fallback scan if failed
         if(ticketB == 0)
         {
            ticketB = FindPositionTicketBySymbolAndComment(symbolB, comment);
            PrintFormat("[v1.3 FALLBACK] SELL SymbolB ticket scan: found=%d", ticketB);
         }
      }
      else
      {
         PrintFormat("Failed to open SELL on %s: %d - Rolling back", symbolB, GetLastError());
         g_trade.PositionClose(ticketA);
         return false;
      }
   }
   
   // Record trade info
   g_pairs[pairIndex].ticketSellA = ticketA;
   g_pairs[pairIndex].ticketSellB = ticketB;
   g_pairs[pairIndex].orderCountSell++;
   g_pairs[pairIndex].entryTimeSell = TimeCurrent();
   
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
   
   // v2.1: Reset Mini Group target trigger when new position opened
   int miniIdx = GetMiniGroupIndex(pairIndex);
   if(g_miniGroups[miniIdx].targetTriggered)
   {
      g_miniGroups[miniIdx].targetTriggered = false;
      PrintFormat("[v2.1] Mini Group %d target trigger RESET (new SELL position opened)", miniIdx + 1);
   }
   
   PrintFormat("Pair %d SELL SIDE OPENED: SELL %s | %s %s | Z=%.2f | Corr=%s",
      pairIndex + 1, symbolA,
      corrType == 1 ? "BUY" : "SELL", symbolB,
      g_pairs[pairIndex].zScore,
      corrType == 1 ? "Positive" : "Negative");
   
   return true;
}

//+------------------------------------------------------------------+
//| Close Buy Side Trade (v1.1 - Group Target System)                  |
//+------------------------------------------------------------------+
bool CloseBuySide(int pairIndex)
{
   if(g_pairs[pairIndex].directionBuy == 0) return false;
   
   // v1.1: Get group index
   int groupIdx = GetGroupIndex(pairIndex);
   
   // v3.6.0 HF3 Patch 3: Pause orphan detection during close
   g_orphanCheckPaused = true;
   
   bool closedA = false;
   bool closedB = false;
   
   // Close position A
   if(g_pairs[pairIndex].ticketBuyA > 0)
   {
      if(PositionSelectByTicket(g_pairs[pairIndex].ticketBuyA))
      {
         closedA = g_trade.PositionClose(g_pairs[pairIndex].ticketBuyA);
      }
      else
      {
         closedA = true;
      }
   }
   else
   {
      closedA = true;
   }
   
   // Close position B
   if(g_pairs[pairIndex].ticketBuyB > 0)
   {
      if(PositionSelectByTicket(g_pairs[pairIndex].ticketBuyB))
      {
         closedB = g_trade.PositionClose(g_pairs[pairIndex].ticketBuyB);
      }
      else
      {
         closedB = true;
      }
   }
   else
   {
      closedB = true;
   }
   
   // Close all averaging positions for Buy side
   CloseAveragingPositions(pairIndex, "BUY");
   
   if(closedA && closedB)
   {
      PrintFormat("Pair %d BUY SIDE CLOSED | Profit: %.2f | Group: %d", 
                  pairIndex + 1, g_pairs[pairIndex].profitBuy, groupIdx + 1);
      
      // v3.2.9: Accumulate closed P/L before reset
      g_pairs[pairIndex].closedProfitBuy += g_pairs[pairIndex].profitBuy;
      
       // v2.1.3: Add to MINI GROUP for basket accumulation
       int miniIdx = GetMiniGroupIndex(pairIndex);
       if(!g_miniGroups[miniIdx].targetTriggered)
       {
          g_miniGroups[miniIdx].closedProfit += g_pairs[pairIndex].profitBuy;
          PrintFormat("MINI GROUP %d: Added $%.2f from Pair %d BUY | Mini Total: $%.2f | Target: $%.2f",
                      miniIdx + 1, g_pairs[pairIndex].profitBuy, pairIndex + 1, 
                      g_miniGroups[miniIdx].closedProfit, g_miniGroups[miniIdx].closedTarget);
       }
       
       // v1.1: Also add to GROUP for Group-level tracking (unless group is closing all)
       if(!g_groups[groupIdx].closeMode)
       {
          g_groups[groupIdx].closedProfit += g_pairs[pairIndex].profitBuy;
          PrintFormat("GROUP %d: Added $%.2f from Pair %d BUY | Group Total: $%.2f | Target: $%.2f",
                      groupIdx + 1, g_pairs[pairIndex].profitBuy, pairIndex + 1, 
                      g_groups[groupIdx].closedProfit, g_groups[groupIdx].closedTarget);
       }
      
      // Update statistics before reset
      g_dailyProfit += g_pairs[pairIndex].profitBuy;
      g_weeklyProfit += g_pairs[pairIndex].profitBuy;
      g_monthlyProfit += g_pairs[pairIndex].profitBuy;
      g_allTimeProfit += g_pairs[pairIndex].profitBuy;
      // v3.6.0 HF4: Record ALL closed lots including Grid orders
      double closedLot = g_pairs[pairIndex].lotBuyA + g_pairs[pairIndex].lotBuyB + 
                         g_pairs[pairIndex].avgTotalLotBuy;  // Main + Grid orders
      g_dailyLot += closedLot;
      g_weeklyLot += closedLot;
      g_monthlyLot += closedLot;
      g_allTimeLot += closedLot;
      
      // v3.6.0 HF4: Count ALL closed orders (main pairs + all grid orders)
      int closedOrdersCount = g_pairs[pairIndex].orderCountBuy;  // Total orders on this side
      g_dailyClosedOrders += closedOrdersCount;
      g_weeklyClosedOrders += closedOrdersCount;
      g_monthlyClosedOrders += closedOrdersCount;
      g_allTimeClosedOrders += closedOrdersCount;
      
      // v3.2.4: Reset Buy side state (back to Ready for auto-resume)
      g_pairs[pairIndex].ticketBuyA = 0;
      g_pairs[pairIndex].ticketBuyB = 0;
      g_pairs[pairIndex].directionBuy = -1;  // Ready (auto-resume)
      g_pairs[pairIndex].profitBuy = 0;
      g_pairs[pairIndex].entryTimeBuy = 0;
      g_pairs[pairIndex].orderCountBuy = 0;
      g_pairs[pairIndex].lotBuyA = 0;
      g_pairs[pairIndex].lotBuyB = 0;
      // v3.2.7: Reset averaging
      g_pairs[pairIndex].avgOrderCountBuy = 0;
      g_pairs[pairIndex].lastAvgPriceBuy = 0;
      g_pairs[pairIndex].entryZScoreBuy = 0;
      // v3.6.0: Reset Grid Profit Side
      g_pairs[pairIndex].gridProfitCountBuy = 0;
      g_pairs[pairIndex].lastProfitPriceBuy = 0;
      g_pairs[pairIndex].initialEntryPriceBuy = 0;
      g_pairs[pairIndex].lastProfitGridLotBuyA = 0;
      g_pairs[pairIndex].lastProfitGridLotBuyB = 0;
      g_pairs[pairIndex].gridProfitZLevelBuy = 0;
      // v3.6.0 HF4: Reset total grid lot
      g_pairs[pairIndex].avgTotalLotBuy = 0;
      
      // v3.6.0 HF3 Patch 3: Resume orphan detection
      g_orphanCheckPaused = false;
      
      return true;
   }
   
   // v3.6.0 HF3 Patch 3: Resume orphan detection even on failure
   g_orphanCheckPaused = false;
   return false;
}

//+------------------------------------------------------------------+
//| Close Sell Side Trade (v1.1 - Group Target System)                 |
//+------------------------------------------------------------------+
bool CloseSellSide(int pairIndex)
{
   if(g_pairs[pairIndex].directionSell == 0) return false;
   
   // v1.1: Get group index
   int groupIdx = GetGroupIndex(pairIndex);
   
   // v3.6.0 HF3 Patch 3: Pause orphan detection during close
   g_orphanCheckPaused = true;
   
   bool closedA = false;
   bool closedB = false;
   
   // Close position A
   if(g_pairs[pairIndex].ticketSellA > 0)
   {
      if(PositionSelectByTicket(g_pairs[pairIndex].ticketSellA))
      {
         closedA = g_trade.PositionClose(g_pairs[pairIndex].ticketSellA);
      }
      else
      {
         closedA = true;
      }
   }
   else
   {
      closedA = true;
   }
   
   // Close position B
   if(g_pairs[pairIndex].ticketSellB > 0)
   {
      if(PositionSelectByTicket(g_pairs[pairIndex].ticketSellB))
      {
         closedB = g_trade.PositionClose(g_pairs[pairIndex].ticketSellB);
      }
      else
      {
         closedB = true;
      }
   }
   else
   {
      closedB = true;
   }
   
   // Close all averaging positions for Sell side
   CloseAveragingPositions(pairIndex, "SELL");
   
   if(closedA && closedB)
   {
      PrintFormat("Pair %d SELL SIDE CLOSED | Profit: %.2f | Group: %d", 
                  pairIndex + 1, g_pairs[pairIndex].profitSell, groupIdx + 1);
      
      // v3.2.9: Accumulate closed P/L before reset
      g_pairs[pairIndex].closedProfitSell += g_pairs[pairIndex].profitSell;
      
       // v2.1.3: Add to MINI GROUP for basket accumulation
       int miniIdx = GetMiniGroupIndex(pairIndex);
       if(!g_miniGroups[miniIdx].targetTriggered)
       {
          g_miniGroups[miniIdx].closedProfit += g_pairs[pairIndex].profitSell;
          PrintFormat("MINI GROUP %d: Added $%.2f from Pair %d SELL | Mini Total: $%.2f | Target: $%.2f",
                      miniIdx + 1, g_pairs[pairIndex].profitSell, pairIndex + 1, 
                      g_miniGroups[miniIdx].closedProfit, g_miniGroups[miniIdx].closedTarget);
       }
       
       // v1.1: Also add to GROUP for Group-level tracking (unless group is closing all)
       if(!g_groups[groupIdx].closeMode)
       {
          g_groups[groupIdx].closedProfit += g_pairs[pairIndex].profitSell;
          PrintFormat("GROUP %d: Added $%.2f from Pair %d SELL | Group Total: $%.2f | Target: $%.2f",
                      groupIdx + 1, g_pairs[pairIndex].profitSell, pairIndex + 1, 
                      g_groups[groupIdx].closedProfit, g_groups[groupIdx].closedTarget);
       }
      
      // Update statistics before reset
      g_dailyProfit += g_pairs[pairIndex].profitSell;
      g_weeklyProfit += g_pairs[pairIndex].profitSell;
      g_monthlyProfit += g_pairs[pairIndex].profitSell;
      g_allTimeProfit += g_pairs[pairIndex].profitSell;
      // v3.6.0 HF4: Record ALL closed lots including Grid orders
      double closedLot = g_pairs[pairIndex].lotSellA + g_pairs[pairIndex].lotSellB + 
                         g_pairs[pairIndex].avgTotalLotSell;  // Main + Grid orders
      g_dailyLot += closedLot;
      g_weeklyLot += closedLot;
      g_monthlyLot += closedLot;
      g_allTimeLot += closedLot;
      
      // v3.6.0 HF4: Count ALL closed orders (main pairs + all grid orders)
      int closedOrdersCount = g_pairs[pairIndex].orderCountSell;  // Total orders on this side
      g_dailyClosedOrders += closedOrdersCount;
      g_weeklyClosedOrders += closedOrdersCount;
      g_monthlyClosedOrders += closedOrdersCount;
      g_allTimeClosedOrders += closedOrdersCount;
      
      // v3.2.4: Reset Sell side state (back to Ready for auto-resume)
      g_pairs[pairIndex].ticketSellA = 0;
      g_pairs[pairIndex].ticketSellB = 0;
      g_pairs[pairIndex].directionSell = -1;  // Ready (auto-resume)
      g_pairs[pairIndex].profitSell = 0;
      g_pairs[pairIndex].entryTimeSell = 0;
      g_pairs[pairIndex].orderCountSell = 0;
      g_pairs[pairIndex].lotSellA = 0;
      g_pairs[pairIndex].lotSellB = 0;
      // v3.2.7: Reset averaging
      g_pairs[pairIndex].avgOrderCountSell = 0;
      g_pairs[pairIndex].lastAvgPriceSell = 0;
      g_pairs[pairIndex].entryZScoreSell = 0;
      // v3.6.0: Reset Grid Profit Side
      g_pairs[pairIndex].gridProfitCountSell = 0;
      g_pairs[pairIndex].lastProfitPriceSell = 0;
      g_pairs[pairIndex].initialEntryPriceSell = 0;
      g_pairs[pairIndex].lastProfitGridLotSellA = 0;
      g_pairs[pairIndex].lastProfitGridLotSellB = 0;
      g_pairs[pairIndex].gridProfitZLevelSell = 0;
      // v3.6.0 HF4: Reset total grid lot
      g_pairs[pairIndex].avgTotalLotSell = 0;
      
      // v3.6.0 HF3 Patch 3: Resume orphan detection
      g_orphanCheckPaused = false;
      
      return true;
   }
   
   // v3.6.0 HF3 Patch 3: Resume orphan detection even on failure
   g_orphanCheckPaused = false;
   return false;
}

//+------------------------------------------------------------------+
//| Close All Grid Positions (v3.6.0 - GL, GP, AVG comments)           |
//+------------------------------------------------------------------+
void CloseAveragingPositions(int pairIndex, string side)
{
   string symbolA = g_pairs[pairIndex].symbolA;
   string symbolB = g_pairs[pairIndex].symbolB;
   
   // v1.8.7: Get dynamic pair prefix for new comment format
   string pairPrefix = GetPairCommentPrefix(pairIndex);
   
   // v1.8.8 HF3: Use prefix + suffix pattern to match BOTH old and new formats
   // Old: XU-XE_GL_BUY_20  |  New: XU-XE_GL#1_BUY_20
   string glPrefix = StringFormat("%s_GL", pairPrefix);
   string gpPrefix = StringFormat("%s_GP", pairPrefix);
   string sideSuffix = StringFormat("_%s_%d", side, pairIndex + 1);
   
   // Legacy format comments (backward compatibility)
   string commentGLOld = StringFormat("HrmDream_GL_%s_%d", side, pairIndex + 1);
   string commentGPOld = StringFormat("HrmDream_GP_%s_%d", side, pairIndex + 1);
   string commentAVGOld = StringFormat("HrmDream_AVG_%s_%d", side, pairIndex + 1);
   
   int closeAttempts = 0;
   int maxAttempts = 10;  // Prevent infinite loop
   
   // Keep trying to close until all are closed
   while(closeAttempts < maxAttempts)
   {
      bool foundAny = false;
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(!PositionSelectByTicket(ticket)) continue;
         
         string posSymbol = PositionGetString(POSITION_SYMBOL);
         string posComment = PositionGetString(POSITION_COMMENT);
         
         // v1.8.8 HF3: Match prefix + suffix pattern (supports both old and new #N format)
         bool matchGLNew = StringFind(posComment, glPrefix) >= 0 && StringFind(posComment, sideSuffix) >= 0;
         bool matchGPNew = StringFind(posComment, gpPrefix) >= 0 && StringFind(posComment, sideSuffix) >= 0;
         
         // Match symbol AND any of the grid comments (both new and legacy formats)
         if((posSymbol == symbolA || posSymbol == symbolB) &&
            (matchGLNew || matchGPNew ||
             StringFind(posComment, commentGLOld) >= 0 || 
             StringFind(posComment, commentGPOld) >= 0 ||
             StringFind(posComment, commentAVGOld) >= 0))
         {
            if(g_trade.PositionClose(ticket))
            {
               PrintFormat("Closed Grid position %d on %s", ticket, posSymbol);
            }
            foundAny = true;
         }
      }
      
      if(!foundAny) break;  // No more positions to close
      closeAttempts++;
   }
}

//+------------------------------------------------------------------+
//| Check for Orphan Positions (v3.6.0 HF3 - Skip when EA closing)     |
//+------------------------------------------------------------------+
void CheckOrphanPositions()
{
   // v3.6.0 HF3 Patch 3: Skip orphan check if EA is closing positions
   if(g_orphanCheckPaused) return;
   
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(!g_pairs[i].enabled) continue;
      
      // === Check Buy Side ===
      if(g_pairs[i].directionBuy == 1)
      {
         bool posAExists = VerifyPositionExists(g_pairs[i].ticketBuyA);
         bool posBExists = VerifyPositionExists(g_pairs[i].ticketBuyB);
         
         // If one side is gone but the other exists - Orphan detected!
         if((g_pairs[i].ticketBuyA > 0 && !posAExists) || 
            (g_pairs[i].ticketBuyB > 0 && !posBExists))
         {
            PrintFormat("ORPHAN DETECTED Pair %d BUY: A=%s B=%s - Force closing remaining",
                        i + 1, posAExists ? "OK" : "GONE", posBExists ? "OK" : "GONE");
            ForceCloseBuySide(i);
         }
      }
      
      // === Check Sell Side ===
      if(g_pairs[i].directionSell == 1)
      {
         bool posAExists = VerifyPositionExists(g_pairs[i].ticketSellA);
         bool posBExists = VerifyPositionExists(g_pairs[i].ticketSellB);
         
         if((g_pairs[i].ticketSellA > 0 && !posAExists) || 
            (g_pairs[i].ticketSellB > 0 && !posBExists))
         {
            PrintFormat("ORPHAN DETECTED Pair %d SELL: A=%s B=%s - Force closing remaining",
                        i + 1, posAExists ? "OK" : "GONE", posBExists ? "OK" : "GONE");
            ForceCloseSellSide(i);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Verify Position Exists (v3.3.2)                                    |
//+------------------------------------------------------------------+
bool VerifyPositionExists(ulong ticket)
{
   if(ticket == 0) return true;  // No ticket = no position expected
   return PositionSelectByTicket(ticket);
}

//+------------------------------------------------------------------+
//| Force Close Buy Side (v3.77 - Magic Number + Comment detection)    |
//+------------------------------------------------------------------+
void ForceCloseBuySide(int pairIndex)
{
   string symbolA = g_pairs[pairIndex].symbolA;
   string symbolB = g_pairs[pairIndex].symbolB;
   string mainComment = StringFormat("HrmDream_BUY_%d", pairIndex + 1);
   string avgComment = StringFormat("HrmDream_AVG_BUY_%d", pairIndex + 1);
   string glComment = StringFormat("HrmDream_GL_BUY_%d", pairIndex + 1);
   string gpComment = StringFormat("HrmDream_GP_BUY_%d", pairIndex + 1);
   
   // v3.77: Close ALL positions using Magic Number + Comment match
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      
      string posSymbol = PositionGetString(POSITION_SYMBOL);
      string posComment = PositionGetString(POSITION_COMMENT);
      long magic = PositionGetInteger(POSITION_MAGIC);
      
      // v3.77: Check Magic Number OR comment prefix for backward compatibility
      bool isMagicMatch = (magic == InpMagicNumber);
      bool isCommentMatch = (StringFind(posComment, mainComment) >= 0 || 
                             StringFind(posComment, avgComment) >= 0 ||
                             StringFind(posComment, glComment) >= 0 ||
                             StringFind(posComment, gpComment) >= 0);
      
      // Close if symbol matches AND (Magic OR Comment matches)
      if((posSymbol == symbolA || posSymbol == symbolB) && (isMagicMatch || isCommentMatch))
      {
         // Also verify the position is for BUY side (check comment or position type)
         if(StringFind(posComment, "_BUY_") >= 0 || StringFind(posComment, "GL_BUY") >= 0 || StringFind(posComment, "GP_BUY") >= 0)
         {
            g_trade.PositionClose(ticket);
            PrintFormat("Force closed ticket %d (%s)", ticket, posSymbol);
         }
      }
   }
   
   // v3.2.9: Accumulate closed P/L before reset
   g_pairs[pairIndex].closedProfitBuy += g_pairs[pairIndex].profitBuy;
   
   // v1.1: Add to GROUP instead of global basket
   int groupIdx = GetGroupIndex(pairIndex);
   if(!g_groups[groupIdx].closeMode)
   {
      g_groups[groupIdx].closedProfit += g_pairs[pairIndex].profitBuy;
   }
   
   // Update statistics before reset
   g_dailyProfit += g_pairs[pairIndex].profitBuy;
   g_weeklyProfit += g_pairs[pairIndex].profitBuy;
   g_monthlyProfit += g_pairs[pairIndex].profitBuy;
   g_allTimeProfit += g_pairs[pairIndex].profitBuy;
   // v3.6.0 HF4: Record ALL closed lots including Grid orders
   double closedLot = g_pairs[pairIndex].lotBuyA + g_pairs[pairIndex].lotBuyB + 
                      g_pairs[pairIndex].avgTotalLotBuy;
   g_dailyLot += closedLot;
   g_weeklyLot += closedLot;
   g_monthlyLot += closedLot;
   g_allTimeLot += closedLot;
   
   // v3.6.0 HF4: Count ALL closed orders
   int closedOrdersCount = g_pairs[pairIndex].orderCountBuy;
   g_dailyClosedOrders += closedOrdersCount;
   g_weeklyClosedOrders += closedOrdersCount;
   g_monthlyClosedOrders += closedOrdersCount;
   g_allTimeClosedOrders += closedOrdersCount;
   
   // Reset state
   g_pairs[pairIndex].ticketBuyA = 0;
   g_pairs[pairIndex].ticketBuyB = 0;
   g_pairs[pairIndex].directionBuy = -1;  // Ready
   g_pairs[pairIndex].profitBuy = 0;
   g_pairs[pairIndex].entryTimeBuy = 0;
   g_pairs[pairIndex].orderCountBuy = 0;
   g_pairs[pairIndex].lotBuyA = 0;
   g_pairs[pairIndex].lotBuyB = 0;
   g_pairs[pairIndex].avgOrderCountBuy = 0;
   g_pairs[pairIndex].lastAvgPriceBuy = 0;
   g_pairs[pairIndex].entryZScoreBuy = 0;
   // v3.6.0 HF4: Reset total grid lot
   g_pairs[pairIndex].avgTotalLotBuy = 0;
   
   PrintFormat("Pair %d BUY SIDE FORCE CLOSED (Orphan Recovery)", pairIndex + 1);
}

//+------------------------------------------------------------------+
//| Force Close Sell Side (v3.77 - Magic Number + Comment detection)   |
//+------------------------------------------------------------------+
void ForceCloseSellSide(int pairIndex)
{
   string symbolA = g_pairs[pairIndex].symbolA;
   string symbolB = g_pairs[pairIndex].symbolB;
   string mainComment = StringFormat("HrmDream_SELL_%d", pairIndex + 1);
   string avgComment = StringFormat("HrmDream_AVG_SELL_%d", pairIndex + 1);
   string glComment = StringFormat("HrmDream_GL_SELL_%d", pairIndex + 1);
   string gpComment = StringFormat("HrmDream_GP_SELL_%d", pairIndex + 1);
   
   // v3.77: Close ALL positions using Magic Number + Comment match
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      
      string posSymbol = PositionGetString(POSITION_SYMBOL);
      string posComment = PositionGetString(POSITION_COMMENT);
      long magic = PositionGetInteger(POSITION_MAGIC);
      
      // v3.77: Check Magic Number OR comment prefix for backward compatibility
      bool isMagicMatch = (magic == InpMagicNumber);
      bool isCommentMatch = (StringFind(posComment, mainComment) >= 0 || 
                             StringFind(posComment, avgComment) >= 0 ||
                             StringFind(posComment, glComment) >= 0 ||
                             StringFind(posComment, gpComment) >= 0);
      
      // Close if symbol matches AND (Magic OR Comment matches)
      if((posSymbol == symbolA || posSymbol == symbolB) && (isMagicMatch || isCommentMatch))
      {
         // Also verify the position is for SELL side
         if(StringFind(posComment, "_SELL_") >= 0 || StringFind(posComment, "GL_SELL") >= 0 || StringFind(posComment, "GP_SELL") >= 0)
         {
            g_trade.PositionClose(ticket);
            PrintFormat("Force closed ticket %d (%s)", ticket, posSymbol);
         }
      }
   }
   
   // v3.2.9: Accumulate closed P/L before reset
   g_pairs[pairIndex].closedProfitSell += g_pairs[pairIndex].profitSell;
   
   // v1.1: Add to GROUP instead of global basket
   int groupIdx = GetGroupIndex(pairIndex);
   if(!g_groups[groupIdx].closeMode)
   {
      g_groups[groupIdx].closedProfit += g_pairs[pairIndex].profitSell;
   }
   
   // Update statistics before reset
   g_dailyProfit += g_pairs[pairIndex].profitSell;
   g_weeklyProfit += g_pairs[pairIndex].profitSell;
   g_monthlyProfit += g_pairs[pairIndex].profitSell;
   g_allTimeProfit += g_pairs[pairIndex].profitSell;
   // v3.6.0 HF4: Record ALL closed lots including Grid orders
   double closedLot = g_pairs[pairIndex].lotSellA + g_pairs[pairIndex].lotSellB + 
                      g_pairs[pairIndex].avgTotalLotSell;
   g_dailyLot += closedLot;
   g_weeklyLot += closedLot;
   g_monthlyLot += closedLot;
   g_allTimeLot += closedLot;
   
   // v3.6.0 HF4: Count ALL closed orders
   int closedOrdersCount = g_pairs[pairIndex].orderCountSell;
   g_dailyClosedOrders += closedOrdersCount;
   g_weeklyClosedOrders += closedOrdersCount;
   g_monthlyClosedOrders += closedOrdersCount;
   g_allTimeClosedOrders += closedOrdersCount;
   
   // Reset state
   g_pairs[pairIndex].ticketSellA = 0;
   g_pairs[pairIndex].ticketSellB = 0;
   g_pairs[pairIndex].directionSell = -1;  // Ready
   g_pairs[pairIndex].profitSell = 0;
   g_pairs[pairIndex].entryTimeSell = 0;
   g_pairs[pairIndex].orderCountSell = 0;
   g_pairs[pairIndex].lotSellA = 0;
   g_pairs[pairIndex].lotSellB = 0;
   g_pairs[pairIndex].avgOrderCountSell = 0;
   g_pairs[pairIndex].lastAvgPriceSell = 0;
   g_pairs[pairIndex].entryZScoreSell = 0;
   // v3.6.0 HF4: Reset total grid lot
   g_pairs[pairIndex].avgTotalLotSell = 0;
   
   PrintFormat("Pair %d SELL SIDE FORCE CLOSED (Orphan Recovery)", pairIndex + 1);
}

//+------------------------------------------------------------------+
//| Close All Buy Sides                                                |
//+------------------------------------------------------------------+
void CloseAllBuySides()
{
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(g_pairs[i].directionBuy != 0)
      {
         CloseBuySide(i);
      }
   }
}

//+------------------------------------------------------------------+
//| Close All Sell Sides                                               |
//+------------------------------------------------------------------+
void CloseAllSellSides()
{
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(g_pairs[i].directionSell != 0)
      {
         CloseSellSide(i);
      }
   }
}

//+------------------------------------------------------------------+
//| ================ POSITION MANAGEMENT (v3.2.7) ================     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Manage All Open Positions (v3.2.9 - Force Profit Update)           |
//+------------------------------------------------------------------+
void ManageAllPositions()
{
   // v3.2.9: Force profit update before checking exit conditions
   UpdatePairProfits();
   
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(!g_pairs[i].enabled) continue;
      
      double zScore = g_pairs[i].zScore;
      
      // === Manage Buy Side ===
      if(g_pairs[i].directionBuy == 1)
      {
         bool shouldCloseBuy = false;
         string closeReason = "";
         
         // Check exit conditions based on mode
         if(CheckExitCondition(i, "BUY", zScore))
         {
            shouldCloseBuy = true;
            closeReason = "Exit Condition";
         }
         
         // Check correlation drop
         if(!shouldCloseBuy && MathAbs(g_pairs[i].correlation) < InpMinCorrelation)
         {
            if(InpCorrDropMode == CORR_DROP_CLOSE_ALL)
            {
               shouldCloseBuy = true;
               closeReason = "Correlation Drop";
            }
            else if(InpCorrDropMode == CORR_DROP_CLOSE_PROFIT_ONLY && g_pairs[i].profitBuy > 0)
            {
               shouldCloseBuy = true;
               closeReason = "Corr Drop (Profit)";
            }
         }
         
         if(shouldCloseBuy)
         {
            PrintFormat("Pair %d BUY: Closing - %s | Profit: %.2f", i + 1, closeReason, g_pairs[i].profitBuy);
            CloseBuySide(i);
         }
      }
      
      // === Manage Sell Side ===
      if(g_pairs[i].directionSell == 1)
      {
         bool shouldCloseSell = false;
         string closeReason = "";
         
         // Check exit conditions based on mode
         if(CheckExitCondition(i, "SELL", zScore))
         {
            shouldCloseSell = true;
            closeReason = "Exit Condition";
         }
         
         // Check correlation drop
         if(!shouldCloseSell && MathAbs(g_pairs[i].correlation) < InpMinCorrelation)
         {
            if(InpCorrDropMode == CORR_DROP_CLOSE_ALL)
            {
               shouldCloseSell = true;
               closeReason = "Correlation Drop";
            }
            else if(InpCorrDropMode == CORR_DROP_CLOSE_PROFIT_ONLY && g_pairs[i].profitSell > 0)
            {
               shouldCloseSell = true;
               closeReason = "Corr Drop (Profit)";
            }
         }
         
         if(shouldCloseSell)
         {
            PrintFormat("Pair %d SELL: Closing - %s | Profit: %.2f", i + 1, closeReason, g_pairs[i].profitSell);
            CloseSellSide(i);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check Exit Condition Based on Mode (v3.2.7)                        |
//+------------------------------------------------------------------+
bool CheckExitCondition(int pairIndex, string side, double zScore)
{
   double profit = (side == "BUY") ? g_pairs[pairIndex].profitBuy : g_pairs[pairIndex].profitSell;
   double target = (side == "BUY") ? g_pairs[pairIndex].targetBuy : g_pairs[pairIndex].targetSell;
   
   // Z-Score exit for Buy: Z rises back above -ExitThreshold (toward 0)
   // Z-Score exit for Sell: Z falls back below +ExitThreshold (toward 0)
   bool zScoreExit = false;
   if(side == "BUY")
   {
      zScoreExit = (zScore > -InpExitZScore);
   }
   else
   {
      zScoreExit = (zScore < InpExitZScore);
   }
   
   // Require positive profit for Z-Score exit if enabled
   if(zScoreExit && InpRequirePositiveProfit && profit <= 0)
   {
      zScoreExit = false;
   }
   
   // Profit target exit
   bool profitExit = (target > 0 && profit >= target);
   
   switch(InpExitMode)
   {
      case EXIT_ZSCORE_ONLY:
         return zScoreExit;
         
      case EXIT_PROFIT_ONLY:
         return profitExit;
         
      case EXIT_ZSCORE_OR_PROFIT:
         return zScoreExit || profitExit;
         
      case EXIT_ZSCORE_AND_PROFIT:
         return zScoreExit && profitExit;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Update Pair Profits (v1.3 - with Auto-Recovery + Log Throttling)   |
//+------------------------------------------------------------------+
void UpdatePairProfits()
{
   g_totalCurrentProfit = 0;
   
   // v1.3: Check if we should log profits this tick (throttling)
   bool shouldLogProfit = false;
   if(InpDebugMode)
   {
      datetime currentTime = TimeCurrent();
      if(currentTime - g_lastProfitLogTime >= PROFIT_LOG_INTERVAL)
      {
         shouldLogProfit = true;
         g_lastProfitLogTime = currentTime;
      }
   }
   
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(!g_pairs[i].enabled) continue;
      
      double buyProfit = 0;
      double sellProfit = 0;
      
      // Calculate Buy side profit
      if(g_pairs[i].directionBuy == 1)
      {
         // v1.8.7: Get dynamic pair prefix for new comment format
         string pairPrefix = GetPairCommentPrefix(i);
         
         // v1.8.7: Auto-recover missing tickets with NEW comment format
         if(g_pairs[i].ticketBuyA == 0 || g_pairs[i].ticketBuyB == 0)
         {
            PrintFormat("[v1.8.7 WARN] Pair %d BUY: Missing ticket! A=%d B=%d - Attempting recovery...", 
                        i + 1, g_pairs[i].ticketBuyA, g_pairs[i].ticketBuyB);
            string buyComment = StringFormat("%s_BUY_%d", pairPrefix, i + 1);
            RecoverMissingTickets(i, "BUY", buyComment);
         }
         
         double profitA = GetPositionProfit(g_pairs[i].ticketBuyA);
         double profitB = GetPositionProfit(g_pairs[i].ticketBuyB);
         buyProfit = profitA + profitB;
         
         // v1.3: Debug log with throttling (only every 5 seconds)
         if(shouldLogProfit)
         {
            PrintFormat("[v1.3 PROFIT] Pair %d BUY: TicketA=%d (%.2f) + TicketB=%d (%.2f) = %.2f", 
                        i + 1, g_pairs[i].ticketBuyA, profitA,
                        g_pairs[i].ticketBuyB, profitB, buyProfit);
         }
         
         // v1.8.8 HF2: Use flexible pattern that matches both old and new format
         // Old: XU-XE_GL_BUY_20  |  New: XU-XE_GL#1_BUY_20
         // Strategy: Search for prefix AND side suffix separately
         string glPrefix = StringFormat("%s_GL", pairPrefix);
         string gpPrefix = StringFormat("%s_GP", pairPrefix);
         string buySuffix = StringFormat("_BUY_%d", i + 1);
         
         buyProfit += GetAveragingProfitWithSuffix(glPrefix, buySuffix);
         buyProfit += GetAveragingProfitWithSuffix(gpPrefix, buySuffix);
         
         // Legacy support: Also check old HrmDream_ format for backward compatibility
         string legacyAVGBuy = StringFormat("HrmDream_AVG_BUY_%d", i + 1);
         string legacyGLBuy = StringFormat("HrmDream_GL_BUY_%d", i + 1);
         string legacyGPBuy = StringFormat("HrmDream_GP_BUY_%d", i + 1);
         buyProfit += GetAveragingProfit(legacyAVGBuy);
         buyProfit += GetAveragingProfit(legacyGLBuy);
         buyProfit += GetAveragingProfit(legacyGPBuy);
      }
      
      // Calculate Sell side profit
      if(g_pairs[i].directionSell == 1)
      {
         // v1.8.7: Get dynamic pair prefix for new comment format
         string pairPrefix = GetPairCommentPrefix(i);
         
         // v1.8.7: Auto-recover missing tickets with NEW comment format
         if(g_pairs[i].ticketSellA == 0 || g_pairs[i].ticketSellB == 0)
         {
            PrintFormat("[v1.8.7 WARN] Pair %d SELL: Missing ticket! A=%d B=%d - Attempting recovery...", 
                        i + 1, g_pairs[i].ticketSellA, g_pairs[i].ticketSellB);
            string sellComment = StringFormat("%s_SELL_%d", pairPrefix, i + 1);
            RecoverMissingTickets(i, "SELL", sellComment);
         }
         
         double profitA = GetPositionProfit(g_pairs[i].ticketSellA);
         double profitB = GetPositionProfit(g_pairs[i].ticketSellB);
         sellProfit = profitA + profitB;
         
         // v1.3: Debug log with throttling (only every 5 seconds)
         if(shouldLogProfit)
         {
            PrintFormat("[v1.3 PROFIT] Pair %d SELL: TicketA=%d (%.2f) + TicketB=%d (%.2f) = %.2f", 
                        i + 1, g_pairs[i].ticketSellA, profitA,
                        g_pairs[i].ticketSellB, profitB, sellProfit);
         }
         
         // v1.8.8 HF2: Use flexible pattern that matches both old and new format
         // Old: XU-XE_GL_SELL_20  |  New: XU-XE_GL#1_SELL_20
         // Strategy: Search for prefix AND side suffix separately
         string glPrefix = StringFormat("%s_GL", pairPrefix);
         string gpPrefix = StringFormat("%s_GP", pairPrefix);
         string sellSuffix = StringFormat("_SELL_%d", i + 1);
         
         sellProfit += GetAveragingProfitWithSuffix(glPrefix, sellSuffix);
         sellProfit += GetAveragingProfitWithSuffix(gpPrefix, sellSuffix);
         
         // Legacy support: Also check old HrmDream_ format for backward compatibility
         string legacyAVGSell = StringFormat("HrmDream_AVG_SELL_%d", i + 1);
         string legacyGLSell = StringFormat("HrmDream_GL_SELL_%d", i + 1);
         string legacyGPSell = StringFormat("HrmDream_GP_SELL_%d", i + 1);
         sellProfit += GetAveragingProfit(legacyAVGSell);
         sellProfit += GetAveragingProfit(legacyGLSell);
         sellProfit += GetAveragingProfit(legacyGPSell);
      }
      
      g_pairs[i].profitBuy = buyProfit;
      g_pairs[i].profitSell = sellProfit;
      g_pairs[i].totalPairProfit = buyProfit + sellProfit;
      
      g_totalCurrentProfit += g_pairs[i].totalPairProfit;
   }
}

//+------------------------------------------------------------------+
//| v1.8.8 HF2: Get profit from positions matching prefix AND suffix  |
//| Matches both old format (GL_BUY) and new format (GL#1_BUY)        |
//+------------------------------------------------------------------+
double GetAveragingProfitWithSuffix(string prefix, string suffix)
{
   double totalProfit = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         string comment = PositionGetString(POSITION_COMMENT);
         
         // Check if comment contains BOTH prefix AND suffix
         if(StringFind(comment, prefix) >= 0 && StringFind(comment, suffix) >= 0)
         {
            // v1.4: Include Commission for Net Profit
            totalProfit += PositionGetDouble(POSITION_PROFIT) + 
                           PositionGetDouble(POSITION_SWAP) + 
                           PositionGetDouble(POSITION_COMMISSION);
         }
      }
   }
   
   return totalProfit;
}

//+------------------------------------------------------------------+
//| v1.4: Get Position NET Profit (Profit + Swap + Commission)         |
//+------------------------------------------------------------------+
double GetPositionProfit(ulong ticket)
{
   if(ticket == 0) return 0;
   
   if(PositionSelectByTicket(ticket))
   {
      // v1.4: Include Commission for Net Profit
      return PositionGetDouble(POSITION_PROFIT) + 
             PositionGetDouble(POSITION_SWAP) + 
             PositionGetDouble(POSITION_COMMISSION);
   }
   
   return 0;
}

//+------------------------------------------------------------------+
//| v1.4: Get Averaging Positions NET Profit (incl Commission)         |
//+------------------------------------------------------------------+
double GetAveragingProfit(string commentPattern)
{
   double totalProfit = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(StringFind(PositionGetString(POSITION_COMMENT), commentPattern) >= 0)
         {
            // v1.4: Include Commission for Net Profit
            totalProfit += PositionGetDouble(POSITION_PROFIT) + 
                           PositionGetDouble(POSITION_SWAP) + 
                           PositionGetDouble(POSITION_COMMISSION);
         }
      }
   }
   
   return totalProfit;
}

//+------------------------------------------------------------------+
//| Check Pair Targets (v1.6.6: Real-Time Scaled Targets)              |
//+------------------------------------------------------------------+
void CheckPairTargets()
{
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(!g_pairs[i].enabled) continue;
      
      // v1.6.6: Get group index and real-time scaled targets
      int groupIdx = GetGroupIndex(i);
      double scaledTargetBuy = GetRealTimeScaledTargetBuy(groupIdx);
      double scaledTargetSell = GetRealTimeScaledTargetSell(groupIdx);
      
      // Check Buy side target (using real-time scaled value)
      if(g_pairs[i].directionBuy == 1 && scaledTargetBuy > 0)
      {
         if(g_pairs[i].profitBuy >= scaledTargetBuy)
         {
            PrintFormat("Pair %d BUY TARGET HIT: %.2f >= %.2f (Scaled)", 
                        i + 1, g_pairs[i].profitBuy, scaledTargetBuy);
            CloseBuySide(i);
         }
      }
      
      // Check Sell side target (using real-time scaled value)
      if(g_pairs[i].directionSell == 1 && scaledTargetSell > 0)
      {
         if(g_pairs[i].profitSell >= scaledTargetSell)
         {
            PrintFormat("Pair %d SELL TARGET HIT: %.2f >= %.2f (Scaled)", 
                        i + 1, g_pairs[i].profitSell, scaledTargetSell);
            CloseSellSide(i);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check Group Profit Targets (v1.1 - Group-based)                    |
//+------------------------------------------------------------------+
void CheckTotalTarget()
{
   // v1.1: Calculate floating profit per group and check targets
   g_basketClosedProfit = 0;
   g_basketFloatingProfit = 0;
   
   for(int g = 0; g < MAX_GROUPS; g++)
   {
      // 1. Calculate floating profit for this group
      g_groups[g].floatingProfit = 0;
      int startPair = g * PAIRS_PER_GROUP;
      int endPair = startPair + PAIRS_PER_GROUP;
      
      for(int i = startPair; i < endPair && i < MAX_PAIRS; i++)
      {
         if(g_pairs[i].enabled)
         {
            g_groups[g].floatingProfit += g_pairs[i].profitBuy + g_pairs[i].profitSell;
         }
      }
      
      g_groups[g].totalProfit = g_groups[g].closedProfit + g_groups[g].floatingProfit;
      
      // Accumulate to legacy global variables for stats display
      g_basketClosedProfit += g_groups[g].closedProfit;
      g_basketFloatingProfit += g_groups[g].floatingProfit;
   }
   
   // v1.8.7 HF2: Include accumulated profit from already-closed groups
   g_basketTotalProfit = g_accumulatedBasketProfit + g_basketClosedProfit + g_basketFloatingProfit;
   
   // === v1.8.7: Check Total Basket Target (ALL GROUPS) ===
   if(InpEnableTotalBasket && InpTotalBasketTarget > 0)
   {
      if(g_basketTotalProfit >= InpTotalBasketTarget)
      {
         PrintFormat(">>> TOTAL BASKET TARGET REACHED: $%.2f >= $%.2f <<<", 
                     g_basketTotalProfit, InpTotalBasketTarget);
         PrintFormat(">>> Closing ALL Groups... <<<");
         
         g_orphanCheckPaused = true;
         
         // Close all groups
         for(int grp = 0; grp < MAX_GROUPS; grp++)
         {
            g_groups[grp].closeMode = true;
            
            int startPairG = grp * PAIRS_PER_GROUP;
            int endPairG = startPairG + PAIRS_PER_GROUP;
            
            for(int pi = startPairG; pi < endPairG && pi < MAX_PAIRS; pi++)
            {
               if(g_pairs[pi].directionBuy == 1)
                  CloseBuySide(pi);
               if(g_pairs[pi].directionSell == 1)
                  CloseSellSide(pi);
            }
            
            g_groups[grp].closeMode = false;
            ResetGroupProfit(grp);
         }
         
         // v1.8.7 HF2: Reset accumulated basket after closing all groups
         g_accumulatedBasketProfit = 0;
         PrintFormat(">>> TOTAL BASKET RESET: Accumulated = 0 <<<");
         
         g_orphanCheckPaused = false;
         PrintFormat(">>> TOTAL BASKET CLOSE COMPLETE <<<");
         return;  // Skip per-group checks after total basket close
      }
   }
   
   // 2. Check each group's target independently
   for(int g = 0; g < MAX_GROUPS; g++)
   {
      // v1.6.6: Get real-time scaled targets for this group
      double scaledClosedTarget = GetRealTimeScaledClosedTarget(g);
      double scaledFloatingTarget = GetRealTimeScaledFloatingTarget(g);
      
      // Skip if no targets set
      if(scaledClosedTarget <= 0 && scaledFloatingTarget <= 0)
         continue;
      
      bool shouldClose = false;
      string reason = "";
      
      // Check TOTAL target (Closed + Floating) using real-time scaled value
      if(scaledClosedTarget > 0 && 
         g_groups[g].totalProfit >= scaledClosedTarget)
      {
         shouldClose = true;
         reason = StringFormat("Total %.2f >= Target %.2f (Scaled)", 
                               g_groups[g].totalProfit, scaledClosedTarget);
      }
      
      // Check Floating-only target using real-time scaled value
      if(!shouldClose && scaledFloatingTarget > 0 && 
         g_groups[g].floatingProfit >= scaledFloatingTarget)
      {
         shouldClose = true;
         reason = StringFormat("Floating %.2f >= Target %.2f (Scaled)", 
                               g_groups[g].floatingProfit, scaledFloatingTarget);
      }
      
      // Execute close for THIS GROUP ONLY
      if(shouldClose && !g_groups[g].targetTriggered)
      {
         g_groups[g].targetTriggered = true;
         g_groups[g].closeMode = true;
         g_orphanCheckPaused = true;
         
         PrintFormat(">>> GROUP %d TARGET REACHED: %s <<<", g + 1, reason);
         PrintFormat(">>> Closing Group %d positions (Pairs %d-%d)... <<<", 
                     g + 1, g * PAIRS_PER_GROUP + 1, (g + 1) * PAIRS_PER_GROUP);
         
         // Close only pairs in THIS group
         int startPair = g * PAIRS_PER_GROUP;
         int endPair = startPair + PAIRS_PER_GROUP;
         
         for(int i = startPair; i < endPair && i < MAX_PAIRS; i++)
         {
            if(g_pairs[i].directionBuy == 1)
            {
               PrintFormat(">>> GROUP %d: Closing Pair %d BUY (Floating: %.2f)", 
                           g + 1, i + 1, g_pairs[i].profitBuy);
               CloseBuySide(i);
            }
            if(g_pairs[i].directionSell == 1)
            {
               PrintFormat(">>> GROUP %d: Closing Pair %d SELL (Floating: %.2f)", 
                           g + 1, i + 1, g_pairs[i].profitSell);
               CloseSellSide(i);
            }
         }
         
         g_groups[g].closeMode = false;
         g_orphanCheckPaused = false;
         
         // v1.8.7 HF2: Accumulate this group's closed profit to basket BEFORE reset
         double groupRealizedProfit = g_groups[g].closedProfit + g_groups[g].floatingProfit;
         g_accumulatedBasketProfit += groupRealizedProfit;
         
         PrintFormat(">>> GROUP %d REALIZED: $%.2f | Accumulated Basket: $%.2f <<<",
                     g + 1, groupRealizedProfit, g_accumulatedBasketProfit);
         PrintFormat(">>> GROUP %d RESET: Previous Closed %.2f | New: 0.00 <<<",
                     g + 1, g_groups[g].closedProfit);
         ResetGroupProfit(g);
         PrintFormat(">>> GROUP %d: Ready for new cycle <<<", g + 1);
      }
   }
}

//+------------------------------------------------------------------+
//| v1.8.7: Close Group Orders (Manual Close Group button)             |
//+------------------------------------------------------------------+
void CloseGroupOrders(int groupIdx)
{
   g_orphanCheckPaused = true;
   g_groups[groupIdx].closeMode = true;
   
   int startPair = groupIdx * PAIRS_PER_GROUP;
   int endPair = startPair + PAIRS_PER_GROUP;
   
   PrintFormat(">>> MANUAL CLOSE: Group %d (Pairs %d-%d) <<<", 
               groupIdx + 1, startPair + 1, endPair);
   
   for(int i = startPair; i < endPair && i < MAX_PAIRS; i++)
   {
      if(g_pairs[i].directionBuy == 1)
      {
         PrintFormat(">>> GROUP %d: Closing Pair %d BUY (Floating: %.2f)", 
                     groupIdx + 1, i + 1, g_pairs[i].profitBuy);
         CloseBuySide(i);
      }
      if(g_pairs[i].directionSell == 1)
      {
         PrintFormat(">>> GROUP %d: Closing Pair %d SELL (Floating: %.2f)", 
                     groupIdx + 1, i + 1, g_pairs[i].profitSell);
         CloseSellSide(i);
      }
   }
   
   g_groups[groupIdx].closeMode = false;
   g_orphanCheckPaused = false;
   
   // v1.8.7 HF2: Accumulate this group's profit before reset
   double groupRealizedProfit = g_groups[groupIdx].closedProfit + g_groups[groupIdx].floatingProfit;
   g_accumulatedBasketProfit += groupRealizedProfit;
   PrintFormat(">>> GROUP %d MANUAL CLOSE: Realized $%.2f | Accumulated: $%.2f <<<",
               groupIdx + 1, groupRealizedProfit, g_accumulatedBasketProfit);
   
   // Reset group's profit after manual close
   ResetGroupProfit(groupIdx);
   PrintFormat(">>> GROUP %d MANUAL CLOSE COMPLETE <<<", groupIdx + 1);
}

//+------------------------------------------------------------------+
//| Update Account Statistics (v3.3.0 - with Closed Orders Reset)      |
//+------------------------------------------------------------------+
void UpdateAccountStats()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity > g_maxEquity) g_maxEquity = equity;
   
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   MqlDateTime dtStart;
   TimeToStruct(g_dayStart, dtStart);
   if(dt.day != dtStart.day)
   {
      g_dailyProfit = 0;
      g_dailyLot = 0;
      g_dailyClosedOrders = 0;  // v3.3.0: Reset daily closed orders
      g_dayStart = TimeCurrent();
   }
   
   TimeToStruct(g_weekStart, dtStart);
   if(dt.day_of_week < dtStart.day_of_week || dt.day - dtStart.day >= 7)
   {
      g_weeklyProfit = 0;
      g_weeklyLot = 0;
      g_weeklyClosedOrders = 0;  // v3.3.0: Reset weekly closed orders
      g_weekStart = TimeCurrent();
   }
   
   TimeToStruct(g_monthStart, dtStart);
   if(dt.mon != dtStart.mon)
   {
      g_monthlyProfit = 0;
      g_monthlyLot = 0;
      g_monthlyClosedOrders = 0;  // v3.3.0: Reset monthly closed orders
      g_monthStart = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| ================ RISK MANAGEMENT (v3.2.7) ================         |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check Risk Limits (v3.2.7 - DD=0 Disable)                          |
//+------------------------------------------------------------------+
void CheckRiskLimits()
{
   // v3.2.7: If Emergency DD = 0, disable this feature
   if(InpEmergencyCloseDD <= 0) return;
   
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   if(balance <= 0) return;
   if(g_maxEquity <= 0) return;
   
   double drawdown = ((g_maxEquity - equity) / g_maxEquity) * 100;
   
   // Safeguard against negative drawdown
   if(drawdown < 0) drawdown = 0;
   
   if(drawdown > g_maxDrawdownPercent) g_maxDrawdownPercent = drawdown;
   
   if(drawdown >= InpEmergencyCloseDD)
   {
      PrintFormat("EMERGENCY: Drawdown %.2f%% exceeded limit %.2f%% - Closing ALL", 
                  drawdown, InpEmergencyCloseDD);
      CloseAllBuySides();
      CloseAllSellSides();
      
      // v3.2.7: Set pause with reason
      g_isPaused = true;
      g_pauseReason = "DD_LIMIT";
      g_equityAtDDClose = equity;
      
      PrintFormat("Trading PAUSED due to DD limit. Will auto-resume when equity recovers to %.2f%%",
                  InpResumeEquityPercent);
      return;
   }
}

//+------------------------------------------------------------------+
//| ================ DASHBOARD PANEL (v3.3.0) ================         |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Create Dashboard (v3.3.0 - with Closed Orders)                     |
//+------------------------------------------------------------------+
void CreateDashboard()
{
   string prefix = "STAT_";
   ObjectsDeleteAll(0, prefix);
   
   // Main background
   CreateRectangle(prefix + "BG_MAIN", PANEL_X, PANEL_Y, PANEL_WIDTH, PANEL_HEIGHT, COLOR_BG_DARK, COLOR_BG_DARK);
   
   // v3.7.3: Add EA Title Row with centered title + EA Status + Pause button
   int titleHeight = 22;
   CreateRectangle(prefix + "TITLE_BG", PANEL_X, PANEL_Y, PANEL_WIDTH, titleHeight, COLOR_TITLE_BG, COLOR_TITLE_BG);
   
   // v3.7.3: Center the title using manual centering approach
   ObjectCreate(0, prefix + "TITLE_NAME", OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, prefix + "TITLE_NAME", OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, prefix + "TITLE_NAME", OBJPROP_XDISTANCE, PANEL_X + (PANEL_WIDTH / 2));
   ObjectSetInteger(0, prefix + "TITLE_NAME", OBJPROP_YDISTANCE, PANEL_Y + 4);
   ObjectSetInteger(0, prefix + "TITLE_NAME", OBJPROP_ANCHOR, ANCHOR_UPPER);
   ObjectSetString(0, prefix + "TITLE_NAME", OBJPROP_TEXT, "Moneyx Harmony Dream v1.8.8");
   ObjectSetString(0, prefix + "TITLE_NAME", OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, prefix + "TITLE_NAME", OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, prefix + "TITLE_NAME", OBJPROP_COLOR, COLOR_GOLD);
   ObjectSetInteger(0, prefix + "TITLE_NAME", OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, prefix + "TITLE_NAME", OBJPROP_HIDDEN, true);
   
   // v3.76: Last Sync Display (new - left side of title bar)
   CreateLabel(prefix + "SYNC_LBL", PANEL_X + 10, PANEL_Y + 5, "Sync:", COLOR_TEXT_WHITE, 8, "Arial");
   CreateLabel(prefix + "SYNC_VAL", PANEL_X + 45, PANEL_Y + 4, "Pending", clrYellow, 9, "Arial Bold");
   CreateLabel(prefix + "SYNC_AGO", PANEL_X + 100, PANEL_Y + 5, "", clrGray, 8, "Arial");
   
   // v1.6.7: Z-Score Update Display (shows mode and when Z-Score was last updated)
   string zModeLbl = (InpZScoreBarMode == ZSCORE_BAR_CURRENT) 
                     ? StringFormat("Z(%dm):", InpZScoreCurrentUpdateMins)
                     : "Z(Close):";
   CreateLabel(prefix + "ZSCORE_LBL", PANEL_X + 160, PANEL_Y + 5, zModeLbl, COLOR_TEXT_WHITE, 8, "Arial");
   CreateLabel(prefix + "ZSCORE_AGO", PANEL_X + 210, PANEL_Y + 4, "Pending", clrYellow, 9, "Arial Bold");
   
   // v3.7.4: EA Status Display (adjusted position - moved left by 50px)
   CreateLabel(prefix + "EA_STATUS_LBL", PANEL_X + PANEL_WIDTH - 210, PANEL_Y + 5, "Status:", COLOR_TEXT_WHITE, 8, "Arial");
   CreateLabel(prefix + "EA_STATUS_VAL", PANEL_X + PANEL_WIDTH - 165, PANEL_Y + 4, "Working", clrLime, 9, "Arial Bold");
   
   // v3.7.4: Global Pause/Start Button (adjusted position - moved left by 50px)
   string pauseBtnText = g_isPaused ? "Start" : "Pause";
   color pauseBtnColor = g_isPaused ? clrGreen : clrOrangeRed;
   CreateButton(prefix + "_BTN_PAUSE", PANEL_X + PANEL_WIDTH - 108, PANEL_Y + 2, 50, 18, pauseBtnText, pauseBtnColor, clrWhite);
   
   // v3.2.9 Hotfix: Increased header height and spacing to prevent overlap
   int buyWidth = 395;
   int centerWidth = 390;
   int sellWidth = 395;
   int headerHeight = 30;  // Main header height (increased)
   int colHeaderHeight = 20;  // Dedicated space for column headers with background (increased)
   int headerY = PANEL_Y + titleHeight;  // Shifted down by title
   int colHeaderY = headerY + headerHeight + 4;  // Column headers BELOW main headers with more gap
   int rowStartY = colHeaderY + colHeaderHeight + 4;  // Data rows start after column headers
   
   int buyStartX = PANEL_X + 10;
   int centerX = buyStartX + buyWidth + 5;
   int sellStartX = centerX + centerWidth + 5;
   
   // v2.1.2: Mini Group Column (EXPANDED)
   int miniGroupWidth = 110;  // Increased from 90 to 110
   int miniGroupX = sellStartX + sellWidth + 5;
   
   // v2.0: Group Info Column (shifted right)
   int groupInfoWidth = 125;
   int groupInfoX = miniGroupX + miniGroupWidth + 5;
   
   // ===== MAIN SECTION HEADERS =====
   // Buy Header - text centered vertically
   CreateRectangle(prefix + "HDR_BUY", buyStartX, headerY + 3, buyWidth, headerHeight, COLOR_HEADER_BUY, COLOR_HEADER_BUY);
   CreateLabel(prefix + "HDR_BUY_TXT", buyStartX + 165, headerY + 8, "BUY DATA", COLOR_HEADER_TXT, 10, "Arial Bold");
   
   // Center Header  
   CreateRectangle(prefix + "HDR_CENTER", centerX, headerY + 3, centerWidth, headerHeight, COLOR_HEADER_MAIN, COLOR_HEADER_MAIN);
   CreateLabel(prefix + "HDR_CENTER_TXT", centerX + 145, headerY + 8, "TRADING PAIRS", COLOR_HEADER_TXT, 10, "Arial Bold");
   
   // Sell Header
   CreateRectangle(prefix + "HDR_SELL", sellStartX, headerY + 3, sellWidth, headerHeight, COLOR_HEADER_SELL, COLOR_HEADER_SELL);
   CreateLabel(prefix + "HDR_SELL_TXT", sellStartX + 165, headerY + 8, "SELL DATA", COLOR_HEADER_TXT, 10, "Arial Bold");
   
   // v2.1.2: Mini Group Header (distinct blue color)
   CreateRectangle(prefix + "HDR_MINI", miniGroupX, headerY + 3, miniGroupWidth, headerHeight, COLOR_HEADER_MINI, COLOR_HEADER_MINI);
   CreateLabel(prefix + "HDR_MINI_TXT", miniGroupX + 15, headerY + 8, "MINI GROUP", COLOR_HEADER_TXT, 9, "Arial Bold");
   
   // v2.0: Group Info Header (shifted right)
   CreateRectangle(prefix + "HDR_GROUP", groupInfoX, headerY + 3, groupInfoWidth, headerHeight, COLOR_HEADER_GROUP, COLOR_HEADER_GROUP);
   CreateLabel(prefix + "HDR_GROUP_TXT", groupInfoX + 15, headerY + 8, "GROUP INFO", COLOR_HEADER_TXT, 10, "Arial Bold");
   
   // ===== COLUMN HEADER BACKGROUNDS (v1.8.5: Theme-based colors) =====
   CreateRectangle(prefix + "COLHDR_BUY_BG", buyStartX, colHeaderY - 1, buyWidth, colHeaderHeight, COLOR_COLHDR_BUY, COLOR_COLHDR_BUY);
   CreateRectangle(prefix + "COLHDR_CENTER_BG", centerX, colHeaderY - 1, centerWidth, colHeaderHeight, COLOR_COLHDR_CENTER, COLOR_COLHDR_CENTER);
   CreateRectangle(prefix + "COLHDR_SELL_BG", sellStartX, colHeaderY - 1, sellWidth, colHeaderHeight, COLOR_COLHDR_SELL, COLOR_COLHDR_SELL);
   // v2.1.2: Mini Group Column Header Background (distinct blue)
   CreateRectangle(prefix + "COLHDR_MINI_BG", miniGroupX, colHeaderY - 1, miniGroupWidth, colHeaderHeight, COLOR_COLHDR_MINI, COLOR_COLHDR_MINI);
   // v2.0: Group Info Column Header Background (shifted right)
   CreateRectangle(prefix + "COLHDR_GROUP_BG", groupInfoX, colHeaderY - 1, groupInfoWidth, colHeaderHeight, COLOR_COLHDR_GROUP, COLOR_COLHDR_GROUP);
   
   // ===== COLUMN HEADERS (v3.2.9: Labels on top of backgrounds) =====
   int colLabelY = colHeaderY + 2;  // Center text vertically in column header row
   
   // Buy columns: X | Closed | Lot | Ord | Tot | Target | Status | Z | P/L
   CreateLabel(prefix + "COL_B_X", buyStartX + 5, colLabelY, "X", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_B_PF", buyStartX + 25, colLabelY, "Closed", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_B_LT", buyStartX + 75, colLabelY, "Lot", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_B_OR", buyStartX + 128, colLabelY, "Ord", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_B_MX", buyStartX + 165, colLabelY, "Tot", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_B_TG", buyStartX + 205, colLabelY, "Target", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_B_ST", buyStartX + 260, colLabelY, "Status", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_B_Z", buyStartX + 310, colLabelY, "Z", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_B_PL", buyStartX + 358, colLabelY, "P/L", COLOR_HEADER_TXT, 7, "Arial");
   
   // Center columns: Pair | Trend | C-% | Type | Total P/L
   CreateLabel(prefix + "COL_C_PR", centerX + 10, colLabelY, "#.Pair", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_C_TRD", centerX + 155, colLabelY, "Trend", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_C_CR", centerX + 215, colLabelY, "C-%", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_C_TY", centerX + 265, colLabelY, "Type", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_C_TP", centerX + 330, colLabelY, "Tot P/L", COLOR_HEADER_TXT, 7, "Arial");
   
   // Sell columns: P/L | Z | Status | Target | Tot | Ord | Lot | Closed | X
   CreateLabel(prefix + "COL_S_PL", sellStartX + 5, colLabelY, "P/L", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_S_Z", sellStartX + 50, colLabelY, "Z", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_S_ST", sellStartX + 105, colLabelY, "Status", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_S_TG", sellStartX + 155, colLabelY, "Target", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_S_MX", sellStartX + 210, colLabelY, "Tot", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_S_OR", sellStartX + 262, colLabelY, "Ord", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_S_LT", sellStartX + 305, colLabelY, "Lot", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_S_PF", sellStartX + 340, colLabelY, "Closed", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_S_X", sellStartX + 378, colLabelY, "X", COLOR_HEADER_TXT, 7, "Arial");
   
   // v2.1.2: Mini Group columns: # | Float | Closed (adjusted positions for wider column)
   CreateLabel(prefix + "COL_M_HDR", miniGroupX + 5, colLabelY, "#", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_M_FLT", miniGroupX + 30, colLabelY, "Float", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_M_CL", miniGroupX + 70, colLabelY, "Closed", COLOR_HEADER_TXT, 7, "Arial");
   
   // v2.0: Group Info columns (Grp | Float | Closed | Tgt | M.Tgt)
   CreateLabel(prefix + "COL_G_GRP", groupInfoX + 5, colLabelY, "Grp", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_G_FLT", groupInfoX + 35, colLabelY, "Float", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_G_CL", groupInfoX + 75, colLabelY, "Closed", COLOR_HEADER_TXT, 7, "Arial");
   
   // ===== PAIR ROWS =====
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      int rowY = rowStartY + i * ROW_HEIGHT;
      color rowBg = (i % 2 == 0) ? COLOR_BG_ROW_EVEN : COLOR_BG_ROW_ODD;
      
      // Row backgrounds
      CreateRectangle(prefix + "ROW_B_" + IntegerToString(i), buyStartX, rowY, buyWidth, ROW_HEIGHT - 1, rowBg, rowBg);
      CreateRectangle(prefix + "ROW_C_" + IntegerToString(i), centerX, rowY, centerWidth, ROW_HEIGHT - 1, rowBg, rowBg);
      CreateRectangle(prefix + "ROW_S_" + IntegerToString(i), sellStartX, rowY, sellWidth, ROW_HEIGHT - 1, rowBg, rowBg);
      
      // v2.1.2: Mini Group row background (distinct blue - every 2 pairs)
      if(i % PAIRS_PER_MINI == 0)
      {
         int miniRowHeight = PAIRS_PER_MINI * ROW_HEIGHT - 1;
         CreateRectangle(prefix + "ROW_M_" + IntegerToString(i / PAIRS_PER_MINI), miniGroupX, rowY, miniGroupWidth, miniRowHeight, COLOR_MINI_BG, COLOR_MINI_BORDER);
      }
      
      // v2.0: Group Info row background (every 6 pairs)
      if(i % PAIRS_PER_GROUP == 0)
      {
         int groupRowHeight = PAIRS_PER_GROUP * ROW_HEIGHT - 1;
         color grpBg = C'35,25,45';
         CreateRectangle(prefix + "ROW_G_" + IntegerToString(i / PAIRS_PER_GROUP), groupInfoX, rowY, groupInfoWidth, groupRowHeight, grpBg, C'60,40,80');
      }
      
      // Create pair row content (v2.0: Pass miniGroupX and groupInfoX)
      CreatePairRow(prefix, i, buyStartX, centerX, sellStartX, rowY, miniGroupX, groupInfoX);
   }
   
   // ===== ACCOUNT SUMMARY SECTION =====
   int summaryY = rowStartY + MAX_PAIRS * ROW_HEIGHT + 5;
   CreateAccountSummary(prefix, summaryY);
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Create Pair Row (v2.0 - with Mini Group Column)                    |
//+------------------------------------------------------------------+
void CreatePairRow(string prefix, int idx, int buyX, int centerX, int sellX, int y, int miniGroupX, int groupInfoX)
{
   string idxStr = IntegerToString(idx);
   string pairNum = IntegerToString(idx + 1);
   string pairName = pairNum + ". " + g_pairs[idx].symbolA + "-" + g_pairs[idx].symbolB;
   
   int groupIdx = idx / PAIRS_PER_GROUP;
   
   // === BUY SIDE DATA ===
   CreateButton(prefix + "_CLOSE_BUY_" + idxStr, buyX + 5, y + 2, 16, 14, "X", clrRed, clrWhite);
   CreateLabel(prefix + "P" + idxStr + "_B_CLOSED", buyX + 25, y + 3, "0", COLOR_TEXT, FONT_SIZE, "Arial");
   CreateLabel(prefix + "P" + idxStr + "_B_LOT", buyX + 75, y + 3, "0.00", COLOR_TEXT, FONT_SIZE, "Arial");
   CreateLabel(prefix + "P" + idxStr + "_B_ORD", buyX + 128, y + 3, "0", COLOR_TEXT, FONT_SIZE, "Arial");
   CreateEditField(prefix + "_MAX_BUY_" + idxStr, buyX + 160, y + 2, 30, 14, IntegerToString(g_groups[groupIdx].maxOrderBuy));
   CreateEditField(prefix + "_TGT_BUY_" + idxStr, buyX + 200, y + 2, 45, 14, DoubleToString(g_groups[groupIdx].targetBuy, 0));
   
   string buyStatusText = g_pairs[idx].enabled ? "Off" : "-";
   color buyStatusColor = COLOR_OFF;
   CreateButton(prefix + "_ST_BUY_" + idxStr, buyX + 255, y + 2, 40, 14, buyStatusText, buyStatusColor, clrWhite);
   CreateLabel(prefix + "P" + idxStr + "_B_Z", buyX + 310, y + 3, "0.00", COLOR_TEXT, FONT_SIZE, "Arial");
   CreateLabel(prefix + "P" + idxStr + "_B_PL", buyX + 358, y + 3, "0", COLOR_TEXT, FONT_SIZE, "Arial");
   
   // === CENTER DATA ===
   CreateLabel(prefix + "P" + idxStr + "_NAME", centerX + 10, y + 3, pairName, COLOR_TEXT, FONT_SIZE, "Arial Bold");
   CreateLabel(prefix + "P" + idxStr + "_CDC", centerX + 155, y + 3, "-", COLOR_OFF, FONT_SIZE, "Arial Bold");
   CreateLabel(prefix + "P" + idxStr + "_CORR", centerX + 215, y + 3, "0%", COLOR_TEXT, FONT_SIZE, "Arial");
   CreateLabel(prefix + "P" + idxStr + "_TYPE", centerX + 265, y + 3, "Pos", COLOR_PROFIT, FONT_SIZE, "Arial");
   CreateLabel(prefix + "P" + idxStr + "_TPL", centerX + 330, y + 3, "0", COLOR_TEXT, 9, "Arial Bold");
   
   // === SELL SIDE DATA ===
   CreateLabel(prefix + "P" + idxStr + "_S_PL", sellX + 5, y + 3, "0", COLOR_TEXT, FONT_SIZE, "Arial");
   CreateLabel(prefix + "P" + idxStr + "_S_Z", sellX + 50, y + 3, "0.00", COLOR_TEXT, FONT_SIZE, "Arial");
   
   string sellStatusText = g_pairs[idx].enabled ? "Off" : "-";
   color sellStatusColor = COLOR_OFF;
   CreateButton(prefix + "_ST_SELL_" + idxStr, sellX + 100, y + 2, 40, 14, sellStatusText, sellStatusColor, clrWhite);
   CreateEditField(prefix + "_TGT_SELL_" + idxStr, sellX + 150, y + 2, 45, 14, DoubleToString(g_groups[groupIdx].targetSell, 0));
   CreateEditField(prefix + "_MAX_SELL_" + idxStr, sellX + 205, y + 2, 30, 14, IntegerToString(g_groups[groupIdx].maxOrderSell));
   CreateLabel(prefix + "P" + idxStr + "_S_ORD", sellX + 262, y + 3, "0", COLOR_TEXT, FONT_SIZE, "Arial");
   CreateLabel(prefix + "P" + idxStr + "_S_LOT", sellX + 305, y + 3, "0.00", COLOR_TEXT, FONT_SIZE, "Arial");
   CreateLabel(prefix + "P" + idxStr + "_S_CLOSED", sellX + 340, y + 3, "0", COLOR_TEXT, FONT_SIZE, "Arial");
   CreateButton(prefix + "_CLOSE_SELL_" + idxStr, sellX + 375, y + 2, 16, 14, "X", clrRed, clrWhite);
   
   // === v2.1.2: MINI GROUP COLUMN (Display every 2 pairs) ===
   if(idx % PAIRS_PER_MINI == 0)
   {
      int mIdx = idx / PAIRS_PER_MINI;
      string mIdxStr = IntegerToString(mIdx);
      string miniLabel = "M" + IntegerToString(mIdx + 1);
      
      // Row 1: Mini number + Float value + Closed value (expanded layout)
      CreateLabel(prefix + "M" + mIdxStr + "_HDR", miniGroupX + 5, y + 3, miniLabel, COLOR_GOLD, 8, "Arial Bold");
      CreateLabel(prefix + "M" + mIdxStr + "_V_FLT", miniGroupX + 30, y + 3, "$0", COLOR_PROFIT, 8, "Arial");
      CreateLabel(prefix + "M" + mIdxStr + "_V_CL", miniGroupX + 70, y + 3, "$0", COLOR_PROFIT, 8, "Arial");
   }
   // v2.1.2: Row 2 - Close Mini Group button (on second row of each Mini)
   else if(idx % PAIRS_PER_MINI == 1)
   {
      int mIdx = idx / PAIRS_PER_MINI;
      string mIdxStr = IntegerToString(mIdx);
      
      // Close Mini button on Row 2 (centered, larger button)
      CreateButton(prefix + "_CLOSE_MINI_" + mIdxStr, miniGroupX + 10, y + 2, 90, 14, "Close Mini", clrDarkRed, clrWhite);
   }
   
   // === v2.0: GROUP INFO COLUMN (Display every 6 pairs) ===
   if(idx % PAIRS_PER_GROUP == 0)
   {
      int gIdx = idx / PAIRS_PER_GROUP;
      string gIdxStr = IntegerToString(gIdx);
      
      CreateLabel(prefix + "G" + gIdxStr + "_HDR", groupInfoX + 5, y + 2, "Group " + IntegerToString(gIdx + 1), COLOR_GOLD, 8, "Arial Bold");
      
      CreateLabel(prefix + "G" + gIdxStr + "_L_FLT", groupInfoX + 5, y + 16, "Float:", COLOR_TEXT_LABEL, 7, "Arial");
      CreateLabel(prefix + "G" + gIdxStr + "_V_FLT", groupInfoX + 40, y + 16, "$0", COLOR_PROFIT, 8, "Arial Bold");
      
      CreateLabel(prefix + "G" + gIdxStr + "_L_CL", groupInfoX + 5, y + 30, "Closed:", COLOR_TEXT_LABEL, 7, "Arial");
      CreateLabel(prefix + "G" + gIdxStr + "_V_CL", groupInfoX + 48, y + 30, "$0", COLOR_PROFIT, 8, "Arial Bold");
      
      double scaledTarget = GetRealTimeScaledClosedTarget(gIdx);
      string tgtStr = (scaledTarget > 0) ? "$" + DoubleToString(scaledTarget, 0) : "-";
      CreateLabel(prefix + "G" + gIdxStr + "_L_TGT", groupInfoX + 5, y + 44, "Target:", COLOR_TEXT_LABEL, 7, "Arial");
      CreateLabel(prefix + "G" + gIdxStr + "_V_TGT", groupInfoX + 45, y + 44, tgtStr, COLOR_GOLD, 8, "Arial");
      
      // v2.1.2: Mini Target row - Display format: 1000/1000/1000
      string miniTgtStr = GetMiniGroupTargetString(gIdx);  // Returns "1000/1000/1000"
      CreateLabel(prefix + "G" + gIdxStr + "_L_MTGT", groupInfoX + 5, y + 58, "M.Tgt:", COLOR_TEXT_LABEL, 7, "Arial");
      CreateLabel(prefix + "G" + gIdxStr + "_V_MTGT", groupInfoX + 40, y + 58, miniTgtStr, COLOR_ACTIVE, 7, "Arial");
      
      CreateButton(prefix + "_CLOSE_GRP_" + gIdxStr, groupInfoX + 5, y + 75, 80, 14, "Close Grp", COLOR_HEADER_SELL, clrWhite);
   }
}

//+------------------------------------------------------------------+
//| Create Account Summary Section (v3.3.0 - with Closed Orders)       |
//+------------------------------------------------------------------+
void CreateAccountSummary(string prefix, int y)
{
   int boxWidth = 290;
   int boxHeight = 75;
   int gap = 8;
   int startX = PANEL_X + 10;
   
   // === BOX 1: DETAIL ===
   int box1X = startX;
   CreateRectangle(prefix + "BOX1_BG", box1X, y, boxWidth, boxHeight, COLOR_BOX_BG, COLOR_BORDER);
   CreateLabel(prefix + "BOX1_HDR", box1X + 10, y + 5, "DETAIL", COLOR_GOLD, 9, "Arial Bold");
   
   CreateLabel(prefix + "L_BAL", box1X + 10, y + 22, "Balance:", COLOR_TEXT_LABEL, 8, "Arial");
   CreateLabel(prefix + "V_BAL", box1X + 80, y + 22, "0.00", COLOR_PROFIT, 9, "Arial Bold");
   
   CreateLabel(prefix + "L_EQ", box1X + 10, y + 38, "Equity:", COLOR_TEXT_LABEL, 8, "Arial");
   CreateLabel(prefix + "V_EQ", box1X + 80, y + 38, "0.00", COLOR_PROFIT, 9, "Arial Bold");
   
   CreateLabel(prefix + "L_MG", box1X + 10, y + 54, "Margin:", COLOR_TEXT_LABEL, 8, "Arial");
   CreateLabel(prefix + "V_MG", box1X + 80, y + 54, "0.00", COLOR_TEXT_LABEL, 9, "Arial");
   
   CreateLabel(prefix + "L_TPL", box1X + 155, y + 22, "Current P/L:", COLOR_TEXT_LABEL, 8, "Arial");
   CreateLabel(prefix + "V_TPL", box1X + 230, y + 22, "0.00", COLOR_PROFIT, 10, "Arial Bold");
   
   CreateLabel(prefix + "L_TTG", box1X + 155, y + 40, "Total Target:", COLOR_TEXT_LABEL, 8, "Arial");
   // v1.8.7 HF2: Show InpTotalBasketTarget value (user-defined)
   double displayTarget = InpEnableTotalBasket ? InpTotalBasketTarget : g_totalTarget;
   CreateEditField(prefix + "_TOTAL_TARGET", box1X + 230, y + 38, 60, 16, DoubleToString(displayTarget, 0));
   
   // === BOX 2: STATUS ===
   int box2X = startX + boxWidth + gap;
   CreateRectangle(prefix + "BOX2_BG", box2X, y, boxWidth, boxHeight, COLOR_BOX_BG, COLOR_BORDER);
   CreateLabel(prefix + "BOX2_HDR", box2X + 10, y + 5, "STATUS", COLOR_GOLD, 9, "Arial Bold");
   
   CreateLabel(prefix + "L_TLOT", box2X + 10, y + 22, "Total Lot:", COLOR_TEXT_LABEL, 8, "Arial");
   CreateLabel(prefix + "V_TLOT", box2X + 80, y + 22, "0.00", COLOR_TEXT_LABEL, 9, "Arial");
   
   CreateLabel(prefix + "L_TORD", box2X + 10, y + 38, "Total Order:", COLOR_TEXT_LABEL, 8, "Arial");
   CreateLabel(prefix + "V_TORD", box2X + 85, y + 38, "0", COLOR_TEXT_LABEL, 9, "Arial");
   
   CreateLabel(prefix + "L_DD", box2X + 155, y + 22, "DD%:", COLOR_TEXT_LABEL, 8, "Arial");
   CreateLabel(prefix + "V_DD", box2X + 195, y + 22, "0.00%", COLOR_LOSS, 9, "Arial Bold");
   
   CreateLabel(prefix + "L_MDD", box2X + 155, y + 38, "Max DD%:", COLOR_TEXT_LABEL, 8, "Arial");
   CreateLabel(prefix + "V_MDD", box2X + 215, y + 38, "0.00%", COLOR_LOSS, 9, "Arial Bold");
   
   CreateLabel(prefix + "L_PAIRS", box2X + 10, y + 54, "Active Pairs:", COLOR_TEXT_LABEL, 8, "Arial");
   CreateLabel(prefix + "V_PAIRS", box2X + 90, y + 54, IntegerToString(g_activePairs), COLOR_GOLD, 9, "Arial Bold");
   
   // v1.6.5: Show Scale Factor
   string scaleStr = InpEnableAutoScaling ? StringFormat("%.2fx", GetScaleFactor()) : "Off";
   CreateLabel(prefix + "L_SCALE", box2X + 155, y + 54, "Scale:", COLOR_TEXT_LABEL, 8, "Arial");
   CreateLabel(prefix + "V_SCALE", box2X + 195, y + 54, scaleStr, InpEnableAutoScaling ? COLOR_GOLD : COLOR_OFF, 9, "Arial Bold");
   
   // === BOX 3: HISTORY LOT (v3.3.0 - with Closed Orders) ===
   int box3X = startX + 2 * (boxWidth + gap);
   CreateRectangle(prefix + "BOX3_BG", box3X, y, boxWidth, boxHeight, COLOR_BOX_BG, COLOR_BORDER);
   CreateLabel(prefix + "BOX3_HDR", box3X + 10, y + 5, "HISTORY LOT", COLOR_GOLD, 9, "Arial Bold");
   
   // v3.3.0: Format: "Lot (Orders)"
   CreateLabel(prefix + "L_DLOT", box3X + 10, y + 22, "Daily:", COLOR_TEXT_LABEL, 8, "Arial");
   CreateLabel(prefix + "V_DLOT", box3X + 55, y + 22, "0.00", COLOR_TEXT_LABEL, 9, "Arial");
   CreateLabel(prefix + "V_DORD", box3X + 95, y + 22, "(0)", COLOR_GOLD, 8, "Arial");  // Closed orders
   
   CreateLabel(prefix + "L_WLOT", box3X + 10, y + 38, "Weekly:", COLOR_TEXT_LABEL, 8, "Arial");
   CreateLabel(prefix + "V_WLOT", box3X + 55, y + 38, "0.00", COLOR_TEXT_LABEL, 9, "Arial");
   CreateLabel(prefix + "V_WORD", box3X + 95, y + 38, "(0)", COLOR_GOLD, 8, "Arial");  // Closed orders
   
   CreateLabel(prefix + "L_MLOT", box3X + 145, y + 22, "Monthly:", COLOR_TEXT_LABEL, 8, "Arial");
   CreateLabel(prefix + "V_MLOT", box3X + 200, y + 22, "0.00", COLOR_TEXT_LABEL, 9, "Arial");
   CreateLabel(prefix + "V_MORD", box3X + 240, y + 22, "(0)", COLOR_GOLD, 8, "Arial");  // Closed orders
   
   CreateLabel(prefix + "L_ALOT", box3X + 145, y + 38, "All Time:", COLOR_TEXT_LABEL, 8, "Arial");
   CreateLabel(prefix + "V_ALOT", box3X + 200, y + 38, "0.00", COLOR_TEXT_LABEL, 9, "Arial");
   CreateLabel(prefix + "V_AORD", box3X + 240, y + 38, "(0)", COLOR_GOLD, 8, "Arial");  // Closed orders
   
   // v3.6.0: Show Grid Loss Mode
   string gridLossStr = InpEnableGridLoss ? EnumToString(InpGridLossDistMode) : "Off";
   StringReplace(gridLossStr, "GRID_DIST_", "");
   CreateLabel(prefix + "L_AVG", box3X + 10, y + 54, "GL: " + gridLossStr, COLOR_TEXT_LABEL, 8, "Arial");
   
   // v3.3.0: Show Z-Score TF info
   string zTFStr = EnumToString(GetZScoreTimeframe());
   CreateLabel(prefix + "L_ZTF", box3X + 145, y + 54, "Z-TF: " + zTFStr, COLOR_TEXT_LABEL, 8, "Arial");
   
   // === BOX 4: HISTORY PROFIT ===
   int box4X = startX + 3 * (boxWidth + gap);
   CreateRectangle(prefix + "BOX4_BG", box4X, y, boxWidth, boxHeight, COLOR_BOX_BG, COLOR_BORDER);
   CreateLabel(prefix + "BOX4_HDR", box4X + 10, y + 5, "HISTORY PROFIT", COLOR_GOLD, 9, "Arial Bold");
   
   CreateLabel(prefix + "L_DP", box4X + 10, y + 22, "Daily:", COLOR_TEXT_LABEL, 8, "Arial");
   CreateLabel(prefix + "V_DP", box4X + 55, y + 22, "0.00", COLOR_PROFIT, 9, "Arial Bold");
   
   CreateLabel(prefix + "L_WP", box4X + 10, y + 38, "Weekly:", COLOR_TEXT_LABEL, 8, "Arial");
   CreateLabel(prefix + "V_WP", box4X + 60, y + 38, "0.00", COLOR_PROFIT, 9, "Arial Bold");
   
   CreateLabel(prefix + "L_MP", box4X + 155, y + 22, "Monthly:", COLOR_TEXT_LABEL, 8, "Arial");
   CreateLabel(prefix + "V_MP", box4X + 210, y + 22, "0.00", COLOR_PROFIT, 9, "Arial Bold");
   
   CreateLabel(prefix + "L_AP", box4X + 155, y + 38, "All Time:", COLOR_TEXT_LABEL, 8, "Arial");
   CreateLabel(prefix + "V_AP", box4X + 210, y + 38, "0.00", COLOR_PROFIT, 9, "Arial Bold");
   
   // Close All Buttons
   CreateButton(prefix + "_CLOSE_ALL_BUY", box4X + 10, y + 54, 60, 16, "Close Buy", COLOR_HEADER_BUY, clrWhite);
   CreateButton(prefix + "_CLOSE_ALL_SELL", box4X + 75, y + 54, 65, 16, "Close Sell", COLOR_HEADER_SELL, clrWhite);
   
   // Start All / Stop All Buttons
   CreateButton(prefix + "_START_ALL", box4X + 145, y + 54, 60, 16, "Start All", COLOR_ON, clrWhite);
   CreateButton(prefix + "_STOP_ALL", box4X + 210, y + 54, 60, 16, "Stop All", COLOR_OFF, clrWhite);
}

//+------------------------------------------------------------------+
//| Update Dashboard Values (v3.3.0 - with Closed Orders)              |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   if(MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE)) return;
   
   string prefix = "STAT_";
   
   // Update Account Info
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double margin = AccountInfoDouble(ACCOUNT_MARGIN);
   
   // v3.77: Calculate totals from ALL open positions using Magic Number (backward compatible)
   double totalLot = 0;
   int totalOrders = 0;
   
   for(int pos = PositionsTotal() - 1; pos >= 0; pos--)
   {
      ulong ticket = PositionGetTicket(pos);
      if(PositionSelectByTicket(ticket))
      {
         long magic = PositionGetInteger(POSITION_MAGIC);
         string comment = PositionGetString(POSITION_COMMENT);
         // v3.77: Check Magic Number first, then fallback to comment prefix for backward compatibility
         bool isOurOrder = (magic == InpMagicNumber) || 
                           (StringFind(comment, "HrmDream_") == 0) ||
                           (StringFind(comment, "HrmFlow_") == 0) ||
                           (StringFind(comment, "StatArb_") == 0);
         if(isOurOrder)
         {
            totalLot += PositionGetDouble(POSITION_VOLUME);
            totalOrders++;
         }
      }
   }
   
   // Update max equity
   if(equity > g_maxEquity) g_maxEquity = equity;
   
   // v3.6.0 HF4: Calculate DD from Total P/L (Negative = Drawdown)
   // DD% = |Negative Floating P/L| / Balance * 100
   double ddPercent = 0;
   if(balance > 0 && g_totalCurrentProfit < 0)
   {
      ddPercent = MathAbs(g_totalCurrentProfit) / balance * 100;
   }
   if(ddPercent > g_maxDrawdownPercent) g_maxDrawdownPercent = ddPercent;
   
   // v3.7.3: Update EA Status Display on title bar
   // v1.6.1: Enhanced status display with proper priority
   string eaStatusDisplay = "Working";
   color eaStatusColor = clrLime;
   
   if(g_licenseStatus == LICENSE_SUSPENDED)
   {
      eaStatusDisplay = "Suspended";
      eaStatusColor = clrRed;
   }
   else if(g_licenseStatus == LICENSE_EXPIRED)
   {
      eaStatusDisplay = "Expired";
      eaStatusColor = clrRed;
   }
   else if(g_licenseStatus == LICENSE_NOT_FOUND)
   {
      eaStatusDisplay = "Invalid";  // v1.6.1: Account not registered
      eaStatusColor = clrRed;
   }
   else if(g_licenseStatus == LICENSE_ERROR)
   {
      eaStatusDisplay = "Error";    // v1.6.1: Connection/Server error
      eaStatusColor = clrOrange;
   }
   else if(!g_isLicenseValid)
   {
      eaStatusDisplay = "Invalid";
      eaStatusColor = clrRed;
   }
   else if(g_isPaused)
   {
      eaStatusDisplay = "Paused";
      eaStatusColor = clrOrange;
   }
   else if(g_isNewsPaused)
   {
      eaStatusDisplay = "News";
      eaStatusColor = clrYellow;
   }
   
   UpdateLabel(prefix + "EA_STATUS_VAL", eaStatusDisplay, eaStatusColor);
   
   // v3.76: Update Last Sync Display
   color syncColor = clrYellow;
   string syncStatus = g_lastSyncStatus;
   if(g_lastSyncStatus == "OK") syncColor = clrLime;
   else if(g_lastSyncStatus == "Failed") syncColor = clrRed;
   UpdateLabel(prefix + "SYNC_VAL", syncStatus, syncColor);
   
   // v3.76: Calculate time since last sync
   string syncAgoText = "";
   if(g_lastSuccessfulSync > 0)
   {
      int secAgo = (int)(TimeCurrent() - g_lastSuccessfulSync);
      if(secAgo < 60)
         syncAgoText = IntegerToString(secAgo) + "s ago";
      else if(secAgo < 3600)
         syncAgoText = IntegerToString(secAgo / 60) + "m ago";
      else
         syncAgoText = IntegerToString(secAgo / 3600) + "h ago";
         
      // Warning if sync is stale (>10 min)
      color agoColor = (secAgo > 600) ? clrOrange : clrGray;
      UpdateLabel(prefix + "SYNC_AGO", "(" + syncAgoText + ")", agoColor);
   }
   else
   {
      UpdateLabel(prefix + "SYNC_AGO", "", clrGray);
   }
   
   // v1.6.4: Calculate time since last Z-Score update
   if(g_lastZScoreUpdateDisplay > 0)
   {
      int zSecAgo = (int)(TimeCurrent() - g_lastZScoreUpdateDisplay);
      string zUpdateText = "";
      if(zSecAgo < 60)
         zUpdateText = IntegerToString(zSecAgo) + "s ago";
      else if(zSecAgo < 3600)
         zUpdateText = IntegerToString(zSecAgo / 60) + "m ago";
      else
         zUpdateText = IntegerToString(zSecAgo / 3600) + "h ago";
      
      // Color based on Z-Score TF (warn if longer than expected)
      ENUM_TIMEFRAMES zTF = GetZScoreTimeframe();
      int expectedSeconds = PeriodSeconds(zTF);
      color zColor = (zSecAgo > expectedSeconds * 2) ? clrOrange : clrLime;
      UpdateLabel(prefix + "ZSCORE_AGO", zUpdateText, zColor);
   }
   else
   {
      UpdateLabel(prefix + "ZSCORE_AGO", "Pending", clrYellow);
   }
   
   // ===== Update Account Labels =====
   UpdateLabel(prefix + "V_BAL", DoubleToString(balance, 2), balance >= g_initialBalance ? COLOR_PROFIT : COLOR_LOSS);
   UpdateLabel(prefix + "V_EQ", DoubleToString(equity, 2), equity >= balance ? COLOR_PROFIT : COLOR_LOSS);
   UpdateLabel(prefix + "V_MG", DoubleToString(margin, 2), COLOR_TEXT_WHITE);
   
   // v1.8.7 HF2: Show Basket including accumulated profit from closed groups
   double displayBasket = g_accumulatedBasketProfit + g_basketClosedProfit;
   double displayTarget = InpEnableTotalBasket ? InpTotalBasketTarget : g_totalTarget;
   double basketNeed = displayTarget - displayBasket;
   if(basketNeed < 0) basketNeed = 0;
   
   // If Basket Target is enabled, show Basket (with accumulated); otherwise show Floating P/L
   if(displayTarget > 0)
   {
      UpdateLabel(prefix + "V_TPL", DoubleToString(displayBasket, 2), displayBasket >= 0 ? COLOR_PROFIT : COLOR_LOSS);
      UpdateLabel(prefix + "L_TPL", "Basket:", COLOR_TEXT_WHITE);  // Update label text
   }
   else
   {
      UpdateLabel(prefix + "V_TPL", DoubleToString(g_totalCurrentProfit, 2), g_totalCurrentProfit >= 0 ? COLOR_PROFIT : COLOR_LOSS);
   }
   
   UpdateLabel(prefix + "V_TLOT", DoubleToString(totalLot, 2), COLOR_TEXT_WHITE);
   UpdateLabel(prefix + "V_TORD", IntegerToString(totalOrders), COLOR_TEXT_WHITE);
   UpdateLabel(prefix + "V_DD", DoubleToString(ddPercent, 2) + "%", ddPercent > 10 ? COLOR_LOSS : COLOR_TEXT_WHITE);
   
   // v3.6.0 HF4: Always show Max DD% (removed "Need" - Basket vs Target is enough)
   UpdateLabel(prefix + "L_MDD", "Max DD%:", COLOR_TEXT_WHITE);
   UpdateLabel(prefix + "V_MDD", DoubleToString(g_maxDrawdownPercent, 2) + "%", 
               g_maxDrawdownPercent > InpMaxDrawdown ? COLOR_LOSS : COLOR_TEXT_WHITE);
   
   // v1.6.5: Update Scale Factor display (dynamic mode recalculates based on current balance)
   if(InpEnableAutoScaling)
   {
      double currentScale = GetScaleFactor();
      string scaleStr = StringFormat("%.2fx", currentScale);
      UpdateLabel(prefix + "V_SCALE", scaleStr, COLOR_GOLD);
   }
   else
   {
      UpdateLabel(prefix + "V_SCALE", "Off", COLOR_OFF);
   }
   
   // Lot Statistics with Closed Orders (v3.3.0)
   UpdateLabel(prefix + "V_DLOT", DoubleToString(g_dailyLot, 2), COLOR_TEXT_WHITE);
   UpdateLabel(prefix + "V_DORD", "(" + IntegerToString(g_dailyClosedOrders) + ")", COLOR_GOLD);
   UpdateLabel(prefix + "V_WLOT", DoubleToString(g_weeklyLot, 2), COLOR_TEXT_WHITE);
   UpdateLabel(prefix + "V_WORD", "(" + IntegerToString(g_weeklyClosedOrders) + ")", COLOR_GOLD);
   UpdateLabel(prefix + "V_MLOT", DoubleToString(g_monthlyLot, 2), COLOR_TEXT_WHITE);
   UpdateLabel(prefix + "V_MORD", "(" + IntegerToString(g_monthlyClosedOrders) + ")", COLOR_GOLD);
   UpdateLabel(prefix + "V_ALOT", DoubleToString(g_allTimeLot, 2), COLOR_TEXT_WHITE);
   UpdateLabel(prefix + "V_AORD", "(" + IntegerToString(g_allTimeClosedOrders) + ")", COLOR_GOLD);
   
   // Profit Statistics
   UpdateLabel(prefix + "V_DP", DoubleToString(g_dailyProfit, 2), g_dailyProfit >= 0 ? COLOR_PROFIT : COLOR_LOSS);
   UpdateLabel(prefix + "V_WP", DoubleToString(g_weeklyProfit, 2), g_weeklyProfit >= 0 ? COLOR_PROFIT : COLOR_LOSS);
   UpdateLabel(prefix + "V_MP", DoubleToString(g_monthlyProfit, 2), g_monthlyProfit >= 0 ? COLOR_PROFIT : COLOR_LOSS);
   UpdateLabel(prefix + "V_AP", DoubleToString(g_allTimeProfit, 2), g_allTimeProfit >= 0 ? COLOR_PROFIT : COLOR_LOSS);
   
   // ===== Update Each Pair Row =====
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      string idxStr = IntegerToString(i);
      
      // === Center Data ===
      if(!g_pairs[i].enabled)
      {
         UpdateLabel(prefix + "P" + idxStr + "_CDC", "-", COLOR_OFF);  // v3.5.0
         UpdateLabel(prefix + "P" + idxStr + "_CORR", "-", COLOR_OFF);
         UpdateLabel(prefix + "P" + idxStr + "_TYPE", "-", COLOR_OFF);
         UpdateLabel(prefix + "P" + idxStr + "_BETA", "-", COLOR_OFF);
      }
      else if(!g_pairs[i].dataValid)
      {
         UpdateLabel(prefix + "P" + idxStr + "_CDC", "-", clrGray);  // v3.5.0
         UpdateLabel(prefix + "P" + idxStr + "_CORR", "N/A", COLOR_GOLD);
         UpdateLabel(prefix + "P" + idxStr + "_TYPE", "N/A", COLOR_GOLD);
         UpdateLabel(prefix + "P" + idxStr + "_BETA", "N/A", COLOR_GOLD);
      }
      else
      {
         // v3.7.1: Update CDC Trend Status Badge using GetCDCStatusText
         color cdcColor;
         string cdcStatus = GetCDCStatusText(i, cdcColor);
         UpdateLabel(prefix + "P" + idxStr + "_CDC", cdcStatus, cdcColor);
         
         double corr = g_pairs[i].correlation * 100;
         color corrColor = MathAbs(corr) >= InpMinCorrelation * 100 ? COLOR_PROFIT : COLOR_TEXT;
         UpdateLabel(prefix + "P" + idxStr + "_CORR", DoubleToString(corr, 0) + "%", corrColor);
         
         // v1.8: Simplified TYPE display - always show Pos/Neg only
         string corrType;
         color typeColor;
         
         if(g_pairs[i].correlationType == 1)
         {
            corrType = "Pos";
            typeColor = COLOR_PROFIT;  // Green
         }
         else
         {
            corrType = "Neg";
            typeColor = COLOR_LOSS;    // Red
         }
         UpdateLabel(prefix + "P" + idxStr + "_TYPE", corrType, typeColor);
         
         // v3.6.0 HF4: Beta update hidden
         // UpdateLabel(prefix + "P" + idxStr + "_BETA", DoubleToString(g_pairs[i].hedgeRatio, 2), COLOR_TEXT);
      }
      
      // Total P/L
      double totalPL = g_pairs[i].totalPairProfit;
      UpdateLabel(prefix + "P" + idxStr + "_TPL", DoubleToString(totalPL, 0), totalPL >= 0 ? COLOR_PROFIT : COLOR_LOSS);
      
      // === Buy Side Data ===
      // v3.2.9: First column is Closed P/L
      UpdateLabel(prefix + "P" + idxStr + "_B_CLOSED", DoubleToString(g_pairs[i].closedProfitBuy, 0), 
                  g_pairs[i].closedProfitBuy >= 0 ? COLOR_PROFIT : COLOR_LOSS);
      
      // v1.8.6: Calculate total lot from actual positions (Main + Sub + Grid)
      double buyLot = g_pairs[i].directionBuy == 1 ? GetTotalLotForPair(i, true) : 0;
      UpdateLabel(prefix + "P" + idxStr + "_B_LOT", DoubleToString(buyLot, 2), COLOR_TEXT);
      
      // v3.2.7: Show order count including averaging
      int buyOrders = g_pairs[i].orderCountBuy;
      UpdateLabel(prefix + "P" + idxStr + "_B_ORD", IntegerToString(buyOrders), 
                  buyOrders > 0 ? COLOR_ACTIVE : COLOR_TEXT);
      
      double zScore = g_pairs[i].zScore;
      color zColor = MathAbs(zScore) > InpEntryZScore ? (zScore > 0 ? COLOR_LOSS : COLOR_PROFIT) : COLOR_TEXT;
      UpdateLabel(prefix + "P" + idxStr + "_B_Z", DoubleToString(zScore, 2), zColor);
      
      // v3.2.9: P/L column shows current/floating P/L
      UpdateLabel(prefix + "P" + idxStr + "_B_PL", DoubleToString(g_pairs[i].profitBuy, 0),
                  g_pairs[i].profitBuy >= 0 ? COLOR_PROFIT : COLOR_LOSS);
      
      // Status Button Update
      string buyBtnName = prefix + "_ST_BUY_" + idxStr;
      if(ObjectFind(0, buyBtnName) >= 0)
      {
         string buyStatus = "Off";
         color buyBgColor = COLOR_OFF;
         if(!g_pairs[i].enabled)
         {
            buyStatus = "-";
            buyBgColor = COLOR_OFF;
         }
         else if(g_pairs[i].directionBuy == 1)
         {
            buyStatus = "LONG";
            buyBgColor = COLOR_PROFIT;
         }
         else if(g_pairs[i].directionBuy == -1)
         {
            buyStatus = "On";
            buyBgColor = COLOR_ON;
         }
         ObjectSetString(0, buyBtnName, OBJPROP_TEXT, buyStatus);
         ObjectSetInteger(0, buyBtnName, OBJPROP_BGCOLOR, buyBgColor);
      }
      
      // === Sell Side Data ===
      // v3.2.9: P/L column shows current/floating P/L
      UpdateLabel(prefix + "P" + idxStr + "_S_PL", DoubleToString(g_pairs[i].profitSell, 0),
                  g_pairs[i].profitSell >= 0 ? COLOR_PROFIT : COLOR_LOSS);
      
      // v1.8.6: Calculate total lot from actual positions (Main + Sub + Grid)
      double sellLot = g_pairs[i].directionSell == 1 ? GetTotalLotForPair(i, false) : 0;
      UpdateLabel(prefix + "P" + idxStr + "_S_LOT", DoubleToString(sellLot, 2), COLOR_TEXT);
      
      // v3.2.7: Show order count including averaging
      int sellOrders = g_pairs[i].orderCountSell;
      UpdateLabel(prefix + "P" + idxStr + "_S_ORD", IntegerToString(sellOrders),
                  sellOrders > 0 ? COLOR_ACTIVE : COLOR_TEXT);
      
      UpdateLabel(prefix + "P" + idxStr + "_S_Z", DoubleToString(zScore, 2), zColor);
      
      // v3.2.9: Last column is Closed P/L
      UpdateLabel(prefix + "P" + idxStr + "_S_CLOSED", DoubleToString(g_pairs[i].closedProfitSell, 0),
                  g_pairs[i].closedProfitSell >= 0 ? COLOR_PROFIT : COLOR_LOSS);
      
      // Sell Status Button Update
      string sellBtnName = prefix + "_ST_SELL_" + idxStr;
      if(ObjectFind(0, sellBtnName) >= 0)
      {
         string sellStatus = "Off";
         color sellBgColor = COLOR_OFF;
         if(!g_pairs[i].enabled)
         {
            sellStatus = "-";
            sellBgColor = COLOR_OFF;
         }
         else if(g_pairs[i].directionSell == 1)
         {
            sellStatus = "SHORT";
            sellBgColor = COLOR_LOSS;
         }
         else if(g_pairs[i].directionSell == -1)
         {
            sellStatus = "On";
            sellBgColor = COLOR_ON;
         }
         ObjectSetString(0, sellBtnName, OBJPROP_TEXT, sellStatus);
         ObjectSetInteger(0, sellBtnName, OBJPROP_BGCOLOR, sellBgColor);
      }
   }
   
   // === v2.0: Update Mini Group Column ===
   for(int m = 0; m < MAX_MINI_GROUPS; m++)
   {
      string mIdxStr = IntegerToString(m);
      
      // Update Floating P/L
      double mFloat = g_miniGroups[m].floatingProfit;
      color mFltColor = (mFloat >= 0) ? COLOR_PROFIT : COLOR_LOSS;
      UpdateLabel(prefix + "M" + mIdxStr + "_V_FLT", "$" + DoubleToString(mFloat, 0), mFltColor);
      
      // Update Closed P/L
      double mClosed = g_miniGroups[m].closedProfit;
      color mClColor = (mClosed >= 0) ? COLOR_PROFIT : COLOR_LOSS;
      UpdateLabel(prefix + "M" + mIdxStr + "_V_CL", "$" + DoubleToString(mClosed, 0), mClColor);
   }
   
   // === v1.8.7: Update Group Info Column (Vertical Layout) ===
   for(int g = 0; g < MAX_GROUPS; g++)
   {
      string gIdxStr = IntegerToString(g);
      
      // v1.8.7: Update Floating P/L
      double grpFloating = g_groups[g].floatingProfit;
      color fltColor = (grpFloating >= 0) ? COLOR_PROFIT : COLOR_LOSS;
      UpdateLabel(prefix + "G" + gIdxStr + "_V_FLT", "$" + DoubleToString(grpFloating, 0), fltColor);
      
      // v1.8.7: Update Closed P/L
      double grpClosed = g_groups[g].closedProfit;
      color clColor = (grpClosed >= 0) ? COLOR_PROFIT : COLOR_LOSS;
      UpdateLabel(prefix + "G" + gIdxStr + "_V_CL", "$" + DoubleToString(grpClosed, 0), clColor);
      
      // v1.6.6: Update Group Target with real-time scaled value
      double scaledTarget = GetRealTimeScaledClosedTarget(g);
      string tgtStr = (scaledTarget > 0) ? "$" + DoubleToString(scaledTarget, 0) : "-";
      UpdateLabel(prefix + "G" + gIdxStr + "_V_TGT", tgtStr, COLOR_GOLD);
      
      // v2.1.2: Update Mini Target with individual format
      string miniTgtStr = GetMiniGroupTargetString(g);  // Returns "1000/1000/1000"
      UpdateLabel(prefix + "G" + gIdxStr + "_V_MTGT", miniTgtStr, COLOR_ACTIVE);
   }
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Helper: Create Rectangle                                           |
//+------------------------------------------------------------------+
void CreateRectangle(string name, int x, int y, int width, int height, color bgColor, color borderColor)
{
   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgColor);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, borderColor);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| Helper: Create Label                                               |
//+------------------------------------------------------------------+
void CreateLabel(string name, int x, int y, string text, color clr, int fontSize, string fontName)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, fontName);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| Helper: Create Button                                              |
//+------------------------------------------------------------------+
void CreateButton(string name, int x, int y, int width, int height, string text, color bgColor, color textColor)
{
   ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgColor);
   ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 7);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| Helper: Create Edit Field                                          |
//+------------------------------------------------------------------+
void CreateEditField(string name, int x, int y, int width, int height, string text)
{
   ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 7);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ALIGN, ALIGN_CENTER);
   ObjectSetInteger(0, name, OBJPROP_READONLY, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| Helper: Update Label                                               |
//+------------------------------------------------------------------+
void UpdateLabel(string name, string text, color clr)
{
   if(ObjectFind(0, name) >= 0)
   {
      ObjectSetString(0, name, OBJPROP_TEXT, text);
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   }
}
//+------------------------------------------------------------------+
