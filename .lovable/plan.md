

## แผนแก้ไข: Fix Z-Score Entry Mode (v2.2.0)

---

### ยืนยัน Logic ที่ถูกต้อง

| Z-Score | การออก Order | เหตุผล (Mean Reversion) |
|---------|--------------|------------------------|
| **< -1.0 (ลบ)** | BUY Main (A) / SELL Sub (B) | Spread ต่ำกว่าปกติ → ซื้อ |
| **> +1.0 (บวก)** | SELL Main (A) / BUY Sub (B) | Spread สูงกว่าปกติ → ขาย |

**Logic นี้ถูกต้องแล้ว - ไม่ต้องเปลี่ยน**

---

### ปัญหาที่ต้องแก้ไข

| ปัญหา | รายละเอียด |
|-------|------------|
| **`continue` Bug** | บรรทัด 5946, 5979 - เมื่อ Grid Guard block จะ skip ทั้ง pair (รวม SELL side) |
| **ไม่มี Debug Log** | เมื่อ RSI/CDC block ไม่มี log บอกเหตุผล |

---

### การแก้ไข

#### Part A: อัปเดต Version

```cpp
#property version   "2.20"
#property description "v2.2.0: Fix Z-Score Entry - Add Debug Logs + Remove continue bug"
```

---

#### Part B: แก้ไข BUY Side Entry (บรรทัด 5937-5965)

**เปลี่ยนจาก nested if + continue เป็น flag-based:**

```cpp
// === BUY SIDE ENTRY (Z-SCORE MODE) ===
if(g_pairs[i].directionBuy == -1 && g_pairs[i].orderCountBuy < g_pairs[i].maxOrderBuy)
{
   if(zScore < -InpEntryZScore)
   {
      bool buyAllowed = true;
      string buyBlockReason = "";
      
      // Check 1: Grid Guard (Optional)
      if(buyAllowed && InpGridPauseAffectsMain)
      {
         string pauseReason = "";
         if(!CheckGridTradingAllowed(i, "BUY", pauseReason))
         {
            buyAllowed = false;
            buyBlockReason = "Grid Guard: " + pauseReason;
         }
      }
      
      // Check 2: RSI Confirmation
      if(buyAllowed && !CheckRSIEntryConfirmation(i, "BUY"))
      {
         buyAllowed = false;
         buyBlockReason = StringFormat("RSI Block (RSI=%.1f, need<=%.0f)", 
                                       g_pairs[i].rsiSpread, InpRSIOversold);
      }
      
      // Check 3: CDC Trend Confirmation
      if(buyAllowed && !CheckCDCTrendConfirmation(i, "BUY"))
      {
         buyAllowed = false;
         buyBlockReason = "CDC Block";
      }
      
      // Execute or Log
      if(buyAllowed)
      {
         if(OpenBuySideTrade(i))
         {
            g_pairs[i].directionBuy = 1;
            g_pairs[i].entryZScoreBuy = zScore;
            g_pairs[i].lastAvgPriceBuy = SymbolInfoDouble(g_pairs[i].symbolA, SYMBOL_ASK);
            g_pairs[i].justOpenedMainBuy = true;
            PrintFormat("[Z-SCORE] Pair %d OPENED BUY: Z=%.2f", i + 1, zScore);
         }
      }
      else if(InpDebugMode && (!g_isTesterMode || !InpDisableDebugInTester))
      {
         // v2.2.0: Throttled debug log
         string reason = StringFormat("BUY BLOCKED: %s (Z=%.2f)", buyBlockReason, zScore);
         datetime now = TimeCurrent();
         if(g_firstAnalyzeRun || reason != g_pairs[i].lastBlockReason || 
            now - g_pairs[i].lastBlockLogTime >= DEBUG_LOG_INTERVAL)
         {
            PrintFormat("[Z-SCORE] Pair %d %s/%s: %s",
                        i + 1, g_pairs[i].symbolA, g_pairs[i].symbolB, reason);
            g_pairs[i].lastBlockReason = reason;
            g_pairs[i].lastBlockLogTime = now;
         }
      }
   }
}
```

---

#### Part C: แก้ไข SELL Side Entry (บรรทัด 5967-5998)

**เหมือน BUY แต่เงื่อนไขกลับทาง:**

```cpp
// === SELL SIDE ENTRY (Z-SCORE MODE) ===
if(g_pairs[i].directionSell == -1 && g_pairs[i].orderCountSell < g_pairs[i].maxOrderSell)
{
   if(zScore > InpEntryZScore)
   {
      bool sellAllowed = true;
      string sellBlockReason = "";
      
      // Check 1: Grid Guard (Optional)
      if(sellAllowed && InpGridPauseAffectsMain)
      {
         string pauseReason = "";
         if(!CheckGridTradingAllowed(i, "SELL", pauseReason))
         {
            sellAllowed = false;
            sellBlockReason = "Grid Guard: " + pauseReason;
         }
      }
      
      // Check 2: RSI Confirmation
      if(sellAllowed && !CheckRSIEntryConfirmation(i, "SELL"))
      {
         sellAllowed = false;
         sellBlockReason = StringFormat("RSI Block (RSI=%.1f, need>=%.0f)", 
                                        g_pairs[i].rsiSpread, InpRSIOverbought);
      }
      
      // Check 3: CDC Trend Confirmation
      if(sellAllowed && !CheckCDCTrendConfirmation(i, "SELL"))
      {
         sellAllowed = false;
         sellBlockReason = "CDC Block";
      }
      
      // Execute or Log
      if(sellAllowed)
      {
         if(OpenSellSideTrade(i))
         {
            g_pairs[i].directionSell = 1;
            g_pairs[i].entryZScoreSell = zScore;
            g_pairs[i].lastAvgPriceSell = SymbolInfoDouble(g_pairs[i].symbolA, SYMBOL_BID);
            g_pairs[i].justOpenedMainSell = true;
            PrintFormat("[Z-SCORE] Pair %d OPENED SELL: Z=%.2f", i + 1, zScore);
         }
      }
      else if(InpDebugMode && (!g_isTesterMode || !InpDisableDebugInTester))
      {
         // v2.2.0: Throttled debug log
         string reason = StringFormat("SELL BLOCKED: %s (Z=%.2f)", sellBlockReason, zScore);
         datetime now = TimeCurrent();
         if(g_firstAnalyzeRun || reason != g_pairs[i].lastBlockReason || 
            now - g_pairs[i].lastBlockLogTime >= DEBUG_LOG_INTERVAL)
         {
            PrintFormat("[Z-SCORE] Pair %d %s/%s: %s",
                        i + 1, g_pairs[i].symbolA, g_pairs[i].symbolB, reason);
            g_pairs[i].lastBlockReason = reason;
            g_pairs[i].lastBlockLogTime = now;
         }
      }
   }
}
```

---

### สรุปไฟล์ที่แก้ไข

| ไฟล์ | ส่วนที่แก้ไข | บรรทัด | รายละเอียด |
|------|-------------|--------|------------|
| `Harmony_Dream_EA.mq5` | Version | 7-10 | อัปเดตเป็น v2.20 |
| `Harmony_Dream_EA.mq5` | Z-Score BUY Entry | 5937-5965 | เปลี่ยน `continue` เป็น flag + เพิ่ม debug log |
| `Harmony_Dream_EA.mq5` | Z-Score SELL Entry | 5967-5998 | เปลี่ยน `continue` เป็น flag + เพิ่ม debug log |

---

### ผลลัพธ์ที่คาดหวัง

| สถานการณ์ | ก่อนแก้ไข | หลังแก้ไข v2.2.0 |
|-----------|----------|------------------|
| Grid Guard block BUY | skip ทั้ง pair | skip แค่ BUY, ยังเช็ค SELL |
| RSI block | ไม่มี log | แสดง "BUY/SELL BLOCKED: RSI Block" |
| CDC block | ไม่มี log | แสดง "BUY/SELL BLOCKED: CDC Block" |
| Debug log | - | Throttled ทุก 30 วินาที |

---

### หมายเหตุ

- **ไม่แตะต้อง Correlation Only mode** (บรรทัด 5753-5928)
- **Logic Mean Reversion คงเดิม** (Z ลบ = BUY, Z บวก = SELL)
- เปลี่ยนเฉพาะ Z-Score entry logic (บรรทัด 5930-5998)

