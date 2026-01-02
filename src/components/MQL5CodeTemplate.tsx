import { useState } from 'react';
import { Button } from '@/components/ui/button';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card';
import { Tabs, TabsContent, TabsList, TabsTrigger } from '@/components/ui/tabs';
import { Badge } from '@/components/ui/badge';
import { Copy, Check, Download, FileCode } from 'lucide-react';
import { useToast } from '@/hooks/use-toast';
import CodeBlock from '@/components/CodeBlock';

interface MQL5CodeTemplateProps {
  systemName: string;
  version: string;
  description?: string;
}

// Generate file-safe name from system name
const generateFileName = (name: string): string => {
  return name
    .replace(/[^a-zA-Z0-9\s]/g, '')
    .replace(/\s+/g, '_')
    .trim();
};

const MQL5CodeTemplate = ({ systemName, version, description }: MQL5CodeTemplateProps) => {
  const [copiedSection, setCopiedSection] = useState<string | null>(null);
  const { toast } = useToast();
  
  const fileName = generateFileName(systemName);
  const fileNameMq5 = `${fileName}_EA.mq5`;
  
  const handleCopy = async (text: string, sectionId: string) => {
    await navigator.clipboard.writeText(text);
    setCopiedSection(sectionId);
    toast({
      title: "คัดลอกแล้ว",
      description: "โค้ดถูกคัดลอกไปยัง clipboard",
    });
    setTimeout(() => setCopiedSection(null), 2000);
  };
  
  const handleDownload = (content: string, filename: string) => {
    const blob = new Blob([content], { type: 'text/plain;charset=utf-8' });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = filename;
    document.body.appendChild(a);
    a.click();
    document.body.removeChild(a);
    URL.revokeObjectURL(url);
    
    toast({
      title: "ดาวน์โหลดสำเร็จ",
      description: `ไฟล์ ${filename} ถูกดาวน์โหลดแล้ว`,
    });
  };

  // === LICENSE MANAGER CODE ===
  const licenseManagerCode = `//+------------------------------------------------------------------+
//|                              License Manager for ${systemName}
//|                                  Version ${version}
//+------------------------------------------------------------------+

// ===== LICENSE CONFIGURATION =====
// IMPORTANT: Update this URL to your Supabase project URL
#define LICENSE_BASE_URL    "https://lkbhomsulgycxawwlnfh.supabase.co"
#define EA_API_SECRET       "moneyx-ea-secret-2024-secure-key-v1"
#define LICENSE_CHECK_HOURS 24  // Check license every 24 hours

// License Status Enumeration
enum ENUM_LICENSE_STATUS
{
   LICENSE_VALID,           // License is valid and active
   LICENSE_EXPIRED,         // License has expired
   LICENSE_EXPIRING_SOON,   // License expiring within 7 days
   LICENSE_NOT_FOUND,       // Account not registered
   LICENSE_SUSPENDED,       // Account suspended by admin
   LICENSE_ERROR            // Connection or server error
};

// Global license variables
ENUM_LICENSE_STATUS g_licenseStatus = LICENSE_ERROR;
bool              g_isLicenseValid = false;
datetime          g_lastLicenseCheck = 0;
string            g_customerName = "";
string            g_packageType = "";
int               g_daysRemaining = 0;
bool              g_isLifetime = false;

//+------------------------------------------------------------------+
//| Check if running in tester (skip license for MQL5 Market)        |
//+------------------------------------------------------------------+
bool IsTestMode()
{
   return (MQLInfoInteger(MQL_TESTER) || 
           MQLInfoInteger(MQL_OPTIMIZATION) ||
           MQLInfoInteger(MQL_VISUAL_MODE));
}

//+------------------------------------------------------------------+
//| Verify License with Server                                        |
//+------------------------------------------------------------------+
ENUM_LICENSE_STATUS VerifyLicense()
{
   // Skip in tester mode for MQL5 Market approval
   if(IsTestMode())
   {
      g_isLicenseValid = true;
      g_licenseStatus = LICENSE_VALID;
      return LICENSE_VALID;
   }
   
   string accountNumber = IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
   string url = LICENSE_BASE_URL + "/functions/v1/verify-license";
   
   // Build JSON request
   string jsonBody = "{\\"account_number\\":\\"" + accountNumber + "\\"}";
   
   // Setup request
   char post[];
   char result[];
   string resultHeaders;
   string headers = "Content-Type: application/json\\r\\nx-api-key: " + EA_API_SECRET + "\\r\\n";
   
   StringToCharArray(jsonBody, post, 0, StringLen(jsonBody), CP_UTF8);
   ArrayResize(post, ArraySize(post) - 1);
   
   ResetLastError();
   int res = WebRequest("POST", url, headers, 10000, post, result, resultHeaders);
   
   if(res == -1)
   {
      int error = GetLastError();
      if(error == 4060)
      {
         Print("[License] ERROR: WebRequest disabled. Please enable in Tools > Options > Expert Advisors");
      }
      else if(error == 4024)
      {
         Print("[License] ERROR: Please add ", LICENSE_BASE_URL, " to allowed URLs");
         Print("[License] Go to: Tools > Options > Expert Advisors > Allow WebRequest for listed URL");
      }
      return LICENSE_ERROR;
   }
   
   string response = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
   
   // Parse response
   if(StringFind(response, "\\"valid\\":true") >= 0)
   {
      g_isLicenseValid = true;
      g_customerName = ExtractJsonString(response, "customer_name");
      g_packageType = ExtractJsonString(response, "package_type");
      g_daysRemaining = ExtractJsonInt(response, "days_remaining");
      g_isLifetime = (StringFind(response, "\\"is_lifetime\\":true") >= 0);
      
      g_lastLicenseCheck = TimeCurrent();
      
      if(g_daysRemaining > 0 && g_daysRemaining <= 7)
      {
         g_licenseStatus = LICENSE_EXPIRING_SOON;
         return LICENSE_EXPIRING_SOON;
      }
      
      g_licenseStatus = LICENSE_VALID;
      return LICENSE_VALID;
   }
   else
   {
      g_isLicenseValid = false;
      
      if(StringFind(response, "not found") >= 0)
      {
         g_licenseStatus = LICENSE_NOT_FOUND;
         return LICENSE_NOT_FOUND;
      }
      if(StringFind(response, "expired") >= 0)
      {
         g_licenseStatus = LICENSE_EXPIRED;
         return LICENSE_EXPIRED;
      }
      if(StringFind(response, "suspended") >= 0)
      {
         g_licenseStatus = LICENSE_SUSPENDED;
         return LICENSE_SUSPENDED;
      }
      
      g_licenseStatus = LICENSE_ERROR;
      return LICENSE_ERROR;
   }
}

//+------------------------------------------------------------------+
//| Show License Status Popup                                         |
//+------------------------------------------------------------------+
void ShowLicensePopup(ENUM_LICENSE_STATUS status)
{
   string title = "${systemName} - License";
   string message = "";
   int icon = MB_ICONINFORMATION;
   
   switch(status)
   {
      case LICENSE_VALID:
         if(g_isLifetime)
            message = "✅ License Activated!\\n\\nCustomer: " + g_customerName + 
                     "\\nPackage: " + g_packageType + 
                     "\\nLicense: LIFETIME\\n\\nThank you!";
         else
            message = "✅ License Activated!\\n\\nCustomer: " + g_customerName + 
                     "\\nPackage: " + g_packageType + 
                     "\\nDays Remaining: " + IntegerToString(g_daysRemaining);
         break;
         
      case LICENSE_EXPIRING_SOON:
         message = "⚠️ License Expiring Soon!\\n\\nDays Remaining: " + 
                  IntegerToString(g_daysRemaining) + "\\n\\nPlease renew your license.";
         icon = MB_ICONWARNING;
         break;
         
      case LICENSE_EXPIRED:
         message = "❌ License Expired!\\n\\nAccount: " + 
                  IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + 
                  "\\n\\nPlease contact support to renew.";
         icon = MB_ICONERROR;
         break;
         
      case LICENSE_NOT_FOUND:
         message = "❌ Account Not Registered!\\n\\nAccount: " + 
                  IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + 
                  "\\n\\nPlease contact support.";
         icon = MB_ICONERROR;
         break;
         
      case LICENSE_SUSPENDED:
         message = "❌ License Suspended!\\n\\nAccount: " + 
                  IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + 
                  "\\n\\nPlease contact support.";
         icon = MB_ICONERROR;
         break;
         
      case LICENSE_ERROR:
         message = "⚠️ Connection Error!\\n\\nPlease check internet connection.\\n" +
                  "Make sure " + LICENSE_BASE_URL + " is in allowed URLs.";
         icon = MB_ICONWARNING;
         break;
   }
   
   MessageBox(message, title, icon | MB_OK);
}

//+------------------------------------------------------------------+
//| Initialize License (call in OnInit)                               |
//+------------------------------------------------------------------+
bool InitLicense()
{
   // Skip in tester mode
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

//+------------------------------------------------------------------+
//| Check License Periodically (call in OnTick)                       |
//+------------------------------------------------------------------+
bool CheckLicenseTick()
{
   if(IsTestMode()) return true;
   
   datetime now = TimeCurrent();
   
   // Check license every LICENSE_CHECK_HOURS
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
}`;

  // === NEWS FILTER CODE ===
  const newsFilterCode = `//+------------------------------------------------------------------+
//|                              News Filter for ${systemName}
//|                                  Version ${version}
//+------------------------------------------------------------------+

// ===== NEWS FILTER CONFIGURATION =====
#define NEWS_REFRESH_HOURS   1    // Refresh news every 1 hour
#define NEWS_RETRY_MINUTES   5    // Retry after error every 5 minutes
#define NEWS_MAX_EVENTS      100  // Maximum news events to store

// News Event Structure
struct SNewsEvent
{
   datetime  eventTime;      // Event time (server time)
   string    title;          // Event title
   string    currency;       // Currency affected
   int       impactLevel;    // 1=Low, 2=Medium, 3=High, 4=Holiday
   datetime  pauseStart;     // Pause window start
   datetime  pauseEnd;       // Pause window end
};

// Global news filter variables
SNewsEvent   g_newsEvents[];
int          g_newsEventCount = 0;
datetime     g_lastNewsRefresh = 0;
bool         g_newsFilterEnabled = true;
bool         g_forceNewsRefresh = true;  // Force refresh on init
string       g_currentNewsTitle = "";
datetime     g_currentPauseEnd = 0;
bool         g_isTradingPaused = false;

// News Filter Inputs (add to EA inputs section)
// input group "=== News Filter Settings ==="
// input bool     InpEnableNewsFilter = true;    // Enable News Filter
// input bool     InpFilterHighImpact = true;    // Filter High Impact News
// input bool     InpFilterMediumImpact = false; // Filter Medium Impact News
// input bool     InpFilterLowImpact = false;    // Filter Low Impact News
// input int      InpPauseBeforeHigh = 60;       // Pause Before High (minutes)
// input int      InpPauseAfterHigh = 60;        // Pause After High (minutes)
// input int      InpPauseBeforeMedium = 30;     // Pause Before Medium (minutes)
// input int      InpPauseAfterMedium = 30;      // Pause After Medium (minutes)

// Default values (replace with inputs in actual EA)
bool     InpEnableNewsFilter = true;
bool     InpFilterHighImpact = true;
bool     InpFilterMediumImpact = false;
bool     InpFilterLowImpact = false;
int      InpPauseBeforeHigh = 60;
int      InpPauseAfterHigh = 60;
int      InpPauseBeforeMedium = 30;
int      InpPauseAfterMedium = 30;

//+------------------------------------------------------------------+
//| Initialize News Filter (call in OnInit)                           |
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

//+------------------------------------------------------------------+
//| Refresh News Data from Server                                     |
//+------------------------------------------------------------------+
bool RefreshNewsData()
{
   if(IsTestMode()) return true;
   
   string url = LICENSE_BASE_URL + "/functions/v1/economic-news?format=ea&days=3";
   
   char post[];
   char result[];
   string resultHeaders;
   string headers = "Content-Type: application/json\\r\\n";
   
   ResetLastError();
   int res = WebRequest("GET", url, headers, 10000, post, result, resultHeaders);
   
   if(res == -1)
   {
      int error = GetLastError();
      if(error == 4060 || error == 4024)
      {
         Print("[NewsFilter] ERROR: Please add ", LICENSE_BASE_URL, " to allowed URLs");
      }
      return false;
   }
   
   if(res != 200)
   {
      Print("[NewsFilter] HTTP Error: ", res);
      return false;
   }
   
   string response = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
   
   // Check for success
   if(StringFind(response, "\\"success\\":true") < 0)
   {
      Print("[NewsFilter] Invalid response from server");
      return false;
   }
   
   // Parse news events
   return ParseNewsResponse(response);
}

//+------------------------------------------------------------------+
//| Parse News JSON Response                                          |
//+------------------------------------------------------------------+
bool ParseNewsResponse(string json)
{
   // Reset event count
   g_newsEventCount = 0;
   
   // Find data array
   int dataStart = StringFind(json, "\\"data\\":[");
   if(dataStart < 0)
   {
      // Empty data array is valid (no news)
      if(StringFind(json, "\\"data\\":[]") >= 0)
      {
         Print("[NewsFilter] No news events found (OK)");
         return true;
      }
      return false;
   }
   
   // Parse each event
   int searchPos = dataStart;
   while(g_newsEventCount < NEWS_MAX_EVENTS)
   {
      int eventStart = StringFind(json, "{", searchPos + 1);
      if(eventStart < 0) break;
      
      int eventEnd = StringFind(json, "}", eventStart);
      if(eventEnd < 0) break;
      
      // Check if we've reached end of data array
      int arrayEnd = StringFind(json, "]", dataStart);
      if(arrayEnd > 0 && eventStart > arrayEnd) break;
      
      string eventJson = StringSubstr(json, eventStart, eventEnd - eventStart + 1);
      
      // Parse timestamp
      string timestamp = ExtractJsonString(eventJson, "timestamp");
      if(StringLen(timestamp) == 0)
      {
         searchPos = eventEnd;
         continue;
      }
      
      // Parse fields
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

//+------------------------------------------------------------------+
//| Parse ISO DateTime String to datetime                             |
//+------------------------------------------------------------------+
datetime ParseISODateTime(string isoStr)
{
   // Format: 2024-01-15T14:30:00Z
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
   
   // Convert to server time
   int serverOffset = (int)(TimeCurrent() - TimeGMT());
   return utcTime + serverOffset;
}

//+------------------------------------------------------------------+
//| Check if Trading Should be Paused for News                        |
//+------------------------------------------------------------------+
bool CheckNewsFilter()
{
   if(!InpEnableNewsFilter) return true;  // Not paused, can trade
   if(IsTestMode()) return true;
   
   datetime now = TimeCurrent();
   
   // Refresh news data if needed
   bool needRefresh = g_forceNewsRefresh || 
                      (now - g_lastNewsRefresh >= NEWS_REFRESH_HOURS * 3600);
   
   if(needRefresh)
   {
      if(RefreshNewsData())
      {
         g_lastNewsRefresh = now;
         g_forceNewsRefresh = false;
      }
      else
      {
         // On error, wait before retry
         if(g_lastNewsRefresh == 0)
            g_lastNewsRefresh = now - (NEWS_REFRESH_HOURS * 3600) + (NEWS_RETRY_MINUTES * 60);
      }
   }
   
   // Check each event for pause window
   g_isTradingPaused = false;
   g_currentNewsTitle = "";
   g_currentPauseEnd = 0;
   
   for(int i = 0; i < g_newsEventCount; i++)
   {
      if(!IsEventRelevant(g_newsEvents[i].impactLevel)) continue;
      
      // Calculate pause window
      int pauseBefore = GetPauseBeforeMinutes(g_newsEvents[i].impactLevel);
      int pauseAfter = GetPauseAfterMinutes(g_newsEvents[i].impactLevel);
      
      datetime pauseStart = g_newsEvents[i].eventTime - pauseBefore * 60;
      datetime pauseEnd = g_newsEvents[i].eventTime + pauseAfter * 60;
      
      // Check if we're in the pause window
      if(now >= pauseStart && now <= pauseEnd)
      {
         g_isTradingPaused = true;
         g_currentNewsTitle = g_newsEvents[i].title;
         
         // Keep earliest pause end time
         if(g_currentPauseEnd == 0 || pauseEnd < g_currentPauseEnd)
            g_currentPauseEnd = pauseEnd;
      }
   }
   
   return !g_isTradingPaused;  // Return true if NOT paused
}

//+------------------------------------------------------------------+
//| Check if Event Impact Level is Relevant                           |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| Get Pause Before Minutes for Impact Level                         |
//+------------------------------------------------------------------+
int GetPauseBeforeMinutes(int impactLevel)
{
   switch(impactLevel)
   {
      case 3: return InpPauseBeforeHigh;
      case 2: return InpPauseBeforeMedium;
      case 1: return 15;  // Default for low
      default: return 0;
   }
}

//+------------------------------------------------------------------+
//| Get Pause After Minutes for Impact Level                          |
//+------------------------------------------------------------------+
int GetPauseAfterMinutes(int impactLevel)
{
   switch(impactLevel)
   {
      case 3: return InpPauseAfterHigh;
      case 2: return InpPauseAfterMedium;
      case 1: return 15;  // Default for low
      default: return 0;
   }
}

//+------------------------------------------------------------------+
//| Get News Status String for Dashboard                              |
//+------------------------------------------------------------------+
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
         return StringFormat("PAUSE: %s (%02d:%02d:%02d)", 
                            g_currentNewsTitle, hours, mins, secs);
      }
   }
   
   return "No Important News";
}`;

  // === DATA SYNC CODE ===
  const dataSyncCode = `//+------------------------------------------------------------------+
//|                              Data Sync for ${systemName}
//|                                  Version ${version}
//+------------------------------------------------------------------+

// ===== SYNC CONFIGURATION =====
#define SYNC_INTERVAL_MIN    5     // Sync account data every 5 minutes
#define SYNC_DAILY_HOUR_1    5     // Daily sync at 05:00
#define SYNC_DAILY_HOUR_2    23    // Daily sync at 23:00
#define TRADE_HISTORY_COUNT  100   // Last 100 trades to sync

// Global sync variables
datetime g_lastDataSync = 0;
int      g_lastSyncHour = -1;
string   g_eaStatus = "working";   // working, paused, suspended, expired, invalid

//+------------------------------------------------------------------+
//| Sync Account Data to Server                                       |
//+------------------------------------------------------------------+
bool SyncAccountData(string eventType = "scheduled")
{
   if(IsTestMode()) return true;
   if(!g_isLicenseValid) return false;
   
   string accountNumber = IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
   string url = LICENSE_BASE_URL + "/functions/v1/sync-account-data";
   
   // Collect account metrics
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   double profitLoss = AccountInfoDouble(ACCOUNT_PROFIT);
   
   // Calculate drawdown
   double drawdown = 0;
   if(balance > 0)
   {
      drawdown = ((balance - equity) / balance) * 100;
      if(drawdown < 0) drawdown = 0;
   }
   
   // Count open orders and floating P/L
   int openOrders = PositionsTotal();
   double floatingPL = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
         floatingPL += PositionGetDouble(POSITION_PROFIT);
   }
   
   // Calculate total profit from history
   double totalProfit = CalculateTotalProfit();
   
   // Get trade statistics
   int totalTrades = 0, winTrades = 0, lossTrades = 0;
   CalculateTradeStats(totalTrades, winTrades, lossTrades);
   
   // Build trade history JSON
   string tradeHistoryJson = BuildTradeHistoryJson();
   
   // Build JSON payload
   string json = "{";
   json += "\\"account_number\\":\\"" + accountNumber + "\\",";
   json += "\\"balance\\":" + DoubleToString(balance, 2) + ",";
   json += "\\"equity\\":" + DoubleToString(equity, 2) + ",";
   json += "\\"margin_level\\":" + DoubleToString(marginLevel, 2) + ",";
   json += "\\"drawdown\\":" + DoubleToString(drawdown, 2) + ",";
   json += "\\"profit_loss\\":" + DoubleToString(profitLoss, 2) + ",";
   json += "\\"open_orders\\":" + IntegerToString(openOrders) + ",";
   json += "\\"floating_pl\\":" + DoubleToString(floatingPL, 2) + ",";
   json += "\\"total_profit\\":" + DoubleToString(totalProfit, 2) + ",";
   json += "\\"total_trades\\":" + IntegerToString(totalTrades) + ",";
   json += "\\"win_trades\\":" + IntegerToString(winTrades) + ",";
   json += "\\"loss_trades\\":" + IntegerToString(lossTrades) + ",";
   json += "\\"ea_status\\":\\"" + g_eaStatus + "\\",";
   json += "\\"event_type\\":\\"" + eventType + "\\",";
   json += "\\"trade_history\\":" + tradeHistoryJson;
   json += "}";
   
   // Send request
   char post[];
   char result[];
   string resultHeaders;
   string headers = "Content-Type: application/json\\r\\nx-api-key: " + EA_API_SECRET + "\\r\\n";
   
   StringToCharArray(json, post, 0, StringLen(json), CP_UTF8);
   ArrayResize(post, ArraySize(post) - 1);
   
   int res = WebRequest("POST", url, headers, 15000, post, result, resultHeaders);
   
   if(res == 200)
   {
      g_lastDataSync = TimeCurrent();
      Print("[Sync] Account data synced - Event: ", eventType, 
            " | Balance: ", DoubleToString(balance, 2),
            " | Equity: ", DoubleToString(equity, 2));
      return true;
   }
   
   Print("[Sync] Failed to sync. HTTP: ", res);
   return false;
}

//+------------------------------------------------------------------+
//| Build Trade History JSON Array                                    |
//+------------------------------------------------------------------+
string BuildTradeHistoryJson()
{
   string json = "[";
   bool first = true;
   
   // Select history for all time
   if(!HistorySelect(0, TimeCurrent()))
      return "[]";
   
   int totalDeals = HistoryDealsTotal();
   int startIndex = MathMax(0, totalDeals - TRADE_HISTORY_COUNT);
   
   for(int i = startIndex; i < totalDeals; i++)
   {
      ulong ticket = HistoryDealGetTicket(i);
      if(ticket == 0) continue;
      
      // Get deal properties
      long dealType = HistoryDealGetInteger(ticket, DEAL_TYPE);
      long entryType = HistoryDealGetInteger(ticket, DEAL_ENTRY);
      
      // Only include actual trades (not balance operations)
      if(dealType != DEAL_TYPE_BUY && dealType != DEAL_TYPE_SELL) continue;
      
      if(!first) json += ",";
      first = false;
      
      json += "{";
      json += "\\"deal_ticket\\":" + IntegerToString(ticket) + ",";
      json += "\\"order_ticket\\":" + IntegerToString(HistoryDealGetInteger(ticket, DEAL_ORDER)) + ",";
      json += "\\"symbol\\":\\"" + HistoryDealGetString(ticket, DEAL_SYMBOL) + "\\",";
      json += "\\"deal_type\\":\\"" + (dealType == DEAL_TYPE_BUY ? "BUY" : "SELL") + "\\",";
      json += "\\"entry_type\\":\\"" + GetEntryTypeString(entryType) + "\\",";
      json += "\\"volume\\":" + DoubleToString(HistoryDealGetDouble(ticket, DEAL_VOLUME), 2) + ",";
      json += "\\"open_price\\":" + DoubleToString(HistoryDealGetDouble(ticket, DEAL_PRICE), 5) + ",";
      json += "\\"profit\\":" + DoubleToString(HistoryDealGetDouble(ticket, DEAL_PROFIT), 2) + ",";
      json += "\\"commission\\":" + DoubleToString(HistoryDealGetDouble(ticket, DEAL_COMMISSION), 2) + ",";
      json += "\\"swap\\":" + DoubleToString(HistoryDealGetDouble(ticket, DEAL_SWAP), 2) + ",";
      json += "\\"magic_number\\":" + IntegerToString(HistoryDealGetInteger(ticket, DEAL_MAGIC)) + ",";
      json += "\\"comment\\":\\"" + HistoryDealGetString(ticket, DEAL_COMMENT) + "\\",";
      json += "\\"close_time\\":\\"" + TimeToString(HistoryDealGetInteger(ticket, DEAL_TIME), TIME_DATE|TIME_SECONDS) + "\\"";
      json += "}";
   }
   
   json += "]";
   return json;
}

//+------------------------------------------------------------------+
//| Get Entry Type String                                             |
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

//+------------------------------------------------------------------+
//| Calculate Total Profit from History                               |
//+------------------------------------------------------------------+
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

//+------------------------------------------------------------------+
//| Calculate Trade Statistics                                        |
//+------------------------------------------------------------------+
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
      
      // Count only closed trades
      if((dealType == DEAL_TYPE_BUY || dealType == DEAL_TYPE_SELL) && entryType == DEAL_ENTRY_OUT)
      {
         total++;
         double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
         if(profit >= 0) wins++;
         else losses++;
      }
   }
}

//+------------------------------------------------------------------+
//| Sync on Trade Event (call in OnTradeTransaction)                  |
//+------------------------------------------------------------------+
void OnTradeSync(const MqlTradeTransaction& trans)
{
   if(IsTestMode()) return;
   if(!g_isLicenseValid) return;
   
   // Sync on order open/close
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD ||
      trans.type == TRADE_TRANSACTION_HISTORY_ADD)
   {
      Sleep(200);  // Let the deal settle
      SyncAccountData("trade");
   }
}

//+------------------------------------------------------------------+
//| Scheduled Sync Check (call in OnTick)                             |
//+------------------------------------------------------------------+
void CheckScheduledSync()
{
   if(IsTestMode()) return;
   if(!g_isLicenseValid) return;
   
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   
   // Sync every SYNC_INTERVAL_MIN minutes
   if(now - g_lastDataSync >= SYNC_INTERVAL_MIN * 60)
   {
      SyncAccountData("scheduled");
   }
   
   // Also sync at daily times
   if((dt.hour == SYNC_DAILY_HOUR_1 || dt.hour == SYNC_DAILY_HOUR_2) && g_lastSyncHour != dt.hour)
   {
      SyncAccountData("daily");
      g_lastSyncHour = dt.hour;
   }
}`;

  // === HELPER FUNCTIONS ===
  const helperFunctionsCode = `//+------------------------------------------------------------------+
//|                           Helper Functions for ${systemName}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Extract string value from JSON                                    |
//+------------------------------------------------------------------+
string ExtractJsonString(string json, string key)
{
   string searchKey = "\\"" + key + "\\":\\"";
   int startPos = StringFind(json, searchKey);
   if(startPos < 0) return "";
   
   startPos += StringLen(searchKey);
   int endPos = StringFind(json, "\\"", startPos);
   if(endPos < 0) return "";
   
   return StringSubstr(json, startPos, endPos - startPos);
}

//+------------------------------------------------------------------+
//| Extract integer value from JSON                                   |
//+------------------------------------------------------------------+
int ExtractJsonInt(string json, string key)
{
   // Try string format first: "key":"value"
   string strVal = ExtractJsonString(json, key);
   if(StringLen(strVal) > 0)
      return (int)StringToInteger(strVal);
   
   // Try number format: "key":value
   string searchKey = "\\"" + key + "\\":";
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

//+------------------------------------------------------------------+
//| Extract double value from JSON                                    |
//+------------------------------------------------------------------+
double ExtractJsonDouble(string json, string key)
{
   string searchKey = "\\"" + key + "\\":";
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

//+------------------------------------------------------------------+
//| Extract boolean value from JSON                                   |
//+------------------------------------------------------------------+
bool ExtractJsonBool(string json, string key)
{
   string searchKey = "\\"" + key + "\\":true";
   return (StringFind(json, searchKey) >= 0);
}`;

  // === EA TEMPLATE ===
  const eaTemplateCode = `//+------------------------------------------------------------------+
//|                                          ${fileNameMq5}
//|                                     ${systemName} v${version}
//|                                     ${description || 'Trading System'}
//+------------------------------------------------------------------+
#property copyright "MoneyX Trading"
#property link      ""
#property version   "${version}"
#property strict

#include <Trade/Trade.mqh>

// ===== EA INPUTS =====
input group "=== Trading Settings ==="
input double   InpLotSize = 0.01;         // Lot Size
input int      InpStopLoss = 100;         // Stop Loss (points)
input int      InpTakeProfit = 200;       // Take Profit (points)
input int      InpMagicNumber = ${Math.floor(Math.random() * 900000) + 100000};   // Magic Number

input group "=== Time Filter ==="
input bool     InpUseTimeFilter = false;  // Use Time Filter
input int      InpStartHour = 8;          // Start Hour
input int      InpEndHour = 20;           // End Hour

input group "=== News Filter Settings ==="
input bool     Inp_EnableNewsFilter = true;    // Enable News Filter
input bool     Inp_FilterHighImpact = true;    // Filter High Impact News
input bool     Inp_FilterMediumImpact = false; // Filter Medium Impact News
input bool     Inp_FilterLowImpact = false;    // Filter Low Impact News
input int      Inp_PauseBeforeHigh = 60;       // Pause Before High (minutes)
input int      Inp_PauseAfterHigh = 60;        // Pause After High (minutes)
input int      Inp_PauseBeforeMedium = 30;     // Pause Before Medium (minutes)
input int      Inp_PauseAfterMedium = 30;      // Pause After Medium (minutes)

// ===== GLOBAL VARIABLES =====
CTrade trade;

//+------------------------------------------------------------------+
// === PASTE ALL MODULE CODE SECTIONS BELOW ===
// 1. HELPER FUNCTIONS
// 2. LICENSE MANAGER
// 3. DATA SYNC
// 4. NEWS FILTER
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize License (required)
   if(!InitLicense())
   {
      Print("[${systemName}] License verification failed!");
      // Allow to load but disable trading
      g_isLicenseValid = false;
   }
   
   // Initialize News Filter
   InitNewsFilter();
   
   // Override news filter inputs
   InpEnableNewsFilter = Inp_EnableNewsFilter;
   InpFilterHighImpact = Inp_FilterHighImpact;
   InpFilterMediumImpact = Inp_FilterMediumImpact;
   InpFilterLowImpact = Inp_FilterLowImpact;
   InpPauseBeforeHigh = Inp_PauseBeforeHigh;
   InpPauseAfterHigh = Inp_PauseAfterHigh;
   InpPauseBeforeMedium = Inp_PauseBeforeMedium;
   InpPauseAfterMedium = Inp_PauseAfterMedium;
   
   // Setup trade
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(10);
   
   Print("[${systemName}] EA initialized successfully!");
   Print("[${systemName}] Account: ", AccountInfoInteger(ACCOUNT_LOGIN));
   
   // Initial sync
   SyncAccountData("init");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Print("[${systemName}] EA deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   // Check license on each tick
   if(!CheckLicenseTick())
   {
      g_eaStatus = "invalid";
      return;
   }
   
   // Check scheduled sync
   CheckScheduledSync();
   
   // Check News Filter
   bool canTrade = CheckNewsFilter();
   
   // Time filter
   if(InpUseTimeFilter && !IsTradeTime())
      canTrade = false;
   
   // Update EA status
   if(g_isTradingPaused)
      g_eaStatus = "paused";
   else
      g_eaStatus = "working";
   
   // === TRADING LOGIC ===
   if(!canTrade)
   {
      // Still manage existing positions (TP/SL/etc)
      ManagePositions();
      return;
   }
   
   // === YOUR ENTRY LOGIC HERE ===
   
}

//+------------------------------------------------------------------+
//| Trade transaction handler                                         |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   // Sync on trade events
   OnTradeSync(trans);
}

//+------------------------------------------------------------------+
//| Check if within trading hours                                     |
//+------------------------------------------------------------------+
bool IsTradeTime()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   return (dt.hour >= InpStartHour && dt.hour < InpEndHour);
}

//+------------------------------------------------------------------+
//| Manage Existing Positions (always active)                         |
//+------------------------------------------------------------------+
void ManagePositions()
{
   // === YOUR POSITION MANAGEMENT LOGIC HERE ===
   // This runs even during news pause
   // Handle: TP/SL adjustments, trailing stops, partial closes, etc.
}

//+------------------------------------------------------------------+
//| END OF EA TEMPLATE                                                |
//+------------------------------------------------------------------+`;

  // Full combined code
  const fullCode = `${eaTemplateCode}

// =====================================================
// ===== HELPER FUNCTIONS (INCLUDE FIRST) ==============
// =====================================================
${helperFunctionsCode}

// =====================================================
// ===== LICENSE MANAGER CODE ==========================
// =====================================================
${licenseManagerCode}

// =====================================================
// ===== DATA SYNC CODE ================================
// =====================================================
${dataSyncCode}

// =====================================================
// ===== NEWS FILTER CODE ==============================
// =====================================================
${newsFilterCode}`;

  return (
    <Card>
      <CardHeader>
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="p-3 rounded-xl bg-cyan-500/20">
              <FileCode className="w-6 h-6 text-cyan-400" />
            </div>
            <div>
              <CardTitle>{systemName}</CardTitle>
              <CardDescription>{description || 'Trading System'}</CardDescription>
            </div>
          </div>
          <Badge>v{version}</Badge>
        </div>
      </CardHeader>
      <CardContent className="space-y-4">
        <div className="flex flex-wrap gap-2">
          <Badge variant="outline">License Manager</Badge>
          <Badge variant="outline">News Filter</Badge>
          <Badge variant="outline">Data Sync</Badge>
          <Badge variant="outline">Trade History</Badge>
          <Badge variant="outline">Account Metrics</Badge>
        </div>
        
        <Tabs defaultValue="template" className="w-full">
          <TabsList className="grid w-full grid-cols-5">
            <TabsTrigger value="template">EA Template</TabsTrigger>
            <TabsTrigger value="license">License</TabsTrigger>
            <TabsTrigger value="news">News Filter</TabsTrigger>
            <TabsTrigger value="sync">Data Sync</TabsTrigger>
            <TabsTrigger value="helpers">Helpers</TabsTrigger>
          </TabsList>
          
          <TabsContent value="template" className="space-y-3">
            <CodeBlock 
              language="mql5" 
              code={eaTemplateCode} 
              filename={fileNameMq5}
            />
            <div className="flex gap-2">
              <Button 
                variant="outline"
                className="flex-1"
                onClick={() => handleDownload(fullCode, fileNameMq5)}
              >
                <Download className="w-4 h-4 mr-2" />
                Download Full EA
              </Button>
              <Button 
                variant="outline"
                onClick={() => handleCopy(eaTemplateCode, 'template')}
              >
                {copiedSection === 'template' ? <Check className="w-4 h-4" /> : <Copy className="w-4 h-4" />}
              </Button>
            </div>
          </TabsContent>
          
          <TabsContent value="license" className="space-y-3">
            <CodeBlock 
              language="mql5" 
              code={licenseManagerCode} 
              filename="LicenseManager.mqh"
            />
            <Button 
              variant="outline"
              className="w-full"
              onClick={() => handleCopy(licenseManagerCode, 'license')}
            >
              {copiedSection === 'license' ? <Check className="w-4 h-4 mr-2" /> : <Copy className="w-4 h-4 mr-2" />}
              Copy License Code
            </Button>
          </TabsContent>
          
          <TabsContent value="news" className="space-y-3">
            <CodeBlock 
              language="mql5" 
              code={newsFilterCode} 
              filename="NewsFilter.mqh"
            />
            <Button 
              variant="outline"
              className="w-full"
              onClick={() => handleCopy(newsFilterCode, 'news')}
            >
              {copiedSection === 'news' ? <Check className="w-4 h-4 mr-2" /> : <Copy className="w-4 h-4 mr-2" />}
              Copy News Filter Code
            </Button>
          </TabsContent>
          
          <TabsContent value="sync" className="space-y-3">
            <CodeBlock 
              language="mql5" 
              code={dataSyncCode} 
              filename="DataSync.mqh"
            />
            <Button 
              variant="outline"
              className="w-full"
              onClick={() => handleCopy(dataSyncCode, 'sync')}
            >
              {copiedSection === 'sync' ? <Check className="w-4 h-4 mr-2" /> : <Copy className="w-4 h-4 mr-2" />}
              Copy Sync Code
            </Button>
          </TabsContent>
          
          <TabsContent value="helpers" className="space-y-3">
            <CodeBlock 
              language="mql5" 
              code={helperFunctionsCode} 
              filename="Helpers.mqh"
            />
            <Button 
              variant="outline"
              className="w-full"
              onClick={() => handleCopy(helperFunctionsCode, 'helpers')}
            >
              {copiedSection === 'helpers' ? <Check className="w-4 h-4 mr-2" /> : <Copy className="w-4 h-4 mr-2" />}
              Copy Helper Functions
            </Button>
          </TabsContent>
        </Tabs>
      </CardContent>
    </Card>
  );
};

export default MQL5CodeTemplate;
