//+------------------------------------------------------------------+
//|                                              Gold_Miner_EA.mq5   |
//|                                    Copyright 2025, MoneyX Smart  |
//|                     Gold Miner EA v2.9 - SMA+Grid+ATR+License    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MoneyX Smart System"
#property link      "https://moneyxsmartsystem.lovable.app"
#property version   "2.90"
#property description "Gold Miner EA v2.9 - License Check + News Filter + Time Filter + Dashboard Controls"
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
input double           MaxDrawdownPct     = 30.0;      // Max Drawdown % (emergency close)
input bool             StopEAOnDrawdown   = false;     // Stop EA after Emergency Drawdown Close
input ENUM_TRADE_MODE  TradingMode        = TRADE_BOTH; // Trading Mode (Buy/Sell/Both)

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
input bool     ShowAverageLine     = true;     // Show Average Price Line
input bool     ShowTPLine          = true;     // Show TP Line
input color    AverageLineColor    = clrYellow; // Average Line Color
input color    TPLineColor         = clrLime;   // TP Line Color

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

// Dashboard Control Variables (v2.9)
bool           g_eaIsPaused = false;           // EA Pause State (manual)

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

   //--- ATR handles for grid
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

   Print("Gold Miner EA v2.9 initialized successfully");

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

   ObjectDelete(0, "GM_AvgLine");
   ObjectDelete(0, "GM_TPLine");
   ObjectDelete(0, "GM_SLLine");
   ObjectsDeleteAll(0, "GM_Dash_");
   ObjectsDeleteAll(0, "GM_TBL_");
   ObjectsDeleteAll(0, "GM_Btn");

   Print("Gold Miner EA v2.9 deinitialized");
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


void OnTick()
{
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

   // === ORIGINAL TRADING LOGIC (unchanged) ===
   if(g_eaStopped) return;

   //--- Every tick: Per-Order Trailing FIRST (set SL at broker before basket TP checks)
   if(EnablePerOrderTrailing)
   {
      ManagePerOrderTrailing();
   }
   else if(EnableTrailingStop || EnableBreakeven)
   {
      ManageTrailingStop();
   }

   //--- Every tick: TP/SL management (basket) - runs AFTER trailing has set SL
   ManageTPSL();

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

   //--- New bar logic
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   bool isNewBar = (currentBarTime != lastBarTime);

   if(isNewBar)
   {
      lastBarTime = currentBarTime;

      //--- Copy indicator buffers
      if(CopyBuffer(handleSMA, 0, 0, 3, bufSMA) < 3) return;
      if(CopyBuffer(handleATR_Loss, 0, 0, 3, bufATR_Loss) < 3) return;
      if(CopyBuffer(handleATR_Profit, 0, 0, 3, bufATR_Profit) < 3) return;

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

      //--- Grid Loss management (check both sides independently) - blocked by News/Time filter
      if(!g_newOrderBlocked)
      {
         if((hasInitialBuy || g_initialBuyPrice > 0) && gridLossBuy < GridLoss_MaxTrades && buyCount > 0)
         {
            CheckGridLoss(POSITION_TYPE_BUY, gridLossBuy);
         }
         if((hasInitialSell || g_initialSellPrice > 0) && gridLossSell < GridLoss_MaxTrades && sellCount > 0)
         {
            CheckGridLoss(POSITION_TYPE_SELL, gridLossSell);
         }
      }

      //--- Grid Profit management - blocked by News/Time filter
      if(!g_newOrderBlocked && GridProfit_Enable)
      {
         if((hasInitialBuy || g_initialBuyPrice > 0) && gridProfitBuy < GridProfit_MaxTrades && buyCount > 0)
         {
            CheckGridProfit(POSITION_TYPE_BUY, gridProfitBuy);
         }
         if((hasInitialSell || g_initialSellPrice > 0) && gridProfitSell < GridProfit_MaxTrades && sellCount > 0)
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
          if(buyCount == 0 && g_initialBuyPrice == 0 && canOpenMore && canOpenOnThisCandle)
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
          if(sellCount == 0 && g_initialSellPrice == 0 && canOpenMore && canOpenOnThisCandle)
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
      // If g_newOrderBlocked = true, flags are preserved until filter clears
      if(!g_newOrderBlocked)
      {
         justClosedBuy = false;
         justClosedSell = false;
      }
   }

   //--- Draw lines and dashboard every tick
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
      double totalHistory = CalcTotalHistoryProfit();
      g_accumulatedProfit = totalHistory - g_accumulateBaseline;

      double totalFloating = CalculateTotalFloatingPL();
      double accumTotal = g_accumulatedProfit + totalFloating;

      if(accumTotal >= AccumulateTarget && accumTotal > 0 && g_accumulatedProfit > 0)  // guard: only trigger with real closed profit, never on floating alone
      {
         Print("ACCUMULATE TARGET HIT: ", accumTotal, " / ", AccumulateTarget);
         CloseAllPositions();
         // Recalc after closing to include just-closed profit
         Sleep(500);
         double newHistory = CalcTotalHistoryProfit();
         g_accumulateBaseline = newHistory;
         g_accumulatedProfit = 0;
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
   if(dd >= MaxDrawdownPct)
   {
      Print("EMERGENCY DD: ", DoubleToString(dd, 2), "% >= ", MaxDrawdownPct, "% - Closing all positions!");
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
         double atrVal = (ArraySize(bufATR_Loss) > 1 && bufATR_Loss[1] > 0) ? bufATR_Loss[1] : bufATR_Loss[0];
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
         double atrVal = (ArraySize(bufATR_Profit) > 1 && bufATR_Profit[1] > 0) ? bufATR_Profit[1] : bufATR_Profit[0];
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

   double avgPrice = 0;
   if(avgBuy > 0 && avgSell > 0)
   {
      avgPrice = (avgBuy + avgSell) / 2.0;
   }
   else if(avgBuy > 0)
   {
      avgPrice = avgBuy;
   }
   else if(avgSell > 0)
   {
      avgPrice = avgSell;
   }

   if(avgPrice > 0 && ShowAverageLine)
   {
      DrawHLine("GM_AvgLine", avgPrice, AverageLineColor, STYLE_SOLID, 2);
   }
   else
   {
      ObjectDelete(0, "GM_AvgLine");
   }

   //--- TP Line
   if(ShowTPLine && UseTP_Points)
   {
      if(avgBuy > 0)
      {
         DrawHLine("GM_TPLine", avgBuy + TP_Points * point, TPLineColor, STYLE_DASH, 1);
      }
      else if(avgSell > 0)
      {
         DrawHLine("GM_TPLine", avgSell - TP_Points * point, TPLineColor, STYLE_DASH, 1);
      }
      else
      {
         ObjectDelete(0, "GM_TPLine");
      }
   }
   else
   {
      ObjectDelete(0, "GM_TPLine");
   }

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
   int x = DashboardX;
   int y = DashboardY + 24 + rowIndex * 20;  // 24px header
   int tableWidth = 340;
   int rowHeight = 19;
   int sectionBarWidth = 4;
   int labelX = x + sectionBarWidth + 6;
   int valueX = x + 180;

   // Alternating row background
   color rowBg = (rowIndex % 2 == 0) ? C'40,44,52' : C'35,39,46';

   string rowName = "GM_TBL_R" + IntegerToString(rowIndex);
   string secName = "GM_TBL_S" + IntegerToString(rowIndex);
   string lblName = "GM_TBL_L" + IntegerToString(rowIndex);
   string valName = "GM_TBL_V" + IntegerToString(rowIndex);

   // Row background
   CreateDashRect(rowName, x, y, tableWidth, rowHeight, rowBg);
   // Section color bar
   CreateDashRect(secName, x, y, sectionBarWidth, rowHeight, sectionColor);
   // Label text
   CreateDashText(lblName, labelX, y + 2, label, C'180,180,180', 9, "Consolas");
   // Value text
   CreateDashText(valName, valueX, y + 2, value, valueColor, 9, "Consolas");
}

//+------------------------------------------------------------------+
//| Display Dashboard - Table Layout v2.3                              |
//+------------------------------------------------------------------+
void DisplayDashboard()
{
   int tableWidth = 340;
   int headerHeight = 22;

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
   if(bufSMA[0] > 0)
   {
      double bidPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      smaDir = (bidPrice > bufSMA[0]) ? "BUY ▲" : "SELL ▼";
   }

   string tradeModeStr = (TradingMode == TRADE_BUY_ONLY) ? "Buy Only" :
                          (TradingMode == TRADE_SELL_ONLY) ? "Sell Only" : "Both";

   //--- Header
   CreateDashRect("GM_TBL_HDR", DashboardX, DashboardY, tableWidth, headerHeight, COLOR_HEADER_BG);
   CreateDashText("GM_TBL_HDR_T", DashboardX + 8, DashboardY + 3, "Gold Miner EA v2.9", COLOR_HEADER_TEXT, 11, "Arial Bold");
   CreateDashText("GM_TBL_HDR_M", DashboardX + 220, DashboardY + 4, "Mode: " + tradeModeStr, COLOR_HEADER_TEXT, 9, "Consolas");

   //--- DETAIL Section
   int row = 0;
   DrawTableRow(row, "Balance",       "$" + DoubleToString(balance, 2),  COLOR_TEXT, COLOR_SECTION_DETAIL); row++;
   DrawTableRow(row, "Equity",        "$" + DoubleToString(equity, 2),   COLOR_TEXT, COLOR_SECTION_DETAIL); row++;
   DrawTableRow(row, "Floating P/L",  "$" + DoubleToString(totalPL, 2),  (totalPL >= 0 ? COLOR_PROFIT : COLOR_LOSS), COLOR_SECTION_DETAIL); row++;
   DrawTableRow(row, "Signal (SMA" + IntegerToString(SMA_Period) + ")", smaDir, (smaDir == "BUY ▲" ? COLOR_PROFIT : COLOR_LOSS), COLOR_SECTION_DETAIL); row++;

   // Buy position info
   string buyInfo = "$" + DoubleToString(plBuy, 2) + "  " + DoubleToString(lotsBuy, 2) + "L  " + IntegerToString(buyCount) + "ord";
   DrawTableRow(row, "Position BUY",  buyInfo, (plBuy >= 0 ? COLOR_PROFIT : COLOR_LOSS), COLOR_SECTION_DETAIL); row++;

   // Sell position info
   string sellInfo = "$" + DoubleToString(plSell, 2) + "  " + DoubleToString(lotsSell, 2) + "L  " + IntegerToString(sellCount) + "ord";
   DrawTableRow(row, "Position SELL", sellInfo, (plSell >= 0 ? COLOR_PROFIT : COLOR_LOSS), COLOR_SECTION_DETAIL); row++;

   DrawTableRow(row, "Current DD%",   DoubleToString(dd, 2) + "%",      (dd > 10 ? COLOR_LOSS : COLOR_TEXT), COLOR_SECTION_DETAIL); row++;
   DrawTableRow(row, "Max DD%",       DoubleToString(g_maxDD, 2) + "%",  (g_maxDD > 15 ? COLOR_LOSS : COLOR_TEXT), COLOR_SECTION_DETAIL); row++;

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
   DrawTableRow(row, "Total Closed Ord", IntegerToString(closedOrders) + " orders", COLOR_TEXT, COLOR_SECTION_HIST); row++;
   DrawTableRow(row, "Monthly P/L",      "$" + DoubleToString(monthlyPL, 2), (monthlyPL >= 0 ? COLOR_PROFIT : COLOR_LOSS), COLOR_SECTION_HIST); row++;
   DrawTableRow(row, "Total P/L",        "$" + DoubleToString(totalPLHist, 2), (totalPLHist >= 0 ? COLOR_PROFIT : COLOR_LOSS), COLOR_SECTION_HIST); row++;

   DrawTableRow(row, "Auto Re-Entry", (EnableAutoReEntry ? "ON" : "OFF"), (EnableAutoReEntry ? COLOR_PROFIT : COLOR_LOSS), COLOR_SECTION_INFO); row++;

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

   //--- Bottom border
   int bottomY = DashboardY + 24 + row * 20;
   CreateDashRect("GM_TBL_BTM", DashboardX, bottomY, tableWidth, 2, COLOR_HEADER_BG);

   //--- Control Buttons (v2.9) - below dashboard
   int btnY = bottomY + 5;
   int btnW = (tableWidth - 10) / 2;
   int btnH = 22;

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
