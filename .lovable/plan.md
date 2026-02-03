
## แผนดำเนินการ: Fix Grid Log Throttling (v2.2.1)

---

### สรุปสิ่งที่ต้องแก้ไข

| ปัญหา | ตำแหน่ง | สาเหตุ |
|-------|---------|--------|
| **CDC BLOCK log spam** | `CheckGridTradingAllowed()` (บรรทัด 5522-5592) | Log ทุก tick ไม่มี debouncing |
| **CDC BLOCK log spam** | `CheckGridTradingAllowedCorrOnly()` (บรรทัด 5698-5733) | Log ทุก tick ไม่มี debouncing |

---

### การแก้ไข

#### Part A: อัปเดต Version

**ไฟล์:** `public/docs/mql5/Harmony_Dream_EA.mq5`
**บรรทัด:** 7, 10

```cpp
#property version   "2.21"
#property description "v2.2.1: Fix Grid Guard Log Spam - Add Debounced Logging"
```

---

#### Part B: เพิ่ม Global Variables สำหรับ Grid Pause Tracking

**ไฟล์:** `public/docs/mql5/Harmony_Dream_EA.mq5`
**ตำแหน่ง:** หลังบรรทัด 901 (หลัง DEBUG_LOG_INTERVAL)

เพิ่ม:
```cpp
// v2.2.1: Grid Pause Reason Tracking (separate from Main Entry tracking)
string g_lastGridPauseReason[MAX_PAIRS][2];    // [pairIndex][0=BUY, 1=SELL]
datetime g_lastGridPauseLogTime[MAX_PAIRS][2]; // Last time grid pause was logged
```

---

#### Part C: แก้ไข `CheckGridTradingAllowed()` (Z-Score Mode)

**ไฟล์:** `public/docs/mql5/Harmony_Dream_EA.mq5`
**บรรทัด:** 5522-5592

**เปลี่ยนจาก:** Log ทุก tick เมื่อ block
**เป็น:** Log เฉพาะเมื่อ reason เปลี่ยน หรือทุก 30 วินาที

```cpp
bool CheckGridTradingAllowed(int pairIndex, string side, string &pauseReason)
{
   pauseReason = "";
   int sideIdx = (side == "BUY") ? 0 : 1;
   bool debugLog = InpDebugMode && (!g_isTesterMode || !InpDisableDebugInTester);
   datetime now = TimeCurrent();
   
   // === เงื่อนไข 1: Correlation Check ===
   double absCorr = MathAbs(g_pairs[pairIndex].correlation);
   if(absCorr < InpGridMinCorrelation)
   {
      pauseReason = StringFormat("Corr %.0f%% < %.0f%%", 
                                 absCorr * 100, InpGridMinCorrelation * 100);
   }
   
   // === เงื่อนไข 2: Z-Score Direction-Aware Check ===
   if(pauseReason == "")
   {
      double zScore = g_pairs[pairIndex].zScore;
      if(side == "BUY" && zScore > -InpGridMinZScore)
         pauseReason = StringFormat("Z=%.2f > -%.2f (BUY)", zScore, InpGridMinZScore);
      else if(side == "SELL" && zScore < InpGridMinZScore)
         pauseReason = StringFormat("Z=%.2f < +%.2f (SELL)", zScore, InpGridMinZScore);
   }
   
   // === เงื่อนไข 3: CDC Trend Block ===
   if(pauseReason == "" && InpUseCDCTrendFilter)
   {
      if(!CheckCDCTrendConfirmation(pairIndex, side))
         pauseReason = "CDC BLOCK";
   }
   
   // === v2.2.1: Debounced Logging ===
   if(pauseReason != "")
   {
      // Log only if reason is NEW/DIFFERENT or 30 seconds passed
      if(debugLog && (g_firstAnalyzeRun || 
         pauseReason != g_lastGridPauseReason[pairIndex][sideIdx] ||
         now - g_lastGridPauseLogTime[pairIndex][sideIdx] >= DEBUG_LOG_INTERVAL))
      {
         PrintFormat("GRID PAUSE [Pair %d %s/%s %s]: %s", pairIndex + 1, 
                     g_pairs[pairIndex].symbolA, g_pairs[pairIndex].symbolB, side, pauseReason);
         g_lastGridPauseReason[pairIndex][sideIdx] = pauseReason;
         g_lastGridPauseLogTime[pairIndex][sideIdx] = now;
      }
      return false;
   }
   else
   {
      // Grid allowed - log RESUME only if previously paused
      if(debugLog && g_lastGridPauseReason[pairIndex][sideIdx] != "")
      {
         PrintFormat("GRID RESUME [Pair %d %s/%s %s]: All conditions met", pairIndex + 1,
                     g_pairs[pairIndex].symbolA, g_pairs[pairIndex].symbolB, side);
         g_lastGridPauseReason[pairIndex][sideIdx] = "";
      }
      return true;
   }
}
```

---

#### Part D: แก้ไข `CheckGridTradingAllowedCorrOnly()` (Correlation Only Mode)

**ไฟล์:** `public/docs/mql5/Harmony_Dream_EA.mq5`
**บรรทัด:** 5698-5733

**เหมือน Part C แต่สำหรับ Correlation Only Mode:**

```cpp
bool CheckGridTradingAllowedCorrOnly(int pairIndex, string side, string &pauseReason)
{
   pauseReason = "";
   int sideIdx = (side == "BUY") ? 0 : 1;
   bool debugLog = InpDebugMode && (!g_isTesterMode || !InpDisableDebugInTester);
   datetime now = TimeCurrent();
   
   // === เงื่อนไข 1: Correlation Check ===
   double absCorr = MathAbs(g_pairs[pairIndex].correlation);
   if(absCorr < InpGridMinCorrelation)
   {
      pauseReason = StringFormat("Corr %.0f%% < %.0f%%", 
                                 absCorr * 100, InpGridMinCorrelation * 100);
   }
   
   // === เงื่อนไข 2: CDC Trend Block ===
   if(pauseReason == "" && InpUseCDCTrendFilter)
   {
      if(!CheckCDCTrendConfirmation(pairIndex, side))
         pauseReason = "CDC BLOCK";
   }
   
   // === v2.2.1: Debounced Logging ===
   if(pauseReason != "")
   {
      if(debugLog && (g_firstAnalyzeRun || 
         pauseReason != g_lastGridPauseReason[pairIndex][sideIdx] ||
         now - g_lastGridPauseLogTime[pairIndex][sideIdx] >= DEBUG_LOG_INTERVAL))
      {
         PrintFormat("GRID PAUSE [CORR ONLY] [Pair %d %s/%s %s]: %s", pairIndex + 1, 
                     g_pairs[pairIndex].symbolA, g_pairs[pairIndex].symbolB, side, pauseReason);
         g_lastGridPauseReason[pairIndex][sideIdx] = pauseReason;
         g_lastGridPauseLogTime[pairIndex][sideIdx] = now;
      }
      return false;
   }
   else
   {
      if(debugLog && g_lastGridPauseReason[pairIndex][sideIdx] != "")
      {
         PrintFormat("GRID RESUME [CORR ONLY] [Pair %d %s/%s %s]: All conditions met", pairIndex + 1,
                     g_pairs[pairIndex].symbolA, g_pairs[pairIndex].symbolB, side);
         g_lastGridPauseReason[pairIndex][sideIdx] = "";
      }
      return true;
   }
}
```

---

### สรุปไฟล์ที่แก้ไข

| ไฟล์ | ส่วนที่แก้ไข | บรรทัด | รายละเอียด |
|------|-------------|--------|------------|
| `Harmony_Dream_EA.mq5` | Version | 7, 10 | อัปเดตเป็น v2.21 |
| `Harmony_Dream_EA.mq5` | Global Variables | หลัง 901 | เพิ่ม `g_lastGridPauseReason[][]` และ `g_lastGridPauseLogTime[][]` |
| `Harmony_Dream_EA.mq5` | `CheckGridTradingAllowed()` | 5522-5592 | เพิ่ม debounced logging |
| `Harmony_Dream_EA.mq5` | `CheckGridTradingAllowedCorrOnly()` | 5698-5733 | เพิ่ม debounced logging |

---

### ผลลัพธ์ที่คาดหวัง

| สถานการณ์ | ก่อนแก้ไข | หลังแก้ไข v2.2.1 |
|-----------|----------|------------------|
| CDC BLOCK log | แสดง **ทุก tick** (spam) | แสดงครั้งแรก + ทุก **30 วินาที** |
| Correlation block log | แสดง **ทุก tick** | แสดงครั้งแรก + ทุก **30 วินาที** |
| Z-Score block log | แสดง **ทุก tick** | แสดงครั้งแรก + ทุก **30 วินาที** |
| Grid Resume | ไม่มี log | แสดง **GRID RESUME** เมื่อกลับมาทำงาน |
| Journal Clarity | ไม่รู้ว่า Grid ถูก block ตรงไหน | เห็นชัดว่าทำไม Grid หยุด + เมื่อกลับมา |

---

### Technical Notes

- ใช้ global arrays `g_lastGridPauseReason[MAX_PAIRS][2]` และ `g_lastGridPauseLogTime[MAX_PAIRS][2]` แยกจาก `lastBlockReason` ใน PairInfo (ที่ใช้สำหรับ Main Entry)
- `sideIdx = 0` สำหรับ BUY, `sideIdx = 1` สำหรับ SELL
- Log throttling ใช้ `DEBUG_LOG_INTERVAL = 30` วินาที (เหมือน Main Entry)
- เพิ่ม "GRID RESUME" log เมื่อเงื่อนไขกลับมาผ่าน (เพื่อให้รู้ว่า Grid พร้อมทำงานแล้ว)
