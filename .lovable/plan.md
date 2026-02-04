

## แผนแก้ไข: Grid Recovery v2.2.3

---

### สรุปปัญหาที่พบ

| ตัวแปร | Backtest | Live Trading (หลัง Restart) |
|--------|----------|----------------------------|
| `initialEntryPriceBuy/Sell` | ถูกตั้งค่าตอน open order | **= 0** (ไม่ถูก restore) |
| `lastAvgPriceBuy/Sell` | อัปเดตต่อเนื่อง | **= 0** → reset เป็น currentPrice |
| **Grid Profit** | ทำงานปกติ | **ไม่ทำงานเลย** (return ทันที) |
| **Grid Loss** | ทำงานปกติ | ต้องรอราคาเคลื่อนที่ใหม่ |

---

### สาเหตุ

```text
RestoreOpenPositions() (บรรทัด 1596-1811)
├── ✅ Restore tickets (ticketBuyA, ticketSellA, etc.)
├── ✅ Restore lots (lotBuyA, lotSellA, etc.)
├── ✅ Restore direction (directionBuy, directionSell)
├── ❌ ไม่ restore initialEntryPriceBuy/Sell
└── ❌ ไม่ restore lastAvgPriceBuy/Sell
```

---

### การแก้ไข

#### Part A: อัปเดต Version

**ไฟล์:** `public/docs/mql5/Harmony_Dream_EA.mq5`
**บรรทัด:** 7, 10

```cpp
#property version   "2.23"
#property description "v2.2.3: Fix Grid Recovery - Restore Entry Price from Positions"
```

---

#### Part B: แก้ไข `RestoreOpenPositions()` เพิ่ม Entry Price Recovery

**ไฟล์:** `public/docs/mql5/Harmony_Dream_EA.mq5`
**ตำแหน่ง:** หลังบรรทัด 1741 (หลัง `g_pairs[i].entryTimeBuy = ...`)

เพิ่มโค้ดสำหรับ BUY side:
```cpp
   g_pairs[i].entryTimeBuy = (datetime)PositionGetInteger(POSITION_TIME);
   
   // v2.2.3: Restore entry price for Grid calculations
   if(isMainOrder && symbol == symbolA)
   {
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      
      // Set initialEntryPriceBuy if not set yet
      if(g_pairs[i].initialEntryPriceBuy == 0 || openPrice < g_pairs[i].initialEntryPriceBuy)
      {
         g_pairs[i].initialEntryPriceBuy = openPrice;
      }
      
      // Set lastAvgPriceBuy to entry price (Grid Loss reference)
      if(g_pairs[i].lastAvgPriceBuy == 0)
      {
         g_pairs[i].lastAvgPriceBuy = openPrice;
      }
      
      PrintFormat("[v2.2.3] Pair %d BUY: Restored EntryPrice=%.5f, LastAvgPrice=%.5f",
                  i + 1, g_pairs[i].initialEntryPriceBuy, g_pairs[i].lastAvgPriceBuy);
   }
   
   restoredBuy++;
```

---

#### Part C: เพิ่ม Entry Price Recovery สำหรับ SELL side

**ไฟล์:** `public/docs/mql5/Harmony_Dream_EA.mq5`
**ตำแหน่ง:** หลังบรรทัด 1795 (หลัง `g_pairs[i].entryTimeSell = ...`)

เพิ่มโค้ดสำหรับ SELL side:
```cpp
   g_pairs[i].entryTimeSell = (datetime)PositionGetInteger(POSITION_TIME);
   
   // v2.2.3: Restore entry price for Grid calculations
   if(isMainOrderSell && symbol == symbolA)
   {
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      
      // Set initialEntryPriceSell if not set yet
      if(g_pairs[i].initialEntryPriceSell == 0 || openPrice > g_pairs[i].initialEntryPriceSell)
      {
         g_pairs[i].initialEntryPriceSell = openPrice;
      }
      
      // Set lastAvgPriceSell to entry price (Grid Loss reference)
      if(g_pairs[i].lastAvgPriceSell == 0)
      {
         g_pairs[i].lastAvgPriceSell = openPrice;
      }
      
      PrintFormat("[v2.2.3] Pair %d SELL: Restored EntryPrice=%.5f, LastAvgPrice=%.5f",
                  i + 1, g_pairs[i].initialEntryPriceSell, g_pairs[i].lastAvgPriceSell);
   }
   
   restoredSell++;
```

---

#### Part D: เพิ่ม Grid Order Price Recovery

**ปัญหา:** ถ้ามี Grid Order อยู่แล้ว, `lastAvgPrice` ควรใช้ราคาของ Grid Order ล่าสุด ไม่ใช่ Main Order

**ไฟล์:** `public/docs/mql5/Harmony_Dream_EA.mq5`
**ตำแหน่ง:** ในส่วน BUY Grid order recovery (บรรทัด ~1726-1733)

แก้ไข:
```cpp
   // v2.1.6: Count Grid orders individually (they have _GL or _GP in comment)
   if(!isMainOrder)
   {
      g_pairs[i].orderCountBuy++;
      if(StringFind(comment, "_GL") >= 0)
      {
         g_pairs[i].avgOrderCountBuy++;
         
         // v2.2.3: Update lastAvgPriceBuy to latest Grid Loss price
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         if(g_pairs[i].lastAvgPriceBuy == 0 || openPrice < g_pairs[i].lastAvgPriceBuy)
         {
            g_pairs[i].lastAvgPriceBuy = openPrice;
         }
      }
      else if(StringFind(comment, "_GP") >= 0)
      {
         g_pairs[i].gridProfitCountBuy++;
         
         // v2.2.3: Update lastProfitPriceBuy to latest Grid Profit price
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         if(g_pairs[i].lastProfitPriceBuy == 0 || openPrice > g_pairs[i].lastProfitPriceBuy)
         {
            g_pairs[i].lastProfitPriceBuy = openPrice;
         }
      }
   }
```

**ตำแหน่ง:** ในส่วน SELL Grid order recovery (บรรทัด ~1779-1787)

แก้ไข:
```cpp
   // v2.1.6: Count Grid orders individually (they have _GL or _GP in comment)
   if(!isMainOrderSell)
   {
      g_pairs[i].orderCountSell++;
      if(StringFind(comment, "_GL") >= 0)
      {
         g_pairs[i].avgOrderCountSell++;
         
         // v2.2.3: Update lastAvgPriceSell to latest Grid Loss price
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         if(g_pairs[i].lastAvgPriceSell == 0 || openPrice > g_pairs[i].lastAvgPriceSell)
         {
            g_pairs[i].lastAvgPriceSell = openPrice;
         }
      }
      else if(StringFind(comment, "_GP") >= 0)
      {
         g_pairs[i].gridProfitCountSell++;
         
         // v2.2.3: Update lastProfitPriceSell to latest Grid Profit price
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         if(g_pairs[i].lastProfitPriceSell == 0 || openPrice < g_pairs[i].lastProfitPriceSell)
         {
            g_pairs[i].lastProfitPriceSell = openPrice;
         }
      }
   }
```

---

### สรุปไฟล์ที่แก้ไข

| ไฟล์ | ส่วนที่แก้ไข | บรรทัด | รายละเอียด |
|------|-------------|--------|------------|
| `Harmony_Dream_EA.mq5` | Version | 7, 10 | อัปเดตเป็น v2.23 |
| `Harmony_Dream_EA.mq5` | `RestoreOpenPositions()` BUY | ~1741 | เพิ่ม restore `initialEntryPriceBuy`, `lastAvgPriceBuy` |
| `Harmony_Dream_EA.mq5` | `RestoreOpenPositions()` SELL | ~1795 | เพิ่ม restore `initialEntryPriceSell`, `lastAvgPriceSell` |
| `Harmony_Dream_EA.mq5` | Grid Order BUY Recovery | ~1726 | เพิ่ม restore `lastAvgPriceBuy`, `lastProfitPriceBuy` |
| `Harmony_Dream_EA.mq5` | Grid Order SELL Recovery | ~1779 | เพิ่ม restore `lastAvgPriceSell`, `lastProfitPriceSell` |

---

### ผลลัพธ์ที่คาดหวัง

| สถานการณ์ | ก่อนแก้ไข | หลังแก้ไข v2.2.3 |
|-----------|----------|------------------|
| EA Restart มี BUY order | `initialEntryPriceBuy = 0` | Restore จาก Main Order Price |
| EA Restart มี Grid Loss | `lastAvgPriceBuy = currentPrice` | Restore จาก Grid Order Price ล่าสุด |
| Grid Profit ทำงาน | ❌ return ทันที | ✅ ทำงานปกติ |
| Grid Loss ทำงาน | ⚠️ รอราคาใหม่ | ✅ ต่อจากที่เดิม |

---

### Log Output หลัง Restart

```text
[v2.2.3] Pair 1 BUY: Restored EntryPrice=183.650, LastAvgPrice=183.650
[v2.2.3] Pair 7 SELL: Restored EntryPrice=1.08500, LastAvgPrice=1.08200
```

---

### Recovery Logic สรุป

```text
BUY Side:
├── Main Order → initialEntryPriceBuy = POSITION_PRICE_OPEN
│              → lastAvgPriceBuy = POSITION_PRICE_OPEN (ถ้ายังเป็น 0)
├── Grid Loss  → lastAvgPriceBuy = MIN(current, openPrice) // ราคาต่ำสุด
└── Grid Profit→ lastProfitPriceBuy = MAX(current, openPrice) // ราคาสูงสุด

SELL Side:
├── Main Order → initialEntryPriceSell = POSITION_PRICE_OPEN
│              → lastAvgPriceSell = POSITION_PRICE_OPEN (ถ้ายังเป็น 0)
├── Grid Loss  → lastAvgPriceSell = MAX(current, openPrice) // ราคาสูงสุด
└── Grid Profit→ lastProfitPriceSell = MIN(current, openPrice) // ราคาต่ำสุด
```

---

### Technical Notes

- **ไม่แก้ไขเงื่อนไขการออก order** - แก้เฉพาะ recovery logic เท่านั้น
- ใช้ `POSITION_PRICE_OPEN` จาก ticket เพื่อ restore ราคา
- Grid Loss ใช้ราคา "ต่ำสุด" สำหรับ BUY (ราคาลง = ขาดทุน)
- Grid Profit ใช้ราคา "สูงสุด" สำหรับ BUY (ราคาขึ้น = กำไร)
- ทำงานร่วมกับ v2.2.2 Grid Trend Guard ได้ปกติ

