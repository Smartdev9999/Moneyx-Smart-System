

## Fix: H2-H4 Net Lot Calculation + Partial Close Orphan Bug (v5.17 → v5.18)

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

---

### ปัญหาที่ 1: H2-H4 Lot Calculation ผิด

**สาเหตุ:** Line 6112-6127 คำนวณ `unboundCounterLots` โดย **ข้าม** orders ที่มี comment `GM_HEDGE` และ `GM_HG` → H2-H4 ไม่เห็น hedge/grid orders จาก level ก่อนหน้า → lot คำนวณผิดหรือเป็น 0

**ตามที่ user อธิบาย:**
- H2 ต้องรวม lot ของ H1 hedge + grid orders ทั้งหมดในฝั่ง counter แล้วลบกับฝั่ง hedge → ส่วนต่าง = lot ของ H2
- H3 ต้องรวมทุก level (H1+H2) แล้วหาส่วนต่าง Buy-Sell → lot ของ H3
- หลักการ: **ทุก level ล็อคให้ Buy lots = Sell lots ภายใน cycle**

**แก้ไข:** เปลี่ยน `unboundCounterLots` เป็น **Net Imbalance Calculation**:

```text
เดิม (line 6112-6130):
  scan counter-side orders, skip GM_HEDGE/GM_HG, skip bound → hedgeLots = unboundCounterLots

ใหม่:
  // คำนวณ Buy lots vs Sell lots ทั้งหมดใน cycle นี้ (รวม hedge + grid + normal)
  double buyLots = 0, sellLots = 0;
  for(all positions with MagicNumber + _Symbol)
  {
     // รวม orders ทุกประเภทที่อยู่ใน cycle นี้
     // เช็คจาก: bound tickets ของ sets ใน cycle + hedge tickets + grid tickets + unbound
     if(IsBelongsToCycle(ticket, g_currentCycleIndex))
     {
        if(type == BUY) buyLots += volume;
        else sellLots += volume;
     }
  }
  double imbalance = MathAbs(buyLots - sellLots);
  if(imbalance <= 0) return;  // balanced → ไม่ต้อง hedge
  hedgeLots = NormalizeDouble(imbalance, 2);
  // hedgeSide ถูกกำหนดจาก expansion direction อยู่แล้ว (ด้านบน)
```

เพิ่ม helper function `IsBelongsToCycle()` — เช็คว่า ticket อยู่ใน cycle ใด:
- เป็น bound ticket ของ set ที่ cycleIndex ตรง
- เป็น hedgeTicket ของ set ที่ cycleIndex ตรง  
- เป็น grid ticket (GM_HG{slot}) ของ set ที่ cycleIndex ตรง
- เป็น unbound normal order ที่จะถูกผูกใน cycle ปัจจุบัน

---

### ปัญหาที่ 2: ManageHedgePartialClose — ปิด Hedge หมดแต่ไม่เช็ค Bound Orders

**สาเหตุ:** Line 6620-6627 เมื่อ `closeLots >= hedgeLots` → ปิด hedge + deactivate set ทันที → **ไม่เช็คว่ายังมี bound orders เหลือ** → orders กลายเป็น orphan

**แก้ไข:**
```text
เดิม (line 6620-6627):
  if(closeLots >= hedgeLots)
  {
     trade.PositionClose(hedgeTicket);
     active = false;
     boundTicketCount = 0;  ← ลบ bound ทิ้งเลย!
     g_hedgeSetCount--;
  }

ใหม่:
  if(closeLots >= hedgeLots)
  {
     trade.PositionClose(hedgeTicket);
     g_hedgeSets[idx].hedgeTicket = 0;
     RefreshBoundTickets(idx);
     
     if(g_hedgeSets[idx].boundTicketCount > 0)
     {
        // ยังมี bound orders → เข้า Grid Recovery
        g_hedgeSets[idx].gridMode = true;
        g_hedgeSets[idx].gridLevel = CalculateEquivGridLevel(
           CalculateRemainingBoundLots(idx));
        Print("HEDGE Set#", idx+1, " hedge fully closed but ",
              g_hedgeSets[idx].boundTicketCount, " bound orders remain.");
     }
     else
     {
        g_hedgeSets[idx].active = false;
        g_hedgeSetCount = MathMax(0, g_hedgeSetCount - 1);
     }
  }
```

---

### 3. Version bump: v5.17 → v5.18

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Normal Matching Close logic
- Dashboard / Hedge Cycle Monitor
- Grid Recovery lot calculation + direction logic
- Hedge Guards 1-3 (hasCounterOrders, same-direction, alternate-direction)

