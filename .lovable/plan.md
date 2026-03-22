

## Fix: Hedge Guard — ต้องมี Order ฝั่งตรงข้ามจริงๆ ก่อนเปิด Hedge (v5.2 → v5.3)

### สาเหตุของปัญหา

**Line 6008:** `if(netLots <= 0) return;` — ถ้า net > 0 ก็ผ่านไปเลย
**Line 6013:** `if(counterCount == 0 && netLots <= 0) return;` — เงื่อนไข `netLots <= 0` **ไม่มีทางเป็น true** เพราะ line 6008 filter ไปแล้ว → **dead code** → ไม่มีการเช็คว่ามี order ฝั่งตรงข้ามจริงหรือไม่

**ผล:** ระบบเปิด hedge ทุกครั้งที่มี expansion + net lot > 0 แม้ไม่มี order ติดอยู่ฝั่งผิด

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. แก้ Guard: ต้องมี order ฝั่ง counterSide จริง (line 6008-6013)

```text
เดิม:
  if(netLots <= 0) return;                          // line 6008
  counterCount = CountUnboundOrders(counterSide...); // line 6012
  if(counterCount == 0 && netLots <= 0) return;      // line 6013 ← dead code

ใหม่:
  // ต้องมี order ฝั่งตรงข้ามของ expansion จริงๆ ถึงจะ hedge
  // สแกนทุก position (รวม bound) ว่ามี counterSide อยู่หรือไม่
  bool hasCounterOrders = false;
  for all positions:
     if type == counterSide → hasCounterOrders = true; break;
  
  if(!hasCounterOrders) return;  // ไม่มี order ติดฝั่งผิด → ไม่ต้อง hedge
  
  if(netLots <= 0) return;       // net lot ต้อง > 0
```

**สำคัญ:** เช็ค **ทุก** position (ไม่ใช่แค่ unbound) เพราะ order ที่ bound อยู่ใน set เดิมก็ยังเป็น exposure ที่ต้อง hedge

#### 2. เพิ่ม Guard ป้องกัน hedge ซ้ำฝั่งเดียวกัน

```text
// ห้ามเปิด hedge ซ้ำทิศเดียวกันถ้ามี active set อยู่แล้ว
for(int h = 0; h < MAX_HEDGE_SETS; h++)
   if(g_hedgeSets[h].active && g_hedgeSets[h].hedgeSide == hedgeSide) return;
```

#### 3. เพิ่ม Guard: Hedge #2+ ต้อง expansion เปลี่ยนทิศ

```text
int g_lastHedgeExpansionDir = 0;  // global variable

// ใน CheckAndOpenHedge():
if(g_hedgeSetCount > 0 && bestDir == g_lastHedgeExpansionDir) return;

// หลังเปิดสำเร็จ:
g_lastHedgeExpansionDir = bestDir;
```

#### 4. แก้ Cycle increment — ย้ายไปตอนเปิด INIT order

ลบ `g_currentCycleIndex++` ออกจาก `CheckAndOpenHedge()` (line 6081-6082) → ย้ายไปใส่ตอนเปิด INIT order: `if(g_hedgeSetCount > 0) g_currentCycleIndex++`

#### 5. Version bump: v5.2 → v5.3

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Net Lot Calculation (`CalculateNetHedgeLots`)
- Hedge Partial/Matching Close, Grid Mode logic
- Normal Matching Close logic

