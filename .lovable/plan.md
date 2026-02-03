
## แผนดำเนินการ: Grid Trend Guard v2.2.2

---

### สรุปสิ่งที่ต้องเพิ่ม

| ฟีเจอร์ใหม่ | รายละเอียด |
|------------|-----------|
| **Grid Trend Guard** | Block Grid ในฝั่งที่สวนกับ CDC Trend Direction |
| **Enable/Disable Toggle** | สามารถเปิด-ปิดฟีเจอร์นี้ได้ |
| **Positive Correlation Only** | ใช้กับ Positive Correlation เท่านั้น (ตามที่ต้องการ) |

---

### Logic ที่ต้องการ

```text
Positive Correlation + CDC Trend Filter:
┌────────────────────────────────────────────────────────────┐
│ Trend A = BULLISH, Trend B = BULLISH (Both UP)             │
│ ─────────────────────────────────────────────────────────  │
│   BUY Grid  → ✓ ALLOWED (ตามเทรน)                          │
│   SELL Grid → ✗ BLOCKED (สวนเทรน) ← Grid Trend Guard!      │
├────────────────────────────────────────────────────────────┤
│ Trend A = BEARISH, Trend B = BEARISH (Both DOWN)           │
│ ─────────────────────────────────────────────────────────  │
│   BUY Grid  → ✗ BLOCKED (สวนเทรน) ← Grid Trend Guard!      │
│   SELL Grid → ✓ ALLOWED (ตามเทรน)                          │
└────────────────────────────────────────────────────────────┘
```

---

### การแก้ไข

#### Part A: อัปเดต Version

**ไฟล์:** `public/docs/mql5/Harmony_Dream_EA.mq5`
**บรรทัด:** 7, 10

```cpp
#property version   "2.22"
#property description "v2.2.2: Add Grid Trend Guard - Block Grid Counter-Trend"
```

---

#### Part B: เพิ่ม Input Parameter

**ไฟล์:** `public/docs/mql5/Harmony_Dream_EA.mq5`
**ตำแหน่ง:** ใน group "=== Grid Trading Guard (v3.5.1) ===" (บรรทัด 396-399)

เพิ่ม Input ใหม่:
```cpp
input group "=== Grid Trading Guard (v3.5.1) ==="
input double   InpGridMinCorrelation = 0.60;      // Grid: Minimum Correlation (ต่ำกว่านี้หยุด Grid)
input double   InpGridMinZScore = 0.5;            // Grid: Minimum |Z-Score| (ต่ำกว่านี้หยุด Grid)
input bool     InpGridPauseAffectsMain = true;    // Apply to Main Entry Too (เกณฑ์นี้ใช้กับ Order แรกด้วย)
input bool     InpGridTrendGuard = true;          // Grid Trend Guard (Block Grid ที่สวนเทรน - Positive Corr Only)
```

---

#### Part C: สร้างฟังก์ชันใหม่ `CheckGridTrendDirection()`

**ไฟล์:** `public/docs/mql5/Harmony_Dream_EA.mq5`
**ตำแหน่ง:** หลัง `CheckCDCTrendConfirmation()` (ประมาณบรรทัด 5295)

```cpp
//+------------------------------------------------------------------+
//| Check Grid Trend Direction Guard (v2.2.2)                          |
//| Logic:                                                             |
//|   - For Positive Correlation: Block Grid that goes AGAINST trend   |
//|   - BUY Grid blocked when trend = BEARISH (Down)                   |
//|   - SELL Grid blocked when trend = BULLISH (Up)                    |
//|   - Returns TRUE if Grid is allowed                                |
//|   - Returns FALSE if Grid should be blocked (counter-trend)        |
//+------------------------------------------------------------------+
bool CheckGridTrendDirection(int pairIndex, string side)
{
   // If Grid Trend Guard is disabled, always allow
   if(!InpGridTrendGuard) return true;
   
   // Only apply to Positive Correlation
   int corrType = g_pairs[pairIndex].correlationType;
   if(corrType != 1) return true;  // Skip for Negative Correlation
   
   // If CDC Filter is disabled, skip this check
   if(!InpUseCDCTrendFilter) return true;
   
   // Check if CDC data is ready
   if(!g_pairs[pairIndex].cdcReadyA || !g_pairs[pairIndex].cdcReadyB)
      return true;  // Allow during loading (don't block prematurely)
   
   string trendA = g_pairs[pairIndex].cdcTrendA;
   string trendB = g_pairs[pairIndex].cdcTrendB;
   
   // If either trend is NEUTRAL, allow (can't determine direction)
   if(trendA == "NEUTRAL" || trendB == "NEUTRAL")
      return true;
   
   // For Positive Correlation: Both symbols should have SAME trend
   // Determine the dominant trend direction
   // If both are BULLISH → UP trend
   // If both are BEARISH → DOWN trend
   // If mismatch → CheckCDCTrendConfirmation already blocks, so allow here
   
   if(trendA != trendB)
      return true;  // Mismatch handled by CheckCDCTrendConfirmation
   
   // trendA == trendB at this point
   bool isBullish = (trendA == "BULLISH");
   bool isBearish = (trendA == "BEARISH");
   
   // Grid Trend Guard Logic:
   // BUY Grid → Block when BEARISH (Down trend)
   // SELL Grid → Block when BULLISH (Up trend)
   if(side == "BUY" && isBearish)
      return false;  // BUY Grid blocked in DOWN trend
   
   if(side == "SELL" && isBullish)
      return false;  // SELL Grid blocked in UP trend
   
   return true;  // Grid allowed
}
```

---

#### Part D: เพิ่มการเรียก `CheckGridTrendDirection()` ใน `CheckGridTradingAllowed()`

**ไฟล์:** `public/docs/mql5/Harmony_Dream_EA.mq5`
**ตำแหน่ง:** ใน `CheckGridTradingAllowed()` หลัง CDC Block check (บรรทัด 5553-5558)

เพิ่มเงื่อนไขที่ 4:
```cpp
   // === เงื่อนไข 3: CDC Trend Block (v3.5.2) ===
   if(pauseReason == "" && InpUseCDCTrendFilter)
   {
      if(!CheckCDCTrendConfirmation(pairIndex, side))
         pauseReason = "CDC BLOCK";
   }
   
   // === v2.2.2: Grid Trend Guard (Block Counter-Trend Grid) ===
   if(pauseReason == "" && !CheckGridTrendDirection(pairIndex, side))
   {
      pauseReason = "TREND GUARD";
   }
```

---

#### Part E: เพิ่มการเรียก `CheckGridTrendDirection()` ใน `CheckGridTradingAllowedCorrOnly()`

**ไฟล์:** `public/docs/mql5/Harmony_Dream_EA.mq5`
**ตำแหน่ง:** ใน `CheckGridTradingAllowedCorrOnly()` หลัง CDC Block check (บรรทัด 5707-5712)

เพิ่มเงื่อนไขเดียวกัน:
```cpp
   // === เงื่อนไข 2: CDC Trend Block (v3.5.2) ===
   if(pauseReason == "" && InpUseCDCTrendFilter)
   {
      if(!CheckCDCTrendConfirmation(pairIndex, side))
         pauseReason = "CDC BLOCK";
   }
   
   // === v2.2.2: Grid Trend Guard (Block Counter-Trend Grid) ===
   if(pauseReason == "" && !CheckGridTrendDirection(pairIndex, side))
   {
      pauseReason = "TREND GUARD";
   }
```

---

### สรุปไฟล์ที่แก้ไข

| ไฟล์ | ส่วนที่แก้ไข | บรรทัด | รายละเอียด |
|------|-------------|--------|------------|
| `Harmony_Dream_EA.mq5` | Version | 7, 10 | อัปเดตเป็น v2.22 |
| `Harmony_Dream_EA.mq5` | Input Parameters | ~399 | เพิ่ม `InpGridTrendGuard` |
| `Harmony_Dream_EA.mq5` | ฟังก์ชันใหม่ | หลัง 5295 | เพิ่ม `CheckGridTrendDirection()` |
| `Harmony_Dream_EA.mq5` | `CheckGridTradingAllowed()` | ~5558 | เพิ่มการเรียก `CheckGridTrendDirection()` |
| `Harmony_Dream_EA.mq5` | `CheckGridTradingAllowedCorrOnly()` | ~5712 | เพิ่มการเรียก `CheckGridTrendDirection()` |

---

### ผลลัพธ์ที่คาดหวัง

| สถานการณ์ | Trend | Grid BUY | Grid SELL |
|-----------|-------|----------|-----------|
| Positive Corr, Both UP | BULLISH | ✅ ALLOWED | ❌ TREND GUARD |
| Positive Corr, Both DOWN | BEARISH | ❌ TREND GUARD | ✅ ALLOWED |
| Positive Corr, Mismatch | - | ❌ CDC BLOCK | ❌ CDC BLOCK |
| Negative Corr | - | ✅ (ไม่มีผล) | ✅ (ไม่มีผล) |
| InpGridTrendGuard = false | - | ✅ (ปิดฟีเจอร์) | ✅ (ปิดฟีเจอร์) |

---

### Log Output ที่จะเห็น

```text
GRID PAUSE [CORR ONLY] [Pair 7 EURUSD/GBPUSD SELL]: TREND GUARD
   → เมื่อ Pair 7 เป็นเทรนขาขึ้น SELL Grid จะหยุด

GRID RESUME [CORR ONLY] [Pair 7 EURUSD/GBPUSD SELL]: All conditions met
   → เมื่อเทรนกลับเป็นขาลง SELL Grid กลับมาทำงาน
```

---

### Technical Notes

- ฟีเจอร์นี้ทำงานเฉพาะ **Positive Correlation** (ตามที่ต้องการ)
- สามารถเปิด-ปิดได้ผ่าน `InpGridTrendGuard`
- ไม่กระทบกับ Main Entry หรือกลยุทธ์อื่น
- ใช้ระบบ log throttling จาก v2.2.1 (แสดงเฉพาะเมื่อ reason เปลี่ยน)
- ทำงานร่วมกับทั้ง Z-Score mode และ Correlation Only mode
