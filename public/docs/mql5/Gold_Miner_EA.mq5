//+------------------------------------------------------------------+
//|                                              Gold_Miner_EA.mq5   |
//|                                    Copyright 2025, MoneyX Smart  |
//|                                        https://moneyxsmart.com   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MoneyX Smart System"
#property link      "https://moneyxsmart.com"
#property version   "1.00"
#property description "Gold Miner EA - Hybrid Strategy for XAUUSD"
#property description "Scalping + Trend Following + Counter-Trend + Grid/Martingale Recovery"
#property strict

#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| Custom Enumerations                                              |
//+------------------------------------------------------------------+
enum ENUM_LOT_MODE
  {
   FIXED_LOT,              // Fixed Lot Size
   RISK_PERCENTAGE,        // Risk Percentage of Balance
   RECOVERY_MARTINGALE     // Recovery/Martingale Strategy
  };

//+------------------------------------------------------------------+
//| Input Parameters                                                 |
//+------------------------------------------------------------------+
// --- General Settings ---
input string                  _GeneralSettings         = "=== General Settings ===";
input int                     MagicNumber              = 12345;
input int                     MaxSlippagePoints        = 3;
input int                     MaxOpenOrders            = 10;
input double                  MaxAllowedDrawdownPct    = 25.0;

// --- Trading Time Filters (UTC) ---
input string                  _TimeFilterSettings      = "=== Trading Time Filters (UTC) ===";
input bool                    EnableTimeFilter         = false;
input int                     StartHourUTC             = 0;
input int                     EndHourUTC               = 23;
input int                     StartMinuteUTC           = 0;
input int                     EndMinuteUTC             = 59;
input bool                    AllowTradingMonday       = true;
input bool                    AllowTradingTuesday      = true;
input bool                    AllowTradingWednesday    = true;
input bool                    AllowTradingThursday     = true;
input bool                    AllowTradingFriday       = true;
input bool                    AllowTradingSaturday     = false;
input bool                    AllowTradingSunday       = false;

// --- Lot Sizing & Money Management ---
input string                  _LotSizingSettings       = "=== Lot Sizing & Money Management ===";
input ENUM_LOT_MODE           LotSizingMode            = FIXED_LOT;
input double                  FixedLot                 = 0.01;
input double                  RiskPercentage           = 1.0;
input double                  RecoveryMultiplier       = 1.5;
input int                     RecoveryMaxSteps         = 5;
input double                  RecoveryFactorExponent   = 1.0;

// --- Indicator Settings ---
input string                  _IndicatorSettings       = "=== Indicator Settings ===";
input int                     RSIPeriod                = 14;
input ENUM_APPLIED_PRICE      RSIAppliedPrice          = PRICE_CLOSE;
input int                     EMA_FastPeriod           = 20;
input int                     EMA_SlowPeriod           = 50;
input ENUM_APPLIED_PRICE      EMAAppliedPrice          = PRICE_CLOSE;
input int                     ATRPeriod                = 14;
input int                     MACDFastPeriod           = 12;
input int                     MACDSlowPeriod           = 26;
input int                     MACDSignalPeriod         = 9;
input ENUM_APPLIED_PRICE      MACDAppliedPrice         = PRICE_CLOSE;
input int                     BBPeriod                 = 20;
input double                  BBDeviation              = 2.0;
input ENUM_APPLIED_PRICE      BBAppliedPrice           = PRICE_CLOSE;

// --- Entry Logic Thresholds ---
input string                  _EntryLogicSettings      = "=== Entry Logic Thresholds ===";
input double                  RSI_Buy_Min              = 45.0;
input double                  RSI_Buy_Max              = 70.0;
input double                  RSI_Sell_Min             = 30.0;
input double                  RSI_Sell_Max             = 55.0;
input double                  EMA_CrossoverTolerance   = 0.0001;
input double                  MACD_CrossoverTolerance  = 0.00001;
input double                  BB_PriceDistanceFromBand = 0.5;
input int                     MinBarsSinceEntry        = 3;

// --- Exit Logic Thresholds ---
input string                  _ExitLogicSettings       = "=== Exit Logic Thresholds ===";
input double                  ScalpProfitPoints        = 10.0;
input double                  BreakevenPlusPoints      = 2.0;
input double                  TrailingStopStartPoints  = 20.0;
input double                  TrailingStopDistance      = 10.0;
input double                  MaxHoldingTimeHours      = 24.0;
input double                  MaxIndividualLossPoints  = 1000.0;
input double                  HedgingProfitThreshold   = 5.0;

// --- Grid/Recovery Settings ---
input string                  _GridRecoverySettings    = "=== Grid/Recovery Settings ===";
input bool                    EnableRecoveryByGrid     = true;
input int                     GridRecoveryDistancePips = 20;
input int                     GridRecoveryMaxOrders    = 5;
input double                  RecoveryProfitTargetPerc = 0.0;

//+------------------------------------------------------------------+
//| Order Tracking Structure                                         |
//+------------------------------------------------------------------+
struct OrderInfo
  {
   ulong             ticket;
   int               type;           // 0=Buy, 1=Sell
   double            entryPrice;
   double            internalSL;
   double            internalTP;
   datetime          openTime;
   double            lotSize;
   bool              trailingActive;
   int               recoveryStep;
  };

//+------------------------------------------------------------------+
//| Global Variables                                                 |
//+------------------------------------------------------------------+
CTrade            trade;

// Indicator handles
int               hRSI;
int               hEMA_Fast;
int               hEMA_Slow;
int               hATR;
int               hMACD;
int               hBands;

// Indicator buffers
double            bufRSI[];
double            bufEMA_Fast[];
double            bufEMA_Slow[];
double            bufATR[];
double            bufMACD_Main[];
double            bufMACD_Signal[];
double            bufBB_Upper[];
double            bufBB_Middle[];
double            bufBB_Lower[];

// Current indicator values
double            _RSI_Current, _RSI_Prev;
double            _EMA_Fast_Current, _EMA_Fast_Prev;
double            _EMA_Slow_Current, _EMA_Slow_Prev;
double            _ATR_Current;
double            _MACD_Main_Current, _MACD_Main_Prev;
double            _MACD_Signal_Current, _MACD_Signal_Prev;
double            _BB_Upper_Current, _BB_Middle_Current, _BB_Lower_Current;

// Order tracking
OrderInfo         g_orders[];
int               g_totalOrders;
datetime          g_lastBarTime;
datetime          g_lastBuyBarTime;
datetime          g_lastSellBarTime;

// Recovery tracking
int               g_consecutiveBuyLosses;
int               g_consecutiveSellLosses;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(MaxSlippagePoints);
   trade.SetTypeFilling(ORDER_FILLING_IOC);

   // Create indicator handles
   hRSI = iRSI(_Symbol, PERIOD_M15, RSIPeriod, RSIAppliedPrice);
   hEMA_Fast = iMA(_Symbol, PERIOD_M15, EMA_FastPeriod, 0, MODE_EMA, EMAAppliedPrice);
   hEMA_Slow = iMA(_Symbol, PERIOD_M15, EMA_SlowPeriod, 0, MODE_EMA, EMAAppliedPrice);
   hATR = iATR(_Symbol, PERIOD_M15, ATRPeriod);
   hMACD = iMACD(_Symbol, PERIOD_M15, MACDFastPeriod, MACDSlowPeriod, MACDSignalPeriod, MACDAppliedPrice);
   hBands = iBands(_Symbol, PERIOD_M15, BBPeriod, 0, BBDeviation, BBAppliedPrice);

   if(hRSI == INVALID_HANDLE || hEMA_Fast == INVALID_HANDLE || hEMA_Slow == INVALID_HANDLE ||
      hATR == INVALID_HANDLE || hMACD == INVALID_HANDLE || hBands == INVALID_HANDLE)
     {
      Print("Gold Miner EA: Failed to create indicator handles!");
      return(INIT_FAILED);
     }

   // Init arrays as series
   ArraySetAsSeries(bufRSI, true);
   ArraySetAsSeries(bufEMA_Fast, true);
   ArraySetAsSeries(bufEMA_Slow, true);
   ArraySetAsSeries(bufATR, true);
   ArraySetAsSeries(bufMACD_Main, true);
   ArraySetAsSeries(bufMACD_Signal, true);
   ArraySetAsSeries(bufBB_Upper, true);
   ArraySetAsSeries(bufBB_Middle, true);
   ArraySetAsSeries(bufBB_Lower, true);

   g_lastBarTime = 0;
   g_lastBuyBarTime = 0;
   g_lastSellBarTime = 0;
   g_consecutiveBuyLosses = 0;
   g_consecutiveSellLosses = 0;
   g_totalOrders = 0;

   Print("Gold Miner EA v1.00 initialized successfully on ", _Symbol);
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(hRSI != INVALID_HANDLE)      IndicatorRelease(hRSI);
   if(hEMA_Fast != INVALID_HANDLE) IndicatorRelease(hEMA_Fast);
   if(hEMA_Slow != INVALID_HANDLE) IndicatorRelease(hEMA_Slow);
   if(hATR != INVALID_HANDLE)      IndicatorRelease(hATR);
   if(hMACD != INVALID_HANDLE)     IndicatorRelease(hMACD);
   if(hBands != INVALID_HANDLE)    IndicatorRelease(hBands);

   Print("Gold Miner EA deinitialized. Reason: ", reason);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Check for new bar - main logic runs once per bar
   datetime currentBarTime = iTime(_Symbol, PERIOD_M15, 0);
   bool isNewBar = (currentBarTime != g_lastBarTime);

   // Always manage positions on every tick
   ManageOpenPositions();

   // Check drawdown on every tick
   if(CheckDrawdownExit())
      return;

   // Entry logic and grid only on new bar
   if(!isNewBar)
      return;

   g_lastBarTime = currentBarTime;

   // Calculate indicators
   if(!CalculateIndicators())
      return;

   // Check time filter
   if(!CheckTimeFilter())
      return;

   // Count current EA orders
   int buyCount = 0, sellCount = 0;
   CountMyOrders(buyCount, sellCount);
   int totalCount = buyCount + sellCount;

   // Manage hedging
   ManageHedging(buyCount, sellCount);

   // Check entries
   if(totalCount < MaxOpenOrders)
     {
      bool canBuy = CheckBuyEntry(currentBarTime);
      bool canSell = CheckSellEntry(currentBarTime);

      if(canBuy && totalCount < MaxOpenOrders)
        {
         double lots = CalculateLotSize(0); // 0 = Buy
         if(lots > 0)
           {
            double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            if(trade.Buy(lots, _Symbol, ask, 0, 0, "GoldMiner_Buy"))
              {
               g_lastBuyBarTime = currentBarTime;
               Print("Gold Miner: BUY opened, lots=", lots, " price=", ask);
              }
            else
               Print("Gold Miner: BUY failed, error=", GetLastError());
           }
         totalCount++;
        }

      if(canSell && totalCount < MaxOpenOrders)
        {
         double lots = CalculateLotSize(1); // 1 = Sell
         if(lots > 0)
           {
            double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            if(trade.Sell(lots, _Symbol, bid, 0, 0, "GoldMiner_Sell"))
              {
               g_lastSellBarTime = currentBarTime;
               Print("Gold Miner: SELL opened, lots=", lots, " price=", bid);
              }
            else
               Print("Gold Miner: SELL failed, error=", GetLastError());
           }
        }
     }

   // Grid/Recovery management
   if(EnableRecoveryByGrid && LotSizingMode == RECOVERY_MARTINGALE)
      ManageGridRecovery(buyCount, sellCount);

   // Display dashboard
   DisplayDashboard(buyCount, sellCount);
  }

//+------------------------------------------------------------------+
//| Calculate all indicator values                                   |
//+------------------------------------------------------------------+
bool CalculateIndicators()
  {
   if(CopyBuffer(hRSI, 0, 0, 3, bufRSI) < 3)           return false;
   if(CopyBuffer(hEMA_Fast, 0, 0, 3, bufEMA_Fast) < 3)  return false;
   if(CopyBuffer(hEMA_Slow, 0, 0, 3, bufEMA_Slow) < 3)  return false;
   if(CopyBuffer(hATR, 0, 0, 12, bufATR) < 12)           return false;
   if(CopyBuffer(hMACD, 0, 0, 3, bufMACD_Main) < 3)      return false;
   if(CopyBuffer(hMACD, 1, 0, 3, bufMACD_Signal) < 3)    return false;
   if(CopyBuffer(hBands, 0, 0, 3, bufBB_Middle) < 3)     return false;
   if(CopyBuffer(hBands, 1, 0, 3, bufBB_Upper) < 3)      return false;
   if(CopyBuffer(hBands, 2, 0, 3, bufBB_Lower) < 3)      return false;

   // Use bar index 1 (last closed bar) as current, index 2 as previous
   _RSI_Current        = bufRSI[1];
   _RSI_Prev           = bufRSI[2];
   _EMA_Fast_Current   = bufEMA_Fast[1];
   _EMA_Fast_Prev      = bufEMA_Fast[2];
   _EMA_Slow_Current   = bufEMA_Slow[1];
   _EMA_Slow_Prev      = bufEMA_Slow[2];
   _ATR_Current        = bufATR[1];
   _MACD_Main_Current  = bufMACD_Main[1];
   _MACD_Main_Prev     = bufMACD_Main[2];
   _MACD_Signal_Current= bufMACD_Signal[1];
   _MACD_Signal_Prev   = bufMACD_Signal[2];
   _BB_Upper_Current   = bufBB_Upper[1];
   _BB_Middle_Current  = bufBB_Middle[1];
   _BB_Lower_Current   = bufBB_Lower[1];

   return true;
  }

//+------------------------------------------------------------------+
//| Check trading time filter                                        |
//+------------------------------------------------------------------+
bool CheckTimeFilter()
  {
   if(!EnableTimeFilter)
      return true;

   MqlDateTime dt;
   TimeToStruct(TimeGMT(), dt);

   // Check day of week
   bool dayAllowed = false;
   if(dt.day_of_week == 1 && AllowTradingMonday)       dayAllowed = true;
   if(dt.day_of_week == 2 && AllowTradingTuesday)      dayAllowed = true;
   if(dt.day_of_week == 3 && AllowTradingWednesday)    dayAllowed = true;
   if(dt.day_of_week == 4 && AllowTradingThursday)     dayAllowed = true;
   if(dt.day_of_week == 5 && AllowTradingFriday)       dayAllowed = true;
   if(dt.day_of_week == 6 && AllowTradingSaturday)     dayAllowed = true;
   if(dt.day_of_week == 0 && AllowTradingSunday)       dayAllowed = true;

   if(!dayAllowed)
      return false;

   // Check time window
   int currentMinutes = dt.hour * 60 + dt.min;
   int startMinutes   = StartHourUTC * 60 + StartMinuteUTC;
   int endMinutes     = EndHourUTC * 60 + EndMinuteUTC;

   if(startMinutes <= endMinutes)
      return (currentMinutes >= startMinutes && currentMinutes <= endMinutes);
   else
      return (currentMinutes >= startMinutes || currentMinutes <= endMinutes);
  }

//+------------------------------------------------------------------+
//| Check drawdown and emergency close all                           |
//+------------------------------------------------------------------+
bool CheckDrawdownExit()
  {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);

   if(balance <= 0)
      return false;

   double floatingPL = equity - balance;
   if(floatingPL >= 0)
      return false;

   double drawdownPct = MathAbs(floatingPL) / balance * 100.0;

   if(drawdownPct >= MaxAllowedDrawdownPct)
     {
      Print("Gold Miner: MAX DRAWDOWN reached (", DoubleToString(drawdownPct, 2),
            "%). Closing ALL positions!");
      CloseAllPositions();
      return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//| Close all EA positions                                           |
//+------------------------------------------------------------------+
void CloseAllPositions()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      trade.PositionClose(ticket);
     }
  }

//+------------------------------------------------------------------+
//| Count EA orders by type                                          |
//+------------------------------------------------------------------+
void CountMyOrders(int &buyCount, int &sellCount)
  {
   buyCount = 0;
   sellCount = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      long posType = PositionGetInteger(POSITION_TYPE);
      if(posType == POSITION_TYPE_BUY)
         buyCount++;
      else if(posType == POSITION_TYPE_SELL)
         sellCount++;
     }
  }

//+------------------------------------------------------------------+
//| Check BUY entry conditions                                       |
//+------------------------------------------------------------------+
bool CheckBuyEntry(datetime currentBarTime)
  {
   // Min bars since last buy entry
   if(g_lastBuyBarTime > 0)
     {
      int barsSince = Bars(_Symbol, PERIOD_M15, g_lastBuyBarTime, currentBarTime) - 1;
      if(barsSince < MinBarsSinceEntry)
         return false;
     }

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Primary conditions - ALL must be true
   bool rsiOk = (_RSI_Current >= RSI_Buy_Min && _RSI_Current <= RSI_Buy_Max);
   bool emaCross = (_EMA_Fast_Prev < _EMA_Slow_Prev + EMA_CrossoverTolerance &&
                    _EMA_Fast_Current > _EMA_Slow_Current - EMA_CrossoverTolerance);
   bool priceAboveEMA = (bid > _EMA_Slow_Current);
   bool macdOk = (_MACD_Main_Current > _MACD_Signal_Current);

   if(!rsiOk || !emaCross || !priceAboveEMA || !macdOk)
      return false;

   // Secondary conditions - at least ONE must be true
   bool macdZeroCross = (_MACD_Main_Prev < 0 && _MACD_Main_Current > 0);

   bool bbReversal = (bid <= _BB_Lower_Current + BB_PriceDistanceFromBand && _RSI_Current < 40.0);

   // ATR confirmation - current ATR above average of last 10 bars
   double atrAvg = 0;
   for(int k = 1; k <= 10; k++)
      atrAvg += bufATR[k];
   atrAvg /= 10.0;
   bool atrConfirm = (_ATR_Current > atrAvg);

   if(!macdZeroCross && !bbReversal && !atrConfirm)
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Check SELL entry conditions                                      |
//+------------------------------------------------------------------+
bool CheckSellEntry(datetime currentBarTime)
  {
   // Min bars since last sell entry
   if(g_lastSellBarTime > 0)
     {
      int barsSince = Bars(_Symbol, PERIOD_M15, g_lastSellBarTime, currentBarTime) - 1;
      if(barsSince < MinBarsSinceEntry)
         return false;
     }

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // Primary conditions - ALL must be true
   bool rsiOk = (_RSI_Current >= RSI_Sell_Min && _RSI_Current <= RSI_Sell_Max);
   bool emaCross = (_EMA_Fast_Prev > _EMA_Slow_Prev - EMA_CrossoverTolerance &&
                    _EMA_Fast_Current < _EMA_Slow_Current + EMA_CrossoverTolerance);
   bool priceBelowEMA = (ask < _EMA_Slow_Current);
   bool macdOk = (_MACD_Main_Current < _MACD_Signal_Current);

   if(!rsiOk || !emaCross || !priceBelowEMA || !macdOk)
      return false;

   // Secondary conditions - at least ONE must be true
   bool macdZeroCross = (_MACD_Main_Prev > 0 && _MACD_Main_Current < 0);

   bool bbReversal = (ask >= _BB_Upper_Current - BB_PriceDistanceFromBand && _RSI_Current > 60.0);

   double atrAvg = 0;
   for(int k = 1; k <= 10; k++)
      atrAvg += bufATR[k];
   atrAvg /= 10.0;
   bool atrConfirm = (_ATR_Current > atrAvg);

   if(!macdZeroCross && !bbReversal && !atrConfirm)
      return false;

   return true;
  }

//+------------------------------------------------------------------+
//| Calculate lot size based on mode                                 |
//+------------------------------------------------------------------+
double CalculateLotSize(int direction)
  {
   double lots = FixedLot;
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(LotSizingMode == FIXED_LOT)
     {
      lots = FixedLot;
     }
   else if(LotSizingMode == RISK_PERCENTAGE)
     {
      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double dollarsToRisk = equity * (RiskPercentage / 100.0);
      double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

      if(tickValue > 0 && tickSize > 0 && MaxIndividualLossPoints > 0)
        {
         double pointValue = tickValue / tickSize * _Point;
         lots = dollarsToRisk / (MaxIndividualLossPoints * pointValue);
        }
     }
   else if(LotSizingMode == RECOVERY_MARTINGALE)
     {
      int consecutiveLosses = (direction == 0) ? g_consecutiveBuyLosses : g_consecutiveSellLosses;

      if(consecutiveLosses > RecoveryMaxSteps)
         consecutiveLosses = 0; // Reset after max steps

      lots = FixedLot * MathPow(RecoveryMultiplier, (double)consecutiveLosses);
     }

   // Normalize and clamp
   lots = MathMax(minLot, lots);
   lots = MathMin(maxLot, lots);

   // Round to lot step
   if(lotStep > 0)
      lots = MathFloor(lots / lotStep) * lotStep;

   lots = NormalizeDouble(lots, 2);

   return lots;
  }

//+------------------------------------------------------------------+
//| Manage all open positions (SL, TP, Trailing, Time exit)          |
//+------------------------------------------------------------------+
void ManageOpenPositions()
  {
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point = _Point;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      long posType = PositionGetInteger(POSITION_TYPE);
      double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double posProfit = PositionGetDouble(POSITION_PROFIT);
      double volume = PositionGetDouble(POSITION_VOLUME);
      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      double currentSL = PositionGetDouble(POSITION_SL);

      double profitPoints = 0;
      bool shouldClose = false;
      string closeReason = "";

      if(posType == POSITION_TYPE_BUY)
        {
         profitPoints = (bid - entryPrice) / point;

         // Max individual loss check
         if(profitPoints <= -MaxIndividualLossPoints)
           {
            shouldClose = true;
            closeReason = "MaxLoss";
           }

         // Scalp profit target
         if(!shouldClose && profitPoints >= ScalpProfitPoints)
           {
            // If trailing is not active yet, check if we should just scalp
            if(profitPoints < TrailingStopStartPoints)
              {
               shouldClose = true;
               closeReason = "ScalpTP";
              }
           }

         // Breakeven logic
         if(!shouldClose && profitPoints >= BreakevenPlusPoints)
           {
            double beLevel = entryPrice + BreakevenPlusPoints * point;
            if(currentSL < entryPrice)
              {
               trade.PositionModify(ticket, beLevel, 0);
              }
           }

         // Trailing stop logic
         if(!shouldClose && profitPoints >= TrailingStopStartPoints)
           {
            double trailSL = bid - TrailingStopDistance * point;
            if(trailSL > currentSL)
              {
               trade.PositionModify(ticket, trailSL, 0);
              }
           }
        }
      else if(posType == POSITION_TYPE_SELL)
        {
         profitPoints = (entryPrice - ask) / point;

         // Max individual loss check
         if(profitPoints <= -MaxIndividualLossPoints)
           {
            shouldClose = true;
            closeReason = "MaxLoss";
           }

         // Scalp profit target
         if(!shouldClose && profitPoints >= ScalpProfitPoints)
           {
            if(profitPoints < TrailingStopStartPoints)
              {
               shouldClose = true;
               closeReason = "ScalpTP";
              }
           }

         // Breakeven logic
         if(!shouldClose && profitPoints >= BreakevenPlusPoints)
           {
            double beLevel = entryPrice - BreakevenPlusPoints * point;
            if(currentSL > entryPrice || currentSL == 0)
              {
               trade.PositionModify(ticket, beLevel, 0);
              }
           }

         // Trailing stop logic
         if(!shouldClose && profitPoints >= TrailingStopStartPoints)
           {
            double trailSL = ask + TrailingStopDistance * point;
            if(trailSL < currentSL || currentSL == 0)
              {
               trade.PositionModify(ticket, trailSL, 0);
              }
           }
        }

      // Time-based exit
      if(!shouldClose && MaxHoldingTimeHours > 0)
        {
         double hoursHeld = (double)(TimeCurrent() - openTime) / 3600.0;
         if(hoursHeld >= MaxHoldingTimeHours)
           {
            shouldClose = true;
            closeReason = "TimeExit";
           }
        }

      // Execute close if needed
      if(shouldClose)
        {
         Print("Gold Miner: Closing ", (posType == POSITION_TYPE_BUY ? "BUY" : "SELL"),
               " #", ticket, " Reason: ", closeReason,
               " Profit: ", DoubleToString(posProfit, 2));

         if(trade.PositionClose(ticket))
           {
            // Track for recovery
            if(posProfit < 0)
              {
               if(posType == POSITION_TYPE_BUY)
                  g_consecutiveBuyLosses++;
               else
                  g_consecutiveSellLosses++;
              }
            else
              {
               if(posType == POSITION_TYPE_BUY)
                  g_consecutiveBuyLosses = 0;
               else
                  g_consecutiveSellLosses = 0;
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Manage hedging - close opposing losers when one side profits     |
//+------------------------------------------------------------------+
void ManageHedging(int buyCount, int sellCount)
  {
   if(buyCount == 0 || sellCount == 0)
      return;

   double totalBuyProfit = 0;
   double totalSellProfit = 0;

   // Calculate total profit by direction
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      long posType = PositionGetInteger(POSITION_TYPE);
      double profit = PositionGetDouble(POSITION_PROFIT);

      if(posType == POSITION_TYPE_BUY)
         totalBuyProfit += profit;
      else
         totalSellProfit += profit;
     }

   double point = _Point;
   double profitThresholdValue = HedgingProfitThreshold * point *
                                  SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) /
                                  SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   // If buys are profitable and sells are losing, close oldest losing sell
   if(totalBuyProfit > profitThresholdValue && totalSellProfit < 0)
     {
      CloseOldestLosingPosition(POSITION_TYPE_SELL);
     }
   // If sells are profitable and buys are losing, close oldest losing buy
   else if(totalSellProfit > profitThresholdValue && totalBuyProfit < 0)
     {
      CloseOldestLosingPosition(POSITION_TYPE_BUY);
     }
  }

//+------------------------------------------------------------------+
//| Close the oldest losing position of a specific type              |
//+------------------------------------------------------------------+
void CloseOldestLosingPosition(ENUM_POSITION_TYPE targetType)
  {
   ulong oldestTicket = 0;
   datetime oldestTime = TimeCurrent();

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      long posType = PositionGetInteger(POSITION_TYPE);
      double profit = PositionGetDouble(POSITION_PROFIT);
      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);

      if(posType == targetType && profit < 0 && openTime < oldestTime)
        {
         oldestTime = openTime;
         oldestTicket = ticket;
        }
     }

   if(oldestTicket > 0)
     {
      Print("Gold Miner: Hedging - Closing oldest losing ",
            (targetType == POSITION_TYPE_BUY ? "BUY" : "SELL"), " #", oldestTicket);
      trade.PositionClose(oldestTicket);
     }
  }

//+------------------------------------------------------------------+
//| Grid/Martingale Recovery Management                              |
//+------------------------------------------------------------------+
void ManageGridRecovery(int buyCount, int sellCount)
  {
   if(!EnableRecoveryByGrid)
      return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double point = _Point;
   double gridDistance = GridRecoveryDistancePips * point * 10; // Convert pips to price

   // Check if we should add recovery grid orders for buys
   if(buyCount > 0 && buyCount < GridRecoveryMaxOrders)
     {
      double lowestBuyPrice = 999999;
      double totalBuyProfit = 0;

      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0)
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != MagicNumber)
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
            continue;

         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         totalBuyProfit += PositionGetDouble(POSITION_PROFIT);

         if(openPrice < lowestBuyPrice)
            lowestBuyPrice = openPrice;
        }

      // Check recovery profit target
      if(RecoveryProfitTargetPerc > 0 && totalBuyProfit > 0)
        {
         double targetProfit = AccountInfoDouble(ACCOUNT_EQUITY) * RecoveryProfitTargetPerc / 100.0;
         if(totalBuyProfit >= targetProfit)
           {
            Print("Gold Miner: Recovery target hit for BUY grid. Closing all buys.");
            CloseAllByType(POSITION_TYPE_BUY);
            g_consecutiveBuyLosses = 0;
            return;
           }
        }

      // Add grid order if price dropped enough
      if(totalBuyProfit < 0 && bid <= lowestBuyPrice - gridDistance)
        {
         double lots = CalculateLotSize(0);
         if(lots > 0)
           {
            if(trade.Buy(lots, _Symbol, ask, 0, 0, "GoldMiner_Grid_Buy"))
               Print("Gold Miner: Grid BUY added at ", ask, " lots=", lots);
           }
        }
     }

   // Check if we should add recovery grid orders for sells
   if(sellCount > 0 && sellCount < GridRecoveryMaxOrders)
     {
      double highestSellPrice = 0;
      double totalSellProfit = 0;

      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0)
            continue;
         if(PositionGetInteger(POSITION_MAGIC) != MagicNumber)
            continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol)
            continue;
         if(PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL)
            continue;

         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         totalSellProfit += PositionGetDouble(POSITION_PROFIT);

         if(openPrice > highestSellPrice)
            highestSellPrice = openPrice;
        }

      // Check recovery profit target
      if(RecoveryProfitTargetPerc > 0 && totalSellProfit > 0)
        {
         double targetProfit = AccountInfoDouble(ACCOUNT_EQUITY) * RecoveryProfitTargetPerc / 100.0;
         if(totalSellProfit >= targetProfit)
           {
            Print("Gold Miner: Recovery target hit for SELL grid. Closing all sells.");
            CloseAllByType(POSITION_TYPE_SELL);
            g_consecutiveSellLosses = 0;
            return;
           }
        }

      // Add grid order if price rose enough
      if(totalSellProfit < 0 && ask >= highestSellPrice + gridDistance)
        {
         double lots = CalculateLotSize(1);
         if(lots > 0)
           {
            if(trade.Sell(lots, _Symbol, bid, 0, 0, "GoldMiner_Grid_Sell"))
               Print("Gold Miner: Grid SELL added at ", bid, " lots=", lots);
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Close all positions of a specific type                           |
//+------------------------------------------------------------------+
void CloseAllByType(ENUM_POSITION_TYPE targetType)
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0)
         continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber)
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;
      if(PositionGetInteger(POSITION_TYPE) != targetType)
         continue;

      trade.PositionClose(ticket);
     }
  }

//+------------------------------------------------------------------+
//| Display dashboard on chart                                       |
//+------------------------------------------------------------------+
void DisplayDashboard(int buyCount, int sellCount)
  {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double floatingPL = equity - balance;
   double drawdownPct = (balance > 0) ? MathAbs(MathMin(0, floatingPL)) / balance * 100.0 : 0;

   string info = "";
   info += "╔══════════════════════════════╗\n";
   info += "║    GOLD MINER EA v1.00       ║\n";
   info += "╠══════════════════════════════╣\n";
   info += "║ Balance:  " + DoubleToString(balance, 2) + "\n";
   info += "║ Equity:   " + DoubleToString(equity, 2) + "\n";
   info += "║ Float PL: " + DoubleToString(floatingPL, 2) + "\n";
   info += "║ Drawdown: " + DoubleToString(drawdownPct, 2) + "%\n";
   info += "╠══════════════════════════════╣\n";
   info += "║ BUY:  " + IntegerToString(buyCount) + "  SELL: " + IntegerToString(sellCount) + "\n";
   info += "║ Max DD:   " + DoubleToString(MaxAllowedDrawdownPct, 1) + "%\n";
   info += "║ Lot Mode: " + EnumToString(LotSizingMode) + "\n";
   info += "╠══════════════════════════════╣\n";
   info += "║ RSI:  " + DoubleToString(_RSI_Current, 2) + "\n";
   info += "║ ATR:  " + DoubleToString(_ATR_Current, 5) + "\n";
   info += "║ MACD: " + DoubleToString(_MACD_Main_Current, 5) + "\n";
   info += "║ EMA Fast: " + DoubleToString(_EMA_Fast_Current, 5) + "\n";
   info += "║ EMA Slow: " + DoubleToString(_EMA_Slow_Current, 5) + "\n";
   info += "║ BB Upper: " + DoubleToString(_BB_Upper_Current, 5) + "\n";
   info += "║ BB Lower: " + DoubleToString(_BB_Lower_Current, 5) + "\n";
   info += "╠══════════════════════════════╣\n";
   info += "║ Buy Losses:  " + IntegerToString(g_consecutiveBuyLosses) + "\n";
   info += "║ Sell Losses: " + IntegerToString(g_consecutiveSellLosses) + "\n";
   info += "╚══════════════════════════════╝\n";

   Comment(info);
  }
//+------------------------------------------------------------------+
