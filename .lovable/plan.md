

## Fix: Dashboard แสดงข้อมูล Stale + PnL เฉพาะ Hedge Order (v5.18 → v5.19)

### สาเหตุ

**Dashboard ค้าง:** เมื่อ hedge order ถูกปิด → `hedgeTicket` reset เป็น 0 (line 6314) แต่ `hedgeLots` ไม่ถูก reset → Dashboard line 7776 ยังแสดง `hedgeLots` ค่าเก่า (เช่น 0.15L) ทั้งที่ไม่มี position แล้ว

**Set ยังคง active:** ถ้ามี grid recovery orders (`GM_HG{slot}`) ค้างอยู่ → line 6321-6328 เจอ → ไม่ deactivate (ถูกต้อง) แต่ dashboard ยังแสดง "H1:B 0.15L" ราวกับ hedge ยังเปิดอยู่

---

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Reset `hedgeLots` เมื่อ hedge ปิด

Line 6312-6315 เพิ่ม reset hedgeLots:
```cpp
if(!hedgeExists && g_hedgeSets[h].hedgeTicket > 0)
{
   g_hedgeSets[h].hedgeTicket = 0;
   g_hedgeSets[h].hedgeLots = 0;  // ← เพิ่ม
}
```

#### 2. Dashboard แสดงสถานะจริง — แยก hedge มี/ไม่มี

Line 7753-7777: เปลี่ยน display logic ให้เช็ค `hedgeTicket`:

```text
เดิม:
  cellText = "H1:B 0.15L B:3"  (ใช้ hedgeLots ค่าเก่าเสมอ)

ใหม่:
  if(hedgeTicket > 0 && PositionSelectByTicket(hedgeTicket))
     // Hedge ยังอยู่ → แสดงปกติ ใช้ POSITION_VOLUME จริง
     cellText = "H1:B 0.15L B:3"
  else if(gridMode)
     // Hedge ปิดแล้ว แต่ recovery mode → แสดง "REC" + bound count
     cellText = "H1:REC B:3"
  else if(boundTicketCount > 0)
     // Hedge ปิด ไม่มี grid → แสดง bound ที่เหลือ
     cellText = "H1:-- B:3"
```

#### 3. PnL แสดงเฉพาะ Hedge Order เท่านั้น (ตามแผน v5.19)

Line 7756-7772: ลบ loop grid tickets + bound orders → เหลือแค่:
```cpp
double pnl = 0;
if(g_hedgeSets[h].hedgeTicket > 0 && PositionSelectByTicket(g_hedgeSets[h].hedgeTicket))
   pnl = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
```

#### 4. Version bump: v5.18 → v5.19

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge/Grid Recovery logic ทั้งหมด
- Hedge Guards, Normal Matching Close logic

