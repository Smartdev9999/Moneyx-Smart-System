//+------------------------------------------------------------------+
//|                                Multi_Currency_Statistical_EA.mq5 |
//|                      Statistical Arbitrage (Pairs Trading) v3.2.3 |
//|                                             MoneyX Trading        |
//+------------------------------------------------------------------+
#property copyright "MoneyX Trading"
#property version   "3.23"
#property strict
#property description "Statistical Arbitrage / Pairs Trading Expert Advisor"
#property description "Full Hedging with Independent Buy/Sell Sides"
#property description "v3.2.3: Status syncs with Settings, Start All/Stop All buttons"

#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| CONSTANTS                                                          |
//+------------------------------------------------------------------+
#define MAX_PAIRS 30
#define MAX_LOOKBACK 200

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
//| PAIR INFO STRUCTURE (v3.2 - Separated Buy/Sell Sides + dataValid) |
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

input group "=== Lot Sizing (Dollar-Neutral) ==="
input bool     InpUseDollarNeutral = true;      // Use Dollar-Neutral Sizing
input double   InpMaxMarginPercent = 50.0;      // Max Margin Usage (%)

input group "=== Risk Management ==="
input double   InpMaxDrawdown = 20.0;           // Max Drawdown (%)
input int      InpMaxHoldingBars = 0;           // Max Holding Time (0=Disabled)
input double   InpEmergencyCloseDD = 30.0;      // Emergency Close Drawdown (%)

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

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("===== Statistical Arbitrage EA v3.2.1 =====");
   Print("Correlation Method: ", EnumToString(InpCorrMethod));
   Print("Correlation Timeframe: ", EnumToString(InpCorrTimeframe));
   Print("Correlation Bars: ", InpCorrBars);
   Print("Debug Mode: ", InpDebugMode ? "ON" : "OFF");
   Print("=========================================");
   
   // Initialize dashboard settings from inputs
   PANEL_X = InpPanelX;
   PANEL_Y = InpPanelY;
   PANEL_WIDTH = InpPanelWidth;
   PANEL_HEIGHT = InpPanelHeight;
   ROW_HEIGHT = InpRowHeight;
   FONT_SIZE = InpFontSize;
   
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
   
   // Initialize trade object
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(InpSlippage);
   
   // Initialize target from input
   g_totalTarget = InpTotalTarget;
   
   // Initialize price arrays
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      ArrayInitialize(g_pairData[i].pricesA, 0);
      ArrayInitialize(g_pairData[i].pricesB, 0);
      ArrayInitialize(g_pairData[i].returnsA, 0);
      ArrayInitialize(g_pairData[i].returnsB, 0);
      ArrayInitialize(g_pairData[i].spreadHistory, 0);
   }
   
   // Initialize pairs
   if(!InitializePairs())
   {
      Print("Failed to initialize trading pairs!");
      return(INIT_FAILED);
   }
   
   // License verification
   g_isLicenseValid = VerifyLicense();
   if(!g_isLicenseValid)
   {
      Print("License verification failed!");
      return(INIT_FAILED);
   }
   
   // Initialize account stats
   g_initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   g_maxEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_dayStart = TimeCurrent();
   g_weekStart = TimeCurrent();
   g_monthStart = TimeCurrent();
   
   // Set timer for dashboard updates
   EventSetTimer(1);
   
   // Force initial data update before dashboard
   UpdateAllPairData();
   
   // Print pair status summary
   Print("===== Pair Status Summary =====");
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
   PrintFormat("Total Enabled Pairs: %d", g_activePairs);
   Print("================================");
   
   // Create dashboard panel
   if(!MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE))
   {
      CreateDashboard();
   }
   
   PrintFormat("=== Statistical Arbitrage EA v3.1 Initialized - %d Active Pairs ===", g_activePairs);
   return(INIT_SUCCEEDED);
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
//| Setup Individual Pair (v3.2 - with symbol validation + dataValid) |
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
   
   // Buy Side initialization - directionBuy = -1 means Ready to trade
   // v3.2.3: Set direction based on enabled status from Settings
   g_pairs[index].directionBuy = enabled ? -1 : 0;  // -1=Ready when enabled, 0=Off when disabled
   g_pairs[index].ticketBuyA = 0;
   g_pairs[index].ticketBuyB = 0;
   g_pairs[index].lotBuyA = InpBaseLot;
   g_pairs[index].lotBuyB = InpBaseLot;
   g_pairs[index].profitBuy = 0;
   g_pairs[index].orderCountBuy = 0;
   g_pairs[index].maxOrderBuy = InpDefaultMaxOrderBuy;
   g_pairs[index].targetBuy = InpDefaultTargetBuy;
   g_pairs[index].entryTimeBuy = 0;
   
   // Sell Side initialization - directionSell = -1 means Ready to trade
   // v3.2.3: Set direction based on enabled status from Settings
   g_pairs[index].directionSell = enabled ? -1 : 0;  // -1=Ready when enabled, 0=Off when disabled
   g_pairs[index].ticketSellA = 0;
   g_pairs[index].ticketSellB = 0;
   g_pairs[index].lotSellA = InpBaseLot;
   g_pairs[index].lotSellB = InpBaseLot;
   g_pairs[index].profitSell = 0;
   g_pairs[index].orderCountSell = 0;
   g_pairs[index].maxOrderSell = InpDefaultMaxOrderSell;
   g_pairs[index].targetSell = InpDefaultTargetSell;
   g_pairs[index].entryTimeSell = 0;
   
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
   Print("=== Statistical Arbitrage EA v3.1 Deinitialized ===");
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!g_isLicenseValid) return;
   if(g_isPaused) return;
   
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
      UpdateAllPairData();  // Recalculate correlation on new candle
      PrintFormat("Correlation updated on new %s candle", EnumToString(InpCorrTimeframe));
   }
   
   // Check for new trading candle
   datetime currentTime = iTime(_Symbol, InpTimeframe, 0);
   if(currentTime == g_lastCandleTime) return;
   g_lastCandleTime = currentTime;
   
   // Main trading logic
   AnalyzeAllPairs();
   ManageAllPositions();
   CheckPairTargets();
   CheckTotalTarget();
   CheckRiskLimits();
}

//+------------------------------------------------------------------+
//| Timer function - Dashboard Updates                                 |
//+------------------------------------------------------------------+
void OnTimer()
{
   UpdatePairProfits();
   UpdateAccountStats();
   UpdateDashboard();
}

//+------------------------------------------------------------------+
//| Chart Event Handler - Interactive Dashboard (v3.1)                 |
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
       // v3.2.3: Handle Start All button
       else if(StringFind(sparam, "_START_ALL") >= 0)
       {
          StartAllPairs();
          Print("Start All Pairs triggered");
       }
       // v3.2.3: Handle Stop All button
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
//| Start All Pairs (v3.2.3)                                           |
//+------------------------------------------------------------------+
void StartAllPairs()
{
   int count = 0;
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(g_pairs[i].enabled && g_pairs[i].dataValid)
      {
         // Only start pairs that are Off (0), not Active (1)
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
   UpdateDashboard();
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Stop All Pairs (v3.2.3)                                            |
//+------------------------------------------------------------------+
void StopAllPairs()
{
   int stopped = 0;
   int skipped = 0;
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(g_pairs[i].enabled)
      {
         // Only stop pairs that are Ready (-1), not Active (1)
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
   UpdateDashboard();
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Toggle Buy Side Status (v3.1)                                      |
//+------------------------------------------------------------------+
void ToggleBuySideStatus(int pairIndex)
{
   string prefix = "STAT_";
   string btnName = prefix + "_ST_BUY_" + IntegerToString(pairIndex);
   
   // Toggle: 0 (Off) -> -1 (Ready) -> 0 (Off)
   // If active trade (1), cannot toggle off
   if(g_pairs[pairIndex].directionBuy == 0)
   {
      // Enable - Ready to trade
      g_pairs[pairIndex].directionBuy = -1;
      ObjectSetString(0, btnName, OBJPROP_TEXT, "On");
      ObjectSetInteger(0, btnName, OBJPROP_BGCOLOR, COLOR_ON);
      PrintFormat("Pair %d Buy Side ENABLED (Ready)", pairIndex + 1);
   }
   else if(g_pairs[pairIndex].directionBuy == -1)
   {
      // Disable
      g_pairs[pairIndex].directionBuy = 0;
      ObjectSetString(0, btnName, OBJPROP_TEXT, "Off");
      ObjectSetInteger(0, btnName, OBJPROP_BGCOLOR, COLOR_OFF);
      PrintFormat("Pair %d Buy Side DISABLED", pairIndex + 1);
   }
   // If directionBuy == 1 (Active trade), show message
   else if(g_pairs[pairIndex].directionBuy == 1)
   {
      Print("Cannot toggle: Active trade on Pair ", pairIndex + 1, " Buy Side. Close trade first.");
   }
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Toggle Sell Side Status (v3.1)                                     |
//+------------------------------------------------------------------+
void ToggleSellSideStatus(int pairIndex)
{
   string prefix = "STAT_";
   string btnName = prefix + "_ST_SELL_" + IntegerToString(pairIndex);
   
   // Toggle: 0 (Off) -> -1 (Ready) -> 0 (Off)
   if(g_pairs[pairIndex].directionSell == 0)
   {
      // Enable - Ready to trade
      g_pairs[pairIndex].directionSell = -1;
      ObjectSetString(0, btnName, OBJPROP_TEXT, "On");
      ObjectSetInteger(0, btnName, OBJPROP_BGCOLOR, COLOR_ON);
      PrintFormat("Pair %d Sell Side ENABLED (Ready)", pairIndex + 1);
   }
   else if(g_pairs[pairIndex].directionSell == -1)
   {
      // Disable
      g_pairs[pairIndex].directionSell = 0;
      ObjectSetString(0, btnName, OBJPROP_TEXT, "Off");
      ObjectSetInteger(0, btnName, OBJPROP_BGCOLOR, COLOR_OFF);
      PrintFormat("Pair %d Sell Side DISABLED", pairIndex + 1);
   }
   else if(g_pairs[pairIndex].directionSell == 1)
   {
      Print("Cannot toggle: Active trade on Pair ", pairIndex + 1, " Sell Side. Close trade first.");
   }
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Extract Pair Index from Object Name                                |
//+------------------------------------------------------------------+
int ExtractPairIndex(string objName, string prefix)
{
   int pos = StringFind(objName, prefix);
   if(pos < 0) return -1;
   
   string numStr = StringSubstr(objName, pos + StringLen(prefix));
   return (int)StringToInteger(numStr);
}

//+------------------------------------------------------------------+
//| Verify License via WebRequest                                      |
//+------------------------------------------------------------------+
bool VerifyLicense()
{
   // Bypass license check in Strategy Tester
   if(MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_OPTIMIZATION) || MQLInfoInteger(MQL_VISUAL_MODE))
   {
      Print("Strategy Tester Mode - License check bypassed");
      return true;
   }
   
   string accountNumber = IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
   if(accountNumber == "" || accountNumber == "0")
   {
      Print("Account Number not available");
      return false;
   }
   
   string url = InpApiUrl + "/verify-license";
   string headers = "Content-Type: application/json\r\nx-api-key: " + InpApiKey;
   string postData = "{\"account_number\":\"" + accountNumber + "\"}";
   
   char post[];
   char result[];
   string resultHeaders;
   
   int postLen = StringToCharArray(postData, post, 0, -1, CP_UTF8);
   ArrayResize(post, postLen - 1);
   
   ResetLastError();
   int timeout = 10000;
   int res = WebRequest("POST", url, headers, timeout, post, result, resultHeaders);
   
   if(res == -1)
   {
      int error = GetLastError();
      if(error == 4014)
      {
         Print("ERROR: Add URL to MT5 allowed list: ", InpApiUrl);
         MessageBox("Please add this URL to MT5 allowed list:\n\n" + InpApiUrl, "WebRequest Error", MB_ICONERROR);
      }
      return false;
   }
   
   string response = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
   
   if(StringFind(response, "\"valid\":true") >= 0)
   {
      Print("License verified successfully!");
      return true;
   }
   
   Print("License validation failed");
   return false;
}

//+------------------------------------------------------------------+
//| Check News Pause (placeholder)                                     |
//+------------------------------------------------------------------+
bool IsNewsPaused()
{
   // Implement news filter logic here
   return false;
}

//+------------------------------------------------------------------+
//| ================ STATISTICAL ENGINE ================               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Download History Data (v3.1 - ensures data availability)           |
//+------------------------------------------------------------------+
bool DownloadHistoryData(string symbol, ENUM_TIMEFRAMES tf, int bars)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   // Request data from server
   int copied = CopyRates(symbol, tf, 0, bars + 10, rates);
   
   if(copied < bars)
   {
      PrintFormat("Warning: Only %d bars available for %s on %s (requested %d)", 
                  copied, symbol, EnumToString(tf), bars);
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Update All Pair Data (Prices, Returns, Statistics)                 |
//+------------------------------------------------------------------+
void UpdateAllPairData()
{
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(!g_pairs[i].enabled) continue;
      
      // Download history data first (v3.1)
      if(InpAutoDownloadData)
      {
         DownloadHistoryData(g_pairs[i].symbolA, InpCorrTimeframe, InpCorrBars);
         DownloadHistoryData(g_pairs[i].symbolB, InpCorrTimeframe, InpCorrBars);
      }
      
      // Update prices using correlation timeframe
      UpdatePriceHistory(i);
      
      // Calculate log returns
      CalculateLogReturns(i);
      
      // Calculate correlation
      g_pairs[i].correlation = CalculatePearsonCorrelation(i);
      
      // Auto-detect correlation type
      DetectCorrelationType(i);
      
      // Calculate hedge ratio (beta)
      g_pairs[i].hedgeRatio = CalculateHedgeRatio(i);
      
      // Update spread history and calculate current spread
      UpdateSpreadHistory(i);
      
      // Calculate Z-Score
      g_pairs[i].zScore = CalculateSpreadZScore(i);
      
      // Calculate dollar-neutral lots
      if(InpUseDollarNeutral)
      {
         CalculateDollarNeutralLots(i);
      }
   }
}

//+------------------------------------------------------------------+
//| Detect Correlation Type (Positive/Negative) - v3.0                 |
//| Based on Pearson Correlation coefficient                          |
//+------------------------------------------------------------------+
void DetectCorrelationType(int pairIndex)
{
   double r = g_pairs[pairIndex].correlation;
   
   if(r > 0)
      g_pairs[pairIndex].correlationType = 1;   // Positive correlation
   else
      g_pairs[pairIndex].correlationType = -1;  // Negative correlation
}

//+------------------------------------------------------------------+
//| Update Price History for a Pair (v3.2 - uses CopyClose for reliability) |
//+------------------------------------------------------------------+
void UpdatePriceHistory(int pairIndex)
{
   string symbolA = g_pairs[pairIndex].symbolA;
   string symbolB = g_pairs[pairIndex].symbolB;
   
   int period = MathMin(InpCorrBars, MAX_LOOKBACK);
   
   // Use CopyClose for more reliable data retrieval
   double closesA[], closesB[];
   ArraySetAsSeries(closesA, true);
   ArraySetAsSeries(closesB, true);
   
   int copiedA = CopyClose(symbolA, InpCorrTimeframe, 0, period, closesA);
   int copiedB = CopyClose(symbolB, InpCorrTimeframe, 0, period, closesB);
   
   // Check if data is available
   if(copiedA < period || copiedB < period)
   {
      if(InpDebugMode)
      {
         PrintFormat("Pair %d: Data incomplete - %s: %d bars, %s: %d bars (need %d)",
                     pairIndex + 1, symbolA, copiedA, symbolB, copiedB, period);
      }
      g_pairs[pairIndex].dataValid = false;
      return;
   }
   
   // Check if data has valid values (not all zeros)
   bool hasValidDataA = false;
   bool hasValidDataB = false;
   for(int i = 0; i < period && (!hasValidDataA || !hasValidDataB); i++)
   {
      if(closesA[i] > 0) hasValidDataA = true;
      if(closesB[i] > 0) hasValidDataB = true;
   }
   
   if(!hasValidDataA || !hasValidDataB)
   {
      if(InpDebugMode)
      {
         PrintFormat("Pair %d: Data has zero values - %s valid: %s, %s valid: %s",
                     pairIndex + 1, symbolA, hasValidDataA ? "Yes" : "No", 
                     symbolB, hasValidDataB ? "Yes" : "No");
      }
      g_pairs[pairIndex].dataValid = false;
      return;
   }
   
   g_pairs[pairIndex].dataValid = true;
   
   // Copy to price arrays
   for(int i = 0; i < period; i++)
   {
      g_pairData[pairIndex].pricesA[i] = closesA[i];
      g_pairData[pairIndex].pricesB[i] = closesB[i];
   }
   
   if(InpDebugMode && pairIndex == 0)
   {
      PrintFormat("Pair 1 Price Data: A[0]=%.5f, A[1]=%.5f, B[0]=%.5f, B[1]=%.5f",
                  closesA[0], closesA[1], closesB[0], closesB[1]);
   }
}

//+------------------------------------------------------------------+
//| Calculate Returns (Percentage or Log based on method)              |
//+------------------------------------------------------------------+
void CalculateLogReturns(int pairIndex)
{
   // Skip calculation if using Price Direct method
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
//| Calculate Pearson Correlation (v3.2.1 - with method selection)    |
//| Formula: r = Σ[(xi - x̄)(yi - ȳ)] / √[Σ(xi - x̄)² × Σ(yi - ȳ)²]  |
//+------------------------------------------------------------------+
double CalculatePearsonCorrelation(int pairIndex)
{
   // Check if data is valid
   if(!g_pairs[pairIndex].dataValid)
   {
      return 0;
   }
   
   // Choose calculation method based on input
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
//| Calculate Price Direct Correlation (like myfxbook)                 |
//| Uses raw price values, not returns                                 |
//+------------------------------------------------------------------+
double CalculatePriceCorrelation(int pairIndex)
{
   int n = MathMin(InpCorrBars, MAX_LOOKBACK);
   if(n < 10) return 0;
   
   double sumA = 0, sumB = 0;
   double sumA2 = 0, sumB2 = 0;
   double sumAB = 0;
   
   // Use prices directly (not returns) - like myfxbook
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
   
   // Debug output for first pair
   if(InpDebugMode && pairIndex == 0)
   {
      PrintFormat("Pair 1 [PRICE_DIRECT] n=%d, meanA=%.5f, meanB=%.5f", n, meanA, meanB);
      PrintFormat("Pair 1 [PRICE_DIRECT] cov=%.10f, varA=%.10f, varB=%.10f", covariance, varA, varB);
   }
   
   if(varA <= 0 || varB <= 0) return 0;
   
   double stdDevA = MathSqrt(varA);
   double stdDevB = MathSqrt(varB);
   
   double correlation = covariance / (stdDevA * stdDevB);
   
   if(InpDebugMode && pairIndex == 0)
   {
      PrintFormat("Pair 1 [PRICE_DIRECT] Correlation r = %.4f (%.2f%%)", correlation, correlation * 100);
   }
   
   return correlation;
}

//+------------------------------------------------------------------+
//| Calculate Return-Based Correlation (Percentage or Log Returns)     |
//+------------------------------------------------------------------+
double CalculateReturnCorrelation(int pairIndex)
{
   int n = MathMin(InpCorrBars - 1, MAX_LOOKBACK - 1);
   if(n < 10)  // Need at least 10 data points for reliable correlation
   {
      if(InpDebugMode)
      {
         PrintFormat("Pair %d: Not enough data for correlation (n=%d, need 10)", pairIndex + 1, n);
      }
      return 0;
   }
   
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
   
   // Debug output for first pair
   if(InpDebugMode && pairIndex == 0)
   {
      PrintFormat("Pair 1 [RETURNS] n=%d, sumA=%.8f, sumB=%.8f", n, sumA, sumB);
      PrintFormat("Pair 1 [RETURNS] meanA=%.8f, meanB=%.8f, cov=%.10f", meanA, meanB, covariance);
      PrintFormat("Pair 1 [RETURNS] varA=%.10f, varB=%.10f", varA, varB);
   }
   
   if(varA <= 0 || varB <= 0) 
   {
      if(InpDebugMode)
      {
         PrintFormat("Pair %d: Variance is zero or negative (varA=%.10f, varB=%.10f)", 
                     pairIndex + 1, varA, varB);
      }
      return 0;
   }
   
   double stdDevA = MathSqrt(varA);
   double stdDevB = MathSqrt(varB);
   
   if(stdDevA == 0 || stdDevB == 0) return 0;
   
   double correlation = covariance / (stdDevA * stdDevB);
   
   if(InpDebugMode && pairIndex == 0)
   {
      PrintFormat("Pair 1 [RETURNS] Corr Result: r = %.4f (%.2f%%)", correlation, correlation * 100);
   }
   
   return correlation;
}

//+------------------------------------------------------------------+
//| Calculate Hedge Ratio (Beta) v3.2.1                                |
//| Formula: β = Cov(A,B) / Var(A)  (OLS Regression: B = β × A)        |
//+------------------------------------------------------------------+
double CalculateHedgeRatio(int pairIndex)
{
   // Check if data is valid
   if(!g_pairs[pairIndex].dataValid) return 1.0;
   
   if(InpCorrMethod == CORR_PRICE_DIRECT)
   {
      return CalculatePriceBasedBeta(pairIndex);
   }
   else
   {
      return CalculateReturnBasedBeta(pairIndex);
   }
}

//+------------------------------------------------------------------+
//| Get Dollar Value per 1 Standard Lot for a symbol (v3.2.2)         |
//| Normalizes prices to USD value for accurate Beta calculation      |
//| XXXUSD pairs: value = price * contract_size (already in USD)      |
//| USDXXX pairs: value = contract_size (base is USD)                 |
//| Cross pairs: value = price * contract_size * XXXUSD rate          |
//+------------------------------------------------------------------+
double GetDollarValuePerLot(string symbol, double price)
{
   double contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   if(contractSize == 0) contractSize = 100000; // Default to standard lot
   
   string base = StringSubstr(symbol, 0, 3);   // First 3 chars (e.g., "GBP")
   string quote = StringSubstr(symbol, 3, 3);  // Last 3 chars (e.g., "USD")
   
   // Case 1: Quote currency is USD (e.g., GBPUSD, EURUSD)
   // Dollar value = price * contract_size
   if(quote == "USD")
   {
      return price * contractSize;  // e.g., 1.26 * 100000 = 126,000 USD
   }
   
   // Case 2: Base currency is USD (e.g., USDJPY, USDCHF)  
   // Dollar value = contract_size (1 lot = 100,000 USD)
   if(base == "USD")
   {
      return contractSize;  // e.g., 100000 USD
   }
   
   // Case 3: Cross pair (e.g., GBPJPY, EURJPY, EURGBP)
   // Need to convert base currency to USD using XXXUSD rate
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
//| v3.2.2 Revised: Uses % change for proper scale normalization      |
//| Note: Correlation still uses Price Direct (myfxbook style)        |
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
   if(beta < 0.1) beta = 0.1;
   if(beta > 10.0) beta = 10.0;
   
   if(InpDebugMode && pairIndex < 5)
   {
      PrintFormat("Pair %d [PCT_BETA] %s-%s: meanPctA=%.6f%%, meanPctB=%.6f%%", 
                  pairIndex + 1, symbolA, symbolB, meanA * 100, meanB * 100);
      PrintFormat("Pair %d [PCT_BETA] Cov=%.10f, VarA=%.10f, Beta=%.4f", 
                  pairIndex + 1, covariance, varianceA, beta);
   }
   
   return beta;
}

//+------------------------------------------------------------------+
//| Calculate Return-Based Beta (for Percentage/Log Returns method)   |
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
   
   // Beta = Cov(A,B) / Var(A) - using variance of Symbol A (not B!)
   double covariance = (sumAB / n) - (meanA * meanB);
   double varianceA = (sumA2 / n) - (meanA * meanA);
   
   if(varianceA <= 0) 
   {
      if(InpDebugMode)
      {
         PrintFormat("Pair %d: varianceA is zero or negative (%.10f), using beta=1.0", 
                     pairIndex + 1, varianceA);
      }
      return 1.0;
   }
   
   double beta = MathAbs(covariance / varianceA);
   
   // Clamp beta to reasonable range (0.1 to 10.0)
   if(beta < 0.1) beta = 0.1;
   if(beta > 10.0) beta = 10.0;
   
   if(InpDebugMode && pairIndex == 0)
   {
      PrintFormat("Pair 1 [RETURNS] Beta: cov=%.10f, varA=%.10f, beta=%.4f", 
                  covariance, varianceA, beta);
   }
   
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
//| ================ SIGNAL ENGINE (v3.1) ================             |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Analyze All Pairs for Trading Signals (v3.1)                       |
//| Separate Buy/Sell Side Analysis - Check directionBuy/Sell == -1   |
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
      if(g_pairs[i].directionBuy == -1 && g_pairs[i].orderCountBuy < g_pairs[i].maxOrderBuy)
      {
         if(zScore < -InpEntryZScore)
         {
            if(OpenBuySideTrade(i))
            {
               g_pairs[i].directionBuy = 1;  // Active trade
            }
         }
      }
      
      // === SELL SIDE ENTRY ===
      // Condition: directionSell == -1 (Ready) AND Z-Score > +EntryThreshold
      if(g_pairs[i].directionSell == -1 && g_pairs[i].orderCountSell < g_pairs[i].maxOrderSell)
      {
         if(zScore > InpEntryZScore)
         {
            if(OpenSellSideTrade(i))
            {
               g_pairs[i].directionSell = 1;  // Active trade
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| ================ EXECUTION ENGINE (v3.0) ================          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Open Buy Side Trade                                                |
//| Positive Correlation: SymbolA=BUY, SymbolB=SELL                   |
//| Negative Correlation: SymbolA=BUY, SymbolB=BUY                    |
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
//| Positive Correlation: SymbolA=SELL, SymbolB=BUY                   |
//| Negative Correlation: SymbolA=SELL, SymbolB=SELL                  |
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
//| Close Buy Side Trade                                               |
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
   
   if(closedA && closedB)
   {
      PrintFormat("Pair %d BUY SIDE CLOSED | Profit: %.2f", pairIndex + 1, g_pairs[pairIndex].profitBuy);
      
      // Update statistics before reset
      g_dailyProfit += g_pairs[pairIndex].profitBuy;
      g_weeklyProfit += g_pairs[pairIndex].profitBuy;
      g_monthlyProfit += g_pairs[pairIndex].profitBuy;
      g_allTimeProfit += g_pairs[pairIndex].profitBuy;
      g_dailyLot += g_pairs[pairIndex].lotBuyA + g_pairs[pairIndex].lotBuyB;
      g_weeklyLot += g_pairs[pairIndex].lotBuyA + g_pairs[pairIndex].lotBuyB;
      g_monthlyLot += g_pairs[pairIndex].lotBuyA + g_pairs[pairIndex].lotBuyB;
      g_allTimeLot += g_pairs[pairIndex].lotBuyA + g_pairs[pairIndex].lotBuyB;
      
      // Reset Buy side state (back to Off, not Ready)
      g_pairs[pairIndex].ticketBuyA = 0;
      g_pairs[pairIndex].ticketBuyB = 0;
      g_pairs[pairIndex].directionBuy = 0;
      g_pairs[pairIndex].profitBuy = 0;
      g_pairs[pairIndex].entryTimeBuy = 0;
      
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
   
   if(closedA && closedB)
   {
      PrintFormat("Pair %d SELL SIDE CLOSED | Profit: %.2f", pairIndex + 1, g_pairs[pairIndex].profitSell);
      
      // Update statistics before reset
      g_dailyProfit += g_pairs[pairIndex].profitSell;
      g_weeklyProfit += g_pairs[pairIndex].profitSell;
      g_monthlyProfit += g_pairs[pairIndex].profitSell;
      g_allTimeProfit += g_pairs[pairIndex].profitSell;
      g_dailyLot += g_pairs[pairIndex].lotSellA + g_pairs[pairIndex].lotSellB;
      g_weeklyLot += g_pairs[pairIndex].lotSellA + g_pairs[pairIndex].lotSellB;
      g_monthlyLot += g_pairs[pairIndex].lotSellA + g_pairs[pairIndex].lotSellB;
      g_allTimeLot += g_pairs[pairIndex].lotSellA + g_pairs[pairIndex].lotSellB;
      
      // Reset Sell side state (back to Off, not Ready)
      g_pairs[pairIndex].ticketSellA = 0;
      g_pairs[pairIndex].ticketSellB = 0;
      g_pairs[pairIndex].directionSell = 0;
      g_pairs[pairIndex].profitSell = 0;
      g_pairs[pairIndex].entryTimeSell = 0;
      
      return true;
   }
   
   return false;
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
//| ================ POSITION MANAGEMENT ================              |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Manage All Open Positions (v3.0)                                   |
//+------------------------------------------------------------------+
void ManageAllPositions()
{
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(!g_pairs[i].enabled) continue;
      
      double zScore = g_pairs[i].zScore;
      
      // === Manage Buy Side ===
      if(g_pairs[i].directionBuy == 1)  // Only active trades
      {
         // Exit: Z-Score returned to normal (>= -ExitThreshold)
         if(zScore >= -InpExitZScore)
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
      if(g_pairs[i].directionSell == 1)  // Only active trades
      {
         // Exit: Z-Score returned to normal (<= +ExitThreshold)
         if(zScore <= InpExitZScore)
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
//| Update Pair Profits (v3.0)                                         |
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
         
         g_pairs[i].profitSell = profitA + profitB;
      }
      else
      {
         g_pairs[i].profitSell = 0;
      }
      
      // Combined profit for this pair
      g_pairs[i].totalPairProfit = g_pairs[i].profitBuy + g_pairs[i].profitSell;
      g_totalCurrentProfit += g_pairs[i].totalPairProfit;
   }
}

//+------------------------------------------------------------------+
//| ================ TARGET SYSTEM (v3.0) ================             |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check Per-Pair Targets                                             |
//+------------------------------------------------------------------+
void CheckPairTargets()
{
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(!g_pairs[i].enabled) continue;
      
      // Check Buy Side Target
      if(g_pairs[i].directionBuy == 1 && g_pairs[i].profitBuy >= g_pairs[i].targetBuy)
      {
         PrintFormat("Pair %d Buy Side TARGET REACHED: %.2f >= %.2f",
            i + 1, g_pairs[i].profitBuy, g_pairs[i].targetBuy);
         CloseBuySide(i);
      }
      
      // Check Sell Side Target
      if(g_pairs[i].directionSell == 1 && g_pairs[i].profitSell >= g_pairs[i].targetSell)
      {
         PrintFormat("Pair %d Sell Side TARGET REACHED: %.2f >= %.2f",
            i + 1, g_pairs[i].profitSell, g_pairs[i].targetSell);
         CloseSellSide(i);
      }
   }
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
//| ================ RISK MANAGEMENT ================                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check Risk Limits                                                  |
//+------------------------------------------------------------------+
void CheckRiskLimits()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   if(balance <= 0) return;
   
   double drawdown = ((g_maxEquity - equity) / g_maxEquity) * 100;
   
   if(drawdown > g_maxDrawdownPercent) g_maxDrawdownPercent = drawdown;
   
   if(drawdown >= InpEmergencyCloseDD)
   {
      PrintFormat("EMERGENCY: Drawdown %.2f%% exceeded limit - Closing ALL", drawdown);
      CloseAllBuySides();
      CloseAllSellSides();
      g_isPaused = true;
      return;
   }
}

//+------------------------------------------------------------------+
//| ================ DASHBOARD PANEL (v3.1) ================           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Create Dashboard Panel (New 3-Part Layout for 30 pairs)            |
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
   CreateLabel(prefix + "VER", PANEL_X + PANEL_WIDTH - 60, headerY + 5, "v3.1", COLOR_TEXT_WHITE, 9, "Arial");
   
   // ===== COLUMN HEADERS =====
   int colY = PANEL_Y + 35;
   
   // Buy Side Header (Left)
   int buyStartX = PANEL_X + 5;
   CreateRectangle(prefix + "HDR_BUY", buyStartX, colY, 395, 22, COLOR_HEADER_BUY, COLOR_BORDER);
   CreateLabel(prefix + "H_BUY", buyStartX + 150, colY + 4, "MAIN ORDER BUY", COLOR_TEXT_WHITE, 10, "Arial Bold");
   
   // Center Header (Pairs)
   int centerX = PANEL_X + 405;
   CreateRectangle(prefix + "HDR_CENTER", centerX, colY, 390, 22, COLOR_HEADER_MAIN, COLOR_BORDER);
   CreateLabel(prefix + "H_CENTER", centerX + 130, colY + 4, "TRADING PAIRS", COLOR_GOLD, 10, "Arial Bold");
   
   // Sell Side Header (Right)
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
   CreateLabel(prefix + "SH_B_TPL", buyStartX + 360, subY, "P/L", COLOR_TEXT_WHITE, 7, "Arial");
   
   // Center Sub-headers
   CreateLabel(prefix + "SH_C_PAIR", centerX + 10, subY, "Pair", COLOR_TEXT_WHITE, 7, "Arial");
   CreateLabel(prefix + "SH_C_CORR", centerX + 140, subY, "Corr%", COLOR_TEXT_WHITE, 7, "Arial");
   CreateLabel(prefix + "SH_C_TYPE", centerX + 195, subY, "Type", COLOR_TEXT_WHITE, 7, "Arial");
   CreateLabel(prefix + "SH_C_BETA", centerX + 250, subY, "Beta", COLOR_TEXT_WHITE, 7, "Arial");
   CreateLabel(prefix + "SH_C_TPL", centerX + 310, subY, "Total P/L", COLOR_TEXT_WHITE, 7, "Arial");
   
   // Sell Sub-headers
   CreateLabel(prefix + "SH_S_TPL", sellStartX + 5, subY, "P/L", COLOR_TEXT_WHITE, 7, "Arial");
   CreateLabel(prefix + "SH_S_Z", sellStartX + 50, subY, "Z-Score", COLOR_TEXT_WHITE, 7, "Arial");
   CreateLabel(prefix + "SH_S_ST", sellStartX + 105, subY, "Status", COLOR_TEXT_WHITE, 7, "Arial");
   CreateLabel(prefix + "SH_S_TGT", sellStartX + 155, subY, "Target", COLOR_TEXT_WHITE, 7, "Arial");
   CreateLabel(prefix + "SH_S_MAX", sellStartX + 210, subY, "Max", COLOR_TEXT_WHITE, 7, "Arial");
   CreateLabel(prefix + "SH_S_ORD", sellStartX + 255, subY, "Order", COLOR_TEXT_WHITE, 7, "Arial");
   CreateLabel(prefix + "SH_S_LOT", sellStartX + 305, subY, "Lot", COLOR_TEXT_WHITE, 7, "Arial");
   CreateLabel(prefix + "SH_S_PROF", sellStartX + 345, subY, "Profit", COLOR_TEXT_WHITE, 7, "Arial");
   CreateLabel(prefix + "SH_S_X", sellStartX + 380, subY, "X", COLOR_TEXT_WHITE, 7, "Arial");
   
   // ===== PAIR ROWS (30 Pairs) =====
   int rowStartY = subY + 18;
   
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      int rowY = rowStartY + i * ROW_HEIGHT;
      color rowBg = (i % 2 == 0) ? COLOR_BG_ROW_EVEN : COLOR_BG_ROW_ODD;
      
      // Row backgrounds
      CreateRectangle(prefix + "ROW_B_" + IntegerToString(i), buyStartX, rowY, 395, ROW_HEIGHT - 1, rowBg, rowBg);
      CreateRectangle(prefix + "ROW_C_" + IntegerToString(i), centerX, rowY, 390, ROW_HEIGHT - 1, rowBg, rowBg);
      CreateRectangle(prefix + "ROW_S_" + IntegerToString(i), sellStartX, rowY, 395, ROW_HEIGHT - 1, rowBg, rowBg);
      
      // Create pair row content
      CreatePairRow(prefix, i, buyStartX, centerX, sellStartX, rowY);
   }
   
   // ===== ACCOUNT SUMMARY SECTION =====
   int summaryY = rowStartY + MAX_PAIRS * ROW_HEIGHT + 5;
   CreateAccountSummary(prefix, summaryY);
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Create Pair Row (v3.1 - 3-Part Layout with Toggle Buttons)         |
//+------------------------------------------------------------------+
void CreatePairRow(string prefix, int idx, int buyX, int centerX, int sellX, int y)
{
   string idxStr = IntegerToString(idx);
   string pairName = g_pairs[idx].symbolA + "-" + g_pairs[idx].symbolB;
   
   // === BUY SIDE DATA ===
   // Close button
   CreateButton(prefix + "_CLOSE_BUY_" + idxStr, buyX + 5, y + 2, 16, 14, "X", clrRed, clrWhite);
   
   // Profit
   CreateLabel(prefix + "P" + idxStr + "_B_PROF", buyX + 28, y + 3, "0", COLOR_TEXT, FONT_SIZE, "Arial");
   
   // Lot
   CreateLabel(prefix + "P" + idxStr + "_B_LOT", buyX + 75, y + 3, "0.00", COLOR_TEXT, FONT_SIZE, "Arial");
   
   // Order count
   CreateLabel(prefix + "P" + idxStr + "_B_ORD", buyX + 128, y + 3, "0", COLOR_TEXT, FONT_SIZE, "Arial");
   
   // Max orders (editable)
   CreateEditField(prefix + "_MAX_BUY_" + idxStr, buyX + 160, y + 2, 30, 14, IntegerToString(InpDefaultMaxOrderBuy));
   
   // Target (editable)
   CreateEditField(prefix + "_TGT_BUY_" + idxStr, buyX + 200, y + 2, 45, 14, DoubleToString(InpDefaultTargetBuy, 0));
   
   // Status (Toggle Button - v3.1)
   string buyStatusText = g_pairs[idx].enabled ? "Off" : "-";
   color buyStatusColor = COLOR_OFF;
   CreateButton(prefix + "_ST_BUY_" + idxStr, buyX + 255, y + 2, 40, 14, buyStatusText, buyStatusColor, clrWhite);
   
   // Z-Score
   CreateLabel(prefix + "P" + idxStr + "_B_Z", buyX + 310, y + 3, "0.00", COLOR_TEXT, FONT_SIZE, "Arial");
   
   // P/L (this side)
   CreateLabel(prefix + "P" + idxStr + "_B_PL", buyX + 360, y + 3, "0", COLOR_TEXT, FONT_SIZE, "Arial");
   
   // === CENTER DATA (Pair Info) ===
   // Pair name
   CreateLabel(prefix + "P" + idxStr + "_NAME", centerX + 10, y + 3, pairName, COLOR_TEXT, FONT_SIZE, "Arial Bold");
   
   // Correlation %
   CreateLabel(prefix + "P" + idxStr + "_CORR", centerX + 140, y + 3, "0%", COLOR_TEXT, FONT_SIZE, "Arial");
   
   // Correlation Type
   CreateLabel(prefix + "P" + idxStr + "_TYPE", centerX + 195, y + 3, "Pos", COLOR_PROFIT, FONT_SIZE, "Arial");
   
   // Beta/Hedge Ratio
   CreateLabel(prefix + "P" + idxStr + "_BETA", centerX + 250, y + 3, "1.00", COLOR_TEXT, FONT_SIZE, "Arial");
   
   // Total P/L (both sides)
   CreateLabel(prefix + "P" + idxStr + "_TPL", centerX + 310, y + 3, "0", COLOR_TEXT, 9, "Arial Bold");
   
   // === SELL SIDE DATA ===
   // P/L
   CreateLabel(prefix + "P" + idxStr + "_S_PL", sellX + 5, y + 3, "0", COLOR_TEXT, FONT_SIZE, "Arial");
   
   // Z-Score
   CreateLabel(prefix + "P" + idxStr + "_S_Z", sellX + 50, y + 3, "0.00", COLOR_TEXT, FONT_SIZE, "Arial");
   
   // Status (Toggle Button - v3.1)
   string sellStatusText = g_pairs[idx].enabled ? "Off" : "-";
   color sellStatusColor = COLOR_OFF;
   CreateButton(prefix + "_ST_SELL_" + idxStr, sellX + 100, y + 2, 40, 14, sellStatusText, sellStatusColor, clrWhite);
   
   // Target (editable)
   CreateEditField(prefix + "_TGT_SELL_" + idxStr, sellX + 150, y + 2, 45, 14, DoubleToString(InpDefaultTargetSell, 0));
   
   // Max orders (editable)
   CreateEditField(prefix + "_MAX_SELL_" + idxStr, sellX + 205, y + 2, 30, 14, IntegerToString(InpDefaultMaxOrderSell));
   
   // Order count
   CreateLabel(prefix + "P" + idxStr + "_S_ORD", sellX + 262, y + 3, "0", COLOR_TEXT, FONT_SIZE, "Arial");
   
   // Lot
   CreateLabel(prefix + "P" + idxStr + "_S_LOT", sellX + 305, y + 3, "0.00", COLOR_TEXT, FONT_SIZE, "Arial");
   
   // Profit
   CreateLabel(prefix + "P" + idxStr + "_S_PROF", sellX + 345, y + 3, "0", COLOR_TEXT, FONT_SIZE, "Arial");
   
   // Close button
   CreateButton(prefix + "_CLOSE_SELL_" + idxStr, sellX + 375, y + 2, 16, 14, "X", clrRed, clrWhite);
}

//+------------------------------------------------------------------+
//| Create Account Summary Section (v3.0 - 4-Box Layout)               |
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
   
   CreateLabel(prefix + "L_LIC", box2X + 155, y + 54, "License:", COLOR_TEXT_WHITE, 8, "Arial");
   CreateLabel(prefix + "V_LIC", box2X + 210, y + 54, g_isLicenseValid ? "VALID" : "INVALID", g_isLicenseValid ? COLOR_ON : COLOR_LOSS, 9, "Arial Bold");
   
   // === BOX 3: HISTORY LOT ===
   int box3X = startX + 2 * (boxWidth + gap);
   CreateRectangle(prefix + "BOX3_BG", box3X, y, boxWidth, boxHeight, C'30,35,45', COLOR_BORDER);
   CreateLabel(prefix + "BOX3_HDR", box3X + 10, y + 5, "HISTORY LOT", COLOR_GOLD, 9, "Arial Bold");
   
   CreateLabel(prefix + "L_DLOT", box3X + 10, y + 22, "Daily:", COLOR_TEXT_WHITE, 8, "Arial");
   CreateLabel(prefix + "V_DLOT", box3X + 60, y + 22, "0.00", COLOR_TEXT_WHITE, 9, "Arial");
   
   CreateLabel(prefix + "L_WLOT", box3X + 10, y + 38, "Weekly:", COLOR_TEXT_WHITE, 8, "Arial");
   CreateLabel(prefix + "V_WLOT", box3X + 60, y + 38, "0.00", COLOR_TEXT_WHITE, 9, "Arial");
   
   CreateLabel(prefix + "L_MLOT", box3X + 155, y + 22, "Monthly:", COLOR_TEXT_WHITE, 8, "Arial");
   CreateLabel(prefix + "V_MLOT", box3X + 210, y + 22, "0.00", COLOR_TEXT_WHITE, 9, "Arial");
   
   CreateLabel(prefix + "L_ALOT", box3X + 155, y + 38, "All Time:", COLOR_TEXT_WHITE, 8, "Arial");
   CreateLabel(prefix + "V_ALOT", box3X + 210, y + 38, "0.00", COLOR_TEXT_WHITE, 9, "Arial");
   
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
   
   // v3.2.3: Start All / Stop All Buttons
   CreateButton(prefix + "_START_ALL", box4X + 145, y + 54, 60, 16, "Start All", COLOR_ON, clrWhite);
   CreateButton(prefix + "_STOP_ALL", box4X + 210, y + 54, 60, 16, "Stop All", COLOR_OFF, clrWhite);
}

//+------------------------------------------------------------------+
//| Update Dashboard Values (v3.1)                                     |
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
         totalOrders += 2;
      }
      if(g_pairs[i].directionSell == 1)
      {
         totalLot += g_pairs[i].lotSellA + g_pairs[i].lotSellB;
         totalOrders += 2;
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
   
   // Lot Statistics
   UpdateLabel(prefix + "V_DLOT", DoubleToString(g_dailyLot, 2), COLOR_TEXT_WHITE);
   UpdateLabel(prefix + "V_WLOT", DoubleToString(g_weeklyLot, 2), COLOR_TEXT_WHITE);
   UpdateLabel(prefix + "V_MLOT", DoubleToString(g_monthlyLot, 2), COLOR_TEXT_WHITE);
   UpdateLabel(prefix + "V_ALOT", DoubleToString(g_allTimeLot, 2), COLOR_TEXT_WHITE);
   
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
      // Handle disabled or invalid data pairs
      if(!g_pairs[i].enabled)
      {
         UpdateLabel(prefix + "P" + idxStr + "_CORR", "-", COLOR_OFF);
         UpdateLabel(prefix + "P" + idxStr + "_TYPE", "-", COLOR_OFF);
         UpdateLabel(prefix + "P" + idxStr + "_BETA", "-", COLOR_OFF);
      }
      else if(!g_pairs[i].dataValid)
      {
         // Show N/A when data is not available
         UpdateLabel(prefix + "P" + idxStr + "_CORR", "N/A", COLOR_GOLD);
         UpdateLabel(prefix + "P" + idxStr + "_TYPE", "N/A", COLOR_GOLD);
         UpdateLabel(prefix + "P" + idxStr + "_BETA", "N/A", COLOR_GOLD);
      }
      else
      {
         // Normal display with valid data
         // Correlation %
         double corr = g_pairs[i].correlation * 100;
         color corrColor = MathAbs(corr) >= InpMinCorrelation * 100 ? COLOR_PROFIT : COLOR_TEXT;
         UpdateLabel(prefix + "P" + idxStr + "_CORR", DoubleToString(corr, 0) + "%", corrColor);
         
         // Correlation Type
         string corrType = g_pairs[i].correlationType == 1 ? "Pos" : "Neg";
         color typeColor = g_pairs[i].correlationType == 1 ? COLOR_PROFIT : COLOR_LOSS;
         UpdateLabel(prefix + "P" + idxStr + "_TYPE", corrType, typeColor);
         
         // Beta
         UpdateLabel(prefix + "P" + idxStr + "_BETA", DoubleToString(g_pairs[i].hedgeRatio, 2), COLOR_TEXT);
      }
      
      // Total P/L
      double totalPL = g_pairs[i].totalPairProfit;
      UpdateLabel(prefix + "P" + idxStr + "_TPL", DoubleToString(totalPL, 0), totalPL >= 0 ? COLOR_PROFIT : COLOR_LOSS);
      
      // === Buy Side Data ===
      // Profit
      UpdateLabel(prefix + "P" + idxStr + "_B_PROF", DoubleToString(g_pairs[i].profitBuy, 0), 
                  g_pairs[i].profitBuy >= 0 ? COLOR_PROFIT : COLOR_LOSS);
      
      // Lot
      double buyLot = g_pairs[i].directionBuy == 1 ? g_pairs[i].lotBuyA + g_pairs[i].lotBuyB : 0;
      UpdateLabel(prefix + "P" + idxStr + "_B_LOT", DoubleToString(buyLot, 2), COLOR_TEXT);
      
      // Order count
      UpdateLabel(prefix + "P" + idxStr + "_B_ORD", IntegerToString(g_pairs[i].orderCountBuy), 
                  g_pairs[i].orderCountBuy > 0 ? COLOR_ACTIVE : COLOR_TEXT);
      
      // Z-Score (same for both sides)
      double zScore = g_pairs[i].zScore;
      color zColor = MathAbs(zScore) > InpEntryZScore ? (zScore > 0 ? COLOR_LOSS : COLOR_PROFIT) : COLOR_TEXT;
      UpdateLabel(prefix + "P" + idxStr + "_B_Z", DoubleToString(zScore, 2), zColor);
      
      // P/L
      UpdateLabel(prefix + "P" + idxStr + "_B_PL", DoubleToString(g_pairs[i].profitBuy, 0),
                  g_pairs[i].profitBuy >= 0 ? COLOR_PROFIT : COLOR_LOSS);
      
      // Status Button Update (v3.1)
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
      // Profit
      UpdateLabel(prefix + "P" + idxStr + "_S_PROF", DoubleToString(g_pairs[i].profitSell, 0),
                  g_pairs[i].profitSell >= 0 ? COLOR_PROFIT : COLOR_LOSS);
      
      // Lot
      double sellLot = g_pairs[i].directionSell == 1 ? g_pairs[i].lotSellA + g_pairs[i].lotSellB : 0;
      UpdateLabel(prefix + "P" + idxStr + "_S_LOT", DoubleToString(sellLot, 2), COLOR_TEXT);
      
      // Order count
      UpdateLabel(prefix + "P" + idxStr + "_S_ORD", IntegerToString(g_pairs[i].orderCountSell),
                  g_pairs[i].orderCountSell > 0 ? COLOR_ACTIVE : COLOR_TEXT);
      
      // Z-Score
      UpdateLabel(prefix + "P" + idxStr + "_S_Z", DoubleToString(zScore, 2), zColor);
      
      // P/L
      UpdateLabel(prefix + "P" + idxStr + "_S_PL", DoubleToString(g_pairs[i].profitSell, 0),
                  g_pairs[i].profitSell >= 0 ? COLOR_PROFIT : COLOR_LOSS);
      
      // Status Button Update (v3.1)
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
//| ================ HELPER FUNCTIONS ================                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Create Rectangle                                                   |
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
//| Create Label                                                       |
//+------------------------------------------------------------------+
void CreateLabel(string name, int x, int y, string text, color clr, int fontSize, string font)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, font);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Update Label                                                       |
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
//| Create Button (Clickable)                                          |
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
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, bgColor);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 7);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Create Editable Field                                              |
//+------------------------------------------------------------------+
void CreateEditField(string name, int x, int y, int width, int height, string defaultValue)
{
   ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetString(0, name, OBJPROP_TEXT, defaultValue);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, C'40,45,55');
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, COLOR_BORDER);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ALIGN, ALIGN_CENTER);
   ObjectSetInteger(0, name, OBJPROP_READONLY, false);
}
//+------------------------------------------------------------------+
