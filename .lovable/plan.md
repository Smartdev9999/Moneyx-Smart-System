

## แผนแก้ไข v2.3.7: แก้ 3 ปัญหา - Rapid Open/Close + Total Floating Basket + Basket Reset

---

### ปัญหาที่ 1: EA เปิดปิดออเดอร์ซ้ำอย่างรวดเร็ว

**สาเหตุที่พบจากโค้ด:**

ผู้ใช้ตั้งค่า **Correlation Only** mode (ไม่ใช้ Z-Score) แต่ `CheckExitCondition()` (บรรทัด 9270-9312) ยังคงใช้ Z-Score exit logic:

```text
InpExitMode = EXIT_ZSCORE_OR_PROFIT (default)

CheckExitCondition() ทำ:
  BUY exit → zScore > -InpExitZScore (-0.5)
  SELL exit → zScore < InpExitZScore (0.5)

ปัญหา: ในโหมด Correlation Only:
  - Z-Score ยังถูกคำนวณและผันผวนรอบ 0
  - เงื่อนไข zScore > -0.5 = TRUE เกือบตลอดเวลา!
  - รวมกับ InpRequirePositiveProfit = true → ปิดทันทีที่มี profit เล็กน้อย
  - แล้วเปิดใหม่ทันที เพราะ correlation ยังเกิน threshold
  - วนลูปเปิด-ปิดไม่หยุด!
```

นอกจากนี้ `InpMinHoldingBars` ถูกกำหนดเป็น Input (บรรทัด 416) แต่**ไม่มีโค้ดใช้จริง**ใน `ManageAllPositions()`

**วิธีแก้ไข:**

**A. แก้ `CheckExitCondition()` ให้ skip Z-Score exit ใน Correlation Only mode:**
```cpp
bool CheckExitCondition(int pairIndex, string side, double zScore)
{
   // ...existing code...
   
   bool zScoreExit = false;
   
   // v2.3.7: Skip Z-Score exit in Correlation Only mode
   if(InpEntryMode != ENTRY_MODE_CORRELATION_ONLY)
   {
      if(side == "BUY")
         zScoreExit = (zScore > -InpExitZScore);
      else
         zScoreExit = (zScore < InpExitZScore);
      
      if(zScoreExit && InpRequirePositiveProfit && profit <= 0)
         zScoreExit = false;
   }
   
   // ...rest unchanged...
}
```

**B. Implement `InpMinHoldingBars` ใน `ManageAllPositions()`:**
```cpp
// v2.3.7: Check minimum holding time before exit
if(InpMinHoldingBars > 0 && g_pairs[i].entryTimeBuy > 0)
{
   int holdingSeconds = (int)(TimeCurrent() - g_pairs[i].entryTimeBuy);
   int minSeconds = InpMinHoldingBars * PeriodSeconds();
   if(holdingSeconds < minSeconds)
      continue;  // Skip exit check
}
```

**C. เพิ่ม Cooldown Period:**
```cpp
input group "=== Anti-Churn Protection (v2.3.7) ==="
input int      InpCooldownSeconds = 60;     // Cooldown after close (seconds, 0=Disable)
```

เพิ่ม `lastClosedTimeBuy` / `lastClosedTimeSell` ใน PairInfo struct และบันทึกเวลาใน `CloseBuySide()` / `CloseSellSide()` จากนั้นเช็คใน entry logic ก่อนเปิดออเดอร์ใหม่

---

### ปัญหาที่ 2: เพิ่ม Total Floating Profit บน Dashboard

**สูตร:** `Tot Float = Basket (Closed Profit) + Floating P/L`

เมื่อ Tot Float >= Total Target และ `InpEnableTotalFloatingClose = true` → ปิดทั้งหมด

**Layout Dashboard เดิม (ฝั่งขวาของ BOX1):**
```text
y+22: Current P/L: [value]
y+38: Total Target: [edit field]
```

**Layout ใหม่:**
```text
y+6:  Tot Float: [value]          ← ใหม่ (สีเขียว/แดง ตาม +/-)
y+22: Basket:    [value]          ← ย้ายขึ้น (เดิมชื่อ Current P/L)
y+38: Total Target: [edit field]  ← เหมือนเดิม
```

**Input Parameter ใหม่:**
```cpp
input bool     InpEnableTotalFloatingClose = false;   // v2.3.7: Enable Total Floating Close
```

**Logic ใน `CheckTotalTarget()`:**
```cpp
// v2.3.7: Check Total Floating Profit (Basket + Floating)
if(InpEnableTotalFloatingClose && InpTotalBasketTarget > 0)
{
   double totalFloatingProfit = g_accumulatedBasketProfit + g_basketClosedProfit + g_basketFloatingProfit;
   if(totalFloatingProfit >= InpTotalBasketTarget)
   {
      // Close ALL groups (same logic as existing Total Basket)
   }
}
```

---

### ปัญหาที่ 3: Total Basket ไม่ Reset เมื่อปิดออเดอร์ Manual

**สาเหตุ:** เมื่อปิดออเดอร์จากภายนอก (Manual close จาก MT5 Trade Tab):
1. `CloseBuySide()`/`CloseSellSide()` ไม่ถูกเรียก
2. `g_groups[g].closedProfit` และ `g_accumulatedBasketProfit` ไม่ถูก reset
3. ค่า Basket เก่ายังค้างอยู่
4. เมื่อเปิดออเดอร์ใหม่ → Basket เก่า + Floating ใหม่ อาจถึง Target → ปิดออเดอร์ใหม่ทิ้งทันที!

**วิธีแก้ไข:**

เพิ่มฟังก์ชัน `DetectExternalClosures()` เรียกใน `OnTick()` ก่อน `CheckOrphanPositions()`:

```cpp
void DetectExternalClosures()
{
   // นับ positions ที่ EA manage อยู่
   int totalActive = 0;
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(!g_pairs[i].enabled) continue;
      if(g_pairs[i].directionBuy == 1) totalActive++;
      if(g_pairs[i].directionSell == 1) totalActive++;
   }
   
   // ถ้า directionBuy/Sell == 1 แต่ position จริงไม่มี → reset pair
   for(int i = 0; i < MAX_PAIRS; i++)
   {
      if(!g_pairs[i].enabled) continue;
      
      if(g_pairs[i].directionBuy == 1)
      {
         bool aExists = (g_pairs[i].ticketBuyA == 0) || PositionSelectByTicket(g_pairs[i].ticketBuyA);
         bool bExists = (g_pairs[i].ticketBuyB == 0) || PositionSelectByTicket(g_pairs[i].ticketBuyB);
         if(!aExists && !bExists)
         {
            // ทั้ง A และ B หายไป → reset pair (ไม่สะสม profit เพราะไม่รู้ค่า)
            g_pairs[i].directionBuy = -1;
            g_pairs[i].ticketBuyA = 0;
            g_pairs[i].ticketBuyB = 0;
            g_pairs[i].profitBuy = 0;
            // ... reset other fields ...
         }
      }
      // Same for Sell side
   }
   
   // ถ้าไม่มี position ของ EA เหลืออยู่เลย → reset ALL baskets
   if(totalActive == 0 && (g_accumulatedBasketProfit != 0 || g_basketClosedProfit != 0))
   {
      // Verify by scanning real positions
      bool anyEAPosition = false;
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         if(PositionGetTicket(i) > 0 && PositionSelectByTicket(PositionGetTicket(i)))
         {
            if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            {
               anyEAPosition = true;
               break;
            }
         }
      }
      
      if(!anyEAPosition)
      {
         g_accumulatedBasketProfit = 0;
         for(int g = 0; g < MAX_GROUPS; g++)
            ResetGroupProfit(g);
         PrintFormat("[v2.3.7] No EA positions - ALL baskets reset");
      }
   }
}
```

---

### สรุปการแก้ไขทั้งหมด

| ลำดับ | ส่วน | การแก้ไข |
|------|------|---------|
| 1 | Version | อัปเดตเป็น 2.37 |
| 2 | PairInfo struct (~95) | เพิ่ม `lastClosedTimeBuy`, `lastClosedTimeSell` |
| 3 | Input Parameters (~706-728) | เพิ่ม `InpCooldownSeconds`, `InpEnableTotalFloatingClose` |
| 4 | `CheckExitCondition()` (~9270-9312) | Skip Z-Score exit ใน Correlation Only mode |
| 5 | `ManageAllPositions()` (~9196, ~9231) | Implement `InpMinHoldingBars` check |
| 6 | Entry Logic (~6708, ~6772) | เพิ่ม Cooldown check |
| 7 | `CloseBuySide()` / `CloseSellSide()` (~8625, ~8760) | บันทึก `lastClosedTime` |
| 8 | `CheckTotalTarget()` (~9617) | เพิ่ม Total Floating close logic |
| 9 | Dashboard Create (~10175) | เพิ่ม "Tot Float:" row + จัดเลย์เอาต์ |
| 10 | Dashboard Update (~10414) | แสดง Total Floating Profit |
| 11 | `OnTick()` (~3154) | เรียก `DetectExternalClosures()` |
| 12 | New Function | `DetectExternalClosures()` |

---

### ผลลัพธ์ที่คาดหวัง

**ปัญหา 1:** ในโหมด Correlation Only จะไม่มี Z-Score exit trigger อีก ออเดอร์จะปิดเมื่อถึง Profit Target หรือ Basket Target เท่านั้น + Cooldown ป้องกันเปิดซ้ำทันที

**ปัญหา 2:** Dashboard แสดง "Tot Float" = Basket + Floating เมื่อเปิด InpEnableTotalFloatingClose และถึง Target → ปิดทั้งหมด

**ปัญหา 3:** เมื่อปิดออเดอร์ Manual ทั้งหมด → Basket auto-reset เป็น 0 เริ่มรอบใหม่สะอาด

---

### ไฟล์ที่แก้ไข

`public/docs/mql5/Harmony_Dream_EA.mq5` เท่านั้น

