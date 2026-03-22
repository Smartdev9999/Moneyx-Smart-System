

## Fix: Hedge Set ค้าง (Stale Data) + Comment หาย + Hedge ไม่เปิดใหม่ (v5.16 → v5.17)

### วิเคราะห์ปัญหา

**ปัญหา 3 จุดที่เกี่ยวเนื่องกัน:**

**1. Hedge Comment หาย** — `OpenOrder()` ส่ง comment `"GM_HEDGE_X"` ถูกต้อง แต่ broker อาจตัด/strip comment ออก → scan ticket ด้วย comment match ที่ line 6170-6181 ไม่เจอ → `hedgeTicket = 0`

**2. Hedge Set ยังค้างหลังปิด Order** — Flow ที่ทำให้ค้าง:
```text
1. Hedge เปิดสำเร็จ → hedgeTicket ได้ค่าถูกต้อง (สมมุติ comment ไม่โดนลบ)
2. ระหว่าง expansion: bound orders หมด → line 6285 set gridMode = true
3. Expansion เปลี่ยนเป็น Normal → orders ถูกปิดโดยระบบอื่น (matching close/accumulate)
4. Hedge order ถูกปิด → hedgeExists = false
5. แต่ gridMode = true → line 6239 check (!hedgeExists && !gridMode) = FALSE → ไม่ deactivate!
6. hedgeTicket ยังเป็นค่าเก่า (> 0 แต่ position ไม่มีแล้ว)
7. Line 6266: gridMode=true && hedgeTicket>0 → เรียก ManageGridRecoveryMode
8. Recovery ทำงานไม่ได้ → set ค้างถาวร
```

**3. Hedge ใหม่ไม่เปิด** — Set เก่ายังคง `active = true` → Guard 2 (line 6094-6100) เจอ hedge ทิศเดียวกันใน cycle เดียวกัน → block + `g_hedgeSetCount` ผิด → `FindFreeHedgeSlot` อาจไม่เจอ slot ว่าง

---

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. แก้ Hedge Ticket Lookup — ใช้ `trade.ResultDeal()` แทน Comment Scan

ปัจจุบัน line 6168-6181 scan by comment match ซึ่ง fail ถ้า broker strip comment

```text
เดิม:
  g_hedgeSets[slot].hedgeTicket = 0;
  for(scan by comment match...)

ใหม่:
  // ใช้ trade result เพื่อหา ticket โดยตรง
  g_hedgeSets[slot].hedgeTicket = 0;
  ulong dealId = trade.ResultDeal();
  if(dealId > 0)
  {
     HistoryDealSelect(dealId);
     long posId = HistoryDealGetInteger(dealId, DEAL_POSITION_ID);
     if(posId > 0)
        g_hedgeSets[slot].hedgeTicket = (ulong)posId;
  }
  // Fallback: scan by comment if trade result failed
  if(g_hedgeSets[slot].hedgeTicket == 0)
  {
     for(existing comment scan loop...)
  }
```

**ผล:** แม้ broker ลบ comment → trade result ยังให้ ticket ถูกต้อง

#### 2. แก้ `ManageHedgeSets()` — Deactivation ต้องครอบ gridMode ด้วย

เพิ่ม cleanup logic ก่อน gridMode check (หลัง line 6237):

```text
ใหม่ (แทรกหลัง line 6237):
  // v5.17: Full cleanup — ถ้า hedge ไม่อยู่ + bound หมด → deactivate ไม่ว่า gridMode จะเป็นอะไร
  if(!hedgeExists && g_hedgeSets[h].boundTicketCount == 0)
  {
     // ตรวจสอบว่ามี grid recovery orders (GM_HG) ค้างหรือไม่
     bool hasGridOrders = false;
     string gridPrefix = "GM_HG" + IntegerToString(h+1);
     for(int i = PositionsTotal()-1; i >= 0; i--)
     {
        ulong t = PositionGetTicket(i);
        if(t == 0) continue;
        if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
        if(StringFind(PositionGetString(POSITION_COMMENT), gridPrefix) >= 0)
        { hasGridOrders = true; break; }
     }
     
     if(!hasGridOrders)
     {
        Print("HEDGE Set#", h+1, " fully cleared (hedge+bound+grid all gone). Deactivating.");
        g_hedgeSets[h].active = false;
        g_hedgeSets[h].gridMode = false;
        g_hedgeSets[h].hedgeTicket = 0;
        g_hedgeSets[h].boundTicketCount = 0;
        ArrayResize(g_hedgeSets[h].boundTickets, 0);
        g_hedgeSetCount = MathMax(0, g_hedgeSetCount - 1);
        continue;
     }
  }
```

แก้ deactivation เดิมที่ line 6239-6248 ให้ reset hedgeTicket ด้วย:
```text
  if(!hedgeExists && !g_hedgeSets[h].gridMode)
  {
     // เดิม + เพิ่ม hedgeTicket = 0
     g_hedgeSets[h].hedgeTicket = 0;
     ...
  }
```

#### 3. แก้ `ManageHedgeSets()` — Reset hedgeTicket เมื่อ position หายแม้ gridMode

หลัง line 6237: ถ้า hedge ไม่อยู่แล้ว → reset hedgeTicket = 0 เสมอ (ไม่ว่า gridMode เป็นอะไร)

```text
เพิ่มหลัง hedgeExists check:
  if(!hedgeExists && g_hedgeSets[h].hedgeTicket > 0)
  {
     g_hedgeSets[h].hedgeTicket = 0;  // position ถูกปิดแล้ว → reset
  }
```

**ผล:** gridMode path ที่ line 6262 `hedgeTicket == 0` จะ match → เข้า ManageHedgeGridMode แทน ManageGridRecoveryMode → recovery ทำงานถูกต้อง

#### 4. ป้องกัน `g_hedgeSetCount` ติดลบ

ทุกจุดที่ `g_hedgeSetCount--` เปลี่ยนเป็น `g_hedgeSetCount = MathMax(0, g_hedgeSetCount - 1);`

#### 5. Version bump: v5.16 → v5.17

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge Guards logic (cycle-aware, squeeze directional block)
- Normal Matching Close logic
- Grid Recovery lot calculation + direction logic
- Dashboard / Hedge Cycle Monitor layout

