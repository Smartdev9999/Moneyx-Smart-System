//+------------------------------------------------------------------+
//|                                               LicenseManager.mqh |
//|                                    License Verification System   |
//|                                           For MT5 Expert Advisor |
//+------------------------------------------------------------------+
#property copyright "Your Company"
#property link      "https://yourwebsite.com"
#property version   "1.00"

//+------------------------------------------------------------------+
//| License Status Enumeration                                        |
//+------------------------------------------------------------------+
enum ENUM_LICENSE_STATUS
{
   LICENSE_VALID,           // License is valid and active
   LICENSE_EXPIRED,         // License has expired
   LICENSE_EXPIRING_SOON,   // License expiring within 7 days
   LICENSE_NOT_FOUND,       // Account not registered
   LICENSE_SUSPENDED,       // Account suspended
   LICENSE_ERROR            // Connection or server error
};

//+------------------------------------------------------------------+
//| License Manager Class                                             |
//+------------------------------------------------------------------+
class CLicenseManager
{
private:
   string            m_baseUrl;              // API base URL
   string            m_accountNumber;        // MT5 account number
   bool              m_isValid;              // License validity status
   datetime          m_expiryDate;           // License expiry date
   datetime          m_lastCheck;            // Last verification time
   int               m_checkInterval;        // Check interval in seconds
   string            m_lastError;            // Last error message
   string            m_customerName;         // Customer name from server
   string            m_packageType;          // Package type
   bool              m_isLifetime;           // Lifetime license flag
   int               m_daysRemaining;        // Days until expiry
   
   // Sync settings
   int               m_syncInterval;         // Sync interval in seconds
   datetime          m_lastSync;             // Last sync time
   
public:
                     CLicenseManager();
                    ~CLicenseManager();
   
   // Initialization
   bool              Init(string baseUrl, int checkIntervalMinutes = 60, int syncIntervalMinutes = 5);
   
   // License verification
   ENUM_LICENSE_STATUS VerifyLicense();
   bool              IsLicenseValid() { return m_isValid; }
   
   // Account data sync
   bool              SyncAccountData();
   
   // Getters
   string            GetLastError() { return m_lastError; }
   string            GetCustomerName() { return m_customerName; }
   string            GetPackageType() { return m_packageType; }
   datetime          GetExpiryDate() { return m_expiryDate; }
   int               GetDaysRemaining() { return m_daysRemaining; }
   bool              IsLifetime() { return m_isLifetime; }
   
   // Periodic check (call in OnTick)
   bool              OnTick();
   
   // Show notifications
   void              ShowLicensePopup(ENUM_LICENSE_STATUS status);
   
private:
   string            SendRequest(string endpoint, string jsonBody);
   string            BuildVerifyJson();
   string            BuildSyncJson();
   bool              ParseVerifyResponse(string response);
   bool              ParseSyncResponse(string response);
   string            JsonGetString(string json, string key);
   int               JsonGetInt(string json, string key);
   bool              JsonGetBool(string json, string key);
};

//+------------------------------------------------------------------+
//| Constructor                                                       |
//+------------------------------------------------------------------+
CLicenseManager::CLicenseManager()
{
   m_baseUrl = "";
   m_accountNumber = IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
   m_isValid = false;
   m_expiryDate = 0;
   m_lastCheck = 0;
   m_checkInterval = 3600; // 1 hour default
   m_lastError = "";
   m_customerName = "";
   m_packageType = "";
   m_isLifetime = false;
   m_daysRemaining = 0;
   m_syncInterval = 300; // 5 minutes default
   m_lastSync = 0;
}

//+------------------------------------------------------------------+
//| Destructor                                                        |
//+------------------------------------------------------------------+
CLicenseManager::~CLicenseManager()
{
}

//+------------------------------------------------------------------+
//| Initialize the license manager                                    |
//+------------------------------------------------------------------+
bool CLicenseManager::Init(string baseUrl, int checkIntervalMinutes = 60, int syncIntervalMinutes = 5)
{
   m_baseUrl = baseUrl;
   m_checkInterval = checkIntervalMinutes * 60;
   m_syncInterval = syncIntervalMinutes * 60;
   
   // Verify license on init
   ENUM_LICENSE_STATUS status = VerifyLicense();
   ShowLicensePopup(status);
   
   return (status == LICENSE_VALID || status == LICENSE_EXPIRING_SOON);
}

//+------------------------------------------------------------------+
//| Verify license with server                                        |
//+------------------------------------------------------------------+
ENUM_LICENSE_STATUS CLicenseManager::VerifyLicense()
{
   string jsonBody = BuildVerifyJson();
   string response = SendRequest("/functions/v1/verify-license", jsonBody);
   
   if(response == "")
   {
      m_lastError = "Connection failed - please check internet connection";
      return LICENSE_ERROR;
   }
   
   if(!ParseVerifyResponse(response))
   {
      return LICENSE_ERROR;
   }
   
   m_lastCheck = TimeCurrent();
   
   // Determine status
   if(!m_isValid)
   {
      // Check error message for specific status
      if(StringFind(m_lastError, "not found") >= 0 || StringFind(m_lastError, "not registered") >= 0)
         return LICENSE_NOT_FOUND;
      if(StringFind(m_lastError, "expired") >= 0)
         return LICENSE_EXPIRED;
      if(StringFind(m_lastError, "suspended") >= 0 || StringFind(m_lastError, "inactive") >= 0)
         return LICENSE_SUSPENDED;
      return LICENSE_ERROR;
   }
   
   // Check if expiring soon
   if(m_daysRemaining > 0 && m_daysRemaining <= 7)
      return LICENSE_EXPIRING_SOON;
   
   return LICENSE_VALID;
}

//+------------------------------------------------------------------+
//| Sync account data to server                                       |
//+------------------------------------------------------------------+
bool CLicenseManager::SyncAccountData()
{
   if(!m_isValid)
   {
      m_lastError = "Cannot sync - license not valid";
      return false;
   }
   
   string jsonBody = BuildSyncJson();
   string response = SendRequest("/functions/v1/sync-account-data", jsonBody);
   
   if(response == "")
   {
      m_lastError = "Sync failed - connection error";
      return false;
   }
   
   if(!ParseSyncResponse(response))
   {
      return false;
   }
   
   m_lastSync = TimeCurrent();
   return true;
}

//+------------------------------------------------------------------+
//| OnTick handler - call this in EA's OnTick                        |
//+------------------------------------------------------------------+
bool CLicenseManager::OnTick()
{
   datetime now = TimeCurrent();
   
   // Check license periodically
   if(now - m_lastCheck >= m_checkInterval)
   {
      ENUM_LICENSE_STATUS status = VerifyLicense();
      if(status != LICENSE_VALID && status != LICENSE_EXPIRING_SOON)
      {
         ShowLicensePopup(status);
         return false;
      }
      
      // Show warning if expiring soon
      if(status == LICENSE_EXPIRING_SOON)
      {
         static datetime lastWarning = 0;
         if(now - lastWarning >= 86400) // Once per day
         {
            ShowLicensePopup(status);
            lastWarning = now;
         }
      }
   }
   
   // Sync account data periodically
   if(now - m_lastSync >= m_syncInterval)
   {
      SyncAccountData();
   }
   
   return m_isValid;
}

//+------------------------------------------------------------------+
//| Show license status popup                                         |
//+------------------------------------------------------------------+
void CLicenseManager::ShowLicensePopup(ENUM_LICENSE_STATUS status)
{
   string title = "License Status";
   string message = "";
   int icon = MB_ICONINFORMATION;
   
   switch(status)
   {
      case LICENSE_VALID:
         if(m_isLifetime)
         {
            message = "✅ License Activated!\n\n" +
                      "Customer: " + m_customerName + "\n" +
                      "Package: " + m_packageType + "\n" +
                      "License: LIFETIME\n\n" +
                      "Thank you for your purchase!";
         }
         else
         {
            message = "✅ License Activated!\n\n" +
                      "Customer: " + m_customerName + "\n" +
                      "Package: " + m_packageType + "\n" +
                      "Expires: " + TimeToString(m_expiryDate, TIME_DATE) + "\n" +
                      "Days Remaining: " + IntegerToString(m_daysRemaining) + "\n\n" +
                      "Thank you for your purchase!";
         }
         icon = MB_ICONINFORMATION;
         break;
         
      case LICENSE_EXPIRING_SOON:
         message = "⚠️ License Expiring Soon!\n\n" +
                   "Customer: " + m_customerName + "\n" +
                   "Package: " + m_packageType + "\n" +
                   "Expires: " + TimeToString(m_expiryDate, TIME_DATE) + "\n" +
                   "Days Remaining: " + IntegerToString(m_daysRemaining) + "\n\n" +
                   "Please renew your license to continue using the EA.";
         icon = MB_ICONWARNING;
         break;
         
      case LICENSE_EXPIRED:
         title = "License Expired";
         message = "❌ Your license has expired!\n\n" +
                   "Account: " + m_accountNumber + "\n\n" +
                   "Please contact support to renew your license.\n" +
                   "The EA will not execute trades.";
         icon = MB_ICONERROR;
         break;
         
      case LICENSE_NOT_FOUND:
         title = "License Not Found";
         message = "❌ Account not registered!\n\n" +
                   "Account: " + m_accountNumber + "\n\n" +
                   "This account is not registered in our system.\n" +
                   "Please contact support to activate your license.";
         icon = MB_ICONERROR;
         break;
         
      case LICENSE_SUSPENDED:
         title = "License Suspended";
         message = "❌ Your license has been suspended!\n\n" +
                   "Account: " + m_accountNumber + "\n\n" +
                   "Please contact support for assistance.\n" +
                   "The EA will not execute trades.";
         icon = MB_ICONERROR;
         break;
         
      case LICENSE_ERROR:
         title = "Connection Error";
         message = "⚠️ Unable to verify license!\n\n" +
                   "Error: " + m_lastError + "\n\n" +
                   "Please check your internet connection.\n" +
                   "The EA will retry verification shortly.";
         icon = MB_ICONWARNING;
         break;
   }
   
   MessageBox(message, title, icon | MB_OK);
}

//+------------------------------------------------------------------+
//| Send HTTP request to server                                       |
//+------------------------------------------------------------------+
string CLicenseManager::SendRequest(string endpoint, string jsonBody)
{
   string url = m_baseUrl + endpoint;
   string headers = "Content-Type: application/json\r\n";
   char post[];
   char result[];
   string resultHeaders;
   
   // Convert JSON body to char array
   StringToCharArray(jsonBody, post, 0, StringLen(jsonBody), CP_UTF8);
   ArrayResize(post, ArraySize(post) - 1); // Remove null terminator
   
   // Reset error
   ResetLastError();
   
   // Send request
   int timeout = 10000; // 10 seconds
   int res = WebRequest("POST", url, headers, timeout, post, result, resultHeaders);
   
   if(res == -1)
   {
      int error = GetLastError();
      if(error == 4060)
      {
         m_lastError = "WebRequest not allowed. Please add '" + m_baseUrl + "' to allowed URLs in Tools > Options > Expert Advisors";
         Print("License Error: ", m_lastError);
      }
      else if(error == 4024)
      {
         m_lastError = "WebRequest error: " + IntegerToString(error) + ". Check URL whitelist.";
         Print("License Error: ", m_lastError);
      }
      else
      {
         m_lastError = "WebRequest failed with error: " + IntegerToString(error);
         Print("License Error: ", m_lastError);
      }
      return "";
   }
   
   // Check HTTP status
   if(res != 200)
   {
      m_lastError = "Server returned HTTP " + IntegerToString(res);
      Print("License Error: ", m_lastError);
   }
   
   // Convert result to string
   string response = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
   return response;
}

//+------------------------------------------------------------------+
//| Build JSON for verify request                                     |
//+------------------------------------------------------------------+
string CLicenseManager::BuildVerifyJson()
{
   return "{\"account_number\":\"" + m_accountNumber + "\"}";
}

//+------------------------------------------------------------------+
//| Build JSON for sync request                                       |
//+------------------------------------------------------------------+
string CLicenseManager::BuildSyncJson()
{
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
   
   string json = "{";
   json += "\"account_number\":\"" + m_accountNumber + "\",";
   json += "\"balance\":" + DoubleToString(balance, 2) + ",";
   json += "\"equity\":" + DoubleToString(equity, 2) + ",";
   json += "\"margin_level\":" + DoubleToString(marginLevel, 2) + ",";
   json += "\"drawdown\":" + DoubleToString(drawdown, 2) + ",";
   json += "\"profit_loss\":" + DoubleToString(profitLoss, 2);
   json += "}";
   
   return json;
}

//+------------------------------------------------------------------+
//| Parse verify response                                             |
//+------------------------------------------------------------------+
bool CLicenseManager::ParseVerifyResponse(string response)
{
   // Check for success
   string valid = JsonGetString(response, "valid");
   if(valid == "" && StringFind(response, "\"valid\"") < 0)
   {
      // Check for error message
      string error = JsonGetString(response, "error");
      if(error != "")
      {
         m_lastError = error;
         m_isValid = false;
         return false;
      }
      
      m_lastError = "Invalid server response";
      m_isValid = false;
      return false;
   }
   
   m_isValid = (valid == "true" || StringFind(response, "\"valid\":true") >= 0);
   
   if(!m_isValid)
   {
      string message = JsonGetString(response, "message");
      m_lastError = (message != "") ? message : "License not valid";
      return true;
   }
   
   // Parse additional data
   m_customerName = JsonGetString(response, "customer_name");
   m_packageType = JsonGetString(response, "package_type");
   m_isLifetime = JsonGetBool(response, "is_lifetime");
   m_daysRemaining = JsonGetInt(response, "days_remaining");
   
   // Parse expiry date
   string expiryStr = JsonGetString(response, "expiry_date");
   if(expiryStr != "" && expiryStr != "null")
   {
      // Parse ISO date (YYYY-MM-DD or YYYY-MM-DDTHH:MM:SS)
      string datePart = expiryStr;
      int tPos = StringFind(expiryStr, "T");
      if(tPos > 0)
         datePart = StringSubstr(expiryStr, 0, tPos);
      
      string parts[];
      StringSplit(datePart, '-', parts);
      if(ArraySize(parts) >= 3)
      {
         MqlDateTime dt;
         dt.year = (int)StringToInteger(parts[0]);
         dt.mon = (int)StringToInteger(parts[1]);
         dt.day = (int)StringToInteger(parts[2]);
         dt.hour = 23;
         dt.min = 59;
         dt.sec = 59;
         m_expiryDate = StructToTime(dt);
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
//| Parse sync response                                               |
//+------------------------------------------------------------------+
bool CLicenseManager::ParseSyncResponse(string response)
{
   string success = JsonGetString(response, "success");
   if(success == "true" || StringFind(response, "\"success\":true") >= 0)
   {
      return true;
   }
   
   string error = JsonGetString(response, "error");
   m_lastError = (error != "") ? error : "Sync failed";
   return false;
}

//+------------------------------------------------------------------+
//| Simple JSON string value parser                                   |
//+------------------------------------------------------------------+
string CLicenseManager::JsonGetString(string json, string key)
{
   string searchKey = "\"" + key + "\":";
   int keyPos = StringFind(json, searchKey);
   if(keyPos < 0) return "";
   
   int valueStart = keyPos + StringLen(searchKey);
   
   // Skip whitespace
   while(valueStart < StringLen(json) && StringGetCharacter(json, valueStart) == ' ')
      valueStart++;
   
   if(valueStart >= StringLen(json)) return "";
   
   ushort firstChar = StringGetCharacter(json, valueStart);
   
   // Check if it's a string value
   if(firstChar == '"')
   {
      valueStart++;
      int valueEnd = StringFind(json, "\"", valueStart);
      if(valueEnd < 0) return "";
      return StringSubstr(json, valueStart, valueEnd - valueStart);
   }
   
   // It's a non-string value (number, boolean, null)
   int valueEnd = valueStart;
   while(valueEnd < StringLen(json))
   {
      ushort c = StringGetCharacter(json, valueEnd);
      if(c == ',' || c == '}' || c == ']' || c == ' ' || c == '\n' || c == '\r')
         break;
      valueEnd++;
   }
   
   return StringSubstr(json, valueStart, valueEnd - valueStart);
}

//+------------------------------------------------------------------+
//| Simple JSON integer value parser                                  |
//+------------------------------------------------------------------+
int CLicenseManager::JsonGetInt(string json, string key)
{
   string value = JsonGetString(json, key);
   if(value == "" || value == "null") return 0;
   return (int)StringToInteger(value);
}

//+------------------------------------------------------------------+
//| Simple JSON boolean value parser                                  |
//+------------------------------------------------------------------+
bool CLicenseManager::JsonGetBool(string json, string key)
{
   string value = JsonGetString(json, key);
   return (value == "true");
}
//+------------------------------------------------------------------+
