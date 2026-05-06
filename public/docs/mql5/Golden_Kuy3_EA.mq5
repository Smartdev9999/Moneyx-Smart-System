//+------------------------------------------------------------------+
//|                                            Golden_Kuy3_EA.mq5    |
//|                                       Golden Kuy3 EA  v1.58      |
//|  v1.58: Hero Handoff Reserve + Conditional Alternation Lock —    |
//|         While owner side is BE_GUARD, opposite may pre-arm as    |
//|         Reserve so the next basket TP keeps a Hero set instead   |
//|         of closing all. If both sides are below threshold,       |
//|         Next-Allowed lock auto-resets (no forced alternation).   |
//|         Full history in mem://trading/golden-kuy3/*.             |
//+------------------------------------------------------------------+
#property copyright "Golden Kuy3 EA"
#property version   "1.58"
#property description "Golden Kuy3 v1.58 — Hero Handoff Reserve + Conditional Alternation: opposite side may pre-arm Reserve while owner is BE_GUARD; alternation lock auto-resets when both sides under threshold."
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
input bool   InpHero_AlternateSides     = true;   // v1.46 — ฝั่งที่เพิ่งปิด Hero ห้าม re-arm จนกว่าฝั่งตรงข้ามจะ Hero หรือฝั่งเดิม flat สนิท
input bool   InpHero_CloseWithOpposite  = true;   // [DEPRECATED] hard-wired to opposite-basket close
input bool   InpHero_RequireNetProfit   = false;  // [DEPRECATED] not used (lock-profit SL guarantees floor)
input bool   InpHero_OppCloseRequireTP    = true;   // v1.50 — close Hero ONLY when opp basket realized > min profit
input double InpHero_OppCloseMinProfit    = 0.0;    // v1.50 — minimum opp realized profit to qualify as TP close ($)
input bool   InpHero_OppCloseRequireAvgTP = true;   // v1.51 — close Hero ONLY when opp basket flattened by Avg-TP/Avg-Trail/Master TP/Accumulate (intent flag); Per-Order Trail/SL/Cost-Hit do NOT count
input bool   InpHero_StickySet              = false;  // v1.55 — [DEPRECATED/IGNORED] Hero set is always rebuilt every tick from price-extreme. Kept only for .set file backward compatibility.

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

// v1.42 — forward decl
void TryResetAccumulateCycleIfFlat();

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
int      g_heroLastClosedSide     = -1;    // v1.46 — ฝั่ง Hero ที่เพิ่งปิดล่าสุด (POSITION_TYPE_BUY/SELL หรือ -1)
int      g_heroNextAllowedSide    = -1;    // v1.56 — ฝั่งที่อนุญาตให้เป็น Hero รอบถัดไป (-1=any, BUY=POSITION_TYPE_BUY, SELL=POSITION_TYPE_SELL)
// v1.49 Stable per-side Hero ticket sets — chosen ONCE at first activation, never replaced
ulong    g_heroBuyStable[200];
int      g_heroBuyStableN         = 0;
ulong    g_heroSellStable[200];
int      g_heroSellStableN        = 0;
// v1.50 — Per-side accumulator of opposite-basket realized P/L since hero ARMED.
// Indexed by HERO side (BUY/SELL). When opp basket flattens with positive net -> close hero.
double   g_oppBasketRealized_HeroBuy   = 0.0; // realized P/L of SELL deals while BUY hero alive
double   g_oppBasketRealized_HeroSell  = 0.0; // realized P/L of BUY  deals while SELL hero alive
datetime g_oppBasketLastDealTime_HeroBuy  = 0;
datetime g_oppBasketLastDealTime_HeroSell = 0;
// v1.51 — Intent flag: set TRUE just before CloseAllSide/CloseAllOurs from Avg-TP/Avg-Trail/Master TP/Accumulate.
// Hero opposite-clear close gate requires this flag (per opp side) to be true.
bool     g_oppCloseIntent_AvgTP_Buy   = false; // BUY  basket about to be flattened by Avg-TP/Avg-Trail/Accum
bool     g_oppCloseIntent_AvgTP_Sell  = false; // SELL basket about to be flattened by Avg-TP/Avg-Trail/Accum
datetime g_oppCloseIntentTime_Buy     = 0;
datetime g_oppCloseIntentTime_Sell    = 0;
// v1.51 — Master TP Points safety net: count broker TP closes per side in short window
int      g_oppTPDealCount_Buy         = 0;     // count of non-Hero BUY  tickets closed by DEAL_REASON_TP recently
int      g_oppTPDealCount_Sell        = 0;
datetime g_oppTPDealWindow_Buy        = 0;
datetime g_oppTPDealWindow_Sell       = 0;
// v1.57 — Opposite TP-event latch (per Hero side). Set when opposite basket logs a TP/Avg-TP
//          event so Hero can close even after AutoReEntry/Grid re-opens an opposite ticket
//          on the same tick. Consumed by ManageHeroOppositeClose() and CloseHeroOnSide().
bool     g_oppTPEvent_HeroBuy         = false; // BUY  Hero waiting on SELL basket TP event
bool     g_oppTPEvent_HeroSell        = false; // SELL Hero waiting on BUY  basket TP event
datetime g_oppTPEventTime_HeroBuy     = 0;
datetime g_oppTPEventTime_HeroSell    = 0;
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

// v1.45: Owner = ฝั่งที่ phase == BE_GUARD เท่านั้น (basket ปกติฝั่งเดียวกันปิดหมดแล้ว)
//         ARMED (CANDIDATE) ไม่ใช่ owner — ทั้งสองฝั่งสามารถ ARMED พร้อมกันได้
int GetHeroOwnerSide()
{
   bool buyOwns  = (g_heroPhase_Buy  == 3);
   bool sellOwns = (g_heroPhase_Sell == 3);
   if(buyOwns && !sellOwns)  return (int)POSITION_TYPE_BUY;
   if(sellOwns && !buyOwns)  return (int)POSITION_TYPE_SELL;
   return -1; // ไม่มีฝั่งใดถึง BE_GUARD (ARMED ไม่นับ) หรือทั้งสองฝั่ง BE_GUARD พร้อมกัน
}

bool IsHeroTicket(ulong ticket)
{
   if(!InpHero_Enabled) return false;
   for(int i = 0; i < g_heroTicketCount; i++)
      if(g_heroTickets[i] == ticket) return true;
   return false;
}

// v1.49 — Hero protection helper: ticket is protected if it's in flat array OR either stable set.
// Used by every "skip Hero" guard so Hero is never touched even between rebuilds.
bool IsHeroProtectedTicket(ulong ticket)
{
   if(!InpHero_Enabled) return false;
   if(IsHeroTicket(ticket)) return true;
   for(int i = 0; i < g_heroBuyStableN;  i++) if(g_heroBuyStable[i]  == ticket) return true;
   for(int i = 0; i < g_heroSellStableN; i++) if(g_heroSellStable[i] == ticket) return true;
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
      if(IsHeroProtectedTicket(ticket)) continue;
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

// v1.49 helpers — stable per-side Hero ticket set management
int  GetStableCount(int sideId) { return (sideId==POSITION_TYPE_BUY) ? g_heroBuyStableN : g_heroSellStableN; }

bool IsTicketStillOpen(ulong t)
{
   return PositionSelectByTicket(t);
}

// Drop tickets that are no longer open. Returns previous count for change detection.
int PruneStableSet(int sideId)
{
   int prev = GetStableCount(sideId);
   if(sideId==POSITION_TYPE_BUY) {
      int w = 0;
      for(int i=0; i<g_heroBuyStableN; i++)
         if(IsTicketStillOpen(g_heroBuyStable[i])) g_heroBuyStable[w++] = g_heroBuyStable[i];
      g_heroBuyStableN = w;
   } else {
      int w = 0;
      for(int i=0; i<g_heroSellStableN; i++)
         if(IsTicketStillOpen(g_heroSellStable[i])) g_heroSellStable[w++] = g_heroSellStable[i];
      g_heroSellStableN = w;
   }
   return prev;
}

void ClearStableSet(int sideId)
{
   if(sideId==POSITION_TYPE_BUY) g_heroBuyStableN = 0; else g_heroSellStableN = 0;
}

void AddToStableSet(int sideId, ulong t)
{
   if(sideId==POSITION_TYPE_BUY) {
      if(g_heroBuyStableN < 200) g_heroBuyStable[g_heroBuyStableN++] = t;
   } else {
      if(g_heroSellStableN < 200) g_heroSellStable[g_heroSellStableN++] = t;
   }
}

bool IsInStableSet(int sideId, ulong t)
{
   if(sideId==POSITION_TYPE_BUY) {
      for(int i=0; i<g_heroBuyStableN; i++) if(g_heroBuyStable[i]==t) return true;
   } else {
      for(int i=0; i<g_heroSellStableN; i++) if(g_heroSellStable[i]==t) return true;
   }
   return false;
}

// v1.53 — Demote Restore: tickets that were Hero in prevSet but no longer in newSet
//          get their broker-side Initial TP restored and any lock-profit SL cleared,
//          so they re-join the normal basket. Skipped when InpHero_StickySet=true.
void RestoreInitialTPOnDemoted(const ulong &prevSet[], int prevCnt,
                               const ulong &newSet[],  int newCnt,
                               ENUM_POSITION_TYPE side)
{
   if(prevCnt <= 0) return;
   string demotedLog = "";
   int restored = 0;
   for(int i = 0; i < prevCnt; i++) {
      ulong tk = prevSet[i];
      bool stillHero = false;
      for(int j = 0; j < newCnt; j++) if(newSet[j] == tk) { stillHero = true; break; }
      if(stillHero) continue;

      if(!PositionSelectByTicket(tk)) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != side) continue;

      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double curSL     = PositionGetDouble(POSITION_SL);
      double curTP     = PositionGetDouble(POSITION_TP);
      double newTP = 0.0;
      if(InpUseTakeProfit && !InpUseTPPoints && InpInitialTPPips > 0) {
         double minStop = GetMinStopPrice();
         double dist    = MathMax(PipsToPrice(InpInitialTPPips), minStop);
         newTP = (side == POSITION_TYPE_BUY) ? openPrice + dist : openPrice - dist;
      }
      // Clear lock-profit SL we placed earlier; per-order BE/Trail/Cost-Hit will
      // re-apply their own SL on later ticks if enabled.
      double newSL = 0.0;
      // v1.54 — idempotency: skip modify when state already matches target
      if(NormalizeDouble(curSL, g_digits) == NormalizeDouble(newSL, g_digits) &&
         NormalizeDouble(curTP, g_digits) == NormalizeDouble(newTP, g_digits)) continue;
      if(trade.PositionModify(tk, newSL, newTP)) {
         restored++;
         demotedLog += StringFormat(" #%I64u@open=%s->TP=%s",
                          tk, DoubleToString(openPrice, g_digits),
                          DoubleToString(newTP, g_digits));
      }
   }
   if(restored > 0)
      Print("v1.54 Hero DEMOTE restore side=", EnumToString(side),
            " count=", restored, " (TP restored, lock-SL cleared):", demotedLog);
}

void BuildHeroTicketCache()
{
   // v1.49: STICKY stable sets per side — chosen ONCE at activation, never re-selected
   if(!InpHero_Enabled || InpHero_OrderCount <= 0) {
      g_heroTicketCount = 0;
      g_heroBuyStableN = 0;
      g_heroSellStableN = 0;
      return;
   }
   g_heroLastBuildTime = TimeCurrent();

   int sideTotalActive[2] = {0, 0};
   int sideHeroTagged[2]  = {0, 0};

   // ============ STEP 1: Prune stable sets + detect external Hero close ============
   for(int s = 0; s < 2; s++) {
      int sideId = (s==0) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
      int prevN = (sideId==POSITION_TYPE_BUY) ? g_heroBuyStableN : g_heroSellStableN;
      PruneStableSet(sideId);
      int nowN  = (sideId==POSITION_TYPE_BUY) ? g_heroBuyStableN : g_heroSellStableN;

      int curPhase = (sideId == POSITION_TYPE_BUY) ? g_heroPhase_Buy : g_heroPhase_Sell;
      // External-close detection: stable set drained while phase was active -> treat as Hero closed
      if(prevN > 0 && nowN == 0 && curPhase > 0) {
         Print("v1.49 Hero TICKET-SET LOST side=", (sideId==POSITION_TYPE_BUY?"BUY":"SELL"),
               " — all stable Hero tickets closed externally (broker/SL/TP/manual). Resetting phase + stamping last-closed.");
         if(sideId == POSITION_TYPE_BUY) {
            g_heroPhase_Buy = 0; g_heroBE_Applied_Buy = false; g_heroJustClosed_Buy = TimeCurrent();
         } else {
            g_heroPhase_Sell = 0; g_heroBE_Applied_Sell = false; g_heroJustClosed_Sell = TimeCurrent();
         }
         g_heroLastClosedSide = sideId;
         g_heroNextAllowedSide = (sideId == (int)POSITION_TYPE_BUY) ? (int)POSITION_TYPE_SELL : (int)POSITION_TYPE_BUY; // v1.56
         Print("v1.56 Hero NEXT-ALLOWED set to ", (g_heroNextAllowedSide==(int)POSITION_TYPE_BUY?"BUY":"SELL"),
               " after external close on ", (sideId==POSITION_TYPE_BUY?"BUY":"SELL"));
      }
   }

   // ============ STEP 2: Dual BE_GUARD pre-guard (rare safety net) ============
   if(InpHero_SingleSideLock && g_heroPhase_Buy == 3 && g_heroPhase_Sell == 3) {
      int nB = CountSideSimple(POSITION_TYPE_BUY);
      int nS = CountSideSimple(POSITION_TYPE_SELL);
      int keep = (nB >= nS) ? (int)POSITION_TYPE_BUY : (int)POSITION_TYPE_SELL;
      if(keep == (int)POSITION_TYPE_BUY) {
         Print("v1.49 Hero PRE-GUARD: dual BE_GUARD detected, keeping BUY, resetting SELL");
         g_heroPhase_Sell = 0; g_heroBE_Applied_Sell = false; g_heroJustClosed_Sell = TimeCurrent();
         ClearStableSet(POSITION_TYPE_SELL);
      } else {
         Print("v1.49 Hero PRE-GUARD: dual BE_GUARD detected, keeping SELL, resetting BUY");
         g_heroPhase_Buy = 0; g_heroBE_Applied_Buy = false; g_heroJustClosed_Buy = TimeCurrent();
         ClearStableSet(POSITION_TYPE_BUY);
      }
   }

   int activeOwner = -1;
   if(InpHero_SingleSideLock) activeOwner = GetHeroOwnerSide();

   // ============ STEP 3: Per-side processing — only SELECT new Hero when phase==NONE ============
   for(int s = 0; s < 2; s++)
   {
      ENUM_POSITION_TYPE side = (s == 0) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
      int sideId = (int)side;

      // Scan all current open positions on this side (for activation count + price-extreme select)
      ulong  tkPool[200]; double pxPool[200]; int nPool = 0;
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
            pxPool[nPool] = PositionGetDouble(POSITION_PRICE_OPEN);
            nPool++;
         }
      }
      sideTotalActive[s] = nAll;

      int curPhase = (sideId == POSITION_TYPE_BUY) ? g_heroPhase_Buy : g_heroPhase_Sell;
      int stableN  = GetStableCount(sideId);

      // ===== Branch A v1.56: phase active =====
      // v1.56: Dynamic Price-Extreme refresh ONLY when phase == ARMED (2).
      //        When phase == BE_GUARD (3) the Hero set is FROZEN — new same-side tickets
      //        opened after the non-Hero basket closed are NOT allowed to extend Hero ownership.
      //        PruneStableSet (STEP 1) already removed closed tickets; nothing else to do.
      if(curPhase == 3) {
         sideHeroTagged[s] = stableN;
         continue;
      }
      if(curPhase == 2) {
         if(nPool <= 0) { sideHeroTagged[s] = 0; continue; }

         // Sort pool by price-extreme (BUY ascending lowest first / SELL descending highest first)
         bool buySideA = (side == POSITION_TYPE_BUY);
         for(int a = 1; a < nPool; a++)
            for(int b = a; b > 0; b--) {
               bool swap = false;
               if(buySideA) {
                  if(pxPool[b] < pxPool[b-1]) swap = true;
                  else if(pxPool[b] == pxPool[b-1] && tkPool[b] < tkPool[b-1]) swap = true;
               } else {
                  if(pxPool[b] > pxPool[b-1]) swap = true;
                  else if(pxPool[b] == pxPool[b-1] && tkPool[b] < tkPool[b-1]) swap = true;
               }
               if(!swap) break;
               double _p = pxPool[b]; pxPool[b] = pxPool[b-1]; pxPool[b-1] = _p;
               ulong  _k = tkPool[b]; tkPool[b] = tkPool[b-1]; tkPool[b-1] = _k;
            }

         int takeA = MathMin(InpHero_OrderCount, nPool);
         if(takeA <= 0) { sideHeroTagged[s] = 0; continue; }

         ulong prevSet[200]; int prevCnt = 0;
         if(sideId == POSITION_TYPE_BUY) {
            for(int i=0; i<g_heroBuyStableN; i++) prevSet[prevCnt++] = g_heroBuyStable[i];
         } else {
            for(int i=0; i<g_heroSellStableN; i++) prevSet[prevCnt++] = g_heroSellStable[i];
         }

         ClearStableSet(sideId);
         for(int k = 0; k < takeA; k++) AddToStableSet(sideId, tkPool[k]);
         sideHeroTagged[s] = takeA;

         bool changed = (prevCnt != takeA);
         if(!changed) {
            for(int k = 0; k < takeA && !changed; k++)
               if(prevSet[k] != tkPool[k]) changed = true;
         }
         if(changed) {
            string newList = "";
            for(int k = 0; k < takeA; k++)
               newList += StringFormat(" #%I64u@%s", tkPool[k], DoubleToString(pxPool[k], g_digits));
            Print("v1.56 Hero DYNAMIC REFRESH (ARMED only) side=", (sideId==POSITION_TYPE_BUY?"BUY":"SELL"),
                  " count=", takeA, " new set:", newList);
            // Demote restore: tickets pushed out get Initial TP back + lock-SL cleared
            RestoreInitialTPOnDemoted(prevSet, prevCnt, tkPool, takeA, (ENUM_POSITION_TYPE)sideId);
         }
         continue;
      }

      // ===== Branch B: phase NONE — consider activating a NEW stable set =====

      // Post-close grace
      datetime jc = (sideId == POSITION_TYPE_BUY) ? g_heroJustClosed_Buy : g_heroJustClosed_Sell;
      if(jc > 0 && (TimeCurrent() - jc) < InpHero_PostCloseGraceSec) {
         continue;
      }

      // v1.46/v1.49 Side-Alternation Lock — ฝั่งที่เพิ่งปิด Hero ห้าม re-arm
      if(InpHero_AlternateSides && g_heroLastClosedSide >= 0 && sideId == g_heroLastClosedSide)
      {
         int oppPhase  = (sideId == POSITION_TYPE_BUY) ? g_heroPhase_Sell : g_heroPhase_Buy;
         bool oppActive = (oppPhase == 2 || oppPhase == 3);
         bool selfFlat  = (CountHeroOnSide((ENUM_POSITION_TYPE)sideId) == 0
                        && CountNonHeroMainOnSide((ENUM_POSITION_TYPE)sideId) == 0);
         if(oppActive || selfFlat) {
            g_heroLastClosedSide = -1; // ปลด lock
         } else {
            static datetime lastAltBlockLog_B = 0, lastAltBlockLog_S = 0;
            datetime lastLog = (sideId == POSITION_TYPE_BUY) ? lastAltBlockLog_B : lastAltBlockLog_S;
            if(TimeCurrent() - lastLog >= 30) {
               Print("v1.49 Hero ALT-BLOCK side=", (sideId==POSITION_TYPE_BUY?"BUY":"SELL"),
                     " lastClosed=", (sideId==POSITION_TYPE_BUY?"BUY":"SELL"),
                     " — waiting opposite-side Hero or self flat");
               if(sideId == POSITION_TYPE_BUY) lastAltBlockLog_B = TimeCurrent();
               else                            lastAltBlockLog_S = TimeCurrent();
            }
            continue;
         }
      }

      int activateThreshold = (InpHero_MinOrdersToActivate > 0)
                              ? InpHero_MinOrdersToActivate
                              : (InpHero_OrderCount + 1);

      // v1.58 Handoff Reserve: Single-Side Lock no longer blocks opposite side from
      //         ARMing as Reserve while owner is BE_GUARD. Reserve protects the
      //         opposite-side Hero set so the next basket TP keeps a Hero
      //         instead of closing all. Owner promotion (BE_GUARD) still
      //         handled by DetectSameSideBasketClearedForHero per side.
      // (Old strict-lock block removed.)

      // v1.58 Conditional Alternation Lock — gate clears itself if the
      //         designated next-allowed side has no realistic chance of
      //         becoming Hero soon (active count < threshold AND phase==NONE).
      //         This implements: when both sides are flat/under threshold,
      //         system resets like a fresh start — first side to hit TP wins Hero.
      if(g_heroNextAllowedSide >= 0 && sideId != g_heroNextAllowedSide) {
         int oppActiveCnt   = (g_heroNextAllowedSide == (int)POSITION_TYPE_BUY)
                              ? sideTotalActive[0] : sideTotalActive[1];
         int oppPhaseCheck  = (g_heroNextAllowedSide == (int)POSITION_TYPE_BUY)
                              ? g_heroPhase_Buy : g_heroPhase_Sell;
         bool oppCanArm     = (oppPhaseCheck > 0) || (oppActiveCnt >= activateThreshold);
         if(!oppCanArm) {
            // Designated next-allowed side has nothing — auto-clear lock
            static datetime lastAltResetLog = 0;
            if(TimeCurrent() - lastAltResetLog >= 30) {
               Print("v1.58 Hero ALT-RESET — designated next=", (g_heroNextAllowedSide==(int)POSITION_TYPE_BUY?"BUY":"SELL"),
                     " has no path to Hero (active=", oppActiveCnt, " thr=", activateThreshold,
                     " phase=", oppPhaseCheck, ") — clearing lock, allowing this side");
               lastAltResetLog = TimeCurrent();
            }
            g_heroNextAllowedSide = -1;
         } else {
            static datetime lastNextBlockLog_B = 0, lastNextBlockLog_S = 0;
            datetime lastLogN = (sideId == POSITION_TYPE_BUY) ? lastNextBlockLog_B : lastNextBlockLog_S;
            if(TimeCurrent() - lastLogN >= 30) {
               string nextStr = (g_heroNextAllowedSide == (int)POSITION_TYPE_BUY) ? "BUY" : "SELL";
               Print("v1.58 Hero ALT-BLOCK side=", (sideId==POSITION_TYPE_BUY?"BUY":"SELL"),
                     " waitingNext=", nextStr, " (opp ready: active=", oppActiveCnt, " phase=", oppPhaseCheck, ")");
               if(sideId == POSITION_TYPE_BUY) lastNextBlockLog_B = TimeCurrent();
               else                            lastNextBlockLog_S = TimeCurrent();
            }
            continue;
         }
      }

      // Activation gate
      if(nAll < activateThreshold) continue;
      if(nPool <= 0) continue;

      // Sort by OPEN PRICE: BUY ascending (lowest first); SELL descending (highest first)
      bool buySide = (side == POSITION_TYPE_BUY);
      for(int a = 1; a < nPool; a++)
         for(int b = a; b > 0; b--) {
            bool swap = false;
            if(buySide) {
               if(pxPool[b] < pxPool[b-1]) swap = true;
               else if(pxPool[b] == pxPool[b-1] && tkPool[b] < tkPool[b-1]) swap = true;
            } else {
               if(pxPool[b] > pxPool[b-1]) swap = true;
               else if(pxPool[b] == pxPool[b-1] && tkPool[b] < tkPool[b-1]) swap = true;
            }
            if(!swap) break;
            double _p = pxPool[b]; pxPool[b] = pxPool[b-1]; pxPool[b-1] = _p;
            ulong  _k = tkPool[b]; tkPool[b] = tkPool[b-1]; tkPool[b-1] = _k;
         }

      int take = MathMin(InpHero_OrderCount, nPool - 1); // keep ≥1 non-Hero
      if(take <= 0) continue;

      // FREEZE the stable set NOW — never replaced until phase resets to NONE
      ClearStableSet(sideId);
      for(int k = 0; k < take; k++) AddToStableSet(sideId, tkPool[k]);

      // Promote phase ARMED — reset opp accumulator (fresh window starts NOW)
      if(sideId == POSITION_TYPE_BUY) {
         g_heroPhase_Buy  = 2;
         g_oppBasketRealized_HeroBuy  = 0.0;
         g_oppBasketLastDealTime_HeroBuy = 0;
      } else {
         g_heroPhase_Sell = 2;
         g_oppBasketRealized_HeroSell = 0.0;
         g_oppBasketLastDealTime_HeroSell = 0;
      }
      sideHeroTagged[s] = take;

      // v1.57 — DO NOT clear g_heroNextAllowedSide on activation.
      //         The alternation gate is consumed only when the opposite Hero CYCLE actually closes
      //         (CloseHeroOnSide / external close / auto-release). Activating Hero alone is not enough.

      string fixedList = "";
      for(int k = 0; k < take; k++)
         fixedList += StringFormat(" #%I64u", tkPool[k]);
      Print("v1.56 Hero STABLE-SET FROZEN side=", (sideId==POSITION_TYPE_BUY?"BUY":"SELL"),
            " count=", take, " (ARMED — refresh by price-extreme until BE_GUARD):", fixedList);
   }

   // ============ STEP 4: Rebuild flat g_heroTickets[] from both stable sets ============
   g_heroTicketCount = 0;
   for(int i=0; i<g_heroBuyStableN  && g_heroTicketCount<200; i++) g_heroTickets[g_heroTicketCount++] = g_heroBuyStable[i];
   for(int i=0; i<g_heroSellStableN && g_heroTicketCount<200; i++) g_heroTickets[g_heroTicketCount++] = g_heroSellStable[i];

   // Dashboard ticket lists
   g_heroDash_BuyTicketN = 0;
   for(int i=0; i<g_heroBuyStableN  && g_heroDash_BuyTicketN  < 10; i++) g_heroDash_BuyTickets[g_heroDash_BuyTicketN++]  = g_heroBuyStable[i];
   g_heroDash_SellTicketN = 0;
   for(int i=0; i<g_heroSellStableN && g_heroDash_SellTicketN < 10; i++) g_heroDash_SellTickets[g_heroDash_SellTicketN++] = g_heroSellStable[i];

   // ============ STEP 5: Auto-release stale BE_GUARD when stable set is empty ============
   if(g_heroPhase_Buy == 3 && g_heroBuyStableN == 0) {
      Print("v1.49 Hero AUTO-RELEASE BUY: phase=BE_GUARD but stable set empty — releasing owner lock");
      g_heroPhase_Buy = 0; g_heroBE_Applied_Buy = false; g_heroJustClosed_Buy = TimeCurrent();
      g_heroLastClosedSide = (int)POSITION_TYPE_BUY;
      g_heroNextAllowedSide = (int)POSITION_TYPE_SELL; // v1.56 — opposite must take next turn
      Print("v1.56 Hero NEXT-ALLOWED set to SELL after BUY auto-release");
   }
   if(g_heroPhase_Sell == 3 && g_heroSellStableN == 0) {
      Print("v1.49 Hero AUTO-RELEASE SELL: phase=BE_GUARD but stable set empty — releasing owner lock");
      g_heroPhase_Sell = 0; g_heroBE_Applied_Sell = false; g_heroJustClosed_Sell = TimeCurrent();
      g_heroLastClosedSide = (int)POSITION_TYPE_SELL;
      g_heroNextAllowedSide = (int)POSITION_TYPE_BUY; // v1.56 — opposite must take next turn
      Print("v1.56 Hero NEXT-ALLOWED set to BUY after SELL auto-release");
   }

   // Phase fallback: keep ARMED if stable set populated, drop to NONE only if empty (BE_GUARD respected)
   if(g_heroPhase_Buy  != 3) g_heroPhase_Buy  = (g_heroBuyStableN  > 0) ? 2 : 0;
   if(g_heroPhase_Sell != 3) g_heroPhase_Sell = (g_heroSellStableN > 0) ? 2 : 0;

   g_heroDash_BuyActive  = sideTotalActive[0];
   g_heroDash_SellActive = sideTotalActive[1];
   g_heroDash_BuyTagged  = g_heroBuyStableN;
   g_heroDash_SellTagged = g_heroSellStableN;

   // Audit log every 30s
   static datetime lastHeroAuditLog = 0;
   if(TimeCurrent() - lastHeroAuditLog >= 30) {
      int minAct = (InpHero_MinOrdersToActivate > 0) ? InpHero_MinOrdersToActivate : (InpHero_OrderCount + 1);
      string roleB = (g_heroPhase_Buy  == 3) ? "OWNER" : (g_heroPhase_Buy  == 2) ? "CANDIDATE" : "NONE";
      string roleS = (g_heroPhase_Sell == 3) ? "OWNER" : (g_heroPhase_Sell == 2) ? "CANDIDATE" : "NONE";
      int    ownerSide = GetHeroOwnerSide();
      string ownerStr  = (ownerSide == (int)POSITION_TYPE_BUY)  ? "BUY"
                       : (ownerSide == (int)POSITION_TYPE_SELL) ? "SELL" : "NONE";
      string heroPxList = "";
      for(int i = 0; i < g_heroTicketCount; i++) {
         if(!PositionSelectByTicket(g_heroTickets[i])) continue;
         heroPxList += StringFormat(" #%I64u@%s", g_heroTickets[i],
                       DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN), g_digits));
      }
      string lcStr2 = (g_heroLastClosedSide == (int)POSITION_TYPE_BUY) ? "BUY"
                    : (g_heroLastClosedSide == (int)POSITION_TYPE_SELL) ? "SELL" : "-";
      Print("v1.49 Hero AUDIT [Sticky/StrictLock/Alt]: BUY ", roleB, " active=", sideTotalActive[0],
            " stable=", g_heroBuyStableN,
            " | SELL ", roleS, " active=", sideTotalActive[1],
            " stable=", g_heroSellStableN,
            " | OWNER=", ownerStr, " lastClosed=", lcStr2,
            " thr=", minAct, " N=", InpHero_OrderCount, " |", heroPxList);
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

// v1.45: ระหว่าง CANDIDATE/ARMED — ถอดเฉพาะ TP เพื่อกันโดน basket Avg-TP/per-order TP ปิดก่อนเวลา
//        คง SL เดิม (BE/cost-lock จาก Per-Order BE/Trail) เพื่อกันราคาวิ่งกลับทะลุทุน
//        เมื่อ basket ฝั่งเดียวกันปิดหมด phase->BE_GUARD แล้ว ApplyHeroLockProfitSL จะตั้ง SL ใหม่ทับ
void StripBrokerTPSLFromHeroTickets()
{
   if(!InpHero_Enabled || g_heroTicketCount == 0) return;
   static datetime lastDiagLog = 0;
   bool doLog = (TimeCurrent() - lastDiagLog) >= 30;
   string diag = "";
   for(int i = 0; i < g_heroTicketCount; i++) {
      ulong ticket = g_heroTickets[i];
      if(!PositionSelectByTicket(ticket)) continue;
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      int phase = (posType == POSITION_TYPE_BUY) ? g_heroPhase_Buy : g_heroPhase_Sell;
      if(phase == 3) continue; // BE_GUARD owns it (ApplyHeroLockProfitSL จัดการเอง)
      double curTP = PositionGetDouble(POSITION_TP);
      double curSL = PositionGetDouble(POSITION_SL);
      if(curTP == 0) continue; // TP ถอดอยู่แล้ว — ไม่ต้องแตะ SL
      // v1.45 ถอดเฉพาะ TP, คง SL เดิมไว้
      if(trade.PositionModify(ticket, curSL, 0)) {
         if(doLog) diag += StringFormat(" #%I64u(SL=%s)", ticket, DoubleToString(curSL, g_digits));
      }
   }
   if(doLog && StringLen(diag) > 0) {
      Print("v1.45 Hero CANDIDATE strip TP only (SL kept):", diag);
      lastDiagLog = TimeCurrent();
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
   ClearStableSet((int)side); // v1.49 — clear sticky set for this side
   // v1.51 — clear intent flags (consumed)
   g_oppCloseIntent_AvgTP_Buy  = false;
   g_oppCloseIntent_AvgTP_Sell = false;
   if(side == POSITION_TYPE_BUY) {
      g_heroPhase_Buy = 0; g_heroBE_Applied_Buy = false;
      g_heroJustClosed_Buy = TimeCurrent();
      g_oppBasketRealized_HeroBuy = 0.0;            // v1.50 reset
      g_oppBasketLastDealTime_HeroBuy = 0;
   } else {
      g_heroPhase_Sell = 0; g_heroBE_Applied_Sell = false;
      g_heroJustClosed_Sell = TimeCurrent();
      g_oppBasketRealized_HeroSell = 0.0;           // v1.50 reset
      g_oppBasketLastDealTime_HeroSell = 0;
   }
   // v1.46 Side-Alternation Lock — จำฝั่งที่เพิ่งปิด Hero
   g_heroLastClosedSide = (int)side;
   // v1.57 — opposite must take next Hero turn AND close it before this side may re-arm
   g_heroNextAllowedSide = (side == POSITION_TYPE_BUY) ? (int)POSITION_TYPE_SELL : (int)POSITION_TYPE_BUY;
   // v1.57 — clear TP-event latch belonging to the side we just closed; arm fresh latch reset
   if(side == POSITION_TYPE_BUY) { g_oppTPEvent_HeroBuy  = false; g_oppTPEventTime_HeroBuy  = 0; }
   else                          { g_oppTPEvent_HeroSell = false; g_oppTPEventTime_HeroSell = 0; }
   Print("v1.57 Hero LAST-CLOSED side=", EnumToString(side),
         " — NEXT-ALLOWED=", (g_heroNextAllowedSide==(int)POSITION_TYPE_BUY?"BUY":"SELL"),
         " (opposite Hero must complete its OWN cycle before this side re-arms)");
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
   // v1.46 — เคลียร์ alternation lock เมื่อฝั่งที่เพิ่งปิดกลับมา flat สนิท
   if(g_heroLastClosedSide == (int)side) {
      Print("v1.46 Hero ALTERNATION CLEAR — side=", EnumToString(side), " is flat");
      g_heroLastClosedSide = -1;
   }
}

// v6.96 Master orchestrator — runs every tick after BuildHeroTicketCache().
void ManageHeroOppositeClose()
{
   if(!InpHero_Enabled) return;

   StripBrokerTPSLFromHeroTickets();

   // v1.51 — auto-expire stale Avg-TP intent flags (basket re-armed without consuming flag, 60s timeout)
   {
      datetime now = TimeCurrent();
      if(g_oppCloseIntent_AvgTP_Buy && CountNonHeroMainOnSide(POSITION_TYPE_BUY) > 0
         && now - g_oppCloseIntentTime_Buy > 60) {
         Print("v1.51 Avg-TP intent EXPIRED side=BUY (basket re-armed)"); g_oppCloseIntent_AvgTP_Buy = false;
      }
      if(g_oppCloseIntent_AvgTP_Sell && CountNonHeroMainOnSide(POSITION_TYPE_SELL) > 0
         && now - g_oppCloseIntentTime_Sell > 60) {
         Print("v1.51 Avg-TP intent EXPIRED side=SELL (basket re-armed)"); g_oppCloseIntent_AvgTP_Sell = false;
      }
   }

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

   // v1.51 Tick-based opposite-clear detector — gated by Avg-TP intent flag (preferred) + realized P/L.
   //  Hero closes ONLY when opp basket flat AND opp was flattened by Avg-TP/Avg-Trail/Master TP/Accumulate.
   //  Per-Order Trail / SL / Cost-Hit / manual close => Hero HOLDS locked at BE-SL.
   // v1.57 — TP-EVENT LATCH FAST CLOSE: if a TP/Avg-TP event was logged on the opposite basket,
   //          close Hero immediately even if AutoReEntry/Grid already opened a NEW opposite ticket
   //          on the same tick (legacy gate required CountNonHeroMainOnSide(opp)==0 which races).
   for(int sL = 0; sL < 2; sL++) {
      ENUM_POSITION_TYPE side = (sL == 0) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
      ENUM_POSITION_TYPE opp  = (sL == 0) ? POSITION_TYPE_SELL : POSITION_TYPE_BUY;
      int phase = (side == POSITION_TYPE_BUY) ? g_heroPhase_Buy : g_heroPhase_Sell;
      if(phase != 3) continue;
      if(CountHeroOnSide(side) <= 0) continue;
      bool latch = (side == POSITION_TYPE_BUY) ? g_oppTPEvent_HeroBuy : g_oppTPEvent_HeroSell;
      if(!latch) continue;
      double oppRealized = (side == POSITION_TYPE_BUY) ? g_oppBasketRealized_HeroBuy
                                                       : g_oppBasketRealized_HeroSell;
      if(InpHero_OppCloseRequireTP && oppRealized <= InpHero_OppCloseMinProfit) {
         // Wait for accumulator to confirm net profit (TP event may still be settling)
         continue;
      }
      Print("v1.57 Hero CLOSE (opp TP-event latch): heroSide=", EnumToString(side),
            " oppSide=", EnumToString(opp),
            " oppRealized=", DoubleToString(oppRealized, 2),
            " heroProfit=", DoubleToString(SumHeroProfitOnSide(side), 2));
      CloseHeroOnSide(side, "OppositeTPEventLatch");
      g_oppCloseIntent_AvgTP_Buy  = false;
      g_oppCloseIntent_AvgTP_Sell = false;
   }

   for(int s2 = 0; s2 < 2; s2++) {
      ENUM_POSITION_TYPE side = (s2 == 0) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
      ENUM_POSITION_TYPE opp  = (s2 == 0) ? POSITION_TYPE_SELL : POSITION_TYPE_BUY;
      int phase = (side == POSITION_TYPE_BUY) ? g_heroPhase_Buy : g_heroPhase_Sell;
      if(phase != 3) continue;
      if(CountHeroOnSide(side) <= 0) continue;
      if(CountNonHeroMainOnSide(opp) > 0) continue;
      if(CountHeroOnSide(opp) > 0) continue;

      double oppRealized = (side == POSITION_TYPE_BUY) ? g_oppBasketRealized_HeroBuy
                                                       : g_oppBasketRealized_HeroSell;
      bool   intentFlag  = (opp  == POSITION_TYPE_BUY) ? g_oppCloseIntent_AvgTP_Buy
                                                       : g_oppCloseIntent_AvgTP_Sell;

      // v1.51 — Avg-TP intent gate (primary)
      if(InpHero_OppCloseRequireAvgTP && !intentFlag) {
         static datetime lastHoldLog_B51 = 0, lastHoldLog_S51 = 0;
         datetime lastLog51 = (side == POSITION_TYPE_BUY) ? lastHoldLog_B51 : lastHoldLog_S51;
         if(TimeCurrent() - lastLog51 >= 30) {
            Print("v1.51 Hero HOLD heroSide=", EnumToString(side),
                  " oppSide=", EnumToString(opp),
                  " — opp basket flat WITHOUT Avg-TP intent (Per-Order Trail/SL/Cost-Hit) — keep Hero locked at BE-SL");
            if(side == POSITION_TYPE_BUY) lastHoldLog_B51 = TimeCurrent();
            else                          lastHoldLog_S51 = TimeCurrent();
         }
         // Reset opp accumulator so next basket cycle is judged fresh
         if(side == POSITION_TYPE_BUY) g_oppBasketRealized_HeroBuy  = 0.0;
         else                          g_oppBasketRealized_HeroSell = 0.0;
         continue;
      }

      // v1.50 — TP/profit gate (secondary, retained)
      if(InpHero_OppCloseRequireTP) {
         if(oppRealized <= InpHero_OppCloseMinProfit) {
            static datetime lastHoldLog_B = 0, lastHoldLog_S = 0;
            datetime lastLog = (side == POSITION_TYPE_BUY) ? lastHoldLog_B : lastHoldLog_S;
            if(TimeCurrent() - lastLog >= 30) {
               Print("v1.50 Hero HOLD heroSide=", EnumToString(side),
                     " oppSide=", EnumToString(opp), " oppRealized=", DoubleToString(oppRealized, 2),
                     " minTP=", DoubleToString(InpHero_OppCloseMinProfit, 2),
                     " — opp realized below min profit, keep Hero locked at BE-SL");
               if(side == POSITION_TYPE_BUY) lastHoldLog_B = TimeCurrent();
               else                          lastHoldLog_S = TimeCurrent();
            }
            if(side == POSITION_TYPE_BUY) g_oppBasketRealized_HeroBuy  = 0.0;
            else                          g_oppBasketRealized_HeroSell = 0.0;
            continue;
         }
      }

      Print("v1.51 Hero CLOSE (opp Avg-TP intent + realized): heroSide=", EnumToString(side),
            " oppSide=", EnumToString(opp),
            " oppRealized=", DoubleToString(oppRealized, 2),
            " intent=", (intentFlag?"YES":"NO"),
            " heroProfit=", DoubleToString(SumHeroProfitOnSide(side), 2));
      CloseHeroOnSide(side, "OppositeBasketAvgTPClose");
      // Clear intent flags after consuming
      g_oppCloseIntent_AvgTP_Buy  = false;
      g_oppCloseIntent_AvgTP_Sell = false;
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
      if(IsHeroProtectedTicket(pos.Ticket())) continue; // v1.3: Hero managed separately
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
      if(IsHeroProtectedTicket(pos.Ticket())) continue; // v1.3: never close Hero via per-side close
      trade.PositionClose(pos.Ticket());
   }
}

void CloseAllOurs()
{
   for(int i=PositionsTotal()-1;i>=0;i--){
      if(!pos.SelectByIndex(i)) continue;
      if(!IsOurPosition()) continue;
      if(IsHeroProtectedTicket(pos.Ticket())) continue; // v1.3
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
      if(IsHeroProtectedTicket(pos.Ticket())) continue;
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
      if(IsHeroProtectedTicket(pos.Ticket())) continue;
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
      if(IsHeroProtectedTicket(pos.Ticket())) continue; // v1.3: keep Hero SL/TP intact
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
         // v1.51 — mark intent on BOTH sides (CloseAllOurs flattens both baskets)
         g_oppCloseIntent_AvgTP_Buy  = true; g_oppCloseIntentTime_Buy  = TimeCurrent();
         g_oppCloseIntent_AvgTP_Sell = true; g_oppCloseIntentTime_Sell = TimeCurrent();
         CloseAllOurs();
         return;
      }
   }

   double bal = AccountInfoDouble(ACCOUNT_BALANCE);

   for(int sideIdx=0; sideIdx<2; sideIdx++){
      int side = (sideIdx==0)?POSITION_TYPE_BUY:POSITION_TYPE_SELL;
      int n = CountNonHeroMainOnSide((ENUM_POSITION_TYPE)side); // v1.42 exclude Hero
      if(n<=0) continue;

      double pl = CalcSideFloating_NonHero(side); // v1.3

      // 2. Fixed dollar
      if(InpUseTPFixedDollar && InpTPDollarAmount>0 && pl >= InpTPDollarAmount){
         Print("GK TP DOLLAR ",(side==POSITION_TYPE_BUY?"BUY":"SELL")," PL=",DoubleToString(pl,2));
         // v1.51 — mark intent for this side
         if(side==POSITION_TYPE_BUY){ g_oppCloseIntent_AvgTP_Buy=true;  g_oppCloseIntentTime_Buy =TimeCurrent(); }
         else                       { g_oppCloseIntent_AvgTP_Sell=true; g_oppCloseIntentTime_Sell=TimeCurrent(); }
         CloseAllSide(side);
         continue;
      }

      // 3. % of balance
      if(InpUseTPPercentBalance && InpTPPercentOfBalance>0 && bal>0){
         double tgt = bal * InpTPPercentOfBalance / 100.0;
         if(pl >= tgt){
            Print("GK TP %BAL ",(side==POSITION_TYPE_BUY?"BUY":"SELL")," PL=",DoubleToString(pl,2)," tgt=",DoubleToString(tgt,2));
            // v1.51 — mark intent for this side
            if(side==POSITION_TYPE_BUY){ g_oppCloseIntent_AvgTP_Buy=true;  g_oppCloseIntentTime_Buy =TimeCurrent(); }
            else                       { g_oppCloseIntent_AvgTP_Sell=true; g_oppCloseIntentTime_Sell=TimeCurrent(); }
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
            if(IsHeroProtectedTicket(pos.Ticket())) continue; // v1.3
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
               g_oppCloseIntent_AvgTP_Buy = true; g_oppCloseIntentTime_Buy = TimeCurrent(); // v1.51
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
               g_oppCloseIntent_AvgTP_Sell = true; g_oppCloseIntentTime_Sell = TimeCurrent(); // v1.51
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
      if(IsHeroProtectedTicket(pos.Ticket())) continue; // v1.3
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
   // v1.49 — display lines exclude Hero/Candidate so chart matches actual TP logic
   double avgB = CalcSideAvgPrice_NonHero(POSITION_TYPE_BUY,  tlB, cB);
   double avgS = CalcSideAvgPrice_NonHero(POSITION_TYPE_SELL, tlS, cS);

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

   DashHeader(StringFormat("Golden Kuy3 v1.57  Side:%s Grid:%s/%s", SideModeStr(), GridModeStr(), LotModeStr()));

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

   DashHeader("=== HERO ORDER (v1.57) ===");
   DashRow("Hero Cfg", StringFormat("%s  N=%d minAct=%d BE=%dpt  Mode=ARMED-DYN Lock=%s Alt=%s",
                          OnOff(InpHero_Enabled), InpHero_OrderCount,
                          InpHero_MinOrdersToActivate, InpHero_BE_OffsetPoints,
                          (InpHero_SingleSideLock?"STRICT":"OFF"),
                          (InpHero_AlternateSides?"ON":"OFF")),
                          (InpHero_Enabled?gold:warn));
   {
      int ownerSide = GetHeroOwnerSide();
      string ownerStr = (ownerSide == (int)POSITION_TYPE_BUY)  ? "BUY (locked)"
                      : (ownerSide == (int)POSITION_TYPE_SELL) ? "SELL (locked)"
                      : (g_heroPhase_Buy == 2 || g_heroPhase_Sell == 2) ? "NONE (waiting close)" : "NONE";
      color ownClr = (ownerSide >= 0) ? gold : ((g_heroPhase_Buy==2||g_heroPhase_Sell==2)?warn:info);
      DashRow("Hero Owner", ownerStr, ownClr);
      string lcStr = (g_heroLastClosedSide == (int)POSITION_TYPE_BUY)  ? "BUY"
                   : (g_heroLastClosedSide == (int)POSITION_TYPE_SELL) ? "SELL" : "-";
      DashRow("Last Closed", lcStr, (g_heroLastClosedSide>=0?warn:info));
      string nextStr = (g_heroNextAllowedSide == (int)POSITION_TYPE_BUY)  ? "BUY only"
                     : (g_heroNextAllowedSide == (int)POSITION_TYPE_SELL) ? "SELL only" : "ANY";
      DashRow("Next Allowed", nextStr, (g_heroNextAllowedSide>=0?warn:info));
      string tpEvStr = "-";
      if(g_oppTPEvent_HeroBuy)  tpEvStr = "SELL->BUY (waiting close)";
      if(g_oppTPEvent_HeroSell) tpEvStr = (tpEvStr=="-") ? "BUY->SELL (waiting close)" : "BOTH";
      DashRow("TP Event", tpEvStr, ((g_oppTPEvent_HeroBuy||g_oppTPEvent_HeroSell)?gold:info));
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

               // v1.50 — Accumulate opp-basket realized P/L per Hero side.
               //  When a non-Hero ticket of side X closes, attribute P/L to Hero of opp(X) if armed.
               if(InpHero_Enabled){
                  long dealTypeH = HistoryDealGetInteger(trans.deal, DEAL_TYPE);
                  int closedSideH = (dealTypeH == DEAL_TYPE_SELL) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
                  ulong posTicketH = (ulong)trans.position;
                  bool wasHero = IsHeroProtectedTicket(posTicketH);
                  if(!wasHero){
                     // Closed ticket is opp basket relative to Hero on the OTHER side.
                     int heroSide = (closedSideH == POSITION_TYPE_BUY) ? POSITION_TYPE_SELL : POSITION_TYPE_BUY;
                     int heroPhase = (heroSide == POSITION_TYPE_BUY) ? g_heroPhase_Buy : g_heroPhase_Sell;
                     if(heroPhase == 2 || heroPhase == 3){
                        if(heroSide == POSITION_TYPE_BUY){
                           g_oppBasketRealized_HeroBuy  += pr;
                           g_oppBasketLastDealTime_HeroBuy = TimeCurrent();
                        } else {
                           g_oppBasketRealized_HeroSell += pr;
                           g_oppBasketLastDealTime_HeroSell = TimeCurrent();
                        }
                        // v1.57 — TP-event latch: if BE_GUARD and the closing reason was TP / Avg-TP intent,
                        //         arm latch so Hero closes even if AutoReEntry/Grid opens new opp ticket same tick.
                        if(heroPhase == 3){
                           long reasonE = HistoryDealGetInteger(trans.deal, DEAL_REASON);
                           bool intentE = (closedSideH == POSITION_TYPE_BUY) ? g_oppCloseIntent_AvgTP_Buy
                                                                              : g_oppCloseIntent_AvgTP_Sell;
                           if(reasonE == DEAL_REASON_TP || intentE){
                              if(heroSide == POSITION_TYPE_BUY) { g_oppTPEvent_HeroBuy  = true; g_oppTPEventTime_HeroBuy  = TimeCurrent(); }
                              else                              { g_oppTPEvent_HeroSell = true; g_oppTPEventTime_HeroSell = TimeCurrent(); }
                              Print("v1.57 Hero TP-EVENT LATCH ARMED heroSide=", (heroSide==POSITION_TYPE_BUY?"BUY":"SELL"),
                                    " closedSide=", (closedSideH==POSITION_TYPE_BUY?"BUY":"SELL"),
                                    " reason=", reasonE, " intent=", (intentE?"YES":"NO"));
                           }
                        }
                        Print("v1.50 OppBasket dealOut heroSide=", (heroSide==POSITION_TYPE_BUY?"BUY":"SELL"),
                              " closedSide=", (closedSideH==POSITION_TYPE_BUY?"BUY":"SELL"),
                              " pr=", DoubleToString(pr,2),
                              " accum=", DoubleToString(heroSide==POSITION_TYPE_BUY?g_oppBasketRealized_HeroBuy:g_oppBasketRealized_HeroSell,2));
                     }

                     // v1.51 — Master TP Points safety net: detect simultaneous broker TP closes (>=N within 2s)
                     //   on a side. If so, auto-set Avg-TP intent flag for that side so Hero gate can fire.
                     if(InpUseTPPoints){
                        long reasonH = HistoryDealGetInteger(trans.deal, DEAL_REASON);
                        if(reasonH == DEAL_REASON_TP){
                           datetime now = TimeCurrent();
                           int needed = MathMax(2, InpAvgTP_MinOrders);
                           if(closedSideH == POSITION_TYPE_BUY){
                              if(now - g_oppTPDealWindow_Buy > 2) { g_oppTPDealCount_Buy = 0; g_oppTPDealWindow_Buy = now; }
                              g_oppTPDealCount_Buy++;
                              if(g_oppTPDealCount_Buy >= needed && !g_oppCloseIntent_AvgTP_Buy){
                                 g_oppCloseIntent_AvgTP_Buy = true; g_oppCloseIntentTime_Buy = now;
                                 Print("v1.51 Master-TP intent AUTO-SET side=BUY (",g_oppTPDealCount_Buy," TP closes in 2s)");
                              }
                           } else {
                              if(now - g_oppTPDealWindow_Sell > 2) { g_oppTPDealCount_Sell = 0; g_oppTPDealWindow_Sell = now; }
                              g_oppTPDealCount_Sell++;
                              if(g_oppTPDealCount_Sell >= needed && !g_oppCloseIntent_AvgTP_Sell){
                                 g_oppCloseIntent_AvgTP_Sell = true; g_oppCloseIntentTime_Sell = now;
                                 Print("v1.51 Master-TP intent AUTO-SET side=SELL (",g_oppTPDealCount_Sell," TP closes in 2s)");
                              }
                           }
                        }
                     }
                  }
               }

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
   // v1.42 — Reset accumulate cycle when fully flat (Gold Miner concept)
   if(trans.type==TRADE_TRANSACTION_DEAL_ADD){
      TryResetAccumulateCycleIfFlat();
   }
}

// v1.42 — Gold Miner-style cycle reset: when no EA position exists, zero realized
void TryResetAccumulateCycleIfFlat()
{
   if(CountSideSimple(POSITION_TYPE_BUY)==0 && CountSideSimple(POSITION_TYPE_SELL)==0){
      if(MathAbs(g_realizedCycle) > 0.0001){
         Print("GK ACCUM CYCLE RESET — flat detected. prev realized=",
               DoubleToString(g_realizedCycle,2));
         g_realizedCycle = 0.0;
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

   Print("Golden Kuy3 v1.57 init  digits=",g_digits," pip=",g_pip," stopsLvl=",g_stopsLevel,
         " | Hero=", InpHero_Enabled?"ON":"OFF", " HeroN=", InpHero_OrderCount,
         " minAct=", InpHero_MinOrdersToActivate, " BE=", InpHero_BE_OffsetPoints, "pt");
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   DelDash();
   DelLines();
   Print("Golden Kuy3 v1.57 deinit reason=",reason);
}

void OnTick()
{
   TryResetAccumulateCycleIfFlat();   // v1.42 — Gold Miner cycle reset
   BuildHeroTicketCache();      // v1.4 — must run first
   ManageHeroOppositeClose();   // v1.4 — orchestrator (strip TP/SL, BE_GUARD, opp-clear close)
   ManageCostHitRestart();
   ManageInitialEntry();
   ManageGridEntry();
   // v1.54 — re-run Hero refresh AFTER order-entry modules so brand-new tickets
   //         are immediately considered for price-extreme Hero selection
   //         (prevents stale Hero set / dashboard showing old tickets).
   BuildHeroTicketCache();
   ManageHeroOppositeClose();
   ManagePerOrderTrailing();
   ManageTakeProfit();
   ManageAverageTrailing();
   EnforceClearTPIfDisabled();
   DrawAvgAndTPLines();
   DrawDashboard();
}
//+------------------------------------------------------------------+
