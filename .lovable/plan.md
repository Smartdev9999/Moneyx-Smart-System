

## Fix: Order ค้างหลัง Hedge Matching Close + รวมแผน Dashboard (v5.11 → v5.12)

### ปัญหา: Order ชุด E ค้างหลัง Hedge Matching Close

**สาเหตุ:** ใน `ManageHedgeMatchingClose()` (line 6384-6412) เมื่อ hedge matching close สำเร็จ (`lossUsed > 0`):

```text
ขั้นตอนปัจจุบัน:
1. ปิด hedge order ✓
2. ปิด loss orders ที่ match ได้ ✓
3. ลบ matched tickets จาก boundTickets ✓
4. DEACTIVATE set ทันที ← ปัญหาอยู่ตรงนี้!
   boundTicketCount = 0, active = false
```

**ปัญหา:** ถ้า hedge profit match ได้แค่ 3 จาก 8 bound orders → 5 orders เหลือ → set ถูก deactivate → orders กลายเป็น orphan → ไม่มีระบบดูแล → ไม่มี grid recovery

**เปรียบเทียบ:** เมื่อ `lossUsed == 0` (line 6414-6436) มีการเช็ค `boundTicketCount > 0` แล้วเข้า Grid Mode อย่างถูกต้อง แต่ path สำเร็จ (line 6384) ไม่มีการเช็คนี้

---

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. แก้ `ManageHedgeMatchingClose()` — เช็ค bound orders หลัง matching สำเร็จ

```text
เดิม (line 6407-6412):
  g_hedgeSets[idx].active = false;
  g_hedgeSets[idx].boundTicketCount = 0;
  ArrayResize(g_hedgeSets[idx].boundTickets, 0);
  g_hedgeSetCount--;
  Sleep(100);

ใหม่:
  // Refresh bound tickets หลังปิด orders
  RefreshBoundTickets(idx);
  
  if(g_hedgeSets[idx].boundTicketCount > 0)
  {
     // ยังมี orders ค้าง → เข้า Grid Mode เพื่อ recovery
     g_hedgeSets[idx].gridMode = true;
     g_hedgeSets[idx].hedgeTicket = 0;  // hedge ปิดแล้ว
     g_hedgeSets[idx].gridLevel = CalculateEquivGridLevel(
        CalculateRemainingBoundLots(idx));
     Print("HEDGE Set#", idx+1, " matched but ", 
           g_hedgeSets[idx].boundTicketCount, 
           " bound orders remain. Entering Grid Mode.");
  }
  else
  {
     g_hedgeSets[idx].active = false;
     g_hedgeSets[idx].boundTicketCount = 0;
     ArrayResize(g_hedgeSets[idx].boundTickets, 0);
     g_hedgeSetCount--;
  }
  Sleep(100);
```

#### 2. เพิ่มฟังก์ชัน `CalculateRemainingBoundLots()`

```cpp
double CalculateRemainingBoundLots(int idx)
{
   double totalLots = 0;
   for(int i = 0; i < g_hedgeSets[idx].boundTicketCount; i++)
   {
      if(PositionSelectByTicket(g_hedgeSets[idx].boundTickets[i]))
         totalLots += PositionGetDouble(POSITION_VOLUME);
   }
   return totalLots;
}
```

#### 3. แก้ `ManageHedgeGridMode()` — รองรับกรณี hedge ticket = 0

ปัจจุบัน Grid Mode สมมุติว่ายังมี main hedge อยู่เสมอ → ถ้า `hedgeTicket == 0` (ปิดไปแล้วจาก matching close) grid ต้องเปิด orders ฝั่งเดิมของ hedge เพื่อ recovery:

```text
เพิ่มตอนต้น ManageHedgeGridMode():
  if(g_hedgeSets[idx].hedgeTicket == 0)
  {
     // Main hedge ถูกปิดแล้ว → grid orders ที่ profit จะ match กับ bound orders ที่เหลือ
     // ใช้ normal matching close logic สำหรับ bound orders
     ManageGridRecoveryMode(idx);
     return;
  }
```

#### 4. เพิ่มฟังก์ชัน `ManageGridRecoveryMode()`

ฟังก์ชันใหม่สำหรับ recovery bound orders ที่เหลือหลัง hedge ปิดแล้ว:
- สแกน grid orders (GM_HG{idx}) ที่กำไร
- ใช้ budget จากกำไร grid เพื่อ matching close กับ bound orders ที่ขาดทุน
- ถ้า bound orders หมด → deactivate set
- ถ้ายังเหลือ → เปิด grid order ถัดไปตามระยะ ATR/Grid distance

#### 5. ซ่อน Cycle Details จาก Dashboard หลัก + เพิ่ม PnL ใน Hedge Monitor

ตามแผนที่อนุมัติก่อนหน้า:
- ลบ "Counter-Trend Hedging Section" จาก `DisplayDashboard()`
- เพิ่ม PnL เป็นบรรทัดที่ 2 ในแต่ละ cell ของ Hedge Cycle Monitor
- ปรับ `rowH` เพื่อรองรับ 2 บรรทัด
- PnL สีเขียว/แดงตามกำไร-ขาดทุน

#### 6. Version bump: v5.11 → v5.12

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge Guards (cycle-aware, squeeze directional block)
- Normal Matching Close logic
- Dashboard หลัก (ข้อมูลอื่นๆ)

