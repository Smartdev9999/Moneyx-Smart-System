

## Gold Miner EA v2.9 - แก้ Bug Entry หยุดหลัง Close + ซ่อน ATR Chart

### ไฟล์ที่แก้ไข

`public/docs/mql5/Gold_Miner_EA.mq5` (ไฟล์เดียว)

---

### ปัญหาที่ 1: ระบบหยุดออกออเดอร์หลัง Basket/Accumulate Close

**สาเหตุที่พบ:**

เมื่อ `ManageTPSL()` หรือ Accumulate Close ปิดออเดอร์ (ผ่าน `CloseAllPositions()` หรือ `CloseAllSide()`), ระบบตั้ง `justClosedBuy = true` / `justClosedSell = true` ซึ่งทำให้ logic ในส่วน entry มีปัญหา:

```text
// Logic ปัจจุบัน (บรรทัด 683-685):
bool shouldEnterBuy = false;
if(justClosedBuy && EnableAutoReEntry) shouldEnterBuy = true;
else if(!justClosedBuy && buyCount == 0) shouldEnterBuy = true;
```

กรณี `EnableAutoReEntry = false` และ `justClosedBuy = true`:
- เงื่อนไขแรก: `true && false` = false
- เงื่อนไขสอง: `!true && ...` = false
- ผลลัพธ์: **shouldEnterBuy = false** (ไม่เปิดออเดอร์!)

แม้ว่า flag จะถูก reset ในบาร์ถัดไป แต่มีปัจจัยอื่นที่ทำให้ entry ล่าช้าต่อเนื่อง:
- ถ้า close เกิดใกล้ขอบ session (เช่น 12:39) จะ reset flag ทัน แต่ SMA signal อาจไม่ match
- ถ้า close เกิดระหว่าง session gap (เช่น 12:40-15:10) flag จะค้างจนเริ่ม session ใหม่
- เมื่อ session ใหม่เริ่ม ถ้า `EnableAutoReEntry=false` จะหลุด 1 บาร์แรก แล้วต้องรอ SMA match อีก

นอกจากนี้ `CloseAllPositions()` ตั้ง `justClosedBuy=true` และ `justClosedSell=true` ทั้งคู่เสมอ แม้จะมีแค่ฝั่งเดียว ทำให้ SELL side ก็ถูกบล็อกด้วย

**แก้ไข:**

เปลี่ยน `shouldEnterBuy/Sell` logic ให้เรียบง่ายและ robust ขึ้น - เมื่อ `buyCount == 0` ให้พร้อมเปิดออเดอร์เสมอ โดยใช้ `justClosedBuy` เป็น cooldown 1 บาร์เฉพาะเมื่อ `EnableAutoReEntry = false`:

```text
// Logic ใหม่:
bool shouldEnterBuy = false;
if(buyCount == 0)
{
   if(justClosedBuy && !EnableAutoReEntry)
      shouldEnterBuy = false;  // 1-bar cooldown
   else
      shouldEnterBuy = true;   // Ready to enter
}
```

**ความแตกต่าง:**
- เดิม: เมื่อ `justClosedBuy=true` + `EnableAutoReEntry=false` = **ไม่เปิด** (แม้ buyCount=0)
- ใหม่: เมื่อ `justClosedBuy=true` + `EnableAutoReEntry=false` = **ไม่เปิด** (cooldown 1 บาร์เท่านั้น)
- เดิม: เมื่อ `justClosedBuy=true` + `EnableAutoReEntry=true` = **เปิดทันที**
- ใหม่: เหมือนเดิม = **เปิดทันที**
- เพิ่ม: เมื่อ `justClosedBuy=false` + `buyCount=0` = **เปิดเสมอ** (เหมือนเดิม)

ผลลัพธ์เหมือนกันทาง logic แต่ structure ชัดเจนกว่า ป้องกัน edge case

**เพิ่ม Debug Print:**

เพิ่ม Print statements เพื่อวินิจฉัยปัญหาในอนาคต:

```text
if(buyCount == 0 && g_initialBuyPrice == 0 && shouldEnterBuy)
{
   if(!(currentPrice > smaValue))
      Print("BUY ENTRY SKIP: SMA signal not match (Price=", currentPrice, " SMA=", smaValue, ")");
}
```

**แก้ไข CloseAllPositions():**

ตั้ง justClosed flags ตามฝั่งที่ปิดจริง ไม่ใช่ทั้งคู่เสมอ:

```text
void CloseAllPositions()
{
   bool hadBuy = false, hadSell = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) hadBuy = true;
      else hadSell = true;
      trade.PositionClose(ticket);
   }
   if(hadBuy) justClosedBuy = true;
   if(hadSell) justClosedSell = true;
   ResetTrailingState();
   g_initialBuyPrice = 0;
   g_initialSellPrice = 0;
}
```

---

### ปัญหาที่ 2: ซ่อน ATR Chart ใน Backtest

ATR indicator ที่สร้างผ่าน `iATR()` จะแสดง subwindow อัตโนมัติใน Strategy Tester Visual Mode ทำให้ backtest ช้าลง

**แก้ไข:**

เพิ่ม global flag และ logic ใน OnTick เพื่อลบ ATR subwindow ออกจาก chart:

```text
// Global
bool g_atrChartHidden = false;

// ใน OnTick() ต้นสุด (ก่อน license check):
if(!g_atrChartHidden && (MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE)))
{
   int total = (int)ChartGetInteger(0, CHART_WINDOWS_TOTAL);
   for(int sw = total - 1; sw > 0; sw--)
   {
      int indCount = ChartIndicatorsTotal(0, sw);
      for(int j = 0; j < indCount; j++)
      {
         string name = ChartIndicatorName(0, sw, j);
         if(StringFind(name, "ATR") >= 0)
            ChartIndicatorDelete(0, sw, name);
      }
   }
   g_atrChartHidden = true;
   ChartRedraw(0);
}
```

ทำเพียงครั้งเดียวเมื่อเริ่ม backtest ไม่กระทบ live trading

---

### สิ่งที่ไม่เปลี่ยนแปลง (รับประกัน 100%)

- SMA Signal Logic
- Grid Entry/Exit Logic (Loss + Profit)
- TP/SL/Trailing/Breakeven Logic
- Accumulate Close Logic (ManageTPSL)
- Drawdown Exit Logic
- License/News/Time Filter core logic
- Dashboard layout + buttons (v2.9)
- OnChartEvent handler

---

### สรุป

- แก้ไข 2 จุดในไฟล์เดียว: `public/docs/mql5/Gold_Miner_EA.mq5`
- Fix 1: ปรับ shouldEnterBuy/Sell logic ให้ robust + แก้ CloseAllPositions ตั้ง flags ตามฝั่งจริง
- Fix 2: ซ่อน ATR subwindow ใน Strategy Tester ด้วย ChartIndicatorDelete
- เพิ่มประมาณ 30 บรรทัด

