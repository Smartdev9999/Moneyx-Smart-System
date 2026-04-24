//+------------------------------------------------------------------+
//|                                                   Golden2_EA.mq5 |
//|                                    Copyright 2025, MoneyX Smart  |
//|     Golden2 EA v2.5 - One-Way Toward-Price Trail:               |
//|     pending BuyStop is dragged DOWN only when price falls away  |
//|     (target = ask + UpperPips below current pending). SellStop  |
//|     is dragged UP only when price rises away. Pending NEVER     |
//|     moves AWAY from price -> price approaching always triggers  |
//|     the order. Replaces v2.4 symmetric/recenter behaviour.      |
//+------------------------------------------------------------------+
#property copyright "MoneyX"
#property link      "https://moneyx.com"
#property version   "2.70"
#property description "Golden2 EA v2.70 - Continuous Frame Maintenance. Two-sided BuyStop/SellStop frame is kept ALIVE at all times: any side that becomes empty (no pending + no position) is immediately re-filled at Ask+InpFrameUpperPips / Bid-InpFrameLowerPips, with NO requirement for the opposite side to have a live position. Toward-price-only M1 trail (v2.5) and v2.3 hedge-active freeze retained. Re-arm/Re-entry/legacy-trail inputs deprecated (no-op, kept for .set file compatibility). Per-side cooldown + STOPS_LEVEL guards from v2.61 retained. Order execution, grid logic, hedging, Triple-Gate, Avg TP/SL, Accumulate, Squeeze — all untouched."
#property strict

#include <Trade/Trade.mqh>

CTrade trade;

//================ ENUMS ================
enum ENUM_SIDE { SIDE_BUY=0, SIDE_SELL=1 };

// [v1.7] Initial frame side mode
enum ENUM_INIT_SIDE_MODE
{
   INIT_BOTH      = 0, // Both sides (Buy Stop + Sell Stop)
   INIT_BUY_ONLY  = 1, // Buy Stop only
   INIT_SELL_ONLY = 2  // Sell Stop only
};

enum ENUM_HEDGE_DELAY_MODE_G2
{
   G2_HDELAY_AFTER_LAST_OPEN  = 0,
   G2_HDELAY_AFTER_LAST_CLOSE = 1,
   G2_HDELAY_BOTH             = 2
};

enum ENUM_SL_ACTION_G2
{
   SL_CLOSE_POSITIONS = 0   // Close Positions (Stop Loss)
};

// Gold-Miner style enums (G2 prefix to avoid clash)
enum ENUM_LOT_MODE_G2
{
   G2_LOT_CUSTOM   = 0,  // Custom Lots (semicolon list)
   G2_LOT_ADD      = 1,  // Add per level (Initial + level*Add*Initial)
   G2_LOT_MULTIPLY = 2   // Multiply per level (Initial * factor^level)
};

enum ENUM_GAP_TYPE_G2
{
   G2_GAP_FIXED  = 0,    // Fixed Points
   G2_GAP_CUSTOM = 1,    // Custom Distance (semicolon list)
   G2_GAP_ATR    = 2     // ATR-based
};

enum ENUM_ATR_REF_G2
{
   G2_ATR_REF_DYNAMIC   = 0,  // Current ATR
   G2_ATR_REF_LAST_GRID = 1   // ATR snapshot at last grid order
};

//================ INPUTS ================
//--- === General ===
input string  __sec_general__         = "=== General ===";          // ---
input long    InpMagic                = 22220001;                    // Magic number
input int     InpSlippage             = 30;                          // Slippage (points)
input bool    InpAllowTrade           = true;                        // Master allow trade
input bool    InpVerboseLog           = true;                        // Verbose log

//--- === Frame & Initial Order ===
input string  __sec_frame__           = "=== Frame & Initial Order ==="; // ---
input ENUM_INIT_SIDE_MODE InpInitSideMode = INIT_BOTH;                   // [v1.7] Initial side mode (Both/Buy/Sell)
input double  InpInitialLot           = 0.01;                            // Initial lot (G_IN)
input int     InpFrameUpperPips       = 200;                             // BUY_STOP distance from mid (points)
input int     InpFrameLowerPips       = 200;                             // SELL_STOP distance from mid (points)
input int     InpInitialTPPips        = 300;                             // Initial TP (points) (0=off)
input int     InpInitialSLPips        = 0;                               // Initial SL (points) (0=off)
input bool    InpInitTrailOpposite    = true;                            // [v2.70 DEPRECATED — no-op, kept for .set file compat]
input int     InpInitTrailTriggerPips = 200;                             // [v2.70 DEPRECATED — no-op]
input bool    InpInitReArmAfterTP     = true;                            // [v2.70 DEPRECATED — superseded by continuous frame maintenance (always ON)]
input int     InpInitReArmDistancePips= 200;                             // [v2.70 DEPRECATED — re-fill uses InpFrameUpperPips/LowerPips instead]
input bool    InpInitReEntryOnClose   = true;                            // [v2.70 DEPRECATED — superseded by continuous frame maintenance (always ON)]
input bool            InpInitTrailOnBarClose      = true;                  // [v2.70 DEPRECATED — bar-close trail always ON]
input ENUM_TIMEFRAMES InpInitTrailTF              = PERIOD_M1;             // [v1.8] Trail timer TF (default M1)
input bool            InpGL_ImmediateAfterInitial = true;                  // [v1.8] Fire GL#1 immediately after Initial fill (bypass candle guards on first GL)
input bool            InpFrameSymmetricTrail      = false;                 // [v2.70 DEPRECATED — toward-price-only trail always]
input int             InpFrameRecenterMinPips     = 50;                    // [v2.5] Min frame-distance growth (points) before dragging pending toward price

//--- === Grid Loss Side === (Gold Miner-style)
input string  __sec_grid_loss__       = "=== Grid Loss Side ===";    // ---
input bool           GridLoss_Enable          = true;                 // [v1.7] Enable Grid Loss (off = Initial only)
input int            GridLoss_MaxTrades       = 30;                  // Max Grid Loss Trades
input ENUM_LOT_MODE_G2 GridLoss_LotMode       = G2_LOT_MULTIPLY;     // Grid Loss Lot Mode
input string         GridLoss_CustomLots      = "0.01;0.01;0.01;0.01;0.01;0.01;0.01;0.01;0.01;0.01"; // Custom Lots (semicolon)
input double         GridLoss_AddLotPerLevel  = 0.4;                 // Add Lot per Level (× InitialLot)
input double         GridLoss_MultiplyFactor  = 1.4;                 // Multiply Factor (for Multiply mode)
input ENUM_GAP_TYPE_G2 GridLoss_GapType       = G2_GAP_FIXED;        // Grid Loss Gap Type
input int            GridLoss_Points          = 50;                  // Grid Loss Distance (points)
input string         GridLoss_CustomDistance  = "100;200;300;400;500;600;700;800;900;1000"; // Custom Distance (points, semicolon)
input ENUM_TIMEFRAMES GridLoss_ATR_TF         = PERIOD_H1;           // ATR Timeframe
input int            GridLoss_ATR_Period      = 14;                  // ATR Period
input double         GridLoss_ATR_Multiplier  = 2.0;                 // ATR Multiplier
input ENUM_ATR_REF_G2 GridLoss_ATR_Reference  = G2_ATR_REF_LAST_GRID;// ATR Reference Point
input int            GridLoss_MinGapPoints    = 50;                  // Minimum Grid Gap (points)
input int            GridLoss_CandleConfirm   = 1;                   // Require N confirming candles before GL (0=Off)
input bool           GridLoss_OnlyInSignal    = false;               // Grid Only in Signal (loss-side) Direction
input bool           GridLoss_OnlyNewCandle   = true;                // Grid Only on New Candle
input bool           GridLoss_DontSameCandle  = true;                // Don't Open Grid in Same Candle as Initial

//--- === Max Grid Average Trailing Stop ===
input string  __sec_maxgrid_trail__   = "=== Max Grid Average Trailing Stop ==="; // ---
input bool           MaxGrid_TrailEnable      = false;               // Enable Max Grid Avg Trailing
input int            MaxGrid_TrailMode        = 1;                   // Mode: 0=Max Order Grid, 1=Start Order Grid
input int            MaxGrid_StartOrders      = 8;                   // Start Trail at N orders (Mode 1)
input int            MaxGrid_TrailActivation  = 100;                 // Activation (points from average, 0=Off)
input int            MaxGrid_TrailStep        = 50;                  // Trailing Step (points)
input int            MaxGrid_BreakevenBuffer  = 10;                  // Breakeven Buffer (points above/below avg)

//--- === Grid Profit Side === (Gold Miner-style)
input string  __sec_grid_profit__     = "=== Grid Profit Side ===";  // ---
input bool           GridProfit_Enable        = false;               // Enable Profit Grid
input int            GridProfit_MaxTrades     = 2;                   // Max Grid Profit Trades
input ENUM_LOT_MODE_G2 GridProfit_LotMode     = G2_LOT_MULTIPLY;     // Grid Profit Lot Mode
input string         GridProfit_CustomLots    = "0.01;0.01;0.01;0.01;0.01"; // Custom Lots
input double         GridProfit_AddLotPerLevel= 0.2;                 // Add Lot per Level
input double         GridProfit_MultiplyFactor= 1.4;                 // Multiply Factor
input ENUM_GAP_TYPE_G2 GridProfit_GapType     = G2_GAP_FIXED;        // Grid Profit Gap Type
input int            GridProfit_Points        = 100;                 // Grid Profit Distance (points)
input string         GridProfit_CustomDistance= "100;200;500";       // Custom Distance
input ENUM_TIMEFRAMES GridProfit_ATR_TF       = PERIOD_H1;           // ATR Timeframe
input int            GridProfit_ATR_Period    = 14;                  // ATR Period
input double         GridProfit_ATR_Multiplier= 2.0;                 // ATR Multiplier
input ENUM_ATR_REF_G2 GridProfit_ATR_Reference= G2_ATR_REF_LAST_GRID;// ATR Reference Point
input int            GridProfit_MinGapPoints  = 100;                 // Minimum Grid Gap (points)
input bool           GridProfit_OnlyNewCandle = true;                // Grid Only on New Candle

// Legacy v1.1 inputs (kept for backward-compat / hedge stack & continuation)
input int     InpMaxGridLevels        = 4;                           // [Legacy] Max levels for hedge stack & continuation
input double  InpMultiplier           = 2.0;                         // [Legacy] Multiplier (used by hedge stack lot)
input int     InpGridStepPips         = 200;                         // [Legacy] Step used by hedge stack offset
input int     InpGridProfitTPPips     = 300;                         // [Legacy] Reserved

//--- === Group / Queue ===
input string  __sec_group__           = "=== Group / Queue ===";     // ---
input int     InpMaxGroups            = 50;                          // Max active groups (1..50)
input bool    InpSequentialQueue      = true;                        // Process one group at a time
input bool    InpGroup_RequireFullLockBeforeNext = true;             // [v2.0] Block next group until prior group is fully hedge-locked or empty
input bool    InpGroup_AdvancePerTick            = true;             // [v2.2] Retry group advance every tick (not only on hedge edge)

//--- === Take Profit (Average) ===
input string  __sec_tp__              = "=== Take Profit (Average) ==="; // ---
input bool    InpTP_UseFixedDollar    = false;                       // Use TP Fixed Dollar (per side)
input double  InpTP_DollarAmount      = 100.0;                       // TP Dollar Amount
input bool    InpTP_UsePointsFromAvg  = true;                        // Use TP in Points (from Average)
input int     InpTP_PointsFromAvg     = 1000;                        // TP Points from Average
input bool    InpTP_UsePctBalance     = false;                       // Use TP % of Balance
input double  InpTP_PctBalance        = 26.0;                        // TP % of Balance
input bool    InpTP_UseAccumulateClose= false;                       // Use Accumulate Close (group-wide)
input double  InpTP_AccumulateTarget  = 1000.0;                      // Accumulate Target ($)
input int     InpTP_AccumCooldownSec  = 30;                          // [v2.1] Accumulate cooldown after close (sec) — blocks re-trigger & new frames
input bool    InpTP_UsePctMaxDD       = false;                       // Use TP % of Max Drawdown (per side)
input double  InpTP_PctMaxDD          = 50.0;                        // TP DD % (target = X% of max DD)
input bool    InpTP_ShowAvgLine       = true;                        // Show Average Price Line
input bool    InpTP_ShowTPLine        = true;                        // Show TP Line
input int     InpTP_AvgLineWidth      = 3;                           // [v2.0] Average Line Width (pixels)
input color   InpTP_AvgBuyColor       = clrDodgerBlue;               // Average Buy Line Color
input color   InpTP_AvgSellColor      = clrOrangeRed;                // Average Sell Line Color
input color   InpTP_BuyLineColor      = clrLime;                     // TP Buy Line Color
input color   InpTP_SellLineColor     = clrMagenta;                  // TP Sell Line Color
input bool    InpTPAvg_AutoSyncToBroker = true;                      // [v1.3] Auto-sync Avg TP/SL to Broker (>=N orders)
input int     InpTPAvg_MinTicketsToActivate = 2;                     // [v1.3] Min tickets/side to switch from Initial TP to Avg TP

//--- === Stop Loss (Average) ===
input string  __sec_sl__              = "=== Stop Loss (Average) ==="; // ---
input bool    InpSL_Enable            = false;                       // Enable Stop Loss
input ENUM_SL_ACTION_G2 InpSL_ActionMode = SL_CLOSE_POSITIONS;       // SL Action Mode
input bool    InpSL_UseFixedDollar    = false;                       // Use SL Fixed Dollar (per side)
input double  InpSL_DollarAmount      = 50.0;                        // SL Dollar Amount
input bool    InpSL_UsePointsFromAvg  = false;                       // Use SL in Points (from Average)
input int     InpSL_PointsFromAvg     = 1000;                        // SL Points from Average
input bool    InpSL_UsePctBalance     = false;                       // Use SL % of Balance
input double  InpSL_PctBalance        = 3.0;                         // SL % of Balance
input bool    InpSL_ShowSLLine        = true;                        // Show SL Line
input color   InpSL_LineColor         = clrBlack;                    // SL Line Color

//--- === Hedging ===
input string  __sec_hedge__           = "=== Hedging ===";           // ---
input bool    InpHedge_Enabled        = true;                        // Enable Hedging system (master switch)
input double  InpHedgeTriggerUSD      = 1000.0;                      // Hedge trigger (USD floating loss target)
input double  InpHedge_BlockNewOrderPercent = 75.0;                  // Block new grid orders when DD% >= this (0=off)
input double  InpHedgeArmPercent      = 80.0;                        // Arm pending hedge when DD% reaches
input double  InpHedgeDisarmPercent   = 70.0;                        // Disarm pending hedge when DD% drops below
input bool    InpHedgeLotMatch1to1    = true;                        // Hedge lots match opposite side 1:1 (mirror tag+lot)
input int     InpHedge_OpenDelayMin   = 0;                           // Cooldown minutes between hedges (0=off)
input ENUM_HEDGE_DELAY_MODE_G2 InpHedge_OpenDelayMode = G2_HDELAY_BOTH; // Cooldown reference

//--- === Exit Triple Gate ===
input string  __sec_exit__            = "=== Exit Triple Gate ==="; // ---
input bool    InpExitTripleGate_Enable= true;                        // [v1.6] Enable Triple-Gate matching close
input bool    InpPostHedge_AllowContinuation = false;                // [v1.6] Allow continuation grid AFTER hedge activates (default OFF = freeze group)
input ENUM_TIMEFRAMES InpExitTF       = PERIOD_H4;                   // Higher TF for Expansion->Normal gate
input int     InpExitBBPeriod         = 20;                          // BB period
input double  InpExitBBDev            = 2.0;                         // BB deviation
input int     InpExitKeltnerATR       = 20;                          // Keltner ATR period
input double  InpExitKeltnerMult      = 1.5;                         // Keltner multiplier
input int     InpExitBreakoutPips     = 300;                         // Breakout distance from average (points)
input double  InpExitMinNetUSD        = 1.0;                         // Min net USD profit to allow exit

//--- === Volatility Squeeze Filter === [v1.6 ported from Gold Miner]
input string  __sec_sq__              = "=== Volatility Squeeze Filter ==="; // ---
input bool    InpSQ_Enable            = true;                        // Enable Squeeze Filter
input ENUM_TIMEFRAMES InpSQ_TF1       = PERIOD_M1;                   // Timeframe 1
input ENUM_TIMEFRAMES InpSQ_TF2       = PERIOD_M5;                   // Timeframe 2
input ENUM_TIMEFRAMES InpSQ_TF3       = PERIOD_M15;                  // Timeframe 3
input int     InpSQ_BBPeriod          = 15;                          // BB Period
input double  InpSQ_BBMult            = 2.0;                         // BB Multiplier
input int     InpSQ_KCPeriod          = 15;                          // KC Period (EMA)
input double  InpSQ_KCMult            = 1.5;                         // KC Multiplier (ATR)
input int     InpSQ_ATRPeriod         = 14;                          // ATR Period for KC
input double  InpSQ_ExpansionThreshold= 1.6;                         // Expansion Threshold (BBwidth/KCwidth)
input bool    InpSQ_BlockNewOrders    = true;                        // Block New Orders on Expansion
input int     InpSQ_MinExpansionTFs   = 1;                           // Min TFs in Expansion to Block (1-3)
input bool    InpSQ_DirectionalBlock  = true;                        // Directional Block (block counter-trend only)
input bool    InpSQ_CloseOnExpansion  = false;                       // Close All Orders on Expansion

//--- === Dashboard ===
input string  __sec_dash__            = "=== Dashboard ===";         // ---
input bool    InpShowDashboard        = true;                        // Show dashboard
input int     InpDashX                = 10;                          // Dashboard X (left panel)
input int     InpDashY                = 20;                          // Dashboard Y (left panel)
input int     InpDashLeftWidth        = 360;                         // Left panel width (px)
input int     InpDashHedgeGap         = 12;                          // Gap between left and right panels (px)
input color   InpDashColor            = clrWhite;                    // Dashboard text color (default)
input color   InpDashHeaderBg         = C'40,40,80';                 // Header background
input color   InpDashRowBg            = C'20,20,30';                 // Row background
input color   InpDashAccent           = clrGold;                     // Accent (titles, totals)
input color   InpDashGood             = clrLime;                     // Positive value color
input color   InpDashBad              = clrTomato;                   // Negative/warning color
input int     InpDashFontSize         = 9;                           // Font size
input string  InpDashFont             = "Consolas";                  // Font name (monospaced recommended)

//================ GLOBALS ================
double g_point;
double g_pipMul;       // 1.0 (using points directly)
int    g_digits;
int    g_activeOpsGroup = -1;       // mutex (-1 = idle)
datetime g_activeOpsClaimedAt = 0;

datetime g_lastHedgeOpenTime  = 0;
datetime g_lastHedgeCloseTime = 0;
datetime g_lastDelayLog       = 0;

string g_dashName    = "Golden2_DASH";   // legacy single-label (kept for cleanup)
string g_dashPrefix  = "G2DASH_";         // [v1.5] prefix for all dashboard label objects
string g_linePrefix  = "G2L_";            // chart line objects prefix

int g_bbHandle = INVALID_HANDLE;
int g_atrHandle = INVALID_HANDLE;
int g_atrLossHandle   = INVALID_HANDLE;
int g_atrProfitHandle = INVALID_HANDLE;

// [v1.6] Squeeze Filter handles per TF (3 timeframes)
int g_sqBB[3]      = {INVALID_HANDLE, INVALID_HANDLE, INVALID_HANDLE};
int g_sqKCEMA[3]   = {INVALID_HANDLE, INVALID_HANDLE, INVALID_HANDLE};
int g_sqATR[3]     = {INVALID_HANDLE, INVALID_HANDLE, INVALID_HANDLE};
ENUM_TIMEFRAMES g_sqTF[3];
// Cached squeeze state (refreshed each tick by RefreshSqueezeState)
bool   g_sqExpansion[3]   = {false,false,false}; // is TF in expansion
int    g_sqDir[3]         = {0,0,0};             // +1 up, -1 down, 0 none
int    g_sqExpCount       = 0;                    // # TFs currently in expansion
bool   g_sqBlockBuy       = false;
bool   g_sqBlockSell      = false;
double g_sqRatio[3]       = {0.0, 0.0, 0.0};      // [v1.8] BBwidth/KCwidth ratio per TF (for dashboard)
datetime g_lastTrailBar[51];                      // [v1.8] last bar time we ran bar-close trail (per group)

bool   g_stripped[51];          // per-group flag: broker TP/SL stripped after hedge match
double g_maxDDPerSide[51][2];   // [group][side] track max floating loss USD seen (positive value)
bool   g_blockNewOrders[51];    // per-group: pre-hedge block (DD% near arm threshold)
bool   g_hedgeMasterCleared = false; // one-shot cleanup when master toggle is OFF

// Snapshot of ATR (in points) at the moment last grid order was placed (per group, side, family 0=GL/1=GP)
double   g_atrAtLastGridLoss[51][2];
double   g_atrAtLastGridProfit[51][2];
// Track last "initial" candle time per group (for DontSameCandle guard)
datetime g_initialCandleTime[51][2];
// Track last grid placement candle (for OnlyNewCandle guard)
datetime g_lastGridCandleLoss[51][2];
datetime g_lastGridCandleProfit[51][2];

// Max Grid Avg Trailing virtual SL state (per group, side)
double   g_maxGridTrailSL[51][2];   // 0 = inactive
bool     g_maxGridTrailArmed[51][2];

// [v1.3] Track last avg-TP price synced to broker per (group, side); 0 = none synced (Initial-TP mode)
double   g_avgTPSynced[51][2];
double   g_avgSLSynced[51][2];

// [v2.0] Global Accumulate Close state (account-wide, sums realized + floating)
double   g_accumRealizedSinceReset = 0.0;
datetime g_accumResetTime          = 0;
bool     g_hadAnyOrderLastTick     = false;
double   g_accumNetCached          = 0.0;
double   g_accumFloatingCached     = 0.0;
// [v2.1] Cooldown after Accumulate Close fires — prevents re-trigger loop
//        while broker history still reports the just-realized profit, and
//        blocks PlaceInitialFrame so no new frame is opened mid-cooldown.
bool     g_accumJustTriggered      = false;
datetime g_accumTriggerTime        = 0;

//================ HELPERS: comments / parsing ================
string SidePrefix(ENUM_SIDE s){ return (s==SIDE_BUY?"B":"S"); }

string MakeComment(int g, bool hedge, string tag){
   string base = StringFormat("G%d_", g);
   if(hedge) base += "HD_";
   return base + tag;
}

bool ParseComment(string c, int &grp, bool &isHedge, string &tag){
   grp = -1; isHedge = false; tag = "";
   if(StringLen(c) < 4) return false;
   if(StringSubstr(c,0,1) != "G") return false;
   int us = StringFind(c, "_");
   if(us < 2) return false;
   string gnum = StringSubstr(c, 1, us-1);
   grp = (int)StringToInteger(gnum);
   string rest = StringSubstr(c, us+1);
   if(StringFind(rest,"HD_") == 0){
      isHedge = true;
      tag = StringSubstr(rest, 3);
   } else {
      isHedge = false;
      tag = rest;
   }
   return (grp >= 1);
}

//================ POSITION/ORDER SCAN ================
int CountGroupPositions(int g, int sideFilter, int hedgeFilter){
   int n = 0;
   int total = PositionsTotal();
   for(int i=0;i<total;i++){
      ulong tk = PositionGetTicket(i);
      if(tk==0) continue;
      if(!PositionSelectByTicket(tk)) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      string c = PositionGetString(POSITION_COMMENT);
      int gp; bool hd; string tag;
      if(!ParseComment(c, gp, hd, tag)) continue;
      if(gp != g) continue;
      int sd = (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?0:1;
      if(sideFilter != -1 && sideFilter != sd) continue;
      if(hedgeFilter != -1 && ((hedgeFilter==1) != hd)) continue;
      n++;
   }
   return n;
}

double GroupFloatingPL(int g, int sideFilter, int hedgeFilter){
   double s = 0.0;
   int total = PositionsTotal();
   for(int i=0;i<total;i++){
      ulong tk = PositionGetTicket(i);
      if(tk==0) continue;
      if(!PositionSelectByTicket(tk)) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      string c = PositionGetString(POSITION_COMMENT);
      int gp; bool hd; string tag;
      if(!ParseComment(c, gp, hd, tag)) continue;
      if(gp != g) continue;
      int sd = (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?0:1;
      if(sideFilter != -1 && sideFilter != sd) continue;
      if(hedgeFilter != -1 && ((hedgeFilter==1) != hd)) continue;
      s += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return s;
}

double GroupAveragePrice(int g, int sideFilter, int hedgeFilter){
   double sumLP = 0.0, sumL = 0.0;
   int total = PositionsTotal();
   for(int i=0;i<total;i++){
      ulong tk = PositionGetTicket(i);
      if(tk==0) continue;
      if(!PositionSelectByTicket(tk)) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      string c = PositionGetString(POSITION_COMMENT);
      int gp; bool hd; string tag;
      if(!ParseComment(c, gp, hd, tag)) continue;
      if(gp != g) continue;
      int sd = (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?0:1;
      if(sideFilter != -1 && sideFilter != sd) continue;
      if(hedgeFilter != -1 && ((hedgeFilter==1) != hd)) continue;
      double l = PositionGetDouble(POSITION_VOLUME);
      double p = PositionGetDouble(POSITION_PRICE_OPEN);
      sumLP += p*l; sumL += l;
   }
   if(sumL <= 0) return 0.0;
   return sumLP / sumL;
}

double GroupTotalLot(int g, int sideFilter, int hedgeFilter){
   double s = 0.0;
   int total = PositionsTotal();
   for(int i=0;i<total;i++){
      ulong tk = PositionGetTicket(i);
      if(tk==0) continue;
      if(!PositionSelectByTicket(tk)) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      string c = PositionGetString(POSITION_COMMENT);
      int gp; bool hd; string tag;
      if(!ParseComment(c, gp, hd, tag)) continue;
      if(gp != g) continue;
      int sd = (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?0:1;
      if(sideFilter != -1 && sideFilter != sd) continue;
      if(hedgeFilter != -1 && ((hedgeFilter==1) != hd)) continue;
      s += PositionGetDouble(POSITION_VOLUME);
   }
   return s;
}

int CountGroupPendingsByTagPrefix(int g, bool hedge, string tagPrefix){
   int n = 0;
   int total = OrdersTotal();
   for(int i=0;i<total;i++){
      ulong tk = OrderGetTicket(i);
      if(tk==0) continue;
      if(!OrderSelect(tk)) continue;
      if((long)OrderGetInteger(ORDER_MAGIC) != InpMagic) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      string c = OrderGetString(ORDER_COMMENT);
      int gp; bool hd; string tag;
      if(!ParseComment(c, gp, hd, tag)) continue;
      if(gp != g) continue;
      if(hd != hedge) continue;
      if(StringFind(tag, tagPrefix) != 0) continue;
      n++;
   }
   return n;
}

void DeleteGroupPendings(int g, int hedgeFilter){
   int total = OrdersTotal();
   for(int i=total-1;i>=0;i--){
      ulong tk = OrderGetTicket(i);
      if(tk==0) continue;
      if(!OrderSelect(tk)) continue;
      if((long)OrderGetInteger(ORDER_MAGIC) != InpMagic) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      string c = OrderGetString(ORDER_COMMENT);
      int gp; bool hd; string tag;
      if(!ParseComment(c, gp, hd, tag)) continue;
      if(gp != g) continue;
      if(hedgeFilter != -1 && ((hedgeFilter==1) != hd)) continue;
      trade.OrderDelete(tk);
   }
}

bool GroupHasAnyPositions(int g){ return CountGroupPositions(g,-1,-1) > 0; }
bool GroupHasAnyPendings(int g){
   int total = OrdersTotal();
   for(int i=0;i<total;i++){
      ulong tk = OrderGetTicket(i);
      if(tk==0) continue;
      if(!OrderSelect(tk)) continue;
      if((long)OrderGetInteger(ORDER_MAGIC) != InpMagic) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      string c = OrderGetString(ORDER_COMMENT);
      int gp; bool hd; string tag;
      if(!ParseComment(c, gp, hd, tag)) continue;
      if(gp == g) return true;
   }
   return false;
}

//================ HEDGE COOLDOWN ================
bool IsHedgeOpenDelayActive(int &remainSec){
   remainSec = 0;
   if(InpHedge_OpenDelayMin <= 0) return false;
   datetime ref = 0;
   if(InpHedge_OpenDelayMode == G2_HDELAY_AFTER_LAST_OPEN)  ref = g_lastHedgeOpenTime;
   else if(InpHedge_OpenDelayMode == G2_HDELAY_AFTER_LAST_CLOSE) ref = g_lastHedgeCloseTime;
   else { ref = (datetime)MathMax((long)g_lastHedgeOpenTime, (long)g_lastHedgeCloseTime); }
   if(ref == 0) return false;
   long elapsed = (long)TimeCurrent() - (long)ref;
   long need    = (long)InpHedge_OpenDelayMin * 60;
   if(elapsed >= need) return false;
   remainSec = (int)(need - elapsed);
   return true;
}

//================ EXPANSION->NORMAL GATE ================
bool IsExpansionToNormal(){
   double bbU[3], bbL[3], bbM[3], atr[3];
   if(g_bbHandle == INVALID_HANDLE || g_atrHandle == INVALID_HANDLE) return false;
   if(CopyBuffer(g_bbHandle, 1, 0, 3, bbU) <= 0) return false;
   if(CopyBuffer(g_bbHandle, 2, 0, 3, bbL) <= 0) return false;
   if(CopyBuffer(g_bbHandle, 0, 0, 3, bbM) <= 0) return false;
   if(CopyBuffer(g_atrHandle, 0, 0, 3, atr) <= 0) return false;
   double bbW1 = bbU[1] - bbL[1];
   double bbW2 = bbU[2] - bbL[2];
   double keW1 = 2.0 * InpExitKeltnerMult * atr[1];
   double keW2 = 2.0 * InpExitKeltnerMult * atr[2];
   bool wasExpansion = (bbW2 > keW2);
   bool nowNormal    = (bbW1 <= keW1);
   return (wasExpansion && nowNormal);
}

//================ [v1.6] VOLATILITY SQUEEZE FILTER ================
// Per TF: BBwidth/KCwidth on closed bar (shift=1). Expansion when ratio >= threshold.
// Direction = sign(close - BBmid) on shift=1.
bool ComputeSqueezeForTF(int idx, bool &isExp, int &dir){
   isExp = false; dir = 0;
   if(g_sqBB[idx] == INVALID_HANDLE || g_sqKCEMA[idx] == INVALID_HANDLE || g_sqATR[idx] == INVALID_HANDLE) return false;
   double bbU[3], bbL[3], bbM[3], ema[3], atr[3];
   if(CopyBuffer(g_sqBB[idx],   1, 0, 3, bbU) <= 0) return false;
   if(CopyBuffer(g_sqBB[idx],   2, 0, 3, bbL) <= 0) return false;
   if(CopyBuffer(g_sqBB[idx],   0, 0, 3, bbM) <= 0) return false;
   if(CopyBuffer(g_sqKCEMA[idx],0, 0, 3, ema) <= 0) return false;
   if(CopyBuffer(g_sqATR[idx],  0, 0, 3, atr) <= 0) return false;
   double bbW = bbU[1] - bbL[1];
   double kcW = 2.0 * InpSQ_KCMult * atr[1];
   if(kcW <= 0) return false;
   double ratio = bbW / kcW;
   g_sqRatio[idx] = ratio; // [v1.8] expose for dashboard
   isExp = (ratio >= InpSQ_ExpansionThreshold);
   double cl = iClose(_Symbol, g_sqTF[idx], 1);
   if(cl > bbM[1]) dir = +1;
   else if(cl < bbM[1]) dir = -1;
   else dir = 0;
   return true;
}

void RefreshSqueezeState(){
   g_sqExpCount = 0;
   g_sqBlockBuy = false;
   g_sqBlockSell = false;
   if(!InpSQ_Enable) return;
   int upCnt=0, dnCnt=0;
   for(int i=0;i<3;i++){
      bool e=false; int d=0;
      ComputeSqueezeForTF(i, e, d);
      g_sqExpansion[i] = e;
      g_sqDir[i] = d;
      if(e){
         g_sqExpCount++;
         if(d>0) upCnt++;
         else if(d<0) dnCnt++;
      }
   }
   if(InpSQ_BlockNewOrders && g_sqExpCount >= InpSQ_MinExpansionTFs){
      if(InpSQ_DirectionalBlock){
         // Expansion-up (price above BB mid breaking up) → block SELL (counter-trend)
         // Expansion-down → block BUY
         if(upCnt > 0) g_sqBlockSell = true;
         if(dnCnt > 0) g_sqBlockBuy  = true;
      } else {
         g_sqBlockBuy = true;
         g_sqBlockSell = true;
      }
   }
}

bool SqueezeBlocksSide(int side){
   if(!InpSQ_Enable || !InpSQ_BlockNewOrders) return false;
   if(side == 0) return g_sqBlockBuy;
   if(side == 1) return g_sqBlockSell;
   return false;
}

bool SqueezeBlocksAny(){
   return SqueezeBlocksSide(0) || SqueezeBlocksSide(1);
}

string SqueezeStatusString(){
   if(!InpSQ_Enable) return "OFF";
   string tfs[3] = {"TF1","TF2","TF3"};
   string s = StringFormat("E:%d", g_sqExpCount);
   for(int i=0;i<3;i++){
      if(g_sqExpansion[i]){
         s += StringFormat(" %s%s", tfs[i], (g_sqDir[i]>0?"^":(g_sqDir[i]<0?"v":"-")));
      }
   }
   if(g_sqBlockBuy)  s += " BLK_BUY";
   if(g_sqBlockSell) s += " BLK_SELL";
   return s;
}

// [v1.8] Gold-Miner-style helpers for multi-row Squeeze panel
string SqueezeTFLabel(int i){
   ENUM_TIMEFRAMES tf = g_sqTF[i];
   switch(tf){
      case PERIOD_M1:  return "M1";
      case PERIOD_M5:  return "M5";
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
   }
   return EnumToString(tf);
}
string SqueezeStateLabel(int i){
   if(!g_sqExpansion[i]) return "NORMAL";
   if(g_sqDir[i] > 0) return "EXPANSION BUY";
   if(g_sqDir[i] < 0) return "EXPANSION SELL";
   return "EXPANSION";
}
string SqueezeBarString(double ratio){
   double thr = (InpSQ_ExpansionThreshold>0)? InpSQ_ExpansionThreshold : 1.0;
   int fill = (int)MathFloor(ratio / thr * 10.0);
   if(fill < 0) fill = 0;
   if(fill > 10) fill = 10;
   string bar = "|";
   for(int k=0; k<fill; k++) bar += "#";
   for(int k=fill; k<10; k++) bar += ".";
   bar += "|";
   return bar;
}
string SqueezeOverallLabel(){
   if(!InpSQ_Enable) return "OFF";
   if(g_sqBlockBuy && g_sqBlockSell) return "BOTH BLOCKED";
   if(g_sqBlockBuy)  return "BUY BLOCKED";
   if(g_sqBlockSell) return "SELL BLOCKED";
   return "READY";
}


bool ClaimMutex(int g){
   if(!InpSequentialQueue) return true;
   if(g_activeOpsGroup == -1){
      g_activeOpsGroup = g;
      g_activeOpsClaimedAt = TimeCurrent();
      return true;
   }
   return (g_activeOpsGroup == g);
}
void ReleaseMutex(int g){
   if(!InpSequentialQueue) return;
   if(g_activeOpsGroup == g){
      g_activeOpsGroup = -1;
      g_activeOpsClaimedAt = 0;
   }
}

//================ INITIAL FRAME (per group) ================
int FindLowestIdleGroup(){
   for(int g=1; g<=InpMaxGroups; g++){
      if(!GroupHasAnyPositions(g) && !GroupHasAnyPendings(g)) return g;
   }
   return -1;
}

int FindActiveTradingGroup(){
   for(int g=InpMaxGroups; g>=1; g--){
      if(GroupHasAnyPositions(g) || GroupHasAnyPendings(g)) return g;
   }
   return -1;
}

void PlaceInitialFrame(int g){
   // [v2.1] Accumulate cooldown guard — after CloseEverythingNow() fires, do
   //        NOT open a new frame until the cooldown elapses AND the cycle has
   //        truly reset (handled in ManageGlobalAccumulateClose). This breaks
   //        the per-tick close→reopen→close loop seen when broker history is
   //        slow to reflect the just-realized profit.
   if(g_accumJustTriggered){
      if(InpVerboseLog) PrintFormat("Golden2 v2.1: PlaceInitialFrame G%d skipped (accum cooldown active)", g);
      return;
   }
   // [v1.6] Squeeze block: don't place initial frame on volatile expansion
   if(InpSQ_Enable && InpSQ_BlockNewOrders && g_sqExpCount >= InpSQ_MinExpansionTFs && SqueezeBlocksAny()){
      if(InpVerboseLog) PrintFormat("Golden2 v2.1: Squeeze BLOCK initial G%d (%s)", g, SqueezeStatusString());
      return;
   }

   // [v2.6.1] Validate side mode and pre-compute place flags BEFORE any work or
   //          log spam. If the enum value is corrupted (e.g. .set file overrode
   //          to a non-enum value like 5000), fall back to INIT_BOTH so the EA
   //          never silently sits idle.
   int sideMode = (int)InpInitSideMode;
   if(sideMode != (int)INIT_BOTH && sideMode != (int)INIT_BUY_ONLY && sideMode != (int)INIT_SELL_ONLY){
      static datetime lastBadModeWarn = 0;
      if(TimeCurrent() - lastBadModeWarn >= 60){
         PrintFormat("Golden2 v2.6.1: INVALID InpInitSideMode=%d — falling back to INIT_BOTH (0). Check inputs/.set file.", sideMode);
         lastBadModeWarn = TimeCurrent();
      }
      sideMode = (int)INIT_BOTH;
   }
   bool placeBuy  = (sideMode == (int)INIT_BOTH || sideMode == (int)INIT_BUY_ONLY);
   bool placeSell = (sideMode == (int)INIT_BOTH || sideMode == (int)INIT_SELL_ONLY);
   if(!placeBuy && !placeSell){
      static datetime lastNoSideWarn = 0;
      if(TimeCurrent() - lastNoSideWarn >= 60){
         PrintFormat("Golden2 v2.6.1: PlaceInitialFrame G%d skipped — no side enabled (mode=%d)", g, sideMode);
         lastNoSideWarn = TimeCurrent();
      }
      return;
   }

   // [v2.6.1] Per-group cooldown to stop per-tick re-fire when the previous
   //          attempt failed (e.g. invalid stops, off-quotes, market closed).
   //          Without this, FindLowestIdleGroup keeps returning g and we spam
   //          OrderSend every tick.
   static datetime s_lastAttempt[51];
   static datetime s_lastFailLog[51];
   int gi = (g >= 0 && g < 51) ? g : 0;
   if(s_lastAttempt[gi] != 0 && TimeCurrent() - s_lastAttempt[gi] < 5){
      return; // 5s cooldown between attempts
   }
   s_lastAttempt[gi] = TimeCurrent();

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0 || bid <= 0){
      if(InpVerboseLog) PrintFormat("Golden2 v2.6.1: PlaceInitialFrame G%d skipped — no quotes (ask=%.5f bid=%.5f)", g, ask, bid);
      return;
   }
   double mid = (ask+bid)*0.5;
   double upPx = NormalizeDouble(mid + InpFrameUpperPips * g_point, g_digits);
   double dnPx = NormalizeDouble(mid - InpFrameLowerPips * g_point, g_digits);

   // [v2.0] Honour broker stops level when computing initial TP/SL.
   long stopsLvl = (long)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist = (stopsLvl > 0) ? stopsLvl * g_point : 0.0;

   // [v2.6.1] Reject pending price that violates broker minimum stop distance
   //          (BuyStop must be >= ask + minDist, SellStop must be <= bid - minDist).
   //          Also catches the case where InpFrameUpperPips/InpFrameLowerPips are
   //          set to zero or below stops level.
   if(placeBuy && (upPx - ask) < minDist + g_point){
      if(TimeCurrent() - s_lastFailLog[gi] >= 60){
         PrintFormat("Golden2 v2.6.1: BuyStop G%d distance %.*f below stops level %.*f (FrameUpperPips=%d) — skipping",
                     g, g_digits, upPx-ask, g_digits, minDist, InpFrameUpperPips);
         s_lastFailLog[gi] = TimeCurrent();
      }
      placeBuy = false;
   }
   if(placeSell && (bid - dnPx) < minDist + g_point){
      if(TimeCurrent() - s_lastFailLog[gi] >= 60){
         PrintFormat("Golden2 v2.6.1: SellStop G%d distance %.*f below stops level %.*f (FrameLowerPips=%d) — skipping",
                     g, g_digits, bid-dnPx, g_digits, minDist, InpFrameLowerPips);
         s_lastFailLog[gi] = TimeCurrent();
      }
      placeSell = false;
   }
   if(!placeBuy && !placeSell) return;

   double tpUp = 0.0, slUp = 0.0, tpDn = 0.0, slDn = 0.0;
   if(InpInitialTPPips > 0){
      double tpDistUp = MathMax(InpInitialTPPips * g_point, minDist + g_point);
      tpUp = NormalizeDouble(upPx + tpDistUp, g_digits);
      double tpDistDn = MathMax(InpInitialTPPips * g_point, minDist + g_point);
      tpDn = NormalizeDouble(dnPx - tpDistDn, g_digits);
   }
   if(InpInitialSLPips > 0){
      double slDistUp = MathMax(InpInitialSLPips * g_point, minDist + g_point);
      slUp = NormalizeDouble(upPx - slDistUp, g_digits);
      double slDistDn = MathMax(InpInitialSLPips * g_point, minDist + g_point);
      slDn = NormalizeDouble(dnPx + slDistDn, g_digits);
   }

   // [v2.0] Sanity guards — never let TP land at/under entry for BUY (or above entry for SELL).
   if(tpUp > 0 && tpUp <= upPx){ PrintFormat("Golden2 v2.0: invalid BuyStop TP %.*f<=%.*f, force 0", g_digits, tpUp, g_digits, upPx); tpUp = 0; }
   if(slUp > 0 && slUp >= upPx){ PrintFormat("Golden2 v2.0: invalid BuyStop SL %.*f>=%.*f, force 0", g_digits, slUp, g_digits, upPx); slUp = 0; }
   if(tpDn > 0 && tpDn >= dnPx){ PrintFormat("Golden2 v2.0: invalid SellStop TP %.*f>=%.*f, force 0", g_digits, tpDn, g_digits, dnPx); tpDn = 0; }
   if(slDn > 0 && slDn <= dnPx){ PrintFormat("Golden2 v2.0: invalid SellStop SL %.*f>=%.*f, force 0", g_digits, slDn, g_digits, dnPx); slDn = 0; }

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippage);

   string cBuy  = MakeComment(g, false, "IN");
   string cSell = MakeComment(g, false, "IN");

   bool anySent = false;
   if(placeBuy){
      if(!trade.BuyStop(InpInitialLot, upPx, _Symbol, slUp, tpUp, ORDER_TIME_GTC, 0, cBuy)){
         PrintFormat("Golden2 v2.6.1: BuyStop FAIL G%d err=%d retcode=%d open=%.*f tp=%.*f sl=%.*f",
                     g, GetLastError(), trade.ResultRetcode(), g_digits, upPx, g_digits, tpUp, g_digits, slUp);
      } else {
         anySent = true;
         if(InpVerboseLog)
            PrintFormat("Golden2 v2.6.1: BuyStop G%d open=%.*f tp=%.*f sl=%.*f", g, g_digits, upPx, g_digits, tpUp, g_digits, slUp);
      }
   }
   if(placeSell){
      if(!trade.SellStop(InpInitialLot, dnPx, _Symbol, slDn, tpDn, ORDER_TIME_GTC, 0, cSell)){
         PrintFormat("Golden2 v2.6.1: SellStop FAIL G%d err=%d retcode=%d open=%.*f tp=%.*f sl=%.*f",
                     g, GetLastError(), trade.ResultRetcode(), g_digits, dnPx, g_digits, tpDn, g_digits, slDn);
      } else {
         anySent = true;
         if(InpVerboseLog)
            PrintFormat("Golden2 v2.6.1: SellStop G%d open=%.*f tp=%.*f sl=%.*f", g, g_digits, dnPx, g_digits, tpDn, g_digits, slDn);
      }
   }
   if(!anySent){
      // Both attempts failed — extend cooldown to 30s so we don't spam.
      s_lastAttempt[gi] = TimeCurrent() + 25;
      return;
   }
   if(InpVerboseLog)
      PrintFormat("Golden2 v2.6.1: Placed initial frame G%d mode=%d mid=%.5f up=%s dn=%s",
                  g, sideMode, mid,
                  placeBuy?DoubleToString(upPx,g_digits):"-",
                  placeSell?DoubleToString(dnPx,g_digits):"-");
}

// [v1.7] EnforceFrameMutualExclusion: only delete the opposite-side IN pending in
//        single-side modes (Buy-only / Sell-only). In BOTH mode we KEEP the
//        opposite stop alive so the user gets a real two-side hedge frame.
void EnforceFrameMutualExclusion(int g){
   if(InpInitSideMode == INIT_BOTH) return; // keep both pendings live
   bool hasBuyPos  = (CountGroupPositions(g, 0, 0) > 0);
   bool hasSellPos = (CountGroupPositions(g, 1, 0) > 0);
   if(!hasBuyPos && !hasSellPos) return;
   int total = OrdersTotal();
   for(int i=total-1;i>=0;i--){
      ulong tk = OrderGetTicket(i);
      if(tk==0) continue;
      if(!OrderSelect(tk)) continue;
      if((long)OrderGetInteger(ORDER_MAGIC) != InpMagic) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      string c = OrderGetString(ORDER_COMMENT);
      int gp; bool hd; string tag;
      if(!ParseComment(c, gp, hd, tag)) continue;
      if(gp != g) continue;
      if(hd) continue;
      if(tag != "IN") continue;
      ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      bool isBuyPending  = (ot==ORDER_TYPE_BUY_STOP || ot==ORDER_TYPE_BUY_LIMIT);
      bool isSellPending = (ot==ORDER_TYPE_SELL_STOP|| ot==ORDER_TYPE_SELL_LIMIT);
      if(hasBuyPos && isSellPending) trade.OrderDelete(tk);
      if(hasSellPos && isBuyPending) trade.OrderDelete(tk);
   }
}

// [v1.7] Find the IN pending ticket for a given side (Buy=0/Sell=1). Returns 0 if none.
ulong FindInitialPendingTicket(int g, int side){
   int total = OrdersTotal();
   for(int i=0;i<total;i++){
      ulong tk = OrderGetTicket(i);
      if(tk==0) continue;
      if(!OrderSelect(tk)) continue;
      if((long)OrderGetInteger(ORDER_MAGIC) != InpMagic) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      string c = OrderGetString(ORDER_COMMENT);
      int gp; bool hd; string tag;
      if(!ParseComment(c, gp, hd, tag)) continue;
      if(gp != g || hd || tag != "IN") continue;
      ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
      if(side==0 && (ot==ORDER_TYPE_BUY_STOP || ot==ORDER_TYPE_BUY_LIMIT)) return tk;
      if(side==1 && (ot==ORDER_TYPE_SELL_STOP|| ot==ORDER_TYPE_SELL_LIMIT)) return tk;
   }
   return 0;
}

// [v2.5] Bar-close trail: ONE-WAY toward-price only.
//        BuyStop pending sits ABOVE market. We drag it DOWN (closer to price)
//        only when ask falls so frame distance grew beyond InpFrameUpperPips.
//        We NEVER move BuyStop UP (away from price) — if price approaches,
//        the pending stays put so it can trigger as designed.
//        SellStop pending sits BELOW market — symmetric: drag UP only.
void ManageInitialTrailOnBarClose(int g){
   if(!InpInitTrailOnBarClose) return;
   // [v2.3] Freeze initial-frame trail as soon as ANY hedge position exists
   //         for this group (don't wait for a fully matched set). Prevents
   //         post-hedge IN trail/re-arm from creating orphan main positions
   //         that would block group advancement.
   if(CountGroupPositions(g, -1, 1) > 0) return;
   if(IsGroupHedgeMatched(g)) return;
   if(g_blockNewOrders[g]) return;

   datetime curBar = iTime(_Symbol, InpInitTrailTF, 0);
   if(curBar == 0) return;
   if(g_lastTrailBar[g] == curBar) return;
   g_lastTrailBar[g] = curBar;

   if(!GroupHasAnyPositions(g) && !GroupHasAnyPendings(g)) return;

   ulong tBuy  = FindInitialPendingTicket(g, 0);
   ulong tSell = FindInitialPendingTicket(g, 1);
   int buyPos  = CountGroupPositions(g, 0, 0);
   int sellPos = CountGroupPositions(g, 1, 0);

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // [v2.5] Threshold guards micro modifications. Only drag toward price when
   //        the frame distance has grown by more than this many points.
   double minStep = MathMax(InpFrameRecenterMinPips, 1) * g_point;

   // ---- BUY pending (BuyStop sits ABOVE market) ----
   if(tBuy != 0 && buyPos == 0 && (sellPos > 0 || tSell != 0)){
      if(OrderSelect(tBuy)){
         double oldPx = OrderGetDouble(ORDER_PRICE_OPEN);
         double oldTP = OrderGetDouble(ORDER_TP);
         double oldSL = OrderGetDouble(ORDER_SL);
         // Target = the "ideal" frame distance above current ask.
         double targetPx = NormalizeDouble(ask + InpFrameUpperPips * g_point, g_digits);
         // Drag DOWN (toward price) ONLY when target is meaningfully BELOW current pending.
         // = ask has fallen, frame distance grew → pull BuyStop down.
         // If targetPx >= oldPx → price approaching or stable → DO NOT MOVE (stay put to be triggered).
         if(targetPx < oldPx - minStep){
            double newPx = targetPx;
            // [v2.2] Preserve TP/SL: shift by entry delta when InitialTP is on, else forward verbatim.
            double tp, sl;
            if(InpInitialTPPips > 0){
               tp = (oldTP > 0) ? NormalizeDouble(oldTP + (newPx - oldPx), g_digits) : 0;
            } else {
               tp = oldTP;
            }
            if(InpInitialSLPips > 0){
               sl = (oldSL > 0) ? NormalizeDouble(oldSL + (newPx - oldPx), g_digits) : 0;
            } else {
               sl = oldSL;
            }
            if(trade.OrderModify(tBuy, newPx, sl, tp, ORDER_TIME_GTC, 0)){
               if(InpVerboseLog) PrintFormat("Golden2 v2.5: TrailIn BuyStop G%d %.5f -> %.5f ask=%.5f tp=%.5f sl=%.5f",
                                             g, oldPx, newPx, ask, tp, sl);
            } else {
               PrintFormat("Golden2 v2.5: BuyStop modify FAIL G%d err=%d", g, GetLastError());
            }
         }
      }
   }

   // ---- SELL pending (SellStop sits BELOW market) ----
   if(tSell != 0 && sellPos == 0 && (buyPos > 0 || tBuy != 0)){
      if(OrderSelect(tSell)){
         double oldPx = OrderGetDouble(ORDER_PRICE_OPEN);
         double oldTP = OrderGetDouble(ORDER_TP);
         double oldSL = OrderGetDouble(ORDER_SL);
         double targetPx = NormalizeDouble(bid - InpFrameLowerPips * g_point, g_digits);
         // Drag UP (toward price) ONLY when target is meaningfully ABOVE current pending.
         // = bid has risen, frame distance grew → pull SellStop up.
         // If targetPx <= oldPx → price approaching or stable → DO NOT MOVE.
         if(targetPx > oldPx + minStep){
            double newPx = targetPx;
            double tp, sl;
            if(InpInitialTPPips > 0){
               tp = (oldTP > 0) ? NormalizeDouble(oldTP + (newPx - oldPx), g_digits) : 0;
            } else {
               tp = oldTP;
            }
            if(InpInitialSLPips > 0){
               sl = (oldSL > 0) ? NormalizeDouble(oldSL + (newPx - oldPx), g_digits) : 0;
            } else {
               sl = oldSL;
            }
            if(trade.OrderModify(tSell, newPx, sl, tp, ORDER_TIME_GTC, 0)){
               if(InpVerboseLog) PrintFormat("Golden2 v2.5: TrailIn SellStop G%d %.5f -> %.5f bid=%.5f tp=%.5f sl=%.5f",
                                             g, oldPx, newPx, bid, tp, sl);
            } else {
               PrintFormat("Golden2 v2.5: SellStop modify FAIL G%d err=%d", g, GetLastError());
            }
         }
      }
   }
}

// [v1.7] Auto-trail opposite IN stop while no position has filled yet.
//        If price runs UP by > InpInitTrailTriggerPips beyond mid (i.e. closer to
//        BuyStop), the SellStop is moved UP to keep it InpFrameLowerPips below market.
//        Symmetric for downward moves. Only operates while BOTH IN pendings exist.
void ManageInitialTrail(int g){
   if(InpInitTrailOnBarClose) return; // [v1.8] superseded by bar-close trail
   if(!InpInitTrailOpposite) return;
   if(InpInitSideMode != INIT_BOTH) return; // need both stops
   if(CountGroupPositions(g,-1,0) > 0) return; // a side already filled
   // [v2.3] Same hedge-active freeze as bar-close trail.
   if(CountGroupPositions(g, -1, 1) > 0) return;
   if(IsGroupHedgeMatched(g)) return;

   ulong tBuy  = FindInitialPendingTicket(g, 0);
   ulong tSell = FindInitialPendingTicket(g, 1);
   if(tBuy==0 || tSell==0) return; // need both alive to trail

   if(!OrderSelect(tBuy)) return;
   double buyPx  = OrderGetDouble(ORDER_PRICE_OPEN);
   if(!OrderSelect(tSell)) return;
   double sellPx = OrderGetDouble(ORDER_PRICE_OPEN);

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double trigger = InpInitTrailTriggerPips * g_point;

   // Price moving UP toward Buy stop → drag Sell stop up
   double distBuy = buyPx - ask;     // points until BuyStop trips
   if(distBuy < InpFrameUpperPips*g_point - trigger){
      double newSellPx = NormalizeDouble(bid - InpFrameLowerPips*g_point, g_digits);
      if(newSellPx > sellPx + g_point){
         if(!OrderSelect(tSell)) return;
         double sl = OrderGetDouble(ORDER_SL);
         double tp = (InpInitialTPPips>0)? NormalizeDouble(newSellPx - InpInitialTPPips*g_point, g_digits) : 0;
         double newSL = (InpInitialSLPips>0)? NormalizeDouble(newSellPx + InpInitialSLPips*g_point, g_digits) : sl;
         if(trade.OrderModify(tSell, newSellPx, newSL, tp, ORDER_TIME_GTC, 0)){
            if(InpVerboseLog) PrintFormat("Golden2 v1.7: Trail SellStop G%d %.5f -> %.5f", g, sellPx, newSellPx);
         }
      }
   }
   // Price moving DOWN toward Sell stop → drag Buy stop down
   double distSell = bid - sellPx;
   if(distSell < InpFrameLowerPips*g_point - trigger){
      double newBuyPx = NormalizeDouble(ask + InpFrameUpperPips*g_point, g_digits);
      if(newBuyPx < buyPx - g_point){
         if(!OrderSelect(tBuy)) return;
         double sl = OrderGetDouble(ORDER_SL);
         double tp = (InpInitialTPPips>0)? NormalizeDouble(newBuyPx + InpInitialTPPips*g_point, g_digits) : 0;
         double newSL = (InpInitialSLPips>0)? NormalizeDouble(newBuyPx - InpInitialSLPips*g_point, g_digits) : sl;
         if(trade.OrderModify(tBuy, newBuyPx, newSL, tp, ORDER_TIME_GTC, 0)){
            if(InpVerboseLog) PrintFormat("Golden2 v1.7: Trail BuyStop G%d %.5f -> %.5f", g, buyPx, newBuyPx);
         }
      }
   }
}

// [v1.7] Re-arm a fresh IN stop on a side after that side empties (TP hit) while
//        the OPPOSITE side still has open positions. New stop is placed at
//        current market ± InpInitReArmDistancePips. Side mode is respected.
// [v2.6] Returns true if there is at least one CLOSED deal in history for this
// group + side (main, non-hedge), meaning the initial pending was triggered and
// later closed (TP/SL/manual). Used as the gate for Re-entry-on-Close so we do
// not place a re-entry pending before the very first initial fill.
bool HasClosedMainOnSide(int g, int side){
   if(!HistorySelect(g_accumResetTime>0 ? g_accumResetTime : (TimeCurrent()-7*24*3600), TimeCurrent()))
      return false;
   int total = HistoryDealsTotal();
   for(int i=total-1;i>=0;i--){
      ulong tk = HistoryDealGetTicket(i);
      if(tk==0) continue;
      if((long)HistoryDealGetInteger(tk, DEAL_MAGIC) != InpMagic) continue;
      if(HistoryDealGetString(tk, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(tk, DEAL_ENTRY) != DEAL_ENTRY_OUT) continue;
      string c = HistoryDealGetString(tk, DEAL_COMMENT);
      // Broker may rewrite comment on TP/SL; fall back to position comment lookup.
      int gp; bool hd; string tag;
      bool parsed = ParseComment(c, gp, hd, tag);
      if(!parsed){
         ulong posId = HistoryDealGetInteger(tk, DEAL_POSITION_ID);
         if(posId>0 && HistorySelectByPosition(posId)){
            int dn = HistoryDealsTotal();
            for(int j=0;j<dn;j++){
               ulong dtk = HistoryDealGetTicket(j);
               if(dtk==0) continue;
               if(HistoryDealGetInteger(dtk, DEAL_ENTRY) != DEAL_ENTRY_IN) continue;
               string ic = HistoryDealGetString(dtk, DEAL_COMMENT);
               if(ParseComment(ic, gp, hd, tag)){ parsed = true; break; }
            }
            HistorySelect(g_accumResetTime>0 ? g_accumResetTime : (TimeCurrent()-7*24*3600), TimeCurrent());
         }
      }
      if(!parsed) continue;
      if(gp != g) continue;
      if(hd) continue;
      long dealType = HistoryDealGetInteger(tk, DEAL_TYPE);
      // On exit: deal type is opposite of position side. BUY position → SELL deal to close.
      int posSide = (dealType == DEAL_TYPE_SELL) ? 0 : 1;
      if(posSide != side) continue;
      return true;
   }
   return false;
}

void ManageInitialReArm(int g){
   if(!InpInitReArmAfterTP && !InpInitReEntryOnClose) return;
   // [v2.3] Do not re-arm a fresh G_IN stop once the group is hedging — that
   //         was the source of the post-hedge orphan main that blocked
   //         advancement to the next group.
   if(CountGroupPositions(g, -1, 1) > 0) return;
   if(IsGroupHedgeMatched(g)) return;
   if(g_blockNewOrders[g]) return;

   bool buyAllowed  = (InpInitSideMode == INIT_BOTH || InpInitSideMode == INIT_BUY_ONLY);
   bool sellAllowed = (InpInitSideMode == INIT_BOTH || InpInitSideMode == INIT_SELL_ONLY);

   int buyPos  = CountGroupPositions(g, 0, 0);
   int sellPos = CountGroupPositions(g, 1, 0);
   ulong tBuyPend  = FindInitialPendingTicket(g, 0);
   ulong tSellPend = FindInitialPendingTicket(g, 1);

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double dist = InpInitReArmDistancePips * g_point;

   // [v2.6] Re-entry trigger condition for BUY side:
   //   - v1.7 path: opposite (sell) has open position (original re-arm)
   //   - v2.6 path: this side previously closed (TP/SL) in this group → re-enter
   //                regardless of what the opposite side currently is.
   bool buyTrigger  = (sellPos > 0) ||
                      (InpInitReEntryOnClose && HasClosedMainOnSide(g, 0));
   bool sellTrigger = (buyPos  > 0) ||
                      (InpInitReEntryOnClose && HasClosedMainOnSide(g, 1));

   // Re-arm BUY: side empty + pending missing + trigger condition met
   if(buyAllowed && buyPos==0 && tBuyPend==0 && buyTrigger){
      double upPx = NormalizeDouble(ask + dist, g_digits);
      double tp   = (InpInitialTPPips>0)? NormalizeDouble(upPx + InpInitialTPPips*g_point, g_digits) : 0;
      double sl   = (InpInitialSLPips>0)? NormalizeDouble(upPx - InpInitialSLPips*g_point, g_digits) : 0;
      string c    = MakeComment(g, false, "IN");
      if(trade.BuyStop(InpInitialLot, upPx, _Symbol, sl, tp, ORDER_TIME_GTC, 0, c)){
         if(InpVerboseLog) PrintFormat("Golden2 v2.6: Re-entry BuyStop G%d at %.5f (sellPos=%d)", g, upPx, sellPos);
      }
   }
   // Re-arm SELL: side empty + pending missing + trigger condition met
   if(sellAllowed && sellPos==0 && tSellPend==0 && sellTrigger){
      double dnPx = NormalizeDouble(bid - dist, g_digits);
      double tp   = (InpInitialTPPips>0)? NormalizeDouble(dnPx - InpInitialTPPips*g_point, g_digits) : 0;
      double sl   = (InpInitialSLPips>0)? NormalizeDouble(dnPx + InpInitialSLPips*g_point, g_digits) : 0;
      string c    = MakeComment(g, false, "IN");
      if(trade.SellStop(InpInitialLot, dnPx, _Symbol, sl, tp, ORDER_TIME_GTC, 0, c)){
         if(InpVerboseLog) PrintFormat("Golden2 v2.6: Re-entry SellStop G%d at %.5f (buyPos=%d)", g, dnPx, buyPos);
      }
   }
}

//================ MAIN GRID ================
// Legacy lot ladder (used by hedge stack & continuation logic — DO NOT TOUCH)
double LotForLevel(int level){
   double l = InpInitialLot;
   for(int i=0;i<level;i++) l *= InpMultiplier;
   double minL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step>0) l = MathRound(l/step)*step;
   if(l<minL) l = minL;
   return NormalizeDouble(l, 2);
}

//----- Gold-Miner-style helpers -----
// Parse semicolon-separated double list; returns fallback when index missing
double ParseCSVDouble(const string s, int idx, double fallback){
   string parts[];
   int n = StringSplit(s, ';', parts);
   if(idx < 0 || idx >= n) return fallback;
   string v = parts[idx];
   StringTrimLeft(v); StringTrimRight(v);
   if(StringLen(v) == 0) return fallback;
   return StringToDouble(v);
}
int ParseCSVInt(const string s, int idx, int fallback){
   double d = ParseCSVDouble(s, idx, (double)fallback);
   return (int)d;
}

double NormalizeLot(double l){
   double minL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step>0) l = MathRound(l/step)*step;
   if(l<minL) l = minL;
   if(maxL>0 && l>maxL) l = maxL;
   return NormalizeDouble(l, 2);
}

// Resolve lot for a given grid level (level=1..MaxTrades) with the chosen mode
double ResolveLot(int level, ENUM_LOT_MODE_G2 mode, const string customStr,
                  double addPerLvl, double mulFactor){
   double l = InpInitialLot;
   if(mode == G2_LOT_CUSTOM){
      l = ParseCSVDouble(customStr, level-1, InpInitialLot);
   } else if(mode == G2_LOT_ADD){
      l = InpInitialLot + (double)level * addPerLvl * InpInitialLot;
   } else { // MULTIPLY
      l = InpInitialLot * MathPow(mulFactor, (double)level);
   }
   return NormalizeLot(l);
}

double GetATRPoints(int handle){
   if(handle == INVALID_HANDLE) return 0.0;
   double buf[2];
   if(CopyBuffer(handle, 0, 0, 2, buf) <= 0) return 0.0;
   if(buf[0] <= 0) return 0.0;
   return buf[0] / g_point; // ATR in points
}

// Resolve gap in points for next grid level
int ResolveGapPoints(int level, ENUM_GAP_TYPE_G2 gapType, int fixedPts,
                     const string customStr, int atrHandle, double atrMult,
                     ENUM_ATR_REF_G2 atrRef, double atrSnapshotPts, int minGap){
   int gap = fixedPts;
   if(gapType == G2_GAP_FIXED){
      gap = fixedPts;
   } else if(gapType == G2_GAP_CUSTOM){
      gap = ParseCSVInt(customStr, level-1, fixedPts);
   } else { // ATR
      double atrPts = (atrRef == G2_ATR_REF_LAST_GRID && atrSnapshotPts>0)
                       ? atrSnapshotPts
                       : GetATRPoints(atrHandle);
      gap = (int)(atrPts * atrMult);
   }
   if(gap < minGap) gap = minGap;
   return gap;
}

int HighestGridLevel(int g, ENUM_SIDE side, bool hedge, string family){
   int best = 0;
   int total = PositionsTotal();
   for(int i=0;i<total;i++){
      ulong tk = PositionGetTicket(i);
      if(tk==0) continue;
      if(!PositionSelectByTicket(tk)) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      string c = PositionGetString(POSITION_COMMENT);
      int gp; bool hd; string tag;
      if(!ParseComment(c, gp, hd, tag)) continue;
      if(gp != g || hd != hedge) continue;
      int sd = (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?0:1;
      if(sd != (int)side) continue;
      int hashPos = StringFind(tag, "#");
      if(hashPos < 0) continue;
      string fam = StringSubstr(tag, 0, hashPos);
      if(fam != family) continue;
      int n = (int)StringToInteger(StringSubstr(tag, hashPos+1));
      if(n>best) best = n;
   }
   return best;
}

double LastEntryPrice(int g, int sideFilter, bool hedge){
   datetime newest = 0;
   double price = 0.0;
   int total = PositionsTotal();
   for(int i=0;i<total;i++){
      ulong tk = PositionGetTicket(i);
      if(tk==0) continue;
      if(!PositionSelectByTicket(tk)) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      string c = PositionGetString(POSITION_COMMENT);
      int gp; bool hd; string tag;
      if(!ParseComment(c, gp, hd, tag)) continue;
      if(gp != g) continue;
      if(hd != hedge) continue;
      int sd = (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?0:1;
      if(sd != sideFilter) continue;
      datetime t = (datetime)PositionGetInteger(POSITION_TIME);
      if(t > newest){ newest = t; price = PositionGetDouble(POSITION_PRICE_OPEN); }
   }
   return price;
}

datetime LastEntryCandleTime(int g, int sideFilter, bool hedge, ENUM_TIMEFRAMES tf){
   double px;
   datetime newest = 0;
   int total = PositionsTotal();
   for(int i=0;i<total;i++){
      ulong tk = PositionGetTicket(i);
      if(tk==0) continue;
      if(!PositionSelectByTicket(tk)) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      string c = PositionGetString(POSITION_COMMENT);
      int gp; bool hd; string tag;
      if(!ParseComment(c, gp, hd, tag)) continue;
      if(gp != g) continue;
      if(hd != hedge) continue;
      int sd = (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?0:1;
      if(sd != sideFilter) continue;
      datetime t = (datetime)PositionGetInteger(POSITION_TIME);
      if(t > newest) newest = t;
   }
   if(newest == 0) return 0;
   return iTime(_Symbol, tf, iBarShift(_Symbol, tf, newest));
}

// Count consecutive recent CLOSED candles in given direction (1=bull, -1=bear)
int CountConfirmingCandles(int dir, int n){
   int found = 0;
   for(int i=1; i<=n; i++){
      double o = iOpen(_Symbol, PERIOD_CURRENT, i);
      double c = iClose(_Symbol, PERIOD_CURRENT, i);
      if(dir > 0){ if(c >  o) found++; else break; }
      else       { if(c <  o) found++; else break; }
   }
   return found;
}

void TryPlaceGridLoss(int g){
   if(!GridLoss_Enable) return; // [v1.7] Master toggle: disable grid → Initial-only mode
   if(g_blockNewOrders[g]) return; // [v1.4] Pre-hedge block
   if(IsGroupHedgeMatched(g)) return; // [v1.6] Post-hedge lock: freeze grid until Triple-Gate close
   for(int sd=0; sd<2; sd++){
      if(SqueezeBlocksSide(sd)) continue; // [v1.6] Squeeze directional block
      int posCount = CountGroupPositions(g, sd, 0);
      if(posCount <= 0) continue;

      int gl = HighestGridLevel(g, (ENUM_SIDE)sd, false, "GL");
      if(gl >= GridLoss_MaxTrades) continue;

      // OnlyInSignal → only grid the loss-side
      if(GridLoss_OnlyInSignal){
         int loseSide = GroupLossSide(g);
         if(loseSide != -1 && loseSide != sd) continue;
      }

      double lastPrice = LastEntryPrice(g, sd, false);
      if(lastPrice <= 0) continue;

      // Resolve gap
      int gapPts = ResolveGapPoints(gl+1, GridLoss_GapType, GridLoss_Points,
                                    GridLoss_CustomDistance, g_atrLossHandle,
                                    GridLoss_ATR_Multiplier, GridLoss_ATR_Reference,
                                    g_atrAtLastGridLoss[g][sd], GridLoss_MinGapPoints);

      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      bool trigger = false;
      if(sd==0) trigger = (ask <= lastPrice - gapPts*g_point);
      else      trigger = (bid >= lastPrice + gapPts*g_point);
      if(!trigger) continue;

      // [v1.8] Bypass candle guards on GL#1 right after Initial fill (immediate trigger)
      bool bypassGuards = (InpGL_ImmediateAfterInitial && gl == 0);

      // OnlyNewCandle / DontSameCandle guards
      // [v1.9] OnlyNewCandle now waits for the last grid/initial bar to FULLY CLOSE
      //        Previous logic only blocked re-fire within the same open bar, so a
      //        trigger on the very first tick of the next bar still fired (too fast).
      //        Now we require iTime(...,1) (last CLOSED bar) > stored bar — guarantees
      //        at least one completed candle between consecutive grid orders.
      datetime curBar      = iTime(_Symbol, PERIOD_CURRENT, 0);
      datetime lastClosed  = iTime(_Symbol, PERIOD_CURRENT, 1);
      if(!bypassGuards && GridLoss_OnlyNewCandle && g_lastGridCandleLoss[g][sd] != 0
         && lastClosed <= g_lastGridCandleLoss[g][sd]) continue;
      if(!bypassGuards && GridLoss_DontSameCandle && g_initialCandleTime[g][sd] != 0
         && lastClosed < g_initialCandleTime[g][sd]) continue;

      // Candle confirmation (N consecutive closed candles in the loss direction)
      if(!bypassGuards && GridLoss_CandleConfirm > 0){
         int dir = (sd==0) ? -1 : +1; // BUY losing → bears, SELL losing → bulls
         if(CountConfirmingCandles(dir, GridLoss_CandleConfirm) < GridLoss_CandleConfirm) continue;
      }

      double lot = ResolveLot(gl+1, GridLoss_LotMode, GridLoss_CustomLots,
                              GridLoss_AddLotPerLevel, GridLoss_MultiplyFactor);
      string c = MakeComment(g, false, StringFormat("GL#%d", gl+1));
      bool ok = (sd==0) ? trade.Buy(lot, _Symbol, ask, 0, 0, c)
                        : trade.Sell(lot, _Symbol, bid, 0, 0, c);
      if(ok){
         g_lastGridCandleLoss[g][sd] = curBar;
         g_atrAtLastGridLoss[g][sd]  = GetATRPoints(g_atrLossHandle);
      }
      if(InpVerboseLog) PrintFormat("Golden2 v1.2: GL#%d %s G%d lot=%.2f gap=%dpts ok=%d",
                                    gl+1, sd==0?"BUY":"SELL", g, lot, gapPts, ok);
   }
}

void TryPlaceGridProfit(int g){
   if(!GridProfit_Enable) return;
   if(g_blockNewOrders[g]) return; // [v1.4] Pre-hedge block
   if(IsGroupHedgeMatched(g)) return; // pre-hedge only
   for(int sd=0; sd<2; sd++){
      if(SqueezeBlocksSide(sd)) continue; // [v1.6] Squeeze directional block
      int posCount = CountGroupPositions(g, sd, 0);
      if(posCount <= 0) continue;
      double pl = GroupFloatingPL(g, sd, 0);
      if(pl <= 0) continue; // only winning side

      int gp = HighestGridLevel(g, (ENUM_SIDE)sd, false, "GP");
      if(gp >= GridProfit_MaxTrades) continue;

      double lastPrice = LastEntryPrice(g, sd, false);
      if(lastPrice <= 0) continue;

      int gapPts = ResolveGapPoints(gp+1, GridProfit_GapType, GridProfit_Points,
                                    GridProfit_CustomDistance, g_atrProfitHandle,
                                    GridProfit_ATR_Multiplier, GridProfit_ATR_Reference,
                                    g_atrAtLastGridProfit[g][sd], GridProfit_MinGapPoints);

      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      bool trigger = false;
      // Profit grid: BUY → price went UP from lastPrice; SELL → price went DOWN
      if(sd==0) trigger = (ask >= lastPrice + gapPts*g_point);
      else      trigger = (bid <= lastPrice - gapPts*g_point);
      if(!trigger) continue;

      // [v1.9] OnlyNewCandle: require at least one fully-closed bar since last GP
      datetime curBar     = iTime(_Symbol, PERIOD_CURRENT, 0);
      datetime lastClosed = iTime(_Symbol, PERIOD_CURRENT, 1);
      if(GridProfit_OnlyNewCandle && g_lastGridCandleProfit[g][sd] != 0
         && lastClosed <= g_lastGridCandleProfit[g][sd]) continue;

      double lot = ResolveLot(gp+1, GridProfit_LotMode, GridProfit_CustomLots,
                              GridProfit_AddLotPerLevel, GridProfit_MultiplyFactor);
      string c = MakeComment(g, false, StringFormat("GP#%d", gp+1));
      bool ok = (sd==0) ? trade.Buy(lot, _Symbol, ask, 0, 0, c)
                        : trade.Sell(lot, _Symbol, bid, 0, 0, c);
      if(ok){
         g_lastGridCandleProfit[g][sd] = curBar;
         g_atrAtLastGridProfit[g][sd]  = GetATRPoints(g_atrProfitHandle);
      }
      if(InpVerboseLog) PrintFormat("Golden2 v1.2: GP#%d %s G%d lot=%.2f gap=%dpts ok=%d",
                                    gp+1, sd==0?"BUY":"SELL", g, lot, gapPts, ok);
   }
}

//================ MAX GRID AVERAGE TRAILING STOP ================
void ManageMaxGridTrailing(int g){
   if(!MaxGrid_TrailEnable) return;
   if(IsGroupHedgeMatched(g)) return; // only pre-hedge
   if(MaxGrid_TrailActivation <= 0) return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   for(int sd=0; sd<2; sd++){
      int cnt = CountGroupPositions(g, sd, 0);
      if(cnt <= 0){
         g_maxGridTrailSL[g][sd] = 0;
         g_maxGridTrailArmed[g][sd] = false;
         continue;
      }
      // Activation gate per mode
      bool gateOk = false;
      if(MaxGrid_TrailMode == 0){
         gateOk = (cnt >= GridLoss_MaxTrades); // require maxed out
      } else {
         gateOk = (cnt >= MaxGrid_StartOrders);
      }
      if(!gateOk){
         g_maxGridTrailSL[g][sd] = 0;
         g_maxGridTrailArmed[g][sd] = false;
         continue;
      }
      double avg = GroupAveragePrice(g, sd, 0);
      if(avg <= 0) continue;

      double price = (sd==0) ? bid : ask;
      double moveFromAvg = (sd==0) ? (price - avg) : (avg - price);
      double activation = MaxGrid_TrailActivation * g_point;
      double buffer     = MaxGrid_BreakevenBuffer * g_point;
      double step       = MaxGrid_TrailStep * g_point;

      if(moveFromAvg < activation) continue;

      double desiredSL;
      if(sd==0) desiredSL = NormalizeDouble(price - step, g_digits);
      else      desiredSL = NormalizeDouble(price + step, g_digits);

      // never below avg+buffer (BUY) / above avg-buffer (SELL)
      double floorSL = (sd==0) ? (avg + buffer) : (avg - buffer);
      if(sd==0 && desiredSL < floorSL) desiredSL = floorSL;
      if(sd==1 && desiredSL > floorSL) desiredSL = floorSL;

      // Move only in profit direction
      double curSL = g_maxGridTrailSL[g][sd];
      bool update = false;
      if(curSL <= 0) update = true;
      else if(sd==0 && desiredSL > curSL) update = true;
      else if(sd==1 && desiredSL < curSL) update = true;

      if(update){
         g_maxGridTrailSL[g][sd] = desiredSL;
         g_maxGridTrailArmed[g][sd] = true;
         if(InpVerboseLog) PrintFormat("Golden2 v1.2: MaxGridTrail G%d %s virtSL=%.5f (avg=%.5f)",
                                       g, sd==0?"BUY":"SELL", desiredSL, avg);
      }

      // Trigger check (virtual SL)
      bool hit = false;
      if(sd==0 && bid <= g_maxGridTrailSL[g][sd]) hit = true;
      if(sd==1 && ask >= g_maxGridTrailSL[g][sd]) hit = true;
      if(hit && g_maxGridTrailArmed[g][sd]){
         if(InpVerboseLog) PrintFormat("Golden2 v1.2: MaxGridTrail G%d %s HIT virtSL=%.5f -> close side",
                                       g, sd==0?"BUY":"SELL", g_maxGridTrailSL[g][sd]);
         CloseMainSideOfGroup(g, sd);
         g_maxGridTrailSL[g][sd] = 0;
         g_maxGridTrailArmed[g][sd] = false;
      }
   }
}

//================ HEDGING (per group) ================
int GroupLossSide(int g){
   double pBuy  = GroupFloatingPL(g, 0, 0);
   double pSell = GroupFloatingPL(g, 1, 0);
   if(pBuy < 0 && pSell >= 0) return 0;
   if(pSell < 0 && pBuy >= 0) return 1;
   if(pBuy < 0 && pSell < 0) return (pBuy < pSell ? 0 : 1);
   return -1;
}

// Return anchor price for hedge pending set (just beyond market on hedge side)
double HedgePendingAnchorPrice(int hedgeSide){
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double offsetPts = MathMax(50, InpGridStepPips/4);
   if(hedgeSide==1) return NormalizeDouble(bid - offsetPts*g_point, g_digits);
   else             return NormalizeDouble(ask + offsetPts*g_point, g_digits);
}

// Check if a pending hedge with comment exists (exact match)
bool HasPendingByComment(string targetComment){
   int total = OrdersTotal();
   for(int i=0;i<total;i++){
      ulong tk = OrderGetTicket(i);
      if(tk==0) continue;
      if(!OrderSelect(tk)) continue;
      if((long)OrderGetInteger(ORDER_MAGIC) != InpMagic) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(OrderGetString(ORDER_COMMENT) == targetComment) return true;
   }
   return false;
}

// Mirror loss-side positions to hedge-side pending stops (1:1 lot+tag).
// Adds missing pendings, removes pendings whose source loss tag no longer exists.
void MirrorLossSideToHedgePendings(int g, int lossSide){
   int hedgeSide = (lossSide==0)?1:0;
   double anchor = HedgePendingAnchorPrice(hedgeSide);

   // Build set of current loss-side tags (e.g. "IN", "GL#1", "GL#7", "GP#2") with their lots
   string  lossTags[];
   double  lossLots[];
   int total = PositionsTotal();
   for(int i=0;i<total;i++){
      ulong tk = PositionGetTicket(i);
      if(tk==0) continue;
      if(!PositionSelectByTicket(tk)) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      string c = PositionGetString(POSITION_COMMENT);
      int gp; bool hd; string tag;
      if(!ParseComment(c, gp, hd, tag)) continue;
      if(gp != g || hd) continue;
      int sd = (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?0:1;
      if(sd != lossSide) continue;
      int n = ArraySize(lossTags);
      ArrayResize(lossTags, n+1);
      ArrayResize(lossLots, n+1);
      lossTags[n] = tag;
      lossLots[n] = PositionGetDouble(POSITION_VOLUME);
   }

   // 1) Remove orphan hedge pendings (tag not in loss set)
   int ot = OrdersTotal();
   for(int i=ot-1;i>=0;i--){
      ulong tk = OrderGetTicket(i);
      if(tk==0) continue;
      if(!OrderSelect(tk)) continue;
      if((long)OrderGetInteger(ORDER_MAGIC) != InpMagic) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      string c = OrderGetString(ORDER_COMMENT);
      int gp; bool hd; string tag;
      if(!ParseComment(c, gp, hd, tag)) continue;
      if(gp != g || !hd) continue;
      bool keep = false;
      for(int k=0;k<ArraySize(lossTags);k++){
         if(lossTags[k] == tag){ keep = true; break; }
      }
      if(!keep){
         trade.OrderDelete(tk);
         if(InpVerboseLog) PrintFormat("Golden2 v1.4: HD trim G%d %s (loss tag gone)", g, c);
      }
   }

   // 2) Add missing hedge pendings for each loss tag
   for(int k=0;k<ArraySize(lossTags);k++){
      string newC = MakeComment(g, true, lossTags[k]);
      if(HasPendingByComment(newC)) continue;
      double lot = lossLots[k];
      bool ok;
      if(hedgeSide==1) ok = trade.SellStop(lot, anchor, _Symbol, 0, 0, ORDER_TIME_GTC, 0, newC);
      else             ok = trade.BuyStop (lot, anchor, _Symbol, 0, 0, ORDER_TIME_GTC, 0, newC);
      if(InpVerboseLog) PrintFormat("Golden2 v1.4: HD mirror G%d %s lot=%.2f price=%.5f comment=%s ok=%d",
         g, hedgeSide==1?"SELL_STOP":"BUY_STOP", lot, anchor, newC, ok);
   }
}

// Legacy fallback (used only when InpHedgeLotMatch1to1==false)
void PlaceHedgePendingSet_Legacy(int g, int lossSide){
   int hedgeSide = (lossSide==0)?1:0;
   double price = HedgePendingAnchorPrice(hedgeSide);
   double lotIN = InpInitialLot;
   string c = MakeComment(g, true, "IN");
   bool ok;
   if(hedgeSide==1) ok = trade.SellStop(lotIN, price, _Symbol, 0, 0, ORDER_TIME_GTC, 0, c);
   else             ok = trade.BuyStop (lotIN, price, _Symbol, 0, 0, ORDER_TIME_GTC, 0, c);
   if(InpVerboseLog) PrintFormat("Golden2 v1.4: HD_IN(legacy) G%d %s lot=%.2f price=%.5f ok=%d",
      g, hedgeSide==1?"SELL_STOP":"BUY_STOP", lotIN, price, ok);
   int oppMaxLvl = HighestGridLevel(g, (ENUM_SIDE)lossSide, false, "GL");
   for(int lvl=1; lvl<=oppMaxLvl; lvl++){
      double lot = LotForLevel(lvl);
      string cg = MakeComment(g, true, StringFormat("GL#%d", lvl));
      bool ok2;
      double pStack = price + ((hedgeSide==1?-1:1) * lvl * 1 * g_point);
      pStack = NormalizeDouble(pStack, g_digits);
      if(hedgeSide==1) ok2 = trade.SellStop(lot, pStack, _Symbol, 0, 0, ORDER_TIME_GTC, 0, cg);
      else             ok2 = trade.BuyStop (lot, pStack, _Symbol, 0, 0, ORDER_TIME_GTC, 0, cg);
      if(InpVerboseLog) PrintFormat("Golden2 v1.4: HD_GL#%d(legacy) G%d lot=%.2f price=%.5f ok=%d", lvl, g, lot, pStack, ok2);
   }
}

void PlaceHedgePendingSet(int g, int lossSide){
   if(InpHedgeLotMatch1to1) MirrorLossSideToHedgePendings(g, lossSide);
   else                     PlaceHedgePendingSet_Legacy(g, lossSide);
   g_lastHedgeOpenTime = TimeCurrent();
}

void ManageGroupHedgeArm(int g){
   // Master toggle OFF: one-shot cleanup of any pending hedges, then bail
   if(!InpHedge_Enabled){
      if(!g_hedgeMasterCleared){
         for(int gi=1; gi<=InpMaxGroups; gi++) DeleteGroupPendings(gi, 1);
         g_hedgeMasterCleared = true;
         if(InpVerboseLog) Print("Golden2 v1.4: HEDGE MASTER OFF - cleared all pending hedges");
      }
      g_blockNewOrders[g] = false;
      return;
   }
   g_hedgeMasterCleared = false;

   bool hedgePosExists = (CountGroupPositions(g,-1,1) > 0);
   bool hedgePendingExists = (CountGroupPendingsByTagPrefix(g, true, "") > 0);

   double lossUSD = -MathMin(GroupFloatingPL(g,0,0), GroupFloatingPL(g,1,0));
   if(lossUSD < 0) lossUSD = 0;
   double pct = (InpHedgeTriggerUSD>0) ? (lossUSD * 100.0 / InpHedgeTriggerUSD) : 0.0;

   // Pre-hedge block-new-orders flag (hysteresis 5%); only meaningful pre-match
   if(!hedgePosExists && InpHedge_BlockNewOrderPercent > 0){
      if(pct >= InpHedge_BlockNewOrderPercent)               g_blockNewOrders[g] = true;
      else if(pct < InpHedge_BlockNewOrderPercent - 5.0)     g_blockNewOrders[g] = false;
   } else {
      g_blockNewOrders[g] = false;
   }

   // [v1.6] Disarm: drop pending if DD recovers, no loss side, or no main positions exist
   if(!hedgePosExists && hedgePendingExists){
      int lossSideNow = GroupLossSide(g);
      bool noMainPos  = (CountGroupPositions(g,-1,0) == 0);
      bool ddRecovered= (pct < InpHedgeDisarmPercent);
      bool noLossSide = (lossSideNow < 0);
      if(ddRecovered || noLossSide || noMainPos){
         DeleteGroupPendings(g, 1);
         g_blockNewOrders[g] = false;
         if(InpVerboseLog) PrintFormat("Golden2 v1.6: HD DISARM G%d pct=%.1f reason=%s",
            g, pct, ddRecovered?"recover":(noMainPos?"noMain":"noLossSide"));
         return;
      }
      // Already armed: dynamically top-up / trim mirror to match current loss-side tickets
      if(lossSideNow >= 0 && InpHedgeLotMatch1to1){
         MirrorLossSideToHedgePendings(g, lossSideNow);
      }
      return;
   }
   if(hedgePosExists) return;

   if(pct >= InpHedgeArmPercent){
      int rem = 0;
      if(IsHedgeOpenDelayActive(rem)){
         if(TimeCurrent() - g_lastDelayLog >= 60){
            PrintFormat("Golden2 v1.4: HEDGE DELAY wait %dm%02ds before arming new hedge", rem/60, rem%60);
            g_lastDelayLog = TimeCurrent();
         }
         return;
      }
      int lossSide = GroupLossSide(g);
      if(lossSide < 0) return;
      if(!ClaimMutex(g)) return;
      PlaceHedgePendingSet(g, lossSide);
      ReleaseMutex(g);
   }
}

bool GroupHedgeJustActivated(int g){
   return (CountGroupPositions(g, -1, 1) > 0);
}

// Group has a "matched" hedge set: both main and hedge positions exist
bool IsGroupHedgeMatched(int g){
   return (CountGroupPositions(g,-1,0) > 0 && CountGroupPositions(g,-1,1) > 0);
}

//================ AUTO-STRIP BROKER TP/SL ON HEDGE MATCH ================
// When main + hedge coexist for a group, immediately remove broker TP/SL on
// every position of that group so that subsequent close logic (Average TP/SL
// or Triple-Gate Matching Close) can take over without the broker pre-empting.
void StripBrokerTPSL_OnHedgeMatch(int g){
   int total = PositionsTotal();
   int modified = 0;
   for(int i=0;i<total;i++){
      ulong tk = PositionGetTicket(i);
      if(tk==0) continue;
      if(!PositionSelectByTicket(tk)) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      string c = PositionGetString(POSITION_COMMENT);
      int gp; bool hd; string tag;
      if(!ParseComment(c, gp, hd, tag)) continue;
      if(gp != g) continue;
      double curTP = PositionGetDouble(POSITION_TP);
      double curSL = PositionGetDouble(POSITION_SL);
      if(curTP == 0.0 && curSL == 0.0) continue;
      if(trade.PositionModify(tk, 0.0, 0.0)){
         modified++;
      } else {
         PrintFormat("Golden2 v1.1: StripTPSL fail G%d ticket=%I64u err=%d",
                     g, tk, GetLastError());
      }
   }
   g_stripped[g] = true;
   if(InpVerboseLog && modified>0)
      PrintFormat("Golden2 v1.1: G%d hedge MATCHED -> stripped broker TP/SL on %d position(s). Awaiting Avg TP/SL or Triple-Gate.", g, modified);
}

//================ AVERAGE TP/SL MANAGER (per side, before hedge matched) ================
// Tracks max DD per (group, side) for "% of Max DD" mode
void UpdateMaxDDPerSide(int g){
   for(int sd=0; sd<2; sd++){
      double pl = GroupFloatingPL(g, sd, 0); // main side only
      double loss = (pl < 0) ? -pl : 0.0;
      if(loss > g_maxDDPerSide[g][sd]) g_maxDDPerSide[g][sd] = loss;
   }
}

void ResetMaxDDPerSide(int g){
   g_maxDDPerSide[g][0] = 0.0;
   g_maxDDPerSide[g][1] = 0.0;
}

double ComputeAvgTPPrice(int g, int side){
   double avg = GroupAveragePrice(g, side, 0);
   if(avg <= 0) return 0.0;
   double off = InpTP_PointsFromAvg * g_point;
   return NormalizeDouble((side==0) ? (avg + off) : (avg - off), g_digits);
}

double ComputeAvgSLPrice(int g, int side){
   double avg = GroupAveragePrice(g, side, 0);
   if(avg <= 0) return 0.0;
   double off = InpSL_PointsFromAvg * g_point;
   return NormalizeDouble((side==0) ? (avg - off) : (avg + off), g_digits);
}

//================ [v1.3] AVG TP/SL → BROKER SYNC (Gold-Miner style) ================
// Logic per (group, side, hedge=false):
//   count == 1 ticket  → keep Initial TP that PlaceInitialFrame set; if previously
//                        synced to avg, restore Initial TP recomputed from entry.
//   count >= MinTickets→ compute Avg TP price (and optional Avg SL price) and
//                        push the SAME tp/sl onto every broker ticket on that side.
// Skips groups where hedge already matched (g_stripped takes over).

double InitialTPPriceForTicket(ulong tk){
   if(InpInitialTPPips <= 0) return 0.0;
   if(!PositionSelectByTicket(tk)) return 0.0;
   double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   bool isBuy   = (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
   double off   = InpInitialTPPips * g_point;
   return NormalizeDouble(isBuy ? (entry+off) : (entry-off), g_digits);
}
double InitialSLPriceForTicket(ulong tk){
   if(InpInitialSLPips <= 0) return 0.0;
   if(!PositionSelectByTicket(tk)) return 0.0;
   double entry = PositionGetDouble(POSITION_PRICE_OPEN);
   bool isBuy   = (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY);
   double off   = InpInitialSLPips * g_point;
   return NormalizeDouble(isBuy ? (entry-off) : (entry+off), g_digits);
}

bool ModifyIfDifferent(ulong tk, double newSL, double newTP){
   if(!PositionSelectByTicket(tk)) return false;
   double curTP = PositionGetDouble(POSITION_TP);
   double curSL = PositionGetDouble(POSITION_SL);
   double tol   = g_point; // 1 point tolerance
   if(MathAbs(curTP-newTP) <= tol && MathAbs(curSL-newSL) <= tol) return true;
   if(!trade.PositionModify(tk, newSL, newTP)){
      if(InpVerboseLog)
         PrintFormat("Golden2 v1.3: PositionModify fail tk=%I64u sl=%.5f tp=%.5f err=%d",
                     tk, newSL, newTP, GetLastError());
      return false;
   }
   return true;
}

void SyncSideTPSLToBroker(int g, int side){
   if(!InpTPAvg_AutoSyncToBroker) return;
   if(g_stripped[g]) return;                        // hedge already matched
   if(IsGroupHedgeMatched(g)) return;
   int cnt = CountGroupPositions(g, side, 0);
   if(cnt <= 0){
      g_avgTPSynced[g][side] = 0; g_avgSLSynced[g][side] = 0;
      return;
   }

   if(cnt < InpTPAvg_MinTicketsToActivate){
      // === INITIAL-TP MODE ===
      // If previously synced to avg, restore each ticket's Initial TP/SL based on its own entry
      if(g_avgTPSynced[g][side] != 0.0 || g_avgSLSynced[g][side] != 0.0){
         int total = PositionsTotal();
         for(int i=0;i<total;i++){
            ulong tk = PositionGetTicket(i);
            if(tk==0) continue;
            if(!PositionSelectByTicket(tk)) continue;
            if((long)PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
            string c = PositionGetString(POSITION_COMMENT);
            int gp; bool hd; string tag;
            if(!ParseComment(c, gp, hd, tag)) continue;
            if(gp != g || hd) continue;
            int sd = (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?0:1;
            if(sd != side) continue;
            double itp = InitialTPPriceForTicket(tk);
            double isl = InitialSLPriceForTicket(tk);
            ModifyIfDifferent(tk, isl, itp);
         }
         g_avgTPSynced[g][side] = 0;
         g_avgSLSynced[g][side] = 0;
         if(InpVerboseLog)
            PrintFormat("Golden2 v1.3: G%d side=%d back to INITIAL-TP mode (count=%d)", g, side, cnt);
      }
      return;
   }

   // === AVERAGE-TP/SL MODE === (count >= MinTickets)
   if(!InpTP_UsePointsFromAvg) return; // only this mode pushes broker TP from average
   double tpPrice = ComputeAvgTPPrice(g, side);
   double slPrice = (InpSL_Enable && InpSL_UsePointsFromAvg) ? ComputeAvgSLPrice(g, side) : 0.0;
   if(tpPrice <= 0) return;

   // Respect broker stops level
   long stopsLvl = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minDist = stopsLvl * g_point;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   if(side==0){ // BUY: TP must be > bid + minDist
      if(tpPrice < bid + minDist) tpPrice = NormalizeDouble(bid + minDist + g_point, g_digits);
      if(slPrice>0 && slPrice > bid - minDist) slPrice = NormalizeDouble(bid - minDist - g_point, g_digits);
   } else {     // SELL: TP must be < ask - minDist
      if(tpPrice > ask - minDist) tpPrice = NormalizeDouble(ask - minDist - g_point, g_digits);
      if(slPrice>0 && slPrice < ask + minDist) slPrice = NormalizeDouble(ask + minDist + g_point, g_digits);
   }

   bool changed = (MathAbs(g_avgTPSynced[g][side]-tpPrice) > g_point) ||
                  (MathAbs(g_avgSLSynced[g][side]-slPrice) > g_point);
   int total = PositionsTotal();
   int modified = 0;
   for(int i=0;i<total;i++){
      ulong tk = PositionGetTicket(i);
      if(tk==0) continue;
      if(!PositionSelectByTicket(tk)) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      string c = PositionGetString(POSITION_COMMENT);
      int gp; bool hd; string tag;
      if(!ParseComment(c, gp, hd, tag)) continue;
      if(gp != g || hd) continue;
      int sd = (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?0:1;
      if(sd != side) continue;
      if(ModifyIfDifferent(tk, slPrice, tpPrice)) modified++;
   }
   g_avgTPSynced[g][side] = tpPrice;
   g_avgSLSynced[g][side] = slPrice;
   if(InpVerboseLog && changed && modified>0)
      PrintFormat("Golden2 v1.3: G%d side=%d AVG-TP synced -> %d ticket(s) tp=%.5f sl=%.5f (count=%d)",
                  g, side, modified, tpPrice, slPrice, cnt);
}

void CloseMainSideOfGroup(int g, int side){
   int total = PositionsTotal();
   for(int i=total-1;i>=0;i--){
      ulong tk = PositionGetTicket(i);
      if(tk==0) continue;
      if(!PositionSelectByTicket(tk)) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      string c = PositionGetString(POSITION_COMMENT);
      int gp; bool hd; string tag;
      if(!ParseComment(c, gp, hd, tag)) continue;
      if(gp != g || hd) continue;  // main only
      int sd = (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?0:1;
      if(sd != side) continue;
      trade.PositionClose(tk);
   }
}

void CloseAllPositionsOfGroup(int g){
   int total = PositionsTotal();
   for(int i=total-1;i>=0;i--){
      ulong tk = PositionGetTicket(i);
      if(tk==0) continue;
      if(!PositionSelectByTicket(tk)) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      string c = PositionGetString(POSITION_COMMENT);
      int gp; bool hd; string tag;
      if(!ParseComment(c, gp, hd, tag)) continue;
      if(gp != g) continue;
      trade.PositionClose(tk);
   }
}

// Average TP/SL only fires while the group is NOT yet in a matched hedge state.
// Once hedge matches, Triple-Gate Matching Close takes over.
void CheckAndCloseByAverageTP(int g){
   if(IsGroupHedgeMatched(g)) return; // don't override Triple-Gate logic

   double bal = AccountInfoDouble(ACCOUNT_BALANCE);

   // [v2.0] Per-group accumulate-close removed — handled globally in
   //        ManageGlobalAccumulateClose() (account-wide, includes realized).

   for(int sd=0; sd<2; sd++){
      int cnt = CountGroupPositions(g, sd, 0);
      if(cnt <= 0) continue;
      double pl = GroupFloatingPL(g, sd, 0);

      // 1) Fixed dollar
      if(InpTP_UseFixedDollar && pl >= InpTP_DollarAmount){
         if(InpVerboseLog) PrintFormat("Golden2 v1.1: TP FixedUSD G%d %s pl=%.2f", g, sd==0?"BUY":"SELL", pl);
         CloseMainSideOfGroup(g, sd); continue;
      }
      // 2) Points from average
      if(InpTP_UsePointsFromAvg){
         double tpPx = ComputeAvgTPPrice(g, sd);
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         bool hit = (sd==0) ? (bid >= tpPx) : (ask <= tpPx);
         if(tpPx > 0 && hit){
            if(InpVerboseLog) PrintFormat("Golden2 v1.1: TP AvgPts G%d %s tp=%.5f", g, sd==0?"BUY":"SELL", tpPx);
            CloseMainSideOfGroup(g, sd); continue;
         }
      }
      // 3) % of balance
      if(InpTP_UsePctBalance && bal > 0){
         double tgt = bal * InpTP_PctBalance / 100.0;
         if(pl >= tgt){
            if(InpVerboseLog) PrintFormat("Golden2 v1.1: TP %%Bal G%d %s pl=%.2f tgt=%.2f", g, sd==0?"BUY":"SELL", pl, tgt);
            CloseMainSideOfGroup(g, sd); continue;
         }
      }
      // 4) % of max DD per side
      if(InpTP_UsePctMaxDD){
         double mdd = g_maxDDPerSide[g][sd];
         if(mdd > 0){
            double tgt = mdd * InpTP_PctMaxDD / 100.0;
            if(pl >= tgt){
               if(InpVerboseLog) PrintFormat("Golden2 v1.1: TP %%MaxDD G%d %s pl=%.2f tgt=%.2f (mdd=%.2f)",
                                             g, sd==0?"BUY":"SELL", pl, tgt, mdd);
               CloseMainSideOfGroup(g, sd); continue;
            }
         }
      }
   }
}

void CheckAndCloseByAverageSL(int g){
   if(!InpSL_Enable) return;
   if(IsGroupHedgeMatched(g)) return;

   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   for(int sd=0; sd<2; sd++){
      int cnt = CountGroupPositions(g, sd, 0);
      if(cnt <= 0) continue;
      double pl = GroupFloatingPL(g, sd, 0);
      double loss = (pl < 0) ? -pl : 0.0;

      if(InpSL_UseFixedDollar && loss >= InpSL_DollarAmount){
         if(InpVerboseLog) PrintFormat("Golden2 v1.1: SL FixedUSD G%d %s loss=%.2f", g, sd==0?"BUY":"SELL", loss);
         CloseMainSideOfGroup(g, sd); continue;
      }
      if(InpSL_UsePointsFromAvg){
         double slPx = ComputeAvgSLPrice(g, sd);
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         bool hit = (sd==0) ? (bid <= slPx) : (ask >= slPx);
         if(slPx > 0 && hit){
            if(InpVerboseLog) PrintFormat("Golden2 v1.1: SL AvgPts G%d %s sl=%.5f", g, sd==0?"BUY":"SELL", slPx);
            CloseMainSideOfGroup(g, sd); continue;
         }
      }
      if(InpSL_UsePctBalance && bal > 0){
         double tgt = bal * InpSL_PctBalance / 100.0;
         if(loss >= tgt){
            if(InpVerboseLog) PrintFormat("Golden2 v1.1: SL %%Bal G%d %s loss=%.2f tgt=%.2f", g, sd==0?"BUY":"SELL", loss, tgt);
            CloseMainSideOfGroup(g, sd); continue;
         }
      }
   }
}

//================ CHART LINES (Avg / TP / SL) ================
void DeleteLinesForGroup(int g){
   string keys[6] = {"AVGB","AVGS","TPB","TPS","SLB","SLS"};
   for(int i=0;i<6;i++){
      string nm = StringFormat("%s%s_G%d", g_linePrefix, keys[i], g);
      if(ObjectFind(0, nm) >= 0) ObjectDelete(0, nm);
   }
}

void DrawHLine(string name, double price, color clr, ENUM_LINE_STYLE style=STYLE_DOT, int width=1){
   if(price <= 0) return;
   if(ObjectFind(0, name) < 0){
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
   }
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetDouble(0, name, OBJPROP_PRICE, price);
}

void DrawAverageAndTPLinesForGroup(int g){
   // Skip if hedge matched (Triple-Gate is in charge)
   if(IsGroupHedgeMatched(g)){ DeleteLinesForGroup(g); return; }
   if(!GroupHasAnyPositions(g)){ DeleteLinesForGroup(g); return; }

   for(int sd=0; sd<2; sd++){
      int cnt = CountGroupPositions(g, sd, 0);
      string keyAvg = (sd==0?"AVGB":"AVGS");
      string keyTp  = (sd==0?"TPB":"TPS");
      string keySl  = (sd==0?"SLB":"SLS");
      string nmAvg = StringFormat("%s%s_G%d", g_linePrefix, keyAvg, g);
      string nmTp  = StringFormat("%s%s_G%d", g_linePrefix, keyTp,  g);
      string nmSl  = StringFormat("%s%s_G%d", g_linePrefix, keySl,  g);
      if(cnt <= 0){
         if(ObjectFind(0,nmAvg)>=0) ObjectDelete(0,nmAvg);
         if(ObjectFind(0,nmTp )>=0) ObjectDelete(0,nmTp );
         if(ObjectFind(0,nmSl )>=0) ObjectDelete(0,nmSl );
         continue;
      }
      double avg = GroupAveragePrice(g, sd, 0);
      if(InpTP_ShowAvgLine) DrawHLine(nmAvg, avg, sd==0?InpTP_AvgBuyColor:InpTP_AvgSellColor, STYLE_SOLID, MathMax(1, InpTP_AvgLineWidth));
      else if(ObjectFind(0,nmAvg)>=0) ObjectDelete(0,nmAvg);

      if(InpTP_ShowTPLine && InpTP_UsePointsFromAvg){
         double tpPx = ComputeAvgTPPrice(g, sd);
         DrawHLine(nmTp, tpPx, sd==0?InpTP_BuyLineColor:InpTP_SellLineColor);
      } else if(ObjectFind(0,nmTp)>=0) ObjectDelete(0,nmTp);

      if(InpSL_Enable && InpSL_ShowSLLine && InpSL_UsePointsFromAvg){
         double slPx = ComputeAvgSLPrice(g, sd);
         DrawHLine(nmSl, slPx, InpSL_LineColor);
      } else if(ObjectFind(0,nmSl)>=0) ObjectDelete(0,nmSl);
   }
}

void CleanupAllLinesByPrefix(){
   // delete all G2L_* objects (used at OnDeinit)
   int total = ObjectsTotal(0,-1,-1);
   for(int i=total-1;i>=0;i--){
      string nm = ObjectName(0,i,-1,-1);
      if(StringFind(nm, g_linePrefix) == 0) ObjectDelete(0, nm);
   }
}

//================ MATCHING CLOSE (Triple Gate) ================
void TryMatchingCloseForGroup(int g){
   if(!InpExitTripleGate_Enable) return; // [v1.6] master toggle for Triple-Gate
   if(!IsExpansionToNormal()) return;

   double avgMain  = GroupAveragePrice(g, -1, 0);
   double avgHedge = GroupAveragePrice(g, -1, 1);
   if(avgMain<=0 || avgHedge<=0) return;

   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double mid = (bid+ask)*0.5;
   double avgMid = (avgMain + avgHedge)*0.5;
   double dist = MathAbs(mid - avgMid) / g_point;
   if(dist < InpExitBreakoutPips) return;

   double plBuyMain   = GroupFloatingPL(g, 0, 0);
   double plSellMain  = GroupFloatingPL(g, 1, 0);
   double plBuyHedge  = GroupFloatingPL(g, 0, 1);
   double plSellHedge = GroupFloatingPL(g, 1, 1);

   bool priceUp = (mid > avgMid);
   int winSide = priceUp ? 0 : 1;
   int losSide = priceUp ? 1 : 0;

   double winProfit = (winSide==0) ? (plBuyMain + plBuyHedge) : (plSellMain + plSellHedge);
   double netCheck = plBuyMain+plSellMain+plBuyHedge+plSellHedge;
   if(netCheck < InpExitMinNetUSD) return;

   if(!ClaimMutex(g)) return;

   CloseAllGroupSide(g, winSide);
   double pool = winProfit;
   ShredCloseLosingSide(g, losSide, pool);

   g_lastHedgeCloseTime = TimeCurrent();
   ReleaseMutex(g);

   if(InpPostHedge_AllowContinuation) PlaceContinuationGridIfNeeded(g); // [v1.6] off by default = freeze
}

void CloseAllGroupSide(int g, int side){
   int total = PositionsTotal();
   for(int i=total-1;i>=0;i--){
      ulong tk = PositionGetTicket(i);
      if(tk==0) continue;
      if(!PositionSelectByTicket(tk)) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      string c = PositionGetString(POSITION_COMMENT);
      int gp; bool hd; string tag;
      if(!ParseComment(c, gp, hd, tag)) continue;
      if(gp != g) continue;
      int sd = (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?0:1;
      if(sd != side) continue;
      trade.PositionClose(tk);
   }
}

void ShredCloseLosingSide(int g, int side, double pool){
   ulong tickets[]; double profits[]; int n=0;
   int total = PositionsTotal();
   for(int i=0;i<total;i++){
      ulong tk = PositionGetTicket(i);
      if(tk==0) continue;
      if(!PositionSelectByTicket(tk)) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      string c = PositionGetString(POSITION_COMMENT);
      int gp; bool hd; string tag;
      if(!ParseComment(c, gp, hd, tag)) continue;
      if(gp != g) continue;
      int sd = (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?0:1;
      if(sd != side) continue;
      ArrayResize(tickets, n+1);
      ArrayResize(profits, n+1);
      tickets[n] = tk;
      profits[n] = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      n++;
   }
   for(int i=0;i<n-1;i++){
      for(int j=i+1;j<n;j++){
         if(profits[j] > profits[i]){
            double tp = profits[i]; profits[i]=profits[j]; profits[j]=tp;
            ulong tt = tickets[i]; tickets[i]=tickets[j]; tickets[j]=tt;
         }
      }
   }
   for(int i=0;i<n;i++){
      double p = profits[i];
      if(pool + p >= InpExitMinNetUSD){
         if(PositionSelectByTicket(tickets[i])){
            if(trade.PositionClose(tickets[i])) pool += p;
         }
      } else {
         break;
      }
   }
}

void PlaceContinuationGridIfNeeded(int g){
   for(int sd=0; sd<2; sd++){
      for(int hd=0; hd<2; hd++){
         int cnt = CountGroupPositions(g, sd, hd);
         if(cnt <= 0) continue;
         int gl = HighestGridLevel(g, (ENUM_SIDE)sd, (hd==1), "GL");
         if(gl >= InpMaxGridLevels) continue;
         double lot = LotForLevel(gl+1);
         string c = MakeComment(g, hd==1, StringFormat("GL#%d", gl+1));
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         bool ok = (sd==0) ? trade.Buy(lot,_Symbol,ask,0,0,c) : trade.Sell(lot,_Symbol,bid,0,0,c);
         if(InpVerboseLog) PrintFormat("Golden2 v1.1: Continuation GL#%d %s G%d hedge=%d lot=%.2f ok=%d",
            gl+1, sd==0?"BUY":"SELL", g, hd, lot, ok);
      }
   }
}

//================ CYCLE / GROUP LIFECYCLE ================

// [v2.0] Account-wide accumulate-close: sums realized (since last reset) +
// floating across ALL groups + sides. Resets to 0 each time the account
// holds zero positions and zero pendings of this magic.
bool AnyOrderInSystem(){
   int p = PositionsTotal();
   for(int i=0;i<p;i++){
      ulong tk = PositionGetTicket(i);
      if(tk==0) continue;
      if(!PositionSelectByTicket(tk)) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      return true;
   }
   int o = OrdersTotal();
   for(int i=0;i<o;i++){
      ulong tk = OrderGetTicket(i);
      if(tk==0) continue;
      if(!OrderSelect(tk)) continue;
      if((long)OrderGetInteger(ORDER_MAGIC) != InpMagic) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      return true;
   }
   return false;
}

double SumRealizedSince(datetime since){
   double sum = 0.0;
   if(!HistorySelect(since, TimeCurrent())) return 0.0;
   int total = HistoryDealsTotal();
   for(int i=0;i<total;i++){
      ulong tk = HistoryDealGetTicket(i);
      if(tk==0) continue;
      if((long)HistoryDealGetInteger(tk, DEAL_MAGIC) != InpMagic) continue;
      if(HistoryDealGetString(tk, DEAL_SYMBOL) != _Symbol) continue;
      long entry = HistoryDealGetInteger(tk, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT && entry != DEAL_ENTRY_OUT_BY) continue;
      sum += HistoryDealGetDouble(tk, DEAL_PROFIT);
      sum += HistoryDealGetDouble(tk, DEAL_SWAP);
      sum += HistoryDealGetDouble(tk, DEAL_COMMISSION);
   }
   return sum;
}

void CloseEverythingNow(){
   // Close all positions of this magic
   for(int pass=0; pass<3; pass++){
      int p = PositionsTotal();
      for(int i=p-1;i>=0;i--){
         ulong tk = PositionGetTicket(i);
         if(tk==0) continue;
         if(!PositionSelectByTicket(tk)) continue;
         if((long)PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         trade.PositionClose(tk);
      }
      int o = OrdersTotal();
      for(int i=o-1;i>=0;i--){
         ulong tk = OrderGetTicket(i);
         if(tk==0) continue;
         if(!OrderSelect(tk)) continue;
         if((long)OrderGetInteger(ORDER_MAGIC) != InpMagic) continue;
         if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
         trade.OrderDelete(tk);
      }
   }
}

void ManageGlobalAccumulateClose(){
   bool any = AnyOrderInSystem();
   double floating = 0.0;
   if(any){
      for(int g=1; g<=InpMaxGroups; g++) floating += GroupFloatingPL(g,-1,-1);
   }

   // [v2.1] Cooldown branch — after CloseEverythingNow() we sit here until the
   //        account is truly empty AND cooldown elapsed, then force-reset the
   //        cycle so the next legitimate accumulation starts at zero.
   if(g_accumJustTriggered){
      bool cooldownDone = (InpTP_AccumCooldownSec <= 0) ||
                          (TimeCurrent() - g_accumTriggerTime >= InpTP_AccumCooldownSec);
      if(!any && cooldownDone){
         g_accumRealizedSinceReset = 0.0;
         g_accumResetTime          = TimeCurrent();
         g_accumNetCached          = 0.0;
         g_accumFloatingCached     = 0.0;
         g_accumJustTriggered      = false;
         if(InpVerboseLog) Print("Golden2 v2.1: Accumulate cooldown DONE — cycle reset, trading resumes");
      } else {
         // Still cooling down — refresh dashboard cache only, do not re-trigger.
         g_accumFloatingCached = floating;
         g_accumNetCached      = g_accumRealizedSinceReset + floating;
         g_hadAnyOrderLastTick = any;
         return;
      }
   }

   // Reset point: transition from "had orders" -> "none" (normal cycle end)
   if(!any && g_hadAnyOrderLastTick){
      g_accumRealizedSinceReset = 0.0;
      g_accumResetTime          = TimeCurrent();
      g_accumNetCached          = 0.0;
      g_accumFloatingCached     = 0.0;
      if(InpVerboseLog) Print("Golden2 v2.1: Accumulate cycle RESET (no orders in system)");
   }
   if(g_accumResetTime == 0) g_accumResetTime = TimeCurrent();

   double realized = SumRealizedSince(g_accumResetTime);
   g_accumRealizedSinceReset = realized;
   g_accumFloatingCached     = floating;
   g_accumNetCached          = realized + floating;

   if(InpTP_UseAccumulateClose && any && g_accumNetCached >= InpTP_AccumulateTarget){
      PrintFormat("Golden2 v2.1: GLOBAL Accumulate Close net=%.2f >= %.2f (realized=%.2f float=%.2f) — cooldown %ds",
                  g_accumNetCached, InpTP_AccumulateTarget, realized, floating, InpTP_AccumCooldownSec);
      CloseEverythingNow();
      // Arm cooldown so PlaceInitialFrame/this function will not loop.
      g_accumJustTriggered = true;
      g_accumTriggerTime   = TimeCurrent();
   }

   g_hadAnyOrderLastTick = any;
}

// [v2.3] Count main positions on a side that should BLOCK group advancement.
// A residual post-hedge "IN" position (the lone initial fill that landed AFTER
// the hedge was already armed) does not block advancement when:
//   - the group already has hedge positions (hedge cycle is in progress), AND
//   - the IN position is the only main position on that side.
// In that case the IN is treated as an isolated leftover, not unhedged exposure.
int CountBlockingMainPositionsForAdvance(int g, int side){
   int total = PositionsTotal();
   int blocking = 0;
   int inCount  = 0;
   bool hedgeAny = (CountGroupPositions(g, -1, 1) > 0);
   for(int i=0;i<total;i++){
      ulong tk = PositionGetTicket(i);
      if(tk==0) continue;
      if(!PositionSelectByTicket(tk)) continue;
      if((long)PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      string c = PositionGetString(POSITION_COMMENT);
      int gp; bool hd; string tag;
      if(!ParseComment(c, gp, hd, tag)) continue;
      if(gp != g) continue;
      if(hd) continue; // hedge side handled elsewhere
      int sd = (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?0:1;
      if(sd != side) continue;
      if(hedgeAny && tag == "IN") { inCount++; continue; }
      blocking++;
   }
   // Allow up to one residual IN orphan to be ignored when hedge is active.
   // If multiple non-IN main positions exist alongside, IN is no longer "isolated"
   // and its absence from blocking is still safe (hedge already covers them).
   return blocking;
}

// [v2.3] Cancel any leftover G_IN pendings on a group that has already begun
// hedging. Keeps hedge pendings/positions and main grid positions untouched.
// This prevents a stray BuyStop/SellStop from being triggered after the hedge
// frame is set up, which would create an orphan main with no opposing hedge.
void DeleteLeftoverInitialPendingsAfterHedge(int g){
   if(CountGroupPositions(g, -1, 1) <= 0) return; // no hedge yet, nothing to do
   int total = OrdersTotal();
   for(int i=total-1;i>=0;i--){
      ulong tk = OrderGetTicket(i);
      if(tk==0) continue;
      if(!OrderSelect(tk)) continue;
      if((long)OrderGetInteger(ORDER_MAGIC) != InpMagic) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      string c = OrderGetString(ORDER_COMMENT);
      int gp; bool hd; string tag;
      if(!ParseComment(c, gp, hd, tag)) continue;
      if(gp != g) continue;
      if(hd) continue;            // never delete hedge pendings
      if(tag != "IN") continue;   // only target initial-frame pendings
      if(trade.OrderDelete(tk)){
         if(InpVerboseLog) PrintFormat("Golden2 v2.3: post-hedge cleanup G%d deleted leftover IN pending #%I64u", g, tk);
      } else {
         PrintFormat("Golden2 v2.3: post-hedge cleanup G%d delete IN #%I64u FAIL err=%d", g, tk, GetLastError());
      }
   }
}

// [v2.3] Group is "safe to advance to next" using PER-SIDE hedge-lock check.
// Each surviving main side must be covered by hedge positions; sides that have
// already emptied (TP hit / Triple-Gate close) do not need a hedge counterpart.
// Residual post-hedge IN orphans are ignored (see CountBlockingMainPositionsForAdvance).
bool IsGroupSafeToAdvance(int g){
   int buyMain  = CountBlockingMainPositionsForAdvance(g, 0);
   int sellMain = CountBlockingMainPositionsForAdvance(g, 1);
   if(buyMain == 0 && sellMain == 0) return true;        // no blocking main exposure
   bool hedgeAny = (CountGroupPositions(g, -1, 1) > 0);
   if(!hedgeAny) return false;                           // unlocked main with zero hedge
   bool buyOK  = (buyMain  == 0) || (CountGroupPositions(g, 1, 1) > 0); // sell-side hedge locks BUY main
   bool sellOK = (sellMain == 0) || (CountGroupPositions(g, 0, 1) > 0); // buy-side hedge locks SELL main
   return (buyOK && sellOK);
}

// [v2.2] Verify every group BEFORE curG is also safe (no orphan unlocked main
// in groups 1..curG-1). Prevents skipping past a stuck older group.
bool AreAllPriorGroupsSafe(int curG){
   for(int i=1; i<curG; i++){
      if(!GroupHasAnyPositions(i)) continue; // empty group is fine
      if(!IsGroupSafeToAdvance(i)) return false;
   }
   return true;
}

void TryAdvanceToNextGroup(){
   int cur = FindActiveTradingGroup();
   if(cur < 1) {
      int g = FindLowestIdleGroup();
      if(g >= 1) PlaceInitialFrame(g);
      return;
   }
   // [v2.3] As soon as cur is hedging, sweep any leftover IN pendings so a
   //        late stop trigger cannot drop a new orphan main into the group.
   DeleteLeftoverInitialPendingsAfterHedge(cur);

   // [v2.2/v2.3] Advance condition: cur has hedge active AND (lock-guard off OR cur+priors safe).
   bool hedgeActive = GroupHedgeJustActivated(cur);
   if(!hedgeActive) return;
   if(!InpGroup_AdvancePerTick){
      // legacy edge-only behaviour preserved for users who want v2.1 semantics
   }
   if(InpGroup_RequireFullLockBeforeNext){
      if(!IsGroupSafeToAdvance(cur) || !AreAllPriorGroupsSafe(cur)){
         static datetime lastHoldLog = 0;
         if(InpVerboseLog && TimeCurrent() - lastHoldLog >= 60){
            PrintFormat("Golden2 v2.3: hold G%d->G%d (cur safe=%d priors safe=%d blkBUY=%d blkSELL=%d rawBUY=%d rawSELL=%d hedgeBuy=%d hedgeSell=%d)",
                        cur, cur+1,
                        IsGroupSafeToAdvance(cur), AreAllPriorGroupsSafe(cur),
                        CountBlockingMainPositionsForAdvance(cur,0), CountBlockingMainPositionsForAdvance(cur,1),
                        CountGroupPositions(cur,0,0), CountGroupPositions(cur,1,0),
                        CountGroupPositions(cur,0,1), CountGroupPositions(cur,1,1));
            lastHoldLog = TimeCurrent();
         }
         return;
      }
   }
   if(cur < InpMaxGroups){
      int next = cur + 1;
      if(!GroupHasAnyPositions(next) && !GroupHasAnyPendings(next)){
         if(InpVerboseLog) PrintFormat("Golden2 v2.3: advance G%d -> G%d (placing initial frame)", cur, next);
         PlaceInitialFrame(next);
      }
   } else {
      static datetime lastWarn = 0;
      if(TimeCurrent() - lastWarn >= 300){
         Print("Golden2 v2.3: Reached InpMaxGroups limit, no new group will be opened.");
         lastWarn = TimeCurrent();
      }
   }
}

//================ DASHBOARD ================
string StrippedListString(){
   string s = "";
   for(int g=1; g<=InpMaxGroups; g++){
      if(g_stripped[g] && GroupHasAnyPositions(g)){
         if(StringLen(s)>0) s += ",";
         s += StringFormat("G%d", g);
      }
   }
   return (StringLen(s)==0) ? "-" : s;
}

// ---------- Dashboard helpers (v1.5: 2-panel Gold-Miner-style) ----------
void DashCleanupAll(){
   int total = ObjectsTotal(0,-1,-1);
   for(int i=total-1;i>=0;i--){
      string nm = ObjectName(0, i, -1, -1);
      if(StringFind(nm, g_dashPrefix) == 0) ObjectDelete(0, nm);
   }
   if(ObjectFind(0, g_dashName) >= 0) ObjectDelete(0, g_dashName);
}

void DashRect(string name, int x, int y, int w, int h, color bg){
   if(ObjectFind(0, name) < 0){
      ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_COLOR, bg);
}

void DashLabel(string name, int x, int y, string text, color clr){
   if(ObjectFind(0, name) < 0){
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, InpDashFontSize);
      ObjectSetString (0, name, OBJPROP_FONT, InpDashFont);
   }
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetString (0, name, OBJPROP_TEXT, text);
}

// Track names rendered each frame so we can sweep stale ones
string g_dashAlive[];
void DashTrack(string name){
   int n = ArraySize(g_dashAlive);
   ArrayResize(g_dashAlive, n+1);
   g_dashAlive[n] = name;
}
void DashSweepStale(){
   int total = ObjectsTotal(0,-1,-1);
   for(int i=total-1;i>=0;i--){
      string nm = ObjectName(0, i, -1, -1);
      if(StringFind(nm, g_dashPrefix) != 0) continue;
      bool keep = false;
      for(int k=0;k<ArraySize(g_dashAlive);k++){
         if(g_dashAlive[k] == nm){ keep=true; break; }
      }
      if(!keep) ObjectDelete(0, nm);
   }
}

// One-row helper: bg rect + key label (left) + value label (right)
void DashRow(string keyId, int x, int y, int w, int rowH,
             string keyText, string valText, color valColor){
   string bgN  = g_dashPrefix + "BG_"  + keyId;
   string keyN = g_dashPrefix + "K_"   + keyId;
   string valN = g_dashPrefix + "V_"   + keyId;
   DashRect (bgN, x, y, w, rowH, InpDashRowBg);                         DashTrack(bgN);
   DashLabel(keyN, x+6, y+3, keyText, InpDashColor);                    DashTrack(keyN);
   DashLabel(valN, x+w/2, y+3, valText, valColor);                      DashTrack(valN);
}

// Header bar
void DashHeader(string id, int x, int y, int w, int rowH, string text, color clr){
   string bgN = g_dashPrefix + "HBG_" + id;
   string txN = g_dashPrefix + "HTX_" + id;
   DashRect (bgN, x, y, w, rowH, InpDashHeaderBg);   DashTrack(bgN);
   DashLabel(txN, x+6, y+3, text, clr);              DashTrack(txN);
}

void DrawDashboard(){
   if(!InpShowDashboard){ DashCleanupAll(); return; }
   ArrayResize(g_dashAlive, 0);

   //==== LEFT PANEL: Gold-Miner-style summary ====
   int x = InpDashX;
   int y = InpDashY;
   int w = InpDashLeftWidth;
   int rowH = 18;

   double bal   = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq    = AccountInfoDouble(ACCOUNT_EQUITY);
   double flt   = eq - bal;

   // Aggregates across all groups
   double totMainLot=0, totHedgeLot=0, totPL=0, totLossUSD=0, peakLossUSD=0;
   int    activeGroups=0, matchedGroups=0, blockedGroups=0;
   int    totBuyPos=0, totSellPos=0, totHedgePos=0, totHedgePend=0;
   double plBuy=0, plSell=0;
   for(int g=1; g<=InpMaxGroups; g++){
      bool hp = GroupHasAnyPositions(g), he = GroupHasAnyPendings(g);
      if(!hp && !he) continue;
      activeGroups++;
      if(IsGroupHedgeMatched(g)) matchedGroups++;
      if(g_blockNewOrders[g])    blockedGroups++;
      totMainLot  += GroupTotalLot(g,-1,0);
      totHedgeLot += GroupTotalLot(g,-1,1);
      totPL       += GroupFloatingPL(g,-1,-1);
      double lUSD = -MathMin(GroupFloatingPL(g,0,0), GroupFloatingPL(g,1,0));
      if(lUSD>0) totLossUSD += lUSD;
      if(lUSD>peakLossUSD) peakLossUSD = lUSD;
      totBuyPos    += CountGroupPositions(g,0,0);
      totSellPos   += CountGroupPositions(g,1,0);
      totHedgePos  += CountGroupPositions(g,-1,1);
      totHedgePend += CountGroupPendingsByTagPrefix(g, true, "");
      plBuy        += GroupFloatingPL(g,0,0);
      plSell       += GroupFloatingPL(g,1,0);
   }
   double maxPct = (InpHedgeTriggerUSD>0) ? (peakLossUSD*100.0/InpHedgeTriggerUSD) : 0;

   // Build mode label
   string modeLbl = "BOTH";
   if(InpInitSideMode == INIT_BUY_ONLY)  modeLbl = "BUY-only";
   if(InpInitSideMode == INIT_SELL_ONLY) modeLbl = "SELL-only";

   // Header
   DashHeader("L_TITLE", x, y, w, rowH+2, StringFormat(" Golden2 EA v2.6.1    Side: %s", modeLbl), InpDashAccent);
   y += rowH+2;

   // ==== Account section ====
   DashHeader("L_S_ACC", x, y, w, rowH, " === ACCOUNT ===", InpDashAccent); y+=rowH;
   DashRow("L_BAL",   x, y, w, rowH, "Balance",          StringFormat("$%.2f", bal), InpDashColor);  y+=rowH;
   DashRow("L_EQ",    x, y, w, rowH, "Equity",           StringFormat("$%.2f", eq),  InpDashColor);  y+=rowH;
   DashRow("L_FLT",   x, y, w, rowH, "Floating P/L",     StringFormat("$%.2f", flt), flt>=0?InpDashGood:InpDashBad); y+=rowH;

   // ==== [v2.0] Accumulate section ====
   if(InpTP_UseAccumulateClose){
      DashHeader("L_S_ACC2", x, y, w, rowH, " === ACCUMULATE ===", InpDashAccent); y+=rowH;
      DashRow("L_AC_ST",  x, y, w, rowH, "Status",   "ON", InpDashGood); y+=rowH;
      DashRow("L_AC_TGT", x, y, w, rowH, "Target",   StringFormat("$%.2f", InpTP_AccumulateTarget), InpDashColor); y+=rowH;
      DashRow("L_AC_RLZ", x, y, w, rowH, "Realized (cycle)", StringFormat("$%.2f", g_accumRealizedSinceReset),
              g_accumRealizedSinceReset>=0?InpDashGood:InpDashBad); y+=rowH;
      DashRow("L_AC_FLT", x, y, w, rowH, "Floating", StringFormat("$%.2f", g_accumFloatingCached),
              g_accumFloatingCached>=0?InpDashGood:InpDashBad); y+=rowH;
      DashRow("L_AC_NET", x, y, w, rowH, "Accum Net", StringFormat("$%.2f", g_accumNetCached),
              g_accumNetCached>=0?InpDashGood:InpDashBad); y+=rowH;
      double pct = (InpTP_AccumulateTarget>0) ? (g_accumNetCached*100.0/InpTP_AccumulateTarget) : 0;
      DashRow("L_AC_PCT", x, y, w, rowH, "Progress", StringFormat("%.1f%%", pct),
              pct>=100?InpDashGood:(pct>=50?InpDashAccent:InpDashColor)); y+=rowH;
   } else {
      DashRow("L_AC_OFF", x, y, w, rowH, "Accumulate", "OFF", InpDashColor); y+=rowH;
   }

   // ==== Position section ====
   DashHeader("L_S_POS", x, y, w, rowH, " === POSITIONS ===", InpDashAccent); y+=rowH;
   DashRow("L_PB",    x, y, w, rowH, "BUY  P/L  Lot  Ord",  StringFormat("$%.2f  %.2fL  %dord", plBuy,  GroupAggLotBuy(),  totBuyPos),  plBuy>=0?InpDashGood:InpDashBad);  y+=rowH;
   DashRow("L_PS",    x, y, w, rowH, "SELL P/L  Lot  Ord",  StringFormat("$%.2f  %.2fL  %dord", plSell, GroupAggLotSell(), totSellPos), plSell>=0?InpDashGood:InpDashBad); y+=rowH;
   DashRow("L_TOTLOT",x, y, w, rowH, "Total Cur. Lot",   StringFormat("%.2f L", totMainLot+totHedgeLot), InpDashColor); y+=rowH;
   DashRow("L_GRP",   x, y, w, rowH, "Active / Matched", StringFormat("%d / %d", activeGroups, matchedGroups), InpDashAccent); y+=rowH;
   DashRow("L_DD",    x, y, w, rowH, "Current DD% (max)", StringFormat("%.2f%% / %.0f%%", maxPct, InpHedgeArmPercent), maxPct>=InpHedgeArmPercent?InpDashBad:(maxPct>=InpHedge_BlockNewOrderPercent?InpDashAccent:InpDashColor)); y+=rowH;

   // ==== Module status section ====
   DashHeader("L_S_MOD", x, y, w, rowH, " === MODULES ===", InpDashAccent); y+=rowH;
   DashRow("L_INIT",  x, y, w, rowH, "Initial Side",     StringFormat("%s  Trail:%s  ReArm:%s",
                          modeLbl,
                          InpInitTrailOpposite?"ON":"OFF",
                          InpInitReArmAfterTP ?"ON":"OFF"),
                          InpDashColor); y+=rowH;
   DashRow("L_GL",    x, y, w, rowH, "Grid Loss",        GridLoss_Enable?"ON":"OFF", GridLoss_Enable?InpDashGood:InpDashBad); y+=rowH;
   DashRow("L_GP",    x, y, w, rowH, "Grid Profit",      GridProfit_Enable?"ON":"OFF", GridProfit_Enable?InpDashGood:InpDashBad); y+=rowH;
   DashRow("L_TRAIL", x, y, w, rowH, "MaxGrid Trail",    StringFormat("%s (Mode %d)", MaxGrid_TrailEnable?"ON":"OFF", MaxGrid_TrailMode), MaxGrid_TrailEnable?InpDashGood:InpDashColor); y+=rowH;
   DashRow("L_HEDGE", x, y, w, rowH, "Hedging",          InpHedge_Enabled?"ON":"OFF", InpHedge_Enabled?InpDashGood:InpDashBad); y+=rowH;
   DashRow("L_BLK",   x, y, w, rowH, "Pre-Hedge Block",  StringFormat("%d grp(s)", blockedGroups), blockedGroups>0?InpDashAccent:InpDashColor); y+=rowH;
   int rem=0;
   string hd = IsHedgeOpenDelayActive(rem) ? StringFormat("WAIT %dm%02ds", rem/60, rem%60) : "READY";
   DashRow("L_HDLY",  x, y, w, rowH, "Hedge Delay",      hd, InpDashColor); y+=rowH;
   DashRow("L_TG",    x, y, w, rowH, "Triple-Gate",      InpExitTripleGate_Enable?"ON":"OFF", InpExitTripleGate_Enable?InpDashGood:InpDashBad); y+=rowH;
   // ==== [v1.8] Gold-Miner-style Squeeze panel (multi-row) ====
   if(InpSQ_Enable){
      DashHeader("L_S_SQ", x, y, w, rowH, " === SQUEEZE ===", InpDashAccent); y+=rowH;
      for(int si=0; si<3; si++){
         string lbl = SqueezeTFLabel(si);
         string st  = SqueezeStateLabel(si);
         string val = StringFormat("%-15s %.2f %s", st, g_sqRatio[si], SqueezeBarString(g_sqRatio[si]));
         color  cc;
         if(!g_sqExpansion[si]) cc = InpDashColor;
         else if((g_sqDir[si]>0 && g_sqBlockSell) || (g_sqDir[si]<0 && g_sqBlockBuy)) cc = InpDashBad;
         else cc = InpDashAccent;
         DashRow(StringFormat("L_SQ_%d", si), x, y, w, rowH, lbl, val, cc); y+=rowH;
      }
      string ov = SqueezeOverallLabel();
      color  ovC = (ov=="READY")? InpDashGood : InpDashBad;
      DashRow("L_SQ_ST", x, y, w, rowH, "Squeeze Status", ov, ovC); y+=rowH;
   } else {
      DashRow("L_SQ",   x, y, w, rowH, "Squeeze", "OFF", InpDashColor); y+=rowH;
   }

   // ==== Footer ====
   DashHeader("L_S_SYS", x, y, w, rowH, " === SYSTEM ===", InpDashAccent); y+=rowH;
   DashRow("L_QUEUE", x, y, w, rowH, "Queue Mutex",      g_activeOpsGroup<0?"IDLE":StringFormat("G%d", g_activeOpsGroup), InpDashColor); y+=rowH;
   DashRow("L_STRIP", x, y, w, rowH, "TP-Stripped",      StrippedListString(), InpDashColor); y+=rowH;
   DashRow("L_STAT",  x, y, w, rowH, "System Status",    InpAllowTrade?"Working":"Paused", InpAllowTrade?InpDashGood:InpDashBad); y+=rowH;

   //==== RIGHT PANEL: Hedging table (only when Hedging is ON) ====
   if(InpHedge_Enabled){
      int xR = InpDashX + InpDashLeftWidth + InpDashHedgeGap;
      int yR = InpDashY;
      int wR = 380;

      DashHeader("R_TITLE", xR, yR, wR, rowH+2, StringFormat(" Hedging Table (%d/%d)", activeGroups, InpMaxGroups), InpDashAccent);
      yR += rowH+2;

      // Column header
      string hdr = StringFormat("%-4s %-9s %-6s %-6s %-9s %-5s",
                                "Grp", "Status", "MainL", "HdgL", "P/L", "Pend");
      DashRow("R_HDR", xR, yR, wR, rowH, "G/Status", "MainL  HdgL   P/L   Pend  DD%", InpDashAccent);
      yR += rowH;

      bool any=false;
      for(int g=1; g<=InpMaxGroups; g++){
         if(!GroupHasAnyPositions(g) && !GroupHasAnyPendings(g)) continue;
         any=true;
         double mL  = GroupTotalLot(g,-1,0);
         double hL  = GroupTotalLot(g,-1,1);
         double pl  = GroupFloatingPL(g,-1,-1);
         double lU  = -MathMin(GroupFloatingPL(g,0,0), GroupFloatingPL(g,1,0));
         if(lU<0) lU=0;
         double pct = (InpHedgeTriggerUSD>0) ? (lU*100.0/InpHedgeTriggerUSD) : 0;
         int hPend  = CountGroupPendingsByTagPrefix(g, true, "");
         int hPos   = CountGroupPositions(g,-1,1);
         string st;
         color  stClr;
         if(hPos > 0)              { st = "ACTIVE";              stClr = InpDashBad; }
         else if(hPend > 0)        { st = StringFormat("ARMED%d", hPend); stClr = InpDashAccent; }
         else if(g_blockNewOrders[g]){ st = "BLOCK";              stClr = InpDashAccent; }
         else                      { st = "IDLE";                stClr = InpDashColor; }
         string match = IsGroupHedgeMatched(g) ? "*" : " ";

         string keyTxt = StringFormat("G%d%s %s", g, match, st);
         string valTxt = StringFormat("%5.2f %5.2f %7.2f %3d  %5.1f%%",
                                       mL, hL, pl, hPend, pct);
         color rowClr  = (pl>=0)?InpDashGood:InpDashBad;
         DashRow(StringFormat("R_G%d", g), xR, yR, wR, rowH, keyTxt, valTxt, rowClr);
         // Override key color separately
         ObjectSetInteger(0, g_dashPrefix + "K_" + StringFormat("R_G%d", g), OBJPROP_COLOR, stClr);
         yR += rowH;
      }
      if(!any){
         DashRow("R_EMPTY", xR, yR, wR, rowH, "(no active groups)", "-", InpDashColor);
         yR += rowH;
      }

      // Totals footer
      DashHeader("R_FOOT", xR, yR, wR, rowH+2, StringFormat(" TOTAL  Main=%.2fL  Hdg=%.2fL  P/L=$%.2f  Pend=%d",
                          totMainLot, totHedgeLot, totPL, totHedgePend),
                          totPL>=0?InpDashGood:InpDashBad);
      yR += rowH+2;
   }

   DashSweepStale();
}

// Helpers used by dashboard above
double GroupAggLotBuy(){
   double s=0;
   for(int g=1; g<=InpMaxGroups; g++) s += GroupTotalLot(g, 0, 0);
   return s;
}
double GroupAggLotSell(){
   double s=0;
   for(int g=1; g<=InpMaxGroups; g++) s += GroupTotalLot(g, 1, 0);
   return s;
}

//================ INIT / DEINIT / TICK ================
int OnInit(){
   g_point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   g_digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   g_pipMul = 1.0;
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippage);

   for(int i=0;i<51;i++){
      g_stripped[i]=false;
      g_maxDDPerSide[i][0]=0.0; g_maxDDPerSide[i][1]=0.0;
      g_atrAtLastGridLoss[i][0]=0.0; g_atrAtLastGridLoss[i][1]=0.0;
      g_atrAtLastGridProfit[i][0]=0.0; g_atrAtLastGridProfit[i][1]=0.0;
      g_initialCandleTime[i][0]=0; g_initialCandleTime[i][1]=0;
      g_lastGridCandleLoss[i][0]=0; g_lastGridCandleLoss[i][1]=0;
      g_lastGridCandleProfit[i][0]=0; g_lastGridCandleProfit[i][1]=0;
      g_lastTrailBar[i] = 0; // [v1.8]
      g_maxGridTrailSL[i][0]=0; g_maxGridTrailSL[i][1]=0;
      g_maxGridTrailArmed[i][0]=false; g_maxGridTrailArmed[i][1]=false;
      g_avgTPSynced[i][0]=0; g_avgTPSynced[i][1]=0;
      g_avgSLSynced[i][0]=0; g_avgSLSynced[i][1]=0;
   }

   g_bbHandle  = iBands(_Symbol, InpExitTF, InpExitBBPeriod, 0, InpExitBBDev, PRICE_CLOSE);
   g_atrHandle = iATR(_Symbol, InpExitTF, InpExitKeltnerATR);
   g_atrLossHandle   = iATR(_Symbol, GridLoss_ATR_TF,   GridLoss_ATR_Period);
   g_atrProfitHandle = iATR(_Symbol, GridProfit_ATR_TF, GridProfit_ATR_Period);
   if(g_bbHandle == INVALID_HANDLE || g_atrHandle == INVALID_HANDLE){
      Print("Golden2 v1.7: indicator init failed");
      return INIT_FAILED;
   }

   // [v1.6] Squeeze Filter handles
   g_sqTF[0] = InpSQ_TF1; g_sqTF[1] = InpSQ_TF2; g_sqTF[2] = InpSQ_TF3;
   for(int i=0;i<3;i++){
      g_sqBB[i]    = iBands(_Symbol, g_sqTF[i], InpSQ_BBPeriod, 0, InpSQ_BBMult, PRICE_CLOSE);
      g_sqKCEMA[i] = iMA   (_Symbol, g_sqTF[i], InpSQ_KCPeriod, 0, MODE_EMA, PRICE_CLOSE);
      g_sqATR[i]   = iATR  (_Symbol, g_sqTF[i], InpSQ_ATRPeriod);
      if(InpSQ_Enable && (g_sqBB[i]==INVALID_HANDLE || g_sqKCEMA[i]==INVALID_HANDLE || g_sqATR[i]==INVALID_HANDLE)){
         PrintFormat("Golden2 v1.6: Squeeze indicator init failed TF[%d]", i);
      }
   }

   PrintFormat("Golden2 EA v2.6.1 initialized | Magic=%I64d | MaxGroups=%d | InitMode=%d | GridLoss=%s | Squeeze=%s | TripleGate=%s | BarTrail=%s | TrailMode=ToWardPriceOnly | MinStep=%dpt | ReEntryOnClose=%s | Accum=%s | AccumCooldown=%ds | GroupLock=%s | AdvancePerTick=%s",
               (long)InpMagic, InpMaxGroups, (int)InpInitSideMode,
               GridLoss_Enable?"ON":"OFF", InpSQ_Enable?"ON":"OFF", InpExitTripleGate_Enable?"ON":"OFF",
               InpInitTrailOnBarClose?"ON":"OFF",
               InpFrameRecenterMinPips,
               InpInitReEntryOnClose?"ON":"OFF",
               InpTP_UseAccumulateClose?"ON":"OFF",
               InpTP_AccumCooldownSec,
               InpGroup_RequireFullLockBeforeNext?"ON":"OFF",
               InpGroup_AdvancePerTick?"ON":"OFF");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason){
   DashCleanupAll();
   CleanupAllLinesByPrefix();
   if(g_bbHandle != INVALID_HANDLE) IndicatorRelease(g_bbHandle);
   if(g_atrHandle != INVALID_HANDLE) IndicatorRelease(g_atrHandle);
   if(g_atrLossHandle != INVALID_HANDLE)   IndicatorRelease(g_atrLossHandle);
   if(g_atrProfitHandle != INVALID_HANDLE) IndicatorRelease(g_atrProfitHandle);
   for(int i=0;i<3;i++){
      if(g_sqBB[i]    != INVALID_HANDLE) IndicatorRelease(g_sqBB[i]);
      if(g_sqKCEMA[i] != INVALID_HANDLE) IndicatorRelease(g_sqKCEMA[i]);
      if(g_sqATR[i]   != INVALID_HANDLE) IndicatorRelease(g_sqATR[i]);
   }
}

// Track first-position candle for "DontSameCandle" guard
void TrackInitialCandle(int g){
   datetime curBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   for(int sd=0; sd<2; sd++){
      int cnt = CountGroupPositions(g, sd, 0);
      if(cnt == 0){
         g_initialCandleTime[g][sd] = 0;
      } else if(g_initialCandleTime[g][sd] == 0){
         // First time we see a position on this side → record the bar
         g_initialCandleTime[g][sd] = curBar;
      }
   }
}

void OnTick(){
   if(!InpAllowTrade){ DrawDashboard(); return; }
   RefreshSqueezeState(); // [v1.6] update squeeze cache once per tick

   // [v1.6] Optional close-on-expansion (default off)
   if(InpSQ_Enable && InpSQ_CloseOnExpansion && g_sqExpCount >= InpSQ_MinExpansionTFs){
      // safety: do not auto-close matched groups (Triple-Gate handles them)
      // intentionally left as a no-op stub to avoid touching trade.PositionClose flow
   }

   for(int g=1; g<=InpMaxGroups; g++){
      bool hasPos = GroupHasAnyPositions(g);
      bool hasPend= GroupHasAnyPendings(g);
      if(!hasPos && !hasPend){
         // group empty: reset trackers
         if(g_stripped[g]) g_stripped[g] = false;
         g_blockNewOrders[g] = false;
         ResetMaxDDPerSide(g);
         g_initialCandleTime[g][0]=0; g_initialCandleTime[g][1]=0;
         g_maxGridTrailSL[g][0]=0;    g_maxGridTrailSL[g][1]=0;
         g_maxGridTrailArmed[g][0]=false; g_maxGridTrailArmed[g][1]=false;
         g_avgTPSynced[g][0]=0; g_avgTPSynced[g][1]=0;
         g_avgSLSynced[g][0]=0; g_avgSLSynced[g][1]=0;
         continue;
      }
      EnforceFrameMutualExclusion(g);
      TrackInitialCandle(g);
      ManageInitialTrailOnBarClose(g); // [v1.8] bar-close trail (preferred)
      ManageInitialTrail(g);   // [v1.7] legacy trigger trail (skipped if bar-close ON)
      ManageInitialReArm(g);   // [v1.7] re-arm side stop after TP
      TryPlaceGridLoss(g);
      TryPlaceGridProfit(g);
      ManageGroupHedgeArm(g);

      // Auto-strip broker TP/SL when main + hedge coexist (matched set)
      if(IsGroupHedgeMatched(g) && !g_stripped[g]){
         StripBrokerTPSL_OnHedgeMatch(g);
      }

      // Update max DD per side (only useful pre-match)
      UpdateMaxDDPerSide(g);

      // Max Grid Average Trailing Stop (pre-match only)
      ManageMaxGridTrailing(g);

      // Average TP/SL Manager (only acts pre-match)
      CheckAndCloseByAverageTP(g);
      CheckAndCloseByAverageSL(g);

      // [v1.3] Sync Avg TP/SL → Broker (or restore Initial TP when count<MinTickets)
      SyncSideTPSLToBroker(g, 0);
      SyncSideTPSLToBroker(g, 1);

      // Triple-Gate Matching Close (only acts when matched)
      TryMatchingCloseForGroup(g);

      // Chart visualization
      DrawAverageAndTPLinesForGroup(g);
   }

   ManageGlobalAccumulateClose(); // [v2.0] account-wide accumulate close + dashboard cache
   TryAdvanceToNextGroup();
   DrawDashboard();
}
