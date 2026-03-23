

## เพิ่ม Hedge Average Bound TP — ซอย Hedge (ไม่ปิดทั้งชุด) — Gold Miner SQ EA (v5.4 → v5.5)

### แนวคิดที่ถูกต้อง

เมื่อ bound orders ถึง Average TP → **ปิด bound orders + ซอย hedge ตามกำไร** (เหมือน Partial Close) ไม่ใช่ปิด hedge ทั้งหมด → เมื่อ bound orders หมด → เข้า Grid Mode ต่อ

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. เพิ่ม Input (หลัง InpHedge_MaxSets ~line 321)
```cpp
input int InpHedge_BoundAvgTPPoints = 0; // Bound Avg TP Points (0=Disabled)
```

#### 2. เพิ่มฟังก์ชัน `ManageHedgeBoundAvgTP(int idx)` — return bool

Logic:
1. Guard: `InpHedge_BoundAvgTPPoints <= 0` → return false
2. Guard: `boundTicketCount == 0` → return false
3. คำนวณ weighted avg price ของ bound orders (lots × openPrice / totalLots)
4. เช็คว่าราคาถึง avg ± TP points หรือยัง
5. ถ้าถึง:
   - คำนวณ `totalProfit` จาก bound orders ที่เป็นบวก
   - คำนวณ `closeLots = totalProfit / hedgeLossPerLot` (เหมือน Partial Close)
   - ปิด bound orders ที่เป็นบวกทั้งหมด + `RemoveBoundTicket`
   - **Partial close hedge** ด้วย closeLots (ซอย ไม่ปิดทั้งหมด)
   - ถ้า closeLots ≥ hedgeLots → ปิด hedge ทั้งหมด + deactivate set
   - ถ้า closeLots < hedgeLots → ซอย hedge ลด lot → bound orders ที่เหลือยังทำงานต่อ
   - ถ้า boundTicketCount == 0 หลังปิด → เข้า Grid Mode
6. return true (ทำงานแล้ว)

#### 3. เรียกใน `ManageHedgeSets()` (line 6137) — branch `!isExpansion`

```text
else if(!isExpansion)
{
   // Check bound orders gone → grid mode
   if(g_hedgeSets[h].boundTicketCount == 0 && hedgeExists) {
      gridMode = true; gridLevel = CalculateEquivGridLevel(...); continue;
   }
   
   // NEW: Average TP check (ซอย hedge ด้วยกำไร bound orders)
   if(ManageHedgeBoundAvgTP(h)) continue;
   
   if(hedgePnL > 0) ManageHedgeMatchingClose(h);
   else ManageHedgePartialClose(h);
}
```

#### 4. Version bump: v5.4 → v5.5

### ผลลัพธ์
- Average TP ถึง → ปิด bound orders ที่บวก → ซอย hedge ลดขนาด → bound ที่เหลือทำงานต่อ
- bound หมด → Grid Mode → Hedge Grid orders ออกมาซอย hedge ที่เหลือจนหมด
- ทำงานร่วมกับ Matching Close และ Partial Close ได้ (Average TP เช็คก่อน)

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter, Time filter, Data sync)
- ManageHedgeMatchingClose, ManageHedgePartialClose, ManageHedgeGridMode logic
- Bound ticket management, Lot Cap
- Accumulate/Drawdown close logic

