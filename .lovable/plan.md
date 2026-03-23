

## เพิ่ม Hedge Average Bound TP Points — Gold Miner SQ EA (v5.4 → v5.5)

### แนวคิด

เพิ่มระบบ "Average TP" สำหรับ bound orders ของแต่ละ hedge set — คำนวณราคาเฉลี่ยถ่วงน้ำหนักของ bound orders แล้วเมื่อราคาปัจจุบันวิ่งถึง avg ± TP points → ปิด bound orders + hedge ทั้งชุดพร้อมกัน

ทำงานร่วมกับ Matching Close: ถ้า matching close ไม่สามารถทำงานได้ (order ไม่ครบเงื่อนไข) → Average TP จะเป็นทางออกอีกทางหนึ่ง

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. เพิ่ม Input (line 321 หลัง InpHedge_MaxSets)
```cpp
input int      InpHedge_BoundAvgTPPoints    = 0;      // Bound Avg TP Points (0=Disabled)
```

#### 2. เพิ่มฟังก์ชัน `ManageHedgeBoundAvgTP(int idx)`

Logic:
1. Guard: `InpHedge_BoundAvgTPPoints <= 0` → return
2. Guard: `isExpansion` → return (ทำงานเฉพาะ Normal เหมือนระบบอื่น)
3. คำนวณ weighted average price ของ bound orders ทั้งหมด (lots × open price / total lots)
4. คำนวณ TP level:
   - ถ้า bound orders เป็น **BUY** (counterSide = BUY) → `tpPrice = avgPrice + TPPoints * _Point`
   - ถ้า bound orders เป็น **SELL** (counterSide = SELL) → `tpPrice = avgPrice - TPPoints * _Point`
5. เช็คว่าราคาถึง TP หรือยัง:
   - BUY bound: `Bid >= tpPrice`
   - SELL bound: `Ask <= tpPrice`
6. ถ้าถึง → ปิด bound orders ทั้งหมด + ปิด hedge order → deactivate set

#### 3. เรียกใน `ManageHedgeSets()` (line 6137)

เพิ่มเรียก `ManageHedgeBoundAvgTP(h)` ใน branch `!isExpansion` **ก่อน** matching/partial close:

```text
else if(!isExpansion)
{
   // Check bound orders avg TP first
   if(g_hedgeSets[h].boundTicketCount == 0 && hedgeExists) { gridMode... }
   
   // NEW: Average TP check
   if(ManageHedgeBoundAvgTP(h)) continue;  // closed entire set
   
   if(hedgePnL > 0) ManageHedgeMatchingClose(h);
   else ManageHedgePartialClose(h);
}
```

#### 4. Version bump: v5.4 → v5.5

### ผลลัพธ์
- `InpHedge_BoundAvgTPPoints = 0` → ปิดระบบนี้ (ทำงานเหมือนเดิม)
- `InpHedge_BoundAvgTPPoints = 500` → เมื่อราคาวิ่งบวก 500 points จาก avg price ของ bound orders → ปิดทั้งชุด
- ทำงานร่วมกับ matching close: ถ้า avg TP ไม่ถึง → matching/partial close ยังทำงานตามปกติ

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter, Time filter, Data sync)
- ManageHedgeMatchingClose, ManageHedgePartialClose, ManageHedgeGridMode logic
- Bound ticket management, Lot Cap
- Accumulate/Drawdown close logic

