

## แก้ไข ATR Chart ไม่ถูกซ่อนใน Backtest

### สาเหตุ

โค้ดปัจจุบันพยายามลบ ATR subwindow เพียง **tick แรก** เท่านั้น (`g_atrChartHidden = true` ทันที) แต่ปัญหาคือ:

1. ใน tick แรกของ Strategy Tester, ATR subwindow อาจยังไม่ถูกสร้างขึ้น (indicator ยังไม่ render)
2. เมื่อ flag ถูกตั้งเป็น `true` แล้ว จะไม่ลองลบอีกเลย
3. `iATR()` สร้าง 2 handles (`handleATR_Loss`, `handleATR_Profit`) ซึ่งอาจสร้าง subwindow แยกกัน

### ไฟล์ที่แก้ไข

`public/docs/mql5/Gold_Miner_EA.mq5` (ไฟล์เดียว)

### วิธีแก้ไข

เปลี่ยนจาก "ลบครั้งเดียวแล้วหยุด" เป็น "ลองลบทุก tick จนกว่าจะลบสำเร็จหรือครบ 50 tick"

```text
// แก้ไข global variable
bool g_atrChartHidden = false;
int  g_atrHideAttempts = 0;        // เพิ่มตัวนับ

// แก้ไข logic ใน OnTick():
if(!g_atrChartHidden && (MQLInfoInteger(MQL_TESTER) || MQLInfoInteger(MQL_VISUAL_MODE)))
{
   g_atrHideAttempts++;
   int totalWindows = (int)ChartGetInteger(0, CHART_WINDOWS_TOTAL);
   bool found = false;
   for(int sw = totalWindows - 1; sw > 0; sw--)
   {
      int indCount = ChartIndicatorsTotal(0, sw);
      for(int j = indCount - 1; j >= 0; j--)
      {
         string indName = ChartIndicatorName(0, sw, j);
         if(StringFind(indName, "ATR") >= 0)
         {
            ChartIndicatorDelete(0, sw, indName);
            found = true;
         }
      }
   }
   // หยุดเมื่อลบสำเร็จ หรือพยายามครบ 50 tick แล้ว
   if(found || g_atrHideAttempts >= 50)
   {
      g_atrChartHidden = true;
      ChartRedraw(0);
   }
}
```

### สิ่งที่เปลี่ยน

- เพิ่ม `g_atrHideAttempts` counter เพื่อลองลบซ้ำหลาย tick
- เปลี่ยน inner loop ให้ iterate ย้อนกลับ (`j = indCount - 1; j >= 0; j--`) เพื่อป้องกัน index shift เมื่อลบ
- ตั้ง `g_atrChartHidden = true` ก็ต่อเมื่อลบสำเร็จจริง หรือพยายามครบ 50 tick

### สิ่งที่ไม่เปลี่ยนแปลง

- Trading logic ทั้งหมด (SMA, Grid, TP/SL, Trailing, Drawdown, Entry)
- News/Time Filter logic
- Dashboard + Buttons
- License module

