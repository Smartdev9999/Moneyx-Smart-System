//+------------------------------------------------------------------+
//|                                 Money_Printing_Machine__EA.mq5
//|                               Money Printing Machine v1.0
//+------------------------------------------------------------------+
#property copyright "MoneyX Trading"
#property version   "1.0"
#property strict

#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| INPUT PARAMETERS                                                  |
//+------------------------------------------------------------------+
input group "=== Trading Settings ==="
input double   InpLotSize = 0.01;
input int      InpMagicNumber = 123456;
input int      InpSlippage = 10;

input group "=== Time Filter ==="
input bool     InpUseTimeFilter = false;
input int      InpStartHour = 8;
input int      InpEndHour = 20;

input group "=== News Filter Settings ==="
input bool     InpEnableNewsFilter = true;
input bool     InpFilterHighImpact = true;
input bool     InpFilterMediumImpact = false;
input bool     InpFilterLowImpact = false;
input int      InpPauseBeforeHigh = 60;
input int      InpPauseAfterHigh = 60;
input int      InpPauseBeforeMedium = 30;
input int      InpPauseAfterMedium = 30;

input group "=== AI Market Bias Settings ==="
input bool     InpEnableAIAnalysis = true;
input string   InpAIPairs = "EURUSD,GBPUSD,XAUUSD,USDJPY,AUDUSD";
input ENUM_TIMEFRAMES InpAITimeframe = PERIOD_H1;
input int      InpBiasThreshold = 70;  // Minimum probability to trade (%)

//+------------------------------------------------------------------+
//| CONFIGURATION CONSTANTS                                           |
//+------------------------------------------------------------------+
#define LICENSE_BASE_URL    "https://lkbhomsulgycxawwlnfh.supabase.co"
#define EA_API_SECRET       "moneyx-ea-secret-2024-secure-key-v1"
#define LICENSE_CHECK_HOURS 24
#define NEWS_REFRESH_HOURS  1
#define NEWS_RETRY_MINUTES  5
#define NEWS_MAX_EVENTS     100
#define SYNC_DAILY_HOUR_1   5
#define SYNC_DAILY_HOUR_2   23
#define TRADE_HISTORY_COUNT 100
#define AI_CANDLE_COUNT     50

//+------------------------------------------------------------------+
//| ENUMERATIONS                                                      |
//+------------------------------------------------------------------+
enum ENUM_LICENSE_STATUS
{
   LICENSE_VALID,
   LICENSE_EXPIRED,
   LICENSE_EXPIRING_SOON,
   LICENSE_NOT_FOUND,
   LICENSE_SUSPENDED,
   LICENSE_ERROR
};

//+------------------------------------------------------------------+
//| STRUCTURES                                                        |
//+------------------------------------------------------------------+
struct SNewsEvent
{
   datetime  eventTime;
   string    title;
   string    currency;
   int       impactLevel;
};

struct SMarketBias
{
   string    symbol;
   int       bullishProb;      // 0-100
   int       bearishProb;      // 0-100
   int       sidewaysProb;     // 0-100
   string    dominantBias;     // bullish, bearish, sideways
   bool      thresholdMet;     // >= threshold%
   string    marketStructure;
   string    trendH4;
   string    trendDaily;
   string    patterns;
   string    recommendation;   // "Only LONG", "Only SHORT", "No Trade"
   string    reasoning;
   datetime  lastUpdate;
};

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                  |
//+------------------------------------------------------------------+
CTrade trade;

// License
ENUM_LICENSE_STATUS g_licenseStatus = LICENSE_ERROR;
bool              g_isLicenseValid = false;
datetime          g_lastLicenseCheck = 0;
string            g_customerName = "";
string            g_packageType = "";
int               g_daysRemaining = 0;
bool              g_isLifetime = false;

// News Filter
SNewsEvent   g_newsEvents[];
int          g_newsEventCount = 0;
datetime     g_lastNewsRefresh = 0;
bool         g_forceNewsRefresh = true;
string       g_currentNewsTitle = "";
datetime     g_currentPauseEnd = 0;
bool         g_isTradingPaused = false;

// AI Market Bias Analysis
SMarketBias  g_marketBias[];
int          g_biasCount = 0;
datetime     g_lastBiasAnalysis = 0;
datetime     g_lastCandleTime[];
string       g_aiPairs[];
int          g_aiPairCount = 0;
string       g_overallBias = "sideways";
int          g_tradablePairs = 0;

// Data Sync
datetime g_lastDataSync = 0;
int      g_lastSyncHour = -1;
string   g_eaStatus = "working";

//+------------------------------------------------------------------+
//| HELPER FUNCTIONS                                                  |
//+------------------------------------------------------------------+
string ExtractJsonString(string json, string key)
{
   string searchKey = "\"" + key + "\":\"";
   int startPos = StringFind(json, searchKey);
   if(startPos < 0) return "";
   
   startPos += StringLen(searchKey);
   int endPos = StringFind(json, "\"", startPos);
   if(endPos < 0) return "";
   
   return StringSubstr(json, startPos, endPos - startPos);
}

int ExtractJsonInt(string json, string key)
{
   string strVal = ExtractJsonString(json, key);
   if(StringLen(strVal) > 0)
      return (int)StringToInteger(strVal);
   
   string searchKey = "\"" + key + "\":";
   int startPos = StringFind(json, searchKey);
   if(startPos < 0) return 0;
   
   startPos += StringLen(searchKey);
   string numStr = "";
   
   for(int i = startPos; i < StringLen(json); i++)
   {
      ushort ch = StringGetCharacter(json, i);
      if((ch >= '0' && ch <= '9') || ch == '-')
         numStr += ShortToString(ch);
      else if(StringLen(numStr) > 0)
         break;
   }
   
   return (int)StringToInteger(numStr);
}

double ExtractJsonDouble(string json, string key)
{
   string searchKey = "\"" + key + "\":";
   int startPos = StringFind(json, searchKey);
   if(startPos < 0) return 0;
   
   startPos += StringLen(searchKey);
   string numStr = "";
   
   for(int i = startPos; i < StringLen(json); i++)
   {
      ushort ch = StringGetCharacter(json, i);
      if((ch >= '0' && ch <= '9') || ch == '.' || ch == '-')
         numStr += ShortToString(ch);
      else if(StringLen(numStr) > 0)
         break;
   }
   
   return StringToDouble(numStr);
}

datetime ParseISODateTime(string isoStr)
{
   if(StringLen(isoStr) < 19) return 0;
   
   int year = (int)StringToInteger(StringSubstr(isoStr, 0, 4));
   int month = (int)StringToInteger(StringSubstr(isoStr, 5, 2));
   int day = (int)StringToInteger(StringSubstr(isoStr, 8, 2));
   int hour = (int)StringToInteger(StringSubstr(isoStr, 11, 2));
   int minute = (int)StringToInteger(StringSubstr(isoStr, 14, 2));
   int second = (int)StringToInteger(StringSubstr(isoStr, 17, 2));
   
   MqlDateTime dt;
   dt.year = year;
   dt.mon = month;
   dt.day = day;
   dt.hour = hour;
   dt.min = minute;
   dt.sec = second;
   
   datetime utcTime = StructToTime(dt);
   int serverOffset = (int)(TimeCurrent() - TimeGMT());
   return utcTime + serverOffset;
}

//+------------------------------------------------------------------+
//| LICENSE MANAGER                                                   |
//+------------------------------------------------------------------+
bool IsTestMode()
{
   return (MQLInfoInteger(MQL_TESTER) || 
           MQLInfoInteger(MQL_OPTIMIZATION) ||
           MQLInfoInteger(MQL_VISUAL_MODE));
}

ENUM_LICENSE_STATUS VerifyLicense()
{
   if(IsTestMode())
   {
      g_isLicenseValid = true;
      g_licenseStatus = LICENSE_VALID;
      return LICENSE_VALID;
   }
   
   string accountNumber = IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
   string url = LICENSE_BASE_URL + "/functions/v1/verify-license";
   string jsonBody = "{\"account_number\":\"" + accountNumber + "\"}";
   
   char post[];
   char result[];
   string resultHeaders;
   string headers = "Content-Type: application/json\r\nx-api-key: " + EA_API_SECRET + "\r\n";
   
   StringToCharArray(jsonBody, post, 0, StringLen(jsonBody), CP_UTF8);
   ArrayResize(post, ArraySize(post) - 1);
   
   ResetLastError();
   int res = WebRequest("POST", url, headers, 10000, post, result, resultHeaders);
   
   if(res == -1)
   {
      int error = GetLastError();
      if(error == 4060)
         Print("[License] ERROR: WebRequest disabled. Enable in Tools > Options > Expert Advisors");
      else if(error == 4024)
         Print("[License] ERROR: Add ", LICENSE_BASE_URL, " to allowed URLs");
      return LICENSE_ERROR;
   }
   
   string response = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
   
   if(StringFind(response, "\"valid\":true") >= 0)
   {
      g_isLicenseValid = true;
      g_customerName = ExtractJsonString(response, "customer_name");
      g_packageType = ExtractJsonString(response, "package_type");
      g_daysRemaining = ExtractJsonInt(response, "days_remaining");
      g_isLifetime = (StringFind(response, "\"is_lifetime\":true") >= 0);
      g_lastLicenseCheck = TimeCurrent();
      
      if(g_daysRemaining > 0 && g_daysRemaining <= 7)
      {
         g_licenseStatus = LICENSE_EXPIRING_SOON;
         return LICENSE_EXPIRING_SOON;
      }
      
      g_licenseStatus = LICENSE_VALID;
      return LICENSE_VALID;
   }
   
   g_isLicenseValid = false;
   
   if(StringFind(response, "not found") >= 0) { g_licenseStatus = LICENSE_NOT_FOUND; return LICENSE_NOT_FOUND; }
   if(StringFind(response, "expired") >= 0) { g_licenseStatus = LICENSE_EXPIRED; return LICENSE_EXPIRED; }
   if(StringFind(response, "suspended") >= 0) { g_licenseStatus = LICENSE_SUSPENDED; return LICENSE_SUSPENDED; }
   
   g_licenseStatus = LICENSE_ERROR;
   return LICENSE_ERROR;
}

void ShowLicensePopup(ENUM_LICENSE_STATUS status)
{
   string title = "Money Printing Machine - License";
   string message = "";
   int icon = MB_ICONINFORMATION;
   
   switch(status)
   {
      case LICENSE_VALID:
         if(g_isLifetime)
            message = "License Activated!\n\nCustomer: " + g_customerName + "\nPackage: " + g_packageType + "\nLicense: LIFETIME";
         else
            message = "License Activated!\n\nCustomer: " + g_customerName + "\nPackage: " + g_packageType + "\nDays Remaining: " + IntegerToString(g_daysRemaining);
         break;
      case LICENSE_EXPIRING_SOON:
         message = "License Expiring Soon!\n\nDays Remaining: " + IntegerToString(g_daysRemaining) + "\n\nPlease renew your license.";
         icon = MB_ICONWARNING;
         break;
      case LICENSE_EXPIRED:
         message = "License Expired!\n\nAccount: " + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "\n\nPlease contact support to renew.";
         icon = MB_ICONERROR;
         break;
      case LICENSE_NOT_FOUND:
         message = "Account Not Registered!\n\nAccount: " + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "\n\nPlease contact support.";
         icon = MB_ICONERROR;
         break;
      case LICENSE_SUSPENDED:
         message = "License Suspended!\n\nAccount: " + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "\n\nPlease contact support.";
         icon = MB_ICONERROR;
         break;
      case LICENSE_ERROR:
         message = "Connection Error!\n\nPlease check internet connection.\nMake sure " + LICENSE_BASE_URL + " is in allowed URLs.";
         icon = MB_ICONWARNING;
         break;
   }
   
   MessageBox(message, title, icon | MB_OK);
}

bool InitLicense()
{
   if(IsTestMode())
   {
      g_isLicenseValid = true;
      g_licenseStatus = LICENSE_VALID;
      Print("[License] Running in tester mode - License check skipped");
      return true;
   }
   
   g_licenseStatus = VerifyLicense();
   ShowLicensePopup(g_licenseStatus);
   
   return (g_licenseStatus == LICENSE_VALID || g_licenseStatus == LICENSE_EXPIRING_SOON);
}

bool CheckLicenseTick()
{
   if(IsTestMode()) return true;
   
   datetime now = TimeCurrent();
   
   if(now - g_lastLicenseCheck >= LICENSE_CHECK_HOURS * 3600)
   {
      g_licenseStatus = VerifyLicense();
      if(g_licenseStatus != LICENSE_VALID && g_licenseStatus != LICENSE_EXPIRING_SOON)
      {
         ShowLicensePopup(g_licenseStatus);
         return false;
      }
   }
   
   return g_isLicenseValid;
}

//+------------------------------------------------------------------+
//| NEWS FILTER                                                       |
//+------------------------------------------------------------------+
void InitNewsFilter()
{
   ArrayResize(g_newsEvents, NEWS_MAX_EVENTS);
   g_newsEventCount = 0;
   g_lastNewsRefresh = 0;
   g_forceNewsRefresh = true;
   g_isTradingPaused = false;
   g_currentNewsTitle = "";
   g_currentPauseEnd = 0;
   
   Print("[NewsFilter] Initialized - Enabled: ", InpEnableNewsFilter);
}

bool ParseNewsResponse(string json)
{
   g_newsEventCount = 0;
   
   int dataStart = StringFind(json, "\"data\":[");
   if(dataStart < 0)
   {
      if(StringFind(json, "\"data\":[]") >= 0)
      {
         Print("[NewsFilter] No news events found (OK)");
         return true;
      }
      return false;
   }
   
   int searchPos = dataStart;
   while(g_newsEventCount < NEWS_MAX_EVENTS)
   {
      int eventStart = StringFind(json, "{", searchPos + 1);
      if(eventStart < 0) break;
      
      int eventEnd = StringFind(json, "}", eventStart);
      if(eventEnd < 0) break;
      
      int arrayEnd = StringFind(json, "]", dataStart);
      if(arrayEnd > 0 && eventStart > arrayEnd) break;
      
      string eventJson = StringSubstr(json, eventStart, eventEnd - eventStart + 1);
      
      string timestamp = ExtractJsonString(eventJson, "timestamp");
      if(StringLen(timestamp) == 0)
      {
         searchPos = eventEnd;
         continue;
      }
      
      g_newsEvents[g_newsEventCount].eventTime = ParseISODateTime(timestamp);
      g_newsEvents[g_newsEventCount].title = ExtractJsonString(eventJson, "title");
      g_newsEvents[g_newsEventCount].currency = ExtractJsonString(eventJson, "currency");
      g_newsEvents[g_newsEventCount].impactLevel = ExtractJsonInt(eventJson, "impact_level");
      
      g_newsEventCount++;
      searchPos = eventEnd;
   }
   
   Print("[NewsFilter] Loaded ", g_newsEventCount, " news events");
   return true;
}

bool RefreshNewsData()
{
   if(IsTestMode()) return true;
   
   string url = LICENSE_BASE_URL + "/functions/v1/economic-news?format=ea&days=3";
   
   char post[];
   char result[];
   string resultHeaders;
   string headers = "Content-Type: application/json\r\n";
   
   ResetLastError();
   int res = WebRequest("GET", url, headers, 10000, post, result, resultHeaders);
   
   if(res == -1)
   {
      int error = GetLastError();
      if(error == 4060 || error == 4024)
         Print("[NewsFilter] ERROR: Add ", LICENSE_BASE_URL, " to allowed URLs");
      return false;
   }
   
   if(res != 200)
   {
      Print("[NewsFilter] HTTP Error: ", res);
      return false;
   }
   
   string response = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
   
   if(StringFind(response, "\"success\":true") < 0)
   {
      Print("[NewsFilter] Invalid response from server");
      return false;
   }
   
   return ParseNewsResponse(response);
}

bool IsEventRelevant(int impactLevel)
{
   switch(impactLevel)
   {
      case 3: return InpFilterHighImpact;
      case 2: return InpFilterMediumImpact;
      case 1: return InpFilterLowImpact;
      default: return false;
   }
}

int GetPauseBeforeMinutes(int impactLevel)
{
   switch(impactLevel)
   {
      case 3: return InpPauseBeforeHigh;
      case 2: return InpPauseBeforeMedium;
      case 1: return 15;
      default: return 0;
   }
}

int GetPauseAfterMinutes(int impactLevel)
{
   switch(impactLevel)
   {
      case 3: return InpPauseAfterHigh;
      case 2: return InpPauseAfterMedium;
      case 1: return 15;
      default: return 0;
   }
}

bool CheckNewsFilter()
{
   if(!InpEnableNewsFilter) return true;
   if(IsTestMode()) return true;
   
   datetime now = TimeCurrent();
   
   bool needRefresh = g_forceNewsRefresh || (now - g_lastNewsRefresh >= NEWS_REFRESH_HOURS * 3600);
   
   if(needRefresh)
   {
      if(RefreshNewsData())
      {
         g_lastNewsRefresh = now;
         g_forceNewsRefresh = false;
      }
      else
      {
         if(g_lastNewsRefresh == 0)
            g_lastNewsRefresh = now - (NEWS_REFRESH_HOURS * 3600) + (NEWS_RETRY_MINUTES * 60);
      }
   }
   
   g_isTradingPaused = false;
   g_currentNewsTitle = "";
   g_currentPauseEnd = 0;
   
   for(int i = 0; i < g_newsEventCount; i++)
   {
      if(!IsEventRelevant(g_newsEvents[i].impactLevel)) continue;
      
      int pauseBefore = GetPauseBeforeMinutes(g_newsEvents[i].impactLevel);
      int pauseAfter = GetPauseAfterMinutes(g_newsEvents[i].impactLevel);
      
      datetime pauseStart = g_newsEvents[i].eventTime - pauseBefore * 60;
      datetime pauseEnd = g_newsEvents[i].eventTime + pauseAfter * 60;
      
      if(now >= pauseStart && now <= pauseEnd)
      {
         g_isTradingPaused = true;
         g_currentNewsTitle = g_newsEvents[i].title;
         
         if(g_currentPauseEnd == 0 || pauseEnd < g_currentPauseEnd)
            g_currentPauseEnd = pauseEnd;
      }
   }
   
   return !g_isTradingPaused;
}

string GetNewsStatusString()
{
   if(!InpEnableNewsFilter) return "Disabled";
   
   if(g_isTradingPaused && g_currentPauseEnd > 0)
   {
      int remaining = (int)(g_currentPauseEnd - TimeCurrent());
      if(remaining > 0)
      {
         int hours = remaining / 3600;
         int mins = (remaining % 3600) / 60;
         int secs = remaining % 60;
         return StringFormat("PAUSE: %s (%02d:%02d:%02d)", g_currentNewsTitle, hours, mins, secs);
      }
   }
   
   return "No Important News";
}

//+------------------------------------------------------------------+
//| AI MARKET BIAS ANALYSIS                                           |
//+------------------------------------------------------------------+
void InitAIAnalysis()
{
   if(!InpEnableAIAnalysis) return;
   
   // Parse pairs string
   string pairs = InpAIPairs;
   StringReplace(pairs, " ", "");
   
   string pairArray[];
   g_aiPairCount = StringSplit(pairs, ',', pairArray);
   
   ArrayResize(g_aiPairs, g_aiPairCount);
   ArrayResize(g_lastCandleTime, g_aiPairCount);
   ArrayResize(g_marketBias, g_aiPairCount);
   
   for(int i = 0; i < g_aiPairCount; i++)
   {
      g_aiPairs[i] = pairArray[i];
      g_lastCandleTime[i] = 0;
      g_marketBias[i].symbol = pairArray[i];
      g_marketBias[i].dominantBias = "sideways";
      g_marketBias[i].bullishProb = 33;
      g_marketBias[i].bearishProb = 33;
      g_marketBias[i].sidewaysProb = 34;
      g_marketBias[i].thresholdMet = false;
      g_marketBias[i].recommendation = "No Trade";
   }
   
   g_biasCount = g_aiPairCount;
   Print("[AI Bias] Initialized for ", g_aiPairCount, " pairs: ", InpAIPairs, " | Threshold: ", InpBiasThreshold, "%");
}

bool IsNewCandle(string symbol, int index)
{
   datetime currentCandleTime = iTime(symbol, InpAITimeframe, 0);
   if(currentCandleTime > g_lastCandleTime[index])
   {
      g_lastCandleTime[index] = currentCandleTime;
      return true;
   }
   return false;
}

bool CheckAnyNewCandle()
{
   for(int i = 0; i < g_aiPairCount; i++)
   {
      if(IsNewCandle(g_aiPairs[i], i))
         return true;
   }
   return false;
}

string BuildCandleJson(string symbol, int count)
{
   string json = "[";
   
   for(int i = count - 1; i >= 0; i--)
   {
      datetime time = iTime(symbol, InpAITimeframe, i);
      double open = iOpen(symbol, InpAITimeframe, i);
      double high = iHigh(symbol, InpAITimeframe, i);
      double low = iLow(symbol, InpAITimeframe, i);
      double close = iClose(symbol, InpAITimeframe, i);
      long volume = iVolume(symbol, InpAITimeframe, i);
      
      if(i < count - 1) json += ",";
      
      json += "{";
      json += "\"time\":\"" + TimeToString(time, TIME_DATE|TIME_SECONDS) + "\",";
      json += "\"open\":" + DoubleToString(open, 5) + ",";
      json += "\"high\":" + DoubleToString(high, 5) + ",";
      json += "\"low\":" + DoubleToString(low, 5) + ",";
      json += "\"close\":" + DoubleToString(close, 5) + ",";
      json += "\"volume\":" + IntegerToString(volume);
      json += "}";
   }
   
   json += "]";
   return json;
}

string BuildIndicatorsJson(string symbol)
{
   // Calculate indicators
   int rsiHandle = iRSI(symbol, InpAITimeframe, 14, PRICE_CLOSE);
   int macdHandle = iMACD(symbol, InpAITimeframe, 12, 26, 9, PRICE_CLOSE);
   int ema20Handle = iMA(symbol, InpAITimeframe, 20, 0, MODE_EMA, PRICE_CLOSE);
   int ema50Handle = iMA(symbol, InpAITimeframe, 50, 0, MODE_EMA, PRICE_CLOSE);
   int atrHandle = iATR(symbol, InpAITimeframe, 14);
   
   double rsiBuffer[], macdMainBuffer[], macdSignalBuffer[], ema20Buffer[], ema50Buffer[], atrBuffer[];
   
   CopyBuffer(rsiHandle, 0, 0, 1, rsiBuffer);
   CopyBuffer(macdHandle, 0, 0, 1, macdMainBuffer);
   CopyBuffer(macdHandle, 1, 0, 1, macdSignalBuffer);
   CopyBuffer(ema20Handle, 0, 0, 1, ema20Buffer);
   CopyBuffer(ema50Handle, 0, 0, 1, ema50Buffer);
   CopyBuffer(atrHandle, 0, 0, 1, atrBuffer);
   
   // Release handles
   IndicatorRelease(rsiHandle);
   IndicatorRelease(macdHandle);
   IndicatorRelease(ema20Handle);
   IndicatorRelease(ema50Handle);
   IndicatorRelease(atrHandle);
   
   string json = "{";
   json += "\"rsi\":" + (ArraySize(rsiBuffer) > 0 ? DoubleToString(rsiBuffer[0], 2) : "0") + ",";
   json += "\"macd\":{";
   json += "\"main\":" + (ArraySize(macdMainBuffer) > 0 ? DoubleToString(macdMainBuffer[0], 6) : "0") + ",";
   json += "\"signal\":" + (ArraySize(macdSignalBuffer) > 0 ? DoubleToString(macdSignalBuffer[0], 6) : "0") + ",";
   json += "\"histogram\":" + (ArraySize(macdMainBuffer) > 0 && ArraySize(macdSignalBuffer) > 0 ? DoubleToString(macdMainBuffer[0] - macdSignalBuffer[0], 6) : "0");
   json += "},";
   json += "\"ema\":{";
   json += "\"ema20\":" + (ArraySize(ema20Buffer) > 0 ? DoubleToString(ema20Buffer[0], 5) : "0") + ",";
   json += "\"ema50\":" + (ArraySize(ema50Buffer) > 0 ? DoubleToString(ema50Buffer[0], 5) : "0");
   json += "},";
   json += "\"atr\":" + (ArraySize(atrBuffer) > 0 ? DoubleToString(atrBuffer[0], 5) : "0");
   json += "}";
   
   return json;
}

string BuildAIRequestJson()
{
   string json = "{\"pairs\":[";
   
   for(int i = 0; i < g_aiPairCount; i++)
   {
      if(i > 0) json += ",";
      
      string symbol = g_aiPairs[i];
      datetime candleTime = iTime(symbol, InpAITimeframe, 0);
      
      json += "{";
      json += "\"symbol\":\"" + symbol + "\",";
      json += "\"timeframe\":\"" + EnumToString(InpAITimeframe) + "\",";
      json += "\"candle_time\":\"" + TimeToString(candleTime, TIME_DATE|TIME_SECONDS) + "\",";
      json += "\"candles\":" + BuildCandleJson(symbol, AI_CANDLE_COUNT) + ",";
      json += "\"indicators\":" + BuildIndicatorsJson(symbol);
      json += "}";
   }
   
   json += "],\"threshold\":" + IntegerToString(InpBiasThreshold) + "}";
   return json;
}

bool ParseMarketBias(string json, int index)
{
   // Extract symbol
   string symbol = ExtractJsonString(json, "symbol");
   if(symbol != g_aiPairs[index]) return false;
   
   g_marketBias[index].symbol = symbol;
   g_marketBias[index].bullishProb = ExtractJsonInt(json, "bullish_probability");
   g_marketBias[index].bearishProb = ExtractJsonInt(json, "bearish_probability");
   g_marketBias[index].sidewaysProb = ExtractJsonInt(json, "sideways_probability");
   g_marketBias[index].dominantBias = ExtractJsonString(json, "dominant_bias");
   g_marketBias[index].thresholdMet = (StringFind(json, "\"threshold_met\":true") >= 0);
   g_marketBias[index].marketStructure = ExtractJsonString(json, "market_structure");
   g_marketBias[index].trendH4 = ExtractJsonString(json, "trend_h4");
   g_marketBias[index].trendDaily = ExtractJsonString(json, "trend_daily");
   g_marketBias[index].patterns = ExtractJsonString(json, "patterns");
   g_marketBias[index].recommendation = ExtractJsonString(json, "recommendation");
   g_marketBias[index].reasoning = ExtractJsonString(json, "reasoning");
   g_marketBias[index].lastUpdate = TimeCurrent();
   
   return true;
}

bool ParseBiasResponse(string response)
{
   if(StringFind(response, "\"success\":true") < 0)
   {
      Print("[AI Bias] Request failed: ", response);
      return false;
   }
   
   // Extract overall bias and tradable pairs
   g_overallBias = ExtractJsonString(response, "overall_bias");
   g_tradablePairs = ExtractJsonInt(response, "tradable_pairs");
   
   // Parse each bias from analysis array
   int analysisStart = StringFind(response, "\"analysis\":[");
   if(analysisStart < 0) return false;
   
   int searchPos = analysisStart;
   int biasIndex = 0;
   
   while(biasIndex < g_aiPairCount)
   {
      int objStart = StringFind(response, "{\"symbol\":", searchPos);
      if(objStart < 0) break;
      
      int objEnd = StringFind(response, "}", objStart);
      if(objEnd < 0) break;
      
      string biasJson = StringSubstr(response, objStart, objEnd - objStart + 1);
      
      // Find matching pair index
      for(int i = 0; i < g_aiPairCount; i++)
      {
         if(StringFind(biasJson, "\"" + g_aiPairs[i] + "\"") >= 0)
         {
            ParseMarketBias(biasJson, i);
            break;
         }
      }
      
      searchPos = objEnd;
      biasIndex++;
   }
   
   return true;
}

bool RequestMarketBias()
{
   if(IsTestMode()) return true;
   if(!InpEnableAIAnalysis) return true;
   
   string url = LICENSE_BASE_URL + "/functions/v1/ai-market-analysis";
   string json = BuildAIRequestJson();
   
   char post[];
   char result[];
   string resultHeaders;
   string headers = "Content-Type: application/json\r\nx-api-key: " + EA_API_SECRET + "\r\n";
   
   StringToCharArray(json, post, 0, StringLen(json), CP_UTF8);
   ArrayResize(post, ArraySize(post) - 1);
   
   ResetLastError();
   int res = WebRequest("POST", url, headers, 30000, post, result, resultHeaders);
   
   if(res == -1)
   {
      int error = GetLastError();
      if(error == 4060 || error == 4024)
         Print("[AI Bias] ERROR: Add ", LICENSE_BASE_URL, " to allowed URLs");
      return false;
   }
   
   if(res != 200)
   {
      Print("[AI Bias] HTTP Error: ", res);
      return false;
   }
   
   string response = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
   bool success = ParseBiasResponse(response);
   
   if(success)
   {
      g_lastBiasAnalysis = TimeCurrent();
      Print("[AI Bias] Updated bias for ", g_aiPairCount, " pairs. Overall: ", g_overallBias, " | Tradable: ", g_tradablePairs);
   }
   
   return success;
}

void CheckMarketBias()
{
   if(!InpEnableAIAnalysis) return;
   if(IsTestMode()) return;
   if(!g_isLicenseValid) return;
   
   // Only analyze on new candle
   if(CheckAnyNewCandle())
   {
      Print("[AI Bias] New candle detected, requesting market bias...");
      RequestMarketBias();
   }
}

SMarketBias GetMarketBias(string symbol)
{
   SMarketBias emptyBias;
   emptyBias.symbol = symbol;
   emptyBias.dominantBias = "sideways";
   emptyBias.bullishProb = 33;
   emptyBias.bearishProb = 33;
   emptyBias.sidewaysProb = 34;
   emptyBias.thresholdMet = false;
   emptyBias.recommendation = "No Trade";
   
   for(int i = 0; i < g_biasCount; i++)
   {
      if(g_marketBias[i].symbol == symbol)
         return g_marketBias[i];
   }
   
   return emptyBias;
}

// Check if we can trade in a specific direction based on AI bias
bool CanTradeDirection(string symbol, string direction)
{
   SMarketBias bias = GetMarketBias(symbol);
   
   if(!bias.thresholdMet) return false;
   
   if(direction == "buy" || direction == "long")
      return (bias.dominantBias == "bullish");
   
   if(direction == "sell" || direction == "short")
      return (bias.dominantBias == "bearish");
   
   return false;
}

string GetBiasStatusString()
{
   if(!InpEnableAIAnalysis) return "Disabled";
   
   if(g_lastBiasAnalysis == 0) return "Waiting for first analysis...";
   
   int elapsed = (int)(TimeCurrent() - g_lastBiasAnalysis);
   int mins = elapsed / 60;
   
   string status = StringFormat("Overall: %s | Tradable: %d/%d | Updated: %d min ago",
      g_overallBias, g_tradablePairs, g_aiPairCount, mins);
   
   return status;
}
   
   string status = "Sentiment: " + g_marketSentiment + " | Updated: " + IntegerToString(mins) + "m ago";
   return status;
}

//+------------------------------------------------------------------+
//| DATA SYNC                                                         |
//+------------------------------------------------------------------+
string GetEntryTypeString(long entryType)
{
   switch(entryType)
   {
      case DEAL_ENTRY_IN:    return "IN";
      case DEAL_ENTRY_OUT:   return "OUT";
      case DEAL_ENTRY_INOUT: return "INOUT";
      default:               return "UNKNOWN";
   }
}

double CalculateTotalProfit()
{
   double total = 0;
   if(!HistorySelect(0, TimeCurrent())) return 0;
   
   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      
      long dealType = HistoryDealGetInteger(ticket, DEAL_TYPE);
      if(dealType == DEAL_TYPE_BUY || dealType == DEAL_TYPE_SELL)
      {
         total += HistoryDealGetDouble(ticket, DEAL_PROFIT);
         total += HistoryDealGetDouble(ticket, DEAL_SWAP);
         total += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
      }
   }
   return total;
}

void CalculateTradeStats(int &total, int &wins, int &losses)
{
   total = 0; wins = 0; losses = 0;
   if(!HistorySelect(0, TimeCurrent())) return;
   
   for(int i = 0; i < HistoryDealsTotal(); i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      
      long dealType = HistoryDealGetInteger(ticket, DEAL_TYPE);
      long entryType = HistoryDealGetInteger(ticket, DEAL_ENTRY);
      
      if((dealType == DEAL_TYPE_BUY || dealType == DEAL_TYPE_SELL) && entryType == DEAL_ENTRY_OUT)
      {
         total++;
         double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
         if(profit >= 0) wins++;
         else losses++;
      }
   }
}

string BuildTradeHistoryJson()
{
   string json = "[";
   bool first = true;
   
   if(!HistorySelect(0, TimeCurrent()))
      return "[]";
   
   int totalDeals = HistoryDealsTotal();
   int startIndex = MathMax(0, totalDeals - TRADE_HISTORY_COUNT);
   
   for(int i = startIndex; i < totalDeals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      
      long dealType = HistoryDealGetInteger(ticket, DEAL_TYPE);
      long entryType = HistoryDealGetInteger(ticket, DEAL_ENTRY);
      
      if(dealType != DEAL_TYPE_BUY && dealType != DEAL_TYPE_SELL) continue;
      
      if(!first) json += ",";
      first = false;
      
      json += "{";
      json += "\"deal_ticket\":" + IntegerToString(ticket) + ",";
      json += "\"order_ticket\":" + IntegerToString(HistoryDealGetInteger(ticket, DEAL_ORDER)) + ",";
      json += "\"symbol\":\"" + HistoryDealGetString(ticket, DEAL_SYMBOL) + "\",";
      json += "\"deal_type\":\"" + (dealType == DEAL_TYPE_BUY ? "BUY" : "SELL") + "\",";
      json += "\"entry_type\":\"" + GetEntryTypeString(entryType) + "\",";
      json += "\"volume\":" + DoubleToString(HistoryDealGetDouble(ticket, DEAL_VOLUME), 2) + ",";
      json += "\"open_price\":" + DoubleToString(HistoryDealGetDouble(ticket, DEAL_PRICE), 5) + ",";
      json += "\"profit\":" + DoubleToString(HistoryDealGetDouble(ticket, DEAL_PROFIT), 2) + ",";
      json += "\"commission\":" + DoubleToString(HistoryDealGetDouble(ticket, DEAL_COMMISSION), 2) + ",";
      json += "\"swap\":" + DoubleToString(HistoryDealGetDouble(ticket, DEAL_SWAP), 2) + ",";
      json += "\"magic_number\":" + IntegerToString(HistoryDealGetInteger(ticket, DEAL_MAGIC)) + ",";
      json += "\"comment\":\"" + HistoryDealGetString(ticket, DEAL_COMMENT) + "\",";
      json += "\"close_time\":\"" + TimeToString(HistoryDealGetInteger(ticket, DEAL_TIME), TIME_DATE|TIME_SECONDS) + "\"";
      json += "}";
   }
   
   json += "]";
   return json;
}

bool SyncAccountData(string eventType = "scheduled")
{
   if(IsTestMode()) return true;
   if(!g_isLicenseValid) return false;
   
   string accountNumber = IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
   string url = LICENSE_BASE_URL + "/functions/v1/sync-account-data";
   
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   double profitLoss = AccountInfoDouble(ACCOUNT_PROFIT);
   
   double drawdown = 0;
   if(balance > 0)
   {
      drawdown = ((balance - equity) / balance) * 100;
      if(drawdown < 0) drawdown = 0;
   }
   
   int openOrders = PositionsTotal();
   double floatingPL = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
         floatingPL += PositionGetDouble(POSITION_PROFIT);
   }
   
   double totalProfit = CalculateTotalProfit();
   
   int totalTrades = 0, winTrades = 0, lossTrades = 0;
   CalculateTradeStats(totalTrades, winTrades, lossTrades);
   
   string tradeHistoryJson = BuildTradeHistoryJson();
   
   string json = "{";
   json += "\"account_number\":\"" + accountNumber + "\",";
   json += "\"balance\":" + DoubleToString(balance, 2) + ",";
   json += "\"equity\":" + DoubleToString(equity, 2) + ",";
   json += "\"margin_level\":" + DoubleToString(marginLevel, 2) + ",";
   json += "\"drawdown\":" + DoubleToString(drawdown, 2) + ",";
   json += "\"profit_loss\":" + DoubleToString(profitLoss, 2) + ",";
   json += "\"open_orders\":" + IntegerToString(openOrders) + ",";
   json += "\"floating_pl\":" + DoubleToString(floatingPL, 2) + ",";
   json += "\"total_profit\":" + DoubleToString(totalProfit, 2) + ",";
   json += "\"total_trades\":" + IntegerToString(totalTrades) + ",";
   json += "\"win_trades\":" + IntegerToString(winTrades) + ",";
   json += "\"loss_trades\":" + IntegerToString(lossTrades) + ",";
   json += "\"ea_status\":\"" + g_eaStatus + "\",";
   json += "\"event_type\":\"" + eventType + "\",";
   json += "\"trade_history\":" + tradeHistoryJson;
   json += "}";
   
   char post[];
   char result[];
   string resultHeaders;
   string headers = "Content-Type: application/json\r\nx-api-key: " + EA_API_SECRET + "\r\n";
   
   StringToCharArray(json, post, 0, StringLen(json), CP_UTF8);
   ArrayResize(post, ArraySize(post) - 1);
   
   int res = WebRequest("POST", url, headers, 15000, post, result, resultHeaders);
   
   if(res == 200)
   {
      g_lastDataSync = TimeCurrent();
      Print("[Sync] Account data synced - Event: ", eventType);
      return true;
   }
   
   Print("[Sync] Failed to sync. HTTP: ", res);
   return false;
}

void OnTradeSync(const MqlTradeTransaction& trans)
{
   if(IsTestMode()) return;
   if(!g_isLicenseValid) return;
   
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD || trans.type == TRADE_TRANSACTION_HISTORY_ADD)
   {
      Sleep(200);
      SyncAccountData("trade");
   }
}

void CheckScheduledSync()
{
   if(IsTestMode()) return;
   if(!g_isLicenseValid) return;
   
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   
   if((dt.hour == SYNC_DAILY_HOUR_1 || dt.hour == SYNC_DAILY_HOUR_2) && g_lastSyncHour != dt.hour)
   {
      SyncAccountData("daily");
      g_lastSyncHour = dt.hour;
   }
}

//+------------------------------------------------------------------+
//| CUSTOM FUNCTIONS                                                  |
//+------------------------------------------------------------------+
bool IsTradeTime()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   return (dt.hour >= InpStartHour && dt.hour < InpEndHour);
}

void ManagePositions()
{
   // === YOUR POSITION MANAGEMENT LOGIC HERE ===
   // This runs even during news pause
   // Handle: TP/SL adjustments, trailing stops, partial closes, etc.
}

//+------------------------------------------------------------------+
//| MAIN EA FUNCTIONS                                                 |
//+------------------------------------------------------------------+
int OnInit()
{
   if(!InitLicense())
   {
      Print("[Money Printing Machine] License verification failed!");
      g_isLicenseValid = false;
   }
   
   InitNewsFilter();
   InitAIAnalysis();
   
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   
   Print("[Money Printing Machine] EA initialized successfully!");
   Print("[Money Printing Machine] Account: ", AccountInfoInteger(ACCOUNT_LOGIN));
   Print("[Money Printing Machine] AI Bias Analysis: ", InpEnableAIAnalysis ? "Enabled" : "Disabled", " | Threshold: ", InpBiasThreshold, "%");
   
   SyncAccountData("init");
   
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   Print("[Money Printing Machine] EA deinitialized. Reason: ", reason);
}

void OnTick()
{
   if(!CheckLicenseTick())
   {
      g_eaStatus = "invalid";
      return;
   }
   
   CheckScheduledSync();
   CheckMarketBias();
   
   bool canTrade = CheckNewsFilter();
   
   if(InpUseTimeFilter && !IsTradeTime())
      canTrade = false;
   
   if(g_isTradingPaused)
      g_eaStatus = "paused";
   else
      g_eaStatus = "working";
   
   if(!canTrade)
   {
      ManagePositions();
      return;
   }
   
   // === YOUR ENTRY LOGIC HERE ===
   // Use AI Market Bias to filter direction:
   // SMarketBias bias = GetMarketBias(_Symbol);
   // if(bias.thresholdMet && bias.dominantBias == "bullish")
   // {
   //    // Only look for BUY setups with SMC + Price Action
   // }
   // else if(bias.thresholdMet && bias.dominantBias == "bearish")
   // {
   //    // Only look for SELL setups with SMC + Price Action
   // }
   // else
   // {
   //    // No trade today - probability below threshold
   // }
   
}

void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   OnTradeSync(trans);
}
//+------------------------------------------------------------------+
