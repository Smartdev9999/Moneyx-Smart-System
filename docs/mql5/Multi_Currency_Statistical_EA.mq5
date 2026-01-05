//+------------------------------------------------------------------+
//|                                Multi_Currency_Statistical_EA.mq5 |
//|                 Statistical Arbitrage (Pairs Trading) v3.3.0     |
//|                                             MoneyX Trading        |
//+------------------------------------------------------------------+
#property copyright "MoneyX Trading"
#property version   "3.30"
#property strict
#property description "Statistical Arbitrage / Pairs Trading Expert Advisor"
#property description "Full Hedging with Independent Buy/Sell Sides"
#property description "v3.3.0: Separate Z-Score TF, Skip ATR in Tester, Closed Orders Count"

#include <Trade/Trade.mqh>

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
//| INPUT PARAMETERS                                                   |
//+------------------------------------------------------------------+
input group "=== Trading Settings ==="
input double   InpBaseLot = 0.01;               // Base Lot Size (Symbol A)
input double   InpMaxLot = 1.0;                 // Maximum Lot Size
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

input group "=== Averaging System (v3.3.0 - Simplified) ==="
input ENUM_AVERAGING_MODE InpAveragingMode = AVG_MODE_DISABLED;  // Averaging Mode
input string   InpZScoreGrid = "2.5;3.0;4.0;5.0";                // Z-Score Grid Levels (semicolon separated)
input ENUM_TIMEFRAMES InpAtrTimeframe = PERIOD_H1;               // ATR Timeframe
input int      InpAtrPeriod = 14;                                // ATR Period
input double   InpAtrMultiplier = 1.5;                           // ATR Multiplier for Grid
// v3.3.0: Removed InpMaxAveragingOrders - use InpDefaultMaxOrderBuy/Sell instead
input double   InpAveragingLotMult = 1.0;                        // Averaging Lot Multiplier (1.0 = same)

input group "=== Target Settings (v3.3.0) ==="
input double   InpTotalTarget = 100.0;          // Total Portfolio Target ($)
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
input bool     InpSkipATRInTester = true;           // Skip ATR Indicator in Tester (v3.3.0)

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

input group "=== License Settings ==="
input string   InpApiUrl = "https://lkbhomsulgycxawwlnfh.supabase.co/functions/v1";  // API URL
input string   InpApiKey = "moneyx-ea-secret-2024-secure-key-v1";  // API Key

input group "=== News Filter ==="
input bool     InpEnableNewsFilter = true;      // Enable News Filter
input int      InpNewsBeforeMinutes = 30;       // Minutes Before News
input int      InpNewsAfterMinutes = 30;        // Minutes After News

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                   |
//+------------------------------------------------------------------+
CTrade g_trade;
bool g_isLicenseValid = false;
bool g_isNewsPaused = false;
bool g_isPaused = false;
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

// v3.2.7: Z-Score Grid Levels
double g_zScoreGridLevels[MAX_AVG_LEVELS];
int g_zScoreGridCount = 0;

// v3.2.7: Batch Processing
int g_currentPairIndex = 0;

// ATR Handle for averaging
int g_atrHandle = INVALID_HANDLE;

// v3.2.8: Ultra Fast Mode tick counter
int g_tickCounter = 0;

// v3.3.0: Separate Z-Score timeframe tracking
datetime g_lastZScoreUpdate = 0;

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
   
   // v3.2.7: Parse Z-Score Grid levels
   ParseZScoreGrid(InpZScoreGrid);
   
   // v3.3.0: Initialize ATR handle if needed (skip in tester if InpSkipATRInTester)
   if(InpAveragingMode == AVG_MODE_ATR)
   {
      if(!(g_isTesterMode && InpSkipATRInTester))
      {
         g_atrHandle = iATR(_Symbol, InpAtrTimeframe, InpAtrPeriod);
         if(g_atrHandle == INVALID_HANDLE)
         {
            Print("Warning: Could not create ATR handle for averaging system");
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
   
   PrintFormat("=== Statistical Arbitrage EA v3.3.0 Initialized - %d Active Pairs ===", g_activePairs);
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
      
      // Warmup ATR timeframe data if different (and ATR not skipped)
      if(InpAveragingMode == AVG_MODE_ATR && !InpSkipATRInTester)
      {
         if(InpAtrTimeframe != InpCorrTimeframe)
         {
            SafeCopyClose(g_pairs[i].symbolA, InpAtrTimeframe, 0, InpAtrPeriod + 10, temp);
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
//| v3.2.7: Parse Z-Score Grid String                                  |
//+------------------------------------------------------------------+
void ParseZScoreGrid(string gridStr)
{
   g_zScoreGridCount = 0;
   ArrayInitialize(g_zScoreGridLevels, 0);
   
   string parts[];
   int count = StringSplit(gridStr, ';', parts);
   
   for(int i = 0; i < count && i < MAX_AVG_LEVELS; i++)
   {
      double level = StringToDouble(parts[i]);
      if(level > 0)
      {
         g_zScoreGridLevels[g_zScoreGridCount] = level;
         g_zScoreGridCount++;
      }
   }
   
   if(InpDebugMode)
   {
      Print("Z-Score Grid Levels Parsed: ", g_zScoreGridCount);
      for(int i = 0; i < g_zScoreGridCount; i++)
      {
         PrintFormat("  Level %d: %.2f", i + 1, g_zScoreGridLevels[i]);
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
   }
   
   // v3.2.7: Check for auto-resume after DD
   CheckAutoResume();
   
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
   CheckAllAveraging();
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
//| Verify License                                                     |
//+------------------------------------------------------------------+
bool VerifyLicense()
{
   // Bypass license check in tester/optimizer
   if(MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_OPTIMIZATION))
   {
      return true;
   }
   
   // For demo accounts, always allow
   if(AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_DEMO)
   {
      return true;
   }
   
   return true;  // Simplified for now
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
//| Get Pip Value for Symbol                                           |
//+------------------------------------------------------------------+
double GetPipValue(string symbol)
{
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(tickSize == 0) return 0;
   
   return (tickValue / tickSize) * point;
}

//+------------------------------------------------------------------+
//| Calculate Dollar-Neutral Lot Sizes (v3.0)                          |
//+------------------------------------------------------------------+
void CalculateDollarNeutralLots(int pairIndex)
{
   double baseLot = InpBaseLot;
   double hedgeRatio = g_pairs[pairIndex].hedgeRatio;
   
   string symbolA = g_pairs[pairIndex].symbolA;
   string symbolB = g_pairs[pairIndex].symbolB;
   
   double pipValueA = GetPipValue(symbolA);
   double pipValueB = GetPipValue(symbolB);
   
   if(pipValueB == 0)
   {
      // Set same lots for both sides
      g_pairs[pairIndex].lotBuyA = baseLot;
      g_pairs[pairIndex].lotBuyB = baseLot;
      g_pairs[pairIndex].lotSellA = baseLot;
      g_pairs[pairIndex].lotSellB = baseLot;
      return;
   }
   
   // LotA = Base Lot
   double lotA = baseLot;
   
   // LotB = LotA × β × (PipValueA / PipValueB)
   double lotB = baseLot * hedgeRatio * (pipValueA / pipValueB);
   
   // Normalize lot size
   double minLotB = SymbolInfoDouble(symbolB, SYMBOL_VOLUME_MIN);
   double maxLotB = SymbolInfoDouble(symbolB, SYMBOL_VOLUME_MAX);
   double stepLotB = SymbolInfoDouble(symbolB, SYMBOL_VOLUME_STEP);
   
   lotB = MathMax(minLotB, MathMin(maxLotB, lotB));
   lotB = MathFloor(lotB / stepLotB) * stepLotB;
   lotB = MathMin(lotB, InpMaxLot);
   
   // Set for both Buy and Sell sides
   g_pairs[pairIndex].lotBuyA = lotA;
   g_pairs[pairIndex].lotBuyB = lotB;
   g_pairs[pairIndex].lotSellA = lotA;
   g_pairs[pairIndex].lotSellB = lotB;
}

//+------------------------------------------------------------------+
//| ================ SIGNAL ENGINE (v3.3.0) ================           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Analyze All Pairs for Trading Signals (v3.3.0)                     |
//+------------------------------------------------------------------+
void AnalyzeAllPairs()
{
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(!g_pairs[i].enabled) continue;
      
      // Check correlation threshold
      if(MathAbs(g_pairs[i].correlation) < InpMinCorrelation)
         continue;
      
      double zScore = g_pairs[i].zScore;
      
      // === BUY SIDE ENTRY ===
      // Condition: directionBuy == -1 (Ready) AND Z-Score < -EntryThreshold
      // v3.3.0: Use maxOrderBuy as total limit (Main + Grid)
      if(g_pairs[i].directionBuy == -1 && g_pairs[i].orderCountBuy < g_pairs[i].maxOrderBuy)
      {
         if(zScore < -InpEntryZScore)
         {
            if(OpenBuySideTrade(i))
            {
               g_pairs[i].directionBuy = 1;  // Active trade
               // v3.2.7: Store entry Z-Score for averaging
               g_pairs[i].entryZScoreBuy = zScore;
               g_pairs[i].lastAvgPriceBuy = SymbolInfoDouble(g_pairs[i].symbolA, SYMBOL_ASK);
               // v3.2.9: Set flag to prevent averaging in same tick
               g_pairs[i].justOpenedMainBuy = true;
            }
         }
      }
      
      // === SELL SIDE ENTRY ===
      // Condition: directionSell == -1 (Ready) AND Z-Score > +EntryThreshold
      // v3.3.0: Use maxOrderSell as total limit (Main + Grid)
      if(g_pairs[i].directionSell == -1 && g_pairs[i].orderCountSell < g_pairs[i].maxOrderSell)
      {
         if(zScore > InpEntryZScore)
         {
            if(OpenSellSideTrade(i))
            {
               g_pairs[i].directionSell = 1;  // Active trade
               // v3.2.7: Store entry Z-Score for averaging
               g_pairs[i].entryZScoreSell = zScore;
               g_pairs[i].lastAvgPriceSell = SymbolInfoDouble(g_pairs[i].symbolA, SYMBOL_BID);
               // v3.2.9: Set flag to prevent averaging in same tick
               g_pairs[i].justOpenedMainSell = true;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check All Pairs for Averaging (v3.3.0)                             |
//+------------------------------------------------------------------+
void CheckAllAveraging()
{
   if(InpAveragingMode == AVG_MODE_DISABLED) return;
   
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(!g_pairs[i].enabled) continue;
      
      // Check Buy Side Averaging
      if(g_pairs[i].directionBuy == 1 && !g_pairs[i].justOpenedMainBuy)
      {
         // v3.3.0: Total orders = 1 (main) + avgOrderCountBuy
         int totalBuyOrders = 1 + g_pairs[i].avgOrderCountBuy;
         if(totalBuyOrders < g_pairs[i].maxOrderBuy)
         {
            CheckAveragingForSide(i, "BUY");
         }
      }
      
      // Check Sell Side Averaging
      if(g_pairs[i].directionSell == 1 && !g_pairs[i].justOpenedMainSell)
      {
         // v3.3.0: Total orders = 1 (main) + avgOrderCountSell
         int totalSellOrders = 1 + g_pairs[i].avgOrderCountSell;
         if(totalSellOrders < g_pairs[i].maxOrderSell)
         {
            CheckAveragingForSide(i, "SELL");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check Averaging for Specific Side (v3.2.7)                         |
//+------------------------------------------------------------------+
void CheckAveragingForSide(int pairIndex, string side)
{
   if(InpAveragingMode == AVG_MODE_ZSCORE)
   {
      CheckZScoreAveraging(pairIndex, side);
   }
   else if(InpAveragingMode == AVG_MODE_ATR)
   {
      // v3.3.0: Skip ATR averaging in tester if InpSkipATRInTester
      if(g_isTesterMode && InpSkipATRInTester)
      {
         return;  // Skip ATR averaging entirely in tester
      }
      CheckATRAveraging(pairIndex, side);
   }
}

//+------------------------------------------------------------------+
//| Z-Score Based Averaging (v3.2.7)                                   |
//+------------------------------------------------------------------+
void CheckZScoreAveraging(int pairIndex, string side)
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
         OpenAveragingBuy(pairIndex);
      }
      else
      {
         OpenAveragingSell(pairIndex);
      }
   }
}

//+------------------------------------------------------------------+
//| ATR Based Averaging (v3.2.7)                                       |
//+------------------------------------------------------------------+
void CheckATRAveraging(int pairIndex, string side)
{
   if(g_atrHandle == INVALID_HANDLE) return;
   
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   
   if(CopyBuffer(g_atrHandle, 0, 0, 1, atrBuffer) < 1) return;
   
   double atr = atrBuffer[0];
   double gridDistance = atr * InpAtrMultiplier;
   
   double currentPrice = SymbolInfoDouble(g_pairs[pairIndex].symbolA, SYMBOL_BID);
   
   if(side == "BUY")
   {
      double lastPrice = g_pairs[pairIndex].lastAvgPriceBuy;
      if(lastPrice == 0) lastPrice = currentPrice;
      
      if(currentPrice < lastPrice - gridDistance)
      {
         OpenAveragingBuy(pairIndex);
         g_pairs[pairIndex].lastAvgPriceBuy = currentPrice;
      }
   }
   else
   {
      double lastPrice = g_pairs[pairIndex].lastAvgPriceSell;
      if(lastPrice == 0) lastPrice = currentPrice;
      
      if(currentPrice > lastPrice + gridDistance)
      {
         OpenAveragingSell(pairIndex);
         g_pairs[pairIndex].lastAvgPriceSell = currentPrice;
      }
   }
}

//+------------------------------------------------------------------+
//| Open Averaging Buy Position (v3.2.7)                               |
//+------------------------------------------------------------------+
void OpenAveragingBuy(int pairIndex)
{
   string symbolA = g_pairs[pairIndex].symbolA;
   string symbolB = g_pairs[pairIndex].symbolB;
   
   double lotA = g_pairs[pairIndex].lotBuyA * InpAveragingLotMult;
   double lotB = g_pairs[pairIndex].lotBuyB * InpAveragingLotMult;
   int corrType = g_pairs[pairIndex].correlationType;
   
   string comment = StringFormat("StatArb_AVG_BUY_%d", pairIndex + 1);
   
   // Open Buy on Symbol A
   double askA = SymbolInfoDouble(symbolA, SYMBOL_ASK);
   if(!g_trade.Buy(lotA, symbolA, askA, 0, 0, comment)) return;
   
   // Open position on Symbol B based on correlation type
   if(corrType == 1)  // Positive correlation: Sell B
   {
      double bidB = SymbolInfoDouble(symbolB, SYMBOL_BID);
      g_trade.Sell(lotB, symbolB, bidB, 0, 0, comment);
   }
   else  // Negative correlation: Buy B
   {
      double askB = SymbolInfoDouble(symbolB, SYMBOL_ASK);
      g_trade.Buy(lotB, symbolB, askB, 0, 0, comment);
   }
   
   g_pairs[pairIndex].avgOrderCountBuy++;
   g_pairs[pairIndex].orderCountBuy++;
   
   PrintFormat("Pair %d AVG BUY #%d opened at Z=%.2f", 
               pairIndex + 1, g_pairs[pairIndex].avgOrderCountBuy, g_pairs[pairIndex].zScore);
}

//+------------------------------------------------------------------+
//| Open Averaging Sell Position (v3.2.7)                              |
//+------------------------------------------------------------------+
void OpenAveragingSell(int pairIndex)
{
   string symbolA = g_pairs[pairIndex].symbolA;
   string symbolB = g_pairs[pairIndex].symbolB;
   
   double lotA = g_pairs[pairIndex].lotSellA * InpAveragingLotMult;
   double lotB = g_pairs[pairIndex].lotSellB * InpAveragingLotMult;
   int corrType = g_pairs[pairIndex].correlationType;
   
   string comment = StringFormat("StatArb_AVG_SELL_%d", pairIndex + 1);
   
   // Open Sell on Symbol A
   double bidA = SymbolInfoDouble(symbolA, SYMBOL_BID);
   if(!g_trade.Sell(lotA, symbolA, bidA, 0, 0, comment)) return;
   
   // Open position on Symbol B based on correlation type
   if(corrType == 1)  // Positive correlation: Buy B
   {
      double askB = SymbolInfoDouble(symbolB, SYMBOL_ASK);
      g_trade.Buy(lotB, symbolB, askB, 0, 0, comment);
   }
   else  // Negative correlation: Sell B
   {
      double bidB = SymbolInfoDouble(symbolB, SYMBOL_BID);
      g_trade.Sell(lotB, symbolB, bidB, 0, 0, comment);
   }
   
   g_pairs[pairIndex].avgOrderCountSell++;
   g_pairs[pairIndex].orderCountSell++;
   
   PrintFormat("Pair %d AVG SELL #%d opened at Z=%.2f", 
               pairIndex + 1, g_pairs[pairIndex].avgOrderCountSell, g_pairs[pairIndex].zScore);
}

//+------------------------------------------------------------------+
//| ================ EXECUTION ENGINE ================                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Open Buy Side Trade                                                |
//+------------------------------------------------------------------+
bool OpenBuySideTrade(int pairIndex)
{
   string symbolA = g_pairs[pairIndex].symbolA;
   string symbolB = g_pairs[pairIndex].symbolB;
   double lotA = g_pairs[pairIndex].lotBuyA;
   double lotB = g_pairs[pairIndex].lotBuyB;
   int corrType = g_pairs[pairIndex].correlationType;
   
   string comment = StringFormat("StatArb_BUY_%d", pairIndex + 1);
   
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
   
   PrintFormat("Pair %d BUY SIDE OPENED: BUY %s | %s %s | Z=%.2f | Corr=%s",
      pairIndex + 1, symbolA,
      corrType == 1 ? "SELL" : "BUY", symbolB,
      g_pairs[pairIndex].zScore,
      corrType == 1 ? "Positive" : "Negative");
   
   return true;
}

//+------------------------------------------------------------------+
//| Open Sell Side Trade                                               |
//+------------------------------------------------------------------+
bool OpenSellSideTrade(int pairIndex)
{
   string symbolA = g_pairs[pairIndex].symbolA;
   string symbolB = g_pairs[pairIndex].symbolB;
   double lotA = g_pairs[pairIndex].lotSellA;
   double lotB = g_pairs[pairIndex].lotSellB;
   int corrType = g_pairs[pairIndex].correlationType;
   
   string comment = StringFormat("StatArb_SELL_%d", pairIndex + 1);
   
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
   
   PrintFormat("Pair %d SELL SIDE OPENED: SELL %s | %s %s | Z=%.2f | Corr=%s",
      pairIndex + 1, symbolA,
      corrType == 1 ? "BUY" : "SELL", symbolB,
      g_pairs[pairIndex].zScore,
      corrType == 1 ? "Positive" : "Negative");
   
   return true;
}

//+------------------------------------------------------------------+
//| Close Buy Side Trade (v3.3.0 - with Closed Orders Count)           |
//+------------------------------------------------------------------+
bool CloseBuySide(int pairIndex)
{
   if(g_pairs[pairIndex].directionBuy == 0) return false;
   
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
      
      // Update statistics before reset
      g_dailyProfit += g_pairs[pairIndex].profitBuy;
      g_weeklyProfit += g_pairs[pairIndex].profitBuy;
      g_monthlyProfit += g_pairs[pairIndex].profitBuy;
      g_allTimeProfit += g_pairs[pairIndex].profitBuy;
      g_dailyLot += g_pairs[pairIndex].lotBuyA + g_pairs[pairIndex].lotBuyB;
      g_weeklyLot += g_pairs[pairIndex].lotBuyA + g_pairs[pairIndex].lotBuyB;
      g_monthlyLot += g_pairs[pairIndex].lotBuyA + g_pairs[pairIndex].lotBuyB;
      g_allTimeLot += g_pairs[pairIndex].lotBuyA + g_pairs[pairIndex].lotBuyB;
      
      // v3.3.0: Count closed orders (1 main + averaging orders)
      int closedOrdersCount = 1 + g_pairs[pairIndex].avgOrderCountBuy;
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
      
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Close Sell Side Trade (v3.3.0 - with Closed Orders Count)          |
//+------------------------------------------------------------------+
bool CloseSellSide(int pairIndex)
{
   if(g_pairs[pairIndex].directionSell == 0) return false;
   
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
      
      // Update statistics before reset
      g_dailyProfit += g_pairs[pairIndex].profitSell;
      g_weeklyProfit += g_pairs[pairIndex].profitSell;
      g_monthlyProfit += g_pairs[pairIndex].profitSell;
      g_allTimeProfit += g_pairs[pairIndex].profitSell;
      g_dailyLot += g_pairs[pairIndex].lotSellA + g_pairs[pairIndex].lotSellB;
      g_weeklyLot += g_pairs[pairIndex].lotSellA + g_pairs[pairIndex].lotSellB;
      g_monthlyLot += g_pairs[pairIndex].lotSellA + g_pairs[pairIndex].lotSellB;
      g_allTimeLot += g_pairs[pairIndex].lotSellA + g_pairs[pairIndex].lotSellB;
      
      // v3.3.0: Count closed orders (1 main + averaging orders)
      int closedOrdersCount = 1 + g_pairs[pairIndex].avgOrderCountSell;
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
      
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Close Averaging Positions (v3.2.7)                                 |
//+------------------------------------------------------------------+
void CloseAveragingPositions(int pairIndex, string side)
{
   string comment = StringFormat("StatArb_AVG_%s_%d", side, pairIndex + 1);
   
   // Close all positions with matching comment
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(StringFind(PositionGetString(POSITION_COMMENT), comment) >= 0)
         {
            g_trade.PositionClose(PositionGetTicket(i));
         }
      }
   }
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
         
         // Add averaging positions profit
         string avgComment = StringFormat("StatArb_AVG_BUY_%d", i + 1);
         buyProfit += GetAveragingProfit(avgComment);
      }
      
      // Calculate Sell side profit
      if(g_pairs[i].directionSell == 1)
      {
         sellProfit = GetPositionProfit(g_pairs[i].ticketSellA) + GetPositionProfit(g_pairs[i].ticketSellB);
         
         // Add averaging positions profit
         string avgComment = StringFormat("StatArb_AVG_SELL_%d", i + 1);
         sellProfit += GetAveragingProfit(avgComment);
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
//| Check Total Portfolio Target                                       |
//+------------------------------------------------------------------+
void CheckTotalTarget()
{
   if(g_totalTarget <= 0) return;
   
   if(g_totalCurrentProfit >= g_totalTarget)
   {
      PrintFormat(">>> TOTAL TARGET REACHED: %.2f >= %.2f - Closing ALL positions! <<<",
         g_totalCurrentProfit, g_totalTarget);
      
      for(int i = 0; i < MAX_PAIRS; i++)
      {
         if(g_pairs[i].directionBuy == 1)
         {
            PrintFormat(">>> TOTAL TARGET: Closing Pair %d BUY (Profit: %.2f)", 
                        i + 1, g_pairs[i].profitBuy);
            CloseBuySide(i);
         }
         if(g_pairs[i].directionSell == 1)
         {
            PrintFormat(">>> TOTAL TARGET: Closing Pair %d SELL (Profit: %.2f)", 
                        i + 1, g_pairs[i].profitSell);
            CloseSellSide(i);
         }
      }
   }
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
               "Multi-Currency Statistical EA v3.3.0 - MoneyX Trading", 
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
   
   // Center columns: Pair | C-% | Type | Beta | Total P/L
   CreateLabel(prefix + "COL_C_PR", centerX + 10, colLabelY, "Pair", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_C_CR", centerX + 140, colLabelY, "C-%", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_C_TY", centerX + 195, colLabelY, "Type", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_C_BT", centerX + 250, colLabelY, "Beta", COLOR_HEADER_TXT, 7, "Arial");
   CreateLabel(prefix + "COL_C_TP", centerX + 310, colLabelY, "Tot P/L", COLOR_HEADER_TXT, 7, "Arial");
   
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
   CreateLabel(prefix + "P" + idxStr + "_CORR", centerX + 140, y + 3, "0%", COLOR_TEXT, FONT_SIZE, "Arial");
   CreateLabel(prefix + "P" + idxStr + "_TYPE", centerX + 195, y + 3, "Pos", COLOR_PROFIT, FONT_SIZE, "Arial");
   CreateLabel(prefix + "P" + idxStr + "_BETA", centerX + 250, y + 3, "1.00", COLOR_TEXT, FONT_SIZE, "Arial");
   CreateLabel(prefix + "P" + idxStr + "_TPL", centerX + 310, y + 3, "0", COLOR_TEXT, 9, "Arial Bold");
   
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
   
   // v3.2.7: Show Averaging Mode
   string avgModeStr = "Off";
   if(InpAveragingMode == AVG_MODE_ZSCORE) avgModeStr = "Z-Grid";
   else if(InpAveragingMode == AVG_MODE_ATR) avgModeStr = "ATR";
   CreateLabel(prefix + "L_AVG", box3X + 10, y + 54, "Avg: " + avgModeStr, COLOR_TEXT_WHITE, 8, "Arial");
   
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
   
   // Calculate totals
   double totalLot = 0;
   int totalOrders = 0;
   
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(g_pairs[i].directionBuy == 1)
      {
         totalLot += g_pairs[i].lotBuyA + g_pairs[i].lotBuyB;
         totalOrders += 2 + g_pairs[i].avgOrderCountBuy * 2;  // Include averaging orders
      }
      if(g_pairs[i].directionSell == 1)
      {
         totalLot += g_pairs[i].lotSellA + g_pairs[i].lotSellB;
         totalOrders += 2 + g_pairs[i].avgOrderCountSell * 2;  // Include averaging orders
      }
   }
   
   // Update max equity
   if(equity > g_maxEquity) g_maxEquity = equity;
   
   // Calculate drawdown
   double ddPercent = 0;
   if(g_maxEquity > 0)
   {
      ddPercent = ((g_maxEquity - equity) / g_maxEquity) * 100;
      if(ddPercent < 0) ddPercent = 0;
   }
   if(ddPercent > g_maxDrawdownPercent) g_maxDrawdownPercent = ddPercent;
   
   // ===== Update Account Labels =====
   UpdateLabel(prefix + "V_BAL", DoubleToString(balance, 2), balance >= g_initialBalance ? COLOR_PROFIT : COLOR_LOSS);
   UpdateLabel(prefix + "V_EQ", DoubleToString(equity, 2), equity >= balance ? COLOR_PROFIT : COLOR_LOSS);
   UpdateLabel(prefix + "V_MG", DoubleToString(margin, 2), COLOR_TEXT_WHITE);
   UpdateLabel(prefix + "V_TPL", DoubleToString(g_totalCurrentProfit, 2), g_totalCurrentProfit >= 0 ? COLOR_PROFIT : COLOR_LOSS);
   
   UpdateLabel(prefix + "V_TLOT", DoubleToString(totalLot, 2), COLOR_TEXT_WHITE);
   UpdateLabel(prefix + "V_TORD", IntegerToString(totalOrders), COLOR_TEXT_WHITE);
   UpdateLabel(prefix + "V_DD", DoubleToString(ddPercent, 2) + "%", ddPercent > 10 ? COLOR_LOSS : COLOR_TEXT_WHITE);
   UpdateLabel(prefix + "V_MDD", DoubleToString(g_maxDrawdownPercent, 2) + "%", g_maxDrawdownPercent > InpMaxDrawdown ? COLOR_LOSS : COLOR_TEXT_WHITE);
   
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
         UpdateLabel(prefix + "P" + idxStr + "_CORR", "-", COLOR_OFF);
         UpdateLabel(prefix + "P" + idxStr + "_TYPE", "-", COLOR_OFF);
         UpdateLabel(prefix + "P" + idxStr + "_BETA", "-", COLOR_OFF);
      }
      else if(!g_pairs[i].dataValid)
      {
         UpdateLabel(prefix + "P" + idxStr + "_CORR", "N/A", COLOR_GOLD);
         UpdateLabel(prefix + "P" + idxStr + "_TYPE", "N/A", COLOR_GOLD);
         UpdateLabel(prefix + "P" + idxStr + "_BETA", "N/A", COLOR_GOLD);
      }
      else
      {
         double corr = g_pairs[i].correlation * 100;
         color corrColor = MathAbs(corr) >= InpMinCorrelation * 100 ? COLOR_PROFIT : COLOR_TEXT;
         UpdateLabel(prefix + "P" + idxStr + "_CORR", DoubleToString(corr, 0) + "%", corrColor);
         
         string corrType = g_pairs[i].correlationType == 1 ? "Pos" : "Neg";
         color typeColor = g_pairs[i].correlationType == 1 ? COLOR_PROFIT : COLOR_LOSS;
         UpdateLabel(prefix + "P" + idxStr + "_TYPE", corrType, typeColor);
         
         UpdateLabel(prefix + "P" + idxStr + "_BETA", DoubleToString(g_pairs[i].hedgeRatio, 2), COLOR_TEXT);
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
