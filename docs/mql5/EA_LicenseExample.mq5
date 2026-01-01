//+------------------------------------------------------------------+
//|                                            EA_LicenseExample.mq5 |
//|                        Example EA with License Verification      |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Your Company"
#property link      "https://yourwebsite.com"
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| Include License Manager                                           |
//+------------------------------------------------------------------+
#include "LicenseManager.mqh"

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input group "=== License Settings ==="
input string   InpLicenseServer = "https://lkbhomsulgycxawwlnfh.supabase.co";  // License Server URL
input int      InpLicenseCheckMinutes = 60;     // License Check Interval (minutes)
input int      InpDataSyncMinutes = 5;          // Data Sync Interval (minutes)

input group "=== Trading Settings ==="
input double   InpLotSize = 0.01;               // Lot Size
input int      InpMagicNumber = 12345;          // Magic Number

//+------------------------------------------------------------------+
//| Global Variables                                                  |
//+------------------------------------------------------------------+
CLicenseManager* g_licenseManager = NULL;
bool g_isLicenseValid = false;

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("=== EA Initializing ===");
   Print("Account: ", AccountInfoInteger(ACCOUNT_LOGIN));
   Print("Server: ", AccountInfoString(ACCOUNT_SERVER));
   
   //--- Create license manager
   g_licenseManager = new CLicenseManager();
   
   //--- Initialize and verify license
   Print("Verifying license...");
   g_isLicenseValid = g_licenseManager.Init(InpLicenseServer, InpLicenseCheckMinutes, InpDataSyncMinutes);
   
   if(!g_isLicenseValid)
   {
      Print("License verification failed: ", g_licenseManager.GetLastError());
      Print("EA will not execute trades.");
      
      // You can choose to:
      // 1. Return INIT_FAILED to prevent EA from running
      // 2. Return INIT_SUCCEEDED but disable trading
      
      // Option 1: Prevent EA from loading
      // return INIT_FAILED;
      
      // Option 2: Allow EA to load but disable trading
      return INIT_SUCCEEDED;
   }
   
   Print("License verified successfully!");
   Print("Customer: ", g_licenseManager.GetCustomerName());
   Print("Package: ", g_licenseManager.GetPackageType());
   
   if(g_licenseManager.IsLifetime())
   {
      Print("License Type: LIFETIME");
   }
   else
   {
      Print("Expiry: ", TimeToString(g_licenseManager.GetExpiryDate(), TIME_DATE));
      Print("Days Remaining: ", g_licenseManager.GetDaysRemaining());
   }
   
   Print("=== EA Ready ===");
   
   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Clean up license manager
   if(g_licenseManager != NULL)
   {
      delete g_licenseManager;
      g_licenseManager = NULL;
   }
   
   Print("EA Deinitialized. Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Check license on each tick (internally handles timing)
   if(g_licenseManager != NULL)
   {
      g_isLicenseValid = g_licenseManager.OnTick();
   }
   
   //--- Don't trade if license is invalid
   if(!g_isLicenseValid)
   {
      return;
   }
   
   //=================================================================
   // YOUR TRADING LOGIC GOES HERE
   //=================================================================
   
   // Example: Simple moving average cross strategy
   // This is just a placeholder - replace with your actual strategy
   
   /*
   double ma_fast = iMA(_Symbol, PERIOD_CURRENT, 10, 0, MODE_EMA, PRICE_CLOSE);
   double ma_slow = iMA(_Symbol, PERIOD_CURRENT, 20, 0, MODE_EMA, PRICE_CLOSE);
   
   // Your trading logic...
   */
   
   //=================================================================
}

//+------------------------------------------------------------------+
//| Trade transaction event handler                                   |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   // Handle trade transactions if needed
}

//+------------------------------------------------------------------+
//| Timer event handler (alternative for periodic checks)            |
//+------------------------------------------------------------------+
void OnTimer()
{
   // You can use timer events instead of OnTick for periodic operations
   // if you prefer: EventSetTimer(60); in OnInit()
}
//+------------------------------------------------------------------+
