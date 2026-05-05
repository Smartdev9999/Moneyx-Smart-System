//+------------------------------------------------------------------+
//|                                            Golden_Kuy3_EA.mq5    |
//|                                       Golden Kuy3 EA  v1.41      |
//|  v1.41: Fix NonHero count compile reference after Hero port       |
//|  v1.40: Hero Order ported from Gold Miner v7.09                  |
//|         (single-side lock, no gen, cycle-based, lock-profit BE-SL)|
//+------------------------------------------------------------------+
#property copyright "Golden Kuy3 EA"
#property version   "1.41"
#property description "Golden Kuy3 v1.41 — Fix NonHero count compile reference after Hero port"
#property strict

#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>

CTrade           trade;
CPositionInfo    pos;

//============================ INPUTS ===============================
enum ENUM_GK_SIDE_MODE { GK_SIDE_BOTH=0, GK_SIDE_BUY_ONLY=1, GK_SIDE_SELL_ONLY=2 };
enum ENUM_GK_GRID_SIDE { GK_GRID_BOTH=0, GK_GRID_UP_ONLY=1, GK_GRID_DOWN_ONLY=2 };
enum ENUM_GK_GRID_LOT  { GK_LOT_FIXED=0, GK_LOT_ADD=1, GK_LOT_MULTIPLY=2 };

input group "=== General ==="
input long                 InpMagicNumber          = 33001;
input ENUM_GK_SIDE_MODE    InpInitSideMode         = GK_SIDE_BOTH;
input double               InpInitialLot           = 0.01;
input double               InpInitialTPPips        = 200.0;     // 0 = none, also overridden by InpUseTakeProfit/Points
input double               InpInitialSLPips        = 0.0;       // 0 = none
input bool                 InpAutoReEntry          = true;
input int                  InpReEntryCooldownSec   = 5;
input int                  InpSlippagePoints       = 30;

input group "=== Grid (single set) ==="
input bool                 InpEnableGrid           = true;
input ENUM_GK_GRID_SIDE    InpGridSideMode         = GK_GRID_BOTH;
input double               InpGridDistancePips     = 150.0;
input ENUM_GK_GRID_LOT     InpGridLotMode          = GK_LOT_MULTIPLY;
input double               InpGridLotValue         = 1.5;
input int                  InpMaxGridOrders        = 20;
input bool                 InpGridOnlyNewCandle    = true;
input ENUM_TIMEFRAMES      InpGridCandleTF         = PERIOD_M1;
input bool                 InpEnableCostHitRestart = false;     // re-open initial-lot when SL/TP closes a ticket
input double               InpCostHitMinSpacingPips= 100.0;     // min distance from nearest same-side position
input int                  InpCostHitCooldownSec   = 2;

input group "=== Per-Order Break-Even Lock ==="
input bool                 InpEnableBreakevenLock     = true;     // lock cost on each ticket independently
input double               InpBreakevenActivationPips = 200.0;    // profit pips required before locking
input double               InpBreakevenBufferPips     = 10.0;     // SL = open ± buffer

input group "=== Per-Order Trailing Stop ==="
input bool                 InpEnableTrailingStop      = false;    // trail SL after BE
input double               InpTrailingActivationPips  = 250.0;    // profit pips needed before trailing kicks in
input double               InpTrailingStepPips        = 20.0;     // distance trailed behind price

input group "=== Take Profit ==="
input bool                 InpUseTakeProfit           = true;     // master TP switch
input bool                 InpUseTPFixedDollar        = false;
input double               InpTPDollarAmount          = 100.0;
input bool                 InpUseTPPoints             = true;     // push broker TP at avg ± points
input double               InpTPPointsFromAverage     = 500.0;
input bool                 InpUseTPPercentBalance     = false;
input double               InpTPPercentOfBalance      = 26.0;
input bool                 InpUseAccumulateClose      = false;
input double               InpAccumulateTarget        = 20000.0;
input int                  InpAvgTP_MinOrders         = 2;

input group "=== Average Trailing Stop ==="
input bool                 InpEnableAvgTrailing       = true;
input double               InpAvgTrail_ActivationPips = 100.0;
input double               InpAvgTrail_StepPips       = 20.0;
input double               InpAvgTrail_BE_Buffer      = 20.0;
input int                  InpAvgTrail_MinOrders      = 3;
input bool                 InpAvgTrail_Strict2Cross   = true;
input double               InpAvgTrail_UnderAvgBuffer = 50.0;

input group "===== Hero Order (v7.09) ====="
input bool   InpHero_Enabled            = false;  // Enable Hero Order (opposite-side helper)
input int    InpHero_OrderCount         = 2;      // Hero count per side — N newest become Hero
input int    InpHero_MinOrdersToActivate= 5;      // Min orders on side before Hero activates (0=OrderCount+1)
input int    InpHero_BE_OffsetPoints    = 50;     // Lock-profit BE-SL offset in POINTS (SELL=open-offset, BUY=open+offset)
input bool   InpHero_BlockSameSideGrid  = true;   // Block new entries on side that has Hero survivor only
input bool   InpHero_IncludeInMaxOrders = true;   // Count Hero into MaxGridOrders cap
input int    InpHero_PostCloseGraceSec  = 5;      // Seconds after Hero close to suppress re-tag
input bool   InpHero_SingleSideLock     = true;   // Only ONE side may own Hero at a time (sleep opposite first activation)
input bool   InpHero_CloseWithOpposite  = true;   // [DEPRECATED] hard-wired to opposite-basket close
input bool   InpHero_RequireNetProfit   = false;  // [DEPRECATED] not used (lock-profit SL guarantees floor)

input group "=== Chart Lines ==="
input bool                 InpShowAvgLine             = true;
input color                InpAvgBuyLineColor         = clrDodgerBlue;
input color                InpAvgSellLineColor        = clrOrangeRed;
input bool                 InpShowTPLine              = true;
input color                InpTPBuyLineColor          = clrLime;
input color                InpTPSellLineColor         = clrMagenta;

input group "=== Dashboard ==="
input bool                 InpShowDashboard        = true;
input int                  InpDashRefreshSec       = 1;
input int                  InpDashX                = 10;
input int                  InpDashY                = 20;
input int                  InpDashRowH             = 16;
input int                  InpDashColW1            = 150;
input int                  InpDashColW2            = 170;
input color                InpDashTextColor        = clrWhite;
input color                InpDashHeaderColor      = clrAqua;
input color                InpDashRowBgColor       = C'15,15,30';
input color                InpDashAltRowBgColor    = C'25,25,45';
input color                InpDashHeaderBgColor    = C'40,40,80';

//========================= GLOBALS =================================
double  g_pip            = 0.0;
double  g_point          = 0.0;
int     g_digits         = 0;
double  g_stopsLevel     = 0.0;

datetime g_lastReEntry_Buy   = 0;
datetime g_lastReEntry_Sell  = 0;
datetime g_lastGridBar_Buy   = 0;
datetime g_lastGridBar_Sell  = 0;

double  g_initPrice_Buy  = 0.0;
double  g_initPrice_Sell = 0.0;

bool    g_avgTrail_Active_Buy   = false;
bool    g_avgTrail_Active_Sell  = false;
double  g_avgTrail_SL_Buy       = 0.0;
double  g_avgTrail_SL_Sell      = 0.0;
bool    g_avgTrail_ArmReady_Buy  = false;
bool    g_avgTrail_ArmReady_Sell = false;

datetime g_lastDashTime    = 0;
datetime g_lastTpClearScan = 0;
double   g_realizedCycle   = 0.0;
bool     g_tpStripped      = false;

string g_dashPrefix = "GK_DASH_";
string g_linePrefix = "GK_LINE_";

// v1.2 cost-hit restart
bool     g_costHit_Pending_Buy  = false;
bool     g_costHit_Pending_Sell = false;
double   g_costHit_Price_Buy    = 0.0;
double   g_costHit_Price_Sell   = 0.0;
datetime g_costHit_Time_Buy     = 0;
datetime g_costHit_Time_Sell    = 0;

// v1.2 dashboard high-water row tracker (no full wipe each refresh)
int      g_dashRowMax = 0;

// v1.4 Hero Order state (ported from Gold Miner v7.09 — no gen)
ulong    g_heroTickets[200];
int      g_heroTicketCount        = 0;
datetime g_heroLastBuildTime      = 0;
int      g_heroPhase_Buy          = 0;     // 0=NONE 2=ARMED 3=BE_GUARD
int      g_heroPhase_Sell         = 0;
bool     g_heroBE_Applied_Buy     = false;
bool     g_heroBE_Applied_Sell    = false;
datetime g_heroJustClosed_Buy     = 0;
datetime g_heroJustClosed_Sell    = 0;
// Dashboard counters
int      g_heroDash_BuyActive     = 0;
int      g_heroDash_SellActive    = 0;
int      g_heroDash_BuyTagged     = 0;
int      g_heroDash_SellTagged    = 0;
ulong    g_heroDash_BuyTickets[10];
int      g_heroDash_BuyTicketN    = 0;
ulong    g_heroDash_SellTickets[10];
int      g_heroDash_SellTicketN   = 0;

//========================= HELPERS =================================
double PipsToPrice(double pips) { return pips * g_pip; }
double PriceToPips(double pr)   { return (g_pip>0) ? pr / g_pip : 0; }

string MakeInitComment(int side) { return (side==POSITION_TYPE_BUY) ? "GK_INIT_BUY" : "GK_INIT_SELL"; }
string MakeGridComment(int side, int idx)
{
   return StringFormat("GK_GRID_%s_%d", (side==POSITION_TYPE_BUY?"BUY":"SELL"), idx);
}

bool IsOurPosition()
{
   return (pos.Magic() == InpMagicNumber && pos.Symbol() == _Symbol);
}

int CountSide(int side, string &lastCommentOut, ulong &lastTicketOut, double &lastLotOut, double &lastPriceOut)
{
   int n = 0;
   ulong bestTicket = 0;
   lastCommentOut = "";
   lastLotOut = 0; lastPriceOut = 0; lastTicketOut = 0;

   for(int i=PositionsTotal()-1; i>=0; i--)
   {
      if(!pos.SelectByIndex(i)) continue;
      if(!IsOurPosition()) continue;
      if((int)pos.PositionType() != side) continue;
      n++;
      ulong tk = pos.Ticket();
      if(tk > bestTicket) {
         bestTicket = tk;
         lastCommentOut = pos.Comment();
         lastLotOut     = pos.Volume();
         lastPriceOut   = pos.PriceOpen();
         lastTicketOut  = tk;
      }
   }
   return n;
}

int CountSideSimple(int side)
{
   int n=0;
   for(int i=PositionsTotal()-1;i>=0;i--){
      if(!pos.SelectByIndex(i)) continue;
      if(!IsOurPosition()) continue;
      if((int)pos.PositionType()!=side) continue;
      n++;
   }
   return n;
}

double CalcSideAvgPrice(int side, double &totalLotOut, int &countOut)
{
   double sumLP=0, sumL=0;
   int n=0;
   for(int i=PositionsTotal()-1;i>=0;i--){
      if(!pos.SelectByIndex(i)) continue;
      if(!IsOurPosition()) continue;
      if((int)pos.PositionType()!=side) continue;
      sumLP += pos.PriceOpen()*pos.Volume();
      sumL  += pos.Volume();
      n++;
   }
   totalLotOut = sumL;
   countOut = n;
   return (sumL>0 ? sumLP/sumL : 0.0);
}

double CalcSideFloating(int side)
{
   double pl=0;
   for(int i=PositionsTotal()-1;i>=0;i--){
      if(!pos.SelectByIndex(i)) continue;
      if(!IsOurPosition()) continue;
      if((int)pos.PositionType()!=side) continue;
      pl += pos.Profit() + pos.Swap() + pos.Commission();
   }
   return pl;
}

//============== HERO ORDER (ported from Gold Miner v7.09) ==========
// Single-side lock, cycle-based, no gen, no hedge.
// Phase per side: 0=NONE, 2=ARMED (locked, basket alive), 3=BE_GUARD (basket cleared, lock-profit SL applied)

// v7.08: Owner = side at phase==BE_GUARD (basket cleared). ARMED is just CANDIDATE.
int GetHeroOwnerSide()
{
   bool buyOwns  = (g_heroPhase_Buy  == 3);
   bool sellOwns = (g_heroPhase_Sell == 3);
   if(buyOwns && !sellOwns)  return (int)POSITION_TYPE_BUY;
   if(sellOwns && !buyOwns)  return (int)POSITION_TYPE_SELL;
   return -1;
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

// Count basket orders on a side (excluding Hero) — used for survivor-block + reset detection.
int CountNonHeroMainOnSide(ENUM_POSITION_TYPE side)
{
   int n = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL)  != _Symbol)        continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != side) continue;
      if(IsHeroTicket(ticket)) continue;
      n++;
   }
   return n;
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

// v6.94: Block new same-side entries only when Hero survives ALONE (basket=0).
bool ShouldBlockSameSideGridForHero(ENUM_POSITION_TYPE side)
{
   if(!InpHero_Enabled || !InpHero_BlockSameSideGrid) return false;
   if(CountHeroOnSide(side) <= 0) return false;
   return (CountNonHeroMainOnSide(side) == 0);
}

void BuildHeroTicketCache()
{
   // v6.98: rebuild every tick — Hero set is always latest N on each side.
   if(!InpHero_Enabled || InpHero_OrderCount <= 0) { g_heroTicketCount = 0; return; }
   g_heroLastBuildTime = TimeCurrent();
   g_heroTicketCount = 0;

   int sideTotalActive[2] = {0, 0};
   int sideHeroTagged[2]  = {0, 0};

   // v7.04 Single-Side Lock — owner decided ONLY at phase==BE_GUARD.
   int activeOwner = -1;
   if(InpHero_SingleSideLock) activeOwner = GetHeroOwnerSide();

   for(int s = 0; s < 2; s++)
   {
      ENUM_POSITION_TYPE side = (s == 0) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
      ulong  tkPool[200]; long ttMs[200]; int nPool = 0;
      int    nAll = 0;

      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
         if(PositionGetString(POSITION_SYMBOL)  != _Symbol)        continue;
         if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != side) continue;
         nAll++;
         if(nPool < 200) {
            tkPool[nPool] = ticket;
            ttMs[nPool]   = PositionGetInteger(POSITION_TIME_MSC);
            nPool++;
         }
      }
      sideTotalActive[s] = nAll;

      // Sort newest first (POSITION_TIME_MSC desc, then ticket desc)
      for(int a = 1; a < nPool; a++)
         for(int b = a; b > 0; b--)
         {
            bool swap = false;
            if(ttMs[b] > ttMs[b-1]) swap = true;
            else if(ttMs[b] == ttMs[b-1] && tkPool[b] > tkPool[b-1]) swap = true;
            if(!swap) break;
            long _t = ttMs[b]; ttMs[b] = ttMs[b-1]; ttMs[b-1] = _t;
            ulong _k = tkPool[b]; tkPool[b] = tkPool[b-1]; tkPool[b-1] = _k;
         }

      int sideId = (int)side;
      int curPhase = (sideId == POSITION_TYPE_BUY) ? g_heroPhase_Buy : g_heroPhase_Sell;

      // v7.03 Post-close grace
      datetime jc = (sideId == POSITION_TYPE_BUY) ? g_heroJustClosed_Buy : g_heroJustClosed_Sell;
      if(jc > 0 && (TimeCurrent() - jc) < InpHero_PostCloseGraceSec) {
         if(sideId == POSITION_TYPE_BUY) g_heroPhase_Buy = 0; else g_heroPhase_Sell = 0;
         continue;
      }

      int activateThreshold = (InpHero_MinOrdersToActivate > 0)
                              ? InpHero_MinOrdersToActivate
                              : (InpHero_OrderCount + 1);

      // v7.04 Single-side lock — block first activation on non-owner side
      if(InpHero_SingleSideLock && curPhase == 0 && activeOwner >= 0 && sideId != activeOwner) {
         if(sideId == POSITION_TYPE_BUY) g_heroPhase_Buy = 0; else g_heroPhase_Sell = 0;
         continue;
      }

      // Activation gate ONLY for first tag (sticky after that)
      if(curPhase == 0 && nAll < activateThreshold) continue;
      if(nPool <= 0) continue;

      // v7.01 Sticky tag rolling latest-N
      int take;
      if(curPhase == 0) take = MathMin(InpHero_OrderCount, nPool - 1);
      else              take = MathMin(InpHero_OrderCount, nPool);
      if(take <= 0) continue;

      if(sideId == POSITION_TYPE_BUY) {
         g_heroDash_BuyTicketN = 0;
         for(int k = 0; k < take && g_heroDash_BuyTicketN < 10; k++)
            g_heroDash_BuyTickets[g_heroDash_BuyTicketN++] = tkPool[k];
      } else {
         g_heroDash_SellTicketN = 0;
         for(int k = 0; k < take && g_heroDash_SellTicketN < 10; k++)
            g_heroDash_SellTickets[g_heroDash_SellTicketN++] = tkPool[k];
      }

      for(int k = 0; k < take && g_heroTicketCount < 200; k++)
         g_heroTickets[g_heroTicketCount++] = tkPool[k];
      sideHeroTagged[s] += take;
   }

   // v7.09 Auto-release ownership when phase==BE_GUARD but Hero tickets=0
   if(g_heroPhase_Buy == 3 && sideHeroTagged[0] == 0) {
      Print("v7.09 Hero AUTO-RELEASE BUY: phase=BE_GUARD but Hero tickets=0 — releasing owner lock");
      g_heroPhase_Buy = 0; g_heroBE_Applied_Buy = false; g_heroJustClosed_Buy = TimeCurrent();
   }
   if(g_heroPhase_Sell == 3 && sideHeroTagged[1] == 0) {
      Print("v7.09 Hero AUTO-RELEASE SELL: phase=BE_GUARD but Hero tickets=0 — releasing owner lock");
      g_heroPhase_Sell = 0; g_heroBE_Applied_Sell = false; g_heroJustClosed_Sell = TimeCurrent();
   }

   // Phase NONE -> ARMED auto-promote (BE_GUARD set elsewhere)
   if(g_heroPhase_Buy  != 3) g_heroPhase_Buy  = (sideHeroTagged[0] > 0) ? 2 : 0;
   if(g_heroPhase_Sell != 3) g_heroPhase_Sell = (sideHeroTagged[1] > 0) ? 2 : 0;

   g_heroDash_BuyActive  = sideTotalActive[0];
   g_heroDash_SellActive = sideTotalActive[1];
   g_heroDash_BuyTagged  = sideHeroTagged[0];
   g_heroDash_SellTagged = sideHeroTagged[1];
   if(sideHeroTagged[0] == 0) g_heroDash_BuyTicketN = 0;
   if(sideHeroTagged[1] == 0) g_heroDash_SellTicketN = 0;

   // Audit log every 30s
   static datetime lastHeroAuditLog = 0;
   if(TimeCurrent() - lastHeroAuditLog >= 30) {
      int minAct = (InpHero_MinOrdersToActivate > 0) ? InpHero_MinOrdersToActivate : (InpHero_OrderCount + 1);
      string roleB = (g_heroPhase_Buy  == 3) ? "OWNER" : (g_heroPhase_Buy  == 2) ? "CANDIDATE" : "NONE";
      string roleS = (g_heroPhase_Sell == 3) ? "OWNER" : (g_heroPhase_Sell == 2) ? "CANDIDATE" : "NONE";
      int    ownerSide = GetHeroOwnerSide();
      string ownerStr  = (ownerSide == (int)POSITION_TYPE_BUY)  ? "BUY"
                       : (ownerSide == (int)POSITION_TYPE_SELL) ? "SELL" : "NONE";
      Print("v1.4 Hero AUDIT: BUY ", roleB, " active=", sideTotalActive[0],
            " hero=", sideHeroTagged[0], " phase=", g_heroPhase_Buy,
            " | SELL ", roleS, " active=", sideTotalActive[1],
            " hero=", sideHeroTagged[1], " phase=", g_heroPhase_Sell,
            " | OWNER=", ownerStr, " threshold=", minAct, " HeroCount=", InpHero_OrderCount);
      lastHeroAuditLog = TimeCurrent();
   }
}

// v7.02 SL validation (FIXED comparisons)
double ComputeHeroLockProfitSL(ENUM_POSITION_TYPE posType, double openPrice)
{
   double offset = (double)InpHero_BE_OffsetPoints * g_point;
   if(posType == POSITION_TYPE_SELL) return NormalizeDouble(openPrice - offset, g_digits);
   if(posType == POSITION_TYPE_BUY)  return NormalizeDouble(openPrice + offset, g_digits);
   return 0;
}

bool ValidateHeroLockProfitSL(ENUM_POSITION_TYPE posType, double sl)
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double minDist = g_stopsLevel * g_point;
   if(posType == POSITION_TYPE_SELL) return (sl > 0 && sl > (ask + minDist));
   if(posType == POSITION_TYPE_BUY)  return (sl > 0 && sl < (bid - minDist));
   return false;
}

void ApplyHeroLockProfitSL(ENUM_POSITION_TYPE side)
{
   int applied = 0, skipped = 0;
   string slList = "";
   for(int i = 0; i < g_heroTicketCount; i++) {
      ulong ticket = g_heroTickets[i];
      if(!PositionSelectByTicket(ticket)) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != side) continue;
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double curTP     = PositionGetDouble(POSITION_TP);
      double curSL     = PositionGetDouble(POSITION_SL);
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double newSL = ComputeHeroLockProfitSL(posType, openPrice);
      if(!ValidateHeroLockProfitSL(posType, newSL)) { skipped++; continue; }
      if(NormalizeDouble(curSL, g_digits) == NormalizeDouble(newSL, g_digits) &&
         NormalizeDouble(curTP, g_digits) == 0) continue;
      if(trade.PositionModify(ticket, newSL, 0)) {
         applied++;
         slList += StringFormat(" #%I64u@%s", ticket, DoubleToString(newSL, g_digits));
      }
   }
   if(applied > 0)
      Print("v1.4 Hero BE_GUARD applied side=", EnumToString(side),
            " count=", applied, " skipped=", skipped, " (lock-profit SL):", slList);
}

void StripBrokerTPSLFromHeroTickets()
{
   if(!InpHero_Enabled || g_heroTicketCount == 0) return;
   for(int i = 0; i < g_heroTicketCount; i++) {
      ulong ticket = g_heroTickets[i];
      if(!PositionSelectByTicket(ticket)) continue;
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      int phase = (posType == POSITION_TYPE_BUY) ? g_heroPhase_Buy : g_heroPhase_Sell;
      if(phase == 3) continue; // BE_GUARD owns it
      double curTP = PositionGetDouble(POSITION_TP);
      double curSL = PositionGetDouble(POSITION_SL);
      if(curTP == 0 && curSL == 0) continue;
      trade.PositionModify(ticket, 0, 0);
   }
}

void CloseHeroOnSide(ENUM_POSITION_TYPE side, string reason)
{
   for(int i = g_heroTicketCount - 1; i >= 0; i--)
   {
      ulong ticket = g_heroTickets[i];
      if(!PositionSelectByTicket(ticket)) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != side) continue;
      trade.PositionClose(ticket);
      Print("v1.4 Hero CLOSE: ticket=", ticket, " side=", EnumToString(side), " reason=", reason);
   }
   g_heroTicketCount = 0;
   g_heroLastBuildTime = 0;
   if(side == POSITION_TYPE_BUY) {
      g_heroPhase_Buy = 0; g_heroBE_Applied_Buy = false;
      g_heroJustClosed_Buy = TimeCurrent();
   } else {
      g_heroPhase_Sell = 0; g_heroBE_Applied_Sell = false;
      g_heroJustClosed_Sell = TimeCurrent();
   }
}

bool DetectSameSideBasketClearedForHero(ENUM_POSITION_TYPE side)
{
   if(!InpHero_Enabled) return false;
   if(CountHeroOnSide(side) <= 0) return false;
   if(CountNonHeroMainOnSide(side) > 0) return false;
   return true;
}

void ResetHeroStateIfFlat(ENUM_POSITION_TYPE side)
{
   if(CountHeroOnSide(side) > 0) return;
   if(CountNonHeroMainOnSide(side) > 0) return;
   if(side == POSITION_TYPE_BUY) {
      if(g_heroPhase_Buy != 0 || g_heroBE_Applied_Buy)
         Print("v1.4 Hero RESET side=BUY (flat)");
      g_heroPhase_Buy = 0; g_heroBE_Applied_Buy = false;
   } else {
      if(g_heroPhase_Sell != 0 || g_heroBE_Applied_Sell)
         Print("v1.4 Hero RESET side=SELL (flat)");
      g_heroPhase_Sell = 0; g_heroBE_Applied_Sell = false;
   }
}

// v6.96 Master orchestrator — runs every tick after BuildHeroTicketCache().
void ManageHeroOppositeClose()
{
   if(!InpHero_Enabled) return;

   StripBrokerTPSLFromHeroTickets();

   for(int s = 0; s < 2; s++) {
      ENUM_POSITION_TYPE side = (s == 0) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
      bool already = (side == POSITION_TYPE_BUY) ? g_heroBE_Applied_Buy : g_heroBE_Applied_Sell;
      if(!already && DetectSameSideBasketClearedForHero(side)) {
         if(side == POSITION_TYPE_BUY)  g_heroPhase_Buy  = 3;
         else                            g_heroPhase_Sell = 3;
         ApplyHeroLockProfitSL(side);
         if(side == POSITION_TYPE_BUY)  g_heroBE_Applied_Buy  = true;
         else                            g_heroBE_Applied_Sell = true;
      }
      int phase = (side == POSITION_TYPE_BUY) ? g_heroPhase_Buy : g_heroPhase_Sell;
      if(phase == 3 && CountHeroOnSide(side) > 0) ApplyHeroLockProfitSL(side);
      ResetHeroStateIfFlat(side);
   }

   // v7.02 Tick-based opposite-clear detector (Broker TP race)
   for(int s2 = 0; s2 < 2; s2++) {
      ENUM_POSITION_TYPE side = (s2 == 0) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
      ENUM_POSITION_TYPE opp  = (s2 == 0) ? POSITION_TYPE_SELL : POSITION_TYPE_BUY;
      int phase = (side == POSITION_TYPE_BUY) ? g_heroPhase_Buy : g_heroPhase_Sell;
      if(phase != 3) continue;
      if(CountHeroOnSide(side) <= 0) continue;
      if(CountNonHeroMainOnSide(opp) > 0) continue;
      if(CountHeroOnSide(opp) > 0) continue;
      Print("v1.4 Hero CLOSE (opp basket flat tick): heroSide=", EnumToString(side),
            " oppSide=", EnumToString(opp), " heroProfit=", DoubleToString(SumHeroProfitOnSide(side), 2));
      CloseHeroOnSide(side, "OppositeBasketFlatTick");
   }
}

// v1.4 helper: latest Hero-close timestamp across both sides — used by Cost-Hit grace.
datetime GetHeroLastCloseTime()
{
   datetime t = g_heroJustClosed_Buy;
   if(g_heroJustClosed_Sell > t) t = g_heroJustClosed_Sell;
   return t;
}

int NextGridIndex(int side)
{
   int maxIdx = 0;
   for(int i=PositionsTotal()-1;i>=0;i--){
      if(!pos.SelectByIndex(i)) continue;
      if(!IsOurPosition()) continue;
      if((int)pos.PositionType()!=side) continue;
      string c = pos.Comment();
      string prefix = (side==POSITION_TYPE_BUY) ? "GK_GRID_BUY_" : "GK_GRID_SELL_";
      int p = StringFind(c, prefix);
      if(p==0){
         int n = (int)StringToInteger(StringSubstr(c, StringLen(prefix)));
         if(n>maxIdx) maxIdx = n;
      }
   }
   return maxIdx + 1;
}

double NormalizeLot(double lot)
{
   double minL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stp  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(lot < minL) lot = minL;
   if(lot > maxL) lot = maxL;
   if(stp > 0)    lot = MathRound(lot/stp)*stp;
   return NormalizeDouble(lot, 2);
}

double CalcGridLot(double lastLot)
{
   double v    = InpGridLotValue;
   double base = (lastLot>0 ? lastLot : InpInitialLot);
   double raw  = InpInitialLot;
   if(InpGridLotMode == GK_LOT_FIXED)         raw = v;
   else if(InpGridLotMode == GK_LOT_ADD)      raw = base + v;
   else if(InpGridLotMode == GK_LOT_MULTIPLY) raw = base * v;

   double stp  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxL = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double out  = raw;

   // ADD/MULTIPLY: ceil to next step so small multipliers (e.g. 1.1 * 0.01) actually grow
   if(InpGridLotMode==GK_LOT_ADD || InpGridLotMode==GK_LOT_MULTIPLY){
      if(stp>0) out = MathCeil(raw/stp)*stp;
      // Force >= base + 1 step so chain always grows
      if(stp>0 && out <= base + g_point) out = base + stp;
   } else {
      if(stp>0) out = MathRound(raw/stp)*stp;
   }

   if(out < minL) out = minL;
   if(out > maxL) out = maxL;
   out = NormalizeDouble(out, 2);

   if(InpGridLotMode==GK_LOT_ADD || InpGridLotMode==GK_LOT_MULTIPLY)
      Print("GK CalcGridLot mode=",(InpGridLotMode==GK_LOT_ADD?"ADD":"MULT"),
            " base=",base," v=",v," raw=",raw," out=",out);
   return out;
}

// v1.2 distance guard helper — true if any same-side position is within minPips of refPrice
bool HasNearbyPosition(int side, double refPrice, double minPips)
{
   double minDist = PipsToPrice(minPips);
   if(minDist<=0) return false;
   for(int i=PositionsTotal()-1;i>=0;i--){
      if(!pos.SelectByIndex(i)) continue;
      if(!IsOurPosition()) continue;
      if((int)pos.PositionType()!=side) continue;
      if(MathAbs(pos.PriceOpen() - refPrice) < minDist) return true;
   }
   return false;
}

bool SideAllowedForInit(int side)
{
   if(InpInitSideMode == GK_SIDE_BOTH)      return true;
   if(InpInitSideMode == GK_SIDE_BUY_ONLY)  return side == POSITION_TYPE_BUY;
   if(InpInitSideMode == GK_SIDE_SELL_ONLY) return side == POSITION_TYPE_SELL;
   return false;
}

double GetMinStopPrice() { return g_stopsLevel * g_point; }

bool IsTPAnyModeActive()
{
   if(!InpUseTakeProfit) return false;
   return (InpUseTPFixedDollar || InpUseTPPoints || InpUseTPPercentBalance || InpUseAccumulateClose);
}

//========================== ENTRY ==================================
bool OpenInitial(int side)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double price = (side==POSITION_TYPE_BUY)?ask:bid;
   double sl=0, tp=0;
   double minStop = GetMinStopPrice();

   // Initial TP only if master TP ON and Points mode is OFF (Points mode pushes its own TP later)
   if(InpUseTakeProfit && !InpUseTPPoints && InpInitialTPPips>0){
      double dist = MathMax(PipsToPrice(InpInitialTPPips), minStop);
      tp = (side==POSITION_TYPE_BUY)? price + dist : price - dist;
   }
   if(InpInitialSLPips>0){
      double dist = MathMax(PipsToPrice(InpInitialSLPips), minStop);
      sl = (side==POSITION_TYPE_BUY)? price - dist : price + dist;
   }

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippagePoints);
   bool ok=false;
   string cmt = MakeInitComment(side);
   if(side==POSITION_TYPE_BUY)  ok = trade.Buy(NormalizeLot(InpInitialLot), _Symbol, price, sl, tp, cmt);
   else                          ok = trade.Sell(NormalizeLot(InpInitialLot), _Symbol, price, sl, tp, cmt);
   if(ok){
      if(side==POSITION_TYPE_BUY){ g_initPrice_Buy = price; g_lastReEntry_Buy = TimeCurrent(); }
      else                       { g_initPrice_Sell= price; g_lastReEntry_Sell= TimeCurrent(); }
      Print("GK INIT ",(side==POSITION_TYPE_BUY?"BUY":"SELL")," @ ",DoubleToString(price,g_digits)," lot=",InpInitialLot);
   } else {
      Print("GK INIT FAIL ",(side==POSITION_TYPE_BUY?"BUY":"SELL")," err=",GetLastError());
   }
   return ok;
}

bool OpenGrid(int side, double lot, int idx)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double price = (side==POSITION_TYPE_BUY)?ask:bid;

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippagePoints);
   string cmt = MakeGridComment(side, idx);
   bool ok=false;
   if(side==POSITION_TYPE_BUY) ok = trade.Buy(NormalizeLot(lot), _Symbol, price, 0, 0, cmt);
   else                         ok = trade.Sell(NormalizeLot(lot), _Symbol, price, 0, 0, cmt);
   if(ok) Print("GK GRID ",cmt," lot=",lot," @ ",DoubleToString(price,g_digits));
   else   Print("GK GRID FAIL ",cmt," err=",GetLastError());
   return ok;
}

//===================== MANAGE INITIAL ==============================
void ManageInitialEntry()
{
   if(SideAllowedForInit(POSITION_TYPE_BUY)){
      int n = CountSideSimple(POSITION_TYPE_BUY);
      if(n==0 && (TimeCurrent()-g_lastReEntry_Buy) >= InpReEntryCooldownSec){
         if(g_lastReEntry_Buy==0 || InpAutoReEntry) OpenInitial(POSITION_TYPE_BUY);
      }
   }
   if(SideAllowedForInit(POSITION_TYPE_SELL)){
      int n = CountSideSimple(POSITION_TYPE_SELL);
      if(n==0 && (TimeCurrent()-g_lastReEntry_Sell) >= InpReEntryCooldownSec){
         if(g_lastReEntry_Sell==0 || InpAutoReEntry) OpenInitial(POSITION_TYPE_SELL);
      }
   }
}

//======================= MANAGE GRID ===============================
bool GridSideAllowed(bool isUp)
{
   if(InpGridSideMode == GK_GRID_BOTH)      return true;
   if(InpGridSideMode == GK_GRID_UP_ONLY)   return isUp;
   if(InpGridSideMode == GK_GRID_DOWN_ONLY) return !isUp;
   return false;
}

void ManageGridEntry()
{
   if(!InpEnableGrid) return;

   double dist = PipsToPrice(InpGridDistancePips);
   if(dist<=0) return;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   {
      string lc; ulong ltk; double llot, lprice;
      int n = CountSide(POSITION_TYPE_BUY, lc, ltk, llot, lprice);
      if(n>0 && (n-1) < InpMaxGridOrders){
         bool fire=false; bool isUp=false;
         if(ask >= lprice + dist){ fire=true;  isUp=true;  }
         if(bid <= lprice - dist){ fire=true;  isUp=false; }
         if(fire && GridSideAllowed(isUp)){
            if(InpGridOnlyNewCandle){
               datetime bar = (datetime)iTime(_Symbol, InpGridCandleTF, 0);
               if(bar == g_lastGridBar_Buy) fire=false;
               else g_lastGridBar_Buy = bar;
            }
            if(fire){
               double newLot = CalcGridLot(llot);
               double refPx  = (isUp?ask:bid);
               if(InpEnableCostHitRestart && HasNearbyPosition(POSITION_TYPE_BUY, refPx, InpCostHitMinSpacingPips)){
                  // skip — too close to an existing same-side ticket (post-restart guard)
               } else {
                  if(!ShouldBlockSameSideGridForHero(POSITION_TYPE_BUY))
                     OpenGrid(POSITION_TYPE_BUY, newLot, NextGridIndex(POSITION_TYPE_BUY));
               }
            }
         }
      }
   }

   {
      string lc; ulong ltk; double llot, lprice;
      int n = CountSide(POSITION_TYPE_SELL, lc, ltk, llot, lprice);
      if(n>0 && (n-1) < InpMaxGridOrders){
         bool fire=false; bool isUp=false;
         if(ask >= lprice + dist){ fire=true;  isUp=true;  }
         if(bid <= lprice - dist){ fire=true;  isUp=false; }
         if(fire && GridSideAllowed(isUp)){
            if(InpGridOnlyNewCandle){
               datetime bar = (datetime)iTime(_Symbol, InpGridCandleTF, 0);
               if(bar == g_lastGridBar_Sell) fire=false;
               else g_lastGridBar_Sell = bar;
            }
            if(fire){
               double newLot = CalcGridLot(llot);
               double refPx  = (isUp?ask:bid);
               if(InpEnableCostHitRestart && HasNearbyPosition(POSITION_TYPE_SELL, refPx, InpCostHitMinSpacingPips)){
                  // skip — too close
               } else {
                  if(!ShouldBlockSameSideGridForHero(POSITION_TYPE_SELL))
                     OpenGrid(POSITION_TYPE_SELL, newLot, NextGridIndex(POSITION_TYPE_SELL));
               }
            }
         }
      }
   }
}

//================ PER-ORDER BE LOCK + TRAILING =====================
// Returns target SL price (0 = no change). Combines BE lock + Trailing.
double ComputePerOrderSL(int side, double openPrice, double curBid, double curAsk)
{
   if(!InpEnableBreakevenLock && !InpEnableTrailingStop) return 0.0;

   double profitPips = (side==POSITION_TYPE_BUY)
                        ? PriceToPips(curBid - openPrice)
                        : PriceToPips(openPrice - curAsk);

   double slPrice = 0.0;
   bool   haveSL  = false;

   // Layer 1: Breakeven lock (only when ON and profit reached BE activation)
   if(InpEnableBreakevenLock && profitPips >= InpBreakevenActivationPips){
      double bePips = InpBreakevenBufferPips;
      slPrice = (side==POSITION_TYPE_BUY) ? openPrice + PipsToPrice(bePips)
                                          : openPrice - PipsToPrice(bePips);
      haveSL = true;
   }

   // Layer 2: Trailing — only when ON and profit reached trail activation
   if(InpEnableTrailingStop && profitPips >= InpTrailingActivationPips){
      double trailPips = profitPips - InpTrailingStepPips;
      // floor: BE buffer (don't trail tighter than BE if BE is on)
      double floorPips = InpEnableBreakevenLock ? InpBreakevenBufferPips : 0.0;
      if(trailPips < floorPips) trailPips = floorPips;
      double trailSL = (side==POSITION_TYPE_BUY) ? openPrice + PipsToPrice(trailPips)
                                                 : openPrice - PipsToPrice(trailPips);
      // pick the more protective SL
      if(!haveSL){ slPrice = trailSL; haveSL = true; }
      else {
         if(side==POSITION_TYPE_BUY  && trailSL > slPrice) slPrice = trailSL;
         if(side==POSITION_TYPE_SELL && trailSL < slPrice) slPrice = trailSL;
      }
   }

   return haveSL ? slPrice : 0.0;
}

void ManagePerOrderTrailing()
{
   if(!InpEnableBreakevenLock && !InpEnableTrailingStop) return;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double minStop = GetMinStopPrice();

   for(int i=PositionsTotal()-1;i>=0;i--){
      if(!pos.SelectByIndex(i)) continue;
      if(!IsOurPosition()) continue;
      if(IsHeroTicket(pos.Ticket())) continue; // v1.3: Hero managed separately
      int side = (int)pos.PositionType();
      double op = pos.PriceOpen();
      double curSL = pos.StopLoss();
      double newSL = ComputePerOrderSL(side, op, bid, ask);
      if(newSL<=0) continue;

      if(side==POSITION_TYPE_BUY){
         if(bid - newSL < minStop) newSL = bid - minStop;
         if(curSL>0 && newSL <= curSL + g_point) continue;
      } else {
         if(newSL - ask < minStop) newSL = ask + minStop;
         if(curSL>0 && newSL >= curSL - g_point) continue;
      }

      trade.PositionModify(pos.Ticket(), NormalizeDouble(newSL, g_digits), pos.TakeProfit());
   }
}

//==================== TAKE PROFIT (multi-mode) =====================
void CloseAllSide(int side)
{
   for(int i=PositionsTotal()-1;i>=0;i--){
      if(!pos.SelectByIndex(i)) continue;
      if(!IsOurPosition()) continue;
      if((int)pos.PositionType()!=side) continue;
      if(IsHeroTicket(pos.Ticket())) continue; // v1.3: never close Hero via per-side close
      trade.PositionClose(pos.Ticket());
   }
}

void CloseAllOurs()
{
   for(int i=PositionsTotal()-1;i>=0;i--){
      if(!pos.SelectByIndex(i)) continue;
      if(!IsOurPosition()) continue;
      if(IsHeroTicket(pos.Ticket())) continue; // v1.3
      trade.PositionClose(pos.Ticket());
   }
}

// v1.3 Floating excluding Hero tickets (per side)
double CalcSideFloating_NonHero(int side)
{
   double pl=0;
   for(int i=PositionsTotal()-1;i>=0;i--){
      if(!pos.SelectByIndex(i)) continue;
      if(!IsOurPosition()) continue;
      if((int)pos.PositionType()!=side) continue;
      if(IsHeroTicket(pos.Ticket())) continue;
      pl += pos.Profit() + pos.Swap() + pos.Commission();
   }
   return pl;
}

// v1.3 Avg price excl Hero only (per side)
double CalcSideAvgPrice_NonHero(int side, double &lotsOut, int &cntOut)
{
   double sumLP=0, sumL=0; int n=0;
   for(int i=PositionsTotal()-1;i>=0;i--){
      if(!pos.SelectByIndex(i)) continue;
      if(!IsOurPosition()) continue;
      if((int)pos.PositionType()!=side) continue;
      if(IsHeroTicket(pos.Ticket())) continue;
      sumLP += pos.PriceOpen()*pos.Volume();
      sumL  += pos.Volume();
      n++;
   }
   lotsOut=sumL; cntOut=n;
   return (sumL>0?sumLP/sumL:0.0);
}

// Strip stale broker TP from every ticket when no Points-TP mode is active
void EnforceClearTPIfDisabled()
{
   bool pointsActive = (InpUseTakeProfit && InpUseTPPoints);
   if(pointsActive) { g_tpStripped = false; return; }
   if(TimeCurrent() - g_lastTpClearScan < 5) return;
   g_lastTpClearScan = TimeCurrent();

   int cleared = 0;
   for(int i=PositionsTotal()-1;i>=0;i--){
      if(!pos.SelectByIndex(i)) continue;
      if(!IsOurPosition()) continue;
      if(IsHeroTicket(pos.Ticket())) continue; // v1.3: keep Hero SL/TP intact
      if(pos.TakeProfit() <= 0) continue;
      if(trade.PositionModify(pos.Ticket(), pos.StopLoss(), 0)) cleared++;
   }
   g_tpStripped = (cleared>0) || g_tpStripped;
}

void ManageTakeProfit()
{
   if(!InpUseTakeProfit) return;

   // 1. Accumulate (whole account) — realized + floating
   if(InpUseAccumulateClose && InpAccumulateTarget>0){
      double floatingAll = CalcSideFloating_NonHero(POSITION_TYPE_BUY) + CalcSideFloating_NonHero(POSITION_TYPE_SELL);
      if((g_realizedCycle + floatingAll) >= InpAccumulateTarget){
         Print("GK ACCUM CLOSE — realized=",DoubleToString(g_realizedCycle,2)," floating=",DoubleToString(floatingAll,2)," tgt=",InpAccumulateTarget);
         CloseAllOurs();
         return;
      }
   }

   double bal = AccountInfoDouble(ACCOUNT_BALANCE);

   for(int sideIdx=0; sideIdx<2; sideIdx++){
      int side = (sideIdx==0)?POSITION_TYPE_BUY:POSITION_TYPE_SELL;
      int n = CountNonHeroMainOnSide((ENUM_POSITION_TYPE)side); // v1.41 exclude Hero
      if(n<=0) continue;

      double pl = CalcSideFloating_NonHero(side); // v1.3

      // 2. Fixed dollar
      if(InpUseTPFixedDollar && InpTPDollarAmount>0 && pl >= InpTPDollarAmount){
         Print("GK TP DOLLAR ",(side==POSITION_TYPE_BUY?"BUY":"SELL")," PL=",DoubleToString(pl,2));
         CloseAllSide(side);
         continue;
      }

      // 3. % of balance
      if(InpUseTPPercentBalance && InpTPPercentOfBalance>0 && bal>0){
         double tgt = bal * InpTPPercentOfBalance / 100.0;
         if(pl >= tgt){
            Print("GK TP %BAL ",(side==POSITION_TYPE_BUY?"BUY":"SELL")," PL=",DoubleToString(pl,2)," tgt=",DoubleToString(tgt,2));
            CloseAllSide(side);
            continue;
         }
      }

      // 4. Points from average — push broker TP (Hero excluded from avg + skipped from modify)
      if(InpUseTPPoints && n >= InpAvgTP_MinOrders){
         double tot=0; int cnt=0;
         double avg = CalcSideAvgPrice_NonHero(side, tot, cnt);
         if(avg<=0) continue;
         double minStop = GetMinStopPrice();
         double tpDist = MathMax(InpTPPointsFromAverage * g_point, minStop);
         double tpPrice = (side==POSITION_TYPE_BUY)? avg + tpDist : avg - tpDist;
         tpPrice = NormalizeDouble(tpPrice, g_digits);
         for(int i=PositionsTotal()-1;i>=0;i--){
            if(!pos.SelectByIndex(i)) continue;
            if(!IsOurPosition()) continue;
            if((int)pos.PositionType()!=side) continue;
            if(IsHeroTicket(pos.Ticket())) continue; // v1.3
            if(MathAbs(pos.TakeProfit()-tpPrice) <= g_point*2) continue;
            trade.PositionModify(pos.Ticket(), pos.StopLoss(), tpPrice);
         }
      }
   }
}

//================ AVG TRAILING (Gold Miner v6.91) ==================
void ResetAvgTrailBuy()  { g_avgTrail_Active_Buy=false;  g_avgTrail_SL_Buy=0;  g_avgTrail_ArmReady_Buy=false; }
void ResetAvgTrailSell() { g_avgTrail_Active_Sell=false; g_avgTrail_SL_Sell=0; g_avgTrail_ArmReady_Sell=false;}

void ManageAverageTrailing()
{
   if(!InpEnableAvgTrailing) return;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double minStop = GetMinStopPrice();

   {
      double tot=0; int cnt=0;
      double avg = CalcSideAvgPrice_NonHero(POSITION_TYPE_BUY, tot, cnt); // v1.3
      if(cnt >= InpAvgTrail_MinOrders && avg>0){
         if(InpAvgTrail_Strict2Cross && !g_avgTrail_ArmReady_Buy){
            if(bid < avg - InpAvgTrail_UnderAvgBuffer*g_point) g_avgTrail_ArmReady_Buy = true;
         }
         double profitPips = PriceToPips(bid - avg);
         if(!g_avgTrail_Active_Buy){
            bool armOk = (!InpAvgTrail_Strict2Cross || g_avgTrail_ArmReady_Buy);
            if(armOk && profitPips >= InpAvgTrail_ActivationPips){
               g_avgTrail_Active_Buy = true;
               g_avgTrail_SL_Buy = avg + PipsToPrice(InpAvgTrail_BE_Buffer);
               Print("GK AVG-TRAIL BUY ARMED avg=",DoubleToString(avg,g_digits)," sl=",DoubleToString(g_avgTrail_SL_Buy,g_digits));
            }
         } else {
            double trailPips = profitPips - InpAvgTrail_StepPips;
            if(trailPips < InpAvgTrail_BE_Buffer) trailPips = InpAvgTrail_BE_Buffer;
            double newSL = avg + PipsToPrice(trailPips);
            if(newSL > g_avgTrail_SL_Buy) g_avgTrail_SL_Buy = newSL;

            if(bid <= g_avgTrail_SL_Buy){
               Print("GK AVG-TRAIL BUY HIT — closing all BUY");
               CloseAllSide(POSITION_TYPE_BUY);
               ResetAvgTrailBuy();
            }
         }
      } else {
         if(cnt==0) ResetAvgTrailBuy();
      }
   }

   {
      double tot=0; int cnt=0;
      double avg = CalcSideAvgPrice_NonHero(POSITION_TYPE_SELL, tot, cnt); // v1.3
      if(cnt >= InpAvgTrail_MinOrders && avg>0){
         if(InpAvgTrail_Strict2Cross && !g_avgTrail_ArmReady_Sell){
            if(ask > avg + InpAvgTrail_UnderAvgBuffer*g_point) g_avgTrail_ArmReady_Sell = true;
         }
         double profitPips = PriceToPips(avg - ask);
         if(!g_avgTrail_Active_Sell){
            bool armOk = (!InpAvgTrail_Strict2Cross || g_avgTrail_ArmReady_Sell);
            if(armOk && profitPips >= InpAvgTrail_ActivationPips){
               g_avgTrail_Active_Sell = true;
               g_avgTrail_SL_Sell = avg - PipsToPrice(InpAvgTrail_BE_Buffer);
               Print("GK AVG-TRAIL SELL ARMED avg=",DoubleToString(avg,g_digits)," sl=",DoubleToString(g_avgTrail_SL_Sell,g_digits));
            }
         } else {
            double trailPips = profitPips - InpAvgTrail_StepPips;
            if(trailPips < InpAvgTrail_BE_Buffer) trailPips = InpAvgTrail_BE_Buffer;
            double newSL = avg - PipsToPrice(trailPips);
            if(g_avgTrail_SL_Sell==0 || newSL < g_avgTrail_SL_Sell) g_avgTrail_SL_Sell = newSL;

            if(ask >= g_avgTrail_SL_Sell){
               Print("GK AVG-TRAIL SELL HIT — closing all SELL");
               CloseAllSide(POSITION_TYPE_SELL);
               ResetAvgTrailSell();
            }
         }
      } else {
         if(cnt==0) ResetAvgTrailSell();
      }
   }

   for(int i=PositionsTotal()-1;i>=0;i--){
      if(!pos.SelectByIndex(i)) continue;
      if(!IsOurPosition()) continue;
      if(IsHeroTicket(pos.Ticket())) continue; // v1.3
      int side = (int)pos.PositionType();
      double targetSL = 0;
      if(side==POSITION_TYPE_BUY  && g_avgTrail_Active_Buy)  targetSL = g_avgTrail_SL_Buy;
      if(side==POSITION_TYPE_SELL && g_avgTrail_Active_Sell) targetSL = g_avgTrail_SL_Sell;
      if(targetSL<=0) continue;

      if(side==POSITION_TYPE_BUY){
         if(bid - targetSL < minStop) targetSL = bid - minStop;
      } else {
         if(targetSL - ask < minStop) targetSL = ask + minStop;
      }
      double curSL = pos.StopLoss();
      double nrm = NormalizeDouble(targetSL, g_digits);
      if(MathAbs(curSL - nrm) <= g_point*2) continue;
      trade.PositionModify(pos.Ticket(), nrm, pos.TakeProfit());
   }
}

//===================== CHART LINES (Avg + TP) ======================
void DelLines() { ObjectsDeleteAll(0, g_linePrefix); }

void DrawHLine(string name, double price, color clr, int width=2, ENUM_LINE_STYLE style=STYLE_SOLID)
{
   string n = g_linePrefix + name;
   if(ObjectFind(0,n)<0){
      ObjectCreate(0,n,OBJ_HLINE,0,0,price);
      ObjectSetInteger(0,n,OBJPROP_BACK, false);
      ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
   }
   ObjectSetDouble (0,n,OBJPROP_PRICE, price);
   ObjectSetInteger(0,n,OBJPROP_COLOR, clr);
   ObjectSetInteger(0,n,OBJPROP_WIDTH, width);
   ObjectSetInteger(0,n,OBJPROP_STYLE, style);
}

void RemoveLine(string name)
{
   string n = g_linePrefix + name;
   if(ObjectFind(0,n)>=0) ObjectDelete(0,n);
}

void DrawAvgAndTPLines()
{
   double tlB=0,tlS=0; int cB=0,cS=0;
   double avgB = CalcSideAvgPrice(POSITION_TYPE_BUY,  tlB, cB);
   double avgS = CalcSideAvgPrice(POSITION_TYPE_SELL, tlS, cS);

   // Average lines
   if(InpShowAvgLine && cB>0 && avgB>0) DrawHLine("AVG_BUY",  avgB, InpAvgBuyLineColor,  3, STYLE_SOLID);
   else                                  RemoveLine("AVG_BUY");
   if(InpShowAvgLine && cS>0 && avgS>0) DrawHLine("AVG_SELL", avgS, InpAvgSellLineColor, 3, STYLE_SOLID);
   else                                  RemoveLine("AVG_SELL");

   // TP lines (Points mode only)
   bool drawTP = InpShowTPLine && InpUseTakeProfit && InpUseTPPoints;
   double tpDist = MathMax(InpTPPointsFromAverage * g_point, GetMinStopPrice());
   if(drawTP && cB >= InpAvgTP_MinOrders && avgB>0)
      DrawHLine("TP_BUY", avgB + tpDist, InpTPBuyLineColor, 1, STYLE_DASH);
   else
      RemoveLine("TP_BUY");
   if(drawTP && cS >= InpAvgTP_MinOrders && avgS>0)
      DrawHLine("TP_SELL", avgS - tpDist, InpTPSellLineColor, 1, STYLE_DASH);
   else
      RemoveLine("TP_SELL");
}

//=========================== DASHBOARD =============================
void DelDash() { ObjectsDeleteAll(0, g_dashPrefix); }

void SetRectBg(string name, int x, int y, int w, int h, color bg)
{
   string n = g_dashPrefix + "BG_" + name;
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_RECTANGLE_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0,n,OBJPROP_XSIZE, w);
   ObjectSetInteger(0,n,OBJPROP_YSIZE, h);
   ObjectSetInteger(0,n,OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0,n,OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0,n,OBJPROP_COLOR, bg);
   ObjectSetInteger(0,n,OBJPROP_BACK, false);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
}

void SetCell(string name, int x, int y, string text, color clr, int sz=9, bool bold=false)
{
   string n = g_dashPrefix + name;
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0,n,OBJPROP_COLOR, clr);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE, sz);
   ObjectSetString (0,n,OBJPROP_TEXT, text);
   ObjectSetString (0,n,OBJPROP_FONT, bold?"Consolas Bold":"Consolas");
   ObjectSetInteger(0,n,OBJPROP_BACK, false);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
}

string SideModeStr(){ if(InpInitSideMode==GK_SIDE_BUY_ONLY) return "BUY"; if(InpInitSideMode==GK_SIDE_SELL_ONLY) return "SELL"; return "BOTH"; }
string GridModeStr(){ if(InpGridSideMode==GK_GRID_UP_ONLY)  return "UP";  if(InpGridSideMode==GK_GRID_DOWN_ONLY) return "DOWN"; return "BOTH"; }
string LotModeStr() { if(InpGridLotMode==GK_LOT_FIXED) return "FIXED"; if(InpGridLotMode==GK_LOT_ADD) return "ADD"; return "MULT"; }
string OnOff(bool b) { return b?"ON":"OFF"; }
string AvgTrailStateStr(bool active, bool ready) { return active?"ARMED":(ready?"READY":"WAIT"); }

int g_dashRow = 0;

void DashHeader(string text)
{
   int y = InpDashY + g_dashRow * InpDashRowH;
   int w = InpDashColW1 + InpDashColW2;
   SetRectBg(StringFormat("R%d",g_dashRow), InpDashX, y, w, InpDashRowH, InpDashHeaderBgColor);
   SetCell(StringFormat("C%d",g_dashRow), InpDashX+4, y+1, text, InpDashHeaderColor, 9, true);
   g_dashRow++;
}

void DashRow(string label, string value, color valColor)
{
   int y = InpDashY + g_dashRow * InpDashRowH;
   color bg = (g_dashRow%2==0) ? InpDashRowBgColor : InpDashAltRowBgColor;
   SetRectBg(StringFormat("R%d",g_dashRow), InpDashX, y, InpDashColW1+InpDashColW2, InpDashRowH, bg);
   SetCell(StringFormat("L%d",g_dashRow), InpDashX+4,                y+1, label, InpDashTextColor, 9, false);
   SetCell(StringFormat("V%d",g_dashRow), InpDashX+InpDashColW1+4,   y+1, value, valColor,         9, false);
   g_dashRow++;
}

void DrawDashboard()
{
   if(!InpShowDashboard) return;
   if(TimeCurrent() - g_lastDashTime < InpDashRefreshSec) return;
   g_lastDashTime = TimeCurrent();

   // v1.2: do NOT wipe the entire panel each refresh (caused flicker).
   // Cells are updated in-place via SetRectBg/SetCell ObjectFind path.
   int prevMax = g_dashRowMax;
   g_dashRow = 0;

   color ok=clrLime, warn=clrOrange, bad=clrTomato, info=clrSilver, gold=clrGold;

   double bal  = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq   = AccountInfoDouble(ACCOUNT_EQUITY);
   double tlB=0,tlS=0; int cB=0,cS=0;
   double avgB = CalcSideAvgPrice(POSITION_TYPE_BUY,  tlB, cB);
   double avgS = CalcSideAvgPrice(POSITION_TYPE_SELL, tlS, cS);
   double plB  = CalcSideFloating(POSITION_TYPE_BUY);
   double plS  = CalcSideFloating(POSITION_TYPE_SELL);
   double plAll= plB+plS;

   DashHeader(StringFormat("Golden Kuy3 v1.41  Side:%s Grid:%s/%s", SideModeStr(), GridModeStr(), LotModeStr()));

   DashHeader("=== ACCOUNT ===");
   DashRow("Balance",     StringFormat("$%.2f", bal), info);
   DashRow("Equity",      StringFormat("$%.2f", eq),  info);
   DashRow("Floating P/L",StringFormat("$%.2f", plAll), (plAll>=0?ok:bad));
   DashRow("Realized (cycle)", StringFormat("$%.2f", g_realizedCycle), (g_realizedCycle>=0?ok:bad));

   DashHeader("=== POSITIONS ===");
   DashRow("BUY  P/L Lot Ord",
           StringFormat("$%.2f  %.2fL  %dord", plB, tlB, cB),
           (plB>=0?ok:bad));
   DashRow("SELL P/L Lot Ord",
           StringFormat("$%.2f  %.2fL  %dord", plS, tlS, cS),
           (plS>=0?ok:bad));
   DashRow("Total Cur. Lot",   StringFormat("%.2f L", tlB+tlS), info);
   DashRow("Avg BUY",  (avgB>0?DoubleToString(avgB,g_digits):"-"), info);
   DashRow("Avg SELL", (avgS>0?DoubleToString(avgS,g_digits):"-"), info);

   DashHeader("=== MODULES ===");
   DashRow("Initial Side", SideModeStr(), info);
   DashRow("Grid",         StringFormat("%s  dist=%.1fp max=%d %s",
                            OnOff(InpEnableGrid), InpGridDistancePips, InpMaxGridOrders, (InpGridOnlyNewCandle?"NewBar":"")),
                           (InpEnableGrid?ok:warn));
   DashRow("BE Lock",      StringFormat("%s  act=%.0fp buf=%.0fp", OnOff(InpEnableBreakevenLock), InpBreakevenActivationPips, InpBreakevenBufferPips),
                           (InpEnableBreakevenLock?ok:warn));
   DashRow("Per-Order Trail", StringFormat("%s  act=%.0fp step=%.0fp", OnOff(InpEnableTrailingStop), InpTrailingActivationPips, InpTrailingStepPips),
                           (InpEnableTrailingStop?ok:warn));
   DashRow("Avg Trail",    StringFormat("%s  act=%.0fp step=%.0fp min=%d 2X=%s",
                            OnOff(InpEnableAvgTrailing), InpAvgTrail_ActivationPips, InpAvgTrail_StepPips,
                            InpAvgTrail_MinOrders, (InpAvgTrail_Strict2Cross?"Y":"N")),
                           (InpEnableAvgTrailing?ok:warn));
   DashRow("Cost-Hit Restart", StringFormat("%s  spc=%.0fp cd=%ds",
                            OnOff(InpEnableCostHitRestart), InpCostHitMinSpacingPips, InpCostHitCooldownSec),
                           (InpEnableCostHitRestart?ok:warn));

   DashHeader("=== TAKE PROFIT ===");
   DashRow("Master TP",    OnOff(InpUseTakeProfit), (InpUseTakeProfit?ok:warn));
   DashRow("TP Dollar",    StringFormat("%s  $%.2f", OnOff(InpUseTPFixedDollar), InpTPDollarAmount),
                           (InpUseTPFixedDollar?ok:warn));
   DashRow("TP Points",    StringFormat("%s  %.0fpt /%dord", OnOff(InpUseTPPoints), InpTPPointsFromAverage, InpAvgTP_MinOrders),
                           (InpUseTPPoints?ok:warn));
   DashRow("TP %Bal",      StringFormat("%s  %.1f%%", OnOff(InpUseTPPercentBalance), InpTPPercentOfBalance),
                           (InpUseTPPercentBalance?ok:warn));
   DashRow("Accumulate",   StringFormat("%s  $%.0f", OnOff(InpUseAccumulateClose), InpAccumulateTarget),
                           (InpUseAccumulateClose?ok:warn));

   DashHeader("=== AVG TRAIL STATE ===");
   DashRow("BUY",  StringFormat("%s  SL:%s", AvgTrailStateStr(g_avgTrail_Active_Buy, g_avgTrail_ArmReady_Buy),
                    (g_avgTrail_SL_Buy>0?DoubleToString(g_avgTrail_SL_Buy,g_digits):"-")),
                  (g_avgTrail_Active_Buy?ok:warn));
   DashRow("SELL", StringFormat("%s  SL:%s", AvgTrailStateStr(g_avgTrail_Active_Sell, g_avgTrail_ArmReady_Sell),
                    (g_avgTrail_SL_Sell>0?DoubleToString(g_avgTrail_SL_Sell,g_digits):"-")),
                  (g_avgTrail_Active_Sell?ok:warn));

   DashHeader("=== SYSTEM ===");
   bool tpModeOn = (InpUseTakeProfit && InpUseTPPoints);
   DashRow("TP Lines", (tpModeOn?"Drawn":"Cleared"), (tpModeOn?ok:warn));
   DashRow("Init BUY Px",  (g_initPrice_Buy>0?DoubleToString(g_initPrice_Buy,g_digits):"-"), info);
   DashRow("Init SELL Px", (g_initPrice_Sell>0?DoubleToString(g_initPrice_Sell,g_digits):"-"), info);
   string rpB = g_costHit_Pending_Buy  ? StringFormat("WAIT@%s", DoubleToString(g_costHit_Price_Buy, g_digits))  : "-";
   string rpS = g_costHit_Pending_Sell ? StringFormat("WAIT@%s", DoubleToString(g_costHit_Price_Sell, g_digits)) : "-";
   DashRow("Restart Pending", StringFormat("BUY:%s  SELL:%s", rpB, rpS),
           (g_costHit_Pending_Buy||g_costHit_Pending_Sell)?warn:info);

   DashHeader("=== HERO ORDER (v7.09) ===");
   DashRow("Hero Cfg", StringFormat("%s  N=%d minAct=%d BE=%dpt",
                          OnOff(InpHero_Enabled), InpHero_OrderCount,
                          InpHero_MinOrdersToActivate, InpHero_BE_OffsetPoints),
                          (InpHero_Enabled?gold:warn));
   {
      int ownerSide = GetHeroOwnerSide();
      string ownerStr = (ownerSide == (int)POSITION_TYPE_BUY)  ? "BUY (locked)"
                      : (ownerSide == (int)POSITION_TYPE_SELL) ? "SELL (locked)"
                      : (g_heroPhase_Buy == 2 || g_heroPhase_Sell == 2) ? "NONE (waiting close)" : "NONE";
      color ownClr = (ownerSide >= 0) ? gold : ((g_heroPhase_Buy==2||g_heroPhase_Sell==2)?warn:info);
      DashRow("Hero Owner", ownerStr, ownClr);
   }
   {
      string phaseB = (g_heroPhase_Buy == 3) ? "BE_GUARD" : (g_heroPhase_Buy == 2) ? "ARMED" : "WAIT";
      int minAct = (InpHero_MinOrdersToActivate > 0) ? InpHero_MinOrdersToActivate : (InpHero_OrderCount + 1);
      DashRow("Hero BUY", StringFormat("active=%d/%d  Hero=%d  %s",
                          g_heroDash_BuyActive, minAct, g_heroDash_BuyTagged, phaseB),
                          (g_heroPhase_Buy==3?gold:(g_heroPhase_Buy==2?warn:info)));
      string ids = "";
      for(int i = 0; i < g_heroDash_BuyTicketN; i++) {
         if(i > 0) ids += " ";
         ids += StringFormat("#%I64u", g_heroDash_BuyTickets[i]);
      }
      DashRow("Tix BUY", (g_heroDash_BuyTicketN > 0 ? ids : "-"), info);
   }
   {
      string phaseS = (g_heroPhase_Sell == 3) ? "BE_GUARD" : (g_heroPhase_Sell == 2) ? "ARMED" : "WAIT";
      int minAct = (InpHero_MinOrdersToActivate > 0) ? InpHero_MinOrdersToActivate : (InpHero_OrderCount + 1);
      DashRow("Hero SELL", StringFormat("active=%d/%d  Hero=%d  %s",
                           g_heroDash_SellActive, minAct, g_heroDash_SellTagged, phaseS),
                           (g_heroPhase_Sell==3?gold:(g_heroPhase_Sell==2?warn:info)));
      string ids = "";
      for(int i = 0; i < g_heroDash_SellTicketN; i++) {
         if(i > 0) ids += " ";
         ids += StringFormat("#%I64u", g_heroDash_SellTickets[i]);
      }
      DashRow("Tix SELL", (g_heroDash_SellTicketN > 0 ? ids : "-"), info);
   }

   // v1.2 high-water trim: remove rows that existed last frame but not this frame
   if(g_dashRow > g_dashRowMax) g_dashRowMax = g_dashRow;
   for(int r=g_dashRow; r<prevMax; r++){
      ObjectDelete(0, g_dashPrefix + StringFormat("BG_R%d", r));
      ObjectDelete(0, g_dashPrefix + StringFormat("R%d",   r));
      ObjectDelete(0, g_dashPrefix + StringFormat("C%d",   r));
      ObjectDelete(0, g_dashPrefix + StringFormat("L%d",   r));
      ObjectDelete(0, g_dashPrefix + StringFormat("V%d",   r));
   }
   g_dashRowMax = g_dashRow;
}

//==================== TRADE TRANSACTION ============================
void OnTradeTransaction(const MqlTradeTransaction& trans, const MqlTradeRequest& req, const MqlTradeResult& res)
{
   // Track realized P/L per cycle (deal-add only)
   if(trans.type==TRADE_TRANSACTION_DEAL_ADD){
      if(HistoryDealSelect(trans.deal)){
         long magic = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
         string sym = HistoryDealGetString (trans.deal, DEAL_SYMBOL);
         if(magic == InpMagicNumber && sym == _Symbol){
            int entry = (int)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
            if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_INOUT || entry == DEAL_ENTRY_OUT_BY){
               double pr = HistoryDealGetDouble(trans.deal, DEAL_PROFIT)
                         + HistoryDealGetDouble(trans.deal, DEAL_SWAP)
                         + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
               g_realizedCycle += pr;

               // v1.2 Cost-Hit detection: was this deal closed by SL or TP?
               if(InpEnableCostHitRestart){
                  long reason = HistoryDealGetInteger(trans.deal, DEAL_REASON);
                  if(reason == DEAL_REASON_SL || reason == DEAL_REASON_TP){
                     // v1.4: suppress during Hero post-close grace
                     bool inGrace = (InpHero_Enabled && InpHero_PostCloseGraceSec>0
                                     && (TimeCurrent()-GetHeroLastCloseTime()) < InpHero_PostCloseGraceSec);
                     long dealType = HistoryDealGetInteger(trans.deal, DEAL_TYPE);
                     int closedSide = (dealType == DEAL_TYPE_SELL) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
                     double closePx = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
                     if(!inGrace){
                        if(closedSide == POSITION_TYPE_BUY){
                           g_costHit_Pending_Buy = true;
                           g_costHit_Price_Buy   = closePx;
                           g_costHit_Time_Buy    = TimeCurrent();
                        } else {
                           g_costHit_Pending_Sell = true;
                           g_costHit_Price_Sell   = closePx;
                           g_costHit_Time_Sell    = TimeCurrent();
                        }
                        Print("GK COST-HIT detected side=",(closedSide==POSITION_TYPE_BUY?"BUY":"SELL"),
                              " reason=",reason," px=",DoubleToString(closePx,g_digits));
                     } else {
                        Print("GK COST-HIT suppressed (Hero grace) side=",(closedSide==POSITION_TYPE_BUY?"BUY":"SELL"));
                     }
                  }
               }
            }
         }
      }
   }
   // Reset cycle when fully flat
   if(CountSideSimple(POSITION_TYPE_BUY)==0 && CountSideSimple(POSITION_TYPE_SELL)==0){
      // small epsilon to avoid resetting in the middle of multi-deal flatten
      if(MathAbs(g_realizedCycle) > 0.0 && trans.type==TRADE_TRANSACTION_DEAL_ADD){
         // keep g_realizedCycle visible until next entry; reset on next OpenInitial cycle
      }
   }
}

//================ COST-HIT RESTART (v1.2) ==========================
void TryRestartSide(int side, bool &pendingFlag, double &pendingPx, datetime pendingTime)
{
   if(!pendingFlag) return;
   if(InpCostHitCooldownSec>0 && (TimeCurrent() - pendingTime) < InpCostHitCooldownSec) return;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double refPx = (side==POSITION_TYPE_BUY)?ask:bid;

   if(HasNearbyPosition(side, refPx, InpCostHitMinSpacingPips)){
      return; // wait — too close to existing same-side ticket
   }

   if(OpenInitial(side)){
      Print("GK COST-HIT RESTART ",(side==POSITION_TYPE_BUY?"BUY":"SELL"),
            " @ ",DoubleToString(refPx,g_digits)," (closed@",DoubleToString(pendingPx,g_digits),")");
      pendingFlag = false;
      pendingPx   = 0.0;
   }
}

void ManageCostHitRestart()
{
   if(!InpEnableCostHitRestart) return;
   TryRestartSide(POSITION_TYPE_BUY,  g_costHit_Pending_Buy,  g_costHit_Price_Buy,  g_costHit_Time_Buy);
   TryRestartSide(POSITION_TYPE_SELL, g_costHit_Pending_Sell, g_costHit_Price_Sell, g_costHit_Time_Sell);
}

//=========================== INIT/TICK =============================
int OnInit()
{
   g_digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   g_point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   g_pip    = (g_digits==3 || g_digits==5) ? 10.0*g_point : g_point;
   g_stopsLevel = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippagePoints);
   trade.SetTypeFilling(ORDER_FILLING_FOK);

   for(int i=PositionsTotal()-1;i>=0;i--){
      if(!pos.SelectByIndex(i)) continue;
      if(!IsOurPosition()) continue;
      string c = pos.Comment();
      if(c=="GK_INIT_BUY")  g_initPrice_Buy  = pos.PriceOpen();
      if(c=="GK_INIT_SELL") g_initPrice_Sell = pos.PriceOpen();
   }

   Print("Golden Kuy3 v1.41 init  digits=",g_digits," pip=",g_pip," stopsLvl=",g_stopsLevel,
         " | Hero=", InpHero_Enabled?"ON":"OFF", " HeroN=", InpHero_OrderCount,
         " minAct=", InpHero_MinOrdersToActivate, " BE=", InpHero_BE_OffsetPoints, "pt");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   DelDash();
   DelLines();
   Print("Golden Kuy3 v1.41 deinit reason=",reason);
}

void OnTick()
{
   BuildHeroTicketCache();      // v1.4 — must run first
   ManageHeroOppositeClose();   // v1.4 — orchestrator (strip TP/SL, BE_GUARD, opp-clear close)
   ManageCostHitRestart();
   ManageInitialEntry();
   ManageGridEntry();
   ManagePerOrderTrailing();
   ManageTakeProfit();
   ManageAverageTrailing();
   EnforceClearTPIfDisabled();
   DrawAvgAndTPLines();
   DrawDashboard();
}
//+------------------------------------------------------------------+
