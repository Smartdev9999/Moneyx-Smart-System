
## แผนแก้ไข v2.3.5: ป้องกัน Orphan Position ตั้งแต่เปิดออเดอร์ + Log Throttling

---

### สาเหตุหลักที่พบ

จากการวิเคราะห์โค้ดใน `OpenSellSideTrade()` และ `OpenBuySideTrade()`:

**ปัญหาที่ 1: ไม่มีการตรวจสอบ ticketA ก่อนเปิด Order B**

```cpp
// บรรทัด 8388-8430 (OpenSellSideTrade)
if(g_trade.Sell(lotA, symbolA, bidA, 0, 0, comment))
{
   ticketA = g_trade.ResultOrder();  // อาจได้ 0!
   
   if(ticketA == 0)
   {
      ticketA = FindPositionTicketBySymbolAndComment(symbolA, comment);
      // ถ้ายังได้ 0 ก็ไม่ได้ทำอะไร!
   }
}

Sleep(50);

// โค้ดข้างล่างนี้จะทำงานต่อ แม้ว่า ticketA = 0!
if(g_trade.Buy(lotB, symbolB, askB, 0, 0, comment))
{
   ticketB = g_trade.ResultOrder();  // ได้ ticket จริง
   ...
}
```

**สิ่งที่เกิดขึ้น:**
1. `g_trade.Sell()` return **TRUE** (บอกว่าส่งคำสั่งสำเร็จ)
2. แต่ `g_trade.ResultOrder()` return **0** (ไม่ได้ ticket กลับมา)
3. Fallback scan หาไม่เจอ (เพราะ position อาจไม่ได้เปิดจริง หรือ comment ไม่ตรง)
4. **ไม่มี Guard**: โค้ดยังเปิด Order B ต่อไป
5. ผลลัพธ์: `ticketSellA = 0`, `ticketSellB = 564170288` → **Orphan ตั้งแต่เริ่มต้น**

**ปัญหาที่ 2: Log Spam จาก UpdatePairProfits()**
- Log warning แสดงทุก Tick ไม่มี Throttling

---

### โซลูชัน

#### Part A: เพิ่ม Guard ตรวจสอบ ticketA ก่อนเปิด Order B

**แก้ไขใน OpenSellSideTrade() (บรรทัด 8388-8410):**

```cpp
// Open Sell on Symbol A
double bidA = SymbolInfoDouble(symbolA, SYMBOL_BID);
if(g_trade.Sell(lotA, symbolA, bidA, 0, 0, comment))
{
   ticketA = g_trade.ResultOrder();
   
   // v1.3: Validate ticket was recorded - fallback scan if failed
   if(ticketA == 0)
   {
      Sleep(100);  // v2.3.5: Wait longer for server response
      ticketA = FindPositionTicketBySymbolAndComment(symbolA, comment);
      PrintFormat("[v1.3 FALLBACK] SELL SymbolA ticket scan: found=%d", ticketA);
   }
   
   // v2.3.5: CRITICAL - If still no ticket, abort completely
   if(ticketA == 0)
   {
      PrintFormat("[v2.3.5 ABORT] SELL on %s: Order sent but no ticket received! Aborting pair entry.", symbolA);
      return false;
   }
}
else
{
   PrintFormat("Failed to open SELL on %s: %d", symbolA, GetLastError());
   return false;
}
```

**เหตุผล:**
- ป้องกัน Orphan Position ตั้งแต่ต้น
- ถ้า Order A ไม่ได้ ticket → ไม่เปิด Order B → ไม่มี Orphan

---

#### Part B: เพิ่ม Sleep เพื่อรอ Server Response

บาง Broker อาจใช้เวลา process order ช้า โดยเฉพาะช่วงตลาดเปิด

**แก้ไข:**
```cpp
// เพิ่ม Sleep หลัง Sell/Buy ก่อน ResultOrder()
if(g_trade.Sell(lotA, symbolA, bidA, 0, 0, comment))
{
   Sleep(50);  // v2.3.5: Wait for server to process
   ticketA = g_trade.ResultOrder();
   ...
}
```

---

#### Part C: เพิ่ม Log Throttling สำหรับ Missing Ticket Warning

**เพิ่ม Global Variables:**
```cpp
// v2.3.5: Recovery Log Throttling
datetime g_lastRecoveryLogTime[MAX_PAIRS];
string   g_lastRecoveryLogSide[MAX_PAIRS];
```

**แก้ไขใน UpdatePairProfits():**
```cpp
// v2.3.5: Throttle recovery logs (once per 30 seconds per pair/side)
if(g_pairs[i].ticketSellA == 0 || g_pairs[i].ticketSellB == 0)
{
   datetime now = TimeCurrent();
   bool shouldLog = (now - g_lastRecoveryLogTime[i] >= 30) || 
                    (g_lastRecoveryLogSide[i] != "SELL");
   
   if(shouldLog)
   {
      PrintFormat("[v2.3.5 WARN] Pair %d SELL: Missing ticket! A=%d B=%d", 
                  i + 1, g_pairs[i].ticketSellA, g_pairs[i].ticketSellB);
      g_lastRecoveryLogTime[i] = now;
      g_lastRecoveryLogSide[i] = "SELL";
   }
   
   RecoverMissingTickets(i, "SELL", sellComment);
}
```

---

#### Part D: เพิ่ม Orphan Status ใน Dashboard

**แก้ไขใน UpdatePairRow():**
```cpp
// v2.3.5: Show Orphan status in Type column
string typeStr = "Pos";
color typeColor = clrWhite;

if(g_pairs[pairIndex].directionSell == 1)
{
   if(g_pairs[pairIndex].ticketSellA == 0 && g_pairs[pairIndex].ticketSellB != 0)
   {
      typeStr = "ORPH-A";
      typeColor = clrMagenta;
   }
   else if(g_pairs[pairIndex].ticketSellA != 0 && g_pairs[pairIndex].ticketSellB == 0)
   {
      typeStr = "ORPH-B";
      typeColor = clrMagenta;
   }
}
// Same for BUY direction...
```

---

### สรุปการแก้ไขทั้งหมด

| ลำดับ | ส่วน | การแก้ไข |
|------|------|---------|
| 1 | Version | อัปเดตเป็น 2.35 |
| 2 | `OpenBuySideTrade()` | เพิ่ม Guard: ถ้า ticketA = 0 หลัง fallback → return false |
| 3 | `OpenSellSideTrade()` | เพิ่ม Guard: ถ้า ticketA = 0 หลัง fallback → return false |
| 4 | Global Variables | เพิ่ม `g_lastRecoveryLogTime[]`, `g_lastRecoveryLogSide[]` |
| 5 | `UpdatePairProfits()` | เพิ่ม Log Throttling (30 วินาที) |
| 6 | `UpdatePairRow()` | แสดง "ORPH-A" หรือ "ORPH-B" ใน Type column |
| 7 | `OnInit()` | Initialize arrays |

---

### ผลลัพธ์ที่คาดหวัง

**ก่อนแก้ไข:**
- Order A ไม่ได้ ticket แต่ Order B เปิดสำเร็จ → Orphan
- Log "Missing ticket" วิ่งทุก Tick

**หลังแก้ไข:**
- ถ้า Order A ไม่ได้ ticket → ไม่เปิด Order B → **ไม่มี Orphan**
- Log แสดง: `[v2.3.5 ABORT] SELL on EURCHF.v: Order sent but no ticket received!`
- Log warning แสดงทุก 30 วินาทีแทนทุก Tick

---

### บรรทัดที่แก้ไขหลัก

| บรรทัด | ไฟล์ | การแก้ไข |
|--------|------|---------|
| ~790 | Harmony_Dream_EA.mq5 | เพิ่ม Global Variables |
| ~1530 | Harmony_Dream_EA.mq5 | Initialize arrays ใน OnInit() |
| 8195-8206 | Harmony_Dream_EA.mq5 | Guard สำหรับ ticketA ใน OpenBuySideTrade() |
| 8394-8405 | Harmony_Dream_EA.mq5 | Guard สำหรับ ticketA ใน OpenSellSideTrade() |
| 9307-9330 | Harmony_Dream_EA.mq5 | Log Throttling ใน UpdatePairProfits() |
| 10100-10120 | Harmony_Dream_EA.mq5 | Orphan indicator ใน UpdatePairRow() |

---

### ไฟล์ที่แก้ไข

`public/docs/mql5/Harmony_Dream_EA.mq5` เท่านั้น
