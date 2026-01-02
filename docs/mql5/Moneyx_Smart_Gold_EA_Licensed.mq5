//+------------------------------------------------------------------+
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
   string jsonRequest = "{\"account_number\":\"" + IntegerToString(accountNumber) + "\"}";
   
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
   
   // Calculate portfolio statistics
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
   
   // Event type string
   string eventTypeStr = "scheduled";
   if(eventType == SYNC_ORDER_OPEN) eventTypeStr = "order_open";
   else if(eventType == SYNC_ORDER_CLOSE) eventTypeStr = "order_close";
   
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
   // Portfolio stats
   json += "\"initial_balance\":" + DoubleToString(initialBalance, 2) + ",";
   json += "\"total_deposit\":" + DoubleToString(totalDeposit, 2) + ",";
   json += "\"total_withdrawal\":" + DoubleToString(totalWithdrawal, 2) + ",";
   json += "\"max_drawdown\":" + DoubleToString(maxDrawdown, 2) + ",";
   json += "\"win_trades\":" + IntegerToString(winTrades) + ",";
   json += "\"loss_trades\":" + IntegerToString(lossTrades) + ",";
   json += "\"total_trades\":" + IntegerToString(totalTrades) + ",";
   json += "\"event_type\":\"" + eventTypeStr + "\"";
   
   // Include trade history on order close events
   if(eventType == SYNC_ORDER_CLOSE)
   {
      string tradeHistoryJson = BuildTradeHistoryJson();
      if(StringLen(tradeHistoryJson) > 2)  // Not empty array "[]"
      {
         json += ",\"trade_history\":" + tradeHistoryJson;
      }
   }
   
   json += "}";
   
   return json;
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
   
   // Select history for all time
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
         
         // Track deposits and withdrawals
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
         // Count closed trades (exit or in-out)
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
         
         // Track max drawdown
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
   
   // Select history for all time
   if(!HistorySelect(0, TimeCurrent()))
   {
      Print("[Trade History] Failed to select history");
      return "[]";
   }
   
   int totalDeals = HistoryDealsTotal();
   
   // Only send last 100 deals to avoid huge payloads
   int startIdx = MathMax(0, totalDeals - 100);
   
   for(int i = startIdx; i < totalDeals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket > 0)
      {
         ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(dealTicket, DEAL_TYPE);
         ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
         
         // Skip if not a trade or balance operation
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
         
         // Determine deal type string
         string dealTypeStr = "unknown";
         if(dealType == DEAL_TYPE_BUY) dealTypeStr = "buy";
         else if(dealType == DEAL_TYPE_SELL) dealTypeStr = "sell";
         else if(dealType == DEAL_TYPE_BALANCE) dealTypeStr = "balance";
         
         // Determine entry type string
         string entryTypeStr = "unknown";
         if(dealEntry == DEAL_ENTRY_IN) entryTypeStr = "in";
         else if(dealEntry == DEAL_ENTRY_OUT) entryTypeStr = "out";
         else if(dealEntry == DEAL_ENTRY_INOUT) entryTypeStr = "inout";
         
         // Build JSON object
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
         message = "✅ License Verified Successfully!\n\n";
         message += "Customer: " + g_customerName + "\n";
         message += "Package: " + g_packageType + "\n";
         message += "System: " + g_tradingSystem + "\n\n";
         if(g_isLifetime)
            message += "License Type: LIFETIME\n";
         else
            message += "Expires: " + TimeToString(g_expiryDate, TIME_DATE) + "\n";
         message += "\nReal-time sync enabled! 🚀";
         flags = MB_OK | MB_ICONINFORMATION;
         break;
         
      case LICENSE_EXPIRING_SOON:
         message = "⚠️ License Expiring Soon!\n\n";
         message += "Customer: " + g_customerName + "\n";
         message += "Days Remaining: " + IntegerToString(g_daysRemaining) + " days\n";
         message += "Expires: " + TimeToString(g_expiryDate, TIME_DATE) + "\n\n";
         message += "Please renew your license to continue using.\n";
         message += "Contact: support@moneyx-smart.com";
         flags = MB_OK | MB_ICONWARNING;
         break;
         
      case LICENSE_EXPIRED:
         message = "❌ License Expired!\n\n";
         message += "Your license has expired.\n";
         message += "Trading is disabled.\n\n";
         message += "Please renew your license to continue.\n";
         message += "Contact: support@moneyx-smart.com";
         flags = MB_OK | MB_ICONERROR;
         break;
         
      case LICENSE_NOT_FOUND:
         message = "❌ Account Not Registered!\n\n";
         message += "Account: " + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "\n\n";
         message += "This account is not registered in our system.\n";
         message += "Please purchase a license to use this EA.\n\n";
         message += "Contact: support@moneyx-smart.com";
         flags = MB_OK | MB_ICONERROR;
         break;
         
      case LICENSE_SUSPENDED:
         message = "❌ License Suspended!\n\n";
         message += "Your license has been suspended.\n";
         message += "Trading is disabled.\n\n";
         message += "Please contact support for assistance.\n";
         message += "Contact: support@moneyx-smart.com";
         flags = MB_OK | MB_ICONERROR;
         break;
         
      case LICENSE_ERROR:
         message = "⚠️ License Verification Error!\n\n";
         message += "Could not verify license.\n";
         message += "Error: " + g_lastError + "\n\n";
         message += "Please check:\n";
         message += "1. Internet connection\n";
         message += "2. WebRequest allowed for:\n";
         message += "   " + g_licenseServerUrl + "\n\n";
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
   string headers = "Content-Type: application/json\r\nx-api-key: " + EA_API_SECRET + "\r\n";
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
         g_lastError = "WebRequest not allowed. Add URL to allowed list:\n" + 
                       "Tools → Options → Expert Advisors → Allow WebRequest for listed URL\n" +
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
   string searchKey = "\"" + key + "\":";
   int keyPos = StringFind(json, searchKey);
   
   if(keyPos < 0)
      return "";
   
   int valueStart = keyPos + StringLen(searchKey);
   
   // ข้าม whitespace
   while(valueStart < StringLen(json) && (StringGetCharacter(json, valueStart) == ' ' || 
                                           StringGetCharacter(json, valueStart) == '\t'))
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
      int valueEnd = StringFind(json, "\"", valueStart);
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

//+------------------------------------------------------------------+
