//+------------------------------------------------------------------+
//|                                              Jutlameasu_EA.mq5   |
//|                                    Copyright 2025, MoneyX Smart  |
//|          Jutlameasu EA v1.0 - Cross-Over TP/SL Hedging System    |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MoneyX Smart System"
#property link      "https://moneyxsmartsystem.lovable.app"
#property version   "1.00"
#property description "Jutlameasu EA v1.0 - Cross-Over TP/SL Hedging with Martingale"
#property strict

#include <Trade/Trade.mqh>

//--- License Status Enumeration
enum ENUM_LICENSE_STATUS
{
   LICENSE_VALID,
   LICENSE_EXPIRING_SOON,
   LICENSE_EXPIRED,
   LICENSE_NOT_FOUND,
   LICENSE_SUSPENDED,
   LICENSE_ERROR
};

enum ENUM_SYNC_EVENT
{
   SYNC_SCHEDULED,
   SYNC_ORDER_OPEN,
   SYNC_ORDER_CLOSE
};

struct NewsEvent
{
   string   title;
   string   country;
   datetime time;
   string   impact;
   bool     isRelevant;
};

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+

//--- General Settings
input group "=== General Settings ==="
input int              MagicNumber        = 303000;    // Magic Number
input int              MaxSlippage        = 30;        // Max Slippage (points)

//--- Zone & Lot Settings
input group "=== Zone & Lot Settings ==="
input double   InpZonePoints       = 1000;     // Zone Distance (points, 1000=10 USD for XAUUSD)
input double   InpInitialLot       = 0.10;     // Initial Lot Size
input double   InpLotMultiplier    = 2.0;      // Lot Multiplier (Martingale)
input int      InpMaxLevel         = 8;        // Max Martingale Levels
input bool     InpResetOnProfit    = true;     // Reset Lot on TP Hit

//--- TP/SL Distance Settings
input group "=== TP/SL Distance Settings ==="
input bool     InpUseCustomTPSL     = false;    // Use Custom TP/SL Distance (false=Zone)
input double   InpTPDistance         = 1500;     // TP Distance from Entry (points)
input double   InpSLDistance         = 1500;     // SL Distance from Entry (points)

//--- Accumulate Close
input group "=== Accumulate Close ==="
input bool     InpUseAccumulate     = false;    // Enable Accumulate Close
input int      InpAccMinOrders      = 4;        // Minimum Orders to Activate
input double   InpAccTarget         = 5.0;      // Accumulate Target ($)

//--- Grid Profit Side
input group "=== Grid Profit Side ==="
input bool     InpGP_Enable         = false;    // Enable Grid Profit
input int      InpGP_MaxTrades      = 3;        // Max GP Trades per Side
input double   InpGP_LotMultiplier  = 2.0;      // GP Lot Multiplier (from previous lot)
input int      InpGP_Points         = 500;      // GP Distance (points)
input bool     InpGP_OnlyNewCandle  = true;     // GP Only on New Candle

//--- Drawdown Protection
input group "=== Drawdown Protection ==="
input bool     InpUseDrawdownExit  = false;    // Enable Drawdown Protection
input double   InpMaxDrawdownPct   = 50.0;     // Max Drawdown % (emergency close all)
input bool     InpStopOnDrawdown   = true;     // Stop EA after Drawdown Close

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

//--- Spread Compensation
input group "=== Spread Compensation ==="
input double   InpSpreadCompensation = 65;      // Spread Compensation (points) for TP/SL

//--- License Settings
input group "=== License Settings ==="
input string   InpLicenseServer     = "https://lkbhomsulgycxawwlnfh.supabase.co";
input int      InpLicenseCheckMinutes = 60;
input int      InpDataSyncMinutes   = 5;

const string EA_API_SECRET = "moneyx-ea-secret-2024-secure-key-v1";

//--- Time Filter
input group "=== Time Filter ==="
input bool     InpUseTimeFilter     = false;
input string   InpSession1          = "03:10-12:40";
input string   InpSession2          = "15:10-22:00";
input string   InpSession3          = "";
input string   InpFridaySession1    = "03:10-12:40";
input string   InpFridaySession2    = "";
input string   InpFridaySession3    = "";
input bool     InpTradeMonday       = true;
input bool     InpTradeTuesday      = true;
input bool     InpTradeWednesday    = true;
input bool     InpTradeThursday     = true;
input bool     InpTradeFriday       = true;
input bool     InpTradeSaturday     = false;
input bool     InpTradeSunday       = false;

//--- News Filter
input group "=== News Filter ==="
input bool     InpEnableNewsFilter   = false;
input bool     InpNewsUseChartCurrency = false;
input string   InpNewsCurrencies     = "USD";
input bool     InpFilterLowNews      = false;
input int      InpPauseBeforeLow     = 60;
input int      InpPauseAfterLow      = 30;
input bool     InpFilterMedNews      = false;
input int      InpPauseBeforeMed     = 60;
input int      InpPauseAfterMed      = 30;
input bool     InpFilterHighNews     = true;
input int      InpPauseBeforeHigh    = 240;
input int      InpPauseAfterHigh     = 240;
input bool     InpFilterCustomNews   = true;
input string   InpCustomNewsKeywords = "PMI;Unemployment Claims;Non-Farm;FOMC;Fed Chair Powell";
input int      InpPauseBeforeCustom  = 300;
input int      InpPauseAfterCustom   = 300;

//+------------------------------------------------------------------+
//| Global Variables                                                   |
//+------------------------------------------------------------------+
CTrade         trade;

// Cross-Over State
double         g_midPrice;           // Center price of current cycle
double         g_buyEntryLevel;      // Buy Stop trigger level
double         g_sellEntryLevel;     // Sell Stop trigger level
double         g_buyTP;              // Buy TP level
double         g_buySL;              // Buy SL level
double         g_sellTP;             // Sell TP level
double         g_sellSL;             // Sell SL level
double         g_currentLot;         // Current lot size for next order
int            g_currentLevel;       // Current martingale level (0-based)
bool           g_cycleActive;        // Whether a cycle is active
string         g_lastActivatedSide;  // "BUY" or "SELL" - last side that was activated
bool           g_eaStopped;
bool           g_eaIsPaused;
double         g_maxDD;
int            g_totalCycles;        // Total completed cycles
int            g_winCycles;          // Cycles won (TP hit)
int            g_lossCycles;         // Cycles lost (max level reached)

// Pending order tracking
ulong          g_buyStopTicket;      // Current Buy Stop pending order ticket
ulong          g_sellStopTicket;     // Current Sell Stop pending order ticket

// Expected position counts for activation detection
int            g_expectedBuyCount  = 0;
int            g_expectedSellCount = 0;

// Grid Profit tracking
datetime       g_lastGPCandleTime = 0;
int            g_gpBuyCount = 0;
int            g_gpSellCount = 0;

// License Variables
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
bool g_newOrderBlocked = false;
string g_nextNewsTitle = "";
datetime g_nextNewsTime = 0;
string g_newsStatus = "OK";
datetime g_lastGoodNewsTime = 0;
bool g_usingCachedNews = false;
string g_newsCacheFile = "JutlameasuNewsCache.txt";
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
   g_isTesterMode = IsTesterMode();

   if(g_isTesterMode)
   {
      Print("JUTLAMEASU EA - TESTER MODE");
      g_isLicenseValid = true;
      g_licenseStatus = LICENSE_VALID;
   }
   else
   {
      Print("JUTLAMEASU EA - LIVE TRADING MODE");
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

   // Init state
   g_midPrice = 0;
   g_buyEntryLevel = 0;
   g_sellEntryLevel = 0;
   g_buyTP = 0;
   g_buySL = 0;
   g_sellTP = 0;
   g_sellSL = 0;
   g_currentLot = InpInitialLot;
   g_currentLevel = 0;
   g_cycleActive = false;
   g_lastActivatedSide = "";
   g_eaStopped = false;
   g_eaIsPaused = false;
   g_maxDD = 0;
   g_totalCycles = 0;
   g_winCycles = 0;
   g_lossCycles = 0;
   g_buyStopTicket = 0;
   g_sellStopTicket = 0;

   // Recover existing state from positions/orders
   RecoverState();

   // News Filter Init
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

   Print("Jutlameasu EA v1.0 initialized successfully");
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                    |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, "JM_TBL_");
   ObjectsDeleteAll(0, "JM_Btn");
   ObjectsDeleteAll(0, "JM_Line_");
   Print("Jutlameasu EA v1.0 deinitialized");
}

//+------------------------------------------------------------------+
//| Recover state from existing positions and pending orders           |
//+------------------------------------------------------------------+
void RecoverState()
{
   // Check for existing positions
   int buyCount = 0, sellCount = 0;
   CountMyPositions(buyCount, sellCount);

   // Check for existing pending orders
   int buyStopCount = 0, sellStopCount = 0;
   CountMyPendingOrders(buyStopCount, sellStopCount);

   if(buyCount > 0 || sellCount > 0 || buyStopCount > 0 || sellStopCount > 0)
   {
      g_cycleActive = true;
      Print("Recovering state: Positions B=", buyCount, " S=", sellCount,
            " Pending BS=", buyStopCount, " SS=", sellStopCount);

      // Recover GP counts
      CountGPPositions(g_gpBuyCount, g_gpSellCount);
      if(g_gpBuyCount > 0 || g_gpSellCount > 0)
         Print("Recovered GP positions: Buy=", g_gpBuyCount, " Sell=", g_gpSellCount);

      // Set expected counts to include GP positions
      g_expectedBuyCount = buyCount;
      g_expectedSellCount = sellCount;

      // Try to recover price levels from existing positions
      if(buyCount > 0)
      {
         g_lastActivatedSide = "BUY";
         RecoverLevelsFromPosition(POSITION_TYPE_BUY);
      }
      else if(sellCount > 0)
      {
         g_lastActivatedSide = "SELL";
         RecoverLevelsFromPosition(POSITION_TYPE_SELL);
      }
   }
}

//+------------------------------------------------------------------+
//| Recover price levels from existing position TP/SL                  |
//+------------------------------------------------------------------+
void RecoverLevelsFromPosition(ENUM_POSITION_TYPE side)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) != side) continue;

      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double tp = PositionGetDouble(POSITION_TP);
      double sl = PositionGetDouble(POSITION_SL);

      if(side == POSITION_TYPE_BUY)
      {
         g_buyEntryLevel = openPrice;
         g_buyTP = tp;
         g_buySL = sl;
         if(tp > 0 && sl > 0)
         {
            g_sellEntryLevel = sl + InpZonePoints * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            g_sellTP = sl;
            g_sellSL = tp;
            g_midPrice = (g_buyEntryLevel + g_sellEntryLevel) / 2.0;
         }
      }
      else
      {
         g_sellEntryLevel = openPrice;
         g_sellTP = tp;
         g_sellSL = sl;
         if(tp > 0 && sl > 0)
         {
            g_buyEntryLevel = sl - InpZonePoints * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            g_buyTP = sl;
            g_buySL = tp;
            g_midPrice = (g_buyEntryLevel + g_sellEntryLevel) / 2.0;
         }
      }

      // Recover lot level from comment
      string comment = PositionGetString(POSITION_COMMENT);
      int lvlPos = StringFind(comment, "L");
      if(lvlPos >= 3)
      {
         string lvlStr = StringSubstr(comment, lvlPos + 1);
         g_currentLevel = (int)StringToInteger(lvlStr);
         g_currentLot = InpInitialLot * MathPow(InpLotMultiplier, g_currentLevel);
      }

      break; // Use first found
   }
}

//+------------------------------------------------------------------+
//| Count positions for this EA                                        |
//+------------------------------------------------------------------+
void CountMyPositions(int &buyCount, int &sellCount)
{
   buyCount = 0;
   sellCount = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      long posType = PositionGetInteger(POSITION_TYPE);
      if(posType == POSITION_TYPE_BUY) buyCount++;
      else if(posType == POSITION_TYPE_SELL) sellCount++;
   }
}

//+------------------------------------------------------------------+
//| Count pending orders for this EA                                   |
//+------------------------------------------------------------------+
void CountMyPendingOrders(int &buyStopCount, int &sellStopCount)
{
   buyStopCount = 0;
   sellStopCount = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(OrderGetInteger(ORDER_MAGIC) != MagicNumber) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      long orderType = OrderGetInteger(ORDER_TYPE);
      if(orderType == ORDER_TYPE_BUY_STOP) buyStopCount++;
      else if(orderType == ORDER_TYPE_SELL_STOP) sellStopCount++;
   }
}

//+------------------------------------------------------------------+
//| Total positions + pending orders count                             |
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
//| Delete all pending orders for this EA                               |
//+------------------------------------------------------------------+
void DeleteAllPendingOrders()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(OrderGetInteger(ORDER_MAGIC) != MagicNumber) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      trade.OrderDelete(ticket);
   }
   g_buyStopTicket = 0;
   g_sellStopTicket = 0;
}

//+------------------------------------------------------------------+
//| Delete pending orders by specific type for this EA                 |
//+------------------------------------------------------------------+
void DeletePendingByType(ENUM_ORDER_TYPE orderType)
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong ticket = OrderGetTicket(i);
      if(ticket == 0) continue;
      if(OrderGetInteger(ORDER_MAGIC) != MagicNumber) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if((ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE) != orderType) continue;
      trade.OrderDelete(ticket);
      if(orderType == ORDER_TYPE_BUY_STOP) g_buyStopTicket = 0;
      if(orderType == ORDER_TYPE_SELL_STOP) g_sellStopTicket = 0;
   }
}

//+------------------------------------------------------------------+
//| Close all positions for this EA                                    |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      trade.PositionClose(ticket);
   }
}

//+------------------------------------------------------------------+
//| Calculate floating P/L for all positions                           |
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
//| Count GP positions by side (comment contains "JM_GP")             |
//+------------------------------------------------------------------+
void CountGPPositions(int &gpBuy, int &gpSell)
{
   gpBuy = 0;
   gpSell = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      string comment = PositionGetString(POSITION_COMMENT);
      if(StringFind(comment, "JM_GP") >= 0)
      {
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) gpBuy++;
         else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) gpSell++;
      }
   }
}

//+------------------------------------------------------------------+
//| Find the open price of the last GP order or the initial order      |
//+------------------------------------------------------------------+
double FindLastGPOrInitialPrice(ENUM_POSITION_TYPE side)
{
   double lastGPPrice = 0;
   int    lastGPNum   = -1;
   double initialPrice = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) != side) continue;

      string comment = PositionGetString(POSITION_COMMENT);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);

      int gpPos = StringFind(comment, "JM_GP#");
      if(gpPos >= 0)
      {
         string numStr = StringSubstr(comment, gpPos + 6);
         int gpNum = (int)StringToInteger(numStr);
         if(gpNum > lastGPNum)
         {
            lastGPNum = gpNum;
            lastGPPrice = openPrice;
         }
      }
      else
      {
         // Initial order (JM_BS or JM_SS)
         if(initialPrice == 0) initialPrice = openPrice;
      }
   }

   return (lastGPPrice > 0) ? lastGPPrice : initialPrice;
}

//+------------------------------------------------------------------+
//| Calculate GP lot size                                              |
//+------------------------------------------------------------------+
double CalculateGPLot(ENUM_POSITION_TYPE side, int currentGPCount)
{
   // Find the last position lot on this side (GP or initial)
   double lastLot = 0;
   int    lastGPNum = -1;
   double initialLot = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) != side) continue;

      string comment = PositionGetString(POSITION_COMMENT);
      double vol = PositionGetDouble(POSITION_VOLUME);

      int gpPos = StringFind(comment, "JM_GP#");
      if(gpPos >= 0)
      {
         string numStr = StringSubstr(comment, gpPos + 6);
         int gpNum = (int)StringToInteger(numStr);
         if(gpNum > lastGPNum)
         {
            lastGPNum = gpNum;
            lastLot = vol;
         }
      }
      else
      {
         initialLot = vol;
      }
   }

   double baseLot = (lastLot > 0) ? lastLot : initialLot;
   if(baseLot <= 0) baseLot = InpInitialLot;

   return baseLot * InpGP_LotMultiplier;
}

//+------------------------------------------------------------------+
//| Check Grid Profit conditions and open GP order                     |
//+------------------------------------------------------------------+
void CheckGridProfit(ENUM_POSITION_TYPE side, int currentGPCount)
{
   if(currentGPCount >= InpGP_MaxTrades) return;

   // OnlyNewCandle check
   if(InpGP_OnlyNewCandle)
   {
      datetime barTime = iTime(_Symbol, PERIOD_CURRENT, 0);
      if(barTime == g_lastGPCandleTime) return;
   }

   // Find last order price (GP or initial)
   double lastPrice = FindLastGPOrInitialPrice(side);
   if(lastPrice == 0) return;

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double currentPrice = (side == POSITION_TYPE_BUY) ?
      SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Check distance condition
   bool shouldOpen = false;
   if(side == POSITION_TYPE_BUY && currentPrice >= lastPrice + InpGP_Points * point)
      shouldOpen = true;
   else if(side == POSITION_TYPE_SELL && currentPrice <= lastPrice - InpGP_Points * point)
      shouldOpen = true;

   if(shouldOpen)
   {
      double lots = NormalizeLot(CalculateGPLot(side, currentGPCount));
      string comment = "JM_GP#" + IntegerToString(currentGPCount + 1);

      bool success = false;
      if(side == POSITION_TYPE_BUY)
         success = trade.Buy(lots, _Symbol, 0, 0, 0, comment);
      else
         success = trade.Sell(lots, _Symbol, 0, 0, 0, comment);

      if(success)
      {
         Print("GP ORDER OPENED: ", comment, " Side=", (side == POSITION_TYPE_BUY ? "BUY" : "SELL"),
               " Lot=", lots, " Price=", currentPrice);

         g_lastGPCandleTime = iTime(_Symbol, PERIOD_CURRENT, 0);

         // Update expected counts so STATE 2 doesn't misfire
         if(side == POSITION_TYPE_BUY)
            g_expectedBuyCount++;
         else
            g_expectedSellCount++;

         // Modify opposite pending stop with new lot
         ModifyOppositePendingAfterGP(side);
      }
   }
}

//+------------------------------------------------------------------+
//| Modify opposite pending stop after GP order opens                  |
//| Formula: newLot = sum(all positions on GP side) × InpLotMultiplier |
//+------------------------------------------------------------------+
void ModifyOppositePendingAfterGP(ENUM_POSITION_TYPE gpSide)
{
   if(gpSide == POSITION_TYPE_BUY)
   {
      double totalBuyLots = CalculateTotalLots(POSITION_TYPE_BUY);
      double newSellLot = NormalizeLot(totalBuyLots * InpLotMultiplier);

      DeletePendingByType(ORDER_TYPE_SELL_STOP);
      g_currentLot = newSellLot;
      PlaceNextPendingOrder("SELL");
      Print("GP: Updated Sell Stop lot to ", newSellLot, " (totalBuyLots=", totalBuyLots, " × ", InpLotMultiplier, ")");
   }
   else
   {
      double totalSellLots = CalculateTotalLots(POSITION_TYPE_SELL);
      double newBuyLot = NormalizeLot(totalSellLots * InpLotMultiplier);

      DeletePendingByType(ORDER_TYPE_BUY_STOP);
      g_currentLot = newBuyLot;
      PlaceNextPendingOrder("BUY");
      Print("GP: Updated Buy Stop lot to ", newBuyLot, " (totalSellLots=", totalSellLots, " × ", InpLotMultiplier, ")");
   }
}

//+------------------------------------------------------------------+
//| Normalize lot size                                                 |
//+------------------------------------------------------------------+
double NormalizeLot(double lots)
{
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   lots = MathMax(minLot, MathMin(maxLot, NormalizeDouble(MathRound(lots / lotStep) * lotStep, 2)));
   return lots;
}

//+------------------------------------------------------------------+
//| Start a new cycle - calculate levels and place pending orders      |
//+------------------------------------------------------------------+
void StartNewCycle()
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double spread = ask - bid;

   // Calculate mid price from current price
   g_midPrice = NormalizeDouble((bid + ask) / 2.0, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));

   double zonePrice = InpZonePoints * point;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   // Entry levels
   g_buyEntryLevel  = NormalizeDouble(g_midPrice + zonePrice / 2.0, digits);
   g_sellEntryLevel = NormalizeDouble(g_midPrice - zonePrice / 2.0, digits);

   // Cross-Over TP/SL with Spread Compensation
   // Buy TP/SL ตรวจกับ Bid → ใช้ค่าตรงๆ
   // Sell TP/SL ตรวจกับ Ask (= Bid + spread) → ต้อง +spreadComp เพื่อให้ trigger พร้อมกัน
   double spreadComp = InpSpreadCompensation * point;

   // Custom TP/SL Distance: ถ้าเปิดใช้ → ใช้ค่า InpTPDistance/InpSLDistance แทน zonePrice
   double tpDist = InpUseCustomTPSL ? (InpTPDistance * point) : zonePrice;
   double slDist = InpUseCustomTPSL ? (InpSLDistance * point) : zonePrice;

   double crossUp   = g_buyEntryLevel + tpDist;      // จุด cross-over ด้านบน (TP Buy)
   double crossDown = g_sellEntryLevel - tpDist;      // จุด cross-over ด้านล่าง (TP Sell)

   g_buyTP  = NormalizeDouble(crossUp, digits);                    // Bid >= crossUp
   g_buySL  = NormalizeDouble(g_buyEntryLevel - slDist, digits);   // Bid <= Buy Entry - SL dist
   g_sellSL = NormalizeDouble(g_sellEntryLevel + slDist + spreadComp, digits);  // Ask >= Sell Entry + SL dist
   g_sellTP = NormalizeDouble(crossDown + spreadComp, digits);     // Ask <= crossDown+spread

   // Reset lot and level
   g_currentLot = InpInitialLot;
   g_currentLevel = 0;
   g_lastActivatedSide = "";
   g_expectedBuyCount = 0;
   g_expectedSellCount = 0;

   // Ensure levels are valid (Buy Stop must be above Ask, Sell Stop must be below Bid)
   if(g_buyEntryLevel <= ask)
   {
       Print("WARNING: Buy Stop level ", g_buyEntryLevel, " <= Ask ", ask, " - adjusting");
       g_buyEntryLevel = NormalizeDouble(ask + 10 * point, digits);
       // Recalculate crossUp and TP/SL using tpDist/slDist
       double crossUp_adj = g_buyEntryLevel + tpDist;
       g_buyTP  = NormalizeDouble(crossUp_adj, digits);
       g_sellSL = NormalizeDouble(g_sellEntryLevel + slDist + spreadComp, digits);
   }
   if(g_sellEntryLevel >= bid)
   {
      Print("WARNING: Sell Stop level ", g_sellEntryLevel, " >= Bid ", bid, " - adjusting");
      g_sellEntryLevel = NormalizeDouble(bid - 10 * point, digits);
      // Recalculate crossDown and TP/SL using tpDist/slDist
      double crossDown_adj = g_sellEntryLevel - tpDist;
      g_buySL  = NormalizeDouble(g_buyEntryLevel - slDist, digits);
      g_sellTP = NormalizeDouble(crossDown_adj + spreadComp, digits);
   }

   // Place Buy Stop
   double lotBuy = NormalizeLot(g_currentLot);
   string commentBuy = "JM_BS_L0";
   if(trade.BuyStop(lotBuy, g_buyEntryLevel, _Symbol, g_buySL, g_buyTP, ORDER_TIME_GTC, 0, commentBuy))
   {
      g_buyStopTicket = trade.ResultOrder();
      Print("Buy Stop placed: Price=", g_buyEntryLevel, " TP=", g_buyTP, " SL=", g_buySL, " Lot=", lotBuy);
   }
   else
   {
      Print("ERROR: Buy Stop failed - ", trade.ResultRetcodeDescription());
   }

   // Place Sell Stop
   double lotSell = NormalizeLot(g_currentLot);
   string commentSell = "JM_SS_L0";
   if(trade.SellStop(lotSell, g_sellEntryLevel, _Symbol, g_sellSL, g_sellTP, ORDER_TIME_GTC, 0, commentSell))
   {
      g_sellStopTicket = trade.ResultOrder();
      Print("Sell Stop placed: Price=", g_sellEntryLevel, " TP=", g_sellTP, " SL=", g_sellSL, " Lot=", lotSell);
   }
   else
   {
      Print("ERROR: Sell Stop failed - ", trade.ResultRetcodeDescription());
   }

   g_cycleActive = true;
   Print("NEW CYCLE STARTED: Mid=", g_midPrice, " BuyEntry=", g_buyEntryLevel, " SellEntry=", g_sellEntryLevel);
}

//+------------------------------------------------------------------+
//| Place a new pending order on one side (after activation)           |
//+------------------------------------------------------------------+
void PlaceNextPendingOrder(string side)
{
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   if(side == "BUY")
   {
      // Place Buy Stop at same level with doubled lot
      double lot = NormalizeLot(g_currentLot);
      string comment = "JM_BS_L" + IntegerToString(g_currentLevel);
      
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      
      // Ensure Buy Stop is above current ask
      double buyPrice = g_buyEntryLevel;
      if(buyPrice <= ask)
      {
         Print("Buy Stop level at or below Ask - position may have already been triggered");
         return;
      }
      
      if(trade.BuyStop(lot, buyPrice, _Symbol, g_buySL, g_buyTP, ORDER_TIME_GTC, 0, comment))
      {
         g_buyStopTicket = trade.ResultOrder();
         Print("Buy Stop placed (Level ", g_currentLevel, "): Price=", buyPrice, " Lot=", lot);
      }
      else
      {
         Print("ERROR: Buy Stop failed - ", trade.ResultRetcodeDescription());
      }
   }
   else if(side == "SELL")
   {
      double lot = NormalizeLot(g_currentLot);
      string comment = "JM_SS_L" + IntegerToString(g_currentLevel);
      
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      
      double sellPrice = g_sellEntryLevel;
      if(sellPrice >= bid)
      {
         Print("Sell Stop level at or above Bid - position may have already been triggered");
         return;
      }
      
      if(trade.SellStop(lot, sellPrice, _Symbol, g_sellSL, g_sellTP, ORDER_TIME_GTC, 0, comment))
      {
         g_sellStopTicket = trade.ResultOrder();
         Print("Sell Stop placed (Level ", g_currentLevel, "): Price=", sellPrice, " Lot=", lot);
      }
      else
      {
         Print("ERROR: Sell Stop failed - ", trade.ResultRetcodeDescription());
      }
   }
}

//+------------------------------------------------------------------+
//| OnTick - Main trading logic                                        |
//+------------------------------------------------------------------+
void OnTick()
{
   // === LICENSE CHECK ===
   if(!g_isTesterMode)
   {
      if(!OnTickLicense()) return;
   }
   if(!g_isLicenseValid && !g_isTesterMode) return;

   // === NEWS FILTER ===
   RefreshNewsData();

   // === Determine if new orders are blocked ===
   g_newOrderBlocked = false;
   if(g_eaIsPaused) g_newOrderBlocked = true;
   if(IsNewsTimePaused()) g_newOrderBlocked = true;
   if(InpUseTimeFilter && !IsWithinTradingHours()) g_newOrderBlocked = true;

   if(g_eaStopped) return;

   // === DRAWDOWN CHECK ===
   CheckDrawdownExit();

   // === ACCUMULATE CLOSE CHECK ===
   if(InpUseAccumulate) CheckAccumulateClose();

   // === Track max drawdown ===
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(balance > 0)
   {
      double dd = (balance - equity) / balance * 100.0;
      if(dd > g_maxDD) g_maxDD = dd;
   }

   // === MAIN CROSS-OVER LOGIC ===

   int buyCount = 0, sellCount = 0;
   CountMyPositions(buyCount, sellCount);

   int buyStopCount = 0, sellStopCount = 0;
   CountMyPendingOrders(buyStopCount, sellStopCount);

   int totalPositions = buyCount + sellCount;
   int totalPending = buyStopCount + sellStopCount;

   // STATE 1: No positions, no pending, no active cycle → Start new cycle
   if(totalPositions == 0 && totalPending == 0 && !g_cycleActive && !g_newOrderBlocked)
   {
      StartNewCycle();
      if(ShowDashboard) DisplayDashboard();
      return;
   }

   // STATE 2: Check if a pending order was activated (position exists but was pending before)
   // Detect: We had a pending, now we have a position → the pending was triggered
   
   // Check if Buy Stop was triggered (new BUY position appeared)
   if(buyCount > g_expectedBuyCount)
   {
      g_expectedBuyCount = buyCount;
      g_lastActivatedSide = "BUY";
      g_currentLevel++;
      g_currentLot = InpInitialLot * MathPow(InpLotMultiplier, g_currentLevel);
      Print("BUY STOP ACTIVATED → Level ", g_currentLevel, " Lot ", g_currentLot,
            " expectedBuy=", g_expectedBuyCount, " expectedSell=", g_expectedSellCount);

      // Delete old Sell Stop (original lot) and replace with Martingale lot
      if(sellStopCount > 0) DeletePendingByType(ORDER_TYPE_SELL_STOP);
      if(g_currentLevel < InpMaxLevel) PlaceNextPendingOrder("SELL");
      
      if(ShowDashboard) DisplayDashboard();
      return;
   }

   // Check if Sell Stop was triggered (new SELL position appeared)
   if(sellCount > g_expectedSellCount)
   {
      g_expectedSellCount = sellCount;
      g_lastActivatedSide = "SELL";
      g_currentLevel++;
      g_currentLot = InpInitialLot * MathPow(InpLotMultiplier, g_currentLevel);
      Print("SELL STOP ACTIVATED → Level ", g_currentLevel, " Lot ", g_currentLot,
            " expectedBuy=", g_expectedBuyCount, " expectedSell=", g_expectedSellCount);

      // Delete old Buy Stop (original lot) and replace with Martingale lot
      if(buyStopCount > 0) DeletePendingByType(ORDER_TYPE_BUY_STOP);
      if(g_currentLevel < InpMaxLevel) PlaceNextPendingOrder("BUY");
      
      if(ShowDashboard) DisplayDashboard();
      return;
   }

   // STATE 2.5: Position closed (TP/SL hit) but opposite pending still exists
   // Only trigger if a side was previously activated (not at cycle start)
   if(totalPositions == 0 && totalPending > 0 && g_cycleActive && g_lastActivatedSide != "")
   {
      Print("Jutlameasu: All positions closed (TP/SL hit), cleaning remaining pending orders for cycle reset");
      DeleteAllPendingOrders();
      return; // Next tick → STATE 3 will detect cycle end and reset
   }

   // STATE 3: Check if cycle ended (all positions AND pending orders gone)
   // Double-check with stored tickets to avoid timing issues in backtester
   bool buyStopExists = (g_buyStopTicket > 0 && OrderSelect(g_buyStopTicket));
   bool sellStopExists = (g_sellStopTicket > 0 && OrderSelect(g_sellStopTicket));
   
   if(totalPositions == 0 && totalPending == 0 && !buyStopExists && !sellStopExists && g_cycleActive)
   {
      // Cycle ended - determine if it was TP or SL
      bool wasTP = CheckLastDealWasTP();
      
      // Clear stored tickets (no need to delete - they're already gone)
      g_buyStopTicket = 0;
      g_sellStopTicket = 0;

      g_totalCycles++;
      if(wasTP)
      {
         g_winCycles++;
         Print("CYCLE ENDED - TP HIT! Total Cycles: ", g_totalCycles, " Wins: ", g_winCycles);
      }
      else
      {
         Print("CYCLE ENDED - SL or other. Total Cycles: ", g_totalCycles);
      }

      // Reset for next cycle
      g_cycleActive = false;
      g_lastActivatedSide = "";
      g_currentLevel = 0;
      g_currentLot = InpInitialLot;
      g_expectedBuyCount = 0;
      g_expectedSellCount = 0;

      // Don't start new cycle immediately if blocked
      if(!g_newOrderBlocked)
      {
         StartNewCycle();
      }
   }

   // STATE 4: Max level protection
   if(g_currentLevel >= InpMaxLevel && totalPositions > 0)
   {
      Print("MAX MARTINGALE LEVEL REACHED (", InpMaxLevel, ") - Monitoring...");
      // Let the last position play out with its TP/SL
   }

   // Draw chart lines
   DrawChartLines();

   // Display dashboard
   if(ShowDashboard) DisplayDashboard();
}

//+------------------------------------------------------------------+
//| Check if last closed deal was a TP hit                             |
//+------------------------------------------------------------------+
bool CheckLastDealWasTP()
{
   if(!HistorySelect(TimeCurrent() - 300, TimeCurrent())) return false;
   
   int totalDeals = HistoryDealsTotal();
   for(int i = totalDeals - 1; i >= 0; i--)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;
      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != MagicNumber) continue;
      if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) continue;
      
      long dealEntry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_INOUT)
      {
         double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
         return (profit > 0);
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Check Drawdown Exit                                                |
//+------------------------------------------------------------------+
void CheckDrawdownExit()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(balance <= 0) return;
   if(!InpUseDrawdownExit) return;

   double dd = (balance - equity) / balance * 100.0;

   if(dd >= InpMaxDrawdownPct)
   {
      Print("EMERGENCY DD: ", DoubleToString(dd, 2), "% >= ", InpMaxDrawdownPct, "% - Closing ALL!");
      CloseAllPositions();
      DeleteAllPendingOrders();

      g_cycleActive = false;
      g_currentLevel = 0;
      g_currentLot = InpInitialLot;
      g_lastActivatedSide = "";
      g_expectedBuyCount = 0;
      g_expectedSellCount = 0;

      if(InpStopOnDrawdown)
      {
         g_eaStopped = true;
         Print("EA STOPPED by Max Drawdown");
      }
   }
}

//+------------------------------------------------------------------+
//| Check Accumulate Close - close all when floating P/L hits target  |
//+------------------------------------------------------------------+
void CheckAccumulateClose()
{
   if(!InpUseAccumulate) return;

   // Count positions with our magic number
   int posCount = 0;
   double totalPL = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      posCount++;
      totalPL += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }

   // Check conditions: minimum orders met AND floating P/L >= target
   if(posCount >= InpAccMinOrders && totalPL >= InpAccTarget)
   {
      Print("ACCUMULATE CLOSE: ", posCount, " positions, Float P/L=$", DoubleToString(totalPL, 2),
            " >= Target $", DoubleToString(InpAccTarget, 2), " → Closing ALL!");
      CloseAllPositions();
      DeleteAllPendingOrders();

      // Reset cycle
      g_cycleActive = false;
      g_currentLevel = 0;
      g_currentLot = InpInitialLot;
      g_lastActivatedSide = "";
      g_expectedBuyCount = 0;
      g_expectedSellCount = 0;
      g_totalCycles++;
      g_winCycles++;
      Print("ACCUMULATE CLOSE: Cycle completed successfully");
   }
}

//+------------------------------------------------------------------+
//| Draw chart lines for price levels                                  |
//+------------------------------------------------------------------+
void DrawChartLines()
{
   if(!g_cycleActive) return;

   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   // Mid price
   DrawHLine("JM_Line_Mid", g_midPrice, clrGray, STYLE_DOT, 1);
   // Buy Entry
   DrawHLine("JM_Line_BuyEntry", g_buyEntryLevel, clrDodgerBlue, STYLE_SOLID, 2);
   // Sell Entry
   DrawHLine("JM_Line_SellEntry", g_sellEntryLevel, clrOrangeRed, STYLE_SOLID, 2);
   // Buy TP
   DrawHLine("JM_Line_BuyTP", g_buyTP, clrLime, STYLE_DASH, 1);
   // Buy SL = Sell TP
   DrawHLine("JM_Line_BuySL", g_buySL, clrRed, STYLE_DASH, 1);
}

//+------------------------------------------------------------------+
//| Draw horizontal line                                               |
//+------------------------------------------------------------------+
void DrawHLine(string name, double price, color clr, ENUM_LINE_STYLE style, int width)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
   ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| CalcTotalHistoryProfit                                              |
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
//| CalcTotalClosedLots                                                |
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
//| CalcDailyPL                                                        |
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
void CreateDashRect(string name, int x, int y, int w, int h, color bgColor)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
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
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
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
   int tblW = (int)(360 * sc);
   int rH = (int)(19 * sc);
   int sectionBarWidth = (int)(4 * sc);
   int labelX = x + sectionBarWidth + (int)(6 * sc);
   int valueX = x + (int)(180 * sc);
   int fSize = (int)(9 * sc);
   if(fSize < 7) fSize = 7;

   color rowBg = (rowIndex % 2 == 0) ? C'40,44,52' : C'35,39,46';

   string rowName = "JM_TBL_R" + IntegerToString(rowIndex);
   string secName = "JM_TBL_S" + IntegerToString(rowIndex);
   string lblName = "JM_TBL_L" + IntegerToString(rowIndex);
   string valName = "JM_TBL_V" + IntegerToString(rowIndex);

   CreateDashRect(rowName, x, y, tblW, rH, rowBg);
   CreateDashRect(secName, x, y, sectionBarWidth, rH, sectionColor);
   CreateDashText(lblName, labelX, y + 2, label, C'180,180,180', fSize, "Consolas");
   CreateDashText(valName, valueX, y + 2, value, valueColor, fSize, "Consolas");
}

//+------------------------------------------------------------------+
//| Dashboard Helper: Create Button                                    |
//+------------------------------------------------------------------+
void CreateDashButton(string name, int x, int y, int width, int height, string text, color bgColor, color textColor)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
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
//| Display Dashboard                                                  |
//+------------------------------------------------------------------+
void DisplayDashboard()
{
   double sc = MathMax(0.8, MathMin(1.5, DashboardScale));
   int tableWidth = (int)(360 * sc);
   int headerHeight = (int)(22 * sc);
   int headerFontSize = (int)(11 * sc);
   if(headerFontSize < 8) headerFontSize = 8;
   int subFontSize = (int)(9 * sc);
   if(subFontSize < 7) subFontSize = 7;

   color COLOR_HEADER_BG     = C'45,120,180';
   color COLOR_HEADER_TEXT   = clrWhite;
   color COLOR_SECTION_ZONE  = clrDodgerBlue;
   color COLOR_SECTION_TRADE = clrGreen;
   color COLOR_SECTION_INFO  = clrGold;
   color COLOR_SECTION_NEWS  = clrMagenta;
   color COLOR_PROFIT        = clrLime;
   color COLOR_LOSS          = clrOrangeRed;
   color COLOR_TEXT          = clrWhite;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double totalPL = CalculateTotalFloatingPL();
   double dd = (balance > 0) ? (balance - equity) / balance * 100.0 : 0;
   double lotsBuy = CalculateTotalLots(POSITION_TYPE_BUY);
   double lotsSell = CalculateTotalLots(POSITION_TYPE_SELL);

   int buyCount = 0, sellCount = 0;
   CountMyPositions(buyCount, sellCount);
   int buyStopCount = 0, sellStopCount = 0;
   CountMyPendingOrders(buyStopCount, sellStopCount);

   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double dailyPL = CalcDailyPL();
   double totalHistoryPL = CalcTotalHistoryProfit();

   // Header
   string statusText = g_eaStopped ? " [STOPPED]" : (g_eaIsPaused ? " [PAUSED]" : "");
   CreateDashRect("JM_TBL_HDR", DashboardX, DashboardY, tableWidth, headerHeight, COLOR_HEADER_BG);
   CreateDashText("JM_TBL_HDR_T", DashboardX + 8, DashboardY + 3,
                  "Jutlameasu EA v1.0" + statusText, COLOR_HEADER_TEXT, headerFontSize, "Arial Bold");

   int row = 0;

   // === ZONE SECTION ===
   DrawTableRow(row, "Mid Price",     DoubleToString(g_midPrice, digits), COLOR_TEXT, COLOR_SECTION_ZONE); row++;
   DrawTableRow(row, "Buy Entry",     DoubleToString(g_buyEntryLevel, digits), clrDodgerBlue, COLOR_SECTION_ZONE); row++;
   DrawTableRow(row, "Sell Entry",    DoubleToString(g_sellEntryLevel, digits), clrOrangeRed, COLOR_SECTION_ZONE); row++;
   DrawTableRow(row, "Buy TP / Sell SL", DoubleToString(g_buyTP, digits), COLOR_PROFIT, COLOR_SECTION_ZONE); row++;
   DrawTableRow(row, "Buy SL",          DoubleToString(g_buySL, digits), COLOR_LOSS, COLOR_SECTION_ZONE); row++;
   DrawTableRow(row, "Sell TP / Buy SL", DoubleToString(g_sellTP, digits), COLOR_LOSS, COLOR_SECTION_ZONE); row++;
   DrawTableRow(row, "Sell SL",          DoubleToString(g_sellSL, digits), COLOR_LOSS, COLOR_SECTION_ZONE); row++;

   // TP/SL Distance mode
   string tpslMode = InpUseCustomTPSL ? ("Custom TP:" + DoubleToString(InpTPDistance, 0) + " SL:" + DoubleToString(InpSLDistance, 0))
                                      : ("Zone " + DoubleToString(InpZonePoints, 0) + " pts");
   DrawTableRow(row, "TP/SL Dist",     tpslMode, clrCyan, COLOR_SECTION_ZONE); row++;

   // === TRADE SECTION ===
   DrawTableRow(row, "Balance",       "$" + DoubleToString(balance, 2), COLOR_TEXT, COLOR_SECTION_TRADE); row++;
   DrawTableRow(row, "Equity",        "$" + DoubleToString(equity, 2), COLOR_TEXT, COLOR_SECTION_TRADE); row++;
   DrawTableRow(row, "Floating P/L",  "$" + DoubleToString(totalPL, 2), (totalPL >= 0 ? COLOR_PROFIT : COLOR_LOSS), COLOR_SECTION_TRADE); row++;

   string buyInfo = IntegerToString(buyCount) + " pos / " + DoubleToString(lotsBuy, 2) + " lot";
   string sellInfo = IntegerToString(sellCount) + " pos / " + DoubleToString(lotsSell, 2) + " lot";
   DrawTableRow(row, "BUY Positions", buyInfo, clrDodgerBlue, COLOR_SECTION_TRADE); row++;
   DrawTableRow(row, "SELL Positions", sellInfo, clrOrangeRed, COLOR_SECTION_TRADE); row++;

   string pendingInfo = "BS:" + IntegerToString(buyStopCount) + " SS:" + IntegerToString(sellStopCount);
   DrawTableRow(row, "Pending Orders", pendingInfo, COLOR_TEXT, COLOR_SECTION_TRADE); row++;

   // === INFO SECTION ===
   DrawTableRow(row, "Martingale Lv", IntegerToString(g_currentLevel) + " / " + IntegerToString(InpMaxLevel),
                (g_currentLevel > InpMaxLevel / 2 ? COLOR_LOSS : COLOR_TEXT), COLOR_SECTION_INFO); row++;
   DrawTableRow(row, "Next Lot",      DoubleToString(NormalizeLot(g_currentLot), 2),
                (g_currentLevel > 3 ? COLOR_LOSS : COLOR_TEXT), COLOR_SECTION_INFO); row++;

   string sideStr = (g_lastActivatedSide == "") ? "WAITING" : g_lastActivatedSide;
   color sideColor = (g_lastActivatedSide == "BUY") ? clrDodgerBlue :
                     (g_lastActivatedSide == "SELL") ? clrOrangeRed : clrYellow;
   DrawTableRow(row, "Last Activated", sideStr, sideColor, COLOR_SECTION_INFO); row++;

   DrawTableRow(row, "Current DD%",   DoubleToString(dd, 2) + "% / " + DoubleToString(InpMaxDrawdownPct, 1) + "%",
                (dd > InpMaxDrawdownPct * 0.5 ? COLOR_LOSS : COLOR_TEXT), COLOR_SECTION_INFO); row++;
   DrawTableRow(row, "Max DD%",       DoubleToString(g_maxDD, 2) + "%",
                (g_maxDD > 15 ? COLOR_LOSS : COLOR_TEXT), COLOR_SECTION_INFO); row++;

   DrawTableRow(row, "Cycles (W/T)",  IntegerToString(g_winCycles) + " / " + IntegerToString(g_totalCycles),
                COLOR_TEXT, COLOR_SECTION_INFO); row++;

   // === ACCUMULATE CLOSE SECTION ===
   if(InpUseAccumulate)
   {
      color COLOR_SECTION_ACC = C'120,60,120';
      int totalPos = buyCount + sellCount;
      string accStatus = (totalPos >= InpAccMinOrders) ? "ACTIVE" : "WAIT (" + IntegerToString(totalPos) + "/" + IntegerToString(InpAccMinOrders) + ")";
      color accStatusColor = (totalPos >= InpAccMinOrders) ? COLOR_PROFIT : clrYellow;
      DrawTableRow(row, "Accumulate",    accStatus, accStatusColor, COLOR_SECTION_ACC); row++;
      DrawTableRow(row, "Acc Target",    "$" + DoubleToString(InpAccTarget, 2) + " | Float: $" + DoubleToString(totalPL, 2),
                   (totalPL >= InpAccTarget ? COLOR_PROFIT : COLOR_TEXT), COLOR_SECTION_ACC); row++;
   }

   // === HISTORY SECTION ===
   color COLOR_SECTION_HIST   = C'40,60,100';
   color COLOR_SECTION_REBATE = C'100,80,30';

   double totalCurLot = lotsBuy + lotsSell;
   double closedLots = CalcTotalClosedLots();
   double dailyClosedLots = CalcDailyClosedLots();
   int    closedOrders = CalcTotalClosedOrders();
   double monthlyPL = CalcMonthlyPL();

   DrawTableRow(row, "Total Cur. Lot",   DoubleToString(totalCurLot, 2) + " L", COLOR_TEXT, COLOR_SECTION_HIST); row++;
   DrawTableRow(row, "Total Closed Lot", DoubleToString(closedLots, 2) + " L", COLOR_TEXT, COLOR_SECTION_HIST); row++;
   DrawTableRow(row, "Daily Closed Lot", DoubleToString(dailyClosedLots, 2) + " L", COLOR_TEXT, COLOR_SECTION_HIST); row++;

   double dailyRebate = dailyClosedLots * InpRebatePerLot;
   double totalRebate = closedLots * InpRebatePerLot;
   DrawTableRow(row, "Daily Rebate",     "$" + DoubleToString(dailyRebate, 2), COLOR_PROFIT, COLOR_SECTION_REBATE); row++;
   DrawTableRow(row, "Total Rebate",     "$" + DoubleToString(totalRebate, 2), COLOR_PROFIT, COLOR_SECTION_REBATE); row++;

   DrawTableRow(row, "Total Closed Ord", IntegerToString(closedOrders) + " orders", COLOR_TEXT, COLOR_SECTION_HIST); row++;
   DrawTableRow(row, "Monthly P/L",      "$" + DoubleToString(monthlyPL, 2),
                (monthlyPL >= 0 ? COLOR_PROFIT : COLOR_LOSS), COLOR_SECTION_HIST); row++;
   DrawTableRow(row, "Daily P/L",        "$" + DoubleToString(dailyPL, 2),
                (dailyPL >= 0 ? COLOR_PROFIT : COLOR_LOSS), COLOR_SECTION_HIST); row++;
   DrawTableRow(row, "Total P/L",        "$" + DoubleToString(totalHistoryPL, 2),
                (totalHistoryPL >= 0 ? COLOR_PROFIT : COLOR_LOSS), COLOR_SECTION_HIST); row++;

   // === NEWS/TIME STATUS ===
   string licStr = g_isLicenseValid ? "VALID" : "INVALID";
   color licColor = g_isLicenseValid ? COLOR_PROFIT : COLOR_LOSS;
   DrawTableRow(row, "License",       licStr, licColor, COLOR_SECTION_NEWS); row++;

   if(InpUseTimeFilter)
   {
      bool inHours = IsWithinTradingHours();
      DrawTableRow(row, "Time Filter", inHours ? "IN SESSION" : "OUT OF SESSION",
                   inHours ? COLOR_PROFIT : COLOR_LOSS, COLOR_SECTION_NEWS); row++;
   }

   if(InpEnableNewsFilter)
   {
      DrawTableRow(row, "News Filter", g_newsStatus,
                   g_isNewsPaused ? COLOR_LOSS : COLOR_PROFIT, COLOR_SECTION_NEWS); row++;
   }

   // Buttons
   int btnY = DashboardY + (int)(24 * sc) + row * (int)(20 * sc) + 5;
   int btnW = (int)(85 * sc);
   int btnH = (int)(22 * sc);

   CreateDashButton("JM_BtnPause", DashboardX, btnY, btnW, btnH,
                    g_eaIsPaused ? "RESUME" : "PAUSE",
                    g_eaIsPaused ? C'0,120,0' : C'180,50,50', clrWhite);
   CreateDashButton("JM_BtnCloseAll", DashboardX + btnW + 5, btnY, btnW, btnH,
                    "CLOSE ALL", C'180,50,50', clrWhite);
   CreateDashButton("JM_BtnNewCycle", DashboardX + 2 * (btnW + 5), btnY, btnW + 10, btnH,
                    "NEW CYCLE", C'50,120,180', clrWhite);

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| OnChartEvent - Button handler                                      |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam == "JM_BtnPause")
      {
         g_eaIsPaused = !g_eaIsPaused;
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         Print("EA ", g_eaIsPaused ? "PAUSED" : "RESUMED", " by user");
      }
      else if(sparam == "JM_BtnCloseAll")
      {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         int result = MessageBox("Close ALL positions and pending orders?", "Confirm Close All", MB_YESNO | MB_ICONWARNING);
         if(result == IDYES)
         {
            CloseAllPositions();
            DeleteAllPendingOrders();
            g_cycleActive = false;
            g_currentLevel = 0;
            g_currentLot = InpInitialLot;
            g_lastActivatedSide = "";
            Print("All positions and pending orders closed by user");
         }
      }
      else if(sparam == "JM_BtnNewCycle")
      {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         int result = MessageBox("Start a new cycle? (Current positions/orders will be closed)", "New Cycle", MB_YESNO | MB_ICONQUESTION);
         if(result == IDYES)
         {
            CloseAllPositions();
            DeleteAllPendingOrders();
            g_cycleActive = false;
            g_currentLevel = 0;
            g_currentLot = InpInitialLot;
            g_lastActivatedSide = "";
            g_expectedBuyCount = 0;
            g_expectedSellCount = 0;
            g_eaStopped = false;
            StartNewCycle();
            Print("New cycle started by user command");
         }
      }
      ChartRedraw(0);
   }
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
               SyncAccountDataWithEvent(SYNC_ORDER_OPEN);
            }
            else if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_INOUT)
            {
               SyncAccountDataWithEvent(SYNC_ORDER_CLOSE);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| ============== LICENSE MODULE ================================== |
//+------------------------------------------------------------------+

bool IsTesterMode()
{
   return (MQLInfoInteger(MQL_TESTER) ||
           MQLInfoInteger(MQL_OPTIMIZATION) ||
           MQLInfoInteger(MQL_VISUAL_MODE) ||
           MQLInfoInteger(MQL_FRAME_MODE));
}

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
      g_expiryDate = StringToTime(StringSubstr(expiryStr, 0, 10));

   if(!g_isLifetime && g_daysRemaining <= 7 && g_daysRemaining > 0)
      return LICENSE_EXPIRING_SOON;

   return LICENSE_VALID;
}

bool SyncAccountData()
{
   return SyncAccountDataWithEvent(SYNC_SCHEDULED);
}

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

   double totalProfit = 0, totalDeposit = 0, totalWithdrawal = 0;
   double initialBalance = 0, maxDrawdown = 0;
   int winTrades = 0, lossTrades = 0, totalTrades = 0;
   CalculatePortfolioStats(totalProfit, totalDeposit, totalWithdrawal, initialBalance,
                           maxDrawdown, winTrades, lossTrades, totalTrades);

   string eventTypeStr = "scheduled";
   if(eventType == SYNC_ORDER_OPEN) eventTypeStr = "order_open";
   else if(eventType == SYNC_ORDER_CLOSE) eventTypeStr = "order_close";

   string eaStatus = "working";
   if(g_licenseStatus == LICENSE_SUSPENDED) eaStatus = "suspended";
   else if(g_licenseStatus == LICENSE_EXPIRED) eaStatus = "expired";
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
   json += "\"ea_name\":\"Jutlameasu EA\",";
   json += "\"ea_status\":\"" + eaStatus + "\",";
   json += "\"currency\":\"" + accountCurrency + "\",";
   json += "\"account_type\":\"" + accountTypeStr + "\"";

   string tradeHistoryJson = BuildTradeHistoryJson();
   if(StringLen(tradeHistoryJson) > 2)
      json += ",\"trade_history\":" + tradeHistoryJson;

   json += "}";

   string response = "";
   int httpCode = SendLicenseRequest(url, json, response);
   if(httpCode != 200)
   {
      g_lastLicenseError = "Sync HTTP Error: " + IntegerToString(httpCode);
      return false;
   }
   bool success = JsonGetBool(response, "success");
   if(success) Print("[Sync] Data synced (", eventTypeStr, ")");
   return success;
}

void CalculatePortfolioStats(double &totalProfit, double &totalDeposit, double &totalWithdrawal,
                             double &initialBalance, double &maxDrawdown,
                             int &winTrades, int &lossTrades, int &totalTrades)
{
   totalProfit = 0; totalDeposit = 0; totalWithdrawal = 0;
   initialBalance = 0; maxDrawdown = 0;
   winTrades = 0; lossTrades = 0; totalTrades = 0;
   if(!HistorySelect(0, TimeCurrent())) return;

   int totalDeals = HistoryDealsTotal();
   double peakBalance = 0, runningBalance = 0;
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
               if(firstDeposit) { initialBalance = dealProfit; firstDeposit = false; }
            }
            else
               totalWithdrawal += MathAbs(dealProfit);
            runningBalance += dealProfit;
         }
         else if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_INOUT)
         {
            double netProfit = dealProfit + dealSwap + dealCommission;
            totalProfit += netProfit;
            runningBalance += netProfit;
            totalTrades++;
            if(netProfit >= 0) winTrades++; else lossTrades++;
         }

         if(runningBalance > peakBalance) peakBalance = runningBalance;
         if(peakBalance > 0)
         {
            double currentDD = ((peakBalance - runningBalance) / peakBalance) * 100;
            if(currentDD > maxDrawdown) maxDrawdown = currentDD;
         }
      }
   }
}

string BuildTradeHistoryJson()
{
   string json = "[";
   bool first = true;
   if(!HistorySelect(0, TimeCurrent())) return "[]";

   int totalDeals = HistoryDealsTotal();
   int startIdx = MathMax(0, totalDeals - 100);

   for(int i = startIdx; i < totalDeals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket > 0)
      {
         ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(dealTicket, DEAL_TYPE);
         ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
         if(dealType != DEAL_TYPE_BUY && dealType != DEAL_TYPE_SELL && dealType != DEAL_TYPE_BALANCE) continue;

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

         string dealTypeStr = (dealType == DEAL_TYPE_BUY) ? "buy" : (dealType == DEAL_TYPE_SELL) ? "sell" : "balance";
         string entryTypeStr = (dealEntry == DEAL_ENTRY_IN) ? "in" : (dealEntry == DEAL_ENTRY_OUT) ? "out" : "inout";

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
         if(!g_isLicenseValid) ShowLicensePopup(g_licenseStatus);
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

void ShowLicensePopup(ENUM_LICENSE_STATUS status)
{
   string title = "Jutlameasu EA - License";
   string message = "";
   uint flags = MB_OK;

   switch(status)
   {
      case LICENSE_VALID:
      {
         message = "License Verified Successfully!\n\nCustomer: " + g_customerName + "\nPackage: " + g_packageType + "\nSystem: " + g_tradingSystem + "\n\n";
         if(g_isLifetime) message += "License Type: LIFETIME\n";
         else message += "Expires: " + TimeToString(g_expiryDate, TIME_DATE) + "\n";
         message += "\nHappy Trading!";
         flags = MB_OK | MB_ICONINFORMATION;
         break;
      }
      case LICENSE_EXPIRING_SOON:
      {
         message = "License Expiring Soon!\n\nDays Remaining: " + IntegerToString(g_daysRemaining) + "\nExpires: " + TimeToString(g_expiryDate, TIME_DATE) + "\n\nPlease renew.";
         flags = MB_OK | MB_ICONWARNING;
         break;
      }
      case LICENSE_EXPIRED:
      {
         message = "License Expired!\n\nTrading is disabled.\nPlease renew.";
         flags = MB_OK | MB_ICONERROR;
         break;
      }
      case LICENSE_NOT_FOUND:
      {
         message = "Account Not Registered!\n\nAccount: " + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "\n\nPlease purchase a license.";
         flags = MB_OK | MB_ICONERROR;
         break;
      }
      case LICENSE_SUSPENDED:
      {
         message = "License Suspended!\n\nTrading is disabled.\nContact support.";
         flags = MB_OK | MB_ICONERROR;
         break;
      }
      case LICENSE_ERROR:
      {
         message = "License Verification Error!\n\nError: " + g_lastLicenseError + "\n\nPlease check internet and WebRequest settings.";
         flags = MB_OK | MB_ICONWARNING;
         break;
      }
   }
   MessageBox(message, title, flags);
}

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
         g_lastLicenseError = "WebRequest not allowed. Add URL: " + g_licenseServerUrl;
      return -1;
   }

   response = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
   return httpCode;
}

//+------------------------------------------------------------------+
//| JSON Helpers                                                       |
//+------------------------------------------------------------------+
string JsonGetString(string json, string key)
{
   string searchKey = "\"" + key + "\":";
   int keyPos = StringFind(json, searchKey);
   if(keyPos < 0) return "";
   int valueStart = keyPos + StringLen(searchKey);
   while(valueStart < StringLen(json) && (StringGetCharacter(json, valueStart) == ' ' || StringGetCharacter(json, valueStart) == '\t'))
      valueStart++;
   if(StringSubstr(json, valueStart, 4) == "null") return "";
   if(StringGetCharacter(json, valueStart) == '"')
   {
      valueStart++;
      int valueEnd = StringFind(json, "\"", valueStart);
      if(valueEnd < 0) return "";
      return StringSubstr(json, valueStart, valueEnd - valueStart);
   }
   int valueEnd = valueStart;
   while(valueEnd < StringLen(json))
   {
      ushort ch = StringGetCharacter(json, valueEnd);
      if(ch == ',' || ch == '}' || ch == ']') break;
      valueEnd++;
   }
   return StringSubstr(json, valueStart, valueEnd - valueStart);
}

int JsonGetInt(string json, string key)
{
   string value = JsonGetString(json, key);
   if(StringLen(value) == 0) return 0;
   return (int)StringToInteger(value);
}

bool JsonGetBool(string json, string key)
{
   string value = JsonGetString(json, key);
   return (value == "true" || value == "1");
}

//+------------------------------------------------------------------+
//| ============== NEWS FILTER MODULE ============================== |
//+------------------------------------------------------------------+

bool IsCurrencyRelevant(string currency)
{
   string currencies = "";
   if(InpNewsUseChartCurrency)
   {
      string sym = Symbol();
      if(StringLen(sym) >= 6)
         currencies = StringSubstr(sym, 0, 3) + ";" + StringSubstr(sym, 3, 3);
      else
         currencies = sym;
   }
   else
      currencies = InpNewsCurrencies;

   string parts[];
   ushort sep = StringGetCharacter(";", 0);
   int count = StringSplit(currencies, sep, parts);
   for(int i = 0; i < count; i++)
   {
      string c = parts[i];
      StringTrimLeft(c);
      StringTrimRight(c);
      StringToUpper(c);
      string upperCurrency = currency;
      StringToUpper(upperCurrency);
      if(c == upperCurrency) return true;
   }
   return false;
}

bool IsCustomNewsMatch(string newsTitle)
{
   if(!InpFilterCustomNews || StringLen(InpCustomNewsKeywords) == 0) return false;
   string upperTitle = newsTitle;
   StringToUpper(upperTitle);
   string keywordList[];
   ushort sep = StringGetCharacter(";", 0);
   int count = StringSplit(InpCustomNewsKeywords, sep, keywordList);
   for(int i = 0; i < count; i++)
   {
      string keyword = keywordList[i];
      StringTrimLeft(keyword);
      StringTrimRight(keyword);
      StringToUpper(keyword);
      if(StringLen(keyword) > 0 && StringFind(upperTitle, keyword) >= 0) return true;
   }
   return false;
}

string ExtractJSONValue(string json, string key)
{
   string quote = "\"";
   string searchKey = quote + key + quote + ":";
   int startPos = StringFind(json, searchKey);
   if(startPos < 0) return "";
   startPos += StringLen(searchKey);
   while(startPos < StringLen(json) && StringSubstr(json, startPos, 1) == " ") startPos++;
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
         if(c == "," || c == "}" || c == "]") break;
         endPos++;
      }
      value = StringSubstr(json, startPos, endPos - startPos);
   }
   StringTrimLeft(value);
   StringTrimRight(value);
   return value;
}

bool CheckWebRequestConfiguration()
{
   if(!InpEnableNewsFilter) { g_webRequestConfigured = true; return true; }
   string testUrl = InpLicenseServer + "/functions/v1/economic-news?limit=1";
   char postData[], resultData[];
   string headers = "";
   string resultHeaders;
   ResetLastError();
   int result = WebRequest("GET", testUrl, headers, 5000, postData, resultData, resultHeaders);
   if(result == -1)
   {
      int error = GetLastError();
      if(error == 4060 || error == 4024) { g_webRequestConfigured = false; return false; }
      if(error == 5203 || error == 5200 || error == 5201) { g_webRequestConfigured = true; return true; }
      return g_webRequestConfigured;
   }
   g_webRequestConfigured = true;
   return true;
}

void RefreshNewsData()
{
   if(!InpEnableNewsFilter) return;
   datetime currentTime = TimeCurrent();
   if(!g_forceNewsRefresh && g_lastNewsRefresh > 0 && (currentTime - g_lastNewsRefresh) < 3600) return;
   g_forceNewsRefresh = false;

   string currencies = "";
   if(InpNewsUseChartCurrency)
   {
      string sym = Symbol();
      if(StringLen(sym) >= 6) currencies = StringSubstr(sym, 0, 3) + "," + StringSubstr(sym, 3, 3);
   }
   else
   {
      currencies = InpNewsCurrencies;
      StringReplace(currencies, ";", ",");
   }

   bool hasCustomKeywords = InpFilterCustomNews && StringLen(InpCustomNewsKeywords) > 0;
   string impacts = "";
   if(!hasCustomKeywords)
   {
      if(InpFilterHighNews) impacts += "High,";
      if(InpFilterMedNews) impacts += "Medium,";
      if(InpFilterLowNews) impacts += "Low,";
      if(StringLen(impacts) > 0) impacts = StringSubstr(impacts, 0, StringLen(impacts) - 1);
   }

   string apiUrl = InpLicenseServer + "/functions/v1/economic-news?ts=" + IntegerToString((long)currentTime);
   if(StringLen(currencies) > 0) apiUrl += "&currency=" + currencies;
   if(StringLen(impacts) > 0) apiUrl += "&impact=" + impacts;

   char postData[], resultData[];
   string headers = "User-Agent: MoneyX-EA/1.0\r\nAccept: application/json\r\nConnection: close";
   string resultHeaders;

   int result = WebRequest("GET", apiUrl, headers, 10000, postData, resultData, resultHeaders);
   if(result == -1)
   {
      int firstError = GetLastError();
      Sleep(1000);
      ResetLastError();
      result = WebRequest("GET", apiUrl, headers, 10000, postData, resultData, resultHeaders);
   }

   if(result == -1 || result != 200)
   {
      if(g_newsEventCount > 0) g_usingCachedNews = true;
      g_lastNewsRefresh = currentTime - 3300;
      return;
   }

   string jsonContent = CharArrayToString(resultData, 0, WHOLE_ARRAY, CP_UTF8);
   if(ArraySize(resultData) < 10) return;

   string successValue = ExtractJSONValue(jsonContent, "success");
   if(successValue != "true") return;

   NewsEvent tmpEvents[];
   int tmpEventCount = 0;
   ArrayResize(tmpEvents, 100);

   int dataStart = StringFind(jsonContent, "\"data\":", 0);
   if(dataStart < 0) return;
   int arrayStart = StringFind(jsonContent, "[", dataStart);
   if(arrayStart < 0) return;

   int searchPos = arrayStart + 1;

   while(searchPos < StringLen(jsonContent))
   {
      int braceDepth = 0;
      int objStart = searchPos;
      int objEnd = -1;
      for(int i = searchPos; i < StringLen(jsonContent); i++)
      {
         string c = StringSubstr(jsonContent, i, 1);
         if(c == "{") braceDepth++;
         else if(c == "}") { braceDepth--; if(braceDepth == 0) { objEnd = i; break; } }
         else if(c == "]" && braceDepth == 0) break;
      }
      if(objEnd < 0) break;

      string eventJson = StringSubstr(jsonContent, objStart, objEnd - objStart + 1);
      string title = ExtractJSONValue(eventJson, "title");
      string currency = ExtractJSONValue(eventJson, "currency");
      string timestampStr = ExtractJSONValue(eventJson, "timestamp");
      string impact = ExtractJSONValue(eventJson, "impact");

      datetime eventTime = (datetime)StringToInteger(timestampStr);
      if(impact == "Holiday") { searchPos = objEnd + 1; continue; }

      bool isRelevant = false;
      if(IsCurrencyRelevant(currency))
      {
         if(InpFilterHighNews && impact == "High") isRelevant = true;
         else if(InpFilterMedNews && impact == "Medium") isRelevant = true;
         else if(InpFilterLowNews && impact == "Low") isRelevant = true;
         if(IsCustomNewsMatch(title)) isRelevant = true;
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

   if(tmpEventCount > 0)
   {
      ArrayResize(g_newsEvents, tmpEventCount);
      for(int i = 0; i < tmpEventCount; i++) g_newsEvents[i] = tmpEvents[i];
      g_newsEventCount = tmpEventCount;
      g_lastNewsRefresh = currentTime;
      g_lastGoodNewsTime = currentTime;
      g_usingCachedNews = false;
      SaveNewsCacheToFile();
   }
   else
   {
      g_lastNewsRefresh = currentTime;
   }
}

void SaveNewsCacheToFile()
{
   if(g_newsEventCount == 0) return;
   int handle = FileOpen(g_newsCacheFile, FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(handle == INVALID_HANDLE) return;
   FileWriteString(handle, "# Jutlameasu News Cache - " + TimeToString(TimeCurrent()) + "\n");
   for(int i = 0; i < g_newsEventCount; i++)
   {
      string line = g_newsEvents[i].title + "|" + g_newsEvents[i].country + "|" +
                    IntegerToString((long)g_newsEvents[i].time) + "|" + g_newsEvents[i].impact + "|" +
                    (g_newsEvents[i].isRelevant ? "1" : "0") + "\n";
      FileWriteString(handle, line);
   }
   FileClose(handle);
}

void LoadNewsCacheFromFile()
{
   if(!FileIsExist(g_newsCacheFile)) return;
   int handle = FileOpen(g_newsCacheFile, FILE_READ | FILE_TXT | FILE_ANSI);
   if(handle == INVALID_HANDLE) return;
   ArrayResize(g_newsEvents, 100);
   g_newsEventCount = 0;
   while(!FileIsEnding(handle))
   {
      string line = FileReadString(handle);
      if(StringSubstr(line, 0, 1) == "#") continue;
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
   if(g_newsEventCount > 0) g_usingCachedNews = true;
}

void GetNewsPauseDuration(string impact, bool isCustomMatch, int &beforeMin, int &afterMin)
{
   beforeMin = 0; afterMin = 0;
   int customBefore = 0, customAfter = 0, impactBefore = 0, impactAfter = 0;
   if(isCustomMatch && InpFilterCustomNews) { customBefore = InpPauseBeforeCustom; customAfter = InpPauseAfterCustom; }
   if(impact == "High" && InpFilterHighNews) { impactBefore = InpPauseBeforeHigh; impactAfter = InpPauseAfterHigh; }
   else if(impact == "Medium" && InpFilterMedNews) { impactBefore = InpPauseBeforeMed; impactAfter = InpPauseAfterMed; }
   else if(impact == "Low" && InpFilterLowNews) { impactBefore = InpPauseBeforeLow; impactAfter = InpPauseAfterLow; }
   if(customBefore + customAfter >= impactBefore + impactAfter && customBefore + customAfter > 0)
   { beforeMin = customBefore; afterMin = customAfter; }
   else if(impactBefore + impactAfter > 0)
   { beforeMin = impactBefore; afterMin = impactAfter; }
}

bool IsEventRelevantNow(const NewsEvent &ev)
{
   if(!IsCurrencyRelevant(ev.country)) return false;
   if(InpFilterCustomNews && IsCustomNewsMatch(ev.title)) return true;
   if(InpFilterHighNews && ev.impact == "High") return true;
   if(InpFilterMedNews && ev.impact == "Medium") return true;
   if(InpFilterLowNews && ev.impact == "Low") return true;
   return false;
}

bool IsNewsTimePaused()
{
   if(!InpEnableNewsFilter)
   {
      g_isNewsPaused = false; g_newsStatus = "OFF";
      if(g_lastPausedState) { g_lastPausedState = false; g_lastPauseKey = ""; }
      return false;
   }

   datetime currentTime = TimeCurrent();
   bool foundPause = false;
   string pauseKey = "";
   g_nextNewsTitle = ""; g_nextNewsTime = 0;
   datetime earliestPauseEnd = 0;
   string earliestNewsTitle = "", earliestCountry = "", earliestImpact = "";
   datetime earliestNewsTime = 0;
   datetime closestNewsTime = 0;
   string closestNewsTitle = "";

   for(int i = 0; i < g_newsEventCount; i++)
   {
      if(!IsEventRelevantNow(g_newsEvents[i])) continue;
      datetime newsTime = g_newsEvents[i].time;
      bool isCustom = IsCustomNewsMatch(g_newsEvents[i].title);
      int beforeMin, afterMin;
      GetNewsPauseDuration(g_newsEvents[i].impact, isCustom, beforeMin, afterMin);
      if(beforeMin == 0 && afterMin == 0) continue;
      datetime pauseStart = newsTime - beforeMin * 60;
      datetime pauseEnd = newsTime + afterMin * 60;

      if(currentTime >= pauseStart && currentTime <= pauseEnd)
      {
         if(!foundPause || pauseEnd < earliestPauseEnd)
         {
            foundPause = true; earliestPauseEnd = pauseEnd;
            earliestNewsTitle = g_newsEvents[i].title; earliestNewsTime = newsTime;
            earliestCountry = g_newsEvents[i].country; earliestImpact = g_newsEvents[i].impact;
         }
      }
      if(newsTime > currentTime && (closestNewsTime == 0 || newsTime < closestNewsTime))
      {
         datetime futureStart = newsTime - beforeMin * 60;
         if(currentTime < futureStart) { closestNewsTime = newsTime; closestNewsTitle = g_newsEvents[i].title; }
      }
   }

   if(foundPause)
   {
      g_nextNewsTitle = earliestNewsTitle; g_nextNewsTime = earliestNewsTime;
      g_newsPauseEndTime = earliestPauseEnd;
      if(currentTime < earliestNewsTime)
         g_newsStatus = "PAUSE: " + earliestCountry + " " + earliestImpact + " in " + IntegerToString((int)((earliestNewsTime - currentTime) / 60)) + "m";
      else
         g_newsStatus = "PAUSE: " + earliestCountry + " " + earliestImpact + " +" + IntegerToString((int)((currentTime - earliestNewsTime) / 60)) + "m ago";
      g_isNewsPaused = true;
      if(!g_lastPausedState || g_lastPauseKey != earliestNewsTitle + IntegerToString((long)earliestNewsTime))
      {
         Print("NEWS FILTER: PAUSED - ", g_newsStatus);
         g_lastPausedState = true;
         g_lastPauseKey = earliestNewsTitle + IntegerToString((long)earliestNewsTime);
      }
      return true;
   }
   else
   {
      g_isNewsPaused = false; g_newsPauseEndTime = 0;
      if(g_lastPausedState) { Print("NEWS FILTER: RESUMED"); g_lastPausedState = false; g_lastPauseKey = ""; }
      if(closestNewsTime > 0 && (closestNewsTime - currentTime) <= 7200)
      { g_nextNewsTitle = closestNewsTitle; g_nextNewsTime = closestNewsTime; }
      g_newsStatus = "No Important news";
   }
   return false;
}

//+------------------------------------------------------------------+
//| ============== TIME FILTER MODULE ============================== |
//+------------------------------------------------------------------+

int ParseTimeToMinutes(string timeStr)
{
   if(StringLen(timeStr) < 5) return -1;
   int colonPos = StringFind(timeStr, ":");
   if(colonPos < 0) return -1;
   int hour = (int)StringToInteger(StringSubstr(timeStr, 0, colonPos));
   int min = (int)StringToInteger(StringSubstr(timeStr, colonPos + 1, 2));
   if(hour < 0 || hour > 23 || min < 0 || min > 59) return -1;
   return hour * 60 + min;
}

bool IsTimeInSession(string session, int currentMinutes)
{
   if(StringLen(session) < 11) return false;
   int dashPos = StringFind(session, "-");
   if(dashPos < 0) return false;
   int startMinutes = ParseTimeToMinutes(StringSubstr(session, 0, dashPos));
   int endMinutes = ParseTimeToMinutes(StringSubstr(session, dashPos + 1));
   if(startMinutes < 0 || endMinutes < 0) return false;
   if(startMinutes <= endMinutes)
      return (currentMinutes >= startMinutes && currentMinutes < endMinutes);
   else
      return (currentMinutes >= startMinutes || currentMinutes < endMinutes);
}

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

bool IsWithinTradingHours()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(!IsTradableDay(dt.day_of_week)) return false;
   int currentMinutes = dt.hour * 60 + dt.min;
   bool isFriday = (dt.day_of_week == 5);
   if(isFriday)
   {
      bool hasFriday = (StringLen(InpFridaySession1) >= 5 || StringLen(InpFridaySession2) >= 5 || StringLen(InpFridaySession3) >= 5);
      if(hasFriday)
      {
         if(StringLen(InpFridaySession1) >= 5 && IsTimeInSession(InpFridaySession1, currentMinutes)) return true;
         if(StringLen(InpFridaySession2) >= 5 && IsTimeInSession(InpFridaySession2, currentMinutes)) return true;
         if(StringLen(InpFridaySession3) >= 5 && IsTimeInSession(InpFridaySession3, currentMinutes)) return true;
         return false;
      }
   }
   if(StringLen(InpSession1) >= 5 && IsTimeInSession(InpSession1, currentMinutes)) return true;
   if(StringLen(InpSession2) >= 5 && IsTimeInSession(InpSession2, currentMinutes)) return true;
   if(StringLen(InpSession3) >= 5 && IsTimeInSession(InpSession3, currentMinutes)) return true;
   if(StringLen(InpSession1) < 5 && StringLen(InpSession2) < 5 && StringLen(InpSession3) < 5) return true;
   return false;
}
//+------------------------------------------------------------------+
