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
#define SYNC_INTERVAL_MIN   5   // Sync account data every 5 minutes

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
datetime          g_lastDataSync = 0;
string            g_customerName = "";
string            g_packageType = "";
int               g_daysRemaining = 0;
bool              g_isLifetime = false;

//+------------------------------------------------------------------+
//| Check if running in tester (skip license for backtesting)        |
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
   // Skip in tester mode
   if(IsTestMode())
   {
      g_isLicenseValid = true;
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
         Print("[License] ERROR: Please add ", LICENSE_BASE_URL, " to allowed URLs");
         Print("[License] Go to: Tools > Options > Expert Advisors > Allow WebRequest");
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
         return LICENSE_EXPIRING_SOON;
      
      return LICENSE_VALID;
   }
   else
   {
      g_isLicenseValid = false;
      
      if(StringFind(response, "not found") >= 0)
         return LICENSE_NOT_FOUND;
      if(StringFind(response, "expired") >= 0)
         return LICENSE_EXPIRED;
      if(StringFind(response, "suspended") >= 0)
         return LICENSE_SUSPENDED;
      
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

  // === DATA SYNC CODE ===
  const dataSyncCode = `//+------------------------------------------------------------------+
//|                              Data Sync for ${systemName}
//|                                  Version ${version}
//+------------------------------------------------------------------+

// EA Status for Dashboard Display
string g_eaStatus = "working";  // working, paused, suspended, expired, invalid

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
   
   // Count open orders
   int openOrders = PositionsTotal();
   
   // Calculate floating P/L
   double floatingPL = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
         floatingPL += PositionGetDouble(POSITION_PROFIT);
   }
   
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
   json += "\\"ea_status\\":\\"" + g_eaStatus + "\\",";
   json += "\\"event_type\\":\\"" + eventType + "\\"";
   json += "}";
   
   // Send request
   char post[];
   char result[];
   string resultHeaders;
   string headers = "Content-Type: application/json\\r\\nx-api-key: " + EA_API_SECRET + "\\r\\n";
   
   StringToCharArray(json, post, 0, StringLen(json), CP_UTF8);
   ArrayResize(post, ArraySize(post) - 1);
   
   int res = WebRequest("POST", url, headers, 10000, post, result, resultHeaders);
   
   if(res == 200)
   {
      g_lastDataSync = TimeCurrent();
      Print("[Sync] Account data synced successfully - Event: ", eventType);
      return true;
   }
   
   Print("[Sync] Failed to sync account data. HTTP: ", res);
   return false;
}

//+------------------------------------------------------------------+
//| Sync on Trade Event (call in OnTradeTransaction)                  |
//+------------------------------------------------------------------+
void OnTradeSync(const MqlTradeTransaction& trans)
{
   if(IsTestMode()) return;
   
   // Sync on order open/close
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      // Small delay to let the deal settle
      Sleep(100);
      SyncAccountData("trade");
   }
}

//+------------------------------------------------------------------+
//| Scheduled Sync Check (call in OnTick)                             |
//+------------------------------------------------------------------+
void CheckScheduledSync()
{
   if(IsTestMode()) return;
   
   datetime now = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(now, dt);
   
   // Sync every SYNC_INTERVAL_MIN minutes
   if(now - g_lastDataSync >= SYNC_INTERVAL_MIN * 60)
   {
      SyncAccountData("scheduled");
   }
   
   // Also sync at specific times (05:00 and 23:00)
   static int lastSyncHour = -1;
   if((dt.hour == 5 || dt.hour == 23) && lastSyncHour != dt.hour)
   {
      SyncAccountData("daily");
      lastSyncHour = dt.hour;
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
   string searchKey = "\\"" + key + "\\":";
   int startPos = StringFind(json, searchKey);
   if(startPos < 0) return 0;
   
   startPos += StringLen(searchKey);
   string numStr = "";
   
   for(int i = startPos; i < StringLen(json); i++)
   {
      ushort ch = StringGetCharacter(json, i);
      if(ch >= '0' && ch <= '9')
         numStr += ShortToString(ch);
      else if(StringLen(numStr) > 0)
         break;
   }
   
   return (int)StringToInteger(numStr);
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

// ===== GLOBAL VARIABLES =====
CTrade trade;

//+------------------------------------------------------------------+
//| Include License & Sync Code (paste above sections here)          |
//+------------------------------------------------------------------+
// === PASTE LICENSE MANAGER CODE HERE ===
// === PASTE DATA SYNC CODE HERE ===
// === PASTE HELPER FUNCTIONS HERE ===

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   // Initialize License
   if(!InitLicense())
   {
      Print("[${systemName}] License verification failed!");
      return INIT_FAILED;
   }
   
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
      // License invalid - do not trade
      return;
   }
   
   // Check scheduled sync
   CheckScheduledSync();
   
   // Time filter
   if(InpUseTimeFilter && !IsTradeTime())
      return;
   
   // === YOUR TRADING LOGIC HERE ===
   
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
//| END OF EA TEMPLATE                                                |
//+------------------------------------------------------------------+`;

  // Full combined code
  const fullCode = `${eaTemplateCode}

// =====================================================
// ===== LICENSE MANAGER CODE (INCLUDE IN EA) ==========
// =====================================================
${licenseManagerCode}

// =====================================================
// ===== DATA SYNC CODE (INCLUDE IN EA) ================
// =====================================================
${dataSyncCode}

// =====================================================
// ===== HELPER FUNCTIONS (INCLUDE IN EA) ==============
// =====================================================
${helperFunctionsCode}`;

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
          <Badge variant="outline">Data Sync</Badge>
          <Badge variant="outline">WebRequest API</Badge>
          <Badge variant="outline">Account Metrics</Badge>
        </div>
        
        <Tabs defaultValue="template" className="w-full">
          <TabsList className="grid w-full grid-cols-4">
            <TabsTrigger value="template">EA Template</TabsTrigger>
            <TabsTrigger value="license">License</TabsTrigger>
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
