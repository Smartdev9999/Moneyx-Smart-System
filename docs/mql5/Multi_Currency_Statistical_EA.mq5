//+------------------------------------------------------------------+
//|                                Multi_Currency_Statistical_EA.mq5 |
//|                      Statistical Arbitrage (Pairs Trading) v3.2.7 |
//|                                             MoneyX Trading        |
//+------------------------------------------------------------------+
#property copyright "MoneyX Trading"
#property version   "3.27"
#property strict
#property description "Statistical Arbitrage / Pairs Trading Expert Advisor"
#property description "Full Hedging with Independent Buy/Sell Sides"
#property description "v3.2.7: Bug Fixes + Exit Modes + Averaging System"

#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| CONSTANTS                                                          |
//+------------------------------------------------------------------+
#define MAX_PAIRS 30
#define MAX_LOOKBACK 200
#define MAX_ZSCORE_LEVELS 10

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
};

//+------------------------------------------------------------------+
//| PAIR INFO STRUCTURE (v3.2.7 - with Averaging System)               |
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
   int            maxOrderBuy;       // Max orders allowed Buy side
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
   int            maxOrderSell;      // Max orders allowed Sell side
   double         targetSell;        // Target profit Sell side
   datetime       entryTimeSell;     // Entry time Sell side
   
   // === Averaging System (v3.2.7) ===
   int            avgCountBuy;       // Averaging order count for Buy
   int            avgCountSell;      // Averaging order count for Sell
   double         lastAvgZBuy;       // Last Z-Score level triggered (Buy)
   double         lastAvgZSell;      // Last Z-Score level triggered (Sell)
   double         avgEntryPriceBuyA; // Avg entry price Symbol A (Buy)
   double         avgEntryPriceSellA;// Avg entry price Symbol A (Sell)
   
   // === Combined ===
   double         totalPairProfit;   // profitBuy + profitSell
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

//+------------------------------------------------------------------+
//| EXIT MODE ENUM (v3.2.7)                                            |
//+------------------------------------------------------------------+
enum ENUM_EXIT_MODE
{
   EXIT_ZSCORE_ONLY = 0,     // Z-Score Only
   EXIT_PROFIT_ONLY,         // Target Profit Only ($)
   EXIT_ZSCORE_OR_PROFIT,    // Z-Score OR Profit (First Wins)
   EXIT_ZSCORE_AND_PROFIT    // Z-Score AND Profit (Both Required)
};

//+------------------------------------------------------------------+
//| AVERAGING MODE ENUM (v3.2.7)                                       |
//+------------------------------------------------------------------+
enum ENUM_AVG_MODE
{
   AVG_MODE_ZSCORE = 0,      // Z-Score Based
   AVG_MODE_ATR              // ATR Based
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

input group "=== Beta Calculation Settings (v3.2.6) ==="
input ENUM_BETA_MODE InpBetaMode = BETA_AUTO_SMOOTH;   // Beta Calculation Mode
input double   InpBetaSmoothFactor = 0.1;              // Beta EMA Smooth Factor (0.05-0.3)
input double   InpManualBetaDefault = 1.0;             // Default Manual Beta (if MANUAL_FIXED)
input double   InpPipBetaWeight = 0.7;                 // Pip-Value Beta Weight in Auto (0.5-0.9)

input group "=== Exit Mode Settings (v3.2.7) ==="
input ENUM_EXIT_MODE InpExitMode = EXIT_ZSCORE_OR_PROFIT;  // Exit Mode (Z-Score/Profit/Both)
input int      InpMinHoldingBars = 3;                      // Minimum Holding Bars Before Exit (0=disable)
input bool     InpRequirePositiveProfit = true;            // Require Positive Profit for Z-Score Exit

input group "=== Averaging System (v3.2.7) ==="
input bool     InpEnableAveraging = false;              // Enable Averaging System
input ENUM_AVG_MODE InpAveragingMode = AVG_MODE_ZSCORE; // Averaging Mode
input string   InpZScoreGrid = "2.5;3.0;4.0;5.0";       // Z-Score Grid Levels (semicolon separated)
input ENUM_TIMEFRAMES InpAtrTimeframe = PERIOD_H4;      // ATR Timeframe (for ATR mode)
input int      InpAtrPeriod = 14;                       // ATR Period
input double   InpAtrMultiplier = 1.5;                  // ATR Multiplier for Grid Step
input int      InpMaxAveragingOrders = 5;               // Max Averaging Orders per Side
input double   InpAveragingLotMult = 1.0;               // Averaging Lot Multiplier (1.0 = same lot)

input group "=== Target Settings (v3.0) ==="
input double   InpTotalTarget = 100.0;          // Total Portfolio Target ($)
input int      InpDefaultMaxOrderBuy = 5;       // Default Max Order (Buy Side)
input int      InpDefaultMaxOrderSell = 5;      // Default Max Order (Sell Side)
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

input group "=== Fast Backtest Settings (v3.2.7) ==="
input bool     InpFastBacktest = true;              // Enable Fast Backtest Mode
input bool     InpDisableDashboardInTester = false; // Disable Dashboard in Tester (Fastest)
input int      InpBacktestUiUpdateSec = 30;         // Dashboard Update Interval in Tester (sec)
input bool     InpDisableDebugInTester = true;      // Disable Debug Print in Tester
input int      InpBacktestLogInterval = 60;         // Summary Log Interval in Tester (sec, 0=off)
input int      InpMaxPairsPerTick = 10;             // Max Pairs to Calculate per Tick (Backtest)

input group "=== Lot Sizing (Dollar-Neutral) ==="
input bool     InpUseDollarNeutral = true;      // Use Dollar-Neutral Sizing
input double   InpMaxMarginPercent = 50.0;      // Max Margin Usage (%)

input group "=== Risk Management ==="
input double   InpMaxDrawdown = 20.0;           // Max Drawdown (%)
input int      InpMaxHoldingBars = 0;           // Max Holding Time (0=Disabled)
input double   InpEmergencyCloseDD = 30.0;      // Emergency Close Drawdown (% , 0=Disable)
input bool     InpAutoResumeAfterDD = true;     // Auto Resume After DD Recovery
input double   InpResumeEquityPercent = 95.0;   // Resume When Equity Recovers to % of Peak

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
string g_pauseReason = "";  // v3.2.7: Pause reason tracking
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
double g_peakEquityBeforeDD = 0;  // v3.2.7: Track peak before DD pause
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

// v3.2.7: Batch calculation for backtest
int g_currentBatchStart = 0;

// v3.2.7: Z-Score Grid Levels
double g_zScoreGridLevels[MAX_ZSCORE_LEVELS];
int g_zScoreGridCount = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   // v3.2.5: Detect tester mode first
   g_isTesterMode = (bool)MQLInfoInteger(MQL_TESTER) || 
                    (bool)MQLInfoInteger(MQL_OPTIMIZATION) ||
                    (bool)MQLInfoInteger(MQL_VISUAL_MODE);
   
   // v3.2.5: Setup dashboard based on mode
   g_dashboardEnabled = !(g_isTesterMode && InpDisableDashboardInTester);
   
   // For Strategy Tester, skip license check
   if(g_isTesterMode)
   {
      g_isLicenseValid = true;
      Print("Strategy Tester detected - License check bypassed");
   }
   else
   {
      g_isLicenseValid = VerifyLicense();
      if(!g_isLicenseValid)
      {
         Print("License verification failed!");
         return(INIT_FAILED);
      }
   }
   
   // Initialize colors from inputs
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
   
   // Initialize dimensions from inputs
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
   
   // Initialize pairs
   if(!InitializePairs())
   {
      Print("Failed to initialize trading pairs!");
      return(INIT_FAILED);
   }
   
   // v3.2.7: Parse Z-Score grid levels
   ParseZScoreGrid();
   
   // v3.2.7: Warmup symbol data for all pairs
   WarmupSymbolData();
   
   // Force initial data update
   UpdateAllPairData();
   
   // Initialize account stats
   g_initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_maxEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_peakEquityBeforeDD = g_maxEquity;
   g_totalTarget = InpTotalTarget;
   g_dayStart = TimeCurrent();
   g_weekStart = TimeCurrent();
   g_monthStart = TimeCurrent();
   
   // v3.2.5: Only setup timer for live trading
   if(!g_isTesterMode)
   {
      EventSetTimer(1);
   }
   
   // Print configuration summary
   Print("=== Statistical Arbitrage EA v3.2.7 ===");
   PrintFormat("Mode: %s | Pairs: %d | Timeframe: %s", 
               g_isTesterMode ? "TESTER" : "LIVE",
               g_activePairs, 
               EnumToString(InpCorrTimeframe));
   PrintFormat("Beta Mode: %s | Exit Mode: %s", 
               EnumToString(InpBetaMode),
               EnumToString(InpExitMode));
   PrintFormat("Averaging: %s | Mode: %s | Max Orders: %d",
               InpEnableAveraging ? "ON" : "OFF",
               EnumToString(InpAveragingMode),
               InpMaxAveragingOrders);
   
   if(InpDebugMode && !g_isTesterMode)
   {
      Print("=== Active Pairs Summary ===");
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
   }
   PrintFormat("Total Enabled Pairs: %d", g_activePairs);
   
   // v3.2.5: Create dashboard based on mode
   if(g_dashboardEnabled)
   {
      CreateDashboard();
   }
   
   PrintFormat("=== Statistical Arbitrage EA v3.2.7 Initialized - %d Active Pairs ===", g_activePairs);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| v3.2.7: Parse Z-Score Grid String                                  |
//+------------------------------------------------------------------+
void ParseZScoreGrid()
{
   string levels[];
   g_zScoreGridCount = StringSplit(InpZScoreGrid, ';', levels);
   
   if(g_zScoreGridCount > MAX_ZSCORE_LEVELS)
      g_zScoreGridCount = MAX_ZSCORE_LEVELS;
   
   for(int i = 0; i < g_zScoreGridCount; i++)
   {
      g_zScoreGridLevels[i] = StringToDouble(levels[i]);
   }
   
   // Sort ascending
   for(int i = 0; i < g_zScoreGridCount - 1; i++)
   {
      for(int j = i + 1; j < g_zScoreGridCount; j++)
      {
         if(g_zScoreGridLevels[i] > g_zScoreGridLevels[j])
         {
            double temp = g_zScoreGridLevels[i];
            g_zScoreGridLevels[i] = g_zScoreGridLevels[j];
            g_zScoreGridLevels[j] = temp;
         }
      }
   }
   
   if(InpDebugMode)
   {
      string gridStr = "";
      for(int i = 0; i < g_zScoreGridCount; i++)
      {
         gridStr += StringFormat("%.2f", g_zScoreGridLevels[i]);
         if(i < g_zScoreGridCount - 1) gridStr += ", ";
      }
      PrintFormat("Z-Score Grid Levels: [%s]", gridStr);
   }
}

//+------------------------------------------------------------------+
//| v3.2.7: Warmup Symbol Data (preload history)                       |
//+------------------------------------------------------------------+
void WarmupSymbolData()
{
   Print("Warming up symbol data...");
   int warmedUp = 0;
   
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(!g_pairs[i].enabled) continue;
      
      string symbolA = g_pairs[i].symbolA;
      string symbolB = g_pairs[i].symbolB;
      
      // Force symbol selection
      SymbolSelect(symbolA, true);
      SymbolSelect(symbolB, true);
      
      // Request history data
      double tempA[], tempB[];
      ArraySetAsSeries(tempA, true);
      ArraySetAsSeries(tempB, true);
      
      int copiedA = CopyClose(symbolA, InpCorrTimeframe, 0, InpCorrBars, tempA);
      int copiedB = CopyClose(symbolB, InpCorrTimeframe, 0, InpCorrBars, tempB);
      
      if(copiedA >= InpCorrBars && copiedB >= InpCorrBars)
      {
         warmedUp++;
      }
      else if(!g_isTesterMode || !InpFastBacktest)
      {
         PrintFormat("Pair %d warmup: %s=%d bars, %s=%d bars (need %d)",
                     i + 1, symbolA, copiedA, symbolB, copiedB, InpCorrBars);
      }
   }
   
   PrintFormat("Symbol warmup complete: %d/%d pairs ready", warmedUp, g_activePairs);
}

//+------------------------------------------------------------------+
//| v3.2.7: Safe CopyClose with retry logic                            |
//+------------------------------------------------------------------+
bool SafeCopyClose(string symbol, ENUM_TIMEFRAMES tf, int start, int count, double &arr[])
{
   int maxRetry = 3;
   
   for(int retry = 0; retry < maxRetry; retry++)
   {
      int copied = CopyClose(symbol, tf, start, count, arr);
      if(copied >= count) return true;
      
      // Only sleep in live mode (Sleep not reliable in tester)
      if(!g_isTesterMode)
      {
         Sleep(100);
      }
   }
   
   return false;
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
//| Setup Individual Pair (v3.2.7 - with Averaging fields)             |
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
   
   // Buy Side initialization
   g_pairs[index].directionBuy = enabled ? -1 : 0;
   g_pairs[index].ticketBuyA = 0;
   g_pairs[index].ticketBuyB = 0;
   g_pairs[index].lotBuyA = InpBaseLot;
   g_pairs[index].lotBuyB = InpBaseLot;
   g_pairs[index].profitBuy = 0;
   g_pairs[index].orderCountBuy = 0;
   g_pairs[index].maxOrderBuy = InpDefaultMaxOrderBuy;
   g_pairs[index].targetBuy = InpDefaultTargetBuy;
   g_pairs[index].entryTimeBuy = 0;
   
   // Sell Side initialization
   g_pairs[index].directionSell = enabled ? -1 : 0;
   g_pairs[index].ticketSellA = 0;
   g_pairs[index].ticketSellB = 0;
   g_pairs[index].lotSellA = InpBaseLot;
   g_pairs[index].lotSellB = InpBaseLot;
   g_pairs[index].profitSell = 0;
   g_pairs[index].orderCountSell = 0;
   g_pairs[index].maxOrderSell = InpDefaultMaxOrderSell;
   g_pairs[index].targetSell = InpDefaultTargetSell;
   g_pairs[index].entryTimeSell = 0;
   
   // v3.2.7: Averaging System initialization
   g_pairs[index].avgCountBuy = 0;
   g_pairs[index].avgCountSell = 0;
   g_pairs[index].lastAvgZBuy = 0;
   g_pairs[index].lastAvgZSell = 0;
   g_pairs[index].avgEntryPriceBuyA = 0;
   g_pairs[index].avgEntryPriceSellA = 0;
   
   // Combined
   g_pairs[index].totalPairProfit = 0;
   
   if(!enabled) return;
   
   // Validate symbols exist in broker
   if(!SymbolSelect(symbolA, true))
   {
      PrintFormat("Pair %d DISABLED: Symbol %s not found in broker", index + 1, symbolA);
      return;
   }
   
   if(!SymbolSelect(symbolB, true))
   {
      PrintFormat("Pair %d DISABLED: Symbol %s not found in broker", index + 1, symbolB);
      return;
   }
   
   // Check if symbols have valid tick data
   datetime timeA = (datetime)SymbolInfoInteger(symbolA, SYMBOL_TIME);
   datetime timeB = (datetime)SymbolInfoInteger(symbolB, SYMBOL_TIME);
   
   if(timeA == 0 || timeB == 0)
   {
      PrintFormat("Pair %d WARNING: No tick data for %s or %s - will retry on data update", 
                  index + 1, symbolA, symbolB);
   }
   
   g_pairs[index].enabled = true;
   g_activePairs++;
   PrintFormat("Pair %d initialized: %s - %s [ENABLED]", index + 1, symbolA, symbolB);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   ObjectsDeleteAll(0, "STAT_");
   ChartRedraw();
   Print("=== Statistical Arbitrage EA v3.2.7 Deinitialized ===");
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!g_isLicenseValid) return;
   
   // v3.2.7: Check DD recovery before returning on pause
   if(g_isPaused)
   {
      CheckDDRecovery();
      return;
   }
   
   // === v3.2.5: Optimized Backtest Mode Updates ===
   if(g_isTesterMode && InpFastBacktest)
   {
      datetime now = TimeCurrent();
      
      // Dashboard update with configurable interval
      if(g_dashboardEnabled && (now - g_lastTesterDashboardUpdate >= InpBacktestUiUpdateSec))
      {
         UpdatePairProfits();
         UpdateDashboard();
         g_lastTesterDashboardUpdate = now;
      }
      
      // Summary log with configurable interval
      if(InpBacktestLogInterval > 0 && !InpDisableDebugInTester && InpDebugMode)
      {
         if(now - g_lastTesterLogTime >= InpBacktestLogInterval)
         {
            int activeBuys = 0, activeSells = 0;
            double totalProfit = 0;
            for(int i = 0; i < MAX_PAIRS; i++)
            {
               if(g_pairs[i].enabled && g_pairs[i].dataValid)
               {
                  if(g_pairs[i].directionBuy == 1) activeBuys++;
                  if(g_pairs[i].directionSell == 1) activeSells++;
                  totalProfit += g_pairs[i].totalPairProfit;
               }
            }
            PrintFormat("[BT-SUM] Time: %s | Active: Buy=%d Sell=%d | Profit: %.2f",
               TimeToString(now, TIME_DATE|TIME_MINUTES), activeBuys, activeSells, totalProfit);
            g_lastTesterLogTime = now;
         }
      }
   }
   
   // Check news filter
   if(InpEnableNewsFilter && IsNewsPaused())
   {
      g_isNewsPaused = true;
      return;
   }
   g_isNewsPaused = false;
   
   // Check for new correlation timeframe candle (real-time update)
   datetime corrTime = iTime(_Symbol, InpCorrTimeframe, 0);
   if(corrTime != g_lastCorrUpdate)
   {
      g_lastCorrUpdate = corrTime;
      
      // v3.2.7: Use batch update in tester mode
      if(g_isTesterMode && InpFastBacktest)
      {
         UpdatePairDataBatch();
      }
      else
      {
         UpdateAllPairData();
      }
      
      if(!g_isTesterMode || !InpFastBacktest)
      {
         PrintFormat("Correlation updated on new %s candle", EnumToString(InpCorrTimeframe));
      }
   }
   
   // Check for new trading candle
   datetime currentTime = iTime(_Symbol, InpTimeframe, 0);
   if(currentTime == g_lastCandleTime) return;
   g_lastCandleTime = currentTime;
   
   // Main trading logic
   AnalyzeAllPairs();
   
   // v3.2.7: Check averaging signals
   if(InpEnableAveraging)
   {
      CheckAveragingSignals();
   }
   
   ManageAllPositions();
   CheckRiskLimits();
}

//+------------------------------------------------------------------+
//| v3.2.7: Update Pair Data in Batches (for faster backtest)          |
//+------------------------------------------------------------------+
void UpdatePairDataBatch()
{
   int pairsThisTick = 0;
   int startIndex = g_currentBatchStart;
   
   for(int i = startIndex; i < MAX_PAIRS && pairsThisTick < InpMaxPairsPerTick; i++)
   {
      if(!g_pairs[i].enabled) continue;
      
      UpdateSinglePairData(i);
      pairsThisTick++;
      g_currentBatchStart = (i + 1) % MAX_PAIRS;
   }
   
   // If we haven't processed all pairs, continue from 0
   if(pairsThisTick < InpMaxPairsPerTick && startIndex > 0)
   {
      for(int i = 0; i < startIndex && pairsThisTick < InpMaxPairsPerTick; i++)
      {
         if(!g_pairs[i].enabled) continue;
         
         UpdateSinglePairData(i);
         pairsThisTick++;
         g_currentBatchStart = (i + 1) % MAX_PAIRS;
      }
   }
}

//+------------------------------------------------------------------+
//| v3.2.7: Update Single Pair Data                                    |
//+------------------------------------------------------------------+
void UpdateSinglePairData(int pairIndex)
{
   UpdatePriceHistory(pairIndex);
   
   if(!g_pairs[pairIndex].dataValid) return;
   
   CalculateLogReturns(pairIndex);
   g_pairs[pairIndex].correlation = CalculatePearsonCorrelation(pairIndex);
   DetectCorrelationType(pairIndex);
   g_pairs[pairIndex].hedgeRatio = CalculateHedgeRatio(pairIndex);
   
   if(InpUseDollarNeutral)
   {
      CalculateDollarNeutralLots(pairIndex);
   }
   
   UpdateSpreadHistory(pairIndex);
   g_pairs[pairIndex].zScore = CalculateSpreadZScore(pairIndex);
}

//+------------------------------------------------------------------+
//| v3.2.7: Check DD Recovery for Auto-Resume                          |
//+------------------------------------------------------------------+
void CheckDDRecovery()
{
   // Only check if paused due to DD and auto-resume is enabled
   if(g_pauseReason != "DD_LIMIT" || !InpAutoResumeAfterDD) return;
   
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double recoveryPercent = (equity / g_peakEquityBeforeDD) * 100;
   
   if(recoveryPercent >= InpResumeEquityPercent)
   {
      PrintFormat("DD RECOVERED: Equity %.2f%% of peak (%.2f / %.2f) - Resuming trading", 
                  recoveryPercent, equity, g_peakEquityBeforeDD);
      g_isPaused = false;
      g_pauseReason = "";
      g_maxEquity = equity;  // Reset peak to current equity
      StartAllPairs();       // Restart all pairs to Ready state
   }
}

//+------------------------------------------------------------------+
//| Timer function - Dashboard Updates                                 |
//+------------------------------------------------------------------+
void OnTimer()
{
   // v3.2.5: Skip if dashboard disabled in tester
   if(g_isTesterMode && !g_dashboardEnabled) return;
   
   UpdatePairProfits();
   UpdateAccountStats();
   
   if(g_dashboardEnabled)
   {
      UpdateDashboard();
   }
}

//+------------------------------------------------------------------+
//| Chart Event Handler - Interactive Dashboard                        |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      // Handle Close Buy button clicks
      if(StringFind(sparam, "_CLOSE_BUY_") >= 0)
      {
         int pairIndex = ExtractPairIndex(sparam, "_CLOSE_BUY_");
         if(pairIndex >= 0 && pairIndex < MAX_PAIRS)
         {
            CloseBuySide(pairIndex);
            Print("Manual close Buy Side for Pair ", pairIndex + 1);
         }
      }
      // Handle Close Sell button clicks
      else if(StringFind(sparam, "_CLOSE_SELL_") >= 0)
      {
         int pairIndex = ExtractPairIndex(sparam, "_CLOSE_SELL_");
         if(pairIndex >= 0 && pairIndex < MAX_PAIRS)
         {
            CloseSellSide(pairIndex);
            Print("Manual close Sell Side for Pair ", pairIndex + 1);
         }
      }
      // Handle Close All Buy button
      else if(StringFind(sparam, "_CLOSE_ALL_BUY") >= 0)
      {
         CloseAllBuySides();
         Print("Manual close ALL Buy Sides");
      }
       // Handle Close All Sell button
       else if(StringFind(sparam, "_CLOSE_ALL_SELL") >= 0)
       {
          CloseAllSellSides();
          Print("Manual close ALL Sell Sides");
       }
       // Handle Start All button
       else if(StringFind(sparam, "_START_ALL") >= 0)
       {
          StartAllPairs();
          Print("Start All Pairs triggered");
       }
       // Handle Stop All button
       else if(StringFind(sparam, "_STOP_ALL") >= 0)
       {
          StopAllPairs();
          Print("Stop All Pairs triggered");
       }
      // Handle Status Buy Toggle clicks
      else if(StringFind(sparam, "_ST_BUY_") >= 0)
      {
         int pairIndex = ExtractPairIndex(sparam, "_ST_BUY_");
         if(pairIndex >= 0 && pairIndex < MAX_PAIRS && g_pairs[pairIndex].enabled)
         {
            ToggleBuySideStatus(pairIndex);
         }
      }
      // Handle Status Sell Toggle clicks
      else if(StringFind(sparam, "_ST_SELL_") >= 0)
      {
         int pairIndex = ExtractPairIndex(sparam, "_ST_SELL_");
         if(pairIndex >= 0 && pairIndex < MAX_PAIRS && g_pairs[pairIndex].enabled)
         {
            ToggleSellSideStatus(pairIndex);
         }
      }
   }
   
   // Handle editable target fields
   if(id == CHARTEVENT_OBJECT_ENDEDIT)
   {
      // Buy Target edit
      if(StringFind(sparam, "_TGT_BUY_") >= 0)
      {
         int pairIndex = ExtractPairIndex(sparam, "_TGT_BUY_");
         if(pairIndex >= 0 && pairIndex < MAX_PAIRS)
         {
            string value = ObjectGetString(0, sparam, OBJPROP_TEXT);
            g_pairs[pairIndex].targetBuy = StringToDouble(value);
            PrintFormat("Pair %d Buy Target updated to: %.2f", pairIndex + 1, g_pairs[pairIndex].targetBuy);
         }
      }
      // Sell Target edit
      else if(StringFind(sparam, "_TGT_SELL_") >= 0)
      {
         int pairIndex = ExtractPairIndex(sparam, "_TGT_SELL_");
         if(pairIndex >= 0 && pairIndex < MAX_PAIRS)
         {
            string value = ObjectGetString(0, sparam, OBJPROP_TEXT);
            g_pairs[pairIndex].targetSell = StringToDouble(value);
            PrintFormat("Pair %d Sell Target updated to: %.2f", pairIndex + 1, g_pairs[pairIndex].targetSell);
         }
      }
      // Max Order Buy edit
      else if(StringFind(sparam, "_MAX_BUY_") >= 0)
      {
         int pairIndex = ExtractPairIndex(sparam, "_MAX_BUY_");
         if(pairIndex >= 0 && pairIndex < MAX_PAIRS)
         {
            string value = ObjectGetString(0, sparam, OBJPROP_TEXT);
            g_pairs[pairIndex].maxOrderBuy = (int)StringToInteger(value);
            PrintFormat("Pair %d Max Buy updated to: %d", pairIndex + 1, g_pairs[pairIndex].maxOrderBuy);
         }
      }
      // Max Order Sell edit
      else if(StringFind(sparam, "_MAX_SELL_") >= 0)
      {
         int pairIndex = ExtractPairIndex(sparam, "_MAX_SELL_");
         if(pairIndex >= 0 && pairIndex < MAX_PAIRS)
         {
            string value = ObjectGetString(0, sparam, OBJPROP_TEXT);
            g_pairs[pairIndex].maxOrderSell = (int)StringToInteger(value);
            PrintFormat("Pair %d Max Sell updated to: %d", pairIndex + 1, g_pairs[pairIndex].maxOrderSell);
         }
      }
      // Total Target edit
      else if(StringFind(sparam, "_TOTAL_TARGET") >= 0)
      {
         string value = ObjectGetString(0, sparam, OBJPROP_TEXT);
         g_totalTarget = StringToDouble(value);
         PrintFormat("Total Target updated to: %.2f", g_totalTarget);
      }
   }
}

//+------------------------------------------------------------------+
//| Start All Pairs                                                    |
//+------------------------------------------------------------------+
void StartAllPairs()
{
   int count = 0;
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(g_pairs[i].enabled && g_pairs[i].dataValid)
      {
         if(g_pairs[i].directionBuy == 0)
         {
            g_pairs[i].directionBuy = -1;
            count++;
         }
         if(g_pairs[i].directionSell == 0)
         {
            g_pairs[i].directionSell = -1;
            count++;
         }
      }
   }
   PrintFormat("Start All: %d sides enabled (Ready)", count);
   
   if(g_dashboardEnabled)
   {
      UpdateDashboard();
      ChartRedraw();
   }
}

//+------------------------------------------------------------------+
//| Stop All Pairs                                                     |
//+------------------------------------------------------------------+
void StopAllPairs()
{
   int stopped = 0;
   int skipped = 0;
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(g_pairs[i].enabled)
      {
         if(g_pairs[i].directionBuy == -1)
         {
            g_pairs[i].directionBuy = 0;
            stopped++;
         }
         else if(g_pairs[i].directionBuy == 1)
         {
            skipped++;
         }
         
         if(g_pairs[i].directionSell == -1)
         {
            g_pairs[i].directionSell = 0;
            stopped++;
         }
         else if(g_pairs[i].directionSell == 1)
         {
            skipped++;
         }
      }
   }
   PrintFormat("Stop All: %d sides stopped, %d skipped (Active trades)", stopped, skipped);
   if(skipped > 0)
   {
      Print("Note: Close active trades first before stopping those sides");
   }
   
   if(g_dashboardEnabled)
   {
      UpdateDashboard();
      ChartRedraw();
   }
}

//+------------------------------------------------------------------+
//| Toggle Buy Side Status                                             |
//+------------------------------------------------------------------+
void ToggleBuySideStatus(int pairIndex)
{
   string prefix = "STAT_";
   string btnName = prefix + "_ST_BUY_" + IntegerToString(pairIndex);
   
   if(g_pairs[pairIndex].directionBuy == 0)
   {
      g_pairs[pairIndex].directionBuy = -1;
      if(g_dashboardEnabled)
      {
         ObjectSetInteger(0, btnName, OBJPROP_BGCOLOR, COLOR_ON);
         ObjectSetString(0, btnName, OBJPROP_TEXT, "ON");
      }
      PrintFormat("Pair %d Buy Side: Enabled (Ready)", pairIndex + 1);
   }
   else if(g_pairs[pairIndex].directionBuy == -1)
   {
      g_pairs[pairIndex].directionBuy = 0;
      if(g_dashboardEnabled)
      {
         ObjectSetInteger(0, btnName, OBJPROP_BGCOLOR, COLOR_OFF);
         ObjectSetString(0, btnName, OBJPROP_TEXT, "OFF");
      }
      PrintFormat("Pair %d Buy Side: Disabled (Off)", pairIndex + 1);
   }
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Toggle Sell Side Status                                            |
//+------------------------------------------------------------------+
void ToggleSellSideStatus(int pairIndex)
{
   string prefix = "STAT_";
   string btnName = prefix + "_ST_SELL_" + IntegerToString(pairIndex);
   
   if(g_pairs[pairIndex].directionSell == 0)
   {
      g_pairs[pairIndex].directionSell = -1;
      if(g_dashboardEnabled)
      {
         ObjectSetInteger(0, btnName, OBJPROP_BGCOLOR, COLOR_ON);
         ObjectSetString(0, btnName, OBJPROP_TEXT, "ON");
      }
      PrintFormat("Pair %d Sell Side: Enabled (Ready)", pairIndex + 1);
   }
   else if(g_pairs[pairIndex].directionSell == -1)
   {
      g_pairs[pairIndex].directionSell = 0;
      if(g_dashboardEnabled)
      {
         ObjectSetInteger(0, btnName, OBJPROP_BGCOLOR, COLOR_OFF);
         ObjectSetString(0, btnName, OBJPROP_TEXT, "OFF");
      }
      PrintFormat("Pair %d Sell Side: Disabled (Off)", pairIndex + 1);
   }
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Extract Pair Index from Object Name                                |
//+------------------------------------------------------------------+
int ExtractPairIndex(string objName, string pattern)
{
   int pos = StringFind(objName, pattern);
   if(pos < 0) return -1;
   
   string numStr = StringSubstr(objName, pos + StringLen(pattern));
   return (int)StringToInteger(numStr);
}

//+------------------------------------------------------------------+
//| License Verification (stub for tester)                             |
//+------------------------------------------------------------------+
bool VerifyLicense()
{
   // In production, this would call the API
   // For development, return true
   return true;
}

//+------------------------------------------------------------------+
//| News Filter (stub)                                                 |
//+------------------------------------------------------------------+
bool IsNewsPaused()
{
   // Implement news checking logic if needed
   return false;
}

//+------------------------------------------------------------------+
//| ================ STATISTICAL ENGINE ================               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Update All Pair Data                                               |
//+------------------------------------------------------------------+
void UpdateAllPairData()
{
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(!g_pairs[i].enabled) continue;
      UpdateSinglePairData(i);
   }
}

//+------------------------------------------------------------------+
//| Detect Correlation Type (Positive/Negative)                        |
//+------------------------------------------------------------------+
void DetectCorrelationType(int pairIndex)
{
   double r = g_pairs[pairIndex].correlation;
   
   if(r > 0)
      g_pairs[pairIndex].correlationType = 1;
   else
      g_pairs[pairIndex].correlationType = -1;
}

//+------------------------------------------------------------------+
//| Update Price History for a Pair                                    |
//+------------------------------------------------------------------+
void UpdatePriceHistory(int pairIndex)
{
   string symbolA = g_pairs[pairIndex].symbolA;
   string symbolB = g_pairs[pairIndex].symbolB;
   
   int period = MathMin(InpCorrBars, MAX_LOOKBACK);
   
   double closesA[], closesB[];
   ArraySetAsSeries(closesA, true);
   ArraySetAsSeries(closesB, true);
   
   // v3.2.7: Use SafeCopyClose with retry
   bool gotA = SafeCopyClose(symbolA, InpCorrTimeframe, 0, period, closesA);
   bool gotB = SafeCopyClose(symbolB, InpCorrTimeframe, 0, period, closesB);
   
   if(!gotA || !gotB)
   {
      if(InpDebugMode && (!g_isTesterMode || !InpDisableDebugInTester))
      {
         PrintFormat("Pair %d: Data incomplete - %s: %s, %s: %s",
                     pairIndex + 1, symbolA, gotA ? "OK" : "FAIL", symbolB, gotB ? "OK" : "FAIL");
      }
      g_pairs[pairIndex].dataValid = false;
      return;
   }
   
   // Check valid values
   bool hasValidDataA = false;
   bool hasValidDataB = false;
   for(int i = 0; i < period && (!hasValidDataA || !hasValidDataB); i++)
   {
      if(closesA[i] > 0) hasValidDataA = true;
      if(closesB[i] > 0) hasValidDataB = true;
   }
   
   if(!hasValidDataA || !hasValidDataB)
   {
      g_pairs[pairIndex].dataValid = false;
      return;
   }
   
   g_pairs[pairIndex].dataValid = true;
   
   for(int i = 0; i < period; i++)
   {
      g_pairData[pairIndex].pricesA[i] = closesA[i];
      g_pairData[pairIndex].pricesB[i] = closesB[i];
   }
}

//+------------------------------------------------------------------+
//| Calculate Returns                                                  |
//+------------------------------------------------------------------+
void CalculateLogReturns(int pairIndex)
{
   if(InpCorrMethod == CORR_PRICE_DIRECT) return;
   
   int returnCount = MathMin(InpCorrBars - 1, MAX_LOOKBACK - 1);
   bool useLog = (InpCorrMethod == CORR_LOG_RETURNS);
   
   for(int i = 0; i < returnCount; i++)
   {
      double priceA_t = g_pairData[pairIndex].pricesA[i];
      double priceA_t1 = g_pairData[pairIndex].pricesA[i + 1];
      double priceB_t = g_pairData[pairIndex].pricesB[i];
      double priceB_t1 = g_pairData[pairIndex].pricesB[i + 1];
      
      if(priceA_t1 > 0 && priceB_t1 > 0)
      {
         if(useLog)
         {
            g_pairData[pairIndex].returnsA[i] = MathLog(priceA_t / priceA_t1);
            g_pairData[pairIndex].returnsB[i] = MathLog(priceB_t / priceB_t1);
         }
         else
         {
            g_pairData[pairIndex].returnsA[i] = (priceA_t - priceA_t1) / priceA_t1;
            g_pairData[pairIndex].returnsB[i] = (priceB_t - priceB_t1) / priceB_t1;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate Pearson Correlation                                      |
//+------------------------------------------------------------------+
double CalculatePearsonCorrelation(int pairIndex)
{
   if(!g_pairs[pairIndex].dataValid) return 0;
   
   switch(InpCorrMethod)
   {
      case CORR_PRICE_DIRECT:
         return CalculatePriceCorrelation(pairIndex);
         
      case CORR_PERCENTAGE_CHANGE:
      case CORR_LOG_RETURNS:
         return CalculateReturnCorrelation(pairIndex);
         
      default:
         return CalculatePriceCorrelation(pairIndex);
   }
}

//+------------------------------------------------------------------+
//| Calculate Price Direct Correlation                                 |
//+------------------------------------------------------------------+
double CalculatePriceCorrelation(int pairIndex)
{
   int n = MathMin(InpCorrBars, MAX_LOOKBACK);
   if(n < 10) return 0;
   
   double sumA = 0, sumB = 0;
   double sumA2 = 0, sumB2 = 0;
   double sumAB = 0;
   
   for(int i = 0; i < n; i++)
   {
      double priceA = g_pairData[pairIndex].pricesA[i];
      double priceB = g_pairData[pairIndex].pricesB[i];
      
      sumA += priceA;
      sumB += priceB;
      sumA2 += priceA * priceA;
      sumB2 += priceB * priceB;
      sumAB += priceA * priceB;
   }
   
   double meanA = sumA / n;
   double meanB = sumB / n;
   
   double covariance = (sumAB / n) - (meanA * meanB);
   double varA = (sumA2 / n) - (meanA * meanA);
   double varB = (sumB2 / n) - (meanB * meanB);
   
   if(varA <= 0 || varB <= 0) return 0;
   
   double stdDevA = MathSqrt(varA);
   double stdDevB = MathSqrt(varB);
   
   return covariance / (stdDevA * stdDevB);
}

//+------------------------------------------------------------------+
//| Calculate Return-Based Correlation                                 |
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
      double retA = g_pairData[pairIndex].returnsA[i];
      double retB = g_pairData[pairIndex].returnsB[i];
      
      sumA += retA;
      sumB += retB;
      sumA2 += retA * retA;
      sumB2 += retB * retB;
      sumAB += retA * retB;
   }
   
   double meanA = sumA / n;
   double meanB = sumB / n;
   
   double covariance = (sumAB / n) - (meanA * meanB);
   double varA = (sumA2 / n) - (meanA * meanA);
   double varB = (sumB2 / n) - (meanB * meanB);
   
   if(varA <= 0 || varB <= 0) return 0;
   
   double stdDevA = MathSqrt(varA);
   double stdDevB = MathSqrt(varB);
   
   if(stdDevA == 0 || stdDevB == 0) return 0;
   
   return covariance / (stdDevA * stdDevB);
}

//+------------------------------------------------------------------+
//| Calculate Hedge Ratio (Beta) v3.2.6                                |
//+------------------------------------------------------------------+
double CalculateHedgeRatio(int pairIndex)
{
   if(!g_pairs[pairIndex].dataValid) return 1.0;
   
   double rawBeta = 1.0;
   double pipBeta = 0;
   double pctBeta = 0;
   
   switch(InpBetaMode)
   {
      case BETA_MANUAL_FIXED:
         rawBeta = (g_pairs[pairIndex].manualBeta > 0) 
                   ? g_pairs[pairIndex].manualBeta 
                   : InpManualBetaDefault;
         rawBeta = MathMax(0.1, MathMin(10.0, rawBeta));
         return rawBeta;
         
      case BETA_PIP_VALUE_ONLY:
         rawBeta = CalculatePipValueBeta(pairIndex);
         return rawBeta;
         
      case BETA_PERCENTAGE_RAW:
         if(InpCorrMethod == CORR_PRICE_DIRECT)
            rawBeta = CalculatePriceBasedBeta(pairIndex);
         else
            rawBeta = CalculateReturnBasedBeta(pairIndex);
         return rawBeta;
         
      case BETA_AUTO_SMOOTH:
      default:
      {
         pipBeta = CalculatePipValueBeta(pairIndex);
         
         if(InpCorrMethod == CORR_PRICE_DIRECT)
            pctBeta = CalculatePriceBasedBeta(pairIndex);
         else
            pctBeta = CalculateReturnBasedBeta(pairIndex);
         
         double pipWeight = MathMax(0.5, MathMin(0.9, InpPipBetaWeight));
         rawBeta = pipBeta * pipWeight + pctBeta * (1.0 - pipWeight);
         
         double smoothBeta = ApplyBetaSmoothing(pairIndex, rawBeta);
         
         return smoothBeta;
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate Pip-Value Based Beta                                     |
//+------------------------------------------------------------------+
double CalculatePipValueBeta(int pairIndex)
{
   string symbolA = g_pairs[pairIndex].symbolA;
   string symbolB = g_pairs[pairIndex].symbolB;
   
   double pipValueA = GetPipValue(symbolA);
   double pipValueB = GetPipValue(symbolB);
   
   if(pipValueB <= 0 || pipValueA <= 0) return 1.0;
   
   double beta = pipValueA / pipValueB;
   
   beta = MathMax(0.1, MathMin(10.0, beta));
   
   return beta;
}

//+------------------------------------------------------------------+
//| Apply Beta EMA Smoothing                                           |
//+------------------------------------------------------------------+
double ApplyBetaSmoothing(int pairIndex, double newBeta)
{
   if(!g_pairs[pairIndex].betaInitialized)
   {
      g_pairs[pairIndex].prevBeta = newBeta;
      g_pairs[pairIndex].betaInitialized = true;
      return newBeta;
   }
   
   double alpha = MathMax(0.05, MathMin(0.3, InpBetaSmoothFactor));
   double smoothBeta = alpha * newBeta + (1.0 - alpha) * g_pairs[pairIndex].prevBeta;
   
   g_pairs[pairIndex].prevBeta = smoothBeta;
   
   return smoothBeta;
}

//+------------------------------------------------------------------+
//| Calculate Price-Based Beta                                         |
//+------------------------------------------------------------------+
double CalculatePriceBasedBeta(int pairIndex)
{
   int n = MathMin(InpCorrBars, MAX_LOOKBACK);
   if(n < 10) return 1.0;
   
   double sumA = 0, sumB = 0;
   double sumA2 = 0;
   double sumAB = 0;
   int count = 0;
   
   for(int i = 1; i < n; i++)
   {
      double priceA_t = g_pairData[pairIndex].pricesA[i];
      double priceA_t1 = g_pairData[pairIndex].pricesA[i - 1];
      double priceB_t = g_pairData[pairIndex].pricesB[i];
      double priceB_t1 = g_pairData[pairIndex].pricesB[i - 1];
      
      if(priceA_t1 <= 0 || priceB_t1 <= 0) continue;
      
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
   
   double covariance = (sumAB / count) - (meanA * meanB);
   double varianceA = (sumA2 / count) - (meanA * meanA);
   
   if(varianceA <= 0) return 1.0;
   
   double beta = MathAbs(covariance / varianceA);
   
   beta = MathMax(0.1, MathMin(10.0, beta));
   
   return beta;
}

//+------------------------------------------------------------------+
//| Calculate Return-Based Beta                                        |
//+------------------------------------------------------------------+
double CalculateReturnBasedBeta(int pairIndex)
{
   int n = MathMin(InpCorrBars - 1, MAX_LOOKBACK - 1);
   if(n < 10) return 1.0;
   
   double sumA = 0, sumB = 0;
   double sumA2 = 0;
   double sumAB = 0;
   
   for(int i = 0; i < n; i++)
   {
      double retA = g_pairData[pairIndex].returnsA[i];
      double retB = g_pairData[pairIndex].returnsB[i];
      
      sumA += retA;
      sumB += retB;
      sumA2 += retA * retA;
      sumAB += retA * retB;
   }
   
   double meanA = sumA / n;
   double meanB = sumB / n;
   
   double covariance = (sumAB / n) - (meanA * meanB);
   double varianceA = (sumA2 / n) - (meanA * meanA);
   
   if(varianceA <= 0) return 1.0;
   
   double beta = MathAbs(covariance / varianceA);
   
   beta = MathMax(0.1, MathMin(10.0, beta));
   
   return beta;
}

//+------------------------------------------------------------------+
//| Update Spread History                                              |
//+------------------------------------------------------------------+
void UpdateSpreadHistory(int pairIndex)
{
   double beta = g_pairs[pairIndex].hedgeRatio;
   int period = MathMin(InpCorrBars, MAX_LOOKBACK);
   
   for(int i = 0; i < period; i++)
   {
      double priceA = g_pairData[pairIndex].pricesA[i];
      double priceB = g_pairData[pairIndex].pricesB[i];
      
      if(priceA > 0 && priceB > 0)
      {
         g_pairData[pairIndex].spreadHistory[i] = MathLog(priceA) - beta * MathLog(priceB);
      }
   }
   
   g_pairs[pairIndex].currentSpread = g_pairData[pairIndex].spreadHistory[0];
   CalculateSpreadMeanStdDev(pairIndex);
}

//+------------------------------------------------------------------+
//| Calculate Spread Mean and Standard Deviation                       |
//+------------------------------------------------------------------+
void CalculateSpreadMeanStdDev(int pairIndex)
{
   int n = MathMin(InpCorrBars, MAX_LOOKBACK);
   double sum = 0;
   
   for(int i = 0; i < n; i++)
   {
      sum += g_pairData[pairIndex].spreadHistory[i];
   }
   double mean = sum / n;
   g_pairs[pairIndex].spreadMean = mean;
   
   double sumSqDiff = 0;
   for(int i = 0; i < n; i++)
   {
      double diff = g_pairData[pairIndex].spreadHistory[i] - mean;
      sumSqDiff += diff * diff;
   }
   g_pairs[pairIndex].spreadStdDev = MathSqrt(sumSqDiff / n);
}

//+------------------------------------------------------------------+
//| Calculate Z-Score for Spread                                       |
//+------------------------------------------------------------------+
double CalculateSpreadZScore(int pairIndex)
{
   double currentSpread = g_pairs[pairIndex].currentSpread;
   double mean = g_pairs[pairIndex].spreadMean;
   double stdDev = g_pairs[pairIndex].spreadStdDev;
   
   if(stdDev == 0) return 0;
   
   return (currentSpread - mean) / stdDev;
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
//| Calculate Dollar-Neutral Lot Sizes                                 |
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
      g_pairs[pairIndex].lotBuyA = baseLot;
      g_pairs[pairIndex].lotBuyB = baseLot;
      g_pairs[pairIndex].lotSellA = baseLot;
      g_pairs[pairIndex].lotSellB = baseLot;
      return;
   }
   
   double lotA = baseLot;
   double lotB = baseLot * hedgeRatio * (pipValueA / pipValueB);
   
   double minLotB = SymbolInfoDouble(symbolB, SYMBOL_VOLUME_MIN);
   double maxLotB = SymbolInfoDouble(symbolB, SYMBOL_VOLUME_MAX);
   double stepLotB = SymbolInfoDouble(symbolB, SYMBOL_VOLUME_STEP);
   
   lotB = MathMax(minLotB, MathMin(maxLotB, lotB));
   lotB = MathFloor(lotB / stepLotB) * stepLotB;
   lotB = MathMin(lotB, InpMaxLot);
   
   g_pairs[pairIndex].lotBuyA = lotA;
   g_pairs[pairIndex].lotBuyB = lotB;
   g_pairs[pairIndex].lotSellA = lotA;
   g_pairs[pairIndex].lotSellB = lotB;
}

//+------------------------------------------------------------------+
//| ================ SIGNAL ENGINE ================                    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Analyze All Pairs for Trading Signals                              |
//+------------------------------------------------------------------+
void AnalyzeAllPairs()
{
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(!g_pairs[i].enabled) continue;
      
      if(MathAbs(g_pairs[i].correlation) < InpMinCorrelation)
         continue;
      
      double zScore = g_pairs[i].zScore;
      
      // === BUY SIDE ENTRY ===
      if(g_pairs[i].directionBuy == -1 && g_pairs[i].orderCountBuy < g_pairs[i].maxOrderBuy)
      {
         if(zScore < -InpEntryZScore)
         {
            if(OpenBuySideTrade(i))
            {
               g_pairs[i].directionBuy = 1;
               // v3.2.7: Record entry price for ATR averaging
               g_pairs[i].avgEntryPriceBuyA = SymbolInfoDouble(g_pairs[i].symbolA, SYMBOL_ASK);
               g_pairs[i].avgCountBuy = 0;
               g_pairs[i].lastAvgZBuy = MathAbs(zScore);
            }
         }
      }
      
      // === SELL SIDE ENTRY ===
      if(g_pairs[i].directionSell == -1 && g_pairs[i].orderCountSell < g_pairs[i].maxOrderSell)
      {
         if(zScore > InpEntryZScore)
         {
            if(OpenSellSideTrade(i))
            {
               g_pairs[i].directionSell = 1;
               // v3.2.7: Record entry price for ATR averaging
               g_pairs[i].avgEntryPriceSellA = SymbolInfoDouble(g_pairs[i].symbolA, SYMBOL_BID);
               g_pairs[i].avgCountSell = 0;
               g_pairs[i].lastAvgZSell = MathAbs(zScore);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| v3.2.7: Check Averaging Signals                                    |
//+------------------------------------------------------------------+
void CheckAveragingSignals()
{
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(!g_pairs[i].enabled) continue;
      
      // === Buy Side Averaging ===
      if(g_pairs[i].directionBuy == 1 && g_pairs[i].avgCountBuy < InpMaxAveragingOrders)
      {
         if(InpAveragingMode == AVG_MODE_ZSCORE)
            CheckZScoreAveraging(i, true);
         else
            CheckAtrAveraging(i, true);
      }
      
      // === Sell Side Averaging ===
      if(g_pairs[i].directionSell == 1 && g_pairs[i].avgCountSell < InpMaxAveragingOrders)
      {
         if(InpAveragingMode == AVG_MODE_ZSCORE)
            CheckZScoreAveraging(i, false);
         else
            CheckAtrAveraging(i, false);
      }
   }
}

//+------------------------------------------------------------------+
//| v3.2.7: Check Z-Score Based Averaging                              |
//+------------------------------------------------------------------+
void CheckZScoreAveraging(int pairIndex, bool isBuySide)
{
   double zScore = g_pairs[pairIndex].zScore;
   double absZ = MathAbs(zScore);
   double lastTriggered = isBuySide ? g_pairs[pairIndex].lastAvgZBuy : g_pairs[pairIndex].lastAvgZSell;
   
   for(int lvl = 0; lvl < g_zScoreGridCount; lvl++)
   {
      double level = g_zScoreGridLevels[lvl];
      
      // Check if this level is higher than last triggered and Z-Score has reached it
      if(level > lastTriggered && absZ >= level)
      {
         // For Buy side, Z should be negative (going more negative)
         // For Sell side, Z should be positive (going more positive)
         bool validDirection = (isBuySide && zScore < 0) || (!isBuySide && zScore > 0);
         
         if(validDirection)
         {
            if(OpenAveragingOrder(pairIndex, isBuySide))
            {
               if(isBuySide)
               {
                  g_pairs[pairIndex].lastAvgZBuy = level;
                  g_pairs[pairIndex].avgCountBuy++;
               }
               else
               {
                  g_pairs[pairIndex].lastAvgZSell = level;
                  g_pairs[pairIndex].avgCountSell++;
               }
               PrintFormat("Pair %d %s AVG ORDER at Z=%.2f (Level %.2f) [%d/%d]", 
                  pairIndex + 1, isBuySide ? "BUY" : "SELL", zScore, level,
                  isBuySide ? g_pairs[pairIndex].avgCountBuy : g_pairs[pairIndex].avgCountSell,
                  InpMaxAveragingOrders);
            }
            break;  // Only one order per tick
         }
      }
   }
}

//+------------------------------------------------------------------+
//| v3.2.7: Check ATR Based Averaging                                  |
//+------------------------------------------------------------------+
void CheckAtrAveraging(int pairIndex, bool isBuySide)
{
   string symbolA = g_pairs[pairIndex].symbolA;
   
   // Calculate ATR using handle + CopyBuffer (MQL5 standard)
   int atrHandle = iATR(symbolA, InpAtrTimeframe, InpAtrPeriod);
   if(atrHandle == INVALID_HANDLE) return;
   
   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);
   if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) <= 0)
   {
      IndicatorRelease(atrHandle);
      return;
   }
   
   double atr = atrBuffer[0];
   IndicatorRelease(atrHandle);
   if(atr <= 0) return;
   
   double gridStep = atr * InpAtrMultiplier;
   
   double currentPrice = isBuySide 
      ? SymbolInfoDouble(symbolA, SYMBOL_ASK) 
      : SymbolInfoDouble(symbolA, SYMBOL_BID);
   double entryPrice = isBuySide 
      ? g_pairs[pairIndex].avgEntryPriceBuyA 
      : g_pairs[pairIndex].avgEntryPriceSellA;
   
   if(entryPrice == 0) return;
   
   double distance = MathAbs(currentPrice - entryPrice);
   int currentOrders = isBuySide ? g_pairs[pairIndex].avgCountBuy : g_pairs[pairIndex].avgCountSell;
   
   // Check if price has moved enough for next averaging order
   int expectedOrders = (int)MathFloor(distance / gridStep);
   
   if(expectedOrders > currentOrders && currentOrders < InpMaxAveragingOrders)
   {
      // For Buy side: price should have moved down (against us)
      // For Sell side: price should have moved up (against us)
      bool validDirection = (isBuySide && currentPrice < entryPrice) || 
                            (!isBuySide && currentPrice > entryPrice);
      
      if(validDirection)
      {
         if(OpenAveragingOrder(pairIndex, isBuySide))
         {
            if(isBuySide)
               g_pairs[pairIndex].avgCountBuy++;
            else
               g_pairs[pairIndex].avgCountSell++;
            
            PrintFormat("Pair %d %s ATR AVG ORDER: Distance=%.5f, GridStep=%.5f [%d/%d]", 
               pairIndex + 1, isBuySide ? "BUY" : "SELL", distance, gridStep,
               isBuySide ? g_pairs[pairIndex].avgCountBuy : g_pairs[pairIndex].avgCountSell,
               InpMaxAveragingOrders);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| v3.2.7: Open Averaging Order                                       |
//+------------------------------------------------------------------+
bool OpenAveragingOrder(int pairIndex, bool isBuySide)
{
   string symbolA = g_pairs[pairIndex].symbolA;
   string symbolB = g_pairs[pairIndex].symbolB;
   int corrType = g_pairs[pairIndex].correlationType;
   
   double lotA = (isBuySide ? g_pairs[pairIndex].lotBuyA : g_pairs[pairIndex].lotSellA) * InpAveragingLotMult;
   double lotB = (isBuySide ? g_pairs[pairIndex].lotBuyB : g_pairs[pairIndex].lotSellB) * InpAveragingLotMult;
   
   // Normalize lots
   double minLotA = SymbolInfoDouble(symbolA, SYMBOL_VOLUME_MIN);
   double minLotB = SymbolInfoDouble(symbolB, SYMBOL_VOLUME_MIN);
   double stepA = SymbolInfoDouble(symbolA, SYMBOL_VOLUME_STEP);
   double stepB = SymbolInfoDouble(symbolB, SYMBOL_VOLUME_STEP);
   
   lotA = MathMax(minLotA, MathFloor(lotA / stepA) * stepA);
   lotB = MathMax(minLotB, MathFloor(lotB / stepB) * stepB);
   
   string comment = StringFormat("StatArb_AVG_%s_%d", isBuySide ? "BUY" : "SELL", pairIndex + 1);
   
   ulong ticketA = 0;
   ulong ticketB = 0;
   
   if(isBuySide)
   {
      // Buy Side: Buy A, Sell/Buy B based on correlation
      double askA = SymbolInfoDouble(symbolA, SYMBOL_ASK);
      if(g_trade.Buy(lotA, symbolA, askA, 0, 0, comment))
      {
         ticketA = g_trade.ResultOrder();
      }
      else return false;
      
      if(corrType == 1)  // Positive: Sell B
      {
         double bidB = SymbolInfoDouble(symbolB, SYMBOL_BID);
         if(!g_trade.Sell(lotB, symbolB, bidB, 0, 0, comment))
         {
            g_trade.PositionClose(ticketA);
            return false;
         }
      }
      else  // Negative: Buy B
      {
         double askB = SymbolInfoDouble(symbolB, SYMBOL_ASK);
         if(!g_trade.Buy(lotB, symbolB, askB, 0, 0, comment))
         {
            g_trade.PositionClose(ticketA);
            return false;
         }
      }
      
      g_pairs[pairIndex].orderCountBuy++;
   }
   else
   {
      // Sell Side: Sell A, Buy/Sell B based on correlation
      double bidA = SymbolInfoDouble(symbolA, SYMBOL_BID);
      if(g_trade.Sell(lotA, symbolA, bidA, 0, 0, comment))
      {
         ticketA = g_trade.ResultOrder();
      }
      else return false;
      
      if(corrType == 1)  // Positive: Buy B
      {
         double askB = SymbolInfoDouble(symbolB, SYMBOL_ASK);
         if(!g_trade.Buy(lotB, symbolB, askB, 0, 0, comment))
         {
            g_trade.PositionClose(ticketA);
            return false;
         }
      }
      else  // Negative: Sell B
      {
         double bidB = SymbolInfoDouble(symbolB, SYMBOL_BID);
         if(!g_trade.Sell(lotB, symbolB, bidB, 0, 0, comment))
         {
            g_trade.PositionClose(ticketA);
            return false;
         }
      }
      
      g_pairs[pairIndex].orderCountSell++;
   }
   
   return true;
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
   
   if(corrType == 1)
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
   else
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
   
   if(corrType == 1)
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
   else
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
//| Close Buy Side Trade                                               |
//+------------------------------------------------------------------+
bool CloseBuySide(int pairIndex)
{
   if(g_pairs[pairIndex].directionBuy == 0) return false;
   
   bool closedA = false;
   bool closedB = false;
   
   if(g_pairs[pairIndex].ticketBuyA > 0)
   {
      if(PositionSelectByTicket(g_pairs[pairIndex].ticketBuyA))
      {
         closedA = g_trade.PositionClose(g_pairs[pairIndex].ticketBuyA);
      }
      else closedA = true;
   }
   else closedA = true;
   
   if(g_pairs[pairIndex].ticketBuyB > 0)
   {
      if(PositionSelectByTicket(g_pairs[pairIndex].ticketBuyB))
      {
         closedB = g_trade.PositionClose(g_pairs[pairIndex].ticketBuyB);
      }
      else closedB = true;
   }
   else closedB = true;
   
   // v3.2.7: Also close averaging orders (by comment)
   CloseAveragingOrders(pairIndex, true);
   
   if(closedA && closedB)
   {
      PrintFormat("Pair %d BUY SIDE CLOSED | Profit: %.2f", pairIndex + 1, g_pairs[pairIndex].profitBuy);
      
      g_dailyProfit += g_pairs[pairIndex].profitBuy;
      g_weeklyProfit += g_pairs[pairIndex].profitBuy;
      g_monthlyProfit += g_pairs[pairIndex].profitBuy;
      g_allTimeProfit += g_pairs[pairIndex].profitBuy;
      g_dailyLot += g_pairs[pairIndex].lotBuyA + g_pairs[pairIndex].lotBuyB;
      g_weeklyLot += g_pairs[pairIndex].lotBuyA + g_pairs[pairIndex].lotBuyB;
      g_monthlyLot += g_pairs[pairIndex].lotBuyA + g_pairs[pairIndex].lotBuyB;
      g_allTimeLot += g_pairs[pairIndex].lotBuyA + g_pairs[pairIndex].lotBuyB;
      
      g_pairs[pairIndex].ticketBuyA = 0;
      g_pairs[pairIndex].ticketBuyB = 0;
      g_pairs[pairIndex].directionBuy = -1;
      g_pairs[pairIndex].profitBuy = 0;
      g_pairs[pairIndex].entryTimeBuy = 0;
      g_pairs[pairIndex].orderCountBuy = 0;
      g_pairs[pairIndex].lotBuyA = 0;
      g_pairs[pairIndex].lotBuyB = 0;
      g_pairs[pairIndex].avgCountBuy = 0;
      g_pairs[pairIndex].lastAvgZBuy = 0;
      g_pairs[pairIndex].avgEntryPriceBuyA = 0;
      
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Close Sell Side Trade                                              |
//+------------------------------------------------------------------+
bool CloseSellSide(int pairIndex)
{
   if(g_pairs[pairIndex].directionSell == 0) return false;
   
   bool closedA = false;
   bool closedB = false;
   
   if(g_pairs[pairIndex].ticketSellA > 0)
   {
      if(PositionSelectByTicket(g_pairs[pairIndex].ticketSellA))
      {
         closedA = g_trade.PositionClose(g_pairs[pairIndex].ticketSellA);
      }
      else closedA = true;
   }
   else closedA = true;
   
   if(g_pairs[pairIndex].ticketSellB > 0)
   {
      if(PositionSelectByTicket(g_pairs[pairIndex].ticketSellB))
      {
         closedB = g_trade.PositionClose(g_pairs[pairIndex].ticketSellB);
      }
      else closedB = true;
   }
   else closedB = true;
   
   // v3.2.7: Also close averaging orders
   CloseAveragingOrders(pairIndex, false);
   
   if(closedA && closedB)
   {
      PrintFormat("Pair %d SELL SIDE CLOSED | Profit: %.2f", pairIndex + 1, g_pairs[pairIndex].profitSell);
      
      g_dailyProfit += g_pairs[pairIndex].profitSell;
      g_weeklyProfit += g_pairs[pairIndex].profitSell;
      g_monthlyProfit += g_pairs[pairIndex].profitSell;
      g_allTimeProfit += g_pairs[pairIndex].profitSell;
      g_dailyLot += g_pairs[pairIndex].lotSellA + g_pairs[pairIndex].lotSellB;
      g_weeklyLot += g_pairs[pairIndex].lotSellA + g_pairs[pairIndex].lotSellB;
      g_monthlyLot += g_pairs[pairIndex].lotSellA + g_pairs[pairIndex].lotSellB;
      g_allTimeLot += g_pairs[pairIndex].lotSellA + g_pairs[pairIndex].lotSellB;
      
      g_pairs[pairIndex].ticketSellA = 0;
      g_pairs[pairIndex].ticketSellB = 0;
      g_pairs[pairIndex].directionSell = -1;
      g_pairs[pairIndex].profitSell = 0;
      g_pairs[pairIndex].entryTimeSell = 0;
      g_pairs[pairIndex].orderCountSell = 0;
      g_pairs[pairIndex].lotSellA = 0;
      g_pairs[pairIndex].lotSellB = 0;
      g_pairs[pairIndex].avgCountSell = 0;
      g_pairs[pairIndex].lastAvgZSell = 0;
      g_pairs[pairIndex].avgEntryPriceSellA = 0;
      
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| v3.2.7: Close Averaging Orders by Comment                          |
//+------------------------------------------------------------------+
void CloseAveragingOrders(int pairIndex, bool isBuySide)
{
   string pattern = StringFormat("StatArb_AVG_%s_%d", isBuySide ? "BUY" : "SELL", pairIndex + 1);
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      
      string comment = PositionGetString(POSITION_COMMENT);
      if(StringFind(comment, pattern) >= 0)
      {
         g_trade.PositionClose(ticket);
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
//| ================ POSITION MANAGEMENT v3.2.7 ================       |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Manage All Open Positions (v3.2.7 - with Exit Mode)                |
//+------------------------------------------------------------------+
void ManageAllPositions()
{
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(!g_pairs[i].enabled) continue;
      
      double zScore = g_pairs[i].zScore;
      
      // === Manage Buy Side ===
      if(g_pairs[i].directionBuy == 1)
      {
         bool shouldClose = CheckExitConditions(i, true, zScore);
         
         if(shouldClose)
         {
            CloseBuySide(i);
         }
         // Exit: Correlation dropped
         else if(MathAbs(g_pairs[i].correlation) < InpMinCorrelation * 0.8)
         {
            PrintFormat("Pair %d Buy Side: Correlation dropped - Closing", i + 1);
            CloseBuySide(i);
         }
         // Exit: Max holding time
         else if(InpMaxHoldingBars > 0)
         {
            int barsHeld = iBarShift(_Symbol, InpTimeframe, g_pairs[i].entryTimeBuy);
            if(barsHeld >= InpMaxHoldingBars)
            {
               PrintFormat("Pair %d Buy Side: Max holding time - Closing", i + 1);
               CloseBuySide(i);
            }
         }
      }
      
      // === Manage Sell Side ===
      if(g_pairs[i].directionSell == 1)
      {
         bool shouldClose = CheckExitConditions(i, false, zScore);
         
         if(shouldClose)
         {
            CloseSellSide(i);
         }
         // Exit: Correlation dropped
         else if(MathAbs(g_pairs[i].correlation) < InpMinCorrelation * 0.8)
         {
            PrintFormat("Pair %d Sell Side: Correlation dropped - Closing", i + 1);
            CloseSellSide(i);
         }
         // Exit: Max holding time
         else if(InpMaxHoldingBars > 0)
         {
            int barsHeld = iBarShift(_Symbol, InpTimeframe, g_pairs[i].entryTimeSell);
            if(barsHeld >= InpMaxHoldingBars)
            {
               PrintFormat("Pair %d Sell Side: Max holding time - Closing", i + 1);
               CloseSellSide(i);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| v3.2.7: Check Exit Conditions based on Exit Mode                   |
//+------------------------------------------------------------------+
bool CheckExitConditions(int pairIndex, bool isBuySide, double zScore)
{
   // v3.2.8: Minimum holding time check - prevent immediate close after entry
   datetime entryTime = isBuySide ? g_pairs[pairIndex].entryTimeBuy : g_pairs[pairIndex].entryTimeSell;
   if(InpMinHoldingBars > 0 && entryTime > 0)
   {
      int barsHeld = iBarShift(_Symbol, InpTimeframe, entryTime);
      if(barsHeld < InpMinHoldingBars)
      {
         return false;  // Not enough time held, don't check exit conditions yet
      }
   }
   
   // Z-Score Exit condition
   // Buy: entered at Z < -Entry, exit when Z >= -ExitZScore (back toward 0)
   // Sell: entered at Z > +Entry, exit when Z <= +ExitZScore (back toward 0)
   bool zScoreExit = isBuySide 
      ? (zScore >= -InpExitZScore) 
      : (zScore <= InpExitZScore);
   
   // Profit Target Exit condition
   double profit = isBuySide ? g_pairs[pairIndex].profitBuy : g_pairs[pairIndex].profitSell;
   double target = isBuySide ? g_pairs[pairIndex].targetBuy : g_pairs[pairIndex].targetSell;
   bool profitExit = (profit >= target);
   
   // v3.2.8: Check if profit is positive (for Z-Score exit modes)
   bool hasPositiveProfit = (profit > 0);
   
   bool shouldClose = false;
   string reason = "";
   
   switch(InpExitMode)
   {
      case EXIT_ZSCORE_ONLY:
         // v3.2.8: If InpRequirePositiveProfit is true, also require profit > 0
         if(InpRequirePositiveProfit)
         {
            shouldClose = zScoreExit && hasPositiveProfit;
            reason = "Z-Score+Profit>0";
         }
         else
         {
            shouldClose = zScoreExit;
            reason = "Z-Score";
         }
         break;
         
      case EXIT_PROFIT_ONLY:
         shouldClose = profitExit;
         reason = "Profit Target";
         break;
         
      case EXIT_ZSCORE_OR_PROFIT:
         // v3.2.8: For Z-Score exit in OR mode, also check positive profit if enabled
         if(InpRequirePositiveProfit)
         {
            bool zScoreWithProfit = zScoreExit && hasPositiveProfit;
            shouldClose = zScoreWithProfit || profitExit;
            reason = zScoreWithProfit ? (profitExit ? "Z+Profit" : "Z+Profit>0") : "Profit Target";
         }
         else
         {
            shouldClose = zScoreExit || profitExit;
            reason = zScoreExit ? (profitExit ? "Z+Profit" : "Z-Score") : "Profit Target";
         }
         break;
         
      case EXIT_ZSCORE_AND_PROFIT:
         shouldClose = zScoreExit && profitExit;
         reason = "Z+Profit Both";
         break;
   }
   
   if(shouldClose)
   {
      PrintFormat("Pair %d %s CLOSE [%s]: Z=%.2f, Profit=%.2f/%.2f, BarsHeld=%d", 
         pairIndex + 1, isBuySide ? "BUY" : "SELL", reason, 
         zScore, profit, target,
         iBarShift(_Symbol, InpTimeframe, entryTime));
   }
   
   return shouldClose;
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
      
      // === Update Buy Side Profit ===
      if(g_pairs[i].directionBuy == 1)
      {
         double profitA = 0, profitB = 0;
         
         if(g_pairs[i].ticketBuyA > 0 && PositionSelectByTicket(g_pairs[i].ticketBuyA))
         {
            profitA = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
         }
         if(g_pairs[i].ticketBuyB > 0 && PositionSelectByTicket(g_pairs[i].ticketBuyB))
         {
            profitB = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
         }
         
         // v3.2.7: Add averaging orders profit
         profitA += GetAveragingProfit(i, true);
         
         g_pairs[i].profitBuy = profitA + profitB;
      }
      else
      {
         g_pairs[i].profitBuy = 0;
      }
      
      // === Update Sell Side Profit ===
      if(g_pairs[i].directionSell == 1)
      {
         double profitA = 0, profitB = 0;
         
         if(g_pairs[i].ticketSellA > 0 && PositionSelectByTicket(g_pairs[i].ticketSellA))
         {
            profitA = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
         }
         if(g_pairs[i].ticketSellB > 0 && PositionSelectByTicket(g_pairs[i].ticketSellB))
         {
            profitB = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
         }
         
         // v3.2.7: Add averaging orders profit
         profitA += GetAveragingProfit(i, false);
         
         g_pairs[i].profitSell = profitA + profitB;
      }
      else
      {
         g_pairs[i].profitSell = 0;
      }
      
      g_pairs[i].totalPairProfit = g_pairs[i].profitBuy + g_pairs[i].profitSell;
      g_totalCurrentProfit += g_pairs[i].totalPairProfit;
   }
}

//+------------------------------------------------------------------+
//| v3.2.7: Get Profit from Averaging Orders                           |
//+------------------------------------------------------------------+
double GetAveragingProfit(int pairIndex, bool isBuySide)
{
   string pattern = StringFormat("StatArb_AVG_%s_%d", isBuySide ? "BUY" : "SELL", pairIndex + 1);
   double totalProfit = 0;
   
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      
      string comment = PositionGetString(POSITION_COMMENT);
      if(StringFind(comment, pattern) >= 0)
      {
         totalProfit += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      }
   }
   
   return totalProfit;
}

//+------------------------------------------------------------------+
//| Check Total Portfolio Target                                       |
//+------------------------------------------------------------------+
void CheckTotalTarget()
{
   if(g_totalCurrentProfit >= g_totalTarget)
   {
      PrintFormat("TOTAL TARGET REACHED: %.2f >= %.2f - Closing ALL positions!",
         g_totalCurrentProfit, g_totalTarget);
      
      for(int i = 0; i < MAX_PAIRS; i++)
      {
         CloseBuySide(i);
         CloseSellSide(i);
      }
   }
}

//+------------------------------------------------------------------+
//| Update Account Statistics                                          |
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
      g_dayStart = TimeCurrent();
   }
   
   TimeToStruct(g_weekStart, dtStart);
   if(dt.day_of_week < dtStart.day_of_week || dt.day - dtStart.day >= 7)
   {
      g_weeklyProfit = 0;
      g_weeklyLot = 0;
      g_weekStart = TimeCurrent();
   }
   
   TimeToStruct(g_monthStart, dtStart);
   if(dt.mon != dtStart.mon)
   {
      g_monthlyProfit = 0;
      g_monthlyLot = 0;
      g_monthStart = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| ================ RISK MANAGEMENT v3.2.7 ================           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check Risk Limits (v3.2.7 - with pause reason)                     |
//+------------------------------------------------------------------+
void CheckRiskLimits()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   if(balance <= 0) return;

   // Safety: avoid divide-by-zero / uninitialized peaks
   if(g_maxEquity <= 0)
   {
      g_maxEquity = equity;
      g_peakEquityBeforeDD = equity;
      return;
   }
   
   double drawdown = ((g_maxEquity - equity) / g_maxEquity) * 100;
   if(drawdown < 0) drawdown = 0;
   
   if(drawdown > g_maxDrawdownPercent) g_maxDrawdownPercent = drawdown;
   
   // 0 = disabled (prevents "DD 0.00%" instant-close loops)
   if(InpEmergencyCloseDD > 0 && drawdown >= InpEmergencyCloseDD)
   {
      PrintFormat("EMERGENCY: Drawdown %.2f%% exceeded limit - Closing ALL and PAUSING", drawdown);
      CloseAllBuySides();
      CloseAllSellSides();
      
      g_peakEquityBeforeDD = g_maxEquity;  // Save peak for recovery check
      g_isPaused = true;
      g_pauseReason = "DD_LIMIT";
      
      if(InpAutoResumeAfterDD)
      {
         PrintFormat("Auto-resume enabled: Will resume when equity recovers to %.1f%% of peak (%.2f)",
                     InpResumeEquityPercent, g_peakEquityBeforeDD * InpResumeEquityPercent / 100);
      }
      return;
   }
}

//+------------------------------------------------------------------+
//| ================ DASHBOARD PANEL v3.2.7 ================           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Create Dashboard Panel                                             |
//+------------------------------------------------------------------+
void CreateDashboard()
{
   string prefix = "STAT_";
   ObjectsDeleteAll(0, prefix);
   
   // Main Background
   CreateRectangle(prefix + "BG", PANEL_X, PANEL_Y, PANEL_WIDTH, PANEL_HEIGHT, COLOR_BG_DARK, COLOR_BORDER);
   
   // ===== HEADER BAR =====
   int headerY = PANEL_Y + 5;
   CreateRectangle(prefix + "HDR_BG", PANEL_X + 5, headerY, PANEL_WIDTH - 10, 25, COLOR_HEADER_MAIN, COLOR_BORDER);
   CreateLabel(prefix + "LOGO", PANEL_X + 15, headerY + 5, "MoneyX Statistical Arbitrage EA", COLOR_GOLD, 11, "Arial Bold");
   CreateLabel(prefix + "VER", PANEL_X + PANEL_WIDTH - 80, headerY + 5, "v3.2.7", COLOR_TEXT_WHITE, 9, "Arial");
   
   // v3.2.7: Show Exit Mode and Avg status
   string modeStr = StringFormat("Exit:%s | Avg:%s", 
      (InpExitMode == EXIT_ZSCORE_ONLY ? "Z" : (InpExitMode == EXIT_PROFIT_ONLY ? "$" : (InpExitMode == EXIT_ZSCORE_OR_PROFIT ? "Z|$" : "Z&$"))),
      InpEnableAveraging ? "ON" : "OFF");
   CreateLabel(prefix + "MODE", PANEL_X + 400, headerY + 5, modeStr, COLOR_TEXT_WHITE, 8, "Arial");
   
   // ===== COLUMN HEADERS =====
   int colY = PANEL_Y + 35;
   
   // Buy Side Header
   int buyStartX = PANEL_X + 5;
   CreateRectangle(prefix + "HDR_BUY", buyStartX, colY, 395, 22, COLOR_HEADER_BUY, COLOR_BORDER);
   CreateLabel(prefix + "H_BUY", buyStartX + 150, colY + 4, "MAIN ORDER BUY", COLOR_TEXT_WHITE, 10, "Arial Bold");
   
   // Center Header
   int centerX = PANEL_X + 405;
   CreateRectangle(prefix + "HDR_CENTER", centerX, colY, 390, 22, COLOR_HEADER_MAIN, COLOR_BORDER);
   CreateLabel(prefix + "H_CENTER", centerX + 130, colY + 4, "TRADING PAIRS", COLOR_GOLD, 10, "Arial Bold");
   
   // Sell Side Header
   int sellStartX = PANEL_X + 800;
   CreateRectangle(prefix + "HDR_SELL", sellStartX, colY, 395, 22, COLOR_HEADER_SELL, COLOR_BORDER);
   CreateLabel(prefix + "H_SELL", sellStartX + 140, colY + 4, "MAIN ORDER SELL", COLOR_TEXT_WHITE, 10, "Arial Bold");
   
   // ===== SUB-HEADERS =====
   int subY = colY + 24;
   
   // Buy Sub-headers
   CreateLabel(prefix + "SH_B_X", buyStartX + 5, subY, "X", COLOR_TEXT_WHITE, 7, "Arial");
   CreateLabel(prefix + "SH_B_PROF", buyStartX + 25, subY, "Profit", COLOR_TEXT_WHITE, 7, "Arial");
   CreateLabel(prefix + "SH_B_LOT", buyStartX + 75, subY, "Lot", COLOR_TEXT_WHITE, 7, "Arial");
   CreateLabel(prefix + "SH_B_ORD", buyStartX + 120, subY, "Order", COLOR_TEXT_WHITE, 7, "Arial");
   CreateLabel(prefix + "SH_B_MAX", buyStartX + 165, subY, "Max", COLOR_TEXT_WHITE, 7, "Arial");
   CreateLabel(prefix + "SH_B_TGT", buyStartX + 210, subY, "Target", COLOR_TEXT_WHITE, 7, "Arial");
   CreateLabel(prefix + "SH_B_ST", buyStartX + 260, subY, "Status", COLOR_TEXT_WHITE, 7, "Arial");
   CreateLabel(prefix + "SH_B_Z", buyStartX + 310, subY, "Z-Score", COLOR_TEXT_WHITE, 7, "Arial");
   CreateLabel(prefix + "SH_B_AVG", buyStartX + 360, subY, "Avg", COLOR_TEXT_WHITE, 7, "Arial");
   
   // Center Sub-headers
   CreateLabel(prefix + "SH_C_PAIR", centerX + 10, subY, "Pair", COLOR_TEXT_WHITE, 7, "Arial");
   CreateLabel(prefix + "SH_C_CORR", centerX + 140, subY, "Corr%", COLOR_TEXT_WHITE, 7, "Arial");
   CreateLabel(prefix + "SH_C_TYPE", centerX + 195, subY, "Type", COLOR_TEXT_WHITE, 7, "Arial");
   CreateLabel(prefix + "SH_C_BETA", centerX + 250, subY, "Beta", COLOR_TEXT_WHITE, 7, "Arial");
   CreateLabel(prefix + "SH_C_TPL", centerX + 310, subY, "Total P/L", COLOR_TEXT_WHITE, 7, "Arial");
   
   // Sell Sub-headers
   CreateLabel(prefix + "SH_S_AVG", sellStartX + 5, subY, "Avg", COLOR_TEXT_WHITE, 7, "Arial");
   CreateLabel(prefix + "SH_S_Z", sellStartX + 40, subY, "Z-Score", COLOR_TEXT_WHITE, 7, "Arial");
   CreateLabel(prefix + "SH_S_ST", sellStartX + 105, subY, "Status", COLOR_TEXT_WHITE, 7, "Arial");
   CreateLabel(prefix + "SH_S_TGT", sellStartX + 155, subY, "Target", COLOR_TEXT_WHITE, 7, "Arial");
   CreateLabel(prefix + "SH_S_MAX", sellStartX + 210, subY, "Max", COLOR_TEXT_WHITE, 7, "Arial");
   CreateLabel(prefix + "SH_S_ORD", sellStartX + 255, subY, "Order", COLOR_TEXT_WHITE, 7, "Arial");
   CreateLabel(prefix + "SH_S_LOT", sellStartX + 305, subY, "Lot", COLOR_TEXT_WHITE, 7, "Arial");
   CreateLabel(prefix + "SH_S_PROF", sellStartX + 345, subY, "Profit", COLOR_TEXT_WHITE, 7, "Arial");
   CreateLabel(prefix + "SH_S_X", sellStartX + 380, subY, "X", COLOR_TEXT_WHITE, 7, "Arial");
   
   // ===== PAIR ROWS =====
   int rowStartY = subY + 18;
   
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      int rowY = rowStartY + i * ROW_HEIGHT;
      color rowBg = (i % 2 == 0) ? COLOR_BG_ROW_EVEN : COLOR_BG_ROW_ODD;
      
      CreateRectangle(prefix + "ROW_B_" + IntegerToString(i), buyStartX, rowY, 395, ROW_HEIGHT - 1, rowBg, rowBg);
      CreateRectangle(prefix + "ROW_C_" + IntegerToString(i), centerX, rowY, 390, ROW_HEIGHT - 1, rowBg, rowBg);
      CreateRectangle(prefix + "ROW_S_" + IntegerToString(i), sellStartX, rowY, 395, ROW_HEIGHT - 1, rowBg, rowBg);
      
      CreatePairRow(i, rowY, buyStartX, centerX, sellStartX);
   }
   
   // ===== ACCOUNT SUMMARY =====
   int summaryY = rowStartY + MAX_PAIRS * ROW_HEIGHT + 10;
   CreateAccountSummary(summaryY);
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Create Pair Row                                                    |
//+------------------------------------------------------------------+
void CreatePairRow(int pairIndex, int rowY, int buyX, int centerX, int sellX)
{
   string prefix = "STAT_";
   string idx = IntegerToString(pairIndex);
   
   // === Buy Side ===
   CreateButton(prefix + "_CLOSE_BUY_" + idx, buyX + 2, rowY + 1, 18, ROW_HEIGHT - 3, "X", COLOR_LOSS, clrWhite);
   CreateLabel(prefix + "_PROF_BUY_" + idx, buyX + 25, rowY + 2, "0.00", COLOR_TEXT, FONT_SIZE, "Arial");
   CreateLabel(prefix + "_LOT_BUY_" + idx, buyX + 75, rowY + 2, "0.00", COLOR_TEXT, FONT_SIZE, "Arial");
   CreateLabel(prefix + "_ORD_BUY_" + idx, buyX + 125, rowY + 2, "0", COLOR_TEXT, FONT_SIZE, "Arial");
   CreateEditField(prefix + "_MAX_BUY_" + idx, buyX + 160, rowY + 1, 35, ROW_HEIGHT - 3, IntegerToString(InpDefaultMaxOrderBuy));
   CreateEditField(prefix + "_TGT_BUY_" + idx, buyX + 200, rowY + 1, 50, ROW_HEIGHT - 3, DoubleToString(InpDefaultTargetBuy, 1));
   CreateButton(prefix + "_ST_BUY_" + idx, buyX + 255, rowY + 1, 45, ROW_HEIGHT - 3, "OFF", COLOR_OFF, clrWhite);
   CreateLabel(prefix + "_Z_BUY_" + idx, buyX + 310, rowY + 2, "0.00", COLOR_TEXT, FONT_SIZE, "Arial");
   CreateLabel(prefix + "_AVG_BUY_" + idx, buyX + 365, rowY + 2, "0", COLOR_TEXT, FONT_SIZE, "Arial");
   
   // === Center (Pair Info) ===
   string pairName = IntegerToString(pairIndex + 1) + ". " + g_pairs[pairIndex].symbolA + "/" + g_pairs[pairIndex].symbolB;
   CreateLabel(prefix + "_PAIR_" + idx, centerX + 10, rowY + 2, pairName, COLOR_TEXT, FONT_SIZE, "Arial");
   CreateLabel(prefix + "_CORR_" + idx, centerX + 145, rowY + 2, "0.00", COLOR_TEXT, FONT_SIZE, "Arial");
   CreateLabel(prefix + "_TYPE_" + idx, centerX + 195, rowY + 2, "+", COLOR_TEXT, FONT_SIZE, "Arial");
   CreateLabel(prefix + "_BETA_" + idx, centerX + 250, rowY + 2, "1.00", COLOR_TEXT, FONT_SIZE, "Arial");
   CreateLabel(prefix + "_TPL_" + idx, centerX + 310, rowY + 2, "0.00", COLOR_TEXT, FONT_SIZE, "Arial");
   
   // === Sell Side ===
   CreateLabel(prefix + "_AVG_SELL_" + idx, sellX + 5, rowY + 2, "0", COLOR_TEXT, FONT_SIZE, "Arial");
   CreateLabel(prefix + "_Z_SELL_" + idx, sellX + 45, rowY + 2, "0.00", COLOR_TEXT, FONT_SIZE, "Arial");
   CreateButton(prefix + "_ST_SELL_" + idx, sellX + 100, rowY + 1, 45, ROW_HEIGHT - 3, "OFF", COLOR_OFF, clrWhite);
   CreateEditField(prefix + "_TGT_SELL_" + idx, sellX + 150, rowY + 1, 50, ROW_HEIGHT - 3, DoubleToString(InpDefaultTargetSell, 1));
   CreateEditField(prefix + "_MAX_SELL_" + idx, sellX + 205, rowY + 1, 35, ROW_HEIGHT - 3, IntegerToString(InpDefaultMaxOrderSell));
   CreateLabel(prefix + "_ORD_SELL_" + idx, sellX + 255, rowY + 2, "0", COLOR_TEXT, FONT_SIZE, "Arial");
   CreateLabel(prefix + "_LOT_SELL_" + idx, sellX + 305, rowY + 2, "0.00", COLOR_TEXT, FONT_SIZE, "Arial");
   CreateLabel(prefix + "_PROF_SELL_" + idx, sellX + 345, rowY + 2, "0.00", COLOR_TEXT, FONT_SIZE, "Arial");
   CreateButton(prefix + "_CLOSE_SELL_" + idx, sellX + 377, rowY + 1, 18, ROW_HEIGHT - 3, "X", COLOR_LOSS, clrWhite);
}

//+------------------------------------------------------------------+
//| Create Account Summary                                             |
//+------------------------------------------------------------------+
void CreateAccountSummary(int y)
{
   string prefix = "STAT_";
   int boxWidth = 290;
   int boxHeight = 80;
   
   // Box 1: Account Info
   CreateRectangle(prefix + "SUM_BOX1", PANEL_X + 5, y, boxWidth, boxHeight, COLOR_BG_DARK, COLOR_BORDER);
   CreateLabel(prefix + "SUM_T1", PANEL_X + 10, y + 5, "ACCOUNT INFO", COLOR_GOLD, 9, "Arial Bold");
   CreateLabel(prefix + "SUM_BAL_L", PANEL_X + 10, y + 22, "Balance:", COLOR_TEXT_WHITE, 8, "Arial");
   CreateLabel(prefix + "SUM_BAL_V", PANEL_X + 80, y + 22, "0.00", COLOR_TEXT_WHITE, 8, "Arial");
   CreateLabel(prefix + "SUM_EQ_L", PANEL_X + 10, y + 38, "Equity:", COLOR_TEXT_WHITE, 8, "Arial");
   CreateLabel(prefix + "SUM_EQ_V", PANEL_X + 80, y + 38, "0.00", COLOR_TEXT_WHITE, 8, "Arial");
   CreateLabel(prefix + "SUM_DD_L", PANEL_X + 10, y + 54, "Max DD%:", COLOR_TEXT_WHITE, 8, "Arial");
   CreateLabel(prefix + "SUM_DD_V", PANEL_X + 80, y + 54, "0.00%", COLOR_LOSS, 8, "Arial");
   
   // v3.2.7: Show pause status
   CreateLabel(prefix + "SUM_PAUSE_L", PANEL_X + 150, y + 22, "Status:", COLOR_TEXT_WHITE, 8, "Arial");
   CreateLabel(prefix + "SUM_PAUSE_V", PANEL_X + 200, y + 22, "RUNNING", COLOR_ON, 8, "Arial Bold");
   
   // Box 2: Daily/Weekly/Monthly Profit
   CreateRectangle(prefix + "SUM_BOX2", PANEL_X + 305, y, boxWidth, boxHeight, COLOR_BG_DARK, COLOR_BORDER);
   CreateLabel(prefix + "SUM_T2", PANEL_X + 310, y + 5, "PROFIT HISTORY", COLOR_GOLD, 9, "Arial Bold");
   CreateLabel(prefix + "SUM_DP_L", PANEL_X + 310, y + 22, "Daily:", COLOR_TEXT_WHITE, 8, "Arial");
   CreateLabel(prefix + "SUM_DP_V", PANEL_X + 380, y + 22, "0.00", COLOR_TEXT_WHITE, 8, "Arial");
   CreateLabel(prefix + "SUM_WP_L", PANEL_X + 310, y + 38, "Weekly:", COLOR_TEXT_WHITE, 8, "Arial");
   CreateLabel(prefix + "SUM_WP_V", PANEL_X + 380, y + 38, "0.00", COLOR_TEXT_WHITE, 8, "Arial");
   CreateLabel(prefix + "SUM_MP_L", PANEL_X + 310, y + 54, "Monthly:", COLOR_TEXT_WHITE, 8, "Arial");
   CreateLabel(prefix + "SUM_MP_V", PANEL_X + 380, y + 54, "0.00", COLOR_TEXT_WHITE, 8, "Arial");
   
   // Box 3: Current Profit / Target
   CreateRectangle(prefix + "SUM_BOX3", PANEL_X + 605, y, boxWidth, boxHeight, COLOR_BG_DARK, COLOR_BORDER);
   CreateLabel(prefix + "SUM_T3", PANEL_X + 610, y + 5, "TARGET SYSTEM", COLOR_GOLD, 9, "Arial Bold");
   CreateLabel(prefix + "SUM_CP_L", PANEL_X + 610, y + 22, "Current P/L:", COLOR_TEXT_WHITE, 8, "Arial");
   CreateLabel(prefix + "SUM_CP_V", PANEL_X + 700, y + 22, "0.00", COLOR_TEXT_WHITE, 8, "Arial");
   CreateLabel(prefix + "SUM_TGT_L", PANEL_X + 610, y + 38, "Target:", COLOR_TEXT_WHITE, 8, "Arial");
   CreateEditField(prefix + "_TOTAL_TARGET", PANEL_X + 700, y + 36, 80, 16, DoubleToString(g_totalTarget, 2));
   
   // Box 4: Control Buttons
   CreateRectangle(prefix + "SUM_BOX4", PANEL_X + 905, y, boxWidth, boxHeight, COLOR_BG_DARK, COLOR_BORDER);
   CreateLabel(prefix + "SUM_T4", PANEL_X + 910, y + 5, "CONTROLS", COLOR_GOLD, 9, "Arial Bold");
   CreateButton(prefix + "_START_ALL", PANEL_X + 910, y + 25, 80, 20, "Start All", C'0,120,0', clrWhite);
   CreateButton(prefix + "_STOP_ALL", PANEL_X + 1000, y + 25, 80, 20, "Stop All", C'120,60,0', clrWhite);
   CreateButton(prefix + "_CLOSE_ALL_BUY", PANEL_X + 910, y + 50, 80, 20, "Close Buy", COLOR_HEADER_BUY, clrWhite);
   CreateButton(prefix + "_CLOSE_ALL_SELL", PANEL_X + 1000, y + 50, 80, 20, "Close Sell", COLOR_HEADER_SELL, clrWhite);
}

//+------------------------------------------------------------------+
//| Update Dashboard                                                   |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   string prefix = "STAT_";
   
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      string idx = IntegerToString(i);
      
      if(!g_pairs[i].enabled)
      {
         UpdateLabel(prefix + "_CORR_" + idx, "N/A");
         continue;
      }
      
      // Buy Side
      UpdateLabel(prefix + "_PROF_BUY_" + idx, DoubleToString(g_pairs[i].profitBuy, 2), 
                  g_pairs[i].profitBuy >= 0 ? COLOR_PROFIT : COLOR_LOSS);
      UpdateLabel(prefix + "_LOT_BUY_" + idx, DoubleToString(g_pairs[i].lotBuyA + g_pairs[i].lotBuyB, 2));
      UpdateLabel(prefix + "_ORD_BUY_" + idx, IntegerToString(g_pairs[i].orderCountBuy));
      UpdateLabel(prefix + "_Z_BUY_" + idx, DoubleToString(g_pairs[i].zScore, 2));
      UpdateLabel(prefix + "_AVG_BUY_" + idx, IntegerToString(g_pairs[i].avgCountBuy));
      
      // Status buttons
      string buyStatus = (g_pairs[i].directionBuy == 0) ? "OFF" : 
                         (g_pairs[i].directionBuy == -1) ? "ON" : "ACTIVE";
      color buyColor = (g_pairs[i].directionBuy == 0) ? COLOR_OFF : 
                       (g_pairs[i].directionBuy == -1) ? COLOR_ON : COLOR_ACTIVE;
      ObjectSetString(0, prefix + "_ST_BUY_" + idx, OBJPROP_TEXT, buyStatus);
      ObjectSetInteger(0, prefix + "_ST_BUY_" + idx, OBJPROP_BGCOLOR, buyColor);
      
      // Center
      string corrStr = g_pairs[i].dataValid ? DoubleToString(g_pairs[i].correlation * 100, 1) + "%" : "N/A";
      UpdateLabel(prefix + "_CORR_" + idx, corrStr);
      UpdateLabel(prefix + "_TYPE_" + idx, g_pairs[i].correlationType == 1 ? "+" : "-");
      UpdateLabel(prefix + "_BETA_" + idx, DoubleToString(g_pairs[i].hedgeRatio, 2));
      UpdateLabel(prefix + "_TPL_" + idx, DoubleToString(g_pairs[i].totalPairProfit, 2),
                  g_pairs[i].totalPairProfit >= 0 ? COLOR_PROFIT : COLOR_LOSS);
      
      // Sell Side
      UpdateLabel(prefix + "_AVG_SELL_" + idx, IntegerToString(g_pairs[i].avgCountSell));
      UpdateLabel(prefix + "_Z_SELL_" + idx, DoubleToString(g_pairs[i].zScore, 2));
      UpdateLabel(prefix + "_ORD_SELL_" + idx, IntegerToString(g_pairs[i].orderCountSell));
      UpdateLabel(prefix + "_LOT_SELL_" + idx, DoubleToString(g_pairs[i].lotSellA + g_pairs[i].lotSellB, 2));
      UpdateLabel(prefix + "_PROF_SELL_" + idx, DoubleToString(g_pairs[i].profitSell, 2),
                  g_pairs[i].profitSell >= 0 ? COLOR_PROFIT : COLOR_LOSS);
      
      string sellStatus = (g_pairs[i].directionSell == 0) ? "OFF" : 
                          (g_pairs[i].directionSell == -1) ? "ON" : "ACTIVE";
      color sellColor = (g_pairs[i].directionSell == 0) ? COLOR_OFF : 
                        (g_pairs[i].directionSell == -1) ? COLOR_ON : COLOR_ACTIVE;
      ObjectSetString(0, prefix + "_ST_SELL_" + idx, OBJPROP_TEXT, sellStatus);
      ObjectSetInteger(0, prefix + "_ST_SELL_" + idx, OBJPROP_BGCOLOR, sellColor);
   }
   
   // Account Summary
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   UpdateLabel(prefix + "SUM_BAL_V", DoubleToString(balance, 2));
   UpdateLabel(prefix + "SUM_EQ_V", DoubleToString(equity, 2));
   UpdateLabel(prefix + "SUM_DD_V", DoubleToString(g_maxDrawdownPercent, 2) + "%", COLOR_LOSS);
   
   // v3.2.7: Pause status
   string pauseStatus = g_isPaused ? ("PAUSED:" + g_pauseReason) : "RUNNING";
   color pauseColor = g_isPaused ? COLOR_LOSS : COLOR_ON;
   UpdateLabel(prefix + "SUM_PAUSE_V", pauseStatus, pauseColor);
   
   UpdateLabel(prefix + "SUM_DP_V", DoubleToString(g_dailyProfit, 2), g_dailyProfit >= 0 ? COLOR_PROFIT : COLOR_LOSS);
   UpdateLabel(prefix + "SUM_WP_V", DoubleToString(g_weeklyProfit, 2), g_weeklyProfit >= 0 ? COLOR_PROFIT : COLOR_LOSS);
   UpdateLabel(prefix + "SUM_MP_V", DoubleToString(g_monthlyProfit, 2), g_monthlyProfit >= 0 ? COLOR_PROFIT : COLOR_LOSS);
   
   UpdateLabel(prefix + "SUM_CP_V", DoubleToString(g_totalCurrentProfit, 2), 
               g_totalCurrentProfit >= 0 ? COLOR_PROFIT : COLOR_LOSS);
   
   if(!g_isTesterMode) ChartRedraw();
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
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Helper: Create Label                                               |
//+------------------------------------------------------------------+
void CreateLabel(string name, int x, int y, string text, color textColor, int fontSize, string font)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, font);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Helper: Update Label                                               |
//+------------------------------------------------------------------+
void UpdateLabel(string name, string text, color textColor = CLR_NONE)
{
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   if(textColor != CLR_NONE)
      ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
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
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, COLOR_BORDER);
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
   ObjectSetInteger(0, name, OBJPROP_COLOR, COLOR_TEXT);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 7);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ALIGN, ALIGN_CENTER);
}
//+------------------------------------------------------------------+
