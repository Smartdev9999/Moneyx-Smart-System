//+------------------------------------------------------------------+
//|                                Multi_Currency_Statistical_EA.mq5 |
//|                                      Multi Currency Statistical v1.0 |
//+------------------------------------------------------------------+
#property copyright "MoneyX Trading"
#property version   "1.0"
#property strict

#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                    |
//+------------------------------------------------------------------+
input group "=== Trading Settings ==="
input double   InpLotSize = 0.01;              // Lot Size
input int      InpMagicNumber = 123456;        // Magic Number
input int      InpSlippage = 30;               // Slippage (points)

input group "=== Symbol Settings ==="
input string   InpSymbol1 = "EURUSD";          // Symbol 1
input string   InpSymbol2 = "GBPUSD";          // Symbol 2
input string   InpSymbol3 = "USDJPY";          // Symbol 3
input string   InpSymbol4 = "XAUUSD";          // Symbol 4
input string   InpSymbol5 = "USDCHF";          // Symbol 5
input bool     InpEnableSymbol1 = true;        // Enable Symbol 1
input bool     InpEnableSymbol2 = true;        // Enable Symbol 2
input bool     InpEnableSymbol3 = true;        // Enable Symbol 3
input bool     InpEnableSymbol4 = true;        // Enable Symbol 4
input bool     InpEnableSymbol5 = false;       // Enable Symbol 5

input group "=== Statistical Settings ==="
input int      InpStatPeriod = 20;             // Statistical Period
input double   InpZScoreThreshold = 2.0;       // Z-Score Entry Threshold
input double   InpZScoreExit = 0.5;            // Z-Score Exit Threshold
input int      InpCorrelationPeriod = 50;      // Correlation Period
input double   InpMinCorrelation = 0.7;        // Minimum Correlation

input group "=== Risk Management ==="
input double   InpMaxDrawdown = 20.0;          // Max Drawdown (%)
input double   InpRiskPercent = 2.0;           // Risk Per Trade (%)
input double   InpTakeProfit = 500;            // Take Profit (points)
input double   InpStopLoss = 300;              // Stop Loss (points)

input group "=== License Settings ==="
input string   InpLicenseKey = "";             // License Key
input string   InpAccountNumber = "";          // Account Number

input group "=== News Filter ==="
input bool     InpEnableNewsFilter = true;     // Enable News Filter
input int      InpNewsBeforeMinutes = 30;      // Minutes Before News
input int      InpNewsAfterMinutes = 30;       // Minutes After News

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                   |
//+------------------------------------------------------------------+
CTrade g_trade;
bool g_isLicenseValid = false;
bool g_isNewsPaused = false;
datetime g_lastCandleTime = 0;

// Statistical arrays
double g_priceHistory1[];
double g_priceHistory2[];
double g_priceHistory3[];
double g_priceHistory4[];
double g_priceHistory5[];

// Symbol info
string g_symbols[5];
bool g_symbolEnabled[5];

//+------------------------------------------------------------------+
//| Expert initialization function                                      |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("=== Multi Currency Statistical EA v1.0 Initializing ===");
   
   // Initialize trade object
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(InpSlippage);
   
   // Setup symbols
   g_symbols[0] = InpSymbol1;
   g_symbols[1] = InpSymbol2;
   g_symbols[2] = InpSymbol3;
   g_symbols[3] = InpSymbol4;
   g_symbols[4] = InpSymbol5;
   
   g_symbolEnabled[0] = InpEnableSymbol1;
   g_symbolEnabled[1] = InpEnableSymbol2;
   g_symbolEnabled[2] = InpEnableSymbol3;
   g_symbolEnabled[3] = InpEnableSymbol4;
   g_symbolEnabled[4] = InpEnableSymbol5;
   
   // Validate symbols
   for(int i = 0; i < 5; i++)
   {
      if(g_symbolEnabled[i])
      {
         if(!SymbolSelect(g_symbols[i], true))
         {
            PrintFormat("Warning: Symbol %s not available", g_symbols[i]);
            g_symbolEnabled[i] = false;
         }
      }
   }
   
   // Initialize arrays
   ArrayResize(g_priceHistory1, InpStatPeriod);
   ArrayResize(g_priceHistory2, InpStatPeriod);
   ArrayResize(g_priceHistory3, InpStatPeriod);
   ArrayResize(g_priceHistory4, InpStatPeriod);
   ArrayResize(g_priceHistory5, InpStatPeriod);
   
   // License verification
   g_isLicenseValid = VerifyLicense();
   if(!g_isLicenseValid)
   {
      Print("License verification failed!");
      return(INIT_FAILED);
   }
   
   Print("=== Multi Currency Statistical EA Initialized Successfully ===");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("=== Multi Currency Statistical EA Deinitialized ===");
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   if(!g_isLicenseValid) return;
   
   // Check news filter
   if(InpEnableNewsFilter)
   {
      if(IsNewsPaused())
      {
         g_isNewsPaused = true;
         return;
      }
      g_isNewsPaused = false;
   }
   
   // Check for new candle
   datetime currentTime = iTime(_Symbol, PERIOD_H1, 0);
   if(currentTime == g_lastCandleTime) return;
   g_lastCandleTime = currentTime;
   
   // Update price histories
   UpdatePriceHistories();
   
   // Analyze correlations and statistical signals
   AnalyzeStatisticalSignals();
   
   // Manage existing positions
   ManagePositions();
}

//+------------------------------------------------------------------+
//| Verify License                                                      |
//+------------------------------------------------------------------+
bool VerifyLicense()
{
   if(InpLicenseKey == "" || InpAccountNumber == "")
   {
      Print("License Key and Account Number required");
      return false;
   }
   
   // TODO: Implement license verification via WebRequest
   Print("License verification - Placeholder");
   return true;
}

//+------------------------------------------------------------------+
//| Check if news pause is active                                      |
//+------------------------------------------------------------------+
bool IsNewsPaused()
{
   // TODO: Implement news filter via WebRequest
   return false;
}

//+------------------------------------------------------------------+
//| Update price histories for all symbols                             |
//+------------------------------------------------------------------+
void UpdatePriceHistories()
{
   for(int i = 0; i < 5; i++)
   {
      if(!g_symbolEnabled[i]) continue;
      
      double prices[];
      ArrayResize(prices, InpStatPeriod);
      
      for(int j = 0; j < InpStatPeriod; j++)
      {
         prices[j] = iClose(g_symbols[i], PERIOD_H1, j);
      }
      
      switch(i)
      {
         case 0: ArrayCopy(g_priceHistory1, prices); break;
         case 1: ArrayCopy(g_priceHistory2, prices); break;
         case 2: ArrayCopy(g_priceHistory3, prices); break;
         case 3: ArrayCopy(g_priceHistory4, prices); break;
         case 4: ArrayCopy(g_priceHistory5, prices); break;
      }
   }
}

//+------------------------------------------------------------------+
//| Analyze statistical signals across currency pairs                  |
//+------------------------------------------------------------------+
void AnalyzeStatisticalSignals()
{
   for(int i = 0; i < 5; i++)
   {
      if(!g_symbolEnabled[i]) continue;
      
      double zScore = CalculateZScore(i);
      
      // Check for entry signals
      if(MathAbs(zScore) >= InpZScoreThreshold)
      {
         if(zScore > 0)
         {
            // Overbought - potential sell
            if(!HasPosition(g_symbols[i], POSITION_TYPE_SELL))
            {
               OpenSell(g_symbols[i]);
            }
         }
         else
         {
            // Oversold - potential buy
            if(!HasPosition(g_symbols[i], POSITION_TYPE_BUY))
            {
               OpenBuy(g_symbols[i]);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate Z-Score for a symbol                                     |
//+------------------------------------------------------------------+
double CalculateZScore(int symbolIndex)
{
   double prices[];
   
   switch(symbolIndex)
   {
      case 0: ArrayCopy(prices, g_priceHistory1); break;
      case 1: ArrayCopy(prices, g_priceHistory2); break;
      case 2: ArrayCopy(prices, g_priceHistory3); break;
      case 3: ArrayCopy(prices, g_priceHistory4); break;
      case 4: ArrayCopy(prices, g_priceHistory5); break;
      default: return 0;
   }
   
   if(ArraySize(prices) == 0) return 0;
   
   // Calculate mean
   double sum = 0;
   int count = ArraySize(prices);
   for(int i = 0; i < count; i++)
   {
      sum += prices[i];
   }
   double mean = sum / count;
   
   // Calculate standard deviation
   double sumSqDiff = 0;
   for(int i = 0; i < count; i++)
   {
      sumSqDiff += MathPow(prices[i] - mean, 2);
   }
   double stdDev = MathSqrt(sumSqDiff / count);
   
   if(stdDev == 0) return 0;
   
   // Calculate Z-Score for current price
   double currentPrice = prices[0];
   double zScore = (currentPrice - mean) / stdDev;
   
   return zScore;
}

//+------------------------------------------------------------------+
//| Calculate correlation between two price series                     |
//+------------------------------------------------------------------+
double CalculateCorrelation(double &prices1[], double &prices2[])
{
   int n = MathMin(ArraySize(prices1), ArraySize(prices2));
   if(n < 2) return 0;
   
   double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0, sumY2 = 0;
   
   for(int i = 0; i < n; i++)
   {
      sumX += prices1[i];
      sumY += prices2[i];
      sumXY += prices1[i] * prices2[i];
      sumX2 += prices1[i] * prices1[i];
      sumY2 += prices2[i] * prices2[i];
   }
   
   double numerator = n * sumXY - sumX * sumY;
   double denominator = MathSqrt((n * sumX2 - sumX * sumX) * (n * sumY2 - sumY * sumY));
   
   if(denominator == 0) return 0;
   
   return numerator / denominator;
}

//+------------------------------------------------------------------+
//| Check if position exists for symbol                                |
//+------------------------------------------------------------------+
bool HasPosition(string symbol, ENUM_POSITION_TYPE posType)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetString(POSITION_SYMBOL) == symbol &&
            PositionGetInteger(POSITION_MAGIC) == InpMagicNumber &&
            PositionGetInteger(POSITION_TYPE) == posType)
         {
            return true;
         }
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Open Buy Position                                                  |
//+------------------------------------------------------------------+
bool OpenBuy(string symbol)
{
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   double sl = ask - InpStopLoss * point;
   double tp = ask + InpTakeProfit * point;
   
   if(g_trade.Buy(InpLotSize, symbol, ask, sl, tp, "Multi Currency Statistical"))
   {
      PrintFormat("BUY opened on %s at %.5f", symbol, ask);
      return true;
   }
   
   PrintFormat("Failed to open BUY on %s: %d", symbol, GetLastError());
   return false;
}

//+------------------------------------------------------------------+
//| Open Sell Position                                                 |
//+------------------------------------------------------------------+
bool OpenSell(string symbol)
{
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   
   double sl = bid + InpStopLoss * point;
   double tp = bid - InpTakeProfit * point;
   
   if(g_trade.Sell(InpLotSize, symbol, bid, sl, tp, "Multi Currency Statistical"))
   {
      PrintFormat("SELL opened on %s at %.5f", symbol, bid);
      return true;
   }
   
   PrintFormat("Failed to open SELL on %s: %d", symbol, GetLastError());
   return false;
}

//+------------------------------------------------------------------+
//| Manage existing positions                                          |
//+------------------------------------------------------------------+
void ManagePositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
         
         string symbol = PositionGetString(POSITION_SYMBOL);
         
         // Find symbol index
         int symbolIndex = -1;
         for(int j = 0; j < 5; j++)
         {
            if(g_symbols[j] == symbol)
            {
               symbolIndex = j;
               break;
            }
         }
         
         if(symbolIndex == -1) continue;
         
         // Check exit conditions based on Z-Score
         double zScore = CalculateZScore(symbolIndex);
         ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         
         bool shouldClose = false;
         
         if(posType == POSITION_TYPE_BUY && zScore >= -InpZScoreExit)
         {
            shouldClose = true; // Z-Score returned to normal
         }
         else if(posType == POSITION_TYPE_SELL && zScore <= InpZScoreExit)
         {
            shouldClose = true; // Z-Score returned to normal
         }
         
         if(shouldClose)
         {
            g_trade.PositionClose(PositionGetTicket(i));
            PrintFormat("Position closed on %s - Z-Score normalized", symbol);
         }
      }
   }
   
   // Check drawdown limit
   CheckDrawdownLimit();
}

//+------------------------------------------------------------------+
//| Check drawdown limit                                               |
//+------------------------------------------------------------------+
void CheckDrawdownLimit()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   if(balance <= 0) return;
   
   double drawdown = ((balance - equity) / balance) * 100;
   
   if(drawdown >= InpMaxDrawdown)
   {
      PrintFormat("Max drawdown reached: %.2f%% - Closing all positions", drawdown);
      CloseAllPositions();
   }
}

//+------------------------------------------------------------------+
//| Close all positions                                                |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            g_trade.PositionClose(PositionGetTicket(i));
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Timer function                                                     |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Periodic data sync
}

//+------------------------------------------------------------------+
