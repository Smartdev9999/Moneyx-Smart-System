//+------------------------------------------------------------------+
//|                                           Gold_Miner_SQ_EA.mq5   |
//|                                    Copyright 2025, MoneyX Smart  |
//|                Gold Miner EA v6.95 - MTF ZigZag+CDC+Grid+License |
//+------------------------------------------------------------------+
#property copyright "MoneyX"
#property link      "https://moneyx.com"
#property version   "6.95"
#property description "Gold Miner EA v6.95 - Hero Min Activation: new InpHero_MinOrdersToActivate gate so Hero only forms after side has >= N orders (default 5); keeps v6.94 survivor-only block + v6.93 same-side close"
#property strict

#include <Trade/Trade.mqh>

//--- Enums
enum ENUM_LOT_MODE
{
   LOT_ADD     = 0,  // Add Lot
   LOT_CUSTOM  = 1,  // Custom Lot
   LOT_MULTIPLY= 2   // Multiply Lot
};

// v6.29: Balance Guard Mode
enum ENUM_BALGUARD_MODE
{
   BALGUARD_FIXED   = 0,  // Fixed Target ($)
   BALGUARD_DYNAMIC = 1   // Dynamic (last flat balance)
};

// v6.78: Hedge Open Delay reference mode
enum ENUM_HEDGE_DELAY_MODE
{
   HDELAY_AFTER_LAST_OPEN  = 0,  // After last hedge OPEN
   HDELAY_AFTER_LAST_CLOSE = 1,  // After last hedge CLOSE
   HDELAY_BOTH             = 2   // Both (use the longer remaining time)
};

enum ENUM_GAP_TYPE
{
   GAP_FIXED   = 0,  // Fixed Points
   GAP_CUSTOM  = 1,  // Custom Distance
   GAP_ATR     = 2   // ATR-Based
};

enum ENUM_ATR_REF
{
   ATR_REF_INITIAL  = 0,  // From Initial Order (cumulative)
   ATR_REF_DYNAMIC  = 1   // From Last Grid Order
};

enum ENUM_SL_ACTION
{
   SL_CLOSE_POSITIONS = 0,  // Close Positions (Stop Loss)
   SL_CLOSE_ALL_STOP  = 1   // Close All & Stop EA
};

enum ENUM_TRADE_MODE
{
   TRADE_BUY_ONLY  = 0,  // Buy Only
   TRADE_SELL_ONLY = 1,  // Sell Only
   TRADE_BOTH      = 2   // Buy and Sell
};

enum ENUM_ENTRY_MODE
{
   ENTRY_SMA      = 0,  // SMA Mode (Original)
   ENTRY_ZIGZAG   = 1,  // ZigZag Multi-Timeframe Mode
   ENTRY_INSTANT  = 2   // Instant Mode (No Indicator)
};

// License Status Enumeration
enum ENUM_LICENSE_STATUS
{
   LICENSE_VALID,           // License Valid
   LICENSE_EXPIRING_SOON,   // License Expiring Soon (within 7 days)
   LICENSE_EXPIRED,         // License Expired
   LICENSE_NOT_FOUND,       // Account Not Registered
   LICENSE_SUSPENDED,       // License Suspended
   LICENSE_ERROR            // Connection Error
};

enum ENUM_DD_MODE
{
   DD_PERCENT       = 0,  // Percent (%)
   DD_FIXED_DOLLAR  = 1   // Fixed Dollar ($)
};

enum ENUM_HEDGE_TRIGGER
{
   HEDGE_TRIGGER_EXPANSION  = 0,  // Squeeze Expansion (Original)
   HEDGE_TRIGGER_DD_PERCENT = 1,  // Drawdown % per Side
   HEDGE_TRIGGER_DD_DOLLAR  = 2   // Drawdown $ per Side
};

// Sync Event Type (for real-time data sync)
enum ENUM_SYNC_EVENT
{
   SYNC_SCHEDULED,          // Scheduled sync (daily)
   SYNC_ORDER_OPEN,         // Order opened
   SYNC_ORDER_CLOSE         // Order closed
};

// News Event Structure
struct NewsEvent
{
   string   title;       // News title
   string   country;     // Currency (e.g., USD, EUR)
   datetime time;        // Event time
   string   impact;      // "Low", "Medium", "High"
   bool     isRelevant;  // Matches our filter criteria
};

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+

//--- General Settings
input group "=== General Settings ==="
input int              MagicNumber        = 202500;    // Magic Number
input int              MaxSlippage        = 30;        // Max Slippage (points)
input int              MaxOpenOrders      = 20;        // Max Open Orders
input ENUM_DD_MODE     DrawdownMode       = DD_PERCENT; // Drawdown Mode (% or Fixed $)
input double           MaxDrawdownPct     = 30.0;      // Max Drawdown % (when mode = %)
input double           MaxDrawdownDollar  = 5000.0;    // Max Drawdown $ (when mode = Fixed $)
input bool             StopEAOnDrawdown   = false;     // Stop EA after Emergency Drawdown Close
input ENUM_TRADE_MODE  TradingMode        = TRADE_BOTH; // Trading Mode (Buy/Sell/Both)
input ENUM_ENTRY_MODE  EntryMode          = ENTRY_SMA;  // Entry Mode (SMA=Original, ZigZag=MTF)

//--- v6.93: Hero Order ---
input group "===== Hero Order (v6.93) ====="
input bool   InpHero_Enabled            = false; // Enable Hero Order (exclude N newest from basket avg/PL/trail)
input int    InpHero_OrderCount         = 2;     // Hero count per (gen, side)
input bool   InpHero_CloseWithOpposite  = true;  // Close Hero WITH same-side basket trail/TP (v6.93: was opposite)
input bool   InpHero_RequireNetProfit   = false; // Only close Hero if Hero PL >= 0
input bool   InpHero_BlockSameSideGrid  = true;  // Block new INIT/GL/GP on side that has Hero
input bool   InpHero_IncludeInMaxOrders = true;  // Count Hero into MaxOpenOrders

//--- SMA Indicator
input group "=== SMA Indicator ==="
input int               SMA_Period       = 20;              // SMA Period
input ENUM_APPLIED_PRICE SMA_AppliedPrice = PRICE_CLOSE;    // SMA Applied Price
input ENUM_TIMEFRAMES   SMA_Timeframe    = PERIOD_CURRENT;  // SMA Timeframe
input bool              EnableAutoReEntry = true;            // Auto Re-Entry when signal persists
input bool              DontOpenSameCandle= true;            // Don't Open in Same Initial Candle

//--- Initial Lot
input group "=== Initial Lot ==="
input double   InitialLotSize     = 0.01;     // Initial Lot Size
input double   InpMaxLotSize      = 0.0;      // Max Lot Size (0=No Limit)

//--- Grid Loss Side
input group "=== Grid Loss Side ==="
input int            GridLoss_MaxTrades      = 5;          // Max Grid Loss Trades
input ENUM_LOT_MODE  GridLoss_LotMode        = LOT_ADD;    // Grid Loss Lot Mode
input string         GridLoss_CustomLots     = "0.01;0.02;0.03;0.04;0.05"; // Custom Lots (semicolon separated)
input double         GridLoss_AddLotPerLevel = 0.4;        // Add Lot per Level (multiplied by InitialLot)
input double         GridLoss_MultiplyFactor = 2.0;        // Multiply Factor (for Multiply mode)
input ENUM_GAP_TYPE  GridLoss_GapType        = GAP_FIXED;  // Grid Loss Gap Type
input int            GridLoss_Points         = 500;        // Grid Loss Distance (points)
input string         GridLoss_CustomDistance  = "100;200;300;400;500"; // Custom Distance (points, semicolon)
input ENUM_TIMEFRAMES GridLoss_ATR_TF        = PERIOD_H1;  // ATR Timeframe
input int            GridLoss_ATR_Period     = 14;         // ATR Period
input double         GridLoss_ATR_Multiplier = 1.5;        // ATR Multiplier
input ENUM_ATR_REF   GridLoss_ATR_Reference  = ATR_REF_DYNAMIC; // ATR Reference Point
input int            GridLoss_MinGapPoints   = 100;             // Minimum Grid Gap (points)
input int            GridLoss_CandleConfirm  = 0;               // v6.40: Require N confirming candles before GL (0=Off)

//--- Max Grid Average Trailing Stop (v6.41, v6.54)
input group "=== Max Grid Average Trailing Stop ==="
input bool           MaxGrid_TrailEnable     = false;             // Enable Max Grid Avg Trailing
input int            MaxGrid_TrailMode       = 0;                 // Mode: 0=Max Order Grid, 1=Start Order Grid
input int            MaxGrid_StartOrders     = 10;                // Start Trail at N orders (Mode 1 only)
input int            MaxGrid_TrailActivation = 100;               // Activation (points from average, 0=Off)
input int            MaxGrid_TrailStep       = 50;                // Trailing Step (points)
input int            MaxGrid_BreakevenBuffer = 10;                // Breakeven Buffer (points above/below avg)
input bool           GridLoss_OnlyInSignal   = false;      // Grid Only in Signal Direction
input bool           GridLoss_OnlyNewCandle  = true;       // Grid Only on New Candle
input bool           GridLoss_DontSameCandle = true;       // Don't Open Grid in Same Candle as Initial

//--- Grid Profit Side
input group "=== Grid Profit Side ==="
input bool           GridProfit_Enable       = true;       // Enable Profit Grid
input int            GridProfit_MaxTrades    = 3;          // Max Grid Profit Trades
input ENUM_LOT_MODE  GridProfit_LotMode      = LOT_ADD;    // Grid Profit Lot Mode
input string         GridProfit_CustomLots   = "0.01;0.02;0.03"; // Custom Lots
input double         GridProfit_AddLotPerLevel= 0.2;       // Add Lot per Level
input double         GridProfit_MultiplyFactor= 1.5;       // Multiply Factor
input ENUM_GAP_TYPE  GridProfit_GapType      = GAP_FIXED;  // Grid Profit Gap Type
input int            GridProfit_Points       = 300;        // Grid Profit Distance (points)
input string         GridProfit_CustomDistance= "100;200;500"; // Custom Distance
input ENUM_TIMEFRAMES GridProfit_ATR_TF      = PERIOD_H1;  // ATR Timeframe
input int            GridProfit_ATR_Period   = 14;         // ATR Period
input double         GridProfit_ATR_Multiplier= 1.0;       // ATR Multiplier
input ENUM_ATR_REF   GridProfit_ATR_Reference = ATR_REF_DYNAMIC; // ATR Reference Point
input int            GridProfit_MinGapPoints  = 100;             // Minimum Grid Gap (points)
input bool           GridProfit_OnlyNewCandle= true;       // Grid Only on New Candle
input int            GridProfit_CandleConfirm= 0;          // v6.82: Require N confirming candles before GP (0=Off)

//--- Take Profit
input group "=== Take Profit ==="
input bool     UseTP_Dollar        = true;     // Use TP Fixed Dollar
input double   TP_DollarAmount     = 100.0;    // TP Dollar Amount
input bool     UseTP_Points        = false;    // Use TP in Points (from Average)
input int      TP_Points           = 2000;     // TP Points from Average
input bool     UseTP_PercentBalance = false;   // Use TP % of Balance
input double   TP_PercentBalance   = 5.0;      // TP % of Balance
input bool     UseAccumulateClose  = false;    // Use Accumulate Close
input double   AccumulateTarget    = 20000.0;  // Accumulate Target ($)
input bool     UseTP_DDPercent     = false;    // Use TP % of Max Drawdown (per side)
input double   TP_DDPercent        = 10.0;     // TP DD % (profit target = X% of max DD)
input bool     ShowAverageLine     = true;          // Show Average Price Line
input bool     ShowTPLine          = true;          // Show TP Line
input color    AvgBuyLineColor     = clrDodgerBlue; // Average Buy Line Color
input color    AvgSellLineColor    = clrOrangeRed;  // Average Sell Line Color
input color    TPBuyLineColor      = clrLime;       // TP Buy Line Color
input color    TPSellLineColor     = clrMagenta;    // TP Sell Line Color

//--- Stop Loss
input group "=== Stop Loss ==="
input bool           EnableSL            = true;              // Enable Stop Loss
input ENUM_SL_ACTION SL_ActionMode       = SL_CLOSE_POSITIONS;// SL Action Mode
input bool           UseSL_Dollar        = true;              // Use SL Fixed Dollar
input double         SL_DollarAmount     = 50.0;              // SL Dollar Amount
input bool           UseSL_Points        = false;             // Use SL in Points (from Average)
input int            SL_Points           = 1000;              // SL Points from Average
input bool           UseSL_PercentBalance = false;            // Use SL % of Balance
input double         SL_PercentBalance   = 3.0;               // SL % of Balance
input bool           ShowSLLine          = true;              // Show SL Line
input color          SLLineColor         = clrRed;            // SL Line Color

//--- Trailing Stop (Average-Based)
input group "=== Trailing Stop (Average-Based) ==="
input bool     EnableTrailingStop   = false;   // Enable Average-Based Trailing Stop
input int      TrailingActivation   = 100;     // Trailing Activation (points from average)
input int      TrailingStep         = 50;      // Trailing Step (points from current price)
input int      BreakevenBuffer      = 10;      // Breakeven Buffer (points above/below average)
input bool     EnableBreakeven      = true;    // Enable Breakeven
input int      BreakevenActivation  = 50;      // Breakeven Activation (points from average)

//--- Per-Order Trailing Stop (NEW - Standard Breakeven + Trailing)
input group "=== Per-Order Trailing Stop ==="
input bool     EnablePerOrderTrailing    = true;     // Enable Per-Order Trailing
input bool     InpEnableBreakeven        = true;     // Enable Breakeven
input int      InpBreakevenTarget        = 200;      // Breakeven Target (profit points to activate)
input int      InpBreakevenOffset        = 5;        // Breakeven Offset (points above/below open)
input bool     InpEnableTrailing         = true;     // Enable Trailing
input int      InpTrailingStop           = 200;      // Trailing Distance (points from current price)
input int      InpTrailingStep           = 10;       // Trailing Step (min SL movement in points)

//--- v6.56: Bollinger Band Entry Filter
input group "=== Bollinger Band Entry Filter (v6.56) ==="
input bool             BB_FilterEnable    = false;       // Enable BB Entry Filter
input ENUM_TIMEFRAMES  BB_Timeframe       = PERIOD_M15;  // BB Timeframe
input int              BB_Period          = 20;          // BB Period
input double           BB_Deviation       = 2.0;         // BB Deviation (StdDev)
input int              BB_ProximityPips   = 100;         // Block range near each band (points)
input int              BB_BlockMode       = 0;           // 0=Block Both Sides, 1=Block Counter-Trend Only

//--- Dashboard
input group "=== Dashboard ==="
input bool     ShowDashboard        = true;    // Show Dashboard
input int      DashboardX           = 20;      // Dashboard X Position
input int      DashboardY           = 30;      // Dashboard Y Position
input color    DashboardColor       = clrWhite; // Dashboard Text Color
input double   DashboardScale       = 1.0;     // Dashboard Scale (0.8-1.5)
input int      DashboardWidth       = 340;     // Dashboard Width (pixels, default 340)

//--- Rebate Settings
input group "=== Rebate Settings ==="
input double   InpRebatePerLot      = 4.5;     // Rebate per Lot ($)

//--- Backtest Optimization
input group "=== Backtest Optimization ==="
input bool     InpSkipATRInTester   = true;    // Skip ATR Indicator in Tester (use Simplified)

//--- License Settings
input group "=== License Settings ==="
input string   InpLicenseServer     = "https://lkbhomsulgycxawwlnfh.supabase.co";  // License Server URL
input int      InpLicenseCheckMinutes = 60;    // License Check Interval (minutes)
input int      InpDataSyncMinutes   = 5;       // Account Data Sync Interval (minutes)

// ====== HARDCODED API SECRET - DO NOT MODIFY ======
const string EA_API_SECRET = "moneyx-ea-secret-2024-secure-key-v1";

//--- Time Filter
input group "=== Time Filter ==="
input bool     InpUseTimeFilter     = false;           // Use Time Filter
input string   InpSession1          = "03:10-12:40";   // Tradable Session #1 [hh:mm-hh:mm]
input string   InpSession2          = "15:10-22:00";   // Tradable Session #2 [hh:mm-hh:mm]
input string   InpSession3          = "";              // Tradable Session #3 [hh:mm-hh:mm]
input string   InpFridaySession1    = "03:10-12:40";   // Friday Session #1 [hh:mm-hh:mm]
input string   InpFridaySession2    = "";              // Friday Session #2 [hh:mm-hh:mm]
input string   InpFridaySession3    = "";              // Friday Session #3 [hh:mm-hh:mm]
input bool     InpTradeMonday       = true;            // Monday
input bool     InpTradeTuesday      = true;            // Tuesday
input bool     InpTradeWednesday    = true;            // Wednesday
input bool     InpTradeThursday     = true;            // Thursday
input bool     InpTradeFriday       = true;            // Friday
input bool     InpTradeSaturday     = false;           // Saturday
input bool     InpTradeSunday       = false;           // Sunday

//--- News Filter
input group "=== News Filter ==="
//--- Daily Profit Pause
input group "=== Daily Profit Pause ==="
input bool     InpEnableDailyProfitPause = false;    // Enable Daily Profit Pause
input double   InpDailyProfitTarget      = 100.0;    // Daily Profit Target ($)

input bool     InpEnableNewsFilter   = false;          // Enable News Filter
input bool     InpNewsUseChartCurrency = false;        // Current Chart Currencies to Filter News
input string   InpNewsCurrencies     = "USD";          // Select Currency to Filter News (e.g. USD;EUR;GBP)
input bool     InpFilterLowNews      = false;          // Filter Low Impact News
input int      InpPauseBeforeLow     = 60;             // Pause Before a Low News (Min.)
input int      InpPauseAfterLow      = 30;             // Pause After a Low News (Min.)
input bool     InpFilterMedNews      = false;          // Filter Medium Impact News
input int      InpPauseBeforeMed     = 60;             // Pause Before a Medium News (Min.)
input int      InpPauseAfterMed      = 30;             // Pause After a Medium News (Min.)
input bool     InpFilterHighNews     = true;           // Filter High Impact News
input int      InpPauseBeforeHigh    = 240;            // Pause Before a High News (Min.)
input int      InpPauseAfterHigh     = 240;            // Pause After a High News (Min.)
input bool     InpFilterCustomNews   = true;           // Filter Custom News
input string   InpCustomNewsKeywords = "PMI;Unemployment Claims;Non-Farm;FOMC;Fed Chair Powell";  // Put News Title - Separate by semicolon(;)
input int      InpPauseBeforeCustom  = 300;            // Pause Before a Custom News (Min.)
input int      InpPauseAfterCustom   = 300;            // Pause After a Custom News (Min.)

//--- ZigZag Multi-Timeframe Settings
input group "=== ZigZag Multi-Timeframe Settings ==="
input int              ZZ_Depth            = 12;               // ZigZag Depth
input int              ZZ_Deviation        = 5;                // ZigZag Deviation
input int              ZZ_Backstep         = 3;                // ZigZag Backstep
input ENUM_TIMEFRAMES  ZZ_ConfirmTF        = PERIOD_H4;        // Confirm Timeframe (H4)
input bool             ZZ_UseM30           = true;             // Use M30 for Entry
input bool             ZZ_UseM15           = true;             // Use M15 for Entry
input bool             ZZ_UseM5            = false;            // Use M5 for Entry
input bool             ZZ_UseConfirmTFEntry= false;            // Also Enter on Confirm TF directly

//--- CDC Action Zone Trend Filter
input group "=== CDC Action Zone Trend Filter ==="
input bool             InpUseCDCFilter     = false;            // Enable CDC Trend Filter
input ENUM_TIMEFRAMES  InpCDCTimeframe     = PERIOD_D1;        // CDC Timeframe
input int              InpCDCFastPeriod    = 12;               // CDC Fast EMA Period
input int              InpCDCSlowPeriod    = 26;               // CDC Slow EMA Period
input bool             InpCDCRequireCross  = false;            // Require Crossover (not just position)

//--- Matching Close (Pair Profit vs Loss Orders)
input group "=== Matching Close ==="
input bool     UseMatchingClose       = false;    // Enable Matching Close
input double   MatchingMinProfit      = 0.50;     // Min Net Profit per Match ($)
input int      MatchingMaxLossOrders  = 3;        // Max Loss Orders per Match (1-10)
input int      MatchingMinProfitOrders = 1;       // Min Profit Orders to Start Matching
input int      MatchingMinTotalOrders  = 0;        // Min Total Orders to Activate (0=Always)

//--- Volatility Squeeze Filter (BB vs KC)
input group "=== Volatility Squeeze Filter ==="
input bool             InpUseSqueezeFilter      = false;          // Enable Squeeze Filter
input ENUM_TIMEFRAMES  InpSqueeze_TF1           = PERIOD_M5;      // Timeframe 1
input ENUM_TIMEFRAMES  InpSqueeze_TF2           = PERIOD_H1;      // Timeframe 2
input ENUM_TIMEFRAMES  InpSqueeze_TF3           = PERIOD_H4;      // Timeframe 3
input int              InpSqueeze_BB_Period     = 20;              // BB Period
input double           InpSqueeze_BB_Mult       = 2.0;            // BB Multiplier
input int              InpSqueeze_KC_Period     = 20;              // KC Period (EMA)
input double           InpSqueeze_KC_Mult       = 1.5;            // KC Multiplier (ATR)
input int              InpSqueeze_ATR_Period    = 14;              // ATR Period for KC
input double           InpSqueeze_ExpThreshold  = 1.5;            // Expansion Threshold (Intensity ratio)
input bool             InpSqueeze_BlockOnExpansion = true;         // Block New Orders on Expansion
input int              InpSqueeze_MinTFExpansion = 1;              // Min TFs in Expansion to Block (1-3)
input bool             InpSqueeze_DirectionalBlock = false;        // Directional Block (block counter-trend only)
input bool             InpSqueeze_CloseOnExpansion = false;        // Close All Orders on Expansion
input bool             InpSqueeze_PauseTrailing    = true;         // v6.87: Pause Trailing Stop on Expansion (resume when Normal)
input int              InpSqueeze_PauseTrail_MinTF = 1;            // v6.88: Min TFs in Expansion to Pause Trailing (1-3, independent of Block)
input bool             InpSqueeze_PauseTrail_StripSL = true;       // v6.89: On Pause edge, strip broker SL from trailing-owned tickets (INIT/GL/GP)
input bool             InpMaxGridTrail_IncludeINITGP = true;       // v6.90: MaxGridTrail trigger counts INIT+GL+GP (false = GL only, v6.89 behavior)
input string           ___MaxGrid_2Cross___ = "===== Max Grid Trail 2-Cross ARM (v6.91) =====";
input bool             InpMaxGridArm_Strict2Cross    = true;       // v6.91: Require price to first cross BELOW avg before ARM (true = safety net mode)
input int              InpMaxGridArm_UnderAvgBuffer  = 0;          // v6.91: Points BELOW avg required to mark ARM-READY (0 = touching avg is enough)

//--- Counter-Trend Hedging
input group "=== Counter-Trend Hedging ==="
input bool     InpHedge_Enable              = false;   // Enable Hedging Mode (requires Squeeze Filter)
input ENUM_HEDGE_TRIGGER InpHedge_TriggerMode = HEDGE_TRIGGER_EXPANSION; // Hedge Trigger Mode
input double   InpHedge_MatchMinProfit      = 5.0;     // Min Profit for Hedge Matching ($)
input int      InpHedge_MatchMinProfitOrders = 2;      // Min Profit Orders for Hedge Grid Matching
input double   InpHedge_PartialMinProfit    = 5.0;     // Min Profit for Partial Close ($)
input int      InpHedge_PartialMinProfitOrders = 3;    // Min Profit Orders for Partial Close (0=Always)
input int      InpHedge_MaxSets              = 10;    // Max Active Hedge Sets (1-50)
input int      InpHedge_BoundAvgTPPoints     = 0;     // Bound Avg TP Points (0=Disabled)
input int      InpHedge_MinTFConfirm         = 1;     // Min TF Expansion to Confirm Hedge (1-3)
input int      InpHedge_CloseMinPoints       = 300;   // v6.15: Min points from zone edge before matching close
// v6.16: DD% Hedge Trigger inputs
input double   InpHedge_DDTriggerPct         = 5.0;   // DD% to trigger first hedge (per side)
input double   InpHedge_DDStepPct            = 5.0;   // [LEGACY] DD% step — not used since v6.21 (constant threshold per gen)
input int      InpHedge_DDCooldownSec        = 60;    // Min seconds between DD hedges
input int      InpHedge_SidePauseMin         = 0;     // v6.39: Pause hedged side entries (minutes, 0=Off)
// v6.78: Hedge Open Delay (นาที) — กัน false signal โดยบังคับรอเวลาก่อนเปิด hedge รอบใหม่
input int                   InpHedge_OpenDelayMin  = 0;                  // v6.78: Hedge Open Delay (minutes, 0=Off, e.g. 30)
input ENUM_HEDGE_DELAY_MODE InpHedge_OpenDelayMode = HDELAY_BOTH;        // v6.78: Delay reference (Open/Close/Both)
input double   InpHedge_DDTriggerDollar      = 500.0; // v6.25: DD$ to trigger hedge (per side)
input bool     InpHedge_UseMatchingClose     = true;  // v6.51: Enable Hedge Recovery (false=only Balance Guard closes hedge)
// v6.28: Balance Guard — close all when equity recovers to target
input bool     InpBalanceGuard_Enable        = false;  // Balance Guard: Enable
input ENUM_BALGUARD_MODE InpBalanceGuard_Mode = BALGUARD_FIXED; // Balance Guard: Mode (Fixed / Dynamic)
input double   InpBalanceGuard_Target        = 1000.0; // Balance Guard: Target Equity ($) [Fixed mode]
input double   InpBalanceGuard_Profit        = 0.0;   // Balance Guard: Min Profit ($) added to target
// v6.15: Reverse Hedge disabled — kept as constants for legacy function compilation
const bool     InpHedge_ReverseEnable        = false;
const int      InpHedge_ReverseMinTFConfirm  = 2;
const double   InpHedge_ReverseMatchMinProfit = 0.50;

input group "=== Orphan Recovery Grid ==="
input bool     InpOrphan_Enable              = true;   // Enable Orphan Recovery Grid
input int      InpOrphan_ScanIntervalMin     = 15;     // Scan Interval (Minutes)

// === v6.57: Recovery Grid (separate from GridLoss) ===
input group "=== Recovery Grid (Bound/Orphan Orders) ==="
input bool           Recovery_UseSeparate    = false;                       // Use separate Recovery settings (false=use GridLoss_*)
input int            Recovery_MaxTrades      = 5;                           // Recovery Max Grid Trades
input ENUM_LOT_MODE  Recovery_LotMode        = LOT_ADD;                     // Recovery Lot Mode
input string         Recovery_CustomLots     = "0.01;0.02;0.03;0.04;0.05"; // Recovery Custom Lots
input double         Recovery_AddLotPerLevel = 0.4;                         // Recovery Add Lot per Level
input double         Recovery_MultiplyFactor = 2.0;                         // Recovery Multiply Factor
input ENUM_GAP_TYPE  Recovery_GapType        = GAP_FIXED;                   // Recovery Gap Type
input int            Recovery_Points         = 500;                         // Recovery Distance (points)
input string         Recovery_CustomDistance = "100;200;300;400;500";       // Recovery Custom Distance
input ENUM_TIMEFRAMES Recovery_ATR_TF        = PERIOD_H1;                   // Recovery ATR Timeframe
input int            Recovery_ATR_Period     = 14;                          // Recovery ATR Period
input double         Recovery_ATR_Multiplier = 1.5;                         // Recovery ATR Multiplier
input ENUM_ATR_REF   Recovery_ATR_Reference  = ATR_REF_DYNAMIC;             // Recovery ATR Reference
input int            Recovery_MinGapPoints   = 100;                         // Recovery Min Grid Gap (points)
input int            Recovery_CandleConfirm  = 0;                           // Recovery Candle Confirm (0=Off)

// === v6.57: Sequential Hedge Recovery ===
input group "=== Sequential Hedge Recovery ==="
input bool   InpHedge_SequentialRecovery = true;   // true=close oldest hedge set first (H1→H2→H3), false=close any (legacy)
input int    InpHedge_SequentialUnlockDelayMin = 1; // v6.69: Delay before next hedge set unlock after previous set/owner closes (minutes, 0=Off)
input bool   InpHedge_AllowProfitBypass = false;   // v6.70: true=allow profitable hedge to close out of FIFO order, false=STRICT FIFO (default)
input bool   InpCrossGen_InitGuard      = true;    // v6.73: block new-gen INIT while older-gen same-side orders are still free (not hedged)
input bool   InpOwnerAutoAdvance        = true;    // v6.73: auto-advance sequential recovery owner to next remaining gen when current gen flat
input bool   InpHedge_NoReHedgeReleased = true;    // v6.73: tickets released from any hedge set never get re-hedged (let grid recover)
input bool   InpHedge_NoReHedgeGenSide  = true;    // v6.74: ทั้ง gen+side ที่เคย hedge แล้วถูกปล่อยจะไม่ถูก hedge ซ้ำอีกจน flat
input bool   InpHedge_CloseOppositeSurvivors = false; // v6.81: Close opposite-side survivors of same gen on hedge open (fix Cross-Gen INIT block)
input string InpHedge_CloseOppSurvivorsNote  = "Closes BUY survivors of GM4 when SELL hedge fires on GM4 -> next gen starts clean";

// === v6.61: Recovery Shred & Seed ===
input group "=== Recovery Shred & Seed (v6.61) ==="
input bool   InpHedge_ShredOnMatch         = true;  // Shred bound losers using hedge profit (oldest first)
input bool   InpHedge_ShredHedgeOnProfit   = true;  // Shred hedge proportionally when bound side is profitable
input double InpHedge_ShredMinNetProfit    = 1.0;   // Min net $ kept after each shred
input double InpRecovery_SeedTargetLots    = 1.0;   // Target cumulative lots for recovery seed selection
input bool   InpRecovery_StripHedgeComment = true;  // Treat hedge remainder as recovery seed (logical strip)
//+------------------------------------------------------------------+
//| Global Variables                                                   |
//+------------------------------------------------------------------+
CTrade         trade;
int            handleSMA;
int            handleATR_Loss;
int            handleATR_Profit;
int            g_bbHandle = INVALID_HANDLE;       // v6.56: Bollinger Band Entry Filter handle
double         bufSMA[];
double         bufATR_Loss[];
double         bufATR_Profit[];
datetime       lastBarTime;
datetime       lastInitialCandleTime;
datetime       lastGridLossCandleTime;
datetime       lastGridProfitCandleTime;
bool           justClosedBuy;
bool           justClosedSell;
double         g_trailingSL_Buy;
double         g_trailingSL_Sell;
bool           g_trailingActive_Buy;
bool           g_trailingActive_Sell;
bool           g_breakevenDone_Buy;
bool           g_breakevenDone_Sell;
bool           g_eaStopped;
double         g_accumulatedProfit;
double         g_initialBuyPrice;   // track initial order price for grid fallback
double         g_initialSellPrice;  // track initial order price for grid fallback
double         g_accumulateBaseline; // Total history profit at last cycle reset
double         g_maxDD;             // Track max drawdown
bool           g_hadPositions;      // Track if we had positions (for accumulate auto-reset)
double         g_maxDDBuy;          // Max drawdown (most negative PL) of BUY side - for DD% TP
double         g_maxDDSell;         // Max drawdown (most negative PL) of SELL side - for DD% TP

// Dashboard Control Variables (v2.9)
bool           g_eaIsPaused = false;           // EA Pause State (manual)
bool           g_atrChartHidden = false;       // ATR subwindow hidden flag (backtest)
int            g_atrHideAttempts = 0;          // ATR hide retry counter

// Daily Profit Pause Variables
bool           g_dailyProfitPaused   = false;  // Daily profit target reached
datetime       g_dailyProfitPauseDay = 0;      // Day when pause was triggered
double         g_dailyStartBalance   = 0;      // v6.32: Balance snapshot at day start

// License Verification Variables
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

// News Filter Variables
NewsEvent g_newsEvents[];
int g_newsEventCount = 0;
datetime g_lastNewsRefresh = 0;
bool g_isNewsPaused = false;
bool g_newOrderBlocked = false;  // true = News/Time filter blocks new entries only
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

// === ZigZag Multi-Timeframe State (v3.0) ===
struct TFState
{
   ENUM_TIMEFRAMES tf;
   string          tfLabel;
   bool            enabled;
   int             handleZZ;
   double          lastSwingPrice;
   string          lastSwingType;
   datetime        lastSwingTime;
   double          initialBuyPrice;
   double          initialSellPrice;
   datetime        lastInitialCandle;
   datetime        lastGridLossCandle;
   datetime        lastGridProfitCandle;
   bool            justClosedBuy;
   bool            justClosedSell;
   double          trailSL_Buy;
   double          trailSL_Sell;
   bool            trailActive_Buy;
   bool            trailActive_Sell;
   bool            beDone_Buy;
   bool            beDone_Sell;
};

#define MAX_SUB_TF 4
TFState  g_tfStates[MAX_SUB_TF];
int      g_activeTFCount = 0;
int      g_h4TFIndex = -1;
string   g_h4Direction = "NONE";
datetime g_lastH4Bar = 0;

// CDC Action Zone state
string   g_cdcTrend = "NEUTRAL";
double   g_cdcFast = 0;
double   g_cdcSlow = 0;
bool     g_cdcReady = false;
datetime g_lastCdcCandle = 0;

// === Volatility Squeeze Filter State ===
struct SqueezeState
{
   ENUM_TIMEFRAMES tf;
   string          tfLabel;
   int             handleBB;       // iBands handle
   int             handleATR;      // iATR handle for KC
   int             handleEMA;      // iMA handle for KC center
   int             state;          // 0=Normal, 1=Squeeze, 2=Expansion
   double          intensity;      // BB_Width / KC_Width
   int             direction;      // 1=Bullish, -1=Bearish, 0=Neutral (Close vs EMA)
};
SqueezeState g_squeeze[3];
bool         g_squeezeBlocked = false;     // true when expansion detected (all block)
bool         g_squeezeBuyBlocked  = false;  // directional: block BUY only
bool         g_squeezeSellBlocked = false;  // directional: block SELL only
bool         g_expansionCloseTriggered = false;  // cooldown for CloseAllOnExpansion

// === Counter-Trend Hedging State ===
#define MAX_HEDGE_SETS 50  // v6.36: expanded from 10 to support up to 50 sets
#define MAX_BOUND_TICKETS 50
struct HedgeSet
{
   bool     active;           // is this hedge set active?
   ulong    hedgeTicket;      // main hedge order ticket
   ENUM_POSITION_TYPE hedgeSide;  // BUY or SELL (hedge direction)
   double   hedgeLots;        // current remaining hedge lots
   double   originalTotalLots; // original total lots when hedge opened
   ENUM_POSITION_TYPE counterSide; // the side being hedged (opposite of hedgeSide)
   bool     gridMode;         // true = original orders gone, hedge running as grid
   int      gridLevel;        // current grid level in grid mode
   ulong    gridTickets[];    // tickets of hedge grid orders
   int      gridTicketCount;  // count of grid tickets
   string   commentPrefix;    // "GM_HEDGE_1", "GM_HEDGE_2", etc.
   ulong    boundTickets[];   // tickets of counter-side orders bound to this set
   int      boundTicketCount; // count of bound tickets
   int      boundGeneration;  // cycle generation of bound orders
   // === v6.11: Combined Grid Recovery (Track B) ===
   bool     combinedGridMode;   // Track B active (hedge+reverse combined recovery)
   int      combinedGridLevel;  // grid level for combined hedge+reverse
   double   combinedLots;       // combined lot size of hedge+reverse for recovery
   // === v6.13: Matching-first sequencing ===
   bool     matchingDone;       // true after matching cycle completes in this normal phase
   // === v6.15: Hedge Close Gate — Expansion Cycle + Price Zone + TP Distance ===
   bool     seenExpansionSinceHedge;   // has TF index 2 (largest) been in EXPANSION since hedge opened?
   bool     hedgedDuringExpansion;     // was hedge opened while TF index 2 was EXPANSION?
   double   zoneUpperPrice;            // max(oldest bound price, hedge price)
   double   zoneLowerPrice;            // min(oldest bound price, hedge price)
   double   hedgeOpenPrice;            // open price of main hedge order
   double   oldestBoundPrice;          // open price of oldest bound order
   // === v6.16: Hedge Trigger Type ===
   int      triggerType;               // 0 = expansion, 1 = DD%
   // === v6.57: Sequential Recovery ordering ===
   datetime hedgeOpenTime;             // open time of main hedge order (FIFO ordering)
};
HedgeSet g_hedgeSets[MAX_HEDGE_SETS];
int      g_hedgeSetCount = 0;
// === v6.59: Sequential Recovery Owner — locks recovery to one generation until flat ===
int      g_sequentialRecoveryGen      = -1;    // generation currently owning recovery lock
int      g_sequentialRecoverySetIdx   = -1;    // originating hedge set index (for dashboard/log)
bool     g_sequentialRecoveryActive   = false; // true → block all other sets and other-gen orphan recovery
bool     g_sequentialRecoveryCompletedThisTick = false; // one-tick handoff guard
// === v6.69: Sequential Unlock Delay (time-based cooldown ก่อนปลด hedge ชุดถัดไป) ===
datetime g_sequentialUnlockBlockedUntil = 0;   // unix time จนกว่าจะปลด set ถัดไปได้
int      g_sequentialUnlockSourceSetIdx = -1;  // ชุดต้นทางที่ทำให้เริ่ม cooldown (เพื่อ debug)
string   g_sequentialUnlockReason       = "";  // เหตุผลที่ arm cooldown
int      g_lastOrphanGLCount = 0;  // v6.63: dashboard counter for owner-gen orders missing Broker TP
int      g_hedgeIntegrityWarnCount = 0;  // v6.65: count of hedge sets with hedgeLots >> boundLots (>2x)
int      g_hedgeIntegrityCriticalCount = 0;  // v6.65: count of hedge sets with NO bound orders

// === v6.61: Recovery Seed (logically-stripped hedge remainders treated as gen orders) ===
ulong    g_recoverySeedTickets[];   // hedge remainders re-bound as recovery seed
int      g_recoverySeedGen[];       // parallel: generation each seed belongs to
double   g_recoverySeedOpenPrice[]; // parallel: original hedge open price (for avg TP calc)
int      g_recoverySeedCount = 0;

// === v6.61: Recovery Set Tracker — guarantees no skip across generations ===
struct RecoverySetTracker
{
   int    generation;
   ulong  tickets[];
   int    sourceHedgeIdx;
   bool   complete;
};
RecoverySetTracker g_recoverySets[];
int      g_recoverySetCount = 0;

// === v6.61: Last shred event (for dashboard) ===
double   g_lastShredHedgeFrom = 0;
double   g_lastShredHedgeTo   = 0;
int      g_lastShredBoundClosed = 0;
int      g_lastShredBoundRemain = 0;
double   g_lastShredNet       = 0;
datetime g_lastShredTime      = 0;
datetime g_lastHedgeGridTime = 0;  // cooldown timer for hedge grid orders
int      g_lastDashboardRowCount = 0;  // track previous tick row count for stale cleanup
bool     g_hedgeOrphanWarning = false;  // orphan hedge grid orders detected
int      g_cycleGeneration = 1;  // v6.62: starts at 1 (GM1). Incremented on each hedge open. Reset → 1.

// === v6.16: DD% Hedge Trigger State ===
double   g_nextBuyDDTrigger  = 5.0;    // DD% threshold for next BUY-side hedge
double   g_nextSellDDTrigger = 5.0;    // DD% threshold for next SELL-side hedge
datetime g_lastDDHedgeTime   = 0;      // cooldown tracker
datetime g_lastHedgeCloseTime = 0;     // v6.25: cooldown after hedge set close

// === v6.39: Hedge Side Pause State ===
datetime g_lastHedgeBuyTime  = 0;   // last time BUY orders got hedged → pause BUY entries
datetime g_lastHedgeSellTime = 0;   // last time SELL orders got hedged → pause SELL entries

// === v6.26: Previously-Hedged Tickets — prevent DD re-trigger on released orders ===
#define MAX_PREV_HEDGED 200
ulong    g_prevHedgedTickets[MAX_PREV_HEDGED];
int      g_prevHedgedCount = 0;

// === v6.74: Released Gen+Side Lock — prevent re-hedge of an entire (gen,side) ===
// Once a hedge set is released and bound orders go back to grid recovery, the
// SAME (boundGeneration, counterSide) is locked from being hedged again.
// Lock auto-clears when that gen+side has no live normal/recovery orders left.
#define MAX_RELEASED_LOCKS 100
struct ReleasedGenSideLock {
   int                 generation;
   ENUM_POSITION_TYPE  side;
   datetime            lockedAt;
   bool                active;
};
ReleasedGenSideLock g_releasedGenSide[MAX_RELEASED_LOCKS];
int      g_releasedGenSideCount = 0;

// === v6.28: Balance Guard State ===
bool g_balanceGuardActive = false;  // activated when hedge set opens
double g_balanceGuardDynamicTarget = 0; // v6.29: dynamic target — updated when flat

// === Reverse Hedge State (v6.11: array-based for multiple reverse hedges) ===
#define MAX_REVERSE_HEDGES 10
ulong    g_reverseHedgeTickets[MAX_REVERSE_HEDGES];
int      g_reverseHedgeCount = 0;
bool     g_hedgeBalancedLock = false;  // when totalBuy == totalSell → disable TP/SL/Matching

// === v6.41: Max Grid Average Trailing Stop State ===
double   g_maxGridTrailSL_Buy  = 0;
double   g_maxGridTrailSL_Sell = 0;
bool     g_maxGridTrailActive_Buy  = false;
bool     g_maxGridTrailActive_Sell = false;
int      g_maxGridMonitorGen = 0;  // generation currently being monitored

// === v6.91: Max Grid Trail Strict 2-Cross ARM state ===
bool     g_maxGridArmReady_Buy  = false;   // true once price has crossed BELOW avg for current monitored gen
bool     g_maxGridArmReady_Sell = false;   // true once price has crossed ABOVE avg for current monitored gen
int      g_maxGridArmReadyGen   = -1;      // gen that armReady flags refer to (auto-resets on gen change)

// === v6.89: Squeeze Pause Trailing edge state (true while in pause) ===
bool     g_squeezePauseTrailingActive = false;

// === v6.92: Hero Order state ===
ulong    g_heroTickets[200];
int      g_heroTicketCount        = 0;
datetime g_heroLastBuildTime      = 0;
int      g_heroOppCloseSide       = -1;     // POSITION_TYPE_BUY/SELL → side that should close its Hero
datetime g_heroOppCloseTime       = 0;
datetime g_heroLastBlockLog       = 0;
// === v6.42: Dashboard History Cache ===
datetime g_lastDashHistoryCalcTime = 0;
int      g_dashCacheIntervalSec    = 5;  // recalculate every 5 seconds
double   g_cachedClosedLots        = 0;
int      g_cachedClosedOrders      = 0;
double   g_cachedMonthlyPL         = 0;
double   g_cachedTotalPLHist       = 0;
double   g_cachedDailyClosedLots   = 0;

// === v6.42: Broker-Level TP/SL State ===
datetime g_lastBrokerTPSLSync      = 0;
int      g_brokerTPSLIntervalSec   = 2;  // sync every 2 seconds
double   g_lastBrokerTP_Buy        = 0;  // last TP price set for BUY
double   g_lastBrokerTP_Sell       = 0;  // last TP price set for SELL
double   g_lastBrokerSL_Buy        = 0;  // last SL price set for BUY
double   g_lastBrokerSL_Sell       = 0;  // last SL price set for SELL

// === v6.49: Deferred Sync Flags ===
bool     g_pendingSyncOrderOpen   = false;
bool     g_pendingSyncOrderClose  = false;

// v6.44: Dashboard render throttle
datetime g_lastDashboardRenderTime = 0;
int      g_dashRenderIntervalSec   = 1;  // render dashboard every 1 second only

// === Orphan Recovery System ===
datetime g_lastOrphanScanTime = 0;
datetime g_lastOrphanGridCandleTime = 0;  // Track candle time for orphan grid (OnlyNewCandle)

struct OrphanGenGroup {
   int    generation;       // e.g. 0 for "GM_GL"
   bool   active;
   int    buyCount;         // orphan buy orders of this gen
   int    sellCount;        // orphan sell orders of this gen
   int    gridLossBuyCount;
   int    gridLossSellCount;
   int    maxGridLevelBuy;
   int    maxGridLevelSell;
};
#define MAX_ORPHAN_GROUPS 5
OrphanGenGroup g_orphanGroups[MAX_ORPHAN_GROUPS];
int g_activeOrphanGroupCount = 0;

//+------------------------------------------------------------------+
//| Comment Generation Helpers                                         |
//+------------------------------------------------------------------+
// v6.62: comments start at GM1. gen=0 only kept for backward-compat reading legacy "GM_*" orders.
string GetCommentPrefix()
{
   int g = (g_cycleGeneration < 1) ? 1 : g_cycleGeneration;
   return "GM" + IntegerToString(g);
}

// === v6.53: Persist g_cycleGeneration via GlobalVariable ===
string GV_CycleGenKey() { return "GM_CycleGen_" + _Symbol + "_" + IntegerToString(MagicNumber); }

void SaveCycleGeneration()
{
   GlobalVariableSet(GV_CycleGenKey(), (double)g_cycleGeneration);
}

int LoadCycleGeneration()
{
   string key = GV_CycleGenKey();
   if(GlobalVariableCheck(key))
      return (int)GlobalVariableGet(key);
   return -1;  // not found
}

// Get prefix for a specific generation
// v6.62: gen 0 = legacy "GM" (read-only backward-compat). New cycles always >= 1 → "GM1", "GM2", ...
string GenPrefix(int gen)
{
   if(gen <= 0) return "GM";  // legacy reader only
   return "GM" + IntegerToString(gen);
}

// Match comment from any GM generation with a suffix (e.g. "_INIT", "_GL", "_GP")
bool MatchGMSuffix(string comment, string suffix)
{
   if(StringFind(comment, "GM") != 0) return false;
   return StringFind(comment, suffix) >= 0;
}

// Match comment that belongs to any GM generation for a specific TF
bool MatchTFPrefix(string comment, string tfLabel)
{
   if(StringFind(comment, "GM") != 0) return false;
   string tfToken = "_" + tfLabel + "_";
   return StringFind(comment, tfToken) >= 0;
}

// Extract cycle generation number from comment
// GM_INIT → 0, GM1_INIT → 1, GM2_INIT → 2
int ExtractGeneration(string comment)
{
   if(StringFind(comment, "GM") != 0) return -1;
   int pos = 2;  // after "GM"
   while(pos < StringLen(comment))
   {
      ushort ch = StringGetCharacter(comment, pos);
      if(ch >= '0' && ch <= '9') pos++;
      else break;
   }
   if(pos == 2) return 0;  // "GM_" = gen 0
   return (int)StringToInteger(StringSubstr(comment, 2, pos - 2));
}

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
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

   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetDeviationInPoints(MaxSlippage);
   trade.SetTypeFilling(ORDER_FILLING_IOC);

   //--- SMA handle
   handleSMA = iMA(_Symbol, SMA_Timeframe, SMA_Period, 0, MODE_SMA, SMA_AppliedPrice);
   if(handleSMA == INVALID_HANDLE)
   {
      Print("ERROR: Failed to create SMA handle");
      return INIT_FAILED;
   }

   //--- ATR handles for grid (skip in tester if InpSkipATRInTester)
   if(g_isTesterMode && InpSkipATRInTester)
   {
      handleATR_Loss = INVALID_HANDLE;
      handleATR_Profit = INVALID_HANDLE;
      Print("ATR indicator handles SKIPPED - using Simplified ATR for backtest speed");
   }
   else
   {
      handleATR_Loss = iATR(_Symbol, GridLoss_ATR_TF, GridLoss_ATR_Period);
      if(handleATR_Loss == INVALID_HANDLE)
      {
         Print("ERROR: Failed to create ATR Loss handle");
         return INIT_FAILED;
      }

      handleATR_Profit = iATR(_Symbol, GridProfit_ATR_TF, GridProfit_ATR_Period);
      if(handleATR_Profit == INVALID_HANDLE)
      {
         Print("ERROR: Failed to create ATR Profit handle");
         return INIT_FAILED;
      }
   }

   //--- v6.56: Bollinger Band Entry Filter handle
   if(BB_FilterEnable)
   {
      g_bbHandle = iBands(_Symbol, BB_Timeframe, BB_Period, 0, BB_Deviation, PRICE_CLOSE);
      if(g_bbHandle == INVALID_HANDLE)
      {
         Print("ERROR: Failed to create BB Filter handle");
         return INIT_FAILED;
      }
      Print("v6.56 BB Filter: ENABLED TF=", EnumToString(BB_Timeframe), " Period=", BB_Period, " Dev=", BB_Deviation, " Prox=", BB_ProximityPips, "p Mode=", BB_BlockMode);
   }

   //--- Init arrays
   ArraySetAsSeries(bufSMA, true);
   ArraySetAsSeries(bufATR_Loss, true);
   ArraySetAsSeries(bufATR_Profit, true);

   //--- Init globals
   lastBarTime = 0;
   lastInitialCandleTime = 0;
   lastGridLossCandleTime = 0;
   lastGridProfitCandleTime = 0;
   justClosedBuy = false;
   justClosedSell = false;
   g_trailingSL_Buy = 0;
   g_trailingSL_Sell = 0;
   g_trailingActive_Buy = false;
   g_trailingActive_Sell = false;
   g_breakevenDone_Buy = false;
   g_breakevenDone_Sell = false;
   g_eaStopped = false;
   g_accumulatedProfit = 0;
   g_initialBuyPrice = 0;
   g_initialSellPrice = 0;
   g_accumulateBaseline = 0;
   g_maxDD = 0;
   g_maxDDBuy = 0;
   g_maxDDSell = 0;
   g_hadPositions = (TotalOrderCount() > 0);  // detect if positions already exist on init

   //--- Calculate baseline for accumulate (FRESH START: only new deals count)
   if(UseAccumulateClose)
   {
      double totalHistory = CalcTotalHistoryProfit();
      g_accumulateBaseline = totalHistory;  // start fresh each EA load
      g_accumulatedProfit = 0;              // nothing accumulated yet
      Print("Accumulate init: baseline=", g_accumulateBaseline, " accumulated=0 (fresh start)");
   }

   //--- Recover initial prices from existing positions
   RecoverInitialPrices();

   // === ZigZag MTF Init (v3.0) ===
   if(EntryMode == ENTRY_ZIGZAG)
   {
      InitZigZagHandles();
      RecoverTFInitialPrices();
   }

   // === Squeeze Filter Init ===
   if(InpUseSqueezeFilter)
   {
      ENUM_TIMEFRAMES sqTFs[3];
      sqTFs[0] = InpSqueeze_TF1;
      sqTFs[1] = InpSqueeze_TF2;
      sqTFs[2] = InpSqueeze_TF3;
      string sqLabels[3];
      sqLabels[0] = TimeframeToString(InpSqueeze_TF1);
      sqLabels[1] = TimeframeToString(InpSqueeze_TF2);
      sqLabels[2] = TimeframeToString(InpSqueeze_TF3);

      for(int sq = 0; sq < 3; sq++)
      {
         g_squeeze[sq].tf = sqTFs[sq];
         g_squeeze[sq].tfLabel = sqLabels[sq];
         g_squeeze[sq].state = 0;
         g_squeeze[sq].intensity = 1.0;

         g_squeeze[sq].handleBB = iBands(_Symbol, sqTFs[sq], InpSqueeze_BB_Period, 0, InpSqueeze_BB_Mult, PRICE_CLOSE);
         g_squeeze[sq].handleEMA = iMA(_Symbol, sqTFs[sq], InpSqueeze_KC_Period, 0, MODE_EMA, PRICE_CLOSE);
         g_squeeze[sq].handleATR = iATR(_Symbol, sqTFs[sq], InpSqueeze_ATR_Period);

         if(g_squeeze[sq].handleBB == INVALID_HANDLE ||
            g_squeeze[sq].handleEMA == INVALID_HANDLE ||
            g_squeeze[sq].handleATR == INVALID_HANDLE)
         {
            Print("WARNING: Squeeze Filter handle creation failed for TF ", sqLabels[sq]);
         }
      }
      Print("Squeeze Filter initialized: ", sqLabels[0], " / ", sqLabels[1], " / ", sqLabels[2]);
   }

   // === Counter-Trend Hedging Init ===
   for(int h = 0; h < MAX_HEDGE_SETS; h++)
   {
      g_hedgeSets[h].active = false;
      g_hedgeSets[h].hedgeTicket = 0;
      g_hedgeSets[h].hedgeLots = 0;
      g_hedgeSets[h].originalTotalLots = 0;
      g_hedgeSets[h].gridMode = false;
      g_hedgeSets[h].gridLevel = 0;
      g_hedgeSets[h].gridTicketCount = 0;
      g_hedgeSets[h].combinedGridMode = false;
      g_hedgeSets[h].combinedGridLevel = 0;
      g_hedgeSets[h].combinedLots = 0;
      ArrayResize(g_hedgeSets[h].gridTickets, 0);
       g_hedgeSets[h].commentPrefix = "GM_HEDGE_" + IntegerToString(h + 1);
       g_hedgeSets[h].boundTicketCount = 0;
       ArrayResize(g_hedgeSets[h].boundTickets, 0);
       g_hedgeSets[h].boundGeneration = 0;
       // v6.15: Hedge Close Gate init
       g_hedgeSets[h].seenExpansionSinceHedge = false;
       g_hedgeSets[h].hedgedDuringExpansion = false;
       g_hedgeSets[h].zoneUpperPrice = 0;
       g_hedgeSets[h].zoneLowerPrice = 0;
       g_hedgeSets[h].hedgeOpenPrice = 0;
       g_hedgeSets[h].oldestBoundPrice = 0;
       // v6.16: Trigger type init
       g_hedgeSets[h].triggerType = 0;
       g_hedgeSets[h].hedgeOpenTime = 0;  // v6.57
     }
     g_hedgeSetCount = 0;

   // v6.16: Initialize DD% triggers
   g_nextBuyDDTrigger  = InpHedge_DDTriggerPct;
   g_nextSellDDTrigger = InpHedge_DDTriggerPct;
   g_lastDDHedgeTime   = 0;

   // === Recover Hedge Sets from existing positions (crash/restart recovery) ===
   int savedGen = LoadCycleGeneration();  // v6.53: load persisted generation
   RecoverHedgeSets();
   
   // v6.53: If saved gen is higher than recovered (e.g. hedge was closed externally), use saved
   if(savedGen > g_cycleGeneration)
   {
      g_cycleGeneration = savedGen;
      Print("v6.53: Restored g_cycleGeneration from GlobalVariable = ", savedGen);
   }

   // v6.29: Initialize dynamic balance guard target
   if(InpBalanceGuard_Enable && InpBalanceGuard_Mode == BALGUARD_DYNAMIC)
   {
      g_balanceGuardDynamicTarget = AccountInfoDouble(ACCOUNT_BALANCE);
      Print("v6.31 Balance Guard Dynamic: Initial target set to $", DoubleToString(g_balanceGuardDynamicTarget, 2));
   }

   // v6.32: Initialize daily start balance
   g_dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);

   // v6.92: Hero Order — reset state on init
   g_heroTicketCount = 0;
   g_heroLastBuildTime = 0;
   g_heroOppCloseSide = -1;
   g_heroOppCloseTime = 0;
   g_heroLastBlockLog = 0;
   
     Print("Gold Miner EA v6.94 initialized successfully | CycleGen=", g_cycleGeneration, " (base=GM1) | BalanceGuard=", InpBalanceGuard_Enable ? "ON" : "OFF",
          " | Mode=", InpBalanceGuard_Mode == BALGUARD_FIXED ? "Fixed" : "Dynamic",
          " | BalGuardProfit=", DoubleToString(InpBalanceGuard_Profit, 2),
          " | SidePause=", InpHedge_SidePauseMin, "min",
          " | HedgeOpenDelay=", InpHedge_OpenDelayMin, "min (mode=", (int)InpHedge_OpenDelayMode, ")",
          " | OppSurvClose=", InpHedge_CloseOppositeSurvivors ? "ON" : "OFF");

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

   // v6.44: Render dashboard immediately on attach (don't wait for first tick)
   if(ShowDashboard) DisplayDashboard();

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                    |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(handleSMA != INVALID_HANDLE) IndicatorRelease(handleSMA);
   if(handleATR_Loss != INVALID_HANDLE) IndicatorRelease(handleATR_Loss);
   if(handleATR_Profit != INVALID_HANDLE) IndicatorRelease(handleATR_Profit);
   if(g_bbHandle != INVALID_HANDLE) { IndicatorRelease(g_bbHandle); g_bbHandle = INVALID_HANDLE; } // v6.56

   // Release ZigZag indicator handles
   for(int zz = 0; zz < g_activeTFCount; zz++)
   {
      if(g_tfStates[zz].handleZZ != INVALID_HANDLE)
         IndicatorRelease(g_tfStates[zz].handleZZ);
   }

   // Release Squeeze Filter handles
   for(int sq = 0; sq < 3; sq++)
   {
      if(g_squeeze[sq].handleBB != INVALID_HANDLE) IndicatorRelease(g_squeeze[sq].handleBB);
      if(g_squeeze[sq].handleEMA != INVALID_HANDLE) IndicatorRelease(g_squeeze[sq].handleEMA);
      if(g_squeeze[sq].handleATR != INVALID_HANDLE) IndicatorRelease(g_squeeze[sq].handleATR);
   }

   ObjectDelete(0, "GM_AvgBuyLine");
   ObjectDelete(0, "GM_AvgSellLine");
   ObjectDelete(0, "GM_TPBuyLine");
   ObjectDelete(0, "GM_TPSellLine");
   ObjectDelete(0, "GM_SLLine");
   ObjectsDeleteAll(0, "GM_Dash_");
   ObjectsDeleteAll(0, "GM_TBL_");
   ObjectsDeleteAll(0, "GM_Btn");

   ObjectsDeleteAll(0, "GM_HED_");  // hedge dashboard objects

   SaveCycleGeneration();  // v6.53: persist before shutdown
   Print("Gold Miner EA v6.94 deinitialized");
}

//+------------------------------------------------------------------+
//| Recover initial order prices from open positions                   |
//+------------------------------------------------------------------+
void RecoverInitialPrices()
{
   //--- First pass: try to find INIT orders (current generation only)
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      string comment = PositionGetString(POSITION_COMMENT);
      // v6.23: Skip orders from previous generations
      int orderGen = ExtractGeneration(comment);
      if(orderGen >= 0 && orderGen != g_cycleGeneration) continue;
      if(MatchGMSuffix(comment, "_INIT"))
      {
         long posType = PositionGetInteger(POSITION_TYPE);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         if(posType == POSITION_TYPE_BUY)
            g_initialBuyPrice = openPrice;
         else if(posType == POSITION_TYPE_SELL)
            g_initialSellPrice = openPrice;
      }
   }

   //--- Second pass: fallback — if no INIT found, recover from oldest GL order (current gen)
   if(g_initialBuyPrice <= 0 || g_initialSellPrice <= 0)
   {
      datetime oldestBuyTime = D'2099.01.01';
      double   oldestBuyPrice = 0;
      datetime oldestSellTime = D'2099.01.01';
      double   oldestSellPrice = 0;

      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

         string comment = PositionGetString(POSITION_COMMENT);
         //--- Skip hedge/reverse hedge comments — only look at normal grid orders
         if(IsHedgeComment(comment) || IsReverseHedgeComment(comment)) continue;
         // v6.23: Skip orders from previous generations
         int orderGen = ExtractGeneration(comment);
         if(orderGen >= 0 && orderGen != g_cycleGeneration) continue;

         //--- Check for GL suffix (grid loss orders)
         if(StringFind(comment, "_GL") >= 0)
         {
            long posType = PositionGetInteger(POSITION_TYPE);
            datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
            double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);

            if(posType == POSITION_TYPE_BUY && g_initialBuyPrice <= 0)
            {
               if(openTime < oldestBuyTime)
               {
                  oldestBuyTime = openTime;
                  oldestBuyPrice = openPrice;
               }
            }
            else if(posType == POSITION_TYPE_SELL && g_initialSellPrice <= 0)
            {
               if(openTime < oldestSellTime)
               {
                  oldestSellTime = openTime;
                  oldestSellPrice = openPrice;
               }
            }
         }
      }

      if(g_initialBuyPrice <= 0 && oldestBuyPrice > 0)
      {
         g_initialBuyPrice = oldestBuyPrice;
         Print("RecoverInitialPrices: BUY INIT not found (gen=", g_cycleGeneration, "), recovered from oldest GL order price=", oldestBuyPrice);
      }
      if(g_initialSellPrice <= 0 && oldestSellPrice > 0)
      {
         g_initialSellPrice = oldestSellPrice;
         Print("RecoverInitialPrices: SELL INIT not found (gen=", g_cycleGeneration, "), recovered from oldest GL order price=", oldestSellPrice);
      }
   }
}

//+------------------------------------------------------------------+
//| CalcTotalHistoryProfit - sum all closed deal profit for this EA    |
//+------------------------------------------------------------------+
double CalcTotalHistoryProfit()
{
   double total = 0;
   if(!HistorySelect(0, TimeCurrent())) return 0;
   int totalDeals = HistoryDealsTotal();
   for(int i = 0; i < totalDeals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;
      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != MagicNumber) continue;
      if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) continue;
      long dealEntry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_INOUT)
      {
         total += HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                + HistoryDealGetDouble(dealTicket, DEAL_SWAP);
      }
   }
   return total;
}

//+------------------------------------------------------------------+
//| CalcTotalClosedLots - sum all closed deal volumes for this EA      |
//+------------------------------------------------------------------+
double CalcTotalClosedLots()
{
   double total = 0;
   if(!HistorySelect(0, TimeCurrent())) return 0;
   int totalDeals = HistoryDealsTotal();
   for(int i = 0; i < totalDeals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;
      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != MagicNumber) continue;
      if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) continue;
      long dealEntry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_INOUT)
         total += HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
   }
   return total;
}

//+------------------------------------------------------------------+
//| CalcDailyClosedLots - sum closed deal volumes for today             |
//+------------------------------------------------------------------+
double CalcDailyClosedLots()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   datetime dayStart = StructToTime(dt);

   double total = 0;
   if(!HistorySelect(dayStart, TimeCurrent())) return 0;
   int totalDeals = HistoryDealsTotal();
   for(int i = 0; i < totalDeals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;
      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != MagicNumber) continue;
      if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) continue;
      long dealEntry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_INOUT)
         total += HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
   }
   return total;
}

//+------------------------------------------------------------------+
//| CalcTotalClosedOrders - count closed deals for this EA             |
//+------------------------------------------------------------------+
int CalcTotalClosedOrders()
{
   int count = 0;
   if(!HistorySelect(0, TimeCurrent())) return 0;
   int totalDeals = HistoryDealsTotal();
   for(int i = 0; i < totalDeals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;
      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != MagicNumber) continue;
      if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) continue;
      long dealEntry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_INOUT)
         count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| CalcMonthlyPL - sum profit for deals closed this calendar month    |
//+------------------------------------------------------------------+
double CalcMonthlyPL()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.day = 1;
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   datetime monthStart = StructToTime(dt);

   double total = 0;
   if(!HistorySelect(monthStart, TimeCurrent())) return 0;
   int totalDeals = HistoryDealsTotal();
   for(int i = 0; i < totalDeals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;
      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != MagicNumber) continue;
      if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) continue;
      long dealEntry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_INOUT)
         total += HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                + HistoryDealGetDouble(dealTicket, DEAL_SWAP);
   }
   return total;
}

//+------------------------------------------------------------------+
//| CalcDailyPL - sum profit for deals closed today                    |
//+------------------------------------------------------------------+
double CalcDailyPL()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   datetime dayStart = StructToTime(dt);

   double total = 0;
   if(!HistorySelect(dayStart, TimeCurrent())) return 0;
   int totalDeals = HistoryDealsTotal();
   for(int i = 0; i < totalDeals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;
      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != MagicNumber) continue;
      if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) continue;
      long dealEntry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_INOUT)
         total += HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
                + HistoryDealGetDouble(dealTicket, DEAL_SWAP);
   }
   return total;
}

void OnTick()
{
   // v6.92: Hero Order — rebuild ticket cache + handle opposite-close signal
   BuildHeroTicketCache();
   ManageHeroOppositeClose();

   // === HIDE ATR CHART IN BACKTEST (v2.9 / v3.0 simplified) ===
   // When InpSkipATRInTester=true, no ATR handles exist so no subwindow is created.
   // Fallback: if handles exist (InpSkipATRInTester=false), try to hide subwindow.
   if(!g_atrChartHidden && (MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE)))
   {
      if(g_isTesterMode && InpSkipATRInTester)
      {
         g_atrChartHidden = true; // No ATR handle = no subwindow
      }
      else
      {
         g_atrHideAttempts++;
         int totalWindows = (int)ChartGetInteger(0, CHART_WINDOWS_TOTAL);
         bool found = false;
         for(int sw = totalWindows - 1; sw > 0; sw--)
         {
            int indCount = ChartIndicatorsTotal(0, sw);
            for(int j = indCount - 1; j >= 0; j--)
            {
               string indName = ChartIndicatorName(0, sw, j);
               if(StringFind(indName, "ATR") >= 0)
               {
                  ChartIndicatorDelete(0, sw, indName);
                  found = true;
               }
            }
         }
         if(found || g_atrHideAttempts >= 50)
         {
            g_atrChartHidden = true;
            ChartRedraw(0);
         }
      }
   }

   // === LICENSE CHECK ===
   if(!g_isTesterMode)
   {
      if(!OnTickLicense())
      {
         return;
      }
   }
   if(!g_isLicenseValid && !g_isTesterMode) return;

   // === NEWS FILTER - Refresh hourly ===
   RefreshNewsData();

    // === v6.57: Auto-reset cycle generation when account is fully flat ===
    // === v6.66: also re-anchor cycleGen when no active hedge but orphans remain ===
    // Catches cases where positions closed by manual / SL / external means and
    // TryResetCycleStateIfFlat was never invoked, leaving comments stuck at GMx.
    if(g_cycleGeneration > 1 && g_hedgeSetCount == 0)
    {
       TryResetCycleStateIfFlat("OnTick gen-anchor check");
    }

   // === Determine if new orders are blocked (News/Time/Pause) ===
   g_newOrderBlocked = false;

   // Manual Pause check (v2.9)
   if(g_eaIsPaused)
      g_newOrderBlocked = true;

   if(IsNewsTimePaused())
      g_newOrderBlocked = true;

   if(InpUseTimeFilter && !IsWithinTradingHours())
      g_newOrderBlocked = true;

   // === DAILY PROFIT PAUSE CHECK (v6.32: Equity-based, flat-only trigger) ===
   if(InpEnableDailyProfitPause)
   {
      MqlDateTime dtNow;
      TimeToStruct(TimeCurrent(), dtNow);
      dtNow.hour = 0; dtNow.min = 0; dtNow.sec = 0;
      datetime today = StructToTime(dtNow);

      // Reset pause flag and snapshot balance when new day starts
      if(g_dailyProfitPauseDay != today)
      {
         g_dailyProfitPaused = false;
         g_dailyProfitPauseDay = today;
         g_dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);
         Print("v6.32 Daily Profit: New day — start balance snapshot $", DoubleToString(g_dailyStartBalance, 2));
      }
      
      // v6.32: Initialize start balance if not set (first run)
      if(g_dailyStartBalance <= 0)
         g_dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE);

      // v6.32: Check if daily target reached using Equity vs start-of-day Balance
      if(!g_dailyProfitPaused)
      {
         double dailyPL = AccountInfoDouble(ACCOUNT_EQUITY) - g_dailyStartBalance;
         if(dailyPL >= InpDailyProfitTarget && TotalOrderCount() == 0)
         {
            g_dailyProfitPaused = true;
            Print("v6.32 DAILY PROFIT PAUSE: Target $", DoubleToString(InpDailyProfitTarget, 2),
                  " reached (Equity PL=$", DoubleToString(dailyPL, 2), 
                  ", StartBal=$", DoubleToString(g_dailyStartBalance, 2),
                  "). No new orders until tomorrow.");
         }
      }

      if(g_dailyProfitPaused)
         g_newOrderBlocked = true;
   }

   // === SQUEEZE FILTER CHECK ===
   g_squeezeBlocked = false;
   g_squeezeBuyBlocked = false;
   g_squeezeSellBlocked = false;
   if(InpUseSqueezeFilter)
   {
      UpdateSqueezeState();
      if(InpSqueeze_BlockOnExpansion)
      {
         // v6.14: Use unified directional expansion check
         int bestDir = 0;
         int expCount = CountDirectionalExpansion(bestDir);
          if(expCount >= InpSqueeze_MinTFExpansion)
          {
              if(InpSqueeze_DirectionalBlock)
              {
                 // v6.11: Directional block — only block counter-trend side
                 if(bestDir == 1)       // Bullish expansion → block SELL
                    g_squeezeSellBlocked = true;
                 else if(bestDir == -1) // Bearish expansion → block BUY
                    g_squeezeBuyBlocked = true;
                 // v6.11: bestDir == 0 → direction unknown → do NOT block anything
                 //        (safer than blocking everything when DirectionalBlock is enabled)
              }
              else
              {
                 // Original behavior: block everything
                 g_squeezeBlocked = true;
                 g_newOrderBlocked = true;
              }
             
             // Close All on Expansion (v6.6)
             if(InpSqueeze_CloseOnExpansion && !g_expansionCloseTriggered)
             {
                CloseAllOnExpansion();
                g_expansionCloseTriggered = true;
             }
          }
          else
          {
             // Reset cooldown when expansion ends
             g_expansionCloseTriggered = false;
          }
       }
    }

   // === COUNTER-TREND HEDGING CHECK ===
   if(InpHedge_Enable && InpUseSqueezeFilter)
   {
      // v6.16: Choose trigger mode
      if(InpHedge_TriggerMode == HEDGE_TRIGGER_EXPANSION)
         CheckAndOpenHedge();        // Original — Squeeze expansion trigger
      else if(InpHedge_TriggerMode == HEDGE_TRIGGER_DD_PERCENT || InpHedge_TriggerMode == HEDGE_TRIGGER_DD_DOLLAR)
         CheckAndOpenHedgeByDD();    // v6.25: DD% or DD$ per side trigger
      ManageHedgeSets();
   }
   
   // === v6.28: BALANCE GUARD CHECK ===
   CheckBalanceGuard();

   // === ORPHAN RECOVERY GRID ===
   if(InpOrphan_Enable)
   {
      datetime now = TimeCurrent();
      if(now - g_lastOrphanScanTime >= InpOrphan_ScanIntervalMin * 60)
      {
         ScanOrphanGenerations();
         g_lastOrphanScanTime = now;
      }
      ManageOrphanGrid();
   }
   // v6.61: Prune recovery seeds + check unified avg TP for current owner
   PruneRecoverySeeds();
   ManageRecoveryOwnerAvgTP();
   // v6.73: Auto-advance owner to next remaining gen when current owner is flat
   AdvanceSequentialOwnerIfFlat();
   // v6.73: Prune released-ticket list (auto-clean closed entries)
   PrunePrevHedgedTickets();
   // v6.74: Prune released gen+side locks (auto-clear when gen-side flat)
   PruneReleasedGenSideLocks();
   // v6.63: Watchdog — alert if owner-gen orders are missing Broker TP
   AuditUnTPedOwnerOrders();
   // v6.65: Watchdog — alert if hedge set lots are inflated vs bound orders
   AuditHedgeSetIntegrity();

   // === ORIGINAL TRADING LOGIC (unchanged) ===
   if(g_eaStopped) return;

   //--- Every tick: Per-Order Trailing (works for both modes - individual positions)
   if(EnablePerOrderTrailing)
   {
      ManagePerOrderTrailing();
   }
   else if(EnableTrailingStop || EnableBreakeven)
   {
      if(EntryMode == ENTRY_SMA || EntryMode == ENTRY_INSTANT)
         ManageTrailingStop();
      // ZigZag mode: per-TF trailing handled in OnTickZigZagMTF()
    }

    //--- v6.41: Max Grid Average Trailing Stop
    if(MaxGrid_TrailEnable)
       ManageMaxGridTrailing();

    //--- Every tick: Track Max DD per side for DD% TP (v6.7)
   if(UseTP_DDPercent)
   {
      double plBuyDD = CalculateFloatingPL(POSITION_TYPE_BUY);
      double plSellDD = CalculateFloatingPL(POSITION_TYPE_SELL);
      // Only track when positions exist (plBuy/plSell != 0 implies positions)
      if(plBuyDD < g_maxDDBuy) g_maxDDBuy = plBuyDD;
      if(plSellDD < g_maxDDSell) g_maxDDSell = plSellDD;
   }

    //--- Every tick: TP/SL management
    if(EntryMode == ENTRY_SMA || EntryMode == ENTRY_INSTANT)
       ManageTPSL();
    // ZigZag mode: per-TF TP/SL + shared accumulate handled in OnTickZigZagMTF()

     //--- v6.72: Per-tick safety sweep — guarantees no bound ticket keeps a stale
     //          broker TP/SL even if all TP modes are disabled or the 2s timer is late.
     EnforceClearTPOnAllBound();

     //--- v6.44: Broker-Level TP/SL sync (every 2 seconds) — covers ALL TP modes
     if(UseTP_Points || UseTP_Dollar || UseTP_PercentBalance || (EnableSL && UseSL_Points))
     {
        if(TimeCurrent() - g_lastBrokerTPSLSync >= g_brokerTPSLIntervalSec)
           SyncBrokerTPSL();
     }

   //--- Every tick: Matching Close (pair profit vs loss orders)
   if(UseMatchingClose)
      ManageMatchingClose();

   //--- Every tick: Drawdown check
   CheckDrawdownExit();

   //--- Track max drawdown
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(balance > 0)
   {
      double dd = (balance - equity) / balance * 100.0;
      if(dd > g_maxDD) g_maxDD = dd;
   }

   // ============================================================
   // SMA MODE - Original Entry Logic (unchanged when ENTRY_SMA)
   // ============================================================
   if(EntryMode == ENTRY_SMA)
   {
      //--- New bar logic
      datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
      bool isNewBar = (currentBarTime != lastBarTime);

      if(isNewBar)
      {
         lastBarTime = currentBarTime;

          //--- Copy indicator buffers
          if(CopyBuffer(handleSMA, 0, 0, 3, bufSMA) < 3) return;
          if(handleATR_Loss != INVALID_HANDLE)
          {
             if(CopyBuffer(handleATR_Loss, 0, 0, 3, bufATR_Loss) < 3) return;
          }
          if(handleATR_Profit != INVALID_HANDLE)
          {
             if(CopyBuffer(handleATR_Profit, 0, 0, 3, bufATR_Profit) < 3) return;
          }

         double smaValue = bufSMA[0];
         double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

         int buyCount = 0, sellCount = 0;
         int gridLossBuy = 0, gridLossSell = 0;
         int gridProfitBuy = 0, gridProfitSell = 0;
         bool hasInitialBuy = false, hasInitialSell = false;
         CountPositions(buyCount, sellCount, gridLossBuy, gridLossSell, gridProfitBuy, gridProfitSell, hasInitialBuy, hasInitialSell);

          int totalPositions = buyCount + sellCount;

          //--- Reset cycle generation when all positions cleared (standalone check)
           if(g_hadPositions && totalPositions == 0)
           {
               TryResetCycleStateIfFlat("all positions cleared");  // v6.27
               UpdateDynamicBalanceGuardTarget();  // v6.31
           }

         //--- Auto-detect broker-closed positions (e.g. trailing SL hit by broker)
         if(buyCount == 0 && g_initialBuyPrice != 0)
         {
            Print("BUY cycle ended (broker SL). Resetting g_initialBuyPrice.");
            g_initialBuyPrice = 0;
         }
         if(sellCount == 0 && g_initialSellPrice != 0)
         {
            Print("SELL cycle ended (broker SL). Resetting g_initialSellPrice.");
            g_initialSellPrice = 0;
         }

         //--- Grid Loss management (check both sides independently) - blocked by News/Time/Squeeze filter
          // v6.39: Hedge Side Pause — check if each side is paused
          bool buyHedgePaused = (InpHedge_SidePauseMin > 0 && g_lastHedgeBuyTime > 0 
                                 && (TimeCurrent() - g_lastHedgeBuyTime) < InpHedge_SidePauseMin * 60);
          bool sellHedgePaused = (InpHedge_SidePauseMin > 0 && g_lastHedgeSellTime > 0 
                                  && (TimeCurrent() - g_lastHedgeSellTime) < InpHedge_SidePauseMin * 60);

          if(!g_newOrderBlocked)
          {
             if(!buyHedgePaused && !g_squeezeBuyBlocked && (hasInitialBuy || g_initialBuyPrice > 0 || gridLossBuy > 0) && gridLossBuy < GridLoss_MaxTrades && buyCount > 0)
             {
                CheckGridLoss(POSITION_TYPE_BUY, gridLossBuy);
             }
             if(!sellHedgePaused && !g_squeezeSellBlocked && (hasInitialSell || g_initialSellPrice > 0 || gridLossSell > 0) && gridLossSell < GridLoss_MaxTrades && sellCount > 0)
             {
                CheckGridLoss(POSITION_TYPE_SELL, gridLossSell);
             }
          }

         //--- Grid Profit management - blocked by News/Time/Squeeze filter
         if(!g_newOrderBlocked && GridProfit_Enable)
         {
            if(!g_squeezeBuyBlocked && (hasInitialBuy || g_initialBuyPrice > 0) && gridProfitBuy < GridProfit_MaxTrades && buyCount > 0)
            {
               CheckGridProfit(POSITION_TYPE_BUY, gridProfitBuy);
            }
            if(!g_squeezeSellBlocked && (hasInitialSell || g_initialSellPrice > 0) && gridProfitSell < GridProfit_MaxTrades && sellCount > 0)
            {
               CheckGridProfit(POSITION_TYPE_SELL, gridProfitSell);
            }
         }

         //--- Entry logic: Independent Side Entry - blocked by News/Time filter
         if(!g_newOrderBlocked)
         {
            bool canOpenMore = NormalOrderCount() < MaxOpenOrders;
            bool canOpenOnThisCandle = !(DontOpenSameCandle && currentBarTime == lastInitialCandleTime);

            //--- BUY side shouldEnter logic (v2.9 robust fix)
            bool shouldEnterBuy = false;
            if(buyCount == 0)
            {
               if(justClosedBuy && !EnableAutoReEntry)
                  shouldEnterBuy = false;  // 1-bar cooldown only
               else
                  shouldEnterBuy = true;   // Ready to enter (auto re-entry or normal)
            }

            //--- SELL side shouldEnter logic (v2.9 robust fix)
            bool shouldEnterSell = false;
            if(sellCount == 0)
            {
               if(justClosedSell && !EnableAutoReEntry)
                  shouldEnterSell = false;  // 1-bar cooldown only
               else
                  shouldEnterSell = true;   // Ready to enter (auto re-entry or normal)
            }

              // ===== BUY Entry (independent) ===== v6.39: add hedge pause guard
              if(!buyHedgePaused && !g_squeezeBuyBlocked && buyCount == 0 && g_initialBuyPrice == 0 && canOpenMore && canOpenOnThisCandle)
              {
                 if(currentPrice > smaValue && (TradingMode == TRADE_BUY_ONLY || TradingMode == TRADE_BOTH))
                 {
                    if(shouldEnterBuy)
                    {
                        if(OpenOrder(ORDER_TYPE_BUY, InitialLotSize, GetCommentPrefix() + "_INIT"))
                       {
                          g_initialBuyPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                          lastInitialCandleTime = currentBarTime;
                          ResetTrailingState();
                       }
                    }
                 }
                 else if(shouldEnterBuy)
                 {
                    Print("BUY ENTRY SKIP: SMA signal not match (Price=", currentPrice, " SMA=", smaValue, ")");
                 }
              }

              // ===== SELL Entry (independent) ===== v6.39: add hedge pause guard
              if(!sellHedgePaused && !g_squeezeSellBlocked && sellCount == 0 && g_initialSellPrice == 0 && canOpenMore && canOpenOnThisCandle)
              {
                 if(currentPrice < smaValue && (TradingMode == TRADE_SELL_ONLY || TradingMode == TRADE_BOTH))
                 {
                    if(shouldEnterSell)
                    {
                        if(OpenOrder(ORDER_TYPE_SELL, InitialLotSize, GetCommentPrefix() + "_INIT"))
                       {
                          g_initialSellPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                          lastInitialCandleTime = currentBarTime;
                          ResetTrailingState();
                       }
                    }
                 }
                 else if(shouldEnterSell)
                 {
                    Print("SELL ENTRY SKIP: SMA signal not match (Price=", currentPrice, " SMA=", smaValue, ")");
                 }
              }
         }

         // Reset justClosed flags ONLY after entry logic has had a chance to use them
         if(!g_newOrderBlocked)
         {
            justClosedBuy = false;
            justClosedSell = false;
         }
      }
   } // end EntryMode == ENTRY_SMA

   // ============================================================
   // ZIGZAG MTF MODE - Multi-Timeframe Entry System (v3.0)
   // ============================================================
   if(EntryMode == ENTRY_ZIGZAG)
   {
      OnTickZigZagMTF();
   }

   // ============================================================
   // INSTANT MODE - No Indicator, Open Both Sides Immediately
   // ============================================================
   if(EntryMode == ENTRY_INSTANT)
   {
      datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
      bool isNewBar = (currentBarTime != lastBarTime);
      
      if(isNewBar)
      {
         lastBarTime = currentBarTime;
      }
      
      int buyCount = 0, sellCount = 0;
      int gridLossBuy = 0, gridLossSell = 0;
      int gridProfitBuy = 0, gridProfitSell = 0;
      bool hasInitialBuy = false, hasInitialSell = false;
      CountPositions(buyCount, sellCount, gridLossBuy, gridLossSell, 
                     gridProfitBuy, gridProfitSell, hasInitialBuy, hasInitialSell);

      // Auto-detect broker-closed positions
      if(buyCount == 0 && g_initialBuyPrice != 0) { g_initialBuyPrice = 0; }
      if(sellCount == 0 && g_initialSellPrice != 0) { g_initialSellPrice = 0; }

       // v6.39: Hedge Side Pause for Instant mode
       bool buyHedgePaused = (InpHedge_SidePauseMin > 0 && g_lastHedgeBuyTime > 0 
                              && (TimeCurrent() - g_lastHedgeBuyTime) < InpHedge_SidePauseMin * 60);
       bool sellHedgePaused = (InpHedge_SidePauseMin > 0 && g_lastHedgeSellTime > 0 
                               && (TimeCurrent() - g_lastHedgeSellTime) < InpHedge_SidePauseMin * 60);

       // Grid Loss management
       if(!g_newOrderBlocked)
       {
          if(!buyHedgePaused && !g_squeezeBuyBlocked && (hasInitialBuy || g_initialBuyPrice > 0 || gridLossBuy > 0) && gridLossBuy < GridLoss_MaxTrades && buyCount > 0)
             CheckGridLoss(POSITION_TYPE_BUY, gridLossBuy);
          if(!sellHedgePaused && !g_squeezeSellBlocked && (hasInitialSell || g_initialSellPrice > 0 || gridLossSell > 0) && gridLossSell < GridLoss_MaxTrades && sellCount > 0)
             CheckGridLoss(POSITION_TYPE_SELL, gridLossSell);
       }

       // Grid Profit management
       if(!g_newOrderBlocked && GridProfit_Enable)
       {
          if(!g_squeezeBuyBlocked && (hasInitialBuy || g_initialBuyPrice > 0) && gridProfitBuy < GridProfit_MaxTrades && buyCount > 0)
             CheckGridProfit(POSITION_TYPE_BUY, gridProfitBuy);
          if(!g_squeezeSellBlocked && (hasInitialSell || g_initialSellPrice > 0) && gridProfitSell < GridProfit_MaxTrades && sellCount > 0)
             CheckGridProfit(POSITION_TYPE_SELL, gridProfitSell);
       }

       // Entry logic
       if(!g_eaStopped && !g_newOrderBlocked)
       {
          bool canOpenOnThisCandle = !(DontOpenSameCandle && currentBarTime == lastInitialCandleTime);
          bool canOpenMore = NormalOrderCount() < MaxOpenOrders;

          // ===== BUY Entry (instant) ===== v6.39: add hedge pause guard
          if(!buyHedgePaused && !g_squeezeBuyBlocked && buyCount == 0 && g_initialBuyPrice == 0 && canOpenMore && canOpenOnThisCandle)
          {
             if(TradingMode == TRADE_BUY_ONLY || TradingMode == TRADE_BOTH)
             {
                if(OpenOrder(ORDER_TYPE_BUY, InitialLotSize, GetCommentPrefix() + "_INIT"))
                {
                   g_initialBuyPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                   lastInitialCandleTime = currentBarTime;
                   ResetTrailingState();
                }
             }
          }

          // ===== SELL Entry (instant) ===== v6.39: add hedge pause guard
          if(!sellHedgePaused && !g_squeezeSellBlocked && sellCount == 0 && g_initialSellPrice == 0 && canOpenMore && canOpenOnThisCandle)
          {
             if(TradingMode == TRADE_SELL_ONLY || TradingMode == TRADE_BOTH)
             {
                if(OpenOrder(ORDER_TYPE_SELL, InitialLotSize, GetCommentPrefix() + "_INIT"))
                {
                   g_initialSellPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                   lastInitialCandleTime = currentBarTime;
                   ResetTrailingState();
                }
             }
          }
       }

      // Reset justClosed flags
      if(!g_newOrderBlocked)
      {
         justClosedBuy = false;
         justClosedSell = false;
      }
   }

   DrawLines();
   // v6.44: Dashboard render throttle — once per second instead of every tick
   if(ShowDashboard && TimeCurrent() - g_lastDashboardRenderTime >= g_dashRenderIntervalSec)
   {
       DisplayDashboard();
       g_lastDashboardRenderTime = TimeCurrent();
    }

    // === v6.49: Deferred Data Sync — runs AFTER TP/SL is set to avoid blocking ===
    if(!MQLInfoInteger(MQL_TESTER) && !MQLInfoInteger(MQL_OPTIMIZATION))
    {
       if(g_pendingSyncOrderOpen)
       {
          Print("[Sync] Deferred: Order opened - syncing data...");
          SyncAccountDataWithEvent(SYNC_ORDER_OPEN);
          g_pendingSyncOrderOpen = false;
       }
       if(g_pendingSyncOrderClose)
       {
          Print("[Sync] Deferred: Order closed - syncing data with trade history...");
          SyncAccountDataWithEvent(SYNC_ORDER_CLOSE);
          g_pendingSyncOrderClose = false;
       }
    }
}

//+------------------------------------------------------------------+
//| Count positions by type and grid level                             |
//+------------------------------------------------------------------+
void CountPositions(int &buyCount, int &sellCount,
                    int &gridLossBuy, int &gridLossSell,
                    int &gridProfitBuy, int &gridProfitSell,
                    bool &hasInitialBuy, bool &hasInitialSell)
{
   buyCount = 0; sellCount = 0;
   gridLossBuy = 0; gridLossSell = 0;
   gridProfitBuy = 0; gridProfitSell = 0;
   hasInitialBuy = false; hasInitialSell = false;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      string comment = PositionGetString(POSITION_COMMENT);
      
      // Skip hedge orders — they are managed by the Hedge system separately
      if(IsHedgeComment(comment)) continue;
      
      // Skip bound orders — managed by Hedge system, not normal trading cycle
      if(IsTicketBound(ticket)) continue;
      
      // v6.22: Skip orders from previous generations — only count current gen
      int orderGen = ExtractGeneration(comment);
      if(orderGen >= 0 && orderGen != g_cycleGeneration) continue;
      
      long posType = PositionGetInteger(POSITION_TYPE);

      if(posType == POSITION_TYPE_BUY)
      {
         buyCount++;
         if(MatchGMSuffix(comment, "_INIT")) hasInitialBuy = true;
         if(MatchGMSuffix(comment, "_GL")) gridLossBuy++;
         if(MatchGMSuffix(comment, "_GP")) gridProfitBuy++;
      }
      else if(posType == POSITION_TYPE_SELL)
      {
         sellCount++;
         if(MatchGMSuffix(comment, "_INIT")) hasInitialSell = true;
         if(MatchGMSuffix(comment, "_GL")) gridLossSell++;
         if(MatchGMSuffix(comment, "_GP")) gridProfitSell++;
      }
   }
}

//+------------------------------------------------------------------+
//| Total order count for this EA                                      |
//+------------------------------------------------------------------+
int TotalOrderCount()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| v6.20: Normal order count — excludes hedge & bound orders          |
//+------------------------------------------------------------------+
int NormalOrderCount()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      string comment = PositionGetString(POSITION_COMMENT);
      if(IsHedgeComment(comment)) continue;
      if(IsTicketBound(ticket)) continue;
      // v6.22: Skip orders from previous generations
      int orderGen = ExtractGeneration(comment);
      if(orderGen >= 0 && orderGen != g_cycleGeneration) continue;
      // v6.93: optionally exclude Hero tickets from MaxOpenOrders cap
      if(InpHero_Enabled && !InpHero_IncludeInMaxOrders && IsHeroTicket(ticket)) continue;
      count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| Open order                                                         |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| v6.56: Bollinger Band Entry Filter helpers                       |
//| Returns block state: 0=allow, 1=block buy, 2=block sell, 3=both  |
//+------------------------------------------------------------------+
int GetBBBlockState(double &outUpper, double &outMiddle, double &outLower, string &outReason)
{
   outUpper = 0; outMiddle = 0; outLower = 0; outReason = "";
   if(!BB_FilterEnable || g_bbHandle == INVALID_HANDLE) return 0;

   double up[2], mid[2], lo[2];
   if(CopyBuffer(g_bbHandle, 1, 0, 1, up) < 1) return 0;   // UPPER_BAND
   if(CopyBuffer(g_bbHandle, 0, 0, 2, mid) < 2) return 0;  // BASE_LINE (need 2 for slope)
   if(CopyBuffer(g_bbHandle, 2, 0, 1, lo) < 1) return 0;   // LOWER_BAND

   outUpper  = up[0];
   outMiddle = mid[0];
   outLower  = lo[0];

   double price = (SymbolInfoDouble(_Symbol, SYMBOL_BID) + SymbolInfoDouble(_Symbol, SYMBOL_ASK)) / 2.0;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0) return 0;
   double proxDist = BB_ProximityPips * point;

   // Outside band -> block both
   if(price > outUpper)  { outReason = "PRICE > UPPER"; return 3; }
   if(price < outLower)  { outReason = "PRICE < LOWER"; return 3; }

   // Near upper
   if(MathAbs(price - outUpper) <= proxDist)
   {
      if(BB_BlockMode == 0) { outReason = "NEAR UPPER (both)"; return 3; }
      // Counter-trend: near upper -> block buy
      outReason = "NEAR UPPER (block buy)"; return 1;
   }
   // Near lower
   if(MathAbs(price - outLower) <= proxDist)
   {
      if(BB_BlockMode == 0) { outReason = "NEAR LOWER (both)"; return 3; }
      outReason = "NEAR LOWER (block sell)"; return 2;
   }
   // Near middle
   if(MathAbs(price - outMiddle) <= proxDist)
   {
      if(BB_BlockMode == 0) { outReason = "NEAR MID (both)"; return 3; }
      // Use middle slope: rising mid -> uptrend -> block sell; falling -> block buy
      double slope = mid[0] - mid[1];
      if(slope >= 0) { outReason = "NEAR MID (rising, block sell)"; return 2; }
      else           { outReason = "NEAR MID (falling, block buy)"; return 1; }
   }
   return 0;
}

bool IsBBBlockingBuy()
{
   double u, m, l; string r;
   int s = GetBBBlockState(u, m, l, r);
   return (s == 1 || s == 3);
}

bool IsBBBlockingSell()
{
   double u, m, l; string r;
   int s = GetBBBlockState(u, m, l, r);
   return (s == 2 || s == 3);
}

bool OpenOrder(ENUM_ORDER_TYPE orderType, double lots, string comment)
{
   double price = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   //--- v6.73: Cross-gen INIT guard — block new-gen INIT while older-gen same-side
   //          orders are still free (not hedged, can self-close normally).
   //          Prevents GM1 + GM2 same-side mixing after a hedge is opened.
   if(InpCrossGen_InitGuard && !IsHedgeComment(comment) && StringFind(comment, "_INIT") >= 0)
   {
      ENUM_POSITION_TYPE psd = (orderType == ORDER_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
      int legacyFree = CountFreeOlderGenOnSide(psd);
      if(legacyFree > 0)
      {
         static datetime lastBlockLog = 0;
         if(TimeCurrent() - lastBlockLog >= 30)
         {
            Print("v6.73 INIT BLOCKED: ", comment, " (", EnumToString(psd), ") — ",
                  legacyFree, " older-gen order(s) still free on this side. ",
                  "Wait for them to self-close before opening new-gen INIT.");
            lastBlockLog = TimeCurrent();
         }
         return false;
      }
   }

   //--- v6.94: Hero Order — block new INIT/GL/GP on a side ONLY when the side has
   //          a Hero survivor with NO non-Hero basket order left. While the basket
   //          is alive, GL/GP must be free to extend it.
   if(InpHero_Enabled && InpHero_BlockSameSideGrid && !IsHedgeComment(comment))
   {
      bool isMain = (StringFind(comment, "_INIT") >= 0
                  || StringFind(comment, "_GL")   >= 0
                  || StringFind(comment, "_GP")   >= 0);
      if(isMain)
      {
         ENUM_POSITION_TYPE wantSide =
            (orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_BUY_STOP)
            ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
         if(ShouldBlockSameSideGridForHero(wantSide))
         {
            if(TimeCurrent() - g_heroLastBlockLog > 30) {
               Print("v6.94 Hero BLOCK (survivor): side=", EnumToString(wantSide),
                     " hero=", CountHeroOnSide(wantSide),
                     " nonHero=0 — skip ", comment);
               g_heroLastBlockLog = TimeCurrent();
            }
            return false;
         }
      }
   }

   //--- v6.56: Bollinger Band Entry Filter (Block New Orders Only — exempt hedge orders)
   if(BB_FilterEnable && !IsHedgeComment(comment))
   {
      double bbU, bbM, bbL; string bbReason;
      int bbState = GetBBBlockState(bbU, bbM, bbL, bbReason);
      bool blockBuy  = (bbState == 1 || bbState == 3);
      bool blockSell = (bbState == 2 || bbState == 3);
      if(orderType == ORDER_TYPE_BUY && blockBuy)
      {
         static datetime lastLogB = 0;
         if(TimeCurrent() - lastLogB >= 30) { Print("v6.56 BB BLOCK BUY: ", comment, " | ", bbReason, " | Px=", price, " U=", bbU, " M=", bbM, " L=", bbL); lastLogB = TimeCurrent(); }
         return false;
      }
      if(orderType == ORDER_TYPE_SELL && blockSell)
      {
         static datetime lastLogS = 0;
         if(TimeCurrent() - lastLogS >= 30) { Print("v6.56 BB BLOCK SELL: ", comment, " | ", bbReason, " | Px=", price, " U=", bbU, " M=", bbM, " L=", bbL); lastLogS = TimeCurrent(); }
         return false;
      }
   }

   //--- Normalize lot
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    // Don't apply user MaxLotSize cap for hedge orders — hedge must match exact counter-side volume
    if(InpMaxLotSize > 0 && !IsHedgeComment(comment)) maxLot = MathMin(maxLot, InpMaxLotSize);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   // Lot cap: when hedge set has bound orders, limit new orders to not exceed hedge coverage
   if(!IsHedgeComment(comment))
   {
      ENUM_POSITION_TYPE posSide = (orderType == ORDER_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
      double lotCap = GetHedgeLotCap(posSide);
      if(lotCap >= 0)  // hedge set exists for this side
      {
         if(lotCap < minLot)
         {
            Print("LOT CAP: Cannot open ", comment, " — bound+new would exceed hedge coverage (allowed=", DoubleToString(lotCap, 2), ")");
            return false;
         }
         maxLot = MathMin(maxLot, lotCap);
      }
   }
   
   lots = MathMax(minLot, MathMin(maxLot, NormalizeDouble(MathRound(lots / lotStep) * lotStep, 2)));

   // === v6.50: Pre-calculate TP for INIT order (first order — avg = own price) ===
   double preTP = 0;
   double preSL = 0;
   bool isHedge = IsHedgeComment(comment);
   ENUM_POSITION_TYPE side = (orderType == ORDER_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   
   if(!isHedge)
   {
      double existingLots = CalculateTotalLots(side);
      if(existingLots == 0)  // First order on this side — avg = this order's price
      {
         double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
         int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
         double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
         double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
         double balance   = AccountInfoDouble(ACCOUNT_BALANCE);
         
         if(UseTP_Points)
         {
            preTP = (side == POSITION_TYPE_BUY) 
                  ? NormalizeDouble(price + TP_Points * point, digits)
                  : NormalizeDouble(price - TP_Points * point, digits);
         }
         else if(UseTP_Dollar && lots > 0 && tickValue > 0)
         {
            double dist = TP_DollarAmount / (lots * tickValue / tickSize);
            preTP = (side == POSITION_TYPE_BUY)
                  ? NormalizeDouble(price + dist, digits)
                  : NormalizeDouble(price - dist, digits);
         }
         else if(UseTP_PercentBalance && lots > 0 && tickValue > 0 && balance > 0)
         {
            double dollarTarget = balance * TP_PercentBalance / 100.0;
            double dist = dollarTarget / (lots * tickValue / tickSize);
            preTP = (side == POSITION_TYPE_BUY)
                  ? NormalizeDouble(price + dist, digits)
                  : NormalizeDouble(price - dist, digits);
         }
         
         // SL for first order (only Points mode, only when per-order trailing is OFF)
         if(EnableSL && UseSL_Points && !EnablePerOrderTrailing)
         {
            preSL = (side == POSITION_TYPE_BUY)
                  ? NormalizeDouble(price - SL_Points * point, digits)
                  : NormalizeDouble(price + SL_Points * point, digits);
         }
         
         if(preTP > 0)
            Print("v6.50 InstantTP: INIT order preTP=", preTP, " preSL=", preSL);
      }
   }

   if(orderType == ORDER_TYPE_BUY)
   {
      if(!trade.Buy(lots, _Symbol, price, preSL, preTP, comment))
      {
         Print("ERROR: Buy failed - ", trade.ResultRetcodeDescription());
         return false;
      }
   }
   else
   {
      if(!trade.Sell(lots, _Symbol, price, preSL, preTP, comment))
      {
         Print("ERROR: Sell failed - ", trade.ResultRetcodeDescription());
         return false;
      }
   }

   Print("Order opened: ", comment, " Lots=", lots, " Price=", price, (preTP > 0 ? " TP=" + DoubleToString(preTP, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)) : ""));

   // v6.48: Force immediate broker TP/SL sync on next tick after new order
   g_lastBrokerTPSLSync = 0;
   g_lastBrokerTP_Buy   = -1;
   g_lastBrokerTP_Sell  = -1;
   g_lastBrokerSL_Buy   = -1;
   g_lastBrokerSL_Sell  = -1;

   // === v6.50: Immediate SyncBrokerTPSL for grid orders (not first, not hedge) ===
   // Grid orders change the average price → must modify ALL orders' TP immediately
   if(!isHedge && preTP == 0)
   {
      Print("v6.50 InstantTP: Grid order — immediate SyncBrokerTPSL");
      SyncBrokerTPSL();
   }

   return true;
}

//+------------------------------------------------------------------+
//| v6.92 Hero Order helpers                                          |
//+------------------------------------------------------------------+
void BuildHeroTicketCache()
{
   // v6.93 FIX: gate BEFORE clearing cache, so throttled ticks keep last-built cache alive
   if(!InpHero_Enabled || InpHero_OrderCount <= 0) { g_heroTicketCount = 0; return; }
   if(g_heroLastBuildTime == TimeCurrent() && g_heroTicketCount > 0) return; // throttle 1/sec, keep last build
   g_heroLastBuildTime = TimeCurrent();
   g_heroTicketCount = 0;

   int maxGen = g_maxGridMonitorGen + 5;
   for(int gen = 0; gen <= maxGen; gen++)
   {
      for(int s = 0; s < 2; s++)
      {
         ENUM_POSITION_TYPE side = (s == 0) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
         ulong  tk[200]; datetime tt[200]; int n = 0;
         for(int i = PositionsTotal() - 1; i >= 0 && n < 200; i--)
         {
            ulong ticket = PositionGetTicket(i);
            if(ticket == 0) continue;
            if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
            if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != side) continue;
            string c = PositionGetString(POSITION_COMMENT);
            if(IsHedgeComment(c)) continue;
            if(IsTicketBound(ticket)) continue;
            if(ExtractGeneration(c) != gen) continue;
            if(StringFind(c,"_INIT")<0 && StringFind(c,"_GL")<0 && StringFind(c,"_GP")<0) continue;
            tk[n] = ticket;
            tt[n] = (datetime)PositionGetInteger(POSITION_TIME);
            n++;
         }
         // sort desc by time
         for(int a = 1; a < n; a++)
            for(int b = a; b > 0 && tt[b] > tt[b-1]; b--)
            { datetime _t=tt[b]; tt[b]=tt[b-1]; tt[b-1]=_t;
              ulong _k=tk[b]; tk[b]=tk[b-1]; tk[b-1]=_k; }
         // v6.94 FIX: form Hero ONLY when side count exceeds Hero count.
         // Spec: Hero = N newest of (gen,side), but only meaningful once a basket exists.
         // Old behavior tagged the very first INIT as Hero, which blocked GL/GP from ever opening.
         if(n <= InpHero_OrderCount) continue;
         int take = InpHero_OrderCount;
         for(int k = 0; k < take && g_heroTicketCount < 200; k++)
            g_heroTickets[g_heroTicketCount++] = tk[k];
      }
   }
   // v6.94: throttled audit log — show Hero + non-Hero counts so block reason is visible
   static datetime lastHeroAuditLog = 0;
   if(g_heroTicketCount > 0 && TimeCurrent() - lastHeroAuditLog >= 30) {
      Print("v6.94 Hero CACHE: total=", g_heroTicketCount,
            " heroBUY=", CountHeroOnSide(POSITION_TYPE_BUY),
            " heroSELL=", CountHeroOnSide(POSITION_TYPE_SELL),
            " nonHeroBUY=", CountNonHeroMainOnSide(POSITION_TYPE_BUY),
            " nonHeroSELL=", CountNonHeroMainOnSide(POSITION_TYPE_SELL),
            " (block fires only when nonHero=0 on that side)");
      lastHeroAuditLog = TimeCurrent();
   }
}

bool IsHeroTicket(ulong ticket)
{
   if(!InpHero_Enabled) return false;
   for(int i = 0; i < g_heroTicketCount; i++)
      if(g_heroTickets[i] == ticket) return true;
   return false;
}

int CountHeroOnSide(ENUM_POSITION_TYPE side)
{
   int n = 0;
   for(int i = 0; i < g_heroTicketCount; i++)
   {
      if(!PositionSelectByTicket(g_heroTickets[i])) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == side) n++;
   }
   return n;
}

// v6.94: Count non-Hero main basket orders (current generation only) for a side.
// Used by Hero same-side grid block to fire ONLY when basket is empty (Hero survivor).
int CountNonHeroMainOnSide(ENUM_POSITION_TYPE side)
{
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != side) continue;
      string c = PositionGetString(POSITION_COMMENT);
      if(IsHedgeComment(c)) continue;
      if(IsTicketBound(ticket)) continue;
      if(IsHeroTicket(ticket)) continue;
      int g = ExtractGeneration(c);
      if(g >= 0 && g != g_cycleGeneration) continue;
      if(StringFind(c, "_INIT") < 0 && StringFind(c, "_GL") < 0 && StringFind(c, "_GP") < 0) continue;
      n++;
   }
   return n;
}

// v6.94: Hero blocks same-side grid only when no non-Hero basket order remains.
bool ShouldBlockSameSideGridForHero(ENUM_POSITION_TYPE side)
{
   if(!InpHero_Enabled || !InpHero_BlockSameSideGrid) return false;
   if(CountHeroOnSide(side) <= 0) return false;
   return (CountNonHeroMainOnSide(side) == 0);
}

double SumHeroLotsOnSide(ENUM_POSITION_TYPE side)
{
   double l = 0;
   for(int i = 0; i < g_heroTicketCount; i++)
   {
      if(!PositionSelectByTicket(g_heroTickets[i])) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != side) continue;
      l += PositionGetDouble(POSITION_VOLUME);
   }
   return l;
}

double SumHeroProfitOnSide(ENUM_POSITION_TYPE side)
{
   double sum = 0;
   for(int i = 0; i < g_heroTicketCount; i++)
   {
      if(!PositionSelectByTicket(g_heroTickets[i])) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != side) continue;
      sum += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return sum;
}

void CloseHeroOnSide(ENUM_POSITION_TYPE side, string reason)
{
   for(int i = g_heroTicketCount - 1; i >= 0; i--)
   {
      ulong ticket = g_heroTickets[i];
      if(!PositionSelectByTicket(ticket)) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != side) continue;
      trade.PositionClose(ticket);
      Print("v6.92 Hero CLOSE: ticket=", ticket, " side=", EnumToString(side), " reason=", reason);
   }
   g_heroTicketCount = 0;     // force rebuild
   g_heroLastBuildTime = 0;
}

// v6.93: renamed semantically — closes Hero on the SAME side that just flattened its basket
void ManageHeroOppositeClose()
{
   if(!InpHero_Enabled || !InpHero_CloseWithOpposite) return; // input retained for .set compat; now means "close Hero with same-side basket"
   if(g_heroOppCloseSide == -1) return;
   if(TimeCurrent() - g_heroOppCloseTime > 5) { g_heroOppCloseSide = -1; return; }
   ENUM_POSITION_TYPE heroSide = (ENUM_POSITION_TYPE)g_heroOppCloseSide;
   if(CountHeroOnSide(heroSide) == 0) { g_heroOppCloseSide = -1; return; }
   if(InpHero_RequireNetProfit && SumHeroProfitOnSide(heroSide) < 0) return;
   CloseHeroOnSide(heroSide, "SameSideBasketClosed");
   g_heroOppCloseSide = -1;
}

//+------------------------------------------------------------------+
//| Calculate Weighted Average Price for one side                      |
//+------------------------------------------------------------------+
double CalculateAveragePrice(ENUM_POSITION_TYPE side)
{
   double totalLots = 0;
   double totalWeighted = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) != side) continue;
      
      // Skip hedge orders — basket TP/SL must not include hedge positions
      if(IsHedgeComment(PositionGetString(POSITION_COMMENT))) continue;
      if(IsTicketBound(ticket)) continue;  // bound orders managed by Hedge system only
      if(IsHeroTicket(ticket)) continue;   // v6.92: Hero excluded from basket avg

      double vol = PositionGetDouble(POSITION_VOLUME);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      totalLots += vol;
      totalWeighted += openPrice * vol;
   }

   if(totalLots > 0)
      return totalWeighted / totalLots;
   return 0;
}

//+------------------------------------------------------------------+
//| Calculate total floating P/L for one side                          |
//+------------------------------------------------------------------+
double CalculateFloatingPL(ENUM_POSITION_TYPE side)
{
   double totalPL = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) != side) continue;
      
      // Skip hedge orders — floating PL calculation must exclude hedge positions
      if(IsHedgeComment(PositionGetString(POSITION_COMMENT))) continue;
      if(IsTicketBound(ticket)) continue;  // bound orders managed by Hedge system only
      if(IsHeroTicket(ticket)) continue;   // v6.92: Hero excluded from basket PL gate

      totalPL += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return totalPL;
}

//+------------------------------------------------------------------+
//| Calculate total floating P/L for ALL positions                     |
//+------------------------------------------------------------------+
double CalculateTotalFloatingPL()
{
   double totalPL = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      totalPL += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return totalPL;
}

//+------------------------------------------------------------------+
//| Calculate total lots for one side                                  |
//+------------------------------------------------------------------+
double CalculateTotalLots(ENUM_POSITION_TYPE side)
{
   double totalLots = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) != side) continue;
      if(IsHedgeComment(PositionGetString(POSITION_COMMENT))) continue;  // v6.53: skip hedge orders
      if(IsTicketBound(ticket)) continue;  // v6.53: skip bound orders
      totalLots += PositionGetDouble(POSITION_VOLUME);
   }
   return totalLots;
}

//+------------------------------------------------------------------+
//| Close all positions for one side                                   |
//+------------------------------------------------------------------+
void CloseAllSide(ENUM_POSITION_TYPE side)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) != side) continue;
      
      // Skip hedge orders — let the Hedge system manage their lifecycle
      if(IsHedgeComment(PositionGetString(POSITION_COMMENT))) continue;
      if(IsTicketBound(ticket)) continue;  // bound orders managed by Hedge system only
      if(IsHeroTicket(ticket)) continue;   // v6.92: keep Hero, only flatten basket
      
      trade.PositionClose(ticket);
   }
   // Set per-side close flag and reset DD tracker (v6.7)
   if(side == POSITION_TYPE_BUY)
   {
      justClosedBuy = true;
      g_maxDDBuy = 0;
   }
   else
   {
      justClosedSell = true;
      g_maxDDSell = 0;
   }
   // v6.93 FIX: signal SAME-side Hero close (was opposite-side in v6.92 — wrong direction).
   // user spec: Hero closes WITH the same-side basket trail/TP that just succeeded.
   if(InpHero_Enabled && InpHero_CloseWithOpposite) {
      g_heroOppCloseSide = (int)side; // SAME side as the basket that just closed
      g_heroOppCloseTime = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Close ALL positions                                                |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   bool hadBuy = false, hadSell = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) hadBuy = true;
      else hadSell = true;
      trade.PositionClose(ticket);
   }
   if(hadBuy) { justClosedBuy = true; g_initialBuyPrice = 0; g_maxDDBuy = 0; }
   if(hadSell) { justClosedSell = true; g_initialSellPrice = 0; g_maxDDSell = 0; }
   ResetTrailingState();

   // Reset all hedge sets when closing everything
   for(int h = 0; h < MAX_HEDGE_SETS; h++)
   {
      g_hedgeSets[h].active = false;
      g_hedgeSets[h].hedgeTicket = 0;
      g_hedgeSets[h].hedgeLots = 0;
      g_hedgeSets[h].gridMode = false;
      g_hedgeSets[h].gridLevel = 0;
      g_hedgeSets[h].gridTicketCount = 0;
      g_hedgeSets[h].combinedGridMode = false;
      g_hedgeSets[h].combinedGridLevel = 0;
      g_hedgeSets[h].combinedLots = 0;
      ArrayResize(g_hedgeSets[h].gridTickets, 0);
      g_hedgeSets[h].boundTicketCount = 0;
      ArrayResize(g_hedgeSets[h].boundTickets, 0);
      // v6.15: Reset close gate
      g_hedgeSets[h].seenExpansionSinceHedge = false;
      g_hedgeSets[h].hedgedDuringExpansion = false;
      g_hedgeSets[h].zoneUpperPrice = 0;
      g_hedgeSets[h].zoneLowerPrice = 0;
      g_hedgeSets[h].hedgeOpenPrice = 0;
      g_hedgeSets[h].oldestBoundPrice = 0;
      // v6.16: Reset trigger type
      g_hedgeSets[h].triggerType = 0;
      g_hedgeSets[h].hedgeOpenTime = 0;  // v6.57
   }
   g_hedgeSetCount = 0;
   // v6.16: Reset DD triggers on full close
   g_nextBuyDDTrigger  = InpHedge_DDTriggerPct;
   g_nextSellDDTrigger = InpHedge_DDTriggerPct;
}

//+------------------------------------------------------------------+
//| v6.42: Sync Broker-Level TP/SL via PositionModify                  |
//| Sets real TP/SL on each position so broker closes automatically    |
//+------------------------------------------------------------------+
// v6.46: Direct check for active hedge sets with bound orders
//        Replaces unreliable g_hedgeBalancedLock trigger
bool HasActiveBoundHedgeSet()
{
   for(int h = 0; h < MAX_HEDGE_SETS; h++)
   {
      if(g_hedgeSets[h].active && g_hedgeSets[h].boundTicketCount > 0)
         return true;
   }
   return false;
}

void SyncBrokerTPSL()
{
   // v6.46: Use direct hedge set check instead of g_hedgeBalancedLock
   //        g_hedgeBalancedLock was reset to false every tick in ManageHedgeSets()
   //        so ClearBrokerTPSL() was never reached — bound orders kept stale TP
   // v6.47: Do NOT return after clearing — continue to set TP/SL for non-bound orders (GM1, GM2...)
   if(HasActiveBoundHedgeSet())
   {
      // Clear broker TP/SL for bound orders — prevent broker from closing during hedge
      ClearBrokerTPSL();
      // Fall through to set TP/SL for non-bound orders of the current generation
   }

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   // Calculate average prices
   double avgBuy  = CalculateAveragePrice(POSITION_TYPE_BUY);
   double avgSell = CalculateAveragePrice(POSITION_TYPE_SELL);

    // v6.44: Calculate target TP/SL prices — supports Points, Dollar, and Percent modes
    double tpBuy = 0, slBuy = 0, tpSell = 0, slSell = 0;
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double balance   = AccountInfoDouble(ACCOUNT_BALANCE);

    if(avgBuy > 0)
    {
       double totalBuyLots = CalculateTotalLots(POSITION_TYPE_BUY);
       
       if(UseTP_Points)
          tpBuy = NormalizeDouble(avgBuy + TP_Points * point, digits);
       else if(UseTP_Dollar && totalBuyLots > 0 && tickValue > 0)
       {
          double priceDistBuy = TP_DollarAmount / (totalBuyLots * tickValue / tickSize);
          tpBuy = NormalizeDouble(avgBuy + priceDistBuy, digits);
       }
       else if(UseTP_PercentBalance && totalBuyLots > 0 && tickValue > 0 && balance > 0)
       {
          double dollarTargetBuy = balance * TP_PercentBalance / 100.0;
          double priceDistBuy = dollarTargetBuy / (totalBuyLots * tickValue / tickSize);
          tpBuy = NormalizeDouble(avgBuy + priceDistBuy, digits);
       }
       
       // SL via broker only when per-order trailing is OFF (trailing manages its own SL)
       if(EnableSL && UseSL_Points && !EnablePerOrderTrailing)
          slBuy = NormalizeDouble(avgBuy - SL_Points * point, digits);
    }

    if(avgSell > 0)
    {
       double totalSellLots = CalculateTotalLots(POSITION_TYPE_SELL);
       
       if(UseTP_Points)
          tpSell = NormalizeDouble(avgSell - TP_Points * point, digits);
       else if(UseTP_Dollar && totalSellLots > 0 && tickValue > 0)
       {
          double priceDistSell = TP_DollarAmount / (totalSellLots * tickValue / tickSize);
          tpSell = NormalizeDouble(avgSell - priceDistSell, digits);
       }
       else if(UseTP_PercentBalance && totalSellLots > 0 && tickValue > 0 && balance > 0)
       {
          double dollarTargetSell = balance * TP_PercentBalance / 100.0;
          double priceDistSell = dollarTargetSell / (totalSellLots * tickValue / tickSize);
          tpSell = NormalizeDouble(avgSell - priceDistSell, digits);
       }
       
       // SL via broker only when per-order trailing is OFF
       if(EnableSL && UseSL_Points && !EnablePerOrderTrailing)
          slSell = NormalizeDouble(avgSell + SL_Points * point, digits);
    }

   // v6.48: Remove cache-based gate — check actual order TP/SL directly to avoid missed retries
   bool buyModifyOK  = true;
   bool sellModifyOK = true;

   // Modify positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      // Skip hedge/bound orders
      if(IsHedgeComment(PositionGetString(POSITION_COMMENT))) continue;
      if(IsTicketBound(ticket)) continue;

      // v6.63 FIX: Skip orders managed by Recovery Owner — they have their own
      // per-generation avg TP path (ManageRecoveryOwnerAvgTP). Mixing them into
      // the global avg TP causes new GLs to be set with the WRONG TP price.
      if(g_sequentialRecoveryActive)
      {
         string ownerComment = PositionGetString(POSITION_COMMENT);
         int ownerOg = ExtractGeneration(ownerComment);
         if(ownerOg == g_sequentialRecoveryGen) continue;
         if(IsRecoverySeedTicket(ticket) && GetRecoverySeedGen(ticket) == g_sequentialRecoveryGen) continue;
      }

      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double curTP = PositionGetDouble(POSITION_TP);
      double curSL = PositionGetDouble(POSITION_SL);

       if(posType == POSITION_TYPE_BUY && avgBuy > 0)
       {
          // v6.85: Respect Average Trailing Stop SL — do NOT overwrite trailing/breakeven SL with 0
          // v6.89: When Squeeze Pause Trailing is active, force SL=0 (do NOT preserve curSL)
          double effectiveSlBuy = slBuy;
          if(g_squeezePauseTrailingActive && InpSqueeze_PauseTrail_StripSL)
             effectiveSlBuy = 0; // force-clear during pause; trailing will rebuild on resume
          else if(EnableTrailingStop && g_trailingActive_Buy && g_trailingSL_Buy > 0)
             effectiveSlBuy = g_trailingSL_Buy;
          else if(slBuy == 0 && curSL > 0)
             effectiveSlBuy = curSL; // preserve existing broker SL (e.g. breakeven)

          if(NormalizeDouble(curTP, digits) != tpBuy || NormalizeDouble(curSL, digits) != NormalizeDouble(effectiveSlBuy, digits))
          {
             if(trade.PositionModify(ticket, effectiveSlBuy, tpBuy))
                Print("v6.85 BrokerTP: SET BUY #", ticket, " TP=", tpBuy, " SL=", effectiveSlBuy);
             else
             {
                Print("v6.85 BrokerTP: Modify BUY #", ticket, " failed: ", GetLastError());
                buyModifyOK = false;
             }
          }
       }
       else if(posType == POSITION_TYPE_SELL && avgSell > 0)
       {
          // v6.85: Respect Average Trailing Stop SL — do NOT overwrite trailing/breakeven SL with 0
          // v6.89: When Squeeze Pause Trailing is active, force SL=0 (do NOT preserve curSL)
          double effectiveSlSell = slSell;
          if(g_squeezePauseTrailingActive && InpSqueeze_PauseTrail_StripSL)
             effectiveSlSell = 0;
          else if(EnableTrailingStop && g_trailingActive_Sell && g_trailingSL_Sell > 0)
             effectiveSlSell = g_trailingSL_Sell;
          else if(slSell == 0 && curSL > 0)
             effectiveSlSell = curSL; // preserve existing broker SL

          if(NormalizeDouble(curTP, digits) != tpSell || NormalizeDouble(curSL, digits) != NormalizeDouble(effectiveSlSell, digits))
          {
             if(trade.PositionModify(ticket, effectiveSlSell, tpSell))
                Print("v6.85 BrokerTP: SET SELL #", ticket, " TP=", tpSell, " SL=", effectiveSlSell);
             else
             {
                Print("v6.85 BrokerTP: Modify SELL #", ticket, " failed: ", GetLastError());
                sellModifyOK = false;
             }
          }
       }
   }

   // v6.48: Only update cache if ALL modifies succeeded — ensures retry on next sync if any failed
   if(buyModifyOK)  { g_lastBrokerTP_Buy  = tpBuy;  g_lastBrokerSL_Buy  = slBuy;  }
   if(sellModifyOK) { g_lastBrokerTP_Sell  = tpSell; g_lastBrokerSL_Sell  = slSell; }

   g_lastBrokerTPSLSync = TimeCurrent();
}

//+------------------------------------------------------------------+
//| v6.42: Clear Broker TP/SL (during hedge lock or no positions)      |
//+------------------------------------------------------------------+
void ClearBrokerTPSL()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      string clearComment = PositionGetString(POSITION_COMMENT);
      if(IsHedgeComment(clearComment)) continue;
      
      // v6.46: Only clear TP/SL for orders that are bound in active hedge sets
      if(!IsTicketBound(ticket)) continue;

      // v6.64: Don't clear TP of recovery owner generation orders — they're managed
      // by ManageRecoveryOwnerAvgTP. Without this guard, ClearBrokerTPSL and
      // ManageRecoveryOwnerAvgTP fight every tick (ping-pong loop in journal).
      if(g_sequentialRecoveryActive)
      {
         int og = ExtractGeneration(clearComment);
         if(og == g_sequentialRecoveryGen) continue;
         if(IsRecoverySeedTicket(ticket) && GetRecoverySeedGen(ticket) == g_sequentialRecoveryGen) continue;
      }

      double curTP = PositionGetDouble(POSITION_TP);
      double curSL = PositionGetDouble(POSITION_SL);

      if(curTP != 0 || curSL != 0)
      {
         if(trade.PositionModify(ticket, 0, 0))
            Print("v6.47 ClearTP: Cleared bound order #", ticket, " TP=", curTP, "->0 SL=", curSL, "->0");
      }
   }

   g_lastBrokerTP_Buy  = 0;
   g_lastBrokerSL_Buy  = 0;
   g_lastBrokerTP_Sell  = 0;
   g_lastBrokerSL_Sell  = 0;
    }

//+------------------------------------------------------------------+
//| v6.72: Force-clear broker TP/SL of every bound ticket in a set     |
//| Called immediately when a hedge opens & binds counter-side orders  |
//| Independent of TP-mode gates and the 2s sync timer                 |
//+------------------------------------------------------------------+
void ClearBrokerTPSLForSet(int slot)
{
   if(slot < 0 || slot >= MAX_HEDGE_SETS) return;
   if(!g_hedgeSets[slot].active) return;
   int cleared = 0;
   for(int b = 0; b < g_hedgeSets[slot].boundTicketCount; b++)
   {
      ulong tk = g_hedgeSets[slot].boundTickets[b];
      if(tk == 0) continue;
      if(!PositionSelectByTicket(tk)) continue;
      double curTP = PositionGetDouble(POSITION_TP);
      double curSL = PositionGetDouble(POSITION_SL);
      if(curTP == 0 && curSL == 0) continue;
      if(trade.PositionModify(tk, 0, 0))
      {
         cleared++;
         Print("v6.72 ClearTP-OnBind: set#", slot + 1, " ticket #", tk,
               " TP=", DoubleToString(curTP, _Digits), "->0 SL=",
               DoubleToString(curSL, _Digits), "->0");
      }
      else
      {
         Print("v6.72 ClearTP-OnBind FAILED: set#", slot + 1, " ticket #", tk,
               " err=", GetLastError());
      }
   }
   if(cleared > 0)
   {
      // Force next SyncBrokerTPSL to re-evaluate from scratch
      g_lastBrokerTP_Buy   = -1;
      g_lastBrokerTP_Sell  = -1;
      g_lastBrokerSL_Buy   = -1;
      g_lastBrokerSL_Sell  = -1;
      g_lastBrokerTPSLSync = 0;
   }
}

//+------------------------------------------------------------------+
//| v6.72: Per-tick safety sweep — guarantees no bound ticket keeps   |
//| a stale broker TP/SL even if all TP modes are disabled or sync    |
//| timer is delayed. Runs unconditionally each tick.                  |
//+------------------------------------------------------------------+
void EnforceClearTPOnAllBound()
{
   for(int h = 0; h < MAX_HEDGE_SETS; h++)
   {
      if(!g_hedgeSets[h].active) continue;
      if(g_hedgeSets[h].boundTicketCount <= 0) continue;
      for(int b = 0; b < g_hedgeSets[h].boundTicketCount; b++)
      {
         ulong tk = g_hedgeSets[h].boundTickets[b];
         if(tk == 0) continue;
         if(!PositionSelectByTicket(tk)) continue;
         // Skip recovery-owner generation tickets — they have their own TP path
         if(g_sequentialRecoveryActive)
         {
            string c = PositionGetString(POSITION_COMMENT);
            int og = ExtractGeneration(c);
            if(og == g_sequentialRecoveryGen) continue;
            if(IsRecoverySeedTicket(tk) && GetRecoverySeedGen(tk) == g_sequentialRecoveryGen) continue;
         }
         double curTP = PositionGetDouble(POSITION_TP);
         double curSL = PositionGetDouble(POSITION_SL);
         if(curTP == 0 && curSL == 0) continue;
         if(trade.PositionModify(tk, 0, 0))
            Print("v6.72 ClearTP-Sweep: set#", h + 1, " ticket #", tk,
                  " TP=", DoubleToString(curTP, _Digits), "->0 SL=",
                  DoubleToString(curSL, _Digits), "->0");
      }
   }
}

void ManageTPSL()
{
   // v6.11: Skip TP/SL when hedge balanced lock is active (both sides equal)
   // v6.46: Use direct hedge set check instead of g_hedgeBalancedLock
   // v6.47: Removed early return — CalculateAveragePrice/FloatingPL already skip bound orders
   //        so new generation orders (GM1, GM2) still get TP/SL management
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);

   //--- BUY side
   double avgBuy = CalculateAveragePrice(POSITION_TYPE_BUY);
   if(avgBuy > 0)
   {
      double plBuy = CalculateFloatingPL(POSITION_TYPE_BUY);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      bool closeTP = false;
      bool closeSL = false;

       //--- TP checks
       //--- v6.44: Dollar/Percent TP always active — Per-Order Trailing only manages SL, not TP
       //--- Points TP is handled by broker via PositionModify — no EA check needed
       if(UseTP_Dollar && plBuy >= TP_DollarAmount) closeTP = true;
       if(UseTP_PercentBalance && plBuy >= balance * TP_PercentBalance / 100.0) closeTP = true;
      
      //--- DD% TP check (v6.7): profit target = X% of max drawdown, always close in profit
      if(UseTP_DDPercent && g_maxDDBuy < 0)
      {
         double tpTarget = MathAbs(g_maxDDBuy) * TP_DDPercent / 100.0;
         if(plBuy >= tpTarget && plBuy > 0)
         {
            Print("DD% TP HIT (BUY): PL=", plBuy, " Target=+", tpTarget, " MaxDD=", g_maxDDBuy);
            closeTP = true;
         }
      }

      if(closeTP)
      {
         Print("TP HIT (BUY): PL=", plBuy);
         CloseAllSide(POSITION_TYPE_BUY);
         justClosedBuy = true;
         g_initialBuyPrice = 0;
         g_maxDDBuy = 0;  // Reset DD tracker for next cycle
         ResetTrailingState();
         // No manual accumulate increment - baseline handles it
         return;
      }

      //--- SL checks (ONLY when NOT using Per-Order Trailing - per-order trailing handles individual SL via broker)
      if(EnableSL && !EnablePerOrderTrailing)
      {
         if(UseSL_Dollar && plBuy <= -SL_DollarAmount)
         {
            Print("SL_BASKET_DOLLAR HIT (BUY): PL=", plBuy, " Limit=", -SL_DollarAmount);
            closeSL = true;
         }
          // v6.42: SL Points now handled by broker via PositionModify (SyncBrokerTPSL)
          // if(UseSL_Points && bid <= avgBuy - SL_Points * point) closeSL = true;
         if(UseSL_PercentBalance && plBuy <= -(balance * SL_PercentBalance / 100.0))
         {
            Print("SL_BASKET_PCT HIT (BUY): PL=", plBuy, " Limit=", -(balance * SL_PercentBalance / 100.0));
            closeSL = true;
         }

         if(closeSL)
         {
            if(SL_ActionMode == SL_CLOSE_ALL_STOP)
            {
               CloseAllPositions();
               g_eaStopped = true;
               Print("EA STOPPED by SL Action (BUY)");
            }
            else
            {
               CloseAllSide(POSITION_TYPE_BUY);
               justClosedBuy = true;
               g_initialBuyPrice = 0;
               ResetTrailingState();
            }
            return;
         }
      }
   }

   //--- SELL side
   double avgSell = CalculateAveragePrice(POSITION_TYPE_SELL);
   if(avgSell > 0)
   {
      double plSell = CalculateFloatingPL(POSITION_TYPE_SELL);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      bool closeTP2 = false;
      bool closeSL2 = false;

       //--- TP checks
       //--- v6.44: Dollar/Percent TP always active — Per-Order Trailing only manages SL, not TP
       if(UseTP_Dollar && plSell >= TP_DollarAmount) closeTP2 = true;
       if(UseTP_PercentBalance && plSell >= balance * TP_PercentBalance / 100.0) closeTP2 = true;
      
      //--- DD% TP check (v6.7): profit target = X% of max drawdown, always close in profit
      if(UseTP_DDPercent && g_maxDDSell < 0)
      {
         double tpTargetSell = MathAbs(g_maxDDSell) * TP_DDPercent / 100.0;
         if(plSell >= tpTargetSell && plSell > 0)
         {
            Print("DD% TP HIT (SELL): PL=", plSell, " Target=+", tpTargetSell, " MaxDD=", g_maxDDSell);
            closeTP2 = true;
         }
      }

      if(closeTP2)
      {
         Print("TP HIT (SELL): PL=", plSell);
         CloseAllSide(POSITION_TYPE_SELL);
         justClosedSell = true;
         g_initialSellPrice = 0;
         g_maxDDSell = 0;  // Reset DD tracker for next cycle
         ResetTrailingState();
         // No manual accumulate increment - baseline handles it
         return;
      }

      //--- SL checks (ONLY when NOT using Per-Order Trailing - per-order trailing handles individual SL via broker)
      if(EnableSL && !EnablePerOrderTrailing)
      {
         if(UseSL_Dollar && plSell <= -SL_DollarAmount)
         {
            Print("SL_BASKET_DOLLAR HIT (SELL): PL=", plSell, " Limit=", -SL_DollarAmount);
            closeSL2 = true;
         }
          // v6.42: SL Points now handled by broker via PositionModify (SyncBrokerTPSL)
          // if(UseSL_Points && ask >= avgSell + SL_Points * point) closeSL2 = true;
         if(UseSL_PercentBalance && plSell <= -(balance * SL_PercentBalance / 100.0))
         {
            Print("SL_BASKET_PCT HIT (SELL): PL=", plSell, " Limit=", -(balance * SL_PercentBalance / 100.0));
            closeSL2 = true;
         }

         if(closeSL2)
         {
            if(SL_ActionMode == SL_CLOSE_ALL_STOP)
            {
               CloseAllPositions();
               g_eaStopped = true;
               Print("EA STOPPED by SL Action (SELL)");
            }
            else
            {
               CloseAllSide(POSITION_TYPE_SELL);
               justClosedSell = true;
               g_initialSellPrice = 0;
               ResetTrailingState();
            }
            return;
         }
      }
   }

   //--- Accumulate Close (baseline method) - recalculate every tick from deal history
   if(UseAccumulateClose)
   {
      //--- Auto-reset baseline when all positions are closed (cycle ended)
      int currentCount = TotalOrderCount();
        if(g_hadPositions && currentCount == 0)
        {
           // v6.27: Safe reset — only if truly flat
           TryResetCycleStateIfFlat("accumulate reset");
           UpdateDynamicBalanceGuardTarget();  // v6.31
           g_accumulateBaseline = CalcTotalHistoryProfit();
           g_accumulatedProfit = 0;
           g_hadPositions = false;
           Print("Accumulate auto-reset: no positions left. New baseline: ", g_accumulateBaseline);
           return;
        }
      if(currentCount > 0) g_hadPositions = true;

      double totalHistory = CalcTotalHistoryProfit();
      g_accumulatedProfit = totalHistory - g_accumulateBaseline;

      double totalFloating = CalculateTotalFloatingPL();
      double accumTotal = g_accumulatedProfit + totalFloating;

      if(accumTotal >= AccumulateTarget && accumTotal > 0)  // trigger on total (closed + floating)
      {
         Print("ACCUMULATE TARGET HIT: ", accumTotal, " / ", AccumulateTarget);
         CloseAllPositions();
         // Recalc after closing to include just-closed profit
         Sleep(500);
         double newHistory = CalcTotalHistoryProfit();
         g_accumulateBaseline = newHistory;
         g_accumulatedProfit = 0;
         g_hadPositions = false;
         Print("Accumulate cycle reset. New baseline: ", newHistory);
      }
   }
}

//+------------------------------------------------------------------+
//| Manage Per-Order Trailing Stop (Standard Breakeven + Trailing)      |
//| Step 1: Breakeven - lock in small profit when target reached        |
//| Step 2: Trailing - SL follows price at fixed distance with step     |
//| SL never moves backwards. Broker closes order when SL is hit.       |
//+------------------------------------------------------------------+
void ManagePerOrderTrailing()
{
   // v6.89: Squeeze Pause — strip broker SL on edge + skip updates while in Expansion
   if(IsTrailingPausedAndHandleEdge()) return;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   int stopLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   if(stopLevel < 1) stopLevel = 1;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      long posType = PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);

      if(posType == POSITION_TYPE_BUY)
      {
         double profitPoints = (bid - openPrice) / point;

         // ===== STEP 1: Breakeven =====
         if(InpEnableBreakeven && profitPoints >= InpBreakevenTarget)
         {
            double beLevel = NormalizeDouble(openPrice + InpBreakevenOffset * point, digits);
            if(currentSL == 0 || currentSL < beLevel)
            {
               // Broker stop level check
               double minSL = NormalizeDouble(bid - stopLevel * point, digits);
               double finalBE = MathMin(beLevel, minSL);
               if((finalBE > currentSL || currentSL == 0) &&
                  (currentSL == 0 || MathAbs(currentSL - finalBE) >= point)) // v6.83: skip identical SL
               {
                  if(trade.PositionModify(ticket, finalBE, tp))
                  {
                     Print("BREAKEVEN BUY #", ticket,
                           " Open=", openPrice,
                           " SL: ", currentSL, " -> ", finalBE);
                     currentSL = finalBE; // update for trailing check below
                  }
               }
            }
         }

         // ===== STEP 2: Trailing =====
         if(InpEnableTrailing && profitPoints >= InpTrailingStop)
         {
            double newSL = NormalizeDouble(bid - InpTrailingStop * point, digits);

            // Never below breakeven level
            double beFloor = NormalizeDouble(openPrice + InpBreakevenOffset * point, digits);
            if(newSL < beFloor) newSL = beFloor;

            // Broker stop level check
            double minSL = NormalizeDouble(bid - stopLevel * point, digits);
            if(newSL > minSL) newSL = minSL;

            // Must move at least TrailingStep points to modify
            if(currentSL == 0 || newSL > currentSL + InpTrailingStep * point)
            {
               if(trade.PositionModify(ticket, newSL, tp))
               {
                  Print("TRAIL BUY #", ticket,
                        " Open=", openPrice,
                        " Bid=", bid,
                        " Profit=", DoubleToString(profitPoints, 0), "pts",
                        " SL: ", currentSL, " -> ", newSL);
               }
            }
         }
      }
      else if(posType == POSITION_TYPE_SELL)
      {
         double profitPoints = (openPrice - ask) / point;

         // ===== STEP 1: Breakeven =====
         if(InpEnableBreakeven && profitPoints >= InpBreakevenTarget)
         {
            double beLevel = NormalizeDouble(openPrice - InpBreakevenOffset * point, digits);
            if(currentSL == 0 || currentSL > beLevel)
            {
               // Broker stop level check
               double maxSL = NormalizeDouble(ask + stopLevel * point, digits);
               double finalBE = MathMax(beLevel, maxSL);
               if((currentSL == 0 || finalBE < currentSL) &&
                  (currentSL == 0 || MathAbs(currentSL - finalBE) >= point)) // v6.83: skip identical SL
               {
                  if(trade.PositionModify(ticket, finalBE, tp))
                  {
                     Print("BREAKEVEN SELL #", ticket,
                           " Open=", openPrice,
                           " SL: ", currentSL, " -> ", finalBE);
                     currentSL = finalBE;
                  }
               }
            }
         }

          // ===== STEP 2: Trailing =====
          if(InpEnableTrailing && profitPoints >= InpTrailingStop)
          {
             double newSL = NormalizeDouble(ask + InpTrailingStop * point, digits);

             // NOTE v2.7: Removed beCeiling guard here.
             // Reason: BE is already handled in Step 1. The trailing step check below
             // (newSL < currentSL - Step) already prevents SL from moving backward.
             // The old beCeiling guard was clamping newSL to openPrice level which
             // caused SL to never move below BE when TrailingStop >= BE offset.

             // Broker stop level check
             double maxSL = NormalizeDouble(ask + stopLevel * point, digits);
             if(newSL < maxSL) newSL = maxSL;

             // Must move at least TrailingStep points down to modify
             if(currentSL == 0 || newSL < currentSL - InpTrailingStep * point)
            {
               if(trade.PositionModify(ticket, newSL, tp))
               {
                  Print("TRAIL SELL #", ticket,
                        " Open=", openPrice,
                        " Ask=", ask,
                        " Profit=", DoubleToString(profitPoints, 0), "pts",
                        " SL: ", currentSL, " -> ", newSL);
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Manage Average-Based Trailing Stop                                 |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   // v6.89: Squeeze Pause guard (was missing — caused trailing to keep modifying SL during Expansion)
   if(IsTrailingPausedAndHandleEdge()) return;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   //--- BUY side
   double avgBuy = CalculateAveragePrice(POSITION_TYPE_BUY);
   if(avgBuy > 0)
   {
      double beLevel = avgBuy + BreakevenBuffer * point;

      if(EnableTrailingStop)
      {
         double trailActivation = avgBuy + TrailingActivation * point;

         if(bid >= trailActivation)
         {
            g_trailingActive_Buy = true;
            double newSL = bid - TrailingStep * point;
            newSL = MathMax(newSL, beLevel); // never below breakeven

            // v6.83: Only push to broker when SL moves at least TrailingStep points (or first activation)
            bool firstApply = (g_trailingSL_Buy == 0);
            bool stepReached = (newSL >= g_trailingSL_Buy + TrailingStep * point);
            if(firstApply || stepReached)
            {
               g_trailingSL_Buy = newSL;
               ApplyTrailingSL(POSITION_TYPE_BUY, g_trailingSL_Buy);
            }
         }
      }

      if(EnableBreakeven && !g_breakevenDone_Buy)
      {
         double beActivation = avgBuy + BreakevenActivation * point;
         if(bid >= beActivation)
         {
            g_breakevenDone_Buy = true;
            if(g_trailingSL_Buy < beLevel)
            {
               g_trailingSL_Buy = beLevel;
               ApplyTrailingSL(POSITION_TYPE_BUY, beLevel);
               Print("BREAKEVEN BUY: SL moved to ", beLevel);
            }
         }
      }

      // Check if trailing SL hit
      if(g_trailingActive_Buy && g_trailingSL_Buy > 0 && bid <= g_trailingSL_Buy)
      {
         Print("TRAILING SL HIT (BUY): SL=", g_trailingSL_Buy, " Bid=", bid);
         CloseAllSide(POSITION_TYPE_BUY);
         justClosedBuy = true;
         g_initialBuyPrice = 0;
         // v6.84: per-side reset so SELL trailing state is preserved
         ResetTrailingStateBuy();
         // v6.84: NO return — let SELL section continue processing this tick
      }
   }
   else
   {
      g_trailingSL_Buy = 0;
      g_trailingActive_Buy = false;
      g_breakevenDone_Buy = false;
   }

   //--- SELL side
   double avgSell = CalculateAveragePrice(POSITION_TYPE_SELL);
   if(avgSell > 0)
   {
      double beLevelSell = avgSell - BreakevenBuffer * point;

      if(EnableTrailingStop)
      {
         double trailActivationSell = avgSell - TrailingActivation * point;

         if(ask <= trailActivationSell)
         {
            g_trailingActive_Sell = true;
            double newSL = ask + TrailingStep * point;
            newSL = MathMin(newSL, beLevelSell); // never above breakeven

            // v6.83: Only push to broker when SL moves at least TrailingStep points (or first activation)
            bool firstApplyS = (g_trailingSL_Sell == 0);
            bool stepReachedS = (newSL <= g_trailingSL_Sell - TrailingStep * point);
            if(firstApplyS || stepReachedS)
            {
               g_trailingSL_Sell = newSL;
               ApplyTrailingSL(POSITION_TYPE_SELL, g_trailingSL_Sell);
            }
         }
      }

      if(EnableBreakeven && !g_breakevenDone_Sell)
      {
         double beActivationSell = avgSell - BreakevenActivation * point;
         if(ask <= beActivationSell)
         {
            g_breakevenDone_Sell = true;
            if(g_trailingSL_Sell == 0 || g_trailingSL_Sell > beLevelSell)
            {
               g_trailingSL_Sell = beLevelSell;
               ApplyTrailingSL(POSITION_TYPE_SELL, beLevelSell);
               Print("BREAKEVEN SELL: SL moved to ", beLevelSell);
            }
         }
      }

      // Check if trailing SL hit
      if(g_trailingActive_Sell && g_trailingSL_Sell > 0 && ask >= g_trailingSL_Sell)
      {
         Print("TRAILING SL HIT (SELL): SL=", g_trailingSL_Sell, " Ask=", ask);
         CloseAllSide(POSITION_TYPE_SELL);
         justClosedSell = true;
         g_initialSellPrice = 0;
         // v6.84: per-side reset so BUY trailing state is preserved
         ResetTrailingStateSell();
      }
   }
   else
   {
      g_trailingSL_Sell = 0;
      g_trailingActive_Sell = false;
      g_breakevenDone_Sell = false;
   }
}

//+------------------------------------------------------------------+
//| Apply trailing SL to all positions of a side (modify broker SL)    |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| v6.88: Independent Squeeze Pause Trailing                         |
//| Counts EXPANSION TFs directly from g_squeeze[].state — completely |
//| independent of Block-New-Orders flags (g_squeezeBlocked*) and of  |
//| InpSqueeze_BlockOnExpansion / InpSqueeze_MinTFExpansion.          |
//| Triggers when EXPANSION TF count >= InpSqueeze_PauseTrail_MinTF.  |
//| When true, ALL trailing/breakeven SL writers must skip updates    |
//| (does NOT block new orders / grid / hedge / TP / accumulate).     |
//+------------------------------------------------------------------+
bool IsSqueezePausingTrailing()
{
   if(!InpUseSqueezeFilter) return false;
   if(!InpSqueeze_PauseTrailing) return false;

   int expCount = 0;
   for(int sq = 0; sq < 3; sq++)
      if(g_squeeze[sq].state == 2) expCount++;

   int minTF = InpSqueeze_PauseTrail_MinTF;
   if(minTF < 1) minTF = 1;
   if(minTF > 3) minTF = 3;

   return (expCount >= minTF);
}

void ApplyTrailingSL(ENUM_POSITION_TYPE side, double slPrice)
{
   // v6.87: Squeeze Pause guard (defense-in-depth — callers already gated)
   if(IsSqueezePausingTrailing()) return;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   slPrice = NormalizeDouble(slPrice, digits);

   bool anyModified = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) != side) continue;
      // v6.93 FIX: never push basket trailing SL onto Hero tickets — they must outlive the basket close
      if(IsHeroTicket(ticket)) continue;

      double currentSL = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);

      // v6.83: Skip if broker SL already matches target (avoid redundant PositionModify spam)
      if(currentSL > 0 && MathAbs(currentSL - slPrice) < point) continue;

      if(side == POSITION_TYPE_BUY)
      {
         if(currentSL == 0 || slPrice > currentSL)
         {
            if(trade.PositionModify(ticket, slPrice, tp)) anyModified = true;
         }
      }
      else
      {
         if(currentSL == 0 || slPrice < currentSL)
         {
            if(trade.PositionModify(ticket, slPrice, tp)) anyModified = true;
         }
      }
   }

   // v6.85: Sync SyncBrokerTPSL cache so next sync sees this SL as "current" and won't trigger another modify
   if(anyModified)
   {
      if(side == POSITION_TYPE_BUY)  g_lastBrokerSL_Buy  = slPrice;
      else                            g_lastBrokerSL_Sell = slPrice;
   }
}

//+------------------------------------------------------------------+
//| Reset trailing state                                               |
//+------------------------------------------------------------------+
void ResetTrailingState()
{
   g_trailingSL_Buy = 0;
   g_trailingSL_Sell = 0;
   g_trailingActive_Buy = false;
   g_trailingActive_Sell = false;
   g_breakevenDone_Buy = false;
   g_breakevenDone_Sell = false;
}

// v6.84: Per-side reset so closing one side doesn't wipe the other side's trailing state
void ResetTrailingStateBuy()
{
   g_trailingSL_Buy      = 0;
   g_trailingActive_Buy  = false;
   g_breakevenDone_Buy   = false;
}

void ResetTrailingStateSell()
{
   g_trailingSL_Sell     = 0;
   g_trailingActive_Sell = false;
   g_breakevenDone_Sell  = false;
}

//+------------------------------------------------------------------+
//| Check Drawdown Exit                                                |
//+------------------------------------------------------------------+
void CheckDrawdownExit()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(balance <= 0) return;

   double dd = (balance - equity) / balance * 100.0;
   double ddDollar = balance - equity;
   
   bool ddTriggered = false;
   if(DrawdownMode == DD_PERCENT)
   {
      if(dd >= MaxDrawdownPct)
      {
         ddTriggered = true;
         Print("EMERGENCY DD: ", DoubleToString(dd, 2), "% >= ", MaxDrawdownPct, "% - Closing all positions!");
      }
   }
   else // DD_FIXED_DOLLAR
   {
      if(ddDollar >= MaxDrawdownDollar)
      {
         ddTriggered = true;
         Print("EMERGENCY DD: $", DoubleToString(ddDollar, 2), " >= $", DoubleToString(MaxDrawdownDollar, 2), " - Closing all positions!");
      }
   }
   
   if(ddTriggered)
   {
      CloseAllPositions();

      if(StopEAOnDrawdown)
      {
         g_eaStopped = true;
         Print("EA STOPPED by Max Drawdown (StopEAOnDrawdown=true)");
      }
      else
      {
         // Reset state so EA can re-enter on next valid signal
         g_initialBuyPrice  = 0;
         g_initialSellPrice = 0;
         justClosedBuy      = true;
         justClosedSell     = true;
         g_accumulateBaseline = CalcTotalHistoryProfit();
         ResetTrailingState();
         Print("EA continues after DD close (StopEAOnDrawdown=false) - waiting for next signal");
      }
   }
}
//+------------------------------------------------------------------+
//| Find Max Lot on Side (GM_GL / GM_INIT orders)                      |
//+------------------------------------------------------------------+
double FindMaxLotOnSide(ENUM_POSITION_TYPE side)
{
   double maxLot = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != side) continue;
      if(IsTicketBound(ticket)) continue;
      string comment = PositionGetString(POSITION_COMMENT);
      if(IsHedgeComment(comment)) continue;
      // v6.23: Skip orders from previous generations
      int orderGen = ExtractGeneration(comment);
      if(orderGen >= 0 && orderGen != g_cycleGeneration) continue;
      if(MatchGMSuffix(comment, "_GL") || MatchGMSuffix(comment, "_INIT"))
      {
         double lot = PositionGetDouble(POSITION_VOLUME);
         if(lot > maxLot) maxLot = lot;
      }
   }
   return maxLot;
}

//+------------------------------------------------------------------+
//| v6.71: Find max grid level number on side for current generation   |
//| suffix: "_GL" or "_GP". Returns 0 if none found.                   |
//+------------------------------------------------------------------+
int FindMaxGridLevelOnSide(ENUM_POSITION_TYPE side, string suffix)
{
   int maxLevel = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != side) continue;
      if(IsTicketBound(ticket)) continue;
      string comment = PositionGetString(POSITION_COMMENT);
      if(IsHedgeComment(comment)) continue;
      // Only current generation
      int orderGen = ExtractGeneration(comment);
      if(orderGen >= 0 && orderGen != g_cycleGeneration) continue;
      if(!MatchGMSuffix(comment, suffix)) continue;
      // Extract number after '#'
      int hashPos = StringFind(comment, "#");
      if(hashPos < 0) continue;
      int level = (int)StringToInteger(StringSubstr(comment, hashPos + 1));
      if(level > maxLevel) maxLevel = level;
   }
   return maxLevel;
}

//+------------------------------------------------------------------+
//| v6.41: Count GL orders for a specific generation + side            |
//+------------------------------------------------------------------+
int CountGenGridLoss(int gen, ENUM_POSITION_TYPE side)
{
   int count = 0;
   string prefix = GenPrefix(gen);
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != side) continue;
      string comment = PositionGetString(POSITION_COMMENT);
      if(IsHedgeComment(comment)) continue;
      if(IsTicketBound(ticket)) continue;
      int orderGen = ExtractGeneration(comment);
      if(orderGen != gen) continue;
      if(StringFind(comment, "_GL") >= 0) count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| v6.90: Count INIT + GL + GP for gen + side (mirrors avg-price)   |
//| Used by ManageMaxGridTrailing trigger gate so trailing activates  |
//| when the FULL basket (not just GL) reaches the threshold.         |
//+------------------------------------------------------------------+
int CountGenGridAll(int gen, ENUM_POSITION_TYPE side)
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != side) continue;
      string comment = PositionGetString(POSITION_COMMENT);
      if(IsHedgeComment(comment)) continue;
      if(IsTicketBound(ticket)) continue;
      if(IsHeroTicket(ticket)) continue; // v6.92
      int orderGen = ExtractGeneration(comment);
      if(orderGen != gen) continue;
      if(StringFind(comment, "_INIT") >= 0
         || StringFind(comment, "_GL") >= 0
         || StringFind(comment, "_GP") >= 0) count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| v6.86: Calc average price for gen + side (INIT + GL + GP)          |
//| v6.41 originally counted INIT+GL only; v6.86 includes GP so the    |
//| trailing avg reflects the full basket of the same generation.      |
//+------------------------------------------------------------------+
double CalcGenAveragePrice(int gen, ENUM_POSITION_TYPE side)
{
   double totalPrice = 0;
   double totalLots = 0;
   string prefix = GenPrefix(gen);
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != side) continue;
      string comment = PositionGetString(POSITION_COMMENT);
      if(IsHedgeComment(comment)) continue;
      if(IsTicketBound(ticket)) continue;
      if(IsHeroTicket(ticket)) continue; // v6.92
      int orderGen = ExtractGeneration(comment);
      if(orderGen != gen) continue;
      // v6.86: Include INIT, GL and GP (same generation, same side)
      if(StringFind(comment, "_INIT") < 0
         && StringFind(comment, "_GL") < 0
         && StringFind(comment, "_GP") < 0) continue;
      double lots = PositionGetDouble(POSITION_VOLUME);
      double price = PositionGetDouble(POSITION_PRICE_OPEN);
      totalPrice += price * lots;
      totalLots += lots;
   }
   if(totalLots <= 0) return 0;
   return totalPrice / totalLots;
}

//+------------------------------------------------------------------+
//| v6.86: Count total INIT+GL+GP orders for gen + side                |
//| Used by MaxGridTrailing auto-advance: if a gen still has GP only,  |
//| we must keep monitoring it instead of skipping forward.            |
//+------------------------------------------------------------------+
int CountGenOrders(int gen, ENUM_POSITION_TYPE side)
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != side) continue;
      string comment = PositionGetString(POSITION_COMMENT);
      if(IsHedgeComment(comment)) continue;
      if(IsTicketBound(ticket)) continue;
      if(IsHeroTicket(ticket)) continue; // v6.92
      int orderGen = ExtractGeneration(comment);
      if(orderGen != gen) continue;
      // v6.86: count INIT, GL and GP
      if(StringFind(comment, "_INIT") >= 0
         || StringFind(comment, "_GL") >= 0
         || StringFind(comment, "_GP") >= 0) count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| v6.86: Close all orders of a specific generation + side            |
//| Now closes INIT + GL + GP so trailing-SL hit flattens the entire   |
//| same-generation basket on that side (was INIT+GL only in v6.41).   |
//+------------------------------------------------------------------+
void CloseGenSide(int gen, ENUM_POSITION_TYPE side)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != side) continue;
      string comment = PositionGetString(POSITION_COMMENT);
      if(IsHedgeComment(comment)) continue;
      if(IsTicketBound(ticket)) continue;
      if(IsHeroTicket(ticket)) continue; // v6.92: keep Hero, only flatten basket
      int orderGen = ExtractGeneration(comment);
      if(orderGen != gen) continue;
      // v6.86: include _GP so the trailing close flattens the full basket
      if(StringFind(comment, "_INIT") >= 0
         || StringFind(comment, "_GL") >= 0
         || StringFind(comment, "_GP") >= 0)
         trade.PositionClose(ticket);
   }
   Print("v6.86 MaxGridTrail: Closed Gen", gen, " side=", (side == POSITION_TYPE_BUY ? "BUY" : "SELL"), " (INIT+GL+GP)");
   // v6.93 FIX: signal SAME-side Hero close (was opposite in v6.92).
   if(InpHero_Enabled && InpHero_CloseWithOpposite) {
      g_heroOppCloseSide = (int)side; // SAME side
      g_heroOppCloseTime = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| v6.41: Manage Max Grid Average Trailing Stop                       |
//+------------------------------------------------------------------+
void ManageMaxGridTrailing()
{
   // v6.89: Squeeze Pause — strip broker SL on edge + skip avg-trailing while in Expansion
   if(IsTrailingPausedAndHandleEdge()) return;
   // Reset if no orders at all
   if(TotalOrderCount() == 0)
   {
      g_maxGridMonitorGen = 0;
      g_maxGridTrailActive_Buy = false;
      g_maxGridTrailActive_Sell = false;
      g_maxGridTrailSL_Buy = 0;
      g_maxGridTrailSL_Sell = 0;
      return;
   }
   
   // Auto-advance generation: if current monitored gen has no orders, find next
   int maxGenToCheck = g_cycleGeneration;
   while(g_maxGridMonitorGen <= maxGenToCheck)
   {
      // Check if this gen has any orders
      int buyOrders = CountGenOrders(g_maxGridMonitorGen, POSITION_TYPE_BUY);
      int sellOrders = CountGenOrders(g_maxGridMonitorGen, POSITION_TYPE_SELL);
      if(buyOrders > 0 || sellOrders > 0) break;  // found active gen
      // No orders in this gen, advance
      g_maxGridTrailActive_Buy = false;
      g_maxGridTrailActive_Sell = false;
      g_maxGridTrailSL_Buy = 0;
      g_maxGridTrailSL_Sell = 0;
      g_maxGridMonitorGen++;
   }
   
   // If we've gone past all generations, reset
   if(g_maxGridMonitorGen > maxGenToCheck)
   {
      g_maxGridMonitorGen = 0;
      return;
   }
   
   int gen = g_maxGridMonitorGen;
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = _Point;
   
   // === BUY side trailing ===
   {
      // v6.90: trigger gate counts INIT+GL+GP (toggle to revert to GL-only)
      int glCount = InpMaxGridTrail_IncludeINITGP
                       ? CountGenGridAll(gen, POSITION_TYPE_BUY)
                       : CountGenGridLoss(gen, POSITION_TYPE_BUY);
      int requiredOrders_Buy = (MaxGrid_TrailMode == 1) ? MaxGrid_StartOrders : GridLoss_MaxTrades;  // v6.54
      if(glCount >= requiredOrders_Buy)
      {
         double avgPrice = CalcGenAveragePrice(gen, POSITION_TYPE_BUY);
         if(avgPrice > 0)
         {
            // v6.91: reset armReady flags when monitored gen changes
            if(g_maxGridArmReadyGen != gen)
            {
               g_maxGridArmReady_Buy  = false;
               g_maxGridArmReady_Sell = false;
               g_maxGridArmReadyGen   = gen;
            }

            // v6.91 STEP 1: price must first cross BELOW avg (basket truly stuck)
            //               before ARM is allowed. Skip when Strict2Cross=false.
            if(InpMaxGridArm_Strict2Cross && !g_maxGridArmReady_Buy)
            {
               double underThreshold = avgPrice - InpMaxGridArm_UnderAvgBuffer * point;
               if(bid <= underThreshold)
               {
                  g_maxGridArmReady_Buy = true;
                  Print("v6.91 MaxGridTrail BUY ARM-READY: Gen=", gen,
                        " bid=", bid, " <= avgUnder=", underThreshold,
                        " (waiting for cross-up to avg+", MaxGrid_TrailActivation, "pts)");
               }
            }

            double activationPrice = avgPrice + MaxGrid_TrailActivation * point;

            if(!g_maxGridTrailActive_Buy)
            {
               // v6.91 STEP 2: ARM only when armReady (or Strict2Cross=false) AND bid >= activation
               bool armGate = (!InpMaxGridArm_Strict2Cross) || g_maxGridArmReady_Buy;
               if(armGate && bid >= activationPrice)
               {
                  g_maxGridTrailActive_Buy = true;
                  g_maxGridTrailSL_Buy = avgPrice + MaxGrid_BreakevenBuffer * point;
                  Print("v6.91 MaxGridTrail BUY ACTIVATED: Gen=", gen, " AvgPrice=", avgPrice,
                        " SL=", g_maxGridTrailSL_Buy, " count=", glCount,
                        " mode=", (InpMaxGridTrail_IncludeINITGP ? "ALL" : "GL_ONLY"),
                        (InpMaxGridArm_Strict2Cross ? " (2-cross confirmed)" : " (legacy ARM)"));
               }
            }
            else
            {
               // Trailing is active — move SL up
               double newSL = bid - MaxGrid_TrailStep * point;
               if(newSL > g_maxGridTrailSL_Buy)
               {
                  g_maxGridTrailSL_Buy = newSL;
               }
               
               // Check if price hit trailing SL
               if(bid <= g_maxGridTrailSL_Buy)
               {
                  Print("v6.41 MaxGridTrail BUY HIT SL: Gen=", gen, " SL=", g_maxGridTrailSL_Buy, " Bid=", bid);
                  CloseGenSide(gen, POSITION_TYPE_BUY);
                  g_maxGridTrailActive_Buy = false;
                  g_maxGridTrailSL_Buy = 0;
                  g_maxGridArmReady_Buy = false;  // v6.91: reset for next cycle
               }
            }
         }
      }
      else
      {
         // Not at max grid — reset trailing for this side
         if(g_maxGridTrailActive_Buy)
         {
            g_maxGridTrailActive_Buy = false;
            g_maxGridTrailSL_Buy = 0;
         }
         g_maxGridArmReady_Buy = false;  // v6.91: count dropped → reset cross state
      }
   }
   
   // === SELL side trailing ===
   {
      // v6.90: trigger gate counts INIT+GL+GP (toggle to revert to GL-only)
      int glCount = InpMaxGridTrail_IncludeINITGP
                       ? CountGenGridAll(gen, POSITION_TYPE_SELL)
                       : CountGenGridLoss(gen, POSITION_TYPE_SELL);
      int requiredOrders_Sell = (MaxGrid_TrailMode == 1) ? MaxGrid_StartOrders : GridLoss_MaxTrades;  // v6.54
      if(glCount >= requiredOrders_Sell)
      {
         double avgPrice = CalcGenAveragePrice(gen, POSITION_TYPE_SELL);
         if(avgPrice > 0)
         {
            // v6.91: reset armReady flags when monitored gen changes
            if(g_maxGridArmReadyGen != gen)
            {
               g_maxGridArmReady_Buy  = false;
               g_maxGridArmReady_Sell = false;
               g_maxGridArmReadyGen   = gen;
            }

            // v6.91 STEP 1 (SELL): price must first cross ABOVE avg before ARM allowed
            if(InpMaxGridArm_Strict2Cross && !g_maxGridArmReady_Sell)
            {
               double overThreshold = avgPrice + InpMaxGridArm_UnderAvgBuffer * point;
               if(ask >= overThreshold)
               {
                  g_maxGridArmReady_Sell = true;
                  Print("v6.91 MaxGridTrail SELL ARM-READY: Gen=", gen,
                        " ask=", ask, " >= avgOver=", overThreshold,
                        " (waiting for cross-down to avg-", MaxGrid_TrailActivation, "pts)");
               }
            }

            double activationPrice = avgPrice - MaxGrid_TrailActivation * point;

            if(!g_maxGridTrailActive_Sell)
            {
               // v6.91 STEP 2 (SELL): ARM only when armReady AND ask <= activation
               bool armGate = (!InpMaxGridArm_Strict2Cross) || g_maxGridArmReady_Sell;
               if(armGate && ask <= activationPrice)
               {
                  g_maxGridTrailActive_Sell = true;
                  g_maxGridTrailSL_Sell = avgPrice - MaxGrid_BreakevenBuffer * point;
                  Print("v6.91 MaxGridTrail SELL ACTIVATED: Gen=", gen, " AvgPrice=", avgPrice,
                        " SL=", g_maxGridTrailSL_Sell, " count=", glCount,
                        " mode=", (InpMaxGridTrail_IncludeINITGP ? "ALL" : "GL_ONLY"),
                        (InpMaxGridArm_Strict2Cross ? " (2-cross confirmed)" : " (legacy ARM)"));
               }
            }
            else
            {
               // Trailing is active — move SL down
               double newSL = ask + MaxGrid_TrailStep * point;
               if(newSL < g_maxGridTrailSL_Sell || g_maxGridTrailSL_Sell == 0)
               {
                  g_maxGridTrailSL_Sell = newSL;
               }
               
               // Check if price hit trailing SL (for SELL, ask goes above SL)
               if(ask >= g_maxGridTrailSL_Sell)
               {
                  Print("v6.41 MaxGridTrail SELL HIT SL: Gen=", gen, " SL=", g_maxGridTrailSL_Sell, " Ask=", ask);
                  CloseGenSide(gen, POSITION_TYPE_SELL);
                  g_maxGridTrailActive_Sell = false;
                  g_maxGridTrailSL_Sell = 0;
                  g_maxGridArmReady_Sell = false;  // v6.91: reset for next cycle
               }
            }
         }
      }
      else
      {
         // Not at max grid — reset trailing for this side
         if(g_maxGridTrailActive_Sell)
         {
            g_maxGridTrailActive_Sell = false;
            g_maxGridTrailSL_Sell = 0;
         }
         g_maxGridArmReady_Sell = false;  // v6.91: count dropped → reset cross state
      }
   }
}

// === v6.40: Candle Confirmation Helper ===
// Checks if the last N closed candles (shift 1..N) all confirm the trade direction
// BUY: all N candles must be bullish (close > open)
// SELL: all N candles must be bearish (close < open)
bool HasCandleConfirmation(ENUM_POSITION_TYPE side, ENUM_TIMEFRAMES tf, int requiredCandles)
{
   if(requiredCandles <= 0) return true;
   
   for(int i = 1; i <= requiredCandles; i++)
   {
      double o = iOpen(_Symbol, tf, i);
      double c = iClose(_Symbol, tf, i);
      
      if(side == POSITION_TYPE_BUY)
      {
         if(c <= o) return false;
      }
      else
      {
         if(c >= o) return false;
      }
   }
   return true;
}

//+------------------------------------------------------------------+
void CheckGridLoss(ENUM_POSITION_TYPE side, int currentGridCount)
{
   if(currentGridCount >= GridLoss_MaxTrades) return;
   if(NormalOrderCount() >= MaxOpenOrders) return;

   //--- OnlyNewCandle check
   if(GridLoss_OnlyNewCandle)
   {
      datetime barTime = iTime(_Symbol, PERIOD_CURRENT, 0);
      if(barTime == lastGridLossCandleTime) return;
   }

   //--- v6.40: Candle Confirmation check
   if(GridLoss_CandleConfirm > 0)
   {
      if(!HasCandleConfirmation(side, PERIOD_CURRENT, GridLoss_CandleConfirm)) return;
   }

   //--- Check signal filter
   if(GridLoss_OnlyInSignal)
   {
      double sma = bufSMA[0];
      double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(side == POSITION_TYPE_BUY && price < sma) return;
      if(side == POSITION_TYPE_SELL && price > sma) return;
   }

   //--- Find the last order of this side (initial or grid loss)
   //--- Uses initial price as fallback when per-order trailing closed grid orders
   double lastPrice = 0;
   datetime lastTime = 0;
   FindLastOrder(side, "_INIT", "_GL", lastPrice, lastTime);

   //--- Fallback: use initial order price if no open order found
   if(lastPrice == 0)
   {
      if(side == POSITION_TYPE_BUY && g_initialBuyPrice > 0)
         lastPrice = g_initialBuyPrice;
      else if(side == POSITION_TYPE_SELL && g_initialSellPrice > 0)
         lastPrice = g_initialSellPrice;
      else
         return;
   }

   //--- Check same candle restriction
   if(GridLoss_DontSameCandle)
   {
      datetime barTime = iTime(_Symbol, PERIOD_CURRENT, 0);
      if(lastTime >= barTime) return;
   }

   //--- Calculate required distance
   double distance = GetGridDistance(currentGridCount, true);
   if(distance <= 0) return;

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double currentPrice = (side == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   bool shouldOpen = false;

   if(GridLoss_GapType == GAP_ATR && GridLoss_ATR_Reference == ATR_REF_INITIAL)
   {
      // Initial mode: cumulative distance from initial price
      double initialRef = (side == POSITION_TYPE_BUY) ? g_initialBuyPrice : g_initialSellPrice;
      if(initialRef <= 0) return;
      double totalDistance = distance * (currentGridCount + 1);
      if(side == POSITION_TYPE_BUY)
         shouldOpen = (currentPrice <= initialRef - totalDistance * point);
      else
         shouldOpen = (currentPrice >= initialRef + totalDistance * point);
   }
   else
   {
      // Dynamic mode (default): distance from last grid order
      if(side == POSITION_TYPE_BUY && currentPrice <= lastPrice - distance * point)
         shouldOpen = true;
      else if(side == POSITION_TYPE_SELL && currentPrice >= lastPrice + distance * point)
         shouldOpen = true;
   }

   if(shouldOpen)
   {
      double lots = CalculateGridLot(currentGridCount, true);
      
      //--- Ensure lot continues from max existing lot after matching close
      double maxExisting = FindMaxLotOnSide(side);
      if(maxExisting > 0 && lots <= maxExisting)
      {
         if(GridLoss_LotMode == LOT_MULTIPLY)
            lots = maxExisting * GridLoss_MultiplyFactor;
         else if(GridLoss_LotMode == LOT_ADD)
            lots = maxExisting + InitialLotSize * GridLoss_AddLotPerLevel;
         // LOT_CUSTOM: keep level-based calculation
      }
      
      // v6.71: never reuse a level number that's already open after hedge unlock
      int _maxLvlGL = FindMaxGridLevelOnSide(side, "_GL");
      int _nextLvlGL = (int)MathMax(_maxLvlGL + 1, currentGridCount + 1);
      string comment = GetCommentPrefix() + "_GL#" + IntegerToString(_nextLvlGL);
      ENUM_ORDER_TYPE orderType = (side == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      if(OpenOrder(orderType, lots, comment))
      {
         lastGridLossCandleTime = iTime(_Symbol, PERIOD_CURRENT, 0);
      }
   }
}

//+------------------------------------------------------------------+
//| Check Grid Profit                                                  |
//+------------------------------------------------------------------+
void CheckGridProfit(ENUM_POSITION_TYPE side, int currentGridCount)
{
   if(currentGridCount >= GridProfit_MaxTrades) return;
   if(NormalOrderCount() >= MaxOpenOrders) return;

   //--- OnlyNewCandle check
   if(GridProfit_OnlyNewCandle)
   {
      datetime barTime = iTime(_Symbol, PERIOD_CURRENT, 0);
      if(barTime == lastGridProfitCandleTime) return;
   }

   //--- v6.82: Candle Confirmation check (mirror of GL CandleConfirm)
   if(GridProfit_CandleConfirm > 0)
   {
      if(!HasCandleConfirmation(side, PERIOD_CURRENT, GridProfit_CandleConfirm)) return;
   }

   //--- Find the last order of this side (initial or grid profit)
   double lastPrice = 0;
   datetime lastTime = 0;
   FindLastOrder(side, "_INIT", "_GP", lastPrice, lastTime);

   //--- Fallback: use initial order price
   if(lastPrice == 0)
   {
      if(side == POSITION_TYPE_BUY && g_initialBuyPrice > 0)
         lastPrice = g_initialBuyPrice;
      else if(side == POSITION_TYPE_SELL && g_initialSellPrice > 0)
         lastPrice = g_initialSellPrice;
      else
         return;
   }

   //--- Calculate required distance
   double distance = GetGridDistance(currentGridCount, false);
   if(distance <= 0) return;

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double currentPrice = (side == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   bool shouldOpen = false;

   if(GridProfit_GapType == GAP_ATR && GridProfit_ATR_Reference == ATR_REF_INITIAL)
   {
      // Initial mode: cumulative distance from initial price
      double initialRef = (side == POSITION_TYPE_BUY) ? g_initialBuyPrice : g_initialSellPrice;
      if(initialRef <= 0) return;
      double totalDistance = distance * (currentGridCount + 1);
      if(side == POSITION_TYPE_BUY)
         shouldOpen = (currentPrice >= initialRef + totalDistance * point);
      else
         shouldOpen = (currentPrice <= initialRef - totalDistance * point);
   }
   else
   {
      // Dynamic mode (default): distance from last grid order
      if(side == POSITION_TYPE_BUY && currentPrice >= lastPrice + distance * point)
         shouldOpen = true;
      else if(side == POSITION_TYPE_SELL && currentPrice <= lastPrice - distance * point)
         shouldOpen = true;
   }

   if(shouldOpen)
   {
      double lots = CalculateGridLot(currentGridCount, false);
      // v6.71: never reuse a level number that's already open
      int _maxLvlGP = FindMaxGridLevelOnSide(side, "_GP");
      int _nextLvlGP = (int)MathMax(_maxLvlGP + 1, currentGridCount + 1);
      string comment = GetCommentPrefix() + "_GP#" + IntegerToString(_nextLvlGP);
      ENUM_ORDER_TYPE orderType = (side == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      if(OpenOrder(orderType, lots, comment))
      {
         lastGridProfitCandleTime = iTime(_Symbol, PERIOD_CURRENT, 0);
      }
   }
}

//+------------------------------------------------------------------+
//| Find last order price for a side (matching comment prefixes)       |
//+------------------------------------------------------------------+
void FindLastOrder(ENUM_POSITION_TYPE side, string suffix1, string suffix2, double &outPrice, datetime &outTime)
{
   outPrice = 0;
   outTime = 0;
   datetime latestTime = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) != side) continue;
      if(IsTicketBound(ticket)) continue;

      string comment = PositionGetString(POSITION_COMMENT);
      if(IsHedgeComment(comment)) continue;
      // v6.23: Skip orders from previous generations
      int orderGen = ExtractGeneration(comment);
      if(orderGen >= 0 && orderGen != g_cycleGeneration) continue;
      if(MatchGMSuffix(comment, suffix1) || MatchGMSuffix(comment, suffix2))
      {
         datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
         if(openTime > latestTime)
         {
            latestTime = openTime;
            outPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            outTime = openTime;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Simplified ATR Calculation (v3.0 - No Indicator Handle)            |
//| Port from Multi_Currency_Statistical_EA for backtest optimization  |
//+------------------------------------------------------------------+
double CalculateSimplifiedATR(string symbol, ENUM_TIMEFRAMES tf, int period)
{
   double sum = 0;
   int validBars = 0;
   
   for(int i = 1; i <= period; i++)
   {
      double high = iHigh(symbol, tf, i);
      double low = iLow(symbol, tf, i);
      double prevClose = iClose(symbol, tf, i + 1);
      
      if(high == 0 || low == 0 || prevClose == 0) continue;
      
      double tr1 = high - low;
      double tr2 = MathAbs(high - prevClose);
      double tr3 = MathAbs(low - prevClose);
      
      sum += MathMax(tr1, MathMax(tr2, tr3));
      validBars++;
   }
   
   if(validBars == 0) return 0;
   return sum / validBars;
}

//+------------------------------------------------------------------+
//| Get grid distance in points                                        |
//+------------------------------------------------------------------+
double GetGridDistance(int level, bool isLossSide)
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   if(isLossSide)
   {
      if(GridLoss_GapType == GAP_FIXED)
      {
         return (double)GridLoss_Points;
      }
      else if(GridLoss_GapType == GAP_CUSTOM)
      {
         return ParseCustomValue(GridLoss_CustomDistance, level);
      }
      else // ATR - use index 1 (closed bar) to prevent repaint
      {
         double atrVal = 0;
         if(g_isTesterMode && InpSkipATRInTester)
         {
            atrVal = CalculateSimplifiedATR(_Symbol, GridLoss_ATR_TF, GridLoss_ATR_Period);
         }
         else
         {
            atrVal = (ArraySize(bufATR_Loss) > 1 && bufATR_Loss[1] > 0) ? bufATR_Loss[1] : bufATR_Loss[0];
         }
         if(atrVal > 0)
         {
            double atrDistance = atrVal * GridLoss_ATR_Multiplier / point;
            // Apply minimum gap to prevent too-tight grids on low ATR
            atrDistance = MathMax(atrDistance, (double)GridLoss_MinGapPoints);
            return atrDistance;
         }
         return (double)GridLoss_Points;
      }
   }
   else
   {
      if(GridProfit_GapType == GAP_FIXED)
      {
         return (double)GridProfit_Points;
      }
      else if(GridProfit_GapType == GAP_CUSTOM)
      {
         return ParseCustomValue(GridProfit_CustomDistance, level);
      }
      else // ATR - use index 1 (closed bar) to prevent repaint
      {
         double atrVal = 0;
         if(g_isTesterMode && InpSkipATRInTester)
         {
            atrVal = CalculateSimplifiedATR(_Symbol, GridProfit_ATR_TF, GridProfit_ATR_Period);
         }
         else
         {
            atrVal = (ArraySize(bufATR_Profit) > 1 && bufATR_Profit[1] > 0) ? bufATR_Profit[1] : bufATR_Profit[0];
         }
         if(atrVal > 0)
         {
            double atrDistance = atrVal * GridProfit_ATR_Multiplier / point;
            // Apply minimum gap to prevent too-tight grids on low ATR
            atrDistance = MathMax(atrDistance, (double)GridProfit_MinGapPoints);
            return atrDistance;
         }
         return (double)GridProfit_Points;
      }
   }
}

//+------------------------------------------------------------------+
//| Calculate grid lot size                                            |
//+------------------------------------------------------------------+
double CalculateGridLot(int level, bool isLossSide)
{
   if(isLossSide)
   {
      if(GridLoss_LotMode == LOT_ADD)
      {
         return InitialLotSize + InitialLotSize * GridLoss_AddLotPerLevel * (level + 1);
      }
      else if(GridLoss_LotMode == LOT_CUSTOM)
      {
         return ParseCustomValue(GridLoss_CustomLots, level);
      }
      else // MULTIPLY
      {
         return InitialLotSize * MathPow(GridLoss_MultiplyFactor, level + 1);
      }
   }
   else
   {
      if(GridProfit_LotMode == LOT_ADD)
      {
         return InitialLotSize + InitialLotSize * GridProfit_AddLotPerLevel * (level + 1);
      }
      else if(GridProfit_LotMode == LOT_CUSTOM)
      {
         return ParseCustomValue(GridProfit_CustomLots, level);
      }
      else // MULTIPLY
      {
         return InitialLotSize * MathPow(GridProfit_MultiplyFactor, level + 1);
      }
   }
}

//+------------------------------------------------------------------+
//| Parse semicolon-separated values                                   |
//+------------------------------------------------------------------+
double ParseCustomValue(string inputStr, int index)
{
   string parts[];
   ushort sep = StringGetCharacter(";", 0);
   int count = StringSplit(inputStr, sep, parts);
   if(count <= 0) return 0;

   int idx = MathMin(index, count - 1);
   return StringToDouble(parts[idx]);
}

//+------------------------------------------------------------------+
//| Draw chart lines                                                   |
//+------------------------------------------------------------------+
void DrawLines()
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   double avgBuy = CalculateAveragePrice(POSITION_TYPE_BUY);
   double avgSell = CalculateAveragePrice(POSITION_TYPE_SELL);

   //--- Average Buy Line
   if(avgBuy > 0 && ShowAverageLine)
      DrawHLine("GM_AvgBuyLine", avgBuy, AvgBuyLineColor, STYLE_SOLID, 2);
   else
      ObjectDelete(0, "GM_AvgBuyLine");

   //--- Average Sell Line
   if(avgSell > 0 && ShowAverageLine)
      DrawHLine("GM_AvgSellLine", avgSell, AvgSellLineColor, STYLE_SOLID, 2);
   else
      ObjectDelete(0, "GM_AvgSellLine");

   //--- TP Buy Line
   if(ShowTPLine && UseTP_Points && avgBuy > 0)
      DrawHLine("GM_TPBuyLine", avgBuy + TP_Points * point, TPBuyLineColor, STYLE_DASH, 1);
   else
      ObjectDelete(0, "GM_TPBuyLine");

   //--- TP Sell Line
   if(ShowTPLine && UseTP_Points && avgSell > 0)
      DrawHLine("GM_TPSellLine", avgSell - TP_Points * point, TPSellLineColor, STYLE_DASH, 1);
   else
      ObjectDelete(0, "GM_TPSellLine");

   //--- SL Line (show trailing SL if active, otherwise show SL Points)
   if(ShowSLLine)
   {
      bool drawn = false;

      if(g_trailingActive_Buy && g_trailingSL_Buy > 0)
      {
         DrawHLine("GM_SLLine", g_trailingSL_Buy, SLLineColor, STYLE_DASH, 1);
         drawn = true;
      }
      else if(g_trailingActive_Sell && g_trailingSL_Sell > 0)
      {
         DrawHLine("GM_SLLine", g_trailingSL_Sell, SLLineColor, STYLE_DASH, 1);
         drawn = true;
      }

      if(!drawn && UseSL_Points)
      {
         if(avgBuy > 0)
         {
            DrawHLine("GM_SLLine", avgBuy - SL_Points * point, SLLineColor, STYLE_DASH, 1);
         }
         else if(avgSell > 0)
         {
            DrawHLine("GM_SLLine", avgSell + SL_Points * point, SLLineColor, STYLE_DASH, 1);
         }
         else
         {
            ObjectDelete(0, "GM_SLLine");
         }
      }
      else if(!drawn)
      {
         ObjectDelete(0, "GM_SLLine");
      }
   }
   else
   {
      ObjectDelete(0, "GM_SLLine");
   }
}

//+------------------------------------------------------------------+
//| Draw horizontal line                                               |
//+------------------------------------------------------------------+
void DrawHLine(string name, double price, color clr, ENUM_LINE_STYLE style, int width)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
   }
   ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Dashboard Helper: Create Rectangle Label                           |
//+------------------------------------------------------------------+
void CreateDashRect(string name, int x, int y, int w, int h, color bgColor)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgColor);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, bgColor);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Dashboard Helper: Create Text Label                                |
//+------------------------------------------------------------------+
void CreateDashText(string name, int x, int y, string text, color clr, int fontSize, string font)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, font);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Dashboard Helper: Draw one table row                               |
//+------------------------------------------------------------------+
void DrawTableRow(int rowIndex, string label, string value, color valueColor, color sectionColor)
{
   double sc = MathMax(0.8, MathMin(1.5, DashboardScale));
   int x = DashboardX;
   int rowH = (int)(20 * sc);
   int y = DashboardY + (int)(24 * sc) + rowIndex * rowH;
   int tblW = (int)(DashboardWidth * sc);
   int rH = (int)(19 * sc);
   int sectionBarWidth = (int)(4 * sc);
   int labelX = x + sectionBarWidth + (int)(6 * sc);
   int valueX = x + (int)(180 * sc);
   int fSize = (int)(9 * sc);
   if(fSize < 7) fSize = 7;

   // Alternating row background
   color rowBg = (rowIndex % 2 == 0) ? C'40,44,52' : C'35,39,46';

   string rowName = "GM_TBL_R" + IntegerToString(rowIndex);
   string secName = "GM_TBL_S" + IntegerToString(rowIndex);
   string lblName = "GM_TBL_L" + IntegerToString(rowIndex);
   string valName = "GM_TBL_V" + IntegerToString(rowIndex);

   // Row background
   CreateDashRect(rowName, x, y, tblW, rH, rowBg);
   // Section color bar
   CreateDashRect(secName, x, y, sectionBarWidth, rH, sectionColor);
   // Label text
   CreateDashText(lblName, labelX, y + 2, label, C'180,180,180', fSize, "Consolas");
   // Value text
   CreateDashText(valName, valueX, y + 2, value, valueColor, fSize, "Consolas");
}

//+------------------------------------------------------------------+
//| Display Dashboard - Table Layout v2.3                              |
//+------------------------------------------------------------------+
void DisplayDashboard()
{
   // Stale row cleanup moved to end of function (prevents flicker)
   
   double sc = MathMax(0.8, MathMin(1.5, DashboardScale));
   int tableWidth = (int)(DashboardWidth * sc);
   int headerHeight = (int)(22 * sc);
   int headerFontSize = (int)(11 * sc);
   if(headerFontSize < 8) headerFontSize = 8;
   int subFontSize = (int)(9 * sc);
   if(subFontSize < 7) subFontSize = 7;

   // Colors
   color COLOR_HEADER_BG     = C'180,130,50';
   color COLOR_HEADER_TEXT   = clrWhite;
   color COLOR_SECTION_DETAIL = clrGreen;
   color COLOR_SECTION_ACCUM  = clrYellow;
   color COLOR_SECTION_TRAIL  = clrMagenta;
   color COLOR_SECTION_INFO   = clrDodgerBlue;
   color COLOR_PROFIT         = clrLime;
   color COLOR_LOSS           = clrOrangeRed;
   color COLOR_TEXT           = clrWhite;

   //--- Gather data
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double plBuy = CalculateFloatingPL(POSITION_TYPE_BUY);
   double plSell = CalculateFloatingPL(POSITION_TYPE_SELL);
   double totalPL = plBuy + plSell;
   double dd = (balance > 0) ? (balance - equity) / balance * 100.0 : 0;
   double lotsBuy = CalculateTotalLots(POSITION_TYPE_BUY);
   double lotsSell = CalculateTotalLots(POSITION_TYPE_SELL);

   int buyCount = 0, sellCount = 0;
   int glB = 0, glS = 0, gpB = 0, gpS = 0;
   bool ib = false, is2 = false;
   CountPositions(buyCount, sellCount, glB, glS, gpB, gpS, ib, is2);

   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

   string smaDir = "";
   if(EntryMode == ENTRY_SMA && ArraySize(bufSMA) > 0 && bufSMA[0] > 0)
   {
      double bidPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      smaDir = (bidPrice > bufSMA[0]) ? "BUY ▲" : "SELL ▼";
   }

   string tradeModeStr = (TradingMode == TRADE_BUY_ONLY) ? "Buy Only" :
                           (TradingMode == TRADE_SELL_ONLY) ? "Sell Only" : "Both";

   //--- Header
   string headerVersion = (EntryMode == ENTRY_SMA) ? "Gold Miner EA v6.94 [SMA]" : (EntryMode == ENTRY_ZIGZAG) ? "Gold Miner EA v6.94 [ZZ]" : "Gold Miner EA v6.94 [INST]";
   CreateDashRect("GM_TBL_HDR", DashboardX, DashboardY, tableWidth, headerHeight, COLOR_HEADER_BG);
   CreateDashText("GM_TBL_HDR_T", DashboardX + 8, DashboardY + 3, headerVersion, COLOR_HEADER_TEXT, headerFontSize, "Arial Bold");
   CreateDashText("GM_TBL_HDR_M", DashboardX + (int)(220 * sc), DashboardY + 4, "Mode: " + tradeModeStr, COLOR_HEADER_TEXT, subFontSize, "Consolas");

   //--- DETAIL Section
   int row = 0;
   DrawTableRow(row, "Balance",       "$" + DoubleToString(balance, 2),  COLOR_TEXT, COLOR_SECTION_DETAIL); row++;
   DrawTableRow(row, "Equity",        "$" + DoubleToString(equity, 2),   COLOR_TEXT, COLOR_SECTION_DETAIL); row++;
   DrawTableRow(row, "Floating P/L",  "$" + DoubleToString(totalPL, 2),  (totalPL >= 0 ? COLOR_PROFIT : COLOR_LOSS), COLOR_SECTION_DETAIL); row++;

   if(EntryMode == ENTRY_SMA)
   {
      DrawTableRow(row, "Signal (SMA" + IntegerToString(SMA_Period) + ")", smaDir, (smaDir == "BUY ▲" ? COLOR_PROFIT : COLOR_LOSS), COLOR_SECTION_DETAIL); row++;
   }
   else
   {
      // ZigZag MTF info rows
      color COLOR_SECTION_ZZ = clrDarkOrange;

      // CDC Trend
      if(InpUseCDCFilter)
      {
         color cdcColor = (g_cdcTrend == "BULLISH") ? COLOR_PROFIT : (g_cdcTrend == "BEARISH") ? COLOR_LOSS : clrYellow;
         string cdcStatus = g_cdcReady ? g_cdcTrend : "LOADING";
         if(!g_cdcReady) cdcColor = clrYellow;
         DrawTableRow(row, "CDC Trend", cdcStatus, cdcColor, COLOR_SECTION_ZZ); row++;
      }

      // H4 Direction
      color h4Color = (g_h4Direction == "BUY") ? COLOR_PROFIT : (g_h4Direction == "SELL") ? COLOR_LOSS : clrYellow;
      DrawTableRow(row, "H4 Direction", g_h4Direction, h4Color, COLOR_SECTION_ZZ); row++;

      // Per-TF status
      for(int tf = 0; tf < g_activeTFCount; tf++)
      {
         if(g_tfStates[tf].tf == ZZ_ConfirmTF && !ZZ_UseConfirmTFEntry) continue;

         int tfB2 = 0, tfS2 = 0, tGL2 = 0, tGLS2 = 0, tGP2 = 0, tGPS2 = 0;
         bool tIB2 = false, tIS2 = false;
         CountPositionsTF(tf, tfB2, tfS2, tGL2, tGLS2, tGP2, tGPS2, tIB2, tIS2);

         string tfInfo = IntegerToString(tfB2) + "B/" + IntegerToString(tfS2) + "S";
         if(!g_tfStates[tf].enabled) tfInfo = "OFF";
         color tfColor2 = (tfB2 > 0 || tfS2 > 0) ? clrGold : COLOR_TEXT;
         DrawTableRow(row, g_tfStates[tf].tfLabel, tfInfo, tfColor2, COLOR_SECTION_ZZ); row++;
      }
   }

   // Buy position info
   string buyInfo = "$" + DoubleToString(plBuy, 2) + "  " + DoubleToString(lotsBuy, 2) + "L  " + IntegerToString(buyCount) + "ord";
   DrawTableRow(row, "Position BUY",  buyInfo, (plBuy >= 0 ? COLOR_PROFIT : COLOR_LOSS), COLOR_SECTION_DETAIL); row++;

   // Sell position info
   string sellInfo = "$" + DoubleToString(plSell, 2) + "  " + DoubleToString(lotsSell, 2) + "L  " + IntegerToString(sellCount) + "ord";
   DrawTableRow(row, "Position SELL", sellInfo, (plSell >= 0 ? COLOR_PROFIT : COLOR_LOSS), COLOR_SECTION_DETAIL); row++;

   if(DrawdownMode == DD_FIXED_DOLLAR)
   {
      double ddDollar = balance - equity;
      DrawTableRow(row, "Current DD",   "$" + DoubleToString(ddDollar, 2) + " / $" + DoubleToString(MaxDrawdownDollar, 2),
                   (ddDollar > MaxDrawdownDollar * 0.5 ? COLOR_LOSS : COLOR_TEXT), COLOR_SECTION_DETAIL); row++;
      DrawTableRow(row, "Max DD%",      DoubleToString(g_maxDD, 2) + "%",
                   (g_maxDD > 15 ? COLOR_LOSS : COLOR_TEXT), COLOR_SECTION_DETAIL); row++;
   }
   else
   {
      DrawTableRow(row, "Current DD%",   DoubleToString(dd, 2) + "% / " + DoubleToString(MaxDrawdownPct, 1) + "%",
                   (dd > 10 ? COLOR_LOSS : COLOR_TEXT), COLOR_SECTION_DETAIL); row++;
      DrawTableRow(row, "Max DD%",       DoubleToString(g_maxDD, 2) + "%",
                   (g_maxDD > 15 ? COLOR_LOSS : COLOR_TEXT), COLOR_SECTION_DETAIL); row++;
   }

   //--- ACCUMULATE Section
   if(UseAccumulateClose)
   {
      double accumClosed = g_accumulatedProfit;
      double accumFloating = CalculateTotalFloatingPL();
      double accumTotal = accumClosed + accumFloating;
      double accumNeed = AccumulateTarget - accumTotal;
      if(accumNeed < 0) accumNeed = 0;

      DrawTableRow(row, "Accum. Closed",   "$" + DoubleToString(accumClosed, 2),   (accumClosed >= 0 ? COLOR_PROFIT : COLOR_LOSS), COLOR_SECTION_ACCUM); row++;
      DrawTableRow(row, "Accum. Floating",  "$" + DoubleToString(accumFloating, 2), (accumFloating >= 0 ? COLOR_PROFIT : COLOR_LOSS), COLOR_SECTION_ACCUM); row++;

      string accumTotalStr = "$" + DoubleToString(accumTotal, 2)
                           + "  Tg:$" + DoubleToString(AccumulateTarget, 0)
                           + "  Need:$" + DoubleToString(accumNeed, 0);
      DrawTableRow(row, "Accum. Total",    accumTotalStr, (accumTotal >= 0 ? COLOR_PROFIT : COLOR_LOSS), COLOR_SECTION_ACCUM); row++;
   }

   //--- DD% TP Section (v6.7)
   if(UseTP_DDPercent)
   {
      color COLOR_SECTION_DDTP = C'180,80,50';  // warm orange for DD% TP
      // v6.44: reuse plBuy/plSell from top of function (no redundant recalculation)
      double plBuyTP = plBuy;
      double plSellTP = plSell;
      
      // BUY side
      if(g_maxDDBuy < 0)
      {
         double tpTargetBuy = MathAbs(g_maxDDBuy) * TP_DDPercent / 100.0;
         string ddBuyStr = StringFormat("MaxDD=$%.2f | Tg=+$%.2f | Cur=$%.2f", g_maxDDBuy, tpTargetBuy, plBuyTP);
         DrawTableRow(row, "DD%TP Buy", ddBuyStr, (plBuyTP >= tpTargetBuy && plBuyTP > 0) ? COLOR_PROFIT : COLOR_TEXT, COLOR_SECTION_DDTP); row++;
      }
      else
      {
         DrawTableRow(row, "DD%TP Buy", "Tracking...", COLOR_TEXT, COLOR_SECTION_DDTP); row++;
      }
      
      // SELL side
      if(g_maxDDSell < 0)
      {
         double tpTargetSell = MathAbs(g_maxDDSell) * TP_DDPercent / 100.0;
         string ddSellStr = StringFormat("MaxDD=$%.2f | Tg=+$%.2f | Cur=$%.2f", g_maxDDSell, tpTargetSell, plSellTP);
         DrawTableRow(row, "DD%TP Sell", ddSellStr, (plSellTP >= tpTargetSell && plSellTP > 0) ? COLOR_PROFIT : COLOR_TEXT, COLOR_SECTION_DDTP); row++;
      }
      else
      {
         DrawTableRow(row, "DD%TP Sell", "Tracking...", COLOR_TEXT, COLOR_SECTION_DDTP); row++;
      }
   }

   //--- TRAILING Section
   if(EnablePerOrderTrailing)
   {
      string beInfo = InpEnableBreakeven ? "BE:" + IntegerToString(InpBreakevenTarget) + "/" + IntegerToString(InpBreakevenOffset) : "BE:OFF";
      string trInfo = InpEnableTrailing ? "Trail:" + IntegerToString(InpTrailingStop) + "/" + IntegerToString(InpTrailingStep) : "Trail:OFF";
      DrawTableRow(row, "Per-Order",  beInfo + "  " + trInfo, COLOR_TEXT, COLOR_SECTION_TRAIL); row++;
   }
   else if(EnableTrailingStop)
   {
      string trailInfo = "";
      if(g_trailingActive_Buy) trailInfo = "Buy SL:" + DoubleToString(g_trailingSL_Buy, digits);
      else if(g_trailingActive_Sell) trailInfo = "Sell SL:" + DoubleToString(g_trailingSL_Sell, digits);
      else trailInfo = "Waiting...";
      DrawTableRow(row, "Avg Trailing",  trailInfo, COLOR_TEXT, COLOR_SECTION_TRAIL); row++;
   }

   //--- INFO Section (History metrics - removed BUY/SELL Cycle rows)
   color COLOR_SECTION_HIST = C'50,100,180';  // distinct blue for history section

   // Current open lot total
   // v6.44: reuse lotsBuy/lotsSell from top of function
   double totalCurrentLots = lotsBuy + lotsSell;
   DrawTableRow(row, "Total Cur. Lot",   DoubleToString(totalCurrentLots, 2) + " L", COLOR_TEXT, COLOR_SECTION_HIST); row++;

    // History metrics — v6.42: cached every 5 seconds to reduce CPU load
    if(TimeCurrent() - g_lastDashHistoryCalcTime >= g_dashCacheIntervalSec)
    {
       g_cachedClosedLots    = CalcTotalClosedLots();
       g_cachedClosedOrders  = CalcTotalClosedOrders();
       g_cachedMonthlyPL     = CalcMonthlyPL();
       g_cachedTotalPLHist   = CalcTotalHistoryProfit();
       g_cachedDailyClosedLots = CalcDailyClosedLots();
       g_lastDashHistoryCalcTime = TimeCurrent();
    }
    double closedLots   = g_cachedClosedLots;
    int    closedOrders = g_cachedClosedOrders;
    double monthlyPL    = g_cachedMonthlyPL;
    double totalPLHist  = g_cachedTotalPLHist;

    DrawTableRow(row, "Total Closed Lot", DoubleToString(closedLots, 2) + " L", COLOR_TEXT, COLOR_SECTION_HIST); row++;

    // Rebate metrics
    double dailyClosedLots = g_cachedDailyClosedLots;
   double dailyRebate     = dailyClosedLots * InpRebatePerLot;
   double totalRebate     = closedLots * InpRebatePerLot;
   color  COLOR_SECTION_REBATE = C'180,150,50';  // gold for rebate section
   DrawTableRow(row, "Daily Closed Lot", DoubleToString(dailyClosedLots, 2) + " L", COLOR_TEXT, COLOR_SECTION_REBATE); row++;
   DrawTableRow(row, "Daily Rebate",     "$" + DoubleToString(dailyRebate, 2), COLOR_PROFIT, COLOR_SECTION_REBATE); row++;
   DrawTableRow(row, "Total Rebate",     "$" + DoubleToString(totalRebate, 2), COLOR_PROFIT, COLOR_SECTION_REBATE); row++;

   DrawTableRow(row, "Total Closed Ord", IntegerToString(closedOrders) + " orders", COLOR_TEXT, COLOR_SECTION_HIST); row++;
   DrawTableRow(row, "Monthly P/L",      "$" + DoubleToString(monthlyPL, 2), (monthlyPL >= 0 ? COLOR_PROFIT : COLOR_LOSS), COLOR_SECTION_HIST); row++;
   DrawTableRow(row, "Total P/L",        "$" + DoubleToString(totalPLHist, 2), (totalPLHist >= 0 ? COLOR_PROFIT : COLOR_LOSS), COLOR_SECTION_HIST); row++;

   DrawTableRow(row, "Auto Re-Entry", (EnableAutoReEntry ? "ON" : "OFF"), (EnableAutoReEntry ? COLOR_PROFIT : COLOR_LOSS), COLOR_SECTION_INFO); row++;

   // v6.42: Broker TP/SL display
   if(UseTP_Points || (EnableSL && UseSL_Points))
   {
      color COLOR_SECTION_BROKER = C'50,130,100';
      if(g_lastBrokerTP_Buy > 0)
      {  DrawTableRow(row, "Broker TP BUY", DoubleToString(g_lastBrokerTP_Buy, digits), COLOR_PROFIT, COLOR_SECTION_BROKER); row++; }
      if(g_lastBrokerTP_Sell > 0)
      {  DrawTableRow(row, "Broker TP SELL", DoubleToString(g_lastBrokerTP_Sell, digits), COLOR_PROFIT, COLOR_SECTION_BROKER); row++; }
      if(g_lastBrokerSL_Buy > 0)
      {  DrawTableRow(row, "Broker SL BUY", DoubleToString(g_lastBrokerSL_Buy, digits), COLOR_LOSS, COLOR_SECTION_BROKER); row++; }
      if(g_lastBrokerSL_Sell > 0)
      {  DrawTableRow(row, "Broker SL SELL", DoubleToString(g_lastBrokerSL_Sell, digits), COLOR_LOSS, COLOR_SECTION_BROKER); row++; }
   }

   // Daily Profit Pause status (v6.32: Equity-based)
   if(InpEnableDailyProfitPause)
   {
      double dailyPL = AccountInfoDouble(ACCOUNT_EQUITY) - g_dailyStartBalance;
      string dpText = StringFormat("$%.2f / $%.2f", dailyPL, InpDailyProfitTarget);
      color dpColor = g_dailyProfitPaused ? COLOR_LOSS : COLOR_PROFIT;
      if(g_dailyProfitPaused) dpText = dpText + " PAUSED";
      else if(TotalOrderCount() > 0 && dailyPL >= InpDailyProfitTarget)
         dpText = dpText + " (wait flat)";
      DrawTableRow(row, "Daily Profit(Eq)", dpText, dpColor, COLOR_SECTION_INFO); row++;
   }

   // System Status (v2.9)
   string statusText = "Working";
   color statusColor = COLOR_PROFIT;

   if(g_licenseStatus == LICENSE_SUSPENDED || g_licenseStatus == LICENSE_EXPIRED)
   {
      statusText = (g_licenseStatus == LICENSE_SUSPENDED) ? "SUSPENDED" : "EXPIRED";
      statusColor = COLOR_LOSS;
   }
   else if(!g_isLicenseValid && !g_isTesterMode)
   {
      statusText = "INVALID";
      statusColor = COLOR_LOSS;
   }
   else if(g_eaIsPaused)
   {
      statusText = "PAUSED";
      statusColor = COLOR_LOSS;
   }
   else if(g_newOrderBlocked)
   {
      statusText = "BLOCKED";
      statusColor = clrYellow;
   }
   DrawTableRow(row, "System Status", statusText, statusColor, COLOR_SECTION_INFO); row++;

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

   // News Filter with countdown (v2.9)
   if(InpEnableNewsFilter)
   {
      string newsDisplay;
      color newsColor;
      
      if(!g_webRequestConfigured)
      {
         newsDisplay = "WebRequest: NOT CONFIGURED!";
         newsColor = COLOR_LOSS;
      }
      else if(g_isNewsPaused && StringLen(g_nextNewsTitle) > 0)
      {
         // Show news title + countdown timer
         string truncTitle = g_nextNewsTitle;
         if(StringLen(truncTitle) > 18)
            truncTitle = StringSubstr(truncTitle, 0, 15) + "...";
         string countdown = GetNewsCountdownString();
         newsDisplay = truncTitle + " " + countdown;
         newsColor = COLOR_LOSS;
      }
      else if(g_newsEventCount == 0)
      {
         newsDisplay = "0 events loaded";
         newsColor = clrYellow;
      }
      else
      {
         newsDisplay = "No Important news";
         newsColor = COLOR_PROFIT;
      }
      
      DrawTableRow(row, "News Filter", newsDisplay, newsColor, COLOR_SECTION_INFO); row++;
   }

   //--- Squeeze Filter Section
   if(InpUseSqueezeFilter)
   {
      DrawTableRow(row, "--- SQUEEZE ---", "", clrGray, COLOR_SECTION_INFO); row++;
      for(int sq = 0; sq < 3; sq++)
      {
         string stateStr;
         color stateClr;
         if(g_squeeze[sq].state == 1)      { stateStr = "SQUEEZE";   stateClr = clrRed;        }
          else if(g_squeeze[sq].state == 2)
          {
             if(g_squeeze[sq].direction == 1)       { stateStr = "EXPANSION BUY";  stateClr = clrDodgerBlue; }
             else if(g_squeeze[sq].direction == -1) { stateStr = "EXPANSION SELL"; stateClr = clrOrangeRed;  }
             else                                   { stateStr = "EXPANSION";      stateClr = clrDodgerBlue; }
          }
         else                               { stateStr = "NORMAL";    stateClr = clrLime;       }

         // Build intensity bar (10 chars)
         int barLen = (int)MathMin(10, MathMax(0, (int)(g_squeeze[sq].intensity * 5.0)));
         string bar = "|";
         for(int b = 0; b < 10; b++)
         {
            if(b < barLen) bar += "#";
            else bar += ".";
         }
         bar += "|";

         string sqVal = StringFormat("%s  %.2f %s", stateStr, g_squeeze[sq].intensity, bar);
         DrawTableRow(row, g_squeeze[sq].tfLabel, sqVal, stateClr, COLOR_SECTION_INFO); row++;
      }

      string sqBlock;
      color sqBlockClr;
      if(g_squeezeBlocked)             { sqBlock = "BLOCKED ALL"; sqBlockClr = clrRed;    }
      else if(g_squeezeBuyBlocked)     { sqBlock = "BUY BLOCKED"; sqBlockClr = clrOrange;  }
      else if(g_squeezeSellBlocked)    { sqBlock = "SELL BLOCKED"; sqBlockClr = clrOrange; }
      else                             { sqBlock = "OK";           sqBlockClr = clrLime;   }
       DrawTableRow(row, "Squeeze Status", sqBlock, sqBlockClr, COLOR_SECTION_INFO); row++;
       
       if(InpSqueeze_CloseOnExpansion)
       {
          string closeStatus = g_expansionCloseTriggered ? "TRIGGERED" : "ARMED";
          color closeClr = g_expansionCloseTriggered ? clrRed : clrYellow;
          DrawTableRow(row, "Close All", closeStatus, closeClr, COLOR_SECTION_INFO); row++;
       }
    }

   //--- v6.56: Bollinger Band Filter Section
   if(BB_FilterEnable)
   {
      color COLOR_SECTION_BB = C'70,130,180';
      double bbU, bbM, bbL; string bbReason;
      int bbState = GetBBBlockState(bbU, bbM, bbL, bbReason);
      int dg = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
      string modeStr = (BB_BlockMode == 0) ? "Both" : "Counter";
      string cfg = StringFormat("ON %s(%d,%.1f) Prox:%dp %s", EnumToString(BB_Timeframe), BB_Period, BB_Deviation, BB_ProximityPips, modeStr);
      DrawTableRow(row, "BB Filter", cfg, clrSkyBlue, COLOR_SECTION_BB); row++;
      string lvls = StringFormat("U:%s M:%s L:%s", DoubleToString(bbU, dg), DoubleToString(bbM, dg), DoubleToString(bbL, dg));
      DrawTableRow(row, "BB Levels", lvls, clrLightGray, COLOR_SECTION_BB); row++;
      string blkBuy  = (bbState == 1 || bbState == 3) ? "BLOCKED" : "ALLOW";
      string blkSell = (bbState == 2 || bbState == 3) ? "BLOCKED" : "ALLOW";
      color blkClr = (bbState == 0) ? clrLime : clrOrangeRed;
      string blkInfo = StringFormat("BUY:%s | SELL:%s", blkBuy, blkSell);
      if(bbState != 0) blkInfo += " (" + bbReason + ")";
      DrawTableRow(row, "BB Block", blkInfo, blkClr, COLOR_SECTION_BB); row++;
   }

   //--- Counter-Trend Hedging Section
   if(InpHedge_Enable)
   {
      color COLOR_SECTION_HEDGE = C'130,50,180';  // purple for hedge section
      bool anyActive = false;
      for(int h = 0; h < MAX_HEDGE_SETS; h++)
      {
         if(g_hedgeSets[h].active)
         {
            anyActive = true;
            string setLabel = "Hedge #" + IntegerToString(h + 1);
            string sideStr = (g_hedgeSets[h].hedgeSide == POSITION_TYPE_BUY) ? "BUY" : "SELL";

            // Get hedge PnL
            double hedgePnL = 0;
            if(PositionSelectByTicket(g_hedgeSets[h].hedgeTicket))
               hedgePnL = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);

            string hedgeInfo = sideStr + " " + DoubleToString(g_hedgeSets[h].hedgeLots, 2) + "L";
            hedgeInfo += " PnL:$" + DoubleToString(hedgePnL, 2);
            hedgeInfo += " B:" + IntegerToString(g_hedgeSets[h].boundTicketCount);
            if(g_hedgeSets[h].gridMode)
               hedgeInfo += " Grid:L" + IntegerToString(g_hedgeSets[h].gridLevel);

            color hedgeClr = (hedgePnL >= 0) ? clrLime : clrOrangeRed;
            DrawTableRow(row, setLabel, hedgeInfo, hedgeClr, COLOR_SECTION_HEDGE); row++;
            
             // v6.17: Close Gate status per set — all types show real cycle status
             string trigLabel = (g_hedgeSets[h].triggerType == 1) ? "DD%" : "Exp";
             string cycleStatus = "";
             if(!g_hedgeSets[h].seenExpansionSinceHedge && !g_hedgeSets[h].hedgedDuringExpansion)
                cycleStatus = "Wait Exp";
             else if(!IsAllSqueezeTFNormalStrict())
                cycleStatus = "Wait Norm";
             else
                cycleStatus = "Ready";
            
            // Zone status
            double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            string zoneStatus = "";
            double zoneHi = g_hedgeSets[h].zoneUpperPrice;
            double zoneLo = g_hedgeSets[h].zoneLowerPrice;
            if(zoneHi > 0 && zoneLo > 0)
            {
               if(bid > zoneLo && bid < zoneHi)
                  zoneStatus = "IN ZONE";
               else
               {
                  double edgePrice = (bid >= zoneHi) ? zoneHi : zoneLo;
                  double distPts = MathAbs(bid - edgePrice) / _Point;
                  if(distPts < InpHedge_CloseMinPoints)
                     zoneStatus = "OUT " + IntegerToString((int)distPts) + "/" + IntegerToString(InpHedge_CloseMinPoints) + "pts";
                  else
                     zoneStatus = "OUT OK " + IntegerToString((int)distPts) + "pts";
               }
            }
            else
               zoneStatus = "N/A";
            
            string gateInfo = "T:" + trigLabel + " Cy:" + cycleStatus + " Z:" + zoneStatus;
            bool gateOK = IsHedgeCloseAllowed(h);
            color gateClr = gateOK ? clrLime : clrYellow;
            DrawTableRow(row, "  Gate", gateInfo, gateClr, COLOR_SECTION_HEDGE); row++;
         }
        }
        
         // v6.18: DD% / v6.25: DD$ Mode info line with generation scope
          if(InpHedge_TriggerMode == HEDGE_TRIGGER_DD_PERCENT || InpHedge_TriggerMode == HEDGE_TRIGGER_DD_DOLLAR)
          {
             bool isDollarMode = (InpHedge_TriggerMode == HEDGE_TRIGGER_DD_DOLLAR);
             double curBuyDD = 0, curSellDD = 0;
             double bLossAbs = 0, sLossAbs = 0;
             {
                double bal = AccountInfoDouble(ACCOUNT_BALANCE);
                if(bal > 0)
                {
                   double bLoss = 0, sLoss = 0;
                   int curGen = g_cycleGeneration;
                   for(int pi = PositionsTotal() - 1; pi >= 0; pi--)
                   {
                      ulong tk = PositionGetTicket(pi);
                      if(tk == 0) continue;
                      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
                      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
                      string cmt = PositionGetString(POSITION_COMMENT);
                      if(IsHedgeComment(cmt) || IsTicketBound(tk)) continue;
                      if(ExtractGeneration(cmt) != curGen) continue;
                      double pl = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
                      if(pl >= 0) continue;
                      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) bLoss += pl;
                      else sLoss += pl;
                   }
                   bLossAbs = MathAbs(bLoss);
                   sLossAbs = MathAbs(sLoss);
                   curBuyDD  = (bLoss < 0) ? (bLossAbs / bal * 100.0) : 0;
                   curSellDD = (sLoss < 0) ? (sLossAbs / bal * 100.0) : 0;
                }
             }
             string ddInfo;
             if(isDollarMode)
                ddInfo = "BUY DD:$" + DoubleToString(bLossAbs, 2) + "/$" + DoubleToString(InpHedge_DDTriggerDollar, 2) + " | SELL DD:$" + DoubleToString(sLossAbs, 2) + "/$" + DoubleToString(InpHedge_DDTriggerDollar, 2);
             else
                ddInfo = "BUY DD:" + DoubleToString(curBuyDD, 1) + "/" + DoubleToString(InpHedge_DDTriggerPct, 1) + "% | SELL DD:" + DoubleToString(curSellDD, 1) + "/" + DoubleToString(InpHedge_DDTriggerPct, 1) + "%";
             DrawTableRow(row, "  DD Trig", ddInfo, clrAqua, COLOR_SECTION_HEDGE); row++;
            string scopeInfo = "Scope: " + GetCommentPrefix() + " (Gen " + IntegerToString(g_cycleGeneration) + ")";
            DrawTableRow(row, "  DD Scope", scopeInfo, clrYellow, COLOR_SECTION_HEDGE); row++;
         }
        
        // Orphan warning
        if(g_hedgeOrphanWarning)
        {
           DrawTableRow(row, "⚠ WARNING", "ORPHAN GRID ORDERS DETECTED", clrRed, COLOR_SECTION_HEDGE); row++;
         }
          // v6.15: Reverse Hedge removed — no more reverse hedge or balanced lock display
         
          // v6.29: Balance Guard status with mode display
          if(InpBalanceGuard_Enable)
          {
             double curEquity = AccountInfoDouble(ACCOUNT_EQUITY);
             double bgTarget = ((InpBalanceGuard_Mode == BALGUARD_DYNAMIC) ? g_balanceGuardDynamicTarget : InpBalanceGuard_Target) + InpBalanceGuard_Profit;  // v6.35: include min profit
             string modeStr = (InpBalanceGuard_Mode == BALGUARD_DYNAMIC) ? "Dyn" : "Fix";
             string bgStatus;
             color bgClr;
             if(g_balanceGuardActive)
             {
                bgStatus = modeStr + " ACTIVE | Eq: $" + DoubleToString(curEquity, 2) + " / $" + DoubleToString(bgTarget, 2);
                bgClr = (curEquity >= bgTarget) ? clrLime : clrOrange;
             }
             else
             {
                bgStatus = modeStr + " Standby | Target: $" + DoubleToString(bgTarget, 2);
                bgClr = clrGray;
             }
             DrawTableRow(row, "Bal Guard", bgStatus, bgClr, COLOR_SECTION_HEDGE); row++;
           }
           
           // v6.39: Hedge Side Pause status
           if(InpHedge_SidePauseMin > 0)
           {
              datetime nowDash = TimeCurrent();
              bool bPaused = (g_lastHedgeBuyTime > 0 && (nowDash - g_lastHedgeBuyTime) < InpHedge_SidePauseMin * 60);
              bool sPaused = (g_lastHedgeSellTime > 0 && (nowDash - g_lastHedgeSellTime) < InpHedge_SidePauseMin * 60);
              if(bPaused || sPaused)
              {
                 string pauseStr = "";
                 if(bPaused)
                 {
                    int remB = InpHedge_SidePauseMin * 60 - (int)(nowDash - g_lastHedgeBuyTime);
                    pauseStr += "BUY PAUSED " + IntegerToString(remB/60) + "m" + IntegerToString(remB%60) + "s";
                 }
                 if(sPaused)
                 {
                    if(pauseStr != "") pauseStr += " | ";
                    int remS = InpHedge_SidePauseMin * 60 - (int)(nowDash - g_lastHedgeSellTime);
                    pauseStr += "SELL PAUSED " + IntegerToString(remS/60) + "m" + IntegerToString(remS%60) + "s";
                 }
                  DrawTableRow(row, "Side Pause", pauseStr, clrOrange, COLOR_SECTION_HEDGE); row++;
               }
             }

             // v6.78: Hedge Open Delay status
             if(InpHedge_OpenDelayMin > 0)
             {
                int remSecD = 0;
                string modeStrD = (InpHedge_OpenDelayMode == HDELAY_AFTER_LAST_OPEN) ? "Open"
                                : (InpHedge_OpenDelayMode == HDELAY_AFTER_LAST_CLOSE) ? "Close" : "Both";
                if(IsHedgeOpenDelayActive(remSecD))
                {
                   string delayStr = "WAIT " + IntegerToString(remSecD/60) + "m" + IntegerToString(remSecD%60) + "s"
                                    + " (mode=" + modeStrD + ", " + IntegerToString(InpHedge_OpenDelayMin) + "m)";
                   DrawTableRow(row, "Hedge Delay", delayStr, clrOrange, COLOR_SECTION_HEDGE); row++;
                }
                else
                {
                   DrawTableRow(row, "Hedge Delay", "READY (mode=" + modeStrD + ", " + IntegerToString(InpHedge_OpenDelayMin) + "m)", clrLime, COLOR_SECTION_HEDGE); row++;
                }
             }
            
            // v6.40: Grid Loss Candle Confirmation display
            if(GridLoss_CandleConfirm > 0)
            {
               DrawTableRow(row, "GL CandleConfirm", IntegerToString(GridLoss_CandleConfirm) + " candle(s)", clrCyan, COLOR_SECTION_HEDGE); row++;
             }

             // v6.82: Grid Profit Candle Confirmation display
             if(GridProfit_CandleConfirm > 0)
             {
                DrawTableRow(row, "GP CandleConfirm", IntegerToString(GridProfit_CandleConfirm) + " candle(s)", clrCyan, COLOR_SECTION_HEDGE); row++;
             }
             
             // v6.41: Max Grid Average Trailing Stop display
             if(MaxGrid_TrailEnable)
             {
                color COLOR_SECTION_MAXTRAIL = C'20,100,120';
                string genLabel = GenPrefix(g_maxGridMonitorGen);
                string modeStr = (MaxGrid_TrailMode == 1) ? "Start@" + IntegerToString(MaxGrid_StartOrders) : "MaxOrd";  // v6.54
                DrawTableRow(row, "MaxGrid Trail", "ON | " + modeStr + " | Mon: " + genLabel, clrLime, COLOR_SECTION_MAXTRAIL); row++;
                
                if(g_maxGridTrailActive_Buy)
                {
                   DrawTableRow(row, "MG BUY Trail", "ACTIVE SL=" + DoubleToString(g_maxGridTrailSL_Buy, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)), clrLime, COLOR_SECTION_MAXTRAIL); row++;
                }
                else if(InpMaxGridArm_Strict2Cross && g_maxGridArmReady_Buy)  // v6.91
                {
                   DrawTableRow(row, "MG BUY Trail", "READY (waiting cross-up)", clrYellow, COLOR_SECTION_MAXTRAIL); row++;
                }
                if(g_maxGridTrailActive_Sell)
                {
                   DrawTableRow(row, "MG SELL Trail", "ACTIVE SL=" + DoubleToString(g_maxGridTrailSL_Sell, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)), clrLime, COLOR_SECTION_MAXTRAIL); row++;
                }
                else if(InpMaxGridArm_Strict2Cross && g_maxGridArmReady_Sell)  // v6.91
                {
                   DrawTableRow(row, "MG SELL Trail", "READY (waiting cross-down)", clrYellow, COLOR_SECTION_MAXTRAIL); row++;
                }
             }

             // v6.57/v6.58/v6.59: Sequential Hedge Recovery status
             if(InpHedge_SequentialRecovery && (g_hedgeSetCount > 0 || g_sequentialRecoveryActive))
             {
                string seqInfo;
                if(g_sequentialRecoveryActive)
                {
                   // v6.60: owner-locked → show what's holding the queue (strict count, excludes hedges)
                   int ownerRemain = CountSequentialOwnerOrders(g_sequentialRecoveryGen);
                   seqInfo = "LOCKED | Owner Gen" + IntegerToString(g_sequentialRecoveryGen) +
                             " (Src H" + IntegerToString(g_sequentialRecoverySetIdx + 1) + ")" +
                             " | " + IntegerToString(ownerRemain) + " order(s) left";
                   if(g_hedgeSetCount > 0) seqInfo += " | Wait: " + IntegerToString(g_hedgeSetCount) + " set(s)";
                }
                else if(g_hedgeSetCount > 0)
                {
                   int oldestIdx = FindOldestActiveHedgeSet();
                   seqInfo = "Sequential | Next Unlock: H" + IntegerToString(oldestIdx + 1) + " (1/tick)";
                   int pendingCount = g_hedgeSetCount - 1;
                   if(pendingCount > 0) seqInfo += " | Wait: " + IntegerToString(pendingCount) + " set(s)";
                }
                // v6.69: time-based unlock cooldown overlay
                if(IsSequentialUnlockDelayActive())
                {
                   int rem = GetSequentialUnlockRemainSec();
                   seqInfo = "Cooldown " + IntegerToString(rem/60) + "m" + IntegerToString(rem%60) + "s | " + seqInfo;
                }
                 DrawTableRow(row, "Hedge Recovery", seqInfo, clrAqua, COLOR_SECTION_HEDGE); row++;
                 // v6.63: Owner Avg TP + orphan watchdog
                 if(g_sequentialRecoveryActive)
                 {
                    color orphanColor = (g_lastOrphanGLCount > 0) ? clrRed : clrLime;
                    DrawTableRow(row, "Owner Untracked GL",
                                 IntegerToString(g_lastOrphanGLCount) + " order(s) missing Broker TP",
                                 orphanColor, COLOR_SECTION_HEDGE); row++;
                 }
                 // v6.66: Active Hedge X/Max — clarifies that GMx counter ≠ hedge cap
                 {
                    int activeNow = 0;
                    for(int hh = 0; hh < MAX_HEDGE_SETS; hh++)
                       if(g_hedgeSets[hh].active) activeNow++;
                    color actColor = (activeNow >= InpHedge_MaxSets) ? clrOrangeRed
                                    : (activeNow > 0) ? clrYellow : clrLime;
                    string actStr = IntegerToString(activeNow) + " / " + IntegerToString(InpHedge_MaxSets)
                                  + (activeNow >= InpHedge_MaxSets ? "  (CAP — new hedges blocked)" : "");
                    DrawTableRow(row, "Active Hedge Sets", actStr, actColor, COLOR_SECTION_HEDGE); row++;
                    DrawTableRow(row, "Cycle Gen (comment)", "GM" + IntegerToString(g_cycleGeneration)
                                  + "  (counter only — not a cap)", clrSilver, COLOR_SECTION_HEDGE); row++;
                 }
                 // v6.65: Hedge Set Integrity status
                 {
                    string integStatus;
                    color integColor;
                    if(g_hedgeIntegrityCriticalCount > 0)
                    {
                       integStatus = "CRITICAL: " + IntegerToString(g_hedgeIntegrityCriticalCount) + " set(s) w/o bound orders";
                       integColor = clrRed;
                    }
                    else if(g_hedgeIntegrityWarnCount > 0)
                    {
                       integStatus = "WARN: " + IntegerToString(g_hedgeIntegrityWarnCount) + " set(s) inflated (>2x)";
                       integColor = clrYellow;
                    }
                    else
                    {
                       integStatus = "Healthy (all sets balanced)";
                       integColor = clrLime;
                    }
                    DrawTableRow(row, "Hedge Integrity", integStatus, integColor, COLOR_SECTION_HEDGE); row++;
                 }
                if(g_prevHedgedCount > 0)
                {
                   string phInfo = IntegerToString(g_prevHedgedCount) + " ticket(s) locked from re-hedge";
                   DrawTableRow(row, "PrevHedged", phInfo, clrOrange, COLOR_SECTION_HEDGE); row++;
                 }
                 // v6.81: Opposite-side survivor close status
                 {
                    string oppStr = InpHedge_CloseOppositeSurvivors ? "ON (close opp side on hedge)" : "OFF";
                    color oppCol = InpHedge_CloseOppositeSurvivors ? clrLime : clrGray;
                    DrawTableRow(row, "OppSurv Close", oppStr, oppCol, COLOR_SECTION_HEDGE); row++;
                 }
                 // v6.73: Cross-gen INIT guard status row
                if(InpCrossGen_InitGuard && g_cycleGeneration > 1)
                {
                   int lgB = CountFreeOlderGenOnSide(POSITION_TYPE_BUY);
                   int lgS = CountFreeOlderGenOnSide(POSITION_TYPE_SELL);
                   string guardInfo = "LegacyB=" + IntegerToString(lgB) + " LegacyS=" + IntegerToString(lgS) +
                                      " | INIT=" + ((lgB > 0 || lgS > 0) ? "BLOCK" : "ALLOW");
                   color guardCol = (lgB > 0 || lgS > 0) ? clrYellow : clrLime;
                   DrawTableRow(row, "ReEntryGuard", guardInfo, guardCol, COLOR_SECTION_HEDGE); row++;
                }
                // v6.74: Released Gen+Side lock status row
                if(InpHedge_NoReHedgeGenSide && g_releasedGenSideCount > 0)
                {
                   string lockInfo = "";
                   int shown = 0;
                   for(int li = 0; li < g_releasedGenSideCount && shown < 4; li++)
                   {
                      if(!g_releasedGenSide[li].active) continue;
                      if(shown > 0) lockInfo += ", ";
                      lockInfo += "GM" + IntegerToString(g_releasedGenSide[li].generation) +
                                  (g_releasedGenSide[li].side == POSITION_TYPE_BUY ? " B" : " S");
                      shown++;
                   }
                   if(shown == 0) lockInfo = "(none)";
                   else lockInfo = IntegerToString(shown) + " locked: " + lockInfo;
                   DrawTableRow(row, "NoReHedgeLock", lockInfo, clrOrange, COLOR_SECTION_HEDGE); row++;
                }
             }

             // v6.57: Recovery Grid mode indicator
             if(Recovery_UseSeparate)
             {
                string recInfo = "Separate | Max:" + IntegerToString(Recovery_MaxTrades) +
                                 " | Dist:" + IntegerToString(Recovery_Points) + "p";
                DrawTableRow(row, "Recovery Grid", recInfo, clrCyan, COLOR_SECTION_HEDGE); row++;
             }
         }

     // === Orphan Recovery Status ===
     color COLOR_SECTION_ORPHAN = C'130,50,180';  // purple for orphan section
     if(InpOrphan_Enable && g_activeOrphanGroupCount > 0)
     {
        DrawTableRow(row, "ORPHAN RECOVERY", IntegerToString(g_activeOrphanGroupCount) + " group(s)", clrYellow, COLOR_SECTION_ORPHAN); row++;
       for(int og = 0; og < MAX_ORPHAN_GROUPS; og++)
       {
          if(!g_orphanGroups[og].active) continue;
          string genLabel = "Gen" + IntegerToString(g_orphanGroups[og].generation) + " (" + GenPrefix(g_orphanGroups[og].generation) + ")";
          string info = "B:" + IntegerToString(g_orphanGroups[og].buyCount) +
                        " S:" + IntegerToString(g_orphanGroups[og].sellCount) +
                        " GL_B:" + IntegerToString(g_orphanGroups[og].gridLossBuyCount) + "/" + IntegerToString(GridLoss_MaxTrades) +
                        " GL_S:" + IntegerToString(g_orphanGroups[og].gridLossSellCount) + "/" + IntegerToString(GridLoss_MaxTrades);
          DrawTableRow(row, genLabel, info, clrOrange, COLOR_SECTION_ORPHAN); row++;
       }
    }

   //--- Cleanup stale rows from previous tick (prevents flicker)
   for(int r = row; r < g_lastDashboardRowCount; r++)
   {
      ObjectDelete(0, "GM_TBL_R" + IntegerToString(r));
      ObjectDelete(0, "GM_TBL_S" + IntegerToString(r));
      ObjectDelete(0, "GM_TBL_L" + IntegerToString(r));
      ObjectDelete(0, "GM_TBL_V" + IntegerToString(r));
   }
   g_lastDashboardRowCount = row;

   //--- Bottom border
   int rowH_sc = (int)(20 * sc);
   int bottomY = DashboardY + (int)(24 * sc) + row * rowH_sc;
   CreateDashRect("GM_TBL_BTM", DashboardX, bottomY, tableWidth, 2, COLOR_HEADER_BG);

   //--- Control Buttons (v2.9) - below dashboard
   int btnY = bottomY + 5;
   int btnW = (tableWidth - 10) / 2;
   int btnH = (int)(22 * sc);

   // Pause/Start button
   string pauseText = g_eaIsPaused ? "▶ Start" : "⏸ Pause";
   color pauseBg = g_eaIsPaused ? clrForestGreen : clrOrangeRed;
   CreateDashButton("GM_BtnPause", DashboardX, btnY, tableWidth, btnH, pauseText, pauseBg, clrWhite);
   btnY += btnH + 3;

   // Close Buy / Close Sell
   CreateDashButton("GM_BtnCloseBuy", DashboardX, btnY, btnW, btnH, "Close Buy", C'20,100,50', clrWhite);
   CreateDashButton("GM_BtnCloseSell", DashboardX + btnW + 10, btnY, btnW, btnH, "Close Sell", C'180,50,30', clrWhite);
   btnY += btnH + 3;

   // Close All
   CreateDashButton("GM_BtnCloseAll", DashboardX, btnY, tableWidth, btnH, "Close All", C'30,100,180', clrWhite);
   btnY += btnH + 3;

   // Resume Daily Profit button (only visible when paused)
   if(InpEnableDailyProfitPause && g_dailyProfitPaused)
   {
      CreateDashButton("GM_BtnResumeDaily", DashboardX, btnY, tableWidth, btnH,
                       "▶ Resume Daily", clrDarkGreen, clrWhite);
   }
   else
   {
      ObjectDelete(0, "GM_BtnResumeDaily");
   }
}

//+------------------------------------------------------------------+
//| Dashboard label helper (legacy - kept for compatibility)           |
//+------------------------------------------------------------------+
void DashLabel(string name, int x, int y, string text, color clr)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ============== ZIGZAG MTF MODULE (v3.0) ======================== |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Initialize ZigZag handles for enabled timeframes                   |
//+------------------------------------------------------------------+
void InitZigZagHandles()
{
   g_activeTFCount = 0;

   // H4 (Confirm TF) - always created for direction detection
   {
      g_tfStates[g_activeTFCount].tf = ZZ_ConfirmTF;
      g_tfStates[g_activeTFCount].tfLabel = "H4";
      g_tfStates[g_activeTFCount].enabled = ZZ_UseConfirmTFEntry;
      g_tfStates[g_activeTFCount].handleZZ = iCustom(_Symbol, ZZ_ConfirmTF, "Examples\\ZigZag", ZZ_Depth, ZZ_Deviation, ZZ_Backstep);
      ResetTFState(g_activeTFCount);
      g_h4TFIndex = g_activeTFCount;
      if(g_tfStates[g_activeTFCount].handleZZ == INVALID_HANDLE)
         Print("WARNING: ZigZag handle failed for ", EnumToString(ZZ_ConfirmTF));
      else
         Print("ZigZag handle OK for ", EnumToString(ZZ_ConfirmTF));
      g_activeTFCount++;
   }

   // M30
   if(ZZ_UseM30)
   {
      g_tfStates[g_activeTFCount].tf = PERIOD_M30;
      g_tfStates[g_activeTFCount].tfLabel = "M30";
      g_tfStates[g_activeTFCount].enabled = true;
      g_tfStates[g_activeTFCount].handleZZ = iCustom(_Symbol, PERIOD_M30, "Examples\\ZigZag", ZZ_Depth, ZZ_Deviation, ZZ_Backstep);
      ResetTFState(g_activeTFCount);
      if(g_tfStates[g_activeTFCount].handleZZ == INVALID_HANDLE)
         Print("WARNING: ZigZag handle failed for M30");
      g_activeTFCount++;
   }

   // M15
   if(ZZ_UseM15)
   {
      g_tfStates[g_activeTFCount].tf = PERIOD_M15;
      g_tfStates[g_activeTFCount].tfLabel = "M15";
      g_tfStates[g_activeTFCount].enabled = true;
      g_tfStates[g_activeTFCount].handleZZ = iCustom(_Symbol, PERIOD_M15, "Examples\\ZigZag", ZZ_Depth, ZZ_Deviation, ZZ_Backstep);
      ResetTFState(g_activeTFCount);
      if(g_tfStates[g_activeTFCount].handleZZ == INVALID_HANDLE)
         Print("WARNING: ZigZag handle failed for M15");
      g_activeTFCount++;
   }

   // M5
   if(ZZ_UseM5)
   {
      g_tfStates[g_activeTFCount].tf = PERIOD_M5;
      g_tfStates[g_activeTFCount].tfLabel = "M5";
      g_tfStates[g_activeTFCount].enabled = true;
      g_tfStates[g_activeTFCount].handleZZ = iCustom(_Symbol, PERIOD_M5, "Examples\\ZigZag", ZZ_Depth, ZZ_Deviation, ZZ_Backstep);
      ResetTFState(g_activeTFCount);
      if(g_tfStates[g_activeTFCount].handleZZ == INVALID_HANDLE)
         Print("WARNING: ZigZag handle failed for M5");
      g_activeTFCount++;
   }

   Print("ZigZag MTF initialized: ", g_activeTFCount, " timeframes active");
}

//+------------------------------------------------------------------+
//| Reset TFState to defaults                                          |
//+------------------------------------------------------------------+
void ResetTFState(int idx)
{
   g_tfStates[idx].lastSwingPrice = 0;
   g_tfStates[idx].lastSwingType = "NONE";
   g_tfStates[idx].lastSwingTime = 0;
   g_tfStates[idx].initialBuyPrice = 0;
   g_tfStates[idx].initialSellPrice = 0;
   g_tfStates[idx].lastInitialCandle = 0;
   g_tfStates[idx].lastGridLossCandle = 0;
   g_tfStates[idx].lastGridProfitCandle = 0;
   g_tfStates[idx].justClosedBuy = false;
   g_tfStates[idx].justClosedSell = false;
   g_tfStates[idx].trailSL_Buy = 0;
   g_tfStates[idx].trailSL_Sell = 0;
   g_tfStates[idx].trailActive_Buy = false;
   g_tfStates[idx].trailActive_Sell = false;
   g_tfStates[idx].beDone_Buy = false;
   g_tfStates[idx].beDone_Sell = false;
}

//+------------------------------------------------------------------+
//| Reset TF trailing state                                            |
//+------------------------------------------------------------------+
void ResetTrailingStateTF(int tfIdx)
{
   g_tfStates[tfIdx].trailSL_Buy = 0;
   g_tfStates[tfIdx].trailSL_Sell = 0;
   g_tfStates[tfIdx].trailActive_Buy = false;
   g_tfStates[tfIdx].trailActive_Sell = false;
   g_tfStates[tfIdx].beDone_Buy = false;
   g_tfStates[tfIdx].beDone_Sell = false;
}

// v6.84: Per-side reset (MTF) so closing one side doesn't wipe other side's trailing state
void ResetTrailingStateTFBuy(int tfIdx)
{
   g_tfStates[tfIdx].trailSL_Buy      = 0;
   g_tfStates[tfIdx].trailActive_Buy  = false;
   g_tfStates[tfIdx].beDone_Buy       = false;
}

void ResetTrailingStateTFSell(int tfIdx)
{
   g_tfStates[tfIdx].trailSL_Sell     = 0;
   g_tfStates[tfIdx].trailActive_Sell = false;
   g_tfStates[tfIdx].beDone_Sell      = false;
}

//+------------------------------------------------------------------+
//| Recover TF initial prices from existing positions                  |
//+------------------------------------------------------------------+
void RecoverTFInitialPrices()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      string comment = PositionGetString(POSITION_COMMENT);
      // v6.23: Skip orders from previous generations
      int orderGen = ExtractGeneration(comment);
      if(orderGen >= 0 && orderGen != g_cycleGeneration) continue;
      long posType = PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);

      for(int t = 0; t < g_activeTFCount; t++)
      {
          string prefix = "_" + g_tfStates[t].tfLabel + "_INIT";
          if(MatchTFPrefix(comment, g_tfStates[t].tfLabel) && StringFind(comment, "INIT") >= 0)
         {
            if(posType == POSITION_TYPE_BUY)
               g_tfStates[t].initialBuyPrice = openPrice;
            else if(posType == POSITION_TYPE_SELL)
               g_tfStates[t].initialSellPrice = openPrice;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Detect latest ZigZag swing on a specific TF                        |
//| Returns: "LOW" (buy signal), "HIGH" (sell signal), "NONE"          |
//+------------------------------------------------------------------+
string DetectZigZagSwing(int tfIndex)
{
   if(g_tfStates[tfIndex].handleZZ == INVALID_HANDLE) return "NONE";

   // Buffer 1 = High Map (Swing High points), Buffer 2 = Low Map (Swing Low points)
   double zzHighMap[], zzLowMap[];
   ArraySetAsSeries(zzHighMap, true);
   ArraySetAsSeries(zzLowMap, true);
   if(CopyBuffer(g_tfStates[tfIndex].handleZZ, 1, 0, 100, zzHighMap) < 100) return "NONE";
   if(CopyBuffer(g_tfStates[tfIndex].handleZZ, 2, 0, 100, zzLowMap) < 100) return "NONE";

   // Find most recent Swing High and Swing Low bar indices (skip bar 0 = forming)
   int lastHighBar = -1, lastLowBar = -1;
   double lastHighPrice = 0, lastLowPrice = 0;
   for(int i = 1; i < 100; i++)
   {
      if(lastHighBar < 0 && zzHighMap[i] != 0.0) { lastHighBar = i; lastHighPrice = zzHighMap[i]; }
      if(lastLowBar  < 0 && zzLowMap[i]  != 0.0) { lastLowBar  = i; lastLowPrice  = zzLowMap[i];  }
      if(lastHighBar >= 0 && lastLowBar >= 0) break;
   }

   // Determine which swing is more recent (lower bar index = more recent)
   if(lastLowBar >= 0 && (lastHighBar < 0 || lastLowBar < lastHighBar))
   {
      g_tfStates[tfIndex].lastSwingPrice = lastLowPrice;
      g_tfStates[tfIndex].lastSwingType  = "LOW";
      g_tfStates[tfIndex].lastSwingTime  = iTime(_Symbol, g_tfStates[tfIndex].tf, lastLowBar);
      return "LOW";
   }
   else if(lastHighBar >= 0)
   {
      g_tfStates[tfIndex].lastSwingPrice = lastHighPrice;
      g_tfStates[tfIndex].lastSwingType  = "HIGH";
      g_tfStates[tfIndex].lastSwingTime  = iTime(_Symbol, g_tfStates[tfIndex].tf, lastHighBar);
      return "HIGH";
   }
   return "NONE";
}

//+------------------------------------------------------------------+
//| Calculate EMA for CDC (ported from Harmony Dream v3.5.0)           |
//+------------------------------------------------------------------+
void CalculateCDC_EMA_GM(double &src[], double &result[], int period, int size)
{
   if(size < period) return;

   double multiplier = 2.0 / (period + 1);

   // Initial SMA
   double sum = 0;
   for(int i = size - period; i < size; i++)
      sum += src[i];
   result[size - 1] = sum / period;

   // EMA calculation from oldest to newest
   for(int i = size - 2; i >= 0; i--)
      result[i] = (src[i] - result[i + 1]) * multiplier + result[i + 1];
}

//+------------------------------------------------------------------+
//| Update CDC Action Zone trend                                       |
//+------------------------------------------------------------------+
void UpdateCDC()
{
   if(!InpUseCDCFilter) return;

   // Only recalculate on new CDC TF bar
   datetime cdcBar = iTime(_Symbol, InpCDCTimeframe, 0);
   if(cdcBar == g_lastCdcCandle && g_cdcReady) return;
   g_lastCdcCandle = cdcBar;

   int minBarsReq = InpCDCSlowPeriod + 10;
   int barsNeeded = InpCDCSlowPeriod * 3 + 50;

   double closeArr[], highArr[], lowArr[], openArr[];
   ArraySetAsSeries(closeArr, true);
   ArraySetAsSeries(highArr, true);
   ArraySetAsSeries(lowArr, true);
   ArraySetAsSeries(openArr, true);

   int copied = CopyClose(_Symbol, InpCDCTimeframe, 0, barsNeeded, closeArr);
   if(copied < minBarsReq) { g_cdcReady = false; return; }

   int actualBars = MathMin(copied, barsNeeded);

   int copiedH = CopyHigh(_Symbol, InpCDCTimeframe, 0, actualBars, highArr);
   int copiedL = CopyLow(_Symbol, InpCDCTimeframe, 0, actualBars, lowArr);
   int copiedO = CopyOpen(_Symbol, InpCDCTimeframe, 0, actualBars, openArr);
   if(copiedH < actualBars || copiedL < actualBars || copiedO < actualBars)
   {
      g_cdcReady = false;
      return;
   }

   // Calculate OHLC4
   double ohlc4[];
   ArrayResize(ohlc4, actualBars);
   for(int i = 0; i < actualBars; i++)
      ohlc4[i] = (openArr[i] + highArr[i] + lowArr[i] + closeArr[i]) / 4.0;

   // AP (Smoothed OHLC4 with EMA2)
   double ap[];
   ArrayResize(ap, actualBars);
   CalculateCDC_EMA_GM(ohlc4, ap, 2, actualBars);

   // Fast & Slow EMA
   double fast[], slow[];
   ArrayResize(fast, actualBars);
   ArrayResize(slow, actualBars);
   CalculateCDC_EMA_GM(ap, fast, InpCDCFastPeriod, actualBars);
   CalculateCDC_EMA_GM(ap, slow, InpCDCSlowPeriod, actualBars);

   if(ArraySize(fast) < 2 || ArraySize(slow) < 2)
   {
      g_cdcReady = false;
      return;
   }

   g_cdcFast = fast[0];
   g_cdcSlow = slow[0];

   if(g_cdcFast == 0 || g_cdcSlow == 0)
   {
      g_cdcReady = false;
      return;
   }

   // Determine trend
   if(InpCDCRequireCross)
   {
      double fastPrev = fast[1];
      double slowPrev = slow[1];
      bool crossUp = (fastPrev <= slowPrev && g_cdcFast > g_cdcSlow);
      bool crossDown = (fastPrev >= slowPrev && g_cdcFast < g_cdcSlow);
      if(crossUp) g_cdcTrend = "BULLISH";
      else if(crossDown) g_cdcTrend = "BEARISH";
      // else keep previous trend
   }
   else
   {
      if(g_cdcFast > g_cdcSlow) g_cdcTrend = "BULLISH";
      else if(g_cdcFast < g_cdcSlow) g_cdcTrend = "BEARISH";
      else g_cdcTrend = "NEUTRAL";
   }

   g_cdcReady = true;
}

//+------------------------------------------------------------------+
//| Count positions for a specific TF (by comment prefix)              |
//+------------------------------------------------------------------+
void CountPositionsTF(int tfIdx, int &buyCount, int &sellCount,
                      int &gridLossBuy, int &gridLossSell,
                      int &gridProfitBuy, int &gridProfitSell,
                      bool &hasInitialBuy, bool &hasInitialSell)
{
   buyCount = 0; sellCount = 0;
   gridLossBuy = 0; gridLossSell = 0;
   gridProfitBuy = 0; gridProfitSell = 0;
   hasInitialBuy = false; hasInitialSell = false;

   string tfLabel = g_tfStates[tfIdx].tfLabel;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

       string comment = PositionGetString(POSITION_COMMENT);
      // v6.23: Skip orders from previous generations
      int orderGen = ExtractGeneration(comment);
      if(orderGen >= 0 && orderGen != g_cycleGeneration) continue;
      if(!MatchTFPrefix(comment, tfLabel)) continue;

      long posType = PositionGetInteger(POSITION_TYPE);

      if(posType == POSITION_TYPE_BUY)
      {
         buyCount++;
         if(StringFind(comment, "INIT") >= 0) hasInitialBuy = true;
         if(StringFind(comment, "GL") >= 0) gridLossBuy++;
         if(StringFind(comment, "GP") >= 0) gridProfitBuy++;
      }
      else if(posType == POSITION_TYPE_SELL)
      {
         sellCount++;
         if(StringFind(comment, "INIT") >= 0) hasInitialSell = true;
         if(StringFind(comment, "GL") >= 0) gridLossSell++;
         if(StringFind(comment, "GP") >= 0) gridProfitSell++;
      }
   }
}

//+------------------------------------------------------------------+
//| Open order for a specific TF                                       |
//+------------------------------------------------------------------+
bool OpenOrderTF(int tfIdx, ENUM_ORDER_TYPE orderType, double lots, string suffix)
{
   string comment = GetCommentPrefix() + "_" + g_tfStates[tfIdx].tfLabel + "_" + suffix;
   return OpenOrder(orderType, lots, comment);
}

//+------------------------------------------------------------------+
//| Calculate average price for a TF                                   |
//+------------------------------------------------------------------+
double CalculateAveragePriceTF(int tfIdx, ENUM_POSITION_TYPE side)
{
   string tfLabel = g_tfStates[tfIdx].tfLabel;
   double totalLots = 0;
   double totalWeighted = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) != side) continue;
      if(!MatchTFPrefix(PositionGetString(POSITION_COMMENT), tfLabel)) continue;

      double vol = PositionGetDouble(POSITION_VOLUME);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      totalLots += vol;
      totalWeighted += openPrice * vol;
   }

   if(totalLots > 0) return totalWeighted / totalLots;
   return 0;
}

//+------------------------------------------------------------------+
//| Calculate floating PL for a TF                                     |
//+------------------------------------------------------------------+
double CalculateFloatingPL_TF(int tfIdx, ENUM_POSITION_TYPE side)
{
   string tfLabel = g_tfStates[tfIdx].tfLabel;
   double totalPLtf = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) != side) continue;
      if(!MatchTFPrefix(PositionGetString(POSITION_COMMENT), tfLabel)) continue;

      totalPLtf += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return totalPLtf;
}

//+------------------------------------------------------------------+
//| Find last order for a TF (matching comment prefix)                 |
//+------------------------------------------------------------------+
void FindLastOrderTF(int tfIdx, ENUM_POSITION_TYPE side, string suffix1, string suffix2,
                     double &outPrice, datetime &outTime)
{
   string tfLabel = g_tfStates[tfIdx].tfLabel;
   outPrice = 0;
   outTime = 0;
   datetime latestTime = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) != side) continue;

       string comment = PositionGetString(POSITION_COMMENT);
      // v6.23: Skip orders from previous generations
      int orderGen = ExtractGeneration(comment);
      if(orderGen >= 0 && orderGen != g_cycleGeneration) continue;
      if(!MatchTFPrefix(comment, tfLabel)) continue;
      if(StringFind(comment, suffix1) >= 0 || StringFind(comment, suffix2) >= 0)
      {
         datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
         if(openTime > latestTime)
         {
            latestTime = openTime;
            outPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            outTime = openTime;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| v6.71: Find max grid level number on TF + side (current generation)|
//| suffix: "GL" or "GP". Returns 0 if none found.                     |
//+------------------------------------------------------------------+
int FindMaxGridLevelOnSideTF(int tfIdx, ENUM_POSITION_TYPE side, string suffix)
{
   string tfLabel = g_tfStates[tfIdx].tfLabel;
   int maxLevel = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != side) continue;
      string comment = PositionGetString(POSITION_COMMENT);
      int orderGen = ExtractGeneration(comment);
      if(orderGen >= 0 && orderGen != g_cycleGeneration) continue;
      if(!MatchTFPrefix(comment, tfLabel)) continue;
      // Look for "_<suffix>#" segment (e.g. "_GL#")
      string needle = "_" + suffix + "#";
      int p = StringFind(comment, needle);
      if(p < 0) continue;
      int hashPos = p + StringLen(needle) - 1;
      int level = (int)StringToInteger(StringSubstr(comment, hashPos + 1));
      if(level > maxLevel) maxLevel = level;
   }
   return maxLevel;
}
//+------------------------------------------------------------------+
void CloseAllSideTF(int tfIdx, ENUM_POSITION_TYPE side)
{
   string tfLabel = g_tfStates[tfIdx].tfLabel;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) != side) continue;
      if(!MatchTFPrefix(PositionGetString(POSITION_COMMENT), tfLabel)) continue;
      trade.PositionClose(ticket);
   }

   if(side == POSITION_TYPE_BUY)
      g_tfStates[tfIdx].justClosedBuy = true;
   else
      g_tfStates[tfIdx].justClosedSell = true;
}

//+------------------------------------------------------------------+
//| Check Grid Loss for a specific TF                                  |
//+------------------------------------------------------------------+
void CheckGridLossTF(int tfIdx, ENUM_POSITION_TYPE side, int currentGridCount)
{
   if(currentGridCount >= GridLoss_MaxTrades) return;
   if(NormalOrderCount() >= MaxOpenOrders) return;

   // OnlyNewCandle check (per-TF)
   if(GridLoss_OnlyNewCandle)
   {
      datetime barTime = iTime(_Symbol, g_tfStates[tfIdx].tf, 0);
      if(barTime == g_tfStates[tfIdx].lastGridLossCandle) return;
   }

   //--- v6.40: Candle Confirmation check
   if(GridLoss_CandleConfirm > 0)
   {
      if(!HasCandleConfirmation(side, g_tfStates[tfIdx].tf, GridLoss_CandleConfirm)) return;
   }

    // Find last order for this TF
   double lastPrice = 0;
   datetime lastTime = 0;
   FindLastOrderTF(tfIdx, side, "INIT", "GL", lastPrice, lastTime);

   // Fallback to TF initial price
   if(lastPrice == 0)
   {
      if(side == POSITION_TYPE_BUY && g_tfStates[tfIdx].initialBuyPrice > 0)
         lastPrice = g_tfStates[tfIdx].initialBuyPrice;
      else if(side == POSITION_TYPE_SELL && g_tfStates[tfIdx].initialSellPrice > 0)
         lastPrice = g_tfStates[tfIdx].initialSellPrice;
      else
         return;
   }

   // Same candle restriction
   if(GridLoss_DontSameCandle)
   {
      datetime barTime = iTime(_Symbol, g_tfStates[tfIdx].tf, 0);
      if(lastTime >= barTime) return;
   }

   // Copy ATR buffer for grid distance calculation (skip if using simplified ATR)
   if(handleATR_Loss != INVALID_HANDLE)
   {
      if(CopyBuffer(handleATR_Loss, 0, 0, 3, bufATR_Loss) < 3) return;
   }

   double distance = GetGridDistance(currentGridCount, true);
   if(distance <= 0) return;

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double currentPrice = (side == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   bool shouldOpen = false;

   if(GridLoss_GapType == GAP_ATR && GridLoss_ATR_Reference == ATR_REF_INITIAL)
   {
      double initialRef = (side == POSITION_TYPE_BUY) ? g_tfStates[tfIdx].initialBuyPrice : g_tfStates[tfIdx].initialSellPrice;
      if(initialRef <= 0) return;
      double totalDistance = distance * (currentGridCount + 1);
      if(side == POSITION_TYPE_BUY)
         shouldOpen = (currentPrice <= initialRef - totalDistance * point);
      else
         shouldOpen = (currentPrice >= initialRef + totalDistance * point);
   }
   else
   {
      if(side == POSITION_TYPE_BUY && currentPrice <= lastPrice - distance * point)
         shouldOpen = true;
      else if(side == POSITION_TYPE_SELL && currentPrice >= lastPrice + distance * point)
         shouldOpen = true;
   }

   if(shouldOpen)
   {
      double lots = CalculateGridLot(currentGridCount, true);
      
      //--- Ensure lot continues from max existing lot after matching close
      double maxExisting = FindMaxLotOnSide(side);
      if(maxExisting > 0 && lots <= maxExisting)
      {
         if(GridLoss_LotMode == LOT_MULTIPLY)
            lots = maxExisting * GridLoss_MultiplyFactor;
         else if(GridLoss_LotMode == LOT_ADD)
            lots = maxExisting + InitialLotSize * GridLoss_AddLotPerLevel;
         // LOT_CUSTOM: keep level-based calculation
      }
      
      // v6.71: never reuse a level number that's already open after hedge unlock
      int _maxLvlGLTF = FindMaxGridLevelOnSideTF(tfIdx, side, "GL");
      int _nextLvlGLTF = (int)MathMax(_maxLvlGLTF + 1, currentGridCount + 1);
      string suffix = "GL#" + IntegerToString(_nextLvlGLTF);
      ENUM_ORDER_TYPE orderType = (side == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      if(OpenOrderTF(tfIdx, orderType, lots, suffix))
      {
         g_tfStates[tfIdx].lastGridLossCandle = iTime(_Symbol, g_tfStates[tfIdx].tf, 0);
      }
   }
}

//+------------------------------------------------------------------+
//| Check Grid Profit for a specific TF                                |
//+------------------------------------------------------------------+
void CheckGridProfitTF(int tfIdx, ENUM_POSITION_TYPE side, int currentGridCount)
{
   if(currentGridCount >= GridProfit_MaxTrades) return;
   if(NormalOrderCount() >= MaxOpenOrders) return;

   if(GridProfit_OnlyNewCandle)
   {
      datetime barTime = iTime(_Symbol, g_tfStates[tfIdx].tf, 0);
      if(barTime == g_tfStates[tfIdx].lastGridProfitCandle) return;
   }

   //--- v6.82: Candle Confirmation check (mirror of GL CandleConfirm)
   if(GridProfit_CandleConfirm > 0)
   {
      if(!HasCandleConfirmation(side, g_tfStates[tfIdx].tf, GridProfit_CandleConfirm)) return;
   }

   double lastPrice = 0;
   datetime lastTime = 0;
   FindLastOrderTF(tfIdx, side, "INIT", "GP", lastPrice, lastTime);

   if(lastPrice == 0)
   {
      if(side == POSITION_TYPE_BUY && g_tfStates[tfIdx].initialBuyPrice > 0)
         lastPrice = g_tfStates[tfIdx].initialBuyPrice;
      else if(side == POSITION_TYPE_SELL && g_tfStates[tfIdx].initialSellPrice > 0)
         lastPrice = g_tfStates[tfIdx].initialSellPrice;
      else
         return;
   }

   if(handleATR_Profit != INVALID_HANDLE)
   {
      if(CopyBuffer(handleATR_Profit, 0, 0, 3, bufATR_Profit) < 3) return;
   }

   double distance = GetGridDistance(currentGridCount, false);
   if(distance <= 0) return;

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double currentPrice = (side == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   bool shouldOpen = false;

   if(GridProfit_GapType == GAP_ATR && GridProfit_ATR_Reference == ATR_REF_INITIAL)
   {
      double initialRef = (side == POSITION_TYPE_BUY) ? g_tfStates[tfIdx].initialBuyPrice : g_tfStates[tfIdx].initialSellPrice;
      if(initialRef <= 0) return;
      double totalDistance = distance * (currentGridCount + 1);
      if(side == POSITION_TYPE_BUY)
         shouldOpen = (currentPrice >= initialRef + totalDistance * point);
      else
         shouldOpen = (currentPrice <= initialRef - totalDistance * point);
   }
   else
   {
      if(side == POSITION_TYPE_BUY && currentPrice >= lastPrice + distance * point)
         shouldOpen = true;
      else if(side == POSITION_TYPE_SELL && currentPrice <= lastPrice - distance * point)
         shouldOpen = true;
   }

   if(shouldOpen)
   {
      double lots = CalculateGridLot(currentGridCount, false);
      // v6.71: never reuse a level number that's already open
      int _maxLvlGPTF = FindMaxGridLevelOnSideTF(tfIdx, side, "GP");
      int _nextLvlGPTF = (int)MathMax(_maxLvlGPTF + 1, currentGridCount + 1);
      string suffix = "GP#" + IntegerToString(_nextLvlGPTF);
      ENUM_ORDER_TYPE orderType = (side == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      if(OpenOrderTF(tfIdx, orderType, lots, suffix))
      {
         g_tfStates[tfIdx].lastGridProfitCandle = iTime(_Symbol, g_tfStates[tfIdx].tf, 0);
      }
   }
}

//+------------------------------------------------------------------+
//| Manage TP/SL for a specific TF (basket per-TF)                     |
//+------------------------------------------------------------------+
void ManageTPSL_TF(int tfIdx)
{
   // v6.11: Skip TP/SL when hedge balanced lock is active
   // v6.46: Use direct hedge set check instead of g_hedgeBalancedLock
   // v6.47: Removed early return — TF calculations filter by comment prefix, bound orders won't interfere
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);

   //--- BUY side
   double avgBuy = CalculateAveragePriceTF(tfIdx, POSITION_TYPE_BUY);
   if(avgBuy > 0)
   {
      double plBuy = CalculateFloatingPL_TF(tfIdx, POSITION_TYPE_BUY);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      bool closeTP = false;
      bool closeSL = false;

       //--- v6.44: Dollar/Percent TP always active — Per-Order Trailing only manages SL
       if(UseTP_Dollar && plBuy >= TP_DollarAmount) closeTP = true;
       // v6.42: TP Points handled by broker via PositionModify
       // if(UseTP_Points && bid >= avgBuy + TP_Points * point) closeTP = true;
       if(UseTP_PercentBalance && plBuy >= bal * TP_PercentBalance / 100.0) closeTP = true;
      
      //--- DD% TP check (v6.7) - uses global max DD tracker (shared across TFs)
      if(UseTP_DDPercent && g_maxDDBuy < 0)
      {
         double tpTarget = MathAbs(g_maxDDBuy) * TP_DDPercent / 100.0;
         if(plBuy >= tpTarget && plBuy > 0)
         {
            Print("DD% TP HIT (", g_tfStates[tfIdx].tfLabel, " BUY): PL=", plBuy, " Target=+", tpTarget);
            closeTP = true;
         }
      }

      if(closeTP)
      {
         Print("TP HIT (", g_tfStates[tfIdx].tfLabel, " BUY): PL=", plBuy);
         CloseAllSideTF(tfIdx, POSITION_TYPE_BUY);
         g_tfStates[tfIdx].initialBuyPrice = 0;
         ResetTrailingStateTF(tfIdx);
         return;
      }

      if(EnableSL && !EnablePerOrderTrailing)
      {
         if(UseSL_Dollar && plBuy <= -SL_DollarAmount) closeSL = true;
         // v6.42: SL Points handled by broker via PositionModify
         // if(UseSL_Points && bid <= avgBuy - SL_Points * point) closeSL = true;
         if(UseSL_PercentBalance && plBuy <= -(bal * SL_PercentBalance / 100.0)) closeSL = true;

         if(closeSL)
         {
            if(SL_ActionMode == SL_CLOSE_ALL_STOP)
            {
               CloseAllPositions();
               g_eaStopped = true;
               Print("EA STOPPED by SL Action (", g_tfStates[tfIdx].tfLabel, " BUY)");
            }
            else
            {
               CloseAllSideTF(tfIdx, POSITION_TYPE_BUY);
               g_tfStates[tfIdx].initialBuyPrice = 0;
               ResetTrailingStateTF(tfIdx);
            }
            return;
         }
      }
   }

   //--- SELL side
   double avgSell = CalculateAveragePriceTF(tfIdx, POSITION_TYPE_SELL);
   if(avgSell > 0)
   {
      double plSell = CalculateFloatingPL_TF(tfIdx, POSITION_TYPE_SELL);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      bool closeTP2 = false;
      bool closeSL2 = false;

       //--- v6.44: Dollar/Percent TP always active — Per-Order Trailing only manages SL
       if(UseTP_Dollar && plSell >= TP_DollarAmount) closeTP2 = true;
       // v6.42: TP Points handled by broker via PositionModify
       // if(UseTP_Points && ask <= avgSell - TP_Points * point) closeTP2 = true;
       if(UseTP_PercentBalance && plSell >= bal * TP_PercentBalance / 100.0) closeTP2 = true;
      
      //--- DD% TP check (v6.7) - uses global max DD tracker (shared across TFs)
      if(UseTP_DDPercent && g_maxDDSell < 0)
      {
         double tpTargetSell = MathAbs(g_maxDDSell) * TP_DDPercent / 100.0;
         if(plSell >= tpTargetSell && plSell > 0)
         {
            Print("DD% TP HIT (", g_tfStates[tfIdx].tfLabel, " SELL): PL=", plSell, " Target=+", tpTargetSell);
            closeTP2 = true;
         }
      }

      if(closeTP2)
      {
         Print("TP HIT (", g_tfStates[tfIdx].tfLabel, " SELL): PL=", plSell);
         CloseAllSideTF(tfIdx, POSITION_TYPE_SELL);
         g_tfStates[tfIdx].initialSellPrice = 0;
         ResetTrailingStateTF(tfIdx);
         return;
      }

      if(EnableSL && !EnablePerOrderTrailing)
      {
         if(UseSL_Dollar && plSell <= -SL_DollarAmount) closeSL2 = true;
         // v6.42: SL Points handled by broker via PositionModify
         // if(UseSL_Points && ask >= avgSell + SL_Points * point) closeSL2 = true;
         if(UseSL_PercentBalance && plSell <= -(bal * SL_PercentBalance / 100.0)) closeSL2 = true;

         if(closeSL2)
         {
            if(SL_ActionMode == SL_CLOSE_ALL_STOP)
            {
               CloseAllPositions();
               g_eaStopped = true;
               Print("EA STOPPED by SL Action (", g_tfStates[tfIdx].tfLabel, " SELL)");
            }
            else
            {
               CloseAllSideTF(tfIdx, POSITION_TYPE_SELL);
               g_tfStates[tfIdx].initialSellPrice = 0;
               ResetTrailingStateTF(tfIdx);
            }
            return;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Manage Average-Based Trailing Stop for a specific TF               |
//+------------------------------------------------------------------+
void ManageTrailingStop_TF(int tfIdx)
{
   // v6.89: Squeeze Pause — strip broker SL on edge + skip MTF avg-trailing while in Expansion
   if(IsTrailingPausedAndHandleEdge()) return;
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   //--- BUY side
   double avgBuy = CalculateAveragePriceTF(tfIdx, POSITION_TYPE_BUY);
   if(avgBuy > 0)
   {
      double beLevel = avgBuy + BreakevenBuffer * point;

      if(EnableTrailingStop)
      {
         double trailAct = avgBuy + TrailingActivation * point;
         if(bid >= trailAct)
         {
            g_tfStates[tfIdx].trailActive_Buy = true;
            double newSL = bid - TrailingStep * point;
            newSL = MathMax(newSL, beLevel);
            if(newSL > g_tfStates[tfIdx].trailSL_Buy)
            {
               g_tfStates[tfIdx].trailSL_Buy = newSL;
               ApplyTrailingSL_TF(tfIdx, POSITION_TYPE_BUY, newSL);
            }
         }
      }

      if(EnableBreakeven && !g_tfStates[tfIdx].beDone_Buy)
      {
         double beAct = avgBuy + BreakevenActivation * point;
         if(bid >= beAct)
         {
            g_tfStates[tfIdx].beDone_Buy = true;
            if(g_tfStates[tfIdx].trailSL_Buy < beLevel)
            {
               g_tfStates[tfIdx].trailSL_Buy = beLevel;
               ApplyTrailingSL_TF(tfIdx, POSITION_TYPE_BUY, beLevel);
            }
         }
      }

      if(g_tfStates[tfIdx].trailActive_Buy && g_tfStates[tfIdx].trailSL_Buy > 0 && bid <= g_tfStates[tfIdx].trailSL_Buy)
      {
         Print("TRAILING SL HIT (", g_tfStates[tfIdx].tfLabel, " BUY): SL=", g_tfStates[tfIdx].trailSL_Buy);
         CloseAllSideTF(tfIdx, POSITION_TYPE_BUY);
         g_tfStates[tfIdx].initialBuyPrice = 0;
         // v6.84: per-side reset + NO return so SELL continues processing this tick
         ResetTrailingStateTFBuy(tfIdx);
      }
   }
   else
   {
      g_tfStates[tfIdx].trailSL_Buy = 0;
      g_tfStates[tfIdx].trailActive_Buy = false;
      g_tfStates[tfIdx].beDone_Buy = false;
   }

   //--- SELL side
   double avgSell = CalculateAveragePriceTF(tfIdx, POSITION_TYPE_SELL);
   if(avgSell > 0)
   {
      double beLevelSell = avgSell - BreakevenBuffer * point;

      if(EnableTrailingStop)
      {
         double trailActSell = avgSell - TrailingActivation * point;
         if(ask <= trailActSell)
         {
            g_tfStates[tfIdx].trailActive_Sell = true;
            double newSL = ask + TrailingStep * point;
            newSL = MathMin(newSL, beLevelSell);
            if(g_tfStates[tfIdx].trailSL_Sell == 0 || newSL < g_tfStates[tfIdx].trailSL_Sell)
            {
               g_tfStates[tfIdx].trailSL_Sell = newSL;
               ApplyTrailingSL_TF(tfIdx, POSITION_TYPE_SELL, newSL);
            }
         }
      }

      if(EnableBreakeven && !g_tfStates[tfIdx].beDone_Sell)
      {
         double beActSell = avgSell - BreakevenActivation * point;
         if(ask <= beActSell)
         {
            g_tfStates[tfIdx].beDone_Sell = true;
            if(g_tfStates[tfIdx].trailSL_Sell == 0 || g_tfStates[tfIdx].trailSL_Sell > beLevelSell)
            {
               g_tfStates[tfIdx].trailSL_Sell = beLevelSell;
               ApplyTrailingSL_TF(tfIdx, POSITION_TYPE_SELL, beLevelSell);
            }
         }
      }

      if(g_tfStates[tfIdx].trailActive_Sell && g_tfStates[tfIdx].trailSL_Sell > 0 && ask >= g_tfStates[tfIdx].trailSL_Sell)
      {
         Print("TRAILING SL HIT (", g_tfStates[tfIdx].tfLabel, " SELL): SL=", g_tfStates[tfIdx].trailSL_Sell);
         CloseAllSideTF(tfIdx, POSITION_TYPE_SELL);
         g_tfStates[tfIdx].initialSellPrice = 0;
         // v6.84: per-side reset (preserve BUY state)
         ResetTrailingStateTFSell(tfIdx);
      }
   }
   else
   {
      g_tfStates[tfIdx].trailSL_Sell = 0;
      g_tfStates[tfIdx].trailActive_Sell = false;
      g_tfStates[tfIdx].beDone_Sell = false;
   }
}

//+------------------------------------------------------------------+
//| Apply trailing SL to positions of a TF side                        |
//+------------------------------------------------------------------+
void ApplyTrailingSL_TF(int tfIdx, ENUM_POSITION_TYPE side, double slPrice)
{
   // v6.87: Squeeze Pause guard (defense-in-depth)
   if(IsSqueezePausingTrailing()) return;
   string tfLabel = g_tfStates[tfIdx].tfLabel;
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   slPrice = NormalizeDouble(slPrice, digits);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) != side) continue;
      if(!MatchTFPrefix(PositionGetString(POSITION_COMMENT), tfLabel)) continue;
      // v6.93 FIX: never push TF basket trailing SL onto Hero tickets
      if(IsHeroTicket(ticket)) continue;

      double currentSL = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);

      if(side == POSITION_TYPE_BUY)
      {
         if(currentSL == 0 || slPrice > currentSL)
            trade.PositionModify(ticket, slPrice, tp);
      }
      else
      {
         if(currentSL == 0 || slPrice < currentSL)
            trade.PositionModify(ticket, slPrice, tp);
      }
   }
}

//+------------------------------------------------------------------+
//| Manage Shared Accumulate Close (ZigZag mode)                       |
//+------------------------------------------------------------------+
void ManageAccumulateShared()
{
   if(!UseAccumulateClose) return;

   //--- Auto-reset baseline when all positions are closed (cycle ended)
   int currentCount = TotalOrderCount();
     if(g_hadPositions && currentCount == 0)
   {
      // v6.27: Safe reset — only if truly flat
      TryResetCycleStateIfFlat("ZZ accumulate reset");
      UpdateDynamicBalanceGuardTarget();  // v6.31
      g_accumulateBaseline = CalcTotalHistoryProfit();
      g_accumulatedProfit = 0;
      g_hadPositions = false;
      Print("Accumulate auto-reset (ZZ): no positions left. New baseline: ", g_accumulateBaseline);
      return;
   }
   if(currentCount > 0) g_hadPositions = true;

   double totalHistory = CalcTotalHistoryProfit();
   g_accumulatedProfit = totalHistory - g_accumulateBaseline;

   double totalFloating = CalculateTotalFloatingPL();
   double accumTotal = g_accumulatedProfit + totalFloating;

   if(accumTotal >= AccumulateTarget && accumTotal > 0)  // trigger on total (closed + floating)
   {
      Print("ACCUMULATE TARGET HIT: ", accumTotal, " / ", AccumulateTarget);
      CloseAllPositions();
      Sleep(500);
      double newHistory = CalcTotalHistoryProfit();
      g_accumulateBaseline = newHistory;
      g_accumulatedProfit = 0;
      g_hadPositions = false;

      // Reset all TF states
      for(int t = 0; t < g_activeTFCount; t++)
      {
         g_tfStates[t].initialBuyPrice = 0;
         g_tfStates[t].initialSellPrice = 0;
         ResetTrailingStateTF(t);
      }

      Print("Accumulate cycle reset (ZZ). New baseline: ", newHistory);
   }
}

//+------------------------------------------------------------------+
//| Main ZigZag MTF OnTick Handler                                     |
//+------------------------------------------------------------------+
void OnTickZigZagMTF()
{
   // Step 1: Update CDC (if enabled)
   if(InpUseCDCFilter) UpdateCDC();

   // Step 2: Check H4 ZigZag direction (only on new H4 bar)
   if(g_h4TFIndex >= 0)
   {
      datetime h4Bar = iTime(_Symbol, ZZ_ConfirmTF, 0);
      if(h4Bar != g_lastH4Bar)
      {
         g_lastH4Bar = h4Bar;
         string h4Swing = DetectZigZagSwing(g_h4TFIndex);
         if(h4Swing == "LOW") g_h4Direction = "BUY";
         else if(h4Swing == "HIGH") g_h4Direction = "SELL";
         // else keep previous direction
      }
   }

   // Step 3: Apply CDC filter to direction
   string effectiveDirection = g_h4Direction;
   if(InpUseCDCFilter && g_cdcReady)
   {
      if(effectiveDirection == "BUY" && g_cdcTrend == "BEARISH") effectiveDirection = "NONE";
      if(effectiveDirection == "SELL" && g_cdcTrend == "BULLISH") effectiveDirection = "NONE";
   }

   // Step 4: Process each enabled sub-TF
   for(int t = 0; t < g_activeTFCount; t++)
   {
      if(!g_tfStates[t].enabled) continue;

      datetime tfBar = iTime(_Symbol, g_tfStates[t].tf, 0);

      // Per-TF trailing (average-based, non per-order)
      if(!EnablePerOrderTrailing && (EnableTrailingStop || EnableBreakeven))
      {
         ManageTrailingStop_TF(t);
      }

      // Per-TF TP/SL
      ManageTPSL_TF(t);

      // Count positions for this TF
      int tfBuyCount = 0, tfSellCount = 0;
      int tfGLBuy = 0, tfGLSell = 0, tfGPBuy = 0, tfGPSell = 0;
      bool tfHasInitBuy = false, tfHasInitSell = false;
      CountPositionsTF(t, tfBuyCount, tfSellCount, tfGLBuy, tfGLSell, tfGPBuy, tfGPSell, tfHasInitBuy, tfHasInitSell);

      // Auto-detect broker-closed positions per TF
      if(tfBuyCount == 0 && g_tfStates[t].initialBuyPrice != 0)
      {
         Print(g_tfStates[t].tfLabel, " BUY cycle ended (broker). Resetting.");
         g_tfStates[t].initialBuyPrice = 0;
      }
      if(tfSellCount == 0 && g_tfStates[t].initialSellPrice != 0)
      {
         Print(g_tfStates[t].tfLabel, " SELL cycle ended (broker). Resetting.");
         g_tfStates[t].initialSellPrice = 0;
      }

       // v6.39: Hedge Side Pause for ZigZag mode
       bool buyHedgePaused = (InpHedge_SidePauseMin > 0 && g_lastHedgeBuyTime > 0 
                              && (TimeCurrent() - g_lastHedgeBuyTime) < InpHedge_SidePauseMin * 60);
       bool sellHedgePaused = (InpHedge_SidePauseMin > 0 && g_lastHedgeSellTime > 0 
                               && (TimeCurrent() - g_lastHedgeSellTime) < InpHedge_SidePauseMin * 60);

       // Grid management
       if(!g_newOrderBlocked)
       {
          // Grid Loss
          if(!buyHedgePaused && !g_squeezeBuyBlocked && (tfHasInitBuy || g_tfStates[t].initialBuyPrice > 0) && tfGLBuy < GridLoss_MaxTrades && tfBuyCount > 0)
             CheckGridLossTF(t, POSITION_TYPE_BUY, tfGLBuy);
          if(!sellHedgePaused && !g_squeezeSellBlocked && (tfHasInitSell || g_tfStates[t].initialSellPrice > 0) && tfGLSell < GridLoss_MaxTrades && tfSellCount > 0)
             CheckGridLossTF(t, POSITION_TYPE_SELL, tfGLSell);

          // Grid Profit
          if(GridProfit_Enable)
          {
             if(!g_squeezeBuyBlocked && (tfHasInitBuy || g_tfStates[t].initialBuyPrice > 0) && tfGPBuy < GridProfit_MaxTrades && tfBuyCount > 0)
                CheckGridProfitTF(t, POSITION_TYPE_BUY, tfGPBuy);
             if(!g_squeezeSellBlocked && (tfHasInitSell || g_tfStates[t].initialSellPrice > 0) && tfGPSell < GridProfit_MaxTrades && tfSellCount > 0)
                CheckGridProfitTF(t, POSITION_TYPE_SELL, tfGPSell);
          }
       }

       // Entry check: sub-TF ZigZag must agree with H4 direction
       if(!g_newOrderBlocked && effectiveDirection != "NONE")
       {
          bool canOpenMore = NormalOrderCount() < MaxOpenOrders;
          bool canOpenThisCandle = !(DontOpenSameCandle && tfBar == g_tfStates[t].lastInitialCandle);

          // Detect sub-TF swing
          string subSwing = DetectZigZagSwing(t);

          // BUY entry — v6.39: add hedge pause guard
          if(!buyHedgePaused && !g_squeezeBuyBlocked && effectiveDirection == "BUY" && subSwing == "LOW" && tfBuyCount == 0
             && g_tfStates[t].initialBuyPrice == 0 && canOpenMore && canOpenThisCandle
             && (TradingMode == TRADE_BUY_ONLY || TradingMode == TRADE_BOTH))
          {
             bool shouldEnter = true;
             if(g_tfStates[t].justClosedBuy && !EnableAutoReEntry)
                shouldEnter = false;

             if(shouldEnter)
             {
                if(OpenOrderTF(t, ORDER_TYPE_BUY, InitialLotSize, "INIT"))
                {
                   g_tfStates[t].initialBuyPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                   g_tfStates[t].lastInitialCandle = tfBar;
                   ResetTrailingStateTF(t);
                   Print(g_tfStates[t].tfLabel, " ZigZag BUY INIT at ", g_tfStates[t].initialBuyPrice);
                }
             }
          }

          // SELL entry — v6.39: add hedge pause guard
          if(!sellHedgePaused && !g_squeezeSellBlocked && effectiveDirection == "SELL" && subSwing == "HIGH" && tfSellCount == 0
             && g_tfStates[t].initialSellPrice == 0 && canOpenMore && canOpenThisCandle
             && (TradingMode == TRADE_SELL_ONLY || TradingMode == TRADE_BOTH))
          {
             bool shouldEnter = true;
             if(g_tfStates[t].justClosedSell && !EnableAutoReEntry)
                shouldEnter = false;

             if(shouldEnter)
             {
                if(OpenOrderTF(t, ORDER_TYPE_SELL, InitialLotSize, "INIT"))
                {
                   g_tfStates[t].initialSellPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                   g_tfStates[t].lastInitialCandle = tfBar;
                   ResetTrailingStateTF(t);
                   Print(g_tfStates[t].tfLabel, " ZigZag SELL INIT at ", g_tfStates[t].initialSellPrice);
                }
             }
          }
      }

      // Reset justClosed flags when not blocked
      if(!g_newOrderBlocked)
      {
         g_tfStates[t].justClosedBuy = false;
         g_tfStates[t].justClosedSell = false;
      }
   }

   // Step 5: Matching Close (ZigZag mode - new bar already confirmed)
   if(UseMatchingClose)
      ManageMatchingClose();

   // Step 6: Shared Accumulate Close
   ManageAccumulateShared();
}

//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ============== LICENSE MODULE (from v5.34) ===================== |
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
   
   if(StringLen(g_licenseServerUrl) == 0)
   {
      g_lastLicenseError = "License server URL is empty";
      g_licenseStatus = LICENSE_ERROR;
      return false;
   }
   
   g_licenseStatus = VerifyLicense();
   g_lastLicenseCheck = TimeCurrent();
   
   g_isLicenseValid = (g_licenseStatus == LICENSE_VALID || g_licenseStatus == LICENSE_EXPIRING_SOON);
   
   if(g_isLicenseValid)
   {
      SyncAccountData();
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
   
   long accountNumber = AccountInfoInteger(ACCOUNT_LOGIN);
   string jsonRequest = "{\"account_number\":\"" + IntegerToString(accountNumber) + "\"}";
   
   string response = "";
   int httpCode = SendLicenseRequest(url, jsonRequest, response);
   
   if(httpCode != 200)
   {
      g_lastLicenseError = "HTTP Error: " + IntegerToString(httpCode);
      return LICENSE_ERROR;
   }
   
   return ParseVerifyResponse(response);
}

//+------------------------------------------------------------------+
//| Parse Verify License Response                                      |
//+------------------------------------------------------------------+
ENUM_LICENSE_STATUS ParseVerifyResponse(string response)
{
   bool valid = JsonGetBool(response, "valid");
   
   if(!valid)
   {
      string message = JsonGetString(response, "message");
      g_lastLicenseError = message;
      
      if(StringFind(message, "not found") >= 0 || StringFind(message, "Not found") >= 0)
         return LICENSE_NOT_FOUND;
      if(StringFind(message, "suspended") >= 0 || StringFind(message, "inactive") >= 0)
         return LICENSE_SUSPENDED;
      if(StringFind(message, "expired") >= 0 || StringFind(message, "Expired") >= 0)
         return LICENSE_EXPIRED;
      
      return LICENSE_ERROR;
   }
   
   g_customerName = JsonGetString(response, "customer_name");
   g_packageType = JsonGetString(response, "package_type");
   g_tradingSystem = JsonGetString(response, "trading_system");
   g_daysRemaining = JsonGetInt(response, "days_remaining");
   g_isLifetime = JsonGetBool(response, "is_lifetime");
   
   string expiryStr = JsonGetString(response, "expiry_date");
   if(StringLen(expiryStr) > 0 && expiryStr != "null")
   {
      g_expiryDate = StringToTime(StringSubstr(expiryStr, 0, 10));
   }
   
   if(!g_isLifetime && g_daysRemaining <= 7 && g_daysRemaining > 0)
   {
      return LICENSE_EXPIRING_SOON;
   }
   
   return LICENSE_VALID;
}

//+------------------------------------------------------------------+
//| Sync Account Data to Server (Legacy wrapper)                       |
//+------------------------------------------------------------------+
bool SyncAccountData()
{
   return SyncAccountDataWithEvent(SYNC_SCHEDULED);
}

//+------------------------------------------------------------------+
//| Sync Account Data with Event Type                                  |
//+------------------------------------------------------------------+
bool SyncAccountDataWithEvent(ENUM_SYNC_EVENT eventType)
{
   string url = g_licenseServerUrl + "/functions/v1/sync-account-data";
   
   long accountNumber = AccountInfoInteger(ACCOUNT_LOGIN);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   double floatingProfit = AccountInfoDouble(ACCOUNT_PROFIT);
   
   double drawdown = 0;
   if(balance > 0)
   {
      drawdown = ((balance - equity) / balance) * 100;
      if(drawdown < 0) drawdown = 0;
   }
   
   int openOrders = PositionsTotal();
   
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
   
   string eventTypeStr = "scheduled";
   if(eventType == SYNC_ORDER_OPEN) eventTypeStr = "order_open";
   else if(eventType == SYNC_ORDER_CLOSE) eventTypeStr = "order_close";
   
   string eaStatus = "working";
   if(g_licenseStatus == LICENSE_SUSPENDED) eaStatus = "suspended";
   else if(g_licenseStatus == LICENSE_EXPIRED) eaStatus = "expired";
   else if(g_licenseStatus == LICENSE_NOT_FOUND || g_licenseStatus == LICENSE_ERROR) eaStatus = "invalid";
   else if(!g_isLicenseValid) eaStatus = "paused";
   
   string accountCurrency = AccountInfoString(ACCOUNT_CURRENCY);
   
   ENUM_ACCOUNT_TRADE_MODE tradeMode = (ENUM_ACCOUNT_TRADE_MODE)AccountInfoInteger(ACCOUNT_TRADE_MODE);
   string accountTypeStr = (tradeMode == ACCOUNT_TRADE_MODE_DEMO) ? "demo" : 
                           (tradeMode == ACCOUNT_TRADE_MODE_CONTEST) ? "contest" : "real";
   
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
   json += "\"initial_balance\":" + DoubleToString(initialBalance, 2) + ",";
   json += "\"total_deposit\":" + DoubleToString(totalDeposit, 2) + ",";
   json += "\"total_withdrawal\":" + DoubleToString(totalWithdrawal, 2) + ",";
   json += "\"max_drawdown\":" + DoubleToString(maxDrawdown, 2) + ",";
   json += "\"win_trades\":" + IntegerToString(winTrades) + ",";
   json += "\"loss_trades\":" + IntegerToString(lossTrades) + ",";
   json += "\"total_trades\":" + IntegerToString(totalTrades) + ",";
   json += "\"event_type\":\"" + eventTypeStr + "\",";
   json += "\"ea_name\":\"Gold Miner EA\",";
   json += "\"ea_status\":\"" + eaStatus + "\",";
   json += "\"currency\":\"" + accountCurrency + "\",";
   json += "\"account_type\":\"" + accountTypeStr + "\"";
   
   string tradeHistoryJson = BuildTradeHistoryJson();
   if(StringLen(tradeHistoryJson) > 2)
   {
      json += ",\"trade_history\":" + tradeHistoryJson;
   }
   
   json += "}";
   
   string response = "";
   int httpCode = SendLicenseRequest(url, json, response);
   
   if(httpCode != 200)
   {
      g_lastLicenseError = "Sync HTTP Error: " + IntegerToString(httpCode);
      Print("[Sync] HTTP Error: ", httpCode);
      return false;
   }
   
   bool success = JsonGetBool(response, "success");
   if(success)
   {
      Print("[Sync] Data synced successfully (event: ", eventTypeStr, ")");
   }
   
   return success;
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
   
   if(!HistorySelect(0, TimeCurrent()))
   {
      Print("[Trade History] Failed to select history");
      return "[]";
   }
   
   int totalDeals = HistoryDealsTotal();
   int startIdx = MathMax(0, totalDeals - 100);
   
   for(int i = startIdx; i < totalDeals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket > 0)
      {
         ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(dealTicket, DEAL_TYPE);
         ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
         
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
         
         string dealTypeStr = "unknown";
         if(dealType == DEAL_TYPE_BUY) dealTypeStr = "buy";
         else if(dealType == DEAL_TYPE_SELL) dealTypeStr = "sell";
         else if(dealType == DEAL_TYPE_BALANCE) dealTypeStr = "balance";
         
         string entryTypeStr = "unknown";
         if(dealEntry == DEAL_ENTRY_IN) entryTypeStr = "in";
         else if(dealEntry == DEAL_ENTRY_OUT) entryTypeStr = "out";
         else if(dealEntry == DEAL_ENTRY_INOUT) entryTypeStr = "inout";
         
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
//| OnTradeTransaction - Real-time sync on order events                |
//+------------------------------------------------------------------+
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
             {
                // v6.49: Deferred sync — set flag only, actual sync runs at end of OnTick after TP/SL is set
                g_pendingSyncOrderOpen = true;
             }
             else if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_INOUT)
             {
                // v6.49: Deferred sync — set flag only
                g_pendingSyncOrderClose = true;
             }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| OnTick License Handler                                             |
//+------------------------------------------------------------------+
bool OnTickLicense()
{
   datetime currentTime = TimeCurrent();
   
   if(currentTime - g_lastLicenseCheck >= g_licenseCheckInterval * 60)
   {
      ENUM_LICENSE_STATUS newStatus = VerifyLicense();
      g_lastLicenseCheck = currentTime;
      
      if(newStatus != g_licenseStatus)
      {
         g_licenseStatus = newStatus;
         g_isLicenseValid = (newStatus == LICENSE_VALID || newStatus == LICENSE_EXPIRING_SOON);
         
         if(!g_isLicenseValid)
         {
            ShowLicensePopup(g_licenseStatus);
         }
      }
      
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
   
   if(g_isLicenseValid && (currentTime - g_lastDataSync >= g_dataSyncInterval * 60))
   {
      SyncAccountData();
      g_lastDataSync = currentTime;
   }
   
   return g_isLicenseValid;
}

//+------------------------------------------------------------------+
//| Show License Status Popup                                          |
//+------------------------------------------------------------------+
void ShowLicensePopup(ENUM_LICENSE_STATUS status)
{
   string title = "Gold Miner EA - License";
   string message = "";
   uint flags = MB_OK;
   
   switch(status)
   {
      case LICENSE_VALID:
      {
         message = "License Verified Successfully!\n\n";
         message += "Customer: " + g_customerName + "\n";
         message += "Package: " + g_packageType + "\n";
         message += "System: " + g_tradingSystem + "\n\n";
         if(g_isLifetime)
            message += "License Type: LIFETIME\n";
         else
            message += "Expires: " + TimeToString(g_expiryDate, TIME_DATE) + "\n";
         message += "\nHappy Trading!";
         flags = MB_OK | MB_ICONINFORMATION;
         break;
      }
      case LICENSE_EXPIRING_SOON:
      {
         message = "License Expiring Soon!\n\n";
         message += "Customer: " + g_customerName + "\n";
         message += "Days Remaining: " + IntegerToString(g_daysRemaining) + " days\n";
         message += "Expires: " + TimeToString(g_expiryDate, TIME_DATE) + "\n\n";
         message += "Please renew your license to continue using.\n";
         message += "Contact: support@moneyx-smart.com";
         flags = MB_OK | MB_ICONWARNING;
         break;
      }
      case LICENSE_EXPIRED:
      {
         message = "License Expired!\n\n";
         message += "Your license has expired.\n";
         message += "Trading is disabled.\n\n";
         message += "Please renew your license to continue.\n";
         message += "Contact: support@moneyx-smart.com";
         flags = MB_OK | MB_ICONERROR;
         break;
      }
      case LICENSE_NOT_FOUND:
      {
         message = "Account Not Registered!\n\n";
         message += "Account: " + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "\n\n";
         message += "This account is not registered in our system.\n";
         message += "Please purchase a license to use this EA.\n\n";
         message += "Contact: support@moneyx-smart.com";
         flags = MB_OK | MB_ICONERROR;
         break;
      }
      case LICENSE_SUSPENDED:
      {
         message = "License Suspended!\n\n";
         message += "Your license has been suspended.\n";
         message += "Trading is disabled.\n\n";
         message += "Please contact support for assistance.\n";
         message += "Contact: support@moneyx-smart.com";
         flags = MB_OK | MB_ICONERROR;
         break;
      }
      case LICENSE_ERROR:
      {
         message = "License Verification Error!\n\n";
         message += "Could not verify license.\n";
         message += "Error: " + g_lastLicenseError + "\n\n";
         message += "Please check:\n";
         message += "1. Internet connection\n";
         message += "2. WebRequest allowed for:\n";
         message += "   " + g_licenseServerUrl + "\n\n";
         message += "EA will retry on next check.";
         flags = MB_OK | MB_ICONWARNING;
         break;
      }
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
   string headers = "Content-Type: application/json\r\nx-api-key: " + EA_API_SECRET + "\r\n";
   string resultHeaders;
   
   StringToCharArray(jsonData, postData, 0, StringLen(jsonData));
   ArrayResize(postData, StringLen(jsonData));
   
   int timeout = 10000;
   int httpCode = WebRequest("POST", url, headers, timeout, postData, result, resultHeaders);
   
   if(httpCode == -1)
   {
      int errorCode = GetLastError();
      g_lastLicenseError = "WebRequest failed. Error: " + IntegerToString(errorCode);
      
      if(errorCode == 4014)
      {
         g_lastLicenseError = "WebRequest not allowed. Add URL to allowed list:\n" + 
                       "Tools -> Options -> Expert Advisors -> Allow WebRequest for listed URL\n" +
                       "Add: " + g_licenseServerUrl;
      }
      
      return -1;
   }
   
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
   
   while(valueStart < StringLen(json) && (StringGetCharacter(json, valueStart) == ' ' || 
                                           StringGetCharacter(json, valueStart) == '\t'))
   {
      valueStart++;
   }
   
   if(StringSubstr(json, valueStart, 4) == "null")
      return "";
   
   if(StringGetCharacter(json, valueStart) == '"')
   {
      valueStart++;
      int valueEnd = StringFind(json, "\"", valueStart);
      if(valueEnd < 0)
         return "";
      return StringSubstr(json, valueStart, valueEnd - valueStart);
   }
   
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
//| ============== NEWS FILTER MODULE (from v5.34) ================= |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Chart Base Currency (e.g., XAUUSD -> XAU)                      |
//+------------------------------------------------------------------+
string GetChartBaseCurrency()
{
   string symbol = _Symbol;
   if(StringLen(symbol) >= 6)
      return StringSubstr(symbol, 0, 3);
   return "";
}

//+------------------------------------------------------------------+
//| Get Chart Quote Currency (e.g., XAUUSD -> USD)                     |
//+------------------------------------------------------------------+
string GetChartQuoteCurrency()
{
   string symbol = _Symbol;
   if(StringLen(symbol) >= 6)
      return StringSubstr(symbol, 3, 3);
   return "";
}

//+------------------------------------------------------------------+
//| Check if Currency is Relevant for News Filter                      |
//+------------------------------------------------------------------+
bool IsCurrencyRelevant(string newsCurrency)
{
   if(InpNewsUseChartCurrency)
   {
      string baseCurrency = GetChartBaseCurrency();
      string quoteCurrency = GetChartQuoteCurrency();
      
      if(newsCurrency == baseCurrency || newsCurrency == quoteCurrency)
         return true;
      return false;
   }
   
   string currencies = InpNewsCurrencies;
   if(StringLen(currencies) == 0)
      return false;
   
   string currencyList[];
   int count = StringSplit(currencies, ';', currencyList);
   
   for(int i = 0; i < count; i++)
   {
      string curr = currencyList[i];
      StringTrimLeft(curr);
      StringTrimRight(curr);
      if(curr == newsCurrency)
         return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if News Title Matches Custom Keywords                        |
//+------------------------------------------------------------------+
bool IsCustomNewsMatch(string newsTitle)
{
   if(!InpFilterCustomNews)
      return false;
   
   string keywords = InpCustomNewsKeywords;
   if(StringLen(keywords) == 0)
      return false;
   
   string keywordList[];
   int count = StringSplit(keywords, ';', keywordList);
   
   string upperTitle = newsTitle;
   StringToUpper(upperTitle);
   
   for(int i = 0; i < count; i++)
   {
      string keyword = keywordList[i];
      StringTrimLeft(keyword);
      StringTrimRight(keyword);
      StringToUpper(keyword);
      
      if(StringLen(keyword) > 0 && StringFind(upperTitle, keyword) >= 0)
         return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Extract text from JSON element                                     |
//+------------------------------------------------------------------+
string ExtractJSONValue(string json, string key)
{
   string quote = "\"";
   string searchKey = quote + key + quote + ":";
   int startPos = StringFind(json, searchKey);
   if(startPos < 0) return "";

   startPos += StringLen(searchKey);

   while(startPos < StringLen(json) && StringSubstr(json, startPos, 1) == " ")
      startPos++;

   if(startPos >= StringLen(json)) return "";

   string firstChar = StringSubstr(json, startPos, 1);
   string value = "";

   if(firstChar == quote)
   {
      startPos++;
      int endPos = StringFind(json, quote, startPos);
      if(endPos < 0) return "";
      value = StringSubstr(json, startPos, endPos - startPos);
      StringReplace(value, "\\/", "/");
      StringReplace(value, "\\\"", "\"");
      StringReplace(value, "\\n", "\n");
   }
   else
   {
      int endPos = startPos;
      while(endPos < StringLen(json))
      {
         string c = StringSubstr(json, endPos, 1);
         if(c == "," || c == "}" || c == "]")
            break;
         endPos++;
      }
      value = StringSubstr(json, startPos, endPos - startPos);
   }

   StringTrimLeft(value);
   StringTrimRight(value);

   return value;
}

//+------------------------------------------------------------------+
//| Check if WebRequest is properly configured                         |
//+------------------------------------------------------------------+
bool CheckWebRequestConfiguration()
{
   if(!InpEnableNewsFilter)
   {
      g_webRequestConfigured = true;
      return true;
   }
   
   Print("NEWS FILTER: Checking WebRequest configuration...");
   
   string testUrl = InpLicenseServer + "/functions/v1/economic-news?limit=1";
   char postData[], resultData[];
   string headers = "";
   string resultHeaders;
   int timeout = 5000;
   
   ResetLastError();
   
   int result = WebRequest("GET", testUrl, headers, timeout, postData, resultData, resultHeaders);
   
   if(result == -1)
   {
      int error = GetLastError();
      
      if(error == 4060)
      {
         Print("NEWS FILTER ERROR [4060]: WebRequest is NOT enabled in MT5 settings!");
         g_webRequestConfigured = false;
         return false;
      }
      else if(error == 4024)
      {
         Print("NEWS FILTER ERROR [4024]: URL is NOT in the allowed WebRequest list!");
         g_webRequestConfigured = false;
         return false;
      }
      else
      {
         Print("NEWS FILTER ERROR [", error, "]: WebRequest failed - possibly network issue");
         if(error == 5203 || error == 5200 || error == 5201)
         {
            Print("NEWS FILTER: Network error detected - WebRequest is configured, will retry in RefreshNewsData");
            g_webRequestConfigured = true;
            return true;
         }
         Print("NEWS FILTER: Unknown error - will retry later");
         return g_webRequestConfigured;
      }
   }
   
   g_webRequestConfigured = true;
   Print("NEWS FILTER: WebRequest is properly configured!");
   return true;
}

//+------------------------------------------------------------------+
//| Show WebRequest Setup Alert with Instructions                      |
//+------------------------------------------------------------------+
void ShowWebRequestSetupAlert()
{
   string alertTitle = "NEWS FILTER: WebRequest Configuration Required!";
   
   string alertMessage = 
      "News Filter cannot fetch data because WebRequest is not configured.\n\n"
      "Please configure WebRequest:\n\n"
      "1. Open MT5 -> Tools -> Options\n"
      "   (or press Ctrl+O)\n\n"
      "2. Go to 'Expert Advisors' tab\n\n"
      "3. Enable 'Allow WebRequest for listed URL:'\n\n"
      "4. Click 'Add new URL' and add:\n"
      "   " + InpLicenseServer + "\n\n"
      "5. Click OK and RESTART EA\n\n"
      "URL Required: " + InpLicenseServer;
   
   MessageBox(alertMessage, alertTitle, 0x30);
   
   Print("========================================");
   Print("NEWS FILTER: WebRequest NOT CONFIGURED!");
   Print("URL Required: ", InpLicenseServer);
   Print("========================================");
}

//+------------------------------------------------------------------+
//| Fetch and Parse News Data                                          |
//+------------------------------------------------------------------+
void RefreshNewsData()
{
   if(!InpEnableNewsFilter)
      return;
   
   datetime currentTime = TimeCurrent();
   
   if(!g_forceNewsRefresh && g_lastNewsRefresh > 0 && (currentTime - g_lastNewsRefresh) < 3600)
      return;
   
   g_forceNewsRefresh = false;
   
   Print("NEWS FILTER: Refreshing news data from MoneyX API...");
   
   MqlDateTime dt;
   TimeToStruct(currentTime, dt);
   
   string currencies = "";
   if(InpNewsUseChartCurrency)
   {
      string sym = Symbol();
      if(StringLen(sym) >= 6)
      {
         currencies = StringSubstr(sym, 0, 3) + "," + StringSubstr(sym, 3, 3);
      }
   }
   else
   {
      currencies = InpNewsCurrencies;
      StringReplace(currencies, ";", ",");
   }
   
   string impacts = "";
   bool hasCustomKeywords = InpFilterCustomNews && StringLen(InpCustomNewsKeywords) > 0;
   
   if(!hasCustomKeywords)
   {
      if(InpFilterHighNews) impacts += "High,";
      if(InpFilterMedNews) impacts += "Medium,";
      if(InpFilterLowNews) impacts += "Low,";
      if(StringLen(impacts) > 0)
         impacts = StringSubstr(impacts, 0, StringLen(impacts) - 1);
   }
   
   string apiUrl = InpLicenseServer + "/functions/v1/economic-news?ts=" + IntegerToString((long)currentTime);
   if(StringLen(currencies) > 0)
      apiUrl += "&currency=" + currencies;
   if(StringLen(impacts) > 0)
      apiUrl += "&impact=" + impacts;
   
   if(hasCustomKeywords)
      Print("NEWS FILTER: Custom Keywords active - fetching ALL impact levels");
   
   char postData[], resultData[];
   string headers = "User-Agent: MoneyX-EA/2.8\r\nAccept: application/json\r\nConnection: close";
   string resultHeaders;
   
   int timeout = 10000;
   
   Print("NEWS FILTER: Fetching from ", apiUrl);
   
   int result = WebRequest("GET", apiUrl, headers, timeout, postData, resultData, resultHeaders);
   
   if(result == -1)
   {
      int firstError = GetLastError();
      Print("NEWS FILTER: First attempt failed (error ", firstError, "), retrying after 1 second...");
      Sleep(1000);
      ResetLastError();
      result = WebRequest("GET", apiUrl, headers, timeout, postData, resultData, resultHeaders);
   }
   
   if(result == -1)
   {
      int error = GetLastError();
      Print("NEWS FILTER ERROR: WebRequest failed - Error ", error);
      
      if(error == 4060 || error == 4024)
      {
         g_webRequestConfigured = false;
      }
      
      if(g_newsEventCount > 0)
      {
         g_usingCachedNews = true;
         Print("NEWS FILTER: Using cached data (", g_newsEventCount, " events from ", TimeToString(g_lastGoodNewsTime), ")");
      }
      g_lastNewsRefresh = currentTime - 3300;
      return;
   }
   
   if(result != 200)
   {
      Print("NEWS FILTER ERROR: HTTP ", result, " - Server returned error");
      if(g_newsEventCount > 0)
      {
         g_usingCachedNews = true;
         Print("NEWS FILTER: Using cached data (", g_newsEventCount, " events)");
      }
      g_lastNewsRefresh = currentTime - 3300;
      return;
   }
   
   int responseSize = ArraySize(resultData);
   
   string jsonContent = CharArrayToString(resultData, 0, WHOLE_ARRAY, CP_UTF8);
   
   if(responseSize < 10)
   {
      Print("NEWS FILTER WARNING: Response too short (", responseSize, " bytes)");
      if(g_newsEventCount > 0)
      {
         g_usingCachedNews = true;
      }
      return;
   }
   
   string trimmedContent = jsonContent;
   StringTrimLeft(trimmedContent);
   
   if(StringSubstr(trimmedContent, 0, 1) != "{")
   {
      Print("NEWS FILTER WARNING: Response is not a JSON object!");
      if(g_newsEventCount > 0)
      {
         g_usingCachedNews = true;
      }
      return;
   }
   
   string successValue = ExtractJSONValue(jsonContent, "success");
   if(successValue != "true")
   {
      string errorMsg = ExtractJSONValue(jsonContent, "error");
      Print("NEWS FILTER ERROR: API returned error: ", errorMsg);
      if(g_newsEventCount > 0)
      {
         g_usingCachedNews = true;
      }
      return;
   }
   
   NewsEvent tmpEvents[];
   int tmpEventCount = 0;
   ArrayResize(tmpEvents, 100);
   
   int dataStart = StringFind(jsonContent, "\"data\":", 0);
   if(dataStart < 0)
   {
      Print("NEWS FILTER WARNING: No data array found in response!");
      if(g_newsEventCount > 0)
      {
         g_usingCachedNews = true;
      }
      return;
   }
   
   int arrayStart = StringFind(jsonContent, "[", dataStart);
   if(arrayStart < 0)
   {
      Print("NEWS FILTER WARNING: Data array not found!");
      if(g_newsEventCount > 0)
      {
         g_usingCachedNews = true;
      }
      return;
   }
   
   int searchPos = arrayStart + 1;
   int eventCount = 0;
   
   int firstBrace = StringFind(jsonContent, "{", searchPos);
   if(firstBrace < 0)
   {
      Print("NEWS FILTER: No news events for current filters (empty data array)");
      g_lastNewsRefresh = currentTime;
      
      if(g_newsEventCount > 0)
      {
         g_usingCachedNews = true;
         Print("NEWS FILTER: Keeping cached data (", g_newsEventCount, " events)");
      }
      else
      {
         g_usingCachedNews = false;
      }
      return;
   }
   
   searchPos = firstBrace;
   
   while(searchPos < StringLen(jsonContent))
   {
      int braceDepth = 0;
      int objStart = searchPos;
      int objEnd = -1;
      
      for(int i = searchPos; i < StringLen(jsonContent); i++)
      {
         string c = StringSubstr(jsonContent, i, 1);
         if(c == "{") braceDepth++;
         else if(c == "}")
         {
            braceDepth--;
            if(braceDepth == 0)
            {
               objEnd = i;
               break;
            }
         }
         else if(c == "]" && braceDepth == 0)
         {
            break;
         }
      }
      
      if(objEnd < 0) break;
      
      string eventJson = StringSubstr(jsonContent, objStart, objEnd - objStart + 1);
      
      string title = ExtractJSONValue(eventJson, "title");
      string currency = ExtractJSONValue(eventJson, "currency");
      string timestampStr = ExtractJSONValue(eventJson, "timestamp");
      string impact = ExtractJSONValue(eventJson, "impact");
      
      eventCount++;
      
       datetime eventTime = (datetime)StringToInteger(timestampStr);
       
       // Convert UTC timestamp to broker server time (same as MoneyX Smart System)
       int serverGMTOffset = (int)(TimeCurrent() - TimeGMT());
       eventTime += serverGMTOffset;
       
       {
          static bool tzDebugPrinted = false;
          if(!tzDebugPrinted)
          {
             Print("NEWS FILTER TZ: Server GMT offset = ", serverGMTOffset/3600, "h");
             tzDebugPrinted = true;
          }
       }
      
      if(impact == "Holiday")
      {
         searchPos = objEnd + 1;
         continue;
      }
      
      bool isRelevant = false;
      
      if(IsCurrencyRelevant(currency))
      {
         if(InpFilterHighNews && impact == "High")
            isRelevant = true;
         else if(InpFilterMedNews && impact == "Medium")
            isRelevant = true;
         else if(InpFilterLowNews && impact == "Low")
            isRelevant = true;
         
         if(IsCustomNewsMatch(title))
            isRelevant = true;
      }
      
      if(tmpEventCount < ArraySize(tmpEvents))
      {
         tmpEvents[tmpEventCount].title = title;
         tmpEvents[tmpEventCount].country = currency;
         tmpEvents[tmpEventCount].time = eventTime;
         tmpEvents[tmpEventCount].impact = impact;
         tmpEvents[tmpEventCount].isRelevant = isRelevant;
         tmpEventCount++;
      }
      
      searchPos = objEnd + 1;
   }
   
   Print("NEWS FILTER: Parsed ", eventCount, " total events, stored ", tmpEventCount, " events");
   
   if(tmpEventCount > 0)
   {
      ArrayResize(g_newsEvents, tmpEventCount);
      for(int i = 0; i < tmpEventCount; i++)
      {
         g_newsEvents[i] = tmpEvents[i];
      }
      g_newsEventCount = tmpEventCount;
      
      g_lastNewsRefresh = currentTime;
      g_lastGoodNewsTime = currentTime;
      g_usingCachedNews = false;
      
      Print("NEWS FILTER: Successfully loaded ", g_newsEventCount, " events (FRESH DATA)");
      
      SaveNewsCacheToFile();
   }
   else
   {
      Print("NEWS FILTER: API returned 0 events (no relevant news for current filters)");
      g_lastNewsRefresh = currentTime;
      if(g_newsEventCount > 0)
      {
         g_usingCachedNews = true;
      }
      else
      {
         g_usingCachedNews = false;
      }
   }
}

//+------------------------------------------------------------------+
//| Save News Cache to File for Persistence                            |
//+------------------------------------------------------------------+
void SaveNewsCacheToFile()
{
   if(g_newsEventCount == 0)
      return;
   
   int handle = FileOpen(g_newsCacheFile, FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(handle == INVALID_HANDLE)
   {
      Print("NEWS FILTER: Cannot save cache file - ", GetLastError());
      return;
   }
   
   FileWriteString(handle, "# GoldMiner News Cache - " + TimeToString(TimeCurrent()) + "\n");
   FileWriteString(handle, "# Count: " + IntegerToString(g_newsEventCount) + "\n");
   
   for(int i = 0; i < g_newsEventCount; i++)
   {
      string line = g_newsEvents[i].title + "|" + 
                    g_newsEvents[i].country + "|" +
                    IntegerToString((long)g_newsEvents[i].time) + "|" +
                    g_newsEvents[i].impact + "|" +
                    (g_newsEvents[i].isRelevant ? "1" : "0") + "\n";
      FileWriteString(handle, line);
   }
   
   FileClose(handle);
   g_lastFileCacheSave = TimeCurrent();
   Print("NEWS FILTER: Saved ", g_newsEventCount, " events to cache file");
}

//+------------------------------------------------------------------+
//| Load News Cache from File                                          |
//+------------------------------------------------------------------+
void LoadNewsCacheFromFile()
{
   if(!FileIsExist(g_newsCacheFile))
   {
      Print("NEWS FILTER: No cache file found (first run)");
      return;
   }
   
   int handle = FileOpen(g_newsCacheFile, FILE_READ | FILE_TXT | FILE_ANSI);
   if(handle == INVALID_HANDLE)
   {
      Print("NEWS FILTER: Cannot read cache file - ", GetLastError());
      return;
   }
   
   ArrayResize(g_newsEvents, 100);
   g_newsEventCount = 0;
   
   while(!FileIsEnding(handle))
   {
      string line = FileReadString(handle);
      
      if(StringSubstr(line, 0, 1) == "#")
         continue;
      
      string parts[];
      int partCount = StringSplit(line, '|', parts);
      
      if(partCount >= 5 && g_newsEventCount < ArraySize(g_newsEvents))
      {
         g_newsEvents[g_newsEventCount].title = parts[0];
         g_newsEvents[g_newsEventCount].country = parts[1];
         g_newsEvents[g_newsEventCount].time = (datetime)StringToInteger(parts[2]);
         g_newsEvents[g_newsEventCount].impact = parts[3];
         g_newsEvents[g_newsEventCount].isRelevant = (parts[4] == "1");
         g_newsEventCount++;
      }
   }
   
   FileClose(handle);
   
   if(g_newsEventCount > 0)
   {
      g_usingCachedNews = true;
      Print("NEWS FILTER: Loaded ", g_newsEventCount, " events from cache file");
   }
}

//+------------------------------------------------------------------+
//| Get Pause Duration for News Impact Level                           |
//+------------------------------------------------------------------+
void GetNewsPauseDuration(string impact, bool isCustomMatch, int &beforeMin, int &afterMin)
{
   beforeMin = 0;
   afterMin = 0;
   
   int customBefore = 0, customAfter = 0;
   int impactBefore = 0, impactAfter = 0;
   
   if(isCustomMatch && InpFilterCustomNews)
   {
      customBefore = InpPauseBeforeCustom;
      customAfter = InpPauseAfterCustom;
   }
   
   if(impact == "High" && InpFilterHighNews)
   {
      impactBefore = InpPauseBeforeHigh;
      impactAfter = InpPauseAfterHigh;
   }
   else if(impact == "Medium" && InpFilterMedNews)
   {
      impactBefore = InpPauseBeforeMed;
      impactAfter = InpPauseAfterMed;
   }
   else if(impact == "Low" && InpFilterLowNews)
   {
      impactBefore = InpPauseBeforeLow;
      impactAfter = InpPauseAfterLow;
   }
   
   int customTotal = customBefore + customAfter;
   int impactTotal = impactBefore + impactAfter;
   
   if(customTotal >= impactTotal && customTotal > 0)
   {
      beforeMin = customBefore;
      afterMin = customAfter;
   }
   else if(impactTotal > 0)
   {
      beforeMin = impactBefore;
      afterMin = impactAfter;
   }
}

//+------------------------------------------------------------------+
//| Check whether an event is relevant using CURRENT filter settings   |
//+------------------------------------------------------------------+
bool IsEventRelevantNow(const NewsEvent &ev)
{
   if(!IsCurrencyRelevant(ev.country))
      return false;

   if(InpFilterCustomNews && IsCustomNewsMatch(ev.title))
      return true;

   if(InpFilterHighNews && ev.impact == "High")
      return true;

   if(InpFilterMedNews && ev.impact == "Medium")
      return true;

   if(InpFilterLowNews && ev.impact == "Low")
      return true;

   return false;
}

//+------------------------------------------------------------------+
//| Check if Currently in News Pause Window                            |
//+------------------------------------------------------------------+
bool IsNewsTimePaused()
{
   if(!InpEnableNewsFilter)
   {
      g_isNewsPaused = false;
      g_newsStatus = "OFF";
      if(g_lastPausedState)
      {
         g_lastPausedState = false;
         g_lastPauseKey = "";
      }
      return false;
   }
   
   datetime currentTime = TimeCurrent();
   
   bool foundPause = false;
   string pauseKey = "";
   g_nextNewsTitle = "";
   g_nextNewsTime = 0;
   
   datetime closestNewsTime = 0;
   string closestNewsTitle = "";
   int closestBeforeMin = 0;
   int closestAfterMin = 0;
   
   datetime earliestPauseEnd = 0;
   string earliestNewsTitle = "";
   datetime earliestNewsTime = 0;
   string earliestCountry = "";
   string earliestImpact = "";
   
   for(int i = 0; i < g_newsEventCount; i++)
   {
      if(!IsEventRelevantNow(g_newsEvents[i]))
         continue;

      datetime newsTime = g_newsEvents[i].time;
      string impact = g_newsEvents[i].impact;
      bool isCustom = IsCustomNewsMatch(g_newsEvents[i].title);
      
      int beforeMin, afterMin;
      GetNewsPauseDuration(impact, isCustom, beforeMin, afterMin);
      
      if(beforeMin == 0 && afterMin == 0)
         continue;
      
      datetime pauseStart = newsTime - beforeMin * 60;
      datetime pauseEnd = newsTime + afterMin * 60;
      
      if(currentTime >= pauseStart && currentTime <= pauseEnd)
      {
         if(!foundPause || pauseEnd < earliestPauseEnd)
         {
            foundPause = true;
            earliestPauseEnd = pauseEnd;
            earliestNewsTitle = g_newsEvents[i].title;
            earliestNewsTime = newsTime;
            earliestCountry = g_newsEvents[i].country;
            earliestImpact = impact;
         }
      }
      
      if(newsTime > currentTime && (closestNewsTime == 0 || newsTime < closestNewsTime))
      {
         datetime futureStart = newsTime - beforeMin * 60;
         if(currentTime < futureStart)
         {
            closestNewsTime = newsTime;
            closestNewsTitle = g_newsEvents[i].title;
            closestBeforeMin = beforeMin;
            closestAfterMin = afterMin;
         }
      }
   }
   
   if(foundPause)
   {
      g_nextNewsTitle = earliestNewsTitle;
      g_nextNewsTime = earliestNewsTime;
      g_newsPauseEndTime = earliestPauseEnd;
      pauseKey = earliestNewsTitle + "|" + IntegerToString((long)earliestNewsTime);
      
      if(currentTime < earliestNewsTime)
      {
         int minsLeft = (int)((earliestNewsTime - currentTime) / 60);
         g_newsStatus = "PAUSE: " + earliestCountry + " " + earliestImpact + " in " + IntegerToString(minsLeft) + "m";
      }
      else
      {
         int minsAfter = (int)((currentTime - earliestNewsTime) / 60);
         g_newsStatus = "PAUSE: " + earliestCountry + " " + earliestImpact + " +" + IntegerToString(minsAfter) + "m ago";
      }
   }
   
   if(foundPause)
   {
      g_isNewsPaused = true;
      
      if(!g_lastPausedState || g_lastPauseKey != pauseKey)
      {
         Print("NEWS FILTER: Trading PAUSED - ", g_newsStatus, " | Event: ", g_nextNewsTitle);
         g_lastPausedState = true;
         g_lastPauseKey = pauseKey;
      }
      return true;
   }
   else
   {
      g_isNewsPaused = false;
      g_newsPauseEndTime = 0;
      
      if(g_lastPausedState)
      {
         Print("NEWS FILTER: Trading RESUMED - News pause window ended");
         g_lastPausedState = false;
         g_lastPauseKey = "";
      }
      
      if(closestNewsTime > 0 && (closestNewsTime - currentTime) <= 2 * 3600)
      {
         g_nextNewsTitle = closestNewsTitle;
         g_nextNewsTime = closestNewsTime;
      }
      
      g_newsStatus = "No Important news";
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Get Countdown String for News Pause                                |
//+------------------------------------------------------------------+
string GetNewsCountdownString()
{
   if(!g_isNewsPaused || g_newsPauseEndTime == 0)
      return "";
   
   datetime currentTime = TimeCurrent();
   
   if(currentTime >= g_newsPauseEndTime)
      return "00:00:00";
   
   int remainingSeconds = (int)(g_newsPauseEndTime - currentTime);
   
   int hours = remainingSeconds / 3600;
   int minutes = (remainingSeconds % 3600) / 60;
   int seconds = remainingSeconds % 60;
   
   string hh = (hours < 10 ? "0" : "") + IntegerToString(hours);
   string mm = (minutes < 10 ? "0" : "") + IntegerToString(minutes);
   string ss = (seconds < 10 ? "0" : "") + IntegerToString(seconds);
   
   return hh + ":" + mm + ":" + ss;
}

//+------------------------------------------------------------------+
//| ============== TIME FILTER MODULE (from v5.34) ================= |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Parse time string "hh:mm" to minutes from midnight               |
//+------------------------------------------------------------------+
int ParseTimeToMinutes(string timeStr)
{
   if(StringLen(timeStr) < 5) return -1;
   
   int colonPos = StringFind(timeStr, ":");
   if(colonPos < 0) return -1;
   
   string hourStr = StringSubstr(timeStr, 0, colonPos);
   string minStr = StringSubstr(timeStr, colonPos + 1, 2);
   
   int hour = (int)StringToInteger(hourStr);
   int min = (int)StringToInteger(minStr);
   
   if(hour < 0 || hour > 23 || min < 0 || min > 59) return -1;
   
   return hour * 60 + min;
}

//+------------------------------------------------------------------+
//| Parse session string "hh:mm-hh:mm" and check if time is in range |
//+------------------------------------------------------------------+
bool IsTimeInSession(string session, int currentMinutes)
{
   if(StringLen(session) < 11) return false;
   
   int dashPos = StringFind(session, "-");
   if(dashPos < 0) return false;
   
   string startStr = StringSubstr(session, 0, dashPos);
   string endStr = StringSubstr(session, dashPos + 1);
   
   int startMinutes = ParseTimeToMinutes(startStr);
   int endMinutes = ParseTimeToMinutes(endStr);
   
   if(startMinutes < 0 || endMinutes < 0) return false;
   
   if(startMinutes <= endMinutes)
   {
      return (currentMinutes >= startMinutes && currentMinutes < endMinutes);
   }
   else
   {
      return (currentMinutes >= startMinutes || currentMinutes < endMinutes);
   }
}

//+------------------------------------------------------------------+
//| Check if current day is allowed for trading                       |
//+------------------------------------------------------------------+
bool IsTradableDay(int dayOfWeek)
{
   switch(dayOfWeek)
   {
      case 0: return InpTradeSunday;
      case 1: return InpTradeMonday;
      case 2: return InpTradeTuesday;
      case 3: return InpTradeWednesday;
      case 4: return InpTradeThursday;
      case 5: return InpTradeFriday;
      case 6: return InpTradeSaturday;
      default: return false;
   }
}

//+------------------------------------------------------------------+
//| Check if within trading hours                                      |
//+------------------------------------------------------------------+
bool IsWithinTradingHours()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   
   if(!IsTradableDay(dt.day_of_week))
      return false;
   
   int currentMinutes = dt.hour * 60 + dt.min;
   
   bool isFriday = (dt.day_of_week == 5);
   
   if(isFriday)
   {
      bool hasFridaySessions = (StringLen(InpFridaySession1) >= 5 || 
                                 StringLen(InpFridaySession2) >= 5 || 
                                 StringLen(InpFridaySession3) >= 5);
      
      if(hasFridaySessions)
      {
         if(StringLen(InpFridaySession1) >= 5 && IsTimeInSession(InpFridaySession1, currentMinutes))
            return true;
         if(StringLen(InpFridaySession2) >= 5 && IsTimeInSession(InpFridaySession2, currentMinutes))
            return true;
         if(StringLen(InpFridaySession3) >= 5 && IsTimeInSession(InpFridaySession3, currentMinutes))
            return true;
            
         return false;
      }
   }
   
   if(StringLen(InpSession1) >= 5 && IsTimeInSession(InpSession1, currentMinutes))
      return true;
   if(StringLen(InpSession2) >= 5 && IsTimeInSession(InpSession2, currentMinutes))
      return true;
   if(StringLen(InpSession3) >= 5 && IsTimeInSession(InpSession3, currentMinutes))
      return true;
   
   if(StringLen(InpSession1) < 5 && StringLen(InpSession2) < 5 && StringLen(InpSession3) < 5)
      return true;
   
   return false;
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| ============== CHART EVENT HANDLER (v2.9) ====================== |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam == "GM_BtnPause")
      {
         g_eaIsPaused = !g_eaIsPaused;
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         Print("EA ", g_eaIsPaused ? "PAUSED" : "RESUMED", " by user");
      }
      else if(sparam == "GM_BtnCloseBuy")
      {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         int result = MessageBox("Close all BUY orders?", "Confirm Close Buy", MB_YESNO | MB_ICONWARNING);
         if(result == IDYES)
            CloseAllPositionsByType(POSITION_TYPE_BUY);
      }
      else if(sparam == "GM_BtnCloseSell")
      {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         int result = MessageBox("Close all SELL orders?", "Confirm Close Sell", MB_YESNO | MB_ICONWARNING);
         if(result == IDYES)
            CloseAllPositionsByType(POSITION_TYPE_SELL);
      }
      else if(sparam == "GM_BtnCloseAll")
      {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         int result = MessageBox("Close ALL orders?", "Confirm Close All", MB_YESNO | MB_ICONWARNING);
         if(result == IDYES)
         {
            CloseAllPositionsByType(POSITION_TYPE_BUY);
            CloseAllPositionsByType(POSITION_TYPE_SELL);
         }
      }
      else if(sparam == "GM_BtnResumeDaily")
      {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         int result = MessageBox(
            "Resume trading for today?\nDaily profit target was reached.",
            "Confirm Resume", MB_YESNO | MB_ICONQUESTION);
         if(result == IDYES)
         {
            g_dailyProfitPaused = false;
            Print("DAILY PROFIT PAUSE: Manually resumed by user.");
         }
      }
      ChartRedraw(0);
   }
}

//+------------------------------------------------------------------+
//| Close all positions by type (BUY or SELL) - v2.9                   |
//+------------------------------------------------------------------+
void CloseAllPositionsByType(ENUM_POSITION_TYPE posType)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) != posType) continue;
      
      trade.PositionClose(ticket);
   }
   
   string typeStr = (posType == POSITION_TYPE_BUY) ? "BUY" : "SELL";
   Print("Closed all ", typeStr, " positions by user command");
}

//+------------------------------------------------------------------+
//| Dashboard Helper: Create Button (v2.9)                             |
//+------------------------------------------------------------------+
void CreateDashButton(string name, int x, int y, int width, int height, string text, color bgColor, color textColor)
{
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgColor);
   ObjectSetInteger(0, name, OBJPROP_COLOR, textColor);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| ============== COUNTER-TREND HEDGING MODULE (v5.2) ============= |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check if a comment belongs to a hedge order                        |
//+------------------------------------------------------------------+
bool IsReverseHedgeComment(string comment)
{
   return (StringFind(comment, "GM_RHEDGE") >= 0);
}

bool IsHedgeComment(string comment)
{
   // v6.62: also recognise new "GM_Hedge_E{gen}" / "GM_Hedge_D{gen}" comments
   return (StringFind(comment, "GM_Hedge_") >= 0
        || StringFind(comment, "GM_HEDGE") >= 0
        || StringFind(comment, "GM_HG") >= 0
        || IsReverseHedgeComment(comment));
}

//+------------------------------------------------------------------+
//| Count normal (non-hedge) orders for a specific side                |
//+------------------------------------------------------------------+
int CountNormalOrders(ENUM_POSITION_TYPE side, double &totalLots, double &totalPL)
{
   int count = 0;
   totalLots = 0;
   totalPL = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != side) continue;
      string comment = PositionGetString(POSITION_COMMENT);
      if(IsHedgeComment(comment)) continue;
      count++;
      totalLots += PositionGetDouble(POSITION_VOLUME);
      totalPL += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return count;
}

//+------------------------------------------------------------------+
//| Check if a ticket is bound to ANY active hedge set                 |
//+------------------------------------------------------------------+
bool IsTicketBound(ulong ticket)
{
   for(int h = 0; h < MAX_HEDGE_SETS; h++)
   {
      if(!g_hedgeSets[h].active) continue;
      for(int b = 0; b < g_hedgeSets[h].boundTicketCount; b++)
      {
         if(g_hedgeSets[h].boundTickets[b] == ticket)
            return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| v6.26: Add ticket to previously-hedged list                        |
//+------------------------------------------------------------------+
void AddPrevHedgedTicket(ulong ticket)
{
   if(IsPrevHedgedTicket(ticket)) return;
   if(g_prevHedgedCount >= MAX_PREV_HEDGED)
   {
      Print("WARNING: g_prevHedgedTickets array full (", MAX_PREV_HEDGED, "). Cannot add ticket ", ticket);
      return;
   }
   g_prevHedgedTickets[g_prevHedgedCount] = ticket;
   g_prevHedgedCount++;
}

//+------------------------------------------------------------------+
//| v6.26: Check if ticket was previously in a DD hedge set             |
//+------------------------------------------------------------------+
bool IsPrevHedgedTicket(ulong ticket)
{
   for(int i = 0; i < g_prevHedgedCount; i++)
   {
      if(g_prevHedgedTickets[i] == ticket) return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| v6.26: Clear previously-hedged tickets (full cycle reset)          |
//+------------------------------------------------------------------+
void ClearPrevHedgedTickets()
{
   ArrayInitialize(g_prevHedgedTickets, 0);
   g_prevHedgedCount = 0;
   Print("v6.26: Previously-hedged tickets cleared (cycle reset)");
}

//+------------------------------------------------------------------+
//| v6.26: Save remaining bound tickets to prevHedged before deactivation |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| v6.59: Sequential Recovery Owner — exclusive recovery lock         |
//+------------------------------------------------------------------+
bool HasSequentialRecoveryOwner()
{
   return g_sequentialRecoveryActive;
}

bool IsSequentialRecoveryGen(int gen)
{
   if(!g_sequentialRecoveryActive) return false;
   return (g_sequentialRecoveryGen == gen);
}

// Count remaining EA positions of a given generation (any side, including bound/recovery)
int CountAllGenPositions(int gen)
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      string comment = PositionGetString(POSITION_COMMENT);
      int orderGen = ExtractGeneration(comment);
      if(orderGen == gen) count++;
   }
   return count;
}

// v6.60/v6.62: Strict owner counter — counts ONLY normal recovery orders for a specific generation
// Excludes hedge-family comments. v6.62: gen=0 = legacy "GM_" (back-compat); gen>=1 = "GM{gen}_".
int CountSequentialOwnerOrders(int gen)
{
   if(gen < 0) return 0;
   string genPrefix = (gen == 0) ? "GM_" : ("GM" + IntegerToString(gen) + "_");
   int prefixLen = StringLen(genPrefix);
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      string comment = PositionGetString(POSITION_COMMENT);
      // Must start exactly with this generation's prefix (e.g. "GM1_" not "GM10_")
      if(StringFind(comment, genPrefix) != 0) continue;
      // Exclude hedge-family comments — those belong to hedge sets, not recovery owner
      string suffix = StringSubstr(comment, prefixLen);
      if(StringFind(suffix, "HEDGE") == 0) continue;   // legacy GM_HEDGE_*
      if(StringFind(suffix, "Hedge") == 0) continue;   // v6.62 GM_Hedge_*
      if(StringFind(suffix, "HG") == 0) continue;      // GM_HG*
      if(StringFind(suffix, "RHEDGE") == 0) continue;  // GM_RHEDGE*
      count++;
   }
   return count;
}

bool IsSequentialRecoveryComplete()
{
   if(!g_sequentialRecoveryActive) return true;
   int gen = g_sequentialRecoveryGen;
   // v6.61: must be flat by BOTH strict prefix count AND recovery seed/tracker
   if(CountSequentialOwnerOrders(gen) > 0) return false;
   // Check any recovery seeds for this gen still alive
   for(int s = 0; s < g_recoverySeedCount; s++)
   {
      if(g_recoverySeedGen[s] == gen && PositionSelectByTicket(g_recoverySeedTickets[s]))
         return false;
   }
   // Check tracker tickets
   if(!IsRecoverySetFlat(gen)) return false;
   return true;
}

void SetSequentialRecoveryOwner(int hedgeSetIdx, int gen)
{
   if(!InpHedge_SequentialRecovery) return;
   if(g_sequentialRecoveryActive) return;  // do not override existing owner
   if(gen < 0) return;  // v6.60: allow Gen0 (GM) to claim ownership
   // v6.60: only lock if the released set still has normal recovery orders open
   // v6.61: also count recovery seeds belonging to this gen
   int remain = CountSequentialOwnerOrders(gen);
   int seedRemain = 0;
   for(int s = 0; s < g_recoverySeedCount; s++)
      if(g_recoverySeedGen[s] == gen && PositionSelectByTicket(g_recoverySeedTickets[s]))
         seedRemain++;
   if(remain + seedRemain == 0)
   {
      Print("v6.61 SEQ OWNER SKIP: Gen", gen, " has 0 released recovery orders (Set#", hedgeSetIdx + 1, ")");
      // v6.69: ถึงจะไม่มี owner ก็ต้องหน่วงไม่ให้ set ถัดไปปลดทันที
      ArmSequentialUnlockDelay(hedgeSetIdx, "set closed clean (no owner)");
      return;
   }
   g_sequentialRecoveryGen    = gen;
   g_sequentialRecoverySetIdx = hedgeSetIdx;
   g_sequentialRecoveryActive = true;
   Print("v6.60 SEQ OWNER: Gen", gen, " claimed from Set#", hedgeSetIdx + 1,
         " | ", remain, " recovery order(s) — other hedge sets blocked until flat");
   // v6.69: arm delay เผื่อกรณี owner clear แล้วจะถูกต่ออายุ — และกัน set ถัดไปไม่ให้แทรกระหว่าง owner active
   ArmSequentialUnlockDelay(hedgeSetIdx, "owner Gen" + IntegerToString(gen) + " claimed");
}

void ClearSequentialRecoveryOwner(string reason)
{
   if(!g_sequentialRecoveryActive) return;
   Print("v6.60 SEQ COMPLETE: Gen", g_sequentialRecoveryGen,
          " flat (", reason, ") -> unlock next set next tick");
   g_sequentialRecoveryGen    = -1;
   g_sequentialRecoverySetIdx = -1;
   g_sequentialRecoveryActive = false;
   g_sequentialRecoveryCompletedThisTick = true;  // skip releasing next set this tick
   // v6.69: also arm time-based delay so next set ไม่ถูกปลดทันทีหลัง owner เพิ่ง flat
   ArmSequentialUnlockDelay(g_sequentialRecoverySetIdx, "owner cleared: " + reason);
}

//+------------------------------------------------------------------+
//| v6.69: Sequential Unlock Delay helpers                            |
//+------------------------------------------------------------------+
void ArmSequentialUnlockDelay(int sourceSetIdx, string reason)
{
   if(InpHedge_SequentialUnlockDelayMin <= 0) return;  // disabled
   datetime newUntil = TimeCurrent() + (datetime)(InpHedge_SequentialUnlockDelayMin * 60);
   // ถ้ามี cooldown ค้างอยู่แล้วและยาวกว่า ใหม่ → คงของเดิมไว้
   if(newUntil > g_sequentialUnlockBlockedUntil)
   {
      g_sequentialUnlockBlockedUntil = newUntil;
      g_sequentialUnlockSourceSetIdx = sourceSetIdx;
      g_sequentialUnlockReason       = reason;
      Print("v6.69 SEQ DELAY ARM: src=Set#", sourceSetIdx + 1,
            " | wait ", InpHedge_SequentialUnlockDelayMin, " min (", reason, ")");
   }
}

bool IsSequentialUnlockDelayActive()
{
   if(InpHedge_SequentialUnlockDelayMin <= 0) return false;
   if(g_sequentialUnlockBlockedUntil <= 0) return false;
   return (TimeCurrent() < g_sequentialUnlockBlockedUntil);
}

int GetSequentialUnlockRemainSec()
{
   if(!IsSequentialUnlockDelayActive()) return 0;
   return (int)(g_sequentialUnlockBlockedUntil - TimeCurrent());
}

//+------------------------------------------------------------------+
//| v6.61: Recovery Seed registry (logical strip of hedge comment)    |
//+------------------------------------------------------------------+
bool IsRecoverySeedTicket(ulong ticket)
{
   for(int i = 0; i < g_recoverySeedCount; i++)
      if(g_recoverySeedTickets[i] == ticket) return true;
   return false;
}

int GetRecoverySeedGen(ulong ticket)
{
   for(int i = 0; i < g_recoverySeedCount; i++)
      if(g_recoverySeedTickets[i] == ticket) return g_recoverySeedGen[i];
   return -1;
}

void RegisterRecoverySeed(ulong ticket, int gen, double openPrice)
{
   if(ticket == 0 || gen < 0) return;
   if(IsRecoverySeedTicket(ticket)) return;
   ArrayResize(g_recoverySeedTickets, g_recoverySeedCount + 1);
   ArrayResize(g_recoverySeedGen,     g_recoverySeedCount + 1);
   ArrayResize(g_recoverySeedOpenPrice, g_recoverySeedCount + 1);
   g_recoverySeedTickets[g_recoverySeedCount]    = ticket;
   g_recoverySeedGen[g_recoverySeedCount]        = gen;
   g_recoverySeedOpenPrice[g_recoverySeedCount]  = openPrice;
   g_recoverySeedCount++;
   Print("v6.61 RECOV SEED: ticket=", ticket, " gen=", gen, " open=", DoubleToString(openPrice, _Digits));
}

void PruneRecoverySeeds()
{
   // remove tickets that no longer exist
   for(int i = g_recoverySeedCount - 1; i >= 0; i--)
   {
      if(!PositionSelectByTicket(g_recoverySeedTickets[i]))
      {
         for(int j = i; j < g_recoverySeedCount - 1; j++)
         {
            g_recoverySeedTickets[j]   = g_recoverySeedTickets[j + 1];
            g_recoverySeedGen[j]       = g_recoverySeedGen[j + 1];
            g_recoverySeedOpenPrice[j] = g_recoverySeedOpenPrice[j + 1];
         }
         g_recoverySeedCount--;
         ArrayResize(g_recoverySeedTickets, g_recoverySeedCount);
         ArrayResize(g_recoverySeedGen, g_recoverySeedCount);
         ArrayResize(g_recoverySeedOpenPrice, g_recoverySeedCount);
      }
   }
}

//+------------------------------------------------------------------+
//| v6.61: Unified Recovery Owner Avg TP                              |
//| When the sequential-recovery owner generation reaches its weighted|
//| average TP (recovery seed + remaining bound losers + recovery     |
//| grid orders), close the entire basket and clear the owner.        |
//+------------------------------------------------------------------+
void ManageRecoveryOwnerAvgTP()
{
   if(InpHedge_BoundAvgTPPoints <= 0) return;
   if(!g_sequentialRecoveryActive) return;
   int gen = g_sequentialRecoveryGen;
   if(gen < 0) return;

   string prefix = GenPrefix(gen);

   // v6.64: per-side cache for change detection — only sync TP when basket changes
   //        (count, lots, gen, or avg price differs from last tick). This stops the
   //        ping-pong with ClearBrokerTPSL and stops journal log spam.
   static int    s_lastBasketCount[2] = {0, 0};
   static double s_lastBasketLots[2]  = {0.0, 0.0};
   static double s_lastAvgPrice[2]    = {0.0, 0.0};
   static int    s_lastGen[2]         = {-1, -1};

   // Build basket per side: include normal gen orders + recovery seeds for this gen
   for(int sideI = 0; sideI < 2; sideI++)
   {
      ENUM_POSITION_TYPE side = (sideI == 0) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
      double totalWeighted = 0;
      double totalLots = 0;
      ulong  basketTickets[];
      int    basketCount = 0;

      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if(PositionGetInteger(POSITION_TYPE) != side) continue;

         string comment = PositionGetString(POSITION_COMMENT);
         bool isSeed = IsRecoverySeedTicket(ticket);
         bool isOwnerOrder = false;

         if(isSeed && GetRecoverySeedGen(ticket) == gen)
            isOwnerOrder = true;
         else if(StringFind(comment, prefix + "_") == 0 && !IsHedgeComment(comment))
            isOwnerOrder = true;

         if(!isOwnerOrder) continue;

         double lots = PositionGetDouble(POSITION_VOLUME);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         totalWeighted += lots * openPrice;
         totalLots     += lots;
         ArrayResize(basketTickets, basketCount + 1);
         basketTickets[basketCount++] = ticket;
      }

      if(totalLots <= 0 || basketCount == 0)
      {
         // basket empty for this side — reset cache so next time it appears we sync fresh
         s_lastBasketCount[sideI] = 0;
         s_lastBasketLots[sideI]  = 0.0;
         s_lastAvgPrice[sideI]    = 0.0;
         s_lastGen[sideI]         = -1;
         continue;
      }

      double avgPrice  = totalWeighted / totalLots;
      double tpDist    = InpHedge_BoundAvgTPPoints * _Point;
      double tpPrice   = (side == POSITION_TYPE_BUY)
                         ? NormalizeDouble(avgPrice + tpDist, _Digits)
                         : NormalizeDouble(avgPrice - tpDist, _Digits);
      bool   tpReached = false;
      if(side == POSITION_TYPE_BUY)
         tpReached = (SymbolInfoDouble(_Symbol, SYMBOL_BID) >= avgPrice + tpDist);
      else
         tpReached = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) <= avgPrice - tpDist);

      // v6.64: Only re-sync Broker TP when basket signature changes
      // (new GL added, order closed, gen change, or avg shifted by > 1 point).
      // Per user spec: "ควรจะแก้เมื่อมีออเดอร์ Generation เดียวกันเพิ่มขึ้นมาใหม่
      //                 ไม่ใช่จะต้องรีเซ็ตตลอดเวลาแบบนี้"
      bool basketChanged = (basketCount != s_lastBasketCount[sideI])
                        || (MathAbs(totalLots - s_lastBasketLots[sideI]) > 0.001)
                        || (gen != s_lastGen[sideI])
                        || (MathAbs(avgPrice - s_lastAvgPrice[sideI]) > _Point);

      if(basketChanged)
      {
         int syncedCnt = 0;
         for(int b = 0; b < basketCount; b++)
         {
            if(!PositionSelectByTicket(basketTickets[b])) continue;
            double curTP = PositionGetDouble(POSITION_TP);
            double curSL = PositionGetDouble(POSITION_SL);
            if(NormalizeDouble(curTP, _Digits) != tpPrice)
            {
               if(trade.PositionModify(basketTickets[b], curSL, tpPrice))
                  syncedCnt++;
            }
         }
         Print("v6.64 RECOV TP RECALC: Gen", gen, " side=", EnumToString(side),
               " basket=", basketCount, " lots=", DoubleToString(totalLots, 2),
               " avg=", DoubleToString(avgPrice, _Digits),
               " TP=", DoubleToString(tpPrice, _Digits),
               " synced=", syncedCnt);
         s_lastBasketCount[sideI] = basketCount;
         s_lastBasketLots[sideI]  = totalLots;
         s_lastAvgPrice[sideI]    = avgPrice;
         s_lastGen[sideI]         = gen;
      }

      if(!tpReached) continue;

      Print("v6.61 RECOV AVG TP: Gen", gen, " side=", EnumToString(side),
            " avg=", DoubleToString(avgPrice, _Digits),
            " target=", InpHedge_BoundAvgTPPoints, "pts REACHED → closing ", basketCount, " orders");

      for(int b = 0; b < basketCount; b++)
      {
         if(PositionSelectByTicket(basketTickets[b]))
         {
            trade.PositionClose(basketTickets[b]);
            Sleep(30);
         }
      }
      // basket about to be cleared — reset cache
      s_lastBasketCount[sideI] = 0;
      s_lastBasketLots[sideI]  = 0.0;
      s_lastAvgPrice[sideI]    = 0.0;
      s_lastGen[sideI]         = -1;
   }
}

//+------------------------------------------------------------------+
//| v6.63: Orphan GL Watchdog — alert when owner-gen orders have TP=0 |
//+------------------------------------------------------------------+
void AuditUnTPedOwnerOrders()
{
   if(!g_sequentialRecoveryActive) return;
   int gen = g_sequentialRecoveryGen;
   if(gen < 0) return;
   string prefix = GenPrefix(gen);
   static datetime s_lastAuditLog = 0;
   if(TimeCurrent() - s_lastAuditLog < 30) return;  // throttle 30s

   int orphanCnt = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      string c = PositionGetString(POSITION_COMMENT);
      if(IsHedgeComment(c)) continue;
      if(IsTicketBound(ticket)) continue;
      bool ownerOrder = false;
      if(IsRecoverySeedTicket(ticket) && GetRecoverySeedGen(ticket) == gen)
         ownerOrder = true;
      else if(StringFind(c, prefix + "_") == 0)
         ownerOrder = true;
      if(!ownerOrder) continue;
      if(PositionGetDouble(POSITION_TP) == 0)
         orphanCnt++;
   }
   // v6.64: print summary only (one line per audit cycle), not per-ticket spam
   if(orphanCnt > 0)
      Print("v6.64 ORPHAN GL: Gen", gen, " has ", orphanCnt,
            " owner orders with TP=0 → will sync on next basket change");
   if(orphanCnt > 0)
   {
      s_lastAuditLog = TimeCurrent();
      g_lastOrphanGLCount = orphanCnt;
   }
   else
   {
      g_lastOrphanGLCount = 0;
   }
}

//+------------------------------------------------------------------+
//| v6.65: Hedge Set Integrity Watchdog                              |
//| Detect hedge sets where hedgeLots >> bound orders (lot inflation) |
//| or sets with zero bound orders (orphan hedges)                    |
//+------------------------------------------------------------------+
void AuditHedgeSetIntegrity()
{
   static datetime s_lastIntegrityLog = 0;
   if(TimeCurrent() - s_lastIntegrityLog < 30) return;  // throttle 30s

   int warnCnt = 0, critCnt = 0;
   for(int h = 0; h < MAX_HEDGE_SETS; h++)
   {
      if(!g_hedgeSets[h].active) continue;

      // Refresh bound list (remove closed tickets)
      RefreshBoundTickets(h);

      double boundLotsActual = 0;
      for(int b = 0; b < g_hedgeSets[h].boundTicketCount; b++)
      {
         ulong tk = g_hedgeSets[h].boundTickets[b];
         if(!PositionSelectByTicket(tk)) continue;
         boundLotsActual += PositionGetDouble(POSITION_VOLUME);
      }

      double hLots = g_hedgeSets[h].hedgeLots;
      int gen = g_hedgeSets[h].boundGeneration;

      // CRITICAL: hedge open but no bound orders at all
      if(g_hedgeSets[h].boundTicketCount == 0 && hLots > 0)
      {
         critCnt++;
         Print("v6.65 HEDGE INTEGRITY CRITICAL: set#", h, " gen=", gen,
               " hedgeLots=", DoubleToString(hLots, 2),
               " has NO bound orders (orphan hedge — manual review required)");
         continue;
      }

      // WARN: hedge volume more than 2x of actual bound coverage
      if(boundLotsActual > 0 && hLots > boundLotsActual * 2.0)
      {
         warnCnt++;
         Print("v6.65 HEDGE INTEGRITY WARN: set#", h, " gen=", gen,
               " hedgeLots=", DoubleToString(hLots, 2),
               " >> boundLots=", DoubleToString(boundLotsActual, 2),
               " (>2x — possible lot inflation)");
      }
   }

   g_hedgeIntegrityWarnCount = warnCnt;
   g_hedgeIntegrityCriticalCount = critCnt;
   s_lastIntegrityLog = TimeCurrent();
}

//+------------------------------------------------------------------+
//| v6.61: RecoverySetTracker — anti-skip ticket array per generation |
//+------------------------------------------------------------------+
int FindRecoverySetIdx(int gen)
{
   // v6.63 FIX: previously hard-coded -1, breaking RecoverySetTracker entirely
   for(int i = 0; i < g_recoverySetCount; i++)
      if(g_recoverySets[i].generation == gen) return i;
   return -1;
}

void RegisterRecoverySetTickets(int gen, int sourceHedgeIdx, ulong &tickets[])
{
   if(gen < 0) return;
   int idx = FindRecoverySetIdx(gen);
   if(idx < 0)
   {
      ArrayResize(g_recoverySets, g_recoverySetCount + 1);
      idx = g_recoverySetCount;
      g_recoverySets[idx].generation     = gen;
      g_recoverySets[idx].sourceHedgeIdx = sourceHedgeIdx;
      g_recoverySets[idx].complete       = false;
      ArrayResize(g_recoverySets[idx].tickets, 0);
      g_recoverySetCount++;
   }
   for(int t = 0; t < ArraySize(tickets); t++)
   {
      if(tickets[t] == 0) continue;
      bool exists = false;
      int curSize = ArraySize(g_recoverySets[idx].tickets);
      for(int x = 0; x < curSize; x++)
         if(g_recoverySets[idx].tickets[x] == tickets[t]) { exists = true; break; }
      if(exists) continue;
      ArrayResize(g_recoverySets[idx].tickets, curSize + 1);
      g_recoverySets[idx].tickets[curSize] = tickets[t];
   }
   g_recoverySets[idx].complete = false;
}

bool IsRecoverySetFlat(int gen)
{
   int idx = FindRecoverySetIdx(gen);
   if(idx < 0) return true;
   for(int t = 0; t < ArraySize(g_recoverySets[idx].tickets); t++)
   {
      ulong tk = g_recoverySets[idx].tickets[t];
      if(tk == 0) continue;
      if(PositionSelectByTicket(tk)) return false;
   }
   // also include any new recovery grid orders for this gen still alive
   if(CountSequentialOwnerOrders(gen) > 0) return false;
   return true;
}

void ClearRecoverySetIfFlat(int gen)
{
   int idx = FindRecoverySetIdx(gen);
   if(idx < 0) return;
   if(!IsRecoverySetFlat(gen)) return;
   g_recoverySets[idx].complete = true;
}

//+------------------------------------------------------------------+
//| v6.61: Cumulative Sum Seed selection                              |
//| Sums lots of all orders (Initial + GLs + recovery seed) for gen   |
//| on `side`, then returns the level lot whose cumulative is closest |
//| to (but <=) targetLots. Falls back to max single lot if nothing.  |
//+------------------------------------------------------------------+
double FindCumulativeSeedLot(int gen, ENUM_POSITION_TYPE side, double targetLots)
{
   // Collect lots ordered by open time (oldest first) for this gen + side
   string prefix = GenPrefix(gen);
   double lots[];
   datetime times[];
   int cnt = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) != side) continue;

      string comment = PositionGetString(POSITION_COMMENT);
      bool include = false;
      // Normal gen orders (Initial / GL)
      if(StringFind(comment, prefix + "_") == 0 && !IsHedgeComment(comment))
      {
         if(StringFind(comment, "_INIT") >= 0 || StringFind(comment, "_GL") >= 0)
            include = true;
      }
      // Recovery seed (logically stripped hedge remainder)
      if(IsRecoverySeedTicket(ticket) && GetRecoverySeedGen(ticket) == gen)
         include = true;

      if(!include) continue;

      double lot = PositionGetDouble(POSITION_VOLUME);
      datetime t = (datetime)PositionGetInteger(POSITION_TIME);
      ArrayResize(lots, cnt + 1);
      ArrayResize(times, cnt + 1);
      lots[cnt] = lot;
      times[cnt] = t;
      cnt++;
   }
   if(cnt == 0) return 0;

   // sort ascending by time (oldest first) — reflects level order
   for(int a = 0; a < cnt - 1; a++)
      for(int b = a + 1; b < cnt; b++)
         if(times[b] < times[a])
         {
            datetime tt = times[a]; times[a] = times[b]; times[b] = tt;
            double lt = lots[a]; lots[a] = lots[b]; lots[b] = lt;
         }

   // cumulative scan; pick lot of last level whose cumulative <= target
   double cum = 0;
   double pickedLot = lots[0];
   for(int k = 0; k < cnt; k++)
   {
      cum += lots[k];
      if(cum <= targetLots) pickedLot = lots[k];
      else break;
   }
   if(cum <= targetLots) pickedLot = lots[cnt - 1]; // all fit → take largest

   Print("v6.61 RECOVERY SEED: Gen", gen, " side=", EnumToString(side),
         " seed=", DoubleToString(pickedLot, 2),
         " (cum=", DoubleToString(cum, 2), " target=", DoubleToString(targetLots, 2), ")");
   return pickedLot;
}

//+------------------------------------------------------------------+
//| v6.73: Count "free" older-gen normal orders on a side             |
//| Free = not hedge comment, not bound, gen >= 1 && gen < currentGen |
//| Used as guard: while older-gen orders can self-close, do not open |
//| a new gen INIT on the same side (avoid GM1+GM2 same-side mixing). |
//+------------------------------------------------------------------+
int CountFreeOlderGenOnSide(ENUM_POSITION_TYPE side)
{
   int cnt = 0;
   if(g_cycleGeneration <= 1) return 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != side) continue;
      string cmt = PositionGetString(POSITION_COMMENT);
      if(IsHedgeComment(cmt)) continue;
      if(IsTicketBound(tk)) continue;          // bound = hedge is handling it
      int og = ExtractGeneration(cmt);
      if(og < 1) continue;
      if(og >= g_cycleGeneration) continue;    // only OLDER gens
      cnt++;
   }
   return cnt;
}

//+------------------------------------------------------------------+
//| v6.73: Auto-advance Sequential Recovery owner to next remaining   |
//| generation when the current owner gen is flat. Called from OnTick.|
//+------------------------------------------------------------------+
void AdvanceSequentialOwnerIfFlat()
{
   if(!InpOwnerAutoAdvance) return;
   if(!InpHedge_SequentialRecovery) return;
   if(!g_sequentialRecoveryActive) return;
   if(!IsSequentialRecoveryComplete()) return;

   static datetime lastAdvance = 0;
   if(TimeCurrent() - lastAdvance < 1) return;
   lastAdvance = TimeCurrent();

   int oldGen = g_sequentialRecoveryGen;

   // Find next gen with remaining normal (non-hedge) orders, gen > oldGen
   int nextGen = -1;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      string cmt = PositionGetString(POSITION_COMMENT);
      if(IsHedgeComment(cmt)) continue;
      int og = ExtractGeneration(cmt);
      if(og <= oldGen) continue;
      if(nextGen < 0 || og < nextGen) nextGen = og;
   }

   if(nextGen < 0)
   {
      // No newer gen pending — just clear, normal flow takes over
      ClearSequentialRecoveryOwner("v6.73 owner-advance: no newer gen pending");
      return;
   }

   // Find a hedge set bound to nextGen, if any
   int nextSlot = -1;
   for(int h = 0; h < g_hedgeSetCount; h++)
   {
      if(!g_hedgeSets[h].active) continue;
      if(g_hedgeSets[h].boundGeneration == nextGen) { nextSlot = h; break; }
   }

   ClearSequentialRecoveryOwner("v6.73 owner-advance: Gen" + IntegerToString(oldGen) + " flat → Gen" + IntegerToString(nextGen));
   if(nextSlot >= 0)
   {
      SetSequentialRecoveryOwner(nextSlot, nextGen);
      Print("v6.73 OWNER ADVANCE: Gen", oldGen, " → Gen", nextGen, " (set#", nextSlot + 1, ")");
   }
   else
   {
      Print("v6.73 OWNER ADVANCE: Gen", oldGen, " flat → Gen", nextGen,
            " has no active hedge set (continuing as free recovery)");
   }
}

//+------------------------------------------------------------------+
//| v6.73: Prune g_prevHedgedTickets entries whose tickets are gone   |
//| Keeps the array tight; cycle reset still flushes everything.      |
//+------------------------------------------------------------------+
void PrunePrevHedgedTickets()
{
   static datetime lastPrune = 0;
   if(TimeCurrent() - lastPrune < 5) return;
   lastPrune = TimeCurrent();
   if(g_prevHedgedCount <= 0) return;
   int w = 0;
   for(int r = 0; r < g_prevHedgedCount; r++)
   {
      ulong tk = g_prevHedgedTickets[r];
      if(tk != 0 && PositionSelectByTicket(tk))
      {
         g_prevHedgedTickets[w] = tk;
         w++;
      }
   }
   for(int j = w; j < g_prevHedgedCount; j++) g_prevHedgedTickets[j] = 0;
   g_prevHedgedCount = w;
}

//+------------------------------------------------------------------+
//| v6.74: Released Gen+Side lock helpers                              |
//+------------------------------------------------------------------+
bool IsReleasedGenSideLocked(int gen, ENUM_POSITION_TYPE side)
{
   if(!InpHedge_NoReHedgeGenSide) return false;
   if(gen < 1) return false;
   for(int i = 0; i < g_releasedGenSideCount; i++)
   {
      if(!g_releasedGenSide[i].active) continue;
      if(g_releasedGenSide[i].generation == gen && g_releasedGenSide[i].side == side)
         return true;
   }
   return false;
}

void MarkGenSideReleased(int gen, ENUM_POSITION_TYPE side, string reason)
{
   if(!InpHedge_NoReHedgeGenSide) return;
   if(gen < 1) return;
   // Skip duplicates
   for(int i = 0; i < g_releasedGenSideCount; i++)
   {
      if(g_releasedGenSide[i].active &&
         g_releasedGenSide[i].generation == gen &&
         g_releasedGenSide[i].side == side)
         return;
   }
   if(g_releasedGenSideCount >= MAX_RELEASED_LOCKS)
   {
      Print("v6.74 WARNING: g_releasedGenSide[] full (", MAX_RELEASED_LOCKS, ") — cannot lock Gen", gen);
      return;
   }
   g_releasedGenSide[g_releasedGenSideCount].generation = gen;
   g_releasedGenSide[g_releasedGenSideCount].side       = side;
   g_releasedGenSide[g_releasedGenSideCount].lockedAt   = TimeCurrent();
   g_releasedGenSide[g_releasedGenSideCount].active     = true;
   g_releasedGenSideCount++;
   Print("v6.74 GEN-SIDE LOCK: Gen", gen, " ", (side == POSITION_TYPE_BUY ? "BUY" : "SELL"),
         " released → no re-hedge (", reason, ")");
}

// Count live normal/recovery orders for a specific (gen, side). Excludes hedge comments.
int CountLiveOrdersForGenSide(int gen, ENUM_POSITION_TYPE side)
{
   int cnt = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tk = PositionGetTicket(i);
      if(tk == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != side) continue;
      string cmt = PositionGetString(POSITION_COMMENT);
      if(IsHedgeComment(cmt)) continue;
      int og = ExtractGeneration(cmt);
      if(og != gen) continue;
      cnt++;
   }
   return cnt;
}

void PruneReleasedGenSideLocks()
{
   static datetime lastPrune = 0;
   if(TimeCurrent() - lastPrune < 5) return;
   lastPrune = TimeCurrent();
   if(g_releasedGenSideCount <= 0) return;
   int w = 0;
   for(int r = 0; r < g_releasedGenSideCount; r++)
   {
      if(!g_releasedGenSide[r].active) continue;
      int live = CountLiveOrdersForGenSide(g_releasedGenSide[r].generation, g_releasedGenSide[r].side);
      if(live <= 0)
      {
         Print("v6.74 GEN-SIDE LOCK CLEAR: Gen", g_releasedGenSide[r].generation, " ",
               (g_releasedGenSide[r].side == POSITION_TYPE_BUY ? "BUY" : "SELL"),
               " is now flat → lock removed");
         g_releasedGenSide[r].active = false;
         continue;
      }
      if(r != w)
         g_releasedGenSide[w] = g_releasedGenSide[r];
      w++;
   }
   g_releasedGenSideCount = w;
}

void ClearAllReleasedGenSideLocks()
{
   for(int i = 0; i < MAX_RELEASED_LOCKS; i++)
      g_releasedGenSide[i].active = false;
   g_releasedGenSideCount = 0;
}

void SaveBoundTicketsToPrevHedged(int idx)
{
   // v6.73: when InpHedge_NoReHedgeReleased=true, mark ALL released tickets (any trigger type)
   // so they never get re-hedged — grid loss/profit must recover them.
   // Legacy behavior (DD-only) when toggle is off.
   bool ticketGuardActive = (InpHedge_NoReHedgeReleased || g_hedgeSets[idx].triggerType == 1);
   if(ticketGuardActive)
   {
      for(int b = 0; b < g_hedgeSets[idx].boundTicketCount; b++)
      {
         ulong tk = g_hedgeSets[idx].boundTickets[b];
         if(tk == 0) continue;
         if(PositionSelectByTicket(tk))
            AddPrevHedgedTicket(tk);
      }
   }
   // v6.74: Lock the entire (boundGeneration, counterSide) from being hedged again.
   //        This is what stops "ชุดเดิมโดน hedge ซ้ำ" after the first release —
   //        even if new GL/GP orders open inside that gen-side later.
   if(InpHedge_NoReHedgeGenSide)
   {
      int gen = g_hedgeSets[idx].boundGeneration;
      ENUM_POSITION_TYPE side = g_hedgeSets[idx].counterSide;
      string trigName = (g_hedgeSets[idx].triggerType == 1 ? "DD" :
                        (g_hedgeSets[idx].triggerType == 2 ? "Vol" : "Exp"));
      MarkGenSideReleased(gen, side, "Set#" + IntegerToString(idx + 1) + " released (" + trigName + ")");
   }
}

//+------------------------------------------------------------------+
//| v6.27: Safe cycle reset — only reset when account is truly flat    |
//| Prevents premature clearing of prevHedgedTickets while released    |
//| orders are still open (which would allow DD re-trigger)            |
//+------------------------------------------------------------------+
void TryResetCycleStateIfFlat(string reason)
{
   if(g_hedgeSetCount > 0) return;  // still have active sets — never reset
   if(g_cycleGeneration <= 1) return;  // v6.62: GM1 is the base — nothing to reset

   int remaining = TotalOrderCount();

   // === Case A: account fully flat → full reset to GM1 ===
   if(remaining == 0)
   {
      g_cycleGeneration = 1;  // v6.62: cycles always restart at GM1
      SaveCycleGeneration();  // v6.53: persist reset
      g_hedgeSetCount = 0;
      ClearPrevHedgedTickets();
      ClearAllReleasedGenSideLocks();   // v6.74
      g_lastHedgeBuyTime = 0;   // v6.39: reset side pause
      g_lastHedgeSellTime = 0;  // v6.39: reset side pause
      UpdateDynamicBalanceGuardTarget();  // v6.31: update target immediately when flat
      Print("v6.66 CYCLE RESET → GM1 — ", reason, " (account flat)");
      return;
   }

   // === Case B (v6.66): no active hedge but orphan orders remain ===
   // Re-anchor cycleGen to MAX gen of remaining orders so next hedge
   // doesn't keep climbing GM12/13/14… indefinitely.
   int maxRemainingGen = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      string cmt = PositionGetString(POSITION_COMMENT);
      if(IsHedgeComment(cmt)) continue;  // hedge comments shouldn't drive gen anchor
      int g = ExtractGeneration(cmt);
      if(g > maxRemainingGen) maxRemainingGen = g;
   }
   int newGen = (maxRemainingGen < 1) ? 1 : maxRemainingGen;
   if(newGen < g_cycleGeneration)
   {
      Print("v6.66 CYCLE RE-ANCHOR: GM", g_cycleGeneration, " → GM", newGen,
            " (no active hedge, ", remaining, " orphan orders remain) — ", reason);
      g_cycleGeneration = newGen;
      SaveCycleGeneration();
      g_lastHedgeBuyTime = 0;
      g_lastHedgeSellTime = 0;
   }
}

//+------------------------------------------------------------------+
//| v6.31: Helper — update dynamic balance guard target from balance   |
//| Called at every flat-detection point for immediate update          |
//+------------------------------------------------------------------+
void UpdateDynamicBalanceGuardTarget()
{
   if(!InpBalanceGuard_Enable) return;
   if(InpBalanceGuard_Mode != BALGUARD_DYNAMIC) return;
   if(TotalOrderCount() != 0) return;  // v6.33: อัปเดตเฉพาะเมื่อ flat (ไม่มีออเดอร์) เท่านั้น
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if(MathAbs(bal - g_balanceGuardDynamicTarget) > 0.01)
   {
      Print("v6.33 BG Dynamic: Target updated $", 
            DoubleToString(g_balanceGuardDynamicTarget, 2),
            " → $", DoubleToString(bal, 2));
      g_balanceGuardDynamicTarget = bal;
   }
}

//+------------------------------------------------------------------+
//| v6.28: Balance Guard — close all positions when equity recovers    |
//| to target balance. Only active during hedging (g_hedgeSetCount>0)  |
//+------------------------------------------------------------------+
void CheckBalanceGuard()
{
   if(!InpBalanceGuard_Enable) return;
   
   // v6.31: Dynamic target update — fallback check every tick when flat
   UpdateDynamicBalanceGuardTarget();
   
    // v6.31: Determine effective target based on mode
   double effectiveTarget = ((InpBalanceGuard_Mode == BALGUARD_DYNAMIC) ? g_balanceGuardDynamicTarget : InpBalanceGuard_Target) + InpBalanceGuard_Profit;  // v6.35: Add minimum profit to target
   
   // Activate guard when hedge set is active
   if(g_hedgeSetCount > 0)
   {
      if(!g_balanceGuardActive)
      {
         g_balanceGuardActive = true;
         string modeStr = (InpBalanceGuard_Mode == BALGUARD_DYNAMIC) ? "Dynamic" : "Fixed";
         Print("v6.31 Balance Guard [", modeStr, "]: ACTIVATED — monitoring equity toward $", DoubleToString(effectiveTarget, 2));
      }
   }
   
   // Only check when guard is active
   if(!g_balanceGuardActive) return;
   
   double curEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   
   if(curEquity >= effectiveTarget)
   {
      Print("v6.31 Balance Guard: TRIGGERED — Equity $", DoubleToString(curEquity, 2), 
            " >= Target $", DoubleToString(effectiveTarget, 2), " — closing ALL positions");
      
      CloseAllPositions();
      
      // Reset balance guard state
      g_balanceGuardActive = false;
      
      // Reset cycle state (CloseAllPositions already resets hedge sets)
       g_cycleGeneration = 1;  // v6.62: restart at GM1
       SaveCycleGeneration();  // v6.53: persist reset
       ClearPrevHedgedTickets();
       ClearAllReleasedGenSideLocks();   // v6.74
       g_lastHedgeBuyTime = 0;   // v6.39: reset side pause
       g_lastHedgeSellTime = 0;  // v6.39: reset side pause
       Print("v6.31 Balance Guard: Full reset complete — ready for fresh cycle");
   }
   
   // Deactivate if no more hedge sets and no positions (flat after manual close)
   if(g_hedgeSetCount <= 0 && TotalOrderCount() == 0)
   {
      if(g_balanceGuardActive)
      {
         g_balanceGuardActive = false;
         Print("v6.31 Balance Guard: Deactivated — account is flat");
      }
   }
}

//+------------------------------------------------------------------+
//| v6.57: Recovery Grid getters — fall back to GridLoss_* when off    |
//+------------------------------------------------------------------+
int GetRecoveryMaxTrades()
{
   return Recovery_UseSeparate ? Recovery_MaxTrades : GridLoss_MaxTrades;
}
ENUM_LOT_MODE GetRecoveryLotMode()
{
   return Recovery_UseSeparate ? Recovery_LotMode : GridLoss_LotMode;
}
double GetRecoveryAddLotPerLevel()
{
   return Recovery_UseSeparate ? Recovery_AddLotPerLevel : GridLoss_AddLotPerLevel;
}
double GetRecoveryMultiplyFactor()
{
   return Recovery_UseSeparate ? Recovery_MultiplyFactor : GridLoss_MultiplyFactor;
}
ENUM_GAP_TYPE GetRecoveryGapType()
{
   return Recovery_UseSeparate ? Recovery_GapType : GridLoss_GapType;
}
int GetRecoveryPoints()
{
   return Recovery_UseSeparate ? Recovery_Points : GridLoss_Points;
}
string GetRecoveryCustomDistance()
{
   return Recovery_UseSeparate ? Recovery_CustomDistance : GridLoss_CustomDistance;
}
string GetRecoveryCustomLots()
{
   return Recovery_UseSeparate ? Recovery_CustomLots : GridLoss_CustomLots;
}
ENUM_TIMEFRAMES GetRecoveryATR_TF()
{
   return Recovery_UseSeparate ? Recovery_ATR_TF : GridLoss_ATR_TF;
}
int GetRecoveryATR_Period()
{
   return Recovery_UseSeparate ? Recovery_ATR_Period : GridLoss_ATR_Period;
}
double GetRecoveryATR_Multiplier()
{
   return Recovery_UseSeparate ? Recovery_ATR_Multiplier : GridLoss_ATR_Multiplier;
}
ENUM_ATR_REF GetRecoveryATR_Reference()
{
   return Recovery_UseSeparate ? Recovery_ATR_Reference : GridLoss_ATR_Reference;
}
int GetRecoveryMinGapPoints()
{
   return Recovery_UseSeparate ? Recovery_MinGapPoints : GridLoss_MinGapPoints;
}
int GetRecoveryCandleConfirm()
{
   return Recovery_UseSeparate ? Recovery_CandleConfirm : GridLoss_CandleConfirm;
}

// Compute Recovery grid distance (points) for level (0-based)
double GetRecoveryGridDistancePoints(int level)
{
   ENUM_GAP_TYPE gt = GetRecoveryGapType();
   if(gt == GAP_FIXED)
      return (double)GetRecoveryPoints();
   if(gt == GAP_CUSTOM)
      return ParseCustomValue(GetRecoveryCustomDistance(), level);
   // ATR
   double atrVal = CalculateSimplifiedATR(_Symbol, GetRecoveryATR_TF(), GetRecoveryATR_Period());
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(atrVal > 0 && point > 0)
   {
      double atrDist = atrVal * GetRecoveryATR_Multiplier() / point;
      return MathMax(atrDist, (double)GetRecoveryMinGapPoints());
   }
   return (double)GetRecoveryPoints();
}

// Compute Recovery grid lot using mode + maxExisting continuation
double ComputeRecoveryGridLot(double maxExisting, int level)
{
   ENUM_LOT_MODE mode = GetRecoveryLotMode();
   double lots = InitialLotSize;
   if(mode == LOT_ADD)
      lots = InitialLotSize + InitialLotSize * GetRecoveryAddLotPerLevel() * (level + 1);
   else if(mode == LOT_CUSTOM)
      lots = ParseCustomValue(GetRecoveryCustomLots(), level);
   else // LOT_MULTIPLY
      lots = InitialLotSize * MathPow(GetRecoveryMultiplyFactor(), level + 1);

   if(maxExisting > 0 && lots <= maxExisting)
   {
      if(mode == LOT_MULTIPLY)
         lots = maxExisting * GetRecoveryMultiplyFactor();
      else if(mode == LOT_ADD)
         lots = maxExisting + InitialLotSize * GetRecoveryAddLotPerLevel();
   }
   return lots;
}

//+------------------------------------------------------------------+
//| v6.57: Find the oldest active hedge set (FIFO ordering)            |
//| Returns -1 if no active set                                        |
//+------------------------------------------------------------------+
int FindOldestActiveHedgeSet()
{
   int oldest = -1;
   datetime oldestTime = 0;
   for(int h = 0; h < MAX_HEDGE_SETS; h++)
   {
      if(!g_hedgeSets[h].active) continue;
      datetime t = g_hedgeSets[h].hedgeOpenTime;
      if(t == 0)
      {
         // fallback: try live ticket
         if(g_hedgeSets[h].hedgeTicket > 0 && PositionSelectByTicket(g_hedgeSets[h].hedgeTicket))
            t = (datetime)PositionGetInteger(POSITION_TIME);
      }
      if(oldest < 0 || (t > 0 && t < oldestTime) || oldestTime == 0)
      {
         oldest = h;
         oldestTime = t;
      }
   }
   return oldest;
   }
//| Get lot cap for new orders when hedge set has bound orders          |
//| Returns -1 if no hedge set exists for this side (no cap)           |
//| Returns allowedLots = hedgeLots - remainingBoundLots               |
//+------------------------------------------------------------------+
double GetHedgeLotCap(ENUM_POSITION_TYPE side)
{
   double minCap = -1;  // -1 means no cap
   for(int h = 0; h < MAX_HEDGE_SETS; h++)
   {
      if(!g_hedgeSets[h].active) continue;
      if(g_hedgeSets[h].counterSide != side) continue;

      // v6.23: Skip hedge sets from previous generations — only cap current gen
      if(g_hedgeSets[h].boundGeneration != g_cycleGeneration)
      {
         Print("GetHedgeLotCap: skip set#", h, " boundGen=", g_hedgeSets[h].boundGeneration,
               " != currentGen=", g_cycleGeneration);
         continue;
      }

      // This hedge set has bound orders on this side
      double boundLots = 0;
      for(int b = 0; b < g_hedgeSets[h].boundTicketCount; b++)
      {
         ulong ticket = g_hedgeSets[h].boundTickets[b];
         if(!PositionSelectByTicket(ticket)) continue;
         boundLots += PositionGetDouble(POSITION_VOLUME);
      }

      double hedgeLots = g_hedgeSets[h].hedgeLots;
      double allowed = hedgeLots - boundLots;

      // If bound orders already cover or exceed hedge volume,
      // skip this set — new orders are independent cycle, no cap needed
      if(allowed <= 0) continue;

      if(minCap < 0)
         minCap = allowed;
      else
         minCap = MathMin(minCap, allowed);
   }
   if(minCap >= 0)
      Print("GetHedgeLotCap: side=", EnumToString(side), " cap=", DoubleToString(minCap, 2),
            " gen=", g_cycleGeneration);
   return minCap;
}

//+------------------------------------------------------------------+
//| v6.81: Close opposite-side survivors of same generation           |
//| Called right after a hedge opens (before g_cycleGeneration++) so   |
//| the orphan profitable side does not block new-gen INIT via the     |
//| Cross-Gen INIT Guard (v6.76).                                      |
//+------------------------------------------------------------------+
void CloseOppositeSurvivorsOfGen(int gen, ENUM_POSITION_TYPE hedgeSide)
{
   if(!InpHedge_CloseOppositeSurvivors) return;

   ENUM_POSITION_TYPE oppSide = (hedgeSide == POSITION_TYPE_BUY)
                                ? POSITION_TYPE_SELL
                                : POSITION_TYPE_BUY;

   int closed = 0;
   double totalPL = 0.0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != oppSide) continue;

      string comment = PositionGetString(POSITION_COMMENT);
      if(IsHedgeComment(comment)) continue;          // never touch hedge orders
      if(IsTicketBound(ticket)) continue;            // never touch bound tickets

      int orderGen = ExtractGeneration(comment);
      if(orderGen != gen) continue;                  // only same generation

      double pl = PositionGetDouble(POSITION_PROFIT)
                + PositionGetDouble(POSITION_SWAP);

      // Lock from re-hedge so v6.74 / v6.73 logic stays consistent
      AddPrevHedgedTicket(ticket);

      if(trade.PositionClose(ticket))
      {
         closed++;
         totalPL += pl;
         PrintFormat("OPP-SURVIVOR CLOSE gen=%d side=%s ticket=%I64u profit=%.2f comment=%s",
                     gen,
                     (oppSide == POSITION_TYPE_BUY ? "BUY" : "SELL"),
                     ticket, pl, comment);
      }
      else
      {
         PrintFormat("OPP-SURVIVOR CLOSE FAILED gen=%d ticket=%I64u err=%d",
                     gen, ticket, GetLastError());
      }
   }

   if(closed > 0)
      PrintFormat("OPP-SURVIVOR SUMMARY gen=%d hedgeSide=%s closed=%d totalPL=%.2f",
                  gen,
                  (hedgeSide == POSITION_TYPE_BUY ? "BUY" : "SELL"),
                  closed, totalPL);
}

//+------------------------------------------------------------------+
//| v6.89: Strip broker SL from trailing-owned tickets               |
//| Called once on Normal->Pause edge. Targets EA-magic positions    |
//| with comments _INIT / _GL / _GP only. Skips GM_HEDGE_* / GM_HD*  |
//| (Triple-Gate hedge tickets have their own SL/TP lifecycle).      |
//| Sets SL=0 while preserving current TP.                            |
//+------------------------------------------------------------------+
void StripTrailingBrokerSL()
{
   int stripped = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;

      string comment = PositionGetString(POSITION_COMMENT);
      // Skip hedge tickets — Triple-Gate owns their SL/TP
      if(StringFind(comment, "GM_HEDGE_") >= 0) continue;
      if(StringFind(comment, "GM_HD")     >= 0) continue;
      // Only strip trailing-owned tickets
      if(StringFind(comment, "_INIT") < 0 &&
         StringFind(comment, "_GL")   < 0 &&
         StringFind(comment, "_GP")   < 0) continue;

      double curSL = PositionGetDouble(POSITION_SL);
      if(curSL <= 0) continue; // already no SL

      double curTP = PositionGetDouble(POSITION_TP);
      if(trade.PositionModify(ticket, 0.0, curTP))
         stripped++;
      else
         Print("v6.89 StripSL: Modify #", ticket, " failed: ", GetLastError());
   }
   if(stripped > 0)
      Print("v6.89 SQUEEZE PAUSE: Stripped broker SL from ", stripped, " trailing-owned tickets");
}

//+------------------------------------------------------------------+
//| v6.89: Edge-aware pause check used by ALL trailing managers       |
//| Returns true when paused (caller must `return`).                  |
//| On Normal->Pause edge: optionally strip SL + reset trailing state |
//| (so v6.85 SyncBrokerTPSL won't re-apply old SL via g_trailingSL_*)|
//| On Pause->Normal edge: log resume                                 |
//+------------------------------------------------------------------+
bool IsTrailingPausedAndHandleEdge()
{
   bool pausing = IsSqueezePausingTrailing();

   if(pausing && !g_squeezePauseTrailingActive)
   {
      g_squeezePauseTrailingActive = true;
      // Reset trailing state so SyncBrokerTPSL stops re-applying via g_trailingSL_*
      g_trailingActive_Buy  = false;
      g_trailingActive_Sell = false;
      g_trailingSL_Buy  = 0;
      g_trailingSL_Sell = 0;
      g_maxGridTrailActive_Buy  = false;
      g_maxGridTrailActive_Sell = false;
      g_maxGridTrailSL_Buy  = 0;
      g_maxGridTrailSL_Sell = 0;
      // v6.91: also reset 2-cross armReady so re-arm requires a fresh cross-below avg after pause
      g_maxGridArmReady_Buy  = false;
      g_maxGridArmReady_Sell = false;

      if(InpSqueeze_PauseTrail_StripSL)
         StripTrailingBrokerSL();
      else
         Print("v6.89 SQUEEZE PAUSE: Trailing frozen (StripSL=OFF, broker SL kept)");
   }
   else if(!pausing && g_squeezePauseTrailingActive)
   {
      g_squeezePauseTrailingActive = false;
      Print("v6.89 SQUEEZE PAUSE END: Trailing resumes from current price (state cleared)");
   }
   return pausing;
}


//+------------------------------------------------------------------+
//| Count unbound orders (not tied to any hedge set) for a side        |
//| v6.18: genFilter >= 0 → only count orders matching that generation |
//+------------------------------------------------------------------+
int CountUnboundOrders(ENUM_POSITION_TYPE side, double &totalLots, double &totalPL, int genFilter = -1)
{
   int count = 0;
   totalLots = 0;
   totalPL = 0;
   // v6.74: If this (gen, counterSide) was already released from a hedge once,
   //        report ZERO eligible orders so CheckAndOpenHedge / OpenDDHedge
   //        cannot open another hedge for the same ชุดเดิม. Grid recovery
   //        will handle these orders until the gen-side goes flat.
   if(InpHedge_NoReHedgeGenSide && genFilter >= 1 && IsReleasedGenSideLocked(genFilter, side))
   {
      static datetime lastBlockLog = 0;
      if(TimeCurrent() - lastBlockLog >= 30)
      {
         Print("v6.74 RE-HEDGE BLOCKED: Gen", genFilter, " ",
               (side == POSITION_TYPE_BUY ? "BUY" : "SELL"),
               " was already released once → grid recovery only");
         lastBlockLog = TimeCurrent();
      }
      return 0;
   }
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != side) continue;
      string comment = PositionGetString(POSITION_COMMENT);
      if(IsHedgeComment(comment)) continue;
      if(IsTicketBound(ticket)) continue;  // skip tickets already bound to a set
      if(IsPrevHedgedTicket(ticket)) continue;  // v6.58: skip released-from-hedge tickets
      // v6.65: STRICT generation match — only orders of EXACT generation
      // (เดิม v6.38 ใช้ <= → DD hedge ดูด orphan gen เก่า → lots inflated)
      if(genFilter >= 0)
      {
         int orderGen = ExtractGeneration(comment);
         if(orderGen != genFilter) continue;
      }
      count++;
      totalLots += PositionGetDouble(POSITION_VOLUME);
      totalPL += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return count;
}

//+------------------------------------------------------------------+
//| Remove a bound ticket from a hedge set (when order closed)         |
//+------------------------------------------------------------------+
void RemoveBoundTicket(int idx, ulong ticket)
{
   for(int b = 0; b < g_hedgeSets[idx].boundTicketCount; b++)
   {
      if(g_hedgeSets[idx].boundTickets[b] == ticket)
      {
         // Shift remaining tickets down
         for(int j = b; j < g_hedgeSets[idx].boundTicketCount - 1; j++)
            g_hedgeSets[idx].boundTickets[j] = g_hedgeSets[idx].boundTickets[j + 1];
         g_hedgeSets[idx].boundTicketCount--;
         ArrayResize(g_hedgeSets[idx].boundTickets, g_hedgeSets[idx].boundTicketCount);
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| Refresh bound tickets — remove tickets that no longer exist        |
//+------------------------------------------------------------------+
void RefreshBoundTickets(int idx)
{
   for(int b = g_hedgeSets[idx].boundTicketCount - 1; b >= 0; b--)
   {
      ulong ticket = g_hedgeSets[idx].boundTickets[b];
      if(!PositionSelectByTicket(ticket))
      {
         // Position closed externally → remove from bound list
         RemoveBoundTicket(idx, ticket);
      }
   }
}

//+------------------------------------------------------------------+
//| Find free hedge set slot                                           |
//+------------------------------------------------------------------+
int FindFreeHedgeSlot()
{
   for(int h = 0; h < MAX_HEDGE_SETS; h++)
   {
      if(!g_hedgeSets[h].active) return h;
   }
   return -1;
}

//+------------------------------------------------------------------+
//| v6.78: Hedge Open Delay (minutes) — guard against false signals  |
//| Returns true if delay is still active; remainSec = seconds left   |
//+------------------------------------------------------------------+
datetime g_lastHedgeDelayLog = 0;
bool IsHedgeOpenDelayActive(int &remainSec)
{
   remainSec = 0;
   if(InpHedge_OpenDelayMin <= 0) return false;
   datetime now = TimeCurrent();
   long delaySec = (long)InpHedge_OpenDelayMin * 60;

   long remainOpen = 0, remainClose = 0;
   datetime lastOpen = (g_lastHedgeBuyTime > g_lastHedgeSellTime) ? g_lastHedgeBuyTime : g_lastHedgeSellTime;
   if(lastOpen > 0)
   {
      long elapsed = (long)(now - lastOpen);
      if(elapsed < delaySec) remainOpen = delaySec - elapsed;
   }
   if(g_lastHedgeCloseTime > 0)
   {
      long elapsed = (long)(now - g_lastHedgeCloseTime);
      if(elapsed < delaySec) remainClose = delaySec - elapsed;
   }

   long rem = 0;
   if(InpHedge_OpenDelayMode == HDELAY_AFTER_LAST_OPEN)       rem = remainOpen;
   else if(InpHedge_OpenDelayMode == HDELAY_AFTER_LAST_CLOSE) rem = remainClose;
   else                                                        rem = (remainOpen > remainClose) ? remainOpen : remainClose;

   if(rem <= 0) return false;
   remainSec = (int)rem;
   return true;
}

//+------------------------------------------------------------------+
//| Check expansion and open hedge if needed                           |
//| Now supports multiple hedge sets on same side (unbound orders)     |
//+------------------------------------------------------------------+
void CheckAndOpenHedge()
{
   // v6.78: Hedge Open Delay guard (กัน false signal)
   {
      int remSec = 0;
      if(IsHedgeOpenDelayActive(remSec))
      {
         datetime nw = TimeCurrent();
         if(nw - g_lastHedgeDelayLog >= 60)
         {
            g_lastHedgeDelayLog = nw;
            PrintFormat("v6.78 HEDGE DELAY (Expansion): wait %dm%02ds before next hedge (mode=%d, cfg=%dm)",
                        remSec/60, remSec%60, (int)InpHedge_OpenDelayMode, InpHedge_OpenDelayMin);
         }
         return;
      }
   }

   // v6.14: Determine expansion direction — all expansion TFs must agree
   int bestDir = 0;
   int expCount = CountDirectionalExpansion(bestDir);
   // bestDir == 0 means conflict (BUY+SELL mix) → do not open hedge
   if(expCount < InpHedge_MinTFConfirm || bestDir == 0) return;

   // Bearish expansion → hedge BUY orders stuck (open SELL hedge)
   // Bullish expansion → hedge SELL orders stuck (open BUY hedge)
   ENUM_POSITION_TYPE counterSide = (bestDir == -1) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   ENUM_POSITION_TYPE hedgeSide   = (bestDir == -1) ? POSITION_TYPE_SELL : POSITION_TYPE_BUY;

   // v6.19: Count UNBOUND stuck orders on counter side — CURRENT GENERATION ONLY
   double counterLots = 0, counterPL = 0;
   int counterCount = CountUnboundOrders(counterSide, counterLots, counterPL, g_cycleGeneration);
   if(counterCount == 0 || counterLots <= 0) return;

   // Find free slot
   // Check max active sets limit
   int activeSetCount = 0;
   for(int h = 0; h < MAX_HEDGE_SETS; h++)
      if(g_hedgeSets[h].active) activeSetCount++;
   if(activeSetCount >= InpHedge_MaxSets)
   {
      Print("v6.66 HEDGE BLOCKED: Active hedge sets = ", activeSetCount, "/", InpHedge_MaxSets, " (cap reached) → skip new hedge for GM", g_cycleGeneration);
      return;
   }

   int slot = FindFreeHedgeSlot();
   if(slot < 0)
   {
      Print("HEDGE: No free slot available (max ", MAX_HEDGE_SETS, " sets)");
      return;
   }

    // Open hedge order
    ENUM_ORDER_TYPE orderType = (hedgeSide == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
    // v6.62: Hedge comment ties to the bound generation (= current g_cycleGeneration before increment)
    int bindGenForComment = (g_cycleGeneration < 1) ? 1 : g_cycleGeneration;
    string comment = "GM_Hedge_E" + IntegerToString(bindGenForComment);  // E = Expansion-triggered, suffix = bound gen

   if(OpenOrder(orderType, counterLots, comment))
   {
      g_hedgeSets[slot].active = true;
      g_hedgeSets[slot].hedgeSide = hedgeSide;
      g_hedgeSets[slot].counterSide = counterSide;
      g_hedgeSets[slot].hedgeLots = counterLots;
      g_hedgeSets[slot].originalTotalLots = counterLots;
      g_hedgeSets[slot].gridMode = false;
      g_hedgeSets[slot].gridLevel = 0;
      g_hedgeSets[slot].gridTicketCount = 0;
      ArrayResize(g_hedgeSets[slot].gridTickets, 0);
      g_hedgeSets[slot].commentPrefix = comment;

      // Find the hedge ticket we just opened
      g_hedgeSets[slot].hedgeTicket = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if(PositionGetString(POSITION_COMMENT) == comment)
         {
            g_hedgeSets[slot].hedgeTicket = ticket;
            break;
         }
      }

      // === BIND unbound counter-side tickets to this hedge set ===
      g_hedgeSets[slot].boundTicketCount = 0;
      ArrayResize(g_hedgeSets[slot].boundTickets, 0);
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != counterSide) continue;
         string cmt = PositionGetString(POSITION_COMMENT);
         if(IsHedgeComment(cmt)) continue;
         if(IsTicketBound(ticket)) continue;  // already bound to another set
         if(IsPrevHedgedTicket(ticket)) continue;  // v6.58: never re-bind released tickets
         // v6.19: Generation filter — only bind orders from current generation
         int orderGen = ExtractGeneration(cmt);
         if(orderGen < 0) continue;
         if(orderGen != g_cycleGeneration) continue;

         int bc = g_hedgeSets[slot].boundTicketCount;
         ArrayResize(g_hedgeSets[slot].boundTickets, bc + 1);
         g_hedgeSets[slot].boundTickets[bc] = ticket;
         g_hedgeSets[slot].boundTicketCount = bc + 1;
       }

       // v6.72: Force-clear broker TP/SL on every freshly-bound ticket so
       // price cannot run into a stale TP and break the hedge lock.
       ClearBrokerTPSLForSet(slot);

       // Store bound generation BEFORE incrementing
       g_hedgeSets[slot].boundGeneration = g_cycleGeneration;

        // v6.81: close opposite-side survivors of same gen BEFORE advancing
        CloseOppositeSurvivorsOfGen(g_cycleGeneration, hedgeSide);

        // Increment cycle generation — new orders will use new prefix (GM1_, GM2_, etc.)
        g_cycleGeneration++;
       SaveCycleGeneration();  // v6.53: persist after increment
       Print("CYCLE GENERATION incremented to ", g_cycleGeneration, " — new orders use prefix: ", GetCommentPrefix());

       g_hedgeSetCount++;
       
       // === v6.15: Record Expansion Cycle state + Price Zone ===
       // Check if TF index 2 (largest) is currently in expansion
       bool bigTFExpansion = (g_squeeze[2].state == 2);
       g_hedgeSets[slot].hedgedDuringExpansion = bigTFExpansion;
       g_hedgeSets[slot].seenExpansionSinceHedge = bigTFExpansion;  // if already expansion, mark seen
       // v6.16: Mark trigger type as Expansion
       g_hedgeSets[slot].triggerType = 0;
       
       // Calculate Price Zone: find hedge open price + oldest bound order open price
       double hOpenPrice = 0;
       if(g_hedgeSets[slot].hedgeTicket > 0 && PositionSelectByTicket(g_hedgeSets[slot].hedgeTicket))
           hOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        g_hedgeSets[slot].hedgeOpenPrice = hOpenPrice;
        // v6.57: record hedge open time for sequential FIFO ordering
        if(g_hedgeSets[slot].hedgeTicket > 0 && PositionSelectByTicket(g_hedgeSets[slot].hedgeTicket))
           g_hedgeSets[slot].hedgeOpenTime = (datetime)PositionGetInteger(POSITION_TIME);
        else
           g_hedgeSets[slot].hedgeOpenTime = TimeCurrent();
       
       // Find oldest bound order's open price (earliest open time)
       double oldestPrice = 0;
       datetime oldestTime = D'2099.01.01';
       for(int b = 0; b < g_hedgeSets[slot].boundTicketCount; b++)
       {
          if(PositionSelectByTicket(g_hedgeSets[slot].boundTickets[b]))
          {
             datetime oTime = (datetime)PositionGetInteger(POSITION_TIME);
             if(oTime < oldestTime)
             {
                oldestTime = oTime;
                oldestPrice = PositionGetDouble(POSITION_PRICE_OPEN);
             }
          }
       }
       g_hedgeSets[slot].oldestBoundPrice = oldestPrice;
       g_hedgeSets[slot].zoneUpperPrice = MathMax(hOpenPrice, oldestPrice);
       g_hedgeSets[slot].zoneLowerPrice = MathMin(hOpenPrice, oldestPrice);
       
       string sideStr = (hedgeSide == POSITION_TYPE_BUY) ? "BUY" : "SELL";
       Print("HEDGE OPENED: Set#", slot + 1, " ", sideStr, " ", DoubleToString(counterLots, 2),
             " lots to cover ", counterCount, " stuck orders (bound ", g_hedgeSets[slot].boundTicketCount,
             " tickets, boundGen=", g_hedgeSets[slot].boundGeneration, ")");
       Print("v6.19 CLOSE GATE: triggerType=Expansion hedgedDuringExp=", bigTFExpansion,
             " zone=", DoubleToString(g_hedgeSets[slot].zoneLowerPrice, _Digits),
             "-", DoubleToString(g_hedgeSets[slot].zoneUpperPrice, _Digits));
     }
}

//+------------------------------------------------------------------+
//| v6.16: Check DD% per side and open hedge if threshold reached      |
//+------------------------------------------------------------------+
void CheckAndOpenHedgeByDD()
{
   if(!InpHedge_Enable) return;
   if(InpHedge_TriggerMode != HEDGE_TRIGGER_DD_PERCENT && InpHedge_TriggerMode != HEDGE_TRIGGER_DD_DOLLAR) return;

   // v6.78: Hedge Open Delay guard (กัน false signal)
   {
      int remSec = 0;
      if(IsHedgeOpenDelayActive(remSec))
      {
         datetime nwd = TimeCurrent();
         if(nwd - g_lastHedgeDelayLog >= 60)
         {
            g_lastHedgeDelayLog = nwd;
            PrintFormat("v6.78 HEDGE DELAY (DD): wait %dm%02ds before next hedge (mode=%d, cfg=%dm)",
                        remSec/60, remSec%60, (int)InpHedge_OpenDelayMode, InpHedge_OpenDelayMin);
         }
         return;
      }
   }

   // Cooldown check — both DD hedge cooldown and post-close cooldown
   datetime now = TimeCurrent();
   if(now - g_lastDDHedgeTime < InpHedge_DDCooldownSec) return;
   // v6.25: Cooldown after hedge set close to prevent immediate re-trigger
   if(now - g_lastHedgeCloseTime < InpHedge_DDCooldownSec) return;
   
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0) return;
   
   bool isDollarMode = (InpHedge_TriggerMode == HEDGE_TRIGGER_DD_DOLLAR);
   
   // v6.18: Calculate floating loss per side — ONLY from current generation orders
    int curGen = g_cycleGeneration;  // v6.37: snapshot generation before any hedge opens (race condition fix)
   double buyLoss = 0, sellLoss = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      string cmt = PositionGetString(POSITION_COMMENT);
      if(IsHedgeComment(cmt)) continue;
      if(IsTicketBound(ticket)) continue;
      if(IsPrevHedgedTicket(ticket)) continue;  // v6.26: skip previously-hedged orders
      
      int orderGen = ExtractGeneration(cmt);
      if(orderGen < 0) continue;
      if(orderGen != curGen) continue;  // v6.65: STRICT — DD คำนวณเฉพาะ orders ของ gen ปัจจุบันเท่านั้น
      
      double pnl = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP) + PositionGetDouble(POSITION_COMMISSION);
      if(pnl >= 0) continue;
      
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(posType == POSITION_TYPE_BUY)
         buyLoss += pnl;
      else
         sellLoss += pnl;
   }
   
   if(isDollarMode)
   {
      // v6.25: Dollar mode — compare absolute loss directly
      double buyLossAbs  = MathAbs(buyLoss);
      double sellLossAbs = MathAbs(sellLoss);
      
      if(buyLossAbs >= InpHedge_DDTriggerDollar)
      {
         if(OpenDDHedge(POSITION_TYPE_BUY, POSITION_TYPE_SELL, curGen))  // v6.37: pass snapshot gen
          {
             g_lastDDHedgeTime = now;
             g_lastHedgeBuyTime = now;  // v6.39: BUY orders got hedged → pause BUY entries
             Print("DD$ HEDGE [Gen", curGen, "]: BUY side DD=$", DoubleToString(buyLossAbs, 2), 
                   " >= $", DoubleToString(InpHedge_DDTriggerDollar, 2), " → SELL hedge opened");
         }
      }
      
      if(sellLossAbs >= InpHedge_DDTriggerDollar)
      {
         if(OpenDDHedge(POSITION_TYPE_SELL, POSITION_TYPE_BUY, curGen))  // v6.37: pass snapshot gen
         {
             g_lastDDHedgeTime = now;
             g_lastHedgeSellTime = now;  // v6.39: SELL orders got hedged → pause SELL entries
             Print("DD$ HEDGE [Gen", curGen, "]: SELL side DD=$", DoubleToString(sellLossAbs, 2),
                   " >= $", DoubleToString(InpHedge_DDTriggerDollar, 2), " → BUY hedge opened");
         }
      }
   }
   else
   {
      // Percent mode (original)
      double buyDDPct  = (buyLoss < 0)  ? (MathAbs(buyLoss) / balance * 100.0) : 0;
      double sellDDPct = (sellLoss < 0) ? (MathAbs(sellLoss) / balance * 100.0) : 0;
      
      if(buyDDPct >= InpHedge_DDTriggerPct)
      {
         if(OpenDDHedge(POSITION_TYPE_BUY, POSITION_TYPE_SELL, curGen))  // v6.37: pass snapshot gen
         {
             g_lastDDHedgeTime = now;
             g_lastHedgeBuyTime = now;  // v6.39: BUY orders got hedged → pause BUY entries
             Print("DD HEDGE [Gen", curGen, "]: BUY side DD=", DoubleToString(buyDDPct, 1), 
                   "% >= ", DoubleToString(InpHedge_DDTriggerPct, 1), "% → SELL hedge opened");
         }
      }
      
      if(sellDDPct >= InpHedge_DDTriggerPct)
      {
         if(OpenDDHedge(POSITION_TYPE_SELL, POSITION_TYPE_BUY, curGen))  // v6.37: pass snapshot gen
         {
             g_lastDDHedgeTime = now;
             g_lastHedgeSellTime = now;  // v6.39: SELL orders got hedged → pause SELL entries
             Print("DD HEDGE [Gen", curGen, "]: SELL side DD=", DoubleToString(sellDDPct, 1),
                   "% >= ", DoubleToString(InpHedge_DDTriggerPct, 1), "% → BUY hedge opened");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| v6.16: Open a DD%-triggered hedge order for a losing side          |
//| v6.37: Added bindGen parameter to fix generation race condition    |
//+------------------------------------------------------------------+
bool OpenDDHedge(ENUM_POSITION_TYPE counterSide, ENUM_POSITION_TYPE hedgeSide, int bindGen)
{
   // v6.37: Use bindGen (snapshot) instead of g_cycleGeneration to prevent race condition
   double counterLots = 0, counterPL = 0;
   int counterCount = CountUnboundOrders(counterSide, counterLots, counterPL, bindGen);
   if(counterCount == 0 || counterLots <= 0) return false;
   
   // Check max active sets
   int activeSetCount = 0;
   for(int h = 0; h < MAX_HEDGE_SETS; h++)
      if(g_hedgeSets[h].active) activeSetCount++;
   if(activeSetCount >= InpHedge_MaxSets)
   {
      Print("v6.66 DD HEDGE BLOCKED: Active hedge sets = ", activeSetCount, "/", InpHedge_MaxSets, " (cap reached) → skip new DD hedge for GM", bindGen);
      return false;
   }
   
   int slot = FindFreeHedgeSlot();
   if(slot < 0)
   {
      Print("DD HEDGE: No free slot available");
      return false;
   }
   
    // v6.62: DD-triggered hedge — comment ties to bound generation (= bindGen, not slot)
    int bindGenForComment = (bindGen < 1) ? 1 : bindGen;
    string comment = "GM_Hedge_D" + IntegerToString(bindGenForComment);  // D = DD-triggered, suffix = bound gen
   
   ENUM_ORDER_TYPE orderType = (hedgeSide == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(!OpenOrder(orderType, counterLots, comment)) return false;
   
   // Setup hedge set (same as expansion hedge but with triggerType = 1)
   g_hedgeSets[slot].active = true;
   g_hedgeSets[slot].hedgeSide = hedgeSide;
   g_hedgeSets[slot].counterSide = counterSide;
   g_hedgeSets[slot].hedgeLots = counterLots;
   g_hedgeSets[slot].originalTotalLots = counterLots;
   g_hedgeSets[slot].gridMode = false;
   g_hedgeSets[slot].gridLevel = 0;
   g_hedgeSets[slot].gridTicketCount = 0;
   ArrayResize(g_hedgeSets[slot].gridTickets, 0);
   g_hedgeSets[slot].commentPrefix = comment;
   g_hedgeSets[slot].triggerType = 1;  // DD-triggered
   g_hedgeSets[slot].hedgeOpenTime = TimeCurrent();  // v6.57: temporary; refined after ticket lookup
   
   // Find the hedge ticket
   g_hedgeSets[slot].hedgeTicket = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetString(POSITION_COMMENT) == comment)
      {
         g_hedgeSets[slot].hedgeTicket = ticket;
         g_hedgeSets[slot].hedgeOpenTime = (datetime)PositionGetInteger(POSITION_TIME);  // v6.57
         break;
      }
   }
   
   // Bind unbound counter-side tickets
   g_hedgeSets[slot].boundTicketCount = 0;
   ArrayResize(g_hedgeSets[slot].boundTickets, 0);
    // v6.37: Use bindGen parameter — prevents cross-generation contamination & race condition
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != counterSide) continue;
      string cmt = PositionGetString(POSITION_COMMENT);
      if(IsHedgeComment(cmt)) continue;
      if(IsTicketBound(ticket)) continue;
      if(IsPrevHedgedTicket(ticket)) continue;  // v6.58: never re-bind released tickets
      // v6.65: STRICT generation match — bind ONLY orders of EXACT bindGen
      // (เดิม v6.38 ใช้ <= → bind orphan ของ gen เก่าเข้า hedge set ใหม่ → ลอตเกินจริง)
      int orderGen = ExtractGeneration(cmt);
      if(orderGen < 0) continue;
      if(orderGen != bindGen) continue;
      
      int bc = g_hedgeSets[slot].boundTicketCount;
      ArrayResize(g_hedgeSets[slot].boundTickets, bc + 1);
      g_hedgeSets[slot].boundTickets[bc] = ticket;
      g_hedgeSets[slot].boundTicketCount = bc + 1;
   }

   // v6.72: Force-clear broker TP/SL on every freshly-bound ticket so
   // price cannot run into a stale TP and break the hedge lock.
   ClearBrokerTPSLForSet(slot);

    g_hedgeSets[slot].boundGeneration = bindGen;  // v6.37: use snapshot gen, not current

   // v6.81: close opposite-side survivors of same gen BEFORE advancing
   CloseOppositeSurvivorsOfGen(g_cycleGeneration, hedgeSide);

   g_cycleGeneration++;
   SaveCycleGeneration();  // v6.53: persist after increment
   Print("CYCLE GENERATION incremented to ", g_cycleGeneration, " — new orders use prefix: ", GetCommentPrefix());
   g_hedgeSetCount++;
   
    // v6.17: DD hedge must also pass Expansion Gate — track actual state
    bool isBigTFExpansion = (g_squeeze[2].state == 2);
    g_hedgeSets[slot].hedgedDuringExpansion = isBigTFExpansion;
    g_hedgeSets[slot].seenExpansionSinceHedge = isBigTFExpansion;
   
   // Calculate Price Zone (same as expansion hedge)
   double hOpenPrice = 0;
   if(g_hedgeSets[slot].hedgeTicket > 0 && PositionSelectByTicket(g_hedgeSets[slot].hedgeTicket))
      hOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   g_hedgeSets[slot].hedgeOpenPrice = hOpenPrice;
   
   double oldestPrice = 0;
   datetime oldestTime = D'2099.01.01';
   for(int b = 0; b < g_hedgeSets[slot].boundTicketCount; b++)
   {
      if(PositionSelectByTicket(g_hedgeSets[slot].boundTickets[b]))
      {
         datetime oTime = (datetime)PositionGetInteger(POSITION_TIME);
         if(oTime < oldestTime)
         {
            oldestTime = oTime;
            oldestPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         }
      }
   }
   g_hedgeSets[slot].oldestBoundPrice = oldestPrice;
   g_hedgeSets[slot].zoneUpperPrice = MathMax(hOpenPrice, oldestPrice);
   g_hedgeSets[slot].zoneLowerPrice = MathMin(hOpenPrice, oldestPrice);
   
   string sideStr = (hedgeSide == POSITION_TYPE_BUY) ? "BUY" : "SELL";
   Print("DD HEDGE OPENED: Set#", slot + 1, " ", sideStr, " ", DoubleToString(counterLots, 2),
         " lots (bound ", g_hedgeSets[slot].boundTicketCount, " tickets)");
   Print("v6.16 CLOSE GATE: triggerType=DD zone=", DoubleToString(g_hedgeSets[slot].zoneLowerPrice, _Digits),
         "-", DoubleToString(g_hedgeSets[slot].zoneUpperPrice, _Digits));
   
   return true;
}

//+------------------------------------------------------------------+
//| Close all hedge grid orders for a given set (cleanup before deact) |
//+------------------------------------------------------------------+
void CloseAllHedgeGridOrders(int idx)
{
   string prefix = "GM_HG" + IntegerToString(idx + 1);
   int closed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      string comment = PositionGetString(POSITION_COMMENT);
      if(StringFind(comment, prefix) >= 0)
      {
         trade.PositionClose(ticket);
         closed++;
         Sleep(50);
      }
   }
   if(closed > 0)
      Print("HEDGE CLEANUP Set#", idx + 1, ": closed ", closed, " orphan grid orders (", prefix, ")");
   g_hedgeSets[idx].gridTicketCount = 0;
   ArrayResize(g_hedgeSets[idx].gridTickets, 0);
}

//+------------------------------------------------------------------+
//| Recover hedge sets from existing positions on init                 |
//+------------------------------------------------------------------+
void RecoverHedgeSets()
{
   int recovered = 0;

   // v6.57: If account is fully flat → reset persisted cycle gen immediately
   if(PositionsTotal() == 0)
   {
      if(GlobalVariableCheck(GV_CycleGenKey()))
         GlobalVariableDel(GV_CycleGenKey());
      g_cycleGeneration = 1;  // v6.62: base cycle is GM1
      Print("v6.62 RecoverHedgeSets: account flat → cycleGen reset to 1 (GM1)");
      return;
   }

   // Step 0: Determine current cycle generation from existing positions
   int maxGen = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      string cmt = PositionGetString(POSITION_COMMENT);
      int gen = ExtractGeneration(cmt);
      if(gen > maxGen) maxGen = gen;
   }
   // v6.62: never go below GM1 (legacy GM_* orders may report gen=0; allow them to live but new cycles start ≥1)
   g_cycleGeneration = (maxGen < 1) ? 1 : maxGen;
   SaveCycleGeneration();  // v6.53: persist recovered generation
   Print("RECOVER: Detected cycle generation = ", g_cycleGeneration, " (v6.62 min=GM1)");
   
   // Step 1: Find main hedge positions (GM_HEDGE_N) and rebuild sets
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      
      string comment = PositionGetString(POSITION_COMMENT);
      // v6.62: Recognise both legacy GM_HEDGE_<slot>/GM_HEDGE_D<slot> AND new GM_Hedge_E<gen>/GM_Hedge_D<gen>
      // Legacy: suffix = slot index. v6.62: suffix = bound generation.
      bool isHedge = false;
      bool isDD    = false;
      int  legacySlotIdx = -1;
      int  boundGenFromCmt = -1;

      // New v6.62 format
      if(StringFind(comment, "GM_Hedge_E") == 0)
      {
         isHedge = true; isDD = false;
         boundGenFromCmt = (int)StringToInteger(StringSubstr(comment, StringLen("GM_Hedge_E")));
      }
      else if(StringFind(comment, "GM_Hedge_D") == 0)
      {
         isHedge = true; isDD = true;
         boundGenFromCmt = (int)StringToInteger(StringSubstr(comment, StringLen("GM_Hedge_D")));
      }
      else
      {
         // Legacy GM_HEDGE_<slot> / GM_HEDGE_D<slot>
         for(int h = 0; h < MAX_HEDGE_SETS; h++)
         {
            string hedgePrefix   = "GM_HEDGE_"  + IntegerToString(h + 1);
            string hedgePrefixDD = "GM_HEDGE_D" + IntegerToString(h + 1);
            if(StringFind(comment, hedgePrefixDD) >= 0) { isHedge = true; isDD = true;  legacySlotIdx = h; break; }
            if(StringFind(comment, hedgePrefix)   >= 0) { isHedge = true; isDD = false; legacySlotIdx = h; break; }
         }
      }

      if(!isHedge) continue;

      // Pick slot: legacy uses recorded slot index; new format finds first free slot
      int slot = (legacySlotIdx >= 0) ? legacySlotIdx : -1;
      if(slot < 0)
      {
         for(int h = 0; h < MAX_HEDGE_SETS; h++) { if(!g_hedgeSets[h].active) { slot = h; break; } }
      }
      if(slot < 0 || g_hedgeSets[slot].active) continue;

      {
         int h = slot;
         g_hedgeSets[h].active = true;
         g_hedgeSets[h].hedgeTicket = ticket;
         g_hedgeSets[h].hedgeSide = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         g_hedgeSets[h].hedgeLots = PositionGetDouble(POSITION_VOLUME);
         g_hedgeSets[h].counterSide = (g_hedgeSets[h].hedgeSide == POSITION_TYPE_BUY)
                                      ? POSITION_TYPE_SELL : POSITION_TYPE_BUY;
         g_hedgeSets[h].gridMode = false;
         g_hedgeSets[h].gridLevel = 0;
         g_hedgeSets[h].combinedGridMode = false;
         g_hedgeSets[h].combinedGridLevel = 0;
         g_hedgeSets[h].combinedLots = 0;
         g_hedgeSets[h].seenExpansionSinceHedge = true;
         g_hedgeSets[h].hedgedDuringExpansion = true;
         g_hedgeSets[h].hedgeOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         g_hedgeSets[h].hedgeOpenTime  = (datetime)PositionGetInteger(POSITION_TIME);
         g_hedgeSets[h].zoneUpperPrice = 0;
         g_hedgeSets[h].zoneLowerPrice = 0;
         g_hedgeSets[h].oldestBoundPrice = 0;
         g_hedgeSets[h].triggerType = isDD ? 1 : 0;
         g_hedgeSets[h].commentPrefix = comment;
         // v6.62: if recovered via new format, we know the bound generation directly
         if(boundGenFromCmt >= 0) g_hedgeSets[h].boundGeneration = boundGenFromCmt;
         g_hedgeSetCount++;
         recovered++;
         Print("RECOVER v6.62: Rebuilt Hedge Set#", h + 1, " from ticket ", ticket,
               " comment=", comment,
               " boundGen=", (boundGenFromCmt >= 0 ? IntegerToString(boundGenFromCmt) : "(legacy)"),
               " side=", (g_hedgeSets[h].hedgeSide == POSITION_TYPE_BUY ? "BUY" : "SELL"),
               " lots=", DoubleToString(g_hedgeSets[h].hedgeLots, 2));
      }
   }
   
   // Step 2: Rebind counter-side orders — ONLY bind orders from OLDER generations
   for(int h = 0; h < MAX_HEDGE_SETS; h++)
   {
      if(!g_hedgeSets[h].active) continue;
      g_hedgeSets[h].boundTicketCount = 0;
      ArrayResize(g_hedgeSets[h].boundTickets, 0);
      
      // Determine bound generation: orders from generations BEFORE the current one
      // If hedge exists, bound orders were from a previous gen
      int boundGen = -1;  // will be set to the oldest non-current gen found
      
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != g_hedgeSets[h].counterSide) continue;
         string cmt = PositionGetString(POSITION_COMMENT);
         if(IsHedgeComment(cmt)) continue;
         if(IsTicketBound(ticket)) continue;
         if(IsPrevHedgedTicket(ticket)) continue;  // v6.58: never re-bind released tickets
         
         // Only bind orders from older generations (not current cycle)
         int orderGen = ExtractGeneration(cmt);
         if(orderGen < 0) continue;  // not our comment format
         if(orderGen >= g_cycleGeneration) continue;  // skip current gen — it's an independent new cycle
         
         int bc = g_hedgeSets[h].boundTicketCount;
         ArrayResize(g_hedgeSets[h].boundTickets, bc + 1);
         g_hedgeSets[h].boundTickets[bc] = ticket;
         g_hedgeSets[h].boundTicketCount = bc + 1;
         
         if(boundGen < 0 || orderGen < boundGen) boundGen = orderGen;
      }
      
      g_hedgeSets[h].boundGeneration = (boundGen >= 0) ? boundGen : 0;
      
      // v6.13: Recovery — check if grid orders already exist (resume grid mode)
      // This is the ONLY place where gridMode can be set during recovery (OnInit)
      // because grid orders already exist from a previous session
      if(g_hedgeSets[h].boundTicketCount == 0)
      {
         string gridPrefix = "GM_HG" + IntegerToString(h + 1);
         bool hasGridOrders = false;
         for(int i = PositionsTotal() - 1; i >= 0; i--)
         {
            ulong ticket = PositionGetTicket(i);
            if(ticket == 0) continue;
            if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
            if(StringFind(PositionGetString(POSITION_COMMENT), gridPrefix) >= 0)
            { hasGridOrders = true; break; }
         }
         if(hasGridOrders)
         {
            g_hedgeSets[h].gridMode = true;
            g_hedgeSets[h].gridLevel = CalculateEquivGridLevel(g_hedgeSets[h].hedgeLots);
            g_hedgeSets[h].matchingDone = true;  // grid already running → skip matching
            Print("RECOVER: Set#", h + 1, " entering Grid Mode (no bound orders, grid orders exist)");
         }
      }
      
      // v6.15: Recalculate zone prices from bound tickets + hedge open price
      if(g_hedgeSets[h].boundTicketCount > 0 && g_hedgeSets[h].hedgeOpenPrice > 0)
      {
         double oldestPrice = 0;
         datetime oldestTime = D'2099.01.01';
         for(int b = 0; b < g_hedgeSets[h].boundTicketCount; b++)
         {
            if(PositionSelectByTicket(g_hedgeSets[h].boundTickets[b]))
            {
               datetime oTime = (datetime)PositionGetInteger(POSITION_TIME);
               if(oTime < oldestTime)
               {
                  oldestTime = oTime;
                  oldestPrice = PositionGetDouble(POSITION_PRICE_OPEN);
               }
            }
         }
         g_hedgeSets[h].oldestBoundPrice = oldestPrice;
         g_hedgeSets[h].zoneUpperPrice = MathMax(g_hedgeSets[h].hedgeOpenPrice, oldestPrice);
         g_hedgeSets[h].zoneLowerPrice = MathMin(g_hedgeSets[h].hedgeOpenPrice, oldestPrice);
         Print("RECOVER: Set#", h + 1, " zone=", DoubleToString(g_hedgeSets[h].zoneLowerPrice, _Digits),
               "-", DoubleToString(g_hedgeSets[h].zoneUpperPrice, _Digits));
      }
      
      Print("RECOVER: Set#", h + 1, " bound ", g_hedgeSets[h].boundTicketCount,
            " counter-side orders (boundGen=", g_hedgeSets[h].boundGeneration, ")");

      // v6.72: Force-clear stale broker TP/SL of recovered bound tickets
      ClearBrokerTPSLForSet(h);
   }
   
   // Step 3: Clean up orphan GM_HG orders that have no active main hedge
   int orphansClosed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      string comment = PositionGetString(POSITION_COMMENT);
      if(StringFind(comment, "GM_HG") < 0) continue;
      
      // Find which set this belongs to
      bool belongsToActive = false;
      for(int h = 0; h < MAX_HEDGE_SETS; h++)
      {
         string prefix = "GM_HG" + IntegerToString(h + 1);
         if(StringFind(comment, prefix) >= 0 && g_hedgeSets[h].active)
         { belongsToActive = true; break; }
      }
      
      if(!belongsToActive)
      {
         Print("RECOVER: Closing orphan grid order ticket ", ticket, " comment=", comment);
         trade.PositionClose(ticket);
         orphansClosed++;
         Sleep(50);
      }
   }
   
   // Step 4: Recover Reverse Hedge state (v6.11: array-based, multiple reverse hedges)
   g_reverseHedgeCount = 0;
   g_hedgeBalancedLock = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      string cmt = PositionGetString(POSITION_COMMENT);
      if(StringFind(cmt, "GM_RHEDGE") >= 0)
      {
         if(g_reverseHedgeCount < MAX_REVERSE_HEDGES)
         {
            g_reverseHedgeTickets[g_reverseHedgeCount] = ticket;
            g_reverseHedgeCount++;
            
            string rSide = ((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? "BUY" : "SELL";
            Print("RECOVER: Rebuilt Reverse Hedge #", g_reverseHedgeCount, " ticket=", ticket, 
                  " side=", rSide,
                  " lots=", DoubleToString(PositionGetDouble(POSITION_VOLUME), 2));
         }
      }
   }
   if(g_reverseHedgeCount > 0)
      Print("RECOVER: Total reverse hedges recovered: ", g_reverseHedgeCount);
   
   // v6.16: Recalculate DD triggers from recovered DD-triggered sets
   {
      int ddBuyCount = 0, ddSellCount = 0;
      for(int h = 0; h < MAX_HEDGE_SETS; h++)
      {
         if(!g_hedgeSets[h].active || g_hedgeSets[h].triggerType != 1) continue;
         if(g_hedgeSets[h].counterSide == POSITION_TYPE_BUY)
            ddBuyCount++;
         else
            ddSellCount++;
      }
       // v6.21: Threshold is constant per generation — no cumulative step needed
       // g_nextBuyDDTrigger and g_nextSellDDTrigger are kept at InpHedge_DDTriggerPct
       if(ddBuyCount > 0 || ddSellCount > 0)
          Print("RECOVER DD SETS: BUY-side=", ddBuyCount, " SELL-side=", ddSellCount, 
                " | Threshold constant=", DoubleToString(InpHedge_DDTriggerPct, 1), "%");
   }

   if(recovered > 0 || orphansClosed > 0)
      Print("RECOVER COMPLETE: ", recovered, " sets recovered, ", orphansClosed,
            " orphan grid orders closed, cycleGen=", g_cycleGeneration);
}

//+------------------------------------------------------------------+
//| Detect orphan hedge grid orders and set warning flag               |
//+------------------------------------------------------------------+
void DetectOrphanHedgeOrders()
{
   g_hedgeOrphanWarning = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      string comment = PositionGetString(POSITION_COMMENT);
      if(StringFind(comment, "GM_HG") < 0) continue;
      
      bool belongsToActive = false;
      for(int h = 0; h < MAX_HEDGE_SETS; h++)
      {
         string prefix = "GM_HG" + IntegerToString(h + 1);
         if(StringFind(comment, prefix) >= 0 && g_hedgeSets[h].active)
         { belongsToActive = true; break; }
      }
      
      if(!belongsToActive)
      {
         g_hedgeOrphanWarning = true;
         Print("WARNING: Orphan hedge grid order detected! ticket=", ticket, " comment=", comment);
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| Count positions for a specific orphan generation                   |
//+------------------------------------------------------------------+
void CountOrphanPositions(int gen, int &buyCount, int &sellCount,
                          int &gridLossBuyCount, int &gridLossSellCount,
                          int &maxGridLevelBuy, int &maxGridLevelSell)
{
   buyCount = 0; sellCount = 0;
   gridLossBuyCount = 0; gridLossSellCount = 0;
   maxGridLevelBuy = 0; maxGridLevelSell = 0;
   
   string prefix = GenPrefix(gen);
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(IsTicketBound(ticket)) continue;
      
      string comment = PositionGetString(POSITION_COMMENT);
      if(IsHedgeComment(comment)) continue;
      
      // Must start with this gen's prefix
      if(StringFind(comment, prefix + "_") != 0) continue;
      
      // Verify exact gen (e.g. "GM_" should not match "GM1_")
      int extractedGen = ExtractGeneration(comment);
      if(extractedGen != gen) continue;
      
      long posType = PositionGetInteger(POSITION_TYPE);
      
      if(posType == POSITION_TYPE_BUY)
      {
         buyCount++;
         if(StringFind(comment, "_GL") >= 0)
         {
            gridLossBuyCount++;
            // Extract grid level from comment (e.g. GM_GL#3 → 3)
            int hashPos = StringFind(comment, "#");
            if(hashPos >= 0)
            {
               int level = (int)StringToInteger(StringSubstr(comment, hashPos + 1));
               if(level > maxGridLevelBuy) maxGridLevelBuy = level;
            }
         }
      }
      else if(posType == POSITION_TYPE_SELL)
      {
         sellCount++;
         if(StringFind(comment, "_GL") >= 0)
         {
            gridLossSellCount++;
            int hashPos = StringFind(comment, "#");
            if(hashPos >= 0)
            {
               int level = (int)StringToInteger(StringSubstr(comment, hashPos + 1));
               if(level > maxGridLevelSell) maxGridLevelSell = level;
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Find last order price for a specific orphan generation             |
//+------------------------------------------------------------------+
void FindLastOrphanOrder(int gen, ENUM_POSITION_TYPE side, double &outPrice, datetime &outTime, int &outGridLevel)
{
   outPrice = 0;
   outTime = 0;
   outGridLevel = 0;
   datetime latestTime = 0;
   
   string prefix = GenPrefix(gen);
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) != side) continue;
      if(IsTicketBound(ticket)) continue;
      
      string comment = PositionGetString(POSITION_COMMENT);
      if(IsHedgeComment(comment)) continue;
      if(StringFind(comment, prefix + "_") != 0) continue;
      
      int extractedGen = ExtractGeneration(comment);
      if(extractedGen != gen) continue;
      
      // Must be _INIT or _GL
      if(StringFind(comment, "_INIT") < 0 && StringFind(comment, "_GL") < 0) continue;
      
      datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
      if(openTime > latestTime)
      {
         latestTime = openTime;
         outPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         outTime = openTime;
         
         int hashPos = StringFind(comment, "#");
         if(hashPos >= 0)
            outGridLevel = (int)StringToInteger(StringSubstr(comment, hashPos + 1));
         else
            outGridLevel = 0;
      }
   }
}

//+------------------------------------------------------------------+
//| Find max lot on side for a specific orphan generation              |
//+------------------------------------------------------------------+
double FindMaxLotOrphan(int gen, ENUM_POSITION_TYPE side)
{
   double maxLot = 0;
   string prefix = GenPrefix(gen);
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) != side) continue;
      if(IsTicketBound(ticket)) continue;
      
      string comment = PositionGetString(POSITION_COMMENT);
      if(IsHedgeComment(comment)) continue;
      if(StringFind(comment, prefix + "_") != 0) continue;
      
      int extractedGen = ExtractGeneration(comment);
      if(extractedGen != gen) continue;
      
      if(StringFind(comment, "_GL") >= 0 || StringFind(comment, "_INIT") >= 0)
      {
         double lot = PositionGetDouble(POSITION_VOLUME);
         if(lot > maxLot) maxLot = lot;
      }
   }
   return maxLot;
}

//+------------------------------------------------------------------+
//| Scan for orphan generations (orders from older gens not bound)      |
//+------------------------------------------------------------------+
void ScanOrphanGenerations()
{
   g_activeOrphanGroupCount = 0;
   
   // Reset all groups
   for(int g = 0; g < MAX_ORPHAN_GROUPS; g++)
   {
      g_orphanGroups[g].active = false;
      g_orphanGroups[g].generation = -1;
      g_orphanGroups[g].buyCount = 0;
      g_orphanGroups[g].sellCount = 0;
      g_orphanGroups[g].gridLossBuyCount = 0;
      g_orphanGroups[g].gridLossSellCount = 0;
      g_orphanGroups[g].maxGridLevelBuy = 0;
      g_orphanGroups[g].maxGridLevelSell = 0;
   }
   
   // Scan all positions → group by generation
   int foundGens[];
   int foundGenCount = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      string comment = PositionGetString(POSITION_COMMENT);
      int gen = -1;

      // v6.61: Recovery seed (logically stripped hedge remainder) → treat as orphan of its bound gen
      if(IsRecoverySeedTicket(ticket))
      {
         gen = GetRecoverySeedGen(ticket);
      }
      else
      {
         if(IsTicketBound(ticket)) continue;
         if(IsHedgeComment(comment)) continue;
         if(StringFind(comment, "GM") != 0) continue;
         gen = ExtractGeneration(comment);
      }

      if(gen < 0) continue;
      if(gen == g_cycleGeneration) continue;  // skip current generation

      // Check if this gen is bound to an active hedge set
      bool isBoundGen = false;
      for(int h = 0; h < MAX_HEDGE_SETS; h++)
      {
         if(g_hedgeSets[h].active && g_hedgeSets[h].boundGeneration == gen)
         { isBoundGen = true; break; }
      }
      if(isBoundGen) continue;

      // Check if gen already in foundGens
      bool exists = false;
      for(int f = 0; f < foundGenCount; f++)
      {
         if(foundGens[f] == gen) { exists = true; break; }
      }
      if(!exists && foundGenCount < MAX_ORPHAN_GROUPS)
      {
         ArrayResize(foundGens, foundGenCount + 1);
         foundGens[foundGenCount] = gen;
         foundGenCount++;
      }
   }
   
   // For each found gen, count positions
   for(int f = 0; f < foundGenCount && f < MAX_ORPHAN_GROUPS; f++)
   {
      int gen = foundGens[f];
      int bc = 0, sc = 0, glb = 0, gls = 0, mglb = 0, mgls = 0;
      CountOrphanPositions(gen, bc, sc, glb, gls, mglb, mgls);
      
      if(bc > 0 || sc > 0)
      {
         g_orphanGroups[f].generation = gen;
         g_orphanGroups[f].active = true;
         g_orphanGroups[f].buyCount = bc;
         g_orphanGroups[f].sellCount = sc;
         g_orphanGroups[f].gridLossBuyCount = glb;
         g_orphanGroups[f].gridLossSellCount = gls;
         g_orphanGroups[f].maxGridLevelBuy = mglb;
         g_orphanGroups[f].maxGridLevelSell = mgls;
         g_activeOrphanGroupCount++;
         
         Print("ORPHAN SCAN: Gen", gen, " (", GenPrefix(gen), ") — B:", bc, " S:", sc,
               " GL_B:", glb, " GL_S:", gls, " MaxGL_B:", mglb, " MaxGL_S:", mgls);
      }
   }
   
   if(g_activeOrphanGroupCount == 0)
      Print("ORPHAN SCAN: No orphan generations found.");
}

//+------------------------------------------------------------------+
//| Manage orphan grid — open recovery grid orders for orphan gens     |
//+------------------------------------------------------------------+
void ManageOrphanGrid()
{
   if(g_activeOrphanGroupCount == 0) return;
   if(g_newOrderBlocked) return;
   if(NormalOrderCount() >= MaxOpenOrders) return;
   
   // Only work in Normal or Squeeze — not Expansion
   bool isExpansion = false;
   if(InpUseSqueezeFilter)
   {
      for(int sq = 0; sq < 3; sq++)
      {
         if(g_squeeze[sq].state == 2)
         { isExpansion = true; break; }
      }
   }
   if(isExpansion) return;
   
   // OnlyNewCandle check — same rule as normal grid
   if(GridLoss_OnlyNewCandle)
   {
      datetime barTime = iTime(_Symbol, PERIOD_CURRENT, 0);
      if(barTime == g_lastOrphanGridCandleTime) return;
    }
     
    // v6.40: Candle Confirmation — applied per-side inside the loop below
     
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   for(int g = 0; g < MAX_ORPHAN_GROUPS; g++)
   {
      if(!g_orphanGroups[g].active) continue;
      
      int gen = g_orphanGroups[g].generation;
      // v6.59: Sequential Recovery Owner — only the owner generation may run recovery grid
      if(InpHedge_SequentialRecovery && g_sequentialRecoveryActive
         && gen != g_sequentialRecoveryGen)
      {
         static datetime s_lastSeqSkipLog = 0;
         if(TimeCurrent() - s_lastSeqSkipLog >= 30)
         {
            Print("v6.59 SEQ WAIT: Skip orphan Gen", gen,
                  " (owner=Gen", g_sequentialRecoveryGen, ")");
            s_lastSeqSkipLog = TimeCurrent();
         }
         continue;
      }
      string prefix = GenPrefix(gen);
      
      // Re-count fresh each tick to detect if orders were closed
      int bc = 0, sc = 0, glb = 0, gls = 0, mglb = 0, mgls = 0;
      CountOrphanPositions(gen, bc, sc, glb, gls, mglb, mgls);
      
      // Update counts
      g_orphanGroups[g].buyCount = bc;
      g_orphanGroups[g].sellCount = sc;
      g_orphanGroups[g].gridLossBuyCount = glb;
      g_orphanGroups[g].gridLossSellCount = gls;
      g_orphanGroups[g].maxGridLevelBuy = mglb;
      g_orphanGroups[g].maxGridLevelSell = mgls;
      
      // Auto-cleanup: no orders left → deactivate
      if(bc == 0 && sc == 0)
      {
         Print("ORPHAN Gen", gen, " all orders closed. Deactivating group.");
         g_orphanGroups[g].active = false;
         g_activeOrphanGroupCount--;
         continue;
      }
      
      if(NormalOrderCount() >= MaxOpenOrders) return;
      // v6.57: use Recovery getters (falls back to GridLoss_* when Recovery_UseSeparate=false)
      int recMax = GetRecoveryMaxTrades();
      int recCC  = GetRecoveryCandleConfirm();
      if(glb >= recMax && gls >= recMax) continue;
      
      // === BUY side orphan grid ===
      if(bc > 0 && glb < recMax)
      {
          if(!g_squeezeBuyBlocked)
          {
             if(recCC > 0 && !HasCandleConfirmation(POSITION_TYPE_BUY, PERIOD_CURRENT, recCC)) { /* skip */ }
             else
             {
            double lastPrice = 0;
            datetime lastTime = 0;
            int lastLevel = 0;
            FindLastOrphanOrder(gen, POSITION_TYPE_BUY, lastPrice, lastTime, lastLevel);
            
            if(lastPrice > 0)
            {
               double distance = GetRecoveryGridDistancePoints(glb);  // v6.57
               if(distance > 0)
               {
                  double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                  if(currentPrice <= lastPrice - distance * point)
                  {
                     int nextLevel = mglb + 1;
                      // v6.61: cumulative-sum seed (closest level to InpRecovery_SeedTargetLots)
                      double seedLot = FindCumulativeSeedLot(gen, POSITION_TYPE_BUY, InpRecovery_SeedTargetLots);
                      double maxExisting = (seedLot > 0) ? seedLot : FindMaxLotOrphan(gen, POSITION_TYPE_BUY);
                      double lots = ComputeRecoveryGridLot(maxExisting, glb);  // v6.57
                     
                     string comment = prefix + "_GL#" + IntegerToString(nextLevel);
                      if(OpenOrder(ORDER_TYPE_BUY, lots, comment))
                      {
                         g_lastOrphanGridCandleTime = iTime(_Symbol, PERIOD_CURRENT, 0);
                         Print("ORPHAN/RECOVERY GRID: Opened BUY ", prefix, "_GL#", nextLevel,
                               " lots=", DoubleToString(lots, 2), " for Gen", gen);
                      }
                  }
               }
            }
             }
          }
       }
      
      // === SELL side orphan grid ===
      if(sc > 0 && gls < recMax)
      {
          if(!g_squeezeSellBlocked)
          {
             if(recCC > 0 && !HasCandleConfirmation(POSITION_TYPE_SELL, PERIOD_CURRENT, recCC)) { /* skip */ }
             else
             {
            double lastPrice = 0;
            datetime lastTime = 0;
            int lastLevel = 0;
            FindLastOrphanOrder(gen, POSITION_TYPE_SELL, lastPrice, lastTime, lastLevel);
            
            if(lastPrice > 0)
            {
               double distance = GetRecoveryGridDistancePoints(gls);  // v6.57
               if(distance > 0)
               {
                  double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                  if(currentPrice >= lastPrice + distance * point)
                  {
                     int nextLevel = mgls + 1;
                      // v6.61: cumulative-sum seed
                      double seedLot = FindCumulativeSeedLot(gen, POSITION_TYPE_SELL, InpRecovery_SeedTargetLots);
                      double maxExisting = (seedLot > 0) ? seedLot : FindMaxLotOrphan(gen, POSITION_TYPE_SELL);
                      double lots = ComputeRecoveryGridLot(maxExisting, gls);  // v6.57
                     
                     string comment = prefix + "_GL#" + IntegerToString(nextLevel);
                      if(OpenOrder(ORDER_TYPE_SELL, lots, comment))
                      {
                         g_lastOrphanGridCandleTime = iTime(_Symbol, PERIOD_CURRENT, 0);
                         Print("ORPHAN/RECOVERY GRID: Opened SELL ", prefix, "_GL#", nextLevel,
                               " lots=", DoubleToString(lots, 2), " for Gen", gen);
                       }
                   }
                }
             }
              }
           }
        }
    }
}

//+------------------------------------------------------------------+
//| v6.17: Check if hedge close is allowed for a specific set          |
//| Triple Gate: (1) Expansion Cycle, (2) Price Zone, (3) TP Distance  |
//| ALL trigger types must pass Gate 1 (Expansion + DD%)               |
//+------------------------------------------------------------------+
bool IsHedgeCloseAllowed(int h)
{
   // Gate 1: Expansion Cycle — mandatory for ALL trigger types (Expansion & DD%)
   if(g_hedgeSets[h].hedgedDuringExpansion)
   {
      // Case A: Hedge opened during Expansion → wait for all TFs Normal
      if(!IsAllSqueezeTFNormalStrict()) return false;
   }
   else
   {
      // Case B: Hedge opened during Normal/Squeeze → must see Expansion on biggest TF first, THEN all Normal
      if(!g_hedgeSets[h].seenExpansionSinceHedge) return false;
      if(!IsAllSqueezeTFNormalStrict()) return false;
   }
   
   // Gate 2: Price Zone — price must be outside zone (oldest bound ↔ hedge)
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double zoneHi = g_hedgeSets[h].zoneUpperPrice;
   double zoneLo = g_hedgeSets[h].zoneLowerPrice;
   
   // If zone is not set (both 0) → skip zone check (recovery scenario)
   if(zoneHi > 0 && zoneLo > 0)
   {
      if(bid > zoneLo && bid < zoneHi) return false;  // IN ZONE → block
      
      // Gate 3: TP Distance — must be N points away from zone edge
      double pts = _Point;
      if(InpHedge_CloseMinPoints > 0)
      {
         if(bid >= zoneHi)
         {
            // Price exited above zone
            if((bid - zoneHi) / pts < InpHedge_CloseMinPoints) return false;
         }
         else
         {
            // Price exited below zone
            if((zoneLo - bid) / pts < InpHedge_CloseMinPoints) return false;
         }
      }
   }
   
   return true;
}

void ManageHedgeSets()
{
   // Detect orphan hedge grid orders every tick
   DetectOrphanHedgeOrders();
   
   // v6.15: Reverse Hedge disabled — always unlock balanced lock
   g_hedgeBalancedLock = false;
   
   // v6.15: Reverse Hedge management removed (no ManageReverseHedge / CheckAndOpenReverseHedge)
   
   // v6.59: Sequential Recovery Owner — clear when owner generation is fully closed
   g_sequentialRecoveryCompletedThisTick = false;
   if(g_sequentialRecoveryActive && IsSequentialRecoveryComplete())
      ClearSequentialRecoveryOwner("owner gen flat");
   
   bool sequentialActed = false;  // v6.58: only one hedge set may close/recover per tick
   for(int h = 0; h < MAX_HEDGE_SETS; h++)
   {
      if(!g_hedgeSets[h].active) continue;

      // Refresh bound tickets — remove any that were closed externally
      RefreshBoundTickets(h);
      
      // v6.15: Track expansion on TF index 2 (largest) every tick
      if(!g_hedgeSets[h].seenExpansionSinceHedge)
      {
         if(g_squeeze[2].state == 2)  // EXPANSION detected on biggest TF
            g_hedgeSets[h].seenExpansionSinceHedge = true;
      }

      // Verify hedge ticket still exists
      bool hedgeExists = false;
      if(g_hedgeSets[h].hedgeTicket > 0 && PositionSelectByTicket(g_hedgeSets[h].hedgeTicket))
      {
         hedgeExists = true;
         g_hedgeSets[h].hedgeLots = PositionGetDouble(POSITION_VOLUME);
      }

      if(!hedgeExists && !g_hedgeSets[h].gridMode)
      {
         // Hedge was closed externally (accumulate close, manual, etc.)
         Print("HEDGE Set#", h + 1, " ticket no longer exists. Deactivating.");
         CloseAllHedgeGridOrders(h);
         int extGen = g_hedgeSets[h].boundGeneration;  // v6.59: capture before clear
         SaveBoundTicketsToPrevHedged(h);  // v6.26: remember released tickets
         g_hedgeSets[h].active = false;
         g_hedgeSets[h].boundTicketCount = 0;
         ArrayResize(g_hedgeSets[h].boundTickets, 0);
            g_hedgeSetCount--;
            g_lastHedgeCloseTime = TimeCurrent();  // v6.25: cooldown after set close
            // v6.59: claim recovery owner if released bound orders remain open
            SetSequentialRecoveryOwner(h, extGen);
            // v6.27: Safe reset — only if truly flat
            TryResetCycleStateIfFlat("external close");
          continue;
      }

      // === v6.15: Triple-Gate Close Check ===
      // All recovery actions (matching, grid, partial close) require gate pass
      if(!IsHedgeCloseAllowed(h))
      {
         // Reset matchingDone so it re-runs when gate opens
         g_hedgeSets[h].matchingDone = false;
         continue;  // Skip all close/grid logic for this set
      }
      
      // === Gate passed — close logic allowed ===

      // === v6.57/v6.58/v6.59/v6.67/v6.70: Sequential Recovery ===
      // v6.59: If a recovery owner exists → block ALL hedge-set release/recovery
      //        until that owner generation is fully closed. Hedges may still open.
      // v6.58: Otherwise enforce one-set-per-tick on the OLDEST active set.
      // v6.70: STRICT FIFO is now default. Profit-bypass is gated behind
      //        InpHedge_AllowProfitBypass and STILL requires set to be the oldest.
      bool seqBypass_profitClose = false;
      if(InpHedge_AllowProfitBypass && InpHedge_UseMatchingClose && !g_hedgeSets[h].gridMode)
      {
         double _hPnL = 0;
         if(hedgeExists) _hPnL = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
         if(_hPnL > InpHedge_MatchMinProfit) seqBypass_profitClose = true;
      }

      // v6.69: Time-based unlock delay — กันปลด set ถัดไปทันทีหลังชุดก่อนเพิ่งปิด
      if(InpHedge_SequentialRecovery && IsSequentialUnlockDelayActive())
      {
         g_hedgeSets[h].matchingDone = false;
         static datetime _lastSeqDelayLog = 0;
         if(TimeCurrent() - _lastSeqDelayLog >= 15)
         {
            Print("v6.69 SEQ DELAY HOLD: Set#", h+1, " deferred — remain ",
                  GetSequentialUnlockRemainSec(), " sec (", g_sequentialUnlockReason, ")");
            _lastSeqDelayLog = TimeCurrent();
         }
         continue;
      }

      if(InpHedge_SequentialRecovery)
      {
         // v6.59: Owner active → block every set's release/recovery this tick (even profit bypass)
         if(g_sequentialRecoveryActive && !seqBypass_profitClose)
         {
            g_hedgeSets[h].matchingDone = false;
            continue;
         }
         // v6.70: even with bypass enabled, owner lock still blocks unless this IS the oldest
         //        (oldest check below also applies)
         // v6.59: Just completed handoff this tick → wait one more tick
         if(g_sequentialRecoveryCompletedThisTick)
         {
            g_hedgeSets[h].matchingDone = false;
            continue;
         }
         // v6.58: if any set already acted this tick → block all remaining sets
         if(sequentialActed)
         {
            g_hedgeSets[h].matchingDone = false;
            continue;
         }
         // v6.70: STRICT FIFO — only the oldest active set may proceed.
         //        Profit bypass NO LONGER skips this check; it only skips owner lock above.
         int oldestActiveIdx = FindOldestActiveHedgeSet();
         if(oldestActiveIdx >= 0 && h != oldestActiveIdx)
         {
            g_hedgeSets[h].matchingDone = false;
            static datetime _lastFifoLog = 0;
            if(TimeCurrent() - _lastFifoLog >= 30)
            {
               double _profit = 0;
               if(hedgeExists) _profit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
               Print("v6.70 STRICT FIFO BLOCK: Set#", h+1, " profit=$",
                     DoubleToString(_profit,2), " deferred — Set#", oldestActiveIdx+1, " must complete first");
               _lastFifoLog = TimeCurrent();
            }
            continue;
         }
         // This set IS the oldest → mark that we're acting on it this tick
         if(seqBypass_profitClose && g_sequentialRecoveryActive)
            Print("v6.70 SEQ BYPASS (oldest+profit): Set#", h+1, " allowed despite owner Gen", g_sequentialRecoveryGen);
         sequentialActed = true;
      }


      // If in grid mode → execute grid
      if(g_hedgeSets[h].gridMode)
      {
         ManageHedgeGridMode(h);
         continue;
      }
       
       // v6.52: If hedge recovery disabled → skip ALL recovery (only Balance Guard can close hedge)
       if(!InpHedge_UseMatchingClose)
          continue;
       
       // STEP 1 — Run matching/close cycle FIRST (before any grid entry)
       if(!g_hedgeSets[h].matchingDone)
       {
          double hedgePnL = 0;
          if(hedgeExists)
             hedgePnL = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);

           // Matching Close (hedge is profitable → close + match losses)
           if(hedgePnL > 0)
           {
              ManageHedgeMatchingClose(h);
              if(g_hedgeSets[h].active)
                 g_hedgeSets[h].matchingDone = true;
              continue;
           }

         // Average TP (hedge is in loss → try avg TP on bounds)
         if(g_hedgeSets[h].boundTicketCount > 0)
         {
            if(ManageHedgeBoundAvgTP(h))
            {
               if(g_hedgeSets[h].active)
                  g_hedgeSets[h].matchingDone = true;
               continue;
            }
         }

         // Partial Close LAST
         if(g_hedgeSets[h].boundTicketCount > 0)
         {
            ManageHedgePartialClose(h);
         }
         
         g_hedgeSets[h].matchingDone = true;
      }
      
      // STEP 2 — After matching done, try entering combined grid mode
      TryEnterCombinedGridMode(h);
   }
   
   // v6.16: Recalculate DD triggers based on remaining active DD sets
   if(InpHedge_TriggerMode == HEDGE_TRIGGER_DD_PERCENT)
   {
      int ddBuyCount = 0, ddSellCount = 0;
      for(int h = 0; h < MAX_HEDGE_SETS; h++)
      {
         if(!g_hedgeSets[h].active || g_hedgeSets[h].triggerType != 1) continue;
         if(g_hedgeSets[h].counterSide == POSITION_TYPE_BUY)
            ddBuyCount++;
         else
            ddSellCount++;
      }
       // v6.21: Threshold is constant per generation — no cumulative step needed
   }
}

//+------------------------------------------------------------------+
//| v6.11: Calculate NET lots of all orders and set balanced lock       |
//+------------------------------------------------------------------+
void UpdateHedgeBalancedLock()
{
   double totalBuyLots = 0, totalSellLots = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double vol = PositionGetDouble(POSITION_VOLUME);
      if(posType == POSITION_TYPE_BUY)  totalBuyLots += vol;
      if(posType == POSITION_TYPE_SELL) totalSellLots += vol;
   }
   
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double netDiff = MathAbs(totalBuyLots - totalSellLots);
   
   // Consider balanced if NET difference is less than 1 lot step
   if(netDiff < lotStep)
   {
      if(!g_hedgeBalancedLock)
      {
         g_hedgeBalancedLock = true;
         Print("HEDGE BALANCED LOCK: BuyLots=", DoubleToString(totalBuyLots, 2),
               " SellLots=", DoubleToString(totalSellLots, 2), " → TP/SL/Matching disabled");
      }
   }
   else
   {
      if(g_hedgeBalancedLock)
      {
         g_hedgeBalancedLock = false;
         Print("HEDGE BALANCED LOCK RELEASED: BuyLots=", DoubleToString(totalBuyLots, 2),
               " SellLots=", DoubleToString(totalSellLots, 2), " NET=", DoubleToString(netDiff, 2));
      }
   }
}

//+------------------------------------------------------------------+
//| v6.11: Calculate NET lots of all orders (both sides)               |
//+------------------------------------------------------------------+
void CalculateNetLots(double &totalBuyLots, double &totalSellLots)
{
   totalBuyLots = 0;
   totalSellLots = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double vol = PositionGetDouble(POSITION_VOLUME);
      if(posType == POSITION_TYPE_BUY)  totalBuyLots += vol;
      if(posType == POSITION_TYPE_SELL) totalSellLots += vol;
   }
}

//+------------------------------------------------------------------+
//| v6.11: Check if a ticket is in the reverse hedge array             |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| v6.12: Check if any reverse hedge order is currently profitable     |
//| Used as guard: must matching-close profitable reverses BEFORE grid  |
//+------------------------------------------------------------------+
bool HasProfitableReverseOrders()
{
   for(int i = 0; i < g_reverseHedgeCount; i++)
   {
      if(PositionSelectByTicket(g_reverseHedgeTickets[i]))
      {
         double pnl = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
         if(pnl > 0) return true;
      }
   }
   return false;
}

bool IsInReverseHedgeArray(ulong ticket)
{
   for(int i = 0; i < g_reverseHedgeCount; i++)
   {
      if(g_reverseHedgeTickets[i] == ticket) return true;
   }
   return false;
}

//+------------------------------------------------------------------+
//| v6.13: Strict gate — ALL 3 squeeze TFs must be NORMAL (state 0)    |
//| Uses stable state from closed bar (set in UpdateSqueezeState)       |
//+------------------------------------------------------------------+
bool IsAllSqueezeTFNormalStrict()
{
   if(!InpUseSqueezeFilter) return true;  // filter disabled → always "normal"
   for(int sq = 0; sq < 3; sq++)
   {
      if(g_squeeze[sq].state == 2)  // EXPANSION
         return false;
      // state 1 (SQUEEZE) is ok — only EXPANSION blocks recovery
   }
   return true;
}

//+------------------------------------------------------------------+
//| v6.14: Count expansion TFs with directional agreement check        |
//| Returns expansion count. outDir = unified direction (1=BUY,-1=SELL)|
//| outDir = 0 if expansions conflict (BUY+SELL mix) → block entry     |
//+------------------------------------------------------------------+
int CountDirectionalExpansion(int &outDir)
{
   int expCount = 0;
   int buyExp = 0, sellExp = 0;
   outDir = 0;
   
   for(int sq = 0; sq < 3; sq++)
   {
      if(g_squeeze[sq].state == 2)  // EXPANSION
      {
         expCount++;
         if(g_squeeze[sq].direction == 1)  buyExp++;
         else if(g_squeeze[sq].direction == -1) sellExp++;
      }
   }
   
   // If both BUY and SELL expansions exist → conflict → outDir = 0
   if(buyExp > 0 && sellExp > 0) { outDir = 0; return expCount; }
   
   if(buyExp > 0) outDir = 1;
   else if(sellExp > 0) outDir = -1;
   
   return expCount;
}

//+------------------------------------------------------------------+
//| v6.13: Centralized gate to enter combined grid mode                 |
//| ALL conditions must be met before gridMode can be set to true       |
//+------------------------------------------------------------------+
bool TryEnterCombinedGridMode(int h)
{
   if(!g_hedgeSets[h].active) return false;
   if(g_hedgeSets[h].gridMode) return false;  // already in grid
   
   // Gate 1: v6.15 — Close gate must be passed (replaces old allTFNormal check)
   // IsHedgeCloseAllowed already checked in ManageHedgeSets() before calling this
   
   // Gate 2: No bound orders remaining
   if(g_hedgeSets[h].boundTicketCount > 0) return false;
   
   // Gate 3: v6.15 — Reverse Hedge removed, skip HasProfitableReverseOrders()
   
   // Gate 4: Matching must have been attempted this normal phase
   if(!g_hedgeSets[h].matchingDone) return false;
   
   // Gate 5: Hedge ticket must still exist
   bool hedgeExists = false;
   double hedgeLots = 0;
   if(g_hedgeSets[h].hedgeTicket > 0 && PositionSelectByTicket(g_hedgeSets[h].hedgeTicket))
   {
      hedgeExists = true;
      hedgeLots = PositionGetDouble(POSITION_VOLUME);
   }
   
   if(!hedgeExists) return false;  // v6.15: no reverse → nothing to recover
   
   double totalLots = hedgeLots;
   
   g_hedgeSets[h].gridMode = true;
   g_hedgeSets[h].gridLevel = CalculateEquivGridLevel(totalLots);
   
   Print("v6.15 GRID ENTRY: Set#", h + 1, " entering Grid Mode. TotalLots=",
         DoubleToString(totalLots, 2), " GridLevel=", g_hedgeSets[h].gridLevel);
   return true;
}

//+------------------------------------------------------------------+
//| v6.11: Add ticket to reverse hedge array                           |
//+------------------------------------------------------------------+
void AddReverseHedgeTicket(ulong ticket)
{
   if(g_reverseHedgeCount >= MAX_REVERSE_HEDGES)
   {
      Print("WARNING: MAX_REVERSE_HEDGES reached (", MAX_REVERSE_HEDGES, "). Cannot add more.");
      return;
   }
   g_reverseHedgeTickets[g_reverseHedgeCount] = ticket;
   g_reverseHedgeCount++;
}

//+------------------------------------------------------------------+
//| v6.11: Remove ticket from reverse hedge array                      |
//+------------------------------------------------------------------+
void RemoveReverseHedgeTicket(ulong ticket)
{
   for(int i = 0; i < g_reverseHedgeCount; i++)
   {
      if(g_reverseHedgeTickets[i] == ticket)
      {
         // Shift remaining tickets down
         for(int j = i; j < g_reverseHedgeCount - 1; j++)
            g_reverseHedgeTickets[j] = g_reverseHedgeTickets[j + 1];
         g_reverseHedgeCount--;
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| v6.11: Check and open Reverse Hedge — NET-based, multiple allowed  |
//+------------------------------------------------------------------+
void CheckAndOpenReverseHedge()
{
   if(!InpHedge_ReverseEnable) return;
   
   // Must have at least one active hedge set
   int activeIdx = -1;
   for(int h = 0; h < MAX_HEDGE_SETS; h++)
   {
      if(g_hedgeSets[h].active)
      {
         activeIdx = h;
         break;
      }
   }
   if(activeIdx < 0) return;
   
   // v6.14: Determine current expansion direction — all expansion TFs must agree
   int bestDir = 0;
   int expCount = CountDirectionalExpansion(bestDir);
   // bestDir == 0 means conflict (BUY+SELL mix) → do not open reverse hedge
   if(expCount < InpHedge_ReverseMinTFConfirm || bestDir == 0) return;
   
   // Check if expansion is OPPOSITE to the hedge side
   ENUM_POSITION_TYPE hedgeSide = g_hedgeSets[activeIdx].hedgeSide;
   bool needReverse = false;
   ENUM_POSITION_TYPE reverseSide = POSITION_TYPE_BUY;
   
   if(hedgeSide == POSITION_TYPE_SELL && bestDir == 1)  // hedge SELL, now bullish
   {
      needReverse = true;
      reverseSide = POSITION_TYPE_BUY;
   }
   else if(hedgeSide == POSITION_TYPE_BUY && bestDir == -1)  // hedge BUY, now bearish
   {
      needReverse = true;
      reverseSide = POSITION_TYPE_SELL;
   }
   
   if(!needReverse) return;
   
   // === v6.11: Calculate NET of ALL orders (both sides) ===
   double totalBuyLots = 0, totalSellLots = 0;
   CalculateNetLots(totalBuyLots, totalSellLots);
   
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double netDiff = MathAbs(totalBuyLots - totalSellLots);
   
   // If NET is zero (balanced) → no reverse needed
   if(netDiff < lotStep)
   {
      // Already balanced — g_hedgeBalancedLock handles TP/SL disable
      return;
   }
   
   // Determine which side needs more lots
   // If reverseSide is BUY and totalBuy < totalSell → need more BUY
   // If reverseSide is SELL and totalSell < totalBuy → need more SELL
   bool sideMatches = false;
   if(reverseSide == POSITION_TYPE_BUY && totalBuyLots < totalSellLots)
      sideMatches = true;
   if(reverseSide == POSITION_TYPE_SELL && totalSellLots < totalBuyLots)
      sideMatches = true;
   
   if(!sideMatches) return;  // expansion direction doesn't match the weak side
   
   // Normalize lot size
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double openLots = MathFloor(netDiff / lotStep) * lotStep;
   openLots = MathMax(minLot, MathMin(maxLot, openLots));
   
   if(openLots < minLot) return;
   
   // Open reverse hedge order
   ENUM_ORDER_TYPE orderType = (reverseSide == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   string comment = "GM_RHEDGE_" + IntegerToString(g_reverseHedgeCount + 1);
   
   if(OpenOrder(orderType, openLots, comment))
   {
      // Find the ticket we just opened
      ulong newTicket = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if(PositionGetString(POSITION_COMMENT) == comment)
         {
            newTicket = ticket;
            break;
         }
      }
      
      if(newTicket > 0)
         AddReverseHedgeTicket(newTicket);
      
      string sideStr = (reverseSide == POSITION_TYPE_BUY) ? "BUY" : "SELL";
      Print("REVERSE HEDGE #", g_reverseHedgeCount, " OPENED: ", sideStr, " ", DoubleToString(openLots, 2),
            " lots (NET diff=", DoubleToString(netDiff, 2), 
            " BuyL=", DoubleToString(totalBuyLots, 2), " SellL=", DoubleToString(totalSellLots, 2), ")");
   }
}

//+------------------------------------------------------------------+
//| v6.11: Manage Reverse Hedges — global matching close when Normal   |
//+------------------------------------------------------------------+
void ManageReverseHedge()
{
   if(g_reverseHedgeCount == 0) return;
   
   // Clean up tickets that no longer exist
   for(int i = g_reverseHedgeCount - 1; i >= 0; i--)
   {
      if(!PositionSelectByTicket(g_reverseHedgeTickets[i]))
      {
         Print("REVERSE HEDGE: Ticket ", g_reverseHedgeTickets[i], " no longer exists. Removing.");
         RemoveReverseHedgeTicket(g_reverseHedgeTickets[i]);
      }
   }
   
   if(g_reverseHedgeCount == 0) return;
   
   // Check if market is Normal (no expansion on any TF)
   bool hasExpansion = false;
   for(int sq = 0; sq < 3; sq++)
   {
      if(g_squeeze[sq].state == 2)
      {
         hasExpansion = true;
         break;
      }
   }
   
   if(hasExpansion) return;  // still in expansion — keep locking
   
   // === State is Normal → perform GLOBAL matching close ===
   // Scan ALL orders (no set distinction): profit vs loss
   ulong profitTickets[];
   double profitValues[];
   ulong lossTickets[];
   double lossValues[];
   datetime lossTimes[];
   int profitCount = 0, lossCount = 0;
   double totalProfit = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      
      double pnl = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      
      if(pnl > 0)
      {
         ArrayResize(profitTickets, profitCount + 1);
         ArrayResize(profitValues, profitCount + 1);
         profitTickets[profitCount] = ticket;
         profitValues[profitCount] = pnl;
         totalProfit += pnl;
         profitCount++;
      }
      else if(pnl < 0)
      {
         ArrayResize(lossTickets, lossCount + 1);
         ArrayResize(lossValues, lossCount + 1);
         ArrayResize(lossTimes, lossCount + 1);
         lossTickets[lossCount] = ticket;
         lossValues[lossCount] = pnl;
         lossTimes[lossCount] = (datetime)PositionGetInteger(POSITION_TIME);
         lossCount++;
      }
   }
   
   // Budget = total profit - min profit to keep
   double budget = totalProfit - InpHedge_ReverseMatchMinProfit;
   if(budget <= 0)
   {
      // v6.12: No profit budget → close only PROFITABLE reverse hedges, keep losing ones
      Print("REVERSE HEDGE: No profit budget ($", DoubleToString(totalProfit, 2), 
            ") — closing profitable reverse hedges only");
      for(int r = g_reverseHedgeCount - 1; r >= 0; r--)
      {
         if(PositionSelectByTicket(g_reverseHedgeTickets[r]))
         {
            double rpnl = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
            if(rpnl > 0)
            {
               trade.PositionClose(g_reverseHedgeTickets[r]);
               RemoveReverseHedgeTicket(g_reverseHedgeTickets[r]);
               Sleep(50);
            }
         }
      }
      g_hedgeBalancedLock = false;
      if(g_reverseHedgeCount == 0)
         Print("ALL REVERSE HEDGES CLOSED — state reset");
      else
         Print("REVERSE HEDGE: ", g_reverseHedgeCount, " losing reverse orders remain for grid recovery");
      return;
   }
   
   // Sort losses by open time ascending (oldest first)
   for(int a = 0; a < lossCount - 1; a++)
   {
      for(int b = a + 1; b < lossCount; b++)
      {
         if(lossTimes[b] < lossTimes[a])
         {
            double tmpV = lossValues[a]; lossValues[a] = lossValues[b]; lossValues[b] = tmpV;
            ulong tmpT = lossTickets[a]; lossTickets[a] = lossTickets[b]; lossTickets[b] = tmpT;
            datetime tmpD = lossTimes[a]; lossTimes[a] = lossTimes[b]; lossTimes[b] = tmpD;
         }
      }
   }
   
   // Budget-based matching: close losses oldest first
   double cumLoss = 0;
   int closedLoss = 0;
   for(int l = 0; l < lossCount; l++)
   {
      double absLoss = MathAbs(lossValues[l]);
      if(cumLoss + absLoss <= budget)
      {
         trade.PositionClose(lossTickets[l]);
         cumLoss += absLoss;
         closedLoss++;
         Sleep(50);
         
         // Also remove from bound tickets if applicable
         for(int h = 0; h < MAX_HEDGE_SETS; h++)
         {
            if(g_hedgeSets[h].active)
               RemoveBoundTicket(h, lossTickets[l]);
         }
      }
   }
   
   Print("REVERSE HEDGE GLOBAL MATCHING: totalProfit=$", DoubleToString(totalProfit, 2),
         " budget=$", DoubleToString(budget, 2),
         " closed ", closedLoss, " loss orders ($", DoubleToString(cumLoss, 2), ")");
   
   // v6.12: Close only PROFITABLE orders (including profitable reverse hedges)
   // Losing reverse hedges stay open → they will enter combined grid recovery
   for(int p = 0; p < profitCount; p++)
   {
      if(PositionSelectByTicket(profitTickets[p]))
      {
         // Check if this is a reverse hedge — if so, remove from array
         if(IsInReverseHedgeArray(profitTickets[p]))
            RemoveReverseHedgeTicket(profitTickets[p]);
         
         trade.PositionClose(profitTickets[p]);
         Sleep(50);
      }
   }
   
   // v6.12: Only reset balanced lock; do NOT zero g_reverseHedgeCount
   // Losing reverse orders may still remain in the array
   g_hedgeBalancedLock = false;
   
   if(g_reverseHedgeCount > 0)
      Print("REVERSE HEDGE: ", g_reverseHedgeCount, " losing reverse orders remain for combined grid recovery");
   
   // === v6.12: Setup combined grid recovery for remaining orders ===
   CheckAndSetupDualTrackRecovery();
   
   Print("REVERSE HEDGE RECOVERY COMPLETE — dual-track check done, remaining reverses: ", g_reverseHedgeCount);
}

//+------------------------------------------------------------------+
//| v6.11: Setup dual-track grid recovery after global matching close  |
//+------------------------------------------------------------------+
void CheckAndSetupDualTrackRecovery()
{
   // v6.13: This function now ONLY sets up combinedGridMode data (lots/level)
   // It does NOT set gridMode = true directly — that's handled by TryEnterCombinedGridMode()
   for(int h = 0; h < MAX_HEDGE_SETS; h++)
   {
      if(!g_hedgeSets[h].active) continue;
      
      // Refresh bound tickets
      RefreshBoundTickets(h);
      
      // Check if main hedge still exists
      bool hedgeExists = false;
      double hedgeLots = 0;
      if(g_hedgeSets[h].hedgeTicket > 0 && PositionSelectByTicket(g_hedgeSets[h].hedgeTicket))
      {
         hedgeExists = true;
         hedgeLots = PositionGetDouble(POSITION_VOLUME);
      }
      
      // Count remaining reverse hedge orders for this set
      double reverseLots = 0;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         string cmt = PositionGetString(POSITION_COMMENT);
         if(StringFind(cmt, "GM_RHEDGE") >= 0)
            reverseLots += PositionGetDouble(POSITION_VOLUME);
      }
      
      // Setup combined grid data (but don't activate gridMode yet)
      if(hedgeExists || reverseLots > 0)
      {
         double combinedLots = hedgeLots + reverseLots;
         if(combinedLots > 0)
         {
            g_hedgeSets[h].combinedGridMode = true;
            g_hedgeSets[h].combinedLots = combinedLots;
            g_hedgeSets[h].combinedGridLevel = CalculateEquivGridLevel(combinedLots);
            
            Print("v6.13 DUAL-TRACK: Set#", h + 1, " combined data prepared. CombinedLots=",
                  DoubleToString(combinedLots, 2), " (hedge=", DoubleToString(hedgeLots, 2),
                  " reverse=", DoubleToString(reverseLots, 2), ") Level=",
                  g_hedgeSets[h].combinedGridLevel,
                  " | gridMode deferred to TryEnterCombinedGridMode()");
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Average TP for Bound Orders — close profitable bounds + partial   |
//| close hedge proportionally (shred, not full close)                 |
//+------------------------------------------------------------------+
bool ManageHedgeBoundAvgTP(int idx)
{
   if(InpHedge_BoundAvgTPPoints <= 0) return false;
   if(g_hedgeSets[idx].boundTicketCount == 0) return false;
   if(!g_hedgeSets[idx].active) return false;

   // Calculate weighted average price of bound orders
   double totalWeighted = 0;
   double totalLots = 0;
   ENUM_POSITION_TYPE boundSide = g_hedgeSets[idx].counterSide;

   for(int b = 0; b < g_hedgeSets[idx].boundTicketCount; b++)
   {
      ulong ticket = g_hedgeSets[idx].boundTickets[b];
      if(!PositionSelectByTicket(ticket)) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != boundSide) continue;

      double lots = PositionGetDouble(POSITION_VOLUME);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      totalWeighted += lots * openPrice;
      totalLots += lots;
   }

   if(totalLots <= 0) return false;

   double avgPrice = totalWeighted / totalLots;
   double tpDistance = InpHedge_BoundAvgTPPoints * _Point;

   // Check if price reached avg TP
   bool tpReached = false;
   if(boundSide == POSITION_TYPE_BUY)
      tpReached = (SymbolInfoDouble(_Symbol, SYMBOL_BID) >= avgPrice + tpDistance);
   else
      tpReached = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) <= avgPrice - tpDistance);

   if(!tpReached) return false;

   // v6.55: TP reached → do NOT close bound orders, release them as recovery instead
   // Only close hedge order and deactivate set — bound orders stay open
   Print("HEDGE AVG TP Set#", idx + 1, " v6.55: avgPrice=", DoubleToString(avgPrice, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS)),
         " target=", InpHedge_BoundAvgTPPoints, "pts REACHED → releasing ", g_hedgeSets[idx].boundTicketCount, " bound orders to recovery");

   // Close hedge order
   trade.PositionClose(g_hedgeSets[idx].hedgeTicket);
   CloseAllHedgeGridOrders(idx);
   int avgGen = g_hedgeSets[idx].boundGeneration;  // v6.59: capture before clear
   SaveBoundTicketsToPrevHedged(idx);
   g_hedgeSets[idx].active = false;
   g_hedgeSets[idx].boundTicketCount = 0;
   ArrayResize(g_hedgeSets[idx].boundTickets, 0);
   g_hedgeSetCount--;
   g_lastHedgeCloseTime = TimeCurrent();
   SetSequentialRecoveryOwner(idx, avgGen);  // v6.59: claim recovery owner
   TryResetCycleStateIfFlat("AvgTP release");
   Sleep(100);

   return true;
}

//+------------------------------------------------------------------+
//| Scenario 1: Hedge in profit + expansion ended → match with losses  |
//| Now uses boundTickets[] for set-specific isolation                  |
//+------------------------------------------------------------------+
void ManageHedgeMatchingClose(int idx)
{
   if(!PositionSelectByTicket(g_hedgeSets[idx].hedgeTicket)) return;

   double hedgeProfit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   if(hedgeProfit <= 0) return;

   // v6.12: Include profitable reverse orders in budget
   double reverseProfit = 0;
   ulong profitableReverseTickets[];
   int profitableReverseCount = 0;
   for(int r = 0; r < g_reverseHedgeCount; r++)
   {
      if(PositionSelectByTicket(g_reverseHedgeTickets[r]))
      {
         double rpnl = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
         if(rpnl > 0)
         {
            reverseProfit += rpnl;
            ArrayResize(profitableReverseTickets, profitableReverseCount + 1);
            profitableReverseTickets[profitableReverseCount] = g_reverseHedgeTickets[r];
            profitableReverseCount++;
         }
      }
   }

   double totalBudgetProfit = hedgeProfit + reverseProfit;
   double budget = totalBudgetProfit - InpHedge_MatchMinProfit;
   if(budget <= 0) return;

   // Collect loss orders ONLY from this set's boundTickets (oldest first)
   ulong lossTickets[];
   double lossValues[];
   datetime lossTimes[];
   int lossCount = 0;

   for(int b = 0; b < g_hedgeSets[idx].boundTicketCount; b++)
   {
      ulong ticket = g_hedgeSets[idx].boundTickets[b];
      if(!PositionSelectByTicket(ticket)) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != g_hedgeSets[idx].counterSide) continue;

      double pnl = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      if(pnl >= 0) continue;  // only loss orders

      ArrayResize(lossTickets, lossCount + 1);
      ArrayResize(lossValues, lossCount + 1);
      ArrayResize(lossTimes, lossCount + 1);
      lossTickets[lossCount] = ticket;
      lossValues[lossCount] = pnl;
      lossTimes[lossCount] = (datetime)PositionGetInteger(POSITION_TIME);
      lossCount++;
   }

   // Sort by open time ascending (oldest first)
   for(int a = 0; a < lossCount - 1; a++)
      for(int b = a + 1; b < lossCount; b++)
         if(lossTimes[b] < lossTimes[a])
         {
            double tmpV = lossValues[a]; lossValues[a] = lossValues[b]; lossValues[b] = tmpV;
            ulong tmpT = lossTickets[a]; lossTickets[a] = lossTickets[b]; lossTickets[b] = tmpT;
            datetime tmpD = lossTimes[a]; lossTimes[a] = lossTimes[b]; lossTimes[b] = tmpD;
         }

   // Budget-based matching: scan losses oldest first
   int closeLossIdx[];
   ArrayResize(closeLossIdx, 0);
   double cumLoss = 0;
   int lossUsed = 0;

   for(int l = 0; l < lossCount; l++)
   {
      double absLoss = MathAbs(lossValues[l]);
      if(cumLoss + absLoss <= budget)
      {
         ArrayResize(closeLossIdx, lossUsed + 1);
         closeLossIdx[lossUsed] = l;
         cumLoss += absLoss;
         lossUsed++;
      }
   }

   if(lossUsed > 0)
   {
      double finalNet = totalBudgetProfit - cumLoss;
      Print("HEDGE MATCHING Set#", idx + 1, ": hedge profit $", DoubleToString(hedgeProfit, 2),
            " + reverse profit $", DoubleToString(reverseProfit, 2),
            " covers ", lossUsed, " losses ($", DoubleToString(cumLoss, 2),
            ") net: $", DoubleToString(finalNet, 2));

      // Close hedge order
      trade.PositionClose(g_hedgeSets[idx].hedgeTicket);

      // v6.12: Close profitable reverse orders that contributed to budget
      for(int pr = 0; pr < profitableReverseCount; pr++)
      {
         if(PositionSelectByTicket(profitableReverseTickets[pr]))
         {
            trade.PositionClose(profitableReverseTickets[pr]);
            RemoveReverseHedgeTicket(profitableReverseTickets[pr]);
            Sleep(50);
         }
      }

       // v6.61: SHRED bound losers (oldest first) using hedge profit, then close hedge
       int closedBoundCount = 0;
       if(InpHedge_ShredOnMatch)
       {
          for(int li = 0; li < lossUsed; li++)
          {
             ulong tk = lossTickets[ closeLossIdx[li] ];
             if(PositionSelectByTicket(tk))
             {
                if(trade.PositionClose(tk)) closedBoundCount++;
                Sleep(30);
             }
          }
          Print("v6.61 SHRED BOUND: Set#", idx + 1, " closed ", closedBoundCount,
                "/", g_hedgeSets[idx].boundTicketCount, " bound losers via hedge profit");
       }
       else
       {
          Print("HEDGE MATCHING v6.55 Set#", idx + 1, ": releasing ", g_hedgeSets[idx].boundTicketCount, " bound orders to recovery (not closing)");
       }

       // Track shred event for dashboard
       g_lastShredHedgeFrom    = g_hedgeSets[idx].hedgeLots;
       g_lastShredHedgeTo      = 0;
       g_lastShredBoundClosed  = closedBoundCount;
       g_lastShredBoundRemain  = MathMax(0, g_hedgeSets[idx].boundTicketCount - closedBoundCount);
       g_lastShredNet          = finalNet;
       g_lastShredTime         = TimeCurrent();

        // Deactivate hedge set — remaining bound orders stay open as recovery
         CloseAllHedgeGridOrders(idx);
         int matchGen = g_hedgeSets[idx].boundGeneration;  // v6.59

         // v6.61: Register all REMAINING (still-open) bound tickets as recovery set
         ulong remainBound[];
         int rbCnt = 0;
         for(int b = 0; b < g_hedgeSets[idx].boundTicketCount; b++)
         {
            ulong tkb = g_hedgeSets[idx].boundTickets[b];
            if(tkb == 0) continue;
            if(PositionSelectByTicket(tkb))
            {
               ArrayResize(remainBound, rbCnt + 1);
               remainBound[rbCnt++] = tkb;
            }
         }
         if(rbCnt > 0) RegisterRecoverySetTickets(matchGen, idx, remainBound);

         SaveBoundTicketsToPrevHedged(idx);  // v6.26
         g_hedgeSets[idx].active = false;
         g_hedgeSets[idx].boundTicketCount = 0;
         ArrayResize(g_hedgeSets[idx].boundTickets, 0);
           g_hedgeSetCount--;
           g_lastHedgeCloseTime = TimeCurrent();  // v6.25: cooldown after set close
           SetSequentialRecoveryOwner(idx, matchGen);  // v6.59: claim recovery owner
           // v6.27: Safe reset — only if truly flat
           TryResetCycleStateIfFlat("matching close");
         Sleep(100);
     }
     else
     {
        // No losses can be matched → close hedge + release all bound orders to normal
        Print("HEDGE CLOSE (no matchable losses) Set#", idx + 1,
              ": profit $", DoubleToString(hedgeProfit, 2),
              " | Releasing ", g_hedgeSets[idx].boundTicketCount, " bound orders to normal trading");
        trade.PositionClose(g_hedgeSets[idx].hedgeTicket);

         // Release all bound orders → they return to normal trading system
          CloseAllHedgeGridOrders(idx);
          int relGen = g_hedgeSets[idx].boundGeneration;  // v6.59
          SaveBoundTicketsToPrevHedged(idx);  // v6.26
          g_hedgeSets[idx].active = false;
          g_hedgeSets[idx].boundTicketCount = 0;
          ArrayResize(g_hedgeSets[idx].boundTickets, 0);
          g_hedgeSets[idx].gridMode = false;
          g_hedgeSetCount--;
           g_lastHedgeCloseTime = TimeCurrent();  // v6.25: cooldown after set close
           SetSequentialRecoveryOwner(idx, relGen);  // v6.59: claim recovery owner
           // v6.27: Safe reset — only if truly flat
           TryResetCycleStateIfFlat("release close");
         Sleep(100);
      }
}

//+------------------------------------------------------------------+
//| Scenario 2: Hedge in loss + original orders may have profit        |
//| Use partial close to reduce hedge using bound order profits        |
//+------------------------------------------------------------------+
void ManageHedgePartialClose(int idx)
{
   // v6.61: SHRED hedge using bound profit (oldest profit-takers first)
   if(!InpHedge_ShredHedgeOnProfit) return;
   if(!PositionSelectByTicket(g_hedgeSets[idx].hedgeTicket)) return;

   double hedgePnL = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   if(hedgePnL >= 0) return;  // hedge in profit → handled by ManageHedgeMatchingClose

   double hedgeLots = PositionGetDouble(POSITION_VOLUME);
   if(hedgeLots <= 0) return;
   double hedgeOpenPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   ENUM_POSITION_TYPE hedgeType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

   if(g_hedgeSets[idx].boundTicketCount == 0) return;

   // Collect profitable bound orders (oldest first)
   ulong  profTickets[];
   double profValues[];
   datetime profTimes[];
   int profCount = 0;
   double boundProfit = 0;
   for(int b = 0; b < g_hedgeSets[idx].boundTicketCount; b++)
   {
      ulong ticket = g_hedgeSets[idx].boundTickets[b];
      if(!PositionSelectByTicket(ticket)) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != g_hedgeSets[idx].counterSide) continue;
      double pnl = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      if(pnl <= 0) continue;
      ArrayResize(profTickets, profCount + 1);
      ArrayResize(profValues, profCount + 1);
      ArrayResize(profTimes, profCount + 1);
      profTickets[profCount] = ticket;
      profValues[profCount]  = pnl;
      profTimes[profCount]   = (datetime)PositionGetInteger(POSITION_TIME);
      boundProfit += pnl;
      profCount++;
   }
   if(profCount == 0 || boundProfit <= InpHedge_ShredMinNetProfit) return;

   // Re-select hedge ticket for accurate read
   if(!PositionSelectByTicket(g_hedgeSets[idx].hedgeTicket)) return;

   double hedgeLossPerLot = MathAbs(hedgePnL) / hedgeLots;
   if(hedgeLossPerLot <= 0) return;

   double budget = boundProfit - InpHedge_ShredMinNetProfit;
   double closeLots = budget / hedgeLossPerLot;

   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(lotStep <= 0) lotStep = 0.01;
   closeLots = MathFloor(closeLots / lotStep) * lotStep;
   closeLots = NormalizeDouble(closeLots, 2);
   if(closeLots < minLot) return;
   if(closeLots > hedgeLots) closeLots = hedgeLots;

   // Sort profitable bound by time ascending
   for(int a = 0; a < profCount - 1; a++)
      for(int c = a + 1; c < profCount; c++)
         if(profTimes[c] < profTimes[a])
         {
            datetime tt = profTimes[a]; profTimes[a] = profTimes[c]; profTimes[c] = tt;
            double vv = profValues[a]; profValues[a] = profValues[c]; profValues[c] = vv;
            ulong tk = profTickets[a]; profTickets[a] = profTickets[c]; profTickets[c] = tk;
         }

   bool fullClose = (closeLots >= hedgeLots - lotStep / 2.0);

   Print("v6.61 SHRED HEDGE: Set#", idx + 1, " hedge ", DoubleToString(hedgeLots, 2),
         " -> close ", DoubleToString(closeLots, 2), " lots (boundProfit=$",
         DoubleToString(boundProfit, 2), " hedgeLoss/lot=$",
         DoubleToString(hedgeLossPerLot, 2), ")");

   // Close profitable bound orders (oldest first) up to budget
   double profUsed = 0;
   for(int p = 0; p < profCount; p++)
   {
      if(profUsed >= budget) break;
      if(PositionSelectByTicket(profTickets[p]))
      {
         if(trade.PositionClose(profTickets[p]))
         {
            profUsed += profValues[p];
            Sleep(30);
         }
      }
   }

   // Track shred event
   g_lastShredHedgeFrom   = hedgeLots;
   g_lastShredNet         = profUsed - (closeLots * hedgeLossPerLot);
   g_lastShredTime        = TimeCurrent();

   if(fullClose)
   {
      // Close hedge fully → release remaining bound + take ownership
      trade.PositionClose(g_hedgeSets[idx].hedgeTicket);
      g_lastShredHedgeTo = 0;
      Print("v6.61 SHRED HEDGE: Set#", idx + 1, " hedge fully closed");

      CloseAllHedgeGridOrders(idx);
      int gen = g_hedgeSets[idx].boundGeneration;
      ulong remainBound[];
      int rbCnt = 0;
      for(int b = 0; b < g_hedgeSets[idx].boundTicketCount; b++)
      {
         ulong tkb = g_hedgeSets[idx].boundTickets[b];
         if(tkb == 0) continue;
         if(PositionSelectByTicket(tkb))
         {
            ArrayResize(remainBound, rbCnt + 1);
            remainBound[rbCnt++] = tkb;
         }
      }
      if(rbCnt > 0) RegisterRecoverySetTickets(gen, idx, remainBound);
      SaveBoundTicketsToPrevHedged(idx);
      g_hedgeSets[idx].active = false;
      g_hedgeSets[idx].boundTicketCount = 0;
      ArrayResize(g_hedgeSets[idx].boundTickets, 0);
      g_hedgeSetCount--;
      g_lastHedgeCloseTime = TimeCurrent();
      SetSequentialRecoveryOwner(idx, gen);
      TryResetCycleStateIfFlat("shred hedge full");
      Sleep(100);
   }
   else
   {
      // Partial close hedge → strip comment logically → register as recovery seed
      if(trade.PositionClosePartial(g_hedgeSets[idx].hedgeTicket, closeLots))
      {
         double newLots = hedgeLots - closeLots;
         g_hedgeSets[idx].hedgeLots = newLots;
         g_lastShredHedgeTo = newLots;
         Print("v6.61 SHRED HEDGE: Set#", idx + 1, " partial closed ",
               DoubleToString(closeLots, 2), " lots, remainder=", DoubleToString(newLots, 2));

         if(InpRecovery_StripHedgeComment)
         {
            int gen = g_hedgeSets[idx].boundGeneration;
            RegisterRecoverySeed(g_hedgeSets[idx].hedgeTicket, gen, hedgeOpenPrice);

            // Track in recovery set tracker for anti-skip
            ulong seedArr[1];
            seedArr[0] = g_hedgeSets[idx].hedgeTicket;
            RegisterRecoverySetTickets(gen, idx, seedArr);
         }
      }
      Sleep(100);
   }
}

//+------------------------------------------------------------------+
//| Calculate equivalent grid level for remaining hedge lots           |
//+------------------------------------------------------------------+
int CalculateEquivGridLevel(double remainingLots)
{
   double cumLots = InitialLotSize;
   int level = 0;
   double mult = GridLoss_MultiplyFactor;
   double addPerLevel = GridLoss_AddLotPerLevel * InitialLotSize;

   while(cumLots < remainingLots && level < GridLoss_MaxTrades)
   {
      level++;
      double nextLot = 0;
      if(GridLoss_LotMode == LOT_MULTIPLY)
         nextLot = InitialLotSize * MathPow(mult, level);
      else if(GridLoss_LotMode == LOT_ADD)
         nextLot = InitialLotSize + addPerLevel * level;
      else
         nextLot = InitialLotSize;  // custom - simplified
      cumLots += nextLot;
   }
   return level;
}

//+------------------------------------------------------------------+
//| Hedge Grid Mode: original orders gone, manage hedge recovery       |
//+------------------------------------------------------------------+
void ManageHedgeGridMode(int idx)
{
   // Verify main hedge ticket
   bool mainHedgeExists = false;
   double mainHedgePnL = 0;
   if(g_hedgeSets[idx].hedgeTicket > 0 && PositionSelectByTicket(g_hedgeSets[idx].hedgeTicket))
   {
      mainHedgeExists = true;
      mainHedgePnL = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      g_hedgeSets[idx].hedgeLots = PositionGetDouble(POSITION_VOLUME);
   }

   // Count hedge grid orders
   int gridProfitCount = 0;
   double gridTotalProfit = 0;
   ulong gridProfitTickets[];
   double gridProfitValues[];

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      string comment = PositionGetString(POSITION_COMMENT);
      string prefix = "GM_HG" + IntegerToString(idx + 1);
      if(StringFind(comment, prefix) < 0) continue;

      double pnl = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      if(pnl > 0)
      {
         ArrayResize(gridProfitTickets, gridProfitCount + 1);
         ArrayResize(gridProfitValues, gridProfitCount + 1);
         gridProfitTickets[gridProfitCount] = ticket;
         gridProfitValues[gridProfitCount] = pnl;
         gridTotalProfit += pnl;
         gridProfitCount++;
      }
   }

   // If hedge grid profits can cover main hedge loss → partial close
   if(mainHedgeExists && mainHedgePnL < 0 && gridProfitCount >= InpHedge_PartialMinProfitOrders)
   {
      double hedgeLossPerLot = MathAbs(mainHedgePnL) / g_hedgeSets[idx].hedgeLots;
      double budget = gridTotalProfit - InpHedge_MatchMinProfit;
      if(budget > 0 && hedgeLossPerLot > 0)
      {
         double closeLots = budget / hedgeLossPerLot;
         double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
         double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
         closeLots = MathMax(minLot, MathMin(g_hedgeSets[idx].hedgeLots,
                     NormalizeDouble(MathFloor(closeLots / lotStep) * lotStep, 2)));

         if(closeLots >= minLot)
         {
            Print("HEDGE GRID MATCH Set#", idx + 1, ": grid profit $",
                  DoubleToString(gridTotalProfit, 2), " closes ",
                  DoubleToString(closeLots, 2), " lots of main hedge");

            // Close grid profit orders
            for(int gp = 0; gp < gridProfitCount; gp++)
               trade.PositionClose(gridProfitTickets[gp]);

            // Partial close main hedge
            if(closeLots >= g_hedgeSets[idx].hedgeLots)
            {
               trade.PositionClose(g_hedgeSets[idx].hedgeTicket);
                CloseAllHedgeGridOrders(idx);
                int gridGen = g_hedgeSets[idx].boundGeneration;  // v6.59
                SaveBoundTicketsToPrevHedged(idx);  // v6.26
                 g_hedgeSets[idx].active = false;
                 g_hedgeSetCount--;
                  g_lastHedgeCloseTime = TimeCurrent();  // v6.25: cooldown after set close
                  SetSequentialRecoveryOwner(idx, gridGen);  // v6.59
                  // v6.27: Safe reset — only if truly flat
                  TryResetCycleStateIfFlat("grid recover");
                 Print("HEDGE Set#", idx + 1, " fully recovered via grid mode.");
            }
            else
            {
               trade.PositionClosePartial(g_hedgeSets[idx].hedgeTicket, closeLots);
               g_hedgeSets[idx].hedgeLots -= closeLots;
            }
            Sleep(100);
            return;
         }
      }
   }

   // If main hedge fully closed
   if(!mainHedgeExists)
   {
      // Close remaining grid orders
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         string comment = PositionGetString(POSITION_COMMENT);
         string prefix = "GM_HG" + IntegerToString(idx + 1);
         if(StringFind(comment, prefix) >= 0)
            trade.PositionClose(ticket);
      }
       int cleanupGen = g_hedgeSets[idx].boundGeneration;  // v6.59
       SaveBoundTicketsToPrevHedged(idx);  // v6.26
       g_hedgeSets[idx].active = false;
         g_hedgeSetCount--;
         g_lastHedgeCloseTime = TimeCurrent();  // v6.25: cooldown after set close
         SetSequentialRecoveryOwner(idx, cleanupGen);  // v6.59
         // v6.27: Safe reset — only if truly flat
         TryResetCycleStateIfFlat("grid cleanup");
        Print("HEDGE Set#", idx + 1, " grid mode complete. All cleaned up.");
      return;
   }

   // Open next grid order if needed (direction = same as hedge)
   if(g_newOrderBlocked) return;  // respect news/time filters

   int currentGridCount = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      string comment = PositionGetString(POSITION_COMMENT);
      string prefix = "GM_HG" + IntegerToString(idx + 1);
      if(StringFind(comment, prefix) >= 0) currentGridCount++;
   }

   if(currentGridCount < GridLoss_MaxTrades && currentGridCount <= g_hedgeSets[idx].gridLevel + 3)
   {
      // Calculate next grid lot
      int nextLevel = g_hedgeSets[idx].gridLevel + currentGridCount + 1;
      double nextLot = InitialLotSize;
      if(GridLoss_LotMode == LOT_MULTIPLY)
         nextLot = InitialLotSize * MathPow(GridLoss_MultiplyFactor, nextLevel);
      else if(GridLoss_LotMode == LOT_ADD)
         nextLot = InitialLotSize + (GridLoss_AddLotPerLevel * InitialLotSize) * nextLevel;

      // Cooldown to prevent rapid-fire orders
      if(TimeCurrent() - g_lastHedgeGridTime < 5) return;

      // Check grid distance using proper ATR/Custom calculation
      double requiredGap = GetGridDistance(currentGridCount + 1, true);
      if(requiredGap <= 0) return;

      double lastPrice = 0;
      if(PositionSelectByTicket(g_hedgeSets[idx].hedgeTicket))
         lastPrice = PositionGetDouble(POSITION_PRICE_OPEN);

      // Find last grid order price
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         string comment = PositionGetString(POSITION_COMMENT);
         string prefix = "GM_HG" + IntegerToString(idx + 1);
         if(StringFind(comment, prefix) >= 0)
         {
            double gPrice = PositionGetDouble(POSITION_PRICE_OPEN);
            if(g_hedgeSets[idx].hedgeSide == POSITION_TYPE_BUY)
            {
               if(gPrice < lastPrice || lastPrice == 0) lastPrice = gPrice;
            }
            else
            {
               if(gPrice > lastPrice || lastPrice == 0) lastPrice = gPrice;
            }
         }
      }

      if(lastPrice <= 0) return;

      double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      // Directional distance: only trigger when price moves AGAINST the hedge (losing direction)
      // Hedge SELL → grid opens when price goes UP (Bid > lastPrice)
      // Hedge BUY  → grid opens when price goes DOWN (Ask < lastPrice)
      double distance = 0;
      if(g_hedgeSets[idx].hedgeSide == POSITION_TYPE_SELL)
      {
         double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         distance = (currentBid - lastPrice) / point;  // positive = price went up
      }
      else // BUY hedge
      {
         double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         distance = (lastPrice - currentAsk) / point;  // positive = price went down
      }

      if(distance >= requiredGap && distance > 0)
      {
         ENUM_ORDER_TYPE orderType = (g_hedgeSets[idx].hedgeSide == POSITION_TYPE_BUY)
                                    ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
         string comment = "GM_HG" + IntegerToString(idx + 1) + "_GL" + IntegerToString(currentGridCount + 1);

         if(OpenOrder(orderType, nextLot, comment))
         {
            g_lastHedgeGridTime = TimeCurrent();
            Print("HEDGE GRID Set#", idx + 1, " opened grid L", currentGridCount + 1,
                  " lots=", DoubleToString(nextLot, 2),
                  " gap=", DoubleToString(distance, 0), "/", DoubleToString(requiredGap, 0));
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Matching Close - Pair profitable orders with losing orders         |
//| Close sets where net profit >= MatchingMinProfit                   |
//| Runs once per new bar. Buy/Sell sides processed independently.     |
//+------------------------------------------------------------------+
void ManageMatchingClose()
{
   // v6.11: Skip matching close when hedge balanced lock is active
   // v6.46: Use direct hedge set check instead of g_hedgeBalancedLock
   // v6.47: Removed early return — matching close should work for non-bound orders of new generation
   int maxLoss = MathMin(MathMax(MatchingMaxLossOrders, 1), 10);  // allow up to 10

   // Process BUY side then SELL side
   for(int side = 0; side < 2; side++)
   {
      ENUM_POSITION_TYPE posType = (side == 0) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;

      // Keep looping until no more matches found
      bool matchFound = true;
      while(matchFound)
      {
         matchFound = false;

         // Collect profit and loss tickets for this side
         ulong profitTickets[];
         double profitValues[];
         ulong lossTickets[];
         double lossValues[];
         datetime lossOpenTimes[];
         int profitCount = 0, lossCount = 0;

         for(int i = PositionsTotal() - 1; i >= 0; i--)
         {
            ulong ticket = PositionGetTicket(i);
            if(ticket == 0) continue;
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
            if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
            if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != posType) continue;

            // Skip hedge orders — managed separately
            string mcComment = PositionGetString(POSITION_COMMENT);
            if(StringFind(mcComment, "GM_HEDGE") >= 0 || StringFind(mcComment, "GM_HG") >= 0) continue;
            if(IsTicketBound(ticket)) continue;  // bound orders managed by Hedge system only

            double pnl = PositionGetDouble(POSITION_PROFIT)
                       + PositionGetDouble(POSITION_SWAP)
                       + (2.0 * PositionGetDouble(POSITION_COMMISSION));

            if(pnl > 0)
            {
               ArrayResize(profitTickets, profitCount + 1);
               ArrayResize(profitValues, profitCount + 1);
               profitTickets[profitCount] = ticket;
               profitValues[profitCount] = pnl;
               profitCount++;
            }
            else if(pnl < 0)
            {
               ArrayResize(lossTickets, lossCount + 1);
               ArrayResize(lossValues, lossCount + 1);
               ArrayResize(lossOpenTimes, lossCount + 1);
               lossTickets[lossCount] = ticket;
               lossValues[lossCount] = pnl;
               lossOpenTimes[lossCount] = (datetime)PositionGetInteger(POSITION_TIME);
               lossCount++;
            }
         }

         // --- Minimum Total Orders Threshold ---
         int totalSideOrders = profitCount + lossCount;
         if(MatchingMinTotalOrders > 0 && totalSideOrders < MatchingMinTotalOrders)
            break;  // ออเดอร์ยังไม่ถึงเกณฑ์ — ปล่อยให้ TP ทำงานปกติ

         int minPO = MathMax(MatchingMinProfitOrders, 1);
         if(profitCount < minPO) break;  // Not enough profit orders — wait for more

         // Sort profit descending (biggest profit first)
         for(int a = 0; a < profitCount - 1; a++)
            for(int b = a + 1; b < profitCount; b++)
               if(profitValues[b] > profitValues[a])
               {
                  double tmpV = profitValues[a]; profitValues[a] = profitValues[b]; profitValues[b] = tmpV;
                  ulong tmpT = profitTickets[a]; profitTickets[a] = profitTickets[b]; profitTickets[b] = tmpT;
               }

         // Sort loss by open time ascending (oldest/furthest first)
         for(int a = 0; a < lossCount - 1; a++)
            for(int b = a + 1; b < lossCount; b++)
               if(lossOpenTimes[b] < lossOpenTimes[a])
               {
                  double tmpV = lossValues[a]; lossValues[a] = lossValues[b]; lossValues[b] = tmpV;
                  ulong tmpT = lossTickets[a]; lossTickets[a] = lossTickets[b]; lossTickets[b] = tmpT;
                  datetime tmpD = lossOpenTimes[a]; lossOpenTimes[a] = lossOpenTimes[b]; lossOpenTimes[b] = tmpD;
               }

         string sideStr = (posType == POSITION_TYPE_BUY) ? "BUY" : "SELL";

         //--- Case 1: No loss orders — profit-only matching
          if(lossCount == 0)
         {
            if(profitCount < minPO) break;  // Profit-only also needs minPO
            double totalProfit = 0;
            for(int p = 0; p < profitCount; p++)
               totalProfit += profitValues[p];

            if(totalProfit >= MatchingMinProfit)
            {
               Print("MATCHING CLOSE [", sideStr, "] PROFIT-ONLY: ", profitCount,
                     " orders, total $", DoubleToString(totalProfit, 2));
               for(int p = 0; p < profitCount; p++)
               {
                  Print("  Closing profit ticket #", profitTickets[p],
                        " ($", DoubleToString(profitValues[p], 2), ")");
                  trade.PositionClose(profitTickets[p]);
               }
               matchFound = true;
               Sleep(100);
            }
            else
               break;  // Not enough profit
         }
         //--- Case 2: Has loss orders — Budget-based matching
         //    Step 1: Sum ALL profit orders
         //    Step 2: budget = totalProfit - MinProfit
         //    Step 3: Scan losses oldest-first, skip if too heavy, include if fits budget
         //    Step 4: Close all profit + matched losses
         else
         {
            double totalProfit = 0;
            for(int p = 0; p < profitCount; p++)
               totalProfit += profitValues[p];

            double budget = totalProfit - MatchingMinProfit;
            if(budget <= 0) break;  // Not enough profit even for MinProfit

            int closeLossIdx[];
            ArrayResize(closeLossIdx, 0);
            double cumLoss = 0;
            int lossUsed = 0;

            for(int l = 0; l < lossCount && lossUsed < maxLoss; l++)
            {
               double absLoss = MathAbs(lossValues[l]);
               if(cumLoss + absLoss <= budget)
               {
                  ArrayResize(closeLossIdx, lossUsed + 1);
                  closeLossIdx[lossUsed] = l;
                  cumLoss += absLoss;
                  lossUsed++;
               }
               // else: this loss is too heavy — skip to next (possibly lighter) one
            }

            if(lossUsed > 0)
            {
               double finalNet = totalProfit - cumLoss;
               Print("MATCHING CLOSE [", sideStr, "]: ", profitCount, " profit + ",
                     lossUsed, " loss orders. Net: $", DoubleToString(finalNet, 2),
                     " (budget: $", DoubleToString(budget, 2), ")");

               for(int cp = 0; cp < profitCount; cp++)
               {
                  Print("  Closing profit #", profitTickets[cp],
                        " ($", DoubleToString(profitValues[cp], 2), ")");
                  trade.PositionClose(profitTickets[cp]);
               }
               for(int cl = 0; cl < lossUsed; cl++)
               {
                  int idx = closeLossIdx[cl];
                  Print("  Closing loss #", lossTickets[idx],
                        " ($", DoubleToString(lossValues[idx], 2), ")");
                  trade.PositionClose(lossTickets[idx]);
               }

               matchFound = true;
               Sleep(100);
            }
            else break;
         }
      }
   }
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Close All Orders on Expansion (v6.6)                              |
//+------------------------------------------------------------------+
void CloseAllOnExpansion()
{
   int closed = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      
      string comment = PositionGetString(POSITION_COMMENT);
      // Skip reverse hedge orders
      if(StringFind(comment, "GM_RHEDGE") >= 0) continue;
      
      string sym = PositionGetString(POSITION_SYMBOL);
      double vol = PositionGetDouble(POSITION_VOLUME);
      
      if(trade.PositionClose(ticket))
      {
         closed++;
         Print("EXPANSION CLOSE: Closed #", ticket, " ", sym, " ", vol, " lots");
      }
   }
   
   if(closed > 0)
      Print("EXPANSION CLOSE ALL: Closed ", closed, " positions due to expansion >= ", InpSqueeze_MinTFExpansion, " TFs");
}

//+------------------------------------------------------------------+
//| Volatility Squeeze Filter - Update State for all 3 TFs            |
//+------------------------------------------------------------------+
void UpdateSqueezeState()
{
   for(int sq = 0; sq < 3; sq++)
   {
      if(g_squeeze[sq].handleBB == INVALID_HANDLE ||
         g_squeeze[sq].handleEMA == INVALID_HANDLE ||
         g_squeeze[sq].handleATR == INVALID_HANDLE)
      {
         g_squeeze[sq].state = 0;
         g_squeeze[sq].intensity = 1.0;
         continue;
      }

      double bbUpper[], bbLower[], emaVal[], atrVal[];
      ArraySetAsSeries(bbUpper, true);
      ArraySetAsSeries(bbLower, true);
      ArraySetAsSeries(emaVal, true);
      ArraySetAsSeries(atrVal, true);

      // BB: buffer 1 = Upper, buffer 2 = Lower
      // v6.13: Use closed bar (index 1) for state calculation to prevent flickering
      if(CopyBuffer(g_squeeze[sq].handleBB, 1, 1, 1, bbUpper) < 1) continue;
      if(CopyBuffer(g_squeeze[sq].handleBB, 2, 1, 1, bbLower) < 1) continue;
      if(CopyBuffer(g_squeeze[sq].handleEMA, 0, 1, 1, emaVal) < 1) continue;
      if(CopyBuffer(g_squeeze[sq].handleATR, 0, 1, 1, atrVal) < 1) continue;

      double upperBB = bbUpper[0];
      double lowerBB = bbLower[0];
      double ema     = emaVal[0];
      double atr     = atrVal[0];

      // Keltner Channel bands
      double upperKC = ema + InpSqueeze_KC_Mult * atr;
      double lowerKC = ema - InpSqueeze_KC_Mult * atr;

      double bbWidth = upperBB - lowerBB;
      double kcWidth = upperKC - lowerKC;

      if(kcWidth <= 0)
      {
         g_squeeze[sq].state = 0;
         g_squeeze[sq].intensity = 1.0;
         continue;
      }

      double intensity = bbWidth / kcWidth;
      g_squeeze[sq].intensity = intensity;

      // Squeeze: BB is INSIDE KC
      if(upperBB < upperKC && lowerBB > lowerKC)
         g_squeeze[sq].state = 1;  // SQUEEZE
      // Expansion: intensity exceeds threshold
      else if(intensity > InpSqueeze_ExpThreshold)
         g_squeeze[sq].state = 2;  // EXPANSION
      else
         g_squeeze[sq].state = 0;  // NORMAL

        // Direction: Bid vs EMA (for directional block) — v6.11: use Bid directly
      g_squeeze[sq].direction = 0;
      if(g_squeeze[sq].state == 2)
      {
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(bid > ema)
            g_squeeze[sq].direction = 1;   // Bullish
         else if(bid < ema)
            g_squeeze[sq].direction = -1;  // Bearish
         // bid == ema → direction stays 0 (v6.11 safety: won't block anything)
      }
   }
}

//+------------------------------------------------------------------+
//| TimeframeToString - Convert ENUM_TIMEFRAMES to readable label      |
//+------------------------------------------------------------------+
string TimeframeToString(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN";
      default:         return EnumToString(tf);
   }
}
//+------------------------------------------------------------------+
