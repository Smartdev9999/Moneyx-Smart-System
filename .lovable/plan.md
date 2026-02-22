

## Gold Miner EA v2.9 - แก้ไข Time Filter Resume + เพิ่ม Dashboard Features

### ปัญหาที่พบ

1. **Time Filter ไม่ Resume**: หลังหมดช่วงเวลาที่หยุดเทรด ระบบไม่กลับมาเปิดออเดอร์ใหม่ ตรวจสอบพบว่า logic ใน `OnTick()` ถูกต้อง (flag `g_newOrderBlocked` ถูก reset เป็น `false` ทุก tick) แต่ปัญหาอยู่ที่ `justClosedBuy`/`justClosedSell` flags ถูก reset ไปแล้วระหว่างที่ filter ยังทำงาน ทำให้เมื่อ filter หยุด auto re-entry ไม่ทำงาน เพราะ `shouldEnterBuy` ต้องอาศัย `justClosedBuy = true` (กรณี `EnableAutoReEntry`)

   แก้ไข: เลื่อน reset `justClosedBuy`/`justClosedSell` ให้ทำหลังจากได้ลอง entry จริงแล้ว (ภายใน `if(!g_newOrderBlocked)` block) และเพิ่ม fallback สำหรับกรณี `buyCount == 0` ให้ enter ได้แม้ `justClosed` เป็น `false`

2. **News Filter Dashboard**: ต้องแสดงข่าวที่ทำให้หยุด + countdown timer เหมือน v5.34
3. **ปุ่ม Close Buy / Close Sell / Close All**: ยังไม่มี
4. **System Status + Pause button**: ยังไม่มี

---

### ไฟล์ที่แก้ไข

`public/docs/mql5/Gold_Miner_EA.mq5` (ไฟล์เดียว, version 2.80 -> 2.90)

---

### 1. แก้ไข Bug: Time Filter Resume

ปัญหา: `justClosedBuy`/`justClosedSell` ถูก reset ทุก new bar (บรรทัด 720-721) แม้ระหว่างที่ `g_newOrderBlocked = true` ทำให้เมื่อ filter หยุด ระบบไม่พบว่าเพิ่งปิดออเดอร์ จึงไม่ auto re-entry

แก้ไข: ย้าย reset flags เข้าไปอยู่ภายใน `if(!g_newOrderBlocked)` block หลังจากที่ entry logic ได้ทำงานแล้ว เพื่อให้ flags คงอยู่จนกว่าจะได้ลองเปิดออเดอร์จริง

```text
// เดิม (บรรทัด 720-721):
justClosedBuy = false;
justClosedSell = false;

// ใหม่: ย้ายเข้าไปใน if(!g_newOrderBlocked) block ท้ายสุด
if(!g_newOrderBlocked)
{
   // ... entry logic เดิม ...
   
   // Reset justClosed flags AFTER entry logic has had chance to use them
   justClosedBuy = false;
   justClosedSell = false;
}
// ถ้า g_newOrderBlocked = true, flags จะคงอยู่จนกว่า filter จะหยุด
```

---

### 2. เพิ่ม Global Variables ใหม่

```text
// Dashboard Control Variables (from v5.34)
bool g_eaIsPaused = false;           // EA Pause State
bool g_showConfirmDialog = false;    // Confirmation dialog visible
string g_confirmAction = "";         // Pending action
```

---

### 3. เพิ่ม OnChartEvent() (ใหม่ - Gold Miner ยังไม่มี)

คัดลอกจาก v5.34 เพื่อจัดการ button clicks:

```text
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      if(sparam == "GM_BtnPause")
      {
         g_eaIsPaused = !g_eaIsPaused;
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         Print("EA ", g_eaIsPaused ? "PAUSED" : "RESUMED", " by user");
      }
      else if(sparam == "GM_BtnCloseBuy")
      {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         ShowConfirmDialog("CLOSE_BUY", "Close all BUY orders?");
      }
      else if(sparam == "GM_BtnCloseSell")
      {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         ShowConfirmDialog("CLOSE_SELL", "Close all SELL orders?");
      }
      else if(sparam == "GM_BtnCloseAll")
      {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         ShowConfirmDialog("CLOSE_ALL", "Close ALL orders?");
      }
      else if(sparam == "GM_BtnConfirmYes")
      {
         ExecuteConfirmedAction();
      }
      else if(sparam == "GM_BtnConfirmNo")
      {
         HideConfirmDialog();
      }
      ChartRedraw(0);
   }
}
```

---

### 4. เพิ่ม Pause Guard ใน OnTick()

เพิ่มหลัง license check, ก่อน News/Time filter:

```text
// === EA PAUSE CHECK ===
if(g_eaIsPaused)
{
   g_newOrderBlocked = true;
   // แต่ยังคง run TP/SL, trailing, drawdown, dashboard
}
```

---

### 5. เพิ่ม Functions สำหรับ Buttons (ท้ายไฟล์)

คัดลอกจาก v5.34:

| Function | หมายเหตุ |
|----------|----------|
| `CreateDashButton()` | สร้างปุ่มบน chart (OBJ_BUTTON) |
| `ShowConfirmDialog()` | แสดง confirm dialog |
| `HideConfirmDialog()` | ซ่อน confirm dialog |
| `ExecuteConfirmedAction()` | ปิดออเดอร์ตาม action |
| `CloseAllPositionsByType()` | ปิดออเดอร์ตาม type (BUY/SELL) - ใช้ชื่อใหม่เพราะ `CloseAllPositions()` มีอยู่แล้ว |

---

### 6. แก้ไข Dashboard - เพิ่มฟีเจอร์ใหม่

**6.1 News Filter Row - แสดง countdown timer**

แทนที่แถว News Filter ปัจจุบัน (บรรทัด 2079-2083) ด้วย logic จาก v5.34:

```text
if(InpEnableNewsFilter)
{
   string newsDisplay;
   color newsColor;
   
   if(!g_webRequestConfigured)
   {
      newsDisplay = "WebRequest: NOT CONFIGURED!";
      newsColor = COLOR_LOSS;
   }
   else if(g_isNewsPaused && StringLen(g_nextNewsTitle) > 0)
   {
      // แสดงชื่อข่าว + countdown
      string truncTitle = g_nextNewsTitle;
      if(StringLen(truncTitle) > 18)
         truncTitle = StringSubstr(truncTitle, 0, 15) + "...";
      string countdown = GetNewsCountdownString();
      newsDisplay = truncTitle + " " + countdown;
      newsColor = COLOR_LOSS;
   }
   else if(g_newsEventCount == 0)
   {
      newsDisplay = "0 events loaded";
      newsColor = clrYellow;
   }
   else
   {
      newsDisplay = "No Important news";
      newsColor = COLOR_PROFIT;
   }
   
   DrawTableRow(row, "News Filter", newsDisplay, newsColor, COLOR_SECTION_INFO); row++;
}
```

**6.2 System Status Row + Pause Button**

เพิ่มก่อน header (หรือหลัง header row) เหมือน v5.34:

```text
// System Status
string statusText = "Working";
color statusColor = COLOR_PROFIT;

if(g_licenseStatus == LICENSE_SUSPENDED || g_licenseStatus == LICENSE_EXPIRED)
{
   statusText = (g_licenseStatus == LICENSE_SUSPENDED) ? "SUSPENDED" : "EXPIRED";
   statusColor = COLOR_LOSS;
}
else if(!g_isLicenseValid && !g_isTesterMode)
{
   statusText = "INVALID";
   statusColor = COLOR_LOSS;
}
else if(g_eaIsPaused)
{
   statusText = "PAUSED";
   statusColor = COLOR_LOSS;
}
else if(g_newOrderBlocked)
{
   statusText = "BLOCKED";
   statusColor = clrYellow;
}

DrawTableRow(row, "System Status", statusText, statusColor, COLOR_SECTION_INFO); row++;

// Pause Button (ข้างแถว System Status)
CreateDashButton("GM_BtnPause", ...Pause/Start...);
```

**6.3 Close Buttons (ใต้ dashboard)**

```text
// ใต้ bottom border ของ dashboard
int btnY = bottomY + 5;
int btnW = (tableWidth - 10) / 2;
int btnH = 25;

CreateDashButton("GM_BtnCloseBuy", DashboardX, btnY, btnW, btnH, "Close Buy", clrForestGreen);
CreateDashButton("GM_BtnCloseSell", DashboardX + btnW + 10, btnY, btnW, btnH, "Close Sell", clrOrangeRed);
btnY += btnH + 3;
CreateDashButton("GM_BtnCloseAll", DashboardX, btnY, tableWidth, btnH, "Close All", clrDodgerBlue);

// Confirmation Dialog (hidden by default)
CreateDashRect("GM_ConfirmBg", ...);
CreateDashText("GM_ConfirmText", ...);
CreateDashButton("GM_BtnConfirmYes", ...YES...);
CreateDashButton("GM_BtnConfirmNo", ...NO...);
HideConfirmDialog();
```

---

### 7. แก้ไข OnDeinit() - Cleanup objects ใหม่

เพิ่มลบ objects ของ buttons:

```text
ObjectsDeleteAll(0, "GM_Btn");
ObjectsDeleteAll(0, "GM_Confirm");
```

---

### 8. สิ่งที่ไม่เปลี่ยนแปลง (รับประกัน 100%)

- SMA Signal Logic (BUY/SELL)
- Grid Entry/Exit Logic
- TP/SL/Trailing/Breakeven Logic
- Accumulate Close Logic
- Drawdown Exit Logic
- License Module
- News Filter core logic (IsNewsTimePaused, RefreshNewsData, etc.)
- Time Filter core logic (IsWithinTradingHours, etc.)

---

### 9. สรุป

- Version: 2.80 -> 2.90
- แก้ bug: Time Filter resume ด้วยการย้าย justClosed reset เข้าไปใน entry block
- เพิ่ม: News countdown timer บน Dashboard
- เพิ่ม: System Status row + Pause/Start button
- เพิ่ม: Close Buy / Close Sell / Close All buttons พร้อม Confirm dialog
- เพิ่ม: OnChartEvent() สำหรับจัดการ button clicks
- เพิ่มประมาณ ~200 บรรทัด

