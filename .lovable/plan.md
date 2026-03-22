

## Fix: Hedge + Bound Orders ทั้งหมดติดลบ — ต้องเปิด Grid Recovery ขณะ Hedge ยังอยู่ (v5.14 → v5.15)

### สาเหตุ

กรณี Group E: มี hedge sell 0.15L + bound sell 3 orders (0.06L) = รวม 0.21L sell ทั้งหมดขาดทุน (ราคาขึ้น)

Flow ปัจจุบัน:
```text
ManageHedgeSets() → hedgeExists=true, gridMode=false
→ hedgePnL < 0 → ManageHedgePartialClose()
→ หา profit orders ฝั่ง BUY → ไม่มี → return
→ ไม่ทำอะไรเลย ❌
```

Grid Recovery ถูกเรียกเฉพาะเมื่อ `hedgeTicket == 0` → แต่ hedge ยังเปิดอยู่ → ไม่มีทางเข้า recovery

**ปัญหาเพิ่มเติม:** Hedge order ไม่มี comment (broker อาจลบ/ตัด) → `IsHedgeComment()` ไม่จับ → ระบบอื่นอาจนับรวมผิด

---

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. เพิ่ม "Stalled Hedge Detection" ใน `ManageHedgePartialClose()`

หลัง `if(profitCount == 0) return;` เปลี่ยนเป็น:

```text
if(profitCount == 0)
{
   // ทั้ง hedge + bound orders ติดลบหมด → ต้องเปิด grid recovery
   // เพื่อสร้าง profit orders ฝั่งตรงข้ามมาใช้ partial close
   // เข้า gridMode โดยยังคง hedgeTicket ไว้ (ไม่ปิด hedge)
   // Recovery grid จะเปิดฝั่ง counterSide เพื่อเมื่อกำไร → partial close hedge
   if(g_hedgeSets[idx].boundTicketCount > 0 && !g_hedgeSets[idx].gridMode)
   {
      // เช็คว่า bound orders ก็ขาดทุนทั้งหมดหรือไม่
      bool allBoundInLoss = true;
      for(int b = 0; b < g_hedgeSets[idx].boundTicketCount; b++)
      {
         if(PositionSelectByTicket(g_hedgeSets[idx].boundTickets[b]))
         {
            double bpnl = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
            if(bpnl > 0) { allBoundInLoss = false; break; }
         }
      }
      if(allBoundInLoss)
      {
         g_hedgeSets[idx].gridMode = true;
         double totalLots = hedgeLots + CalculateRemainingBoundLots(idx);
         g_hedgeSets[idx].gridLevel = CalculateEquivGridLevel(totalLots);
         Print("HEDGE Set#", idx+1, " STALLED: hedge + bound all in loss. ",
               "Total=", DoubleToString(totalLots,2), "L. Entering Grid Recovery.");
      }
   }
   return;
}
```

#### 2. แก้ `ManageGridRecoveryMode()` — รองรับกรณี hedge ยังเปิดอยู่

ปัจจุบัน recovery grid เปิดฝั่ง `hedgeSide` (ทิศเดียวกับ hedge) → ผิดในกรณีนี้

เมื่อ hedge ยังอยู่: grid recovery ต้องเปิดฝั่ง `counterSide` (ตรงข้าม hedge) เพื่อสร้าง profit มา partial close hedge

```text
เดิม:
  orderType = (hedgeSide == BUY) ? BUY : SELL;

ใหม่:
  if(g_hedgeSets[idx].hedgeTicket == 0)
     // hedge ปิดแล้ว → grid เปิดฝั่งเดิมของ hedge เพื่อ match bound orders
     orderType = (hedgeSide == BUY) ? BUY : SELL;
  else
     // hedge ยังอยู่ → grid เปิดฝั่งตรงข้าม เพื่อสร้าง profit ไป partial close hedge
     orderType = (hedgeSide == BUY) ? SELL : BUY;
```

แก้ทุกจุดที่กำหนด orderType ใน `ManageGridRecoveryMode()` (line 6763-6764 และ 6803-6804)

#### 3. แก้ `ManageGridRecoveryMode()` — matching close รองรับ hedge ยังอยู่

เมื่อ grid profit สะสมพอ:
- ถ้า `hedgeTicket == 0`: ปิด grid profit + match bound orders (เดิม)
- ถ้า `hedgeTicket > 0`: ใช้ grid profit เป็น "profit orders" → เรียก partial close hedge → แล้วซอยปิด bound orders จากเก่าสุด

```text
เพิ่มกรณี hedgeTicket > 0:
  if(gridTotalProfit > InpHedge_PartialMinProfit && hedgeTicket > 0)
  {
     // คำนวณ closeLots จาก profit
     // partial close hedge ก่อน
     // แล้วปิด grid profit orders
     // ถ้า hedge ปิดหมด → เริ่มซอยปิด bound orders จากเก่าสุด
  }
```

#### 4. แก้ Lot Calculation ใน Grid Recovery — ใช้ Total Remaining Lots

ปัจจุบัน line 6761: `nextLot = InitialLotSize` สำหรับ order แรก → ผิด

ควรคำนวณจาก total remaining lots (hedge + bound) เพื่อหา level ที่ถูกต้อง:

```text
double totalRemaining = CalculateRemainingBoundLots(idx);
if(g_hedgeSets[idx].hedgeTicket > 0 && PositionSelectByTicket(g_hedgeSets[idx].hedgeTicket))
   totalRemaining += PositionGetDouble(POSITION_VOLUME);

int equivLevel = CalculateEquivGridLevel(totalRemaining);
// คำนวณ lot ของ grid ถัดไปจาก equivLevel
nextLot = InitialLotSize * MathPow(GridLoss_MultiplyFactor, equivLevel + currentGridCount + 1);
```

#### 5. เพิ่ม `IsHedgeTicket()` helper — จับ hedge order ที่ไม่มี comment

```cpp
bool IsHedgeTicket(ulong ticket)
{
   for(int h = 0; h < MAX_HEDGE_SETS; h++)
   {
      if(g_hedgeSets[h].active && g_hedgeSets[h].hedgeTicket == ticket)
         return true;
   }
   return false;
}
```

เพิ่ม check นี้ในทุกที่ที่ใช้ `IsHedgeComment()` เป็น filter:
- `CountPositions()`, `FindLastOrder()`, `FindMaxLotOnSide()`
- `CalculateAveragePrice()`, `CalculateFloatingPL()`, `CloseAllSide()`
- เพิ่มเป็น: `if(IsHedgeComment(cmt) || IsHedgeTicket(ticket)) continue;`

#### 6. แก้ `ManageHedgeSets()` — routing logic สำหรับ gridMode + hedge ยังอยู่

```text
เดิม (line 6248):
  if(gridMode)
     ManageHedgeGridMode(h);     ← ไปเช็ค hedgeTicket==0 → เข้า recovery
  else
     if(hedgePnL > 0) ManageHedgeMatchingClose
     else ManageHedgePartialClose

ใหม่:
  if(gridMode && g_hedgeSets[h].hedgeTicket == 0)
     ManageHedgeGridMode(h);     // hedge ปิดแล้ว → recovery ปกติ
  else if(gridMode && g_hedgeSets[h].hedgeTicket > 0)
     ManageGridRecoveryMode(h);  // hedge ยังอยู่ → recovery สร้าง profit ฝั่งตรงข้าม
  else
     // ปกติ: partial/matching close
```

#### 7. Version bump: v5.14 → v5.15

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Normal Matching Close logic
- Hedge Guards (cycle-aware, squeeze directional block)
- Dashboard / Hedge Cycle Monitor

