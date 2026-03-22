

## Fix: Hedge System Guards + Dashboard Improvements (v5.5 → v5.6)

### ปัญหา 5 จุดที่ต้องแก้

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

---

#### 1. ห้าม Normal Matching Close ปิด Order ที่ Bound กับ Hedge Set

**Line 6747:** เพิ่ม `IsTicketBound(ticket)` check หลัง hedge comment check:
```cpp
if(IsTicketBound(ticket)) continue;  // reserved for hedge system
```

#### 2. Hedge Lot Calculation — ใช้ Unbound Counter Lots แทน Global Net

**Line 6071-6076:** เปลี่ยนจาก `CalculateNetHedgeLots()` เป็น:
```text
double unboundCounterLots = 0;
for(all positions):
  if type == counterSide && !IsHedgeComment(cmt) && !IsTicketBound(ticket):
    unboundCounterLots += volume;
if(unboundCounterLots <= 0) return;
hedgeLots = unboundCounterLots;
```

#### 3. Guard hasCounterOrders — เช็คเฉพาะ Unbound Non-Hedge Orders

**Line 6046-6057:** เพิ่ม filter:
```cpp
string cmt = PositionGetString(POSITION_COMMENT);
if(IsHedgeComment(cmt)) continue;
if(IsTicketBound(ticket)) continue;
```

#### 4. ห้าม Hedge Partial/Matching/Grid Close ทำงานระหว่าง Expansion

**Line 6207-6233:** ปัจจุบัน `gridMode` ทำงานทุก tick ไม่สน expansion, Partial/Matching ถูก guard แล้วด้วย `!isExpansion` — แต่ Grid Mode ยังไม่ถูก guard

แก้ให้ Grid Mode ก็ต้องอยู่ในเงื่อนไข `!isExpansion` เหมือนกัน:
```text
เดิม:
  if(gridMode)
    ManageHedgeGridMode(h);        ← ทำงานแม้ expansion
  else if(!isExpansion)
    ManageHedgePartialClose/MatchingClose

ใหม่:
  if(!isExpansion)
  {
    if(gridMode)
      ManageHedgeGridMode(h);
    else
      // Partial/Matching Close
  }
  else
  {
    // expansion: เช็คเฉพาะ bound orders หมดหรือยัง → flag gridMode
  }
```

**ผล:** ทุกการปิด order ของ hedge system จะเกิดขึ้นเฉพาะตอน Normal/Squeeze เท่านั้น

#### 5. เพิ่ม Expansion Direction Label บน Dashboard

**Line 2997-3012:** เมื่อ state == EXPANSION เพิ่ม direction arrow:
```text
"EXPANSION ▲ BUY  3.49 |#########|"   (direction == 1)
"EXPANSION ▼ SELL 3.49 |#########|"   (direction == -1)
```

#### 6. Dashboard Default Values

```text
DashboardX:    20 → 50
DashboardY:    30 → 60
DashboardWidth: 340 → 400
HedgeDashY:    500 → 65
```

### Version bump: v5.5 → v5.6

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Normal Matching Close logic (เพิ่มแค่ guard skip bound tickets)
- Hedge Cycle Monitor dashboard

