//+------------------------------------------------------------------+
//|                                             Asset_Miner_EA.mq5   |
//|                                    Copyright 2025, MoneyX Smart  |
//|         Asset Miner EA v4.0 - Multi-Pair MTF ZigZag+CDC+Grid     |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MoneyX Smart System"
#property link      "https://moneyxsmartsystem.lovable.app"
#property version   "4.00"
#property description "Asset Miner EA v4.0 - Multi-Pair (5 Sets) + MTF ZigZag + CDC + Grid + License"
#property strict

#include <Trade/Trade.mqh>

//--- Enums
enum ENUM_LOT_MODE { LOT_ADD=0, LOT_CUSTOM=1, LOT_MULTIPLY=2 };
enum ENUM_GAP_TYPE { GAP_FIXED=0, GAP_CUSTOM=1, GAP_ATR=2 };
enum ENUM_ATR_REF  { ATR_REF_INITIAL=0, ATR_REF_DYNAMIC=1 };
enum ENUM_SL_ACTION { SL_CLOSE_POSITIONS=0, SL_CLOSE_ALL_STOP=1 };
enum ENUM_TRADE_MODE { TRADE_BUY_ONLY=0, TRADE_SELL_ONLY=1, TRADE_BOTH=2 };
enum ENUM_ENTRY_MODE { ENTRY_SMA=0, ENTRY_ZIGZAG=1 };
enum ENUM_LICENSE_STATUS { LICENSE_VALID, LICENSE_EXPIRING_SOON, LICENSE_EXPIRED, LICENSE_NOT_FOUND, LICENSE_SUSPENDED, LICENSE_ERROR };
enum ENUM_SYNC_EVENT { SYNC_SCHEDULED, SYNC_ORDER_OPEN, SYNC_ORDER_CLOSE };

struct NewsEvent { string title; string country; datetime time; string impact; bool isRelevant; };

//--- ZigZag per-TF state (used inside PairState)
#define MAX_PAIR_TF 4
struct PairTFState
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

//+------------------------------------------------------------------+
//| PairState - holds ALL per-pair config + runtime state              |
//+------------------------------------------------------------------+
struct PairState
{
   // Config
   bool     enabled;
   string   symbol;
   int      magic;
   string   commentPrefix;  // "AM_P1_", "AM_P2_", etc.
   double   initialLot;
   // Grid Loss
   int            gl_MaxTrades;
   ENUM_LOT_MODE  gl_LotMode;
   string         gl_CustomLots;
   double         gl_AddLotPerLevel;
   double         gl_MultiplyFactor;
   ENUM_GAP_TYPE  gl_GapType;
   int            gl_Points;
   string         gl_CustomDistance;
   ENUM_TIMEFRAMES gl_ATR_TF;
   int            gl_ATR_Period;
   double         gl_ATR_Multiplier;
   ENUM_ATR_REF   gl_ATR_Reference;
   int            gl_MinGapPoints;
   bool           gl_OnlyInSignal;
   bool           gl_OnlyNewCandle;
   bool           gl_DontSameCandle;
   // Grid Profit
   bool           gp_Enable;
   int            gp_MaxTrades;
   ENUM_LOT_MODE  gp_LotMode;
   string         gp_CustomLots;
   double         gp_AddLotPerLevel;
   double         gp_MultiplyFactor;
   ENUM_GAP_TYPE  gp_GapType;
   int            gp_Points;
   string         gp_CustomDistance;
   ENUM_TIMEFRAMES gp_ATR_TF;
   int            gp_ATR_Period;
   double         gp_ATR_Multiplier;
   ENUM_ATR_REF   gp_ATR_Reference;
   int            gp_MinGapPoints;
   bool           gp_OnlyNewCandle;
   // Accumulate
   bool           useAccumulate;
   double         accumTarget;
   // Matching Close
   bool           useMatching;
   double         matchMinProfit;
   int            matchMaxLoss;
   int            matchMinProfitOrders;
   // Runtime - Indicators
   int      handleSMA;
   int      handleATR_Loss;
   int      handleATR_Profit;
   double   bufSMA[];
   double   bufATR_Loss[];
   double   bufATR_Profit[];
   // Runtime - State
   datetime lastBarTime;
   datetime lastInitialCandleTime;
   datetime lastGridLossCandleTime;
   datetime lastGridProfitCandleTime;
   bool     justClosedBuy;
   bool     justClosedSell;
   double   trailingSL_Buy;
   double   trailingSL_Sell;
   bool     trailingActive_Buy;
   bool     trailingActive_Sell;
   bool     breakevenDone_Buy;
   bool     breakevenDone_Sell;
   double   initialBuyPrice;
   double   initialSellPrice;
   double   accumulatedProfit;
   double   accumulateBaseline;
   bool     hadPositions;
   // ZigZag per-pair
   PairTFState tfStates[MAX_PAIR_TF];
   int      activeTFCount;
   int      h4TFIndex;
   string   h4Direction;
   datetime lastH4Bar;
   // CDC per-pair
   string   cdcTrend;
   double   cdcFast;
   double   cdcSlow;
   bool     cdcReady;
   datetime lastCdcCandle;
   // Matching Close new bar tracking
   datetime lastMatchingBarTime;
};

//+------------------------------------------------------------------+
//| INPUT PARAMETERS - PER-PAIR SETTINGS (5 Sets)                     |
//+------------------------------------------------------------------+

// ======================== SET 1 ========================
input group "========== Set1 Settings =========="
input bool           Set1_Enable          = true;          // Enable Set1
input string         Set1_Symbol          = "XAUUSD";      // Symbol
input int            Set1_MagicOffset     = 1;             // Magic Offset (unique per set)
input double         Set1_InitialLot      = 0.01;          // Initial Lot Size
input group "--- Set1 Grid Loss ---"
input int            Set1_GL_MaxTrades    = 5;             // Max Grid Loss Trades
input ENUM_LOT_MODE  Set1_GL_LotMode      = LOT_ADD;       // Grid Loss Lot Mode
input string         Set1_GL_CustomLots   = "0.01;0.02;0.03;0.04;0.05"; // Custom Lots
input double         Set1_GL_AddLotPerLvl = 0.4;           // Add Lot per Level
input double         Set1_GL_MultFactor   = 2.0;           // Multiply Factor
input ENUM_GAP_TYPE  Set1_GL_GapType      = GAP_FIXED;     // Gap Type
input int            Set1_GL_Points       = 500;           // Distance (points)
input string         Set1_GL_CustomDist   = "100;200;300;400;500"; // Custom Distance
input ENUM_TIMEFRAMES Set1_GL_ATR_TF      = PERIOD_H1;     // ATR Timeframe
input int            Set1_GL_ATR_Period   = 14;            // ATR Period
input double         Set1_GL_ATR_Mult     = 1.5;           // ATR Multiplier
input ENUM_ATR_REF   Set1_GL_ATR_Ref      = ATR_REF_DYNAMIC; // ATR Reference
input int            Set1_GL_MinGap       = 100;           // Min Grid Gap (points)
input bool           Set1_GL_OnlySignal   = false;         // Grid Only in Signal
input bool           Set1_GL_OnlyNewBar   = true;          // Grid Only New Candle
input bool           Set1_GL_DontSameBar  = true;          // Don't Same Candle as Initial
input group "--- Set1 Grid Profit ---"
input bool           Set1_GP_Enable       = true;          // Enable Profit Grid
input int            Set1_GP_MaxTrades    = 3;             // Max Grid Profit Trades
input ENUM_LOT_MODE  Set1_GP_LotMode      = LOT_ADD;       // Lot Mode
input string         Set1_GP_CustomLots   = "0.01;0.02;0.03"; // Custom Lots
input double         Set1_GP_AddLotPerLvl = 0.2;           // Add Lot per Level
input double         Set1_GP_MultFactor   = 1.5;           // Multiply Factor
input ENUM_GAP_TYPE  Set1_GP_GapType      = GAP_FIXED;     // Gap Type
input int            Set1_GP_Points       = 300;           // Distance (points)
input string         Set1_GP_CustomDist   = "100;200;500"; // Custom Distance
input ENUM_TIMEFRAMES Set1_GP_ATR_TF      = PERIOD_H1;     // ATR Timeframe
input int            Set1_GP_ATR_Period   = 14;            // ATR Period
input double         Set1_GP_ATR_Mult     = 1.0;           // ATR Multiplier
input ENUM_ATR_REF   Set1_GP_ATR_Ref      = ATR_REF_DYNAMIC; // ATR Reference
input int            Set1_GP_MinGap       = 100;           // Min Grid Gap (points)
input bool           Set1_GP_OnlyNewBar   = true;          // Grid Only New Candle
input group "--- Set1 Accumulate Close ---"
input bool           Set1_UseAccum        = false;         // Use Accumulate Close
input double         Set1_AccumTarget     = 20000.0;       // Accumulate Target ($)
input group "--- Set1 Matching Close ---"
input bool           Set1_UseMatching     = false;         // Enable Matching Close
input double         Set1_MatchMinProfit  = 0.50;          // Min Net Profit ($)
input int            Set1_MatchMaxLoss    = 3;             // Max Loss Orders per Match
input int            Set1_MatchMinPO      = 1;             // Min Profit Orders

// ======================== SET 2 ========================
input group "========== Set2 Settings =========="
input bool           Set2_Enable          = false;         // Enable Set2
input string         Set2_Symbol          = "EURUSD";      // Symbol
input int            Set2_MagicOffset     = 2;             // Magic Offset
input double         Set2_InitialLot      = 0.01;          // Initial Lot Size
input group "--- Set2 Grid Loss ---"
input int            Set2_GL_MaxTrades    = 5;
input ENUM_LOT_MODE  Set2_GL_LotMode      = LOT_ADD;
input string         Set2_GL_CustomLots   = "0.01;0.02;0.03;0.04;0.05";
input double         Set2_GL_AddLotPerLvl = 0.4;
input double         Set2_GL_MultFactor   = 2.0;
input ENUM_GAP_TYPE  Set2_GL_GapType      = GAP_FIXED;
input int            Set2_GL_Points       = 500;
input string         Set2_GL_CustomDist   = "100;200;300;400;500";
input ENUM_TIMEFRAMES Set2_GL_ATR_TF      = PERIOD_H1;
input int            Set2_GL_ATR_Period   = 14;
input double         Set2_GL_ATR_Mult     = 1.5;
input ENUM_ATR_REF   Set2_GL_ATR_Ref      = ATR_REF_DYNAMIC;
input int            Set2_GL_MinGap       = 100;
input bool           Set2_GL_OnlySignal   = false;
input bool           Set2_GL_OnlyNewBar   = true;
input bool           Set2_GL_DontSameBar  = true;
input group "--- Set2 Grid Profit ---"
input bool           Set2_GP_Enable       = true;
input int            Set2_GP_MaxTrades    = 3;
input ENUM_LOT_MODE  Set2_GP_LotMode      = LOT_ADD;
input string         Set2_GP_CustomLots   = "0.01;0.02;0.03";
input double         Set2_GP_AddLotPerLvl = 0.2;
input double         Set2_GP_MultFactor   = 1.5;
input ENUM_GAP_TYPE  Set2_GP_GapType      = GAP_FIXED;
input int            Set2_GP_Points       = 300;
input string         Set2_GP_CustomDist   = "100;200;500";
input ENUM_TIMEFRAMES Set2_GP_ATR_TF      = PERIOD_H1;
input int            Set2_GP_ATR_Period   = 14;
input double         Set2_GP_ATR_Mult     = 1.0;
input ENUM_ATR_REF   Set2_GP_ATR_Ref      = ATR_REF_DYNAMIC;
input int            Set2_GP_MinGap       = 100;
input bool           Set2_GP_OnlyNewBar   = true;
input group "--- Set2 Accumulate Close ---"
input bool           Set2_UseAccum        = false;
input double         Set2_AccumTarget     = 20000.0;
input group "--- Set2 Matching Close ---"
input bool           Set2_UseMatching     = false;
input double         Set2_MatchMinProfit  = 0.50;
input int            Set2_MatchMaxLoss    = 3;
input int            Set2_MatchMinPO      = 1;

// ======================== SET 3 ========================
input group "========== Set3 Settings =========="
input bool           Set3_Enable          = false;         // Enable Set3
input string         Set3_Symbol          = "GBPUSD";      // Symbol
input int            Set3_MagicOffset     = 3;             // Magic Offset
input double         Set3_InitialLot      = 0.01;          // Initial Lot Size
input group "--- Set3 Grid Loss ---"
input int            Set3_GL_MaxTrades    = 5;
input ENUM_LOT_MODE  Set3_GL_LotMode      = LOT_ADD;
input string         Set3_GL_CustomLots   = "0.01;0.02;0.03;0.04;0.05";
input double         Set3_GL_AddLotPerLvl = 0.4;
input double         Set3_GL_MultFactor   = 2.0;
input ENUM_GAP_TYPE  Set3_GL_GapType      = GAP_FIXED;
input int            Set3_GL_Points       = 500;
input string         Set3_GL_CustomDist   = "100;200;300;400;500";
input ENUM_TIMEFRAMES Set3_GL_ATR_TF      = PERIOD_H1;
input int            Set3_GL_ATR_Period   = 14;
input double         Set3_GL_ATR_Mult     = 1.5;
input ENUM_ATR_REF   Set3_GL_ATR_Ref      = ATR_REF_DYNAMIC;
input int            Set3_GL_MinGap       = 100;
input bool           Set3_GL_OnlySignal   = false;
input bool           Set3_GL_OnlyNewBar   = true;
input bool           Set3_GL_DontSameBar  = true;
input group "--- Set3 Grid Profit ---"
input bool           Set3_GP_Enable       = true;
input int            Set3_GP_MaxTrades    = 3;
input ENUM_LOT_MODE  Set3_GP_LotMode      = LOT_ADD;
input string         Set3_GP_CustomLots   = "0.01;0.02;0.03";
input double         Set3_GP_AddLotPerLvl = 0.2;
input double         Set3_GP_MultFactor   = 1.5;
input ENUM_GAP_TYPE  Set3_GP_GapType      = GAP_FIXED;
input int            Set3_GP_Points       = 300;
input string         Set3_GP_CustomDist   = "100;200;500";
input ENUM_TIMEFRAMES Set3_GP_ATR_TF      = PERIOD_H1;
input int            Set3_GP_ATR_Period   = 14;
input double         Set3_GP_ATR_Mult     = 1.0;
input ENUM_ATR_REF   Set3_GP_ATR_Ref      = ATR_REF_DYNAMIC;
input int            Set3_GP_MinGap       = 100;
input bool           Set3_GP_OnlyNewBar   = true;
input group "--- Set3 Accumulate Close ---"
input bool           Set3_UseAccum        = false;
input double         Set3_AccumTarget     = 20000.0;
input group "--- Set3 Matching Close ---"
input bool           Set3_UseMatching     = false;
input double         Set3_MatchMinProfit  = 0.50;
input int            Set3_MatchMaxLoss    = 3;
input int            Set3_MatchMinPO      = 1;

// ======================== SET 4 ========================
input group "========== Set4 Settings =========="
input bool           Set4_Enable          = false;         // Enable Set4
input string         Set4_Symbol          = "USDJPY";      // Symbol
input int            Set4_MagicOffset     = 4;             // Magic Offset
input double         Set4_InitialLot      = 0.01;          // Initial Lot Size
input group "--- Set4 Grid Loss ---"
input int            Set4_GL_MaxTrades    = 5;
input ENUM_LOT_MODE  Set4_GL_LotMode      = LOT_ADD;
input string         Set4_GL_CustomLots   = "0.01;0.02;0.03;0.04;0.05";
input double         Set4_GL_AddLotPerLvl = 0.4;
input double         Set4_GL_MultFactor   = 2.0;
input ENUM_GAP_TYPE  Set4_GL_GapType      = GAP_FIXED;
input int            Set4_GL_Points       = 500;
input string         Set4_GL_CustomDist   = "100;200;300;400;500";
input ENUM_TIMEFRAMES Set4_GL_ATR_TF      = PERIOD_H1;
input int            Set4_GL_ATR_Period   = 14;
input double         Set4_GL_ATR_Mult     = 1.5;
input ENUM_ATR_REF   Set4_GL_ATR_Ref      = ATR_REF_DYNAMIC;
input int            Set4_GL_MinGap       = 100;
input bool           Set4_GL_OnlySignal   = false;
input bool           Set4_GL_OnlyNewBar   = true;
input bool           Set4_GL_DontSameBar  = true;
input group "--- Set4 Grid Profit ---"
input bool           Set4_GP_Enable       = true;
input int            Set4_GP_MaxTrades    = 3;
input ENUM_LOT_MODE  Set4_GP_LotMode      = LOT_ADD;
input string         Set4_GP_CustomLots   = "0.01;0.02;0.03";
input double         Set4_GP_AddLotPerLvl = 0.2;
input double         Set4_GP_MultFactor   = 1.5;
input ENUM_GAP_TYPE  Set4_GP_GapType      = GAP_FIXED;
input int            Set4_GP_Points       = 300;
input string         Set4_GP_CustomDist   = "100;200;500";
input ENUM_TIMEFRAMES Set4_GP_ATR_TF      = PERIOD_H1;
input int            Set4_GP_ATR_Period   = 14;
input double         Set4_GP_ATR_Mult     = 1.0;
input ENUM_ATR_REF   Set4_GP_ATR_Ref      = ATR_REF_DYNAMIC;
input int            Set4_GP_MinGap       = 100;
input bool           Set4_GP_OnlyNewBar   = true;
input group "--- Set4 Accumulate Close ---"
input bool           Set4_UseAccum        = false;
input double         Set4_AccumTarget     = 20000.0;
input group "--- Set4 Matching Close ---"
input bool           Set4_UseMatching     = false;
input double         Set4_MatchMinProfit  = 0.50;
input int            Set4_MatchMaxLoss    = 3;
input int            Set4_MatchMinPO      = 1;

// ======================== SET 5 ========================
input group "========== Set5 Settings =========="
input bool           Set5_Enable          = false;         // Enable Set5
input string         Set5_Symbol          = "AUDUSD";      // Symbol
input int            Set5_MagicOffset     = 5;             // Magic Offset
input double         Set5_InitialLot      = 0.01;          // Initial Lot Size
input group "--- Set5 Grid Loss ---"
input int            Set5_GL_MaxTrades    = 5;
input ENUM_LOT_MODE  Set5_GL_LotMode      = LOT_ADD;
input string         Set5_GL_CustomLots   = "0.01;0.02;0.03;0.04;0.05";
input double         Set5_GL_AddLotPerLvl = 0.4;
input double         Set5_GL_MultFactor   = 2.0;
input ENUM_GAP_TYPE  Set5_GL_GapType      = GAP_FIXED;
input int            Set5_GL_Points       = 500;
input string         Set5_GL_CustomDist   = "100;200;300;400;500";
input ENUM_TIMEFRAMES Set5_GL_ATR_TF      = PERIOD_H1;
input int            Set5_GL_ATR_Period   = 14;
input double         Set5_GL_ATR_Mult     = 1.5;
input ENUM_ATR_REF   Set5_GL_ATR_Ref      = ATR_REF_DYNAMIC;
input int            Set5_GL_MinGap       = 100;
input bool           Set5_GL_OnlySignal   = false;
input bool           Set5_GL_OnlyNewBar   = true;
input bool           Set5_GL_DontSameBar  = true;
input group "--- Set5 Grid Profit ---"
input bool           Set5_GP_Enable       = true;
input int            Set5_GP_MaxTrades    = 3;
input ENUM_LOT_MODE  Set5_GP_LotMode      = LOT_ADD;
input string         Set5_GP_CustomLots   = "0.01;0.02;0.03";
input double         Set5_GP_AddLotPerLvl = 0.2;
input double         Set5_GP_MultFactor   = 1.5;
input ENUM_GAP_TYPE  Set5_GP_GapType      = GAP_FIXED;
input int            Set5_GP_Points       = 300;
input string         Set5_GP_CustomDist   = "100;200;500";
input ENUM_TIMEFRAMES Set5_GP_ATR_TF      = PERIOD_H1;
input int            Set5_GP_ATR_Period   = 14;
input double         Set5_GP_ATR_Mult     = 1.0;
input ENUM_ATR_REF   Set5_GP_ATR_Ref      = ATR_REF_DYNAMIC;
input int            Set5_GP_MinGap       = 100;
input bool           Set5_GP_OnlyNewBar   = true;
input group "--- Set5 Accumulate Close ---"
input bool           Set5_UseAccum        = false;
input double         Set5_AccumTarget     = 20000.0;
input group "--- Set5 Matching Close ---"
input bool           Set5_UseMatching     = false;
input double         Set5_MatchMinProfit  = 0.50;
input int            Set5_MatchMaxLoss    = 3;
input int            Set5_MatchMinPO      = 1;

// ======================== GLOBAL ACCUMULATE ========================
input group "=== Global Accumulate Close (All Pairs) ==="
input bool     UseGlobalAccumulate     = false;        // Enable Global Accumulate
input double   GlobalAccumulateTarget  = 50000.0;      // Global Target ($)

//+------------------------------------------------------------------+
//| SHARED INPUT PARAMETERS (apply to all pairs)                      |
//+------------------------------------------------------------------+
input group "=== General Settings ==="
input int              MagicNumber        = 202500;     // Base Magic Number
input int              MaxSlippage        = 30;         // Max Slippage (points)
input int              MaxOpenOrders      = 50;         // Max Open Orders (total all pairs)
input double           MaxDrawdownPct     = 30.0;       // Max Drawdown % (emergency)
input bool             StopEAOnDrawdown   = false;      // Stop EA after Emergency DD Close
input ENUM_TRADE_MODE  TradingMode        = TRADE_BOTH; // Trading Mode
input ENUM_ENTRY_MODE  EntryMode          = ENTRY_SMA;  // Entry Mode

input group "=== SMA Indicator ==="
input int               SMA_Period       = 20;
input ENUM_APPLIED_PRICE SMA_AppliedPrice = PRICE_CLOSE;
input ENUM_TIMEFRAMES   SMA_Timeframe    = PERIOD_CURRENT;
input bool              EnableAutoReEntry = true;
input bool              DontOpenSameCandle= true;

input group "=== Take Profit ==="
input bool     UseTP_Dollar        = true;
input double   TP_DollarAmount     = 100.0;
input bool     UseTP_Points        = false;
input int      TP_Points           = 2000;
input bool     UseTP_PercentBalance = false;
input double   TP_PercentBalance   = 5.0;
input bool     ShowAverageLine     = true;
input bool     ShowTPLine          = true;
input color    AvgBuyLineColor     = clrDodgerBlue;
input color    AvgSellLineColor    = clrOrangeRed;
input color    TPBuyLineColor      = clrLime;
input color    TPSellLineColor     = clrMagenta;

input group "=== Stop Loss ==="
input bool           EnableSL            = true;
input ENUM_SL_ACTION SL_ActionMode       = SL_CLOSE_POSITIONS;
input bool           UseSL_Dollar        = true;
input double         SL_DollarAmount     = 50.0;
input bool           UseSL_Points        = false;
input int            SL_Points           = 1000;
input bool           UseSL_PercentBalance = false;
input double         SL_PercentBalance   = 3.0;
input bool           ShowSLLine          = true;
input color          SLLineColor         = clrRed;

input group "=== Trailing Stop (Average-Based) ==="
input bool     EnableTrailingStop   = false;
input int      TrailingActivation   = 100;
input int      TrailingStep         = 50;
input int      BreakevenBuffer      = 10;
input bool     EnableBreakeven      = true;
input int      BreakevenActivation  = 50;

input group "=== Per-Order Trailing Stop ==="
input bool     EnablePerOrderTrailing    = true;
input bool     InpEnableBreakeven        = true;
input int      InpBreakevenTarget        = 200;
input int      InpBreakevenOffset        = 5;
input bool     InpEnableTrailing         = true;
input int      InpTrailingStop           = 200;
input int      InpTrailingStep           = 10;

input group "=== Dashboard ==="
input bool     ShowDashboard        = true;
input int      DashboardX           = 20;
input int      DashboardY           = 30;
input color    DashboardColor       = clrWhite;

input group "=== Backtest Optimization ==="
input bool     InpSkipATRInTester   = true;

input group "=== License Settings ==="
input string   InpLicenseServer     = "https://lkbhomsulgycxawwlnfh.supabase.co";
input int      InpLicenseCheckMinutes = 60;
input int      InpDataSyncMinutes   = 5;
const string EA_API_SECRET = "moneyx-ea-secret-2024-secure-key-v1";

input group "=== Time Filter ==="
input bool     InpUseTimeFilter     = false;
input string   InpSession1          = "03:10-12:40";
input string   InpSession2          = "15:10-22:00";
input string   InpSession3          = "";
input string   InpFridaySession1    = "03:10-12:40";
input string   InpFridaySession2    = "";
input string   InpFridaySession3    = "";
input bool     InpTradeMonday       = true;
input bool     InpTradeTuesday      = true;
input bool     InpTradeWednesday    = true;
input bool     InpTradeThursday     = true;
input bool     InpTradeFriday       = true;
input bool     InpTradeSaturday     = false;
input bool     InpTradeSunday       = false;

input group "=== News Filter ==="
input group "=== Daily Profit Pause ==="
input bool     InpEnableDailyProfitPause = false;
input double   InpDailyProfitTarget      = 100.0;

input bool     InpEnableNewsFilter   = false;
input bool     InpNewsUseChartCurrency = false;
input string   InpNewsCurrencies     = "USD";
input bool     InpFilterLowNews      = false;
input int      InpPauseBeforeLow     = 60;
input int      InpPauseAfterLow      = 30;
input bool     InpFilterMedNews      = false;
input int      InpPauseBeforeMed     = 60;
input int      InpPauseAfterMed      = 30;
input bool     InpFilterHighNews     = true;
input int      InpPauseBeforeHigh    = 240;
input int      InpPauseAfterHigh     = 240;
input bool     InpFilterCustomNews   = true;
input string   InpCustomNewsKeywords = "PMI;Unemployment Claims;Non-Farm;FOMC;Fed Chair Powell";
input int      InpPauseBeforeCustom  = 300;
input int      InpPauseAfterCustom   = 300;

input group "=== ZigZag Multi-Timeframe Settings ==="
input int              ZZ_Depth            = 12;
input int              ZZ_Deviation        = 5;
input int              ZZ_Backstep         = 3;
input ENUM_TIMEFRAMES  ZZ_ConfirmTF        = PERIOD_H4;
input bool             ZZ_UseM30           = true;
input bool             ZZ_UseM15           = true;
input bool             ZZ_UseM5            = false;
input bool             ZZ_UseConfirmTFEntry= false;

input group "=== CDC Action Zone Trend Filter ==="
input bool             InpUseCDCFilter     = false;
input ENUM_TIMEFRAMES  InpCDCTimeframe     = PERIOD_D1;
input int              InpCDCFastPeriod    = 12;
input int              InpCDCSlowPeriod    = 26;
input bool             InpCDCRequireCross  = false;

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                   |
//+------------------------------------------------------------------+
CTrade         trade;
PairState      g_pairs[5];
bool           g_eaStopped = false;
bool           g_eaIsPaused = false;
bool           g_atrChartHidden = false;
int            g_atrHideAttempts = 0;
double         g_maxDD = 0;
bool           g_newOrderBlocked = false;

// Daily Profit Pause
bool           g_dailyProfitPaused = false;
datetime       g_dailyProfitPauseDay = 0;

// Global Accumulate
double         g_globalAccumBaseline = 0;
double         g_globalAccumProfit = 0;
bool           g_globalHadPositions = false;

// License
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

// News Filter
NewsEvent g_newsEvents[];
int g_newsEventCount = 0;
datetime g_lastNewsRefresh = 0;
bool g_isNewsPaused = false;
string g_nextNewsTitle = "";
datetime g_nextNewsTime = 0;
string g_newsStatus = "OK";
datetime g_lastGoodNewsTime = 0;
bool g_usingCachedNews = false;
string g_newsCacheFile = "AssetMinerNewsCache.txt";
datetime g_lastFileCacheSave = 0;
bool g_webRequestConfigured = true;
datetime g_lastWebRequestCheck = 0;
datetime g_lastWebRequestAlert = 0;
int g_webRequestCheckInterval = 3600;
bool g_forceNewsRefresh = false;
bool g_lastPausedState = false;
string g_lastPauseKey = "";
datetime g_newsPauseEndTime = 0;

//+------------------------------------------------------------------+
//| Copy inputs to PairState (called in OnInit)                        |
//+------------------------------------------------------------------+
void InitPairSettings(int p, bool en, string sym, int magicOff, double lot,
   int glMax, ENUM_LOT_MODE glLM, string glCL, double glAL, double glMF,
   ENUM_GAP_TYPE glGT, int glPts, string glCD, ENUM_TIMEFRAMES glATF, int glAP,
   double glAM, ENUM_ATR_REF glAR, int glMG, bool glOS, bool glON, bool glDS,
   bool gpEn, int gpMax, ENUM_LOT_MODE gpLM, string gpCL, double gpAL, double gpMF,
   ENUM_GAP_TYPE gpGT, int gpPts, string gpCD, ENUM_TIMEFRAMES gpATF, int gpAP,
   double gpAM, ENUM_ATR_REF gpAR, int gpMG, bool gpON,
   bool uAccum, double aTarget,
   bool uMatch, double mProfit, int mMaxLoss, int mMinPO)
{
   g_pairs[p].enabled = en;
   g_pairs[p].symbol = sym;
   g_pairs[p].magic = MagicNumber + magicOff;
   g_pairs[p].commentPrefix = "AM_P" + IntegerToString(p + 1) + "_";
   g_pairs[p].initialLot = lot;
   // Grid Loss
   g_pairs[p].gl_MaxTrades = glMax;
   g_pairs[p].gl_LotMode = glLM;
   g_pairs[p].gl_CustomLots = glCL;
   g_pairs[p].gl_AddLotPerLevel = glAL;
   g_pairs[p].gl_MultiplyFactor = glMF;
   g_pairs[p].gl_GapType = glGT;
   g_pairs[p].gl_Points = glPts;
   g_pairs[p].gl_CustomDistance = glCD;
   g_pairs[p].gl_ATR_TF = glATF;
   g_pairs[p].gl_ATR_Period = glAP;
   g_pairs[p].gl_ATR_Multiplier = glAM;
   g_pairs[p].gl_ATR_Reference = glAR;
   g_pairs[p].gl_MinGapPoints = glMG;
   g_pairs[p].gl_OnlyInSignal = glOS;
   g_pairs[p].gl_OnlyNewCandle = glON;
   g_pairs[p].gl_DontSameCandle = glDS;
   // Grid Profit
   g_pairs[p].gp_Enable = gpEn;
   g_pairs[p].gp_MaxTrades = gpMax;
   g_pairs[p].gp_LotMode = gpLM;
   g_pairs[p].gp_CustomLots = gpCL;
   g_pairs[p].gp_AddLotPerLevel = gpAL;
   g_pairs[p].gp_MultiplyFactor = gpMF;
   g_pairs[p].gp_GapType = gpGT;
   g_pairs[p].gp_Points = gpPts;
   g_pairs[p].gp_CustomDistance = gpCD;
   g_pairs[p].gp_ATR_TF = gpATF;
   g_pairs[p].gp_ATR_Period = gpAP;
   g_pairs[p].gp_ATR_Multiplier = gpAM;
   g_pairs[p].gp_ATR_Reference = gpAR;
   g_pairs[p].gp_MinGapPoints = gpMG;
   g_pairs[p].gp_OnlyNewCandle = gpON;
   // Accumulate
   g_pairs[p].useAccumulate = uAccum;
   g_pairs[p].accumTarget = aTarget;
   // Matching
   g_pairs[p].useMatching = uMatch;
   g_pairs[p].matchMinProfit = mProfit;
   g_pairs[p].matchMaxLoss = mMaxLoss;
   g_pairs[p].matchMinProfitOrders = mMinPO;
   // Init runtime state
   g_pairs[p].handleSMA = INVALID_HANDLE;
   g_pairs[p].handleATR_Loss = INVALID_HANDLE;
   g_pairs[p].handleATR_Profit = INVALID_HANDLE;
   ArraySetAsSeries(g_pairs[p].bufSMA, true);
   ArraySetAsSeries(g_pairs[p].bufATR_Loss, true);
   ArraySetAsSeries(g_pairs[p].bufATR_Profit, true);
   g_pairs[p].lastBarTime = 0;
   g_pairs[p].lastInitialCandleTime = 0;
   g_pairs[p].lastGridLossCandleTime = 0;
   g_pairs[p].lastGridProfitCandleTime = 0;
   g_pairs[p].justClosedBuy = false;
   g_pairs[p].justClosedSell = false;
   g_pairs[p].trailingSL_Buy = 0;
   g_pairs[p].trailingSL_Sell = 0;
   g_pairs[p].trailingActive_Buy = false;
   g_pairs[p].trailingActive_Sell = false;
   g_pairs[p].breakevenDone_Buy = false;
   g_pairs[p].breakevenDone_Sell = false;
   g_pairs[p].initialBuyPrice = 0;
   g_pairs[p].initialSellPrice = 0;
   g_pairs[p].accumulatedProfit = 0;
   g_pairs[p].accumulateBaseline = 0;
   g_pairs[p].hadPositions = false;
   g_pairs[p].activeTFCount = 0;
   g_pairs[p].h4TFIndex = -1;
   g_pairs[p].h4Direction = "NONE";
   g_pairs[p].lastH4Bar = 0;
   g_pairs[p].cdcTrend = "NEUTRAL";
   g_pairs[p].cdcFast = 0;
   g_pairs[p].cdcSlow = 0;
   g_pairs[p].cdcReady = false;
   g_pairs[p].lastCdcCandle = 0;
   g_pairs[p].lastMatchingBarTime = 0;
}

//+------------------------------------------------------------------+
//| Forward declarations                                               |
//+------------------------------------------------------------------+
bool IsTesterMode();
bool InitLicense(string baseUrl, int checkMin, int syncMin);
void ShowLicensePopup(ENUM_LICENSE_STATUS status);
bool OnTickLicense();
void RefreshNewsData();
bool IsNewsTimePaused();
bool IsWithinTradingHours();
void LoadNewsCacheFromFile();
bool CheckWebRequestConfiguration();
int TotalOrderCountPair(int p);
int TotalOrderCountAll();
double CalcTotalHistoryProfitPair(int p);
void RecoverInitialPricesPair(int p);
void InitZigZagHandlesPair(int p);
void RecoverTFInitialPricesPair(int p);
void DisplayDashboard();
void DrawLinesPair(int p);
double CalcDailyPLAll();
double CalcTotalClosedLotsAll();
int CalcTotalClosedOrdersAll();
double CalcMonthlyPLAll();
double CalculateTotalLotsPair(int p, int side);
double CalculateTotalLotsAll(int side);
bool SyncAccountData();
bool SyncAccountDataWithEvent(ENUM_SYNC_EVENT eventType);

//+------------------------------------------------------------------+
//| Expert initialization                                              |
//+------------------------------------------------------------------+
int OnInit()
{
   g_isTesterMode = IsTesterMode();

   if(g_isTesterMode)
   {
      Print("ASSET MINER EA v4.0 - TESTER MODE (Multi-Pair)");
      g_isLicenseValid = true;
      g_licenseStatus = LICENSE_VALID;
   }
   else
   {
      Print("ASSET MINER EA v4.0 - LIVE TRADING MODE (Multi-Pair)");
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

   trade.SetDeviationInPoints(MaxSlippage);
   trade.SetTypeFilling(ORDER_FILLING_IOC);

   // Initialize all 5 pair settings from inputs
   InitPairSettings(0, Set1_Enable, Set1_Symbol, Set1_MagicOffset, Set1_InitialLot,
      Set1_GL_MaxTrades, Set1_GL_LotMode, Set1_GL_CustomLots, Set1_GL_AddLotPerLvl, Set1_GL_MultFactor,
      Set1_GL_GapType, Set1_GL_Points, Set1_GL_CustomDist, Set1_GL_ATR_TF, Set1_GL_ATR_Period,
      Set1_GL_ATR_Mult, Set1_GL_ATR_Ref, Set1_GL_MinGap, Set1_GL_OnlySignal, Set1_GL_OnlyNewBar, Set1_GL_DontSameBar,
      Set1_GP_Enable, Set1_GP_MaxTrades, Set1_GP_LotMode, Set1_GP_CustomLots, Set1_GP_AddLotPerLvl, Set1_GP_MultFactor,
      Set1_GP_GapType, Set1_GP_Points, Set1_GP_CustomDist, Set1_GP_ATR_TF, Set1_GP_ATR_Period,
      Set1_GP_ATR_Mult, Set1_GP_ATR_Ref, Set1_GP_MinGap, Set1_GP_OnlyNewBar,
      Set1_UseAccum, Set1_AccumTarget, Set1_UseMatching, Set1_MatchMinProfit, Set1_MatchMaxLoss, Set1_MatchMinPO);

   InitPairSettings(1, Set2_Enable, Set2_Symbol, Set2_MagicOffset, Set2_InitialLot,
      Set2_GL_MaxTrades, Set2_GL_LotMode, Set2_GL_CustomLots, Set2_GL_AddLotPerLvl, Set2_GL_MultFactor,
      Set2_GL_GapType, Set2_GL_Points, Set2_GL_CustomDist, Set2_GL_ATR_TF, Set2_GL_ATR_Period,
      Set2_GL_ATR_Mult, Set2_GL_ATR_Ref, Set2_GL_MinGap, Set2_GL_OnlySignal, Set2_GL_OnlyNewBar, Set2_GL_DontSameBar,
      Set2_GP_Enable, Set2_GP_MaxTrades, Set2_GP_LotMode, Set2_GP_CustomLots, Set2_GP_AddLotPerLvl, Set2_GP_MultFactor,
      Set2_GP_GapType, Set2_GP_Points, Set2_GP_CustomDist, Set2_GP_ATR_TF, Set2_GP_ATR_Period,
      Set2_GP_ATR_Mult, Set2_GP_ATR_Ref, Set2_GP_MinGap, Set2_GP_OnlyNewBar,
      Set2_UseAccum, Set2_AccumTarget, Set2_UseMatching, Set2_MatchMinProfit, Set2_MatchMaxLoss, Set2_MatchMinPO);

   InitPairSettings(2, Set3_Enable, Set3_Symbol, Set3_MagicOffset, Set3_InitialLot,
      Set3_GL_MaxTrades, Set3_GL_LotMode, Set3_GL_CustomLots, Set3_GL_AddLotPerLvl, Set3_GL_MultFactor,
      Set3_GL_GapType, Set3_GL_Points, Set3_GL_CustomDist, Set3_GL_ATR_TF, Set3_GL_ATR_Period,
      Set3_GL_ATR_Mult, Set3_GL_ATR_Ref, Set3_GL_MinGap, Set3_GL_OnlySignal, Set3_GL_OnlyNewBar, Set3_GL_DontSameBar,
      Set3_GP_Enable, Set3_GP_MaxTrades, Set3_GP_LotMode, Set3_GP_CustomLots, Set3_GP_AddLotPerLvl, Set3_GP_MultFactor,
      Set3_GP_GapType, Set3_GP_Points, Set3_GP_CustomDist, Set3_GP_ATR_TF, Set3_GP_ATR_Period,
      Set3_GP_ATR_Mult, Set3_GP_ATR_Ref, Set3_GP_MinGap, Set3_GP_OnlyNewBar,
      Set3_UseAccum, Set3_AccumTarget, Set3_UseMatching, Set3_MatchMinProfit, Set3_MatchMaxLoss, Set3_MatchMinPO);

   InitPairSettings(3, Set4_Enable, Set4_Symbol, Set4_MagicOffset, Set4_InitialLot,
      Set4_GL_MaxTrades, Set4_GL_LotMode, Set4_GL_CustomLots, Set4_GL_AddLotPerLvl, Set4_GL_MultFactor,
      Set4_GL_GapType, Set4_GL_Points, Set4_GL_CustomDist, Set4_GL_ATR_TF, Set4_GL_ATR_Period,
      Set4_GL_ATR_Mult, Set4_GL_ATR_Ref, Set4_GL_MinGap, Set4_GL_OnlySignal, Set4_GL_OnlyNewBar, Set4_GL_DontSameBar,
      Set4_GP_Enable, Set4_GP_MaxTrades, Set4_GP_LotMode, Set4_GP_CustomLots, Set4_GP_AddLotPerLvl, Set4_GP_MultFactor,
      Set4_GP_GapType, Set4_GP_Points, Set4_GP_CustomDist, Set4_GP_ATR_TF, Set4_GP_ATR_Period,
      Set4_GP_ATR_Mult, Set4_GP_ATR_Ref, Set4_GP_MinGap, Set4_GP_OnlyNewBar,
      Set4_UseAccum, Set4_AccumTarget, Set4_UseMatching, Set4_MatchMinProfit, Set4_MatchMaxLoss, Set4_MatchMinPO);

   InitPairSettings(4, Set5_Enable, Set5_Symbol, Set5_MagicOffset, Set5_InitialLot,
      Set5_GL_MaxTrades, Set5_GL_LotMode, Set5_GL_CustomLots, Set5_GL_AddLotPerLvl, Set5_GL_MultFactor,
      Set5_GL_GapType, Set5_GL_Points, Set5_GL_CustomDist, Set5_GL_ATR_TF, Set5_GL_ATR_Period,
      Set5_GL_ATR_Mult, Set5_GL_ATR_Ref, Set5_GL_MinGap, Set5_GL_OnlySignal, Set5_GL_OnlyNewBar, Set5_GL_DontSameBar,
      Set5_GP_Enable, Set5_GP_MaxTrades, Set5_GP_LotMode, Set5_GP_CustomLots, Set5_GP_AddLotPerLvl, Set5_GP_MultFactor,
      Set5_GP_GapType, Set5_GP_Points, Set5_GP_CustomDist, Set5_GP_ATR_TF, Set5_GP_ATR_Period,
      Set5_GP_ATR_Mult, Set5_GP_ATR_Ref, Set5_GP_MinGap, Set5_GP_OnlyNewBar,
      Set5_UseAccum, Set5_AccumTarget, Set5_UseMatching, Set5_MatchMinProfit, Set5_MatchMaxLoss, Set5_MatchMinPO);

   // Initialize each enabled pair
   for(int p = 0; p < 5; p++)
   {
      if(!g_pairs[p].enabled) continue;

      string sym = g_pairs[p].symbol;
      // Ensure symbol is available
      if(!g_isTesterMode) SymbolSelect(sym, true);

      // SMA handle (per-pair symbol)
      ENUM_TIMEFRAMES smaTF = (SMA_Timeframe == PERIOD_CURRENT) ? Period() : SMA_Timeframe;
      g_pairs[p].handleSMA = iMA(sym, smaTF, SMA_Period, 0, MODE_SMA, SMA_AppliedPrice);
      if(g_pairs[p].handleSMA == INVALID_HANDLE)
      {
         Print("ERROR: SMA handle failed for ", sym);
         g_pairs[p].enabled = false;
         continue;
      }

      // ATR handles
      if(g_isTesterMode && InpSkipATRInTester)
      {
         g_pairs[p].handleATR_Loss = INVALID_HANDLE;
         g_pairs[p].handleATR_Profit = INVALID_HANDLE;
      }
      else
      {
         g_pairs[p].handleATR_Loss = iATR(sym, g_pairs[p].gl_ATR_TF, g_pairs[p].gl_ATR_Period);
         g_pairs[p].handleATR_Profit = iATR(sym, g_pairs[p].gp_ATR_TF, g_pairs[p].gp_ATR_Period);
         if(g_pairs[p].handleATR_Loss == INVALID_HANDLE || g_pairs[p].handleATR_Profit == INVALID_HANDLE)
         {
            Print("WARNING: ATR handle failed for ", sym);
         }
      }

      g_pairs[p].hadPositions = (TotalOrderCountPair(p) > 0);

      // Accumulate baseline
      if(g_pairs[p].useAccumulate)
      {
         double hist = CalcTotalHistoryProfitPair(p);
         g_pairs[p].accumulateBaseline = hist;
         g_pairs[p].accumulatedProfit = 0;
      }

      // Recover initial prices
      RecoverInitialPricesPair(p);

      // ZigZag init
      if(EntryMode == ENTRY_ZIGZAG)
      {
         InitZigZagHandlesPair(p);
         RecoverTFInitialPricesPair(p);
      }

      Print("Pair ", p + 1, " [", sym, "] Magic=", g_pairs[p].magic, " initialized OK");
   }

   // Global accumulate baseline
   if(UseGlobalAccumulate)
   {
      g_globalAccumBaseline = CalcTotalHistoryProfitAll();
      g_globalAccumProfit = 0;
      g_globalHadPositions = (TotalOrderCountAll() > 0);
   }

   Print("Asset Miner EA v4.0 initialized - Multi-Pair mode");

   // News Filter Init
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

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                            |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   for(int p = 0; p < 5; p++)
   {
      if(g_pairs[p].handleSMA != INVALID_HANDLE) IndicatorRelease(g_pairs[p].handleSMA);
      if(g_pairs[p].handleATR_Loss != INVALID_HANDLE) IndicatorRelease(g_pairs[p].handleATR_Loss);
      if(g_pairs[p].handleATR_Profit != INVALID_HANDLE) IndicatorRelease(g_pairs[p].handleATR_Profit);
      for(int t = 0; t < g_pairs[p].activeTFCount; t++)
      {
         if(g_pairs[p].tfStates[t].handleZZ != INVALID_HANDLE)
            IndicatorRelease(g_pairs[p].tfStates[t].handleZZ);
      }
   }
   ObjectDelete(0, "GM_AvgBuyLine");
   ObjectDelete(0, "GM_AvgSellLine");
   ObjectDelete(0, "GM_TPBuyLine");
   ObjectDelete(0, "GM_TPSellLine");
   ObjectDelete(0, "GM_SLLine");
   ObjectsDeleteAll(0, "GM_Dash_");
   ObjectsDeleteAll(0, "GM_TBL_");
   ObjectsDeleteAll(0, "GM_Btn");
   Print("Asset Miner EA v4.0 deinitialized");
}

//+------------------------------------------------------------------+
//| ============== PER-PAIR CORE FUNCTIONS ========================= |
//+------------------------------------------------------------------+

void RecoverInitialPricesPair(int p)
{
   string prefix = g_pairs[p].commentPrefix;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != g_pairs[p].magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != g_pairs[p].symbol) continue;
      string comment = PositionGetString(POSITION_COMMENT);
      if(StringFind(comment, prefix + "INIT") >= 0 || StringFind(comment, "GM_INIT") >= 0)
      {
         long posType = PositionGetInteger(POSITION_TYPE);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         if(posType == POSITION_TYPE_BUY) g_pairs[p].initialBuyPrice = openPrice;
         else if(posType == POSITION_TYPE_SELL) g_pairs[p].initialSellPrice = openPrice;
      }
   }
}

double CalcTotalHistoryProfitPair(int p)
{
   double total = 0;
   if(!HistorySelect(0, TimeCurrent())) return 0;
   int totalDeals = HistoryDealsTotal();
   for(int i = 0; i < totalDeals; i++)
   {
      ulong dt2 = HistoryDealGetTicket(i);
      if(dt2 == 0) continue;
      if(HistoryDealGetInteger(dt2, DEAL_MAGIC) != g_pairs[p].magic) continue;
      if(HistoryDealGetString(dt2, DEAL_SYMBOL) != g_pairs[p].symbol) continue;
      long de = HistoryDealGetInteger(dt2, DEAL_ENTRY);
      if(de == DEAL_ENTRY_OUT || de == DEAL_ENTRY_INOUT)
         total += HistoryDealGetDouble(dt2, DEAL_PROFIT) + HistoryDealGetDouble(dt2, DEAL_SWAP);
   }
   return total;
}

double CalcTotalHistoryProfitAll()
{
   double total = 0;
   for(int p = 0; p < 5; p++)
   {
      if(g_pairs[p].enabled) total += CalcTotalHistoryProfitPair(p);
   }
   return total;
}

double CalcTotalClosedLotsPair(int p)
{
   double total = 0;
   if(!HistorySelect(0, TimeCurrent())) return 0;
   int totalDeals = HistoryDealsTotal();
   for(int i = 0; i < totalDeals; i++)
   {
      ulong dt2 = HistoryDealGetTicket(i);
      if(dt2 == 0) continue;
      if(HistoryDealGetInteger(dt2, DEAL_MAGIC) != g_pairs[p].magic) continue;
      if(HistoryDealGetString(dt2, DEAL_SYMBOL) != g_pairs[p].symbol) continue;
      long de = HistoryDealGetInteger(dt2, DEAL_ENTRY);
      if(de == DEAL_ENTRY_OUT || de == DEAL_ENTRY_INOUT)
         total += HistoryDealGetDouble(dt2, DEAL_VOLUME);
   }
   return total;
}

int CalcTotalClosedOrdersPair(int p)
{
   int count = 0;
   if(!HistorySelect(0, TimeCurrent())) return 0;
   int totalDeals = HistoryDealsTotal();
   for(int i = 0; i < totalDeals; i++)
   {
      ulong dt2 = HistoryDealGetTicket(i);
      if(dt2 == 0) continue;
      if(HistoryDealGetInteger(dt2, DEAL_MAGIC) != g_pairs[p].magic) continue;
      if(HistoryDealGetString(dt2, DEAL_SYMBOL) != g_pairs[p].symbol) continue;
      long de = HistoryDealGetInteger(dt2, DEAL_ENTRY);
      if(de == DEAL_ENTRY_OUT || de == DEAL_ENTRY_INOUT) count++;
   }
   return count;
}

double CalcMonthlyPLPair(int p)
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.day = 1; dt.hour = 0; dt.min = 0; dt.sec = 0;
   datetime monthStart = StructToTime(dt);
   double total = 0;
   if(!HistorySelect(monthStart, TimeCurrent())) return 0;
   int totalDeals = HistoryDealsTotal();
   for(int i = 0; i < totalDeals; i++)
   {
      ulong dt2 = HistoryDealGetTicket(i);
      if(dt2 == 0) continue;
      if(HistoryDealGetInteger(dt2, DEAL_MAGIC) != g_pairs[p].magic) continue;
      if(HistoryDealGetString(dt2, DEAL_SYMBOL) != g_pairs[p].symbol) continue;
      long de = HistoryDealGetInteger(dt2, DEAL_ENTRY);
      if(de == DEAL_ENTRY_OUT || de == DEAL_ENTRY_INOUT)
         total += HistoryDealGetDouble(dt2, DEAL_PROFIT) + HistoryDealGetDouble(dt2, DEAL_SWAP);
   }
   return total;
}

double CalcDailyPLAll()
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
      ulong dt2 = HistoryDealGetTicket(i);
      if(dt2 == 0) continue;
      long magic = HistoryDealGetInteger(dt2, DEAL_MAGIC);
      bool isOurs = false;
      for(int pp = 0; pp < 5; pp++)
      {
         if(g_pairs[pp].enabled && magic == g_pairs[pp].magic) { isOurs = true; break; }
      }
      if(!isOurs) continue;
      long de = HistoryDealGetInteger(dt2, DEAL_ENTRY);
      if(de == DEAL_ENTRY_OUT || de == DEAL_ENTRY_INOUT)
         total += HistoryDealGetDouble(dt2, DEAL_PROFIT) + HistoryDealGetDouble(dt2, DEAL_SWAP);
   }
   return total;
}

double CalcTotalClosedLotsAll()
{
   double total = 0;
   for(int p = 0; p < 5; p++)
   {
      if(g_pairs[p].enabled) total += CalcTotalClosedLotsPair(p);
   }
   return total;
}

int CalcTotalClosedOrdersAll()
{
   int total = 0;
   for(int p = 0; p < 5; p++)
   {
      if(g_pairs[p].enabled) total += CalcTotalClosedOrdersPair(p);
   }
   return total;
}

double CalcMonthlyPLAll()
{
   double total = 0;
   for(int p = 0; p < 5; p++)
   {
      if(g_pairs[p].enabled) total += CalcMonthlyPLPair(p);
   }
   return total;
}

double CalculateTotalLotsPair(int p, int side)
{
   double totalLots = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != g_pairs[p].magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != g_pairs[p].symbol) continue;
      long posType = PositionGetInteger(POSITION_TYPE);
      if(side == 0 && posType == POSITION_TYPE_BUY) totalLots += PositionGetDouble(POSITION_VOLUME);
      else if(side == 1 && posType == POSITION_TYPE_SELL) totalLots += PositionGetDouble(POSITION_VOLUME);
      else if(side == -1) totalLots += PositionGetDouble(POSITION_VOLUME);
   }
   return totalLots;
}

double CalculateTotalLotsAll(int side)
{
   double total = 0;
   for(int p = 0; p < 5; p++)
   {
      if(g_pairs[p].enabled) total += CalculateTotalLotsPair(p, side);
   }
   return total;
}

double CalculateTotalFloatingPLSide(int side)
{
   double total = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      long magic = PositionGetInteger(POSITION_MAGIC);
      bool isOurs = false;
      for(int pp = 0; pp < 5; pp++)
      {
         if(g_pairs[pp].enabled && magic == g_pairs[pp].magic) { isOurs = true; break; }
      }
      if(!isOurs) continue;
      long posType = PositionGetInteger(POSITION_TYPE);
      if(side == 0 && posType == POSITION_TYPE_BUY) total += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      else if(side == 1 && posType == POSITION_TYPE_SELL) total += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return total;
}

int TotalOrderCountSide(int side)
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      long magic = PositionGetInteger(POSITION_MAGIC);
      bool isOurs = false;
      for(int pp = 0; pp < 5; pp++)
      {
         if(g_pairs[pp].enabled && magic == g_pairs[pp].magic) { isOurs = true; break; }
      }
      if(!isOurs) continue;
      long posType = PositionGetInteger(POSITION_TYPE);
      if(side == 0 && posType == POSITION_TYPE_BUY) count++;
      else if(side == 1 && posType == POSITION_TYPE_SELL) count++;
   }
   return count;
}

void CountPositionsPair(int p, int &buyCount, int &sellCount,
                        int &gridLossBuy, int &gridLossSell,
                        int &gridProfitBuy, int &gridProfitSell,
                        bool &hasInitialBuy, bool &hasInitialSell)
{
   buyCount = 0; sellCount = 0;
   gridLossBuy = 0; gridLossSell = 0;
   gridProfitBuy = 0; gridProfitSell = 0;
   hasInitialBuy = false; hasInitialSell = false;
   string pfx = g_pairs[p].commentPrefix;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != g_pairs[p].magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != g_pairs[p].symbol) continue;
      string comment = PositionGetString(POSITION_COMMENT);
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

int TotalOrderCountPair(int p)
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != g_pairs[p].magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != g_pairs[p].symbol) continue;
      count++;
   }
   return count;
}

int TotalOrderCountAll()
{
   int count = 0;
   for(int p = 0; p < 5; p++)
   {
      if(g_pairs[p].enabled) count += TotalOrderCountPair(p);
   }
   return count;
}

bool OpenOrderPair(int p, ENUM_ORDER_TYPE orderType, double lots, string comment)
{
   string sym = g_pairs[p].symbol;
   double price = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(sym, SYMBOL_ASK) : SymbolInfoDouble(sym, SYMBOL_BID);
   double minLot = SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP);
   lots = MathMax(minLot, MathMin(maxLot, NormalizeDouble(MathRound(lots / lotStep) * lotStep, 2)));

   trade.SetExpertMagicNumber(g_pairs[p].magic);
   bool ok = false;
   if(orderType == ORDER_TYPE_BUY)
      ok = trade.Buy(lots, sym, price, 0, 0, comment);
   else
      ok = trade.Sell(lots, sym, price, 0, 0, comment);

   if(!ok) Print("ERROR: Order failed [", sym, "] - ", trade.ResultRetcodeDescription());
   else Print("Order [", sym, "]: ", comment, " Lots=", lots, " Price=", price);
   return ok;
}

double CalculateAveragePricePair(int p, ENUM_POSITION_TYPE side)
{
   double totalLots = 0, totalWeighted = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != g_pairs[p].magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != g_pairs[p].symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) != side) continue;
      double vol = PositionGetDouble(POSITION_VOLUME);
      totalLots += vol;
      totalWeighted += PositionGetDouble(POSITION_PRICE_OPEN) * vol;
   }
   return (totalLots > 0) ? totalWeighted / totalLots : 0;
}

double CalculateFloatingPLPair(int p, ENUM_POSITION_TYPE side)
{
   double totalPL = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != g_pairs[p].magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != g_pairs[p].symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) != side) continue;
      totalPL += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return totalPL;
}

double CalculateTotalFloatingPLPair(int p)
{
   double totalPL = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != g_pairs[p].magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != g_pairs[p].symbol) continue;
      totalPL += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return totalPL;
}

double CalculateAllFloatingPL()
{
   double total = 0;
   for(int p = 0; p < 5; p++)
   {
      if(g_pairs[p].enabled) total += CalculateTotalFloatingPLPair(p);
   }
   return total;
}

double CalculateTotalLotsPair(int p, ENUM_POSITION_TYPE side)
{
   double totalLots = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != g_pairs[p].magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != g_pairs[p].symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) != side) continue;
      totalLots += PositionGetDouble(POSITION_VOLUME);
   }
   return totalLots;
}

void CloseAllSidePair(int p, ENUM_POSITION_TYPE side)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != g_pairs[p].magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != g_pairs[p].symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) != side) continue;
      trade.PositionClose(ticket);
   }
   if(side == POSITION_TYPE_BUY) g_pairs[p].justClosedBuy = true;
   else g_pairs[p].justClosedSell = true;
}

void CloseAllPositionsPair(int p)
{
   bool hadBuy = false, hadSell = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != g_pairs[p].magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != g_pairs[p].symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) hadBuy = true;
      else hadSell = true;
      trade.PositionClose(ticket);
   }
   if(hadBuy) { g_pairs[p].justClosedBuy = true; g_pairs[p].initialBuyPrice = 0; }
   if(hadSell) { g_pairs[p].justClosedSell = true; g_pairs[p].initialSellPrice = 0; }
   ResetTrailingStatePair(p);
}

void CloseAllPositionsAll()
{
   for(int p = 0; p < 5; p++)
   {
      if(g_pairs[p].enabled) CloseAllPositionsPair(p);
   }
}

void ResetTrailingStatePair(int p)
{
   g_pairs[p].trailingSL_Buy = 0;
   g_pairs[p].trailingSL_Sell = 0;
   g_pairs[p].trailingActive_Buy = false;
   g_pairs[p].trailingActive_Sell = false;
   g_pairs[p].breakevenDone_Buy = false;
   g_pairs[p].breakevenDone_Sell = false;
}

//+------------------------------------------------------------------+
//| TP/SL Management per pair                                          |
//+------------------------------------------------------------------+
void ManageTPSLPair(int p)
{
   string sym = g_pairs[p].symbol;
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);

   // BUY side
   double avgBuy = CalculateAveragePricePair(p, POSITION_TYPE_BUY);
   if(avgBuy > 0)
   {
      double plBuy = CalculateFloatingPLPair(p, POSITION_TYPE_BUY);
      double bid = SymbolInfoDouble(sym, SYMBOL_BID);
      bool closeTP = false, closeSL = false;

      if(!EnablePerOrderTrailing)
      {
         if(UseTP_Dollar && plBuy >= TP_DollarAmount) closeTP = true;
         if(UseTP_Points && bid >= avgBuy + TP_Points * point) closeTP = true;
         if(UseTP_PercentBalance && plBuy >= balance * TP_PercentBalance / 100.0) closeTP = true;
      }
      if(closeTP)
      {
         Print("TP HIT [", sym, " BUY]: PL=", plBuy);
         CloseAllSidePair(p, POSITION_TYPE_BUY);
         g_pairs[p].initialBuyPrice = 0;
         ResetTrailingStatePair(p);
         return;
      }
      if(EnableSL && !EnablePerOrderTrailing)
      {
         if(UseSL_Dollar && plBuy <= -SL_DollarAmount) closeSL = true;
         if(UseSL_Points && bid <= avgBuy - SL_Points * point) closeSL = true;
         if(UseSL_PercentBalance && plBuy <= -(balance * SL_PercentBalance / 100.0)) closeSL = true;
         if(closeSL)
         {
            if(SL_ActionMode == SL_CLOSE_ALL_STOP)
            {
               CloseAllPositionsAll();
               g_eaStopped = true;
               Print("EA STOPPED by SL [", sym, " BUY]");
            }
            else
            {
               CloseAllSidePair(p, POSITION_TYPE_BUY);
               g_pairs[p].initialBuyPrice = 0;
               ResetTrailingStatePair(p);
            }
            return;
         }
      }
   }

   // SELL side
   double avgSell = CalculateAveragePricePair(p, POSITION_TYPE_SELL);
   if(avgSell > 0)
   {
      double plSell = CalculateFloatingPLPair(p, POSITION_TYPE_SELL);
      double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
      bool closeTP2 = false, closeSL2 = false;

      if(!EnablePerOrderTrailing)
      {
         if(UseTP_Dollar && plSell >= TP_DollarAmount) closeTP2 = true;
         if(UseTP_Points && ask <= avgSell - TP_Points * point) closeTP2 = true;
         if(UseTP_PercentBalance && plSell >= balance * TP_PercentBalance / 100.0) closeTP2 = true;
      }
      if(closeTP2)
      {
         Print("TP HIT [", sym, " SELL]: PL=", plSell);
         CloseAllSidePair(p, POSITION_TYPE_SELL);
         g_pairs[p].initialSellPrice = 0;
         ResetTrailingStatePair(p);
         return;
      }
      if(EnableSL && !EnablePerOrderTrailing)
      {
         if(UseSL_Dollar && plSell <= -SL_DollarAmount) closeSL2 = true;
         if(UseSL_Points && ask >= avgSell + SL_Points * point) closeSL2 = true;
         if(UseSL_PercentBalance && plSell <= -(balance * SL_PercentBalance / 100.0)) closeSL2 = true;
         if(closeSL2)
         {
            if(SL_ActionMode == SL_CLOSE_ALL_STOP)
            {
               CloseAllPositionsAll();
               g_eaStopped = true;
               Print("EA STOPPED by SL [", sym, " SELL]");
            }
            else
            {
               CloseAllSidePair(p, POSITION_TYPE_SELL);
               g_pairs[p].initialSellPrice = 0;
               ResetTrailingStatePair(p);
            }
            return;
         }
      }
   }

   // Per-pair accumulate close
   if(g_pairs[p].useAccumulate)
   {
      int cc = TotalOrderCountPair(p);
      if(g_pairs[p].hadPositions && cc == 0)
      {
         g_pairs[p].accumulateBaseline = CalcTotalHistoryProfitPair(p);
         g_pairs[p].accumulatedProfit = 0;
         g_pairs[p].hadPositions = false;
         return;
      }
      if(cc > 0) g_pairs[p].hadPositions = true;

      double totalHist = CalcTotalHistoryProfitPair(p);
      g_pairs[p].accumulatedProfit = totalHist - g_pairs[p].accumulateBaseline;
      double totalFloat = CalculateTotalFloatingPLPair(p);
      double accumTotal = g_pairs[p].accumulatedProfit + totalFloat;

      if(accumTotal >= g_pairs[p].accumTarget && accumTotal > 0)
      {
         Print("ACCUMULATE TARGET [", sym, "]: ", accumTotal, " / ", g_pairs[p].accumTarget);
         CloseAllPositionsPair(p);
         Sleep(500);
         double newHist = CalcTotalHistoryProfitPair(p);
         g_pairs[p].accumulateBaseline = newHist;
         g_pairs[p].accumulatedProfit = 0;
         g_pairs[p].hadPositions = false;
      }
   }
}

//+------------------------------------------------------------------+
//| Per-Order Trailing per pair                                        |
//+------------------------------------------------------------------+
void ManagePerOrderTrailingPair(int p)
{
   string sym = g_pairs[p].symbol;
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   int stopLevel = (int)SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL);
   if(stopLevel < 1) stopLevel = 1;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != g_pairs[p].magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != sym) continue;

      long posType = PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double currentSL = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);

      if(posType == POSITION_TYPE_BUY)
      {
         double profitPoints = (bid - openPrice) / point;
         if(InpEnableBreakeven && profitPoints >= InpBreakevenTarget)
         {
            double beLevel = NormalizeDouble(openPrice + InpBreakevenOffset * point, digits);
            if(currentSL == 0 || currentSL < beLevel)
            {
               double minSL = NormalizeDouble(bid - stopLevel * point, digits);
               double finalBE = MathMin(beLevel, minSL);
               if(finalBE > currentSL || currentSL == 0)
               {
                  if(trade.PositionModify(ticket, finalBE, tp))
                     currentSL = finalBE;
               }
            }
         }
         if(InpEnableTrailing && profitPoints >= InpTrailingStop)
         {
            double newSL = NormalizeDouble(bid - InpTrailingStop * point, digits);
            double beFloor = NormalizeDouble(openPrice + InpBreakevenOffset * point, digits);
            if(newSL < beFloor) newSL = beFloor;
            double minSL = NormalizeDouble(bid - stopLevel * point, digits);
            if(newSL > minSL) newSL = minSL;
            if(currentSL == 0 || newSL > currentSL + InpTrailingStep * point)
               trade.PositionModify(ticket, newSL, tp);
         }
      }
      else if(posType == POSITION_TYPE_SELL)
      {
         double profitPoints = (openPrice - ask) / point;
         if(InpEnableBreakeven && profitPoints >= InpBreakevenTarget)
         {
            double beLevel = NormalizeDouble(openPrice - InpBreakevenOffset * point, digits);
            if(currentSL == 0 || currentSL > beLevel)
            {
               double maxSL = NormalizeDouble(ask + stopLevel * point, digits);
               double finalBE = MathMax(beLevel, maxSL);
               if(currentSL == 0 || finalBE < currentSL)
               {
                  if(trade.PositionModify(ticket, finalBE, tp))
                     currentSL = finalBE;
               }
            }
         }
         if(InpEnableTrailing && profitPoints >= InpTrailingStop)
         {
            double newSL = NormalizeDouble(ask + InpTrailingStop * point, digits);
            double maxSL = NormalizeDouble(ask + stopLevel * point, digits);
            if(newSL < maxSL) newSL = maxSL;
            if(currentSL == 0 || newSL < currentSL - InpTrailingStep * point)
               trade.PositionModify(ticket, newSL, tp);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Average-Based Trailing per pair                                    |
//+------------------------------------------------------------------+
void ManageTrailingStopPair(int p)
{
   string sym = g_pairs[p].symbol;
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   double ask = SymbolInfoDouble(sym, SYMBOL_ASK);

   double avgBuy = CalculateAveragePricePair(p, POSITION_TYPE_BUY);
   if(avgBuy > 0)
   {
      double beLevel = avgBuy + BreakevenBuffer * point;
      if(EnableTrailingStop)
      {
         double trailAct = avgBuy + TrailingActivation * point;
         if(bid >= trailAct)
         {
            g_pairs[p].trailingActive_Buy = true;
            double newSL = MathMax(bid - TrailingStep * point, beLevel);
            if(newSL > g_pairs[p].trailingSL_Buy)
            {
               g_pairs[p].trailingSL_Buy = newSL;
               ApplyTrailingSLPair(p, POSITION_TYPE_BUY, newSL);
            }
         }
      }
      if(EnableBreakeven && !g_pairs[p].breakevenDone_Buy)
      {
         if(bid >= avgBuy + BreakevenActivation * point)
         {
            g_pairs[p].breakevenDone_Buy = true;
            if(g_pairs[p].trailingSL_Buy < beLevel)
            {
               g_pairs[p].trailingSL_Buy = beLevel;
               ApplyTrailingSLPair(p, POSITION_TYPE_BUY, beLevel);
            }
         }
      }
      if(g_pairs[p].trailingActive_Buy && g_pairs[p].trailingSL_Buy > 0 && bid <= g_pairs[p].trailingSL_Buy)
      {
         CloseAllSidePair(p, POSITION_TYPE_BUY);
         g_pairs[p].initialBuyPrice = 0;
         ResetTrailingStatePair(p);
         return;
      }
   }
   else
   {
      g_pairs[p].trailingSL_Buy = 0;
      g_pairs[p].trailingActive_Buy = false;
      g_pairs[p].breakevenDone_Buy = false;
   }

   double avgSell = CalculateAveragePricePair(p, POSITION_TYPE_SELL);
   if(avgSell > 0)
   {
      double beLevelSell = avgSell - BreakevenBuffer * point;
      if(EnableTrailingStop)
      {
         if(ask <= avgSell - TrailingActivation * point)
         {
            g_pairs[p].trailingActive_Sell = true;
            double newSL = MathMin(ask + TrailingStep * point, beLevelSell);
            if(g_pairs[p].trailingSL_Sell == 0 || newSL < g_pairs[p].trailingSL_Sell)
            {
               g_pairs[p].trailingSL_Sell = newSL;
               ApplyTrailingSLPair(p, POSITION_TYPE_SELL, newSL);
            }
         }
      }
      if(EnableBreakeven && !g_pairs[p].breakevenDone_Sell)
      {
         if(ask <= avgSell - BreakevenActivation * point)
         {
            g_pairs[p].breakevenDone_Sell = true;
            if(g_pairs[p].trailingSL_Sell == 0 || g_pairs[p].trailingSL_Sell > beLevelSell)
            {
               g_pairs[p].trailingSL_Sell = beLevelSell;
               ApplyTrailingSLPair(p, POSITION_TYPE_SELL, beLevelSell);
            }
         }
      }
      if(g_pairs[p].trailingActive_Sell && g_pairs[p].trailingSL_Sell > 0 && ask >= g_pairs[p].trailingSL_Sell)
      {
         CloseAllSidePair(p, POSITION_TYPE_SELL);
         g_pairs[p].initialSellPrice = 0;
         ResetTrailingStatePair(p);
         return;
      }
   }
   else
   {
      g_pairs[p].trailingSL_Sell = 0;
      g_pairs[p].trailingActive_Sell = false;
      g_pairs[p].breakevenDone_Sell = false;
   }
}

void ApplyTrailingSLPair(int p, ENUM_POSITION_TYPE side, double slPrice)
{
   string sym = g_pairs[p].symbol;
   int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   slPrice = NormalizeDouble(slPrice, digits);
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != g_pairs[p].magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != sym) continue;
      if(PositionGetInteger(POSITION_TYPE) != side) continue;
      double currentSL = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      if(side == POSITION_TYPE_BUY)
      {
         if(currentSL == 0 || slPrice > currentSL) trade.PositionModify(ticket, slPrice, tp);
      }
      else
      {
         if(currentSL == 0 || slPrice < currentSL) trade.PositionModify(ticket, slPrice, tp);
      }
   }
}

//+------------------------------------------------------------------+
//| Drawdown exit (account-level, closes all pairs)                    |
//+------------------------------------------------------------------+
void CheckDrawdownExit()
{
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(balance <= 0) return;
   double dd = (balance - equity) / balance * 100.0;
   if(dd >= MaxDrawdownPct)
   {
      Print("EMERGENCY DD: ", DoubleToString(dd, 2), "% - Closing ALL positions!");
      CloseAllPositionsAll();
      if(StopEAOnDrawdown)
      {
         g_eaStopped = true;
         Print("EA STOPPED by Max Drawdown");
      }
      else
      {
         for(int pp = 0; pp < 5; pp++)
         {
            if(g_pairs[pp].enabled)
            {
               g_pairs[pp].initialBuyPrice = 0;
               g_pairs[pp].initialSellPrice = 0;
               g_pairs[pp].justClosedBuy = true;
               g_pairs[pp].justClosedSell = true;
               g_pairs[pp].accumulateBaseline = CalcTotalHistoryProfitPair(pp);
               ResetTrailingStatePair(pp);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Grid helpers per pair                                              |
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
   return (validBars == 0) ? 0 : sum / validBars;
}

double GetGridDistancePair(int p, int level, bool isLoss)
{
   string sym = g_pairs[p].symbol;
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   if(isLoss)
   {
      if(g_pairs[p].gl_GapType == GAP_FIXED) return (double)g_pairs[p].gl_Points;
      else if(g_pairs[p].gl_GapType == GAP_CUSTOM) return ParseCustomValue(g_pairs[p].gl_CustomDistance, level);
      else
      {
         double atrVal = 0;
         if(g_isTesterMode && InpSkipATRInTester)
            atrVal = CalculateSimplifiedATR(sym, g_pairs[p].gl_ATR_TF, g_pairs[p].gl_ATR_Period);
         else
            atrVal = (ArraySize(g_pairs[p].bufATR_Loss) > 1 && g_pairs[p].bufATR_Loss[1] > 0) ? g_pairs[p].bufATR_Loss[1] : (ArraySize(g_pairs[p].bufATR_Loss) > 0 ? g_pairs[p].bufATR_Loss[0] : 0);
         if(atrVal > 0)
         {
            double d = atrVal * g_pairs[p].gl_ATR_Multiplier / point;
            return MathMax(d, (double)g_pairs[p].gl_MinGapPoints);
         }
         return (double)g_pairs[p].gl_Points;
      }
   }
   else
   {
      if(g_pairs[p].gp_GapType == GAP_FIXED) return (double)g_pairs[p].gp_Points;
      else if(g_pairs[p].gp_GapType == GAP_CUSTOM) return ParseCustomValue(g_pairs[p].gp_CustomDistance, level);
      else
      {
         double atrVal = 0;
         if(g_isTesterMode && InpSkipATRInTester)
            atrVal = CalculateSimplifiedATR(sym, g_pairs[p].gp_ATR_TF, g_pairs[p].gp_ATR_Period);
         else
            atrVal = (ArraySize(g_pairs[p].bufATR_Profit) > 1 && g_pairs[p].bufATR_Profit[1] > 0) ? g_pairs[p].bufATR_Profit[1] : (ArraySize(g_pairs[p].bufATR_Profit) > 0 ? g_pairs[p].bufATR_Profit[0] : 0);
         if(atrVal > 0)
         {
            double d = atrVal * g_pairs[p].gp_ATR_Multiplier / point;
            return MathMax(d, (double)g_pairs[p].gp_MinGapPoints);
         }
         return (double)g_pairs[p].gp_Points;
      }
   }
}

double CalculateGridLotPair(int p, int level, bool isLoss)
{
   double lot0 = g_pairs[p].initialLot;
   if(isLoss)
   {
      if(g_pairs[p].gl_LotMode == LOT_ADD) return lot0 + lot0 * g_pairs[p].gl_AddLotPerLevel * (level + 1);
      else if(g_pairs[p].gl_LotMode == LOT_CUSTOM) return ParseCustomValue(g_pairs[p].gl_CustomLots, level);
      else return lot0 * MathPow(g_pairs[p].gl_MultiplyFactor, level + 1);
   }
   else
   {
      if(g_pairs[p].gp_LotMode == LOT_ADD) return lot0 + lot0 * g_pairs[p].gp_AddLotPerLevel * (level + 1);
      else if(g_pairs[p].gp_LotMode == LOT_CUSTOM) return ParseCustomValue(g_pairs[p].gp_CustomLots, level);
      else return lot0 * MathPow(g_pairs[p].gp_MultiplyFactor, level + 1);
   }
}

void FindLastOrderPair(int p, ENUM_POSITION_TYPE side, string prefix1, string prefix2, double &outPrice, datetime &outTime)
{
   outPrice = 0; outTime = 0;
   datetime latestTime = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != g_pairs[p].magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != g_pairs[p].symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) != side) continue;
      string comment = PositionGetString(POSITION_COMMENT);
      if(StringFind(comment, prefix1) >= 0 || StringFind(comment, prefix2) >= 0)
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

void CheckGridLossPair(int p, ENUM_POSITION_TYPE side, int currentGridCount)
{
   if(currentGridCount >= g_pairs[p].gl_MaxTrades) return;
   if(TotalOrderCountAll() >= MaxOpenOrders) return;
   string sym = g_pairs[p].symbol;
   string pfx = g_pairs[p].commentPrefix;

   if(g_pairs[p].gl_OnlyNewCandle)
   {
      datetime barTime = iTime(sym, PERIOD_CURRENT, 0);
      if(barTime == g_pairs[p].lastGridLossCandleTime) return;
   }
   if(g_pairs[p].gl_OnlyInSignal)
   {
      double sma = (ArraySize(g_pairs[p].bufSMA) > 0) ? g_pairs[p].bufSMA[0] : 0;
      double price = SymbolInfoDouble(sym, SYMBOL_BID);
      if(side == POSITION_TYPE_BUY && price < sma) return;
      if(side == POSITION_TYPE_SELL && price > sma) return;
   }

   double lastPrice = 0; datetime lastTime = 0;
   FindLastOrderPair(p, side, "INIT", "GL", lastPrice, lastTime);
   if(lastPrice == 0)
   {
      if(side == POSITION_TYPE_BUY && g_pairs[p].initialBuyPrice > 0) lastPrice = g_pairs[p].initialBuyPrice;
      else if(side == POSITION_TYPE_SELL && g_pairs[p].initialSellPrice > 0) lastPrice = g_pairs[p].initialSellPrice;
      else return;
   }
   if(g_pairs[p].gl_DontSameCandle)
   {
      datetime barTime = iTime(sym, PERIOD_CURRENT, 0);
      if(lastTime >= barTime) return;
   }

   double distance = GetGridDistancePair(p, currentGridCount, true);
   if(distance <= 0) return;
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   double currentPrice = (side == POSITION_TYPE_BUY) ? SymbolInfoDouble(sym, SYMBOL_ASK) : SymbolInfoDouble(sym, SYMBOL_BID);
   bool shouldOpen = false;

   if(g_pairs[p].gl_GapType == GAP_ATR && g_pairs[p].gl_ATR_Reference == ATR_REF_INITIAL)
   {
      double initialRef = (side == POSITION_TYPE_BUY) ? g_pairs[p].initialBuyPrice : g_pairs[p].initialSellPrice;
      if(initialRef <= 0) return;
      double totalDist = distance * (currentGridCount + 1);
      if(side == POSITION_TYPE_BUY) shouldOpen = (currentPrice <= initialRef - totalDist * point);
      else shouldOpen = (currentPrice >= initialRef + totalDist * point);
   }
   else
   {
      if(side == POSITION_TYPE_BUY && currentPrice <= lastPrice - distance * point) shouldOpen = true;
      else if(side == POSITION_TYPE_SELL && currentPrice >= lastPrice + distance * point) shouldOpen = true;
   }

   if(shouldOpen)
   {
      double lots = CalculateGridLotPair(p, currentGridCount, true);
      string comment = pfx + "GL#" + IntegerToString(currentGridCount + 1);
      ENUM_ORDER_TYPE ot = (side == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      if(OpenOrderPair(p, ot, lots, comment))
         g_pairs[p].lastGridLossCandleTime = iTime(sym, PERIOD_CURRENT, 0);
   }
}

void CheckGridProfitPair(int p, ENUM_POSITION_TYPE side, int currentGridCount)
{
   if(currentGridCount >= g_pairs[p].gp_MaxTrades) return;
   if(TotalOrderCountAll() >= MaxOpenOrders) return;
   string sym = g_pairs[p].symbol;
   string pfx = g_pairs[p].commentPrefix;

   if(g_pairs[p].gp_OnlyNewCandle)
   {
      datetime barTime = iTime(sym, PERIOD_CURRENT, 0);
      if(barTime == g_pairs[p].lastGridProfitCandleTime) return;
   }

   double lastPrice = 0; datetime lastTime = 0;
   FindLastOrderPair(p, side, "INIT", "GP", lastPrice, lastTime);
   if(lastPrice == 0)
   {
      if(side == POSITION_TYPE_BUY && g_pairs[p].initialBuyPrice > 0) lastPrice = g_pairs[p].initialBuyPrice;
      else if(side == POSITION_TYPE_SELL && g_pairs[p].initialSellPrice > 0) lastPrice = g_pairs[p].initialSellPrice;
      else return;
   }

   // Copy ATR buffer if needed
   if(g_pairs[p].handleATR_Profit != INVALID_HANDLE)
   {
      if(CopyBuffer(g_pairs[p].handleATR_Profit, 0, 0, 3, g_pairs[p].bufATR_Profit) < 3) return;
   }

   double distance = GetGridDistancePair(p, currentGridCount, false);
   if(distance <= 0) return;
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   double currentPrice = (side == POSITION_TYPE_BUY) ? SymbolInfoDouble(sym, SYMBOL_ASK) : SymbolInfoDouble(sym, SYMBOL_BID);
   bool shouldOpen = false;

   if(g_pairs[p].gp_GapType == GAP_ATR && g_pairs[p].gp_ATR_Reference == ATR_REF_INITIAL)
   {
      double initialRef = (side == POSITION_TYPE_BUY) ? g_pairs[p].initialBuyPrice : g_pairs[p].initialSellPrice;
      if(initialRef <= 0) return;
      double totalDist = distance * (currentGridCount + 1);
      if(side == POSITION_TYPE_BUY) shouldOpen = (currentPrice >= initialRef + totalDist * point);
      else shouldOpen = (currentPrice <= initialRef - totalDist * point);
   }
   else
   {
      if(side == POSITION_TYPE_BUY && currentPrice >= lastPrice + distance * point) shouldOpen = true;
      else if(side == POSITION_TYPE_SELL && currentPrice <= lastPrice - distance * point) shouldOpen = true;
   }

   if(shouldOpen)
   {
      double lots = CalculateGridLotPair(p, currentGridCount, false);
      string comment = pfx + "GP#" + IntegerToString(currentGridCount + 1);
      ENUM_ORDER_TYPE ot = (side == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      if(OpenOrderPair(p, ot, lots, comment))
         g_pairs[p].lastGridProfitCandleTime = iTime(sym, PERIOD_CURRENT, 0);
   }
}

//+------------------------------------------------------------------+
//| Matching Close per pair                                            |
//+------------------------------------------------------------------+
void ManageMatchingClosePair(int p)
{
   if(!g_pairs[p].useMatching) return;
   string sym = g_pairs[p].symbol;
   int magic = g_pairs[p].magic;
   int maxLoss = MathMin(MathMax(g_pairs[p].matchMaxLoss, 1), 10);

   for(int side = 0; side < 2; side++)
   {
      ENUM_POSITION_TYPE posType = (side == 0) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
      bool matchFound = true;
      while(matchFound)
      {
         matchFound = false;
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
            if(PositionGetString(POSITION_SYMBOL) != sym) continue;
            if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
            if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != posType) continue;
            double pnl = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP) + (2.0 * PositionGetDouble(POSITION_COMMISSION));
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

         int minPO = MathMax(g_pairs[p].matchMinProfitOrders, 1);
         if(profitCount < minPO) break;

         // Sort profit descending
         for(int a = 0; a < profitCount - 1; a++)
            for(int b = a + 1; b < profitCount; b++)
               if(profitValues[b] > profitValues[a])
               {
                  double tmpV = profitValues[a]; profitValues[a] = profitValues[b]; profitValues[b] = tmpV;
                  ulong tmpT = profitTickets[a]; profitTickets[a] = profitTickets[b]; profitTickets[b] = tmpT;
               }

         // Sort loss by open time ascending
         for(int a = 0; a < lossCount - 1; a++)
            for(int b = a + 1; b < lossCount; b++)
               if(lossOpenTimes[b] < lossOpenTimes[a])
               {
                  double tmpV = lossValues[a]; lossValues[a] = lossValues[b]; lossValues[b] = tmpV;
                  ulong tmpT = lossTickets[a]; lossTickets[a] = lossTickets[b]; lossTickets[b] = tmpT;
                  datetime tmpD = lossOpenTimes[a]; lossOpenTimes[a] = lossOpenTimes[b]; lossOpenTimes[b] = tmpD;
               }

         string sideStr = (posType == POSITION_TYPE_BUY) ? "BUY" : "SELL";

         if(lossCount == 0)
         {
            if(profitCount < minPO) break;
            double totalProfit = 0;
            for(int pp2 = 0; pp2 < profitCount; pp2++) totalProfit += profitValues[pp2];
            if(totalProfit >= g_pairs[p].matchMinProfit)
            {
               Print("MATCHING [", sym, " ", sideStr, "] PROFIT-ONLY: ", profitCount, " orders $", DoubleToString(totalProfit, 2));
               for(int pp2 = 0; pp2 < profitCount; pp2++) trade.PositionClose(profitTickets[pp2]);
               matchFound = true;
               Sleep(100);
            }
            else break;
         }
         else
         {
            bool found = false;
            double cumProfit = 0;
            for(int pp2 = 0; pp2 < profitCount && !found; pp2++)
            {
               cumProfit += profitValues[pp2];
               int usedPC = pp2 + 1;
               if(usedPC < minPO) continue;
               int closeLossIdx[];
               ArrayResize(closeLossIdx, 0);
               double cumLoss = 0;
               int lossUsed = 0;
               for(int l = 0; l < lossCount && lossUsed < maxLoss; l++)
               {
                  double netIfAdd = cumProfit + cumLoss + lossValues[l];
                  if(netIfAdd >= g_pairs[p].matchMinProfit || netIfAdd >= 0)
                  {
                     ArrayResize(closeLossIdx, lossUsed + 1);
                     closeLossIdx[lossUsed] = l;
                     cumLoss += lossValues[l];
                     lossUsed++;
                  }
               }
               double finalNet = cumProfit + cumLoss;
               if(finalNet >= g_pairs[p].matchMinProfit && lossUsed > 0)
               {
                  Print("MATCHING [", sym, " ", sideStr, "]: ", usedPC, "P+", lossUsed, "L Net=$", DoubleToString(finalNet, 2));
                  for(int cp = 0; cp < usedPC; cp++) trade.PositionClose(profitTickets[cp]);
                  for(int cl = 0; cl < lossUsed; cl++) trade.PositionClose(lossTickets[closeLossIdx[cl]]);
                  matchFound = true;
                  found = true;
                  Sleep(100);
               }
            }
            if(!found) break;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Global Accumulate Close (sum all pairs)                            |
//+------------------------------------------------------------------+
void ManageGlobalAccumulate()
{
   if(!UseGlobalAccumulate) return;

   int totalCount = TotalOrderCountAll();
   if(g_globalHadPositions && totalCount == 0)
   {
      g_globalAccumBaseline = CalcTotalHistoryProfitAll();
      g_globalAccumProfit = 0;
      g_globalHadPositions = false;
      return;
   }
   if(totalCount > 0) g_globalHadPositions = true;

   double totalHist = CalcTotalHistoryProfitAll();
   g_globalAccumProfit = totalHist - g_globalAccumBaseline;
   double totalFloat = CalculateAllFloatingPL();
   double accumTotal = g_globalAccumProfit + totalFloat;

   if(accumTotal >= GlobalAccumulateTarget && accumTotal > 0)
   {
      Print("GLOBAL ACCUMULATE TARGET HIT: $", DoubleToString(accumTotal, 2), " / $", DoubleToString(GlobalAccumulateTarget, 2));
      CloseAllPositionsAll();
      Sleep(500);
      g_globalAccumBaseline = CalcTotalHistoryProfitAll();
      g_globalAccumProfit = 0;
      g_globalHadPositions = false;
   }
}

//+------------------------------------------------------------------+
//| ============== ZIGZAG MTF PER-PAIR MODULE ====================== |
//+------------------------------------------------------------------+

void ResetPairTFState(int p, int idx)
{
   g_pairs[p].tfStates[idx].lastSwingPrice = 0;
   g_pairs[p].tfStates[idx].lastSwingType = "NONE";
   g_pairs[p].tfStates[idx].lastSwingTime = 0;
   g_pairs[p].tfStates[idx].initialBuyPrice = 0;
   g_pairs[p].tfStates[idx].initialSellPrice = 0;
   g_pairs[p].tfStates[idx].lastInitialCandle = 0;
   g_pairs[p].tfStates[idx].lastGridLossCandle = 0;
   g_pairs[p].tfStates[idx].lastGridProfitCandle = 0;
   g_pairs[p].tfStates[idx].justClosedBuy = false;
   g_pairs[p].tfStates[idx].justClosedSell = false;
   g_pairs[p].tfStates[idx].trailSL_Buy = 0;
   g_pairs[p].tfStates[idx].trailSL_Sell = 0;
   g_pairs[p].tfStates[idx].trailActive_Buy = false;
   g_pairs[p].tfStates[idx].trailActive_Sell = false;
   g_pairs[p].tfStates[idx].beDone_Buy = false;
   g_pairs[p].tfStates[idx].beDone_Sell = false;
}

void ResetTrailingStateTFPair(int p, int tfIdx)
{
   g_pairs[p].tfStates[tfIdx].trailSL_Buy = 0;
   g_pairs[p].tfStates[tfIdx].trailSL_Sell = 0;
   g_pairs[p].tfStates[tfIdx].trailActive_Buy = false;
   g_pairs[p].tfStates[tfIdx].trailActive_Sell = false;
   g_pairs[p].tfStates[tfIdx].beDone_Buy = false;
   g_pairs[p].tfStates[tfIdx].beDone_Sell = false;
}

void InitZigZagHandlesPair(int p)
{
   string sym = g_pairs[p].symbol;
   g_pairs[p].activeTFCount = 0;

   // H4 confirm TF
   {
      int idx = g_pairs[p].activeTFCount;
      g_pairs[p].tfStates[idx].tf = ZZ_ConfirmTF;
      g_pairs[p].tfStates[idx].tfLabel = "H4";
      g_pairs[p].tfStates[idx].enabled = ZZ_UseConfirmTFEntry;
      g_pairs[p].tfStates[idx].handleZZ = iCustom(sym, ZZ_ConfirmTF, "Examples\\ZigZag", ZZ_Depth, ZZ_Deviation, ZZ_Backstep);
      ResetPairTFState(p, idx);
      g_pairs[p].h4TFIndex = idx;
      g_pairs[p].activeTFCount++;
   }
   if(ZZ_UseM30)
   {
      int idx = g_pairs[p].activeTFCount;
      g_pairs[p].tfStates[idx].tf = PERIOD_M30;
      g_pairs[p].tfStates[idx].tfLabel = "M30";
      g_pairs[p].tfStates[idx].enabled = true;
      g_pairs[p].tfStates[idx].handleZZ = iCustom(sym, PERIOD_M30, "Examples\\ZigZag", ZZ_Depth, ZZ_Deviation, ZZ_Backstep);
      ResetPairTFState(p, idx);
      g_pairs[p].activeTFCount++;
   }
   if(ZZ_UseM15)
   {
      int idx = g_pairs[p].activeTFCount;
      g_pairs[p].tfStates[idx].tf = PERIOD_M15;
      g_pairs[p].tfStates[idx].tfLabel = "M15";
      g_pairs[p].tfStates[idx].enabled = true;
      g_pairs[p].tfStates[idx].handleZZ = iCustom(sym, PERIOD_M15, "Examples\\ZigZag", ZZ_Depth, ZZ_Deviation, ZZ_Backstep);
      ResetPairTFState(p, idx);
      g_pairs[p].activeTFCount++;
   }
   if(ZZ_UseM5)
   {
      int idx = g_pairs[p].activeTFCount;
      g_pairs[p].tfStates[idx].tf = PERIOD_M5;
      g_pairs[p].tfStates[idx].tfLabel = "M5";
      g_pairs[p].tfStates[idx].enabled = true;
      g_pairs[p].tfStates[idx].handleZZ = iCustom(sym, PERIOD_M5, "Examples\\ZigZag", ZZ_Depth, ZZ_Deviation, ZZ_Backstep);
      ResetPairTFState(p, idx);
      g_pairs[p].activeTFCount++;
   }
}

void RecoverTFInitialPricesPair(int p)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != g_pairs[p].magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != g_pairs[p].symbol) continue;
      string comment = PositionGetString(POSITION_COMMENT);
      long posType = PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      for(int t = 0; t < g_pairs[p].activeTFCount; t++)
      {
         string pfx = g_pairs[p].commentPrefix + g_pairs[p].tfStates[t].tfLabel + "_INIT";
         if(StringFind(comment, pfx) >= 0)
         {
            if(posType == POSITION_TYPE_BUY) g_pairs[p].tfStates[t].initialBuyPrice = openPrice;
            else if(posType == POSITION_TYPE_SELL) g_pairs[p].tfStates[t].initialSellPrice = openPrice;
         }
      }
   }
}

string DetectZigZagSwingPair(int p, int tfIndex)
{
   if(g_pairs[p].tfStates[tfIndex].handleZZ == INVALID_HANDLE) return "NONE";
   double zzHighMap[], zzLowMap[];
   ArraySetAsSeries(zzHighMap, true);
   ArraySetAsSeries(zzLowMap, true);
   if(CopyBuffer(g_pairs[p].tfStates[tfIndex].handleZZ, 1, 0, 100, zzHighMap) < 100) return "NONE";
   if(CopyBuffer(g_pairs[p].tfStates[tfIndex].handleZZ, 2, 0, 100, zzLowMap) < 100) return "NONE";
   int lastHighBar = -1, lastLowBar = -1;
   double lastHighPrice = 0, lastLowPrice = 0;
   for(int i = 1; i < 100; i++)
   {
      if(lastHighBar < 0 && zzHighMap[i] != 0.0) { lastHighBar = i; lastHighPrice = zzHighMap[i]; }
      if(lastLowBar < 0 && zzLowMap[i] != 0.0) { lastLowBar = i; lastLowPrice = zzLowMap[i]; }
      if(lastHighBar >= 0 && lastLowBar >= 0) break;
   }
   string sym = g_pairs[p].symbol;
   if(lastLowBar >= 0 && (lastHighBar < 0 || lastLowBar < lastHighBar))
   {
      g_pairs[p].tfStates[tfIndex].lastSwingPrice = lastLowPrice;
      g_pairs[p].tfStates[tfIndex].lastSwingType = "LOW";
      g_pairs[p].tfStates[tfIndex].lastSwingTime = iTime(sym, g_pairs[p].tfStates[tfIndex].tf, lastLowBar);
      return "LOW";
   }
   else if(lastHighBar >= 0)
   {
      g_pairs[p].tfStates[tfIndex].lastSwingPrice = lastHighPrice;
      g_pairs[p].tfStates[tfIndex].lastSwingType = "HIGH";
      g_pairs[p].tfStates[tfIndex].lastSwingTime = iTime(sym, g_pairs[p].tfStates[tfIndex].tf, lastHighBar);
      return "HIGH";
   }
   return "NONE";
}

void CalculateCDC_EMA(double &src[], double &result[], int period, int size)
{
   if(size < period) return;
   double multiplier = 2.0 / (period + 1);
   double sum = 0;
   for(int i = size - period; i < size; i++) sum += src[i];
   result[size - 1] = sum / period;
   for(int i = size - 2; i >= 0; i--)
      result[i] = (src[i] - result[i + 1]) * multiplier + result[i + 1];
}

void UpdateCDCPair(int p)
{
   if(!InpUseCDCFilter) return;
   string sym = g_pairs[p].symbol;
   datetime cdcBar = iTime(sym, InpCDCTimeframe, 0);
   if(cdcBar == g_pairs[p].lastCdcCandle && g_pairs[p].cdcReady) return;
   g_pairs[p].lastCdcCandle = cdcBar;
   int barsNeeded = InpCDCSlowPeriod * 3 + 50;
   double closeArr[], highArr[], lowArr[], openArr[];
   ArraySetAsSeries(closeArr, true);
   ArraySetAsSeries(highArr, true);
   ArraySetAsSeries(lowArr, true);
   ArraySetAsSeries(openArr, true);
   int copied = CopyClose(sym, InpCDCTimeframe, 0, barsNeeded, closeArr);
   if(copied < InpCDCSlowPeriod + 10) { g_pairs[p].cdcReady = false; return; }
   int actualBars = MathMin(copied, barsNeeded);
   if(CopyHigh(sym, InpCDCTimeframe, 0, actualBars, highArr) < actualBars) { g_pairs[p].cdcReady = false; return; }
   if(CopyLow(sym, InpCDCTimeframe, 0, actualBars, lowArr) < actualBars) { g_pairs[p].cdcReady = false; return; }
   if(CopyOpen(sym, InpCDCTimeframe, 0, actualBars, openArr) < actualBars) { g_pairs[p].cdcReady = false; return; }
   double ohlc4[];
   ArrayResize(ohlc4, actualBars);
   for(int i = 0; i < actualBars; i++) ohlc4[i] = (openArr[i] + highArr[i] + lowArr[i] + closeArr[i]) / 4.0;
   double ap[];
   ArrayResize(ap, actualBars);
   CalculateCDC_EMA(ohlc4, ap, 2, actualBars);
   double fast[], slow[];
   ArrayResize(fast, actualBars);
   ArrayResize(slow, actualBars);
   CalculateCDC_EMA(ap, fast, InpCDCFastPeriod, actualBars);
   CalculateCDC_EMA(ap, slow, InpCDCSlowPeriod, actualBars);
   if(ArraySize(fast) < 2 || ArraySize(slow) < 2) { g_pairs[p].cdcReady = false; return; }
   g_pairs[p].cdcFast = fast[0];
   g_pairs[p].cdcSlow = slow[0];
   if(g_pairs[p].cdcFast == 0 || g_pairs[p].cdcSlow == 0) { g_pairs[p].cdcReady = false; return; }
   if(InpCDCRequireCross)
   {
      bool crossUp = (fast[1] <= slow[1] && g_pairs[p].cdcFast > g_pairs[p].cdcSlow);
      bool crossDown = (fast[1] >= slow[1] && g_pairs[p].cdcFast < g_pairs[p].cdcSlow);
      if(crossUp) g_pairs[p].cdcTrend = "BULLISH";
      else if(crossDown) g_pairs[p].cdcTrend = "BEARISH";
   }
   else
   {
      if(g_pairs[p].cdcFast > g_pairs[p].cdcSlow) g_pairs[p].cdcTrend = "BULLISH";
      else if(g_pairs[p].cdcFast < g_pairs[p].cdcSlow) g_pairs[p].cdcTrend = "BEARISH";
      else g_pairs[p].cdcTrend = "NEUTRAL";
   }
   g_pairs[p].cdcReady = true;
}

void CountPositionsTFPair(int p, int tfIdx, int &buyCount, int &sellCount,
                          int &gridLossBuy, int &gridLossSell, int &gridProfitBuy, int &gridProfitSell,
                          bool &hasInitialBuy, bool &hasInitialSell)
{
   buyCount = 0; sellCount = 0;
   gridLossBuy = 0; gridLossSell = 0;
   gridProfitBuy = 0; gridProfitSell = 0;
   hasInitialBuy = false; hasInitialSell = false;
   string prefix = g_pairs[p].commentPrefix + g_pairs[p].tfStates[tfIdx].tfLabel + "_";
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != g_pairs[p].magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != g_pairs[p].symbol) continue;
      string comment = PositionGetString(POSITION_COMMENT);
      if(StringFind(comment, prefix) < 0) continue;
      long posType = PositionGetInteger(POSITION_TYPE);
      if(posType == POSITION_TYPE_BUY)
      {
         buyCount++;
         if(StringFind(comment, prefix + "INIT") >= 0) hasInitialBuy = true;
         if(StringFind(comment, prefix + "GL") >= 0) gridLossBuy++;
         if(StringFind(comment, prefix + "GP") >= 0) gridProfitBuy++;
      }
      else if(posType == POSITION_TYPE_SELL)
      {
         sellCount++;
         if(StringFind(comment, prefix + "INIT") >= 0) hasInitialSell = true;
         if(StringFind(comment, prefix + "GL") >= 0) gridLossSell++;
         if(StringFind(comment, prefix + "GP") >= 0) gridProfitSell++;
      }
   }
}

bool OpenOrderTFPair(int p, int tfIdx, ENUM_ORDER_TYPE orderType, double lots, string suffix)
{
   string comment = g_pairs[p].commentPrefix + g_pairs[p].tfStates[tfIdx].tfLabel + "_" + suffix;
   return OpenOrderPair(p, orderType, lots, comment);
}

double CalculateAveragePriceTFPair(int p, int tfIdx, ENUM_POSITION_TYPE side)
{
   string prefix = g_pairs[p].commentPrefix + g_pairs[p].tfStates[tfIdx].tfLabel + "_";
   double totalLots = 0, totalWeighted = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != g_pairs[p].magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != g_pairs[p].symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) != side) continue;
      if(StringFind(PositionGetString(POSITION_COMMENT), prefix) < 0) continue;
      double vol = PositionGetDouble(POSITION_VOLUME);
      totalLots += vol;
      totalWeighted += PositionGetDouble(POSITION_PRICE_OPEN) * vol;
   }
   return (totalLots > 0) ? totalWeighted / totalLots : 0;
}

double CalculateFloatingPLTFPair(int p, int tfIdx, ENUM_POSITION_TYPE side)
{
   string prefix = g_pairs[p].commentPrefix + g_pairs[p].tfStates[tfIdx].tfLabel + "_";
   double totalPL = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != g_pairs[p].magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != g_pairs[p].symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) != side) continue;
      if(StringFind(PositionGetString(POSITION_COMMENT), prefix) < 0) continue;
      totalPL += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return totalPL;
}

void FindLastOrderTFPair(int p, int tfIdx, ENUM_POSITION_TYPE side, string suffix1, string suffix2, double &outPrice, datetime &outTime)
{
   string prefix = g_pairs[p].commentPrefix + g_pairs[p].tfStates[tfIdx].tfLabel + "_";
   outPrice = 0; outTime = 0;
   datetime latestTime = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != g_pairs[p].magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != g_pairs[p].symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) != side) continue;
      string comment = PositionGetString(POSITION_COMMENT);
      if(StringFind(comment, prefix + suffix1) >= 0 || StringFind(comment, prefix + suffix2) >= 0)
      {
         datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
         if(openTime > latestTime) { latestTime = openTime; outPrice = PositionGetDouble(POSITION_PRICE_OPEN); outTime = openTime; }
      }
   }
}

void CloseAllSideTFPair(int p, int tfIdx, ENUM_POSITION_TYPE side)
{
   string prefix = g_pairs[p].commentPrefix + g_pairs[p].tfStates[tfIdx].tfLabel + "_";
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != g_pairs[p].magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != g_pairs[p].symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) != side) continue;
      if(StringFind(PositionGetString(POSITION_COMMENT), prefix) < 0) continue;
      trade.PositionClose(ticket);
   }
   if(side == POSITION_TYPE_BUY) g_pairs[p].tfStates[tfIdx].justClosedBuy = true;
   else g_pairs[p].tfStates[tfIdx].justClosedSell = true;
}

void CheckGridLossTFPair(int p, int tfIdx, ENUM_POSITION_TYPE side, int currentGridCount)
{
   if(currentGridCount >= g_pairs[p].gl_MaxTrades) return;
   if(TotalOrderCountAll() >= MaxOpenOrders) return;
   string sym = g_pairs[p].symbol;
   if(g_pairs[p].gl_OnlyNewCandle)
   {
      datetime barTime = iTime(sym, g_pairs[p].tfStates[tfIdx].tf, 0);
      if(barTime == g_pairs[p].tfStates[tfIdx].lastGridLossCandle) return;
   }

   double lastPrice = 0; datetime lastTime = 0;
   FindLastOrderTFPair(p, tfIdx, side, "INIT", "GL", lastPrice, lastTime);
   if(lastPrice == 0)
   {
      if(side == POSITION_TYPE_BUY && g_pairs[p].tfStates[tfIdx].initialBuyPrice > 0) lastPrice = g_pairs[p].tfStates[tfIdx].initialBuyPrice;
      else if(side == POSITION_TYPE_SELL && g_pairs[p].tfStates[tfIdx].initialSellPrice > 0) lastPrice = g_pairs[p].tfStates[tfIdx].initialSellPrice;
      else return;
   }
   if(g_pairs[p].handleATR_Loss != INVALID_HANDLE)
      CopyBuffer(g_pairs[p].handleATR_Loss, 0, 0, 3, g_pairs[p].bufATR_Loss);

   double distance = GetGridDistancePair(p, currentGridCount, true);
   if(distance <= 0) return;
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   double currentPrice = (side == POSITION_TYPE_BUY) ? SymbolInfoDouble(sym, SYMBOL_ASK) : SymbolInfoDouble(sym, SYMBOL_BID);
   bool shouldOpen = false;

   if(g_pairs[p].gl_GapType == GAP_ATR && g_pairs[p].gl_ATR_Reference == ATR_REF_INITIAL)
   {
      double initialRef = (side == POSITION_TYPE_BUY) ? g_pairs[p].tfStates[tfIdx].initialBuyPrice : g_pairs[p].tfStates[tfIdx].initialSellPrice;
      if(initialRef <= 0) return;
      double totalDist = distance * (currentGridCount + 1);
      if(side == POSITION_TYPE_BUY) shouldOpen = (currentPrice <= initialRef - totalDist * point);
      else shouldOpen = (currentPrice >= initialRef + totalDist * point);
   }
   else
   {
      if(side == POSITION_TYPE_BUY && currentPrice <= lastPrice - distance * point) shouldOpen = true;
      else if(side == POSITION_TYPE_SELL && currentPrice >= lastPrice + distance * point) shouldOpen = true;
   }

   if(shouldOpen)
   {
      double lots = CalculateGridLotPair(p, currentGridCount, true);
      string suffix = "GL#" + IntegerToString(currentGridCount + 1);
      ENUM_ORDER_TYPE ot = (side == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      if(OpenOrderTFPair(p, tfIdx, ot, lots, suffix))
         g_pairs[p].tfStates[tfIdx].lastGridLossCandle = iTime(sym, g_pairs[p].tfStates[tfIdx].tf, 0);
   }
}

void CheckGridProfitTFPair(int p, int tfIdx, ENUM_POSITION_TYPE side, int currentGridCount)
{
   if(currentGridCount >= g_pairs[p].gp_MaxTrades) return;
   if(TotalOrderCountAll() >= MaxOpenOrders) return;
   string sym = g_pairs[p].symbol;

   if(g_pairs[p].gp_OnlyNewCandle)
   {
      datetime barTime = iTime(sym, g_pairs[p].tfStates[tfIdx].tf, 0);
      if(barTime == g_pairs[p].tfStates[tfIdx].lastGridProfitCandle) return;
   }

   double lastPrice = 0; datetime lastTime = 0;
   FindLastOrderTFPair(p, tfIdx, side, "INIT", "GP", lastPrice, lastTime);
   if(lastPrice == 0)
   {
      if(side == POSITION_TYPE_BUY && g_pairs[p].tfStates[tfIdx].initialBuyPrice > 0) lastPrice = g_pairs[p].tfStates[tfIdx].initialBuyPrice;
      else if(side == POSITION_TYPE_SELL && g_pairs[p].tfStates[tfIdx].initialSellPrice > 0) lastPrice = g_pairs[p].tfStates[tfIdx].initialSellPrice;
      else return;
   }
   if(g_pairs[p].handleATR_Profit != INVALID_HANDLE)
      CopyBuffer(g_pairs[p].handleATR_Profit, 0, 0, 3, g_pairs[p].bufATR_Profit);

   double distance = GetGridDistancePair(p, currentGridCount, false);
   if(distance <= 0) return;
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   double currentPrice = (side == POSITION_TYPE_BUY) ? SymbolInfoDouble(sym, SYMBOL_ASK) : SymbolInfoDouble(sym, SYMBOL_BID);
   bool shouldOpen = false;

   if(g_pairs[p].gp_GapType == GAP_ATR && g_pairs[p].gp_ATR_Reference == ATR_REF_INITIAL)
   {
      double initialRef = (side == POSITION_TYPE_BUY) ? g_pairs[p].tfStates[tfIdx].initialBuyPrice : g_pairs[p].tfStates[tfIdx].initialSellPrice;
      if(initialRef <= 0) return;
      double totalDist = distance * (currentGridCount + 1);
      if(side == POSITION_TYPE_BUY) shouldOpen = (currentPrice >= initialRef + totalDist * point);
      else shouldOpen = (currentPrice <= initialRef - totalDist * point);
   }
   else
   {
      if(side == POSITION_TYPE_BUY && currentPrice >= lastPrice + distance * point) shouldOpen = true;
      else if(side == POSITION_TYPE_SELL && currentPrice <= lastPrice - distance * point) shouldOpen = true;
   }

   if(shouldOpen)
   {
      double lots = CalculateGridLotPair(p, currentGridCount, false);
      string suffix = "GP#" + IntegerToString(currentGridCount + 1);
      ENUM_ORDER_TYPE ot = (side == POSITION_TYPE_BUY) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
      if(OpenOrderTFPair(p, tfIdx, ot, lots, suffix))
         g_pairs[p].tfStates[tfIdx].lastGridProfitCandle = iTime(sym, g_pairs[p].tfStates[tfIdx].tf, 0);
   }
}

void ManageTPSLTFPair(int p, int tfIdx)
{
   string sym = g_pairs[p].symbol;
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);

   double avgBuy = CalculateAveragePriceTFPair(p, tfIdx, POSITION_TYPE_BUY);
   if(avgBuy > 0)
   {
      double plBuy = CalculateFloatingPLTFPair(p, tfIdx, POSITION_TYPE_BUY);
      double bid = SymbolInfoDouble(sym, SYMBOL_BID);
      bool closeTP = false, closeSL = false;
      if(!EnablePerOrderTrailing)
      {
         if(UseTP_Dollar && plBuy >= TP_DollarAmount) closeTP = true;
         if(UseTP_Points && bid >= avgBuy + TP_Points * point) closeTP = true;
         if(UseTP_PercentBalance && plBuy >= bal * TP_PercentBalance / 100.0) closeTP = true;
      }
      if(closeTP) { CloseAllSideTFPair(p, tfIdx, POSITION_TYPE_BUY); g_pairs[p].tfStates[tfIdx].initialBuyPrice = 0; ResetTrailingStateTFPair(p, tfIdx); return; }
      if(EnableSL && !EnablePerOrderTrailing)
      {
         if(UseSL_Dollar && plBuy <= -SL_DollarAmount) closeSL = true;
         if(UseSL_Points && bid <= avgBuy - SL_Points * point) closeSL = true;
         if(UseSL_PercentBalance && plBuy <= -(bal * SL_PercentBalance / 100.0)) closeSL = true;
         if(closeSL)
         {
            if(SL_ActionMode == SL_CLOSE_ALL_STOP) { CloseAllPositionsAll(); g_eaStopped = true; }
            else { CloseAllSideTFPair(p, tfIdx, POSITION_TYPE_BUY); g_pairs[p].tfStates[tfIdx].initialBuyPrice = 0; ResetTrailingStateTFPair(p, tfIdx); }
            return;
         }
      }
   }

   double avgSell = CalculateAveragePriceTFPair(p, tfIdx, POSITION_TYPE_SELL);
   if(avgSell > 0)
   {
      double plSell = CalculateFloatingPLTFPair(p, tfIdx, POSITION_TYPE_SELL);
      double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
      bool closeTP2 = false, closeSL2 = false;
      if(!EnablePerOrderTrailing)
      {
         if(UseTP_Dollar && plSell >= TP_DollarAmount) closeTP2 = true;
         if(UseTP_Points && ask <= avgSell - TP_Points * point) closeTP2 = true;
         if(UseTP_PercentBalance && plSell >= bal * TP_PercentBalance / 100.0) closeTP2 = true;
      }
      if(closeTP2) { CloseAllSideTFPair(p, tfIdx, POSITION_TYPE_SELL); g_pairs[p].tfStates[tfIdx].initialSellPrice = 0; ResetTrailingStateTFPair(p, tfIdx); return; }
      if(EnableSL && !EnablePerOrderTrailing)
      {
         if(UseSL_Dollar && plSell <= -SL_DollarAmount) closeSL2 = true;
         if(UseSL_Points && ask >= avgSell + SL_Points * point) closeSL2 = true;
         if(UseSL_PercentBalance && plSell <= -(bal * SL_PercentBalance / 100.0)) closeSL2 = true;
         if(closeSL2)
         {
            if(SL_ActionMode == SL_CLOSE_ALL_STOP) { CloseAllPositionsAll(); g_eaStopped = true; }
            else { CloseAllSideTFPair(p, tfIdx, POSITION_TYPE_SELL); g_pairs[p].tfStates[tfIdx].initialSellPrice = 0; ResetTrailingStateTFPair(p, tfIdx); }
            return;
         }
      }
   }
}

void ManageTrailingStopTFPair(int p, int tfIdx)
{
   string sym = g_pairs[p].symbol;
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   double bid = SymbolInfoDouble(sym, SYMBOL_BID);
   double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
   double avgBuy = CalculateAveragePriceTFPair(p, tfIdx, POSITION_TYPE_BUY);
   if(avgBuy > 0)
   {
      double beLevel = avgBuy + BreakevenBuffer * point;
      if(EnableTrailingStop && bid >= avgBuy + TrailingActivation * point)
      {
         g_pairs[p].tfStates[tfIdx].trailActive_Buy = true;
         double newSL = MathMax(bid - TrailingStep * point, beLevel);
         if(newSL > g_pairs[p].tfStates[tfIdx].trailSL_Buy)
         {
            g_pairs[p].tfStates[tfIdx].trailSL_Buy = newSL;
            ApplyTrailingSLTFPair(p, tfIdx, POSITION_TYPE_BUY, newSL);
         }
      }
      if(EnableBreakeven && !g_pairs[p].tfStates[tfIdx].beDone_Buy && bid >= avgBuy + BreakevenActivation * point)
      {
         g_pairs[p].tfStates[tfIdx].beDone_Buy = true;
         if(g_pairs[p].tfStates[tfIdx].trailSL_Buy < beLevel) { g_pairs[p].tfStates[tfIdx].trailSL_Buy = beLevel; ApplyTrailingSLTFPair(p, tfIdx, POSITION_TYPE_BUY, beLevel); }
      }
      if(g_pairs[p].tfStates[tfIdx].trailActive_Buy && g_pairs[p].tfStates[tfIdx].trailSL_Buy > 0 && bid <= g_pairs[p].tfStates[tfIdx].trailSL_Buy)
      {
         CloseAllSideTFPair(p, tfIdx, POSITION_TYPE_BUY); g_pairs[p].tfStates[tfIdx].initialBuyPrice = 0; ResetTrailingStateTFPair(p, tfIdx); return;
      }
   }
   else { g_pairs[p].tfStates[tfIdx].trailSL_Buy = 0; g_pairs[p].tfStates[tfIdx].trailActive_Buy = false; g_pairs[p].tfStates[tfIdx].beDone_Buy = false; }

   double avgSell = CalculateAveragePriceTFPair(p, tfIdx, POSITION_TYPE_SELL);
   if(avgSell > 0)
   {
      double beLevelSell = avgSell - BreakevenBuffer * point;
      if(EnableTrailingStop && ask <= avgSell - TrailingActivation * point)
      {
         g_pairs[p].tfStates[tfIdx].trailActive_Sell = true;
         double newSL = MathMin(ask + TrailingStep * point, beLevelSell);
         if(g_pairs[p].tfStates[tfIdx].trailSL_Sell == 0 || newSL < g_pairs[p].tfStates[tfIdx].trailSL_Sell)
         {
            g_pairs[p].tfStates[tfIdx].trailSL_Sell = newSL;
            ApplyTrailingSLTFPair(p, tfIdx, POSITION_TYPE_SELL, newSL);
         }
      }
      if(EnableBreakeven && !g_pairs[p].tfStates[tfIdx].beDone_Sell && ask <= avgSell - BreakevenActivation * point)
      {
         g_pairs[p].tfStates[tfIdx].beDone_Sell = true;
         if(g_pairs[p].tfStates[tfIdx].trailSL_Sell == 0 || g_pairs[p].tfStates[tfIdx].trailSL_Sell > beLevelSell)
         {
            g_pairs[p].tfStates[tfIdx].trailSL_Sell = beLevelSell;
            ApplyTrailingSLTFPair(p, tfIdx, POSITION_TYPE_SELL, beLevelSell);
         }
      }
      if(g_pairs[p].tfStates[tfIdx].trailActive_Sell && g_pairs[p].tfStates[tfIdx].trailSL_Sell > 0 && ask >= g_pairs[p].tfStates[tfIdx].trailSL_Sell)
      {
         CloseAllSideTFPair(p, tfIdx, POSITION_TYPE_SELL); g_pairs[p].tfStates[tfIdx].initialSellPrice = 0; ResetTrailingStateTFPair(p, tfIdx); return;
      }
   }
   else { g_pairs[p].tfStates[tfIdx].trailSL_Sell = 0; g_pairs[p].tfStates[tfIdx].trailActive_Sell = false; g_pairs[p].tfStates[tfIdx].beDone_Sell = false; }
}

void ApplyTrailingSLTFPair(int p, int tfIdx, ENUM_POSITION_TYPE side, double slPrice)
{
   string prefix = g_pairs[p].commentPrefix + g_pairs[p].tfStates[tfIdx].tfLabel + "_";
   string sym = g_pairs[p].symbol;
   int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   slPrice = NormalizeDouble(slPrice, digits);
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != g_pairs[p].magic) continue;
      if(PositionGetString(POSITION_SYMBOL) != sym) continue;
      if(PositionGetInteger(POSITION_TYPE) != side) continue;
      if(StringFind(PositionGetString(POSITION_COMMENT), prefix) < 0) continue;
      double currentSL = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);
      if(side == POSITION_TYPE_BUY) { if(currentSL == 0 || slPrice > currentSL) trade.PositionModify(ticket, slPrice, tp); }
      else { if(currentSL == 0 || slPrice < currentSL) trade.PositionModify(ticket, slPrice, tp); }
   }
}

//+------------------------------------------------------------------+
//| ZigZag MTF OnTick per pair                                         |
//+------------------------------------------------------------------+
void OnTickZigZagMTFPair(int p)
{
   string sym = g_pairs[p].symbol;

   if(InpUseCDCFilter) UpdateCDCPair(p);

   if(g_pairs[p].h4TFIndex >= 0)
   {
      datetime h4Bar = iTime(sym, ZZ_ConfirmTF, 0);
      if(h4Bar != g_pairs[p].lastH4Bar)
      {
         g_pairs[p].lastH4Bar = h4Bar;
         string h4Swing = DetectZigZagSwingPair(p, g_pairs[p].h4TFIndex);
         if(h4Swing == "LOW") g_pairs[p].h4Direction = "BUY";
         else if(h4Swing == "HIGH") g_pairs[p].h4Direction = "SELL";
      }
   }

   string effectiveDir = g_pairs[p].h4Direction;
   if(InpUseCDCFilter && g_pairs[p].cdcReady)
   {
      if(effectiveDir == "BUY" && g_pairs[p].cdcTrend == "BEARISH") effectiveDir = "NONE";
      if(effectiveDir == "SELL" && g_pairs[p].cdcTrend == "BULLISH") effectiveDir = "NONE";
   }

   for(int t = 0; t < g_pairs[p].activeTFCount; t++)
   {
      if(!g_pairs[p].tfStates[t].enabled) continue;

      if(!EnablePerOrderTrailing && (EnableTrailingStop || EnableBreakeven))
         ManageTrailingStopTFPair(p, t);

      ManageTPSLTFPair(p, t);

      int tfBC = 0, tfSC = 0, tfGLB = 0, tfGLS = 0, tfGPB = 0, tfGPS = 0;
      bool tfHIB = false, tfHIS = false;
      CountPositionsTFPair(p, t, tfBC, tfSC, tfGLB, tfGLS, tfGPB, tfGPS, tfHIB, tfHIS);

      if(tfBC == 0 && g_pairs[p].tfStates[t].initialBuyPrice != 0) g_pairs[p].tfStates[t].initialBuyPrice = 0;
      if(tfSC == 0 && g_pairs[p].tfStates[t].initialSellPrice != 0) g_pairs[p].tfStates[t].initialSellPrice = 0;

      if(!g_newOrderBlocked)
      {
         if((tfHIB || g_pairs[p].tfStates[t].initialBuyPrice > 0) && tfGLB < g_pairs[p].gl_MaxTrades && tfBC > 0)
            CheckGridLossTFPair(p, t, POSITION_TYPE_BUY, tfGLB);
         if((tfHIS || g_pairs[p].tfStates[t].initialSellPrice > 0) && tfGLS < g_pairs[p].gl_MaxTrades && tfSC > 0)
            CheckGridLossTFPair(p, t, POSITION_TYPE_SELL, tfGLS);
         if(g_pairs[p].gp_Enable)
         {
            if((tfHIB || g_pairs[p].tfStates[t].initialBuyPrice > 0) && tfGPB < g_pairs[p].gp_MaxTrades && tfBC > 0)
               CheckGridProfitTFPair(p, t, POSITION_TYPE_BUY, tfGPB);
            if((tfHIS || g_pairs[p].tfStates[t].initialSellPrice > 0) && tfGPS < g_pairs[p].gp_MaxTrades && tfSC > 0)
               CheckGridProfitTFPair(p, t, POSITION_TYPE_SELL, tfGPS);
         }
      }

      if(!g_newOrderBlocked && effectiveDir != "NONE")
      {
         datetime tfBar = iTime(sym, g_pairs[p].tfStates[t].tf, 0);
         bool canOpenMore = TotalOrderCountAll() < MaxOpenOrders;
         bool canOpenThisCandle = !(DontOpenSameCandle && tfBar == g_pairs[p].tfStates[t].lastInitialCandle);
         string subSwing = DetectZigZagSwingPair(p, t);

         if(effectiveDir == "BUY" && subSwing == "LOW" && tfBC == 0
            && g_pairs[p].tfStates[t].initialBuyPrice == 0 && canOpenMore && canOpenThisCandle
            && (TradingMode == TRADE_BUY_ONLY || TradingMode == TRADE_BOTH))
         {
            bool shouldEnter = true;
            if(g_pairs[p].tfStates[t].justClosedBuy && !EnableAutoReEntry) shouldEnter = false;
            if(shouldEnter && OpenOrderTFPair(p, t, ORDER_TYPE_BUY, g_pairs[p].initialLot, "INIT"))
            {
               g_pairs[p].tfStates[t].initialBuyPrice = SymbolInfoDouble(sym, SYMBOL_ASK);
               g_pairs[p].tfStates[t].lastInitialCandle = tfBar;
               ResetTrailingStateTFPair(p, t);
            }
         }

         if(effectiveDir == "SELL" && subSwing == "HIGH" && tfSC == 0
            && g_pairs[p].tfStates[t].initialSellPrice == 0 && canOpenMore && canOpenThisCandle
            && (TradingMode == TRADE_SELL_ONLY || TradingMode == TRADE_BOTH))
         {
            bool shouldEnter = true;
            if(g_pairs[p].tfStates[t].justClosedSell && !EnableAutoReEntry) shouldEnter = false;
            if(shouldEnter && OpenOrderTFPair(p, t, ORDER_TYPE_SELL, g_pairs[p].initialLot, "INIT"))
            {
               g_pairs[p].tfStates[t].initialSellPrice = SymbolInfoDouble(sym, SYMBOL_BID);
               g_pairs[p].tfStates[t].lastInitialCandle = tfBar;
               ResetTrailingStateTFPair(p, t);
            }
         }
      }

      if(!g_newOrderBlocked)
      {
         g_pairs[p].tfStates[t].justClosedBuy = false;
         g_pairs[p].tfStates[t].justClosedSell = false;
      }
   }

   // Per-pair matching close (ZigZag mode)
   {
      datetime mcBar = iTime(sym, PERIOD_CURRENT, 0);
      if(mcBar != g_pairs[p].lastMatchingBarTime)
      {
         g_pairs[p].lastMatchingBarTime = mcBar;
         ManageMatchingClosePair(p);
      }
   }

   // Per-pair accumulate (ZigZag mode)
   if(g_pairs[p].useAccumulate)
   {
      int cc = TotalOrderCountPair(p);
      if(g_pairs[p].hadPositions && cc == 0)
      {
         g_pairs[p].accumulateBaseline = CalcTotalHistoryProfitPair(p);
         g_pairs[p].accumulatedProfit = 0;
         g_pairs[p].hadPositions = false;
         return;
      }
      if(cc > 0) g_pairs[p].hadPositions = true;
      double totalHist = CalcTotalHistoryProfitPair(p);
      g_pairs[p].accumulatedProfit = totalHist - g_pairs[p].accumulateBaseline;
      double totalFloat = CalculateTotalFloatingPLPair(p);
      double accumTotal = g_pairs[p].accumulatedProfit + totalFloat;
      if(accumTotal >= g_pairs[p].accumTarget && accumTotal > 0)
      {
         Print("ACCUMULATE TARGET [", sym, "]: $", DoubleToString(accumTotal, 2));
         CloseAllPositionsPair(p);
         Sleep(500);
         g_pairs[p].accumulateBaseline = CalcTotalHistoryProfitPair(p);
         g_pairs[p].accumulatedProfit = 0;
         g_pairs[p].hadPositions = false;
      }
   }
}

//+------------------------------------------------------------------+
//| OnTick - Main                                                     |
//+------------------------------------------------------------------+
void OnTick()
{
   // ATR chart hide (backtest)
   if(!g_atrChartHidden && (MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE)))
   {
      if(g_isTesterMode && InpSkipATRInTester)
         g_atrChartHidden = true;
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
               if(StringFind(indName, "ATR") >= 0) { ChartIndicatorDelete(0, sw, indName); found = true; }
            }
         }
         if(found || g_atrHideAttempts >= 50) { g_atrChartHidden = true; ChartRedraw(0); }
      }
   }

   // License
   if(!g_isTesterMode)
   {
      if(!OnTickLicense()) return;
   }
   if(!g_isLicenseValid && !g_isTesterMode) return;

   // News
   RefreshNewsData();

   // Block flags
   g_newOrderBlocked = false;
   if(g_eaIsPaused) g_newOrderBlocked = true;
   if(IsNewsTimePaused()) g_newOrderBlocked = true;
   if(InpUseTimeFilter && !IsWithinTradingHours()) g_newOrderBlocked = true;

   // Daily profit pause
   if(InpEnableDailyProfitPause)
   {
      MqlDateTime dtNow;
      TimeToStruct(TimeCurrent(), dtNow);
      dtNow.hour = 0; dtNow.min = 0; dtNow.sec = 0;
      datetime today = StructToTime(dtNow);
      if(g_dailyProfitPauseDay != today) { g_dailyProfitPaused = false; g_dailyProfitPauseDay = today; }
      if(!g_dailyProfitPaused)
      {
         double dailyPL = CalcDailyPLAll();
         if(dailyPL >= InpDailyProfitTarget)
         {
            g_dailyProfitPaused = true;
            Print("DAILY PROFIT PAUSE: Target $", DoubleToString(InpDailyProfitTarget, 2), " reached");
         }
      }
      if(g_dailyProfitPaused) g_newOrderBlocked = true;
   }

   if(g_eaStopped) return;

   // Track max DD
   {
      double bal = AccountInfoDouble(ACCOUNT_BALANCE);
      double eq = AccountInfoDouble(ACCOUNT_EQUITY);
      if(bal > 0) { double dd = (bal - eq) / bal * 100.0; if(dd > g_maxDD) g_maxDD = dd; }
   }

   // Drawdown check (account-level)
   CheckDrawdownExit();

   // Process each enabled pair
   for(int p = 0; p < 5; p++)
   {
      if(!g_pairs[p].enabled) continue;
      string sym = g_pairs[p].symbol;

      // Per-order trailing
      if(EnablePerOrderTrailing)
         ManagePerOrderTrailingPair(p);
      else if(EnableTrailingStop || EnableBreakeven)
      {
         if(EntryMode == ENTRY_SMA) ManageTrailingStopPair(p);
      }

      // SMA Mode
      if(EntryMode == ENTRY_SMA)
      {
         ManageTPSLPair(p);

         // Matching close per new bar
         {
            datetime mcBar = iTime(sym, PERIOD_CURRENT, 0);
            if(mcBar != g_pairs[p].lastMatchingBarTime)
            {
               g_pairs[p].lastMatchingBarTime = mcBar;
               ManageMatchingClosePair(p);
            }
         }

         // New bar logic
         datetime currentBarTime = iTime(sym, PERIOD_CURRENT, 0);
         bool isNewBar = (currentBarTime != g_pairs[p].lastBarTime);
         if(isNewBar)
         {
            g_pairs[p].lastBarTime = currentBarTime;

            if(CopyBuffer(g_pairs[p].handleSMA, 0, 0, 3, g_pairs[p].bufSMA) < 3) continue;
            if(g_pairs[p].handleATR_Loss != INVALID_HANDLE)
               CopyBuffer(g_pairs[p].handleATR_Loss, 0, 0, 3, g_pairs[p].bufATR_Loss);
            if(g_pairs[p].handleATR_Profit != INVALID_HANDLE)
               CopyBuffer(g_pairs[p].handleATR_Profit, 0, 0, 3, g_pairs[p].bufATR_Profit);

            double smaValue = g_pairs[p].bufSMA[0];
            double currentPrice = SymbolInfoDouble(sym, SYMBOL_BID);

            int buyCount = 0, sellCount = 0;
            int glB = 0, glS = 0, gpB = 0, gpS = 0;
            bool hasIB = false, hasIS = false;
            CountPositionsPair(p, buyCount, sellCount, glB, glS, gpB, gpS, hasIB, hasIS);

            // Auto-detect broker-closed
            if(buyCount == 0 && g_pairs[p].initialBuyPrice != 0) g_pairs[p].initialBuyPrice = 0;
            if(sellCount == 0 && g_pairs[p].initialSellPrice != 0) g_pairs[p].initialSellPrice = 0;

            // Grid Loss
            if(!g_newOrderBlocked)
            {
               if((hasIB || g_pairs[p].initialBuyPrice > 0) && glB < g_pairs[p].gl_MaxTrades && buyCount > 0)
                  CheckGridLossPair(p, POSITION_TYPE_BUY, glB);
               if((hasIS || g_pairs[p].initialSellPrice > 0) && glS < g_pairs[p].gl_MaxTrades && sellCount > 0)
                  CheckGridLossPair(p, POSITION_TYPE_SELL, glS);
            }
            // Grid Profit
            if(!g_newOrderBlocked && g_pairs[p].gp_Enable)
            {
               if((hasIB || g_pairs[p].initialBuyPrice > 0) && gpB < g_pairs[p].gp_MaxTrades && buyCount > 0)
                  CheckGridProfitPair(p, POSITION_TYPE_BUY, gpB);
               if((hasIS || g_pairs[p].initialSellPrice > 0) && gpS < g_pairs[p].gp_MaxTrades && sellCount > 0)
                  CheckGridProfitPair(p, POSITION_TYPE_SELL, gpS);
            }

            // Entry
            if(!g_newOrderBlocked)
            {
               bool canOpenMore = TotalOrderCountAll() < MaxOpenOrders;
               bool canOpenOnThisCandle = !(DontOpenSameCandle && currentBarTime == g_pairs[p].lastInitialCandleTime);
               string pfx = g_pairs[p].commentPrefix;

               bool shouldEnterBuy = false;
               if(buyCount == 0)
               {
                  if(g_pairs[p].justClosedBuy && !EnableAutoReEntry) shouldEnterBuy = false;
                  else shouldEnterBuy = true;
               }
               bool shouldEnterSell = false;
               if(sellCount == 0)
               {
                  if(g_pairs[p].justClosedSell && !EnableAutoReEntry) shouldEnterSell = false;
                  else shouldEnterSell = true;
               }

               // BUY
               if(buyCount == 0 && g_pairs[p].initialBuyPrice == 0 && canOpenMore && canOpenOnThisCandle)
               {
                  if(currentPrice > smaValue && (TradingMode == TRADE_BUY_ONLY || TradingMode == TRADE_BOTH) && shouldEnterBuy)
                  {
                     if(OpenOrderPair(p, ORDER_TYPE_BUY, g_pairs[p].initialLot, pfx + "INIT"))
                     {
                        g_pairs[p].initialBuyPrice = SymbolInfoDouble(sym, SYMBOL_ASK);
                        g_pairs[p].lastInitialCandleTime = currentBarTime;
                        ResetTrailingStatePair(p);
                     }
                  }
               }
               // SELL
               if(sellCount == 0 && g_pairs[p].initialSellPrice == 0 && canOpenMore && canOpenOnThisCandle)
               {
                  if(currentPrice < smaValue && (TradingMode == TRADE_SELL_ONLY || TradingMode == TRADE_BOTH) && shouldEnterSell)
                  {
                     if(OpenOrderPair(p, ORDER_TYPE_SELL, g_pairs[p].initialLot, pfx + "INIT"))
                     {
                        g_pairs[p].initialSellPrice = SymbolInfoDouble(sym, SYMBOL_BID);
                        g_pairs[p].lastInitialCandleTime = currentBarTime;
                        ResetTrailingStatePair(p);
                     }
                  }
               }

               g_pairs[p].justClosedBuy = false;
               g_pairs[p].justClosedSell = false;
            }
         }
      }
      // ZigZag Mode
      else if(EntryMode == ENTRY_ZIGZAG)
      {
         OnTickZigZagMTFPair(p);
      }

      // Draw lines only for chart symbol
      if(sym == _Symbol) DrawLinesPair(p);
   }

   // Global accumulate
   ManageGlobalAccumulate();

   // Dashboard
   if(ShowDashboard) DisplayDashboard();
}

//+------------------------------------------------------------------+
//| Draw chart lines (only for pair matching chart symbol)             |
//+------------------------------------------------------------------+
void DrawLinesPair(int p)
{
   string sym = g_pairs[p].symbol;
   double point = SymbolInfoDouble(sym, SYMBOL_POINT);
   double avgBuy = CalculateAveragePricePair(p, POSITION_TYPE_BUY);
   double avgSell = CalculateAveragePricePair(p, POSITION_TYPE_SELL);

   if(avgBuy > 0 && ShowAverageLine) DrawHLine("GM_AvgBuyLine", avgBuy, AvgBuyLineColor, STYLE_SOLID, 2);
   else ObjectDelete(0, "GM_AvgBuyLine");

   if(avgSell > 0 && ShowAverageLine) DrawHLine("GM_AvgSellLine", avgSell, AvgSellLineColor, STYLE_SOLID, 2);
   else ObjectDelete(0, "GM_AvgSellLine");

   if(ShowTPLine && UseTP_Points && avgBuy > 0) DrawHLine("GM_TPBuyLine", avgBuy + TP_Points * point, TPBuyLineColor, STYLE_DASH, 1);
   else ObjectDelete(0, "GM_TPBuyLine");

   if(ShowTPLine && UseTP_Points && avgSell > 0) DrawHLine("GM_TPSellLine", avgSell - TP_Points * point, TPSellLineColor, STYLE_DASH, 1);
   else ObjectDelete(0, "GM_TPSellLine");

   if(ShowSLLine)
   {
      bool drawn = false;
      if(g_pairs[p].trailingActive_Buy && g_pairs[p].trailingSL_Buy > 0) { DrawHLine("GM_SLLine", g_pairs[p].trailingSL_Buy, SLLineColor, STYLE_DASH, 1); drawn = true; }
      else if(g_pairs[p].trailingActive_Sell && g_pairs[p].trailingSL_Sell > 0) { DrawHLine("GM_SLLine", g_pairs[p].trailingSL_Sell, SLLineColor, STYLE_DASH, 1); drawn = true; }
      if(!drawn && UseSL_Points)
      {
         if(avgBuy > 0) DrawHLine("GM_SLLine", avgBuy - SL_Points * point, SLLineColor, STYLE_DASH, 1);
         else if(avgSell > 0) DrawHLine("GM_SLLine", avgSell + SL_Points * point, SLLineColor, STYLE_DASH, 1);
         else ObjectDelete(0, "GM_SLLine");
      }
      else if(!drawn) ObjectDelete(0, "GM_SLLine");
   }
   else ObjectDelete(0, "GM_SLLine");
}

void DrawHLine(string name, double price, color clr, ENUM_LINE_STYLE style, int width)
{
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
   ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Dashboard Helpers                                                  |
//+------------------------------------------------------------------+
void CreateDashRect(string name, int x, int y, int w, int h, color bgColor)
{
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
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

void CreateDashText(string name, int x, int y, string text, color clr, int fontSize, string font)
{
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
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

void DrawTableRow(int rowIndex, string label, string value, color valueColor, color sectionColor)
{
   int x = DashboardX;
   int y = DashboardY + 24 + rowIndex * 20;
   int tableWidth = 380;
   int rowHeight = 19;
   int sectionBarWidth = 4;
   color rowBg = (rowIndex % 2 == 0) ? C'40,44,52' : C'35,39,46';
   string rowName = "GM_TBL_R" + IntegerToString(rowIndex);
   string secName = "GM_TBL_S" + IntegerToString(rowIndex);
   string lblName = "GM_TBL_L" + IntegerToString(rowIndex);
   string valName = "GM_TBL_V" + IntegerToString(rowIndex);
   CreateDashRect(rowName, x, y, tableWidth, rowHeight, rowBg);
   CreateDashRect(secName, x, y, sectionBarWidth, rowHeight, sectionColor);
   CreateDashText(lblName, x + sectionBarWidth + 6, y + 2, label, C'180,180,180', 9, "Consolas");
   CreateDashText(valName, x + 200, y + 2, value, valueColor, 9, "Consolas");
}

void CreateDashButton(string name, int x, int y, int width, int height, string text, color bgColor, color textColor)
{
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
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
//| Dashboard - Multi-Pair Layout                                      |
//+------------------------------------------------------------------+
void DisplayDashboard()
{
   int tableWidth = 380;
   int headerHeight = 22;

   color COLOR_HEADER_BG = C'180,130,50';
   color COLOR_HEADER_TEXT = clrWhite;
   color COLOR_SECTION_PAIR = clrGold;
   color COLOR_SECTION_DETAIL = clrGreen;
   color COLOR_SECTION_ACCUM = clrYellow;
   color COLOR_SECTION_INFO = clrDodgerBlue;
   color COLOR_PROFIT = clrLime;
   color COLOR_LOSS = clrOrangeRed;
   color COLOR_TEXT = clrWhite;

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double dd = (balance > 0) ? (balance - equity) / balance * 100.0 : 0;

   string headerText = (EntryMode == ENTRY_SMA) ? "Asset Miner v4.0 [SMA] Multi-Pair" : "Asset Miner v4.0 [ZZ] Multi-Pair";
   CreateDashRect("GM_TBL_HDR", DashboardX, DashboardY, tableWidth, headerHeight, COLOR_HEADER_BG);
   CreateDashText("GM_TBL_HDR_T", DashboardX + 8, DashboardY + 3, headerText, COLOR_HEADER_TEXT, 10, "Arial Bold");

   int row = 0;
   DrawTableRow(row, "Balance", "$" + DoubleToString(balance, 2), COLOR_TEXT, COLOR_SECTION_DETAIL); row++;
   DrawTableRow(row, "Equity", "$" + DoubleToString(equity, 2), COLOR_TEXT, COLOR_SECTION_DETAIL); row++;

   double totalFloat = CalculateAllFloatingPL();
   DrawTableRow(row, "Total Float P/L", "$" + DoubleToString(totalFloat, 2), (totalFloat >= 0 ? COLOR_PROFIT : COLOR_LOSS), COLOR_SECTION_DETAIL); row++;
   DrawTableRow(row, "DD%", DoubleToString(dd, 2) + "% / Max " + DoubleToString(g_maxDD, 2) + "%", (dd > 10 ? COLOR_LOSS : COLOR_TEXT), COLOR_SECTION_DETAIL); row++;

   // Per-pair summary
   for(int p = 0; p < 5; p++)
   {
      if(!g_pairs[p].enabled) continue;
      int bc = 0, sc = 0, gl1 = 0, gl2 = 0, gp1 = 0, gp2 = 0;
      bool ib = false, is2 = false;
      CountPositionsPair(p, bc, sc, gl1, gl2, gp1, gp2, ib, is2);
      double pl = CalculateTotalFloatingPLPair(p);

      string label = "P" + IntegerToString(p + 1) + " " + g_pairs[p].symbol;
      string info = IntegerToString(bc) + "B/" + IntegerToString(sc) + "S  $" + DoubleToString(pl, 2);
      DrawTableRow(row, label, info, (pl >= 0 ? COLOR_PROFIT : COLOR_LOSS), COLOR_SECTION_PAIR); row++;
   }

   // Global accumulate info
   if(UseGlobalAccumulate)
   {
      double gAccum = g_globalAccumProfit + totalFloat;
      DrawTableRow(row, "Global Accum", "$" + DoubleToString(gAccum, 2) + " / $" + DoubleToString(GlobalAccumulateTarget, 2),
                   (gAccum >= 0 ? COLOR_PROFIT : COLOR_LOSS), COLOR_SECTION_ACCUM); row++;
   }

   // News status
   if(InpEnableNewsFilter)
   {
      color newsColor = g_isNewsPaused ? COLOR_LOSS : COLOR_PROFIT;
      string newsStr = g_isNewsPaused ? g_newsStatus : "No Important news";
      DrawTableRow(row, "News Filter", newsStr, newsColor, COLOR_SECTION_INFO); row++;
   }

   // Status
   string statusStr = g_eaIsPaused ? "PAUSED" : (g_newOrderBlocked ? "BLOCKED" : "ACTIVE");
   color statusColor = g_eaIsPaused ? COLOR_LOSS : (g_newOrderBlocked ? clrYellow : COLOR_PROFIT);
   DrawTableRow(row, "EA Status", statusStr, statusColor, COLOR_SECTION_INFO); row++;

   // License
   if(!g_isTesterMode)
   {
      string licStr = g_isLicenseValid ? (g_isLifetime ? "LIFETIME" : IntegerToString(g_daysRemaining) + " days") : "INVALID";
      DrawTableRow(row, "License", licStr, (g_isLicenseValid ? COLOR_PROFIT : COLOR_LOSS), COLOR_SECTION_INFO); row++;
   }

   // Buttons
   int btnY = DashboardY + 24 + row * 20 + 5;
   int btnW = (tableWidth - 10) / 2;
   int btnH = 22;

   string pauseText = g_eaIsPaused ? "▶ Start" : "⏸ Pause";
   color pauseBg = g_eaIsPaused ? clrForestGreen : clrOrangeRed;
   CreateDashButton("GM_BtnPause", DashboardX, btnY, tableWidth, btnH, pauseText, pauseBg, clrWhite);
   btnY += btnH + 3;

   CreateDashButton("GM_BtnCloseBuy", DashboardX, btnY, btnW, btnH, "Close All Buy", C'20,100,50', clrWhite);
   CreateDashButton("GM_BtnCloseSell", DashboardX + btnW + 10, btnY, btnW, btnH, "Close All Sell", C'180,50,30', clrWhite);
   btnY += btnH + 3;

   CreateDashButton("GM_BtnCloseAll", DashboardX, btnY, tableWidth, btnH, "Close All Pairs", C'30,100,180', clrWhite);
}

//+------------------------------------------------------------------+
//| Chart Event Handler                                                |
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
         int result = MessageBox("Close all BUY orders (all pairs)?", "Confirm", MB_YESNO | MB_ICONWARNING);
         if(result == IDYES)
         {
            for(int pp = 0; pp < 5; pp++)
            {
               if(g_pairs[pp].enabled) CloseAllSidePair(pp, POSITION_TYPE_BUY);
            }
         }
      }
      else if(sparam == "GM_BtnCloseSell")
      {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         int result = MessageBox("Close all SELL orders (all pairs)?", "Confirm", MB_YESNO | MB_ICONWARNING);
         if(result == IDYES)
         {
            for(int pp = 0; pp < 5; pp++)
            {
               if(g_pairs[pp].enabled) CloseAllSidePair(pp, POSITION_TYPE_SELL);
            }
         }
      }
      else if(sparam == "GM_BtnCloseAll")
      {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         int result = MessageBox("Close ALL orders (all pairs)?", "Confirm", MB_YESNO | MB_ICONWARNING);
         if(result == IDYES) CloseAllPositionsAll();
      }
      ChartRedraw(0);
   }
}

//+------------------------------------------------------------------+
//| OnTradeTransaction - Sync on order events                          |
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

         bool isOurs = (dealMagic == 0);
         for(int pp = 0; pp < 5 && !isOurs; pp++)
         {
            if(g_pairs[pp].enabled && dealMagic == g_pairs[pp].magic) isOurs = true;
         }

         if(isOurs)
         {
            if(dealEntry == DEAL_ENTRY_IN) SyncAccountDataWithEvent(SYNC_ORDER_OPEN);
            else if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_INOUT) SyncAccountDataWithEvent(SYNC_ORDER_CLOSE);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| ============== LICENSE MODULE ================================== |
//+------------------------------------------------------------------+
bool IsTesterMode()
{
   return (MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_OPTIMIZATION) ||
           MQLInfoInteger(MQL_VISUAL_MODE) || MQLInfoInteger(MQL_FRAME_MODE));
}

bool InitLicense(string baseUrl, int checkIntervalMinutes = 60, int syncIntervalMinutes = 5)
{
   g_licenseServerUrl = baseUrl;
   g_licenseCheckInterval = checkIntervalMinutes;
   g_dataSyncInterval = syncIntervalMinutes;
   g_lastLicenseCheck = 0;
   g_lastDataSync = 0;
   g_lastExpiryPopup = 0;
   if(StringLen(g_licenseServerUrl) == 0) { g_lastLicenseError = "License server URL is empty"; g_licenseStatus = LICENSE_ERROR; return false; }
   g_licenseStatus = VerifyLicense();
   g_lastLicenseCheck = TimeCurrent();
   g_isLicenseValid = (g_licenseStatus == LICENSE_VALID || g_licenseStatus == LICENSE_EXPIRING_SOON);
   if(g_isLicenseValid) { SyncAccountData(); g_lastDataSync = TimeCurrent(); }
   return g_isLicenseValid;
}

ENUM_LICENSE_STATUS VerifyLicense()
{
   string url = g_licenseServerUrl + "/functions/v1/verify-license";
   long accountNumber = AccountInfoInteger(ACCOUNT_LOGIN);
   string jsonRequest = "{\"account_number\":\"" + IntegerToString(accountNumber) + "\"}";
   string response = "";
   int httpCode = SendLicenseRequest(url, jsonRequest, response);
   if(httpCode != 200) { g_lastLicenseError = "HTTP Error: " + IntegerToString(httpCode); return LICENSE_ERROR; }
   return ParseVerifyResponse(response);
}

ENUM_LICENSE_STATUS ParseVerifyResponse(string response)
{
   bool valid = JsonGetBool(response, "valid");
   if(!valid)
   {
      string message = JsonGetString(response, "message");
      g_lastLicenseError = message;
      if(StringFind(message, "not found") >= 0 || StringFind(message, "Not found") >= 0) return LICENSE_NOT_FOUND;
      if(StringFind(message, "suspended") >= 0 || StringFind(message, "inactive") >= 0) return LICENSE_SUSPENDED;
      if(StringFind(message, "expired") >= 0 || StringFind(message, "Expired") >= 0) return LICENSE_EXPIRED;
      return LICENSE_ERROR;
   }
   g_customerName = JsonGetString(response, "customer_name");
   g_packageType = JsonGetString(response, "package_type");
   g_tradingSystem = JsonGetString(response, "trading_system");
   g_daysRemaining = JsonGetInt(response, "days_remaining");
   g_isLifetime = JsonGetBool(response, "is_lifetime");
   string expiryStr = JsonGetString(response, "expiry_date");
   if(StringLen(expiryStr) > 0 && expiryStr != "null") g_expiryDate = StringToTime(StringSubstr(expiryStr, 0, 10));
   if(!g_isLifetime && g_daysRemaining <= 7 && g_daysRemaining > 0) return LICENSE_EXPIRING_SOON;
   return LICENSE_VALID;
}

bool SyncAccountData() { return SyncAccountDataWithEvent(SYNC_SCHEDULED); }

bool SyncAccountDataWithEvent(ENUM_SYNC_EVENT eventType)
{
   string url = g_licenseServerUrl + "/functions/v1/sync-account-data";
   long accountNumber = AccountInfoInteger(ACCOUNT_LOGIN);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double marginLevel = AccountInfoDouble(ACCOUNT_MARGIN_LEVEL);
   double floatingProfit = AccountInfoDouble(ACCOUNT_PROFIT);
   double drawdown = 0;
   if(balance > 0) { drawdown = ((balance - equity) / balance) * 100; if(drawdown < 0) drawdown = 0; }
   int openOrders = PositionsTotal();
   double totalProfit = 0, totalDeposit = 0, totalWithdrawal = 0, initialBalance = 0, maxDrawdown = 0;
   int winTrades = 0, lossTrades = 0, totalTrades = 0;
   CalculatePortfolioStats(totalProfit, totalDeposit, totalWithdrawal, initialBalance, maxDrawdown, winTrades, lossTrades, totalTrades);
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
   string accountTypeStr = (tradeMode == ACCOUNT_TRADE_MODE_DEMO) ? "demo" : (tradeMode == ACCOUNT_TRADE_MODE_CONTEST) ? "contest" : "real";

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
   json += "\"ea_name\":\"Asset Miner EA\",";
   json += "\"ea_status\":\"" + eaStatus + "\",";
   json += "\"currency\":\"" + accountCurrency + "\",";
   json += "\"account_type\":\"" + accountTypeStr + "\"";
   string tradeHistoryJson = BuildTradeHistoryJson();
   if(StringLen(tradeHistoryJson) > 2) json += ",\"trade_history\":" + tradeHistoryJson;
   json += "}";

   string response = "";
   int httpCode = SendLicenseRequest(url, json, response);
   if(httpCode != 200) { g_lastLicenseError = "Sync HTTP Error: " + IntegerToString(httpCode); return false; }
   return JsonGetBool(response, "success");
}

void CalculatePortfolioStats(double &totalProfit, double &totalDeposit, double &totalWithdrawal,
                             double &initialBalance, double &maxDrawdown, int &winTrades, int &lossTrades, int &totalTrades)
{
   totalProfit = 0; totalDeposit = 0; totalWithdrawal = 0; initialBalance = 0; maxDrawdown = 0;
   winTrades = 0; lossTrades = 0; totalTrades = 0;
   if(!HistorySelect(0, TimeCurrent())) return;
   int totalDeals = HistoryDealsTotal();
   double peakBalance = 0, runningBalance = 0;
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
            if(dealProfit > 0) { totalDeposit += dealProfit; if(firstDeposit) { initialBalance = dealProfit; firstDeposit = false; } }
            else totalWithdrawal += MathAbs(dealProfit);
            runningBalance += dealProfit;
         }
         else if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_INOUT)
         {
            double netProfit = dealProfit + dealSwap + dealCommission;
            totalProfit += netProfit;
            runningBalance += netProfit;
            totalTrades++;
            if(netProfit >= 0) winTrades++; else lossTrades++;
         }
         if(runningBalance > peakBalance) peakBalance = runningBalance;
         if(peakBalance > 0) { double currentDD = ((peakBalance - runningBalance) / peakBalance) * 100; if(currentDD > maxDrawdown) maxDrawdown = currentDD; }
      }
   }
}

string BuildTradeHistoryJson()
{
   string json = "[";
   bool first = true;
   if(!HistorySelect(0, TimeCurrent())) return "[]";
   int totalDeals = HistoryDealsTotal();
   int startIdx = MathMax(0, totalDeals - 100);
   for(int i = startIdx; i < totalDeals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket > 0)
      {
         ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(dealTicket, DEAL_TYPE);
         ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
         if(dealType != DEAL_TYPE_BUY && dealType != DEAL_TYPE_SELL && dealType != DEAL_TYPE_BALANCE) continue;
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
         string dealTypeStr = (dealType == DEAL_TYPE_BUY) ? "buy" : (dealType == DEAL_TYPE_SELL) ? "sell" : "balance";
         string entryTypeStr = (dealEntry == DEAL_ENTRY_IN) ? "in" : (dealEntry == DEAL_ENTRY_OUT) ? "out" : (dealEntry == DEAL_ENTRY_INOUT) ? "inout" : "unknown";
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

bool OnTickLicense()
{
   datetime currentTime = TimeCurrent();
   if(currentTime - g_lastLicenseCheck >= g_licenseCheckInterval * 60)
   {
      g_licenseStatus = VerifyLicense();
      g_lastLicenseCheck = currentTime;
      g_isLicenseValid = (g_licenseStatus == LICENSE_VALID || g_licenseStatus == LICENSE_EXPIRING_SOON);
      if(g_licenseStatus == LICENSE_EXPIRING_SOON)
      {
         if(currentTime - g_lastExpiryPopup >= 86400) { ShowLicensePopup(g_licenseStatus); g_lastExpiryPopup = currentTime; }
      }
   }
   if(g_isLicenseValid && currentTime - g_lastDataSync >= g_dataSyncInterval * 60)
   {
      SyncAccountData();
      g_lastDataSync = currentTime;
   }
   return g_isLicenseValid;
}

void ShowLicensePopup(ENUM_LICENSE_STATUS status)
{
   if(MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_OPTIMIZATION)) return;
   string title = "Asset Miner EA - License";
   string msg = "";
   switch(status)
   {
      case LICENSE_VALID: msg = "License Valid!\nCustomer: " + g_customerName; break;
      case LICENSE_EXPIRING_SOON: msg = "License Expiring Soon!\n" + IntegerToString(g_daysRemaining) + " days remaining"; break;
      case LICENSE_EXPIRED: msg = "License Expired!\nPlease contact support."; break;
      case LICENSE_NOT_FOUND: msg = "Account Not Registered!\nAccount: " + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)); break;
      case LICENSE_SUSPENDED: msg = "License Suspended!\nPlease contact support."; break;
      case LICENSE_ERROR: msg = "License Error: " + g_lastLicenseError; break;
   }
   if(status != LICENSE_VALID) MessageBox(msg, title, 0x30);
}

int SendLicenseRequest(string url, string jsonData, string &response)
{
   char postData[];
   char resultData[];
   string resultHeaders;
   StringToCharArray(jsonData, postData, 0, WHOLE_ARRAY, CP_UTF8);
   ArrayResize(postData, ArraySize(postData) - 1);
   string headers = "Content-Type: application/json\r\nApikey: " + EA_API_SECRET + "\r\nAuthorization: Bearer " + EA_API_SECRET;
   int result = WebRequest("POST", url, headers, 10000, postData, resultData, resultHeaders);
   if(result == -1) { response = ""; return -1; }
   response = CharArrayToString(resultData, 0, WHOLE_ARRAY, CP_UTF8);
   return result;
}

//+------------------------------------------------------------------+
//| JSON Helpers                                                       |
//+------------------------------------------------------------------+
string JsonGetString(string json, string key)
{
   string searchKey = "\"" + key + "\":";
   int startPos = StringFind(json, searchKey);
   if(startPos < 0) return "";
   int valueStart = startPos + StringLen(searchKey);
   while(valueStart < StringLen(json) && StringSubstr(json, valueStart, 1) == " ") valueStart++;
   if(valueStart >= StringLen(json)) return "";
   if(StringSubstr(json, valueStart, 4) == "null") return "";
   if(StringGetCharacter(json, valueStart) == '"')
   {
      valueStart++;
      int valueEnd = StringFind(json, "\"", valueStart);
      if(valueEnd < 0) return "";
      return StringSubstr(json, valueStart, valueEnd - valueStart);
   }
   int valueEnd = valueStart;
   while(valueEnd < StringLen(json))
   {
      ushort ch = StringGetCharacter(json, valueEnd);
      if(ch == ',' || ch == '}' || ch == ']') break;
      valueEnd++;
   }
   return StringSubstr(json, valueStart, valueEnd - valueStart);
}

int JsonGetInt(string json, string key) { string v = JsonGetString(json, key); return (StringLen(v) == 0) ? 0 : (int)StringToInteger(v); }
bool JsonGetBool(string json, string key) { string v = JsonGetString(json, key); return (v == "true" || v == "1"); }

//+------------------------------------------------------------------+
//| ============== NEWS FILTER MODULE ============================== |
//+------------------------------------------------------------------+
string GetChartBaseCurrency() { string s = _Symbol; return (StringLen(s) >= 6) ? StringSubstr(s, 0, 3) : ""; }
string GetChartQuoteCurrency() { string s = _Symbol; return (StringLen(s) >= 6) ? StringSubstr(s, 3, 3) : ""; }

bool IsCurrencyRelevant(string newsCurrency)
{
   if(InpNewsUseChartCurrency)
   {
      string b = GetChartBaseCurrency();
      string q = GetChartQuoteCurrency();
      return (newsCurrency == b || newsCurrency == q);
   }
   string currencies = InpNewsCurrencies;
   if(StringLen(currencies) == 0) return false;
   string currencyList[];
   int count = StringSplit(currencies, ';', currencyList);
   for(int i = 0; i < count; i++)
   {
      string curr = currencyList[i];
      StringTrimLeft(curr); StringTrimRight(curr);
      if(curr == newsCurrency) return true;
   }
   return false;
}

bool IsCustomNewsMatch(string newsTitle)
{
   if(!InpFilterCustomNews) return false;
   string keywords = InpCustomNewsKeywords;
   if(StringLen(keywords) == 0) return false;
   string keywordList[];
   int count = StringSplit(keywords, ';', keywordList);
   string upperTitle = newsTitle;
   StringToUpper(upperTitle);
   for(int i = 0; i < count; i++)
   {
      string keyword = keywordList[i];
      StringTrimLeft(keyword); StringTrimRight(keyword); StringToUpper(keyword);
      if(StringLen(keyword) > 0 && StringFind(upperTitle, keyword) >= 0) return true;
   }
   return false;
}

string ExtractJSONValue(string json, string key)
{
   string quote = "\"";
   string searchKey = quote + key + quote + ":";
   int startPos = StringFind(json, searchKey);
   if(startPos < 0) return "";
   startPos += StringLen(searchKey);
   while(startPos < StringLen(json) && StringSubstr(json, startPos, 1) == " ") startPos++;
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
         if(c == "," || c == "}" || c == "]") break;
         endPos++;
      }
      value = StringSubstr(json, startPos, endPos - startPos);
   }
   StringTrimLeft(value); StringTrimRight(value);
   return value;
}

bool CheckWebRequestConfiguration()
{
   if(!InpEnableNewsFilter) { g_webRequestConfigured = true; return true; }
   string testUrl = InpLicenseServer + "/functions/v1/economic-news?limit=1";
   char postData[], resultData[];
   string headers = "";
   string resultHeaders;
   ResetLastError();
   int result = WebRequest("GET", testUrl, headers, 5000, postData, resultData, resultHeaders);
   if(result == -1)
   {
      int error = GetLastError();
      if(error == 4060 || error == 4024) { g_webRequestConfigured = false; return false; }
      if(error == 5203 || error == 5200 || error == 5201) { g_webRequestConfigured = true; return true; }
      return g_webRequestConfigured;
   }
   g_webRequestConfigured = true;
   return true;
}

void RefreshNewsData()
{
   if(!InpEnableNewsFilter) return;
   datetime currentTime = TimeCurrent();
   if(!g_forceNewsRefresh && g_lastNewsRefresh > 0 && (currentTime - g_lastNewsRefresh) < 3600) return;
   g_forceNewsRefresh = false;

   string currencies = "";
   if(InpNewsUseChartCurrency)
   {
      string sym = Symbol();
      if(StringLen(sym) >= 6) currencies = StringSubstr(sym, 0, 3) + "," + StringSubstr(sym, 3, 3);
   }
   else { currencies = InpNewsCurrencies; StringReplace(currencies, ";", ","); }

   string impacts = "";
   bool hasCustom = InpFilterCustomNews && StringLen(InpCustomNewsKeywords) > 0;
   if(!hasCustom)
   {
      if(InpFilterHighNews) impacts += "High,";
      if(InpFilterMedNews) impacts += "Medium,";
      if(InpFilterLowNews) impacts += "Low,";
      if(StringLen(impacts) > 0) impacts = StringSubstr(impacts, 0, StringLen(impacts) - 1);
   }

   string apiUrl = InpLicenseServer + "/functions/v1/economic-news?ts=" + IntegerToString((long)currentTime);
   if(StringLen(currencies) > 0) apiUrl += "&currency=" + currencies;
   if(StringLen(impacts) > 0) apiUrl += "&impact=" + impacts;

   char postData[], resultData[];
   string headers = "User-Agent: MoneyX-EA/4.0\r\nAccept: application/json\r\nConnection: close";
   string resultHeaders;
   int result = WebRequest("GET", apiUrl, headers, 10000, postData, resultData, resultHeaders);
   if(result == -1) { Sleep(1000); ResetLastError(); result = WebRequest("GET", apiUrl, headers, 10000, postData, resultData, resultHeaders); }
   if(result == -1 || result != 200)
   {
      if(g_newsEventCount > 0) g_usingCachedNews = true;
      g_lastNewsRefresh = currentTime - 3300;
      return;
   }

   string jsonContent = CharArrayToString(resultData, 0, WHOLE_ARRAY, CP_UTF8);
   if(ArraySize(resultData) < 10) { if(g_newsEventCount > 0) g_usingCachedNews = true; return; }

   string trimmed = jsonContent; StringTrimLeft(trimmed);
   if(StringSubstr(trimmed, 0, 1) != "{") { if(g_newsEventCount > 0) g_usingCachedNews = true; return; }

   string successValue = ExtractJSONValue(jsonContent, "success");
   if(successValue != "true") { if(g_newsEventCount > 0) g_usingCachedNews = true; return; }

   NewsEvent tmpEvents[];
   int tmpCount = 0;
   ArrayResize(tmpEvents, 100);
   int dataStart = StringFind(jsonContent, "\"data\":", 0);
   if(dataStart < 0) { if(g_newsEventCount > 0) g_usingCachedNews = true; return; }
   int arrayStart = StringFind(jsonContent, "[", dataStart);
   if(arrayStart < 0) { if(g_newsEventCount > 0) g_usingCachedNews = true; return; }

   int searchPos = arrayStart + 1;
   int firstBrace = StringFind(jsonContent, "{", searchPos);
   if(firstBrace < 0) { g_lastNewsRefresh = currentTime; return; }
   searchPos = firstBrace;

   while(searchPos < StringLen(jsonContent))
   {
      int braceDepth = 0;
      int objEnd = -1;
      for(int i = searchPos; i < StringLen(jsonContent); i++)
      {
         string c = StringSubstr(jsonContent, i, 1);
         if(c == "{") braceDepth++;
         else if(c == "}") { braceDepth--; if(braceDepth == 0) { objEnd = i; break; } }
         else if(c == "]" && braceDepth == 0) break;
      }
      if(objEnd < 0) break;
      string eventJson = StringSubstr(jsonContent, searchPos, objEnd - searchPos + 1);
      string title = ExtractJSONValue(eventJson, "title");
      string currency = ExtractJSONValue(eventJson, "currency");
      string timestampStr = ExtractJSONValue(eventJson, "timestamp");
      string impact = ExtractJSONValue(eventJson, "impact");
      datetime eventTime = (datetime)StringToInteger(timestampStr);
      if(impact != "Holiday" && tmpCount < ArraySize(tmpEvents))
      {
         bool isRelevant = false;
         if(IsCurrencyRelevant(currency))
         {
            if(InpFilterHighNews && impact == "High") isRelevant = true;
            else if(InpFilterMedNews && impact == "Medium") isRelevant = true;
            else if(InpFilterLowNews && impact == "Low") isRelevant = true;
            if(IsCustomNewsMatch(title)) isRelevant = true;
         }
         tmpEvents[tmpCount].title = title;
         tmpEvents[tmpCount].country = currency;
         tmpEvents[tmpCount].time = eventTime;
         tmpEvents[tmpCount].impact = impact;
         tmpEvents[tmpCount].isRelevant = isRelevant;
         tmpCount++;
      }
      searchPos = objEnd + 1;
   }

   if(tmpCount > 0)
   {
      ArrayResize(g_newsEvents, tmpCount);
      for(int i = 0; i < tmpCount; i++) g_newsEvents[i] = tmpEvents[i];
      g_newsEventCount = tmpCount;
      g_lastNewsRefresh = currentTime;
      g_lastGoodNewsTime = currentTime;
      g_usingCachedNews = false;
      SaveNewsCacheToFile();
   }
   else
   {
      g_lastNewsRefresh = currentTime;
   }
}

void SaveNewsCacheToFile()
{
   if(g_newsEventCount <= 0) return;
   int handle = FileOpen(g_newsCacheFile, FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(handle == INVALID_HANDLE) return;
   FileWriteString(handle, "# AssetMiner News Cache - " + TimeToString(TimeCurrent()) + "\n");
   for(int i = 0; i < g_newsEventCount; i++)
   {
      string line = g_newsEvents[i].title + "|" + g_newsEvents[i].country + "|" +
                    IntegerToString((long)g_newsEvents[i].time) + "|" + g_newsEvents[i].impact + "|" +
                    (g_newsEvents[i].isRelevant ? "1" : "0") + "\n";
      FileWriteString(handle, line);
   }
   FileClose(handle);
   g_lastFileCacheSave = TimeCurrent();
}

void LoadNewsCacheFromFile()
{
   if(!FileIsExist(g_newsCacheFile)) return;
   int handle = FileOpen(g_newsCacheFile, FILE_READ | FILE_TXT | FILE_ANSI);
   if(handle == INVALID_HANDLE) return;
   ArrayResize(g_newsEvents, 100);
   g_newsEventCount = 0;
   while(!FileIsEnding(handle))
   {
      string line = FileReadString(handle);
      if(StringSubstr(line, 0, 1) == "#") continue;
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
   if(g_newsEventCount > 0) g_usingCachedNews = true;
}

void GetNewsPauseDuration(string impact, bool isCustomMatch, int &beforeMin, int &afterMin)
{
   beforeMin = 0; afterMin = 0;
   int customBefore = 0, customAfter = 0, impactBefore = 0, impactAfter = 0;
   if(isCustomMatch && InpFilterCustomNews) { customBefore = InpPauseBeforeCustom; customAfter = InpPauseAfterCustom; }
   if(impact == "High" && InpFilterHighNews) { impactBefore = InpPauseBeforeHigh; impactAfter = InpPauseAfterHigh; }
   else if(impact == "Medium" && InpFilterMedNews) { impactBefore = InpPauseBeforeMed; impactAfter = InpPauseAfterMed; }
   else if(impact == "Low" && InpFilterLowNews) { impactBefore = InpPauseBeforeLow; impactAfter = InpPauseAfterLow; }
   if(customBefore + customAfter >= impactBefore + impactAfter && customBefore + customAfter > 0) { beforeMin = customBefore; afterMin = customAfter; }
   else if(impactBefore + impactAfter > 0) { beforeMin = impactBefore; afterMin = impactAfter; }
}

bool IsEventRelevantNow(const NewsEvent &ev)
{
   if(!IsCurrencyRelevant(ev.country)) return false;
   if(InpFilterCustomNews && IsCustomNewsMatch(ev.title)) return true;
   if(InpFilterHighNews && ev.impact == "High") return true;
   if(InpFilterMedNews && ev.impact == "Medium") return true;
   if(InpFilterLowNews && ev.impact == "Low") return true;
   return false;
}

bool IsNewsTimePaused()
{
   if(!InpEnableNewsFilter) { g_isNewsPaused = false; g_newsStatus = "OFF"; if(g_lastPausedState) { g_lastPausedState = false; g_lastPauseKey = ""; } return false; }
   datetime currentTime = TimeCurrent();
   bool foundPause = false;
   string pauseKey = "";
   g_nextNewsTitle = ""; g_nextNewsTime = 0;
   datetime closestNewsTime = 0;
   datetime earliestPauseEnd = 0;
   string earliestNewsTitle = "", earliestCountry = "", earliestImpact = "";
   datetime earliestNewsTime = 0;

   for(int i = 0; i < g_newsEventCount; i++)
   {
      if(!IsEventRelevantNow(g_newsEvents[i])) continue;
      datetime newsTime = g_newsEvents[i].time;
      string impact = g_newsEvents[i].impact;
      bool isCustom = IsCustomNewsMatch(g_newsEvents[i].title);
      int beforeMin, afterMin;
      GetNewsPauseDuration(impact, isCustom, beforeMin, afterMin);
      if(beforeMin == 0 && afterMin == 0) continue;
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
         if(currentTime < futureStart) closestNewsTime = newsTime;
      }
   }

   if(foundPause)
   {
      g_nextNewsTitle = earliestNewsTitle;
      g_nextNewsTime = earliestNewsTime;
      g_newsPauseEndTime = earliestPauseEnd;
      pauseKey = earliestNewsTitle + "|" + IntegerToString((long)earliestNewsTime);
      if(currentTime < earliestNewsTime)
         g_newsStatus = "PAUSE: " + earliestCountry + " " + earliestImpact + " in " + IntegerToString((int)((earliestNewsTime - currentTime) / 60)) + "m";
      else
         g_newsStatus = "PAUSE: " + earliestCountry + " " + earliestImpact + " +" + IntegerToString((int)((currentTime - earliestNewsTime) / 60)) + "m ago";
      g_isNewsPaused = true;
      if(!g_lastPausedState || g_lastPauseKey != pauseKey) { g_lastPausedState = true; g_lastPauseKey = pauseKey; }
      return true;
   }
   else
   {
      g_isNewsPaused = false;
      g_newsPauseEndTime = 0;
      if(g_lastPausedState) { g_lastPausedState = false; g_lastPauseKey = ""; }
      g_newsStatus = "No Important news";
      return false;
   }
}

//+------------------------------------------------------------------+
//| ============== TIME FILTER MODULE ============================== |
//+------------------------------------------------------------------+
int ParseTimeToMinutes(string timeStr)
{
   if(StringLen(timeStr) < 5) return -1;
   int colonPos = StringFind(timeStr, ":");
   if(colonPos < 0) return -1;
   int hour = (int)StringToInteger(StringSubstr(timeStr, 0, colonPos));
   int min = (int)StringToInteger(StringSubstr(timeStr, colonPos + 1, 2));
   if(hour < 0 || hour > 23 || min < 0 || min > 59) return -1;
   return hour * 60 + min;
}

bool IsTimeInSession(string session, int currentMinutes)
{
   if(StringLen(session) < 11) return false;
   int dashPos = StringFind(session, "-");
   if(dashPos < 0) return false;
   int startMinutes = ParseTimeToMinutes(StringSubstr(session, 0, dashPos));
   int endMinutes = ParseTimeToMinutes(StringSubstr(session, dashPos + 1));
   if(startMinutes < 0 || endMinutes < 0) return false;
   if(startMinutes <= endMinutes) return (currentMinutes >= startMinutes && currentMinutes < endMinutes);
   else return (currentMinutes >= startMinutes || currentMinutes < endMinutes);
}

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

bool IsWithinTradingHours()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   if(!IsTradableDay(dt.day_of_week)) return false;
   int currentMinutes = dt.hour * 60 + dt.min;
   bool isFriday = (dt.day_of_week == 5);
   if(isFriday)
   {
      bool hasFridaySessions = (StringLen(InpFridaySession1) >= 5 || StringLen(InpFridaySession2) >= 5 || StringLen(InpFridaySession3) >= 5);
      if(hasFridaySessions)
      {
         if(StringLen(InpFridaySession1) >= 5 && IsTimeInSession(InpFridaySession1, currentMinutes)) return true;
         if(StringLen(InpFridaySession2) >= 5 && IsTimeInSession(InpFridaySession2, currentMinutes)) return true;
         if(StringLen(InpFridaySession3) >= 5 && IsTimeInSession(InpFridaySession3, currentMinutes)) return true;
         return false;
      }
   }
   if(StringLen(InpSession1) >= 5 && IsTimeInSession(InpSession1, currentMinutes)) return true;
   if(StringLen(InpSession2) >= 5 && IsTimeInSession(InpSession2, currentMinutes)) return true;
   if(StringLen(InpSession3) >= 5 && IsTimeInSession(InpSession3, currentMinutes)) return true;
   if(StringLen(InpSession1) < 5 && StringLen(InpSession2) < 5 && StringLen(InpSession3) < 5) return true;
   return false;
}
//+------------------------------------------------------------------+
