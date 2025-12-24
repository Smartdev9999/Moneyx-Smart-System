import { Link } from 'react-router-dom';
import { ArrowLeft, Settings, TrendingUp, TrendingDown, Shield, AlertTriangle, Download, FileCode, Info, Filter } from 'lucide-react';
import CodeBlock from '@/components/CodeBlock';
import StepCard from '@/components/StepCard';

const MT5EAGuide = () => {
  const fullEACode = `//+------------------------------------------------------------------+
//|                                   ZigZag_CDC_Structure_EA.mq5      |
//|                          ZigZag + CDC Action Zone Trend Filter     |
//+------------------------------------------------------------------+
#property copyright "Trading Education"
#property link      ""
#property version   "2.00"
#property strict

// *** Include CTrade ***
#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| ===================== INPUT PARAMETERS ========================= |
//+------------------------------------------------------------------+

// === ZigZag Settings ===
input int      InpDepth        = 12;          // ZigZag Depth
input int      InpDeviation    = 5;           // ZigZag Deviation (pips)
input int      InpBackstep     = 3;           // ZigZag Backstep

// === CDC Action Zone Settings ===
input bool     InpUseCDCFilter = true;        // Use CDC Action Zone Filter
input ENUM_TIMEFRAMES InpCDCTimeframe = PERIOD_D1;  // CDC Filter Timeframe
input int      InpCDCFastPeriod = 12;         // CDC Fast EMA Period
input int      InpCDCSlowPeriod = 26;         // CDC Slow EMA Period
input bool     InpShowCDCLines = true;        // Show CDC Lines on Chart

// === Trading Settings ===
input double   InpLotSize      = 0.01;        // Lot Size
input int      InpStopLoss     = 50;          // Stop Loss (pips)
input int      InpTakeProfit   = 100;         // Take Profit (pips)
input int      InpMagicNumber  = 123456;      // Magic Number

// === Risk Management ===
input double   InpMaxRiskPercent = 2.0;       // Max Risk %
input int      InpMaxOrders    = 1;           // Max Orders

// === Time Filter ===
input bool     InpUseTimeFilter = false;      // Use Time Filter
input int      InpStartHour    = 8;           // Start Hour
input int      InpEndHour      = 20;          // End Hour

//+------------------------------------------------------------------+
//| ===================== GLOBAL VARIABLES ========================= |
//+------------------------------------------------------------------+

// Swing Point Structure
struct SwingPoint
{
   int       index;
   double    price;
   datetime  time;
   string    type;      // "HIGH" or "LOW"
   string    pattern;   // "HH", "HL", "LH", "LL"
};

SwingPoint SwingPoints[];
int TotalSwingPoints = 0;

// Trade Objects
CTrade trade;
int zigzagHandle;

// CDC Action Zone Variables
string CDCTrend = "NEUTRAL";
double CDCFast = 0;
double CDCSlow = 0;
double CDCAP = 0;
color CDCZoneColor = clrWhite;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("===========================================");
   Print("ZigZag + CDC Action Zone EA v2.0");
   Print("Symbol: ", _Symbol);
   Print("Entry TF: ", EnumToString(Period()));
   Print("CDC Filter TF: ", EnumToString(InpCDCTimeframe));
   Print("===========================================");
   
   trade.SetExpertMagicNumber(InpMagicNumber);
   
   // Load ZigZag indicator
   zigzagHandle = iCustom(_Symbol, PERIOD_CURRENT, "Examples/ZigZag", 
                          InpDepth, InpDeviation, InpBackstep);
   
   if(zigzagHandle == INVALID_HANDLE)
   {
      Print("ERROR: Cannot load ZigZag indicator!");
      return(INIT_FAILED);
   }
   
   // Create CDC objects for visual display
   if(InpShowCDCLines && InpUseCDCFilter)
   {
      ObjectCreate(0, "CDC_Fast_Line", OBJ_TREND, 0, 0, 0);
      ObjectCreate(0, "CDC_Slow_Line", OBJ_TREND, 0, 0, 0);
   }
   
   Print("EA Started Successfully!");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(zigzagHandle != INVALID_HANDLE)
      IndicatorRelease(zigzagHandle);
   
   // Remove CDC objects
   ObjectDelete(0, "CDC_Fast_Line");
   ObjectDelete(0, "CDC_Slow_Line");
   ObjectDelete(0, "CDC_Zone_Label");
   
   // Remove zone rectangles and lines
   for(int i = 0; i < 100; i++)
   {
      ObjectDelete(0, "CDC_Zone_" + IntegerToString(i));
      ObjectDelete(0, "CDC_Fast_" + IntegerToString(i));
      ObjectDelete(0, "CDC_Slow_" + IntegerToString(i));
   }
   
   Comment("");
   Print("EA Stopped - Reason: ", reason);
}

//+------------------------------------------------------------------+
//| Calculate CDC Action Zone Values                                   |
//| Based on TradingView CDC Action Zone V.2                          |
//| Logic: Fast = EMA(EMA(OHLC4, 2), FastPeriod)                      |
//|        Slow = EMA(EMA(OHLC4, 2), SlowPeriod)                      |
//|        Green Zone = Fast > Slow AND AP > Fast (BUY ONLY)          |
//|        Red Zone = Fast < Slow AND AP < Fast (SELL ONLY)           |
//+------------------------------------------------------------------+
void CalculateCDC()
{
   if(!InpUseCDCFilter)
   {
      CDCTrend = "NEUTRAL";
      CDCZoneColor = clrWhite;
      return;
   }
   
   // Get OHLC4 data from CDC timeframe
   double closeArr[], highArr[], lowArr[], openArr[];
   ArraySetAsSeries(closeArr, true);
   ArraySetAsSeries(highArr, true);
   ArraySetAsSeries(lowArr, true);
   ArraySetAsSeries(openArr, true);
   
   int barsNeeded = InpCDCSlowPeriod * 3 + 10;
   
   if(CopyClose(_Symbol, InpCDCTimeframe, 0, barsNeeded, closeArr) < barsNeeded) return;
   if(CopyHigh(_Symbol, InpCDCTimeframe, 0, barsNeeded, highArr) < barsNeeded) return;
   if(CopyLow(_Symbol, InpCDCTimeframe, 0, barsNeeded, lowArr) < barsNeeded) return;
   if(CopyOpen(_Symbol, InpCDCTimeframe, 0, barsNeeded, openArr) < barsNeeded) return;
   
   // Calculate OHLC4 (Average Price)
   double ohlc4[];
   ArrayResize(ohlc4, barsNeeded);
   for(int i = 0; i < barsNeeded; i++)
   {
      ohlc4[i] = (openArr[i] + highArr[i] + lowArr[i] + closeArr[i]) / 4.0;
   }
   
   // Calculate AP = EMA(OHLC4, 2)
   double ap[];
   ArrayResize(ap, barsNeeded);
   CalculateEMA(ohlc4, ap, 2, barsNeeded);
   
   // Calculate Fast = EMA(AP, FastPeriod)
   double fast[];
   ArrayResize(fast, barsNeeded);
   CalculateEMA(ap, fast, InpCDCFastPeriod, barsNeeded);
   
   // Calculate Slow = EMA(AP, SlowPeriod)
   double slow[];
   ArrayResize(slow, barsNeeded);
   CalculateEMA(ap, slow, InpCDCSlowPeriod, barsNeeded);
   
   // Get current values (index 0 = most recent)
   CDCAP = ap[0];
   CDCFast = fast[0];
   CDCSlow = slow[0];
   
   // Determine Zone Color and Trend
   bool bullish = CDCFast > CDCSlow;
   bool bearish = CDCFast < CDCSlow;
   
   bool isGreen = bullish && CDCAP > CDCFast;    // Strong Bullish
   bool isRed = bearish && CDCAP < CDCFast;       // Strong Bearish
   bool isYellow = bullish && CDCAP < CDCFast;    // Weak Bullish
   bool isBlue = bearish && CDCAP > CDCFast;      // Weak Bearish
   
   if(isGreen)
   {
      CDCTrend = "BULLISH";
      CDCZoneColor = clrLime;
   }
   else if(isRed)
   {
      CDCTrend = "BEARISH";
      CDCZoneColor = clrRed;
   }
   else if(isYellow)
   {
      CDCTrend = "WEAK_BULL";
      CDCZoneColor = clrYellow;
   }
   else if(isBlue)
   {
      CDCTrend = "WEAK_BEAR";
      CDCZoneColor = clrDodgerBlue;
   }
   else
   {
      CDCTrend = "NEUTRAL";
      CDCZoneColor = clrWhite;
   }
   
   // Draw CDC lines and zone on chart
   if(InpShowCDCLines)
   {
      DrawCDCOnChart(fast, slow, ap, barsNeeded);
   }
}

//+------------------------------------------------------------------+
//| Calculate EMA Array                                                |
//+------------------------------------------------------------------+
void CalculateEMA(double &src[], double &result[], int period, int size)
{
   if(size < period) return;
   
   double multiplier = 2.0 / (period + 1);
   
   // First value = simple average
   double sum = 0;
   for(int i = size - period; i < size; i++)
   {
      sum += src[i];
   }
   result[size - 1] = sum / period;
   
   // Calculate EMA from oldest to newest
   for(int i = size - 2; i >= 0; i--)
   {
      result[i] = (src[i] - result[i + 1]) * multiplier + result[i + 1];
   }
}

//+------------------------------------------------------------------+
//| Draw CDC Lines and Zone on Chart                                   |
//+------------------------------------------------------------------+
void DrawCDCOnChart(double &fast[], double &slow[], double &ap[], int size)
{
   // Draw zone fill as rectangles
   int maxBars = MathMin(50, size - 1);
   
   for(int i = 0; i < maxBars; i++)
   {
      string objName = "CDC_Zone_" + IntegerToString(i);
      datetime t1 = iTime(_Symbol, InpCDCTimeframe, i + 1);
      datetime t2 = iTime(_Symbol, InpCDCTimeframe, i);
      
      double fastVal1 = fast[i + 1];
      double slowVal1 = slow[i + 1];
      double fastVal2 = fast[i];
      double slowVal2 = slow[i];
      
      // Determine zone color for this bar
      bool bullish = fast[i] > slow[i];
      bool bearish = fast[i] < slow[i];
      
      color zoneColor;
      if(bullish && ap[i] > fast[i])
         zoneColor = clrLime;          // Green - Strong Bullish
      else if(bearish && ap[i] < fast[i])
         zoneColor = clrRed;           // Red - Strong Bearish
      else if(bullish && ap[i] < fast[i])
         zoneColor = clrYellow;        // Yellow - Weak Bullish
      else if(bearish && ap[i] > fast[i])
         zoneColor = clrDodgerBlue;    // Blue - Weak Bearish
      else
         zoneColor = clrGray;
      
      // Create filled zone
      ObjectDelete(0, objName);
      ObjectCreate(0, objName, OBJ_RECTANGLE, 0, t1, MathMax(fastVal1, slowVal1), t2, MathMin(fastVal2, slowVal2));
      ObjectSetInteger(0, objName, OBJPROP_COLOR, zoneColor);
      ObjectSetInteger(0, objName, OBJPROP_FILL, true);
      ObjectSetInteger(0, objName, OBJPROP_BACK, true);
      ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
   }
   
   // Draw Fast MA line (Red/Orange)
   for(int i = 0; i < maxBars; i++)
   {
      string lineName = "CDC_Fast_" + IntegerToString(i);
      datetime t1 = iTime(_Symbol, InpCDCTimeframe, i + 1);
      datetime t2 = iTime(_Symbol, InpCDCTimeframe, i);
      
      ObjectDelete(0, lineName);
      ObjectCreate(0, lineName, OBJ_TREND, 0, t1, fast[i + 1], t2, fast[i]);
      ObjectSetInteger(0, lineName, OBJPROP_COLOR, clrOrangeRed);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
   }
   
   // Draw Slow MA line (Blue)
   for(int i = 0; i < maxBars; i++)
   {
      string lineName = "CDC_Slow_" + IntegerToString(i);
      datetime t1 = iTime(_Symbol, InpCDCTimeframe, i + 1);
      datetime t2 = iTime(_Symbol, InpCDCTimeframe, i);
      
      ObjectDelete(0, lineName);
      ObjectCreate(0, lineName, OBJ_TREND, 0, t1, slow[i + 1], t2, slow[i]);
      ObjectSetInteger(0, lineName, OBJPROP_COLOR, clrDodgerBlue);
      ObjectSetInteger(0, lineName, OBJPROP_WIDTH, 3);
      ObjectSetInteger(0, lineName, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
   }
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   if(lastBarTime == currentBarTime)
      return;
      
   lastBarTime = currentBarTime;
   
   // Calculate CDC Action Zone first
   CalculateCDC();
   
   if(InpUseTimeFilter && !IsWithinTradingHours())
   {
      UpdateChartComment("WAIT", "Outside trading hours");
      return;
   }
   
   if(CountOpenOrders() >= InpMaxOrders)
   {
      UpdateChartComment("WAIT", "Max orders reached");
      return;
   }
   
   if(!CalculateSwingPoints())
   {
      UpdateChartComment("WAIT", "Calculating Swing Points...");
      return;
   }
   
   string signal = AnalyzeSignal();
   string reason = "";
   
   // Apply CDC Filter
   if(signal == "BUY")
   {
      if(InpUseCDCFilter && CDCTrend != "BULLISH")
      {
         reason = "CDC Zone not Green (" + CDCTrend + ")";
         signal = "WAIT";
      }
      else
      {
         ExecuteBuy();
         reason = "CDC Confirmed BULLISH";
      }
   }
   else if(signal == "SELL")
   {
      if(InpUseCDCFilter && CDCTrend != "BEARISH")
      {
         reason = "CDC Zone not Red (" + CDCTrend + ")";
         signal = "WAIT";
      }
      else
      {
         ExecuteSell();
         reason = "CDC Confirmed BEARISH";
      }
   }
   
   UpdateChartComment(signal, reason);
}

//+------------------------------------------------------------------+
//| Calculate Swing Points from ZigZag                                 |
//+------------------------------------------------------------------+
bool CalculateSwingPoints()
{
   ArrayResize(SwingPoints, 0);
   TotalSwingPoints = 0;
   
   double zigzagBuffer[];
   ArraySetAsSeries(zigzagBuffer, true);
   
   int copied = CopyBuffer(zigzagHandle, 0, 0, 200, zigzagBuffer);
   if(copied <= 0)
   {
      Print("ERROR: Cannot copy ZigZag buffer");
      return false;
   }
   
   double lastHigh = 0;
   double lastLow = DBL_MAX;
   
   for(int i = 0; i < copied; i++)
   {
      if(zigzagBuffer[i] != 0 && zigzagBuffer[i] != EMPTY_VALUE)
      {
         double price = zigzagBuffer[i];
         double high = iHigh(_Symbol, PERIOD_CURRENT, i);
         double low = iLow(_Symbol, PERIOD_CURRENT, i);
         
         SwingPoint point;
         point.index = i;
         point.price = price;
         point.time = iTime(_Symbol, PERIOD_CURRENT, i);
         
         if(MathAbs(price - high) < MathAbs(price - low))
         {
            point.type = "HIGH";
            
            if(price > lastHigh && lastHigh > 0)
               point.pattern = "HH";
            else
               point.pattern = "LH";
               
            lastHigh = price;
         }
         else
         {
            point.type = "LOW";
            
            if(price < lastLow && lastLow < DBL_MAX)
               point.pattern = "LL";
            else
               point.pattern = "HL";
               
            lastLow = price;
         }
         
         int size = ArraySize(SwingPoints);
         ArrayResize(SwingPoints, size + 1);
         SwingPoints[size] = point;
         TotalSwingPoints++;
         
         if(TotalSwingPoints >= 10)
            break;
      }
   }
   
   return (TotalSwingPoints >= 4);
}

//+------------------------------------------------------------------+
//| Analyze Signal based on Market Structure                           |
//+------------------------------------------------------------------+
string AnalyzeSignal()
{
   if(TotalSwingPoints < 4)
      return "WAIT";
   
   int hhCount = 0, hlCount = 0, lhCount = 0, llCount = 0;
   
   for(int i = 0; i < 4 && i < TotalSwingPoints; i++)
   {
      if(SwingPoints[i].pattern == "HH") hhCount++;
      else if(SwingPoints[i].pattern == "HL") hlCount++;
      else if(SwingPoints[i].pattern == "LH") lhCount++;
      else if(SwingPoints[i].pattern == "LL") llCount++;
   }
   
   Print("Pattern: HH=", hhCount, " HL=", hlCount, 
         " LH=", lhCount, " LL=", llCount);
   
   // BUY Signal: Uptrend (HH + HL) and last point is HL
   if(hhCount >= 1 && hlCount >= 1)
   {
      if(SwingPoints[0].pattern == "HL")
      {
         Print("Structure BUY Signal detected");
         return "BUY";
      }
   }
   
   // SELL Signal: Downtrend (LL + LH) and last point is LH
   if(llCount >= 1 && lhCount >= 1)
   {
      if(SwingPoints[0].pattern == "LH")
      {
         Print("Structure SELL Signal detected");
         return "SELL";
      }
   }
   
   return "WAIT";
}

//+------------------------------------------------------------------+
//| Execute BUY order                                                  |
//+------------------------------------------------------------------+
void ExecuteBuy()
{
   double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl = price - InpStopLoss * _Point * 10;
   double tp = price + InpTakeProfit * _Point * 10;
   double lot = CalculateLotSize(InpStopLoss);
   
   Print("Executing BUY - CDC: ", CDCTrend);
   Print("Price: ", price, " SL: ", sl, " TP: ", tp);
   
   if(trade.Buy(lot, _Symbol, price, sl, tp, "ZigZag+CDC EA"))
   {
      Print("BUY Success! Ticket: ", trade.ResultOrder());
   }
   else
   {
      Print("BUY Failed! Error: ", trade.ResultRetcode());
   }
}

//+------------------------------------------------------------------+
//| Execute SELL order                                                 |
//+------------------------------------------------------------------+
void ExecuteSell()
{
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = price + InpStopLoss * _Point * 10;
   double tp = price - InpTakeProfit * _Point * 10;
   double lot = CalculateLotSize(InpStopLoss);
   
   Print("Executing SELL - CDC: ", CDCTrend);
   Print("Price: ", price, " SL: ", sl, " TP: ", tp);
   
   if(trade.Sell(lot, _Symbol, price, sl, tp, "ZigZag+CDC EA"))
   {
      Print("SELL Success! Ticket: ", trade.ResultOrder());
   }
   else
   {
      Print("SELL Failed! Error: ", trade.ResultRetcode());
   }
}

//+------------------------------------------------------------------+
//| Calculate Lot Size based on Risk Management                        |
//+------------------------------------------------------------------+
double CalculateLotSize(int slPips)
{
   if(InpMaxRiskPercent <= 0)
      return InpLotSize;
   
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * InpMaxRiskPercent / 100;
   
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double pipValue = tickValue * (10 * _Point / tickSize);
   
   double calculatedLot = riskAmount / (slPips * pipValue);
   
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   calculatedLot = MathMax(minLot, MathMin(maxLot, calculatedLot));
   calculatedLot = MathFloor(calculatedLot / lotStep) * lotStep;
   
   return calculatedLot;
}

//+------------------------------------------------------------------+
//| Count open orders for this EA                                      |
//+------------------------------------------------------------------+
int CountOpenOrders()
{
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      if(PositionGetSymbol(i) == _Symbol)
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Check if within trading hours                                      |
//+------------------------------------------------------------------+
bool IsWithinTradingHours()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.hour >= InpStartHour && dt.hour < InpEndHour);
}

//+------------------------------------------------------------------+
//| Update chart comment with CDC info                                 |
//+------------------------------------------------------------------+
void UpdateChartComment(string signal, string reason = "")
{
   string nl = "\\n";
   string text = "";
   
   text = text + "=================================" + nl;
   text = text + " ZigZag + CDC Action Zone EA v2.0" + nl;
   text = text + "=================================" + nl;
   text = text + "Symbol: " + _Symbol + nl;
   text = text + "Entry TF: " + EnumToString(Period()) + nl;
   text = text + "---------------------------------" + nl;
   
   // CDC Action Zone Info
   text = text + "CDC FILTER (" + EnumToString(InpCDCTimeframe) + "):" + nl;
   text = text + "  Fast EMA: " + DoubleToString(CDCFast, _Digits) + nl;
   text = text + "  Slow EMA: " + DoubleToString(CDCSlow, _Digits) + nl;
   text = text + "  Zone: " + CDCTrend + nl;
   
   // Color indicator
   string zoneSymbol = "";
   if(CDCTrend == "BULLISH") zoneSymbol = "[GREEN - BUY ONLY]";
   else if(CDCTrend == "BEARISH") zoneSymbol = "[RED - SELL ONLY]";
   else if(CDCTrend == "WEAK_BULL") zoneSymbol = "[YELLOW - CAUTION]";
   else if(CDCTrend == "WEAK_BEAR") zoneSymbol = "[BLUE - CAUTION]";
   else zoneSymbol = "[NEUTRAL]";
   text = text + "  Status: " + zoneSymbol + nl;
   
   text = text + "---------------------------------" + nl;
   text = text + "STRUCTURE ANALYSIS:" + nl;
   text = text + "  Swing Points: " + IntegerToString(TotalSwingPoints) + nl;
   
   if(TotalSwingPoints >= 4)
   {
      text = text + "  Recent: ";
      for(int i = 0; i < 4 && i < TotalSwingPoints; i++)
      {
         text = text + SwingPoints[i].pattern;
         if(i < 3) text = text + " > ";
      }
      text = text + nl;
   }
   
   text = text + "---------------------------------" + nl;
   text = text + "SIGNAL: " + signal + nl;
   if(reason != "") text = text + "Reason: " + reason + nl;
   text = text + "Orders: " + IntegerToString(CountOpenOrders()) + 
          "/" + IntegerToString(InpMaxOrders) + nl;
   text = text + "=================================" + nl;
   
   Comment(text);
}
//+------------------------------------------------------------------+`;

  return (
    <div className="min-h-screen bg-background">
      {/* Header */}
      <header className="sticky top-0 z-50 border-b border-border bg-background/95 backdrop-blur">
        <div className="container py-4 flex items-center justify-between">
          <Link 
            to="/trading-bot-guide" 
            className="inline-flex items-center gap-2 text-muted-foreground hover:text-foreground transition-colors"
          >
            <ArrowLeft className="w-4 h-4" />
            กลับหน้า Trading Bot Guide
          </Link>
        </div>
      </header>

      {/* Hero */}
      <section className="container pt-12 pb-8">
        <div className="max-w-4xl mx-auto text-center">
          <div className="inline-flex items-center gap-2 px-4 py-2 rounded-full bg-primary/10 border border-primary/30 mb-6">
            <FileCode className="w-4 h-4 text-primary" />
            <span className="text-sm font-mono text-primary">MQL5 Expert Advisor v2.0</span>
          </div>
          
          <h1 className="text-3xl md:text-4xl font-bold text-foreground mb-4">
            ZigZag + <span className="text-primary">CDC Action Zone</span> EA
          </h1>
          
          <p className="text-lg text-muted-foreground">
            EA ที่รวม Market Structure กับ CDC Action Zone Trend Filter สำหรับ MT5
          </p>
        </div>
      </section>

      {/* Warning */}
      <section className="container pb-8">
        <div className="max-w-4xl mx-auto">
          <div className="p-6 rounded-2xl bg-destructive/10 border border-destructive/30 flex items-start gap-4">
            <AlertTriangle className="w-6 h-6 text-destructive shrink-0 mt-1" />
            <div>
              <h3 className="font-bold text-destructive mb-2">คำเตือนสำคัญ!</h3>
              <ul className="text-sm text-muted-foreground space-y-1">
                <li>โค้ดนี้เป็นตัวอย่างเพื่อ<strong>การศึกษาเท่านั้น</strong></li>
                <li><strong>ทดสอบบน Demo Account</strong> อย่างน้อย 1-3 เดือนก่อนใช้เงินจริง</li>
                <li>ไม่มี EA ใดรับประกันกำไร - การเทรดมีความเสี่ยง</li>
              </ul>
            </div>
          </div>
        </div>
      </section>

      {/* Features */}
      <section className="container py-8">
        <div className="max-w-4xl mx-auto">
          <h2 className="text-2xl font-bold text-foreground mb-6 text-center">คุณสมบัติของ EA v2.0</h2>
          
          <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-4">
            <div className="glass-card rounded-xl p-5 text-center">
              <div className="w-12 h-12 rounded-xl bg-primary/20 text-primary flex items-center justify-center mx-auto mb-3">
                <TrendingUp className="w-6 h-6" />
              </div>
              <h3 className="font-semibold text-foreground mb-1">Market Structure</h3>
              <p className="text-sm text-muted-foreground">วิเคราะห์ HH/HL/LH/LL อัตโนมัติ</p>
            </div>
            
            <div className="glass-card rounded-xl p-5 text-center border-2 border-bull/30">
              <div className="w-12 h-12 rounded-xl bg-bull/20 text-bull flex items-center justify-center mx-auto mb-3">
                <Filter className="w-6 h-6" />
              </div>
              <h3 className="font-semibold text-foreground mb-1">CDC Trend Filter</h3>
              <p className="text-sm text-muted-foreground">ฟิลเตอร์เทรนด์จาก TradingView</p>
            </div>
            
            <div className="glass-card rounded-xl p-5 text-center">
              <div className="w-12 h-12 rounded-xl bg-bear/20 text-bear flex items-center justify-center mx-auto mb-3">
                <Shield className="w-6 h-6" />
              </div>
              <h3 className="font-semibold text-foreground mb-1">Risk Management</h3>
              <p className="text-sm text-muted-foreground">คำนวณ Lot Size ตาม % เสี่ยง</p>
            </div>
            
            <div className="glass-card rounded-xl p-5 text-center">
              <div className="w-12 h-12 rounded-xl bg-secondary text-muted-foreground flex items-center justify-center mx-auto mb-3">
                <Settings className="w-6 h-6" />
              </div>
              <h3 className="font-semibold text-foreground mb-1">Visual Display</h3>
              <p className="text-sm text-muted-foreground">แสดงเส้น MA และโซนสีบน chart</p>
            </div>
          </div>
        </div>
      </section>

      {/* CDC Action Zone Explanation */}
      <section className="container py-8">
        <div className="max-w-4xl mx-auto">
          <h2 className="text-2xl font-bold text-foreground mb-6 text-center">CDC Action Zone Logic</h2>
          
          <div className="glass-card rounded-2xl p-6 mb-6">
            <h3 className="font-semibold text-foreground mb-4">สูตรการคำนวณ (จาก TradingView)</h3>
            <div className="bg-secondary/50 rounded-xl p-4 font-mono text-sm space-y-2">
              <p><span className="text-primary">AP</span> = EMA(OHLC4, 2)</p>
              <p><span className="text-bear">Fast</span> = EMA(AP, 12)</p>
              <p><span className="text-bull">Slow</span> = EMA(AP, 26)</p>
            </div>
          </div>
          
          <div className="grid md:grid-cols-2 gap-6">
            <div className="glass-card rounded-xl p-6 border-2 border-bull/50">
              <div className="flex items-center gap-3 mb-4">
                <div className="w-10 h-10 rounded-lg bg-bull flex items-center justify-center">
                  <TrendingUp className="w-5 h-5 text-white" />
                </div>
                <div>
                  <h3 className="font-bold text-bull">Green Zone</h3>
                  <p className="text-xs text-muted-foreground">BUY ONLY</p>
                </div>
              </div>
              <div className="space-y-2 text-sm">
                <p className="text-muted-foreground">เงื่อนไข:</p>
                <ul className="space-y-1 text-muted-foreground">
                  <li className="flex items-center gap-2">
                    <span className="w-2 h-2 rounded-full bg-bull"></span>
                    Fast EMA {">"} Slow EMA (Bullish)
                  </li>
                  <li className="flex items-center gap-2">
                    <span className="w-2 h-2 rounded-full bg-bull"></span>
                    AP {">"} Fast EMA (Strong momentum)
                  </li>
                </ul>
              </div>
            </div>
            
            <div className="glass-card rounded-xl p-6 border-2 border-bear/50">
              <div className="flex items-center gap-3 mb-4">
                <div className="w-10 h-10 rounded-lg bg-bear flex items-center justify-center">
                  <TrendingDown className="w-5 h-5 text-white" />
                </div>
                <div>
                  <h3 className="font-bold text-bear">Red Zone</h3>
                  <p className="text-xs text-muted-foreground">SELL ONLY</p>
                </div>
              </div>
              <div className="space-y-2 text-sm">
                <p className="text-muted-foreground">เงื่อนไข:</p>
                <ul className="space-y-1 text-muted-foreground">
                  <li className="flex items-center gap-2">
                    <span className="w-2 h-2 rounded-full bg-bear"></span>
                    Fast EMA {"<"} Slow EMA (Bearish)
                  </li>
                  <li className="flex items-center gap-2">
                    <span className="w-2 h-2 rounded-full bg-bear"></span>
                    AP {"<"} Fast EMA (Strong momentum)
                  </li>
                </ul>
              </div>
            </div>
          </div>
          
          <div className="grid md:grid-cols-2 gap-6 mt-6">
            <div className="glass-card rounded-xl p-5 border border-yellow-500/30">
              <h4 className="font-semibold text-yellow-500 mb-2">Yellow Zone (Weak Bull)</h4>
              <p className="text-sm text-muted-foreground">
                Fast {">"} Slow แต่ AP {"<"} Fast - เทรนด์ขาขึ้นแต่โมเมนตัมอ่อน
              </p>
            </div>
            
            <div className="glass-card rounded-xl p-5 border border-blue-500/30">
              <h4 className="font-semibold text-blue-500 mb-2">Blue Zone (Weak Bear)</h4>
              <p className="text-sm text-muted-foreground">
                Fast {"<"} Slow แต่ AP {">"} Fast - เทรนด์ขาลงแต่โมเมนตัมอ่อน
              </p>
            </div>
          </div>
        </div>
      </section>

      {/* Parameters Explanation */}
      <section className="container py-8">
        <div className="max-w-4xl mx-auto">
          <h2 className="text-2xl font-bold text-foreground mb-6 text-center">Parameters ใหม่</h2>
          
          <div className="glass-card rounded-2xl overflow-hidden">
            <table className="w-full text-sm">
              <thead>
                <tr className="border-b border-border bg-secondary/50">
                  <th className="px-4 py-3 text-left font-semibold text-foreground">Parameter</th>
                  <th className="px-4 py-3 text-left font-semibold text-foreground">ค่าเริ่มต้น</th>
                  <th className="px-4 py-3 text-left font-semibold text-foreground">คำอธิบาย</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-border">
                <tr className="bg-bull/5">
                  <td className="px-4 py-3 font-mono text-bull">InpUseCDCFilter</td>
                  <td className="px-4 py-3">true</td>
                  <td className="px-4 py-3 text-muted-foreground">เปิด/ปิดการใช้ CDC Action Zone Filter</td>
                </tr>
                <tr className="bg-bull/5">
                  <td className="px-4 py-3 font-mono text-bull">InpCDCTimeframe</td>
                  <td className="px-4 py-3">D1</td>
                  <td className="px-4 py-3 text-muted-foreground">Timeframe สำหรับคำนวณ CDC (D1, H4, H1, etc.)</td>
                </tr>
                <tr className="bg-bull/5">
                  <td className="px-4 py-3 font-mono text-bull">InpCDCFastPeriod</td>
                  <td className="px-4 py-3">12</td>
                  <td className="px-4 py-3 text-muted-foreground">Period ของ Fast EMA</td>
                </tr>
                <tr className="bg-bull/5">
                  <td className="px-4 py-3 font-mono text-bull">InpCDCSlowPeriod</td>
                  <td className="px-4 py-3">26</td>
                  <td className="px-4 py-3 text-muted-foreground">Period ของ Slow EMA</td>
                </tr>
                <tr className="bg-bull/5">
                  <td className="px-4 py-3 font-mono text-bull">InpShowCDCLines</td>
                  <td className="px-4 py-3">true</td>
                  <td className="px-4 py-3 text-muted-foreground">แสดงเส้น EMA และแถบสีบน chart (สำหรับ backtest)</td>
                </tr>
                <tr>
                  <td className="px-4 py-3 font-mono text-primary">InpDepth</td>
                  <td className="px-4 py-3">12</td>
                  <td className="px-4 py-3 text-muted-foreground">ZigZag Depth</td>
                </tr>
                <tr>
                  <td className="px-4 py-3 font-mono text-primary">InpStopLoss</td>
                  <td className="px-4 py-3">50</td>
                  <td className="px-4 py-3 text-muted-foreground">Stop Loss (pips)</td>
                </tr>
                <tr>
                  <td className="px-4 py-3 font-mono text-primary">InpTakeProfit</td>
                  <td className="px-4 py-3">100</td>
                  <td className="px-4 py-3 text-muted-foreground">Take Profit (pips)</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </section>

      {/* Trading Logic */}
      <section className="container py-8">
        <div className="max-w-4xl mx-auto">
          <h2 className="text-2xl font-bold text-foreground mb-6 text-center">กลยุทธ์การเทรด (รวม CDC Filter)</h2>
          
          <div className="grid md:grid-cols-2 gap-6">
            <div className="glass-card rounded-xl p-6 border-2 border-bull/30">
              <div className="flex items-center gap-3 mb-4">
                <div className="w-10 h-10 rounded-lg bg-bull/20 flex items-center justify-center">
                  <TrendingUp className="w-5 h-5 text-bull" />
                </div>
                <h3 className="text-lg font-bold text-bull">สัญญาณ BUY</h3>
              </div>
              <ol className="space-y-2 text-sm text-muted-foreground">
                <li className="flex items-start gap-2">
                  <span className="font-mono text-bull">1.</span>
                  <span>Structure: มี <strong className="text-bull">HH + HL</strong></span>
                </li>
                <li className="flex items-start gap-2">
                  <span className="font-mono text-bull">2.</span>
                  <span>Swing Point ล่าสุดเป็น <strong className="text-bull">HL</strong></span>
                </li>
                <li className="flex items-start gap-2 text-bull font-semibold">
                  <span className="font-mono">3.</span>
                  <span>CDC Zone = <strong>GREEN</strong> (Bullish + Strong)</span>
                </li>
                <li className="flex items-start gap-2">
                  <span className="font-mono text-bull">→</span>
                  <span>ส่งคำสั่ง <strong className="text-bull">BUY</strong></span>
                </li>
              </ol>
            </div>
            
            <div className="glass-card rounded-xl p-6 border-2 border-bear/30">
              <div className="flex items-center gap-3 mb-4">
                <div className="w-10 h-10 rounded-lg bg-bear/20 flex items-center justify-center">
                  <TrendingDown className="w-5 h-5 text-bear" />
                </div>
                <h3 className="text-lg font-bold text-bear">สัญญาณ SELL</h3>
              </div>
              <ol className="space-y-2 text-sm text-muted-foreground">
                <li className="flex items-start gap-2">
                  <span className="font-mono text-bear">1.</span>
                  <span>Structure: มี <strong className="text-bear">LL + LH</strong></span>
                </li>
                <li className="flex items-start gap-2">
                  <span className="font-mono text-bear">2.</span>
                  <span>Swing Point ล่าสุดเป็น <strong className="text-bear">LH</strong></span>
                </li>
                <li className="flex items-start gap-2 text-bear font-semibold">
                  <span className="font-mono">3.</span>
                  <span>CDC Zone = <strong>RED</strong> (Bearish + Strong)</span>
                </li>
                <li className="flex items-start gap-2">
                  <span className="font-mono text-bear">→</span>
                  <span>ส่งคำสั่ง <strong className="text-bear">SELL</strong></span>
                </li>
              </ol>
            </div>
          </div>
        </div>
      </section>

      {/* Installation */}
      <section className="container py-8">
        <div className="max-w-5xl mx-auto">
          <StepCard
            step={1}
            title="วิธีติดตั้ง EA"
            description="ทำตามขั้นตอนเหล่านี้เพื่อติดตั้ง EA บน MetaTrader 5"
            icon={<Download className="w-6 h-6" />}
          >
            <div className="space-y-4">
              <div className="p-4 rounded-xl bg-secondary/50">
                <ol className="space-y-2 text-sm text-muted-foreground">
                  <li><span className="font-mono text-primary">1.</span> เปิด MetaTrader 5</li>
                  <li><span className="font-mono text-primary">2.</span> กด <kbd className="px-2 py-0.5 rounded bg-secondary text-foreground">File</kbd> → <kbd className="px-2 py-0.5 rounded bg-secondary text-foreground">Open Data Folder</kbd></li>
                  <li><span className="font-mono text-primary">3.</span> ไปที่โฟลเดอร์ <code className="text-primary">MQL5 → Experts</code></li>
                  <li><span className="font-mono text-primary">4.</span> สร้างไฟล์ใหม่ชื่อ <code className="text-primary">ZigZag_CDC_Structure_EA.mq5</code></li>
                  <li><span className="font-mono text-primary">5.</span> วางโค้ดด้านล่างลงไป แล้วบันทึก</li>
                  <li><span className="font-mono text-primary">6.</span> กลับไป MT5 กด <kbd className="px-2 py-0.5 rounded bg-secondary text-foreground">F7</kbd> เพื่อ Compile</li>
                  <li><span className="font-mono text-primary">7.</span> ลาก EA ไปวางบน Chart</li>
                  <li><span className="font-mono text-primary">8.</span> ตั้งค่าพารามิเตอร์ → กด <kbd className="px-2 py-0.5 rounded bg-secondary text-foreground">OK</kbd></li>
                </ol>
              </div>
              
              <div className="flex items-start gap-3 p-4 rounded-xl bg-primary/10 border border-primary/30">
                <Info className="w-5 h-5 text-primary shrink-0 mt-0.5" />
                <div className="text-sm text-muted-foreground">
                  <strong className="text-foreground">สำคัญ:</strong> ต้องเปิด Auto Trading บน MT5 ด้วย (ปุ่ม AutoTrading บน toolbar)
                </div>
              </div>
            </div>
          </StepCard>
        </div>
      </section>

      {/* Full Code */}
      <section className="container py-8">
        <div className="max-w-5xl mx-auto">
          <h2 className="text-2xl font-bold text-foreground mb-6 text-center">โค้ด EA ฉบับเต็ม (v2.0 + CDC Filter)</h2>
          <CodeBlock
            code={fullEACode}
            language="MQL5"
            filename="ZigZag_CDC_Structure_EA.mq5"
          />
        </div>
      </section>

      {/* Tips */}
      <section className="container py-12">
        <div className="max-w-4xl mx-auto">
          <h2 className="text-2xl font-bold text-foreground mb-6 text-center">เคล็ดลับการใช้งาน</h2>
          
          <div className="grid md:grid-cols-2 gap-4">
            <div className="glass-card rounded-xl p-5">
              <h3 className="font-semibold text-foreground mb-3">ควรทำ</h3>
              <ul className="space-y-2 text-sm text-muted-foreground">
                <li>- ใช้ CDC Filter TF ที่สูงกว่า Entry TF (เช่น Entry H1, Filter D1)</li>
                <li>- Backtest บน Strategy Tester ดูแถบสีและเส้น MA</li>
                <li>- ทดสอบบน Demo Account อย่างน้อย 1 เดือน</li>
                <li>- ปรับ Fast/Slow Period ให้เหมาะกับคู่เงิน</li>
              </ul>
            </div>
            
            <div className="glass-card rounded-xl p-5">
              <h3 className="font-semibold text-foreground mb-3">ไม่ควรทำ</h3>
              <ul className="space-y-2 text-sm text-muted-foreground">
                <li>- เปิด CDC Filter TF เดียวกับ Entry TF</li>
                <li>- ใช้เงินจริงโดยไม่ทดสอบ</li>
                <li>- เทรดเมื่อ Zone เป็น Yellow/Blue (โมเมนตัมอ่อน)</li>
                <li>- ปล่อยทิ้งไว้โดยไม่ตรวจสอบ</li>
              </ul>
            </div>
          </div>
        </div>
      </section>

      {/* Footer */}
      <footer className="border-t border-border py-8">
        <div className="container text-center text-sm text-muted-foreground">
          <p>โค้ดนี้เป็นตัวอย่างเพื่อการศึกษา - ไม่รับประกันผลกำไร กรุณาศึกษาและทดสอบอย่างละเอียด</p>
        </div>
      </footer>
    </div>
  );
};

export default MT5EAGuide;