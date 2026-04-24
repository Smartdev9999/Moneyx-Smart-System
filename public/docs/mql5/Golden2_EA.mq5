//+------------------------------------------------------------------+
//|                                                   Golden2_EA.mq5 |
//|                                    Copyright 2025, MoneyX Smart  |
//|     Golden2 EA v1.0 - Multiplier Pending-Stop Hedging (50 sets)  |
//+------------------------------------------------------------------+
#property copyright "MoneyX"
#property link      "https://moneyx.com"
#property version   "1.00"
#property description "Golden2 EA v1.0 - Pending Buy/Sell Stop frame + Multiplier Grid + Group-based Pending Hedge (arm/disarm) + Triple-Gate Matching Close + Sequential Queue (max 50 groups)"
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

//================ INPUTS ================
//--- General
input long             InpMagic              = 22220001;     // Magic number
input int              InpSlippage           = 30;           // Slippage (points)
input bool             InpAllowTrade         = true;         // Master allow trade
input bool             InpVerboseLog         = true;         // Verbose log

//--- Frame & Initial
input double           InpInitialLot         = 0.01;         // Initial lot (G_IN)
input double           InpMultiplier         = 2.0;          // Multiplier per grid level
input int              InpMaxGridLevels      = 4;            // Max grid loss levels (GL#1..#N)
input int              InpFrameUpperPips     = 200;          // BUY_STOP distance from mid (points)
input int              InpFrameLowerPips     = 200;          // SELL_STOP distance from mid (points)
input int              InpInitialTPPips      = 300;          // Initial TP (points) (0=off)
input int              InpInitialSLPips      = 0;            // Initial SL (points) (0=off)
input int              InpGridStepPips       = 200;          // Grid step (points)
input int              InpGridProfitTPPips   = 300;          // Grid TP (points)

//--- Hedging
input double           InpHedgeTriggerUSD    = 1000.0;       // Hedge trigger (USD floating loss target)
input double           InpHedgeArmPercent    = 80.0;         // Arm pending hedge when DD% reaches
input double           InpHedgeDisarmPercent = 70.0;         // Disarm pending hedge when DD% drops below
input bool             InpHedgeLotMatch1to1  = true;         // Hedge lots match opposite side 1:1
input int              InpHedge_OpenDelayMin = 0;            // Cooldown minutes between hedges (0=off)
input ENUM_HEDGE_DELAY_MODE_G2 InpHedge_OpenDelayMode = G2_HDELAY_BOTH; // Cooldown reference

//--- Group / Queue
input int              InpMaxGroups          = 50;           // Max active groups (1..50)
input bool             InpSequentialQueue    = true;         // Process one group at a time

//--- Exit Triple Gate
input ENUM_TIMEFRAMES  InpExitTF             = PERIOD_H4;    // Higher TF for Expansion->Normal gate
input int              InpExitBBPeriod       = 20;           // BB period
input double           InpExitBBDev          = 2.0;          // BB deviation
input int              InpExitKeltnerATR     = 20;           // Keltner ATR period
input double           InpExitKeltnerMult    = 1.5;          // Keltner multiplier
input int              InpExitBreakoutPips   = 300;          // Breakout distance from average (points)
input double           InpExitMinNetUSD      = 1.0;          // Min net USD profit to allow exit

//--- Dashboard
input bool             InpShowDashboard      = true;
input int              InpDashX              = 10;
input int              InpDashY              = 20;
input color            InpDashColor          = clrWhite;

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

int g_bbHandle = INVALID_HANDLE;
int g_atrHandle = INVALID_HANDLE;

//================ HELPERS: comments / parsing ================
string SidePrefix(ENUM_SIDE s){ return (s==SIDE_BUY?"B":"S"); }

string MakeComment(int g, bool hedge, string tag){
   // Examples: G1_IN, G1_GL#1, G1_HD_IN, G1_HD_GL#3, G1_GP#1, G1_HD_GP#2
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
int CountGroupPositions(int g, int sideFilter /*-1=any,0=buy,1=sell*/, int hedgeFilter /*-1=any,0=main,1=hedge*/){
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

double GroupFloatingPL(int g, int sideFilter /*-1/0/1*/, int hedgeFilter /*-1/0/1*/){
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

void DeleteGroupPendings(int g, int hedgeFilter /*-1=any,0=main,1=hedge*/){
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
   else { ref = MathMax((long)g_lastHedgeOpenTime, (long)g_lastHedgeCloseTime); }
   if(ref == 0) return false;
   long elapsed = (long)TimeCurrent() - (long)ref;
   long need    = (long)InpHedge_OpenDelayMin * 60;
   if(elapsed >= need) return false;
   remainSec = (int)(need - elapsed);
   return true;
}

//================ EXPANSION->NORMAL GATE (BB vs Keltner on InpExitTF) ================
bool IsExpansionToNormal(){
   // Compare last closed bar (1) vs (2): expansion = BB_width > Keltner_width
   double bbU[3], bbL[3], bbM[3], atr[3];
   if(g_bbHandle == INVALID_HANDLE || g_atrHandle == INVALID_HANDLE) return false;
   if(CopyBuffer(g_bbHandle, 1, 0, 3, bbU) <= 0) return false; // upper
   if(CopyBuffer(g_bbHandle, 2, 0, 3, bbL) <= 0) return false; // lower
   if(CopyBuffer(g_bbHandle, 0, 0, 3, bbM) <= 0) return false; // middle
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
   // Returns smallest group# in [1..InpMaxGroups] with no positions and no pendings.
   for(int g=1; g<=InpMaxGroups; g++){
      if(!GroupHasAnyPositions(g) && !GroupHasAnyPendings(g)) return g;
   }
   return -1;
}

int FindActiveTradingGroup(){
   // Highest group# with positions/pendings (the "current" cycle being traded)
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
      PrintFormat("Golden2 v1.0: BuyStop failed G%d err=%d", g, GetLastError());
   if(!trade.SellStop(InpInitialLot, dnPx, _Symbol, slDn, tpDn, ORDER_TIME_GTC, 0, cSell))
      PrintFormat("Golden2 v1.0: SellStop failed G%d err=%d", g, GetLastError());
   if(InpVerboseLog)
      PrintFormat("Golden2 v1.0: Placed initial frame G%d mid=%.5f up=%.5f dn=%.5f", g, mid, upPx, dnPx);
}

// When one side triggers, remove the opposite pending IN of same group
void EnforceFrameMutualExclusion(int g){
   bool hasBuyPos  = (CountGroupPositions(g, 0, 0) > 0);
   bool hasSellPos = (CountGroupPositions(g, 1, 0) > 0);
   if(!hasBuyPos && !hasSellPos) return;
   // delete remaining IN pending of opposite side
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

//================ MAIN GRID (after IN triggered, price reverses) ================
double LotForLevel(int level){
   // level=0 -> initial, 1 -> *m, 2 -> *m^2 ...
   double l = InpInitialLot;
   for(int i=0;i<level;i++) l *= InpMultiplier;
   double minL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step>0) l = MathRound(l/step)*step;
   if(l<minL) l = minL;
   return NormalizeDouble(l, 2);
}

int HighestGridLevel(int g, ENUM_SIDE side, bool hedge, string family /*"GL" or "GP"*/){
   // returns highest #N seen for tag family on this side
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

void TryPlaceGridLoss(int g){
   // For main side (non-hedge): if a side has positions and price moved against by step, add GL
   for(int sd=0; sd<2; sd++){
      int posCount = CountGroupPositions(g, sd, 0);
      if(posCount <= 0) continue;
      int gl = HighestGridLevel(g, (ENUM_SIDE)sd, false, "GL");
      if(gl >= InpMaxGridLevels) continue;
      // last main entry price for this side
      double lastPrice = LastEntryPrice(g, sd, false);
      if(lastPrice <= 0) continue;
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      bool trigger = false;
      if(sd==0) trigger = (ask <= lastPrice - InpGridStepPips*g_point); // buy adds when price drops
      else      trigger = (bid >= lastPrice + InpGridStepPips*g_point); // sell adds when price rises
      if(!trigger) continue;
      double lot = LotForLevel(gl+1);
      string c = MakeComment(g, false, StringFormat("GL#%d", gl+1));
      double tp = 0.0; // TP managed by average exit gate; keep 0
      bool ok = (sd==0) ? trade.Buy(lot, _Symbol, ask, 0, tp, c)
                        : trade.Sell(lot, _Symbol, bid, 0, tp, c);
      if(InpVerboseLog) PrintFormat("Golden2 v1.0: GL#%d %s G%d lot=%.2f ok=%d", gl+1, sd==0?"BUY":"SELL", g, lot, ok);
   }
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

//================ HEDGING (per group) ================
// Determine the "loss side" of the group (the side currently floating loss) for hedging purposes
int GroupLossSide(int g){
   double pBuy  = GroupFloatingPL(g, 0, 0);
   double pSell = GroupFloatingPL(g, 1, 0);
   if(pBuy < 0 && pSell >= 0) return 0;
   if(pSell < 0 && pBuy >= 0) return 1;
   if(pBuy < 0 && pSell < 0) return (pBuy < pSell ? 0 : 1);
   return -1;
}

void PlaceHedgePendingSet(int g, int lossSide){
   // Hedge side = opposite of lossSide. Place 1:1 lots stacked at one price.
   // Price chosen so that AT THE TRIGGER, total floating loss across group = InpHedgeTriggerUSD.
   // Simplification: place at current price ± InpFrameUpperPips/2 in trigger direction.
   int hedgeSide = (lossSide==0)?1:0;
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   // pending price beyond current adverse direction by small offset to ensure pending status
   double offsetPts = MathMax(50, InpGridStepPips/4);
   double price;
   if(hedgeSide==1) price = NormalizeDouble(bid - offsetPts*g_point, g_digits); // sell stop below
   else             price = NormalizeDouble(ask + offsetPts*g_point, g_digits); // buy stop above

   // Mirror lots from loss side (1:1)
   // IN
   double lotIN = InpInitialLot;
   string c = MakeComment(g, true, "IN");
   bool ok;
   if(hedgeSide==1) ok = trade.SellStop(lotIN, price, _Symbol, 0, 0, ORDER_TIME_GTC, 0, c);
   else             ok = trade.BuyStop (lotIN, price, _Symbol, 0, 0, ORDER_TIME_GTC, 0, c);
   if(InpVerboseLog) PrintFormat("Golden2 v1.0: HD_IN G%d %s lot=%.2f price=%.5f ok=%d",
      g, hedgeSide==1?"SELL_STOP":"BUY_STOP", lotIN, price, ok);
   // GL#1..#N matching opposing side levels actually present
   int oppMaxLvl = HighestGridLevel(g, (ENUM_SIDE)lossSide, false, "GL");
   for(int lvl=1; lvl<=oppMaxLvl; lvl++){
      double lot = LotForLevel(lvl);
      string cg = MakeComment(g, true, StringFormat("GL#%d", lvl));
      bool ok2;
      // small intra-stack offset to satisfy brokers that reject duplicate price stops
      double pStack = price + ((hedgeSide==1?-1:1) * lvl * 1 * g_point);
      pStack = NormalizeDouble(pStack, g_digits);
      if(hedgeSide==1) ok2 = trade.SellStop(lot, pStack, _Symbol, 0, 0, ORDER_TIME_GTC, 0, cg);
      else             ok2 = trade.BuyStop (lot, pStack, _Symbol, 0, 0, ORDER_TIME_GTC, 0, cg);
      if(InpVerboseLog) PrintFormat("Golden2 v1.0: HD_GL#%d G%d lot=%.2f price=%.5f ok=%d", lvl, g, lot, pStack, ok2);
   }
   g_lastHedgeOpenTime = TimeCurrent();
}

void ManageGroupHedgeArm(int g){
   // Skip if hedge already exists (positions OR pendings)
   bool hedgePosExists = (CountGroupPositions(g,-1,1) > 0);
   bool hedgePendingExists = (CountGroupPendingsByTagPrefix(g, true, "") > 0);

   double lossUSD = -MathMin(GroupFloatingPL(g,0,0), GroupFloatingPL(g,1,0));
   if(lossUSD < 0) lossUSD = 0;
   double pct = (InpHedgeTriggerUSD>0) ? (lossUSD * 100.0 / InpHedgeTriggerUSD) : 0.0;

   if(!hedgePosExists && hedgePendingExists){
      // disarm if pct dropped below disarm threshold
      if(pct < InpHedgeDisarmPercent){
         DeleteGroupPendings(g, 1);
         if(InpVerboseLog) PrintFormat("Golden2 v1.0: HD DISARM G%d pct=%.1f", g, pct);
      }
      return;
   }
   if(hedgePosExists) return;

   if(pct >= InpHedgeArmPercent){
      // cooldown check
      int rem = 0;
      if(IsHedgeOpenDelayActive(rem)){
         if(TimeCurrent() - g_lastDelayLog >= 60){
            PrintFormat("Golden2 v1.0: HEDGE DELAY wait %dm%02ds before arming new hedge", rem/60, rem%60);
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

// When a hedge IN gets triggered (becomes a position) -> open next group
bool GroupHedgeJustActivated(int g){
   // hedge has at least 1 position
   return (CountGroupPositions(g, -1, 1) > 0);
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

   // Determine winning side
   double plBuyMain   = GroupFloatingPL(g, 0, 0);
   double plSellMain  = GroupFloatingPL(g, 1, 0);
   double plBuyHedge  = GroupFloatingPL(g, 0, 1);
   double plSellHedge = GroupFloatingPL(g, 1, 1);

   bool priceUp = (mid > avgMid);
   // Winning side closes as a basket; losing side gets shred-closed using the basket profit.
   int winSide = priceUp ? 0 : 1;
   int losSide = priceUp ? 1 : 0;

   // Sum profit on winning side (across main + hedge of that direction)
   double winProfit = (winSide==0) ? (plBuyMain + plBuyHedge) : (plSellMain + plSellHedge);
   double netCheck = plBuyMain+plSellMain+plBuyHedge+plSellHedge;
   if(netCheck < InpExitMinNetUSD) return;

   if(!ClaimMutex(g)) return;

   // 1) Close all winning side positions in this group
   CloseAllGroupSide(g, winSide);

   // 2) Shred-close losing side from most-profitable to least until pool drains
   double pool = winProfit;
   ShredCloseLosingSide(g, losSide, pool);

   g_lastHedgeCloseTime = TimeCurrent();
   ReleaseMutex(g);

   // 3) After shred, if leftover orders remain on losing side, place next grid level
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
   // Sort losing-side tickets by profit desc and close while pool covers their loss with min residual
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
   // bubble sort desc
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
         // can absorb this position (positive helps; negative consumes pool)
         if(PositionSelectByTicket(tickets[i])){
            if(trade.PositionClose(tickets[i])) pool += p;
         }
      } else {
         break;
      }
   }
}

void PlaceContinuationGridIfNeeded(int g){
   // After shred, if losing side still has positions -> place next GL based on highest level present
   for(int sd=0; sd<2; sd++){
      for(int hd=0; hd<2; hd++){
         int cnt = CountGroupPositions(g, sd, hd);
         if(cnt <= 0) continue;
         int gl = HighestGridLevel(g, (ENUM_SIDE)sd, (hd==1), "GL");
         if(gl >= InpMaxGridLevels) continue;
         // continuation: next level placed at current adverse price (market)
         double lot = LotForLevel(gl+1);
         string c = MakeComment(g, hd==1, StringFormat("GL#%d", gl+1));
         double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         bool ok = (sd==0) ? trade.Buy(lot,_Symbol,ask,0,0,c) : trade.Sell(lot,_Symbol,bid,0,0,c);
         if(InpVerboseLog) PrintFormat("Golden2 v1.0: Continuation GL#%d %s G%d hedge=%d lot=%.2f ok=%d",
            gl+1, sd==0?"BUY":"SELL", g, hd, lot, ok);
      }
   }
}

//================ CYCLE / GROUP LIFECYCLE ================
void TryAdvanceToNextGroup(){
   // If current trading group has hedge activated, open next group's frame
   int cur = FindActiveTradingGroup();
   if(cur < 1) {
      // no group active -> create G1
      int g = FindLowestIdleGroup();
      if(g >= 1) PlaceInitialFrame(g);
      return;
   }
   // If current group has hedge active and next slot is free -> place next group's initial frame
   if(GroupHedgeJustActivated(cur)){
      if(cur < InpMaxGroups){
         int next = cur + 1;
         if(!GroupHasAnyPositions(next) && !GroupHasAnyPendings(next)){
            PlaceInitialFrame(next);
         }
      } else {
         static datetime lastWarn = 0;
         if(TimeCurrent() - lastWarn >= 300){
            Print("Golden2 v1.0: Reached InpMaxGroups limit, no new group will be opened.");
            lastWarn = TimeCurrent();
         }
      }
   }
}

//================ DASHBOARD ================
void DrawDashboard(){
   if(!InpShowDashboard) return;
   string txt = "Golden2 EA v1.0\n";
   txt += StringFormat("Symbol: %s  Magic: %I64d\n", _Symbol, (long)InpMagic);
   int rem = 0;
   if(IsHedgeOpenDelayActive(rem)) txt += StringFormat("HedgeDelay: WAIT %dm%02ds\n", rem/60, rem%60);
   else txt += "HedgeDelay: READY\n";
   txt += StringFormat("Queue mutex: %s\n", g_activeOpsGroup<0?"IDLE":StringFormat("G%d", g_activeOpsGroup));
   txt += "------------------------------\n";
   for(int g=1; g<=InpMaxGroups; g++){
      if(!GroupHasAnyPositions(g) && !GroupHasAnyPendings(g)) continue;
      double mainL = GroupTotalLot(g,-1,0);
      double hedgeL= GroupTotalLot(g,-1,1);
      double pl    = GroupFloatingPL(g,-1,-1);
      double lossUSD = -MathMin(GroupFloatingPL(g,0,0), GroupFloatingPL(g,1,0));
      if(lossUSD<0) lossUSD=0;
      double pct = (InpHedgeTriggerUSD>0) ? (lossUSD*100.0/InpHedgeTriggerUSD) : 0;
      txt += StringFormat("G%d  mainL=%.2f hdgL=%.2f  PL=%.2f  arm=%.0f%%\n",
                          g, mainL, hedgeL, pl, pct);
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

   g_bbHandle  = iBands(_Symbol, InpExitTF, InpExitBBPeriod, 0, InpExitBBDev, PRICE_CLOSE);
   g_atrHandle = iATR(_Symbol, InpExitTF, InpExitKeltnerATR);
   if(g_bbHandle == INVALID_HANDLE || g_atrHandle == INVALID_HANDLE){
      Print("Golden2 v1.0: indicator init failed");
      return INIT_FAILED;
   }

   PrintFormat("Golden2 EA v1.0 initialized | Magic=%I64d | MaxGroups=%d", (long)InpMagic, InpMaxGroups);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason){
   ObjectDelete(0, g_dashName);
   if(g_bbHandle != INVALID_HANDLE) IndicatorRelease(g_bbHandle);
   if(g_atrHandle != INVALID_HANDLE) IndicatorRelease(g_atrHandle);
}

void OnTick(){
   if(!InpAllowTrade){ DrawDashboard(); return; }

   // 1) For every active group: enforce frame, manage grid, hedge arming, matching close
   for(int g=1; g<=InpMaxGroups; g++){
      if(!GroupHasAnyPositions(g) && !GroupHasAnyPendings(g)) continue;
      EnforceFrameMutualExclusion(g);
      TryPlaceGridLoss(g);
      ManageGroupHedgeArm(g);
      TryMatchingCloseForGroup(g);
   }

   // 2) Spawn next group if current group activated its hedge (or create G1 if idle)
   TryAdvanceToNextGroup();

   // 3) Dashboard
   DrawDashboard();
}
