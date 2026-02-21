

## Gold Miner EA v2.8 - เพิ่ม License Check, News Filter, Time Filter

ใช้ **Moneyx Smart Gold System v5.34** (`src/pages/MT5EAGuide.tsx`) เป็นต้นแบบตรงตามที่ระบุ คัดลอก functions จากระบบเดิมนี้โดยตรง ไม่แตะต้องกลยุทธ์การเทรดหรือการออก/ปิดออเดอร์เดิม

---

### ไฟล์ที่แก้ไข

`public/docs/mql5/Gold_Miner_EA.mq5` (ไฟล์เดียว, version 2.70 -> 2.80)

---

### 1. เพิ่ม Enums + Structs (หลัง ENUM_TRADE_MODE)

คัดลอกจาก v5.34 บรรทัด 108-117, 44-50, 819-827:

```text
// License Status
enum ENUM_LICENSE_STATUS { LICENSE_VALID, LICENSE_EXPIRING_SOON, LICENSE_EXPIRED, LICENSE_NOT_FOUND, LICENSE_SUSPENDED, LICENSE_ERROR };

// Sync Event Type
enum ENUM_SYNC_EVENT { SYNC_SCHEDULED, SYNC_ORDER_OPEN, SYNC_ORDER_CLOSE };

// News Event Structure
struct NewsEvent { string title; string country; datetime time; string impact; bool isRelevant; };
```

---

### 2. เพิ่ม Input Parameters (3 groups ใหม่)

คัดลอกจาก v5.34 แต่ปรับชื่อ header ให้ตรงกับ Gold Miner:

**License Settings** (จาก v5.34 บรรทัด 449-456):
```text
input group "=== License Settings ==="
input string   InpLicenseServer = "https://lkbhomsulgycxawwlnfh.supabase.co";
input int      InpLicenseCheckMinutes = 60;
input int      InpDataSyncMinutes = 5;
const string EA_API_SECRET = "moneyx-ea-secret-2024-secure-key-v1";
```

**Time Filter** (จาก v5.34 บรรทัด 380-403, format "hh:mm-hh:mm"):
```text
input group "=== Time Filter ==="
input bool     InpUseTimeFilter = false;
input string   InpSession1 = "03:10-12:40";    // Session #1 [hh:mm-hh:mm]
input string   InpSession2 = "15:10-22:00";    // Session #2 [hh:mm-hh:mm]
input string   InpSession3 = "";               // Session #3 [hh:mm-hh:mm]
input string   InpFridaySession1 = "03:10-12:40";
input string   InpFridaySession2 = "";
input string   InpFridaySession3 = "";
input bool     InpTradeMonday = true;
input bool     InpTradeTuesday = true;
input bool     InpTradeWednesday = true;
input bool     InpTradeThursday = true;
input bool     InpTradeFriday = true;
input bool     InpTradeSaturday = false;
input bool     InpTradeSunday = false;
```

**News Filter** (จาก v5.34 บรรทัด 405-434, รวม Custom Keywords):
```text
input group "=== News Filter ==="
input bool     InpEnableNewsFilter = false;
input bool     InpNewsUseChartCurrency = false;
input string   InpNewsCurrencies = "USD";
input bool     InpFilterLowNews = false;
input int      InpPauseBeforeLow = 60;
input int      InpPauseAfterLow = 30;
input bool     InpFilterMedNews = false;
input int      InpPauseBeforeMed = 60;
input int      InpPauseAfterMed = 30;
input bool     InpFilterHighNews = true;
input int      InpPauseBeforeHigh = 240;
input int      InpPauseAfterHigh = 240;
input bool     InpFilterCustomNews = true;
input string   InpCustomNewsKeywords = "PMI;Unemployment Claims;Non-Farm;FOMC;Fed Chair Powell";
input int      InpPauseBeforeCustom = 300;
input int      InpPauseAfterCustom = 300;
```

---

### 3. เพิ่ม Global Variables

คัดลอกจาก v5.34 บรรทัด 462-478 (License) และ 818-858 (News):

```text
// License Globals
bool              g_isLicenseValid = false;
bool              g_isTesterMode = false;
ENUM_LICENSE_STATUS g_licenseStatus = LICENSE_ERROR;
string            g_customerName = "";
string            g_packageType = "";
string            g_tradingSystem = "";
datetime          g_expiryDate = 0;
int               g_daysRemaining = 0;
bool              g_isLifetime = false;
string            g_lastLicenseError = "";
datetime          g_lastLicenseCheck = 0;
datetime          g_lastDataSync = 0;
datetime          g_lastExpiryPopup = 0;
string            g_licenseServerUrl = "";
int               g_licenseCheckInterval = 60;
int               g_dataSyncInterval = 5;

// News Filter Globals
NewsEvent g_newsEvents[];
int g_newsEventCount = 0;
datetime g_lastNewsRefresh = 0;
bool g_isNewsPaused = false;
string g_nextNewsTitle = "";
datetime g_nextNewsTime = 0;
string g_newsStatus = "OK";
datetime g_lastGoodNewsTime = 0;
bool g_usingCachedNews = false;
string g_newsCacheFile = "GoldMinerNewsCache.txt";
datetime g_lastFileCacheSave = 0;
bool g_webRequestConfigured = true;
datetime g_lastWebRequestCheck = 0;
datetime g_lastWebRequestAlert = 0;
int g_webRequestCheckInterval = 3600;
bool g_forceNewsRefresh = false;
bool g_lastPausedState = false;
string g_lastPauseKey = "";
datetime g_newsPauseEndTime = 0;
```

---

### 4. แก้ไข OnInit() - เพิ่ม guard ก่อน indicator handles

เพิ่มที่ต้น `OnInit()` ก่อนบรรทัด `trade.SetExpertMagicNumber(...)`:

```text
// === Tester Mode Detection ===
g_isTesterMode = IsTesterMode();

if(g_isTesterMode)
{
   Print("GOLD MINER EA - TESTER MODE");
   Print("License check skipped for backtesting");
   g_isLicenseValid = true;
   g_licenseStatus = LICENSE_VALID;
}
else
{
   Print("GOLD MINER EA - LIVE TRADING MODE");
   if(!InitLicense(InpLicenseServer, InpLicenseCheckMinutes, InpDataSyncMinutes))
      Print("License initialization failed: ", g_lastLicenseError);
   ShowLicensePopup(g_licenseStatus);
   if(g_isLicenseValid)
   {
      Print("License Valid - Customer: ", g_customerName);
      if(g_isLifetime) Print("License Type: LIFETIME");
      else Print("Expiry: ", TimeToString(g_expiryDate, TIME_DATE), " (", g_daysRemaining, " days)");
   }
}
```

เพิ่มที่ท้าย `OnInit()` (ก่อน `return INIT_SUCCEEDED`):

```text
// === News Filter Init ===
if(InpEnableNewsFilter)
{
   g_isNewsPaused = false;
   g_newsStatus = "";
   g_webRequestConfigured = true;
   g_forceNewsRefresh = true;
   LoadNewsCacheFromFile();
   CheckWebRequestConfiguration();
   RefreshNewsData();
}
```

---

### 5. แก้ไข OnTick() - เพิ่ม guard ก่อน trading logic

เพิ่มก่อนบรรทัด `if(g_eaStopped) return;`:

```text
// === LICENSE CHECK ===
if(!g_isTesterMode)
{
   if(!OnTickLicense())
   {
      // License invalid - stop trading
      return;
   }
}
if(!g_isLicenseValid && !g_isTesterMode) return;

// === NEWS FILTER - Refresh hourly ===
RefreshNewsData();

// === NEWS PAUSE CHECK ===
if(IsNewsTimePaused())
   return;

// === TIME FILTER CHECK ===
if(InpUseTimeFilter && !IsWithinTradingHours())
   return;
```

---

### 6. เพิ่ม OnTradeTransaction()

คัดลอกจาก v5.34 บรรทัด 1259-1367 แต่ตัดส่วน Hedge Mode ออก (Gold Miner ไม่มี Hedge):

```text
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   if(!g_isLicenseValid) return;
   if(MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_OPTIMIZATION)) return;
   
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      if(HistoryDealSelect(trans.deal))
      {
         ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
         long dealMagic = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
         
         if(dealMagic == MagicNumber || dealMagic == 0)
         {
            if(dealEntry == DEAL_ENTRY_IN)
               SyncAccountDataWithEvent(SYNC_ORDER_OPEN);
            else if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_INOUT)
               SyncAccountDataWithEvent(SYNC_ORDER_CLOSE);
         }
      }
   }
}
```

---

### 7. เพิ่ม Functions ใหม่ท้ายไฟล์ (ก่อน Dashboard section)

ทั้งหมดคัดลอกจาก v5.34 โดยตรง ปรับเฉพาะชื่อ EA:

| Function | แหล่งใน v5.34 | หมายเหตุ |
|----------|---------------|----------|
| `IsTesterMode()` | บรรทัด 863-869 | เหมือนเดิม |
| `InitLicense()` | บรรทัด 874-902 | เหมือนเดิม |
| `VerifyLicense()` | บรรทัด 907-924 | เหมือนเดิม |
| `ParseVerifyResponse()` | บรรทัด 929-966 | เหมือนเดิม |
| `SyncAccountData()` | บรรทัด 971-974 | wrapper |
| `SyncAccountDataWithEvent()` | บรรทัด 979-1084 | เปลี่ยน ea_name เป็น "Gold Miner EA" |
| `CalculatePortfolioStats()` | บรรทัด 1089-1170 (เดิมมีอยู่แล้วใน Licensed) | คัดลอกตรง |
| `BuildTradeHistoryJson()` | บรรทัด 1174-1254 | เหมือนเดิม |
| `OnTickLicense()` | บรรทัด 1373-1411 | เหมือนเดิม |
| `ShowLicensePopup()` | บรรทัด 1416-1488 | เปลี่ยนชื่อ EA |
| `SendLicenseRequest()` | บรรทัด 1493-1525 | เหมือนเดิม |
| `JsonGetString()` | บรรทัด 1530-1568 | เหมือนเดิม |
| `JsonGetInt()` | บรรทัด 1573-1579 | เหมือนเดิม |
| `JsonGetBool()` | บรรทัด 1584-1588 | เหมือนเดิม |
| `GetChartBaseCurrency()` | บรรทัด 7571-7579 | เหมือนเดิม |
| `GetChartQuoteCurrency()` | บรรทัด 7584-7590 | เหมือนเดิม |
| `IsCurrencyRelevant()` | บรรทัด 7595-7627 | เหมือนเดิม |
| `IsCustomNewsMatch()` | บรรทัด 7632-7661 | เหมือนเดิม |
| `ExtractJSONValue()` | บรรทัด 7728-7783 | เหมือนเดิม |
| `CheckWebRequestConfiguration()` | บรรทัด 7857-7921 | เหมือนเดิม |
| `ShowWebRequestSetupAlert()` | บรรทัด 7927-7961 | เปลี่ยนชื่อ EA |
| `RefreshNewsData()` | บรรทัด 7967-8345 | เหมือนเดิม (ใช้ MoneyX API) |
| `SaveNewsCacheToFile()` | บรรทัด 8350-8380 | เปลี่ยนชื่อ cache file |
| `LoadNewsCacheFromFile()` | บรรทัด 8385-8434 | เปลี่ยนชื่อ cache file |
| `GetNewsPauseDuration()` | บรรทัด 8441-8488 | เหมือนเดิม |
| `IsEventRelevantNow()` | บรรทัด 8495-8514 | เหมือนเดิม |
| `IsNewsTimePaused()` | บรรทัด 8519-8664 | เหมือนเดิม |
| `GetNewsCountdownString()` | บรรทัด 8669-8691 | เหมือนเดิม |
| `ParseTimeToMinutes()` | บรรทัด 11233-11249 | เหมือนเดิม |
| `IsTimeInSession()` | บรรทัด 11254-11279 | เหมือนเดิม |
| `IsTradableDay()` | บรรทัด 11284-11297 | เหมือนเดิม |
| `IsWithinTradingHours()` | บรรทัด 11302-11352 | เหมือนเดิม (3 sessions + Friday) |

---

### 8. Dashboard Update

เพิ่มแสดงสถานะ 3 โมดูลบน Dashboard (ก่อนแถว "Auto Re-Entry"):

```text
// License Status
DrawTableRow(row, "License", g_isTesterMode ? "TESTER" : 
   (g_isLicenseValid ? (g_isLifetime ? "LIFETIME" : IntegerToString(g_daysRemaining) + " days") : "INVALID"),
   g_isLicenseValid ? COLOR_PROFIT : COLOR_LOSS, COLOR_SECTION_INFO); row++;

// Time Filter
if(InpUseTimeFilter)
{
   DrawTableRow(row, "Time Filter", IsWithinTradingHours() ? "ACTIVE" : "PAUSED",
      IsWithinTradingHours() ? COLOR_PROFIT : COLOR_LOSS, COLOR_SECTION_INFO); row++;
}

// News Filter
if(InpEnableNewsFilter)
{
   DrawTableRow(row, "News", g_newsStatus,
      g_isNewsPaused ? COLOR_LOSS : COLOR_PROFIT, COLOR_SECTION_INFO); row++;
}
```

---

### 9. สิ่งที่ไม่เปลี่ยนแปลง (รับประกัน 100%)

- SMA Signal Logic (BUY/SELL)
- Grid Entry/Exit Logic (Loss + Profit sides)
- TP/SL/Trailing/Breakeven Logic (Average-Based + Per-Order)
- Accumulate Close Logic
- Drawdown Exit Logic (CheckDrawdownExit)
- ทุก function ที่เกี่ยวกับการเปิด/ปิดออเดอร์

โค้ดใหม่ทำหน้าที่เป็น **guard gate** ที่ต้น OnTick() เท่านั้น: ถ้า License/Time/News ไม่ผ่าน จะ `return` ก่อนเข้า trading logic

---

### 10. สรุป

- Version: 2.70 -> 2.80
- เพิ่มประมาณ ~800 บรรทัด (License ~250, News ~350, Time ~100, Sync ~100)
- ทุก function คัดลอกจาก **Moneyx Smart Gold System v5.34** ตามที่ระบุ
- ไม่แก้ไขบรรทัดเดิมใดๆ ในส่วน trading logic

