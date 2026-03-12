

## ปัญหา: Grid Lot ไม่ต่อเนื่องหลัง Matching Close

### สาเหตุ

`CalculateGridLot(currentGridCount, true)` ใช้ **จำนวน GL orders ที่เหลือ** (`gridLossBuy` / `gridLossSell`) เป็น level ในการคำนวณ lot

ตัวอย่างจากรูป:
- มี GL#5 ถึง GL#8 (lot 0.08 → 0.11 → 0.17 → 0.26)
- Matching Close ปิด GL#6 (lot 0.11) ไปพร้อมกับออเดอร์กำไร
- `gridLossBuy` ลดจาก 8 เหลือ 7 → ออเดอร์ใหม่คำนวณจาก level 7 = `InitialLotSize * multiplier^7` ซึ่งอาจเล็กกว่า 0.26 ที่เป็น lot ใหญ่สุดที่เหลืออยู่

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. เพิ่ม Helper Function: `FindMaxLotOnSide()`

หา lot ที่ใหญ่ที่สุดของ GM_GL orders ที่ยังเปิดอยู่ในฝั่งนั้น:
```cpp
double FindMaxLotOnSide(ENUM_POSITION_TYPE side)
{
   double maxLot = 0;
   for(int i = PositionsTotal()-1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) != side) continue;
      string comment = PositionGetString(POSITION_COMMENT);
      if(StringFind(comment, "GM_GL") >= 0 || StringFind(comment, "GM_INIT") >= 0)
      {
         double lot = PositionGetDouble(POSITION_VOLUME);
         if(lot > maxLot) maxLot = lot;
      }
   }
   return maxLot;
}
```

#### 2. แก้ไข `CheckGridLoss()` — เปรียบเทียบ lot กับ maxLot

หลังคำนวณ `lots = CalculateGridLot(currentGridCount, true)` ให้เทียบกับ `FindMaxLotOnSide()`:

```cpp
double lots = CalculateGridLot(currentGridCount, true);
double maxExisting = FindMaxLotOnSide(side);
if(maxExisting > 0 && lots <= maxExisting)
{
   // ต่อ martingale จาก lot ใหญ่สุดที่เหลือ
   if(GridLoss_LotMode == LOT_MULTIPLY)
      lots = maxExisting * GridLoss_MultiplyFactor;
   else if(GridLoss_LotMode == LOT_ADD)
      lots = maxExisting + InitialLotSize * GridLoss_AddLotPerLevel;
   else
      lots = CalculateGridLot(currentGridCount, true); // Custom ใช้ level เดิม
}
```

#### 3. ทำเช่นเดียวกันใน ZigZag mode `CheckGridLossTF()` (line ~3241)

ใช้ logic เดียวกันเพื่อให้ทั้ง SMA mode และ ZigZag mode มีพฤติกรรมเหมือนกัน

### ผลลัพธ์

จากตัวอย่างในรูป: ออเดอร์ใหญ่สุดที่เหลือ = 0.26 → ออเดอร์ใหม่ = 0.26 × multiplier (เช่น 0.26 × 1.5 = 0.39) แทนที่จะย้อนกลับไปใช้ lot ที่เล็กกว่า

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (OpenOrder, CloseAllPositions)
- Trading Strategy Logic (SMA/EMA signals, Entry conditions)
- Matching Close logic (ManageMatchingClose)
- Accumulate / Drawdown / TP/SL / Trailing / Breakeven
- License / News / Time Filter / Data Sync
- OnChartEvent buttons / Dashboard

