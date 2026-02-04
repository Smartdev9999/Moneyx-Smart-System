

## แผนแก้ไข: Grid Lot Recovery v2.2.4

---

### สรุปปัญหาที่พบ

| ตัวแปร | Backtest | Live Trading (หลัง Restart) |
|--------|----------|----------------------------|
| `lastProfitGridLotBuyA/B` | อัปเดตหลัง open GP | **= 0** (ไม่ถูก restore) |
| `lastProfitGridLotSellA/B` | อัปเดตหลัง open GP | **= 0** (ไม่ถูก restore) |
| `lastGridLotBuyA/B` | อัปเดตหลัง open GL | **= 0** (ไม่ถูก restore) |
| `lastGridLotSellA/B` | อัปเดตหลัง open GL | **= 0** (ไม่ถูก restore) |
| **Compounding** | ทำงานปกติ | **ใช้ baseLot แทน!** |

---

### ตัวอย่างจากรูปที่แนบ

```text
Settings:
- Grid Lot Calculation Mode: ATR Trend Mode (CDC Trend + Compounding)
- Lot Progression Mode: Compounding (prev × mult each level)
- Trend-Aligned Side: Fixed Multiplier = 2.0

Expected:
Initial: 0.1 → GP#1: 0.2 (0.1 × 2.0) → GP#2: 0.4 (0.2 × 2.0)

Actual (หลัง restart):
Initial: 0.1 → GP#1: 0.1 (ใช้ baseLot!) → GP#2: 0.1 (ใช้ baseLot!)
```

---

### สาเหตุ

```text
CalculateTrendBasedLots() (บรรทัด 6909-6951)
├── ถ้า isGridOrder && Compounding:
│   ├── ใช้ lastProfitGridLotBuyA/B สำหรับ Grid Profit
│   └── ใช้ lastGridLotBuyA/B สำหรับ Grid Loss
│
└── ปัญหา: หลัง restart ค่าเหล่านี้ = 0 → fallback ไปใช้ initialLot!

if(isProfitSide) {
   if(isTrendAlignedA && g_pairs[pairIndex].lastProfitGridLotBuyA > 0)  // = 0 หลัง restart!
      effectiveBaseLotA = g_pairs[pairIndex].lastProfitGridLotBuyA;
   // ... ถ้า = 0 ก็จะใช้ initialLotA แทน!
}
```

---

### การแก้ไข

#### Part A: อัปเดต Version

**ไฟล์:** `public/docs/mql5/Harmony_Dream_EA.mq5`  
**บรรทัด:** 7, 10

```cpp
#property version   "2.24"
#property description "v2.2.4: Fix Grid Lot Recovery - Restore Last Grid Lots for Compounding"
```

---

#### Part B: เพิ่ม Grid Lot Recovery ใน BUY Grid Loss section

**ไฟล์:** `public/docs/mql5/Harmony_Dream_EA.mq5`  
**ตำแหน่ง:** หลังบรรทัด 1737 (ใน Grid Loss BUY recovery)

```cpp
if(StringFind(comment, "_GL") >= 0)
{
   g_pairs[i].avgOrderCountBuy++;
   
   // v2.2.3: Update lastAvgPriceBuy to latest Grid Loss price (lowest for BUY)
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   if(g_pairs[i].lastAvgPriceBuy == 0 || openPrice < g_pairs[i].lastAvgPriceBuy)
   {
      g_pairs[i].lastAvgPriceBuy = openPrice;
   }
   
   // v2.2.4: Restore lastGridLotBuy for Compounding (use LARGEST lot = latest level)
   double gridLot = PositionGetDouble(POSITION_VOLUME);
   if(symbol == symbolA && gridLot > g_pairs[i].lastGridLotBuyA)
   {
      g_pairs[i].lastGridLotBuyA = gridLot;
   }
   else if(symbol == symbolB && gridLot > g_pairs[i].lastGridLotBuyB)
   {
      g_pairs[i].lastGridLotBuyB = gridLot;
   }
}
```

---

#### Part C: เพิ่ม Grid Lot Recovery ใน BUY Grid Profit section

**ไฟล์:** `public/docs/mql5/Harmony_Dream_EA.mq5`  
**ตำแหน่ง:** หลังบรรทัด 1748 (ใน Grid Profit BUY recovery)

```cpp
else if(StringFind(comment, "_GP") >= 0)
{
   g_pairs[i].gridProfitCountBuy++;
   
   // v2.2.3: Update lastProfitPriceBuy to latest Grid Profit price (highest for BUY)
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   if(g_pairs[i].lastProfitPriceBuy == 0 || openPrice > g_pairs[i].lastProfitPriceBuy)
   {
      g_pairs[i].lastProfitPriceBuy = openPrice;
   }
   
   // v2.2.4: Restore lastProfitGridLotBuy for Compounding (use LARGEST lot = latest level)
   double gridLot = PositionGetDouble(POSITION_VOLUME);
   if(symbol == symbolA && gridLot > g_pairs[i].lastProfitGridLotBuyA)
   {
      g_pairs[i].lastProfitGridLotBuyA = gridLot;
   }
   else if(symbol == symbolB && gridLot > g_pairs[i].lastProfitGridLotBuyB)
   {
      g_pairs[i].lastProfitGridLotBuyB = gridLot;
   }
}
```

---

#### Part D: เพิ่ม Grid Lot Recovery ใน SELL Grid Loss section

**ไฟล์:** `public/docs/mql5/Harmony_Dream_EA.mq5`  
**ตำแหน่ง:** หลังบรรทัด 1831 (ใน Grid Loss SELL recovery)

```cpp
if(StringFind(comment, "_GL") >= 0)
{
   g_pairs[i].avgOrderCountSell++;
   
   // v2.2.3: Update lastAvgPriceSell to latest Grid Loss price (highest for SELL)
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   if(g_pairs[i].lastAvgPriceSell == 0 || openPrice > g_pairs[i].lastAvgPriceSell)
   {
      g_pairs[i].lastAvgPriceSell = openPrice;
   }
   
   // v2.2.4: Restore lastGridLotSell for Compounding (use LARGEST lot = latest level)
   double gridLot = PositionGetDouble(POSITION_VOLUME);
   if(symbol == symbolA && gridLot > g_pairs[i].lastGridLotSellA)
   {
      g_pairs[i].lastGridLotSellA = gridLot;
   }
   else if(symbol == symbolB && gridLot > g_pairs[i].lastGridLotSellB)
   {
      g_pairs[i].lastGridLotSellB = gridLot;
   }
}
```

---

#### Part E: เพิ่ม Grid Lot Recovery ใน SELL Grid Profit section

**ไฟล์:** `public/docs/mql5/Harmony_Dream_EA.mq5`  
**ตำแหน่ง:** หลังบรรทัด 1842 (ใน Grid Profit SELL recovery)

```cpp
else if(StringFind(comment, "_GP") >= 0)
{
   g_pairs[i].gridProfitCountSell++;
   
   // v2.2.3: Update lastProfitPriceSell to latest Grid Profit price (lowest for SELL)
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   if(g_pairs[i].lastProfitPriceSell == 0 || openPrice < g_pairs[i].lastProfitPriceSell)
   {
      g_pairs[i].lastProfitPriceSell = openPrice;
   }
   
   // v2.2.4: Restore lastProfitGridLotSell for Compounding (use LARGEST lot = latest level)
   double gridLot = PositionGetDouble(POSITION_VOLUME);
   if(symbol == symbolA && gridLot > g_pairs[i].lastProfitGridLotSellA)
   {
      g_pairs[i].lastProfitGridLotSellA = gridLot;
   }
   else if(symbol == symbolB && gridLot > g_pairs[i].lastProfitGridLotSellB)
   {
      g_pairs[i].lastProfitGridLotSellB = gridLot;
   }
}
```

---

#### Part F: เพิ่ม Main Order Lot as Initial Grid Lot

**ปัญหา:** ถ้ามีเฉพาะ Main Order (ยังไม่มี Grid) ต้อง initialize `lastGridLot*` จาก Main Order lot

**ไฟล์:** `public/docs/mql5/Harmony_Dream_EA.mq5`  
**ตำแหน่ง:** หลังบรรทัด 1779 (หลัง restore EntryPrice for BUY)

เพิ่มใน Main Order BUY recovery:
```cpp
// v2.2.4: Initialize Grid Lots from Main Order (for first Grid level)
if(g_pairs[i].lastGridLotBuyA == 0)
   g_pairs[i].lastGridLotBuyA = g_pairs[i].lotBuyA;
if(g_pairs[i].lastGridLotBuyB == 0)
   g_pairs[i].lastGridLotBuyB = g_pairs[i].lotBuyB;
if(g_pairs[i].lastProfitGridLotBuyA == 0)
   g_pairs[i].lastProfitGridLotBuyA = g_pairs[i].lotBuyA;
if(g_pairs[i].lastProfitGridLotBuyB == 0)
   g_pairs[i].lastProfitGridLotBuyB = g_pairs[i].lotBuyB;
```

**ตำแหน่ง:** หลัง SELL Main Order recovery (ใกล้บรรทัด 1870)

```cpp
// v2.2.4: Initialize Grid Lots from Main Order (for first Grid level)
if(g_pairs[i].lastGridLotSellA == 0)
   g_pairs[i].lastGridLotSellA = g_pairs[i].lotSellA;
if(g_pairs[i].lastGridLotSellB == 0)
   g_pairs[i].lastGridLotSellB = g_pairs[i].lotSellB;
if(g_pairs[i].lastProfitGridLotSellA == 0)
   g_pairs[i].lastProfitGridLotSellA = g_pairs[i].lotSellA;
if(g_pairs[i].lastProfitGridLotSellB == 0)
   g_pairs[i].lastProfitGridLotSellB = g_pairs[i].lotSellB;
```

---

#### Part G: เพิ่ม Log สำหรับ Grid Lot Recovery

**ตำแหน่ง:** ท้าย RestoreOpenPositions() ก่อน Print summary

```cpp
// v2.2.4: Log restored Grid Lots for Compounding
for(int i = 0; i < MAX_PAIRS; i++)
{
   if(!g_pairs[i].enabled) continue;
   
   if(g_pairs[i].directionBuy == 1)
   {
      PrintFormat("[v2.2.4] Pair %d BUY GridLots: GL(A=%.2f,B=%.2f) GP(A=%.2f,B=%.2f)",
                  i + 1, 
                  g_pairs[i].lastGridLotBuyA, g_pairs[i].lastGridLotBuyB,
                  g_pairs[i].lastProfitGridLotBuyA, g_pairs[i].lastProfitGridLotBuyB);
   }
   if(g_pairs[i].directionSell == 1)
   {
      PrintFormat("[v2.2.4] Pair %d SELL GridLots: GL(A=%.2f,B=%.2f) GP(A=%.2f,B=%.2f)",
                  i + 1,
                  g_pairs[i].lastGridLotSellA, g_pairs[i].lastGridLotSellB,
                  g_pairs[i].lastProfitGridLotSellA, g_pairs[i].lastProfitGridLotSellB);
   }
}
```

---

### สรุปไฟล์ที่แก้ไข

| ไฟล์ | ส่วนที่แก้ไข | บรรทัด | รายละเอียด |
|------|-------------|--------|------------|
| `Harmony_Dream_EA.mq5` | Version | 7, 10 | อัปเดตเป็น v2.24 |
| `Harmony_Dream_EA.mq5` | BUY GL Recovery | ~1737 | เพิ่ม restore `lastGridLotBuyA/B` |
| `Harmony_Dream_EA.mq5` | BUY GP Recovery | ~1748 | เพิ่ม restore `lastProfitGridLotBuyA/B` |
| `Harmony_Dream_EA.mq5` | BUY Main Recovery | ~1779 | Initialize grid lots จาก Main |
| `Harmony_Dream_EA.mq5` | SELL GL Recovery | ~1831 | เพิ่ม restore `lastGridLotSellA/B` |
| `Harmony_Dream_EA.mq5` | SELL GP Recovery | ~1842 | เพิ่ม restore `lastProfitGridLotSellA/B` |
| `Harmony_Dream_EA.mq5` | SELL Main Recovery | ~1870 | Initialize grid lots จาก Main |
| `Harmony_Dream_EA.mq5` | Summary Log | End | Log restored grid lots |

---

### ผลลัพธ์ที่คาดหวัง

| สถานการณ์ | ก่อนแก้ไข | หลังแก้ไข v2.2.4 |
|-----------|----------|------------------|
| EA Restart มี GP#1 (0.2 lot) | `lastProfitGridLotBuyA = 0` → GP#2 = 0.2 | `lastProfitGridLotBuyA = 0.2` → GP#2 = 0.4 |
| EA Restart มี GL#2 (0.4 lot) | `lastGridLotBuyA = 0` → GL#3 = 0.2 | `lastGridLotBuyA = 0.4` → GL#3 = 0.8 |
| EA Restart มีเฉพาะ Main (0.1) | Grid lots = 0 → GP#1 = 0.1 | Grid lots = 0.1 → GP#1 = 0.2 |

---

### Recovery Logic สรุป (v2.2.4 Complete)

```text
BUY Side:
├── Main Order
│   ├── initialEntryPriceBuy = POSITION_PRICE_OPEN (v2.2.3)
│   ├── lastAvgPriceBuy = POSITION_PRICE_OPEN (v2.2.3)
│   ├── lastGridLotBuyA/B = lotBuyA/B (v2.2.4 - NEW)
│   └── lastProfitGridLotBuyA/B = lotBuyA/B (v2.2.4 - NEW)
│
├── Grid Loss Orders
│   ├── lastAvgPriceBuy = MIN(price) (v2.2.3)
│   └── lastGridLotBuyA/B = MAX(lot) (v2.2.4 - NEW)
│
└── Grid Profit Orders
    ├── lastProfitPriceBuy = MAX(price) (v2.2.3)
    └── lastProfitGridLotBuyA/B = MAX(lot) (v2.2.4 - NEW)
```

---

### Technical Notes

- ใช้ `POSITION_VOLUME` เพื่อ extract lot จาก Grid Order
- ใช้ MAX(lot) เพื่อหา lot ล่าสุด (เพราะ Compounding = lot เพิ่มขึ้นเรื่อยๆ)
- Initialize จาก Main Order lot ถ้ายังไม่มี Grid Order
- ไม่แก้ไขเงื่อนไขการออก order - แก้เฉพาะ recovery logic เท่านั้น
- ทำงานร่วมกับ v2.2.3 (Entry Price Recovery) ได้สมบูรณ์

