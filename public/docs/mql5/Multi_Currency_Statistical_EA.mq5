//+------------------------------------------------------------------+
//|                                Multi_Currency_Statistical_EA.mq5 |
//|                 Statistical Arbitrage (Pairs Trading) v3.6.5     |
//|                                             MoneyX Trading        |
//+------------------------------------------------------------------+
#property copyright "MoneyX Trading"
#property version   "3.65"
#property strict
#property description "Statistical Arbitrage / Pairs Trading Expert Advisor"
#property description "Full Hedging with Independent Buy/Sell Sides"
#property description "v3.6.5: License Verification System Integration"

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
   
   // === v3.5.3 HF1: Last Grid Lot for Compounding ===
   double         lastGridLotBuyA;   // Last Lot A for BUY side grid
   double         lastGridLotBuyB;   // Last Lot B for BUY side grid
   double         lastGridLotSellA;  // Last Lot A for SELL side grid
   double         lastGridLotSellB;  // Last Lot B for SELL side grid
   
   // === v3.5.3 HF3: ADX for Negative Correlation Pairs ===
   double         adxValueA;         // ADX value for Symbol A
   double         adxValueB;         // ADX value for Symbol B
   
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
//| INPUT PARAMETERS                                                   |
//+------------------------------------------------------------------+
input group "=== Trading Settings ==="
input double   InpBaseLot = 0.1;                // Base Lot Size (Symbol A)
input double   InpMaxLot = 10.0;                // Maximum Lot Size
input int      InpMagicNumber = 888888;         // Magic Number
input int      InpSlippage = 30;                // Slippage (points)
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_H1; // Trading Timeframe

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

input group "=== Z-Score Timeframe Settings (v3.3.0) ==="
input ENUM_TIMEFRAMES InpZScoreTimeframe = PERIOD_CURRENT;  // Z-Score Timeframe (CURRENT = use Correlation TF)
input int      InpZScoreBars = 0;                            // Z-Score Bars (0 = use Correlation Bars)

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

input group "=== Grid Loss Side Settings (v3.6.0 HF1) ==="
input bool     InpEnableGridLoss = true;              // Enable Grid Loss Side
input ENUM_GRID_DISTANCE_MODE InpGridLossDistMode = GRID_DIST_ATR;  // Distance Mode
input ENUM_GRID_LOT_TYPE      InpGridLossLotType = GRID_LOT_TYPE_TREND_BASED;  // Lot Type
input double   InpGridLossFixedPoints = 500;          // Fixed Points (if mode = Fixed Points)
input double   InpGridLossFixedPips = 50;             // Fixed Pips (if mode = Fixed Pips)
input double   InpGridLossATRMult = 1.5;              // ATR Multiplier (if mode = ATR)
input ENUM_TIMEFRAMES InpGridLossATRTimeframe = PERIOD_H1;  // ATR Timeframe (if mode = ATR)
input int      InpGridLossATRPeriod = 14;             // ATR Period (if mode = ATR)
input string   InpGridLossZScoreLevels = "2.5;3.0;4.0;5.0"; // Z-Score Levels (if mode = Z-Score)
input double   InpGridLossCustomLot = 0.1;            // Custom Lot (if type = Custom)
input double   InpGridLossLotMultiplier = 1.2;        // Lot Multiplier (if type = Multiplier)
input int      InpMaxGridLossOrders = 5;              // Max Grid Loss Orders per Side

input group "=== Grid Profit Side Settings (v3.6.0 HF1) ==="
input bool     InpEnableGridProfit = false;           // Enable Grid Profit Side
input ENUM_GRID_DISTANCE_MODE InpGridProfitDistMode = GRID_DIST_ATR;  // Distance Mode
input ENUM_GRID_LOT_TYPE      InpGridProfitLotType = GRID_LOT_TYPE_TREND_BASED;  // Lot Type
input double   InpGridProfitFixedPoints = 500;        // Fixed Points (if mode = Fixed Points)
input double   InpGridProfitFixedPips = 50;           // Fixed Pips (if mode = Fixed Pips)
input double   InpGridProfitATRMult = 1.5;            // ATR Multiplier (if mode = ATR)
input ENUM_TIMEFRAMES InpGridProfitATRTimeframe = PERIOD_H1;  // ATR Timeframe (if mode = ATR)
input int      InpGridProfitATRPeriod = 14;           // ATR Period (if mode = ATR)
input string   InpGridProfitZScoreLevels = "1.5;1.0;0.5"; // Z-Score Levels (if mode = Z-Score)
input double   InpGridProfitCustomLot = 0.1;          // Custom Lot (if type = Custom)
input double   InpGridProfitLotMultiplier = 1.1;      // Lot Multiplier (if type = Multiplier)
input int      InpMaxGridProfitOrders = 3;            // Max Grid Profit Orders per Side

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

input group "=== Basket Target Settings (v3.6.0 HF3) ==="
input double   InpTotalTarget = 0;              // Basket Closed Profit Target $ (0=Disable)
input double   InpBasketFloatingTarget = 0;     // Basket Floating Profit Target $ (0=Disable)
input int      InpDefaultMaxOrderBuy = 5;       // Total Max Orders Buy (Main + Grid)
input int      InpDefaultMaxOrderSell = 5;      // Total Max Orders Sell (Main + Grid)
input double   InpDefaultTargetBuy = 10.0;      // Default Target (Buy Side) $
input double   InpDefaultTargetSell = 10.0;     // Default Target (Sell Side) $

input group "=== Dashboard Settings ==="
input int      InpPanelX = 10;                  // Dashboard X Position
input int      InpPanelY = 30;                  // Dashboard Y Position
input int      InpPanelWidth = 1200;            // Dashboard Width
input int      InpPanelHeight = 820;            // Dashboard Height (for 30 pairs)
input int      InpRowHeight = 18;               // Row Height per Pair
input int      InpFontSize = 8;                 // Font Size

input group "=== Dashboard Colors ==="
input color    InpColorBgDark = C'20,60,80';        // Background Color (Dark)
input color    InpColorRowOdd = C'255,235,180';     // Row Color (Odd)
input color    InpColorRowEven = C'255,245,200';    // Row Color (Even)
input color    InpColorHeaderMain = C'50,50,80';    // Header Main Color
input color    InpColorHeaderBuy = C'0,100,150';    // Header Buy Color
input color    InpColorHeaderSell = C'150,60,60';   // Header Sell Color
input color    InpColorProfit = C'0,150,0';         // Profit Color
input color    InpColorLoss = C'200,0,0';           // Loss Color
input color    InpColorOn = C'0,255,0';             // Status On Color
input color    InpColorOff = C'128,128,128';        // Status Off Color

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

input group "=== Pair 1-5 Configuration ==="
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

input group "=== Pair 6-10 Configuration ==="
input bool     InpEnablePair6 = false;          // Enable Pair 6
input string   InpPair6_SymbolA = "EURUSD";     // Pair 6: Symbol A
input string   InpPair6_SymbolB = "USDJPY";     // Pair 6: Symbol B

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

input group "=== Pair 11-15 Configuration ==="
input bool     InpEnablePair11 = false;         // Enable Pair 11
input string   InpPair11_SymbolA = "EURGBP";    // Pair 11: Symbol A
input string   InpPair11_SymbolB = "EURCHF";    // Pair 11: Symbol B

input bool     InpEnablePair12 = false;         // Enable Pair 12
input string   InpPair12_SymbolA = "NZDUSD";    // Pair 12: Symbol A
input string   InpPair12_SymbolB = "USDCAD";    // Pair 12: Symbol B

input bool     InpEnablePair13 = false;         // Enable Pair 13
input string   InpPair13_SymbolA = "AUDJPY";    // Pair 13: Symbol A
input string   InpPair13_SymbolB = "NZDJPY";    // Pair 13: Symbol B

input bool     InpEnablePair14 = false;         // Enable Pair 14
input string   InpPair14_SymbolA = "GBPAUD";    // Pair 14: Symbol A
input string   InpPair14_SymbolB = "GBPNZD";    // Pair 14: Symbol B

input bool     InpEnablePair15 = false;         // Enable Pair 15
input string   InpPair15_SymbolA = "EURAUD";    // Pair 15: Symbol A
input string   InpPair15_SymbolB = "EURNZD";    // Pair 15: Symbol B

input group "=== Pair 16-20 Configuration ==="
input bool     InpEnablePair16 = false;         // Enable Pair 16
input string   InpPair16_SymbolA = "CHFJPY";    // Pair 16: Symbol A
input string   InpPair16_SymbolB = "CADJPY";    // Pair 16: Symbol B

input bool     InpEnablePair17 = false;         // Enable Pair 17
input string   InpPair17_SymbolA = "AUDCAD";    // Pair 17: Symbol A
input string   InpPair17_SymbolB = "AUDNZD";    // Pair 17: Symbol B

input bool     InpEnablePair18 = false;         // Enable Pair 18
input string   InpPair18_SymbolA = "GBPCAD";    // Pair 18: Symbol A
input string   InpPair18_SymbolB = "GBPCHF";    // Pair 18: Symbol B

input bool     InpEnablePair19 = false;         // Enable Pair 19
input string   InpPair19_SymbolA = "EURCAD";    // Pair 19: Symbol A
input string   InpPair19_SymbolB = "EURCHF";    // Pair 19: Symbol B

input bool     InpEnablePair20 = false;         // Enable Pair 20
input string   InpPair20_SymbolA = "CADCHF";    // Pair 20: Symbol A
input string   InpPair20_SymbolB = "CADJPY";    // Pair 20: Symbol B

input group "=== Pair 21-25 Configuration ==="
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

input bool     InpEnablePair25 = false;         // Enable Pair 25
input string   InpPair25_SymbolA = "NZDJPY";    // Pair 25: Symbol A
input string   InpPair25_SymbolB = "CADJPY";    // Pair 25: Symbol B

input group "=== Pair 26-30 Configuration ==="
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

input group "=== License Settings (v3.6.5) ==="
input string   InpLicenseServer = LICENSE_BASE_URL;    // License Server URL
input int      InpLicenseCheckMinutes = 60;            // License Check Interval (minutes)
input int      InpDataSyncMinutes = 5;                 // Data Sync Interval (minutes)

input group "=== News Filter ==="
input bool     InpEnableNewsFilter = true;      // Enable News Filter
input int      InpNewsBeforeMinutes = 30;       // Minutes Before News
input int      InpNewsAfterMinutes = 30;        // Minutes After News

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
//| GLOBAL VARIABLES                                                   |
//+------------------------------------------------------------------+
CTrade g_trade;
bool g_isLicenseValid = false;
bool g_isNewsPaused = false;
bool g_isPaused = false;

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

// Dashboard Colors (from inputs)
color COLOR_BG_DARK;
color COLOR_BG_ROW_ODD;
color COLOR_BG_ROW_EVEN;
color COLOR_HEADER_MAIN;
color COLOR_HEADER_BUY;
color COLOR_HEADER_SELL;
color COLOR_HEADER_TXT = clrWhite;
color COLOR_TEXT = C'40,40,40';
color COLOR_TEXT_WHITE = clrWhite;
color COLOR_PROFIT;
color COLOR_LOSS;
color COLOR_ON;
color COLOR_OFF;
color COLOR_GOLD = C'255,180,0';
color COLOR_ACTIVE = C'0,150,255';
color COLOR_BORDER = C'100,100,100';

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

// v3.5.0: CDC Action Zone timeframe tracking
datetime g_lastCDCUpdate = 0;

// === v3.6.0 HF3: Basket Profit Target System ===
double g_basketClosedProfit = 0;      // Accumulated closed profit from all pairs
double g_basketFloatingProfit = 0;    // Current floating profit from all pairs
double g_basketTotalProfit = 0;       // Closed + Floating = Total
bool   g_basketTargetTriggered = false; // Flag to prevent multiple triggers in same tick

// === v3.6.0 HF3 Patch 3: Separate Flags for Different Purposes ===
bool   g_orphanCheckPaused = false;   // Pause orphan check during any position closing operation
bool   g_basketCloseMode = false;     // TRUE when Basket is closing all (don't accumulate to basket)

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
   
   // Initialize dashboard colors from inputs
   COLOR_BG_DARK = InpColorBgDark;
   COLOR_BG_ROW_ODD = InpColorRowOdd;
   COLOR_BG_ROW_EVEN = InpColorRowEven;
   COLOR_HEADER_MAIN = InpColorHeaderMain;
   COLOR_HEADER_BUY = InpColorHeaderBuy;
   COLOR_HEADER_SELL = InpColorHeaderSell;
   COLOR_PROFIT = InpColorProfit;
   COLOR_LOSS = InpColorLoss;
   COLOR_ON = InpColorOn;
   COLOR_OFF = InpColorOff;
   
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
   
   // Initialize target from input
   g_totalTarget = InpTotalTarget;
   
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
   
   // Verify license
   g_isLicenseValid = VerifyLicense();
   if(!g_isLicenseValid)
   {
      Print("License verification failed - EA will not trade");
   }
   
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
   
   PrintFormat("=== Statistical Arbitrage EA v3.5.0 Initialized - %d Active Pairs ===", g_activePairs);
   return(INIT_SUCCEEDED);
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
//| Setup Individual Pair (v3.3.0 - with consolidated max orders)      |
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
   g_pairs[index].lotBuyA = InpBaseLot;
   g_pairs[index].lotBuyB = InpBaseLot;
   g_pairs[index].profitBuy = 0;
   g_pairs[index].orderCountBuy = 0;
   // v3.3.0: maxOrderBuy = Total limit (1 Main + N Grid orders)
   g_pairs[index].maxOrderBuy = InpDefaultMaxOrderBuy;
   g_pairs[index].targetBuy = InpDefaultTargetBuy;
   g_pairs[index].entryTimeBuy = 0;
   
   // Sell Side initialization - directionSell = -1 means Ready to trade
   g_pairs[index].directionSell = enabled ? -1 : 0;
   g_pairs[index].ticketSellA = 0;
   g_pairs[index].ticketSellB = 0;
   g_pairs[index].lotSellA = InpBaseLot;
   g_pairs[index].lotSellB = InpBaseLot;
   g_pairs[index].profitSell = 0;
   g_pairs[index].orderCountSell = 0;
   // v3.3.0: maxOrderSell = Total limit (1 Main + N Grid orders)
   g_pairs[index].maxOrderSell = InpDefaultMaxOrderSell;
   g_pairs[index].targetSell = InpDefaultTargetSell;
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
   g_pairs[index].cdcFastB = 0;
   g_pairs[index].cdcSlowB = 0;
   
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
   
   // Check for new candle on correlation timeframe
   datetime currentCandleTime = iTime(_Symbol, InpCorrTimeframe, 0);
   bool newCandleCorr = (currentCandleTime != g_lastCandleTime);
   
   if(newCandleCorr)
   {
      g_lastCandleTime = currentCandleTime;
      
      // v3.2.5: Skip correlation update in tester if option enabled
      if(!(g_isTesterMode && InpSkipCorrUpdateInTester))
      {
         UpdateAllPairData();
      }
   }
   
   // v3.3.0: Check for new candle on Z-Score timeframe (if different from correlation TF)
   ENUM_TIMEFRAMES zTF = GetZScoreTimeframe();
   datetime zCandleTime = iTime(_Symbol, zTF, 0);
   bool newCandleZScore = (zCandleTime != g_lastZScoreUpdate);
   
   if(newCandleZScore)
   {
      g_lastZScoreUpdate = zCandleTime;
      // Update Z-Score specific data using its own timeframe
      UpdateZScoreData();
      
      // v3.4.0: Calculate RSI on Spread after Z-Score data is updated
      CalculateAllRSIonSpread();
   }
   
   // v3.5.0: Update CDC Trend Data on new CDC timeframe candle
   datetime cdcCandleTime = iTime(_Symbol, InpCDCTimeframe, 0);
   bool newCandleCDC = (cdcCandleTime != g_lastCDCUpdate);
   
   if(newCandleCDC)
   {
      g_lastCDCUpdate = cdcCandleTime;
      UpdateAllPairsCDC();
   }
   
   // v3.5.3 HF3: Update ADX for Negative Correlation Pairs on new ADX timeframe candle
   datetime adxCandleTime = iTime(_Symbol, InpADXTimeframe, 0);
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
      // v3.2.5: Dashboard update with throttling in tester
      if(g_dashboardEnabled)
      {
         if(g_isTesterMode && InpFastBacktest)
         {
            if(TimeCurrent() - g_lastTesterDashboardUpdate >= InpBacktestUiUpdateSec)
            {
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
   CheckRiskLimits();
   UpdateAccountStats();
   
   // v3.2.5: Dashboard update with throttling in tester
   if(g_dashboardEnabled)
   {
      if(g_isTesterMode && InpFastBacktest)
      {
         if(TimeCurrent() - g_lastTesterDashboardUpdate >= InpBacktestUiUpdateSec)
         {
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
      if(StringFind(sparam, prefix + "_CLOSE_BUY_") >= 0)
      {
         int pairIndex = (int)StringToInteger(StringSubstr(sparam, StringLen(prefix + "_CLOSE_BUY_")));
         CloseBuySide(pairIndex);
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      }
      else if(StringFind(sparam, prefix + "_CLOSE_SELL_") >= 0)
      {
         int pairIndex = (int)StringToInteger(StringSubstr(sparam, StringLen(prefix + "_CLOSE_SELL_")));
         CloseSellSide(pairIndex);
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      }
      else if(StringFind(sparam, prefix + "_ST_BUY_") >= 0)
      {
         int pairIndex = (int)StringToInteger(StringSubstr(sparam, StringLen(prefix + "_ST_BUY_")));
         ToggleBuySide(pairIndex);
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      }
      else if(StringFind(sparam, prefix + "_ST_SELL_") >= 0)
      {
         int pairIndex = (int)StringToInteger(StringSubstr(sparam, StringLen(prefix + "_ST_SELL_")));
         ToggleSellSide(pairIndex);
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      }
      else if(sparam == prefix + "_CLOSE_ALL_BUY")
      {
         CloseAllBuySides();
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      }
      else if(sparam == prefix + "_CLOSE_ALL_SELL")
      {
         CloseAllSellSides();
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      }
      else if(sparam == prefix + "_START_ALL")
      {
         StartAllPairs();
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      }
      else if(sparam == prefix + "_STOP_ALL")
      {
         StopAllPairs();
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
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
   
   string response = "";
   int httpCode = SendLicenseRequest(url, jsonRequest, response);
   
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
      g_lastLicenseError = "WebRequest failed. Error: " + IntegerToString(errorCode);
      
      if(errorCode == 4014)
      {
         g_lastLicenseError = "WebRequest not allowed. Add URL to allowed list:\n" + 
                              "Tools > Options > Expert Advisors > Allow WebRequest\n" +
                              "Add: " + g_licenseServerUrl;
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
      if(ch >= '0' && ch <= '9' || ch == '-')
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
//| Sync Account Data with Server                                      |
//+------------------------------------------------------------------+
bool SyncAccountData(ENUM_SYNC_EVENT eventType)
{
   string url = g_licenseServerUrl + "/functions/v1/sync-account-data";
   
   long accountNumber = AccountInfoInteger(ACCOUNT_LOGIN);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double floatingPL = AccountInfoDouble(ACCOUNT_PROFIT);
   int openOrders = PositionsTotal();
   
   string eventStr = "scheduled";
   if(eventType == SYNC_ORDER_OPEN) eventStr = "order_open";
   else if(eventType == SYNC_ORDER_CLOSE) eventStr = "order_close";
   
   string json = "{";
   json += "\"account_number\":\"" + IntegerToString(accountNumber) + "\",";
   json += "\"balance\":" + DoubleToString(balance, 2) + ",";
   json += "\"equity\":" + DoubleToString(equity, 2) + ",";
   json += "\"floating_pl\":" + DoubleToString(floatingPL, 2) + ",";
   json += "\"open_orders\":" + IntegerToString(openOrders) + ",";
   json += "\"event_type\":\"" + eventStr + "\"";
   json += "}";
   
   string response = "";
   int httpCode = SendLicenseRequest(url, json, response);
   
   return (httpCode == 200 && JsonGetBool(response, "success"));
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
   
   // Demo accounts can continue even if license fails (for testing)
   if(isDemo && !result)
   {
      Print("[License] Demo account - allowing trading despite license error");
      g_isLicenseValid = true;
      return true;
   }
   
   // Show popup for license status
   ShowLicensePopup(g_licenseStatus);
   
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
//| v3.3.0: Update Z-Score Data (Separate from Correlation)            |
//+------------------------------------------------------------------+
void UpdateZScoreData()
{
   ENUM_TIMEFRAMES zTF = GetZScoreTimeframe();
   int zBars = GetZScoreBars();
   
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(!g_pairs[i].enabled || !g_pairs[i].dataValid) continue;
      
      // Copy price data using Z-Score timeframe
      double closesA[], closesB[];
      ArrayResize(closesA, zBars + 5);
      ArrayResize(closesB, zBars + 5);
      ArraySetAsSeries(closesA, true);
      ArraySetAsSeries(closesB, true);
      
      int copiedA = CopyClose(g_pairs[i].symbolA, zTF, 0, zBars, closesA);
      int copiedB = CopyClose(g_pairs[i].symbolB, zTF, 0, zBars, closesB);
      
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
   
   // Debug log for first pair if enabled
   if(InpDebugMode && (!g_isTesterMode || !InpDisableDebugInTester))
   {
      for(int i = 0; i < MAX_PAIRS; i++)
      {
         if(g_pairs[i].enabled && g_pairs[i].dataValid)
         {
            PrintFormat("Z-Score Debug [Pair %d]: TF=%s, Bars=%d, Spread=%.6f, Mean=%.6f, StdDev=%.6f, Z=%.4f",
                        i + 1, EnumToString(zTF), zBars,
                        g_pairs[i].currentSpread, g_pairs[i].spreadMean, 
                        g_pairs[i].spreadStdDev, g_pairs[i].zScore);
            PrintFormat("  Interpretation: Z=%.2f means Symbol A is %s relative to B",
                        g_pairs[i].zScore, 
                        g_pairs[i].zScore > 0 ? "EXPENSIVE (Sell A)" : "CHEAP (Buy A)");
            break;  // Only log first enabled pair
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
   
   // Also apply user-defined max
   if(lot > InpMaxLot) lot = InpMaxLot;
   
   // Round to avoid floating point issues
   lot = NormalizeDouble(lot, 2);
   
   return lot;
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
//| Calculate Dollar-Neutral Lot Sizes (v3.3.4)                        |
//+------------------------------------------------------------------+
void CalculateDollarNeutralLots(int pairIndex)
{
   double baseLot = InpBaseLot;
   double hedgeRatio = g_pairs[pairIndex].hedgeRatio;
   
   string symbolA = g_pairs[pairIndex].symbolA;
   string symbolB = g_pairs[pairIndex].symbolB;
   
   double pipValueA = GetPipValue(symbolA);
   double pipValueB = GetPipValue(symbolB);
   
   // v3.3.4: Enhanced validation with warning logs
   if(pipValueA == 0 || pipValueB == 0)
   {
      PrintFormat("WARNING Pair %d: Pip values invalid (A:%.5f B:%.5f) - Using normalized base lot %.2f for both",
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
   
   // v3.3.4: Debug log for lot calculation
   if(InpDebugMode)
   {
      PrintFormat("Pair %d Lots: A=%.2f B=%.2f (BaseLot=%.2f, Beta=%.4f, PipA=%.5f, PipB=%.5f)", 
                  pairIndex + 1, lotA, lotB, baseLot, hedgeRatio, pipValueA, pipValueB);
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
//| Calculate CDC Action Zone for Single Symbol (v3.5.0)               |
//+------------------------------------------------------------------+
void CalculateCDCForSymbol(string symbol, string &trend, double &fastEMA, double &slowEMA)
{
   trend = "NEUTRAL";
   fastEMA = 0;
   slowEMA = 0;
   
   double closeArr[], highArr[], lowArr[], openArr[];
   ArraySetAsSeries(closeArr, true);
   ArraySetAsSeries(highArr, true);
   ArraySetAsSeries(lowArr, true);
   ArraySetAsSeries(openArr, true);
   
   int barsNeeded = InpCDCSlowPeriod * 3 + 50;
   
   if(CopyClose(symbol, InpCDCTimeframe, 0, barsNeeded, closeArr) < barsNeeded) return;
   if(CopyHigh(symbol, InpCDCTimeframe, 0, barsNeeded, highArr) < barsNeeded) return;
   if(CopyLow(symbol, InpCDCTimeframe, 0, barsNeeded, lowArr) < barsNeeded) return;
   if(CopyOpen(symbol, InpCDCTimeframe, 0, barsNeeded, openArr) < barsNeeded) return;
   
   // Calculate OHLC4
   double ohlc4[];
   ArrayResize(ohlc4, barsNeeded);
   for(int i = 0; i < barsNeeded; i++)
      ohlc4[i] = (openArr[i] + highArr[i] + lowArr[i] + closeArr[i]) / 4.0;
   
   // Calculate AP (Smoothed OHLC4 with EMA2)
   double ap[];
   ArrayResize(ap, barsNeeded);
   CalculateCDC_EMA(ohlc4, ap, 2, barsNeeded);
   
   // Calculate Fast & Slow EMA
   double fast[], slow[];
   ArrayResize(fast, barsNeeded);
   ArrayResize(slow, barsNeeded);
   CalculateCDC_EMA(ap, fast, InpCDCFastPeriod, barsNeeded);
   CalculateCDC_EMA(ap, slow, InpCDCSlowPeriod, barsNeeded);
   
   fastEMA = fast[0];
   slowEMA = slow[0];
   
   // Determine Trend
   if(InpRequireStrongTrend)
   {
      // Require actual crossover
      bool crossUp = (fast[1] <= slow[1] && fast[0] > slow[0]);
      bool crossDown = (fast[1] >= slow[1] && fast[0] < slow[0]);
      
      if(crossUp) trend = "BULLISH";
      else if(crossDown) trend = "BEARISH";
   }
   else
   {
      // Just check relative position
      if(fast[0] > slow[0]) trend = "BULLISH";
      else if(fast[0] < slow[0]) trend = "BEARISH";
   }
}

//+------------------------------------------------------------------+
//| Update CDC Trend Data for Single Pair (v3.5.0)                     |
//+------------------------------------------------------------------+
void UpdateCDCForPair(int pairIndex)
{
   if(!InpUseCDCTrendFilter) return;
   if(!g_pairs[pairIndex].enabled) return;
   
   CalculateCDCForSymbol(
      g_pairs[pairIndex].symbolA,
      g_pairs[pairIndex].cdcTrendA,
      g_pairs[pairIndex].cdcFastA,
      g_pairs[pairIndex].cdcSlowA
   );
   
   CalculateCDCForSymbol(
      g_pairs[pairIndex].symbolB,
      g_pairs[pairIndex].cdcTrendB,
      g_pairs[pairIndex].cdcFastB,
      g_pairs[pairIndex].cdcSlowB
   );
}

//+------------------------------------------------------------------+
//| Update CDC for All Enabled Pairs (v3.5.0)                          |
//+------------------------------------------------------------------+
void UpdateAllPairsCDC()
{
   if(!InpUseCDCTrendFilter) return;
   
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(g_pairs[i].enabled)
         UpdateCDCForPair(i);
   }
}

//+------------------------------------------------------------------+
//| Check CDC Trend Confirmation for Entry (v3.5.0)                    |
//| Logic:                                                             |
//|   - Positive Correlation: Both symbols SAME trend                  |
//|   - Negative Correlation: Both symbols OPPOSITE trend              |
//+------------------------------------------------------------------+
bool CheckCDCTrendConfirmation(int pairIndex, string side)
{
   // If filter is disabled, always confirm
   if(!InpUseCDCTrendFilter) return true;
   
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
         if(InpDebugMode && (!g_isTesterMode || !InpDisableDebugInTester))
            PrintFormat("CDC BLOCK: Pair %d (Pos Corr) - Trends differ (A:%s B:%s)", 
                        pairIndex + 1, trendA, trendB);
         return false;
      }
   }
   else  // Negative Correlation (corrType == -1)
   {
      // Require OPPOSITE trends
      if(!oppositeTrend)
      {
         if(InpDebugMode && (!g_isTesterMode || !InpDisableDebugInTester))
            PrintFormat("CDC BLOCK: Pair %d (Neg Corr) - Trends same (A:%s B:%s)", 
                        pairIndex + 1, trendA, trendB);
         return false;
      }
   }
   
   if(InpDebugMode && (!g_isTesterMode || !InpDisableDebugInTester))
      PrintFormat("CDC CONFIRM: Pair %d - A:%s B:%s (CorrType:%d)", 
                  pairIndex + 1, trendA, trendB, corrType);
   
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
   int handle = iADX(symbol, timeframe, period);
   if(handle == INVALID_HANDLE)
   {
      if(InpDebugMode && (!g_isTesterMode || !InpDisableDebugInTester))
         PrintFormat("ADX: Failed to create handle for %s", symbol);
      return 0;
   }
   
   double buffer[];
   ArraySetAsSeries(buffer, true);
   
   if(CopyBuffer(handle, 0, 0, 1, buffer) < 1)
   {
      IndicatorRelease(handle);
      return 0;
   }
   
   double adxValue = buffer[0];
   IndicatorRelease(handle);
   
   return adxValue;
}

//+------------------------------------------------------------------+
//| Update ADX Values for Negative Correlation Pair (v3.5.3 HF3)       |
//+------------------------------------------------------------------+
void UpdateADXForPair(int pairIndex)
{
   if(!InpUseADXForNegative) return;
   if(g_pairs[pairIndex].correlationType != -1) return;  // Only for Negative Correlation
   if(!g_pairs[pairIndex].enabled) return;
   
   g_pairs[pairIndex].adxValueA = GetADXValue(g_pairs[pairIndex].symbolA, InpADXTimeframe, InpADXPeriod);
   g_pairs[pairIndex].adxValueB = GetADXValue(g_pairs[pairIndex].symbolB, InpADXTimeframe, InpADXPeriod);
   
   if(InpDebugMode && (!g_isTesterMode || !InpDisableDebugInTester))
   {
      PrintFormat("ADX UPDATE [Pair %d NEG]: %s=%.1f, %s=%.1f",
                  pairIndex + 1,
                  g_pairs[pairIndex].symbolA, g_pairs[pairIndex].adxValueA,
                  g_pairs[pairIndex].symbolB, g_pairs[pairIndex].adxValueB);
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
//| Analyze All Pairs for Trading Signals (v3.5.2)                     |
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
//| Check All Pairs for Grid Loss Side (v3.6.0)                        |
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
         // === v3.5.2: Check Grid Trading Guard for BUY Side ===
         string pauseReasonBuy = "";
         if(!CheckGridTradingAllowed(i, "BUY", pauseReasonBuy))
         {
            // BUY Grid is PAUSED
         }
         else
         {
            // v3.3.0: Total orders check
            int totalBuyOrders = 1 + g_pairs[i].avgOrderCountBuy;
            if(totalBuyOrders < g_pairs[i].maxOrderBuy && 
               g_pairs[i].avgOrderCountBuy < InpMaxGridLossOrders)
            {
               CheckGridLossForSide(i, "BUY");
            }
         }
      }
      
      // Check Sell Side - Grid Loss (price going UP = losing for SELL)
      if(g_pairs[i].directionSell == 1 && !g_pairs[i].justOpenedMainSell)
      {
         // === v3.5.2: Check Grid Trading Guard for SELL Side ===
         string pauseReasonSell = "";
         if(!CheckGridTradingAllowed(i, "SELL", pauseReasonSell))
         {
            // SELL Grid is PAUSED
         }
         else
         {
            // v3.3.0: Total orders check
            int totalSellOrders = 1 + g_pairs[i].avgOrderCountSell;
            if(totalSellOrders < g_pairs[i].maxOrderSell && 
               g_pairs[i].avgOrderCountSell < InpMaxGridLossOrders)
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
      // ATR, Fixed Points, Fixed Pips - v3.6.0 HF1: Use separate ATR settings
      double gridDist = CalculateGridDistance(pairIndex, InpGridLossDistMode,
                                               InpGridLossATRMult, 
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
//| Check All Pairs for Grid Profit Side (v3.6.0)                      |
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
         if(g_pairs[i].gridProfitCountBuy < InpMaxGridProfitOrders)
         {
            CheckGridProfitForSide(i, "BUY");
         }
      }
      
      // Check SELL Side - Profit Grid (price going DOWN = profitable for SELL)
      if(g_pairs[i].directionSell == 1 && !g_pairs[i].justOpenedMainSell)
      {
         if(g_pairs[i].gridProfitCountSell < InpMaxGridProfitOrders)
         {
            CheckGridProfitForSide(i, "SELL");
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
      // ATR, Fixed Points, Fixed Pips - v3.6.0 HF1: Use separate ATR settings
      double gridDist = CalculateGridDistance(pairIndex, InpGridProfitDistMode,
                                               InpGridProfitATRMult,
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
//| Calculate Grid Distance (v3.6.0 HF1)                               |
//+------------------------------------------------------------------+
double CalculateGridDistance(int pairIndex, ENUM_GRID_DISTANCE_MODE mode, 
                              double atrMult, double fixedPoints, double fixedPips,
                              ENUM_TIMEFRAMES atrTimeframe, int atrPeriod)
{
   string symbolA = g_pairs[pairIndex].symbolA;
   double point = SymbolInfoDouble(symbolA, SYMBOL_POINT);
   
   switch(mode)
   {
      case GRID_DIST_ATR:
      {
         double atr = CalculateSimplifiedATR(symbolA, atrTimeframe, atrPeriod);
         return atr * atrMult;
      }
      case GRID_DIST_FIXED_POINTS:
         return fixedPoints * point;
         
      case GRID_DIST_FIXED_PIPS:
      {
         // 1 pip = 10 points for 5-digit brokers
         int digits = (int)SymbolInfoInteger(symbolA, SYMBOL_DIGITS);
         double pipSize = (digits == 3 || digits == 5) ? point * 10 : point;
         return fixedPips * pipSize;
      }
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
         // Use existing CalculateTrendBasedLots() function
         CalculateTrendBasedLots(pairIndex, side, baseLotA, baseLotB, outLotA, outLotB, isGridOrder);
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
   
   for(int i = 0; i < period; i++)
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
//| Calculate Trend-Based Lots for Grid Orders (v3.5.3 HF1)            |
//| side: "BUY" or "SELL" - the hedge side (not individual symbol)     |
//| isGridOrder: true = Grid/Averaging order, false = Main entry       |
//| Returns: Adjusted lotA and lotB via reference                       |
//+------------------------------------------------------------------+
void CalculateTrendBasedLots(int pairIndex, string side, 
                              double baseLotA, double baseLotB,
                              double &adjustedLotA, double &adjustedLotB,
                              bool isGridOrder = false)
{
   string symbolA = g_pairs[pairIndex].symbolA;
   string symbolB = g_pairs[pairIndex].symbolB;
   
   // Default: no adjustment
   adjustedLotA = baseLotA;
   adjustedLotB = baseLotB;
   
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
      
      // === v3.5.3 HF2: Use InpBaseLot as foundation for ATR Trend Mode ===
      // This fixes the issue where lotBuyA/B and lotSellA/B were influenced by Beta × Pip Ratio
      double initialLotA = NormalizeLot(symbolA, InpBaseLot);
      double initialLotB = NormalizeLot(symbolB, InpBaseLot);
      
      // === Calculate Effective Base Lots ===
      double effectiveBaseLotA = initialLotA;
      double effectiveBaseLotB = initialLotB;
      
      // For Grid Orders with Compounding (Trend-Aligned side only)
      if(isGridOrder && InpLotProgression == LOT_PROG_COMPOUNDING)
      {
         // Use LAST Grid Lot as base for compounding (Trend-Aligned side only)
         // Counter-Trend side will be reset to initialLot below
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
         PrintFormat("TREND LOT [Pair %d %s %s %s]: A(%s)=%.2f×%.2f=%.2f [%s:%s] | B(%s)=%.2f×%.2f=%.2f [%s:%s] [Base=%.2f]",
                     pairIndex + 1, corrStr, side, progMode,
                     symbolA, effectiveBaseLotA, multA, adjustedLotA, directionA, isTrendAlignedA ? "TREND" : "COUNTER",
                     symbolB, effectiveBaseLotB, multB, adjustedLotB, directionB, isTrendAlignedB ? "TREND" : "COUNTER",
                     InpBaseLot);
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
   
   CalculateGridLots(pairIndex, "BUY", InpGridLossLotType,
                     InpGridLossCustomLot, InpGridLossLotMultiplier,
                     baseLotA, baseLotB, lotA, lotB, true, false);
   
   // v3.5.3 HF4: Force update ADX before opening trade for Negative Correlation
   if(corrType == -1 && InpUseADXForNegative)
   {
      UpdateADXForPair(pairIndex);
   }
   
   // Build comment
   string comment;
   if(corrType == -1 && InpUseADXForNegative)
   {
      comment = StringFormat("StatArb_GL_BUY_%d[ADX:%.0f|%.0f]", 
                             pairIndex + 1,
                             g_pairs[pairIndex].adxValueA,
                             g_pairs[pairIndex].adxValueB);
   }
   else
   {
      comment = StringFormat("StatArb_GL_BUY_%d", pairIndex + 1);
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
   
   CalculateGridLots(pairIndex, "SELL", InpGridLossLotType,
                     InpGridLossCustomLot, InpGridLossLotMultiplier,
                     baseLotA, baseLotB, lotA, lotB, true, false);
   
   // v3.5.3 HF4: Force update ADX before opening trade for Negative Correlation
   if(corrType == -1 && InpUseADXForNegative)
   {
      UpdateADXForPair(pairIndex);
   }
   
   // Build comment
   string comment;
   if(corrType == -1 && InpUseADXForNegative)
   {
      comment = StringFormat("StatArb_GL_SELL_%d[ADX:%.0f|%.0f]", 
                             pairIndex + 1,
                             g_pairs[pairIndex].adxValueA,
                             g_pairs[pairIndex].adxValueB);
   }
   else
   {
      comment = StringFormat("StatArb_GL_SELL_%d", pairIndex + 1);
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
   
   CalculateGridLots(pairIndex, "BUY", InpGridProfitLotType,
                     InpGridProfitCustomLot, InpGridProfitLotMultiplier,
                     baseLotA, baseLotB, lotA, lotB, true, true);
   
   // v3.5.3 HF4: Force update ADX before opening trade for Negative Correlation
   if(corrType == -1 && InpUseADXForNegative)
   {
      UpdateADXForPair(pairIndex);
   }
   
   // Build comment
   string comment;
   if(corrType == -1 && InpUseADXForNegative)
   {
      comment = StringFormat("StatArb_GP_BUY_%d[ADX:%.0f|%.0f]", 
                             pairIndex + 1,
                             g_pairs[pairIndex].adxValueA,
                             g_pairs[pairIndex].adxValueB);
   }
   else
   {
      comment = StringFormat("StatArb_GP_BUY_%d", pairIndex + 1);
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
   
   CalculateGridLots(pairIndex, "SELL", InpGridProfitLotType,
                     InpGridProfitCustomLot, InpGridProfitLotMultiplier,
                     baseLotA, baseLotB, lotA, lotB, true, true);
   
   // v3.5.3 HF4: Force update ADX before opening trade for Negative Correlation
   if(corrType == -1 && InpUseADXForNegative)
   {
      UpdateADXForPair(pairIndex);
   }
   
   // Build comment
   string comment;
   if(corrType == -1 && InpUseADXForNegative)
   {
      comment = StringFormat("StatArb_GP_SELL_%d[ADX:%.0f|%.0f]", 
                             pairIndex + 1,
                             g_pairs[pairIndex].adxValueA,
                             g_pairs[pairIndex].adxValueB);
   }
   else
   {
      comment = StringFormat("StatArb_GP_SELL_%d", pairIndex + 1);
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
   
   // v3.5.3 HF3: Add ADX values in comment for Negative Correlation pairs
   string comment;
   if(corrType == -1 && InpUseADXForNegative)
   {
      comment = StringFormat("StatArb_BUY_%d[ADX:%.0f|%.0f]", 
                             pairIndex + 1,
                             g_pairs[pairIndex].adxValueA,
                             g_pairs[pairIndex].adxValueB);
   }
   else
   {
      comment = StringFormat("StatArb_BUY_%d", pairIndex + 1);
   }
   
   ulong ticketA = 0;
   ulong ticketB = 0;
   
   // Open Buy on Symbol A
   double askA = SymbolInfoDouble(symbolA, SYMBOL_ASK);
   if(g_trade.Buy(lotA, symbolA, askA, 0, 0, comment))
   {
      ticketA = g_trade.ResultOrder();
   }
   else
   {
      PrintFormat("Failed to open BUY on %s: %d", symbolA, GetLastError());
      return false;
   }
   
   // Open position on Symbol B based on correlation type
   if(corrType == 1)  // Positive correlation: Sell B
   {
      double bidB = SymbolInfoDouble(symbolB, SYMBOL_BID);
      if(g_trade.Sell(lotB, symbolB, bidB, 0, 0, comment))
      {
         ticketB = g_trade.ResultOrder();
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
   
   // v3.6.0: Store initial entry price for Grid Profit Side
   g_pairs[pairIndex].initialEntryPriceBuy = SymbolInfoDouble(symbolA, SYMBOL_ASK);
   g_pairs[pairIndex].lastProfitPriceBuy = 0;
   g_pairs[pairIndex].gridProfitCountBuy = 0;
   g_pairs[pairIndex].gridProfitZLevelBuy = 0;
   
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
   
   // v3.5.3 HF3: Add ADX values in comment for Negative Correlation pairs
   string comment;
   if(corrType == -1 && InpUseADXForNegative)
   {
      comment = StringFormat("StatArb_SELL_%d[ADX:%.0f|%.0f]", 
                             pairIndex + 1,
                             g_pairs[pairIndex].adxValueA,
                             g_pairs[pairIndex].adxValueB);
   }
   else
   {
      comment = StringFormat("StatArb_SELL_%d", pairIndex + 1);
   }
   
   ulong ticketA = 0;
   ulong ticketB = 0;
   
   // Open Sell on Symbol A
   double bidA = SymbolInfoDouble(symbolA, SYMBOL_BID);
   if(g_trade.Sell(lotA, symbolA, bidA, 0, 0, comment))
   {
      ticketA = g_trade.ResultOrder();
   }
   else
   {
      PrintFormat("Failed to open SELL on %s: %d", symbolA, GetLastError());
      return false;
   }
   
   // Open position on Symbol B based on correlation type
   if(corrType == 1)  // Positive correlation: Buy B
   {
      double askB = SymbolInfoDouble(symbolB, SYMBOL_ASK);
      if(g_trade.Buy(lotB, symbolB, askB, 0, 0, comment))
      {
         ticketB = g_trade.ResultOrder();
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
   
   // v3.6.0: Store initial entry price for Grid Profit Side
   g_pairs[pairIndex].initialEntryPriceSell = SymbolInfoDouble(symbolA, SYMBOL_BID);
   g_pairs[pairIndex].lastProfitPriceSell = 0;
   g_pairs[pairIndex].gridProfitCountSell = 0;
   g_pairs[pairIndex].gridProfitZLevelSell = 0;
   
   PrintFormat("Pair %d SELL SIDE OPENED: SELL %s | %s %s | Z=%.2f | Corr=%s",
      pairIndex + 1, symbolA,
      corrType == 1 ? "BUY" : "SELL", symbolB,
      g_pairs[pairIndex].zScore,
      corrType == 1 ? "Positive" : "Negative");
   
   return true;
}

//+------------------------------------------------------------------+
//| Close Buy Side Trade (v3.6.0 HF3 - with EA Close Flag)             |
//+------------------------------------------------------------------+
bool CloseBuySide(int pairIndex)
{
   if(g_pairs[pairIndex].directionBuy == 0) return false;
   
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
      PrintFormat("Pair %d BUY SIDE CLOSED | Profit: %.2f", pairIndex + 1, g_pairs[pairIndex].profitBuy);
      
      // v3.2.9: Accumulate closed P/L before reset
      g_pairs[pairIndex].closedProfitBuy += g_pairs[pairIndex].profitBuy;
      
      // v3.6.0 HF3 Patch 3: Only add to basket if NOT in Basket Close mode
      // (Basket mode closes all at once and resets - avoid double counting)
      if(!g_basketCloseMode)
      {
         g_basketClosedProfit += g_pairs[pairIndex].profitBuy;
         PrintFormat("BASKET: Added %.2f from Pair %d BUY | Total Closed: %.2f | Target: %.2f",
                     g_pairs[pairIndex].profitBuy, pairIndex + 1, g_basketClosedProfit, g_totalTarget);
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
//| Close Sell Side Trade (v3.6.0 HF3 - with EA Close Flag)            |
//+------------------------------------------------------------------+
bool CloseSellSide(int pairIndex)
{
   if(g_pairs[pairIndex].directionSell == 0) return false;
   
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
      PrintFormat("Pair %d SELL SIDE CLOSED | Profit: %.2f", pairIndex + 1, g_pairs[pairIndex].profitSell);
      
      // v3.2.9: Accumulate closed P/L before reset
      g_pairs[pairIndex].closedProfitSell += g_pairs[pairIndex].profitSell;
      
      // v3.6.0 HF3 Patch 3: Only add to basket if NOT in Basket Close mode
      // (Basket mode closes all at once and resets - avoid double counting)
      if(!g_basketCloseMode)
      {
         g_basketClosedProfit += g_pairs[pairIndex].profitSell;
         PrintFormat("BASKET: Added %.2f from Pair %d SELL | Total Closed: %.2f | Target: %.2f",
                     g_pairs[pairIndex].profitSell, pairIndex + 1, g_basketClosedProfit, g_totalTarget);
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
   
   // v3.6.0: Close all grid orders - Grid Loss, Grid Profit, and old AVG format
   string commentGL = StringFormat("StatArb_GL_%s_%d", side, pairIndex + 1);
   string commentGP = StringFormat("StatArb_GP_%s_%d", side, pairIndex + 1);
   string commentAVG = StringFormat("StatArb_AVG_%s_%d", side, pairIndex + 1);  // Legacy support
   
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
         
         // Match symbol AND any of the grid comments
         if((posSymbol == symbolA || posSymbol == symbolB) &&
            (StringFind(posComment, commentGL) >= 0 || 
             StringFind(posComment, commentGP) >= 0 ||
             StringFind(posComment, commentAVG) >= 0))
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
//| Force Close Buy Side (v3.3.2 - Close ALL related positions)        |
//+------------------------------------------------------------------+
void ForceCloseBuySide(int pairIndex)
{
   string symbolA = g_pairs[pairIndex].symbolA;
   string symbolB = g_pairs[pairIndex].symbolB;
   string mainComment = StringFormat("StatArb_BUY_%d", pairIndex + 1);
   string avgComment = StringFormat("StatArb_AVG_BUY_%d", pairIndex + 1);
   
   // Close ALL positions on both symbols with matching comments
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      
      string posSymbol = PositionGetString(POSITION_SYMBOL);
      string posComment = PositionGetString(POSITION_COMMENT);
      
      // Close if symbol matches AND comment matches
      if((posSymbol == symbolA || posSymbol == symbolB) &&
         (StringFind(posComment, mainComment) >= 0 || StringFind(posComment, avgComment) >= 0))
      {
         g_trade.PositionClose(ticket);
         PrintFormat("Force closed ticket %d (%s)", ticket, posSymbol);
      }
   }
   
   // v3.2.9: Accumulate closed P/L before reset
   g_pairs[pairIndex].closedProfitBuy += g_pairs[pairIndex].profitBuy;
   
   // v3.6.0 HF3 Patch 3: Only add to basket if NOT in Basket Close mode
   if(!g_basketCloseMode)
   {
      g_basketClosedProfit += g_pairs[pairIndex].profitBuy;
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
//| Force Close Sell Side (v3.3.2 - Close ALL related positions)       |
//+------------------------------------------------------------------+
void ForceCloseSellSide(int pairIndex)
{
   string symbolA = g_pairs[pairIndex].symbolA;
   string symbolB = g_pairs[pairIndex].symbolB;
   string mainComment = StringFormat("StatArb_SELL_%d", pairIndex + 1);
   string avgComment = StringFormat("StatArb_AVG_SELL_%d", pairIndex + 1);
   
   // Close ALL positions on both symbols with matching comments
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      
      string posSymbol = PositionGetString(POSITION_SYMBOL);
      string posComment = PositionGetString(POSITION_COMMENT);
      
      // Close if symbol matches AND comment matches
      if((posSymbol == symbolA || posSymbol == symbolB) &&
         (StringFind(posComment, mainComment) >= 0 || StringFind(posComment, avgComment) >= 0))
      {
         g_trade.PositionClose(ticket);
         PrintFormat("Force closed ticket %d (%s)", ticket, posSymbol);
      }
   }
   
   // v3.2.9: Accumulate closed P/L before reset
   g_pairs[pairIndex].closedProfitSell += g_pairs[pairIndex].profitSell;
   
   // v3.6.0 HF3 Patch 3: Only add to basket if NOT in Basket Close mode
   if(!g_basketCloseMode)
   {
      g_basketClosedProfit += g_pairs[pairIndex].profitSell;
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
//| Update Pair Profits                                                |
//+------------------------------------------------------------------+
void UpdatePairProfits()
{
   g_totalCurrentProfit = 0;
   
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(!g_pairs[i].enabled) continue;
      
      double buyProfit = 0;
      double sellProfit = 0;
      
      // Calculate Buy side profit
      if(g_pairs[i].directionBuy == 1)
      {
         buyProfit = GetPositionProfit(g_pairs[i].ticketBuyA) + GetPositionProfit(g_pairs[i].ticketBuyB);
         
         // v3.6.0 HF2: Add ALL grid positions profit
         // Legacy Averaging (backward compatibility)
         string avgBuyComment = StringFormat("StatArb_AVG_BUY_%d", i + 1);
         buyProfit += GetAveragingProfit(avgBuyComment);
         
         // Grid Loss positions
         string glBuyComment = StringFormat("StatArb_GL_BUY_%d", i + 1);
         buyProfit += GetAveragingProfit(glBuyComment);
         
         // Grid Profit positions
         string gpBuyComment = StringFormat("StatArb_GP_BUY_%d", i + 1);
         buyProfit += GetAveragingProfit(gpBuyComment);
      }
      
      // Calculate Sell side profit
      if(g_pairs[i].directionSell == 1)
      {
         sellProfit = GetPositionProfit(g_pairs[i].ticketSellA) + GetPositionProfit(g_pairs[i].ticketSellB);
         
         // v3.6.0 HF2: Add ALL grid positions profit
         // Legacy Averaging (backward compatibility)
         string avgSellComment = StringFormat("StatArb_AVG_SELL_%d", i + 1);
         sellProfit += GetAveragingProfit(avgSellComment);
         
         // Grid Loss positions
         string glSellComment = StringFormat("StatArb_GL_SELL_%d", i + 1);
         sellProfit += GetAveragingProfit(glSellComment);
         
         // Grid Profit positions
         string gpSellComment = StringFormat("StatArb_GP_SELL_%d", i + 1);
         sellProfit += GetAveragingProfit(gpSellComment);
      }
      
      g_pairs[i].profitBuy = buyProfit;
      g_pairs[i].profitSell = sellProfit;
      g_pairs[i].totalPairProfit = buyProfit + sellProfit;
      
      g_totalCurrentProfit += g_pairs[i].totalPairProfit;
   }
}

//+------------------------------------------------------------------+
//| Get Position Profit by Ticket                                      |
//+------------------------------------------------------------------+
double GetPositionProfit(ulong ticket)
{
   if(ticket == 0) return 0;
   
   if(PositionSelectByTicket(ticket))
   {
      return PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   
   return 0;
}

//+------------------------------------------------------------------+
//| Get Averaging Positions Profit                                     |
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
            totalProfit += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
         }
      }
   }
   
   return totalProfit;
}

//+------------------------------------------------------------------+
//| Check Pair Targets                                                 |
//+------------------------------------------------------------------+
void CheckPairTargets()
{
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(!g_pairs[i].enabled) continue;
      
      // Check Buy side target
      if(g_pairs[i].directionBuy == 1 && g_pairs[i].targetBuy > 0)
      {
         if(g_pairs[i].profitBuy >= g_pairs[i].targetBuy)
         {
            PrintFormat("Pair %d BUY TARGET HIT: %.2f >= %.2f", 
                        i + 1, g_pairs[i].profitBuy, g_pairs[i].targetBuy);
            CloseBuySide(i);
         }
      }
      
      // Check Sell side target
      if(g_pairs[i].directionSell == 1 && g_pairs[i].targetSell > 0)
      {
         if(g_pairs[i].profitSell >= g_pairs[i].targetSell)
         {
            PrintFormat("Pair %d SELL TARGET HIT: %.2f >= %.2f", 
                        i + 1, g_pairs[i].profitSell, g_pairs[i].targetSell);
            CloseSellSide(i);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check Basket Profit Target (v3.6.0 HF3)                            |
//+------------------------------------------------------------------+
void CheckTotalTarget()
{
   // v3.6.0 HF3: Calculate Basket Totals (always calculate for dashboard)
   g_basketFloatingProfit = g_totalCurrentProfit;
   g_basketTotalProfit = g_basketClosedProfit + g_basketFloatingProfit;
   
   // Disable if both targets are 0
   if(g_totalTarget <= 0 && InpBasketFloatingTarget <= 0) return;
   
   bool shouldCloseAll = false;
   string closeReason = "";
   
   // Check 1: TOTAL Profit Target (Closed + Floating) - v3.6.0 HF3 Patch 2
   // This is the main basket target check - closes when combined profit reaches target
   if(g_totalTarget > 0 && g_basketTotalProfit >= g_totalTarget)
   {
      shouldCloseAll = true;
      closeReason = StringFormat("Total Profit %.2f (Closed: %.2f + Floating: %.2f) >= Target %.2f", 
                                  g_basketTotalProfit, g_basketClosedProfit, g_basketFloatingProfit, g_totalTarget);
   }
   
   // Check 2: Floating-Only Profit Target (Optional - for special use cases)
   // This triggers ONLY on floating profit, ignoring accumulated closed profit
   if(!shouldCloseAll && InpBasketFloatingTarget > 0 && 
      g_basketFloatingProfit >= InpBasketFloatingTarget)
   {
      shouldCloseAll = true;
      closeReason = StringFormat("Floating Only %.2f >= Target %.2f", 
                                  g_basketFloatingProfit, InpBasketFloatingTarget);
   }
   
   // Execute close if any condition met
   if(shouldCloseAll && !g_basketTargetTriggered)
   {
      g_basketTargetTriggered = true;
      g_basketCloseMode = true;      // v3.6.0 HF3 Patch 3: Mark as basket close (don't accumulate)
      g_orphanCheckPaused = true;    // v3.6.0 HF3 Patch 3: Prevent Orphan Detection
      
      PrintFormat(">>> BASKET TARGET REACHED: %s <<<", closeReason);
      PrintFormat(">>> Closing ALL positions and resetting basket... <<<");
      
      // Close ALL open positions across all pairs
      for(int i = 0; i < MAX_PAIRS; i++)
      {
         if(g_pairs[i].directionBuy == 1)
         {
            PrintFormat(">>> BASKET: Closing Pair %d BUY (Floating: %.2f)", 
                        i + 1, g_pairs[i].profitBuy);
            CloseBuySide(i);
         }
         if(g_pairs[i].directionSell == 1)
         {
            PrintFormat(">>> BASKET: Closing Pair %d SELL (Floating: %.2f)", 
                        i + 1, g_pairs[i].profitSell);
            CloseSellSide(i);
         }
      }
      
      g_basketCloseMode = false;     // v3.6.0 HF3 Patch 3: Reset basket mode
      g_orphanCheckPaused = false;   // v3.6.0 HF3 Patch 3: Resume orphan detection
      
      // Reset Basket after all positions closed
      ResetBasketProfit();
   }
}

//+------------------------------------------------------------------+
//| Reset Basket Profit (v3.6.0 HF3)                                   |
//+------------------------------------------------------------------+
void ResetBasketProfit()
{
   PrintFormat(">>> BASKET RESET: Previous Closed %.2f | New Closed: 0.00 <<<",
               g_basketClosedProfit);
   
   // v3.6.0 HF2 Patch 2: Reset ONLY basket accumulator
   // Per-pair closedProfitBuy/Sell are kept for dashboard display
   g_basketClosedProfit = 0;
   g_basketFloatingProfit = 0;
   g_basketTotalProfit = 0;
   g_basketTargetTriggered = false;
   
   // REMOVED: Do NOT reset per-pair closed profit
   // closedProfitBuy and closedProfitSell are displayed on dashboard
   // and should persist across basket cycles
   
   PrintFormat(">>> BASKET: Ready for new cycle <<<");
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
   
   // v3.3.0: Add EA Title Row
   int titleHeight = 22;
   CreateRectangle(prefix + "TITLE_BG", PANEL_X, PANEL_Y, PANEL_WIDTH, titleHeight, C'20,40,60', C'20,40,60');
   CreateLabel(prefix + "TITLE_NAME", PANEL_X + 10, PANEL_Y + 4, 
               "Multi-Currency Statistical EA v3.5.0 - MoneyX Trading", 
               COLOR_GOLD, 10, "Arial Bold");
   
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
   
   // ===== COLUMN HEADER BACKGROUNDS (v3.2.9: Separate row with background) =====
   CreateRectangle(prefix + "COLHDR_BUY_BG", buyStartX, colHeaderY - 1, buyWidth, colHeaderHeight, C'10,60,100', C'10,60,100');
   CreateRectangle(prefix + "COLHDR_CENTER_BG", centerX, colHeaderY - 1, centerWidth, colHeaderHeight, C'40,45,60', C'40,45,60');
   CreateRectangle(prefix + "COLHDR_SELL_BG", sellStartX, colHeaderY - 1, sellWidth, colHeaderHeight, C'100,40,40', C'100,40,40');
   
   // ===== COLUMN HEADERS (v3.2.9: Labels on top of backgrounds) =====
   int colLabelY = colHeaderY + 2;  // Center text vertically in column header row
   
   // Buy columns: X | Closed | Lot | Ord | Tot | Target | Status | Z | P/L
   CreateLabel(prefix + "COL_B_X", buyStartX + 5, colLabelY, "X", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_B_PF", buyStartX + 25, colLabelY, "Closed", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_B_LT", buyStartX + 75, colLabelY, "Lot", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_B_OR", buyStartX + 128, colLabelY, "Ord", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_B_MX", buyStartX + 165, colLabelY, "Tot", COLOR_HEADER_TXT, 7, "Arial");  // v3.3.0: Changed to "Tot" (Total)
   CreateLabel(prefix + "COL_B_TG", buyStartX + 205, colLabelY, "Target", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_B_ST", buyStartX + 260, colLabelY, "Status", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_B_Z", buyStartX + 310, colLabelY, "Z", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_B_PL", buyStartX + 358, colLabelY, "P/L", COLOR_HEADER_TXT, 7, "Arial");
   
   // Center columns: Pair | Trend | C-% | Type | Total P/L (v3.6.0 HF4: Beta hidden)
   CreateLabel(prefix + "COL_C_PR", centerX + 10, colLabelY, "Pair", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_C_TRD", centerX + 145, colLabelY, "Trend", COLOR_HEADER_TXT, 7, "Arial");  // v3.5.0: CDC Trend column
   CreateLabel(prefix + "COL_C_CR", centerX + 195, colLabelY, "C-%", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_C_TY", centerX + 235, colLabelY, "Type", COLOR_HEADER_TXT, 7, "Arial");
   // v3.6.0 HF4: Beta column hidden - not frequently used
   // CreateLabel(prefix + "COL_C_BT", centerX + 280, colLabelY, "Beta", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_C_TP", centerX + 290, colLabelY, "Tot P/L", COLOR_HEADER_TXT, 7, "Arial");
   
   // Sell columns: P/L | Z | Status | Target | Tot | Ord | Lot | Closed | X
   CreateLabel(prefix + "COL_S_PL", sellStartX + 5, colLabelY, "P/L", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_S_Z", sellStartX + 50, colLabelY, "Z", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_S_ST", sellStartX + 105, colLabelY, "Status", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_S_TG", sellStartX + 155, colLabelY, "Target", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_S_MX", sellStartX + 210, colLabelY, "Tot", COLOR_HEADER_TXT, 7, "Arial");  // v3.3.0: Changed to "Tot" (Total)
   CreateLabel(prefix + "COL_S_OR", sellStartX + 262, colLabelY, "Ord", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_S_LT", sellStartX + 305, colLabelY, "Lot", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_S_PF", sellStartX + 340, colLabelY, "Closed", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_S_X", sellStartX + 378, colLabelY, "X", COLOR_HEADER_TXT, 7, "Arial");
   
   // ===== PAIR ROWS =====
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      int rowY = rowStartY + i * ROW_HEIGHT;
      color rowBg = (i % 2 == 0) ? COLOR_BG_ROW_EVEN : COLOR_BG_ROW_ODD;
      
      // Row backgrounds
      CreateRectangle(prefix + "ROW_B_" + IntegerToString(i), buyStartX, rowY, buyWidth, ROW_HEIGHT - 1, rowBg, rowBg);
      CreateRectangle(prefix + "ROW_C_" + IntegerToString(i), centerX, rowY, centerWidth, ROW_HEIGHT - 1, rowBg, rowBg);
      CreateRectangle(prefix + "ROW_S_" + IntegerToString(i), sellStartX, rowY, sellWidth, ROW_HEIGHT - 1, rowBg, rowBg);
      
      // Create pair row content
      CreatePairRow(prefix, i, buyStartX, centerX, sellStartX, rowY);
   }
   
   // ===== ACCOUNT SUMMARY SECTION =====
   int summaryY = rowStartY + MAX_PAIRS * ROW_HEIGHT + 5;
   CreateAccountSummary(prefix, summaryY);
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Create Pair Row (v3.3.0 - Closed P/L Column)                       |
//+------------------------------------------------------------------+
void CreatePairRow(string prefix, int idx, int buyX, int centerX, int sellX, int y)
{
   string idxStr = IntegerToString(idx);
   string pairName = g_pairs[idx].symbolA + "-" + g_pairs[idx].symbolB;
   
   // === BUY SIDE DATA ===
   // v3.3.0: X | Closed | Lot | Ord | Tot | Target | Status | Z | P/L
   CreateButton(prefix + "_CLOSE_BUY_" + idxStr, buyX + 5, y + 2, 16, 14, "X", clrRed, clrWhite);
   CreateLabel(prefix + "P" + idxStr + "_B_CLOSED", buyX + 25, y + 3, "0", COLOR_TEXT, FONT_SIZE, "Arial");  // Closed P/L
   CreateLabel(prefix + "P" + idxStr + "_B_LOT", buyX + 75, y + 3, "0.00", COLOR_TEXT, FONT_SIZE, "Arial");
   CreateLabel(prefix + "P" + idxStr + "_B_ORD", buyX + 128, y + 3, "0", COLOR_TEXT, FONT_SIZE, "Arial");
   CreateEditField(prefix + "_MAX_BUY_" + idxStr, buyX + 160, y + 2, 30, 14, IntegerToString(InpDefaultMaxOrderBuy));
   CreateEditField(prefix + "_TGT_BUY_" + idxStr, buyX + 200, y + 2, 45, 14, DoubleToString(InpDefaultTargetBuy, 0));
   
   string buyStatusText = g_pairs[idx].enabled ? "Off" : "-";
   color buyStatusColor = COLOR_OFF;
   CreateButton(prefix + "_ST_BUY_" + idxStr, buyX + 255, y + 2, 40, 14, buyStatusText, buyStatusColor, clrWhite);
   CreateLabel(prefix + "P" + idxStr + "_B_Z", buyX + 310, y + 3, "0.00", COLOR_TEXT, FONT_SIZE, "Arial");
   CreateLabel(prefix + "P" + idxStr + "_B_PL", buyX + 358, y + 3, "0", COLOR_TEXT, FONT_SIZE, "Arial");  // Current P/L
   
   // === CENTER DATA ===
   CreateLabel(prefix + "P" + idxStr + "_NAME", centerX + 10, y + 3, pairName, COLOR_TEXT, FONT_SIZE, "Arial Bold");
   // v3.5.0: CDC Trend Status Badge (OK/BLOCK)
   CreateLabel(prefix + "P" + idxStr + "_CDC", centerX + 145, y + 3, "-", COLOR_OFF, FONT_SIZE, "Arial Bold");
   CreateLabel(prefix + "P" + idxStr + "_CORR", centerX + 195, y + 3, "0%", COLOR_TEXT, FONT_SIZE, "Arial");
   CreateLabel(prefix + "P" + idxStr + "_TYPE", centerX + 235, y + 3, "Pos", COLOR_PROFIT, FONT_SIZE, "Arial");
   // v3.6.0 HF4: Beta label hidden
   // CreateLabel(prefix + "P" + idxStr + "_BETA", centerX + 280, y + 3, "1.00", COLOR_TEXT, FONT_SIZE, "Arial");
   CreateLabel(prefix + "P" + idxStr + "_TPL", centerX + 290, y + 3, "0", COLOR_TEXT, 9, "Arial Bold");
   
   // === SELL SIDE DATA ===
   // v3.3.0: P/L | Z | Status | Target | Tot | Ord | Lot | Closed | X
   CreateLabel(prefix + "P" + idxStr + "_S_PL", sellX + 5, y + 3, "0", COLOR_TEXT, FONT_SIZE, "Arial");  // Current P/L
   CreateLabel(prefix + "P" + idxStr + "_S_Z", sellX + 50, y + 3, "0.00", COLOR_TEXT, FONT_SIZE, "Arial");
   
   string sellStatusText = g_pairs[idx].enabled ? "Off" : "-";
   color sellStatusColor = COLOR_OFF;
   CreateButton(prefix + "_ST_SELL_" + idxStr, sellX + 100, y + 2, 40, 14, sellStatusText, sellStatusColor, clrWhite);
   CreateEditField(prefix + "_TGT_SELL_" + idxStr, sellX + 150, y + 2, 45, 14, DoubleToString(InpDefaultTargetSell, 0));
   CreateEditField(prefix + "_MAX_SELL_" + idxStr, sellX + 205, y + 2, 30, 14, IntegerToString(InpDefaultMaxOrderSell));
   CreateLabel(prefix + "P" + idxStr + "_S_ORD", sellX + 262, y + 3, "0", COLOR_TEXT, FONT_SIZE, "Arial");
   CreateLabel(prefix + "P" + idxStr + "_S_LOT", sellX + 305, y + 3, "0.00", COLOR_TEXT, FONT_SIZE, "Arial");
   CreateLabel(prefix + "P" + idxStr + "_S_CLOSED", sellX + 340, y + 3, "0", COLOR_TEXT, FONT_SIZE, "Arial");  // Closed P/L
   CreateButton(prefix + "_CLOSE_SELL_" + idxStr, sellX + 375, y + 2, 16, 14, "X", clrRed, clrWhite);
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
   CreateRectangle(prefix + "BOX1_BG", box1X, y, boxWidth, boxHeight, C'30,35,45', COLOR_BORDER);
   CreateLabel(prefix + "BOX1_HDR", box1X + 10, y + 5, "DETAIL", COLOR_GOLD, 9, "Arial Bold");
   
   CreateLabel(prefix + "L_BAL", box1X + 10, y + 22, "Balance:", COLOR_TEXT_WHITE, 8, "Arial");
   CreateLabel(prefix + "V_BAL", box1X + 80, y + 22, "0.00", COLOR_PROFIT, 9, "Arial Bold");
   
   CreateLabel(prefix + "L_EQ", box1X + 10, y + 38, "Equity:", COLOR_TEXT_WHITE, 8, "Arial");
   CreateLabel(prefix + "V_EQ", box1X + 80, y + 38, "0.00", COLOR_PROFIT, 9, "Arial Bold");
   
   CreateLabel(prefix + "L_MG", box1X + 10, y + 54, "Margin:", COLOR_TEXT_WHITE, 8, "Arial");
   CreateLabel(prefix + "V_MG", box1X + 80, y + 54, "0.00", COLOR_TEXT_WHITE, 9, "Arial");
   
   CreateLabel(prefix + "L_TPL", box1X + 155, y + 22, "Current P/L:", COLOR_TEXT_WHITE, 8, "Arial");
   CreateLabel(prefix + "V_TPL", box1X + 230, y + 22, "0.00", COLOR_PROFIT, 10, "Arial Bold");
   
   CreateLabel(prefix + "L_TTG", box1X + 155, y + 40, "Total Target:", COLOR_TEXT_WHITE, 8, "Arial");
   CreateEditField(prefix + "_TOTAL_TARGET", box1X + 230, y + 38, 50, 16, DoubleToString(g_totalTarget, 0));
   
   // === BOX 2: STATUS ===
   int box2X = startX + boxWidth + gap;
   CreateRectangle(prefix + "BOX2_BG", box2X, y, boxWidth, boxHeight, C'30,35,45', COLOR_BORDER);
   CreateLabel(prefix + "BOX2_HDR", box2X + 10, y + 5, "STATUS", COLOR_GOLD, 9, "Arial Bold");
   
   CreateLabel(prefix + "L_TLOT", box2X + 10, y + 22, "Total Lot:", COLOR_TEXT_WHITE, 8, "Arial");
   CreateLabel(prefix + "V_TLOT", box2X + 80, y + 22, "0.00", COLOR_TEXT_WHITE, 9, "Arial");
   
   CreateLabel(prefix + "L_TORD", box2X + 10, y + 38, "Total Order:", COLOR_TEXT_WHITE, 8, "Arial");
   CreateLabel(prefix + "V_TORD", box2X + 85, y + 38, "0", COLOR_TEXT_WHITE, 9, "Arial");
   
   CreateLabel(prefix + "L_DD", box2X + 155, y + 22, "DD%:", COLOR_TEXT_WHITE, 8, "Arial");
   CreateLabel(prefix + "V_DD", box2X + 195, y + 22, "0.00%", COLOR_LOSS, 9, "Arial Bold");
   
   CreateLabel(prefix + "L_MDD", box2X + 155, y + 38, "Max DD%:", COLOR_TEXT_WHITE, 8, "Arial");
   CreateLabel(prefix + "V_MDD", box2X + 215, y + 38, "0.00%", COLOR_LOSS, 9, "Arial Bold");
   
   CreateLabel(prefix + "L_PAIRS", box2X + 10, y + 54, "Active Pairs:", COLOR_TEXT_WHITE, 8, "Arial");
   CreateLabel(prefix + "V_PAIRS", box2X + 90, y + 54, IntegerToString(g_activePairs), COLOR_GOLD, 9, "Arial Bold");
   
   // v3.2.7: Show Exit Mode
   string exitModeStr = "Z|P";
   if(InpExitMode == EXIT_ZSCORE_ONLY) exitModeStr = "Z-Only";
   else if(InpExitMode == EXIT_PROFIT_ONLY) exitModeStr = "P-Only";
   else if(InpExitMode == EXIT_ZSCORE_AND_PROFIT) exitModeStr = "Z&P";
   CreateLabel(prefix + "L_EXIT", box2X + 155, y + 54, "Exit: " + exitModeStr, COLOR_TEXT_WHITE, 8, "Arial");
   
   // === BOX 3: HISTORY LOT (v3.3.0 - with Closed Orders) ===
   int box3X = startX + 2 * (boxWidth + gap);
   CreateRectangle(prefix + "BOX3_BG", box3X, y, boxWidth, boxHeight, C'30,35,45', COLOR_BORDER);
   CreateLabel(prefix + "BOX3_HDR", box3X + 10, y + 5, "HISTORY LOT", COLOR_GOLD, 9, "Arial Bold");
   
   // v3.3.0: Format: "Lot (Orders)"
   CreateLabel(prefix + "L_DLOT", box3X + 10, y + 22, "Daily:", COLOR_TEXT_WHITE, 8, "Arial");
   CreateLabel(prefix + "V_DLOT", box3X + 55, y + 22, "0.00", COLOR_TEXT_WHITE, 9, "Arial");
   CreateLabel(prefix + "V_DORD", box3X + 95, y + 22, "(0)", COLOR_GOLD, 8, "Arial");  // Closed orders
   
   CreateLabel(prefix + "L_WLOT", box3X + 10, y + 38, "Weekly:", COLOR_TEXT_WHITE, 8, "Arial");
   CreateLabel(prefix + "V_WLOT", box3X + 55, y + 38, "0.00", COLOR_TEXT_WHITE, 9, "Arial");
   CreateLabel(prefix + "V_WORD", box3X + 95, y + 38, "(0)", COLOR_GOLD, 8, "Arial");  // Closed orders
   
   CreateLabel(prefix + "L_MLOT", box3X + 145, y + 22, "Monthly:", COLOR_TEXT_WHITE, 8, "Arial");
   CreateLabel(prefix + "V_MLOT", box3X + 200, y + 22, "0.00", COLOR_TEXT_WHITE, 9, "Arial");
   CreateLabel(prefix + "V_MORD", box3X + 240, y + 22, "(0)", COLOR_GOLD, 8, "Arial");  // Closed orders
   
   CreateLabel(prefix + "L_ALOT", box3X + 145, y + 38, "All Time:", COLOR_TEXT_WHITE, 8, "Arial");
   CreateLabel(prefix + "V_ALOT", box3X + 200, y + 38, "0.00", COLOR_TEXT_WHITE, 9, "Arial");
   CreateLabel(prefix + "V_AORD", box3X + 240, y + 38, "(0)", COLOR_GOLD, 8, "Arial");  // Closed orders
   
   // v3.6.0: Show Grid Loss Mode
   string gridLossStr = InpEnableGridLoss ? EnumToString(InpGridLossDistMode) : "Off";
   StringReplace(gridLossStr, "GRID_DIST_", "");
   CreateLabel(prefix + "L_AVG", box3X + 10, y + 54, "GL: " + gridLossStr, COLOR_TEXT_WHITE, 8, "Arial");
   
   // v3.3.0: Show Z-Score TF info
   string zTFStr = EnumToString(GetZScoreTimeframe());
   CreateLabel(prefix + "L_ZTF", box3X + 145, y + 54, "Z-TF: " + zTFStr, COLOR_TEXT_WHITE, 8, "Arial");
   
   // === BOX 4: HISTORY PROFIT ===
   int box4X = startX + 3 * (boxWidth + gap);
   CreateRectangle(prefix + "BOX4_BG", box4X, y, boxWidth, boxHeight, C'30,35,45', COLOR_BORDER);
   CreateLabel(prefix + "BOX4_HDR", box4X + 10, y + 5, "HISTORY PROFIT", COLOR_GOLD, 9, "Arial Bold");
   
   CreateLabel(prefix + "L_DP", box4X + 10, y + 22, "Daily:", COLOR_TEXT_WHITE, 8, "Arial");
   CreateLabel(prefix + "V_DP", box4X + 55, y + 22, "0.00", COLOR_PROFIT, 9, "Arial Bold");
   
   CreateLabel(prefix + "L_WP", box4X + 10, y + 38, "Weekly:", COLOR_TEXT_WHITE, 8, "Arial");
   CreateLabel(prefix + "V_WP", box4X + 60, y + 38, "0.00", COLOR_PROFIT, 9, "Arial Bold");
   
   CreateLabel(prefix + "L_MP", box4X + 155, y + 22, "Monthly:", COLOR_TEXT_WHITE, 8, "Arial");
   CreateLabel(prefix + "V_MP", box4X + 210, y + 22, "0.00", COLOR_PROFIT, 9, "Arial Bold");
   
   CreateLabel(prefix + "L_AP", box4X + 155, y + 38, "All Time:", COLOR_TEXT_WHITE, 8, "Arial");
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
   
   // v3.6.0 HF4: Calculate totals from ALL open positions (including Grid orders)
   double totalLot = 0;
   int totalOrders = 0;
   
   for(int pos = PositionsTotal() - 1; pos >= 0; pos--)
   {
      ulong ticket = PositionGetTicket(pos);
      if(PositionSelectByTicket(ticket))
      {
         string comment = PositionGetString(POSITION_COMMENT);
         // Include all StatArb positions: Main, AVG, GL (Grid Loss), GP (Grid Profit)
         if(StringFind(comment, "StatArb_") == 0)
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
   
   // ===== Update Account Labels =====
   UpdateLabel(prefix + "V_BAL", DoubleToString(balance, 2), balance >= g_initialBalance ? COLOR_PROFIT : COLOR_LOSS);
   UpdateLabel(prefix + "V_EQ", DoubleToString(equity, 2), equity >= balance ? COLOR_PROFIT : COLOR_LOSS);
   UpdateLabel(prefix + "V_MG", DoubleToString(margin, 2), COLOR_TEXT_WHITE);
   
   // v3.6.0 HF2: Show Basket info instead of floating P/L
   double basketNeed = g_totalTarget - g_basketClosedProfit;
   if(basketNeed < 0) basketNeed = 0;
   
   // If Basket Target is enabled, show Basket Closed; otherwise show Floating P/L
   if(g_totalTarget > 0)
   {
      UpdateLabel(prefix + "V_TPL", DoubleToString(g_basketClosedProfit, 2), g_basketClosedProfit >= 0 ? COLOR_PROFIT : COLOR_LOSS);
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
         // v3.5.0: Update CDC Trend Status Badge
         if(InpUseCDCTrendFilter)
         {
            bool cdcOK = CheckCDCTrendConfirmation(i, "ANY");
            string cdcStatus = cdcOK ? "OK" : "BLOCK";
            color cdcColor = cdcOK ? clrLime : clrOrangeRed;
            UpdateLabel(prefix + "P" + idxStr + "_CDC", cdcStatus, cdcColor);
         }
         else
         {
            UpdateLabel(prefix + "P" + idxStr + "_CDC", "OFF", clrDimGray);
         }
         
         double corr = g_pairs[i].correlation * 100;
         color corrColor = MathAbs(corr) >= InpMinCorrelation * 100 ? COLOR_PROFIT : COLOR_TEXT;
         UpdateLabel(prefix + "P" + idxStr + "_CORR", DoubleToString(corr, 0) + "%", corrColor);
         
         string corrType = g_pairs[i].correlationType == 1 ? "Pos" : "Neg";
         color typeColor = g_pairs[i].correlationType == 1 ? COLOR_PROFIT : COLOR_LOSS;
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
      
      double buyLot = g_pairs[i].directionBuy == 1 ? g_pairs[i].lotBuyA + g_pairs[i].lotBuyB : 0;
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
      
      double sellLot = g_pairs[i].directionSell == 1 ? g_pairs[i].lotSellA + g_pairs[i].lotSellB : 0;
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
