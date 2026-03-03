

## Gold Miner EA - แยกเส้น Average Price และ TP Line เป็น Buy / Sell

### ปัญหาปัจจุบัน

ตอนนี้ `DrawLines()` วาดเส้น Average Price เพียง 1 เส้น (`GM_AvgLine`) โดยเอา avgBuy กับ avgSell มาเฉลี่ยรวมกัน และ TP Line เพียง 1 เส้น (`GM_TPLine`) ทำให้เมื่อมีทั้ง BUY และ SELL พร้อมกัน มองไม่ออกว่าเส้นไหนเป็นฝั่งไหน

### วิธีแก้ไข

แยกเป็น 4 เส้น: Average Buy, Average Sell, TP Buy, TP Sell แต่ละเส้นมีสีแยกกัน

### ไฟล์ที่แก้ไข

`public/docs/mql5/Gold_Miner_EA.mq5` (ไฟล์เดียว)

---

### 1. เปลี่ยน Input Parameters (บรรทัด 149-152)

เปลี่ยนจาก 2 สี (Average + TP) เป็น 4 สี แยก Buy/Sell:

```text
input bool     ShowAverageLine     = true;      // Show Average Price Line
input bool     ShowTPLine          = true;      // Show TP Line
input color    AvgBuyLineColor     = clrDodgerBlue;  // Average Buy Line Color
input color    AvgSellLineColor    = clrOrangeRed;   // Average Sell Line Color
input color    TPBuyLineColor      = clrLime;        // TP Buy Line Color
input color    TPSellLineColor     = clrMagenta;     // TP Sell Line Color
```

**หมายเหตุ**: ลบ `AverageLineColor` และ `TPLineColor` เดิมออก แทนที่ด้วย 4 ตัวใหม่

### 2. แก้ไข DrawLines() (บรรทัด 1881-1930)

เปลี่ยนจากเส้นรวม 1 เส้นเป็นแยก Buy/Sell:

```text
void DrawLines()
{
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double avgBuy = CalculateAveragePrice(POSITION_TYPE_BUY);
   double avgSell = CalculateAveragePrice(POSITION_TYPE_SELL);

   //--- Average Buy Line
   if(avgBuy > 0 && ShowAverageLine)
      DrawHLine("GM_AvgBuyLine", avgBuy, AvgBuyLineColor, STYLE_SOLID, 2);
   else
      ObjectDelete(0, "GM_AvgBuyLine");

   //--- Average Sell Line
   if(avgSell > 0 && ShowAverageLine)
      DrawHLine("GM_AvgSellLine", avgSell, AvgSellLineColor, STYLE_SOLID, 2);
   else
      ObjectDelete(0, "GM_AvgSellLine");

   //--- TP Buy Line
   if(ShowTPLine && UseTP_Points && avgBuy > 0)
      DrawHLine("GM_TPBuyLine", avgBuy + TP_Points * point, TPBuyLineColor, STYLE_DASH, 1);
   else
      ObjectDelete(0, "GM_TPBuyLine");

   //--- TP Sell Line
   if(ShowTPLine && UseTP_Points && avgSell > 0)
      DrawHLine("GM_TPSellLine", avgSell - TP_Points * point, TPSellLineColor, STYLE_DASH, 1);
   else
      ObjectDelete(0, "GM_TPSellLine");

   // ... SL Line logic remains unchanged ...
}
```

### 3. ลบ Object เก่าใน OnDeinit (เพิ่มชื่อใหม่)

เปลี่ยนจากลบ `GM_AvgLine` / `GM_TPLine` เป็นลบชื่อใหม่:

```text
ObjectDelete(0, "GM_AvgBuyLine");
ObjectDelete(0, "GM_AvgSellLine");
ObjectDelete(0, "GM_TPBuyLine");
ObjectDelete(0, "GM_TPSellLine");
// ลบชื่อเดิม GM_AvgLine / GM_TPLine ออก
```

### 4. อัปเดตการอ้างอิง AverageLineColor / TPLineColor ที่อื่น

ค้นหาทุกจุดที่ใช้ `AverageLineColor` หรือ `TPLineColor` เดิม (เช่นใน SL Line section ที่ใช้ avgBuy/avgSell) และอัปเดตให้ใช้ชื่อใหม่ตามฝั่ง

---

### สรุปสีเส้น (ค่า default)

| เส้น | สี | Style |
|------|-----|-------|
| Average Buy | DodgerBlue (ฟ้า) | Solid, หนา 2 |
| Average Sell | OrangeRed (แดงส้ม) | Solid, หนา 2 |
| TP Buy | Lime (เขียว) | Dash, หนา 1 |
| TP Sell | Magenta (ชมพู) | Dash, หนา 1 |

### สิ่งที่ไม่เปลี่ยนแปลง (ยืนยัน 100%)

- Order Execution Logic (trade.Buy, trade.Sell, trade.PositionClose) -- ไม่แตะ
- SMA Signal / Grid Entry-Exit / TP/SL calculations -- ไม่แตะ
- Accumulate Close / Basket Close / Drawdown Exit -- ไม่แตะ
- shouldEnterBuy / shouldEnterSell conditions -- ไม่แตะ
- News Filter / Time Filter / License module -- ไม่แตะ
- SL Line logic -- ไม่แตะ (ยังคงใช้ avgBuy/avgSell เดิม)
- `CalculateAveragePrice()` function -- ไม่แตะ (ใช้งานตามเดิม)

