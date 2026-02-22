

## แก้ไข News Filter และ Time Filter ให้หยุดเฉพาะการเปิดออเดอร์ใหม่

### ปัญหาปัจจุบัน

โค้ดใน `OnTick()` บรรทัด 568-574 ทำ `return` ทันทีเมื่อ News/Time filter ไม่ผ่าน ซึ่งหยุด **ทุกอย่าง** รวมถึง:
- Per-Order Trailing / Breakeven
- ManageTPSL() (Basket TP/SL)
- CheckDrawdownExit()
- Accumulate Close
- Dashboard update

### สิ่งที่ต้องเปลี่ยน

เปลี่ยนจาก "return ทันที" เป็น "ตั้ง flag แล้วใช้ flag บล็อกเฉพาะจุดเปิดออเดอร์ใหม่"

### การแก้ไขในไฟล์ `public/docs/mql5/Gold_Miner_EA.mq5`

**1. เพิ่ม flag variable (global)**

```
bool g_newOrderBlocked = false;  // true = News/Time filter blocks new entries only
```

**2. แก้ OnTick() - ย้าย guard จาก return เป็น flag**

แทนที่บรรทัด 565-574 (ที่ return ทันที):

```
// === NEWS FILTER - Refresh hourly ===
RefreshNewsData();

// === Determine if new orders are blocked (News/Time) ===
g_newOrderBlocked = false;

if(IsNewsTimePaused())
   g_newOrderBlocked = true;

if(InpUseTimeFilter && !IsWithinTradingHours())
   g_newOrderBlocked = true;
```

ส่วน trailing, TP/SL, drawdown, dashboard ยังทำงานปกติทุก tick

**3. ใช้ flag บล็อกเฉพาะจุดเปิดออเดอร์ใหม่ (3 จุด)**

จุดที่ 1 - Grid Loss (บรรทัด ~640-648): เพิ่ม guard
```
if(!g_newOrderBlocked)
{
   if((hasInitialBuy || ...) && gridLossBuy < GridLoss_MaxTrades && buyCount > 0)
      CheckGridLoss(POSITION_TYPE_BUY, gridLossBuy);
   if((hasInitialSell || ...) && gridLossSell < GridLoss_MaxTrades && sellCount > 0)
      CheckGridLoss(POSITION_TYPE_SELL, gridLossSell);
}
```

จุดที่ 2 - Grid Profit (บรรทัด ~651-661): เพิ่ม guard
```
if(!g_newOrderBlocked && GridProfit_Enable)
{
   // ... เหมือนเดิม
}
```

จุดที่ 3 - Entry logic BUY/SELL (บรรทัด ~663-713): เพิ่ม guard
```
if(!g_newOrderBlocked)
{
   // BUY Entry + SELL Entry logic เหมือนเดิม
}
```

**4. Dashboard - เพิ่มแสดงสถานะ**

แสดง "NEW ORDERS BLOCKED" เมื่อ `g_newOrderBlocked = true` เพื่อให้ผู้ใช้เห็นว่า filter กำลังทำงาน

### สิ่งที่ยังทำงานปกติเมื่อ News/Time filter บล็อก

- ManagePerOrderTrailing() - trailing stop ทุก tick
- ManageTrailingStop() - breakeven + trailing ทุก tick
- ManageTPSL() - basket TP/SL ทุก tick
- CheckDrawdownExit() - emergency drawdown ทุก tick
- Accumulate Close (อยู่ใน ManageTPSL)
- DrawLines() + DisplayDashboard() - UI ทุก tick
- Auto-detect broker-closed positions - reset flags ปกติ

### สิ่งที่ถูกบล็อก

- เปิดออเดอร์ Initial ใหม่ (BUY/SELL Entry)
- เปิด Grid Loss ใหม่
- เปิด Grid Profit ใหม่

### สรุป

แก้ไขไฟล์เดียว: `public/docs/mql5/Gold_Miner_EA.mq5` - เปลี่ยน News/Time filter จาก "หยุดทุกอย่าง" เป็น "หยุดเฉพาะเปิดออเดอร์ใหม่" โดยใช้ flag `g_newOrderBlocked`

