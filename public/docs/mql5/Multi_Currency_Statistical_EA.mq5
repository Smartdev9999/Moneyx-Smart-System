//+------------------------------------------------------------------+
//|                                Multi_Currency_Statistical_EA.mq5 |
//|                        Statistical Arbitrage (Pairs Trading) v2.0 |
//|                                             MoneyX Trading        |
//+------------------------------------------------------------------+
#property copyright "MoneyX Trading"
#property version   "2.0"
#property strict
#property description "Statistical Arbitrage / Pairs Trading Expert Advisor"
#property description "Market-Neutral Mean Reversion Strategy"

#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| CONSTANTS                                                          |
//+------------------------------------------------------------------+
#define MAX_PAIRS 20
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
//| PAIR INFO STRUCTURE                                                |
//+------------------------------------------------------------------+
struct PairInfo
{
   string         symbolA;           // Symbol A (Base)
   string         symbolB;           // Symbol B (Hedge)
   bool           enabled;           // Pair On/Off
   double         correlation;       // Current Correlation
   double         hedgeRatio;        // Beta (Hedge Ratio)
   double         spreadMean;        // Spread Mean
   double         spreadStdDev;      // Spread Std Deviation
   double         currentSpread;     // Current Spread Value
   double         zScore;            // Current Z-Score
   double         lotA;              // Lot for Symbol A
   double         lotB;              // Lot for Symbol B (Adjusted)
   ulong          ticketA;           // Position Ticket A
   ulong          ticketB;           // Position Ticket B
   int            direction;         // 1=Long Spread, -1=Short Spread, 0=None
   double         entrySpread;       // Entry Spread Value
   datetime       entryTime;         // Entry Time
   double         pairProfit;        // Current Pair Profit
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

input group "=== Statistical Settings ==="
input int      InpLookbackPeriod = 100;         // Lookback Period (bars)
input double   InpEntryZScore = 2.0;            // Entry Z-Score Threshold
input double   InpExitZScore = 0.5;             // Exit Z-Score Threshold
input double   InpMinCorrelation = 0.70;        // Minimum Correlation
input int      InpCorrelationPeriod = 50;       // Correlation Calculation Period
input bool     InpUseLogReturns = true;         // Use Log Returns (Recommended)

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

// Pairs Data
PairInfo g_pairs[MAX_PAIRS];
PairData g_pairData[MAX_PAIRS];
int g_activePairs = 0;

// Account Statistics
double g_initialBalance = 0;
double g_maxEquity = 0;
double g_dailyProfit = 0;
double g_weeklyProfit = 0;
double g_monthlyProfit = 0;
datetime g_dayStart = 0;
datetime g_weekStart = 0;
datetime g_monthStart = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("=== Statistical Arbitrage EA v2.0 Initializing ===");
   
   // Initialize trade object
   g_trade.SetExpertMagicNumber(InpMagicNumber);
   g_trade.SetDeviationInPoints(InpSlippage);
   
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
   
   // Create dashboard panel
   if(!MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE))
   {
      CreateDashboard();
   }
   
   PrintFormat("=== Statistical Arbitrage EA Initialized - %d Active Pairs ===", g_activePairs);
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Initialize Trading Pairs                                           |
//+------------------------------------------------------------------+
bool InitializePairs()
{
   g_activePairs = 0;
   
   // Setup all 20 pairs
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
   
   return (g_activePairs > 0);
}

//+------------------------------------------------------------------+
//| Setup Individual Pair                                              |
//+------------------------------------------------------------------+
void SetupPair(int index, bool enabled, string symbolA, string symbolB)
{
   g_pairs[index].enabled = false;
   g_pairs[index].symbolA = symbolA;
   g_pairs[index].symbolB = symbolB;
   g_pairs[index].correlation = 0;
   g_pairs[index].hedgeRatio = 1.0;
   g_pairs[index].spreadMean = 0;
   g_pairs[index].spreadStdDev = 0;
   g_pairs[index].currentSpread = 0;
   g_pairs[index].zScore = 0;
   g_pairs[index].lotA = InpBaseLot;
   g_pairs[index].lotB = InpBaseLot;
   g_pairs[index].ticketA = 0;
   g_pairs[index].ticketB = 0;
   g_pairs[index].direction = 0;
   g_pairs[index].entrySpread = 0;
   g_pairs[index].entryTime = 0;
   g_pairs[index].pairProfit = 0;
   
   if(!enabled) return;
   
   // Validate symbols
   if(!SymbolSelect(symbolA, true))
   {
      PrintFormat("Warning: Symbol %s not available", symbolA);
      return;
   }
   
   if(!SymbolSelect(symbolB, true))
   {
      PrintFormat("Warning: Symbol %s not available", symbolB);
      return;
   }
   
   g_pairs[index].enabled = true;
   g_activePairs++;
   PrintFormat("Pair %d initialized: %s - %s", index + 1, symbolA, symbolB);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   ObjectsDeleteAll(0, "STAT_");
   ChartRedraw();
   Print("=== Statistical Arbitrage EA Deinitialized ===");
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
   
   // Check for new candle
   datetime currentTime = iTime(_Symbol, InpTimeframe, 0);
   if(currentTime == g_lastCandleTime) return;
   g_lastCandleTime = currentTime;
   
   // Main trading logic
   UpdateAllPairData();
   AnalyzeAllPairs();
   ManageAllPositions();
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
   
   // Convert string to char array
   int postLen = StringToCharArray(postData, post, 0, -1, CP_UTF8);
   ArrayResize(post, postLen - 1);  // Remove null terminator
   
   ResetLastError();
   int timeout = 10000;
   int res = WebRequest("POST", url, headers, timeout, post, result, resultHeaders);
   
   if(res == -1)
   {
      int error = GetLastError();
      if(error == 4014)
      {
         Print("ERROR: Add URL to MT5 allowed list: ", InpApiUrl);
         Print("Go to: Tools -> Options -> Expert Advisors -> Allow WebRequest for listed URL");
         MessageBox("Please add this URL to MT5 allowed list:\n\n" + InpApiUrl + "\n\nGo to: Tools -> Options -> Expert Advisors", "WebRequest Error", MB_ICONERROR);
      }
      else
      {
         PrintFormat("WebRequest failed. Error: %d", error);
      }
      return false;
   }
   
   string response = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
   PrintFormat("[License] Response: %s", response);
   
   // Parse response
   if(StringFind(response, "\"valid\":true") >= 0)
   {
      // Extract customer name
      int nameStart = StringFind(response, "\"customer_name\":\"");
      if(nameStart >= 0)
      {
         nameStart += 17;
         int nameEnd = StringFind(response, "\"", nameStart);
         string customerName = StringSubstr(response, nameStart, nameEnd - nameStart);
         PrintFormat("[License] Welcome, %s! License valid.", customerName);
      }
      
      // Check if lifetime
      if(StringFind(response, "\"is_lifetime\":true") >= 0)
      {
         Print("[License] Lifetime license active");
      }
      else
      {
         // Extract days remaining
         int daysStart = StringFind(response, "\"days_remaining\":");
         if(daysStart >= 0)
         {
            daysStart += 17;
            int daysEnd = StringFind(response, ",", daysStart);
            if(daysEnd < 0) daysEnd = StringFind(response, "}", daysStart);
            string daysStr = StringSubstr(response, daysStart, daysEnd - daysStart);
            int daysRemaining = (int)StringToInteger(daysStr);
            PrintFormat("[License] Days remaining: %d", daysRemaining);
            
            if(daysRemaining <= 5)
            {
               MessageBox("Your license expires in " + IntegerToString(daysRemaining) + " days.\nPlease contact Moneyx Support to renew.", "License Expiring Soon", MB_ICONWARNING);
            }
         }
      }
      return true;
   }
   
   // License invalid - extract message
   int msgStart = StringFind(response, "\"message\":\"");
   if(msgStart >= 0)
   {
      msgStart += 11;
      int msgEnd = StringFind(response, "\"", msgStart);
      string message = StringSubstr(response, msgStart, msgEnd - msgStart);
      Print("[License] ", message);
      MessageBox(message, "License Error", MB_ICONERROR);
   }
   else
   {
      Print("[License] Verification failed");
   }
   
   return false;
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
//| ================ STATISTICAL ENGINE ================               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Update All Pair Data (Prices, Returns, Statistics)                 |
//+------------------------------------------------------------------+
void UpdateAllPairData()
{
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(!g_pairs[i].enabled) continue;
      
      // Update prices
      UpdatePriceHistory(i);
      
      // Calculate log returns
      CalculateLogReturns(i);
      
      // Calculate correlation
      g_pairs[i].correlation = CalculatePearsonCorrelation(i);
      
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
//| Update Price History for a Pair                                    |
//+------------------------------------------------------------------+
void UpdatePriceHistory(int pairIndex)
{
   string symbolA = g_pairs[pairIndex].symbolA;
   string symbolB = g_pairs[pairIndex].symbolB;
   
   int period = MathMin(InpLookbackPeriod, MAX_LOOKBACK);
   for(int i = 0; i < period; i++)
   {
      g_pairData[pairIndex].pricesA[i] = iClose(symbolA, InpTimeframe, i);
      g_pairData[pairIndex].pricesB[i] = iClose(symbolB, InpTimeframe, i);
   }
}

//+------------------------------------------------------------------+
//| Calculate Log Returns                                              |
//| Formula: Return(t) = ln(Price(t) / Price(t-1))                    |
//+------------------------------------------------------------------+
void CalculateLogReturns(int pairIndex)
{
   int returnCount = MathMin(InpLookbackPeriod - 1, MAX_LOOKBACK - 1);
   
   for(int i = 0; i < returnCount; i++)
   {
      double priceA_t = g_pairData[pairIndex].pricesA[i];
      double priceA_t1 = g_pairData[pairIndex].pricesA[i + 1];
      double priceB_t = g_pairData[pairIndex].pricesB[i];
      double priceB_t1 = g_pairData[pairIndex].pricesB[i + 1];
      
      if(priceA_t1 > 0 && priceB_t1 > 0)
      {
         if(InpUseLogReturns)
         {
            // Log returns (recommended for statistical stability)
            g_pairData[pairIndex].returnsA[i] = MathLog(priceA_t / priceA_t1);
            g_pairData[pairIndex].returnsB[i] = MathLog(priceB_t / priceB_t1);
         }
         else
         {
            // Simple returns
            g_pairData[pairIndex].returnsA[i] = (priceA_t - priceA_t1) / priceA_t1;
            g_pairData[pairIndex].returnsB[i] = (priceB_t - priceB_t1) / priceB_t1;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate Pearson Correlation                                      |
//| Formula: ρ = Cov(ReturnA, ReturnB) / (σA × σB)                    |
//+------------------------------------------------------------------+
double CalculatePearsonCorrelation(int pairIndex)
{
   int n = MathMin(InpCorrelationPeriod, MAX_LOOKBACK - 1);
   if(n < 2) return 0;
   
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
   
   // Covariance
   double covariance = (sumAB / n) - (meanA * meanB);
   
   // Standard Deviations
   double varA = (sumA2 / n) - (meanA * meanA);
   double varB = (sumB2 / n) - (meanB * meanB);
   
   if(varA <= 0 || varB <= 0) return 0;
   
   double stdDevA = MathSqrt(varA);
   double stdDevB = MathSqrt(varB);
   
   if(stdDevA == 0 || stdDevB == 0) return 0;
   
   // Pearson Correlation
   double correlation = covariance / (stdDevA * stdDevB);
   
   return correlation;
}

//+------------------------------------------------------------------+
//| Calculate Hedge Ratio (Beta) - OLS Regression                      |
//| Formula: β = Cov(ReturnA, ReturnB) / Var(ReturnB)                 |
//| Alternative: β = ρ × (σA / σB)                                     |
//+------------------------------------------------------------------+
double CalculateHedgeRatio(int pairIndex)
{
   int n = MathMin(InpCorrelationPeriod, MAX_LOOKBACK - 1);
   if(n < 2) return 1.0;
   
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
   
   // Covariance(A, B)
   double covariance = (sumAB / n) - (meanA * meanB);
   
   // Variance(B)
   double varianceB = (sumB2 / n) - (meanB * meanB);
   
   if(varianceB == 0) return 1.0;
   
   // Hedge Ratio (Beta) = Cov(A,B) / Var(B)
   double hedgeRatio = covariance / varianceB;
   
   // Ensure positive hedge ratio for pairs trading
   return MathAbs(hedgeRatio);
}

//+------------------------------------------------------------------+
//| Update Spread History                                              |
//| Formula: Spread(t) = ln(PriceA) − β × ln(PriceB)                  |
//+------------------------------------------------------------------+
void UpdateSpreadHistory(int pairIndex)
{
   double beta = g_pairs[pairIndex].hedgeRatio;
   int period = MathMin(InpLookbackPeriod, MAX_LOOKBACK);
   
   // Calculate spread for each bar
   for(int i = 0; i < period; i++)
   {
      double priceA = g_pairData[pairIndex].pricesA[i];
      double priceB = g_pairData[pairIndex].pricesB[i];
      
      if(priceA > 0 && priceB > 0)
      {
         // Log-price spread (recommended)
         g_pairData[pairIndex].spreadHistory[i] = MathLog(priceA) - beta * MathLog(priceB);
      }
   }
   
   // Current spread
   g_pairs[pairIndex].currentSpread = g_pairData[pairIndex].spreadHistory[0];
   
   // Calculate spread mean and std dev
   CalculateSpreadMeanStdDev(pairIndex);
}

//+------------------------------------------------------------------+
//| Calculate Spread Mean and Standard Deviation                       |
//+------------------------------------------------------------------+
void CalculateSpreadMeanStdDev(int pairIndex)
{
   int n = MathMin(InpLookbackPeriod, MAX_LOOKBACK);
   double sum = 0;
   
   // Calculate mean
   for(int i = 0; i < n; i++)
   {
      sum += g_pairData[pairIndex].spreadHistory[i];
   }
   double mean = sum / n;
   g_pairs[pairIndex].spreadMean = mean;
   
   // Calculate standard deviation
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
//| Formula: Z = (Spread − Mean) / StdDev                             |
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
//| Formula: PipValue = (Point / Price) × ContractSize                |
//+------------------------------------------------------------------+
double GetPipValue(string symbol)
{
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double price = SymbolInfoDouble(symbol, SYMBOL_BID);
   double contractSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   double tickValue = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(symbol, SYMBOL_TRADE_TICK_SIZE);
   
   if(tickSize == 0) return 0;
   
   // Pip value per 1 lot
   double pipValue = (tickValue / tickSize) * point;
   
   return pipValue;
}

//+------------------------------------------------------------------+
//| Calculate Dollar-Neutral Lot Sizes                                 |
//| Formula: LotB = LotA × β × (PipValueA / PipValueB)                |
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
      g_pairs[pairIndex].lotA = baseLot;
      g_pairs[pairIndex].lotB = baseLot;
      return;
   }
   
   // LotA = Base Lot
   g_pairs[pairIndex].lotA = baseLot;
   
   // LotB = LotA × β × (PipValueA / PipValueB)
   double lotB = baseLot * hedgeRatio * (pipValueA / pipValueB);
   
   // Normalize lot size
   double minLotB = SymbolInfoDouble(symbolB, SYMBOL_VOLUME_MIN);
   double maxLotB = SymbolInfoDouble(symbolB, SYMBOL_VOLUME_MAX);
   double stepLotB = SymbolInfoDouble(symbolB, SYMBOL_VOLUME_STEP);
   
   lotB = MathMax(minLotB, MathMin(maxLotB, lotB));
   lotB = MathFloor(lotB / stepLotB) * stepLotB;
   
   // Apply max lot constraint
   lotB = MathMin(lotB, InpMaxLot);
   
   g_pairs[pairIndex].lotB = lotB;
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
      
      // Skip if already has position
      if(g_pairs[i].direction != 0) continue;
      
      // Check correlation threshold
      if(MathAbs(g_pairs[i].correlation) < InpMinCorrelation)
      {
         // Correlation too low - skip trading
         continue;
      }
      
      double zScore = g_pairs[i].zScore;
      
      // Entry Conditions
      if(zScore > InpEntryZScore)
      {
         // Short Spread: Z > +EntryThreshold
         // Sell SymbolA, Buy SymbolB
         OpenPairTrade(i, -1);
      }
      else if(zScore < -InpEntryZScore)
      {
         // Long Spread: Z < -EntryThreshold
         // Buy SymbolA, Sell SymbolB
         OpenPairTrade(i, 1);
      }
   }
}

//+------------------------------------------------------------------+
//| ================ EXECUTION ENGINE ================                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Open Pair Trade (Atomic Execution)                                 |
//| direction: 1 = Long Spread, -1 = Short Spread                     |
//+------------------------------------------------------------------+
bool OpenPairTrade(int pairIndex, int direction)
{
   if(g_pairs[pairIndex].direction != 0) return false;
   
   string symbolA = g_pairs[pairIndex].symbolA;
   string symbolB = g_pairs[pairIndex].symbolB;
   double lotA = g_pairs[pairIndex].lotA;
   double lotB = g_pairs[pairIndex].lotB;
   
   string comment = StringFormat("StatArb_%d", pairIndex + 1);
   
   ulong ticketA = 0;
   ulong ticketB = 0;
   
   if(direction == 1)  // Long Spread: Buy A, Sell B
   {
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
      
      // Open Sell on Symbol B
      double bidB = SymbolInfoDouble(symbolB, SYMBOL_BID);
      if(g_trade.Sell(lotB, symbolB, bidB, 0, 0, comment))
      {
         ticketB = g_trade.ResultOrder();
      }
      else
      {
         // Rollback - close first leg
         PrintFormat("Failed to open SELL on %s: %d - Rolling back", symbolB, GetLastError());
         g_trade.PositionClose(ticketA);
         return false;
      }
   }
   else if(direction == -1)  // Short Spread: Sell A, Buy B
   {
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
      
      // Open Buy on Symbol B
      double askB = SymbolInfoDouble(symbolB, SYMBOL_ASK);
      if(g_trade.Buy(lotB, symbolB, askB, 0, 0, comment))
      {
         ticketB = g_trade.ResultOrder();
      }
      else
      {
         // Rollback - close first leg
         PrintFormat("Failed to open BUY on %s: %d - Rolling back", symbolB, GetLastError());
         g_trade.PositionClose(ticketA);
         return false;
      }
   }
   
   // Record trade info
   g_pairs[pairIndex].ticketA = ticketA;
   g_pairs[pairIndex].ticketB = ticketB;
   g_pairs[pairIndex].direction = direction;
   g_pairs[pairIndex].entrySpread = g_pairs[pairIndex].currentSpread;
   g_pairs[pairIndex].entryTime = TimeCurrent();
   
   PrintFormat("Pair %d OPENED: %s %s | %s %s | Z=%.2f | β=%.4f",
      pairIndex + 1,
      direction == 1 ? "BUY" : "SELL", symbolA,
      direction == 1 ? "SELL" : "BUY", symbolB,
      g_pairs[pairIndex].zScore,
      g_pairs[pairIndex].hedgeRatio);
   
   return true;
}

//+------------------------------------------------------------------+
//| Close Pair Trade (Synchronized Closing)                            |
//+------------------------------------------------------------------+
bool ClosePairTrade(int pairIndex)
{
   if(g_pairs[pairIndex].direction == 0) return false;
   
   bool closedA = false;
   bool closedB = false;
   
   // Close position A
   if(g_pairs[pairIndex].ticketA > 0)
   {
      if(PositionSelectByTicket(g_pairs[pairIndex].ticketA))
      {
         closedA = g_trade.PositionClose(g_pairs[pairIndex].ticketA);
      }
      else
      {
         closedA = true; // Already closed
      }
   }
   
   // Close position B
   if(g_pairs[pairIndex].ticketB > 0)
   {
      if(PositionSelectByTicket(g_pairs[pairIndex].ticketB))
      {
         closedB = g_trade.PositionClose(g_pairs[pairIndex].ticketB);
      }
      else
      {
         closedB = true; // Already closed
      }
   }
   
   if(closedA && closedB)
   {
      PrintFormat("Pair %d CLOSED: %s-%s | Exit Z=%.2f",
         pairIndex + 1,
         g_pairs[pairIndex].symbolA,
         g_pairs[pairIndex].symbolB,
         g_pairs[pairIndex].zScore);
      
      // Reset pair state
      g_pairs[pairIndex].ticketA = 0;
      g_pairs[pairIndex].ticketB = 0;
      g_pairs[pairIndex].direction = 0;
      g_pairs[pairIndex].entrySpread = 0;
      g_pairs[pairIndex].entryTime = 0;
      g_pairs[pairIndex].pairProfit = 0;
      
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| ================ POSITION MANAGEMENT ================              |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Manage All Open Positions                                          |
//+------------------------------------------------------------------+
void ManageAllPositions()
{
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(!g_pairs[i].enabled) continue;
      if(g_pairs[i].direction == 0) continue;
      
      // Exit Condition 1: Z-Score returned to normal
      double zScore = g_pairs[i].zScore;
      if(MathAbs(zScore) <= InpExitZScore)
      {
         ClosePairTrade(i);
         continue;
      }
      
      // Exit Condition 2: Correlation dropped below threshold
      if(MathAbs(g_pairs[i].correlation) < InpMinCorrelation * 0.8)
      {
         PrintFormat("Pair %d: Correlation dropped (%.2f) - Closing", i + 1, g_pairs[i].correlation);
         ClosePairTrade(i);
         continue;
      }
      
      // Exit Condition 3: Max holding time
      if(InpMaxHoldingBars > 0)
      {
         int barsHeld = iBarShift(_Symbol, InpTimeframe, g_pairs[i].entryTime);
         if(barsHeld >= InpMaxHoldingBars)
         {
            PrintFormat("Pair %d: Max holding time reached - Closing", i + 1);
            ClosePairTrade(i);
            continue;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Update Pair Profits                                                |
//+------------------------------------------------------------------+
void UpdatePairProfits()
{
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(!g_pairs[i].enabled) continue;
      if(g_pairs[i].direction == 0)
      {
         g_pairs[i].pairProfit = 0;
         continue;
      }
      
      double profitA = 0;
      double profitB = 0;
      
      // Get profit from position A
      if(g_pairs[i].ticketA > 0 && PositionSelectByTicket(g_pairs[i].ticketA))
      {
         profitA = PositionGetDouble(POSITION_PROFIT) + 
                   PositionGetDouble(POSITION_SWAP);
      }
      
      // Get profit from position B
      if(g_pairs[i].ticketB > 0 && PositionSelectByTicket(g_pairs[i].ticketB))
      {
         profitB = PositionGetDouble(POSITION_PROFIT) + 
                   PositionGetDouble(POSITION_SWAP);
      }
      
      g_pairs[i].pairProfit = profitA + profitB;
   }
}

//+------------------------------------------------------------------+
//| Update Account Statistics                                          |
//+------------------------------------------------------------------+
void UpdateAccountStats()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity > g_maxEquity) g_maxEquity = equity;
   
   // Reset daily/weekly/monthly profits at period boundaries
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   // Check for new day
   MqlDateTime dtStart;
   TimeToStruct(g_dayStart, dtStart);
   if(dt.day != dtStart.day)
   {
      g_dailyProfit = 0;
      g_dayStart = TimeCurrent();
   }
   
   // Check for new week
   TimeToStruct(g_weekStart, dtStart);
   if(dt.day_of_week < dtStart.day_of_week || dt.day - dtStart.day >= 7)
   {
      g_weeklyProfit = 0;
      g_weekStart = TimeCurrent();
   }
   
   // Check for new month
   TimeToStruct(g_monthStart, dtStart);
   if(dt.mon != dtStart.mon)
   {
      g_monthlyProfit = 0;
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
   
   // Emergency close at high drawdown
   if(drawdown >= InpEmergencyCloseDD)
   {
      PrintFormat("EMERGENCY: Drawdown %.2f%% exceeded limit - Closing ALL", drawdown);
      CloseAllPairTrades();
      g_isPaused = true;
      return;
   }
   
   // Normal max drawdown check
   if(drawdown >= InpMaxDrawdown)
   {
      PrintFormat("Max drawdown reached: %.2f%% - Pausing new trades", drawdown);
      // Don't close positions, just stop new trades
   }
}

//+------------------------------------------------------------------+
//| Close All Pair Trades                                              |
//+------------------------------------------------------------------+
void CloseAllPairTrades()
{
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(g_pairs[i].direction != 0)
      {
         ClosePairTrade(i);
      }
   }
}

//+------------------------------------------------------------------+
//| Close All Positions by Magic Number                                |
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

//+------------------------------------------------------------------+
//| ================ DASHBOARD PANEL ================                  |
//+------------------------------------------------------------------+
//| DASHBOARD PANEL CONSTANTS                                          |
//+------------------------------------------------------------------+
#define PANEL_X          10
#define PANEL_Y          30
#define PANEL_WIDTH      775
#define PANEL_HEIGHT     550
#define HEADER_HEIGHT    25
#define ROW_HEIGHT       18
#define SUMMARY_ROW_H    20

// Dashboard Colors
color COLOR_BG          = C'20,22,28';
color COLOR_HEADER      = C'30,32,40';
color COLOR_BORDER      = C'45,48,60';
color COLOR_TEXT        = clrWhite;
color COLOR_LABEL       = C'170,175,185';
color COLOR_PROFIT      = clrLime;
color COLOR_LOSS        = clrRed;
color COLOR_ON          = clrLime;
color COLOR_OFF         = clrGray;
color COLOR_GOLD        = C'255,215,0';
color COLOR_ACTIVE      = C'0,180,255';

// Global tracking for lot statistics
double g_dailyLot = 0;
double g_weeklyLot = 0;
double g_monthlyLot = 0;
double g_allTimeLot = 0;
double g_allTimeProfit = 0;
double g_maxDrawdownPercent = 0;

//+------------------------------------------------------------------+
//| Create Dashboard Panel (New Design)                                |
//+------------------------------------------------------------------+
void CreateDashboard()
{
   string prefix = "STAT_";
   
   // Delete old objects
   ObjectsDeleteAll(0, prefix);
   
   // Main Background
   CreateRectangle(prefix + "BG", PANEL_X, PANEL_Y, PANEL_WIDTH, PANEL_HEIGHT, COLOR_BG, COLOR_BORDER);
   
   // ===== HEADER BAR =====
   int headerY = PANEL_Y + 5;
   CreateLabel(prefix + "LOGO", PANEL_X + 10, headerY, "MoneyX Statistical Arbitrage", COLOR_GOLD, 11, "Arial Bold");
   CreateLabel(prefix + "VER", PANEL_X + PANEL_WIDTH - 50, headerY, "v2.0", COLOR_TEXT, 9, "Arial");
   
   // ===== PAIRS TABLE SECTION =====
   int tableY = PANEL_Y + HEADER_HEIGHT + 5;
   
   // ----- LEFT COLUMN: Main Order Buy (Header) -----
   int leftX = PANEL_X + 5;
   CreateLabel(prefix + "H_BUY", leftX + 120, tableY, "Main Order Buy", COLOR_GOLD, 9, "Arial Bold");
   
   int colHeaderY = tableY + 18;
   CreateLabel(prefix + "HL_PAIR", leftX, colHeaderY, "Trading Pair", COLOR_GOLD, 8, "Arial Bold");
   CreateLabel(prefix + "HL_C", leftX + 110, colHeaderY, "C-%", COLOR_LABEL, 7, "Arial");
   CreateLabel(prefix + "HL_MAX", leftX + 145, colHeaderY, "Max", COLOR_LABEL, 7, "Arial");
   CreateLabel(prefix + "HL_ORD", leftX + 175, colHeaderY, "Order", COLOR_LABEL, 7, "Arial");
   CreateLabel(prefix + "HL_LOT", leftX + 210, colHeaderY, "Lot", COLOR_LABEL, 7, "Arial");
   CreateLabel(prefix + "HL_PROF", leftX + 245, colHeaderY, "Profit", COLOR_LABEL, 7, "Arial");
   CreateLabel(prefix + "HL_CLOSE", leftX + 290, colHeaderY, "Close", COLOR_LABEL, 7, "Arial");
   CreateLabel(prefix + "HL_TGT", leftX + 330, colHeaderY, "Target", COLOR_LABEL, 7, "Arial");
   CreateLabel(prefix + "HL_TPL", leftX + 370, colHeaderY, "Total P/L", COLOR_LABEL, 7, "Arial");
   
   // Separator line under left header
   CreateLine(prefix + "SEP_L1", leftX, colHeaderY + 14, leftX + 375, colHeaderY + 14, COLOR_BORDER);
   
   // ----- RIGHT COLUMN: Main Order Sell (Header) -----
   int rightX = PANEL_X + 400;
   CreateLabel(prefix + "H_SELL", rightX + 100, tableY, "Main Order Sell", COLOR_GOLD, 9, "Arial Bold");
   
   CreateLabel(prefix + "HR_PAIR", rightX, colHeaderY, "Trading Pair", COLOR_GOLD, 8, "Arial Bold");
   CreateLabel(prefix + "HR_C", rightX + 110, colHeaderY, "C-%", COLOR_LABEL, 7, "Arial");
   CreateLabel(prefix + "HR_MAX", rightX + 145, colHeaderY, "Max", COLOR_LABEL, 7, "Arial");
   CreateLabel(prefix + "HR_ORD", rightX + 175, colHeaderY, "Order", COLOR_LABEL, 7, "Arial");
   CreateLabel(prefix + "HR_LOT", rightX + 210, colHeaderY, "Lot", COLOR_LABEL, 7, "Arial");
   CreateLabel(prefix + "HR_PROF", rightX + 245, colHeaderY, "Profit", COLOR_LABEL, 7, "Arial");
   CreateLabel(prefix + "HR_CLOSE", rightX + 290, colHeaderY, "Close", COLOR_LABEL, 7, "Arial");
   CreateLabel(prefix + "HR_TGT", rightX + 330, colHeaderY, "Target", COLOR_LABEL, 7, "Arial");
   
   // Separator line under right header
   CreateLine(prefix + "SEP_R1", rightX, colHeaderY + 14, rightX + 365, colHeaderY + 14, COLOR_BORDER);
   
   // ===== PAIR ROWS (20 Pairs: 10 Left, 10 Right) =====
   int rowStartY = colHeaderY + 18;
   
   // Left Column (Pairs 0-9)
   for(int i = 0; i < 10; i++)
   {
      CreatePairRowLeft(prefix, i, leftX, rowStartY + i * ROW_HEIGHT);
   }
   
   // Right Column (Pairs 10-19)
   for(int i = 10; i < 20; i++)
   {
      CreatePairRowRight(prefix, i, rightX, rowStartY + (i - 10) * ROW_HEIGHT);
   }
   
   // ===== ACCOUNT SUMMARY SECTION =====
   int summaryY = rowStartY + 10 * ROW_HEIGHT + 10;
   
   // Separator line above summary
   CreateLine(prefix + "SEP_SUM", PANEL_X + 5, summaryY - 5, PANEL_X + PANEL_WIDTH - 5, summaryY - 5, COLOR_BORDER);
   
   // --- Summary Row 1 ---
   int r1Y = summaryY;
   CreateLabel(prefix + "L_BAL", PANEL_X + 10, r1Y, "Balance:", COLOR_LABEL, 8, "Arial");
   CreateLabel(prefix + "V_BAL", PANEL_X + 70, r1Y, "0.00", COLOR_PROFIT, 9, "Arial Bold");
   
   CreateLabel(prefix + "L_TLOT", PANEL_X + 170, r1Y, "Total Current Lot:", COLOR_LABEL, 8, "Arial");
   CreateLabel(prefix + "V_TLOT", PANEL_X + 275, r1Y, "0.00", COLOR_TEXT, 9, "Arial");
   
   CreateLabel(prefix + "L_DLOT", PANEL_X + 340, r1Y, "Daily Lot:", COLOR_LABEL, 8, "Arial");
   CreateLabel(prefix + "V_DLOT", PANEL_X + 400, r1Y, "0.00", COLOR_TEXT, 9, "Arial");
   
   CreateLabel(prefix + "L_DP", PANEL_X + 500, r1Y, "Daily P/L:", COLOR_LABEL, 8, "Arial");
   CreateLabel(prefix + "V_DP", PANEL_X + 560, r1Y, "0.00", COLOR_PROFIT, 9, "Arial Bold");
   
   CreateLabel(prefix + "L_DP_TGT", PANEL_X + 640, r1Y, "50Lot ($50)", COLOR_LABEL, 7, "Arial");
   
   // --- Summary Row 2 ---
   int r2Y = summaryY + SUMMARY_ROW_H;
   CreateLabel(prefix + "L_EQ", PANEL_X + 10, r2Y, "Equity:", COLOR_LABEL, 8, "Arial");
   CreateLabel(prefix + "V_EQ", PANEL_X + 70, r2Y, "0.00", COLOR_PROFIT, 9, "Arial Bold");
   
   CreateLabel(prefix + "L_TORD", PANEL_X + 170, r2Y, "Total Current Order:", COLOR_LABEL, 8, "Arial");
   CreateLabel(prefix + "V_TORD", PANEL_X + 290, r2Y, "0", COLOR_TEXT, 9, "Arial");
   
   CreateLabel(prefix + "L_WLOT", PANEL_X + 340, r2Y, "Weekly Lot:", COLOR_LABEL, 8, "Arial");
   CreateLabel(prefix + "V_WLOT", PANEL_X + 410, r2Y, "0.00", COLOR_TEXT, 9, "Arial");
   
   CreateLabel(prefix + "L_WP", PANEL_X + 500, r2Y, "Weekly P/L:", COLOR_LABEL, 8, "Arial");
   CreateLabel(prefix + "V_WP", PANEL_X + 570, r2Y, "0.00", COLOR_PROFIT, 9, "Arial Bold");
   
   CreateLabel(prefix + "L_WP_TGT", PANEL_X + 640, r2Y, "100Lot ($1000)", COLOR_LABEL, 7, "Arial");
   
   // --- Summary Row 3 ---
   int r3Y = summaryY + 2 * SUMMARY_ROW_H;
   CreateLabel(prefix + "L_MG", PANEL_X + 10, r3Y, "Margin:", COLOR_LABEL, 8, "Arial");
   CreateLabel(prefix + "V_MG", PANEL_X + 70, r3Y, "0.00", COLOR_TEXT, 9, "Arial");
   
   CreateLabel(prefix + "L_DD", PANEL_X + 170, r3Y, "Current DD%:", COLOR_LABEL, 8, "Arial");
   CreateLabel(prefix + "V_DD", PANEL_X + 260, r3Y, "0.00%", COLOR_LOSS, 9, "Arial Bold");
   
   CreateLabel(prefix + "L_MLOT", PANEL_X + 340, r3Y, "Monthly Lot:", COLOR_LABEL, 8, "Arial");
   CreateLabel(prefix + "V_MLOT", PANEL_X + 420, r3Y, "0.00", COLOR_TEXT, 9, "Arial");
   
   CreateLabel(prefix + "L_MP", PANEL_X + 500, r3Y, "Monthly P/L:", COLOR_LABEL, 8, "Arial");
   CreateLabel(prefix + "V_MP", PANEL_X + 580, r3Y, "0.00", COLOR_PROFIT, 9, "Arial Bold");
   
   CreateLabel(prefix + "L_MP_TGT", PANEL_X + 640, r3Y, "500Lot ($5000)", COLOR_LABEL, 7, "Arial");
   
   // --- Summary Row 4 ---
   int r4Y = summaryY + 3 * SUMMARY_ROW_H;
   CreateLabel(prefix + "L_TPL", PANEL_X + 10, r4Y, "Total Current P/L:", COLOR_LABEL, 8, "Arial");
   CreateLabel(prefix + "V_TPL", PANEL_X + 120, r4Y, "0.00", COLOR_PROFIT, 10, "Arial Bold");
   
   CreateLabel(prefix + "L_MDD", PANEL_X + 200, r4Y, "Max DD%:", COLOR_LABEL, 8, "Arial");
   CreateLabel(prefix + "V_MDD", PANEL_X + 260, r4Y, "0.00%", COLOR_LOSS, 9, "Arial Bold");
   
   CreateLabel(prefix + "L_ALOT", PANEL_X + 340, r4Y, "All Time Lot:", COLOR_LABEL, 8, "Arial");
   CreateLabel(prefix + "V_ALOT", PANEL_X + 420, r4Y, "0.00", COLOR_TEXT, 9, "Arial");
   
   CreateLabel(prefix + "L_AP", PANEL_X + 500, r4Y, "All Time Profit:", COLOR_LABEL, 8, "Arial");
   CreateLabel(prefix + "V_AP", PANEL_X + 595, r4Y, "0.00", COLOR_PROFIT, 9, "Arial Bold");
   
   CreateLabel(prefix + "L_AP_TGT", PANEL_X + 640, r4Y, "5000Lot ($5000)", COLOR_LABEL, 7, "Arial");
   
   // --- Summary Row 5: Active Pairs & License ---
   int r5Y = summaryY + 4 * SUMMARY_ROW_H + 5;
   CreateLabel(prefix + "L_PAIRS", PANEL_X + 340, r5Y, "Active Pairs:", COLOR_LABEL, 8, "Arial");
   CreateLabel(prefix + "V_PAIRS", PANEL_X + 420, r5Y, IntegerToString(g_activePairs), COLOR_GOLD, 9, "Arial Bold");
   
   CreateLabel(prefix + "L_LIC", PANEL_X + 500, r5Y, "License:", COLOR_LABEL, 8, "Arial");
   CreateLabel(prefix + "V_LIC", PANEL_X + 560, r5Y, g_isLicenseValid ? "VALID" : "INVALID", g_isLicenseValid ? COLOR_ON : COLOR_LOSS, 9, "Arial Bold");
   
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Create Pair Row - Left Column (Buy Side)                           |
//+------------------------------------------------------------------+
void CreatePairRowLeft(string prefix, int idx, int x, int y)
{
   string pairName = g_pairs[idx].symbolA + "-" + g_pairs[idx].symbolB;
   string idxStr = IntegerToString(idx);
   
   CreateLabel(prefix + "P" + idxStr + "_NAME", x, y, pairName, COLOR_TEXT, 8, "Arial");
   CreateLabel(prefix + "P" + idxStr + "_C", x + 110, y, "0%", COLOR_TEXT, 8, "Arial");
   CreateLabel(prefix + "P" + idxStr + "_MAX", x + 145, y, IntegerToString(InpLookbackPeriod), COLOR_LABEL, 8, "Arial");
   CreateLabel(prefix + "P" + idxStr + "_ORD", x + 180, y, "0", COLOR_TEXT, 8, "Arial");
   CreateLabel(prefix + "P" + idxStr + "_LOT", x + 213, y, "0.00", COLOR_TEXT, 8, "Arial");
   CreateLabel(prefix + "P" + idxStr + "_PROF", x + 248, y, "0", COLOR_TEXT, 8, "Arial");
   CreateLabel(prefix + "P" + idxStr + "_CLOSE", x + 295, y, "0", COLOR_LABEL, 8, "Arial");
   CreateLabel(prefix + "P" + idxStr + "_TGT", x + 338, y, IntegerToString((int)(InpExitZScore * 10)), COLOR_LABEL, 8, "Arial");
   CreateLabel(prefix + "P" + idxStr + "_TPL", x + 375, y, "0", COLOR_TEXT, 8, "Arial");
   CreateLabel(prefix + "P" + idxStr + "_ST", x + 420, y, g_pairs[idx].enabled ? "On" : "Off", g_pairs[idx].enabled ? COLOR_ON : COLOR_OFF, 8, "Arial Bold");
}

//+------------------------------------------------------------------+
//| Create Pair Row - Right Column (Sell Side)                         |
//+------------------------------------------------------------------+
void CreatePairRowRight(string prefix, int idx, int x, int y)
{
   string pairName = g_pairs[idx].symbolA + "-" + g_pairs[idx].symbolB;
   string idxStr = IntegerToString(idx);
   
   CreateLabel(prefix + "P" + idxStr + "_NAME", x, y, pairName, COLOR_TEXT, 8, "Arial");
   CreateLabel(prefix + "P" + idxStr + "_C", x + 110, y, "0%", COLOR_TEXT, 8, "Arial");
   CreateLabel(prefix + "P" + idxStr + "_MAX", x + 145, y, IntegerToString(InpLookbackPeriod), COLOR_LABEL, 8, "Arial");
   CreateLabel(prefix + "P" + idxStr + "_ORD", x + 180, y, "0", COLOR_TEXT, 8, "Arial");
   CreateLabel(prefix + "P" + idxStr + "_LOT", x + 213, y, "0.00", COLOR_TEXT, 8, "Arial");
   CreateLabel(prefix + "P" + idxStr + "_PROF", x + 248, y, "0", COLOR_TEXT, 8, "Arial");
   CreateLabel(prefix + "P" + idxStr + "_CLOSE", x + 295, y, "0", COLOR_LABEL, 8, "Arial");
   CreateLabel(prefix + "P" + idxStr + "_TGT", x + 338, y, IntegerToString((int)(InpExitZScore * 10)), COLOR_LABEL, 8, "Arial");
   CreateLabel(prefix + "P" + idxStr + "_ST", x + 370, y, g_pairs[idx].enabled ? "On" : "Off", g_pairs[idx].enabled ? COLOR_ON : COLOR_OFF, 8, "Arial Bold");
}

//+------------------------------------------------------------------+
//| Update Dashboard Values                                            |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
   if(MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_VISUAL_MODE)) return;
   
   string prefix = "STAT_";
   
   // Update Account Info
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double margin = AccountInfoDouble(ACCOUNT_MARGIN);
   
   // Calculate total P/L and lots from open pairs
   double totalPL = 0;
   double totalLot = 0;
   int totalOrders = 0;
   
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(g_pairs[i].direction != 0)
      {
         totalPL += g_pairs[i].pairProfit;
         totalLot += g_pairs[i].lotA + g_pairs[i].lotB;
         totalOrders += 2;
      }
   }
   
   // Update max equity for drawdown calculation
   if(equity > g_maxEquity) g_maxEquity = equity;
   
   // Calculate current drawdown %
   double ddPercent = 0;
   if(g_maxEquity > 0)
   {
      ddPercent = ((g_maxEquity - equity) / g_maxEquity) * 100;
      if(ddPercent < 0) ddPercent = 0;
   }
   
   // Track max drawdown
   if(ddPercent > g_maxDrawdownPercent) g_maxDrawdownPercent = ddPercent;
   
   // ===== Update Account Labels =====
   UpdateLabel(prefix + "V_BAL", DoubleToString(balance, 2), balance >= g_initialBalance ? COLOR_PROFIT : COLOR_LOSS);
   UpdateLabel(prefix + "V_EQ", DoubleToString(equity, 2), equity >= balance ? COLOR_PROFIT : COLOR_LOSS);
   UpdateLabel(prefix + "V_MG", DoubleToString(margin, 2), COLOR_TEXT);
   
   UpdateLabel(prefix + "V_TLOT", DoubleToString(totalLot, 2), COLOR_TEXT);
   UpdateLabel(prefix + "V_TORD", IntegerToString(totalOrders), COLOR_TEXT);
   
   UpdateLabel(prefix + "V_DD", DoubleToString(ddPercent, 2) + "%", ddPercent > 10 ? COLOR_LOSS : COLOR_TEXT);
   UpdateLabel(prefix + "V_MDD", DoubleToString(g_maxDrawdownPercent, 2) + "%", g_maxDrawdownPercent > InpMaxDrawdown ? COLOR_LOSS : COLOR_TEXT);
   
   UpdateLabel(prefix + "V_TPL", DoubleToString(totalPL, 2), totalPL >= 0 ? COLOR_PROFIT : COLOR_LOSS);
   
   // ===== Update Lot Statistics =====
   UpdateLabel(prefix + "V_DLOT", DoubleToString(g_dailyLot, 2), COLOR_TEXT);
   UpdateLabel(prefix + "V_WLOT", DoubleToString(g_weeklyLot, 2), COLOR_TEXT);
   UpdateLabel(prefix + "V_MLOT", DoubleToString(g_monthlyLot, 2), COLOR_TEXT);
   UpdateLabel(prefix + "V_ALOT", DoubleToString(g_allTimeLot, 2), COLOR_TEXT);
   
   // ===== Update Profit Labels =====
   UpdateLabel(prefix + "V_DP", DoubleToString(g_dailyProfit, 2), g_dailyProfit >= 0 ? COLOR_PROFIT : COLOR_LOSS);
   UpdateLabel(prefix + "V_WP", DoubleToString(g_weeklyProfit, 2), g_weeklyProfit >= 0 ? COLOR_PROFIT : COLOR_LOSS);
   UpdateLabel(prefix + "V_MP", DoubleToString(g_monthlyProfit, 2), g_monthlyProfit >= 0 ? COLOR_PROFIT : COLOR_LOSS);
   UpdateLabel(prefix + "V_AP", DoubleToString(g_allTimeProfit, 2), g_allTimeProfit >= 0 ? COLOR_PROFIT : COLOR_LOSS);
   
   // ===== Update Each Pair Row =====
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      string idxStr = IntegerToString(i);
      
      // Correlation %
      double corr = g_pairs[i].correlation * 100;
      color corrColor = MathAbs(corr) >= InpMinCorrelation * 100 ? COLOR_PROFIT : (corr < 0 ? COLOR_LOSS : COLOR_TEXT);
      UpdateLabel(prefix + "P" + idxStr + "_C", DoubleToString(corr, 0) + "%", corrColor);
      
      // Order count (1 if position open, 0 otherwise)
      int orderCount = (g_pairs[i].direction != 0) ? 1 : 0;
      UpdateLabel(prefix + "P" + idxStr + "_ORD", IntegerToString(orderCount), orderCount > 0 ? COLOR_ACTIVE : COLOR_TEXT);
      
      // Lot
      double pairLot = g_pairs[i].lotA + g_pairs[i].lotB;
      UpdateLabel(prefix + "P" + idxStr + "_LOT", DoubleToString(pairLot, 2), pairLot > 0 ? COLOR_TEXT : COLOR_LABEL);
      
      // Profit
      double profit = g_pairs[i].pairProfit;
      UpdateLabel(prefix + "P" + idxStr + "_PROF", DoubleToString(profit, 0), profit >= 0 ? COLOR_PROFIT : COLOR_LOSS);
      
      // Total P/L for this pair
      UpdateLabel(prefix + "P" + idxStr + "_TPL", DoubleToString(profit, 0), profit >= 0 ? COLOR_PROFIT : COLOR_LOSS);
      
      // Status
      string status = g_pairs[i].enabled ? "On" : "Off";
      color stColor = g_pairs[i].enabled ? COLOR_ON : COLOR_OFF;
      if(g_pairs[i].direction == 1)
      {
         status = "LONG";
         stColor = COLOR_PROFIT;
      }
      else if(g_pairs[i].direction == -1)
      {
         status = "SHORT";
         stColor = COLOR_LOSS;
      }
      UpdateLabel(prefix + "P" + idxStr + "_ST", status, stColor);
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
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Helper: Create Label                                               |
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
//| Helper: Create Line (using rectangle)                              |
//+------------------------------------------------------------------+
void CreateLine(string name, int x1, int y1, int x2, int y2, color clr)
{
   ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x1);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y1);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, x2 - x1);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, 1);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}
