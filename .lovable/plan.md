

## แผนปรับปรุง Harmony Dream EA v1.8.7

### เป้าหมาย (อัพเดทจาก Plan เดิม + Bug Fix ใหม่):

1. **แก้ไข Light Mode Text Bug** - ข้อความด้านล่าง Dashboard มองไม่เห็น
2. เพิ่มหมายเลข Set ใน Comment (เช่น `EU-GU_BUY_1`)
3. ปรับ Group Info เป็นแนวตั้ง + ปุ่ม Close Group
4. เพิ่ม Total Basket Target Input
5. แก้ Bug Group Close (UpdatePairProfits ไม่รู้จัก Comment ใหม่)

---

### 1. แก้ไข Light Mode Text Bug (ปัญหาใหม่)

**สาเหตุของปัญหา:**
- Bottom section (DETAIL, STATUS, HISTORY LOT, HISTORY PROFIT) ใช้ `COLOR_TEXT_WHITE` (สีขาว) สำหรับ labels
- Light Mode มี `COLOR_BOX_BG = C'232,235,240'` (สีเทาอ่อน)
- ผลลัพธ์: ตัวหนังสือสีขาวบนพื้นสีเทาอ่อน = มองไม่เห็น

**แนวทางแก้ไข:**
เพิ่มตัวแปร `COLOR_TEXT_LABEL` ที่เปลี่ยนตาม Theme

**เพิ่มใน Global Variables (~line 755):**
```text
color COLOR_TEXT_LABEL;    // v1.8.7: For secondary labels (changes per theme)
```

**อัพเดท InitializeThemeColors():**

```text
// Light Mode section (~line 834-839):
if(InpThemeMode == THEME_LIGHT)
{
   // ... existing colors ...
   COLOR_TEXT_LABEL   = C'60,65,75';        // Dark Gray for light backgrounds
}
else  // THEME_DARK
{
   // ... existing colors ...
   COLOR_TEXT_LABEL   = C'180,185,195';     // Light Gray for dark backgrounds
}
```

**อัพเดท CreateAccountSummary() (~line 7830-7906):**

เปลี่ยน `COLOR_TEXT_WHITE` เป็น `COLOR_TEXT_LABEL` ในทุก labels:

| บรรทัด | เดิม | ใหม่ |
|--------|------|------|
| 7832 | `COLOR_TEXT_WHITE` | `COLOR_TEXT_LABEL` |
| 7836 | `COLOR_TEXT_WHITE` | `COLOR_TEXT_LABEL` |
| 7840 | `COLOR_TEXT_WHITE` | `COLOR_TEXT_LABEL` |
| 7845 | `COLOR_TEXT_WHITE` | `COLOR_TEXT_LABEL` |
| 7850 | `COLOR_TEXT_WHITE` | `COLOR_TEXT_LABEL` |
| 7852 | `COLOR_TEXT_WHITE` | `COLOR_TEXT_LABEL` |
| 7857 | `COLOR_TEXT_WHITE` | `COLOR_TEXT_LABEL` |
| 7866 | `COLOR_TEXT_WHITE` | `COLOR_TEXT_LABEL` |
| 7870 | `COLOR_TEXT_WHITE` | `COLOR_TEXT_LABEL` |
| 7874 | `COLOR_TEXT_WHITE` | `COLOR_TEXT_LABEL` |
| 7878 | `COLOR_TEXT_WHITE` | `COLOR_TEXT_LABEL` |
| 7885 | `COLOR_TEXT_WHITE` | `COLOR_TEXT_LABEL` |
| 7889 | `COLOR_TEXT_WHITE` | `COLOR_TEXT_LABEL` |
| 7896 | `COLOR_TEXT_WHITE` | `COLOR_TEXT_LABEL` |
| 7899 | `COLOR_TEXT_WHITE` | `COLOR_TEXT_LABEL` |
| 7902 | `COLOR_TEXT_WHITE` | `COLOR_TEXT_LABEL` |
| 7905 | `COLOR_TEXT_WHITE` | `COLOR_TEXT_LABEL` |

**ตัวอย่างการเปลี่ยน:**
```text
// จาก:
CreateLabel(prefix + "L_DLOT", box3X + 10, y + 22, "Daily:", COLOR_TEXT_WHITE, 8, "Arial");

// เป็น:
CreateLabel(prefix + "L_DLOT", box3X + 10, y + 22, "Daily:", COLOR_TEXT_LABEL, 8, "Arial");
```

---

### 2. เพิ่มหมายเลข Set ใน Order Comments

**รูปแบบใหม่:** `EU-GU_BUY_1[ADX:39/37][M:888888]`

**ตำแหน่งที่ต้องแก้ไข (6 จุด):**

| ฟังก์ชัน | รูปแบบเดิม | รูปแบบใหม่ |
|----------|------------|------------|
| OpenBuySideTrade | `%s_BUY[ADX...]` | `%s_BUY_%d[ADX...]` |
| OpenSellSideTrade | `%s_SELL[ADX...]` | `%s_SELL_%d[ADX...]` |
| OpenGridLossBuy | `%s_GL_BUY[ADX...]` | `%s_GL_BUY_%d[ADX...]` |
| OpenGridLossSell | `%s_GL_SELL[ADX...]` | `%s_GL_SELL_%d[ADX...]` |
| OpenGridProfitBuy | `%s_GP_BUY[ADX...]` | `%s_GP_BUY_%d[ADX...]` |
| OpenGridProfitSell | `%s_GP_SELL[ADX...]` | `%s_GP_SELL_%d[ADX...]` |

**ตัวอย่าง:**
```text
// จาก:
comment = StringFormat("%s_BUY[ADX:%.0f/%.0f][M:%d]", 
                       pairPrefix, adxValueA, adxValueB, InpMagicNumber);

// เป็น:
comment = StringFormat("%s_BUY_%d[ADX:%.0f/%.0f][M:%d]", 
                       pairPrefix, pairIndex + 1, adxValueA, adxValueB, InpMagicNumber);
```

**ผลลัพธ์:**
- Pair 1: `EU-GU_BUY_1[M:888888]`
- Pair 21: `GA-AU_GL_SELL_21[M:888888]`

---

### 3. ปรับ Group Info เป็นแนวตั้ง + Close Group Button

**Layout ใหม่ (แนวตั้ง - 5 บรรทัด):**
```text
Group 1
Float: $850
Closed: $1234
Target: $10000
[Close Grp]
```

**การแก้ไขใน CreatePairRow():**

เมื่อ `i % PAIRS_PER_GROUP == 0` (pair แรกของแต่ละ group):

```text
int gIdx = idx / PAIRS_PER_GROUP;
string gIdxStr = IntegerToString(gIdx);

// Group Header
CreateLabel(prefix + "G" + gIdxStr + "_HDR", groupInfoX + 5, y + 2, "Group " + IntegerToString(gIdx + 1), COLOR_GOLD, 8, "Arial Bold");

// Floating P/L
CreateLabel(prefix + "G" + gIdxStr + "_L_FLT", groupInfoX + 5, y + 16, "Float:", COLOR_TEXT_LABEL, 7, "Arial");
CreateLabel(prefix + "G" + gIdxStr + "_V_FLT", groupInfoX + 40, y + 16, "$0", COLOR_PROFIT, 8, "Arial Bold");

// Closed P/L
CreateLabel(prefix + "G" + gIdxStr + "_L_CL", groupInfoX + 5, y + 30, "Closed:", COLOR_TEXT_LABEL, 7, "Arial");
CreateLabel(prefix + "G" + gIdxStr + "_V_CL", groupInfoX + 45, y + 30, "$0", COLOR_PROFIT, 8, "Arial Bold");

// Target
CreateLabel(prefix + "G" + gIdxStr + "_L_TGT", groupInfoX + 5, y + 44, "Target:", COLOR_TEXT_LABEL, 7, "Arial");
CreateLabel(prefix + "G" + gIdxStr + "_V_TGT", groupInfoX + 45, y + 44, "$10000", COLOR_GOLD, 8, "Arial");

// Close Group Button
CreateButton(prefix + "_CLOSE_GRP_" + gIdxStr, groupInfoX + 5, y + 58, 70, 14, "Close Grp", COLOR_HEADER_SELL, clrWhite);
```

**เพิ่ม OnChartEvent handler สำหรับ Close Group button:**

```text
if(StringFind(sparam, prefix + "_CLOSE_GRP_") >= 0)
{
   int grpIdx = (int)StringToInteger(StringSubstr(sparam, StringLen(prefix + "_CLOSE_GRP_")));
   
   string msg = StringFormat("Close ALL orders in Group %d (Pairs %d-%d)?", 
                             grpIdx + 1, grpIdx * PAIRS_PER_GROUP + 1, (grpIdx + 1) * PAIRS_PER_GROUP);
   int result = MessageBox(msg, "Confirm Close Group", MB_YESNO | MB_ICONQUESTION);
   if(result != IDYES)
   {
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      return;
   }
   
   CloseGroupOrders(grpIdx);
   ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
}
```

**เพิ่มฟังก์ชัน CloseGroupOrders():**

```text
void CloseGroupOrders(int groupIdx)
{
   g_orphanCheckPaused = true;
   
   int startPair = groupIdx * PAIRS_PER_GROUP;
   int endPair = startPair + PAIRS_PER_GROUP;
   
   PrintFormat(">>> MANUAL CLOSE: Group %d (Pairs %d-%d) <<<", 
               groupIdx + 1, startPair + 1, endPair);
   
   for(int i = startPair; i < endPair && i < MAX_PAIRS; i++)
   {
      if(g_pairs[i].directionBuy == 1)
         CloseBuySide(i);
      if(g_pairs[i].directionSell == 1)
         CloseSellSide(i);
   }
   
   g_orphanCheckPaused = false;
   
   // Reset group's profit
   ResetGroupProfit(groupIdx);
   PrintFormat(">>> GROUP %d MANUAL CLOSE COMPLETE <<<", groupIdx + 1);
}
```

---

### 4. เพิ่ม Total Basket Target Input

**เพิ่ม Input Parameter:**

```text
input group "=== Total Basket Target (v1.8.7) ==="
input bool     InpEnableTotalBasket = false;      // Enable Total Basket Close
input double   InpTotalBasketTarget = 500.0;      // Total Basket Target ($)
```

**ปรับ CheckTotalTarget() ให้รองรับ Total Basket:**

```text
void CheckTotalTarget()
{
   // ... existing group calculations ...
   
   // === v1.8.7: Check Total Basket Target (ALL GROUPS) ===
   if(InpEnableTotalBasket && InpTotalBasketTarget > 0)
   {
      if(g_basketTotalProfit >= InpTotalBasketTarget)
      {
         PrintFormat(">>> TOTAL BASKET TARGET REACHED: $%.2f >= $%.2f <<<", 
                     g_basketTotalProfit, InpTotalBasketTarget);
         
         g_orphanCheckPaused = true;
         
         // Close all groups
         for(int g = 0; g < MAX_GROUPS; g++)
         {
            int startPair = g * PAIRS_PER_GROUP;
            int endPair = startPair + PAIRS_PER_GROUP;
            
            for(int i = startPair; i < endPair && i < MAX_PAIRS; i++)
            {
               if(g_pairs[i].directionBuy == 1)
                  CloseBuySide(i);
               if(g_pairs[i].directionSell == 1)
                  CloseSellSide(i);
            }
            ResetGroupProfit(g);
         }
         
         g_orphanCheckPaused = false;
         PrintFormat(">>> TOTAL BASKET CLOSE COMPLETE <<<");
      }
   }
   
   // ... existing per-group target check ...
}
```

---

### 5. แก้ Bug Group Close - UpdatePairProfits()

**สาเหตุของปัญหา:**
- v1.8.6 เปลี่ยน Comment เป็น `EU-GU_BUY[M:888888]`
- แต่ `UpdatePairProfits()` ยังค้นหา `HrmDream_GL_BUY_%d` pattern เดิม
- ผลลัพธ์: ไม่พบ positions ที่ใช้ comment format ใหม่ → ไม่คำนวณ profit → Group Target ไม่ปิด

**แนวทางแก้ไข:**
ใช้ `GetPairCommentPrefix()` แบบ dynamic และรองรับทั้ง format ใหม่และเก่า

**แก้ไขใน UpdatePairProfits():**

```text
for(int i = 0; i < MAX_PAIRS; i++)
{
   if(!g_pairs[i].enabled) continue;
   
   double buyProfit = 0;
   double sellProfit = 0;
   
   // v1.8.7: Get dynamic pair prefix
   string pairPrefix = GetPairCommentPrefix(i);
   
   if(g_pairs[i].directionBuy == 1)
   {
      // Main position profit
      buyProfit += GetPositionProfit(g_pairs[i].ticketBuyA);
      buyProfit += GetPositionProfit(g_pairs[i].ticketBuyB);
      
      // v1.8.7: Grid positions using NEW format
      string glBuyComment = StringFormat("%s_GL_BUY_%d", pairPrefix, i + 1);
      string gpBuyComment = StringFormat("%s_GP_BUY_%d", pairPrefix, i + 1);
      buyProfit += GetAveragingProfit(glBuyComment);
      buyProfit += GetAveragingProfit(gpBuyComment);
      
      // Legacy support: Also check old HrmDream_ format
      string legacyGL = StringFormat("HrmDream_GL_BUY_%d", i + 1);
      string legacyGP = StringFormat("HrmDream_GP_BUY_%d", i + 1);
      buyProfit += GetAveragingProfit(legacyGL);
      buyProfit += GetAveragingProfit(legacyGP);
   }
   
   // Same pattern for Sell side...
}
```

**แก้ไขใน ForceCloseBuySide() และ ForceCloseSellSide():**

```text
void ForceCloseBuySide(int pairIndex)
{
   string pairPrefix = GetPairCommentPrefix(pairIndex);
   
   // New format comments
   string mainComment = StringFormat("%s_BUY_%d", pairPrefix, pairIndex + 1);
   string glComment = StringFormat("%s_GL_BUY_%d", pairPrefix, pairIndex + 1);
   string gpComment = StringFormat("%s_GP_BUY_%d", pairPrefix, pairIndex + 1);
   
   // Legacy format comments
   string legacyMain = StringFormat("HrmDream_BUY_%d", pairIndex + 1);
   string legacyGL = StringFormat("HrmDream_GL_BUY_%d", pairIndex + 1);
   string legacyGP = StringFormat("HrmDream_GP_BUY_%d", pairIndex + 1);
   
   // Close ALL matching positions (both formats)
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      // ... check both new and legacy patterns ...
   }
}
```

---

### 6. อัพเดท Version

**บรรทัด 7:**
```text
#property version   "1.87"
```

**Dashboard Title:**
```text
"Moneyx Harmony Dream v1.8.7"
```

---

### สรุปไฟล์ที่ต้องแก้ไข:

| ไฟล์ | การเปลี่ยนแปลง |
|------|----------------|
| `public/docs/mql5/Harmony_Dream_EA.mq5` | 1) เพิ่ม COLOR_TEXT_LABEL และแก้ Light Mode text bug 2) เพิ่มหมายเลข Set ใน Comments 3) ปรับ Group Info แนวตั้ง + Close Group 4) เพิ่ม Total Basket Target 5) แก้ UpdatePairProfits() |

---

### สิ่งที่ไม่แตะต้อง:

- Trading Logic (Entry/Exit conditions)
- ADX / CDC / Correlation Calculation
- Grid Distance และ Lot Sizing Logic
- License System
- Theme System structure (แค่เพิ่ม COLOR_TEXT_LABEL)

---

### ผลลัพธ์ที่คาดหวัง:

**Light Mode:**
- ข้อความ DETAIL, STATUS, HISTORY LOT, HISTORY PROFIT อ่านได้ชัดเจน
- ใช้ตัวหนังสือสีเทาเข้มบนพื้นสีอ่อน

**Order Comments:**
- มีหมายเลข Set: `GA-AU_GL_BUY_21[M:88888]`

**Group Info Display:**
```text
Group 5
Float: $850
Closed: $9500
Target: $10000
[Close Grp]
```

**Group Close Bug:**
- Group Target ทำงานถูกต้องแม้จะใช้ Comment format ใหม่

