import { Link } from 'react-router-dom';
import { ArrowLeft, Settings, TrendingUp, TrendingDown, Shield, AlertTriangle, Download, FileCode, Info } from 'lucide-react';
import CodeBlock from '@/components/CodeBlock';
import StepCard from '@/components/StepCard';

const MT5EAGuide = () => {
  const fullEACode = `//+------------------------------------------------------------------+
//|                                           ZigZag_Structure_EA.mq5 |
//|                                    Based on ZigCycleBarCount Logic |
//|                                             สำหรับการศึกษาเท่านั้น |
//+------------------------------------------------------------------+
#property copyright "Trading Education"
#property link      ""
#property version   "1.00"
#property strict

//+------------------------------------------------------------------+
//| ===================== INPUT PARAMETERS ========================= |
//| ผู้ใช้สามารถปรับค่าได้จากหน้าต่าง EA Settings                     |
//+------------------------------------------------------------------+

// === ZigZag Settings ===
input int      InpDepth        = 12;          // Depth (จำนวนแท่งหา High/Low)
input int      InpDeviation    = 5;           // Deviation (ค่าเบี่ยงเบน pips)
input int      InpBackstep     = 3;           // Backstep

// === Trading Settings ===
input double   InpLotSize      = 0.01;        // Lot Size (ขนาดออเดอร์)
input int      InpStopLoss     = 50;          // Stop Loss (pips)
input int      InpTakeProfit   = 100;         // Take Profit (pips)
input int      InpMagicNumber  = 123456;      // Magic Number (ID ของ EA)

// === Risk Management ===
input double   InpMaxRiskPercent = 2.0;       // Max Risk % ต่อออเดอร์
input int      InpMaxOrders    = 1;           // จำนวนออเดอร์สูงสุด

// === Time Filter ===
input bool     InpUseTimeFilter = false;      // ใช้ Time Filter
input int      InpStartHour    = 8;           // เริ่มเทรด (ชั่วโมง)
input int      InpEndHour      = 20;          // หยุดเทรด (ชั่วโมง)

//+------------------------------------------------------------------+
//| ===================== GLOBAL VARIABLES ========================= |
//+------------------------------------------------------------------+

// เก็บข้อมูล Swing Points
struct SwingPoint
{
   int       index;      // ตำแหน่งแท่งเทียน
   double    price;      // ราคา
   datetime  time;       // เวลา
   string    type;       // "HIGH" หรือ "LOW"
   string    pattern;    // "HH", "HL", "LH", "LL"
};

SwingPoint SwingPoints[];  // Array เก็บ Swing Points ทั้งหมด
int TotalSwingPoints = 0;  // จำนวน Swing Points

// ตัวแปรสำหรับ Trade
CTrade trade;              // Object สำหรับส่งคำสั่งเทรด
int zigzagHandle;          // Handle ของ ZigZag indicator

//+------------------------------------------------------------------+
//| ===================== INITIALIZATION =========================== |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("===========================================");
   Print("ZigZag Structure EA กำลังเริ่มทำงาน...");
   Print("Symbol: ", _Symbol);
   Print("Timeframe: ", EnumToString(Period()));
   Print("===========================================");
   
   // ตั้งค่า Magic Number
   trade.SetExpertMagicNumber(InpMagicNumber);
   
   // โหลด ZigZag indicator
   zigzagHandle = iCustom(_Symbol, PERIOD_CURRENT, "Examples\\ZigZag", 
                          InpDepth, InpDeviation, InpBackstep);
   
   if(zigzagHandle == INVALID_HANDLE)
   {
      Print("❌ ไม่สามารถโหลด ZigZag indicator ได้!");
      return(INIT_FAILED);
   }
   
   Print("✅ EA เริ่มทำงานสำเร็จ!");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| ===================== DEINITIALIZATION ========================= |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // ปล่อย indicator handle
   if(zigzagHandle != INVALID_HANDLE)
      IndicatorRelease(zigzagHandle);
      
   Print("EA หยุดทำงาน - เหตุผล: ", reason);
}

//+------------------------------------------------------------------+
//| ===================== MAIN TICK FUNCTION ======================= |
//| ฟังก์ชันนี้จะถูกเรียกทุกครั้งที่มีราคาใหม่เข้ามา                   |
//+------------------------------------------------------------------+
void OnTick()
{
   // === ตรวจสอบว่าเป็นแท่งเทียนใหม่หรือไม่ ===
   // เพื่อไม่ให้ทำงานซ้ำในแท่งเดิม
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   
   if(lastBarTime == currentBarTime)
      return;  // ยังเป็นแท่งเดิม - ไม่ทำอะไร
      
   lastBarTime = currentBarTime;
   
   // === ตรวจสอบ Time Filter ===
   if(InpUseTimeFilter && !IsWithinTradingHours())
   {
      Comment("⏰ นอกเวลาเทรด - รอ...");
      return;
   }
   
   // === ตรวจสอบจำนวนออเดอร์ ===
   if(CountOpenOrders() >= InpMaxOrders)
   {
      Comment("📊 มีออเดอร์เปิดอยู่แล้ว: ", CountOpenOrders());
      return;
   }
   
   // === คำนวณ Swing Points ===
   if(!CalculateSwingPoints())
   {
      Comment("⚠️ ไม่สามารถคำนวณ Swing Points ได้");
      return;
   }
   
   // === วิเคราะห์สัญญาณ ===
   string signal = AnalyzeSignal();
   
   // === ส่งคำสั่งเทรด ===
   if(signal == "BUY")
   {
      ExecuteBuy();
   }
   else if(signal == "SELL")
   {
      ExecuteSell();
   }
   
   // === อัพเดท Comment บนหน้าจอ ===
   UpdateChartComment(signal);
}

//+------------------------------------------------------------------+
//| ===================== CALCULATE SWING POINTS =================== |
//| คำนวณหา Swing High และ Swing Low จาก ZigZag                      |
//+------------------------------------------------------------------+
bool CalculateSwingPoints()
{
   // รีเซ็ต array
   ArrayResize(SwingPoints, 0);
   TotalSwingPoints = 0;
   
   // ดึงข้อมูล ZigZag
   double zigzagBuffer[];
   ArraySetAsSeries(zigzagBuffer, true);
   
   int copied = CopyBuffer(zigzagHandle, 0, 0, 200, zigzagBuffer);
   if(copied <= 0)
   {
      Print("❌ ไม่สามารถดึงข้อมูล ZigZag ได้");
      return false;
   }
   
   // หา Swing Points จาก ZigZag
   double lastHigh = 0, lastLow = DBL_MAX;
   
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
         
         // ตรวจสอบว่าเป็น High หรือ Low
         if(MathAbs(price - high) < MathAbs(price - low))
         {
            // เป็น Swing High
            point.type = "HIGH";
            
            // กำหนด pattern
            if(price > lastHigh && lastHigh > 0)
               point.pattern = "HH";  // Higher High
            else
               point.pattern = "LH";  // Lower High
               
            lastHigh = price;
         }
         else
         {
            // เป็น Swing Low
            point.type = "LOW";
            
            // กำหนด pattern
            if(price < lastLow && lastLow < DBL_MAX)
               point.pattern = "LL";  // Lower Low
            else
               point.pattern = "HL";  // Higher Low
               
            lastLow = price;
         }
         
         // เพิ่มเข้า array
         int size = ArraySize(SwingPoints);
         ArrayResize(SwingPoints, size + 1);
         SwingPoints[size] = point;
         TotalSwingPoints++;
         
         // เก็บแค่ 10 จุดล่าสุด
         if(TotalSwingPoints >= 10)
            break;
      }
   }
   
   return (TotalSwingPoints >= 4);  // ต้องมีอย่างน้อย 4 จุด
}

//+------------------------------------------------------------------+
//| ===================== ANALYZE SIGNAL =========================== |
//| วิเคราะห์โครงสร้างตลาดและสร้างสัญญาณเทรด                           |
//+------------------------------------------------------------------+
string AnalyzeSignal()
{
   if(TotalSwingPoints < 4)
      return "WAIT";
   
   // ดู 4 จุดล่าสุด
   int hhCount = 0, hlCount = 0, lhCount = 0, llCount = 0;
   
   for(int i = 0; i < 4 && i < TotalSwingPoints; i++)
   {
      if(SwingPoints[i].pattern == "HH") hhCount++;
      else if(SwingPoints[i].pattern == "HL") hlCount++;
      else if(SwingPoints[i].pattern == "LH") lhCount++;
      else if(SwingPoints[i].pattern == "LL") llCount++;
   }
   
   Print("Pattern Count: HH=", hhCount, " HL=", hlCount, 
         " LH=", lhCount, " LL=", llCount);
   
   // === สัญญาณซื้อ ===
   // Uptrend (HH + HL) และจุดล่าสุดเป็น HL
   if(hhCount >= 1 && hlCount >= 1)
   {
      if(SwingPoints[0].pattern == "HL")
      {
         Print("🟢 พบสัญญาณ BUY - Uptrend + Higher Low");
         return "BUY";
      }
   }
   
   // === สัญญาณขาย ===
   // Downtrend (LL + LH) และจุดล่าสุดเป็น LH
   if(llCount >= 1 && lhCount >= 1)
   {
      if(SwingPoints[0].pattern == "LH")
      {
         Print("🔴 พบสัญญาณ SELL - Downtrend + Lower High");
         return "SELL";
      }
   }
   
   return "WAIT";
}

//+------------------------------------------------------------------+
//| ===================== EXECUTE BUY ============================== |
//+------------------------------------------------------------------+
void ExecuteBuy()
{
   double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double sl = price - InpStopLoss * _Point * 10;
   double tp = price + InpTakeProfit * _Point * 10;
   double lot = CalculateLotSize(InpStopLoss);
   
   Print("📈 กำลังส่งคำสั่ง BUY...");
   Print("   Price: ", price);
   Print("   SL: ", sl);
   Print("   TP: ", tp);
   Print("   Lot: ", lot);
   
   if(trade.Buy(lot, _Symbol, price, sl, tp, "ZigZag Structure EA"))
   {
      Print("✅ BUY สำเร็จ! Ticket: ", trade.ResultOrder());
   }
   else
   {
      Print("❌ BUY ล้มเหลว! Error: ", trade.ResultRetcode());
   }
}

//+------------------------------------------------------------------+
//| ===================== EXECUTE SELL ============================= |
//+------------------------------------------------------------------+
void ExecuteSell()
{
   double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double sl = price + InpStopLoss * _Point * 10;
   double tp = price - InpTakeProfit * _Point * 10;
   double lot = CalculateLotSize(InpStopLoss);
   
   Print("📉 กำลังส่งคำสั่ง SELL...");
   Print("   Price: ", price);
   Print("   SL: ", sl);
   Print("   TP: ", tp);
   Print("   Lot: ", lot);
   
   if(trade.Sell(lot, _Symbol, price, sl, tp, "ZigZag Structure EA"))
   {
      Print("✅ SELL สำเร็จ! Ticket: ", trade.ResultOrder());
   }
   else
   {
      Print("❌ SELL ล้มเหลว! Error: ", trade.ResultRetcode());
   }
}

//+------------------------------------------------------------------+
//| ===================== CALCULATE LOT SIZE ======================= |
//| คำนวณ Lot Size ตาม Risk Management                                |
//+------------------------------------------------------------------+
double CalculateLotSize(int slPips)
{
   // ถ้าตั้งค่า Lot Size ไว้แน่นอน
   if(InpMaxRiskPercent <= 0)
      return InpLotSize;
   
   // คำนวณตาม % ความเสี่ยง
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * InpMaxRiskPercent / 100;
   
   // มูลค่า pip ต่อ lot
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double pipValue = tickValue * (10 * _Point / tickSize);
   
   // คำนวณ lot
   double calculatedLot = riskAmount / (slPips * pipValue);
   
   // ปรับให้อยู่ในขอบเขต
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   calculatedLot = MathMax(minLot, MathMin(maxLot, calculatedLot));
   calculatedLot = MathFloor(calculatedLot / lotStep) * lotStep;
   
   return calculatedLot;
}

//+------------------------------------------------------------------+
//| ===================== HELPER FUNCTIONS ========================= |
//+------------------------------------------------------------------+

// นับจำนวนออเดอร์ที่เปิดอยู่
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

// ตรวจสอบเวลาเทรด
bool IsWithinTradingHours()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   return (dt.hour >= InpStartHour && dt.hour < InpEndHour);
}

// อัพเดท Comment บนหน้าจอ
void UpdateChartComment(string signal)
{
   string text = "";
   text += "╔══════════════════════════════════╗\\n";
   text += "║    ZigZag Structure EA v1.0      ║\\n";
   text += "╠══════════════════════════════════╣\\n";
   text += "║ Symbol: " + _Symbol + "\\n";
   text += "║ Swing Points: " + IntegerToString(TotalSwingPoints) + "\\n";
   text += "║──────────────────────────────────║\\n";
   
   // แสดง Pattern ล่าสุด
   if(TotalSwingPoints >= 4)
   {
      text += "║ Recent Patterns:\\n";
      for(int i = 0; i < 4 && i < TotalSwingPoints; i++)
      {
         text += "║   " + IntegerToString(i+1) + ". " + 
                 SwingPoints[i].pattern + " @ " + 
                 DoubleToString(SwingPoints[i].price, _Digits) + "\\n";
      }
   }
   
   text += "║──────────────────────────────────║\\n";
   text += "║ Current Signal: ";
   
   if(signal == "BUY")
      text += "🟢 BUY\\n";
   else if(signal == "SELL")
      text += "🔴 SELL\\n";
   else
      text += "⏳ WAIT\\n";
   
   text += "║ Open Orders: " + IntegerToString(CountOpenOrders()) + "/" + 
           IntegerToString(InpMaxOrders) + "\\n";
   text += "╚══════════════════════════════════╝\\n";
   
   Comment(text);
}
//+------------------------------------------------------------------+`;

  const installationSteps = `วิธีติดตั้ง EA ใน MT5:

1. เปิด MetaTrader 5
2. กด File → Open Data Folder
3. ไปที่โฟลเดอร์ MQL5 → Experts
4. สร้างไฟล์ใหม่ชื่อ "ZigZag_Structure_EA.mq5"
5. วางโค้ดด้านบนลงไป
6. กลับไป MT5 กด Ctrl+Shift+N เพื่อเปิด Navigator
7. คลิกขวาที่ Expert Advisors → Refresh
8. ลาก EA ไปวางบน Chart
9. ตั้งค่าพารามิเตอร์ตามต้องการ
10. กด OK เพื่อเริ่มใช้งาน`;

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
            <span className="text-sm font-mono text-primary">MQL5 Expert Advisor</span>
          </div>
          
          <h1 className="text-3xl md:text-4xl font-bold text-foreground mb-4">
            ZigZag Structure <span className="text-primary">EA for MT5</span>
          </h1>
          
          <p className="text-lg text-muted-foreground">
            โค้ด EA ฉบับเต็มสำหรับ MetaTrader 5 พร้อมใช้งาน
          </p>
        </div>
      </section>

      {/* Warning */}
      <section className="container pb-8">
        <div className="max-w-4xl mx-auto">
          <div className="p-6 rounded-2xl bg-destructive/10 border border-destructive/30 flex items-start gap-4">
            <AlertTriangle className="w-6 h-6 text-destructive shrink-0 mt-1" />
            <div>
              <h3 className="font-bold text-destructive mb-2">⚠️ คำเตือนสำคัญ!</h3>
              <ul className="text-sm text-muted-foreground space-y-1">
                <li>• โค้ดนี้เป็นตัวอย่างเพื่อ<strong>การศึกษาเท่านั้น</strong></li>
                <li>• <strong>ทดสอบบน Demo Account</strong> อย่างน้อย 1-3 เดือนก่อนใช้เงินจริง</li>
                <li>• ไม่มี EA ใดรับประกันกำไร - การเทรดมีความเสี่ยง</li>
                <li>• ปรับพารามิเตอร์ให้เหมาะกับสไตล์การเทรดของคุณ</li>
              </ul>
            </div>
          </div>
        </div>
      </section>

      {/* Features */}
      <section className="container py-8">
        <div className="max-w-4xl mx-auto">
          <h2 className="text-2xl font-bold text-foreground mb-6 text-center">คุณสมบัติของ EA</h2>
          
          <div className="grid md:grid-cols-2 lg:grid-cols-4 gap-4">
            <div className="glass-card rounded-xl p-5 text-center">
              <div className="w-12 h-12 rounded-xl bg-primary/20 text-primary flex items-center justify-center mx-auto mb-3">
                <TrendingUp className="w-6 h-6" />
              </div>
              <h3 className="font-semibold text-foreground mb-1">Market Structure</h3>
              <p className="text-sm text-muted-foreground">วิเคราะห์ HH/HL/LH/LL อัตโนมัติ</p>
            </div>
            
            <div className="glass-card rounded-xl p-5 text-center">
              <div className="w-12 h-12 rounded-xl bg-candle-green/20 text-candle-green flex items-center justify-center mx-auto mb-3">
                <TrendingDown className="w-6 h-6" />
              </div>
              <h3 className="font-semibold text-foreground mb-1">Auto Trading</h3>
              <p className="text-sm text-muted-foreground">ส่งคำสั่ง BUY/SELL อัตโนมัติ</p>
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
              <h3 className="font-semibold text-foreground mb-1">Customizable</h3>
              <p className="text-sm text-muted-foreground">ปรับพารามิเตอร์ได้ทุกตัว</p>
            </div>
          </div>
        </div>
      </section>

      {/* Parameters Explanation */}
      <section className="container py-8">
        <div className="max-w-4xl mx-auto">
          <h2 className="text-2xl font-bold text-foreground mb-6 text-center">อธิบาย Parameters</h2>
          
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
                <tr>
                  <td className="px-4 py-3 font-mono text-primary">InpDepth</td>
                  <td className="px-4 py-3">12</td>
                  <td className="px-4 py-3 text-muted-foreground">จำนวนแท่งที่ใช้หา High/Low (ยิ่งมาก Swing Points ยิ่งน้อย)</td>
                </tr>
                <tr>
                  <td className="px-4 py-3 font-mono text-primary">InpDeviation</td>
                  <td className="px-4 py-3">5</td>
                  <td className="px-4 py-3 text-muted-foreground">ค่าเบี่ยงเบนขั้นต่ำ (pips) ที่จะถือเป็น swing point ใหม่</td>
                </tr>
                <tr>
                  <td className="px-4 py-3 font-mono text-primary">InpLotSize</td>
                  <td className="px-4 py-3">0.01</td>
                  <td className="px-4 py-3 text-muted-foreground">ขนาดออเดอร์ (ใช้เมื่อ MaxRiskPercent = 0)</td>
                </tr>
                <tr>
                  <td className="px-4 py-3 font-mono text-primary">InpStopLoss</td>
                  <td className="px-4 py-3">50</td>
                  <td className="px-4 py-3 text-muted-foreground">ระยะ Stop Loss (pips)</td>
                </tr>
                <tr>
                  <td className="px-4 py-3 font-mono text-primary">InpTakeProfit</td>
                  <td className="px-4 py-3">100</td>
                  <td className="px-4 py-3 text-muted-foreground">ระยะ Take Profit (pips)</td>
                </tr>
                <tr>
                  <td className="px-4 py-3 font-mono text-primary">InpMaxRiskPercent</td>
                  <td className="px-4 py-3">2.0</td>
                  <td className="px-4 py-3 text-muted-foreground">% ความเสี่ยงสูงสุดต่อออเดอร์ (คำนวณ Lot Size อัตโนมัติ)</td>
                </tr>
                <tr>
                  <td className="px-4 py-3 font-mono text-primary">InpMagicNumber</td>
                  <td className="px-4 py-3">123456</td>
                  <td className="px-4 py-3 text-muted-foreground">ID ของ EA (ใช้แยกออเดอร์จาก EA อื่น)</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      </section>

      {/* Trading Logic */}
      <section className="container py-8">
        <div className="max-w-4xl mx-auto">
          <h2 className="text-2xl font-bold text-foreground mb-6 text-center">กลยุทธ์การเทรด</h2>
          
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
                  <span>ตรวจพบ <strong className="text-bull">Higher High (HH)</strong> อย่างน้อย 1 ครั้ง</span>
                </li>
                <li className="flex items-start gap-2">
                  <span className="font-mono text-bull">2.</span>
                  <span>ตรวจพบ <strong className="text-bull">Higher Low (HL)</strong> อย่างน้อย 1 ครั้ง</span>
                </li>
                <li className="flex items-start gap-2">
                  <span className="font-mono text-bull">3.</span>
                  <span>Swing Point ล่าสุดเป็น <strong className="text-bull">HL</strong></span>
                </li>
                <li className="flex items-start gap-2">
                  <span className="font-mono text-bull">→</span>
                  <span>ส่งคำสั่ง <strong className="text-bull">BUY</strong> ที่ราคาปัจจุบัน</span>
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
                  <span>ตรวจพบ <strong className="text-bear">Lower Low (LL)</strong> อย่างน้อย 1 ครั้ง</span>
                </li>
                <li className="flex items-start gap-2">
                  <span className="font-mono text-bear">2.</span>
                  <span>ตรวจพบ <strong className="text-bear">Lower High (LH)</strong> อย่างน้อย 1 ครั้ง</span>
                </li>
                <li className="flex items-start gap-2">
                  <span className="font-mono text-bear">3.</span>
                  <span>Swing Point ล่าสุดเป็น <strong className="text-bear">LH</strong></span>
                </li>
                <li className="flex items-start gap-2">
                  <span className="font-mono text-bear">→</span>
                  <span>ส่งคำสั่ง <strong className="text-bear">SELL</strong> ที่ราคาปัจจุบัน</span>
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
                  <li><span className="font-mono text-primary">4.</span> สร้างไฟล์ใหม่ชื่อ <code className="text-primary">ZigZag_Structure_EA.mq5</code></li>
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
          <h2 className="text-2xl font-bold text-foreground mb-6 text-center">โค้ด EA ฉบับเต็ม</h2>
          <CodeBlock
            code={fullEACode}
            language="MQL5"
            filename="ZigZag_Structure_EA.mq5"
          />
        </div>
      </section>

      {/* Tips */}
      <section className="container py-12">
        <div className="max-w-4xl mx-auto">
          <h2 className="text-2xl font-bold text-foreground mb-6 text-center">เคล็ดลับการใช้งาน</h2>
          
          <div className="grid md:grid-cols-2 gap-4">
            <div className="glass-card rounded-xl p-5">
              <h3 className="font-semibold text-foreground mb-3">✅ ควรทำ</h3>
              <ul className="space-y-2 text-sm text-muted-foreground">
                <li>• Backtest บน Strategy Tester ก่อน</li>
                <li>• ทดสอบบน Demo Account อย่างน้อย 1 เดือน</li>
                <li>• ใช้ Timeframe H1 หรือ H4 ขึ้นไป</li>
                <li>• เริ่มด้วย Lot Size เล็กๆ</li>
                <li>• ตรวจสอบ Log ใน Experts tab</li>
              </ul>
            </div>
            
            <div className="glass-card rounded-xl p-5">
              <h3 className="font-semibold text-foreground mb-3">❌ ไม่ควรทำ</h3>
              <ul className="space-y-2 text-sm text-muted-foreground">
                <li>• ใช้เงินจริงโดยไม่ทดสอบ</li>
                <li>• ใช้ Lot Size ใหญ่เกินไป</li>
                <li>• เปิด EA หลายตัวพร้อมกัน</li>
                <li>• ปล่อยทิ้งไว้โดยไม่ตรวจสอบ</li>
                <li>• คาดหวังกำไร 100%</li>
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
