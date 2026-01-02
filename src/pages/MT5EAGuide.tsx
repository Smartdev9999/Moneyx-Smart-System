import { Link } from 'react-router-dom';
import { ArrowLeft, Settings, TrendingUp, Shield, AlertTriangle, Download, FileCode, Info, Zap, Clock, RefreshCw } from 'lucide-react';
import CodeBlock from '@/components/CodeBlock';

const MT5EAGuide = () => {
  const fullEACode = `//+------------------------------------------------------------------+
//|                                  Moneyx_Smart_Gold_EA_Licensed.mq5 |
//|                                   Copyright 2024, Moneyx Smart     |
//|                                   https://moneyx-smart.com         |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Moneyx Smart System"
#property link      "https://moneyx-smart.com"
#property version   "5.2"
#property description "Moneyx Smart Gold EA with License Verification"
#property description "Free to backtest - License required for live trading"
#property description "v5.2: Real-time sync on order events + Trade History"

//+------------------------------------------------------------------+
//| Input Parameters                                                   |
//+------------------------------------------------------------------+
input group "=== License Settings ==="
input string   InpLicenseServer = "https://lkbhomsulgycxawwlnfh.supabase.co";  // License Server URL
input int      InpLicenseCheckMinutes = 60;    // License Check Interval (minutes)
input int      InpDataSyncMinutes = 5;         // Account Data Sync Interval (minutes)

// ====== HARDCODED API SECRET - DO NOT MODIFY ======
const string EA_API_SECRET = "moneyx-ea-secret-2024-secure-key-v1";

input group "=== Trading Settings ==="
input double   InpLotSize = 0.01;              // Lot Size
input int      InpMagicNumber = 123456;        // Magic Number
// เพิ่ม input parameters สำหรับ trading ของคุณที่นี่

//+------------------------------------------------------------------+
//| License Status Enumeration                                         |
//+------------------------------------------------------------------+
enum ENUM_LICENSE_STATUS
{
   LICENSE_VALID,           // License ถูกต้อง
   LICENSE_EXPIRING_SOON,   // License ใกล้หมดอายุ (ภายใน 7 วัน)
   LICENSE_EXPIRED,         // License หมดอายุแล้ว
   LICENSE_NOT_FOUND,       // ไม่พบบัญชีในระบบ
   LICENSE_SUSPENDED,       // License ถูกระงับ
   LICENSE_ERROR            // เกิดข้อผิดพลาดในการเชื่อมต่อ
};

//+------------------------------------------------------------------+
//| Sync Event Type Enumeration                                        |
//+------------------------------------------------------------------+
enum ENUM_SYNC_EVENT
{
   SYNC_SCHEDULED,          // Scheduled sync (05:00, 23:00)
   SYNC_ORDER_OPEN,         // Order opened
   SYNC_ORDER_CLOSE         // Order closed
};

//+------------------------------------------------------------------+
//| Global Variables                                                   |
//+------------------------------------------------------------------+
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
string            g_lastError = "";
datetime          g_lastLicenseCheck = 0;
datetime          g_lastDataSync = 0;
datetime          g_lastExpiryPopup = 0;
string            g_licenseServerUrl = "";
int               g_licenseCheckInterval = 60;
int               g_dataSyncInterval = 5;

// Trading Variables
int               g_magicNumber = 0;

// Order tracking for event-driven sync
int               g_lastOrderCount = 0;
bool              g_pendingSyncOnOrderEvent = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   g_magicNumber = InpMagicNumber;
   
   // ตรวจสอบว่าอยู่ใน Tester Mode หรือไม่
   g_isTesterMode = IsTesterMode();
   
   if(g_isTesterMode)
   {
      // Backtest/Optimization Mode - ข้าม License Check
      Print("╔══════════════════════════════════════════════════════════════╗");
      Print("║         MONEYX SMART GOLD EA v5.2 - TESTER MODE              ║");
      Print("║         License check skipped for backtesting                ║");
      Print("╚══════════════════════════════════════════════════════════════╝");
      g_isLicenseValid = true;
      g_licenseStatus = LICENSE_VALID;
      return INIT_SUCCEEDED;
   }
   
   // Live Trading Mode - ต้องตรวจ License
   Print("╔══════════════════════════════════════════════════════════════╗");
   Print("║         MONEYX SMART GOLD EA v5.2 - LIVE TRADING MODE        ║");
   Print("║         Real-time sync enabled                               ║");
   Print("║         Verifying license...                                  ║");
   Print("╚══════════════════════════════════════════════════════════════╝");
   
   // Initialize License System
   if(!InitLicense(InpLicenseServer, InpLicenseCheckMinutes, InpDataSyncMinutes))
   {
      Print("License initialization failed: ", g_lastError);
      // ยังคง return INIT_SUCCEEDED เพื่อให้ EA ติดบน chart
      // แต่จะไม่ทำการเทรดเพราะ g_isLicenseValid = false
   }
   
   // แสดง Popup ตามสถานะ License
   ShowLicensePopup(g_licenseStatus);
   
   // Print license info
   if(g_isLicenseValid)
   {
      Print("License Valid - Customer: ", g_customerName);
      Print("Package: ", g_packageType, " | System: ", g_tradingSystem);
      if(g_isLifetime)
         Print("License Type: LIFETIME");
      else
         Print("Expiry: ", TimeToString(g_expiryDate, TIME_DATE), " (", g_daysRemaining, " days remaining)");
   }
   
   // Initialize order count for event tracking
   g_lastOrderCount = PositionsTotal();
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Cleanup
   Print("Moneyx Smart Gold EA v5.2 deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   // ถ้าเป็น Tester Mode - ไม่ต้องเช็ค License ซ้ำ
   if(!g_isTesterMode)
   {
      // เช็ค License ตาม interval
      if(!OnTickLicense())
      {
         // License ไม่ valid - หยุดเทรด
         return;
      }
   }
   
   // ตรวจสอบอีกครั้งว่า License valid
   if(!g_isLicenseValid)
   {
      return;
   }
   
   //+------------------------------------------------------------------+
   //| YOUR TRADING LOGIC STARTS HERE                                   |
   //+------------------------------------------------------------------+
   
   // ตัวอย่าง: ใส่โค้ด trading ของคุณที่นี่
   // ExecuteTradingStrategy();
   
   //+------------------------------------------------------------------+
   //| YOUR TRADING LOGIC ENDS HERE                                     |
   //+------------------------------------------------------------------+
}

//+------------------------------------------------------------------+
//| Trade transaction function - REAL-TIME SYNC ON ORDER EVENTS        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   // Skip if in tester mode
   if(g_isTesterMode) return;
   
   // Skip if license is not valid
   if(!g_isLicenseValid) return;
   
   // Check for deal events (order opened or closed)
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      // Get deal info
      if(HistoryDealSelect(trans.deal))
      {
         ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
         
         if(dealEntry == DEAL_ENTRY_IN)
         {
            // Order opened - sync immediately
            Print("[Real-time Sync] Order opened - syncing data...");
            SyncAccountDataWithEvent(SYNC_ORDER_OPEN);
         }
         else if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_INOUT)
         {
            // Order closed - sync immediately
            Print("[Real-time Sync] Order closed - syncing data...");
            SyncAccountDataWithEvent(SYNC_ORDER_CLOSE);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Timer function                                                     |
//+------------------------------------------------------------------+
void OnTimer()
{
   // Optional: use timer for periodic tasks
}

//+------------------------------------------------------------------+
//|                                                                    |
//|              LICENSE VERIFICATION FUNCTIONS                        |
//|              (Embedded - No external include)                      |
//|                                                                    |
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
   
   // ตรวจสอบ URL
   if(StringLen(g_licenseServerUrl) == 0)
   {
      g_lastError = "License server URL is empty";
      g_licenseStatus = LICENSE_ERROR;
      return false;
   }
   
   // ตรวจสอบ License ครั้งแรก
   g_licenseStatus = VerifyLicense();
   g_lastLicenseCheck = TimeCurrent();
   
   // กำหนดผลลัพธ์
   g_isLicenseValid = (g_licenseStatus == LICENSE_VALID || g_licenseStatus == LICENSE_EXPIRING_SOON);
   
   // Sync ข้อมูลบัญชีครั้งแรก (ถ้า License valid)
   if(g_isLicenseValid)
   {
      SyncAccountDataWithEvent(SYNC_SCHEDULED);
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
   
   // สร้าง JSON request
   long accountNumber = AccountInfoInteger(ACCOUNT_LOGIN);
   string jsonRequest = "{\\"account_number\\":\\"" + IntegerToString(accountNumber) + "\\"}";
   
   // ส่ง request
   string response = "";
   int httpCode = SendLicenseRequest(url, jsonRequest, response);
   
   if(httpCode != 200)
   {
      g_lastError = "HTTP Error: " + IntegerToString(httpCode);
      return LICENSE_ERROR;
   }
   
   // Parse response
   return ParseVerifyResponse(response);
}

//+------------------------------------------------------------------+
//| Parse Verify License Response                                      |
//+------------------------------------------------------------------+
ENUM_LICENSE_STATUS ParseVerifyResponse(string response)
{
   // ตรวจสอบ valid
   bool valid = JsonGetBool(response, "valid");
   
   if(!valid)
   {
      string message = JsonGetString(response, "message");
      g_lastError = message;
      
      if(StringFind(message, "not found") >= 0 || StringFind(message, "Not found") >= 0)
         return LICENSE_NOT_FOUND;
      if(StringFind(message, "suspended") >= 0 || StringFind(message, "inactive") >= 0)
         return LICENSE_SUSPENDED;
      if(StringFind(message, "expired") >= 0 || StringFind(message, "Expired") >= 0)
         return LICENSE_EXPIRED;
      
      return LICENSE_ERROR;
   }
   
   // ดึงข้อมูลจาก response
   g_customerName = JsonGetString(response, "customer_name");
   g_packageType = JsonGetString(response, "package_type");
   g_tradingSystem = JsonGetString(response, "trading_system");
   g_daysRemaining = JsonGetInt(response, "days_remaining");
   g_isLifetime = JsonGetBool(response, "is_lifetime");
   
   // ดึง expiry date
   string expiryStr = JsonGetString(response, "expiry_date");
   if(StringLen(expiryStr) > 0 && expiryStr != "null")
   {
      // แปลง ISO date string เป็น datetime
      g_expiryDate = StringToTime(StringSubstr(expiryStr, 0, 10));
   }
   
   // ตรวจสอบ expiring soon
   if(!g_isLifetime && g_daysRemaining <= 7 && g_daysRemaining > 0)
   {
      return LICENSE_EXPIRING_SOON;
   }
   
   return LICENSE_VALID;
}

//+------------------------------------------------------------------+
//| Sync Account Data with Event Type                                  |
//+------------------------------------------------------------------+
bool SyncAccountDataWithEvent(ENUM_SYNC_EVENT eventType)
{
   string url = g_licenseServerUrl + "/functions/v1/sync-account-data";
   
   // สร้าง JSON request พร้อม event type
   string jsonRequest = BuildSyncJsonWithEvent(eventType);
   
   // ส่ง request
   string response = "";
   int httpCode = SendLicenseRequest(url, jsonRequest, response);
   
   if(httpCode != 200)
   {
      g_lastError = "Sync HTTP Error: " + IntegerToString(httpCode);
      return false;
   }
   
   // ตรวจสอบผลลัพธ์
   bool success = JsonGetBool(response, "success");
   if(!success)
   {
      g_lastError = JsonGetString(response, "error");
   }
   else
   {
      string eventName = "scheduled";
      if(eventType == SYNC_ORDER_OPEN) eventName = "order_open";
      else if(eventType == SYNC_ORDER_CLOSE) eventName = "order_close";
      Print("[Sync] Data synced successfully (event: ", eventName, ")");
   }
   
   return success;
}

//+------------------------------------------------------------------+
//| Build Sync JSON Payload with Event Type and Trade History          |
//+------------------------------------------------------------------+
string BuildSyncJsonWithEvent(ENUM_SYNC_EVENT eventType)
{
   long accountNumber = AccountInfoInteger(ACCOUNT_LOGIN);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   double floatingProfit = AccountInfoDouble(ACCOUNT_PROFIT);
   
   // คำนวณ Drawdown
   double drawdown = 0;
   if(balance > 0)
   {
      drawdown = ((balance - equity) / balance) * 100;
      if(drawdown < 0) drawdown = 0;
   }
   
   // Count open orders
   int openOrders = PositionsTotal();
   
   // Calculate total profit from trade history
   double totalProfit = CalculateTotalProfit();
   
   // Event type string
   string eventTypeStr = "scheduled";
   if(eventType == SYNC_ORDER_OPEN) eventTypeStr = "order_open";
   else if(eventType == SYNC_ORDER_CLOSE) eventTypeStr = "order_close";
   
   string json = "{";
   json += "\\"account_number\\":\\"" + IntegerToString(accountNumber) + "\\",";
   json += "\\"balance\\":" + DoubleToString(balance, 2) + ",";
   json += "\\"equity\\":" + DoubleToString(equity, 2) + ",";
   json += "\\"margin_level\\":" + DoubleToString(marginLevel, 2) + ",";
   json += "\\"drawdown\\":" + DoubleToString(drawdown, 2) + ",";
   json += "\\"profit_loss\\":" + DoubleToString(floatingProfit, 2) + ",";
   json += "\\"open_orders\\":" + IntegerToString(openOrders) + ",";
   json += "\\"floating_pl\\":" + DoubleToString(floatingProfit, 2) + ",";
   json += "\\"total_profit\\":" + DoubleToString(totalProfit, 2) + ",";
   json += "\\"event_type\\":\\"" + eventTypeStr + "\\"";
   json += "}";
   
   return json;
}

//+------------------------------------------------------------------+
//| Calculate Total Profit from Trade History                          |
//+------------------------------------------------------------------+
double CalculateTotalProfit()
{
   double totalProfit = 0;
   
   // Select history for all time
   if(!HistorySelect(0, TimeCurrent()))
   {
      Print("[Trade History] Failed to select history");
      return 0;
   }
   
   int totalDeals = HistoryDealsTotal();
   
   for(int i = 0; i < totalDeals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket > 0)
      {
         // Only count closed deals (exit or in-out)
         ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
         if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_INOUT)
         {
            double dealProfit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
            double dealSwap = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
            double dealCommission = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
            
            totalProfit += dealProfit + dealSwap + dealCommission;
         }
      }
   }
   
   return totalProfit;
}

//+------------------------------------------------------------------+
//| Legacy Sync Account Data (for compatibility)                       |
//+------------------------------------------------------------------+
bool SyncAccountData()
{
   return SyncAccountDataWithEvent(SYNC_SCHEDULED);
}

//+------------------------------------------------------------------+
//| Build Sync JSON Payload (legacy)                                   |
//+------------------------------------------------------------------+
string BuildSyncJson()
{
   return BuildSyncJsonWithEvent(SYNC_SCHEDULED);
}

//+------------------------------------------------------------------+
//| OnTick License Handler                                             |
//+------------------------------------------------------------------+
bool OnTickLicense()
{
   datetime currentTime = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(currentTime, dt);
   
   // ตรวจสอบ License ตาม interval
   if(currentTime - g_lastLicenseCheck >= g_licenseCheckInterval * 60)
   {
      ENUM_LICENSE_STATUS newStatus = VerifyLicense();
      g_lastLicenseCheck = currentTime;
      
      // ถ้าสถานะเปลี่ยน
      if(newStatus != g_licenseStatus)
      {
         g_licenseStatus = newStatus;
         g_isLicenseValid = (newStatus == LICENSE_VALID || newStatus == LICENSE_EXPIRING_SOON);
         
         // แสดง popup ถ้า license หมด
         if(!g_isLicenseValid)
         {
            ShowLicensePopup(g_licenseStatus);
         }
      }
      
      // แสดง popup เตือน expiring soon (วันละ 1 ครั้ง)
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
   
   // Scheduled sync at 05:00 AM and 23:00 PM
   if(g_isLicenseValid)
   {
      bool shouldSync = false;
      
      // Check if it's 05:00 or 23:00
      if((dt.hour == 5 || dt.hour == 23) && dt.min == 0)
      {
         // Only sync once per scheduled time (check if last sync was more than 30 minutes ago)
         if(currentTime - g_lastDataSync >= 1800)
         {
            shouldSync = true;
            Print("[Scheduled Sync] Time: ", dt.hour, ":00 - syncing data...");
         }
      }
      
      // Also sync based on interval (fallback)
      if(!shouldSync && (currentTime - g_lastDataSync >= g_dataSyncInterval * 60))
      {
         shouldSync = true;
      }
      
      if(shouldSync)
      {
         SyncAccountDataWithEvent(SYNC_SCHEDULED);
         g_lastDataSync = currentTime;
      }
   }
   
   return g_isLicenseValid;
}

//+------------------------------------------------------------------+
//| Show License Status Popup                                          |
//+------------------------------------------------------------------+
void ShowLicensePopup(ENUM_LICENSE_STATUS status)
{
   string title = "Moneyx Smart Gold EA v5.2 - License";
   string message = "";
   uint flags = MB_OK;
   
   switch(status)
   {
      case LICENSE_VALID:
         message = "✅ License Verified Successfully!\\n\\n";
         message += "Customer: " + g_customerName + "\\n";
         message += "Package: " + g_packageType + "\\n";
         message += "System: " + g_tradingSystem + "\\n\\n";
         if(g_isLifetime)
            message += "License Type: LIFETIME\\n";
         else
            message += "Expires: " + TimeToString(g_expiryDate, TIME_DATE) + "\\n";
         message += "\\nReal-time sync enabled! 🚀";
         flags = MB_OK | MB_ICONINFORMATION;
         break;
         
      case LICENSE_EXPIRING_SOON:
         message = "⚠️ License Expiring Soon!\\n\\n";
         message += "Customer: " + g_customerName + "\\n";
         message += "Days Remaining: " + IntegerToString(g_daysRemaining) + " days\\n";
         message += "Expires: " + TimeToString(g_expiryDate, TIME_DATE) + "\\n\\n";
         message += "Please renew your license to continue using.\\n";
         message += "Contact: support@moneyx-smart.com";
         flags = MB_OK | MB_ICONWARNING;
         break;
         
      case LICENSE_EXPIRED:
         message = "❌ License Expired!\\n\\n";
         message += "Your license has expired.\\n";
         message += "Trading is disabled.\\n\\n";
         message += "Please renew your license to continue.\\n";
         message += "Contact: support@moneyx-smart.com";
         flags = MB_OK | MB_ICONERROR;
         break;
         
      case LICENSE_NOT_FOUND:
         message = "❌ Account Not Registered!\\n\\n";
         message += "Account: " + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "\\n\\n";
         message += "This account is not registered in our system.\\n";
         message += "Please purchase a license to use this EA.\\n\\n";
         message += "Contact: support@moneyx-smart.com";
         flags = MB_OK | MB_ICONERROR;
         break;
         
      case LICENSE_SUSPENDED:
         message = "❌ License Suspended!\\n\\n";
         message += "Your license has been suspended.\\n";
         message += "Trading is disabled.\\n\\n";
         message += "Please contact support for assistance.\\n";
         message += "Contact: support@moneyx-smart.com";
         flags = MB_OK | MB_ICONERROR;
         break;
         
      case LICENSE_ERROR:
         message = "⚠️ License Verification Error!\\n\\n";
         message += "Could not verify license.\\n";
         message += "Error: " + g_lastError + "\\n\\n";
         message += "Please check:\\n";
         message += "1. Internet connection\\n";
         message += "2. WebRequest allowed for:\\n";
         message += "   " + g_licenseServerUrl + "\\n\\n";
         message += "EA will retry on next check.";
         flags = MB_OK | MB_ICONWARNING;
         break;
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
   // เพิ่ม x-api-key header สำหรับ authentication
   string headers = "Content-Type: application/json\\r\\nx-api-key: " + EA_API_SECRET + "\\r\\n";
   string resultHeaders;
   
   // แปลง string เป็น char array
   StringToCharArray(jsonData, postData, 0, StringLen(jsonData));
   
   // ลบ null terminator
   ArrayResize(postData, StringLen(jsonData));
   
   // ส่ง request
   int timeout = 10000; // 10 seconds
   int httpCode = WebRequest("POST", url, headers, timeout, postData, result, resultHeaders);
   
   if(httpCode == -1)
   {
      int errorCode = GetLastError();
      g_lastError = "WebRequest failed. Error: " + IntegerToString(errorCode);
      
      if(errorCode == 4014)
      {
         g_lastError = "WebRequest not allowed. Add URL to allowed list:\\n" + 
                       "Tools → Options → Expert Advisors → Allow WebRequest for listed URL\\n" +
                       "Add: " + g_licenseServerUrl;
      }
      
      return -1;
   }
   
   // แปลง result เป็น string
   response = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
   
   return httpCode;
}

//+------------------------------------------------------------------+
//| JSON Helper - Get String Value                                     |
//+------------------------------------------------------------------+
string JsonGetString(string json, string key)
{
   string searchKey = "\\"" + key + "\\":";
   int keyPos = StringFind(json, searchKey);
   
   if(keyPos < 0)
      return "";
   
   int valueStart = keyPos + StringLen(searchKey);
   
   // ข้าม whitespace
   while(valueStart < StringLen(json) && (StringGetCharacter(json, valueStart) == ' ' || 
                                           StringGetCharacter(json, valueStart) == '\\t'))
   {
      valueStart++;
   }
   
   // ตรวจสอบ null
   if(StringSubstr(json, valueStart, 4) == "null")
      return "";
   
   // ตรวจสอบว่าเป็น string หรือไม่
   if(StringGetCharacter(json, valueStart) == '"')
   {
      valueStart++;
      int valueEnd = StringFind(json, "\\"", valueStart);
      if(valueEnd < 0)
         return "";
      return StringSubstr(json, valueStart, valueEnd - valueStart);
   }
   
   // ไม่ใช่ string - อ่านจนเจอ , หรือ }
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
//| Get License Valid Status                                           |
//+------------------------------------------------------------------+
bool IsLicenseValid()
{
   return g_isLicenseValid;
}

//+------------------------------------------------------------------+
//| Get Customer Name                                                  |
//+------------------------------------------------------------------+
string GetCustomerName()
{
   return g_customerName;
}

//+------------------------------------------------------------------+
//| Get Package Type                                                   |
//+------------------------------------------------------------------+
string GetPackageType()
{
   return g_packageType;
}

//+------------------------------------------------------------------+
//| Get Expiry Date                                                    |
//+------------------------------------------------------------------+
datetime GetExpiryDate()
{
   return g_expiryDate;
}

//+------------------------------------------------------------------+
//| Get Days Remaining                                                 |
//+------------------------------------------------------------------+
int GetDaysRemaining()
{
   return g_daysRemaining;
}

//+------------------------------------------------------------------+
//| Check if Lifetime License                                          |
//+------------------------------------------------------------------+
bool IsLifetime()
{
   return g_isLifetime;
}

//+------------------------------------------------------------------+
//| Get Last Error Message                                             |
//+------------------------------------------------------------------+
string GetLastLicenseError()
{
   return g_lastError;
}

//+------------------------------------------------------------------+
//|                                                                    |
//|              END OF LICENSE VERIFICATION FUNCTIONS                 |
//|                                                                    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                    |
//|              YOUR TRADING FUNCTIONS GO BELOW                       |
//|              Add your trading strategy here                        |
//|                                                                    |
//+------------------------------------------------------------------+

// ตัวอย่าง: ฟังก์ชัน trading ของคุณ
// void ExecuteTradingStrategy()
// {
//    // Trading logic here
// }

//+------------------------------------------------------------------+`;

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="border-b border-border/40 bg-card/50 backdrop-blur-sm sticky top-0 z-50">
        <div className="container mx-auto px-4 py-4">
          <div className="flex items-center gap-4">
            <Link 
              to="/admin" 
              className="flex items-center gap-2 text-muted-foreground hover:text-foreground transition-colors"
            >
              <ArrowLeft className="w-4 h-4" />
              <span>กลับหน้า Admin</span>
            </Link>
            <div className="h-4 w-px bg-border" />
            <h1 className="text-xl font-bold text-foreground">MT5 EA Guide - License System v5.2</h1>
          </div>
        </div>
      </header>

      <main className="container mx-auto px-4 py-8 max-w-5xl">
        {/* Version Badge */}
        <div className="mb-8 flex items-center gap-3">
          <span className="px-3 py-1 bg-primary/10 text-primary rounded-full text-sm font-medium">
            v5.2
          </span>
          <span className="text-muted-foreground text-sm">
            อัพเดทล่าสุด: Real-time Sync + Trade History
          </span>
        </div>

        {/* What's New in v5.2 */}
        <section className="mb-12">
          <h2 className="text-2xl font-bold text-foreground mb-6 flex items-center gap-2">
            <Zap className="w-6 h-6 text-yellow-500" />
            มีอะไรใหม่ใน v5.2
          </h2>
          
          <div className="grid md:grid-cols-3 gap-4">
            <div className="p-4 bg-card border border-border rounded-lg">
              <div className="flex items-center gap-2 mb-2">
                <RefreshCw className="w-5 h-5 text-green-500" />
                <h3 className="font-semibold text-foreground">Real-time Sync</h3>
              </div>
              <p className="text-sm text-muted-foreground">
                ส่งข้อมูลทันทีเมื่อเปิด/ปิด Order ผ่าน OnTradeTransaction handler
              </p>
            </div>
            
            <div className="p-4 bg-card border border-border rounded-lg">
              <div className="flex items-center gap-2 mb-2">
                <TrendingUp className="w-5 h-5 text-blue-500" />
                <h3 className="font-semibold text-foreground">Trade History</h3>
              </div>
              <p className="text-sm text-muted-foreground">
                คำนวณ Total Profit จากประวัติการเทรดด้วย HistorySelect
              </p>
            </div>
            
            <div className="p-4 bg-card border border-border rounded-lg">
              <div className="flex items-center gap-2 mb-2">
                <Clock className="w-5 h-5 text-orange-500" />
                <h3 className="font-semibold text-foreground">Scheduled Sync</h3>
              </div>
              <p className="text-sm text-muted-foreground">
                Sync อัตโนมัติที่ 05:00 AM และ 23:00 PM ทุกวัน
              </p>
            </div>
          </div>
        </section>

        {/* Data Synced */}
        <section className="mb-12">
          <h2 className="text-2xl font-bold text-foreground mb-6 flex items-center gap-2">
            <TrendingUp className="w-6 h-6 text-primary" />
            ข้อมูลที่ Sync ไปยัง Server
          </h2>
          
          <div className="bg-card border border-border rounded-lg overflow-hidden">
            <table className="w-full">
              <thead className="bg-muted/50">
                <tr>
                  <th className="px-4 py-3 text-left text-sm font-medium text-foreground">Field</th>
                  <th className="px-4 py-3 text-left text-sm font-medium text-foreground">Description</th>
                  <th className="px-4 py-3 text-left text-sm font-medium text-foreground">Source</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                <tr>
                  <td className="px-4 py-3 text-sm font-mono text-foreground">balance</td>
                  <td className="px-4 py-3 text-sm text-muted-foreground">ยอดเงินในบัญชี</td>
                  <td className="px-4 py-3 text-sm font-mono text-muted-foreground">ACCOUNT_BALANCE</td>
                </tr>
                <tr>
                  <td className="px-4 py-3 text-sm font-mono text-foreground">equity</td>
                  <td className="px-4 py-3 text-sm text-muted-foreground">Equity (รวม Floating P/L)</td>
                  <td className="px-4 py-3 text-sm font-mono text-muted-foreground">ACCOUNT_EQUITY</td>
                </tr>
                <tr>
                  <td className="px-4 py-3 text-sm font-mono text-foreground">margin_level</td>
                  <td className="px-4 py-3 text-sm text-muted-foreground">Margin Level (%)</td>
                  <td className="px-4 py-3 text-sm font-mono text-muted-foreground">ACCOUNT_MARGIN_LEVEL</td>
                </tr>
                <tr>
                  <td className="px-4 py-3 text-sm font-mono text-foreground">drawdown</td>
                  <td className="px-4 py-3 text-sm text-muted-foreground">Drawdown (%)</td>
                  <td className="px-4 py-3 text-sm font-mono text-muted-foreground">คำนวณจาก Balance/Equity</td>
                </tr>
                <tr>
                  <td className="px-4 py-3 text-sm font-mono text-foreground">profit_loss</td>
                  <td className="px-4 py-3 text-sm text-muted-foreground">Floating P/L ปัจจุบัน</td>
                  <td className="px-4 py-3 text-sm font-mono text-muted-foreground">ACCOUNT_PROFIT</td>
                </tr>
                <tr className="bg-green-500/5">
                  <td className="px-4 py-3 text-sm font-mono text-green-600 font-semibold">open_orders</td>
                  <td className="px-4 py-3 text-sm text-muted-foreground">จำนวน Orders ที่เปิดอยู่</td>
                  <td className="px-4 py-3 text-sm font-mono text-muted-foreground">PositionsTotal()</td>
                </tr>
                <tr className="bg-green-500/5">
                  <td className="px-4 py-3 text-sm font-mono text-green-600 font-semibold">floating_pl</td>
                  <td className="px-4 py-3 text-sm text-muted-foreground">Floating P/L (alias)</td>
                  <td className="px-4 py-3 text-sm font-mono text-muted-foreground">ACCOUNT_PROFIT</td>
                </tr>
                <tr className="bg-green-500/5">
                  <td className="px-4 py-3 text-sm font-mono text-green-600 font-semibold">total_profit</td>
                  <td className="px-4 py-3 text-sm text-muted-foreground">กำไรสะสมจาก Trade History</td>
                  <td className="px-4 py-3 text-sm font-mono text-muted-foreground">CalculateTotalProfit()</td>
                </tr>
                <tr className="bg-green-500/5">
                  <td className="px-4 py-3 text-sm font-mono text-green-600 font-semibold">event_type</td>
                  <td className="px-4 py-3 text-sm text-muted-foreground">ประเภทเหตุการณ์ที่ trigger sync</td>
                  <td className="px-4 py-3 text-sm font-mono text-muted-foreground">scheduled / order_open / order_close</td>
                </tr>
              </tbody>
            </table>
          </div>
          
          <p className="mt-3 text-sm text-muted-foreground">
            <span className="text-green-600 font-medium">สีเขียว</span> = Field ใหม่ใน v5.2
          </p>
        </section>

        {/* Sync Events */}
        <section className="mb-12">
          <h2 className="text-2xl font-bold text-foreground mb-6 flex items-center gap-2">
            <RefreshCw className="w-6 h-6 text-primary" />
            เหตุการณ์ที่ Trigger การ Sync
          </h2>
          
          <div className="space-y-4">
            <div className="p-4 bg-card border border-border rounded-lg">
              <div className="flex items-center gap-3 mb-2">
                <span className="px-2 py-1 bg-blue-500/10 text-blue-600 rounded text-xs font-mono">scheduled</span>
                <h3 className="font-semibold text-foreground">Scheduled Sync</h3>
              </div>
              <ul className="text-sm text-muted-foreground space-y-1 ml-4">
                <li>• Sync ตอน EA เริ่มทำงานครั้งแรก</li>
                <li>• Sync ทุกๆ 05:00 AM และ 23:00 PM (Server Time)</li>
                <li>• Sync ตาม interval ที่กำหนด (fallback)</li>
              </ul>
            </div>
            
            <div className="p-4 bg-card border border-border rounded-lg">
              <div className="flex items-center gap-3 mb-2">
                <span className="px-2 py-1 bg-green-500/10 text-green-600 rounded text-xs font-mono">order_open</span>
                <h3 className="font-semibold text-foreground">Order Open Event</h3>
              </div>
              <ul className="text-sm text-muted-foreground space-y-1 ml-4">
                <li>• Sync ทันทีเมื่อมี Order เปิดใหม่</li>
                <li>• ใช้ OnTradeTransaction() handler</li>
                <li>• ตรวจจับ DEAL_ENTRY_IN</li>
              </ul>
            </div>
            
            <div className="p-4 bg-card border border-border rounded-lg">
              <div className="flex items-center gap-3 mb-2">
                <span className="px-2 py-1 bg-red-500/10 text-red-600 rounded text-xs font-mono">order_close</span>
                <h3 className="font-semibold text-foreground">Order Close Event</h3>
              </div>
              <ul className="text-sm text-muted-foreground space-y-1 ml-4">
                <li>• Sync ทันทีเมื่อมี Order ปิด</li>
                <li>• ใช้ OnTradeTransaction() handler</li>
                <li>• ตรวจจับ DEAL_ENTRY_OUT หรือ DEAL_ENTRY_INOUT</li>
              </ul>
            </div>
          </div>
        </section>

        {/* Installation Steps */}
        <section className="mb-12">
          <h2 className="text-2xl font-bold text-foreground mb-6 flex items-center gap-2">
            <Settings className="w-6 h-6 text-primary" />
            ขั้นตอนการติดตั้ง
          </h2>
          
          <div className="space-y-4">
            <div className="p-4 bg-card border border-border rounded-lg flex items-start gap-4">
              <span className="flex items-center justify-center w-8 h-8 bg-primary text-primary-foreground rounded-full font-bold shrink-0">1</span>
              <div>
                <h3 className="font-semibold text-foreground">เปิด MT5 → Allow WebRequest</h3>
                <p className="text-sm text-muted-foreground">ไปที่ Tools → Options → Expert Advisors → เปิด 'Allow WebRequest for listed URL' แล้วเพิ่ม URL: https://lkbhomsulgycxawwlnfh.supabase.co</p>
              </div>
            </div>
            <div className="p-4 bg-card border border-border rounded-lg flex items-start gap-4">
              <span className="flex items-center justify-center w-8 h-8 bg-primary text-primary-foreground rounded-full font-bold shrink-0">2</span>
              <div>
                <h3 className="font-semibold text-foreground">Copy โค้ด EA ด้านล่าง</h3>
                <p className="text-sm text-muted-foreground">Copy โค้ดทั้งหมดจากส่วน 'Full EA Code v5.2' แล้วบันทึกเป็นไฟล์ .mq5 ใน MQL5/Experts folder</p>
              </div>
            </div>
            <div className="p-4 bg-card border border-border rounded-lg flex items-start gap-4">
              <span className="flex items-center justify-center w-8 h-8 bg-primary text-primary-foreground rounded-full font-bold shrink-0">3</span>
              <div>
                <h3 className="font-semibold text-foreground">Compile EA</h3>
                <p className="text-sm text-muted-foreground">เปิดไฟล์ใน MetaEditor แล้วกด Compile (F7) ตรวจสอบว่าไม่มี error</p>
              </div>
            </div>
            <div className="p-4 bg-card border border-border rounded-lg flex items-start gap-4">
              <span className="flex items-center justify-center w-8 h-8 bg-primary text-primary-foreground rounded-full font-bold shrink-0">4</span>
              <div>
                <h3 className="font-semibold text-foreground">แนบ EA บน Chart</h3>
                <p className="text-sm text-muted-foreground">ลาก EA ไปวางบน Chart ที่ต้องการ → ติ๊ก 'Allow automated trading' → กด OK</p>
              </div>
            </div>
          </div>
        </section>

        {/* Important Notes */}
        <section className="mb-12">
          <h2 className="text-2xl font-bold text-foreground mb-6 flex items-center gap-2">
            <AlertTriangle className="w-6 h-6 text-yellow-500" />
            ข้อควรระวัง
          </h2>
          
          <div className="bg-yellow-500/10 border border-yellow-500/30 rounded-lg p-6">
            <ul className="space-y-3 text-foreground">
              <li className="flex items-start gap-2">
                <Shield className="w-5 h-5 text-yellow-500 mt-0.5 shrink-0" />
                <span><strong>API Secret:</strong> ห้ามแก้ไขค่า EA_API_SECRET ในโค้ด ต้องตรงกับ Server</span>
              </li>
              <li className="flex items-start gap-2">
                <Info className="w-5 h-5 text-yellow-500 mt-0.5 shrink-0" />
                <span><strong>Tester Mode:</strong> EA จะข้าม License Check และ Data Sync อัตโนมัติใน Strategy Tester</span>
              </li>
              <li className="flex items-start gap-2">
                <AlertTriangle className="w-5 h-5 text-yellow-500 mt-0.5 shrink-0" />
                <span><strong>WebRequest:</strong> ต้องเพิ่ม URL ใน Allowed list ก่อนใช้งาน มิฉะนั้นจะเกิด Error 4014</span>
              </li>
              <li className="flex items-start gap-2">
                <Zap className="w-5 h-5 text-yellow-500 mt-0.5 shrink-0" />
                <span><strong>Real-time Sync:</strong> ทำงานเฉพาะ Live Trading เท่านั้น ไม่ทำงานใน Backtest</span>
              </li>
            </ul>
          </div>
        </section>

        {/* Full EA Code */}
        <section className="mb-12">
          <h2 className="text-2xl font-bold text-foreground mb-6 flex items-center gap-2">
            <FileCode className="w-6 h-6 text-primary" />
            Full EA Code v5.2
          </h2>
          
          <div className="bg-card border border-border rounded-lg overflow-hidden">
            <div className="flex items-center justify-between px-4 py-3 border-b border-border bg-muted/50">
              <span className="text-sm font-medium text-foreground">Moneyx_Smart_Gold_EA_Licensed.mq5</span>
              <button 
                onClick={() => navigator.clipboard.writeText(fullEACode)}
                className="flex items-center gap-2 px-3 py-1.5 bg-primary text-primary-foreground rounded-md text-sm hover:bg-primary/90 transition-colors"
              >
                <Download className="w-4 h-4" />
                Copy Code
              </button>
            </div>
            <CodeBlock code={fullEACode} language="cpp" />
          </div>
        </section>

        {/* Integration with Trading Logic */}
        <section className="mb-12">
          <h2 className="text-2xl font-bold text-foreground mb-6 flex items-center gap-2">
            <Settings className="w-6 h-6 text-primary" />
            การรวมกับ Trading Logic ของคุณ
          </h2>
          
          <div className="bg-card border border-border rounded-lg p-6">
            <p className="text-muted-foreground mb-4">
              หากต้องการรวม License System นี้กับ EA ที่มีอยู่แล้ว ให้ทำตามขั้นตอนนี้:
            </p>
            
            <ol className="space-y-4 text-foreground">
              <li className="flex items-start gap-3">
                <span className="flex items-center justify-center w-6 h-6 bg-primary text-primary-foreground rounded-full text-sm font-bold shrink-0">1</span>
                <div>
                  <p className="font-medium">Copy ทุกอย่างตั้งแต่ Input Parameters ไปจนถึง END OF LICENSE VERIFICATION FUNCTIONS</p>
                  <p className="text-sm text-muted-foreground">นี่คือ License System ทั้งหมดที่ต้องใช้</p>
                </div>
              </li>
              <li className="flex items-start gap-3">
                <span className="flex items-center justify-center w-6 h-6 bg-primary text-primary-foreground rounded-full text-sm font-bold shrink-0">2</span>
                <div>
                  <p className="font-medium">ใส่ Trading Logic ของคุณในส่วน YOUR TRADING LOGIC STARTS HERE</p>
                  <p className="text-sm text-muted-foreground">แทนที่ comment ด้วย function calls หรือโค้ดของคุณ</p>
                </div>
              </li>
              <li className="flex items-start gap-3">
                <span className="flex items-center justify-center w-6 h-6 bg-primary text-primary-foreground rounded-full text-sm font-bold shrink-0">3</span>
                <div>
                  <p className="font-medium">ตรวจสอบว่า g_isLicenseValid ก่อนเปิด Order</p>
                  <p className="text-sm text-muted-foreground">EA จะเช็คให้แล้วใน OnTick แต่ควรเช็คซ้ำในฟังก์ชัน trade ของคุณด้วย</p>
                </div>
              </li>
            </ol>
          </div>
        </section>
      </main>
    </div>
  );
};

export default MT5EAGuide;
