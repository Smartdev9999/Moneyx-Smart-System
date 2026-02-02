

## แผนแก้ไขรวม v2.1.9: Fix Debug Log Spam + Dashboard Order Count

---

### สรุปปัญหาที่พบ

| ปัญหา | รายละเอียด |
|-------|------------|
| **1. Log Spam** | Debug log "[CORR ONLY] Pair X: BUY/SELL BLOCKED" แสดงซ้ำทุก tick |
| **2. Order Count ผิด** | Dashboard แสดง Ord=2 แต่จริงๆมีแค่ 1 order (นับซ้ำเมื่อ restore 2 symbols) |

---

### การแก้ไขที่จะทำ

#### Part A: เพิ่ม Fields ใน PairInfo Structure

**ตำแหน่ง:** หลังบรรทัด 166 (ใน struct PairInfo)

```cpp
// === v2.1.9: Debug Log Throttling ===
string         lastBlockReason;      // Last block reason logged
datetime       lastBlockLogTime;     // Last time block was logged
```

---

#### Part B: เพิ่ม Global Variables สำหรับ Log Control

**ตำแหน่ง:** หลังบรรทัด 893

```cpp
// === v2.1.9: Debug Log Control ===
bool   g_firstAnalyzeRun = true;              // First run after init/TF change
int    DEBUG_LOG_INTERVAL = 30;               // Log same reason every 30 seconds
```

---

#### Part C: Reset Flag ใน OnInit()

**ตำแหน่ง:** หลัง `RestoreOpenPositions()` (ประมาณบรรทัด 1306)

```cpp
// v2.1.9: Reset first-run flag for debug logs
g_firstAnalyzeRun = true;
```

---

#### Part D: แก้ไข AnalyzeAllPairs() - Log Throttling

**ตำแหน่ง:** บรรทัด 5742-5823 และ 5841-5846

**1. Correlation not in range (บรรทัด 5742-5748):**
```cpp
if(debugLog)
{
   string reason = StringFormat("SKIP - Corr %.0f%% not in range", g_pairs[i].correlation * 100);
   datetime now = TimeCurrent();
   if(g_firstAnalyzeRun || reason != g_pairs[i].lastBlockReason || 
      now - g_pairs[i].lastBlockLogTime >= DEBUG_LOG_INTERVAL)
   {
      PrintFormat("[CORR ONLY] Pair %d %s/%s: %s", i + 1, ...);
      g_pairs[i].lastBlockReason = reason;
      g_pairs[i].lastBlockLogTime = now;
   }
}
```

**2. Direction empty (บรรทัด 5772-5773)** → เพิ่ม throttling

**3. Grid Guard (บรรทัด 5784-5786)** → เพิ่ม throttling

**4. RSI Block (บรรทัด 5794-5797)** → เพิ่ม throttling

**5. BUY BLOCKED (บรรทัด 5818-5823):**
```cpp
else if(debugLog)
{
   string reason = StringFormat("BUY BLOCKED (directionBuy=%d, orderCount=%d/%d)",
                                g_pairs[i].directionBuy, g_pairs[i].orderCountBuy, g_pairs[i].maxOrderBuy);
   datetime now = TimeCurrent();
   if(g_firstAnalyzeRun || reason != g_pairs[i].lastBlockReason || 
      now - g_pairs[i].lastBlockLogTime >= DEBUG_LOG_INTERVAL)
   {
      PrintFormat("[CORR ONLY] Pair %d %s/%s: %s", i + 1, ...);
      g_pairs[i].lastBlockReason = reason;
      g_pairs[i].lastBlockLogTime = now;
   }
}
```

**6. SELL BLOCKED (บรรทัด 5841-5846)** → เหมือนกัน

---

#### Part E: Reset First-Run Flag หลัง Loop

**ตำแหน่ง:** ก่อนปิด AnalyzeAllPairs() (ก่อน loop จบ หรือท้ายฟังก์ชัน)

```cpp
// v2.1.9: Clear first-run flag after initial analysis
if(g_firstAnalyzeRun)
   g_firstAnalyzeRun = false;
```

---

#### Part F: แก้ไข RestoreOpenPositions() - ป้องกันนับซ้ำ

**ปัญหา:** Main order ถูกนับ 2 ครั้งเมื่อ restore ทั้ง Symbol A และ B

**ตำแหน่ง:** ต้นฟังก์ชัน RestoreOpenPositions() (บรรทัด ~1580)

```cpp
void RestoreOpenPositions()
{
   int restoredBuy = 0;
   int restoredSell = 0;
   
   // v2.1.9: Track which pairs have counted main orders
   bool mainBuyCounted[MAX_PAIRS];
   bool mainSellCounted[MAX_PAIRS];
   ArrayInitialize(mainBuyCounted, false);
   ArrayInitialize(mainSellCounted, false);
   
   Print("[v2.1.9] Scanning for existing positions with Magic Number: ", InpMagicNumber);
```

**แก้ไขบรรทัด 1712-1716 (BUY side):**
```cpp
else if(shouldCount && !mainBuyCounted[i])
{
   // v2.1.9: Count main order only once per pair
   mainBuyCounted[i] = true;
   g_pairs[i].orderCountBuy++;
}
```

**แก้ไข SELL side เช่นกัน (ประมาณบรรทัด 1756-1760):**
```cpp
else if(shouldCountSell && !mainSellCounted[i])
{
   mainSellCounted[i] = true;
   g_pairs[i].orderCountSell++;
}
```

---

### สรุปไฟล์และบรรทัดที่แก้ไข

| ไฟล์ | ส่วนที่แก้ไข | บรรทัด | รายละเอียด |
|------|-------------|--------|------------|
| `Harmony_Dream_EA.mq5` | Version | 7-10 | อัปเดตเป็น v2.19 |
| `Harmony_Dream_EA.mq5` | `PairInfo` struct | ~168 | เพิ่ม `lastBlockReason`, `lastBlockLogTime` |
| `Harmony_Dream_EA.mq5` | Global Variables | ~894 | เพิ่ม `g_firstAnalyzeRun`, `DEBUG_LOG_INTERVAL` |
| `Harmony_Dream_EA.mq5` | `OnInit()` | ~1307 | Reset `g_firstAnalyzeRun = true` |
| `Harmony_Dream_EA.mq5` | `RestoreOpenPositions()` | 1580-1760 | เพิ่ม `mainBuyCounted[]`, `mainSellCounted[]` |
| `Harmony_Dream_EA.mq5` | `AnalyzeAllPairs()` | 5742-5850 | เพิ่ม throttling ให้ทุก debug log |

---

### Flow หลังแก้ไข

```text
เปลี่ยน Timeframe / Restart EA:
┌─────────────────────────────────────────────────────────────────┐
│ OnInit()                                                        │
│   → g_firstAnalyzeRun = true                                    │
│   → RestoreOpenPositions()                                      │
│       → Pair 1: EURJPY restored → mainBuyCounted[0] = true, +1  │
│       → Pair 1: CADJPY restored → mainBuyCounted[0] = true      │
│         → SKIP! ไม่นับซ้ำ                                        │
│       → ผลลัพธ์: orderCountBuy = 1 (ถูกต้อง)                     │
├─────────────────────────────────────────────────────────────────┤
│ First Tick → AnalyzeAllPairs()                                  │
│   → Pair 1: BUY BLOCKED → g_firstAnalyzeRun = true → LOG!       │
│   → Pair 2: BUY BLOCKED → g_firstAnalyzeRun = true → LOG!       │
│   → ... (all pairs logged once)                                 │
│   → g_firstAnalyzeRun = false                                   │
├─────────────────────────────────────────────────────────────────┤
│ Next Tick → AnalyzeAllPairs()                                   │
│   → Pair 1: BUY BLOCKED                                         │
│     → g_firstAnalyzeRun = false                                 │
│     → reason = same as before                                   │
│     → time diff < 30 sec                                        │
│     → SKIP LOG!                                                 │
├─────────────────────────────────────────────────────────────────┤
│ After 30 seconds...                                             │
│   → Pair 1: BUY BLOCKED                                         │
│     → time diff >= 30 sec                                       │
│     → LOG! (periodic reminder)                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

### ผลลัพธ์ที่คาดหวัง

| สถานการณ์ | ก่อนแก้ไข | หลังแก้ไข v2.1.9 |
|-----------|----------|------------------|
| Debug Log | แสดงทุก tick | แสดงครั้งแรก + ทุก 30 วิ |
| Order Count | Ord=2 (ผิด) | Ord=1 (ถูก) |
| Restart EA | Log spam + count ผิด | Log สะอาด + count ถูก |

---

### Version Update

```cpp
#property version   "2.19"
#property description "v2.1.9: Fix Debug Log Spam + Dashboard Order Count"
```

