

## แผนแก้ไขรวม: Order Counting + ATR Caching (v2.1.6)

### สรุปปัญหาที่ยังไม่ได้แก้

จากภาพ Dashboard ปัจจุบัน:

| Set | Symbol Pair | Actual Positions | Dashboard Ord | ปัญหา |
|-----|-------------|------------------|---------------|-------|
| 2 | EURJPY-GBPJPY | 2 positions (1 pair) | 2 | ควรเป็น 1 |
| 7 | EURUSD-GBPUSD | 2 positions (1 pair) | 2 | ควรเป็น 1 |

**สาเหตุ:** `RestoreOpenPositions()` นับ `orderCountBuy++` ทุกครั้งที่พบ position (ทั้ง Symbol A และ B) แทนที่จะนับครั้งเดียวต่อ pair

---

### ส่วนที่ต้องแก้ไข

#### 1. แก้ไข RestoreOpenPositions() - นับออเดอร์ถูกต้อง

**ตำแหน่ง:** บรรทัด 1579-1635

**ปัญหาปัจจุบัน:**
```cpp
if(isBuySide)
{
   if(symbol == symbolA && g_pairs[i].ticketBuyA == 0)
   {
      g_pairs[i].ticketBuyA = ticket;
      ...
   }
   else if(symbol == symbolB && g_pairs[i].ticketBuyB == 0)
   {
      g_pairs[i].ticketBuyB = ticket;
      ...
   }
   
   g_pairs[i].orderCountBuy++;  // ← นับทุกครั้ง = นับซ้ำ!
}
```

**แก้ไขเป็น:**
```cpp
if(isBuySide)
{
   // v2.1.6: Track if this is Main or Grid order
   bool isMainOrder = (StringFind(comment, "_GL") < 0 && StringFind(comment, "_GP") < 0);
   bool shouldCount = false;
   
   if(symbol == symbolA && g_pairs[i].ticketBuyA == 0)
   {
      g_pairs[i].ticketBuyA = ticket;
      g_pairs[i].lotBuyA = PositionGetDouble(POSITION_VOLUME);
      PrintFormat("[v2.1.6] Restored BUY Pair %d SymbolA: %s ticket=%d lot=%.2f", 
                  i + 1, symbol, ticket, PositionGetDouble(POSITION_VOLUME));
      
      // v2.1.6: Count only when restoring Symbol A (main side) for Main orders
      if(isMainOrder) shouldCount = true;
   }
   else if(symbol == symbolB && g_pairs[i].ticketBuyB == 0)
   {
      g_pairs[i].ticketBuyB = ticket;
      g_pairs[i].lotBuyB = PositionGetDouble(POSITION_VOLUME);
      PrintFormat("[v2.1.6] Restored BUY Pair %d SymbolB: %s ticket=%d lot=%.2f", 
                  i + 1, symbol, ticket, PositionGetDouble(POSITION_VOLUME));
      
      // v2.1.6: Only count if Symbol A was NOT restored yet (orphan case)
      if(isMainOrder && g_pairs[i].ticketBuyA == 0) shouldCount = true;
   }
   
   // v2.1.6: Count Grid orders always (they are individual)
   if(!isMainOrder)
   {
      g_pairs[i].orderCountBuy++;
      if(StringFind(comment, "_GL") >= 0)
         g_pairs[i].avgOrderCountBuy++;
      else if(StringFind(comment, "_GP") >= 0)
         g_pairs[i].gridProfitCountBuy++;
   }
   else if(shouldCount)
   {
      // v2.1.6: Count main order only once per pair
      g_pairs[i].orderCountBuy++;
   }
   
   if(g_pairs[i].directionBuy != 1) g_pairs[i].directionBuy = 1;
   g_pairs[i].entryTimeBuy = (datetime)PositionGetInteger(POSITION_TIME);
   restoredBuy++;
}
```

**เช่นเดียวกันสำหรับ SELL Side** (บรรทัด 1608-1635)

---

#### 2. เพิ่ม ATR Cache Variables ใน PairInfo Struct

**ตำแหน่ง:** ใน `struct PairInfo` (~บรรทัด 130)

```cpp
// v2.1.6: ATR Caching
double   cachedGridLossATR;      // Cached ATR value for Grid Loss
double   cachedGridProfitATR;    // Cached ATR value for Grid Profit
datetime lastATRBarTime;         // Last bar time ATR was calculated
```

---

#### 3. สร้าง UpdateATRCache() Function

**ตำแหน่ง:** หลัง `CalculateSimplifiedATR()` (~บรรทัด 6243)

```cpp
//+------------------------------------------------------------------+
//| v2.1.6: Update ATR Cache on New Bar                                |
//+------------------------------------------------------------------+
void UpdateATRCache(int pairIndex)
{
   string symbolA = g_pairs[pairIndex].symbolA;
   
   // Check if new bar formed
   datetime currentBar = iTime(symbolA, InpGridLossATRTimeframe, 0);
   if(currentBar == g_pairs[pairIndex].lastATRBarTime)
      return;  // Same bar - use cached value
   
   // New bar - recalculate ATR
   g_pairs[pairIndex].lastATRBarTime = currentBar;
   
   // Grid Loss ATR
   g_pairs[pairIndex].cachedGridLossATR = CalculateSimplifiedATR(
      symbolA, InpGridLossATRTimeframe, InpGridLossATRPeriod);
   
   // Grid Profit ATR
   g_pairs[pairIndex].cachedGridProfitATR = CalculateSimplifiedATR(
      symbolA, InpGridProfitATRTimeframe, InpGridProfitATRPeriod);
   
   if(InpDebugMode && (!g_isTesterMode || !InpDisableDebugInTester))
   {
      PrintFormat("[v2.1.6 ATR] Pair %d (%s): GridLossATR=%.5f, GridProfitATR=%.5f",
                  pairIndex + 1, symbolA, 
                  g_pairs[pairIndex].cachedGridLossATR,
                  g_pairs[pairIndex].cachedGridProfitATR);
   }
}
```

---

#### 4. แก้ไข CalculateSimplifiedATR() - เริ่มจาก Bar 1

**ตำแหน่ง:** `CalculateSimplifiedATR()` (~บรรทัด 6224)

**จาก:**
```cpp
for(int i = 0; i < period; i++)
```

**เป็น:**
```cpp
// v2.1.6: Start from bar 1 (first CLOSED bar) for stable ATR
for(int i = 1; i <= period; i++)
```

---

#### 5. แก้ไข CalculateGridDistance() - ใช้ Cached ATR

**ตำแหน่ง:** `CalculateGridDistance()` ATR case (~บรรทัด 6101)

**จาก:**
```cpp
case GRID_DIST_ATR:
{
   double atr = CalculateSimplifiedATR(symbolA, atrTimeframe, atrPeriod);
   ...
}
```

**เป็น:**
```cpp
case GRID_DIST_ATR:
{
   // v2.1.6: Use cached ATR (updated once per new bar)
   double atr = g_pairs[pairIndex].cachedGridLossATR;
   if(atr <= 0)
   {
      // Fallback: calculate if cache empty (first run)
      atr = CalculateSimplifiedATR(symbolA, atrTimeframe, atrPeriod);
      g_pairs[pairIndex].cachedGridLossATR = atr;
   }
   ...
}
```

---

#### 6. เรียก UpdateATRCache() ใน OnTick()

**ตำแหน่ง:** ในส่วน New Bar check ของ `OnTick()` (~บรรทัด 2350)

```cpp
// v2.1.6: Update ATR cache on new bar for all active pairs
for(int i = 0; i < g_totalPairs; i++)
{
   if(!g_pairs[i].enabled) continue;
   UpdateATRCache(i);
}
```

---

### Flow หลังแก้ไข

```text
Order Counting Flow (v2.1.6):
┌─────────────────────────────────────────────────────────────────────┐
│ RestoreOpenPositions() พบ 2 positions ของ Set 7:                     │
│                                                                     │
│ 1. EURUSD (Symbol A) ticket=77384479                                │
│    └── ticketBuyA = 0 → Restore + shouldCount = true                │
│    └── orderCountBuy++ (นับครั้งแรก)                                 │
│                                                                     │
│ 2. GBPUSD (Symbol B) ticket=77384480                                │
│    └── ticketBuyB = 0 → Restore                                     │
│    └── ticketBuyA != 0 → shouldCount = false                        │
│    └── ไม่นับซ้ำ!                                                    │
│                                                                     │
│ ผลลัพธ์: Ord = 1 (ถูกต้อง)                                           │
└─────────────────────────────────────────────────────────────────────┘

ATR Caching Flow (v2.1.6):
┌─────────────────────────────────────────────────────────────────────┐
│ OnTick()                                                            │
│ ├── New Bar? → UpdateATRCache() for all pairs                       │
│ │   ├── Calculate ATR from Bar 1-14 (closed bars only)              │
│ │   ├── Store in cachedGridLossATR                                  │
│ │   └── Print debug log ONCE per bar                                │
│ │                                                                   │
│ └── CheckGridLoss()                                                 │
│     └── CalculateGridDistance() uses cached ATR                     │
│         ├── NO calculation (use cache)                              │
│         └── Grid distance is STABLE throughout the bar              │
└─────────────────────────────────────────────────────────────────────┘
```

---

### ผลลัพธ์ที่คาดหวัง

| หมวด | ก่อนแก้ไข | หลังแก้ไข |
|------|----------|----------|
| **Set 2 Ord** | 2 (ผิด) | 1 (ถูก) |
| **Set 7 Ord** | 2 (ผิด) | 1 (ถูก) |
| **ATR Calculation** | ทุก tick | 1 ครั้ง/bar |
| **ATR Debug Log** | Spam หลายร้อยครั้ง | 1 ครั้ง/bar |
| **Grid Distance** | เปลี่ยนทุก tick | คงที่ตลอด bar |

---

### สรุปไฟล์และบรรทัดที่แก้ไข

| ไฟล์ | ส่วนที่แก้ไข | บรรทัด (ประมาณ) | รายละเอียด |
|------|-------------|-----------------|------------|
| `Harmony_Dream_EA.mq5` | Version/Description | 7-10 | อัปเดตเป็น v2.16 |
| `Harmony_Dream_EA.mq5` | `struct PairInfo` | ~130 | เพิ่ม ATR cache variables |
| `Harmony_Dream_EA.mq5` | `RestoreOpenPositions()` BUY | 1579-1606 | แก้ไข logic นับออเดอร์ |
| `Harmony_Dream_EA.mq5` | `RestoreOpenPositions()` SELL | 1608-1635 | แก้ไข logic นับออเดอร์ |
| `Harmony_Dream_EA.mq5` | `UpdateATRCache()` | ~6243 (ใหม่) | สร้าง function cache ATR |
| `Harmony_Dream_EA.mq5` | `CalculateSimplifiedATR()` | ~6224 | เปลี่ยน loop i=0 → i=1 |
| `Harmony_Dream_EA.mq5` | `CalculateGridDistance()` | ~6101 | ใช้ cached ATR |
| `Harmony_Dream_EA.mq5` | `OnTick()` | ~2350 | เรียก UpdateATRCache() |

---

### Version Update

```cpp
#property version   "2.16"
#property description "v2.1.6: Order Counting Fix + ATR Caching + Stable Grid Distance"
```

