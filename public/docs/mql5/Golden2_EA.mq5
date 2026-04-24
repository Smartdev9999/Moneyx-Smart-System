//+------------------------------------------------------------------+
//|                                                   Golden2_EA.mq5 |
//|                                    Copyright 2025, MoneyX Smart  |
//|     Golden2 EA v1.2 - Gold-Miner-style Grid Settings             |
//|     (Grid Loss / Max Grid Trailing / Grid Profit) + v1.1 features|
//+------------------------------------------------------------------+
#property copyright "MoneyX"
#property link      "https://moneyx.com"
#property version   "1.30"
#property description "Golden2 EA v1.3 - Initial TP (1-order) + Auto-switch to Average TP/SL on Broker (>=2 orders, Gold-Miner style) + Gold-Miner Grid (Loss/Profit/Max-Grid-Trailing) + Group-based Pending Hedge + Auto-strip Broker TP/SL on hedge match + Triple-Gate Matching Close + Sequential Queue (max 50 groups)"
#property strict

#include <Trade/Trade.mqh>

CTrade trade;

//================ ENUMS ================
enum ENUM_SIDE { SIDE_BUY=0, SIDE_SELL=1 };

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
input double  InpInitialLot           = 0.01;                        // Initial lot (G_IN)
input int     InpFrameUpperPips       = 200;                         // BUY_STOP distance from mid (points)
input int     InpFrameLowerPips       = 200;                         // SELL_STOP distance from mid (points)
input int     InpInitialTPPips        = 300;                         // Initial TP (points) (0=off)
input int     InpInitialSLPips        = 0;                           // Initial SL (points) (0=off)

//--- === Grid Loss Side === (Gold Miner-style)
input string  __sec_grid_loss__       = "=== Grid Loss Side ===";    // ---
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
input bool    InpTP_UsePctMaxDD       = false;                       // Use TP % of Max Drawdown (per side)
input double  InpTP_PctMaxDD          = 50.0;                        // TP DD % (target = X% of max DD)
input bool    InpTP_ShowAvgLine       = true;                        // Show Average Price Line
input bool    InpTP_ShowTPLine        = true;                        // Show TP Line
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
input double  InpHedgeTriggerUSD      = 1000.0;                      // Hedge trigger (USD floating loss target)
input double  InpHedgeArmPercent      = 80.0;                        // Arm pending hedge when DD% reaches
input double  InpHedgeDisarmPercent   = 70.0;                        // Disarm pending hedge when DD% drops below
input bool    InpHedgeLotMatch1to1    = true;                        // Hedge lots match opposite side 1:1
input int     InpHedge_OpenDelayMin   = 0;                           // Cooldown minutes between hedges (0=off)
input ENUM_HEDGE_DELAY_MODE_G2 InpHedge_OpenDelayMode = G2_HDELAY_BOTH; // Cooldown reference

//--- === Exit Triple Gate ===
input string  __sec_exit__            = "=== Exit Triple Gate ==="; // ---
input ENUM_TIMEFRAMES InpExitTF       = PERIOD_H4;                   // Higher TF for Expansion->Normal gate
input int     InpExitBBPeriod         = 20;                          // BB period
input double  InpExitBBDev            = 2.0;                         // BB deviation
input int     InpExitKeltnerATR       = 20;                          // Keltner ATR period
input double  InpExitKeltnerMult      = 1.5;                         // Keltner multiplier
input int     InpExitBreakoutPips     = 300;                         // Breakout distance from average (points)
input double  InpExitMinNetUSD        = 1.0;                         // Min net USD profit to allow exit

//--- === Dashboard ===
input string  __sec_dash__            = "=== Dashboard ===";         // ---
input bool    InpShowDashboard        = true;                        // Show dashboard
input int     InpDashX                = 10;                          // Dashboard X
input int     InpDashY                = 20;                          // Dashboard Y
input color   InpDashColor            = clrWhite;                    // Dashboard color

//================ GLOBALS ================
double g_point;
double g_pipMul;       // 1.0 (using points directly)
int    g_digits;
int    g_activeOpsGroup = -1;       // mutex (-1 = idle)
datetime g_activeOpsClaimedAt = 0;

datetime g_lastHedgeOpenTime  = 0;
datetime g_lastHedgeCloseTime = 0;
datetime g_lastDelayLog       = 0;

string g_dashName = "Golden2_DASH";
string g_linePrefix = "G2L_";  // chart line objects prefix

int g_bbHandle = INVALID_HANDLE;
int g_atrHandle = INVALID_HANDLE;
int g_atrLossHandle   = INVALID_HANDLE;
int g_atrProfitHandle = INVALID_HANDLE;

bool   g_stripped[51];          // per-group flag: broker TP/SL stripped after hedge match
double g_maxDDPerSide[51][2];   // [group][side] track max floating loss USD seen (positive value)

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

//================ MUTEX (sequential queue) ================
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
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double mid = (ask+bid)*0.5;
   double upPx = NormalizeDouble(mid + InpFrameUpperPips * g_point, g_digits);
   double dnPx = NormalizeDouble(mid - InpFrameLowerPips * g_point, g_digits);
   double tpUp = (InpInitialTPPips>0) ? NormalizeDouble(upPx + InpInitialTPPips*g_point, g_digits) : 0.0;
   double slUp = (InpInitialSLPips>0) ? NormalizeDouble(upPx - InpInitialSLPips*g_point, g_digits) : 0.0;
   double tpDn = (InpInitialTPPips>0) ? NormalizeDouble(dnPx - InpInitialTPPips*g_point, g_digits) : 0.0;
   double slDn = (InpInitialSLPips>0) ? NormalizeDouble(dnPx + InpInitialSLPips*g_point, g_digits) : 0.0;

   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippage);

   string cBuy  = MakeComment(g, false, "IN");
   string cSell = MakeComment(g, false, "IN");

   if(!trade.BuyStop(InpInitialLot, upPx, _Symbol, slUp, tpUp, ORDER_TIME_GTC, 0, cBuy))
      PrintFormat("Golden2 v1.1: BuyStop failed G%d err=%d", g, GetLastError());
   if(!trade.SellStop(InpInitialLot, dnPx, _Symbol, slDn, tpDn, ORDER_TIME_GTC, 0, cSell))
      PrintFormat("Golden2 v1.1: SellStop failed G%d err=%d", g, GetLastError());
   if(InpVerboseLog)
      PrintFormat("Golden2 v1.1: Placed initial frame G%d mid=%.5f up=%.5f dn=%.5f", g, mid, upPx, dnPx);
}

void EnforceFrameMutualExclusion(int g){
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
   for(int sd=0; sd<2; sd++){
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

      // OnlyNewCandle / DontSameCandle guards
      datetime curBar = iTime(_Symbol, PERIOD_CURRENT, 0);
      if(GridLoss_OnlyNewCandle && g_lastGridCandleLoss[g][sd] == curBar) continue;
      if(GridLoss_DontSameCandle && g_initialCandleTime[g][sd] == curBar) continue;

      // Candle confirmation (N consecutive closed candles in the loss direction)
      if(GridLoss_CandleConfirm > 0){
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
   if(IsGroupHedgeMatched(g)) return; // pre-hedge only
   for(int sd=0; sd<2; sd++){
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

      datetime curBar = iTime(_Symbol, PERIOD_CURRENT, 0);
      if(GridProfit_OnlyNewCandle && g_lastGridCandleProfit[g][sd] == curBar) continue;

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

void PlaceHedgePendingSet(int g, int lossSide){
   int hedgeSide = (lossSide==0)?1:0;
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double offsetPts = MathMax(50, InpGridStepPips/4);
   double price;
   if(hedgeSide==1) price = NormalizeDouble(bid - offsetPts*g_point, g_digits);
   else             price = NormalizeDouble(ask + offsetPts*g_point, g_digits);

   double lotIN = InpInitialLot;
   string c = MakeComment(g, true, "IN");
   bool ok;
   if(hedgeSide==1) ok = trade.SellStop(lotIN, price, _Symbol, 0, 0, ORDER_TIME_GTC, 0, c);
   else             ok = trade.BuyStop (lotIN, price, _Symbol, 0, 0, ORDER_TIME_GTC, 0, c);
   if(InpVerboseLog) PrintFormat("Golden2 v1.1: HD_IN G%d %s lot=%.2f price=%.5f ok=%d",
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
      if(InpVerboseLog) PrintFormat("Golden2 v1.1: HD_GL#%d G%d lot=%.2f price=%.5f ok=%d", lvl, g, lot, pStack, ok2);
   }
   g_lastHedgeOpenTime = TimeCurrent();
}

void ManageGroupHedgeArm(int g){
   bool hedgePosExists = (CountGroupPositions(g,-1,1) > 0);
   bool hedgePendingExists = (CountGroupPendingsByTagPrefix(g, true, "") > 0);

   double lossUSD = -MathMin(GroupFloatingPL(g,0,0), GroupFloatingPL(g,1,0));
   if(lossUSD < 0) lossUSD = 0;
   double pct = (InpHedgeTriggerUSD>0) ? (lossUSD * 100.0 / InpHedgeTriggerUSD) : 0.0;

   if(!hedgePosExists && hedgePendingExists){
      if(pct < InpHedgeDisarmPercent){
         DeleteGroupPendings(g, 1);
         if(InpVerboseLog) PrintFormat("Golden2 v1.1: HD DISARM G%d pct=%.1f", g, pct);
      }
      return;
   }
   if(hedgePosExists) return;

   if(pct >= InpHedgeArmPercent){
      int rem = 0;
      if(IsHedgeOpenDelayActive(rem)){
         if(TimeCurrent() - g_lastDelayLog >= 60){
            PrintFormat("Golden2 v1.1: HEDGE DELAY wait %dm%02ds before arming new hedge", rem/60, rem%60);
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

   // 5) Accumulate close (group-wide)
   if(InpTP_UseAccumulateClose){
      double netGroup = GroupFloatingPL(g,-1,-1);
      if(netGroup >= InpTP_AccumulateTarget){
         if(InpVerboseLog) PrintFormat("Golden2 v1.1: TP AccumClose G%d net=%.2f >= %.2f", g, netGroup, InpTP_AccumulateTarget);
         CloseAllPositionsOfGroup(g);
         return;
      }
   }

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

void DrawHLine(string name, double price, color clr){
   if(price <= 0) return;
   if(ObjectFind(0, name) < 0){
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
   }
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
      if(InpTP_ShowAvgLine) DrawHLine(nmAvg, avg, sd==0?InpTP_AvgBuyColor:InpTP_AvgSellColor);
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

   PlaceContinuationGridIfNeeded(g);
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
void TryAdvanceToNextGroup(){
   int cur = FindActiveTradingGroup();
   if(cur < 1) {
      int g = FindLowestIdleGroup();
      if(g >= 1) PlaceInitialFrame(g);
      return;
   }
   if(GroupHedgeJustActivated(cur)){
      if(cur < InpMaxGroups){
         int next = cur + 1;
         if(!GroupHasAnyPositions(next) && !GroupHasAnyPendings(next)){
            PlaceInitialFrame(next);
         }
      } else {
         static datetime lastWarn = 0;
         if(TimeCurrent() - lastWarn >= 300){
            Print("Golden2 v1.1: Reached InpMaxGroups limit, no new group will be opened.");
            lastWarn = TimeCurrent();
         }
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

void DrawDashboard(){
   if(!InpShowDashboard) return;
   string txt = "Golden2 EA v1.2\n";
   txt += StringFormat("Symbol: %s  Magic: %I64d\n", _Symbol, (long)InpMagic);
   int rem = 0;
   if(IsHedgeOpenDelayActive(rem)) txt += StringFormat("HedgeDelay: WAIT %dm%02ds\n", rem/60, rem%60);
   else txt += "HedgeDelay: READY\n";
   txt += StringFormat("Queue mutex: %s\n", g_activeOpsGroup<0?"IDLE":StringFormat("G%d", g_activeOpsGroup));
   txt += StringFormat("TP-Stripped: %s\n", StrippedListString());
   txt += StringFormat("MaxGridTrail: %s (Mode %d)\n",
                       MaxGrid_TrailEnable?"ON":"OFF", MaxGrid_TrailMode);
   txt += "------------------------------\n";
   for(int g=1; g<=InpMaxGroups; g++){
      if(!GroupHasAnyPositions(g) && !GroupHasAnyPendings(g)) continue;
      double mainL = GroupTotalLot(g,-1,0);
      double hedgeL= GroupTotalLot(g,-1,1);
      double pl    = GroupFloatingPL(g,-1,-1);
      double lossUSD = -MathMin(GroupFloatingPL(g,0,0), GroupFloatingPL(g,1,0));
      if(lossUSD<0) lossUSD=0;
      double pct = (InpHedgeTriggerUSD>0) ? (lossUSD*100.0/InpHedgeTriggerUSD) : 0;
      string match = IsGroupHedgeMatched(g) ? " [MATCHED]" : "";
      int glB = HighestGridLevel(g, SIDE_BUY,  false, "GL");
      int glS = HighestGridLevel(g, SIDE_SELL, false, "GL");
      int gpB = HighestGridLevel(g, SIDE_BUY,  false, "GP");
      int gpS = HighestGridLevel(g, SIDE_SELL, false, "GP");
      txt += StringFormat("G%d  mainL=%.2f hdgL=%.2f  PL=%.2f  arm=%.0f%%%s\n",
                          g, mainL, hedgeL, pl, pct, match);
      txt += StringFormat("  GL B%d/%d S%d/%d  GP B%d/%d S%d/%d\n",
                          glB, GridLoss_MaxTrades, glS, GridLoss_MaxTrades,
                          gpB, GridProfit_MaxTrades, gpS, GridProfit_MaxTrades);
      if(!IsGroupHedgeMatched(g) && GroupHasAnyPositions(g)){
         double avgB = GroupAveragePrice(g, 0, 0);
         double avgS = GroupAveragePrice(g, 1, 0);
         if(avgB>0) txt += StringFormat("  B avg=%.5f tp=%.5f", avgB, ComputeAvgTPPrice(g,0));
         if(avgB>0 && g_maxGridTrailArmed[g][0]) txt += StringFormat(" trail=%.5f", g_maxGridTrailSL[g][0]);
         if(avgB>0) txt += "\n";
         if(avgS>0) txt += StringFormat("  S avg=%.5f tp=%.5f", avgS, ComputeAvgTPPrice(g,1));
         if(avgS>0 && g_maxGridTrailArmed[g][1]) txt += StringFormat(" trail=%.5f", g_maxGridTrailSL[g][1]);
         if(avgS>0) txt += "\n";
      }
   }
   if(ObjectFind(0, g_dashName) < 0){
      ObjectCreate(0, g_dashName, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, g_dashName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, g_dashName, OBJPROP_XDISTANCE, InpDashX);
      ObjectSetInteger(0, g_dashName, OBJPROP_YDISTANCE, InpDashY);
      ObjectSetInteger(0, g_dashName, OBJPROP_COLOR, InpDashColor);
      ObjectSetInteger(0, g_dashName, OBJPROP_FONTSIZE, 9);
      ObjectSetString (0, g_dashName, OBJPROP_FONT, "Consolas");
   }
   ObjectSetString(0, g_dashName, OBJPROP_TEXT, txt);
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
      g_maxGridTrailSL[i][0]=0; g_maxGridTrailSL[i][1]=0;
      g_maxGridTrailArmed[i][0]=false; g_maxGridTrailArmed[i][1]=false;
   }

   g_bbHandle  = iBands(_Symbol, InpExitTF, InpExitBBPeriod, 0, InpExitBBDev, PRICE_CLOSE);
   g_atrHandle = iATR(_Symbol, InpExitTF, InpExitKeltnerATR);
   g_atrLossHandle   = iATR(_Symbol, GridLoss_ATR_TF,   GridLoss_ATR_Period);
   g_atrProfitHandle = iATR(_Symbol, GridProfit_ATR_TF, GridProfit_ATR_Period);
   if(g_bbHandle == INVALID_HANDLE || g_atrHandle == INVALID_HANDLE){
      Print("Golden2 v1.2: indicator init failed");
      return INIT_FAILED;
   }

   PrintFormat("Golden2 EA v1.2 initialized | Magic=%I64d | MaxGroups=%d", (long)InpMagic, InpMaxGroups);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason){
   ObjectDelete(0, g_dashName);
   CleanupAllLinesByPrefix();
   if(g_bbHandle != INVALID_HANDLE) IndicatorRelease(g_bbHandle);
   if(g_atrHandle != INVALID_HANDLE) IndicatorRelease(g_atrHandle);
   if(g_atrLossHandle != INVALID_HANDLE)   IndicatorRelease(g_atrLossHandle);
   if(g_atrProfitHandle != INVALID_HANDLE) IndicatorRelease(g_atrProfitHandle);
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

   for(int g=1; g<=InpMaxGroups; g++){
      bool hasPos = GroupHasAnyPositions(g);
      bool hasPend= GroupHasAnyPendings(g);
      if(!hasPos && !hasPend){
         // group empty: reset trackers
         if(g_stripped[g]) g_stripped[g] = false;
         ResetMaxDDPerSide(g);
         g_initialCandleTime[g][0]=0; g_initialCandleTime[g][1]=0;
         g_maxGridTrailSL[g][0]=0;    g_maxGridTrailSL[g][1]=0;
         g_maxGridTrailArmed[g][0]=false; g_maxGridTrailArmed[g][1]=false;
         continue;
      }
      EnforceFrameMutualExclusion(g);
      TrackInitialCandle(g);
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

      // Triple-Gate Matching Close (only acts when matched)
      TryMatchingCloseForGroup(g);

      // Chart visualization
      DrawAverageAndTPLinesForGroup(g);
   }

   TryAdvanceToNextGroup();
   DrawDashboard();
}
