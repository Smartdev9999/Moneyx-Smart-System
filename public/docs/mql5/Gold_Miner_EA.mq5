//+------------------------------------------------------------------+
//|                                           Gold_Miner_SQ_EA.mq5   |
//|                                    Copyright 2025, MoneyX Smart  |
//|                Gold Miner EA v5.1 - MTF ZigZag+CDC+Grid+License  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MoneyX Smart System"
#property link      "https://moneyxsmartsystem.lovable.app"
#property version   "5.10"
#property description "Gold Miner EA v5.1 - MTF ZigZag + CDC + Squeeze + Hedge Set Isolation + License"
#property strict

#include <Trade/Trade.mqh>

//--- Enums
enum ENUM_LOT_MODE
{
   LOT_ADD     = 0,  // Add Lot
   LOT_CUSTOM  = 1,  // Custom Lot
   LOT_MULTIPLY= 2   // Multiply Lot
};

enum ENUM_GAP_TYPE
{
   GAP_FIXED   = 0,  // Fixed Points
   GAP_CUSTOM  = 1,  // Custom Distance
   GAP_ATR     = 2   // ATR-Based
};

enum ENUM_ATR_REF
{
   ATR_REF_INITIAL  = 0,  // From Initial Order (cumulative)
   ATR_REF_DYNAMIC  = 1   // From Last Grid Order
};

enum ENUM_SL_ACTION
{
   SL_CLOSE_POSITIONS = 0,  // Close Positions (Stop Loss)
   SL_CLOSE_ALL_STOP  = 1   // Close All & Stop EA
};

enum ENUM_TRADE_MODE
{
   TRADE_BUY_ONLY  = 0,  // Buy Only
   TRADE_SELL_ONLY = 1,  // Sell Only
   TRADE_BOTH      = 2   // Buy and Sell
};

enum ENUM_ENTRY_MODE
{
   ENTRY_SMA      = 0,  // SMA Mode (Original)
   ENTRY_ZIGZAG   = 1,  // ZigZag Multi-Timeframe Mode
   ENTRY_INSTANT  = 2   // Instant Mode (No Indicator)
};

// License Status Enumeration
enum ENUM_LICENSE_STATUS
{
   LICENSE_VALID,           // License Valid
   LICENSE_EXPIRING_SOON,   // License Expiring Soon (within 7 days)
   LICENSE_EXPIRED,         // License Expired
   LICENSE_NOT_FOUND,       // Account Not Registered
   LICENSE_SUSPENDED,       // License Suspended
   LICENSE_ERROR            // Connection Error
};

enum ENUM_DD_MODE
{
   DD_PERCENT       = 0,  // Percent (%)
   DD_FIXED_DOLLAR  = 1   // Fixed Dollar ($)
};

// Sync Event Type (for real-time data sync)
enum ENUM_SYNC_EVENT
{
   SYNC_SCHEDULED,          // Scheduled sync (daily)
   SYNC_ORDER_OPEN,         // Order opened
   SYNC_ORDER_CLOSE         // Order closed
};

// News Event Structure
struct NewsEvent
{
   string   title;       // News title
   string   country;     // Currency (e.g., USD, EUR)
   datetime time;        // Event time
   string   impact;      // "Low", "Medium", "High"
   bool     isRelevant;  // Matches our filter criteria
};

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+

//--- General Settings
input group "=== General Settings ==="
input int              MagicNumber        = 202500;    // Magic Number
input int              MaxSlippage        = 30;        // Max Slippage (points)
input int              MaxOpenOrders      = 20;        // Max Open Orders
input ENUM_DD_MODE     DrawdownMode       = DD_PERCENT; // Drawdown Mode (% or Fixed $)
input double           MaxDrawdownPct     = 30.0;      // Max Drawdown % (when mode = %)
input double           MaxDrawdownDollar  = 5000.0;    // Max Drawdown $ (when mode = Fixed $)
input bool             StopEAOnDrawdown   = false;     // Stop EA after Emergency Drawdown Close
input ENUM_TRADE_MODE  TradingMode        = TRADE_BOTH; // Trading Mode (Buy/Sell/Both)
input ENUM_ENTRY_MODE  EntryMode          = ENTRY_SMA;  // Entry Mode (SMA=Original, ZigZag=MTF)

//--- SMA Indicator
input group "=== SMA Indicator ==="
input int               SMA_Period       = 20;              // SMA Period
input ENUM_APPLIED_PRICE SMA_AppliedPrice = PRICE_CLOSE;    // SMA Applied Price
input ENUM_TIMEFRAMES   SMA_Timeframe    = PERIOD_CURRENT;  // SMA Timeframe
input bool              EnableAutoReEntry = true;            // Auto Re-Entry when signal persists
input bool              DontOpenSameCandle= true;            // Don't Open in Same Initial Candle

//--- Initial Lot
input group "=== Initial Lot ==="
input double   InitialLotSize     = 0.01;     // Initial Lot Size
input double   InpMaxLotSize      = 0.0;      // Max Lot Size (0=No Limit)

//--- Grid Loss Side
input group "=== Grid Loss Side ==="
input int            GridLoss_MaxTrades      = 5;          // Max Grid Loss Trades
input ENUM_LOT_MODE  GridLoss_LotMode        = LOT_ADD;    // Grid Loss Lot Mode
input string         GridLoss_CustomLots     = "0.01;0.02;0.03;0.04;0.05"; // Custom Lots (semicolon separated)
input double         GridLoss_AddLotPerLevel = 0.4;        // Add Lot per Level (multiplied by InitialLot)
input double         GridLoss_MultiplyFactor = 2.0;        // Multiply Factor (for Multiply mode)
input ENUM_GAP_TYPE  GridLoss_GapType        = GAP_FIXED;  // Grid Loss Gap Type
input int            GridLoss_Points         = 500;        // Grid Loss Distance (points)
input string         GridLoss_CustomDistance  = "100;200;300;400;500"; // Custom Distance (points, semicolon)
input ENUM_TIMEFRAMES GridLoss_ATR_TF        = PERIOD_H1;  // ATR Timeframe
input int            GridLoss_ATR_Period     = 14;         // ATR Period
input double         GridLoss_ATR_Multiplier = 1.5;        // ATR Multiplier
input ENUM_ATR_REF   GridLoss_ATR_Reference  = ATR_REF_DYNAMIC; // ATR Reference Point
input int            GridLoss_MinGapPoints   = 100;             // Minimum Grid Gap (points)
input bool           GridLoss_OnlyInSignal   = false;      // Grid Only in Signal Direction
input bool           GridLoss_OnlyNewCandle  = true;       // Grid Only on New Candle
input bool           GridLoss_DontSameCandle = true;       // Don't Open Grid in Same Candle as Initial

//--- Grid Profit Side
input group "=== Grid Profit Side ==="
input bool           GridProfit_Enable       = true;       // Enable Profit Grid
input int            GridProfit_MaxTrades    = 3;          // Max Grid Profit Trades
input ENUM_LOT_MODE  GridProfit_LotMode      = LOT_ADD;    // Grid Profit Lot Mode
input string         GridProfit_CustomLots   = "0.01;0.02;0.03"; // Custom Lots
input double         GridProfit_AddLotPerLevel= 0.2;       // Add Lot per Level
input double         GridProfit_MultiplyFactor= 1.5;       // Multiply Factor
input ENUM_GAP_TYPE  GridProfit_GapType      = GAP_FIXED;  // Grid Profit Gap Type
input int            GridProfit_Points       = 300;        // Grid Profit Distance (points)
input string         GridProfit_CustomDistance= "100;200;500"; // Custom Distance
input ENUM_TIMEFRAMES GridProfit_ATR_TF      = PERIOD_H1;  // ATR Timeframe
input int            GridProfit_ATR_Period   = 14;         // ATR Period
input double         GridProfit_ATR_Multiplier= 1.0;       // ATR Multiplier
input ENUM_ATR_REF   GridProfit_ATR_Reference = ATR_REF_DYNAMIC; // ATR Reference Point
input int            GridProfit_MinGapPoints  = 100;             // Minimum Grid Gap (points)
input bool           GridProfit_OnlyNewCandle= true;       // Grid Only on New Candle

//--- Take Profit
input group "=== Take Profit ==="
input bool     UseTP_Dollar        = true;     // Use TP Fixed Dollar
input double   TP_DollarAmount     = 100.0;    // TP Dollar Amount
input bool     UseTP_Points        = false;    // Use TP in Points (from Average)
input int      TP_Points           = 2000;     // TP Points from Average
input bool     UseTP_PercentBalance = false;   // Use TP % of Balance
input double   TP_PercentBalance   = 5.0;      // TP % of Balance
input bool     UseAccumulateClose  = false;    // Use Accumulate Close
input double   AccumulateTarget    = 20000.0;  // Accumulate Target ($)
input bool     ShowAverageLine     = true;          // Show Average Price Line
input bool     ShowTPLine          = true;          // Show TP Line
input color    AvgBuyLineColor     = clrDodgerBlue; // Average Buy Line Color
input color    AvgSellLineColor    = clrOrangeRed;  // Average Sell Line Color
input color    TPBuyLineColor      = clrLime;       // TP Buy Line Color
input color    TPSellLineColor     = clrMagenta;    // TP Sell Line Color

//--- Stop Loss
input group "=== Stop Loss ==="
input bool           EnableSL            = true;              // Enable Stop Loss
input ENUM_SL_ACTION SL_ActionMode       = SL_CLOSE_POSITIONS;// SL Action Mode
input bool           UseSL_Dollar        = true;              // Use SL Fixed Dollar
input double         SL_DollarAmount     = 50.0;              // SL Dollar Amount
input bool           UseSL_Points        = false;             // Use SL in Points (from Average)
input int            SL_Points           = 1000;              // SL Points from Average
input bool           UseSL_PercentBalance = false;            // Use SL % of Balance
input double         SL_PercentBalance   = 3.0;               // SL % of Balance
input bool           ShowSLLine          = true;              // Show SL Line
input color          SLLineColor         = clrRed;            // SL Line Color

//--- Trailing Stop (Average-Based)
input group "=== Trailing Stop (Average-Based) ==="
input bool     EnableTrailingStop   = false;   // Enable Average-Based Trailing Stop
input int      TrailingActivation   = 100;     // Trailing Activation (points from average)
input int      TrailingStep         = 50;      // Trailing Step (points from current price)
input int      BreakevenBuffer      = 10;      // Breakeven Buffer (points above/below average)
input bool     EnableBreakeven      = true;    // Enable Breakeven
input int      BreakevenActivation  = 50;      // Breakeven Activation (points from average)

//--- Per-Order Trailing Stop (NEW - Standard Breakeven + Trailing)
input group "=== Per-Order Trailing Stop ==="
input bool     EnablePerOrderTrailing    = true;     // Enable Per-Order Trailing
input bool     InpEnableBreakeven        = true;     // Enable Breakeven
input int      InpBreakevenTarget        = 200;      // Breakeven Target (profit points to activate)
input int      InpBreakevenOffset        = 5;        // Breakeven Offset (points above/below open)
input bool     InpEnableTrailing         = true;     // Enable Trailing
input int      InpTrailingStop           = 200;      // Trailing Distance (points from current price)
input int      InpTrailingStep           = 10;       // Trailing Step (min SL movement in points)

//--- Dashboard
input group "=== Dashboard ==="
input bool     ShowDashboard        = true;    // Show Dashboard
input int      DashboardX           = 20;      // Dashboard X Position
input int      DashboardY           = 30;      // Dashboard Y Position
input color    DashboardColor       = clrWhite; // Dashboard Text Color
input double   DashboardScale       = 1.0;     // Dashboard Scale (0.8-1.5)

//--- Rebate Settings
input group "=== Rebate Settings ==="
input double   InpRebatePerLot      = 4.5;     // Rebate per Lot ($)

//--- Backtest Optimization
input group "=== Backtest Optimization ==="
input bool     InpSkipATRInTester   = true;    // Skip ATR Indicator in Tester (use Simplified)

//--- License Settings
input group "=== License Settings ==="
input string   InpLicenseServer     = "https://lkbhomsulgycxawwlnfh.supabase.co";  // License Server URL
input int      InpLicenseCheckMinutes = 60;    // License Check Interval (minutes)
input int      InpDataSyncMinutes   = 5;       // Account Data Sync Interval (minutes)

// ====== HARDCODED API SECRET - DO NOT MODIFY ======
const string EA_API_SECRET = "moneyx-ea-secret-2024-secure-key-v1";

//--- Time Filter
input group "=== Time Filter ==="
input bool     InpUseTimeFilter     = false;           // Use Time Filter
input string   InpSession1          = "03:10-12:40";   // Tradable Session #1 [hh:mm-hh:mm]
input string   InpSession2          = "15:10-22:00";   // Tradable Session #2 [hh:mm-hh:mm]
input string   InpSession3          = "";              // Tradable Session #3 [hh:mm-hh:mm]
input string   InpFridaySession1    = "03:10-12:40";   // Friday Session #1 [hh:mm-hh:mm]
input string   InpFridaySession2    = "";              // Friday Session #2 [hh:mm-hh:mm]
input string   InpFridaySession3    = "";              // Friday Session #3 [hh:mm-hh:mm]
input bool     InpTradeMonday       = true;            // Monday
input bool     InpTradeTuesday      = true;            // Tuesday
input bool     InpTradeWednesday    = true;            // Wednesday
input bool     InpTradeThursday     = true;            // Thursday
input bool     InpTradeFriday       = true;            // Friday
input bool     InpTradeSaturday     = false;           // Saturday
input bool     InpTradeSunday       = false;           // Sunday

//--- News Filter
input group "=== News Filter ==="
//--- Daily Profit Pause
input group "=== Daily Profit Pause ==="
input bool     InpEnableDailyProfitPause = false;    // Enable Daily Profit Pause
input double   InpDailyProfitTarget      = 100.0;    // Daily Profit Target ($)

input bool     InpEnableNewsFilter   = false;          // Enable News Filter
input bool     InpNewsUseChartCurrency = false;        // Current Chart Currencies to Filter News
input string   InpNewsCurrencies     = "USD";          // Select Currency to Filter News (e.g. USD;EUR;GBP)
input bool     InpFilterLowNews      = false;          // Filter Low Impact News
input int      InpPauseBeforeLow     = 60;             // Pause Before a Low News (Min.)
input int      InpPauseAfterLow      = 30;             // Pause After a Low News (Min.)
input bool     InpFilterMedNews      = false;          // Filter Medium Impact News
input int      InpPauseBeforeMed     = 60;             // Pause Before a Medium News (Min.)
input int      InpPauseAfterMed      = 30;             // Pause After a Medium News (Min.)
input bool     InpFilterHighNews     = true;           // Filter High Impact News
input int      InpPauseBeforeHigh    = 240;            // Pause Before a High News (Min.)
input int      InpPauseAfterHigh     = 240;            // Pause After a High News (Min.)
input bool     InpFilterCustomNews   = true;           // Filter Custom News
input string   InpCustomNewsKeywords = "PMI;Unemployment Claims;Non-Farm;FOMC;Fed Chair Powell";  // Put News Title - Separate by semicolon(;)
input int      InpPauseBeforeCustom  = 300;            // Pause Before a Custom News (Min.)
input int      InpPauseAfterCustom   = 300;            // Pause After a Custom News (Min.)

//--- ZigZag Multi-Timeframe Settings
input group "=== ZigZag Multi-Timeframe Settings ==="
input int              ZZ_Depth            = 12;               // ZigZag Depth
input int              ZZ_Deviation        = 5;                // ZigZag Deviation
input int              ZZ_Backstep         = 3;                // ZigZag Backstep
input ENUM_TIMEFRAMES  ZZ_ConfirmTF        = PERIOD_H4;        // Confirm Timeframe (H4)
input bool             ZZ_UseM30           = true;             // Use M30 for Entry
input bool             ZZ_UseM15           = true;             // Use M15 for Entry
input bool             ZZ_UseM5            = false;            // Use M5 for Entry
input bool             ZZ_UseConfirmTFEntry= false;            // Also Enter on Confirm TF directly

//--- CDC Action Zone Trend Filter
input group "=== CDC Action Zone Trend Filter ==="
input bool             InpUseCDCFilter     = false;            // Enable CDC Trend Filter
input ENUM_TIMEFRAMES  InpCDCTimeframe     = PERIOD_D1;        // CDC Timeframe
input int              InpCDCFastPeriod    = 12;               // CDC Fast EMA Period
input int              InpCDCSlowPeriod    = 26;               // CDC Slow EMA Period
input bool             InpCDCRequireCross  = false;            // Require Crossover (not just position)

//--- Matching Close (Pair Profit vs Loss Orders)
input group "=== Matching Close ==="
input bool     UseMatchingClose       = false;    // Enable Matching Close
input double   MatchingMinProfit      = 0.50;     // Min Net Profit per Match ($)
input int      MatchingMaxLossOrders  = 3;        // Max Loss Orders per Match (1-10)
input int      MatchingMinProfitOrders = 1;       // Min Profit Orders to Start Matching
input int      MatchingMinTotalOrders  = 0;        // Min Total Orders to Activate (0=Always)

//--- Volatility Squeeze Filter (BB vs KC)
input group "=== Volatility Squeeze Filter ==="
input bool             InpUseSqueezeFilter      = false;          // Enable Squeeze Filter
input ENUM_TIMEFRAMES  InpSqueeze_TF1           = PERIOD_M5;      // Timeframe 1
input ENUM_TIMEFRAMES  InpSqueeze_TF2           = PERIOD_H1;      // Timeframe 2
input ENUM_TIMEFRAMES  InpSqueeze_TF3           = PERIOD_H4;      // Timeframe 3
input int              InpSqueeze_BB_Period     = 20;              // BB Period
input double           InpSqueeze_BB_Mult       = 2.0;            // BB Multiplier
input int              InpSqueeze_KC_Period     = 20;              // KC Period (EMA)
input double           InpSqueeze_KC_Mult       = 1.5;            // KC Multiplier (ATR)
input int              InpSqueeze_ATR_Period    = 14;              // ATR Period for KC
input double           InpSqueeze_ExpThreshold  = 1.5;            // Expansion Threshold (Intensity ratio)
input bool             InpSqueeze_BlockOnExpansion = true;         // Block New Orders on Expansion
input int              InpSqueeze_MinTFExpansion = 1;              // Min TFs in Expansion to Block (1-3)
input bool             InpSqueeze_DirectionalBlock = false;        // Directional Block (block counter-trend only)

//--- Counter-Trend Hedging
input group "=== Counter-Trend Hedging ==="
input bool     InpHedge_Enable              = false;   // Enable Hedging Mode (requires Squeeze Filter)
input double   InpHedge_MatchMinProfit      = 5.0;     // Min Profit for Hedge Matching ($)
input int      InpHedge_MatchMinProfitOrders = 2;      // Min Profit Orders for Hedge Grid Matching
input double   InpHedge_PartialMinProfit    = 5.0;     // Min Profit for Partial Close ($)
input int      InpHedge_PartialMinProfitOrders = 3;    // Min Profit Orders for Partial Close (0=Always)

//+------------------------------------------------------------------+
//| Global Variables                                                   |
//+------------------------------------------------------------------+
CTrade         trade;
int            handleSMA;
int            handleATR_Loss;
int            handleATR_Profit;
double         bufSMA[];
double         bufATR_Loss[];
double         bufATR_Profit[];
datetime       lastBarTime;
datetime       lastInitialCandleTime;
datetime       lastGridLossCandleTime;
datetime       lastGridProfitCandleTime;
bool           justClosedBuy;
bool           justClosedSell;
double         g_trailingSL_Buy;
double         g_trailingSL_Sell;
bool           g_trailingActive_Buy;
bool           g_trailingActive_Sell;
bool           g_breakevenDone_Buy;
bool           g_breakevenDone_Sell;
bool           g_eaStopped;
double         g_accumulatedProfit;
double         g_initialBuyPrice;   // track initial order price for grid fallback
double         g_initialSellPrice;  // track initial order price for grid fallback
double         g_accumulateBaseline; // Total history profit at last cycle reset
double         g_maxDD;             // Track max drawdown
bool           g_hadPositions;      // Track if we had positions (for accumulate auto-reset)

// Dashboard Control Variables (v2.9)
bool           g_eaIsPaused = false;           // EA Pause State (manual)
bool           g_atrChartHidden = false;       // ATR subwindow hidden flag (backtest)
int            g_atrHideAttempts = 0;          // ATR hide retry counter

// Daily Profit Pause Variables
bool           g_dailyProfitPaused   = false;  // Daily profit target reached
datetime       g_dailyProfitPauseDay = 0;      // Day when pause was triggered

// License Verification Variables
bool              g_isLicenseValid = false;
bool              g_isTesterMode = false;
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

// News Filter Variables
NewsEvent g_newsEvents[];
int g_newsEventCount = 0;
datetime g_lastNewsRefresh = 0;
bool g_isNewsPaused = false;
bool g_newOrderBlocked = false;  // true = News/Time filter blocks new entries only
string g_nextNewsTitle = "";
datetime g_nextNewsTime = 0;
string g_newsStatus = "OK";
datetime g_lastGoodNewsTime = 0;
bool g_usingCachedNews = false;
string g_newsCacheFile = "GoldMinerNewsCache.txt";
datetime g_lastFileCacheSave = 0;
bool g_webRequestConfigured = true;
datetime g_lastWebRequestCheck = 0;
datetime g_lastWebRequestAlert = 0;
int g_webRequestCheckInterval = 3600;
bool g_forceNewsRefresh = false;
bool g_lastPausedState = false;
string g_lastPauseKey = "";
datetime g_newsPauseEndTime = 0;

// === ZigZag Multi-Timeframe State (v3.0) ===
struct TFState
{
   ENUM_TIMEFRAMES tf;
   string          tfLabel;
   bool            enabled;
   int             handleZZ;
   double          lastSwingPrice;
   string          lastSwingType;
   datetime        lastSwingTime;
   double          initialBuyPrice;
   double          initialSellPrice;
   datetime        lastInitialCandle;
   datetime        lastGridLossCandle;
   datetime        lastGridProfitCandle;
   bool            justClosedBuy;
   bool            justClosedSell;
   double          trailSL_Buy;
   double          trailSL_Sell;
   bool            trailActive_Buy;
   bool            trailActive_Sell;
   bool            beDone_Buy;
   bool            beDone_Sell;
};

#define MAX_SUB_TF 4
TFState  g_tfStates[MAX_SUB_TF];
int      g_activeTFCount = 0;
int      g_h4TFIndex = -1;
string   g_h4Direction = "NONE";
datetime g_lastH4Bar = 0;

// CDC Action Zone state
string   g_cdcTrend = "NEUTRAL";
double   g_cdcFast = 0;
double   g_cdcSlow = 0;
bool     g_cdcReady = false;
datetime g_lastCdcCandle = 0;

// === Volatility Squeeze Filter State ===
struct SqueezeState
{
   ENUM_TIMEFRAMES tf;
   string          tfLabel;
   int             handleBB;       // iBands handle
   int             handleATR;      // iATR handle for KC
   int             handleEMA;      // iMA handle for KC center
   int             state;          // 0=Normal, 1=Squeeze, 2=Expansion
   double          intensity;      // BB_Width / KC_Width
   int             direction;      // 1=Bullish, -1=Bearish, 0=Neutral (Close vs EMA)
};
SqueezeState g_squeeze[3];
bool         g_squeezeBlocked = false;     // true when expansion detected (all block)
bool         g_squeezeBuyBlocked  = false;  // directional: block BUY only
bool         g_squeezeSellBlocked = false;  // directional: block SELL only

// === Counter-Trend Hedging State ===
#define MAX_HEDGE_SETS 4
#define MAX_BOUND_TICKETS 50
struct HedgeSet
{
   bool     active;           // is this hedge set active?
   ulong    hedgeTicket;      // main hedge order ticket
   ENUM_POSITION_TYPE hedgeSide;  // BUY or SELL (hedge direction)
   double   hedgeLots;        // current remaining hedge lots
   double   originalTotalLots; // original total lots when hedge opened
   ENUM_POSITION_TYPE counterSide; // the side being hedged (opposite of hedgeSide)
   bool     gridMode;         // true = original orders gone, hedge running as grid
   int      gridLevel;        // current grid level in grid mode
   ulong    gridTickets[];    // tickets of hedge grid orders
   int      gridTicketCount;  // count of grid tickets
   string   commentPrefix;    // "GM_HEDGE_1", "GM_HEDGE_2", etc.
   ulong    boundTickets[];   // tickets of counter-side orders bound to this set
   int      boundTicketCount; // count of bound tickets
};
HedgeSet g_hedgeSets[MAX_HEDGE_SETS];
int      g_hedgeSetCount = 0;
datetime g_lastHedgeGridTime = 0;  // cooldown timer for hedge grid orders
int      g_lastDashboardRowCount = 0;  // track previous tick row count for stale cleanup

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   // === Tester Mode Detection ===
   g_isTesterMode = IsTesterMode();

   if(g_isTesterMode)
   {
      Print("GOLD MINER EA - TESTER MODE");
      Print("License check skipped for backtesting");
      g_isLicenseValid = true;
      g_licenseStatus = LICENSE_VALID;
   }
   else
   {
      Print("GOLD MINER EA - LIVE TRADING MODE");
      if(!InitLicense(InpLicenseServer, InpLicenseCheckMinutes, InpDataSyncMinutes))
         Print("License initialization failed: ", g_lastLicenseError);
      ShowLicensePopup(g_licenseStatus);
      if(g_isLicenseValid)
      {
         Print("License Valid - Customer: ", g_customerName);
         if(g_isLifetime) Print("License Type: LIFETIME");
         else Print("Expiry: ", TimeToString(g_expiryDate, TIME_DATE), " (", g_daysRemaining, " days)");
      }
   }

   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(MaxSlippage);
   trade.SetTypeFilling(ORDER_FILLING_IOC);

   //--- SMA handle
   handleSMA = iMA(_Symbol, SMA_Timeframe, SMA_Period, 0, MODE_SMA, SMA_AppliedPrice);
   if(handleSMA == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create SMA handle");
      return INIT_FAILED;
   }

   //--- ATR handles for grid (skip in tester if InpSkipATRInTester)
   if(g_isTesterMode && InpSkipATRInTester)
   {
      handleATR_Loss = INVALID_HANDLE;
      handleATR_Profit = INVALID_HANDLE;
      Print("ATR indicator handles SKIPPED - using Simplified ATR for backtest speed");
   }
   else
   {
      handleATR_Loss = iATR(_Symbol, GridLoss_ATR_TF, GridLoss_ATR_Period);
      if(handleATR_Loss == INVALID_HANDLE)
      {
         Print("ERROR: Failed to create ATR Loss handle");
         return INIT_FAILED;
      }

      handleATR_Profit = iATR(_Symbol, GridProfit_ATR_TF, GridProfit_ATR_Period);
      if(handleATR_Profit == INVALID_HANDLE)
      {
         Print("ERROR: Failed to create ATR Profit handle");
         return INIT_FAILED;
      }
   }

   //--- Init arrays
   ArraySetAsSeries(bufSMA, true);
   ArraySetAsSeries(bufATR_Loss, true);
   ArraySetAsSeries(bufATR_Profit, true);

   //--- Init globals
   lastBarTime = 0;
   lastInitialCandleTime = 0;
   lastGridLossCandleTime = 0;
   lastGridProfitCandleTime = 0;
   justClosedBuy = false;
   justClosedSell = false;
   g_trailingSL_Buy = 0;
   g_trailingSL_Sell = 0;
   g_trailingActive_Buy = false;
   g_trailingActive_Sell = false;
   g_breakevenDone_Buy = false;
   g_breakevenDone_Sell = false;
   g_eaStopped = false;
   g_accumulatedProfit = 0;
   g_initialBuyPrice = 0;
   g_initialSellPrice = 0;
   g_accumulateBaseline = 0;
   g_maxDD = 0;
   g_hadPositions = (TotalOrderCount() > 0);  // detect if positions already exist on init

   //--- Calculate baseline for accumulate (FRESH START: only new deals count)
   if(UseAccumulateClose)
   {
      double totalHistory = CalcTotalHistoryProfit();
      g_accumulateBaseline = totalHistory;  // start fresh each EA load
      g_accumulatedProfit = 0;              // nothing accumulated yet
      Print("Accumulate init: baseline=", g_accumulateBaseline, " accumulated=0 (fresh start)");
   }

   //--- Recover initial prices from existing positions
   RecoverInitialPrices();

   // === ZigZag MTF Init (v3.0) ===
   if(EntryMode == ENTRY_ZIGZAG)
   {
      InitZigZagHandles();
      RecoverTFInitialPrices();
   }

   // === Squeeze Filter Init ===
   if(InpUseSqueezeFilter)
   {
      ENUM_TIMEFRAMES sqTFs[3];
      sqTFs[0] = InpSqueeze_TF1;
      sqTFs[1] = InpSqueeze_TF2;
      sqTFs[2] = InpSqueeze_TF3;
      string sqLabels[3];
      sqLabels[0] = TimeframeToString(InpSqueeze_TF1);
      sqLabels[1] = TimeframeToString(InpSqueeze_TF2);
      sqLabels[2] = TimeframeToString(InpSqueeze_TF3);

      for(int sq = 0; sq < 3; sq++)
      {
         g_squeeze[sq].tf = sqTFs[sq];
         g_squeeze[sq].tfLabel = sqLabels[sq];
         g_squeeze[sq].state = 0;
         g_squeeze[sq].intensity = 1.0;

         g_squeeze[sq].handleBB = iBands(_Symbol, sqTFs[sq], InpSqueeze_BB_Period, 0, InpSqueeze_BB_Mult, PRICE_CLOSE);
         g_squeeze[sq].handleEMA = iMA(_Symbol, sqTFs[sq], InpSqueeze_KC_Period, 0, MODE_EMA, PRICE_CLOSE);
         g_squeeze[sq].handleATR = iATR(_Symbol, sqTFs[sq], InpSqueeze_ATR_Period);

         if(g_squeeze[sq].handleBB == INVALID_HANDLE ||
            g_squeeze[sq].handleEMA == INVALID_HANDLE ||
            g_squeeze[sq].handleATR == INVALID_HANDLE)
         {
            Print("WARNING: Squeeze Filter handle creation failed for TF ", sqLabels[sq]);
         }
      }
      Print("Squeeze Filter initialized: ", sqLabels[0], " / ", sqLabels[1], " / ", sqLabels[2]);
   }

   // === Counter-Trend Hedging Init ===
   for(int h = 0; h < MAX_HEDGE_SETS; h++)
   {
      g_hedgeSets[h].active = false;
      g_hedgeSets[h].hedgeTicket = 0;
      g_hedgeSets[h].hedgeLots = 0;
      g_hedgeSets[h].originalTotalLots = 0;
      g_hedgeSets[h].gridMode = false;
      g_hedgeSets[h].gridLevel = 0;
      g_hedgeSets[h].gridTicketCount = 0;
      ArrayResize(g_hedgeSets[h].gridTickets, 0);
      g_hedgeSets[h].commentPrefix = "GM_HEDGE_" + IntegerToString(h + 1);
      g_hedgeSets[h].boundTicketCount = 0;
      ArrayResize(g_hedgeSets[h].boundTickets, 0);
   }
   g_hedgeSetCount = 0;

   Print("Gold Miner EA v5.1 initialized successfully");

   // === News Filter Init ===
   if(InpEnableNewsFilter)
   {
      g_isNewsPaused = false;
      g_newsStatus = "";
      g_webRequestConfigured = true;
      g_forceNewsRefresh = true;
      LoadNewsCacheFromFile();
      CheckWebRequestConfiguration();
      RefreshNewsData();
   }

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                    |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(handleSMA != INVALID_HANDLE) IndicatorRelease(handleSMA);
   if(handleATR_Loss != INVALID_HANDLE) IndicatorRelease(handleATR_Loss);
   if(handleATR_Profit != INVALID_HANDLE) IndicatorRelease(handleATR_Profit);

   // Release ZigZag indicator handles
   for(int zz = 0; zz < g_activeTFCount; zz++)
   {
      if(g_tfStates[zz].handleZZ != INVALID_HANDLE)
         IndicatorRelease(g_tfStates[zz].handleZZ);
   }

   // Release Squeeze Filter handles
   for(int sq = 0; sq < 3; sq++)
   {
      if(g_squeeze[sq].handleBB != INVALID_HANDLE) IndicatorRelease(g_squeeze[sq].handleBB);
      if(g_squeeze[sq].handleEMA != INVALID_HANDLE) IndicatorRelease(g_squeeze[sq].handleEMA);
      if(g_squeeze[sq].handleATR != INVALID_HANDLE) IndicatorRelease(g_squeeze[sq].handleATR);
   }

   ObjectDelete(0, "GM_AvgBuyLine");
   ObjectDelete(0, "GM_AvgSellLine");
   ObjectDelete(0, "GM_TPBuyLine");
   ObjectDelete(0, "GM_TPSellLine");
   ObjectDelete(0, "GM_SLLine");
   ObjectsDeleteAll(0, "GM_Dash_");
   ObjectsDeleteAll(0, "GM_TBL_");
   ObjectsDeleteAll(0, "GM_Btn");

   ObjectsDeleteAll(0, "GM_HED_");  // hedge dashboard objects

   Print("Gold Miner EA v5.1 deinitialized");
}

//+------------------------------------------------------------------+
//| Recover initial order prices from open positions                   |
//+------------------------------------------------------------------+
void RecoverInitialPrices()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      string comment = PositionGetString(POSITION_COMMENT);
      if(StringFind(comment, "GM_INIT") >= 0)
      {
         long posType = PositionGetInteger(POSITION_TYPE);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         if(posType == POSITION_TYPE_BUY)
            g_initialBuyPrice = openPrice;
         else if(posType == POSITION_TYPE_SELL)
            g_initialSellPrice = openPrice;
      }
   }
}

//+------------------------------------------------------------------+
//| CalcTotalHistoryProfit - sum all closed deal profit for this EA    |
//+------------------------------------------------------------------+
double CalcTotalHistoryProfit()
{
   double total = 0;
   if(!HistorySelect(0, TimeCurrent())) return 0;
   int totalDeals = HistoryDealsTotal();
   for(int i = 0; i < totalDeals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;
      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != MagicNumber) continue;
      if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) continue;
      long dealEntry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_INOUT)
      {
         total += HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                + HistoryDealGetDouble(dealTicket, DEAL_SWAP);
      }
   }
   return total;
}

//+------------------------------------------------------------------+
//| CalcTotalClosedLots - sum all closed deal volumes for this EA      |
//+------------------------------------------------------------------+
double CalcTotalClosedLots()
{
   double total = 0;
   if(!HistorySelect(0, TimeCurrent())) return 0;
   int totalDeals = HistoryDealsTotal();
   for(int i = 0; i < totalDeals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;
      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != MagicNumber) continue;
      if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) continue;
      long dealEntry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_INOUT)
         total += HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
   }
   return total;
}

//+------------------------------------------------------------------+
//| CalcDailyClosedLots - sum closed deal volumes for today             |
//+------------------------------------------------------------------+
double CalcDailyClosedLots()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   datetime dayStart = StructToTime(dt);

   double total = 0;
   if(!HistorySelect(dayStart, TimeCurrent())) return 0;
   int totalDeals = HistoryDealsTotal();
   for(int i = 0; i < totalDeals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;
      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != MagicNumber) continue;
      if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) continue;
      long dealEntry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_INOUT)
         total += HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
   }
   return total;
}

//+------------------------------------------------------------------+
//| CalcTotalClosedOrders - count closed deals for this EA             |
//+------------------------------------------------------------------+
int CalcTotalClosedOrders()
{
   int count = 0;
   if(!HistorySelect(0, TimeCurrent())) return 0;
   int totalDeals = HistoryDealsTotal();
   for(int i = 0; i < totalDeals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;
      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != MagicNumber) continue;
      if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) continue;
      long dealEntry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_INOUT)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| CalcMonthlyPL - sum profit for deals closed this calendar month    |
//+------------------------------------------------------------------+
double CalcMonthlyPL()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.day = 1;
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   datetime monthStart = StructToTime(dt);

   double total = 0;
   if(!HistorySelect(monthStart, TimeCurrent())) return 0;
   int totalDeals = HistoryDealsTotal();
   for(int i = 0; i < totalDeals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;
      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != MagicNumber) continue;
      if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) continue;
      long dealEntry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_INOUT)
         total += HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                + HistoryDealGetDouble(dealTicket, DEAL_SWAP);
   }
   return total;
}

//+------------------------------------------------------------------+
//| CalcDailyPL - sum profit for deals closed today                    |
//+------------------------------------------------------------------+
double CalcDailyPL()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   datetime dayStart = StructToTime(dt);

   double total = 0;
   if(!HistorySelect(dayStart, TimeCurrent())) return 0;
   int totalDeals = HistoryDealsTotal();
   for(int i = 0; i < totalDeals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;
      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != MagicNumber) continue;
      if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) continue;
      long dealEntry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_INOUT)
         total += HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                + HistoryDealGetDouble(dealTicket, DEAL_SWAP);
   }
   return total;
}

void OnTick()
{
   // === HIDE ATR CHART IN BACKTEST (v2.9 / v3.0 simplified) ===
   // When InpSkipATRInTester=true, no ATR handles exist so no subwindow is created.
   // Fallback: if handles exist (InpSkipATRInTester=false), try to hide subwindow.
   if(!g_atrChartHidden && (MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE)))
   {
      if(g_isTesterMode && InpSkipATRInTester)
      {
         g_atrChartHidden = true; // No ATR handle = no subwindow
      }
      else
      {
         g_atrHideAttempts++;
         int totalWindows = (int)ChartGetInteger(0, CHART_WINDOWS_TOTAL);
         bool found = false;
         for(int sw = totalWindows - 1; sw > 0; sw--)
         {
            int indCount = ChartIndicatorsTotal(0, sw);
            for(int j = indCount - 1; j >= 0; j--)
            {
               string indName = ChartIndicatorName(0, sw, j);
               if(StringFind(indName, "ATR") >= 0)
               {
                  ChartIndicatorDelete(0, sw, indName);
                  found = true;
               }
            }
         }
         if(found || g_atrHideAttempts >= 50)
         {
            g_atrChartHidden = true;
            ChartRedraw(0);
         }
      }
   }

   // === LICENSE CHECK ===
   if(!g_isTesterMode)
   {
      if(!OnTickLicense())
      {
         return;
      }
   }
   if(!g_isLicenseValid && !g_isTesterMode) return;

   // === NEWS FILTER - Refresh hourly ===
   RefreshNewsData();

   // === Determine if new orders are blocked (News/Time/Pause) ===
   g_newOrderBlocked = false;

   // Manual Pause check (v2.9)
   if(g_eaIsPaused)
      g_newOrderBlocked = true;

   if(IsNewsTimePaused())
      g_newOrderBlocked = true;

   if(InpUseTimeFilter && !IsWithinTradingHours())
      g_newOrderBlocked = true;

   // === DAILY PROFIT PAUSE CHECK ===
   if(InpEnableDailyProfitPause)
   {
      MqlDateTime dtNow;
      TimeToStruct(TimeCurrent(), dtNow);
      dtNow.hour = 0; dtNow.min = 0; dtNow.sec = 0;
      datetime today = StructToTime(dtNow);

      // Reset pause flag when new day starts
      if(g_dailyProfitPauseDay != today)
      {
         g_dailyProfitPaused = false;
         g_dailyProfitPauseDay = today;
      }

      // Check if daily target reached
      if(!g_dailyProfitPaused)
      {
         double dailyPL = CalcDailyPL();
         if(dailyPL >= InpDailyProfitTarget)
         {
            g_dailyProfitPaused = true;
            Print("DAILY PROFIT PAUSE: Target $", DoubleToString(InpDailyProfitTarget, 2),
                  " reached (PL=$", DoubleToString(dailyPL, 2), "). No new orders until tomorrow.");
         }
      }

      if(g_dailyProfitPaused)
         g_newOrderBlocked = true;
   }

   // === SQUEEZE FILTER CHECK ===
   g_squeezeBlocked = false;
   g_squeezeBuyBlocked = false;
   g_squeezeSellBlocked = false;
   if(InpUseSqueezeFilter)
   {
      UpdateSqueezeState();
      if(InpSqueeze_BlockOnExpansion)
      {
         int expCount = 0;
         int bestDir = 0;          // direction of highest-TF expansion
         for(int sq = 2; sq >= 0; sq--)  // scan from highest TF first
         {
            if(g_squeeze[sq].state == 2)
            {
               expCount++;
               if(bestDir == 0) bestDir = g_squeeze[sq].direction;  // use highest TF direction
            }
         }
         if(expCount >= InpSqueeze_MinTFExpansion)
         {
            if(InpSqueeze_DirectionalBlock && bestDir != 0)
            {
               // Directional: block counter-trend only
               if(bestDir == 1)  // Bullish expansion → block SELL
                  g_squeezeSellBlocked = true;
               else              // Bearish expansion → block BUY
                  g_squeezeBuyBlocked = true;
               // Do NOT set g_newOrderBlocked → trend-following side can still open
            }
            else
            {
               // Original behavior: block everything
               g_squeezeBlocked = true;
               g_newOrderBlocked = true;
            }
         }
      }
   }

   // === COUNTER-TREND HEDGING CHECK ===
   if(InpHedge_Enable && InpUseSqueezeFilter)
   {
      CheckAndOpenHedge();
      ManageHedgeSets();
   }

   // === ORIGINAL TRADING LOGIC (unchanged) ===
   if(g_eaStopped) return;

   //--- Every tick: Per-Order Trailing (works for both modes - individual positions)
   if(EnablePerOrderTrailing)
   {
      ManagePerOrderTrailing();
   }
   else if(EnableTrailingStop || EnableBreakeven)
   {
      if(EntryMode == ENTRY_SMA || EntryMode == ENTRY_INSTANT)
         ManageTrailingStop();
      // ZigZag mode: per-TF trailing handled in OnTickZigZagMTF()
   }

   //--- Every tick: TP/SL management
   if(EntryMode == ENTRY_SMA || EntryMode == ENTRY_INSTANT)
      ManageTPSL();
   // ZigZag mode: per-TF TP/SL + shared accumulate handled in OnTickZigZagMTF()

   //--- Every tick: Matching Close (pair profit vs loss orders)
   if(UseMatchingClose)
      ManageMatchingClose();

   //--- Every tick: Drawdown check
   CheckDrawdownExit();

   //--- Track max drawdown
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(balance > 0)
   {
      double dd = (balance - equity) / balance * 100.0;
      if(dd > g_maxDD) g_maxDD = dd;
   }

   // ============================================================
   // SMA MODE - Original Entry Logic (unchanged when ENTRY_SMA)
   // ============================================================
   if(EntryMode == ENTRY_SMA)
   {
      //--- New bar logic
      datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
      bool isNewBar = (currentBarTime != lastBarTime);

      if(isNewBar)
      {
         lastBarTime = currentBarTime;

          //--- Copy indicator buffers
          if(CopyBuffer(handleSMA, 0, 0, 3, bufSMA) < 3) return;
          if(handleATR_Loss != INVALID_HANDLE)
          {
             if(CopyBuffer(handleATR_Loss, 0, 0, 3, bufATR_Loss) < 3) return;
          }
          if(handleATR_Profit != INVALID_HANDLE)
          {
             if(CopyBuffer(handleATR_Profit, 0, 0, 3, bufATR_Profit) < 3) return;
          }

         double smaValue = bufSMA[0];
         double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

         int buyCount = 0, sellCount = 0;
         int gridLossBuy = 0, gridLossSell = 0;
         int gridProfitBuy = 0, gridProfitSell = 0;
         bool hasInitialBuy = false, hasInitialSell = false;
         CountPositions(buyCount, sellCount, gridLossBuy, gridLossSell, gridProfitBuy, gridProfitSell, hasInitialBuy, hasInitialSell);

         int totalPositions = buyCount + sellCount;

         //--- Auto-detect broker-closed positions (e.g. trailing SL hit by broker)
         if(buyCount == 0 && g_initialBuyPrice != 0)
         {
            Print("BUY cycle ended (broker SL). Resetting g_initialBuyPrice.");
            g_initialBuyPrice = 0;
         }
         if(sellCount == 0 && g_initialSellPrice != 0)
         {
            Print("SELL cycle ended (broker SL). Resetting g_initialSellPrice.");
            g_initialSellPrice = 0;
         }

         //--- Grid Loss management (check both sides independently) - blocked by News/Time/Squeeze filter
         if(!g_newOrderBlocked)
         {
            if(!g_squeezeBuyBlocked && (hasInitialBuy || g_initialBuyPrice > 0) && gridLossBuy < GridLoss_MaxTrades && buyCount > 0)
            {
               CheckGridLoss(POSITION_TYPE_BUY, gridLossBuy);
            }
            if(!g_squeezeSellBlocked && (hasInitialSell || g_initialSellPrice > 0) && gridLossSell < GridLoss_MaxTrades && sellCount > 0)
            {
               CheckGridLoss(POSITION_TYPE_SELL, gridLossSell);
            }
         }

         //--- Grid Profit management - blocked by News/Time/Squeeze filter
         if(!g_newOrderBlocked && GridProfit_Enable)
         {
            if(!g_squeezeBuyBlocked && (hasInitialBuy || g_initialBuyPrice > 0) && gridProfitBuy < GridProfit_MaxTrades && buyCount > 0)
            {
               CheckGridProfit(POSITION_TYPE_BUY, gridProfitBuy);
            }
            if(!g_squeezeSellBlocked && (hasInitialSell || g_initialSellPrice > 0) && gridProfitSell < GridProfit_MaxTrades && sellCount > 0)
            {
               CheckGridProfit(POSITION_TYPE_SELL, gridProfitSell);
            }
         }

         //--- Entry logic: Independent Side Entry - blocked by News/Time filter
         if(!g_newOrderBlocked)
         {
            bool canOpenMore = TotalOrderCount() < MaxOpenOrders;
            bool canOpenOnThisCandle = !(DontOpenSameCandle && currentBarTime == lastInitialCandleTime);

            //--- BUY side shouldEnter logic (v2.9 robust fix)
            bool shouldEnterBuy = false;
            if(buyCount == 0)
            {
               if(justClosedBuy && !EnableAutoReEntry)
                  shouldEnterBuy = false;  // 1-bar cooldown only
               else
                  shouldEnterBuy = true;   // Ready to enter (auto re-entry or normal)
            }

            //--- SELL side shouldEnter logic (v2.9 robust fix)
            bool shouldEnterSell = false;
            if(sellCount == 0)
            {
               if(justClosedSell && !EnableAutoReEntry)
                  shouldEnterSell = false;  // 1-bar cooldown only
               else
                  shouldEnterSell = true;   // Ready to enter (auto re-entry or normal)
            }

             // ===== BUY Entry (independent) =====
             if(!g_squeezeBuyBlocked && buyCount == 0 && g_initialBuyPrice == 0 && canOpenMore && canOpenOnThisCandle)
             {
                if(currentPrice > smaValue && (TradingMode == TRADE_BUY_ONLY || TradingMode == TRADE_BOTH))
                {
                   if(shouldEnterBuy)
                   {
                      if(OpenOrder(ORDER_TYPE_BUY, InitialLotSize, "GM_INIT"))
                      {
                         g_initialBuyPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                         lastInitialCandleTime = currentBarTime;
                         ResetTrailingState();
                      }
                   }
                }
                else if(shouldEnterBuy)
                {
                   Print("BUY ENTRY SKIP: SMA signal not match (Price=", currentPrice, " SMA=", smaValue, ")");
                }
             }

             // ===== SELL Entry (independent) =====
             if(!g_squeezeSellBlocked && sellCount == 0 && g_initialSellPrice == 0 && canOpenMore && canOpenOnThisCandle)
             {
                if(currentPrice < smaValue && (TradingMode == TRADE_SELL_ONLY || TradingMode == TRADE_BOTH))
                {
                   if(shouldEnterSell)
                   {
                      if(OpenOrder(ORDER_TYPE_SELL, InitialLotSize, "GM_INIT"))
                      {
                         g_initialSellPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                         lastInitialCandleTime = currentBarTime;
                         ResetTrailingState();
                      }
                   }
                }
                else if(shouldEnterSell)
                {
                   Print("SELL ENTRY SKIP: SMA signal not match (Price=", currentPrice, " SMA=", smaValue, ")");
                }
             }
         }

         // Reset justClosed flags ONLY after entry logic has had a chance to use them
         if(!g_newOrderBlocked)
         {
            justClosedBuy = false;
            justClosedSell = false;
         }
      }
   } // end EntryMode == ENTRY_SMA

   // ============================================================
   // ZIGZAG MTF MODE - Multi-Timeframe Entry System (v3.0)
   // ============================================================
   if(EntryMode == ENTRY_ZIGZAG)
   {
      OnTickZigZagMTF();
   }

   // ============================================================
   // INSTANT MODE - No Indicator, Open Both Sides Immediately
   // ============================================================
   if(EntryMode == ENTRY_INSTANT)
   {
      datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
      bool isNewBar = (currentBarTime != lastBarTime);
      
      if(isNewBar)
      {
         lastBarTime = currentBarTime;
      }
      
      int buyCount = 0, sellCount = 0;
      int gridLossBuy = 0, gridLossSell = 0;
      int gridProfitBuy = 0, gridProfitSell = 0;
      bool hasInitialBuy = false, hasInitialSell = false;
      CountPositions(buyCount, sellCount, gridLossBuy, gridLossSell, 
                     gridProfitBuy, gridProfitSell, hasInitialBuy, hasInitialSell);

      // Auto-detect broker-closed positions
      if(buyCount == 0 && g_initialBuyPrice != 0) { g_initialBuyPrice = 0; }
      if(sellCount == 0 && g_initialSellPrice != 0) { g_initialSellPrice = 0; }

      // Grid Loss management
      if(!g_newOrderBlocked)
      {
         if(!g_squeezeBuyBlocked && (hasInitialBuy || g_initialBuyPrice > 0) && gridLossBuy < GridLoss_MaxTrades && buyCount > 0)
            CheckGridLoss(POSITION_TYPE_BUY, gridLossBuy);
         if(!g_squeezeSellBlocked && (hasInitialSell || g_initialSellPrice > 0) && gridLossSell < GridLoss_MaxTrades && sellCount > 0)
            CheckGridLoss(POSITION_TYPE_SELL, gridLossSell);
      }

      // Grid Profit management
      if(!g_newOrderBlocked && GridProfit_Enable)
      {
         if(!g_squeezeBuyBlocked && (hasInitialBuy || g_initialBuyPrice > 0) && gridProfitBuy < GridProfit_MaxTrades && buyCount > 0)
            CheckGridProfit(POSITION_TYPE_BUY, gridProfitBuy);
         if(!g_squeezeSellBlocked && (hasInitialSell || g_initialSellPrice > 0) && gridProfitSell < GridProfit_MaxTrades && sellCount > 0)
            CheckGridProfit(POSITION_TYPE_SELL, gridProfitSell);
      }

      // Entry logic
      if(!g_eaStopped && !g_newOrderBlocked)
      {
         bool canOpenOnThisCandle = !(DontOpenSameCandle && currentBarTime == lastInitialCandleTime);
         bool canOpenMore = TotalOrderCount() < MaxOpenOrders;

         // ===== BUY Entry (instant) =====
         if(!g_squeezeBuyBlocked && buyCount == 0 && g_initialBuyPrice == 0 && canOpenMore && canOpenOnThisCandle)
         {
            if(TradingMode == TRADE_BUY_ONLY || TradingMode == TRADE_BOTH)
            {
               if(OpenOrder(ORDER_TYPE_BUY, InitialLotSize, "GM_INIT"))
               {
                  g_initialBuyPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                  lastInitialCandleTime = currentBarTime;
                  ResetTrailingState();
               }
            }
         }

         // ===== SELL Entry (instant) =====
         if(!g_squeezeSellBlocked && sellCount == 0 && g_initialSellPrice == 0 && canOpenMore && canOpenOnThisCandle)
         {
            if(TradingMode == TRADE_SELL_ONLY || TradingMode == TRADE_BOTH)
            {
               if(OpenOrder(ORDER_TYPE_SELL, InitialLotSize, "GM_INIT"))
               {
                  g_initialSellPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                  lastInitialCandleTime = currentBarTime;
                  ResetTrailingState();
               }
            }
         }
      }

      // Reset justClosed flags
      if(!g_newOrderBlocked)
      {
         justClosedBuy = false;
         justClosedSell = false;
      }
   }

   DrawLines();
   if(ShowDashboard) DisplayDashboard();
}

//+------------------------------------------------------------------+
//| Count positions by type and grid level                             |
//+------------------------------------------------------------------+
void CountPositions(int &buyCount, int &sellCount,
                    int &gridLossBuy, int &gridLossSell,
                    int &gridProfitBuy, int &gridProfitSell,
                    bool &hasInitialBuy, bool &hasInitialSell)
{
   buyCount = 0; sellCount = 0;
   gridLossBuy = 0; gridLossSell = 0;
   gridProfitBuy = 0; gridProfitSell = 0;
   hasInitialBuy = false; hasInitialSell = false;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      string comment = PositionGetString(POSITION_COMMENT);
      
      // Skip hedge orders — they are managed by the Hedge system separately
      if(IsHedgeComment(comment)) continue;
      
      long posType = PositionGetInteger(POSITION_TYPE);

      if(posType == POSITION_TYPE_BUY)
      {
         buyCount++;
         if(StringFind(comment, "GM_INIT") >= 0) hasInitialBuy = true;
         if(StringFind(comment, "GM_GL") >= 0) gridLossBuy++;
         if(StringFind(comment, "GM_GP") >= 0) gridProfitBuy++;
      }
      else if(posType == POSITION_TYPE_SELL)
      {
         sellCount++;
         if(StringFind(comment, "GM_INIT") >= 0) hasInitialSell = true;
         if(StringFind(comment, "GM_GL") >= 0) gridLossSell++;
         if(StringFind(comment, "GM_GP") >= 0) gridProfitSell++;
      }
   }
}

//+------------------------------------------------------------------+
//| Total order count for this EA                                      |
//+------------------------------------------------------------------+
int TotalOrderCount()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Open order                                                         |
//+------------------------------------------------------------------+
bool OpenOrder(ENUM_ORDER_TYPE orderType, double lots, string comment)
{
   double price = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   //--- Normalize lot
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    // Don't apply user MaxLotSize cap for hedge orders — hedge must match exact counter-side volume
    if(InpMaxLotSize > 0 && !IsHedgeComment(comment)) maxLot = MathMin(maxLot, InpMaxLotSize);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lots = MathMax(minLot, MathMin(maxLot, NormalizeDouble(MathRound(lots / lotStep) * lotStep, 2)));

   if(orderType == ORDER_TYPE_BUY)
   {
      if(!trade.Buy(lots, _Symbol, price, 0, 0, comment))
      {
         Print("ERROR: Buy failed - ", trade.ResultRetcodeDescription());
         return false;
      }
   }
   else
   {
      if(!trade.Sell(lots, _Symbol, price, 0, 0, comment))
      {
         Print("ERROR: Sell failed - ", trade.ResultRetcodeDescription());
         return false;
      }
   }

   Print("Order opened: ", comment, " Lots=", lots, " Price=", price);
   return true;
}

//+------------------------------------------------------------------+
//| Calculate Weighted Average Price for one side                      |
//+------------------------------------------------------------------+
double CalculateAveragePrice(ENUM_POSITION_TYPE side)
{
   double totalLots = 0;
   double totalWeighted = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) != side) continue;
      
      // Skip hedge orders — basket TP/SL must not include hedge positions
      if(IsHedgeComment(PositionGetString(POSITION_COMMENT))) continue;

      double vol = PositionGetDouble(POSITION_VOLUME);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      totalLots += vol;
      totalWeighted += openPrice * vol;
   }

   if(totalLots > 0)
      return totalWeighted / totalLots;
   return 0;
}

//+------------------------------------------------------------------+
//| Calculate total floating P/L for one side                          |
//+------------------------------------------------------------------+
double CalculateFloatingPL(ENUM_POSITION_TYPE side)
{
   double totalPL = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) != side) continue;
      
      // Skip hedge orders — floating PL calculation must exclude hedge positions
      if(IsHedgeComment(PositionGetString(POSITION_COMMENT))) continue;

      totalPL += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return totalPL;
}

//+------------------------------------------------------------------+
//| Calculate total floating P/L for ALL positions                     |
//+------------------------------------------------------------------+
double CalculateTotalFloatingPL()
{
   double totalPL = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      totalPL += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return totalPL;
}

//+------------------------------------------------------------------+
//| Calculate total lots for one side                                  |
//+------------------------------------------------------------------+
double CalculateTotalLots(ENUM_POSITION_TYPE side)
{
   double totalLots = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) != side) continue;
      totalLots += PositionGetDouble(POSITION_VOLUME);
   }
   return totalLots;
}

//+------------------------------------------------------------------+
//| Close all positions for one side                                   |
//+------------------------------------------------------------------+
void CloseAllSide(ENUM_POSITION_TYPE side)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) != side) continue;
      
      // Skip hedge orders — let the Hedge system manage their lifecycle
      if(IsHedgeComment(PositionGetString(POSITION_COMMENT))) continue;
      
      trade.PositionClose(ticket);
   }
   // Set per-side close flag
   if(side == POSITION_TYPE_BUY)
      justClosedBuy = true;
   else
      justClosedSell = true;
}

//+------------------------------------------------------------------+
//| Close ALL positions                                                |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   bool hadBuy = false, hadSell = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) hadBuy = true;
      else hadSell = true;
      trade.PositionClose(ticket);
   }
   if(hadBuy) { justClosedBuy = true; g_initialBuyPrice = 0; }
   if(hadSell) { justClosedSell = true; g_initialSellPrice = 0; }
   ResetTrailingState();

   // Reset all hedge sets when closing everything
   for(int h = 0; h < MAX_HEDGE_SETS; h++)
   {
      g_hedgeSets[h].active = false;
      g_hedgeSets[h].hedgeTicket = 0;
      g_hedgeSets[h].hedgeLots = 0;
      g_hedgeSets[h].gridMode = false;
      g_hedgeSets[h].gridLevel = 0;
      g_hedgeSets[h].gridTicketCount = 0;
      ArrayResize(g_hedgeSets[h].gridTickets, 0);
      g_hedgeSets[h].boundTicketCount = 0;
      ArrayResize(g_hedgeSets[h].boundTickets, 0);
   }
   g_hedgeSetCount = 0;
}

//+------------------------------------------------------------------+
//| Manage TP/SL (Basket)                                              |
//+------------------------------------------------------------------+
void ManageTPSL()
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);

   //--- BUY side
   double avgBuy = CalculateAveragePrice(POSITION_TYPE_BUY);
   if(avgBuy > 0)
   {
      double plBuy = CalculateFloatingPL(POSITION_TYPE_BUY);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      bool closeTP = false;
      bool closeSL = false;

      //--- TP checks (skip basket TP when per-order trailing is active)
      if(!EnablePerOrderTrailing)
      {
         if(UseTP_Dollar && plBuy >= TP_DollarAmount) closeTP = true;
         if(UseTP_Points && bid >= avgBuy + TP_Points * point) closeTP = true;
         if(UseTP_PercentBalance && plBuy >= balance * TP_PercentBalance / 100.0) closeTP = true;
      }

      if(closeTP)
      {
         Print("TP HIT (BUY): PL=", plBuy);
         CloseAllSide(POSITION_TYPE_BUY);
         justClosedBuy = true;
         g_initialBuyPrice = 0;
         ResetTrailingState();
         // No manual accumulate increment - baseline handles it
         return;
      }

      //--- SL checks (ONLY when NOT using Per-Order Trailing - per-order trailing handles individual SL via broker)
      if(EnableSL && !EnablePerOrderTrailing)
      {
         if(UseSL_Dollar && plBuy <= -SL_DollarAmount)
         {
            Print("SL_BASKET_DOLLAR HIT (BUY): PL=", plBuy, " Limit=", -SL_DollarAmount);
            closeSL = true;
         }
         if(UseSL_Points && bid <= avgBuy - SL_Points * point)
         {
            Print("SL_BASKET_POINTS HIT (BUY): BID=", bid, " Limit=", avgBuy - SL_Points * point);
            closeSL = true;
         }
         if(UseSL_PercentBalance && plBuy <= -(balance * SL_PercentBalance / 100.0))
         {
            Print("SL_BASKET_PCT HIT (BUY): PL=", plBuy, " Limit=", -(balance * SL_PercentBalance / 100.0));
            closeSL = true;
         }

         if(closeSL)
         {
            if(SL_ActionMode == SL_CLOSE_ALL_STOP)
            {
               CloseAllPositions();
               g_eaStopped = true;
               Print("EA STOPPED by SL Action (BUY)");
            }
            else
            {
               CloseAllSide(POSITION_TYPE_BUY);
               justClosedBuy = true;
               g_initialBuyPrice = 0;
               ResetTrailingState();
            }
            return;
         }
      }
   }

   //--- SELL side
   double avgSell = CalculateAveragePrice(POSITION_TYPE_SELL);
   if(avgSell > 0)
   {
      double plSell = CalculateFloatingPL(POSITION_TYPE_SELL);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      bool closeTP2 = false;
      bool closeSL2 = false;

      //--- TP checks (skip basket TP when per-order trailing is active)
      if(!EnablePerOrderTrailing)
      {
         if(UseTP_Dollar && plSell >= TP_DollarAmount) closeTP2 = true;
         if(UseTP_Points && ask <= avgSell - TP_Points * point) closeTP2 = true;
         if(UseTP_PercentBalance && plSell >= balance * TP_PercentBalance / 100.0) closeTP2 = true;
      }

      if(closeTP2)
      {
         Print("TP HIT (SELL): PL=", plSell);
         CloseAllSide(POSITION_TYPE_SELL);
         justClosedSell = true;
         g_initialSellPrice = 0;
         ResetTrailingState();
         // No manual accumulate increment - baseline handles it
         return;
      }

      //--- SL checks (ONLY when NOT using Per-Order Trailing - per-order trailing handles individual SL via broker)
      if(EnableSL && !EnablePerOrderTrailing)
      {
         if(UseSL_Dollar && plSell <= -SL_DollarAmount)
         {
            Print("SL_BASKET_DOLLAR HIT (SELL): PL=", plSell, " Limit=", -SL_DollarAmount);
            closeSL2 = true;
         }
         if(UseSL_Points && ask >= avgSell + SL_Points * point)
         {
            Print("SL_BASKET_POINTS HIT (SELL): ASK=", ask, " Limit=", avgSell + SL_Points * point);
            closeSL2 = true;
         }
         if(UseSL_PercentBalance && plSell <= -(balance * SL_PercentBalance / 100.0))
         {
            Print("SL_BASKET_PCT HIT (SELL): PL=", plSell, " Limit=", -(balance * SL_PercentBalance / 100.0));
            closeSL2 = true;
         }

         if(closeSL2)
         {
            if(SL_ActionMode == SL_CLOSE_ALL_STOP)
            {
               CloseAllPositions();
               g_eaStopped = true;
               Print("EA STOPPED by SL Action (SELL)");
            }
            else
            {
               CloseAllSide(POSITION_TYPE_SELL);
               justClosedSell = true;
               g_initialSellPrice = 0;
               ResetTrailingState();
            }
            return;
         }
      }
   }

   //--- Accumulate Close (baseline method) - recalculate every tick from deal history
   if(UseAccumulateClose)
   {
      //--- Auto-reset baseline when all positions are closed (cycle ended)
      int currentCount = TotalOrderCount();
      if(g_hadPositions && currentCount == 0)
      {
         g_accumulateBaseline = CalcTotalHistoryProfit();
         g_accumulatedProfit = 0;
         g_hadPositions = false;
         Print("Accumulate auto-reset: no positions left. New baseline: ", g_accumulateBaseline);
         return;
      }
      if(currentCount > 0) g_hadPositions = true;

      double totalHistory = CalcTotalHistoryProfit();
      g_accumulatedProfit = totalHistory - g_accumulateBaseline;

      double totalFloating = CalculateTotalFloatingPL();
      double accumTotal = g_accumulatedProfit + totalFloating;

      if(accumTotal >= AccumulateTarget && accumTotal > 0)  // trigger on total (closed + floating)
      {
         Print("ACCUMULATE TARGET HIT: ", accumTotal, " / ", AccumulateTarget);
         CloseAllPositions();
         // Recalc after closing to include just-closed profit
         Sleep(500);
         double newHistory = CalcTotalHistoryProfit();
         g_accumulateBaseline = newHistory;
         g_accumulatedProfit = 0;
         g_hadPositions = false;
         Print("Accumulate cycle reset. New baseline: ", newHistory);
      }
   }
}

//+------------------------------------------------------------------+
//| Manage Per-Order Trailing Stop (Standard Breakeven + Trailing)      |
//| Step 1: Breakeven - lock in small profit when target reached        |
//| Step 2: Trailing - SL follows price at fixed distance with step     |
//| SL never moves backwards. Broker closes order when SL is hit.       |
//+------------------------------------------------------------------+
void ManagePerOrderTrailing()
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   int stopLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(stopLevel < 1) stopLevel = 1;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      long posType = PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);

      if(posType == POSITION_TYPE_BUY)
      {
         double profitPoints = (bid - openPrice) / point;

         // ===== STEP 1: Breakeven =====
         if(InpEnableBreakeven && profitPoints >= InpBreakevenTarget)
         {
            double beLevel = NormalizeDouble(openPrice + InpBreakevenOffset * point, digits);
            if(currentSL == 0 || currentSL < beLevel)
            {
               // Broker stop level check
               double minSL = NormalizeDouble(bid - stopLevel * point, digits);
               double finalBE = MathMin(beLevel, minSL);
               if(finalBE > currentSL || currentSL == 0)
               {
                  if(trade.PositionModify(ticket, finalBE, tp))
                  {
                     Print("BREAKEVEN BUY #", ticket,
                           " Open=", openPrice,
                           " SL: ", currentSL, " -> ", finalBE);
                     currentSL = finalBE; // update for trailing check below
                  }
               }
            }
         }

         // ===== STEP 2: Trailing =====
         if(InpEnableTrailing && profitPoints >= InpTrailingStop)
         {
            double newSL = NormalizeDouble(bid - InpTrailingStop * point, digits);

            // Never below breakeven level
            double beFloor = NormalizeDouble(openPrice + InpBreakevenOffset * point, digits);
            if(newSL < beFloor) newSL = beFloor;

            // Broker stop level check
            double minSL = NormalizeDouble(bid - stopLevel * point, digits);
            if(newSL > minSL) newSL = minSL;

            // Must move at least TrailingStep points to modify
            if(currentSL == 0 || newSL > currentSL + InpTrailingStep * point)
            {
               if(trade.PositionModify(ticket, newSL, tp))
               {
                  Print("TRAIL BUY #", ticket,
                        " Open=", openPrice,
                        " Bid=", bid,
                        " Profit=", DoubleToString(profitPoints, 0), "pts",
                        " SL: ", currentSL, " -> ", newSL);
               }
            }
         }
      }
      else if(posType == POSITION_TYPE_SELL)
      {
         double profitPoints = (openPrice - ask) / point;

         // ===== STEP 1: Breakeven =====
         if(InpEnableBreakeven && profitPoints >= InpBreakevenTarget)
         {
            double beLevel = NormalizeDouble(openPrice - InpBreakevenOffset * point, digits);
            if(currentSL == 0 || currentSL > beLevel)
            {
               // Broker stop level check
               double maxSL = NormalizeDouble(ask + stopLevel * point, digits);
               double finalBE = MathMax(beLevel, maxSL);
               if(currentSL == 0 || finalBE < currentSL)
               {
                  if(trade.PositionModify(ticket, finalBE, tp))
                  {
                     Print("BREAKEVEN SELL #", ticket,
                           " Open=", openPrice,
                           " SL: ", currentSL, " -> ", finalBE);
                     currentSL = finalBE;
                  }
               }
            }
         }

          // ===== STEP 2: Trailing =====
          if(InpEnableTrailing && profitPoints >= InpTrailingStop)
          {
             double newSL = NormalizeDouble(ask + InpTrailingStop * point, digits);

             // NOTE v2.7: Removed beCeiling guard here.
             // Reason: BE is already handled in Step 1. The trailing step check below
             // (newSL < currentSL - Step) already prevents SL from moving backward.
             // The old beCeiling guard was clamping newSL to openPrice level which
             // caused SL to never move below BE when TrailingStop >= BE offset.

             // Broker stop level check
             double maxSL = NormalizeDouble(ask + stopLevel * point, digits);
             if(newSL < maxSL) newSL = maxSL;

             // Must move at least TrailingStep points down to modify
             if(currentSL == 0 || newSL < currentSL - InpTrailingStep * point)
            {
               if(trade.PositionModify(ticket, newSL, tp))
               {
                  Print("TRAIL SELL #", ticket,
                        " Open=", openPrice,
                        " Ask=", ask,
                        " Profit=", DoubleToString(profitPoints, 0), "pts",
                        " SL: ", currentSL, " -> ", newSL);
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Manage Average-Based Trailing Stop                                 |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   //--- BUY side
   double avgBuy = CalculateAveragePrice(POSITION_TYPE_BUY);
   if(avgBuy > 0)
   {
      double beLevel = avgBuy + BreakevenBuffer * point;

      if(EnableTrailingStop)
      {
         double trailActivation = avgBuy + TrailingActivation * point;

         if(bid >= trailActivation)
         {
            g_trailingActive_Buy = true;
            double newSL = bid - TrailingStep * point;
            newSL = MathMax(newSL, beLevel); // never below breakeven

            if(newSL > g_trailingSL_Buy)
            {
               g_trailingSL_Buy = newSL;
               ApplyTrailingSL(POSITION_TYPE_BUY, g_trailingSL_Buy);
            }
         }
      }

      if(EnableBreakeven && !g_breakevenDone_Buy)
      {
         double beActivation = avgBuy + BreakevenActivation * point;
         if(bid >= beActivation)
         {
            g_breakevenDone_Buy = true;
            if(g_trailingSL_Buy < beLevel)
            {
               g_trailingSL_Buy = beLevel;
               ApplyTrailingSL(POSITION_TYPE_BUY, beLevel);
               Print("BREAKEVEN BUY: SL moved to ", beLevel);
            }
         }
      }

      // Check if trailing SL hit
      if(g_trailingActive_Buy && g_trailingSL_Buy > 0 && bid <= g_trailingSL_Buy)
      {
         Print("TRAILING SL HIT (BUY): SL=", g_trailingSL_Buy, " Bid=", bid);
         CloseAllSide(POSITION_TYPE_BUY);
         justClosedBuy = true;
         g_initialBuyPrice = 0;
         // No manual accumulate increment - baseline handles it
         ResetTrailingState();
         return;
      }
   }
   else
   {
      g_trailingSL_Buy = 0;
      g_trailingActive_Buy = false;
      g_breakevenDone_Buy = false;
   }

   //--- SELL side
   double avgSell = CalculateAveragePrice(POSITION_TYPE_SELL);
   if(avgSell > 0)
   {
      double beLevelSell = avgSell - BreakevenBuffer * point;

      if(EnableTrailingStop)
      {
         double trailActivationSell = avgSell - TrailingActivation * point;

         if(ask <= trailActivationSell)
         {
            g_trailingActive_Sell = true;
            double newSL = ask + TrailingStep * point;
            newSL = MathMin(newSL, beLevelSell); // never above breakeven

            if(g_trailingSL_Sell == 0 || newSL < g_trailingSL_Sell)
            {
               g_trailingSL_Sell = newSL;
               ApplyTrailingSL(POSITION_TYPE_SELL, g_trailingSL_Sell);
            }
         }
      }

      if(EnableBreakeven && !g_breakevenDone_Sell)
      {
         double beActivationSell = avgSell - BreakevenActivation * point;
         if(ask <= beActivationSell)
         {
            g_breakevenDone_Sell = true;
            if(g_trailingSL_Sell == 0 || g_trailingSL_Sell > beLevelSell)
            {
               g_trailingSL_Sell = beLevelSell;
               ApplyTrailingSL(POSITION_TYPE_SELL, beLevelSell);
               Print("BREAKEVEN SELL: SL moved to ", beLevelSell);
            }
         }
      }

      // Check if trailing SL hit
      if(g_trailingActive_Sell && g_trailingSL_Sell > 0 && ask >= g_trailingSL_Sell)
      {
         Print("TRAILING SL HIT (SELL): SL=", g_trailingSL_Sell, " Ask=", ask);
         CloseAllSide(POSITION_TYPE_SELL);
         justClosedSell = true;
         g_initialSellPrice = 0;
         // No manual accumulate increment - baseline handles it
         ResetTrailingState();
         return;
      }
   }
   else
   {
      g_trailingSL_Sell = 0;
      g_trailingActive_Sell = false;
      g_breakevenDone_Sell = false;
   }
}

//+------------------------------------------------------------------+
//| Apply trailing SL to all positions of a side (modify broker SL)    |
//+------------------------------------------------------------------+
void ApplyTrailingSL(ENUM_POSITION_TYPE side, double slPrice)
{
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   slPrice = NormalizeDouble(slPrice, digits);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) != side) continue;

      double currentSL = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);

      if(side == POSITION_TYPE_BUY)
      {
         if(currentSL == 0 || slPrice > currentSL)
         {
            trade.PositionModify(ticket, slPrice, tp);
         }
      }
      else
      {
         if(currentSL == 0 || slPrice < currentSL)
         {
            trade.PositionModify(ticket, slPrice, tp);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Reset trailing state                                               |
//+------------------------------------------------------------------+
void ResetTrailingState()
{
   g_trailingSL_Buy = 0;
   g_trailingSL_Sell = 0;
   g_trailingActive_Buy = false;
   g_trailingActive_Sell = false;
   g_breakevenDone_Buy = false;
   g_breakevenDone_Sell = false;
}

//+------------------------------------------------------------------+
//| Check Drawdown Exit                                                |
//+------------------------------------------------------------------+
void CheckDrawdownExit()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(balance <= 0) return;

   double dd = (balance - equity) / balance * 100.0;
   double ddDollar = balance - equity;
   
   bool ddTriggered = false;
   if(DrawdownMode == DD_PERCENT)
   {
      if(dd >= MaxDrawdownPct)
      {
         ddTriggered = true;
         Print("EMERGENCY DD: ", DoubleToString(dd, 2), "% >= ", MaxDrawdownPct, "% - Closing all positions!");
      }
   }
   else // DD_FIXED_DOLLAR
   {
      if(ddDollar >= MaxDrawdownDollar)
      {
         ddTriggered = true;
         Print("EMERGENCY DD: $", DoubleToString(ddDollar, 2), " >= $", DoubleToString(MaxDrawdownDollar, 2), " - Closing all positions!");
      }
   }
   
   if(ddTriggered)
   {
      CloseAllPositions();

      if(StopEAOnDrawdown)
      {
         g_eaStopped = true;
         Print("EA STOPPED by Max Drawdown (StopEAOnDrawdown=true)");
      }
      else
      {
         // Reset state so EA can re-enter on next valid signal
         g_initialBuyPrice  = 0;
         g_initialSellPrice = 0;
         justClosedBuy      = true;
         justClosedSell     = true;
         g_accumulateBaseline = CalcTotalHistoryProfit();
         ResetTrailingState();
         Print("EA continues after DD close (StopEAOnDrawdown=false) - waiting for next signal");
      }
   }
}
//+------------------------------------------------------------------+
//| Find Max Lot on Side (GM_GL / GM_INIT orders)                      |
//+------------------------------------------------------------------+
double FindMaxLotOnSide(ENUM_POSITION_TYPE side)
{
   double maxLot = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != side) continue;
      string comment = PositionGetString(POSITION_COMMENT);
      if(StringFind(comment, "GM_GL") >= 0 || StringFind(comment, "GM_INIT") >= 0)
      {
         double lot = PositionGetDouble(POSITION_VOLUME);
         if(lot > maxLot) maxLot = lot;
      }
   }
   return maxLot;
}

//+------------------------------------------------------------------+
//| Check Grid Loss                                                    |
//+------------------------------------------------------------------+
void CheckGridLoss(ENUM_POSITION_TYPE side, int currentGridCount)
{
   if(currentGridCount >= GridLoss_MaxTrades) return;
   if(TotalOrderCount() >= MaxOpenOrders) return;

   //--- OnlyNewCandle check
   if(GridLoss_OnlyNewCandle)
   {
      datetime barTime = iTime(_Symbol, PERIOD_CURRENT, 0);
      if(barTime == lastGridLossCandleTime) return;
   }

   //--- Check signal filter
   if(GridLoss_OnlyInSignal)
   {
      double sma = bufSMA[0];
      double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(side == POSITION_TYPE_BUY && price < sma) return;
      if(side == POSITION_TYPE_SELL && price > sma) return;
   }

   //--- Find the last order of this side (initial or grid loss)
   //--- Uses initial price as fallback when per-order trailing closed grid orders
   double lastPrice = 0;
   datetime lastTime = 0;
   FindLastOrder(side, "GM_INIT", "GM_GL", lastPrice, lastTime);

   //--- Fallback: use initial order price if no open order found
   if(lastPrice == 0)
   {
      if(side == POSITION_TYPE_BUY && g_initialBuyPrice > 0)
         lastPrice = g_initialBuyPrice;
      else if(side == POSITION_TYPE_SELL && g_initialSellPrice > 0)
         lastPrice = g_initialSellPrice;
      else
         return;
   }

   //--- Check same candle restriction
   if(GridLoss_DontSameCandle)
   {
      datetime barTime = iTime(_Symbol, PERIOD_CURRENT, 0);
      if(lastTime >= barTime) return;
   }

   //--- Calculate required distance
   double distance = GetGridDistance(currentGridCount, true);
   if(distance <= 0) return;

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double currentPrice = (side == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   bool shouldOpen = false;

   if(GridLoss_GapType == GAP_ATR && GridLoss_ATR_Reference == ATR_REF_INITIAL)
   {
      // Initial mode: cumulative distance from initial price
      double initialRef = (side == POSITION_TYPE_BUY) ? g_initialBuyPrice : g_initialSellPrice;
      if(initialRef <= 0) return;
      double totalDistance = distance * (currentGridCount + 1);
      if(side == POSITION_TYPE_BUY)
         shouldOpen = (currentPrice <= initialRef - totalDistance * point);
      else
         shouldOpen = (currentPrice >= initialRef + totalDistance * point);
   }
   else
   {
      // Dynamic mode (default): distance from last grid order
      if(side == POSITION_TYPE_BUY && currentPrice <= lastPrice - distance * point)
         shouldOpen = true;
      else if(side == POSITION_TYPE_SELL && currentPrice >= lastPrice + distance * point)
         shouldOpen = true;
   }

   if(shouldOpen)
   {
      double lots = CalculateGridLot(currentGridCount, true);
      
      //--- Ensure lot continues from max existing lot after matching close
      double maxExisting = FindMaxLotOnSide(side);
      if(maxExisting > 0 && lots <= maxExisting)
      {
         if(GridLoss_LotMode == LOT_MULTIPLY)
            lots = maxExisting * GridLoss_MultiplyFactor;
         else if(GridLoss_LotMode == LOT_ADD)
            lots = maxExisting + InitialLotSize * GridLoss_AddLotPerLevel;
         // LOT_CUSTOM: keep level-based calculation
      }
      
      string comment = "GM_GL#" + IntegerToString(currentGridCount + 1);
      ENUM_ORDER_TYPE orderType = (side == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      if(OpenOrder(orderType, lots, comment))
      {
         lastGridLossCandleTime = iTime(_Symbol, PERIOD_CURRENT, 0);
      }
   }
}

//+------------------------------------------------------------------+
//| Check Grid Profit                                                  |
//+------------------------------------------------------------------+
void CheckGridProfit(ENUM_POSITION_TYPE side, int currentGridCount)
{
   if(currentGridCount >= GridProfit_MaxTrades) return;
   if(TotalOrderCount() >= MaxOpenOrders) return;

   //--- OnlyNewCandle check
   if(GridProfit_OnlyNewCandle)
   {
      datetime barTime = iTime(_Symbol, PERIOD_CURRENT, 0);
      if(barTime == lastGridProfitCandleTime) return;
   }

   //--- Find the last order of this side (initial or grid profit)
   double lastPrice = 0;
   datetime lastTime = 0;
   FindLastOrder(side, "GM_INIT", "GM_GP", lastPrice, lastTime);

   //--- Fallback: use initial order price
   if(lastPrice == 0)
   {
      if(side == POSITION_TYPE_BUY && g_initialBuyPrice > 0)
         lastPrice = g_initialBuyPrice;
      else if(side == POSITION_TYPE_SELL && g_initialSellPrice > 0)
         lastPrice = g_initialSellPrice;
      else
         return;
   }

   //--- Calculate required distance
   double distance = GetGridDistance(currentGridCount, false);
   if(distance <= 0) return;

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double currentPrice = (side == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   bool shouldOpen = false;

   if(GridProfit_GapType == GAP_ATR && GridProfit_ATR_Reference == ATR_REF_INITIAL)
   {
      // Initial mode: cumulative distance from initial price
      double initialRef = (side == POSITION_TYPE_BUY) ? g_initialBuyPrice : g_initialSellPrice;
      if(initialRef <= 0) return;
      double totalDistance = distance * (currentGridCount + 1);
      if(side == POSITION_TYPE_BUY)
         shouldOpen = (currentPrice >= initialRef + totalDistance * point);
      else
         shouldOpen = (currentPrice <= initialRef - totalDistance * point);
   }
   else
   {
      // Dynamic mode (default): distance from last grid order
      if(side == POSITION_TYPE_BUY && currentPrice >= lastPrice + distance * point)
         shouldOpen = true;
      else if(side == POSITION_TYPE_SELL && currentPrice <= lastPrice - distance * point)
         shouldOpen = true;
   }

   if(shouldOpen)
   {
      double lots = CalculateGridLot(currentGridCount, false);
      string comment = "GM_GP#" + IntegerToString(currentGridCount + 1);
      ENUM_ORDER_TYPE orderType = (side == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      if(OpenOrder(orderType, lots, comment))
      {
         lastGridProfitCandleTime = iTime(_Symbol, PERIOD_CURRENT, 0);
      }
   }
}

//+------------------------------------------------------------------+
//| Find last order price for a side (matching comment prefixes)       |
//+------------------------------------------------------------------+
void FindLastOrder(ENUM_POSITION_TYPE side, string prefix1, string prefix2, double &outPrice, datetime &outTime)
{
   outPrice = 0;
   outTime = 0;
   datetime latestTime = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) != side) continue;

      string comment = PositionGetString(POSITION_COMMENT);
      if(StringFind(comment, prefix1) >= 0 || StringFind(comment, prefix2) >= 0)
      {
         datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
         if(openTime > latestTime)
         {
            latestTime = openTime;
            outPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            outTime = openTime;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Simplified ATR Calculation (v3.0 - No Indicator Handle)            |
//| Port from Multi_Currency_Statistical_EA for backtest optimization  |
//+------------------------------------------------------------------+
double CalculateSimplifiedATR(string symbol, ENUM_TIMEFRAMES tf, int period)
{
   double sum = 0;
   int validBars = 0;
   
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
//| Get grid distance in points                                        |
//+------------------------------------------------------------------+
double GetGridDistance(int level, bool isLossSide)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   if(isLossSide)
   {
      if(GridLoss_GapType == GAP_FIXED)
      {
         return (double)GridLoss_Points;
      }
      else if(GridLoss_GapType == GAP_CUSTOM)
      {
         return ParseCustomValue(GridLoss_CustomDistance, level);
      }
      else // ATR - use index 1 (closed bar) to prevent repaint
      {
         double atrVal = 0;
         if(g_isTesterMode && InpSkipATRInTester)
         {
            atrVal = CalculateSimplifiedATR(_Symbol, GridLoss_ATR_TF, GridLoss_ATR_Period);
         }
         else
         {
            atrVal = (ArraySize(bufATR_Loss) > 1 && bufATR_Loss[1] > 0) ? bufATR_Loss[1] : bufATR_Loss[0];
         }
         if(atrVal > 0)
         {
            double atrDistance = atrVal * GridLoss_ATR_Multiplier / point;
            // Apply minimum gap to prevent too-tight grids on low ATR
            atrDistance = MathMax(atrDistance, (double)GridLoss_MinGapPoints);
            return atrDistance;
         }
         return (double)GridLoss_Points;
      }
   }
   else
   {
      if(GridProfit_GapType == GAP_FIXED)
      {
         return (double)GridProfit_Points;
      }
      else if(GridProfit_GapType == GAP_CUSTOM)
      {
         return ParseCustomValue(GridProfit_CustomDistance, level);
      }
      else // ATR - use index 1 (closed bar) to prevent repaint
      {
         double atrVal = 0;
         if(g_isTesterMode && InpSkipATRInTester)
         {
            atrVal = CalculateSimplifiedATR(_Symbol, GridProfit_ATR_TF, GridProfit_ATR_Period);
         }
         else
         {
            atrVal = (ArraySize(bufATR_Profit) > 1 && bufATR_Profit[1] > 0) ? bufATR_Profit[1] : bufATR_Profit[0];
         }
         if(atrVal > 0)
         {
            double atrDistance = atrVal * GridProfit_ATR_Multiplier / point;
            // Apply minimum gap to prevent too-tight grids on low ATR
            atrDistance = MathMax(atrDistance, (double)GridProfit_MinGapPoints);
            return atrDistance;
         }
         return (double)GridProfit_Points;
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate grid lot size                                            |
//+------------------------------------------------------------------+
double CalculateGridLot(int level, bool isLossSide)
{
   if(isLossSide)
   {
      if(GridLoss_LotMode == LOT_ADD)
      {
         return InitialLotSize + InitialLotSize * GridLoss_AddLotPerLevel * (level + 1);
      }
      else if(GridLoss_LotMode == LOT_CUSTOM)
      {
         return ParseCustomValue(GridLoss_CustomLots, level);
      }
      else // MULTIPLY
      {
         return InitialLotSize * MathPow(GridLoss_MultiplyFactor, level + 1);
      }
   }
   else
   {
      if(GridProfit_LotMode == LOT_ADD)
      {
         return InitialLotSize + InitialLotSize * GridProfit_AddLotPerLevel * (level + 1);
      }
      else if(GridProfit_LotMode == LOT_CUSTOM)
      {
         return ParseCustomValue(GridProfit_CustomLots, level);
      }
      else // MULTIPLY
      {
         return InitialLotSize * MathPow(GridProfit_MultiplyFactor, level + 1);
      }
   }
}

//+------------------------------------------------------------------+
//| Parse semicolon-separated values                                   |
//+------------------------------------------------------------------+
double ParseCustomValue(string inputStr, int index)
{
   string parts[];
   ushort sep = StringGetCharacter(";", 0);
   int count = StringSplit(inputStr, sep, parts);
   if(count <= 0) return 0;

   int idx = MathMin(index, count - 1);
   return StringToDouble(parts[idx]);
}

//+------------------------------------------------------------------+
//| Draw chart lines                                                   |
//+------------------------------------------------------------------+
void DrawLines()
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   double avgBuy = CalculateAveragePrice(POSITION_TYPE_BUY);
   double avgSell = CalculateAveragePrice(POSITION_TYPE_SELL);

   //--- Average Buy Line
   if(avgBuy > 0 && ShowAverageLine)
      DrawHLine("GM_AvgBuyLine", avgBuy, AvgBuyLineColor, STYLE_SOLID, 2);
   else
      ObjectDelete(0, "GM_AvgBuyLine");

   //--- Average Sell Line
   if(avgSell > 0 && ShowAverageLine)
      DrawHLine("GM_AvgSellLine", avgSell, AvgSellLineColor, STYLE_SOLID, 2);
   else
      ObjectDelete(0, "GM_AvgSellLine");

   //--- TP Buy Line
   if(ShowTPLine && UseTP_Points && avgBuy > 0)
      DrawHLine("GM_TPBuyLine", avgBuy + TP_Points * point, TPBuyLineColor, STYLE_DASH, 1);
   else
      ObjectDelete(0, "GM_TPBuyLine");

   //--- TP Sell Line
   if(ShowTPLine && UseTP_Points && avgSell > 0)
      DrawHLine("GM_TPSellLine", avgSell - TP_Points * point, TPSellLineColor, STYLE_DASH, 1);
   else
      ObjectDelete(0, "GM_TPSellLine");

   //--- SL Line (show trailing SL if active, otherwise show SL Points)
   if(ShowSLLine)
   {
      bool drawn = false;

      if(g_trailingActive_Buy && g_trailingSL_Buy > 0)
      {
         DrawHLine("GM_SLLine", g_trailingSL_Buy, SLLineColor, STYLE_DASH, 1);
         drawn = true;
      }
      else if(g_trailingActive_Sell && g_trailingSL_Sell > 0)
      {
         DrawHLine("GM_SLLine", g_trailingSL_Sell, SLLineColor, STYLE_DASH, 1);
         drawn = true;
      }

      if(!drawn && UseSL_Points)
      {
         if(avgBuy > 0)
         {
            DrawHLine("GM_SLLine", avgBuy - SL_Points * point, SLLineColor, STYLE_DASH, 1);
         }
         else if(avgSell > 0)
         {
            DrawHLine("GM_SLLine", avgSell + SL_Points * point, SLLineColor, STYLE_DASH, 1);
         }
         else
         {
            ObjectDelete(0, "GM_SLLine");
         }
      }
      else if(!drawn)
      {
         ObjectDelete(0, "GM_SLLine");
      }
   }
   else
   {
      ObjectDelete(0, "GM_SLLine");
   }
}

//+------------------------------------------------------------------+
//| Draw horizontal line                                               |
//+------------------------------------------------------------------+
void DrawHLine(string name, double price, color clr, ENUM_LINE_STYLE style, int width)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
   }
   ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Dashboard Helper: Create Rectangle Label                           |
//+------------------------------------------------------------------+
void CreateDashRect(string name, int x, int y, int w, int h, color bgColor)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgColor);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, bgColor);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Dashboard Helper: Create Text Label                                |
//+------------------------------------------------------------------+
void CreateDashText(string name, int x, int y, string text, color clr, int fontSize, string font)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, font);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Dashboard Helper: Draw one table row                               |
//+------------------------------------------------------------------+
void DrawTableRow(int rowIndex, string label, string value, color valueColor, color sectionColor)
{
   double sc = MathMax(0.8, MathMin(1.5, DashboardScale));
   int x = DashboardX;
   int rowH = (int)(20 * sc);
   int y = DashboardY + (int)(24 * sc) + rowIndex * rowH;
   int tblW = (int)(340 * sc);
   int rH = (int)(19 * sc);
   int sectionBarWidth = (int)(4 * sc);
   int labelX = x + sectionBarWidth + (int)(6 * sc);
   int valueX = x + (int)(180 * sc);
   int fSize = (int)(9 * sc);
   if(fSize < 7) fSize = 7;

   // Alternating row background
   color rowBg = (rowIndex % 2 == 0) ? C'40,44,52' : C'35,39,46';

   string rowName = "GM_TBL_R" + IntegerToString(rowIndex);
   string secName = "GM_TBL_S" + IntegerToString(rowIndex);
   string lblName = "GM_TBL_L" + IntegerToString(rowIndex);
   string valName = "GM_TBL_V" + IntegerToString(rowIndex);

   // Row background
   CreateDashRect(rowName, x, y, tblW, rH, rowBg);
   // Section color bar
   CreateDashRect(secName, x, y, sectionBarWidth, rH, sectionColor);
   // Label text
   CreateDashText(lblName, labelX, y + 2, label, C'180,180,180', fSize, "Consolas");
   // Value text
   CreateDashText(valName, valueX, y + 2, value, valueColor, fSize, "Consolas");
}

//+------------------------------------------------------------------+
//| Display Dashboard - Table Layout v2.3                              |
//+------------------------------------------------------------------+
void DisplayDashboard()
{
   // Clean all table objects before redraw to prevent stale rows
   ObjectsDeleteAll(0, "GM_TBL_R");
   ObjectsDeleteAll(0, "GM_TBL_S");
   ObjectsDeleteAll(0, "GM_TBL_L");
   ObjectsDeleteAll(0, "GM_TBL_V");
   
   double sc = MathMax(0.8, MathMin(1.5, DashboardScale));
   int tableWidth = (int)(340 * sc);
   int headerHeight = (int)(22 * sc);
   int headerFontSize = (int)(11 * sc);
   if(headerFontSize < 8) headerFontSize = 8;
   int subFontSize = (int)(9 * sc);
   if(subFontSize < 7) subFontSize = 7;

   // Colors
   color COLOR_HEADER_BG     = C'180,130,50';
   color COLOR_HEADER_TEXT   = clrWhite;
   color COLOR_SECTION_DETAIL = clrGreen;
   color COLOR_SECTION_ACCUM  = clrYellow;
   color COLOR_SECTION_TRAIL  = clrMagenta;
   color COLOR_SECTION_INFO   = clrDodgerBlue;
   color COLOR_PROFIT         = clrLime;
   color COLOR_LOSS           = clrOrangeRed;
   color COLOR_TEXT           = clrWhite;

   //--- Gather data
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double plBuy = CalculateFloatingPL(POSITION_TYPE_BUY);
   double plSell = CalculateFloatingPL(POSITION_TYPE_SELL);
   double totalPL = plBuy + plSell;
   double dd = (balance > 0) ? (balance - equity) / balance * 100.0 : 0;
   double lotsBuy = CalculateTotalLots(POSITION_TYPE_BUY);
   double lotsSell = CalculateTotalLots(POSITION_TYPE_SELL);

   int buyCount = 0, sellCount = 0;
   int glB = 0, glS = 0, gpB = 0, gpS = 0;
   bool ib = false, is2 = false;
   CountPositions(buyCount, sellCount, glB, glS, gpB, gpS, ib, is2);

   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   string smaDir = "";
   if(EntryMode == ENTRY_SMA && ArraySize(bufSMA) > 0 && bufSMA[0] > 0)
   {
      double bidPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      smaDir = (bidPrice > bufSMA[0]) ? "BUY ▲" : "SELL ▼";
   }

   string tradeModeStr = (TradingMode == TRADE_BUY_ONLY) ? "Buy Only" :
                           (TradingMode == TRADE_SELL_ONLY) ? "Sell Only" : "Both";

   //--- Header
   string headerVersion = (EntryMode == ENTRY_SMA) ? "Gold Miner EA v5.0 [SMA]" : (EntryMode == ENTRY_ZIGZAG) ? "Gold Miner EA v5.0 [ZZ]" : "Gold Miner EA v5.0 [INST]";
   CreateDashRect("GM_TBL_HDR", DashboardX, DashboardY, tableWidth, headerHeight, COLOR_HEADER_BG);
   CreateDashText("GM_TBL_HDR_T", DashboardX + 8, DashboardY + 3, headerVersion, COLOR_HEADER_TEXT, headerFontSize, "Arial Bold");
   CreateDashText("GM_TBL_HDR_M", DashboardX + (int)(220 * sc), DashboardY + 4, "Mode: " + tradeModeStr, COLOR_HEADER_TEXT, subFontSize, "Consolas");

   //--- DETAIL Section
   int row = 0;
   DrawTableRow(row, "Balance",       "$" + DoubleToString(balance, 2),  COLOR_TEXT, COLOR_SECTION_DETAIL); row++;
   DrawTableRow(row, "Equity",        "$" + DoubleToString(equity, 2),   COLOR_TEXT, COLOR_SECTION_DETAIL); row++;
   DrawTableRow(row, "Floating P/L",  "$" + DoubleToString(totalPL, 2),  (totalPL >= 0 ? COLOR_PROFIT : COLOR_LOSS), COLOR_SECTION_DETAIL); row++;

   if(EntryMode == ENTRY_SMA)
   {
      DrawTableRow(row, "Signal (SMA" + IntegerToString(SMA_Period) + ")", smaDir, (smaDir == "BUY ▲" ? COLOR_PROFIT : COLOR_LOSS), COLOR_SECTION_DETAIL); row++;
   }
   else
   {
      // ZigZag MTF info rows
      color COLOR_SECTION_ZZ = clrDarkOrange;

      // CDC Trend
      if(InpUseCDCFilter)
      {
         color cdcColor = (g_cdcTrend == "BULLISH") ? COLOR_PROFIT : (g_cdcTrend == "BEARISH") ? COLOR_LOSS : clrYellow;
         string cdcStatus = g_cdcReady ? g_cdcTrend : "LOADING";
         if(!g_cdcReady) cdcColor = clrYellow;
         DrawTableRow(row, "CDC Trend", cdcStatus, cdcColor, COLOR_SECTION_ZZ); row++;
      }

      // H4 Direction
      color h4Color = (g_h4Direction == "BUY") ? COLOR_PROFIT : (g_h4Direction == "SELL") ? COLOR_LOSS : clrYellow;
      DrawTableRow(row, "H4 Direction", g_h4Direction, h4Color, COLOR_SECTION_ZZ); row++;

      // Per-TF status
      for(int tf = 0; tf < g_activeTFCount; tf++)
      {
         if(g_tfStates[tf].tf == ZZ_ConfirmTF && !ZZ_UseConfirmTFEntry) continue;

         int tfB2 = 0, tfS2 = 0, tGL2 = 0, tGLS2 = 0, tGP2 = 0, tGPS2 = 0;
         bool tIB2 = false, tIS2 = false;
         CountPositionsTF(tf, tfB2, tfS2, tGL2, tGLS2, tGP2, tGPS2, tIB2, tIS2);

         string tfInfo = IntegerToString(tfB2) + "B/" + IntegerToString(tfS2) + "S";
         if(!g_tfStates[tf].enabled) tfInfo = "OFF";
         color tfColor2 = (tfB2 > 0 || tfS2 > 0) ? clrGold : COLOR_TEXT;
         DrawTableRow(row, g_tfStates[tf].tfLabel, tfInfo, tfColor2, COLOR_SECTION_ZZ); row++;
      }
   }

   // Buy position info
   string buyInfo = "$" + DoubleToString(plBuy, 2) + "  " + DoubleToString(lotsBuy, 2) + "L  " + IntegerToString(buyCount) + "ord";
   DrawTableRow(row, "Position BUY",  buyInfo, (plBuy >= 0 ? COLOR_PROFIT : COLOR_LOSS), COLOR_SECTION_DETAIL); row++;

   // Sell position info
   string sellInfo = "$" + DoubleToString(plSell, 2) + "  " + DoubleToString(lotsSell, 2) + "L  " + IntegerToString(sellCount) + "ord";
   DrawTableRow(row, "Position SELL", sellInfo, (plSell >= 0 ? COLOR_PROFIT : COLOR_LOSS), COLOR_SECTION_DETAIL); row++;

   if(DrawdownMode == DD_FIXED_DOLLAR)
   {
      double ddDollar = balance - equity;
      DrawTableRow(row, "Current DD",   "$" + DoubleToString(ddDollar, 2) + " / $" + DoubleToString(MaxDrawdownDollar, 2),
                   (ddDollar > MaxDrawdownDollar * 0.5 ? COLOR_LOSS : COLOR_TEXT), COLOR_SECTION_DETAIL); row++;
      DrawTableRow(row, "Max DD",       "$" + DoubleToString(g_maxDD / 100.0 * balance, 2),
                   (g_maxDD > 15 ? COLOR_LOSS : COLOR_TEXT), COLOR_SECTION_DETAIL); row++;
   }
   else
   {
      DrawTableRow(row, "Current DD%",   DoubleToString(dd, 2) + "% / " + DoubleToString(MaxDrawdownPct, 1) + "%",
                   (dd > 10 ? COLOR_LOSS : COLOR_TEXT), COLOR_SECTION_DETAIL); row++;
      DrawTableRow(row, "Max DD%",       DoubleToString(g_maxDD, 2) + "%",
                   (g_maxDD > 15 ? COLOR_LOSS : COLOR_TEXT), COLOR_SECTION_DETAIL); row++;
   }

   //--- ACCUMULATE Section
   if(UseAccumulateClose)
   {
      double accumClosed = g_accumulatedProfit;
      double accumFloating = CalculateTotalFloatingPL();
      double accumTotal = accumClosed + accumFloating;
      double accumNeed = AccumulateTarget - accumTotal;
      if(accumNeed < 0) accumNeed = 0;

      DrawTableRow(row, "Accum. Closed",   "$" + DoubleToString(accumClosed, 2),   (accumClosed >= 0 ? COLOR_PROFIT : COLOR_LOSS), COLOR_SECTION_ACCUM); row++;
      DrawTableRow(row, "Accum. Floating",  "$" + DoubleToString(accumFloating, 2), (accumFloating >= 0 ? COLOR_PROFIT : COLOR_LOSS), COLOR_SECTION_ACCUM); row++;

      string accumTotalStr = "$" + DoubleToString(accumTotal, 2)
                           + "  Tg:$" + DoubleToString(AccumulateTarget, 0)
                           + "  Need:$" + DoubleToString(accumNeed, 0);
      DrawTableRow(row, "Accum. Total",    accumTotalStr, (accumTotal >= 0 ? COLOR_PROFIT : COLOR_LOSS), COLOR_SECTION_ACCUM); row++;
   }

   //--- TRAILING Section
   if(EnablePerOrderTrailing)
   {
      string beInfo = InpEnableBreakeven ? "BE:" + IntegerToString(InpBreakevenTarget) + "/" + IntegerToString(InpBreakevenOffset) : "BE:OFF";
      string trInfo = InpEnableTrailing ? "Trail:" + IntegerToString(InpTrailingStop) + "/" + IntegerToString(InpTrailingStep) : "Trail:OFF";
      DrawTableRow(row, "Per-Order",  beInfo + "  " + trInfo, COLOR_TEXT, COLOR_SECTION_TRAIL); row++;
   }
   else if(EnableTrailingStop)
   {
      string trailInfo = "";
      if(g_trailingActive_Buy) trailInfo = "Buy SL:" + DoubleToString(g_trailingSL_Buy, digits);
      else if(g_trailingActive_Sell) trailInfo = "Sell SL:" + DoubleToString(g_trailingSL_Sell, digits);
      else trailInfo = "Waiting...";
      DrawTableRow(row, "Avg Trailing",  trailInfo, COLOR_TEXT, COLOR_SECTION_TRAIL); row++;
   }

   //--- INFO Section (History metrics - removed BUY/SELL Cycle rows)
   color COLOR_SECTION_HIST = C'50,100,180';  // distinct blue for history section

   // Current open lot total
   double totalCurrentLots = CalculateTotalLots(POSITION_TYPE_BUY) + CalculateTotalLots(POSITION_TYPE_SELL);
   DrawTableRow(row, "Total Cur. Lot",   DoubleToString(totalCurrentLots, 2) + " L", COLOR_TEXT, COLOR_SECTION_HIST); row++;

   // History metrics (read from deal history)
   double closedLots   = CalcTotalClosedLots();
   int    closedOrders = CalcTotalClosedOrders();
   double monthlyPL    = CalcMonthlyPL();
   double totalPLHist  = CalcTotalHistoryProfit();

   DrawTableRow(row, "Total Closed Lot", DoubleToString(closedLots, 2) + " L", COLOR_TEXT, COLOR_SECTION_HIST); row++;

   // Rebate metrics
   double dailyClosedLots = CalcDailyClosedLots();
   double dailyRebate     = dailyClosedLots * InpRebatePerLot;
   double totalRebate     = closedLots * InpRebatePerLot;
   color  COLOR_SECTION_REBATE = C'180,150,50';  // gold for rebate section
   DrawTableRow(row, "Daily Closed Lot", DoubleToString(dailyClosedLots, 2) + " L", COLOR_TEXT, COLOR_SECTION_REBATE); row++;
   DrawTableRow(row, "Daily Rebate",     "$" + DoubleToString(dailyRebate, 2), COLOR_PROFIT, COLOR_SECTION_REBATE); row++;
   DrawTableRow(row, "Total Rebate",     "$" + DoubleToString(totalRebate, 2), COLOR_PROFIT, COLOR_SECTION_REBATE); row++;

   DrawTableRow(row, "Total Closed Ord", IntegerToString(closedOrders) + " orders", COLOR_TEXT, COLOR_SECTION_HIST); row++;
   DrawTableRow(row, "Monthly P/L",      "$" + DoubleToString(monthlyPL, 2), (monthlyPL >= 0 ? COLOR_PROFIT : COLOR_LOSS), COLOR_SECTION_HIST); row++;
   DrawTableRow(row, "Total P/L",        "$" + DoubleToString(totalPLHist, 2), (totalPLHist >= 0 ? COLOR_PROFIT : COLOR_LOSS), COLOR_SECTION_HIST); row++;

   DrawTableRow(row, "Auto Re-Entry", (EnableAutoReEntry ? "ON" : "OFF"), (EnableAutoReEntry ? COLOR_PROFIT : COLOR_LOSS), COLOR_SECTION_INFO); row++;

   // Daily Profit Pause status
   if(InpEnableDailyProfitPause)
   {
      double dailyPL = CalcDailyPL();
      string dpText = StringFormat("$%.2f / $%.2f", dailyPL, InpDailyProfitTarget);
      color dpColor = g_dailyProfitPaused ? COLOR_LOSS : COLOR_PROFIT;
      if(g_dailyProfitPaused) dpText = dpText + " PAUSED";
      DrawTableRow(row, "Daily Profit", dpText, dpColor, COLOR_SECTION_INFO); row++;
   }

   // System Status (v2.9)
   string statusText = "Working";
   color statusColor = COLOR_PROFIT;

   if(g_licenseStatus == LICENSE_SUSPENDED || g_licenseStatus == LICENSE_EXPIRED)
   {
      statusText = (g_licenseStatus == LICENSE_SUSPENDED) ? "SUSPENDED" : "EXPIRED";
      statusColor = COLOR_LOSS;
   }
   else if(!g_isLicenseValid && !g_isTesterMode)
   {
      statusText = "INVALID";
      statusColor = COLOR_LOSS;
   }
   else if(g_eaIsPaused)
   {
      statusText = "PAUSED";
      statusColor = COLOR_LOSS;
   }
   else if(g_newOrderBlocked)
   {
      statusText = "BLOCKED";
      statusColor = clrYellow;
   }
   DrawTableRow(row, "System Status", statusText, statusColor, COLOR_SECTION_INFO); row++;

   // License Status
   DrawTableRow(row, "License", g_isTesterMode ? "TESTER" : 
      (g_isLicenseValid ? (g_isLifetime ? "LIFETIME" : IntegerToString(g_daysRemaining) + " days") : "INVALID"),
      g_isLicenseValid ? COLOR_PROFIT : COLOR_LOSS, COLOR_SECTION_INFO); row++;

   // Time Filter
   if(InpUseTimeFilter)
   {
      DrawTableRow(row, "Time Filter", IsWithinTradingHours() ? "ACTIVE" : "PAUSED",
         IsWithinTradingHours() ? COLOR_PROFIT : COLOR_LOSS, COLOR_SECTION_INFO); row++;
   }

   // News Filter with countdown (v2.9)
   if(InpEnableNewsFilter)
   {
      string newsDisplay;
      color newsColor;
      
      if(!g_webRequestConfigured)
      {
         newsDisplay = "WebRequest: NOT CONFIGURED!";
         newsColor = COLOR_LOSS;
      }
      else if(g_isNewsPaused && StringLen(g_nextNewsTitle) > 0)
      {
         // Show news title + countdown timer
         string truncTitle = g_nextNewsTitle;
         if(StringLen(truncTitle) > 18)
            truncTitle = StringSubstr(truncTitle, 0, 15) + "...";
         string countdown = GetNewsCountdownString();
         newsDisplay = truncTitle + " " + countdown;
         newsColor = COLOR_LOSS;
      }
      else if(g_newsEventCount == 0)
      {
         newsDisplay = "0 events loaded";
         newsColor = clrYellow;
      }
      else
      {
         newsDisplay = "No Important news";
         newsColor = COLOR_PROFIT;
      }
      
      DrawTableRow(row, "News Filter", newsDisplay, newsColor, COLOR_SECTION_INFO); row++;
   }

   //--- Squeeze Filter Section
   if(InpUseSqueezeFilter)
   {
      DrawTableRow(row, "--- SQUEEZE ---", "", clrGray, COLOR_SECTION_INFO); row++;
      for(int sq = 0; sq < 3; sq++)
      {
         string stateStr;
         color stateClr;
         if(g_squeeze[sq].state == 1)      { stateStr = "SQUEEZE";   stateClr = clrRed;        }
         else if(g_squeeze[sq].state == 2)  { stateStr = "EXPANSION"; stateClr = clrDodgerBlue; }
         else                               { stateStr = "NORMAL";    stateClr = clrLime;       }

         // Build intensity bar (10 chars)
         int barLen = (int)MathMin(10, MathMax(0, (int)(g_squeeze[sq].intensity * 5.0)));
         string bar = "|";
         for(int b = 0; b < 10; b++)
         {
            if(b < barLen) bar += "#";
            else bar += ".";
         }
         bar += "|";

         string sqVal = StringFormat("%s  %.2f %s", stateStr, g_squeeze[sq].intensity, bar);
         DrawTableRow(row, g_squeeze[sq].tfLabel, sqVal, stateClr, COLOR_SECTION_INFO); row++;
      }

      string sqBlock;
      color sqBlockClr;
      if(g_squeezeBlocked)             { sqBlock = "BLOCKED ALL"; sqBlockClr = clrRed;    }
      else if(g_squeezeBuyBlocked)     { sqBlock = "BUY BLOCKED"; sqBlockClr = clrOrange;  }
      else if(g_squeezeSellBlocked)    { sqBlock = "SELL BLOCKED"; sqBlockClr = clrOrange; }
      else                             { sqBlock = "OK";           sqBlockClr = clrLime;   }
      DrawTableRow(row, "Squeeze Status", sqBlock, sqBlockClr, COLOR_SECTION_INFO); row++;
   }

   //--- Counter-Trend Hedging Section
   if(InpHedge_Enable)
   {
      color COLOR_SECTION_HEDGE = C'130,50,180';  // purple for hedge section
      bool anyActive = false;
      for(int h = 0; h < MAX_HEDGE_SETS; h++)
      {
         if(g_hedgeSets[h].active && PositionSelectByTicket(g_hedgeSets[h].hedgeTicket))
         {
            anyActive = true;
            string setLabel = "Hedge #" + IntegerToString(h + 1);
            string sideStr = (g_hedgeSets[h].hedgeSide == POSITION_TYPE_BUY) ? "BUY" : "SELL";

            // Get hedge PnL
            double hedgePnL = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);

            string hedgeInfo = sideStr + " " + DoubleToString(g_hedgeSets[h].hedgeLots, 2) + "L";
            hedgeInfo += " PnL:$" + DoubleToString(hedgePnL, 2);
            hedgeInfo += " B:" + IntegerToString(g_hedgeSets[h].boundTicketCount);
            if(g_hedgeSets[h].gridMode)
               hedgeInfo += " Grid:L" + IntegerToString(g_hedgeSets[h].gridLevel);

            color hedgeClr = (hedgePnL >= 0) ? clrLime : clrOrangeRed;
            DrawTableRow(row, setLabel, hedgeInfo, hedgeClr, COLOR_SECTION_HEDGE); row++;
         }
      }
   }

   //--- Bottom border
   int rowH_sc = (int)(20 * sc);
   int bottomY = DashboardY + (int)(24 * sc) + row * rowH_sc;
   CreateDashRect("GM_TBL_BTM", DashboardX, bottomY, tableWidth, 2, COLOR_HEADER_BG);

   //--- Control Buttons (v2.9) - below dashboard
   int btnY = bottomY + 5;
   int btnW = (tableWidth - 10) / 2;
   int btnH = (int)(22 * sc);

   // Pause/Start button
   string pauseText = g_eaIsPaused ? "▶ Start" : "⏸ Pause";
   color pauseBg = g_eaIsPaused ? clrForestGreen : clrOrangeRed;
   CreateDashButton("GM_BtnPause", DashboardX, btnY, tableWidth, btnH, pauseText, pauseBg, clrWhite);
   btnY += btnH + 3;

   // Close Buy / Close Sell
   CreateDashButton("GM_BtnCloseBuy", DashboardX, btnY, btnW, btnH, "Close Buy", C'20,100,50', clrWhite);
   CreateDashButton("GM_BtnCloseSell", DashboardX + btnW + 10, btnY, btnW, btnH, "Close Sell", C'180,50,30', clrWhite);
   btnY += btnH + 3;

   // Close All
   CreateDashButton("GM_BtnCloseAll", DashboardX, btnY, tableWidth, btnH, "Close All", C'30,100,180', clrWhite);
   btnY += btnH + 3;

   // Resume Daily Profit button (only visible when paused)
   if(InpEnableDailyProfitPause && g_dailyProfitPaused)
   {
      CreateDashButton("GM_BtnResumeDaily", DashboardX, btnY, tableWidth, btnH,
                       "▶ Resume Daily", clrDarkGreen, clrWhite);
   }
   else
   {
      ObjectDelete(0, "GM_BtnResumeDaily");
   }
}

//+------------------------------------------------------------------+
//| Dashboard label helper (legacy - kept for compatibility)           |
//+------------------------------------------------------------------+
void DashLabel(string name, int x, int y, string text, color clr)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ============== ZIGZAG MTF MODULE (v3.0) ======================== |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Initialize ZigZag handles for enabled timeframes                   |
//+------------------------------------------------------------------+
void InitZigZagHandles()
{
   g_activeTFCount = 0;

   // H4 (Confirm TF) - always created for direction detection
   {
      g_tfStates[g_activeTFCount].tf = ZZ_ConfirmTF;
      g_tfStates[g_activeTFCount].tfLabel = "H4";
      g_tfStates[g_activeTFCount].enabled = ZZ_UseConfirmTFEntry;
      g_tfStates[g_activeTFCount].handleZZ = iCustom(_Symbol, ZZ_ConfirmTF, "Examples\\ZigZag", ZZ_Depth, ZZ_Deviation, ZZ_Backstep);
      ResetTFState(g_activeTFCount);
      g_h4TFIndex = g_activeTFCount;
      if(g_tfStates[g_activeTFCount].handleZZ == INVALID_HANDLE)
         Print("WARNING: ZigZag handle failed for ", EnumToString(ZZ_ConfirmTF));
      else
         Print("ZigZag handle OK for ", EnumToString(ZZ_ConfirmTF));
      g_activeTFCount++;
   }

   // M30
   if(ZZ_UseM30)
   {
      g_tfStates[g_activeTFCount].tf = PERIOD_M30;
      g_tfStates[g_activeTFCount].tfLabel = "M30";
      g_tfStates[g_activeTFCount].enabled = true;
      g_tfStates[g_activeTFCount].handleZZ = iCustom(_Symbol, PERIOD_M30, "Examples\\ZigZag", ZZ_Depth, ZZ_Deviation, ZZ_Backstep);
      ResetTFState(g_activeTFCount);
      if(g_tfStates[g_activeTFCount].handleZZ == INVALID_HANDLE)
         Print("WARNING: ZigZag handle failed for M30");
      g_activeTFCount++;
   }

   // M15
   if(ZZ_UseM15)
   {
      g_tfStates[g_activeTFCount].tf = PERIOD_M15;
      g_tfStates[g_activeTFCount].tfLabel = "M15";
      g_tfStates[g_activeTFCount].enabled = true;
      g_tfStates[g_activeTFCount].handleZZ = iCustom(_Symbol, PERIOD_M15, "Examples\\ZigZag", ZZ_Depth, ZZ_Deviation, ZZ_Backstep);
      ResetTFState(g_activeTFCount);
      if(g_tfStates[g_activeTFCount].handleZZ == INVALID_HANDLE)
         Print("WARNING: ZigZag handle failed for M15");
      g_activeTFCount++;
   }

   // M5
   if(ZZ_UseM5)
   {
      g_tfStates[g_activeTFCount].tf = PERIOD_M5;
      g_tfStates[g_activeTFCount].tfLabel = "M5";
      g_tfStates[g_activeTFCount].enabled = true;
      g_tfStates[g_activeTFCount].handleZZ = iCustom(_Symbol, PERIOD_M5, "Examples\\ZigZag", ZZ_Depth, ZZ_Deviation, ZZ_Backstep);
      ResetTFState(g_activeTFCount);
      if(g_tfStates[g_activeTFCount].handleZZ == INVALID_HANDLE)
         Print("WARNING: ZigZag handle failed for M5");
      g_activeTFCount++;
   }

   Print("ZigZag MTF initialized: ", g_activeTFCount, " timeframes active");
}

//+------------------------------------------------------------------+
//| Reset TFState to defaults                                          |
//+------------------------------------------------------------------+
void ResetTFState(int idx)
{
   g_tfStates[idx].lastSwingPrice = 0;
   g_tfStates[idx].lastSwingType = "NONE";
   g_tfStates[idx].lastSwingTime = 0;
   g_tfStates[idx].initialBuyPrice = 0;
   g_tfStates[idx].initialSellPrice = 0;
   g_tfStates[idx].lastInitialCandle = 0;
   g_tfStates[idx].lastGridLossCandle = 0;
   g_tfStates[idx].lastGridProfitCandle = 0;
   g_tfStates[idx].justClosedBuy = false;
   g_tfStates[idx].justClosedSell = false;
   g_tfStates[idx].trailSL_Buy = 0;
   g_tfStates[idx].trailSL_Sell = 0;
   g_tfStates[idx].trailActive_Buy = false;
   g_tfStates[idx].trailActive_Sell = false;
   g_tfStates[idx].beDone_Buy = false;
   g_tfStates[idx].beDone_Sell = false;
}

//+------------------------------------------------------------------+
//| Reset TF trailing state                                            |
//+------------------------------------------------------------------+
void ResetTrailingStateTF(int tfIdx)
{
   g_tfStates[tfIdx].trailSL_Buy = 0;
   g_tfStates[tfIdx].trailSL_Sell = 0;
   g_tfStates[tfIdx].trailActive_Buy = false;
   g_tfStates[tfIdx].trailActive_Sell = false;
   g_tfStates[tfIdx].beDone_Buy = false;
   g_tfStates[tfIdx].beDone_Sell = false;
}

//+------------------------------------------------------------------+
//| Recover TF initial prices from existing positions                  |
//+------------------------------------------------------------------+
void RecoverTFInitialPrices()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      string comment = PositionGetString(POSITION_COMMENT);
      long posType = PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);

      for(int t = 0; t < g_activeTFCount; t++)
      {
         string prefix = "GM_" + g_tfStates[t].tfLabel + "_INIT";
         if(StringFind(comment, prefix) >= 0)
         {
            if(posType == POSITION_TYPE_BUY)
               g_tfStates[t].initialBuyPrice = openPrice;
            else if(posType == POSITION_TYPE_SELL)
               g_tfStates[t].initialSellPrice = openPrice;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Detect latest ZigZag swing on a specific TF                        |
//| Returns: "LOW" (buy signal), "HIGH" (sell signal), "NONE"          |
//+------------------------------------------------------------------+
string DetectZigZagSwing(int tfIndex)
{
   if(g_tfStates[tfIndex].handleZZ == INVALID_HANDLE) return "NONE";

   // Buffer 1 = High Map (Swing High points), Buffer 2 = Low Map (Swing Low points)
   double zzHighMap[], zzLowMap[];
   ArraySetAsSeries(zzHighMap, true);
   ArraySetAsSeries(zzLowMap, true);
   if(CopyBuffer(g_tfStates[tfIndex].handleZZ, 1, 0, 100, zzHighMap) < 100) return "NONE";
   if(CopyBuffer(g_tfStates[tfIndex].handleZZ, 2, 0, 100, zzLowMap) < 100) return "NONE";

   // Find most recent Swing High and Swing Low bar indices (skip bar 0 = forming)
   int lastHighBar = -1, lastLowBar = -1;
   double lastHighPrice = 0, lastLowPrice = 0;
   for(int i = 1; i < 100; i++)
   {
      if(lastHighBar < 0 && zzHighMap[i] != 0.0) { lastHighBar = i; lastHighPrice = zzHighMap[i]; }
      if(lastLowBar  < 0 && zzLowMap[i]  != 0.0) { lastLowBar  = i; lastLowPrice  = zzLowMap[i];  }
      if(lastHighBar >= 0 && lastLowBar >= 0) break;
   }

   // Determine which swing is more recent (lower bar index = more recent)
   if(lastLowBar >= 0 && (lastHighBar < 0 || lastLowBar < lastHighBar))
   {
      g_tfStates[tfIndex].lastSwingPrice = lastLowPrice;
      g_tfStates[tfIndex].lastSwingType  = "LOW";
      g_tfStates[tfIndex].lastSwingTime  = iTime(_Symbol, g_tfStates[tfIndex].tf, lastLowBar);
      return "LOW";
   }
   else if(lastHighBar >= 0)
   {
      g_tfStates[tfIndex].lastSwingPrice = lastHighPrice;
      g_tfStates[tfIndex].lastSwingType  = "HIGH";
      g_tfStates[tfIndex].lastSwingTime  = iTime(_Symbol, g_tfStates[tfIndex].tf, lastHighBar);
      return "HIGH";
   }
   return "NONE";
}

//+------------------------------------------------------------------+
//| Calculate EMA for CDC (ported from Harmony Dream v3.5.0)           |
//+------------------------------------------------------------------+
void CalculateCDC_EMA_GM(double &src[], double &result[], int period, int size)
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
//| Update CDC Action Zone trend                                       |
//+------------------------------------------------------------------+
void UpdateCDC()
{
   if(!InpUseCDCFilter) return;

   // Only recalculate on new CDC TF bar
   datetime cdcBar = iTime(_Symbol, InpCDCTimeframe, 0);
   if(cdcBar == g_lastCdcCandle && g_cdcReady) return;
   g_lastCdcCandle = cdcBar;

   int minBarsReq = InpCDCSlowPeriod + 10;
   int barsNeeded = InpCDCSlowPeriod * 3 + 50;

   double closeArr[], highArr[], lowArr[], openArr[];
   ArraySetAsSeries(closeArr, true);
   ArraySetAsSeries(highArr, true);
   ArraySetAsSeries(lowArr, true);
   ArraySetAsSeries(openArr, true);

   int copied = CopyClose(_Symbol, InpCDCTimeframe, 0, barsNeeded, closeArr);
   if(copied < minBarsReq) { g_cdcReady = false; return; }

   int actualBars = MathMin(copied, barsNeeded);

   int copiedH = CopyHigh(_Symbol, InpCDCTimeframe, 0, actualBars, highArr);
   int copiedL = CopyLow(_Symbol, InpCDCTimeframe, 0, actualBars, lowArr);
   int copiedO = CopyOpen(_Symbol, InpCDCTimeframe, 0, actualBars, openArr);
   if(copiedH < actualBars || copiedL < actualBars || copiedO < actualBars)
   {
      g_cdcReady = false;
      return;
   }

   // Calculate OHLC4
   double ohlc4[];
   ArrayResize(ohlc4, actualBars);
   for(int i = 0; i < actualBars; i++)
      ohlc4[i] = (openArr[i] + highArr[i] + lowArr[i] + closeArr[i]) / 4.0;

   // AP (Smoothed OHLC4 with EMA2)
   double ap[];
   ArrayResize(ap, actualBars);
   CalculateCDC_EMA_GM(ohlc4, ap, 2, actualBars);

   // Fast & Slow EMA
   double fast[], slow[];
   ArrayResize(fast, actualBars);
   ArrayResize(slow, actualBars);
   CalculateCDC_EMA_GM(ap, fast, InpCDCFastPeriod, actualBars);
   CalculateCDC_EMA_GM(ap, slow, InpCDCSlowPeriod, actualBars);

   if(ArraySize(fast) < 2 || ArraySize(slow) < 2)
   {
      g_cdcReady = false;
      return;
   }

   g_cdcFast = fast[0];
   g_cdcSlow = slow[0];

   if(g_cdcFast == 0 || g_cdcSlow == 0)
   {
      g_cdcReady = false;
      return;
   }

   // Determine trend
   if(InpCDCRequireCross)
   {
      double fastPrev = fast[1];
      double slowPrev = slow[1];
      bool crossUp = (fastPrev <= slowPrev && g_cdcFast > g_cdcSlow);
      bool crossDown = (fastPrev >= slowPrev && g_cdcFast < g_cdcSlow);
      if(crossUp) g_cdcTrend = "BULLISH";
      else if(crossDown) g_cdcTrend = "BEARISH";
      // else keep previous trend
   }
   else
   {
      if(g_cdcFast > g_cdcSlow) g_cdcTrend = "BULLISH";
      else if(g_cdcFast < g_cdcSlow) g_cdcTrend = "BEARISH";
      else g_cdcTrend = "NEUTRAL";
   }

   g_cdcReady = true;
}

//+------------------------------------------------------------------+
//| Count positions for a specific TF (by comment prefix)              |
//+------------------------------------------------------------------+
void CountPositionsTF(int tfIdx, int &buyCount, int &sellCount,
                      int &gridLossBuy, int &gridLossSell,
                      int &gridProfitBuy, int &gridProfitSell,
                      bool &hasInitialBuy, bool &hasInitialSell)
{
   buyCount = 0; sellCount = 0;
   gridLossBuy = 0; gridLossSell = 0;
   gridProfitBuy = 0; gridProfitSell = 0;
   hasInitialBuy = false; hasInitialSell = false;

   string prefix = "GM_" + g_tfStates[tfIdx].tfLabel + "_";

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      string comment = PositionGetString(POSITION_COMMENT);
      if(StringFind(comment, prefix) < 0) continue;

      long posType = PositionGetInteger(POSITION_TYPE);

      if(posType == POSITION_TYPE_BUY)
      {
         buyCount++;
         if(StringFind(comment, prefix + "INIT") >= 0) hasInitialBuy = true;
         if(StringFind(comment, prefix + "GL") >= 0) gridLossBuy++;
         if(StringFind(comment, prefix + "GP") >= 0) gridProfitBuy++;
      }
      else if(posType == POSITION_TYPE_SELL)
      {
         sellCount++;
         if(StringFind(comment, prefix + "INIT") >= 0) hasInitialSell = true;
         if(StringFind(comment, prefix + "GL") >= 0) gridLossSell++;
         if(StringFind(comment, prefix + "GP") >= 0) gridProfitSell++;
      }
   }
}

//+------------------------------------------------------------------+
//| Open order for a specific TF                                       |
//+------------------------------------------------------------------+
bool OpenOrderTF(int tfIdx, ENUM_ORDER_TYPE orderType, double lots, string suffix)
{
   string comment = "GM_" + g_tfStates[tfIdx].tfLabel + "_" + suffix;
   return OpenOrder(orderType, lots, comment);
}

//+------------------------------------------------------------------+
//| Calculate average price for a TF                                   |
//+------------------------------------------------------------------+
double CalculateAveragePriceTF(int tfIdx, ENUM_POSITION_TYPE side)
{
   string prefix = "GM_" + g_tfStates[tfIdx].tfLabel + "_";
   double totalLots = 0;
   double totalWeighted = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) != side) continue;
      if(StringFind(PositionGetString(POSITION_COMMENT), prefix) < 0) continue;

      double vol = PositionGetDouble(POSITION_VOLUME);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      totalLots += vol;
      totalWeighted += openPrice * vol;
   }

   if(totalLots > 0) return totalWeighted / totalLots;
   return 0;
}

//+------------------------------------------------------------------+
//| Calculate floating PL for a TF                                     |
//+------------------------------------------------------------------+
double CalculateFloatingPL_TF(int tfIdx, ENUM_POSITION_TYPE side)
{
   string prefix = "GM_" + g_tfStates[tfIdx].tfLabel + "_";
   double totalPLtf = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) != side) continue;
      if(StringFind(PositionGetString(POSITION_COMMENT), prefix) < 0) continue;

      totalPLtf += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return totalPLtf;
}

//+------------------------------------------------------------------+
//| Find last order for a TF (matching comment prefix)                 |
//+------------------------------------------------------------------+
void FindLastOrderTF(int tfIdx, ENUM_POSITION_TYPE side, string suffix1, string suffix2,
                     double &outPrice, datetime &outTime)
{
   string prefix = "GM_" + g_tfStates[tfIdx].tfLabel + "_";
   outPrice = 0;
   outTime = 0;
   datetime latestTime = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) != side) continue;

      string comment = PositionGetString(POSITION_COMMENT);
      if(StringFind(comment, prefix) < 0) continue;
      if(StringFind(comment, prefix + suffix1) >= 0 || StringFind(comment, prefix + suffix2) >= 0)
      {
         datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
         if(openTime > latestTime)
         {
            latestTime = openTime;
            outPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            outTime = openTime;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Close all positions for one side of one TF                         |
//+------------------------------------------------------------------+
void CloseAllSideTF(int tfIdx, ENUM_POSITION_TYPE side)
{
   string prefix = "GM_" + g_tfStates[tfIdx].tfLabel + "_";

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) != side) continue;
      if(StringFind(PositionGetString(POSITION_COMMENT), prefix) < 0) continue;
      trade.PositionClose(ticket);
   }

   if(side == POSITION_TYPE_BUY)
      g_tfStates[tfIdx].justClosedBuy = true;
   else
      g_tfStates[tfIdx].justClosedSell = true;
}

//+------------------------------------------------------------------+
//| Check Grid Loss for a specific TF                                  |
//+------------------------------------------------------------------+
void CheckGridLossTF(int tfIdx, ENUM_POSITION_TYPE side, int currentGridCount)
{
   if(currentGridCount >= GridLoss_MaxTrades) return;
   if(TotalOrderCount() >= MaxOpenOrders) return;

   // OnlyNewCandle check (per-TF)
   if(GridLoss_OnlyNewCandle)
   {
      datetime barTime = iTime(_Symbol, g_tfStates[tfIdx].tf, 0);
      if(barTime == g_tfStates[tfIdx].lastGridLossCandle) return;
   }

   // Find last order for this TF
   double lastPrice = 0;
   datetime lastTime = 0;
   FindLastOrderTF(tfIdx, side, "INIT", "GL", lastPrice, lastTime);

   // Fallback to TF initial price
   if(lastPrice == 0)
   {
      if(side == POSITION_TYPE_BUY && g_tfStates[tfIdx].initialBuyPrice > 0)
         lastPrice = g_tfStates[tfIdx].initialBuyPrice;
      else if(side == POSITION_TYPE_SELL && g_tfStates[tfIdx].initialSellPrice > 0)
         lastPrice = g_tfStates[tfIdx].initialSellPrice;
      else
         return;
   }

   // Same candle restriction
   if(GridLoss_DontSameCandle)
   {
      datetime barTime = iTime(_Symbol, g_tfStates[tfIdx].tf, 0);
      if(lastTime >= barTime) return;
   }

   // Copy ATR buffer for grid distance calculation (skip if using simplified ATR)
   if(handleATR_Loss != INVALID_HANDLE)
   {
      if(CopyBuffer(handleATR_Loss, 0, 0, 3, bufATR_Loss) < 3) return;
   }

   double distance = GetGridDistance(currentGridCount, true);
   if(distance <= 0) return;

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double currentPrice = (side == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   bool shouldOpen = false;

   if(GridLoss_GapType == GAP_ATR && GridLoss_ATR_Reference == ATR_REF_INITIAL)
   {
      double initialRef = (side == POSITION_TYPE_BUY) ? g_tfStates[tfIdx].initialBuyPrice : g_tfStates[tfIdx].initialSellPrice;
      if(initialRef <= 0) return;
      double totalDistance = distance * (currentGridCount + 1);
      if(side == POSITION_TYPE_BUY)
         shouldOpen = (currentPrice <= initialRef - totalDistance * point);
      else
         shouldOpen = (currentPrice >= initialRef + totalDistance * point);
   }
   else
   {
      if(side == POSITION_TYPE_BUY && currentPrice <= lastPrice - distance * point)
         shouldOpen = true;
      else if(side == POSITION_TYPE_SELL && currentPrice >= lastPrice + distance * point)
         shouldOpen = true;
   }

   if(shouldOpen)
   {
      double lots = CalculateGridLot(currentGridCount, true);
      
      //--- Ensure lot continues from max existing lot after matching close
      double maxExisting = FindMaxLotOnSide(side);
      if(maxExisting > 0 && lots <= maxExisting)
      {
         if(GridLoss_LotMode == LOT_MULTIPLY)
            lots = maxExisting * GridLoss_MultiplyFactor;
         else if(GridLoss_LotMode == LOT_ADD)
            lots = maxExisting + InitialLotSize * GridLoss_AddLotPerLevel;
         // LOT_CUSTOM: keep level-based calculation
      }
      
      string suffix = "GL#" + IntegerToString(currentGridCount + 1);
      ENUM_ORDER_TYPE orderType = (side == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      if(OpenOrderTF(tfIdx, orderType, lots, suffix))
      {
         g_tfStates[tfIdx].lastGridLossCandle = iTime(_Symbol, g_tfStates[tfIdx].tf, 0);
      }
   }
}

//+------------------------------------------------------------------+
//| Check Grid Profit for a specific TF                                |
//+------------------------------------------------------------------+
void CheckGridProfitTF(int tfIdx, ENUM_POSITION_TYPE side, int currentGridCount)
{
   if(currentGridCount >= GridProfit_MaxTrades) return;
   if(TotalOrderCount() >= MaxOpenOrders) return;

   if(GridProfit_OnlyNewCandle)
   {
      datetime barTime = iTime(_Symbol, g_tfStates[tfIdx].tf, 0);
      if(barTime == g_tfStates[tfIdx].lastGridProfitCandle) return;
   }

   double lastPrice = 0;
   datetime lastTime = 0;
   FindLastOrderTF(tfIdx, side, "INIT", "GP", lastPrice, lastTime);

   if(lastPrice == 0)
   {
      if(side == POSITION_TYPE_BUY && g_tfStates[tfIdx].initialBuyPrice > 0)
         lastPrice = g_tfStates[tfIdx].initialBuyPrice;
      else if(side == POSITION_TYPE_SELL && g_tfStates[tfIdx].initialSellPrice > 0)
         lastPrice = g_tfStates[tfIdx].initialSellPrice;
      else
         return;
   }

   if(handleATR_Profit != INVALID_HANDLE)
   {
      if(CopyBuffer(handleATR_Profit, 0, 0, 3, bufATR_Profit) < 3) return;
   }

   double distance = GetGridDistance(currentGridCount, false);
   if(distance <= 0) return;

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double currentPrice = (side == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   bool shouldOpen = false;

   if(GridProfit_GapType == GAP_ATR && GridProfit_ATR_Reference == ATR_REF_INITIAL)
   {
      double initialRef = (side == POSITION_TYPE_BUY) ? g_tfStates[tfIdx].initialBuyPrice : g_tfStates[tfIdx].initialSellPrice;
      if(initialRef <= 0) return;
      double totalDistance = distance * (currentGridCount + 1);
      if(side == POSITION_TYPE_BUY)
         shouldOpen = (currentPrice >= initialRef + totalDistance * point);
      else
         shouldOpen = (currentPrice <= initialRef - totalDistance * point);
   }
   else
   {
      if(side == POSITION_TYPE_BUY && currentPrice >= lastPrice + distance * point)
         shouldOpen = true;
      else if(side == POSITION_TYPE_SELL && currentPrice <= lastPrice - distance * point)
         shouldOpen = true;
   }

   if(shouldOpen)
   {
      double lots = CalculateGridLot(currentGridCount, false);
      string suffix = "GP#" + IntegerToString(currentGridCount + 1);
      ENUM_ORDER_TYPE orderType = (side == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      if(OpenOrderTF(tfIdx, orderType, lots, suffix))
      {
         g_tfStates[tfIdx].lastGridProfitCandle = iTime(_Symbol, g_tfStates[tfIdx].tf, 0);
      }
   }
}

//+------------------------------------------------------------------+
//| Manage TP/SL for a specific TF (basket per-TF)                     |
//+------------------------------------------------------------------+
void ManageTPSL_TF(int tfIdx)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);

   //--- BUY side
   double avgBuy = CalculateAveragePriceTF(tfIdx, POSITION_TYPE_BUY);
   if(avgBuy > 0)
   {
      double plBuy = CalculateFloatingPL_TF(tfIdx, POSITION_TYPE_BUY);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      bool closeTP = false;
      bool closeSL = false;

      if(!EnablePerOrderTrailing)
      {
         if(UseTP_Dollar && plBuy >= TP_DollarAmount) closeTP = true;
         if(UseTP_Points && bid >= avgBuy + TP_Points * point) closeTP = true;
         if(UseTP_PercentBalance && plBuy >= bal * TP_PercentBalance / 100.0) closeTP = true;
      }

      if(closeTP)
      {
         Print("TP HIT (", g_tfStates[tfIdx].tfLabel, " BUY): PL=", plBuy);
         CloseAllSideTF(tfIdx, POSITION_TYPE_BUY);
         g_tfStates[tfIdx].initialBuyPrice = 0;
         ResetTrailingStateTF(tfIdx);
         return;
      }

      if(EnableSL && !EnablePerOrderTrailing)
      {
         if(UseSL_Dollar && plBuy <= -SL_DollarAmount) closeSL = true;
         if(UseSL_Points && bid <= avgBuy - SL_Points * point) closeSL = true;
         if(UseSL_PercentBalance && plBuy <= -(bal * SL_PercentBalance / 100.0)) closeSL = true;

         if(closeSL)
         {
            if(SL_ActionMode == SL_CLOSE_ALL_STOP)
            {
               CloseAllPositions();
               g_eaStopped = true;
               Print("EA STOPPED by SL Action (", g_tfStates[tfIdx].tfLabel, " BUY)");
            }
            else
            {
               CloseAllSideTF(tfIdx, POSITION_TYPE_BUY);
               g_tfStates[tfIdx].initialBuyPrice = 0;
               ResetTrailingStateTF(tfIdx);
            }
            return;
         }
      }
   }

   //--- SELL side
   double avgSell = CalculateAveragePriceTF(tfIdx, POSITION_TYPE_SELL);
   if(avgSell > 0)
   {
      double plSell = CalculateFloatingPL_TF(tfIdx, POSITION_TYPE_SELL);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      bool closeTP2 = false;
      bool closeSL2 = false;

      if(!EnablePerOrderTrailing)
      {
         if(UseTP_Dollar && plSell >= TP_DollarAmount) closeTP2 = true;
         if(UseTP_Points && ask <= avgSell - TP_Points * point) closeTP2 = true;
         if(UseTP_PercentBalance && plSell >= bal * TP_PercentBalance / 100.0) closeTP2 = true;
      }

      if(closeTP2)
      {
         Print("TP HIT (", g_tfStates[tfIdx].tfLabel, " SELL): PL=", plSell);
         CloseAllSideTF(tfIdx, POSITION_TYPE_SELL);
         g_tfStates[tfIdx].initialSellPrice = 0;
         ResetTrailingStateTF(tfIdx);
         return;
      }

      if(EnableSL && !EnablePerOrderTrailing)
      {
         if(UseSL_Dollar && plSell <= -SL_DollarAmount) closeSL2 = true;
         if(UseSL_Points && ask >= avgSell + SL_Points * point) closeSL2 = true;
         if(UseSL_PercentBalance && plSell <= -(bal * SL_PercentBalance / 100.0)) closeSL2 = true;

         if(closeSL2)
         {
            if(SL_ActionMode == SL_CLOSE_ALL_STOP)
            {
               CloseAllPositions();
               g_eaStopped = true;
               Print("EA STOPPED by SL Action (", g_tfStates[tfIdx].tfLabel, " SELL)");
            }
            else
            {
               CloseAllSideTF(tfIdx, POSITION_TYPE_SELL);
               g_tfStates[tfIdx].initialSellPrice = 0;
               ResetTrailingStateTF(tfIdx);
            }
            return;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Manage Average-Based Trailing Stop for a specific TF               |
//+------------------------------------------------------------------+
void ManageTrailingStop_TF(int tfIdx)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   //--- BUY side
   double avgBuy = CalculateAveragePriceTF(tfIdx, POSITION_TYPE_BUY);
   if(avgBuy > 0)
   {
      double beLevel = avgBuy + BreakevenBuffer * point;

      if(EnableTrailingStop)
      {
         double trailAct = avgBuy + TrailingActivation * point;
         if(bid >= trailAct)
         {
            g_tfStates[tfIdx].trailActive_Buy = true;
            double newSL = bid - TrailingStep * point;
            newSL = MathMax(newSL, beLevel);
            if(newSL > g_tfStates[tfIdx].trailSL_Buy)
            {
               g_tfStates[tfIdx].trailSL_Buy = newSL;
               ApplyTrailingSL_TF(tfIdx, POSITION_TYPE_BUY, newSL);
            }
         }
      }

      if(EnableBreakeven && !g_tfStates[tfIdx].beDone_Buy)
      {
         double beAct = avgBuy + BreakevenActivation * point;
         if(bid >= beAct)
         {
            g_tfStates[tfIdx].beDone_Buy = true;
            if(g_tfStates[tfIdx].trailSL_Buy < beLevel)
            {
               g_tfStates[tfIdx].trailSL_Buy = beLevel;
               ApplyTrailingSL_TF(tfIdx, POSITION_TYPE_BUY, beLevel);
            }
         }
      }

      if(g_tfStates[tfIdx].trailActive_Buy && g_tfStates[tfIdx].trailSL_Buy > 0 && bid <= g_tfStates[tfIdx].trailSL_Buy)
      {
         Print("TRAILING SL HIT (", g_tfStates[tfIdx].tfLabel, " BUY): SL=", g_tfStates[tfIdx].trailSL_Buy);
         CloseAllSideTF(tfIdx, POSITION_TYPE_BUY);
         g_tfStates[tfIdx].initialBuyPrice = 0;
         ResetTrailingStateTF(tfIdx);
         return;
      }
   }
   else
   {
      g_tfStates[tfIdx].trailSL_Buy = 0;
      g_tfStates[tfIdx].trailActive_Buy = false;
      g_tfStates[tfIdx].beDone_Buy = false;
   }

   //--- SELL side
   double avgSell = CalculateAveragePriceTF(tfIdx, POSITION_TYPE_SELL);
   if(avgSell > 0)
   {
      double beLevelSell = avgSell - BreakevenBuffer * point;

      if(EnableTrailingStop)
      {
         double trailActSell = avgSell - TrailingActivation * point;
         if(ask <= trailActSell)
         {
            g_tfStates[tfIdx].trailActive_Sell = true;
            double newSL = ask + TrailingStep * point;
            newSL = MathMin(newSL, beLevelSell);
            if(g_tfStates[tfIdx].trailSL_Sell == 0 || newSL < g_tfStates[tfIdx].trailSL_Sell)
            {
               g_tfStates[tfIdx].trailSL_Sell = newSL;
               ApplyTrailingSL_TF(tfIdx, POSITION_TYPE_SELL, newSL);
            }
         }
      }

      if(EnableBreakeven && !g_tfStates[tfIdx].beDone_Sell)
      {
         double beActSell = avgSell - BreakevenActivation * point;
         if(ask <= beActSell)
         {
            g_tfStates[tfIdx].beDone_Sell = true;
            if(g_tfStates[tfIdx].trailSL_Sell == 0 || g_tfStates[tfIdx].trailSL_Sell > beLevelSell)
            {
               g_tfStates[tfIdx].trailSL_Sell = beLevelSell;
               ApplyTrailingSL_TF(tfIdx, POSITION_TYPE_SELL, beLevelSell);
            }
         }
      }

      if(g_tfStates[tfIdx].trailActive_Sell && g_tfStates[tfIdx].trailSL_Sell > 0 && ask >= g_tfStates[tfIdx].trailSL_Sell)
      {
         Print("TRAILING SL HIT (", g_tfStates[tfIdx].tfLabel, " SELL): SL=", g_tfStates[tfIdx].trailSL_Sell);
         CloseAllSideTF(tfIdx, POSITION_TYPE_SELL);
         g_tfStates[tfIdx].initialSellPrice = 0;
         ResetTrailingStateTF(tfIdx);
         return;
      }
   }
   else
   {
      g_tfStates[tfIdx].trailSL_Sell = 0;
      g_tfStates[tfIdx].trailActive_Sell = false;
      g_tfStates[tfIdx].beDone_Sell = false;
   }
}

//+------------------------------------------------------------------+
//| Apply trailing SL to positions of a TF side                        |
//+------------------------------------------------------------------+
void ApplyTrailingSL_TF(int tfIdx, ENUM_POSITION_TYPE side, double slPrice)
{
   string prefix = "GM_" + g_tfStates[tfIdx].tfLabel + "_";
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   slPrice = NormalizeDouble(slPrice, digits);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) != side) continue;
      if(StringFind(PositionGetString(POSITION_COMMENT), prefix) < 0) continue;

      double currentSL = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);

      if(side == POSITION_TYPE_BUY)
      {
         if(currentSL == 0 || slPrice > currentSL)
            trade.PositionModify(ticket, slPrice, tp);
      }
      else
      {
         if(currentSL == 0 || slPrice < currentSL)
            trade.PositionModify(ticket, slPrice, tp);
      }
   }
}

//+------------------------------------------------------------------+
//| Manage Shared Accumulate Close (ZigZag mode)                       |
//+------------------------------------------------------------------+
void ManageAccumulateShared()
{
   if(!UseAccumulateClose) return;

   //--- Auto-reset baseline when all positions are closed (cycle ended)
   int currentCount = TotalOrderCount();
   if(g_hadPositions && currentCount == 0)
   {
      g_accumulateBaseline = CalcTotalHistoryProfit();
      g_accumulatedProfit = 0;
      g_hadPositions = false;
      Print("Accumulate auto-reset (ZZ): no positions left. New baseline: ", g_accumulateBaseline);
      return;
   }
   if(currentCount > 0) g_hadPositions = true;

   double totalHistory = CalcTotalHistoryProfit();
   g_accumulatedProfit = totalHistory - g_accumulateBaseline;

   double totalFloating = CalculateTotalFloatingPL();
   double accumTotal = g_accumulatedProfit + totalFloating;

   if(accumTotal >= AccumulateTarget && accumTotal > 0)  // trigger on total (closed + floating)
   {
      Print("ACCUMULATE TARGET HIT: ", accumTotal, " / ", AccumulateTarget);
      CloseAllPositions();
      Sleep(500);
      double newHistory = CalcTotalHistoryProfit();
      g_accumulateBaseline = newHistory;
      g_accumulatedProfit = 0;
      g_hadPositions = false;

      // Reset all TF states
      for(int t = 0; t < g_activeTFCount; t++)
      {
         g_tfStates[t].initialBuyPrice = 0;
         g_tfStates[t].initialSellPrice = 0;
         ResetTrailingStateTF(t);
      }

      Print("Accumulate cycle reset (ZZ). New baseline: ", newHistory);
   }
}

//+------------------------------------------------------------------+
//| Main ZigZag MTF OnTick Handler                                     |
//+------------------------------------------------------------------+
void OnTickZigZagMTF()
{
   // Step 1: Update CDC (if enabled)
   if(InpUseCDCFilter) UpdateCDC();

   // Step 2: Check H4 ZigZag direction (only on new H4 bar)
   if(g_h4TFIndex >= 0)
   {
      datetime h4Bar = iTime(_Symbol, ZZ_ConfirmTF, 0);
      if(h4Bar != g_lastH4Bar)
      {
         g_lastH4Bar = h4Bar;
         string h4Swing = DetectZigZagSwing(g_h4TFIndex);
         if(h4Swing == "LOW") g_h4Direction = "BUY";
         else if(h4Swing == "HIGH") g_h4Direction = "SELL";
         // else keep previous direction
      }
   }

   // Step 3: Apply CDC filter to direction
   string effectiveDirection = g_h4Direction;
   if(InpUseCDCFilter && g_cdcReady)
   {
      if(effectiveDirection == "BUY" && g_cdcTrend == "BEARISH") effectiveDirection = "NONE";
      if(effectiveDirection == "SELL" && g_cdcTrend == "BULLISH") effectiveDirection = "NONE";
   }

   // Step 4: Process each enabled sub-TF
   for(int t = 0; t < g_activeTFCount; t++)
   {
      if(!g_tfStates[t].enabled) continue;

      datetime tfBar = iTime(_Symbol, g_tfStates[t].tf, 0);

      // Per-TF trailing (average-based, non per-order)
      if(!EnablePerOrderTrailing && (EnableTrailingStop || EnableBreakeven))
      {
         ManageTrailingStop_TF(t);
      }

      // Per-TF TP/SL
      ManageTPSL_TF(t);

      // Count positions for this TF
      int tfBuyCount = 0, tfSellCount = 0;
      int tfGLBuy = 0, tfGLSell = 0, tfGPBuy = 0, tfGPSell = 0;
      bool tfHasInitBuy = false, tfHasInitSell = false;
      CountPositionsTF(t, tfBuyCount, tfSellCount, tfGLBuy, tfGLSell, tfGPBuy, tfGPSell, tfHasInitBuy, tfHasInitSell);

      // Auto-detect broker-closed positions per TF
      if(tfBuyCount == 0 && g_tfStates[t].initialBuyPrice != 0)
      {
         Print(g_tfStates[t].tfLabel, " BUY cycle ended (broker). Resetting.");
         g_tfStates[t].initialBuyPrice = 0;
      }
      if(tfSellCount == 0 && g_tfStates[t].initialSellPrice != 0)
      {
         Print(g_tfStates[t].tfLabel, " SELL cycle ended (broker). Resetting.");
         g_tfStates[t].initialSellPrice = 0;
      }

      // Grid management
      if(!g_newOrderBlocked)
      {
         // Grid Loss
         if(!g_squeezeBuyBlocked && (tfHasInitBuy || g_tfStates[t].initialBuyPrice > 0) && tfGLBuy < GridLoss_MaxTrades && tfBuyCount > 0)
            CheckGridLossTF(t, POSITION_TYPE_BUY, tfGLBuy);
         if(!g_squeezeSellBlocked && (tfHasInitSell || g_tfStates[t].initialSellPrice > 0) && tfGLSell < GridLoss_MaxTrades && tfSellCount > 0)
            CheckGridLossTF(t, POSITION_TYPE_SELL, tfGLSell);

         // Grid Profit
         if(GridProfit_Enable)
         {
            if(!g_squeezeBuyBlocked && (tfHasInitBuy || g_tfStates[t].initialBuyPrice > 0) && tfGPBuy < GridProfit_MaxTrades && tfBuyCount > 0)
               CheckGridProfitTF(t, POSITION_TYPE_BUY, tfGPBuy);
            if(!g_squeezeSellBlocked && (tfHasInitSell || g_tfStates[t].initialSellPrice > 0) && tfGPSell < GridProfit_MaxTrades && tfSellCount > 0)
               CheckGridProfitTF(t, POSITION_TYPE_SELL, tfGPSell);
         }
      }

      // Entry check: sub-TF ZigZag must agree with H4 direction
      if(!g_newOrderBlocked && effectiveDirection != "NONE")
      {
         bool canOpenMore = TotalOrderCount() < MaxOpenOrders;
         bool canOpenThisCandle = !(DontOpenSameCandle && tfBar == g_tfStates[t].lastInitialCandle);

         // Detect sub-TF swing
         string subSwing = DetectZigZagSwing(t);

         // BUY entry
         if(!g_squeezeBuyBlocked && effectiveDirection == "BUY" && subSwing == "LOW" && tfBuyCount == 0
            && g_tfStates[t].initialBuyPrice == 0 && canOpenMore && canOpenThisCandle
            && (TradingMode == TRADE_BUY_ONLY || TradingMode == TRADE_BOTH))
         {
            bool shouldEnter = true;
            if(g_tfStates[t].justClosedBuy && !EnableAutoReEntry)
               shouldEnter = false;

            if(shouldEnter)
            {
               if(OpenOrderTF(t, ORDER_TYPE_BUY, InitialLotSize, "INIT"))
               {
                  g_tfStates[t].initialBuyPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                  g_tfStates[t].lastInitialCandle = tfBar;
                  ResetTrailingStateTF(t);
                  Print(g_tfStates[t].tfLabel, " ZigZag BUY INIT at ", g_tfStates[t].initialBuyPrice);
               }
            }
         }

         // SELL entry
         if(!g_squeezeSellBlocked && effectiveDirection == "SELL" && subSwing == "HIGH" && tfSellCount == 0
            && g_tfStates[t].initialSellPrice == 0 && canOpenMore && canOpenThisCandle
            && (TradingMode == TRADE_SELL_ONLY || TradingMode == TRADE_BOTH))
         {
            bool shouldEnter = true;
            if(g_tfStates[t].justClosedSell && !EnableAutoReEntry)
               shouldEnter = false;

            if(shouldEnter)
            {
               if(OpenOrderTF(t, ORDER_TYPE_SELL, InitialLotSize, "INIT"))
               {
                  g_tfStates[t].initialSellPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                  g_tfStates[t].lastInitialCandle = tfBar;
                  ResetTrailingStateTF(t);
                  Print(g_tfStates[t].tfLabel, " ZigZag SELL INIT at ", g_tfStates[t].initialSellPrice);
               }
            }
         }
      }

      // Reset justClosed flags when not blocked
      if(!g_newOrderBlocked)
      {
         g_tfStates[t].justClosedBuy = false;
         g_tfStates[t].justClosedSell = false;
      }
   }

   // Step 5: Matching Close (ZigZag mode - new bar already confirmed)
   if(UseMatchingClose)
      ManageMatchingClose();

   // Step 6: Shared Accumulate Close
   ManageAccumulateShared();
}

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ============== LICENSE MODULE (from v5.34) ===================== |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check if running in tester mode                                    |
//+------------------------------------------------------------------+
bool IsTesterMode()
{
   return (MQLInfoInteger(MQL_TESTER) || 
           MQLInfoInteger(MQL_OPTIMIZATION) ||
           MQLInfoInteger(MQL_VISUAL_MODE) ||
           MQLInfoInteger(MQL_FRAME_MODE));
}

//+------------------------------------------------------------------+
//| Initialize License System                                          |
//+------------------------------------------------------------------+
bool InitLicense(string baseUrl, int checkIntervalMinutes = 60, int syncIntervalMinutes = 5)
{
   g_licenseServerUrl = baseUrl;
   g_licenseCheckInterval = checkIntervalMinutes;
   g_dataSyncInterval = syncIntervalMinutes;
   g_lastLicenseCheck = 0;
   g_lastDataSync = 0;
   g_lastExpiryPopup = 0;
   
   if(StringLen(g_licenseServerUrl) == 0)
   {
      g_lastLicenseError = "License server URL is empty";
      g_licenseStatus = LICENSE_ERROR;
      return false;
   }
   
   g_licenseStatus = VerifyLicense();
   g_lastLicenseCheck = TimeCurrent();
   
   g_isLicenseValid = (g_licenseStatus == LICENSE_VALID || g_licenseStatus == LICENSE_EXPIRING_SOON);
   
   if(g_isLicenseValid)
   {
      SyncAccountData();
      g_lastDataSync = TimeCurrent();
   }
   
   return g_isLicenseValid;
}

//+------------------------------------------------------------------+
//| Verify License with Server                                         |
//+------------------------------------------------------------------+
ENUM_LICENSE_STATUS VerifyLicense()
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
//| Parse Verify License Response                                      |
//+------------------------------------------------------------------+
ENUM_LICENSE_STATUS ParseVerifyResponse(string response)
{
   bool valid = JsonGetBool(response, "valid");
   
   if(!valid)
   {
      string message = JsonGetString(response, "message");
      g_lastLicenseError = message;
      
      if(StringFind(message, "not found") >= 0 || StringFind(message, "Not found") >= 0)
         return LICENSE_NOT_FOUND;
      if(StringFind(message, "suspended") >= 0 || StringFind(message, "inactive") >= 0)
         return LICENSE_SUSPENDED;
      if(StringFind(message, "expired") >= 0 || StringFind(message, "Expired") >= 0)
         return LICENSE_EXPIRED;
      
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
//| Sync Account Data to Server (Legacy wrapper)                       |
//+------------------------------------------------------------------+
bool SyncAccountData()
{
   return SyncAccountDataWithEvent(SYNC_SCHEDULED);
}

//+------------------------------------------------------------------+
//| Sync Account Data with Event Type                                  |
//+------------------------------------------------------------------+
bool SyncAccountDataWithEvent(ENUM_SYNC_EVENT eventType)
{
   string url = g_licenseServerUrl + "/functions/v1/sync-account-data";
   
   long accountNumber = AccountInfoInteger(ACCOUNT_LOGIN);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   double floatingProfit = AccountInfoDouble(ACCOUNT_PROFIT);
   
   double drawdown = 0;
   if(balance > 0)
   {
      drawdown = ((balance - equity) / balance) * 100;
      if(drawdown < 0) drawdown = 0;
   }
   
   int openOrders = PositionsTotal();
   
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
   
   string eventTypeStr = "scheduled";
   if(eventType == SYNC_ORDER_OPEN) eventTypeStr = "order_open";
   else if(eventType == SYNC_ORDER_CLOSE) eventTypeStr = "order_close";
   
   string eaStatus = "working";
   if(g_licenseStatus == LICENSE_SUSPENDED) eaStatus = "suspended";
   else if(g_licenseStatus == LICENSE_EXPIRED) eaStatus = "expired";
   else if(g_licenseStatus == LICENSE_NOT_FOUND || g_licenseStatus == LICENSE_ERROR) eaStatus = "invalid";
   else if(!g_isLicenseValid) eaStatus = "paused";
   
   string accountCurrency = AccountInfoString(ACCOUNT_CURRENCY);
   
   ENUM_ACCOUNT_TRADE_MODE tradeMode = (ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
   string accountTypeStr = (tradeMode == ACCOUNT_TRADE_MODE_DEMO) ? "demo" : 
                           (tradeMode == ACCOUNT_TRADE_MODE_CONTEST) ? "contest" : "real";
   
   string json = "{";
   json += "\"account_number\":\"" + IntegerToString(accountNumber) + "\",";
   json += "\"balance\":" + DoubleToString(balance, 2) + ",";
   json += "\"equity\":" + DoubleToString(equity, 2) + ",";
   json += "\"margin_level\":" + DoubleToString(marginLevel, 2) + ",";
   json += "\"drawdown\":" + DoubleToString(drawdown, 2) + ",";
   json += "\"profit_loss\":" + DoubleToString(floatingProfit, 2) + ",";
   json += "\"open_orders\":" + IntegerToString(openOrders) + ",";
   json += "\"floating_pl\":" + DoubleToString(floatingProfit, 2) + ",";
   json += "\"total_profit\":" + DoubleToString(totalProfit, 2) + ",";
   json += "\"initial_balance\":" + DoubleToString(initialBalance, 2) + ",";
   json += "\"total_deposit\":" + DoubleToString(totalDeposit, 2) + ",";
   json += "\"total_withdrawal\":" + DoubleToString(totalWithdrawal, 2) + ",";
   json += "\"max_drawdown\":" + DoubleToString(maxDrawdown, 2) + ",";
   json += "\"win_trades\":" + IntegerToString(winTrades) + ",";
   json += "\"loss_trades\":" + IntegerToString(lossTrades) + ",";
   json += "\"total_trades\":" + IntegerToString(totalTrades) + ",";
   json += "\"event_type\":\"" + eventTypeStr + "\",";
   json += "\"ea_name\":\"Gold Miner EA\",";
   json += "\"ea_status\":\"" + eaStatus + "\",";
   json += "\"currency\":\"" + accountCurrency + "\",";
   json += "\"account_type\":\"" + accountTypeStr + "\"";
   
   string tradeHistoryJson = BuildTradeHistoryJson();
   if(StringLen(tradeHistoryJson) > 2)
   {
      json += ",\"trade_history\":" + tradeHistoryJson;
   }
   
   json += "}";
   
   string response = "";
   int httpCode = SendLicenseRequest(url, json, response);
   
   if(httpCode != 200)
   {
      g_lastLicenseError = "Sync HTTP Error: " + IntegerToString(httpCode);
      Print("[Sync] HTTP Error: ", httpCode);
      return false;
   }
   
   bool success = JsonGetBool(response, "success");
   if(success)
   {
      Print("[Sync] Data synced successfully (event: ", eventTypeStr, ")");
   }
   
   return success;
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
//| Build Trade History JSON Array                                     |
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
         
         if(!first) json += ",";
         first = false;
         
         json += "{";
         json += "\"deal_ticket\":" + IntegerToString(dealTicket) + ",";
         json += "\"order_ticket\":" + IntegerToString(orderTicket) + ",";
         json += "\"symbol\":\"" + symbol + "\",";
         json += "\"deal_type\":\"" + dealTypeStr + "\",";
         json += "\"entry_type\":\"" + entryTypeStr + "\",";
         json += "\"volume\":" + DoubleToString(volume, 2) + ",";
         json += "\"open_price\":" + DoubleToString(price, 5) + ",";
         json += "\"profit\":" + DoubleToString(profit, 2) + ",";
         json += "\"swap\":" + DoubleToString(swap, 2) + ",";
         json += "\"commission\":" + DoubleToString(commission, 2) + ",";
         json += "\"sl\":" + DoubleToString(sl, 5) + ",";
         json += "\"tp\":" + DoubleToString(tp, 5) + ",";
         json += "\"comment\":\"" + comment + "\",";
         json += "\"magic_number\":" + IntegerToString(magic) + ",";
         json += "\"close_time\":\"" + TimeToString(dealTime, TIME_DATE|TIME_SECONDS) + "\"";
         json += "}";
      }
   }
   
   json += "]";
   return json;
}

//+------------------------------------------------------------------+
//| OnTradeTransaction - Real-time sync on order events                |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   if(!g_isLicenseValid) return;
   if(MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_OPTIMIZATION)) return;
   
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      if(HistoryDealSelect(trans.deal))
      {
         ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
         long dealMagic = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
         
         if(dealMagic == MagicNumber || dealMagic == 0)
         {
            if(dealEntry == DEAL_ENTRY_IN)
            {
               Print("[Sync] Order opened - syncing data...");
               SyncAccountDataWithEvent(SYNC_ORDER_OPEN);
            }
            else if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_INOUT)
            {
               Print("[Sync] Order closed - syncing data with trade history...");
               SyncAccountDataWithEvent(SYNC_ORDER_CLOSE);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| OnTick License Handler                                             |
//+------------------------------------------------------------------+
bool OnTickLicense()
{
   datetime currentTime = TimeCurrent();
   
   if(currentTime - g_lastLicenseCheck >= g_licenseCheckInterval * 60)
   {
      ENUM_LICENSE_STATUS newStatus = VerifyLicense();
      g_lastLicenseCheck = currentTime;
      
      if(newStatus != g_licenseStatus)
      {
         g_licenseStatus = newStatus;
         g_isLicenseValid = (newStatus == LICENSE_VALID || newStatus == LICENSE_EXPIRING_SOON);
         
         if(!g_isLicenseValid)
         {
            ShowLicensePopup(g_licenseStatus);
         }
      }
      
      if(g_licenseStatus == LICENSE_EXPIRING_SOON)
      {
         datetime today = currentTime - (currentTime % 86400);
         if(g_lastExpiryPopup < today)
         {
            ShowLicensePopup(g_licenseStatus);
            g_lastExpiryPopup = currentTime;
         }
      }
   }
   
   if(g_isLicenseValid && (currentTime - g_lastDataSync >= g_dataSyncInterval * 60))
   {
      SyncAccountData();
      g_lastDataSync = currentTime;
   }
   
   return g_isLicenseValid;
}

//+------------------------------------------------------------------+
//| Show License Status Popup                                          |
//+------------------------------------------------------------------+
void ShowLicensePopup(ENUM_LICENSE_STATUS status)
{
   string title = "Gold Miner EA - License";
   string message = "";
   uint flags = MB_OK;
   
   switch(status)
   {
      case LICENSE_VALID:
      {
         message = "License Verified Successfully!\n\n";
         message += "Customer: " + g_customerName + "\n";
         message += "Package: " + g_packageType + "\n";
         message += "System: " + g_tradingSystem + "\n\n";
         if(g_isLifetime)
            message += "License Type: LIFETIME\n";
         else
            message += "Expires: " + TimeToString(g_expiryDate, TIME_DATE) + "\n";
         message += "\nHappy Trading!";
         flags = MB_OK | MB_ICONINFORMATION;
         break;
      }
      case LICENSE_EXPIRING_SOON:
      {
         message = "License Expiring Soon!\n\n";
         message += "Customer: " + g_customerName + "\n";
         message += "Days Remaining: " + IntegerToString(g_daysRemaining) + " days\n";
         message += "Expires: " + TimeToString(g_expiryDate, TIME_DATE) + "\n\n";
         message += "Please renew your license to continue using.\n";
         message += "Contact: support@moneyx-smart.com";
         flags = MB_OK | MB_ICONWARNING;
         break;
      }
      case LICENSE_EXPIRED:
      {
         message = "License Expired!\n\n";
         message += "Your license has expired.\n";
         message += "Trading is disabled.\n\n";
         message += "Please renew your license to continue.\n";
         message += "Contact: support@moneyx-smart.com";
         flags = MB_OK | MB_ICONERROR;
         break;
      }
      case LICENSE_NOT_FOUND:
      {
         message = "Account Not Registered!\n\n";
         message += "Account: " + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "\n\n";
         message += "This account is not registered in our system.\n";
         message += "Please purchase a license to use this EA.\n\n";
         message += "Contact: support@moneyx-smart.com";
         flags = MB_OK | MB_ICONERROR;
         break;
      }
      case LICENSE_SUSPENDED:
      {
         message = "License Suspended!\n\n";
         message += "Your license has been suspended.\n";
         message += "Trading is disabled.\n\n";
         message += "Please contact support for assistance.\n";
         message += "Contact: support@moneyx-smart.com";
         flags = MB_OK | MB_ICONERROR;
         break;
      }
      case LICENSE_ERROR:
      {
         message = "License Verification Error!\n\n";
         message += "Could not verify license.\n";
         message += "Error: " + g_lastLicenseError + "\n\n";
         message += "Please check:\n";
         message += "1. Internet connection\n";
         message += "2. WebRequest allowed for:\n";
         message += "   " + g_licenseServerUrl + "\n\n";
         message += "EA will retry on next check.";
         flags = MB_OK | MB_ICONWARNING;
         break;
      }
   }
   
   MessageBox(message, title, flags);
}

//+------------------------------------------------------------------+
//| Send HTTP POST Request                                             |
//+------------------------------------------------------------------+
int SendLicenseRequest(string url, string jsonData, string &response)
{
   char postData[];
   char result[];
   string headers = "Content-Type: application/json\r\nx-api-key: " + EA_API_SECRET + "\r\n";
   string resultHeaders;
   
   StringToCharArray(jsonData, postData, 0, StringLen(jsonData));
   ArrayResize(postData, StringLen(jsonData));
   
   int timeout = 10000;
   int httpCode = WebRequest("POST", url, headers, timeout, postData, result, resultHeaders);
   
   if(httpCode == -1)
   {
      int errorCode = GetLastError();
      g_lastLicenseError = "WebRequest failed. Error: " + IntegerToString(errorCode);
      
      if(errorCode == 4014)
      {
         g_lastLicenseError = "WebRequest not allowed. Add URL to allowed list:\n" + 
                       "Tools -> Options -> Expert Advisors -> Allow WebRequest for listed URL\n" +
                       "Add: " + g_licenseServerUrl;
      }
      
      return -1;
   }
   
   response = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
   
   return httpCode;
}

//+------------------------------------------------------------------+
//| JSON Helper - Get String Value                                     |
//+------------------------------------------------------------------+
string JsonGetString(string json, string key)
{
   string searchKey = "\"" + key + "\":";
   int keyPos = StringFind(json, searchKey);
   
   if(keyPos < 0)
      return "";
   
   int valueStart = keyPos + StringLen(searchKey);
   
   while(valueStart < StringLen(json) && (StringGetCharacter(json, valueStart) == ' ' || 
                                           StringGetCharacter(json, valueStart) == '\t'))
   {
      valueStart++;
   }
   
   if(StringSubstr(json, valueStart, 4) == "null")
      return "";
   
   if(StringGetCharacter(json, valueStart) == '"')
   {
      valueStart++;
      int valueEnd = StringFind(json, "\"", valueStart);
      if(valueEnd < 0)
         return "";
      return StringSubstr(json, valueStart, valueEnd - valueStart);
   }
   
   int valueEnd = valueStart;
   while(valueEnd < StringLen(json))
   {
      ushort ch = StringGetCharacter(json, valueEnd);
      if(ch == ',' || ch == '}' || ch == ']')
         break;
      valueEnd++;
   }
   
   return StringSubstr(json, valueStart, valueEnd - valueStart);
}

//+------------------------------------------------------------------+
//| JSON Helper - Get Integer Value                                    |
//+------------------------------------------------------------------+
int JsonGetInt(string json, string key)
{
   string value = JsonGetString(json, key);
   if(StringLen(value) == 0)
      return 0;
   return (int)StringToInteger(value);
}

//+------------------------------------------------------------------+
//| JSON Helper - Get Boolean Value                                    |
//+------------------------------------------------------------------+
bool JsonGetBool(string json, string key)
{
   string value = JsonGetString(json, key);
   return (value == "true" || value == "1");
}

//+------------------------------------------------------------------+
//| ============== NEWS FILTER MODULE (from v5.34) ================= |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Chart Base Currency (e.g., XAUUSD -> XAU)                      |
//+------------------------------------------------------------------+
string GetChartBaseCurrency()
{
   string symbol = _Symbol;
   if(StringLen(symbol) >= 6)
      return StringSubstr(symbol, 0, 3);
   return "";
}

//+------------------------------------------------------------------+
//| Get Chart Quote Currency (e.g., XAUUSD -> USD)                     |
//+------------------------------------------------------------------+
string GetChartQuoteCurrency()
{
   string symbol = _Symbol;
   if(StringLen(symbol) >= 6)
      return StringSubstr(symbol, 3, 3);
   return "";
}

//+------------------------------------------------------------------+
//| Check if Currency is Relevant for News Filter                      |
//+------------------------------------------------------------------+
bool IsCurrencyRelevant(string newsCurrency)
{
   if(InpNewsUseChartCurrency)
   {
      string baseCurrency = GetChartBaseCurrency();
      string quoteCurrency = GetChartQuoteCurrency();
      
      if(newsCurrency == baseCurrency || newsCurrency == quoteCurrency)
         return true;
      return false;
   }
   
   string currencies = InpNewsCurrencies;
   if(StringLen(currencies) == 0)
      return false;
   
   string currencyList[];
   int count = StringSplit(currencies, ';', currencyList);
   
   for(int i = 0; i < count; i++)
   {
      string curr = currencyList[i];
      StringTrimLeft(curr);
      StringTrimRight(curr);
      if(curr == newsCurrency)
         return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if News Title Matches Custom Keywords                        |
//+------------------------------------------------------------------+
bool IsCustomNewsMatch(string newsTitle)
{
   if(!InpFilterCustomNews)
      return false;
   
   string keywords = InpCustomNewsKeywords;
   if(StringLen(keywords) == 0)
      return false;
   
   string keywordList[];
   int count = StringSplit(keywords, ';', keywordList);
   
   string upperTitle = newsTitle;
   StringToUpper(upperTitle);
   
   for(int i = 0; i < count; i++)
   {
      string keyword = keywordList[i];
      StringTrimLeft(keyword);
      StringTrimRight(keyword);
      StringToUpper(keyword);
      
      if(StringLen(keyword) > 0 && StringFind(upperTitle, keyword) >= 0)
         return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Extract text from JSON element                                     |
//+------------------------------------------------------------------+
string ExtractJSONValue(string json, string key)
{
   string quote = "\"";
   string searchKey = quote + key + quote + ":";
   int startPos = StringFind(json, searchKey);
   if(startPos < 0) return "";

   startPos += StringLen(searchKey);

   while(startPos < StringLen(json) && StringSubstr(json, startPos, 1) == " ")
      startPos++;

   if(startPos >= StringLen(json)) return "";

   string firstChar = StringSubstr(json, startPos, 1);
   string value = "";

   if(firstChar == quote)
   {
      startPos++;
      int endPos = StringFind(json, quote, startPos);
      if(endPos < 0) return "";
      value = StringSubstr(json, startPos, endPos - startPos);
      StringReplace(value, "\\/", "/");
      StringReplace(value, "\\\"", "\"");
      StringReplace(value, "\\n", "\n");
   }
   else
   {
      int endPos = startPos;
      while(endPos < StringLen(json))
      {
         string c = StringSubstr(json, endPos, 1);
         if(c == "," || c == "}" || c == "]")
            break;
         endPos++;
      }
      value = StringSubstr(json, startPos, endPos - startPos);
   }

   StringTrimLeft(value);
   StringTrimRight(value);

   return value;
}

//+------------------------------------------------------------------+
//| Check if WebRequest is properly configured                         |
//+------------------------------------------------------------------+
bool CheckWebRequestConfiguration()
{
   if(!InpEnableNewsFilter)
   {
      g_webRequestConfigured = true;
      return true;
   }
   
   Print("NEWS FILTER: Checking WebRequest configuration...");
   
   string testUrl = InpLicenseServer + "/functions/v1/economic-news?limit=1";
   char postData[], resultData[];
   string headers = "";
   string resultHeaders;
   int timeout = 5000;
   
   ResetLastError();
   
   int result = WebRequest("GET", testUrl, headers, timeout, postData, resultData, resultHeaders);
   
   if(result == -1)
   {
      int error = GetLastError();
      
      if(error == 4060)
      {
         Print("NEWS FILTER ERROR [4060]: WebRequest is NOT enabled in MT5 settings!");
         g_webRequestConfigured = false;
         return false;
      }
      else if(error == 4024)
      {
         Print("NEWS FILTER ERROR [4024]: URL is NOT in the allowed WebRequest list!");
         g_webRequestConfigured = false;
         return false;
      }
      else
      {
         Print("NEWS FILTER ERROR [", error, "]: WebRequest failed - possibly network issue");
         if(error == 5203 || error == 5200 || error == 5201)
         {
            Print("NEWS FILTER: Network error detected - WebRequest is configured, will retry in RefreshNewsData");
            g_webRequestConfigured = true;
            return true;
         }
         Print("NEWS FILTER: Unknown error - will retry later");
         return g_webRequestConfigured;
      }
   }
   
   g_webRequestConfigured = true;
   Print("NEWS FILTER: WebRequest is properly configured!");
   return true;
}

//+------------------------------------------------------------------+
//| Show WebRequest Setup Alert with Instructions                      |
//+------------------------------------------------------------------+
void ShowWebRequestSetupAlert()
{
   string alertTitle = "NEWS FILTER: WebRequest Configuration Required!";
   
   string alertMessage = 
      "News Filter cannot fetch data because WebRequest is not configured.\n\n"
      "Please configure WebRequest:\n\n"
      "1. Open MT5 -> Tools -> Options\n"
      "   (or press Ctrl+O)\n\n"
      "2. Go to 'Expert Advisors' tab\n\n"
      "3. Enable 'Allow WebRequest for listed URL:'\n\n"
      "4. Click 'Add new URL' and add:\n"
      "   " + InpLicenseServer + "\n\n"
      "5. Click OK and RESTART EA\n\n"
      "URL Required: " + InpLicenseServer;
   
   MessageBox(alertMessage, alertTitle, 0x30);
   
   Print("========================================");
   Print("NEWS FILTER: WebRequest NOT CONFIGURED!");
   Print("URL Required: ", InpLicenseServer);
   Print("========================================");
}

//+------------------------------------------------------------------+
//| Fetch and Parse News Data                                          |
//+------------------------------------------------------------------+
void RefreshNewsData()
{
   if(!InpEnableNewsFilter)
      return;
   
   datetime currentTime = TimeCurrent();
   
   if(!g_forceNewsRefresh && g_lastNewsRefresh > 0 && (currentTime - g_lastNewsRefresh) < 3600)
      return;
   
   g_forceNewsRefresh = false;
   
   Print("NEWS FILTER: Refreshing news data from MoneyX API...");
   
   MqlDateTime dt;
   TimeToStruct(currentTime, dt);
   
   string currencies = "";
   if(InpNewsUseChartCurrency)
   {
      string sym = Symbol();
      if(StringLen(sym) >= 6)
      {
         currencies = StringSubstr(sym, 0, 3) + "," + StringSubstr(sym, 3, 3);
      }
   }
   else
   {
      currencies = InpNewsCurrencies;
      StringReplace(currencies, ";", ",");
   }
   
   string impacts = "";
   bool hasCustomKeywords = InpFilterCustomNews && StringLen(InpCustomNewsKeywords) > 0;
   
   if(!hasCustomKeywords)
   {
      if(InpFilterHighNews) impacts += "High,";
      if(InpFilterMedNews) impacts += "Medium,";
      if(InpFilterLowNews) impacts += "Low,";
      if(StringLen(impacts) > 0)
         impacts = StringSubstr(impacts, 0, StringLen(impacts) - 1);
   }
   
   string apiUrl = InpLicenseServer + "/functions/v1/economic-news?ts=" + IntegerToString((long)currentTime);
   if(StringLen(currencies) > 0)
      apiUrl += "&currency=" + currencies;
   if(StringLen(impacts) > 0)
      apiUrl += "&impact=" + impacts;
   
   if(hasCustomKeywords)
      Print("NEWS FILTER: Custom Keywords active - fetching ALL impact levels");
   
   char postData[], resultData[];
   string headers = "User-Agent: MoneyX-EA/2.8\r\nAccept: application/json\r\nConnection: close";
   string resultHeaders;
   
   int timeout = 10000;
   
   Print("NEWS FILTER: Fetching from ", apiUrl);
   
   int result = WebRequest("GET", apiUrl, headers, timeout, postData, resultData, resultHeaders);
   
   if(result == -1)
   {
      int firstError = GetLastError();
      Print("NEWS FILTER: First attempt failed (error ", firstError, "), retrying after 1 second...");
      Sleep(1000);
      ResetLastError();
      result = WebRequest("GET", apiUrl, headers, timeout, postData, resultData, resultHeaders);
   }
   
   if(result == -1)
   {
      int error = GetLastError();
      Print("NEWS FILTER ERROR: WebRequest failed - Error ", error);
      
      if(error == 4060 || error == 4024)
      {
         g_webRequestConfigured = false;
      }
      
      if(g_newsEventCount > 0)
      {
         g_usingCachedNews = true;
         Print("NEWS FILTER: Using cached data (", g_newsEventCount, " events from ", TimeToString(g_lastGoodNewsTime), ")");
      }
      g_lastNewsRefresh = currentTime - 3300;
      return;
   }
   
   if(result != 200)
   {
      Print("NEWS FILTER ERROR: HTTP ", result, " - Server returned error");
      if(g_newsEventCount > 0)
      {
         g_usingCachedNews = true;
         Print("NEWS FILTER: Using cached data (", g_newsEventCount, " events)");
      }
      g_lastNewsRefresh = currentTime - 3300;
      return;
   }
   
   int responseSize = ArraySize(resultData);
   
   string jsonContent = CharArrayToString(resultData, 0, WHOLE_ARRAY, CP_UTF8);
   
   if(responseSize < 10)
   {
      Print("NEWS FILTER WARNING: Response too short (", responseSize, " bytes)");
      if(g_newsEventCount > 0)
      {
         g_usingCachedNews = true;
      }
      return;
   }
   
   string trimmedContent = jsonContent;
   StringTrimLeft(trimmedContent);
   
   if(StringSubstr(trimmedContent, 0, 1) != "{")
   {
      Print("NEWS FILTER WARNING: Response is not a JSON object!");
      if(g_newsEventCount > 0)
      {
         g_usingCachedNews = true;
      }
      return;
   }
   
   string successValue = ExtractJSONValue(jsonContent, "success");
   if(successValue != "true")
   {
      string errorMsg = ExtractJSONValue(jsonContent, "error");
      Print("NEWS FILTER ERROR: API returned error: ", errorMsg);
      if(g_newsEventCount > 0)
      {
         g_usingCachedNews = true;
      }
      return;
   }
   
   NewsEvent tmpEvents[];
   int tmpEventCount = 0;
   ArrayResize(tmpEvents, 100);
   
   int dataStart = StringFind(jsonContent, "\"data\":", 0);
   if(dataStart < 0)
   {
      Print("NEWS FILTER WARNING: No data array found in response!");
      if(g_newsEventCount > 0)
      {
         g_usingCachedNews = true;
      }
      return;
   }
   
   int arrayStart = StringFind(jsonContent, "[", dataStart);
   if(arrayStart < 0)
   {
      Print("NEWS FILTER WARNING: Data array not found!");
      if(g_newsEventCount > 0)
      {
         g_usingCachedNews = true;
      }
      return;
   }
   
   int searchPos = arrayStart + 1;
   int eventCount = 0;
   
   int firstBrace = StringFind(jsonContent, "{", searchPos);
   if(firstBrace < 0)
   {
      Print("NEWS FILTER: No news events for current filters (empty data array)");
      g_lastNewsRefresh = currentTime;
      
      if(g_newsEventCount > 0)
      {
         g_usingCachedNews = true;
         Print("NEWS FILTER: Keeping cached data (", g_newsEventCount, " events)");
      }
      else
      {
         g_usingCachedNews = false;
      }
      return;
   }
   
   searchPos = firstBrace;
   
   while(searchPos < StringLen(jsonContent))
   {
      int braceDepth = 0;
      int objStart = searchPos;
      int objEnd = -1;
      
      for(int i = searchPos; i < StringLen(jsonContent); i++)
      {
         string c = StringSubstr(jsonContent, i, 1);
         if(c == "{") braceDepth++;
         else if(c == "}")
         {
            braceDepth--;
            if(braceDepth == 0)
            {
               objEnd = i;
               break;
            }
         }
         else if(c == "]" && braceDepth == 0)
         {
            break;
         }
      }
      
      if(objEnd < 0) break;
      
      string eventJson = StringSubstr(jsonContent, objStart, objEnd - objStart + 1);
      
      string title = ExtractJSONValue(eventJson, "title");
      string currency = ExtractJSONValue(eventJson, "currency");
      string timestampStr = ExtractJSONValue(eventJson, "timestamp");
      string impact = ExtractJSONValue(eventJson, "impact");
      
      eventCount++;
      
      datetime eventTime = (datetime)StringToInteger(timestampStr);
      
      if(impact == "Holiday")
      {
         searchPos = objEnd + 1;
         continue;
      }
      
      bool isRelevant = false;
      
      if(IsCurrencyRelevant(currency))
      {
         if(InpFilterHighNews && impact == "High")
            isRelevant = true;
         else if(InpFilterMedNews && impact == "Medium")
            isRelevant = true;
         else if(InpFilterLowNews && impact == "Low")
            isRelevant = true;
         
         if(IsCustomNewsMatch(title))
            isRelevant = true;
      }
      
      if(tmpEventCount < ArraySize(tmpEvents))
      {
         tmpEvents[tmpEventCount].title = title;
         tmpEvents[tmpEventCount].country = currency;
         tmpEvents[tmpEventCount].time = eventTime;
         tmpEvents[tmpEventCount].impact = impact;
         tmpEvents[tmpEventCount].isRelevant = isRelevant;
         tmpEventCount++;
      }
      
      searchPos = objEnd + 1;
   }
   
   Print("NEWS FILTER: Parsed ", eventCount, " total events, stored ", tmpEventCount, " events");
   
   if(tmpEventCount > 0)
   {
      ArrayResize(g_newsEvents, tmpEventCount);
      for(int i = 0; i < tmpEventCount; i++)
      {
         g_newsEvents[i] = tmpEvents[i];
      }
      g_newsEventCount = tmpEventCount;
      
      g_lastNewsRefresh = currentTime;
      g_lastGoodNewsTime = currentTime;
      g_usingCachedNews = false;
      
      Print("NEWS FILTER: Successfully loaded ", g_newsEventCount, " events (FRESH DATA)");
      
      SaveNewsCacheToFile();
   }
   else
   {
      Print("NEWS FILTER: API returned 0 events (no relevant news for current filters)");
      g_lastNewsRefresh = currentTime;
      if(g_newsEventCount > 0)
      {
         g_usingCachedNews = true;
      }
      else
      {
         g_usingCachedNews = false;
      }
   }
}

//+------------------------------------------------------------------+
//| Save News Cache to File for Persistence                            |
//+------------------------------------------------------------------+
void SaveNewsCacheToFile()
{
   if(g_newsEventCount == 0)
      return;
   
   int handle = FileOpen(g_newsCacheFile, FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(handle == INVALID_HANDLE)
   {
      Print("NEWS FILTER: Cannot save cache file - ", GetLastError());
      return;
   }
   
   FileWriteString(handle, "# GoldMiner News Cache - " + TimeToString(TimeCurrent()) + "\n");
   FileWriteString(handle, "# Count: " + IntegerToString(g_newsEventCount) + "\n");
   
   for(int i = 0; i < g_newsEventCount; i++)
   {
      string line = g_newsEvents[i].title + "|" + 
                    g_newsEvents[i].country + "|" +
                    IntegerToString((long)g_newsEvents[i].time) + "|" +
                    g_newsEvents[i].impact + "|" +
                    (g_newsEvents[i].isRelevant ? "1" : "0") + "\n";
      FileWriteString(handle, line);
   }
   
   FileClose(handle);
   g_lastFileCacheSave = TimeCurrent();
   Print("NEWS FILTER: Saved ", g_newsEventCount, " events to cache file");
}

//+------------------------------------------------------------------+
//| Load News Cache from File                                          |
//+------------------------------------------------------------------+
void LoadNewsCacheFromFile()
{
   if(!FileIsExist(g_newsCacheFile))
   {
      Print("NEWS FILTER: No cache file found (first run)");
      return;
   }
   
   int handle = FileOpen(g_newsCacheFile, FILE_READ | FILE_TXT | FILE_ANSI);
   if(handle == INVALID_HANDLE)
   {
      Print("NEWS FILTER: Cannot read cache file - ", GetLastError());
      return;
   }
   
   ArrayResize(g_newsEvents, 100);
   g_newsEventCount = 0;
   
   while(!FileIsEnding(handle))
   {
      string line = FileReadString(handle);
      
      if(StringSubstr(line, 0, 1) == "#")
         continue;
      
      string parts[];
      int partCount = StringSplit(line, '|', parts);
      
      if(partCount >= 5 && g_newsEventCount < ArraySize(g_newsEvents))
      {
         g_newsEvents[g_newsEventCount].title = parts[0];
         g_newsEvents[g_newsEventCount].country = parts[1];
         g_newsEvents[g_newsEventCount].time = (datetime)StringToInteger(parts[2]);
         g_newsEvents[g_newsEventCount].impact = parts[3];
         g_newsEvents[g_newsEventCount].isRelevant = (parts[4] == "1");
         g_newsEventCount++;
      }
   }
   
   FileClose(handle);
   
   if(g_newsEventCount > 0)
   {
      g_usingCachedNews = true;
      Print("NEWS FILTER: Loaded ", g_newsEventCount, " events from cache file");
   }
}

//+------------------------------------------------------------------+
//| Get Pause Duration for News Impact Level                           |
//+------------------------------------------------------------------+
void GetNewsPauseDuration(string impact, bool isCustomMatch, int &beforeMin, int &afterMin)
{
   beforeMin = 0;
   afterMin = 0;
   
   int customBefore = 0, customAfter = 0;
   int impactBefore = 0, impactAfter = 0;
   
   if(isCustomMatch && InpFilterCustomNews)
   {
      customBefore = InpPauseBeforeCustom;
      customAfter = InpPauseAfterCustom;
   }
   
   if(impact == "High" && InpFilterHighNews)
   {
      impactBefore = InpPauseBeforeHigh;
      impactAfter = InpPauseAfterHigh;
   }
   else if(impact == "Medium" && InpFilterMedNews)
   {
      impactBefore = InpPauseBeforeMed;
      impactAfter = InpPauseAfterMed;
   }
   else if(impact == "Low" && InpFilterLowNews)
   {
      impactBefore = InpPauseBeforeLow;
      impactAfter = InpPauseAfterLow;
   }
   
   int customTotal = customBefore + customAfter;
   int impactTotal = impactBefore + impactAfter;
   
   if(customTotal >= impactTotal && customTotal > 0)
   {
      beforeMin = customBefore;
      afterMin = customAfter;
   }
   else if(impactTotal > 0)
   {
      beforeMin = impactBefore;
      afterMin = impactAfter;
   }
}

//+------------------------------------------------------------------+
//| Check whether an event is relevant using CURRENT filter settings   |
//+------------------------------------------------------------------+
bool IsEventRelevantNow(const NewsEvent &ev)
{
   if(!IsCurrencyRelevant(ev.country))
      return false;

   if(InpFilterCustomNews && IsCustomNewsMatch(ev.title))
      return true;

   if(InpFilterHighNews && ev.impact == "High")
      return true;

   if(InpFilterMedNews && ev.impact == "Medium")
      return true;

   if(InpFilterLowNews && ev.impact == "Low")
      return true;

   return false;
}

//+------------------------------------------------------------------+
//| Check if Currently in News Pause Window                            |
//+------------------------------------------------------------------+
bool IsNewsTimePaused()
{
   if(!InpEnableNewsFilter)
   {
      g_isNewsPaused = false;
      g_newsStatus = "OFF";
      if(g_lastPausedState)
      {
         g_lastPausedState = false;
         g_lastPauseKey = "";
      }
      return false;
   }
   
   datetime currentTime = TimeCurrent();
   
   bool foundPause = false;
   string pauseKey = "";
   g_nextNewsTitle = "";
   g_nextNewsTime = 0;
   
   datetime closestNewsTime = 0;
   string closestNewsTitle = "";
   int closestBeforeMin = 0;
   int closestAfterMin = 0;
   
   datetime earliestPauseEnd = 0;
   string earliestNewsTitle = "";
   datetime earliestNewsTime = 0;
   string earliestCountry = "";
   string earliestImpact = "";
   
   for(int i = 0; i < g_newsEventCount; i++)
   {
      if(!IsEventRelevantNow(g_newsEvents[i]))
         continue;

      datetime newsTime = g_newsEvents[i].time;
      string impact = g_newsEvents[i].impact;
      bool isCustom = IsCustomNewsMatch(g_newsEvents[i].title);
      
      int beforeMin, afterMin;
      GetNewsPauseDuration(impact, isCustom, beforeMin, afterMin);
      
      if(beforeMin == 0 && afterMin == 0)
         continue;
      
      datetime pauseStart = newsTime - beforeMin * 60;
      datetime pauseEnd = newsTime + afterMin * 60;
      
      if(currentTime >= pauseStart && currentTime <= pauseEnd)
      {
         if(!foundPause || pauseEnd < earliestPauseEnd)
         {
            foundPause = true;
            earliestPauseEnd = pauseEnd;
            earliestNewsTitle = g_newsEvents[i].title;
            earliestNewsTime = newsTime;
            earliestCountry = g_newsEvents[i].country;
            earliestImpact = impact;
         }
      }
      
      if(newsTime > currentTime && (closestNewsTime == 0 || newsTime < closestNewsTime))
      {
         datetime futureStart = newsTime - beforeMin * 60;
         if(currentTime < futureStart)
         {
            closestNewsTime = newsTime;
            closestNewsTitle = g_newsEvents[i].title;
            closestBeforeMin = beforeMin;
            closestAfterMin = afterMin;
         }
      }
   }
   
   if(foundPause)
   {
      g_nextNewsTitle = earliestNewsTitle;
      g_nextNewsTime = earliestNewsTime;
      g_newsPauseEndTime = earliestPauseEnd;
      pauseKey = earliestNewsTitle + "|" + IntegerToString((long)earliestNewsTime);
      
      if(currentTime < earliestNewsTime)
      {
         int minsLeft = (int)((earliestNewsTime - currentTime) / 60);
         g_newsStatus = "PAUSE: " + earliestCountry + " " + earliestImpact + " in " + IntegerToString(minsLeft) + "m";
      }
      else
      {
         int minsAfter = (int)((currentTime - earliestNewsTime) / 60);
         g_newsStatus = "PAUSE: " + earliestCountry + " " + earliestImpact + " +" + IntegerToString(minsAfter) + "m ago";
      }
   }
   
   if(foundPause)
   {
      g_isNewsPaused = true;
      
      if(!g_lastPausedState || g_lastPauseKey != pauseKey)
      {
         Print("NEWS FILTER: Trading PAUSED - ", g_newsStatus, " | Event: ", g_nextNewsTitle);
         g_lastPausedState = true;
         g_lastPauseKey = pauseKey;
      }
      return true;
   }
   else
   {
      g_isNewsPaused = false;
      g_newsPauseEndTime = 0;
      
      if(g_lastPausedState)
      {
         Print("NEWS FILTER: Trading RESUMED - News pause window ended");
         g_lastPausedState = false;
         g_lastPauseKey = "";
      }
      
      if(closestNewsTime > 0 && (closestNewsTime - currentTime) <= 2 * 3600)
      {
         g_nextNewsTitle = closestNewsTitle;
         g_nextNewsTime = closestNewsTime;
      }
      
      g_newsStatus = "No Important news";
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Get Countdown String for News Pause                                |
//+------------------------------------------------------------------+
string GetNewsCountdownString()
{
   if(!g_isNewsPaused || g_newsPauseEndTime == 0)
      return "";
   
   datetime currentTime = TimeCurrent();
   
   if(currentTime >= g_newsPauseEndTime)
      return "00:00:00";
   
   int remainingSeconds = (int)(g_newsPauseEndTime - currentTime);
   
   int hours = remainingSeconds / 3600;
   int minutes = (remainingSeconds % 3600) / 60;
   int seconds = remainingSeconds % 60;
   
   string hh = (hours < 10 ? "0" : "") + IntegerToString(hours);
   string mm = (minutes < 10 ? "0" : "") + IntegerToString(minutes);
   string ss = (seconds < 10 ? "0" : "") + IntegerToString(seconds);
   
   return hh + ":" + mm + ":" + ss;
}

//+------------------------------------------------------------------+
//| ============== TIME FILTER MODULE (from v5.34) ================= |
//+------------------------------------------------------------------+

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
   if(StringLen(session) < 11) return false;
   
   int dashPos = StringFind(session, "-");
   if(dashPos < 0) return false;
   
   string startStr = StringSubstr(session, 0, dashPos);
   string endStr = StringSubstr(session, dashPos + 1);
   
   int startMinutes = ParseTimeToMinutes(startStr);
   int endMinutes = ParseTimeToMinutes(endStr);
   
   if(startMinutes < 0 || endMinutes < 0) return false;
   
   if(startMinutes <= endMinutes)
   {
      return (currentMinutes >= startMinutes && currentMinutes < endMinutes);
   }
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
   
   if(!IsTradableDay(dt.day_of_week))
      return false;
   
   int currentMinutes = dt.hour * 60 + dt.min;
   
   bool isFriday = (dt.day_of_week == 5);
   
   if(isFriday)
   {
      bool hasFridaySessions = (StringLen(InpFridaySession1) >= 5 || 
                                 StringLen(InpFridaySession2) >= 5 || 
                                 StringLen(InpFridaySession3) >= 5);
      
      if(hasFridaySessions)
      {
         if(StringLen(InpFridaySession1) >= 5 && IsTimeInSession(InpFridaySession1, currentMinutes))
            return true;
         if(StringLen(InpFridaySession2) >= 5 && IsTimeInSession(InpFridaySession2, currentMinutes))
            return true;
         if(StringLen(InpFridaySession3) >= 5 && IsTimeInSession(InpFridaySession3, currentMinutes))
            return true;
            
         return false;
      }
   }
   
   if(StringLen(InpSession1) >= 5 && IsTimeInSession(InpSession1, currentMinutes))
      return true;
   if(StringLen(InpSession2) >= 5 && IsTimeInSession(InpSession2, currentMinutes))
      return true;
   if(StringLen(InpSession3) >= 5 && IsTimeInSession(InpSession3, currentMinutes))
      return true;
   
   if(StringLen(InpSession1) < 5 && StringLen(InpSession2) < 5 && StringLen(InpSession3) < 5)
      return true;
   
   return false;
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ============== CHART EVENT HANDLER (v2.9) ====================== |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam == "GM_BtnPause")
      {
         g_eaIsPaused = !g_eaIsPaused;
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         Print("EA ", g_eaIsPaused ? "PAUSED" : "RESUMED", " by user");
      }
      else if(sparam == "GM_BtnCloseBuy")
      {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         int result = MessageBox("Close all BUY orders?", "Confirm Close Buy", MB_YESNO | MB_ICONWARNING);
         if(result == IDYES)
            CloseAllPositionsByType(POSITION_TYPE_BUY);
      }
      else if(sparam == "GM_BtnCloseSell")
      {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         int result = MessageBox("Close all SELL orders?", "Confirm Close Sell", MB_YESNO | MB_ICONWARNING);
         if(result == IDYES)
            CloseAllPositionsByType(POSITION_TYPE_SELL);
      }
      else if(sparam == "GM_BtnCloseAll")
      {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         int result = MessageBox("Close ALL orders?", "Confirm Close All", MB_YESNO | MB_ICONWARNING);
         if(result == IDYES)
         {
            CloseAllPositionsByType(POSITION_TYPE_BUY);
            CloseAllPositionsByType(POSITION_TYPE_SELL);
         }
      }
      else if(sparam == "GM_BtnResumeDaily")
      {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         int result = MessageBox(
            "Resume trading for today?\nDaily profit target was reached.",
            "Confirm Resume", MB_YESNO | MB_ICONQUESTION);
         if(result == IDYES)
         {
            g_dailyProfitPaused = false;
            Print("DAILY PROFIT PAUSE: Manually resumed by user.");
         }
      }
      ChartRedraw(0);
   }
}

//+------------------------------------------------------------------+
//| Close all positions by type (BUY or SELL) - v2.9                   |
//+------------------------------------------------------------------+
void CloseAllPositionsByType(ENUM_POSITION_TYPE posType)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) != posType) continue;
      
      trade.PositionClose(ticket);
   }
   
   string typeStr = (posType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
   Print("Closed all ", typeStr, " positions by user command");
}

//+------------------------------------------------------------------+
//| Dashboard Helper: Create Button (v2.9)                             |
//+------------------------------------------------------------------+
void CreateDashButton(string name, int x, int y, int width, int height, string text, color bgColor, color textColor)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgColor);
   ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| ============== COUNTER-TREND HEDGING MODULE (v5.1) ============= |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check if a comment belongs to a hedge order                        |
//+------------------------------------------------------------------+
bool IsHedgeComment(string comment)
{
   return (StringFind(comment, "GM_HEDGE") >= 0 || StringFind(comment, "GM_HG") >= 0);
}

//+------------------------------------------------------------------+
//| Count normal (non-hedge) orders for a specific side                |
//+------------------------------------------------------------------+
int CountNormalOrders(ENUM_POSITION_TYPE side, double &totalLots, double &totalPL)
{
   int count = 0;
   totalLots = 0;
   totalPL = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != side) continue;
      string comment = PositionGetString(POSITION_COMMENT);
      if(IsHedgeComment(comment)) continue;
      count++;
      totalLots += PositionGetDouble(POSITION_VOLUME);
      totalPL += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return count;
}

//+------------------------------------------------------------------+
//| Check if a ticket is bound to ANY active hedge set                 |
//+------------------------------------------------------------------+
bool IsTicketBound(ulong ticket)
{
   for(int h = 0; h < MAX_HEDGE_SETS; h++)
   {
      if(!g_hedgeSets[h].active) continue;
      for(int b = 0; b < g_hedgeSets[h].boundTicketCount; b++)
      {
         if(g_hedgeSets[h].boundTickets[b] == ticket)
            return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Count unbound orders (not tied to any hedge set) for a side        |
//+------------------------------------------------------------------+
int CountUnboundOrders(ENUM_POSITION_TYPE side, double &totalLots, double &totalPL)
{
   int count = 0;
   totalLots = 0;
   totalPL = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != side) continue;
      string comment = PositionGetString(POSITION_COMMENT);
      if(IsHedgeComment(comment)) continue;
      if(IsTicketBound(ticket)) continue;  // skip tickets already bound to a set
      count++;
      totalLots += PositionGetDouble(POSITION_VOLUME);
      totalPL += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return count;
}

//+------------------------------------------------------------------+
//| Remove a bound ticket from a hedge set (when order closed)         |
//+------------------------------------------------------------------+
void RemoveBoundTicket(int idx, ulong ticket)
{
   for(int b = 0; b < g_hedgeSets[idx].boundTicketCount; b++)
   {
      if(g_hedgeSets[idx].boundTickets[b] == ticket)
      {
         // Shift remaining tickets down
         for(int j = b; j < g_hedgeSets[idx].boundTicketCount - 1; j++)
            g_hedgeSets[idx].boundTickets[j] = g_hedgeSets[idx].boundTickets[j + 1];
         g_hedgeSets[idx].boundTicketCount--;
         ArrayResize(g_hedgeSets[idx].boundTickets, g_hedgeSets[idx].boundTicketCount);
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| Refresh bound tickets — remove tickets that no longer exist        |
//+------------------------------------------------------------------+
void RefreshBoundTickets(int idx)
{
   for(int b = g_hedgeSets[idx].boundTicketCount - 1; b >= 0; b--)
   {
      ulong ticket = g_hedgeSets[idx].boundTickets[b];
      if(!PositionSelectByTicket(ticket))
      {
         // Position closed externally → remove from bound list
         RemoveBoundTicket(idx, ticket);
      }
   }
}

//+------------------------------------------------------------------+
//| Find free hedge set slot                                           |
//+------------------------------------------------------------------+
int FindFreeHedgeSlot()
{
   for(int h = 0; h < MAX_HEDGE_SETS; h++)
   {
      if(!g_hedgeSets[h].active) return h;
   }
   return -1;
}

//+------------------------------------------------------------------+
//| Check expansion and open hedge if needed                           |
//| Now supports multiple hedge sets on same side (unbound orders)     |
//+------------------------------------------------------------------+
void CheckAndOpenHedge()
{
   // Determine expansion direction
   int expCount = 0;
   int bestDir = 0;
   for(int sq = 2; sq >= 0; sq--)
   {
      if(g_squeeze[sq].state == 2)
      {
         expCount++;
         if(bestDir == 0) bestDir = g_squeeze[sq].direction;
      }
   }

   if(expCount < InpSqueeze_MinTFExpansion || bestDir == 0) return;

   // Bearish expansion → hedge BUY orders stuck (open SELL hedge)
   // Bullish expansion → hedge SELL orders stuck (open BUY hedge)
   ENUM_POSITION_TYPE counterSide = (bestDir == -1) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   ENUM_POSITION_TYPE hedgeSide   = (bestDir == -1) ? POSITION_TYPE_SELL : POSITION_TYPE_BUY;

   // Count UNBOUND stuck orders on counter side (not already assigned to another hedge set)
   double counterLots = 0, counterPL = 0;
   int counterCount = CountUnboundOrders(counterSide, counterLots, counterPL);
   if(counterCount == 0 || counterLots <= 0) return;

   // Find free slot
   int slot = FindFreeHedgeSlot();
   if(slot < 0)
   {
      Print("HEDGE: No free slot available (max ", MAX_HEDGE_SETS, " sets)");
      return;
   }

   // Open hedge order
   ENUM_ORDER_TYPE orderType = (hedgeSide == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   string comment = "GM_HEDGE_" + IntegerToString(slot + 1);

   if(OpenOrder(orderType, counterLots, comment))
   {
      g_hedgeSets[slot].active = true;
      g_hedgeSets[slot].hedgeSide = hedgeSide;
      g_hedgeSets[slot].counterSide = counterSide;
      g_hedgeSets[slot].hedgeLots = counterLots;
      g_hedgeSets[slot].originalTotalLots = counterLots;
      g_hedgeSets[slot].gridMode = false;
      g_hedgeSets[slot].gridLevel = 0;
      g_hedgeSets[slot].gridTicketCount = 0;
      ArrayResize(g_hedgeSets[slot].gridTickets, 0);
      g_hedgeSets[slot].commentPrefix = comment;

      // Find the hedge ticket we just opened
      g_hedgeSets[slot].hedgeTicket = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if(PositionGetString(POSITION_COMMENT) == comment)
         {
            g_hedgeSets[slot].hedgeTicket = ticket;
            break;
         }
      }

      // === BIND unbound counter-side tickets to this hedge set ===
      g_hedgeSets[slot].boundTicketCount = 0;
      ArrayResize(g_hedgeSets[slot].boundTickets, 0);
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != counterSide) continue;
         string cmt = PositionGetString(POSITION_COMMENT);
         if(IsHedgeComment(cmt)) continue;
         if(IsTicketBound(ticket)) continue;  // already bound to another set

         int bc = g_hedgeSets[slot].boundTicketCount;
         ArrayResize(g_hedgeSets[slot].boundTickets, bc + 1);
         g_hedgeSets[slot].boundTickets[bc] = ticket;
         g_hedgeSets[slot].boundTicketCount = bc + 1;
      }

      g_hedgeSetCount++;
      string sideStr = (hedgeSide == POSITION_TYPE_BUY) ? "BUY" : "SELL";
      Print("HEDGE OPENED: Set#", slot + 1, " ", sideStr, " ", DoubleToString(counterLots, 2),
            " lots to cover ", counterCount, " stuck orders (bound ", g_hedgeSets[slot].boundTicketCount, " tickets)");
   }
}

//+------------------------------------------------------------------+
//| Manage all active hedge sets                                       |
//+------------------------------------------------------------------+
void ManageHedgeSets()
{
   for(int h = 0; h < MAX_HEDGE_SETS; h++)
   {
      if(!g_hedgeSets[h].active) continue;

      // Refresh bound tickets — remove any that were closed externally
      RefreshBoundTickets(h);

      // Verify hedge ticket still exists
      bool hedgeExists = false;
      if(g_hedgeSets[h].hedgeTicket > 0 && PositionSelectByTicket(g_hedgeSets[h].hedgeTicket))
      {
         hedgeExists = true;
         g_hedgeSets[h].hedgeLots = PositionGetDouble(POSITION_VOLUME);
      }

      if(!hedgeExists && !g_hedgeSets[h].gridMode)
      {
         // Hedge was closed externally (accumulate close, manual, etc.)
         Print("HEDGE Set#", h + 1, " ticket no longer exists. Deactivating.");
         g_hedgeSets[h].active = false;
         g_hedgeSets[h].boundTicketCount = 0;
         ArrayResize(g_hedgeSets[h].boundTickets, 0);
         g_hedgeSetCount--;
         continue;
      }

      // Check current squeeze state
      bool isExpansion = false;
      for(int sq = 0; sq < 3; sq++)
      {
         if(g_squeeze[sq].state == 2)
         {
            isExpansion = true;
            break;
         }
      }

      if(g_hedgeSets[h].gridMode)
      {
         ManageHedgeGridMode(h);
      }
      else if(!isExpansion)
      {
         // Expansion ended → check scenarios
         double hedgePnL = 0;
         if(hedgeExists)
            hedgePnL = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);

         if(hedgePnL > 0)
            ManageHedgeMatchingClose(h);  // Scenario 1: hedge in profit
         else
            ManageHedgePartialClose(h);   // Scenario 2: hedge in loss, check original orders
      }
      else
      {
         // Still in expansion - check if bound orders are all gone
         if(g_hedgeSets[h].boundTicketCount == 0 && hedgeExists)
         {
            // All bound orders gone but hedge remains → enter grid mode
            Print("HEDGE Set#", h + 1, " all bound orders cleared. Entering Grid Mode.");
            g_hedgeSets[h].gridMode = true;
            g_hedgeSets[h].gridLevel = CalculateEquivGridLevel(g_hedgeSets[h].hedgeLots);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Scenario 1: Hedge in profit + expansion ended → match with losses  |
//| Now uses boundTickets[] for set-specific isolation                  |
//+------------------------------------------------------------------+
void ManageHedgeMatchingClose(int idx)
{
   if(!PositionSelectByTicket(g_hedgeSets[idx].hedgeTicket)) return;

   double hedgeProfit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   if(hedgeProfit <= 0) return;

   double budget = hedgeProfit - InpHedge_MatchMinProfit;
   if(budget <= 0) return;

   // Collect loss orders ONLY from this set's boundTickets (oldest first)
   ulong lossTickets[];
   double lossValues[];
   datetime lossTimes[];
   int lossCount = 0;

   for(int b = 0; b < g_hedgeSets[idx].boundTicketCount; b++)
   {
      ulong ticket = g_hedgeSets[idx].boundTickets[b];
      if(!PositionSelectByTicket(ticket)) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != g_hedgeSets[idx].counterSide) continue;

      double pnl = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      if(pnl >= 0) continue;  // only loss orders

      ArrayResize(lossTickets, lossCount + 1);
      ArrayResize(lossValues, lossCount + 1);
      ArrayResize(lossTimes, lossCount + 1);
      lossTickets[lossCount] = ticket;
      lossValues[lossCount] = pnl;
      lossTimes[lossCount] = (datetime)PositionGetInteger(POSITION_TIME);
      lossCount++;
   }

   // Sort by open time ascending (oldest first)
   for(int a = 0; a < lossCount - 1; a++)
      for(int b = a + 1; b < lossCount; b++)
         if(lossTimes[b] < lossTimes[a])
         {
            double tmpV = lossValues[a]; lossValues[a] = lossValues[b]; lossValues[b] = tmpV;
            ulong tmpT = lossTickets[a]; lossTickets[a] = lossTickets[b]; lossTickets[b] = tmpT;
            datetime tmpD = lossTimes[a]; lossTimes[a] = lossTimes[b]; lossTimes[b] = tmpD;
         }

   // Budget-based matching: scan losses oldest first
   int closeLossIdx[];
   ArrayResize(closeLossIdx, 0);
   double cumLoss = 0;
   int lossUsed = 0;

   for(int l = 0; l < lossCount; l++)
   {
      double absLoss = MathAbs(lossValues[l]);
      if(cumLoss + absLoss <= budget)
      {
         ArrayResize(closeLossIdx, lossUsed + 1);
         closeLossIdx[lossUsed] = l;
         cumLoss += absLoss;
         lossUsed++;
      }
   }

   if(lossUsed > 0)
   {
      double finalNet = hedgeProfit - cumLoss;
      Print("HEDGE MATCHING Set#", idx + 1, ": hedge profit $", DoubleToString(hedgeProfit, 2),
            " covers ", lossUsed, " losses ($", DoubleToString(cumLoss, 2),
            ") net: $", DoubleToString(finalNet, 2));

      // Close hedge order
      trade.PositionClose(g_hedgeSets[idx].hedgeTicket);

      // Close matched losses + remove from boundTickets
      for(int cl = 0; cl < lossUsed; cl++)
      {
         int li = closeLossIdx[cl];
         trade.PositionClose(lossTickets[li]);
         RemoveBoundTicket(idx, lossTickets[li]);
      }

      // Deactivate hedge set
      g_hedgeSets[idx].active = false;
      g_hedgeSets[idx].boundTicketCount = 0;
      ArrayResize(g_hedgeSets[idx].boundTickets, 0);
      g_hedgeSetCount--;
      Sleep(100);
   }
   else
   {
      // No losses can be matched → just close the profitable hedge
      Print("HEDGE CLOSE (no matchable losses) Set#", idx + 1,
            ": profit $", DoubleToString(hedgeProfit, 2));
      trade.PositionClose(g_hedgeSets[idx].hedgeTicket);

      // Enter grid mode to continue recovery if bound tickets remain
      if(g_hedgeSets[idx].boundTicketCount > 0)
      {
         // Still have bound orders → continue as grid for recovery
         g_hedgeSets[idx].gridMode = true;
         g_hedgeSets[idx].gridLevel = 0;
         Print("HEDGE Set#", idx + 1, " closed but bound orders remain. Entering Grid Mode.");
      }
      else
      {
         g_hedgeSets[idx].active = false;
         g_hedgeSets[idx].boundTicketCount = 0;
         ArrayResize(g_hedgeSets[idx].boundTickets, 0);
         g_hedgeSetCount--;
      }
      Sleep(100);
   }
}

//+------------------------------------------------------------------+
//| Scenario 2: Hedge in loss + original orders may have profit        |
//| Use partial close to reduce hedge using bound order profits        |
//+------------------------------------------------------------------+
void ManageHedgePartialClose(int idx)
{
   if(!PositionSelectByTicket(g_hedgeSets[idx].hedgeTicket)) return;

   double hedgePnL = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   double hedgeLots = PositionGetDouble(POSITION_VOLUME);
   if(hedgePnL >= 0) return;  // not in loss → handled by ManageHedgeMatchingClose
   if(hedgeLots <= 0) return;

   // Check if bound orders still exist
   if(g_hedgeSets[idx].boundTicketCount == 0)
   {
      // No bound orders left → enter grid mode
      Print("HEDGE Set#", idx + 1, " no bound orders left. Entering Grid Mode.");
      g_hedgeSets[idx].gridMode = true;
      g_hedgeSets[idx].gridLevel = CalculateEquivGridLevel(hedgeLots);
      return;
   }

   // Find profitable orders ONLY from this set's boundTickets
   ulong profitTickets[];
   double profitValues[];
   int profitCount = 0;

   for(int b = 0; b < g_hedgeSets[idx].boundTicketCount; b++)
   {
      ulong ticket = g_hedgeSets[idx].boundTickets[b];
      if(!PositionSelectByTicket(ticket)) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != g_hedgeSets[idx].counterSide) continue;

      double pnl = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      if(pnl <= 0) continue;

      ArrayResize(profitTickets, profitCount + 1);
      ArrayResize(profitValues, profitCount + 1);
      profitTickets[profitCount] = ticket;
      profitValues[profitCount] = pnl;
      profitCount++;
   }

   if(profitCount == 0) return;  // no profitable bound orders to use

   // Guard: require minimum number of profitable counter-orders before starting partial close
   if(InpHedge_PartialMinProfitOrders > 0 && profitCount < InpHedge_PartialMinProfitOrders) return;

   // Calculate hedge loss per lot
   double hedgeLossPerLot = MathAbs(hedgePnL) / hedgeLots;
   if(hedgeLossPerLot <= 0) return;

   // === BATCH MODE: aggregate all profitable orders ===
   double totalProfit = 0;
   for(int p = 0; p < profitCount; p++)
      totalProfit += profitValues[p];

   // Calculate total hedge lots that can be covered by combined profit
   double closeLots = (totalProfit - InpHedge_PartialMinProfit) / hedgeLossPerLot;
   if(closeLots <= 0) return;

   // Normalize lot
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   closeLots = MathMax(minLot, MathMin(hedgeLots, NormalizeDouble(MathFloor(closeLots / lotStep) * lotStep, 2)));

   if(closeLots < minLot) return;

   Print("HEDGE PARTIAL CLOSE (BATCH) Set#", idx + 1, ": ", profitCount, " profit orders total $",
         DoubleToString(totalProfit, 2), " → close ", DoubleToString(closeLots, 2),
         " lots of hedge (current ", DoubleToString(hedgeLots, 2), " lots)");

   // Close all profitable bound orders + remove from boundTickets
   for(int p = 0; p < profitCount; p++)
   {
      trade.PositionClose(profitTickets[p]);
      RemoveBoundTicket(idx, profitTickets[p]);
      Sleep(50);
   }

   // Partial close (or full close) hedge
   if(!PositionSelectByTicket(g_hedgeSets[idx].hedgeTicket)) return;
   hedgeLots = PositionGetDouble(POSITION_VOLUME);

   if(closeLots >= hedgeLots)
   {
      trade.PositionClose(g_hedgeSets[idx].hedgeTicket);
      g_hedgeSets[idx].active = false;
      g_hedgeSets[idx].boundTicketCount = 0;
      ArrayResize(g_hedgeSets[idx].boundTickets, 0);
      g_hedgeSetCount--;
      Print("HEDGE Set#", idx + 1, " fully closed via batch partial close.");
   }
   else
   {
      trade.PositionClosePartial(g_hedgeSets[idx].hedgeTicket, closeLots);
      g_hedgeSets[idx].hedgeLots = hedgeLots - closeLots;
      Print("HEDGE Set#", idx + 1, " reduced to ", DoubleToString(hedgeLots - closeLots, 2), " lots");
   }
   Sleep(100);
}

//+------------------------------------------------------------------+
//| Calculate equivalent grid level for remaining hedge lots           |
//+------------------------------------------------------------------+
int CalculateEquivGridLevel(double remainingLots)
{
   double cumLots = InitialLotSize;
   int level = 0;
   double mult = GridLoss_MultiplyFactor;
   double addPerLevel = GridLoss_AddLotPerLevel * InitialLotSize;

   while(cumLots < remainingLots && level < GridLoss_MaxTrades)
   {
      level++;
      double nextLot = 0;
      if(GridLoss_LotMode == LOT_MULTIPLY)
         nextLot = InitialLotSize * MathPow(mult, level);
      else if(GridLoss_LotMode == LOT_ADD)
         nextLot = InitialLotSize + addPerLevel * level;
      else
         nextLot = InitialLotSize;  // custom - simplified
      cumLots += nextLot;
   }
   return level;
}

//+------------------------------------------------------------------+
//| Hedge Grid Mode: original orders gone, manage hedge recovery       |
//+------------------------------------------------------------------+
void ManageHedgeGridMode(int idx)
{
   // Verify main hedge ticket
   bool mainHedgeExists = false;
   double mainHedgePnL = 0;
   if(g_hedgeSets[idx].hedgeTicket > 0 && PositionSelectByTicket(g_hedgeSets[idx].hedgeTicket))
   {
      mainHedgeExists = true;
      mainHedgePnL = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      g_hedgeSets[idx].hedgeLots = PositionGetDouble(POSITION_VOLUME);
   }

   // Count hedge grid orders
   int gridProfitCount = 0;
   double gridTotalProfit = 0;
   ulong gridProfitTickets[];
   double gridProfitValues[];

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      string comment = PositionGetString(POSITION_COMMENT);
      string prefix = "GM_HG" + IntegerToString(idx + 1);
      if(StringFind(comment, prefix) < 0) continue;

      double pnl = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      if(pnl > 0)
      {
         ArrayResize(gridProfitTickets, gridProfitCount + 1);
         ArrayResize(gridProfitValues, gridProfitCount + 1);
         gridProfitTickets[gridProfitCount] = ticket;
         gridProfitValues[gridProfitCount] = pnl;
         gridTotalProfit += pnl;
         gridProfitCount++;
      }
   }

   // If hedge grid profits can cover main hedge loss → partial close
   if(mainHedgeExists && mainHedgePnL < 0 && gridProfitCount >= InpHedge_PartialMinProfitOrders)
   {
      double hedgeLossPerLot = MathAbs(mainHedgePnL) / g_hedgeSets[idx].hedgeLots;
      double budget = gridTotalProfit - InpHedge_MatchMinProfit;
      if(budget > 0 && hedgeLossPerLot > 0)
      {
         double closeLots = budget / hedgeLossPerLot;
         double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
         closeLots = MathMax(minLot, MathMin(g_hedgeSets[idx].hedgeLots,
                     NormalizeDouble(MathFloor(closeLots / lotStep) * lotStep, 2)));

         if(closeLots >= minLot)
         {
            Print("HEDGE GRID MATCH Set#", idx + 1, ": grid profit $",
                  DoubleToString(gridTotalProfit, 2), " closes ",
                  DoubleToString(closeLots, 2), " lots of main hedge");

            // Close grid profit orders
            for(int gp = 0; gp < gridProfitCount; gp++)
               trade.PositionClose(gridProfitTickets[gp]);

            // Partial close main hedge
            if(closeLots >= g_hedgeSets[idx].hedgeLots)
            {
               trade.PositionClose(g_hedgeSets[idx].hedgeTicket);
               g_hedgeSets[idx].active = false;
               g_hedgeSetCount--;
               Print("HEDGE Set#", idx + 1, " fully recovered via grid mode.");
            }
            else
            {
               trade.PositionClosePartial(g_hedgeSets[idx].hedgeTicket, closeLots);
               g_hedgeSets[idx].hedgeLots -= closeLots;
            }
            Sleep(100);
            return;
         }
      }
   }

   // If main hedge fully closed
   if(!mainHedgeExists)
   {
      // Close remaining grid orders
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         string comment = PositionGetString(POSITION_COMMENT);
         string prefix = "GM_HG" + IntegerToString(idx + 1);
         if(StringFind(comment, prefix) >= 0)
            trade.PositionClose(ticket);
      }
      g_hedgeSets[idx].active = false;
      g_hedgeSetCount--;
      Print("HEDGE Set#", idx + 1, " grid mode complete. All cleaned up.");
      return;
   }

   // Open next grid order if needed (direction = same as hedge)
   if(g_newOrderBlocked) return;  // respect news/time filters

   int currentGridCount = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      string comment = PositionGetString(POSITION_COMMENT);
      string prefix = "GM_HG" + IntegerToString(idx + 1);
      if(StringFind(comment, prefix) >= 0) currentGridCount++;
   }

   if(currentGridCount < GridLoss_MaxTrades && currentGridCount <= g_hedgeSets[idx].gridLevel + 3)
   {
      // Calculate next grid lot
      int nextLevel = g_hedgeSets[idx].gridLevel + currentGridCount + 1;
      double nextLot = InitialLotSize;
      if(GridLoss_LotMode == LOT_MULTIPLY)
         nextLot = InitialLotSize * MathPow(GridLoss_MultiplyFactor, nextLevel);
      else if(GridLoss_LotMode == LOT_ADD)
         nextLot = InitialLotSize + (GridLoss_AddLotPerLevel * InitialLotSize) * nextLevel;

      // Cooldown to prevent rapid-fire orders
      if(TimeCurrent() - g_lastHedgeGridTime < 5) return;

      // Check grid distance using proper ATR/Custom calculation
      double requiredGap = GetGridDistance(currentGridCount + 1, true);
      if(requiredGap <= 0) return;

      double lastPrice = 0;
      if(PositionSelectByTicket(g_hedgeSets[idx].hedgeTicket))
         lastPrice = PositionGetDouble(POSITION_PRICE_OPEN);

      // Find last grid order price
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         string comment = PositionGetString(POSITION_COMMENT);
         string prefix = "GM_HG" + IntegerToString(idx + 1);
         if(StringFind(comment, prefix) >= 0)
         {
            double gPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            if(g_hedgeSets[idx].hedgeSide == POSITION_TYPE_BUY)
            {
               if(gPrice < lastPrice || lastPrice == 0) lastPrice = gPrice;
            }
            else
            {
               if(gPrice > lastPrice || lastPrice == 0) lastPrice = gPrice;
            }
         }
      }

      if(lastPrice <= 0) return;

      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      // Directional distance: only trigger when price moves AGAINST the hedge (losing direction)
      // Hedge SELL → grid opens when price goes UP (Bid > lastPrice)
      // Hedge BUY  → grid opens when price goes DOWN (Ask < lastPrice)
      double distance = 0;
      if(g_hedgeSets[idx].hedgeSide == POSITION_TYPE_SELL)
      {
         double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         distance = (currentBid - lastPrice) / point;  // positive = price went up
      }
      else // BUY hedge
      {
         double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         distance = (lastPrice - currentAsk) / point;  // positive = price went down
      }

      if(distance >= requiredGap && distance > 0)
      {
         ENUM_ORDER_TYPE orderType = (g_hedgeSets[idx].hedgeSide == POSITION_TYPE_BUY)
                                    ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
         string comment = "GM_HG" + IntegerToString(idx + 1) + "_GL" + IntegerToString(currentGridCount + 1);

         if(OpenOrder(orderType, nextLot, comment))
         {
            g_lastHedgeGridTime = TimeCurrent();
            Print("HEDGE GRID Set#", idx + 1, " opened grid L", currentGridCount + 1,
                  " lots=", DoubleToString(nextLot, 2),
                  " gap=", DoubleToString(distance, 0), "/", DoubleToString(requiredGap, 0));
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Matching Close - Pair profitable orders with losing orders         |
//| Close sets where net profit >= MatchingMinProfit                   |
//| Runs once per new bar. Buy/Sell sides processed independently.     |
//+------------------------------------------------------------------+
void ManageMatchingClose()
{
   int maxLoss = MathMin(MathMax(MatchingMaxLossOrders, 1), 10);  // allow up to 10

   // Process BUY side then SELL side
   for(int side = 0; side < 2; side++)
   {
      ENUM_POSITION_TYPE posType = (side == 0) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;

      // Keep looping until no more matches found
      bool matchFound = true;
      while(matchFound)
      {
         matchFound = false;

         // Collect profit and loss tickets for this side
         ulong profitTickets[];
         double profitValues[];
         ulong lossTickets[];
         double lossValues[];
         datetime lossOpenTimes[];
         int profitCount = 0, lossCount = 0;

         for(int i = PositionsTotal() - 1; i >= 0; i--)
         {
            ulong ticket = PositionGetTicket(i);
            if(ticket == 0) continue;
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
            if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
            if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != posType) continue;

            // Skip hedge orders — managed separately
            string mcComment = PositionGetString(POSITION_COMMENT);
            if(StringFind(mcComment, "GM_HEDGE") >= 0 || StringFind(mcComment, "GM_HG") >= 0) continue;

            double pnl = PositionGetDouble(POSITION_PROFIT)
                       + PositionGetDouble(POSITION_SWAP)
                       + (2.0 * PositionGetDouble(POSITION_COMMISSION));

            if(pnl > 0)
            {
               ArrayResize(profitTickets, profitCount + 1);
               ArrayResize(profitValues, profitCount + 1);
               profitTickets[profitCount] = ticket;
               profitValues[profitCount] = pnl;
               profitCount++;
            }
            else if(pnl < 0)
            {
               ArrayResize(lossTickets, lossCount + 1);
               ArrayResize(lossValues, lossCount + 1);
               ArrayResize(lossOpenTimes, lossCount + 1);
               lossTickets[lossCount] = ticket;
               lossValues[lossCount] = pnl;
               lossOpenTimes[lossCount] = (datetime)PositionGetInteger(POSITION_TIME);
               lossCount++;
            }
         }

         // --- Minimum Total Orders Threshold ---
         int totalSideOrders = profitCount + lossCount;
         if(MatchingMinTotalOrders > 0 && totalSideOrders < MatchingMinTotalOrders)
            break;  // ออเดอร์ยังไม่ถึงเกณฑ์ — ปล่อยให้ TP ทำงานปกติ

         int minPO = MathMax(MatchingMinProfitOrders, 1);
         if(profitCount < minPO) break;  // Not enough profit orders — wait for more

         // Sort profit descending (biggest profit first)
         for(int a = 0; a < profitCount - 1; a++)
            for(int b = a + 1; b < profitCount; b++)
               if(profitValues[b] > profitValues[a])
               {
                  double tmpV = profitValues[a]; profitValues[a] = profitValues[b]; profitValues[b] = tmpV;
                  ulong tmpT = profitTickets[a]; profitTickets[a] = profitTickets[b]; profitTickets[b] = tmpT;
               }

         // Sort loss by open time ascending (oldest/furthest first)
         for(int a = 0; a < lossCount - 1; a++)
            for(int b = a + 1; b < lossCount; b++)
               if(lossOpenTimes[b] < lossOpenTimes[a])
               {
                  double tmpV = lossValues[a]; lossValues[a] = lossValues[b]; lossValues[b] = tmpV;
                  ulong tmpT = lossTickets[a]; lossTickets[a] = lossTickets[b]; lossTickets[b] = tmpT;
                  datetime tmpD = lossOpenTimes[a]; lossOpenTimes[a] = lossOpenTimes[b]; lossOpenTimes[b] = tmpD;
               }

         string sideStr = (posType == POSITION_TYPE_BUY) ? "BUY" : "SELL";

         //--- Case 1: No loss orders — profit-only matching
          if(lossCount == 0)
         {
            if(profitCount < minPO) break;  // Profit-only also needs minPO
            double totalProfit = 0;
            for(int p = 0; p < profitCount; p++)
               totalProfit += profitValues[p];

            if(totalProfit >= MatchingMinProfit)
            {
               Print("MATCHING CLOSE [", sideStr, "] PROFIT-ONLY: ", profitCount,
                     " orders, total $", DoubleToString(totalProfit, 2));
               for(int p = 0; p < profitCount; p++)
               {
                  Print("  Closing profit ticket #", profitTickets[p],
                        " ($", DoubleToString(profitValues[p], 2), ")");
                  trade.PositionClose(profitTickets[p]);
               }
               matchFound = true;
               Sleep(100);
            }
            else
               break;  // Not enough profit
         }
         //--- Case 2: Has loss orders — Budget-based matching
         //    Step 1: Sum ALL profit orders
         //    Step 2: budget = totalProfit - MinProfit
         //    Step 3: Scan losses oldest-first, skip if too heavy, include if fits budget
         //    Step 4: Close all profit + matched losses
         else
         {
            double totalProfit = 0;
            for(int p = 0; p < profitCount; p++)
               totalProfit += profitValues[p];

            double budget = totalProfit - MatchingMinProfit;
            if(budget <= 0) break;  // Not enough profit even for MinProfit

            int closeLossIdx[];
            ArrayResize(closeLossIdx, 0);
            double cumLoss = 0;
            int lossUsed = 0;

            for(int l = 0; l < lossCount && lossUsed < maxLoss; l++)
            {
               double absLoss = MathAbs(lossValues[l]);
               if(cumLoss + absLoss <= budget)
               {
                  ArrayResize(closeLossIdx, lossUsed + 1);
                  closeLossIdx[lossUsed] = l;
                  cumLoss += absLoss;
                  lossUsed++;
               }
               // else: this loss is too heavy — skip to next (possibly lighter) one
            }

            if(lossUsed > 0)
            {
               double finalNet = totalProfit - cumLoss;
               Print("MATCHING CLOSE [", sideStr, "]: ", profitCount, " profit + ",
                     lossUsed, " loss orders. Net: $", DoubleToString(finalNet, 2),
                     " (budget: $", DoubleToString(budget, 2), ")");

               for(int cp = 0; cp < profitCount; cp++)
               {
                  Print("  Closing profit #", profitTickets[cp],
                        " ($", DoubleToString(profitValues[cp], 2), ")");
                  trade.PositionClose(profitTickets[cp]);
               }
               for(int cl = 0; cl < lossUsed; cl++)
               {
                  int idx = closeLossIdx[cl];
                  Print("  Closing loss #", lossTickets[idx],
                        " ($", DoubleToString(lossValues[idx], 2), ")");
                  trade.PositionClose(lossTickets[idx]);
               }

               matchFound = true;
               Sleep(100);
            }
            else break;
         }
      }
   }
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Volatility Squeeze Filter - Update State for all 3 TFs            |
//+------------------------------------------------------------------+
void UpdateSqueezeState()
{
   for(int sq = 0; sq < 3; sq++)
   {
      if(g_squeeze[sq].handleBB == INVALID_HANDLE ||
         g_squeeze[sq].handleEMA == INVALID_HANDLE ||
         g_squeeze[sq].handleATR == INVALID_HANDLE)
      {
         g_squeeze[sq].state = 0;
         g_squeeze[sq].intensity = 1.0;
         continue;
      }

      double bbUpper[], bbLower[], emaVal[], atrVal[];
      ArraySetAsSeries(bbUpper, true);
      ArraySetAsSeries(bbLower, true);
      ArraySetAsSeries(emaVal, true);
      ArraySetAsSeries(atrVal, true);

      // BB: buffer 1 = Upper, buffer 2 = Lower
      if(CopyBuffer(g_squeeze[sq].handleBB, 1, 0, 1, bbUpper) < 1) continue;
      if(CopyBuffer(g_squeeze[sq].handleBB, 2, 0, 1, bbLower) < 1) continue;
      if(CopyBuffer(g_squeeze[sq].handleEMA, 0, 0, 1, emaVal) < 1) continue;
      if(CopyBuffer(g_squeeze[sq].handleATR, 0, 0, 1, atrVal) < 1) continue;

      double upperBB = bbUpper[0];
      double lowerBB = bbLower[0];
      double ema     = emaVal[0];
      double atr     = atrVal[0];

      // Keltner Channel bands
      double upperKC = ema + InpSqueeze_KC_Mult * atr;
      double lowerKC = ema - InpSqueeze_KC_Mult * atr;

      double bbWidth = upperBB - lowerBB;
      double kcWidth = upperKC - lowerKC;

      if(kcWidth <= 0)
      {
         g_squeeze[sq].state = 0;
         g_squeeze[sq].intensity = 1.0;
         continue;
      }

      double intensity = bbWidth / kcWidth;
      g_squeeze[sq].intensity = intensity;

      // Squeeze: BB is INSIDE KC
      if(upperBB < upperKC && lowerBB > lowerKC)
         g_squeeze[sq].state = 1;  // SQUEEZE
      // Expansion: intensity exceeds threshold
      else if(intensity > InpSqueeze_ExpThreshold)
         g_squeeze[sq].state = 2;  // EXPANSION
      else
         g_squeeze[sq].state = 0;  // NORMAL

      // Direction: Close vs EMA (for directional block)
      g_squeeze[sq].direction = 0;
      if(g_squeeze[sq].state == 2)
      {
         double closePrice = iClose(_Symbol, g_squeeze[sq].tf, 0);
         if(closePrice > ema)
            g_squeeze[sq].direction = 1;   // Bullish
         else if(closePrice < ema)
            g_squeeze[sq].direction = -1;  // Bearish
      }
   }
}

//+------------------------------------------------------------------+
//| TimeframeToString - Convert ENUM_TIMEFRAMES to readable label      |
//+------------------------------------------------------------------+
string TimeframeToString(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN";
      default:         return EnumToString(tf);
   }
}
//+------------------------------------------------------------------+
