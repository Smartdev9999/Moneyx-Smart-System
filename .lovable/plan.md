

## Gold Miner EA - เพิ่ม Daily Profit Pause + ปุ่ม Resume Manual

### ฟีเจอร์

1. **Daily Profit Pause**: เมื่อกำไรปิดได้ในวันนั้นถึงเป้าหมาย ระบบหยุดเปิดออเดอร์ใหม่จนถึงวันถัดไป
2. **ปุ่ม Resume Daily**: ปุ่มบน Dashboard ให้กดเพื่อ resume trading ด้วยตนเอง แม้ถึงเป้าหมายแล้ว

### ไฟล์ที่แก้ไข

`public/docs/mql5/Gold_Miner_EA.mq5` (ไฟล์เดียว)

---

### 1. เพิ่ม Input Parameters

```text
input group "=== Daily Profit Pause ==="
input bool     InpEnableDailyProfitPause = false;    // Enable Daily Profit Pause
input double   InpDailyProfitTarget      = 100.0;    // Daily Profit Target ($)
```

### 2. เพิ่ม Global Variables (หลังบรรทัด 270)

```text
bool     g_dailyProfitPaused   = false;   // Daily profit target reached
datetime g_dailyProfitPauseDay = 0;       // Day when pause was triggered
```

### 3. เพิ่ม Function: CalcDailyPL() (หลัง CalcMonthlyPL บรรทัด ~557)

คัดลอกโครงสร้างจาก `CalcMonthlyPL()` แต่ใช้ start of day แทน start of month:

```text
double CalcDailyPL()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = 0; dt.min = 0; dt.sec = 0;
   datetime dayStart = StructToTime(dt);

   double total = 0;
   if(!HistorySelect(dayStart, TimeCurrent())) return 0;
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

### 4. เพิ่ม Daily Profit Pause Logic ใน OnTick() (หลังบรรทัด 606)

```text
// === DAILY PROFIT PAUSE CHECK ===
if(InpEnableDailyProfitPause)
{
   MqlDateTime dtNow;
   TimeToStruct(TimeCurrent(), dtNow);
   dtNow.hour = 0; dtNow.min = 0; dtNow.sec = 0;
   datetime today = StructToTime(dtNow);

   // Reset pause flag when new day starts
   if(g_dailyProfitPauseDay != today)
   {
      g_dailyProfitPaused = false;
      g_dailyProfitPauseDay = today;
   }

   // Check if daily target reached
   if(!g_dailyProfitPaused)
   {
      double dailyPL = CalcDailyPL();
      if(dailyPL >= InpDailyProfitTarget)
      {
         g_dailyProfitPaused = true;
         Print("DAILY PROFIT PAUSE: Target $", InpDailyProfitTarget,
               " reached (PL=$", dailyPL, "). No new orders until tomorrow.");
      }
   }

   if(g_dailyProfitPaused)
      g_newOrderBlocked = true;
}
```

### 5. เพิ่มแถว Daily Profit บน Dashboard (หลัง Auto Re-Entry บรรทัด ~2117)

```text
if(InpEnableDailyProfitPause)
{
   double dailyPL = CalcDailyPL();
   string dpText = StringFormat("$%.2f / $%.2f", dailyPL, InpDailyProfitTarget);
   color dpColor = g_dailyProfitPaused ? COLOR_LOSS : COLOR_PROFIT;
   if(g_dailyProfitPaused) dpText = dpText + " PAUSED";
   DrawTableRow(row, "Daily Profit", dpText, dpColor, COLOR_SECTION_INFO); row++;
}
```

### 6. เพิ่มปุ่ม "Resume Daily" บน Dashboard (หลัง Close All button บรรทัด ~2213)

ปุ่มจะแสดงเฉพาะเมื่อฟีเจอร์เปิดใช้งาน **และ** อยู่ในสถานะ PAUSED:

```text
// Resume Daily Profit button (only visible when paused)
if(InpEnableDailyProfitPause && g_dailyProfitPaused)
{
   btnY += btnH + 3;
   CreateDashButton("GM_BtnResumeDaily", DashboardX, btnY, tableWidth, btnH,
                    "Resume Daily", clrDarkGreen, clrWhite);
}
else
{
   // Hide button when not needed
   ObjectDelete(0, "GM_BtnResumeDaily");
}
```

### 7. เพิ่ม Event Handler ใน OnChartEvent (หลัง GM_BtnCloseAll บรรทัด ~3870)

```text
else if(sparam == "GM_BtnResumeDaily")
{
   ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
   int result = MessageBox(
      "Resume trading for today?\nDaily profit target was reached.",
      "Confirm Resume", MB_YESNO | MB_ICONQUESTION);
   if(result == IDYES)
   {
      g_dailyProfitPaused = false;
      Print("DAILY PROFIT PAUSE: Manually resumed by user.");
   }
}
```

---

### สิ่งที่ไม่เปลี่ยนแปลง (ยืนยัน 100%)

- Order Execution Logic (trade.Buy, trade.Sell, trade.PositionClose) -- ไม่แตะ
- SMA Signal / Grid Entry-Exit / TP/SL / Trailing / Breakeven -- ไม่แตะ
- Accumulate Close / Basket Close / Drawdown Exit -- ไม่แตะ
- shouldEnterBuy / shouldEnterSell conditions -- ไม่แตะ
- News Filter / Time Filter / License module -- ไม่แตะ
- ออเดอร์ที่เปิดอยู่แล้วยังคง manage ตามปกติ
- ใช้ `g_newOrderBlocked` ที่มีอยู่แล้วเพื่อบล็อกเฉพาะออเดอร์ใหม่

### สรุปการเพิ่ม

| รายการ | จำนวนบรรทัดโดยประมาณ |
|--------|----------------------|
| Input parameters | 3 |
| Global variables | 2 |
| CalcDailyPL() function | 18 |
| OnTick logic | 22 |
| Dashboard row | 7 |
| Resume button | 10 |
| OnChartEvent handler | 12 |
| **รวม** | **~74 บรรทัด** |

