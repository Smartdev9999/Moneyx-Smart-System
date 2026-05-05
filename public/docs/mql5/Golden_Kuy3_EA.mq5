//+------------------------------------------------------------------+
//|                                            Golden_Kuy3_EA.mq5    |
//|                                       Golden Kuy3 EA  v1.0       |
//|  Instant entry (no indicator) + Single Grid (Both/Up/Down)       |
//|  + Per-Order Trailing + Average TP + Average Trailing            |
//|  Ported subsystems from Gold Miner EA (v6.85/v6.86/v6.90/v6.91)  |
//+------------------------------------------------------------------+
#property copyright "Golden Kuy3 EA"
#property version   "1.00"
#property description "Golden Kuy3 v1.0 — Instant + Grid + AvgTP + AvgTrailing (no indicator)"
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
input double               InpInitialTPPips        = 200.0;     // 0 = none
input double               InpInitialSLPips        = 0.0;       // 0 = none
input bool                 InpAutoReEntry          = true;      // re-enter side after it goes flat
input int                  InpReEntryCooldownSec   = 5;
input int                  InpSlippagePoints       = 30;

input group "=== Grid (single set) ==="
input bool                 InpEnableGrid           = true;
input ENUM_GK_GRID_SIDE    InpGridSideMode         = GK_GRID_BOTH;     // BOTH / UP / DOWN relative to last ticket
input double               InpGridDistancePips     = 150.0;
input ENUM_GK_GRID_LOT     InpGridLotMode          = GK_LOT_MULTIPLY;
input double               InpGridLotValue         = 1.5;              // FIXED=lot, ADD=+x, MULT=*x
input int                  InpMaxGridOrders        = 20;               // per side, excl. initial
input bool                 InpGridOnlyNewCandle    = true;
input ENUM_TIMEFRAMES      InpGridCandleTF         = PERIOD_M1;

input group "=== Per-Order Trailing (Gold Miner style) ==="
input bool                 InpEnablePerOrderTrailing  = false;
input double               InpTrailingActivationPips  = 80.0;
input double               InpTrailingStepPips        = 20.0;
input double               InpBreakevenActivationPips = 50.0;
input double               InpBreakevenBufferPips     = 10.0;

input group "=== Average TP (Gold Miner style) ==="
input bool                 InpEnableAverageTP      = true;
input double               InpAverageTPPips        = 50.0;
input int                  InpAvgTP_MinOrders      = 2;

input group "=== Average Trailing Stop (Gold Miner v6.85/86/90/91) ==="
input bool                 InpEnableAvgTrailing       = true;
input double               InpAvgTrail_ActivationPips = 100.0;
input double               InpAvgTrail_StepPips       = 20.0;
input double               InpAvgTrail_BE_Buffer      = 20.0;
input int                  InpAvgTrail_MinOrders      = 3;
input bool                 InpAvgTrail_Strict2Cross   = true;
input double               InpAvgTrail_UnderAvgBuffer = 50.0;     // points below/above avg required to "cross under"

input group "=== Dashboard ==="
input bool                 InpShowDashboard        = true;
input int                  InpDashRefreshSec       = 1;
input color                InpDashTextColor        = clrWhite;
input color                InpDashBgColor          = clrDarkSlateGray;

//========================= GLOBALS =================================
double  g_pip            = 0.0;   // 1 pip in price (0.10 for 5-digit gold, 0.0001 for 5-digit fx)
double  g_point          = 0.0;
int     g_digits         = 0;
double  g_stopsLevel     = 0.0;

datetime g_lastReEntry_Buy   = 0;
datetime g_lastReEntry_Sell  = 0;
datetime g_lastGridBar_Buy   = 0;
datetime g_lastGridBar_Sell  = 0;

// Initial center price (open price of side's INIT ticket)
double  g_initPrice_Buy  = 0.0;
double  g_initPrice_Sell = 0.0;

// Per-order trailing virtual SL cache (keyed on ticket)
// We rely on broker SL since we push it; no extra cache needed beyond that.

// Avg trailing state
bool    g_avgTrail_Active_Buy   = false;
bool    g_avgTrail_Active_Sell  = false;
double  g_avgTrail_SL_Buy       = 0.0;
double  g_avgTrail_SL_Sell      = 0.0;
bool    g_avgTrail_ArmReady_Buy  = false;  // strict 2-cross gate
bool    g_avgTrail_ArmReady_Sell = false;

datetime g_lastDashTime = 0;

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
   double v = InpGridLotValue;
   double l = InpInitialLot;
   if(InpGridLotMode == GK_LOT_FIXED)         l = v;
   else if(InpGridLotMode == GK_LOT_ADD)      l = (lastLot>0?lastLot:InpInitialLot) + v;
   else if(InpGridLotMode == GK_LOT_MULTIPLY) l = (lastLot>0?lastLot:InpInitialLot) * v;
   return NormalizeLot(l);
}

bool SideAllowedForInit(int side)
{
   if(InpInitSideMode == GK_SIDE_BOTH)      return true;
   if(InpInitSideMode == GK_SIDE_BUY_ONLY)  return side == POSITION_TYPE_BUY;
   if(InpInitSideMode == GK_SIDE_SELL_ONLY) return side == POSITION_TYPE_SELL;
   return false;
}

double GetMinStopPrice() { return g_stopsLevel * g_point; }

//========================== ENTRY ==================================
bool OpenInitial(int side)
{
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double price = (side==POSITION_TYPE_BUY)?ask:bid;
   double sl=0, tp=0;
   double minStop = GetMinStopPrice();

   if(InpInitialTPPips>0){
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
   // Side BUY
   if(SideAllowedForInit(POSITION_TYPE_BUY)){
      int n = CountSideSimple(POSITION_TYPE_BUY);
      if(n==0 && (TimeCurrent()-g_lastReEntry_Buy) >= InpReEntryCooldownSec){
         if(g_lastReEntry_Buy==0 || InpAutoReEntry) OpenInitial(POSITION_TYPE_BUY);
      }
   }
   // Side SELL
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

   // BUY side
   {
      string lc; ulong ltk; double llot, lprice;
      int n = CountSide(POSITION_TYPE_BUY, lc, ltk, llot, lprice);
      if(n>0 && (n-1) < InpMaxGridOrders){   // -1 for initial
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
               OpenGrid(POSITION_TYPE_BUY, newLot, NextGridIndex(POSITION_TYPE_BUY));
            }
         }
      }
   }

   // SELL side
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
               OpenGrid(POSITION_TYPE_SELL, newLot, NextGridIndex(POSITION_TYPE_SELL));
            }
         }
      }
   }
}

//================ PER-ORDER TRAILING (broker SL) ===================
double ComputePerOrderSL(int side, double openPrice, double curBid, double curAsk)
{
   double profitPips = (side==POSITION_TYPE_BUY)
                        ? PriceToPips(curBid - openPrice)
                        : PriceToPips(openPrice - curAsk);

   if(profitPips < InpBreakevenActivationPips) return 0.0;

   double slPrice = 0.0;
   // Breakeven baseline
   double bePips = InpBreakevenBufferPips;
   if(side==POSITION_TYPE_BUY)  slPrice = openPrice + PipsToPrice(bePips);
   else                          slPrice = openPrice - PipsToPrice(bePips);

   if(profitPips >= InpTrailingActivationPips){
      // trail by step
      double trailPips = profitPips - InpTrailingStepPips;
      if(trailPips < InpBreakevenBufferPips) trailPips = InpBreakevenBufferPips;
      if(side==POSITION_TYPE_BUY)  slPrice = openPrice + PipsToPrice(trailPips);
      else                          slPrice = openPrice - PipsToPrice(trailPips);
   }
   return slPrice;
}

void ManagePerOrderTrailing()
{
   if(!InpEnablePerOrderTrailing) return;
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

      // honor stops level
      if(side==POSITION_TYPE_BUY){
         if(bid - newSL < minStop) newSL = bid - minStop;
         if(curSL>0 && newSL <= curSL) continue;
      } else {
         if(newSL - ask < minStop) newSL = ask + minStop;
         if(curSL>0 && newSL >= curSL) continue;
      }

      // Skip overwriting if AvgTrail SL already tighter
      // (handled by SyncBrokerTPSL ordering — per-order runs first, then avg trailing & avg TP overwrite)
      trade.PositionModify(pos.Ticket(), NormalizeDouble(newSL, g_digits), pos.TakeProfit());
   }
}

//==================== AVERAGE TP (broker push) =====================
void ManageAverageTP()
{
   if(!InpEnableAverageTP) return;
   double minStop = GetMinStopPrice();

   for(int sideIdx=0; sideIdx<2; sideIdx++){
      int side = (sideIdx==0)?POSITION_TYPE_BUY:POSITION_TYPE_SELL;
      double tot=0; int cnt=0;
      double avg = CalcSideAvgPrice(side, tot, cnt);
      if(cnt < InpAvgTP_MinOrders) continue;
      if(avg<=0) continue;

      double tpDist = MathMax(PipsToPrice(InpAverageTPPips), minStop);
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

//================ AVG TRAILING (Gold Miner v6.91) ==================
void ResetAvgTrailBuy()  { g_avgTrail_Active_Buy=false;  g_avgTrail_SL_Buy=0;  g_avgTrail_ArmReady_Buy=false; }
void ResetAvgTrailSell() { g_avgTrail_Active_Sell=false; g_avgTrail_SL_Sell=0; g_avgTrail_ArmReady_Sell=false;}

void ManageAverageTrailing()
{
   if(!InpEnableAvgTrailing) return;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double minStop = GetMinStopPrice();

   // ---------------- BUY ----------------
   {
      double tot=0; int cnt=0;
      double avg = CalcSideAvgPrice(POSITION_TYPE_BUY, tot, cnt);
      if(cnt >= InpAvgTrail_MinOrders && avg>0){
         // strict 2-cross arm-ready
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
            // trail
            double trailPips = profitPips - InpAvgTrail_StepPips;
            if(trailPips < InpAvgTrail_BE_Buffer) trailPips = InpAvgTrail_BE_Buffer;
            double newSL = avg + PipsToPrice(trailPips);
            if(newSL > g_avgTrail_SL_Buy) g_avgTrail_SL_Buy = newSL;

            // hit?
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

   // ---------------- SELL ----------------
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

   // Push avg-trail SL onto broker tickets if armed (overrides per-order trailing)
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

void CloseAllSide(int side)
{
   for(int i=PositionsTotal()-1;i>=0;i--){
      if(!pos.SelectByIndex(i)) continue;
      if(!IsOurPosition()) continue;
      if((int)pos.PositionType()!=side) continue;
      trade.PositionClose(pos.Ticket());
   }
}

//=========================== DASHBOARD =============================
string g_dashPrefix = "GK_DASH_";

void DelDash()
{
   ObjectsDeleteAll(0, g_dashPrefix);
}

void SetLabel(string name, int x, int y, string text, color clr, int sz=9)
{
   string n = g_dashPrefix + name;
   if(ObjectFind(0,n)<0) ObjectCreate(0,n,OBJ_LABEL,0,0,0);
   ObjectSetInteger(0,n,OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0,n,OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0,n,OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0,n,OBJPROP_COLOR, clr);
   ObjectSetInteger(0,n,OBJPROP_FONTSIZE, sz);
   ObjectSetString(0,n,OBJPROP_TEXT, text);
   ObjectSetString(0,n,OBJPROP_FONT,"Consolas");
   ObjectSetInteger(0,n,OBJPROP_BACK, false);
   ObjectSetInteger(0,n,OBJPROP_SELECTABLE,false);
}

string SideModeStr(){ if(InpInitSideMode==GK_SIDE_BUY_ONLY) return "BUY"; if(InpInitSideMode==GK_SIDE_SELL_ONLY) return "SELL"; return "BOTH"; }
string GridModeStr(){ if(InpGridSideMode==GK_GRID_UP_ONLY)  return "UP";  if(InpGridSideMode==GK_GRID_DOWN_ONLY) return "DOWN"; return "BOTH"; }
string LotModeStr() { if(InpGridLotMode==GK_LOT_FIXED) return "FIXED"; if(InpGridLotMode==GK_LOT_ADD) return "ADD"; return "MULT"; }

void DrawDashboard()
{
   if(!InpShowDashboard) return;
   if(TimeCurrent() - g_lastDashTime < InpDashRefreshSec) return;
   g_lastDashTime = TimeCurrent();

   int x=10, y=20, lh=15;
   color title=clrGold, head=clrAqua, ok=clrLime, warn=clrOrange, bad=clrTomato, txt=InpDashTextColor;

   SetLabel("title", x, y, StringFormat("Golden Kuy3 v1.0   Side:%s   Grid:%s/%s", SideModeStr(), GridModeStr(), LotModeStr()), title, 11);
   y+=lh+4;

   double tlB=0,tlS=0; int cB=0,cS=0;
   double avgB = CalcSideAvgPrice(POSITION_TYPE_BUY,  tlB, cB);
   double avgS = CalcSideAvgPrice(POSITION_TYPE_SELL, tlS, cS);
   double plB = CalcSideFloating(POSITION_TYPE_BUY);
   double plS = CalcSideFloating(POSITION_TYPE_SELL);

   SetLabel("hbuy", x,y,"--- BUY ---", head); y+=lh;
   SetLabel("buy1", x,y, StringFormat("Cnt:%d  Lot:%.2f  Avg:%s  PL:%.2f", cB, tlB, (avgB>0?DoubleToString(avgB,g_digits):"-"), plB),
            (plB>=0?ok:bad)); y+=lh;
   SetLabel("buy2", x,y, StringFormat("InitPx:%s  AvgTrail:%s SL:%s",
            (g_initPrice_Buy>0?DoubleToString(g_initPrice_Buy,g_digits):"-"),
            (g_avgTrail_Active_Buy?"ARMED":(g_avgTrail_ArmReady_Buy?"READY":"WAIT")),
            (g_avgTrail_SL_Buy>0?DoubleToString(g_avgTrail_SL_Buy,g_digits):"-")),
            (g_avgTrail_Active_Buy?ok:warn)); y+=lh+3;

   SetLabel("hsel", x,y,"--- SELL ---", head); y+=lh;
   SetLabel("sel1", x,y, StringFormat("Cnt:%d  Lot:%.2f  Avg:%s  PL:%.2f", cS, tlS, (avgS>0?DoubleToString(avgS,g_digits):"-"), plS),
            (plS>=0?ok:bad)); y+=lh;
   SetLabel("sel2", x,y, StringFormat("InitPx:%s  AvgTrail:%s SL:%s",
            (g_initPrice_Sell>0?DoubleToString(g_initPrice_Sell,g_digits):"-"),
            (g_avgTrail_Active_Sell?"ARMED":(g_avgTrail_ArmReady_Sell?"READY":"WAIT")),
            (g_avgTrail_SL_Sell>0?DoubleToString(g_avgTrail_SL_Sell,g_digits):"-")),
            (g_avgTrail_Active_Sell?ok:warn)); y+=lh+3;

   SetLabel("cfg1", x,y, StringFormat("Grid: dist=%.1fpip  max=%d  candle=%s  AvgTP=%s/%dord/%.1fp",
            InpGridDistancePips, InpMaxGridOrders, (InpGridOnlyNewCandle?"Y":"N"),
            (InpEnableAverageTP?"ON":"OFF"), InpAvgTP_MinOrders, InpAverageTPPips), txt); y+=lh;
   SetLabel("cfg2", x,y, StringFormat("AvgTrail: %s act=%.1fp step=%.1fp BE=%.1fp min=%d 2X=%s",
            (InpEnableAvgTrailing?"ON":"OFF"), InpAvgTrail_ActivationPips, InpAvgTrail_StepPips,
            InpAvgTrail_BE_Buffer, InpAvgTrail_MinOrders, (InpAvgTrail_Strict2Cross?"Y":"N")), txt); y+=lh;
   SetLabel("cfg3", x,y, StringFormat("PerOrderTrail: %s act=%.1fp step=%.1fp BE=%.1f/%.1fp",
            (InpEnablePerOrderTrailing?"ON":"OFF"), InpTrailingActivationPips, InpTrailingStepPips,
            InpBreakevenActivationPips, InpBreakevenBufferPips), txt);
}

//=========================== INIT/TICK =============================
int OnInit()
{
   g_digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   g_point  = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   // pip = 10 * point on 3/5-digit symbols, else = point
   g_pip = (g_digits==3 || g_digits==5) ? 10.0*g_point : g_point;
   g_stopsLevel = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippagePoints);
   trade.SetTypeFilling(ORDER_FILLING_FOK);

   // Recover initial price from existing INIT positions (restart safety)
   for(int i=PositionsTotal()-1;i>=0;i--){
      if(!pos.SelectByIndex(i)) continue;
      if(!IsOurPosition()) continue;
      string c = pos.Comment();
      if(c=="GK_INIT_BUY")  g_initPrice_Buy  = pos.PriceOpen();
      if(c=="GK_INIT_SELL") g_initPrice_Sell = pos.PriceOpen();
   }

   Print("Golden Kuy3 v1.0 init  digits=",g_digits," pip=",g_pip," stopsLvl=",g_stopsLevel);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   DelDash();
   Print("Golden Kuy3 v1.0 deinit reason=",reason);
}

void OnTick()
{
   ManageInitialEntry();
   ManageGridEntry();
   ManagePerOrderTrailing();
   ManageAverageTP();
   ManageAverageTrailing();
   DrawDashboard();
}
//+------------------------------------------------------------------+
