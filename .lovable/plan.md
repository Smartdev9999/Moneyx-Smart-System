

## แก้ Entry Logic ให้ BUY/SELL ทำงานแยกฝั่ง (Independent Side Entry)

### สาเหตุของปัญหา

บรรทัด 359 ของ `Gold_Miner_EA.mq5`:

```text
if(totalPositions == 0 && TotalOrderCount() < MaxOpenOrders)
```

เงื่อนไข `totalPositions == 0` บังคับว่า **ต้องไม่มี position ใดเลย** ถึงจะเปิด initial ใหม่ได้ ดังนั้นเมื่อมี BUY grid อยู่ ระบบไม่สามารถเปิด SELL initial ได้แม้ว่า Signal จะเป็น SELL

แต่ระบบ Grid, TP/SL, Trailing ทำงานแยกฝั่ง (per-side) อยู่แล้ว เพียงแค่ Entry ที่ยังไม่แยก

### การแก้ไข

| ไฟล์ | รายละเอียด |
|------|-----------|
| `public/docs/mql5/Gold_Miner_EA.mq5` | แก้ Entry logic ให้เช็คแต่ละฝั่งแยกกัน |

### สิ่งที่จะเปลี่ยน

**1. แก้ Entry Logic (บรรทัด 358-406)**

เปลี่ยนจาก:

```text
if(totalPositions == 0 && TotalOrderCount() < MaxOpenOrders)
{
   // check SMA -> open BUY or SELL
}
```

เป็น:

```text
bool canOpenMore = TotalOrderCount() < MaxOpenOrders;
bool canOpenOnThisCandle = !(DontOpenSameCandle && currentBarTime == lastInitialCandleTime);

// ===== BUY Entry (แยกฝั่ง) =====
if(buyCount == 0 && g_initialBuyPrice == 0 && canOpenMore && canOpenOnThisCandle)
{
   if(currentPrice > smaValue && (TradingMode == TRADE_BUY_ONLY || TradingMode == TRADE_BOTH))
   {
      if(shouldEnter)  // re-entry or first time
      {
         OpenOrder(ORDER_TYPE_BUY, InitialLotSize, "GM_INIT");
         g_initialBuyPrice = ask;
         lastInitialCandleTime = currentBarTime;
      }
   }
}

// ===== SELL Entry (แยกฝั่ง) =====
if(sellCount == 0 && g_initialSellPrice == 0 && canOpenMore && canOpenOnThisCandle)
{
   if(currentPrice < smaValue && (TradingMode == TRADE_SELL_ONLY || TradingMode == TRADE_BOTH))
   {
      if(shouldEnter)  // re-entry or first time
      {
         OpenOrder(ORDER_TYPE_SELL, InitialLotSize, "GM_INIT");
         g_initialSellPrice = bid;
         lastInitialCandleTime = currentBarTime;
      }
   }
}
```

**2. แก้ justClosedPositions ให้แยกฝั่ง**

เพิ่มตัวแปร:

```text
bool justClosedBuy = false;
bool justClosedSell = false;
```

แทนที่ `justClosedPositions` เดิม เพื่อให้แต่ละฝั่งรู้ว่าฝั่งตัวเองเพิ่งปิด (สำหรับ Auto Re-Entry)

- `CloseAllSide(BUY)` -> ตั้ง `justClosedBuy = true`
- `CloseAllSide(SELL)` -> ตั้ง `justClosedSell = true`
- `CloseAllPositions()` -> ตั้งทั้ง `justClosedBuy = true` และ `justClosedSell = true`

**3. shouldEnter logic แยกฝั่ง**

```text
// BUY side
bool shouldEnterBuy = false;
if(justClosedBuy && EnableAutoReEntry) shouldEnterBuy = true;
else if(!justClosedBuy && buyCount == 0) shouldEnterBuy = true;

// SELL side
bool shouldEnterSell = false;
if(justClosedSell && EnableAutoReEntry) shouldEnterSell = true;
else if(!justClosedSell && sellCount == 0) shouldEnterSell = true;
```

### ตัวอย่างการทำงานหลังแก้

```text
ตั้งค่า: TradingMode = Buy and Sell, SMA Period = 20

1. ราคาอยู่เหนือ SMA -> เปิด BUY Initial (GM_INIT)
2. ราคาตกลงใต้ SMA -> BUY grid ทำงาน (GM_GL#1, #2...)
   -> พร้อมกัน: SELL Initial เปิดได้! (เพราะ sellCount == 0)
   -> SELL Initial เปิดที่ bid (GM_INIT)
3. ราคาขึ้นกลับ -> SELL grid ทำงาน (GM_GL#1...)
   -> BUY side TP/Trailing ทำงานปกติ
4. BUY basket ถูกปิด (TP หรือ Trailing) -> g_initialBuyPrice = 0
   -> SELL side ยังทำงานอยู่ ไม่ได้รับผลกระทบ
5. ราคากลับมาเหนือ SMA -> BUY Initial เปิดใหม่ได้
```

### สิ่งที่ไม่เปลี่ยน

- Grid Logic (CheckGridLoss, CheckGridProfit) - ทำงานแยกฝั่งอยู่แล้ว
- ManageTPSL() - TP/SL แยกฝั่งอยู่แล้ว
- ManagePerOrderTrailing() - ทำงานแยก order อยู่แล้ว
- Accumulate Close - ยังเป็น global basket (รวมกำไรทั้ง BUY+SELL)
- ResetTrailingState() - คงเดิม

### รายละเอียดทางเทคนิค

**ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`**

1. **เพิ่มตัวแปร global** (บรรทัด ~183): เปลี่ยน `justClosedPositions` เป็น `justClosedBuy` + `justClosedSell`
2. **แก้ Entry block** (บรรทัด 358-406): แยก BUY/SELL entry ด้วยเงื่อนไข per-side
3. **แก้ CloseAllSide()** (บรรทัด ~570): ตั้ง flag เฉพาะฝั่ง
4. **แก้ CloseAllPositions()** (บรรทัด ~591): ตั้ง flag ทั้งสองฝั่ง
5. **แก้ ManageTPSL()** (บรรทัด 610-740): ใช้ justClosedBuy/Sell แทน justClosedPositions
6. **แก้ reset flag** (บรรทัด ~410): Reset ทั้ง justClosedBuy/Sell เมื่อจบ new bar logic
7. **Dashboard** - แสดงสถานะแต่ละฝั่ง (BUY cycle / SELL cycle)

