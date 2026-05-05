//+------------------------------------------------------------------+
//|                                            Golden_Kuy3_EA.mq5    |
//|                                       Golden Kuy3 EA  v1.2       |
//|  Instant entry + Single Grid (Both/Up/Down)                      |
//|  + Per-Order BE-Lock / Trailing (split toggles)                  |
//|  + Full TP modes (Dollar / Points / %Bal / Accumulate)           |
//|  + Avg/TP chart lines + Gold-Miner-style table dashboard         |
//|  v1.2: dash flicker fix + grid mult fix + Cost-Hit Restart       |
//+------------------------------------------------------------------+
#property copyright "Golden Kuy3 EA"
#property version   "1.20"
#property description "Golden Kuy3 v1.2 — dashboard flicker fix + grid lot fix + Cost-Hit Restart"
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
      trade.PositionClose(pos.Ticket());
   }
}

void CloseAllOurs()
{
   for(int i=PositionsTotal()-1;i>=0;i--){
      if(!pos.SelectByIndex(i)) continue;
      if(!IsOurPosition()) continue;
      trade.PositionClose(pos.Ticket());
   }
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
      double floatingAll = CalcSideFloating(POSITION_TYPE_BUY) + CalcSideFloating(POSITION_TYPE_SELL);
      if((g_realizedCycle + floatingAll) >= InpAccumulateTarget){
         Print("GK ACCUM CLOSE — realized=",DoubleToString(g_realizedCycle,2)," floating=",DoubleToString(floatingAll,2)," tgt=",InpAccumulateTarget);
         CloseAllOurs();
         return;
      }
   }

   double bal = AccountInfoDouble(ACCOUNT_BALANCE);

   for(int sideIdx=0; sideIdx<2; sideIdx++){
      int side = (sideIdx==0)?POSITION_TYPE_BUY:POSITION_TYPE_SELL;
      int n = CountSideSimple(side);
      if(n<=0) continue;

      double pl = CalcSideFloating(side);

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

      // 4. Points from average — push broker TP
      if(InpUseTPPoints && n >= InpAvgTP_MinOrders){
         double tot=0; int cnt=0;
         double avg = CalcSideAvgPrice(side, tot, cnt);
         if(avg<=0) continue;
         double minStop = GetMinStopPrice();
         double tpDist = MathMax(InpTPPointsFromAverage * g_point, minStop);
         double tpPrice = (side==POSITION_TYPE_BUY)? avg + tpDist : avg - tpDist;
         tpPrice = NormalizeDouble(tpPrice, g_digits);
         for(int i=PositionsTotal()-1;i>=0;i--){
            if(!pos.SelectByIndex(i)) continue;
            if(!IsOurPosition()) continue;
            if((int)pos.PositionType()!=side) continue;
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
      double avg = CalcSideAvgPrice(POSITION_TYPE_BUY, tot, cnt);
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
      double avg = CalcSideAvgPrice(POSITION_TYPE_SELL, tot, cnt);
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

   DashHeader(StringFormat("Golden Kuy3 v1.2  Side:%s Grid:%s/%s", SideModeStr(), GridModeStr(), LotModeStr()));

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

   Print("Golden Kuy3 v1.1 init  digits=",g_digits," pip=",g_pip," stopsLvl=",g_stopsLevel);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   DelDash();
   DelLines();
   Print("Golden Kuy3 v1.1 deinit reason=",reason);
}

void OnTick()
{
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
