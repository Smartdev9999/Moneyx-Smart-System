


## Gold Miner EA v2.9 - แก้ Bug Entry หยุดหลัง Close + ซ่อน ATR Chart

### สถานะ: ✅ เสร็จสมบูรณ์

### ไฟล์ที่แก้ไข

`public/docs/mql5/Gold_Miner_EA.mq5` (ไฟล์เดียว)

---

### Fix 1: shouldEnterBuy/Sell logic (robust)

เปลี่ยนจาก:
```
if(justClosedBuy && EnableAutoReEntry) shouldEnterBuy = true;
else if(!justClosedBuy && buyCount == 0) shouldEnterBuy = true;
```

เป็น:
```
if(buyCount == 0) {
   if(justClosedBuy && !EnableAutoReEntry) shouldEnterBuy = false;  // 1-bar cooldown
   else shouldEnterBuy = true;
}
```

เพิ่ม Debug Print เมื่อ SMA signal ไม่ match

### Fix 2: CloseAllPositions() ตั้ง flags ตามฝั่งจริง

ตรวจ hadBuy/hadSell ก่อนตั้ง justClosedBuy/justClosedSell

### Fix 3: ซ่อน ATR subwindow ใน Backtest

เพิ่ม g_atrChartHidden flag + ChartIndicatorDelete ใน OnTick ต้นสุด (ทำครั้งเดียว)

### สิ่งที่ไม่เปลี่ยนแปลง

- SMA Signal Logic, Grid, TP/SL, Trailing, Accumulate Close, Drawdown, License, News/Time Filter, Dashboard, OnChartEvent
