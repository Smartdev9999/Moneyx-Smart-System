//+------------------------------------------------------------------+
//|                                              Gold_Miner_EA.mq5   |
//|                                    Copyright 2025, MoneyX Smart  |
//|                              Gold Miner EA v2.5 - SMA+Grid+ATR   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MoneyX Smart System"
#property link      "https://moneyxsmartsystem.lovable.app"
#property version   "2.50"
#property description "Gold Miner EA v2.5 - Fix Unknown Closure Bug (SL guard + Trailing BE + Accumulate)"
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

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+

//--- General Settings
input group "=== General Settings ==="
input int              MagicNumber        = 202500;    // Magic Number
input int              MaxSlippage        = 30;        // Max Slippage (points)
input int              MaxOpenOrders      = 20;        // Max Open Orders
input double           MaxDrawdownPct     = 30.0;      // Max Drawdown % (emergency close)
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

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
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

   Print("Gold Miner EA v2.4 initialized successfully");
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

   Print("Gold Miner EA v2.4 deinitialized");
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

      //--- Grid Loss management (check both sides independently)
      if((hasInitialBuy || g_initialBuyPrice > 0) && gridLossBuy < GridLoss_MaxTrades && buyCount > 0)
      {
         CheckGridLoss(POSITION_TYPE_BUY, gridLossBuy);
      }
      if((hasInitialSell || g_initialSellPrice > 0) && gridLossSell < GridLoss_MaxTrades && sellCount > 0)
      {
         CheckGridLoss(POSITION_TYPE_SELL, gridLossSell);
      }

      //--- Grid Profit management
      if(GridProfit_Enable)
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

      //--- Entry logic: Independent Side Entry (BUY and SELL checked separately)
      bool canOpenMore = TotalOrderCount() < MaxOpenOrders;
      bool canOpenOnThisCandle = !(DontOpenSameCandle && currentBarTime == lastInitialCandleTime);

      //--- BUY side shouldEnter logic
      bool shouldEnterBuy = false;
      if(justClosedBuy && EnableAutoReEntry) shouldEnterBuy = true;
      else if(!justClosedBuy && buyCount == 0) shouldEnterBuy = true;

      //--- SELL side shouldEnter logic
      bool shouldEnterSell = false;
      if(justClosedSell && EnableAutoReEntry) shouldEnterSell = true;
      else if(!justClosedSell && sellCount == 0) shouldEnterSell = true;

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
      }

      // Reset justClosed flags at end of new bar processing
      justClosedBuy = false;
      justClosedSell = false;
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
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      trade.PositionClose(ticket);
   }
   justClosedBuy = true;
   justClosedSell = true;
   ResetTrailingState();
   g_initialBuyPrice = 0;
   g_initialSellPrice = 0;
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

      //--- SL checks
      if(EnableSL)
      {
         if(UseSL_Dollar && plSell <= -SL_DollarAmount) closeSL2 = true;
         if(UseSL_Points && ask >= avgSell + SL_Points * point) closeSL2 = true;
         if(UseSL_PercentBalance && plSell <= -(balance * SL_PercentBalance / 100.0)) closeSL2 = true;

         if(closeSL2)
         {
            Print("SL HIT (SELL): PL=", plSell);
            if(SL_ActionMode == SL_CLOSE_ALL_STOP)
            {
               CloseAllPositions();
               g_eaStopped = true;
               Print("EA STOPPED by SL Action");
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

         // Never below breakeven level (for SELL, BE floor is below open price, SL moves downward)
            double beFloor = NormalizeDouble(openPrice - InpBreakevenOffset * point, digits);
            if(newSL < beFloor) newSL = beFloor;  // SELL: SL must not go below BE floor

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
      Print("EMERGENCY: Drawdown ", dd, "% >= ", MaxDrawdownPct, "% - Closing all!");
      CloseAllPositions();
      g_eaStopped = true;
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
   CreateDashText("GM_TBL_HDR_T", DashboardX + 8, DashboardY + 3, "Gold Miner EA v2.4", COLOR_HEADER_TEXT, 11, "Arial Bold");
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

   //--- Bottom border
   int bottomY = DashboardY + 24 + row * 20;
   CreateDashRect("GM_TBL_BTM", DashboardX, bottomY, tableWidth, 2, COLOR_HEADER_BG);
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
