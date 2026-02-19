

## Gold Miner EA v2.3 - Accumulate Close Fix + Dashboard Redesign

### Problem 1: Accumulate ไม่นับ profit จาก Per-Order Trailing

เมื่อ Per-Order Trailing ปิดออเดอร์ผ่าน broker SL ตัวแปร `g_accumulatedProfit` ไม่ได้ถูกอัพเดท เพราะ profit จะถูกบันทึกเข้า deal history แต่ EA ไม่ได้ตรวจจับ

**วิธีแก้**: ใช้ระบบ "Baseline" - คำนวณ accumulated จาก deal history โดยอ้างอิงจุดเริ่มต้น cycle

```text
Global Variable ใหม่:
- g_accumulateBaseline (double) = total history profit ณ จุดที่ reset cycle

การคำนวณ:
g_accumulatedProfit = CalcTotalHistoryProfit() - g_accumulateBaseline

เมื่อ Accumulate Target ถึง:
- CloseAllPositions()
- g_accumulateBaseline = CalcTotalHistoryProfit() (หลังปิดออเดอร์ทั้งหมด)
- g_accumulatedProfit = 0
```

### Problem 2: EA หยุดออกออเดอร์หลัง Accumulate Close

หลัง CloseAllPositions() ตัว justClosedBuy/justClosedSell ถูกตั้งค่า แต่ต้องรอ new bar ถึงจะเข้า entry logic
ปัญหาคือ CalculateAccumulatedProfit() ใน OnInit อ่าน ALL history ทำให้ restart EA แล้วอาจ trigger accumulate close ซ้ำ

**วิธีแก้**: OnInit ต้อง set baseline ด้วย ไม่ใช่แค่คำนวณ accumulated

### Problem 3: Dashboard ใหม่ แบบตาราง

เปลี่ยนจาก text labels เป็นตาราง (Rectangle + Label) ใกล้เคียงกับ Moneyx Smart System dashboard

---

### รายละเอียดทางเทคนิค

**ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`**

#### 1. เพิ่ม Global Variable

```text
double g_accumulateBaseline;   // Total history profit at last cycle reset
int    g_lastPositionCount;    // Track position count changes
double g_maxDD;                // Track max drawdown
```

#### 2. แก้ OnInit - Accumulate Baseline

```text
// Calculate baseline for accumulate
if(UseAccumulateClose)
{
   double totalHistory = CalcTotalHistoryProfit();
   // accumulated = totalHistory - baseline
   // On fresh start, baseline = 0, so accumulated = totalHistory
   g_accumulateBaseline = 0;
   g_accumulatedProfit = totalHistory;
}
```

#### 3. แก้ ManageTPSL - Accumulate Logic ใหม่

แทนที่จะพึ่ง manual increment ของ g_accumulatedProfit ในแต่ละ code path:

```text
// Every tick: recalculate accumulated from deal history
if(UseAccumulateClose)
{
   double totalHistory = CalcTotalHistoryProfit();
   g_accumulatedProfit = totalHistory - g_accumulateBaseline;
   
   double totalFloating = CalculateTotalFloatingPL();
   double accumTotal = g_accumulatedProfit + totalFloating;
   
   if(accumTotal >= AccumulateTarget)
   {
      Print("ACCUMULATE TARGET HIT: ", accumTotal, " / ", AccumulateTarget);
      CloseAllPositions();
      // Recalc after closing to include just-closed profit
      Sleep(500);
      double newHistory = CalcTotalHistoryProfit();
      g_accumulateBaseline = newHistory;
      g_accumulatedProfit = 0;
      Print("Accumulate cycle reset. New baseline: ", newHistory);
   }
}
```

#### 4. ลบ manual accumulate increment

ลบ `if(UseAccumulateClose) g_accumulatedProfit += closedPL;` จากทุกที่:
- บรรทัด 658 (TP HIT BUY)
- บรรทัด 715 (TP HIT SELL)
- บรรทัด 953 (TRAILING SL HIT BUY)
- บรรทัด 1012 (TRAILING SL HIT SELL)

เพราะตอนนี้ใช้ระบบ baseline คำนวณจาก history โดยตรง

#### 5. เพิ่ม CalcTotalHistoryProfit()

```text
double CalcTotalHistoryProfit()
{
   double total = 0;
   if(!HistorySelect(0, TimeCurrent())) return 0;
   int totalDeals = HistoryDealsTotal();
   for(int i = 0; i < totalDeals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;
      if(HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != MagicNumber) continue;
      if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol) continue;
      long dealEntry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      if(dealEntry == DEAL_ENTRY_OUT || dealEntry == DEAL_ENTRY_INOUT)
         total += HistoryDealGetDouble(dealTicket, DEAL_PROFIT) 
                + HistoryDealGetDouble(dealTicket, DEAL_SWAP);
   }
   return total;
}
```

#### 6. Dashboard ใหม่ - Table Layout

เปลี่ยน DisplayDashboard() ให้ใช้ Rectangle Label สร้างตาราง:

| Section | Rows |
|---------|------|
| Header (สีส้ม/ทอง) | "Gold Miner EA v2.3" |
| DETAIL (สีเทาเข้ม) | Balance, Equity, Floating P/L, Signal (SMA), Position Buy P/L (lots, orders), Position Sell P/L (lots, orders), Current DD%, Max DD% |
| ACCUMULATE (สีเทา) | Accum. Closed, Accum. Floating, Accum. Total (Tg:xxx Need:xxx) |
| TRAILING (สีเทา) | Per-Order: BE/Trail settings |
| INFO (สีเขียวเข้ม) | BUY Cycle status, SELL Cycle status, Auto Re-Entry, Mode |

แต่ละแถวประกอบด้วย:
- Rectangle background (สีสลับ dark/darker)
- Label ซ้าย (ชื่อ field)
- Label ขวา (ค่า, สีเขียว/แดง/ขาว)

Section แบ่งด้วยสีแถบด้านซ้าย:
- DETAIL = สีเขียว
- ACCUMULATE = สีเหลือง  
- INFO = สีฟ้า

```text
สีที่ใช้:
COLOR_HEADER_BG    = C'180,130,50'   // Header background (gold)
COLOR_ROW_DARK     = C'40,44,52'     // Row dark
COLOR_ROW_DARKER   = C'35,39,46'     // Row darker (alternate)
COLOR_SECTION_DETAIL = clrGreen      // Section indicator
COLOR_SECTION_ACCUM  = clrYellow
COLOR_SECTION_INFO   = clrDodgerBlue
COLOR_TEXT_LABEL   = C'180,180,180'  // Label text
COLOR_TEXT_VALUE   = clrWhite        // Value text
COLOR_PROFIT       = clrLime         // Profit color
COLOR_LOSS         = clrOrangeRed    // Loss color
```

#### 7. Dashboard Helper Functions ใหม่

```text
void CreateDashRect(string name, int x, int y, int w, int h, color bgColor)
void CreateDashText(string name, int x, int y, string text, color clr, int fontSize, string font)
void DrawTableRow(int rowIndex, string label, string value, color valueColor, color sectionColor)
```

### ลำดับการเปลี่ยนแปลง

1. เพิ่ม global variables (g_accumulateBaseline, g_maxDD)
2. เพิ่ม CalcTotalHistoryProfit() function
3. แก้ OnInit - baseline setup
4. แก้ ManageTPSL - accumulate ใช้ baseline
5. ลบ manual g_accumulatedProfit increment (4 จุด)
6. เขียน Dashboard ใหม่ทั้งหมด (DisplayDashboard + helpers)
7. แก้ OnDeinit - cleanup objects ใหม่

