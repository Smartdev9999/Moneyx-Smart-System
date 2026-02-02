

## แผนปรับปรุง: ระบบ Mini Group + Group v2.0 (Updated)

### สรุปความต้องการ (Updated)

**โครงสร้างใหม่:**
- 5 Groups × 6 Pairs = 30 Pairs  
- 15 Mini Groups (นับต่อเนื่อง 1-15) แต่ละ Mini มี 2 Pairs
- เพิ่ม Column "MINI GROUP" ด้านซ้ายของ GROUP INFO
- แสดงเฉพาะ Floating P/L และ Closed P/L (ประหยัดพื้นที่)
- เพิ่ม "Mini Target" ใน GROUP INFO (ใต้ Target)

---

### Dashboard Layout ใหม่

```text
┌────────────┬────────────┬────────────┬─────────────┬────────────────┐
│  BUY DATA  │   CENTER   │ SELL DATA  │ MINI GROUP  │   GROUP INFO   │
│   (395px)  │  (390px)   │  (395px)   │   (90px)    │    (125px)     │
├────────────┼────────────┼────────────┼─────────────┼────────────────┤
│ Pair 1     │            │            │ M1 F:$xx    │                │
│ Pair 2     │            │            │    C:$xx    │                │
│ Pair 3     │            │            │ M2 F:$xx    │                │
│ Pair 4     │            │            │    C:$xx    │ Group 1        │
│ Pair 5     │            │            │ M3 F:$xx    │ Float: $xx     │
│ Pair 6     │            │            │    C:$xx    │ Closed:$xx     │
│            │            │            │             │ Target:$xx     │
│            │            │            │             │ M.Tgt: $xx     │
│            │            │            │             │ [Close Grp]    │
├────────────┼────────────┼────────────┼─────────────┼────────────────┤
│ Pair 7     │            │            │ M4 F:$xx    │                │
│ Pair 8     │            │            │    C:$xx    │                │
│ Pair 9     │            │            │ M5 F:$xx    │                │
│ Pair 10    │            │            │    C:$xx    │ Group 2        │
│ Pair 11    │            │            │ M6 F:$xx    │ Float: $xx     │
│ Pair 12    │            │            │    C:$xx    │ Closed:$xx     │
│            │            │            │             │ Target:$xx     │
│            │            │            │             │ M.Tgt: $xx     │
│            │            │            │             │ [Close Grp]    │
└────────────┴────────────┴────────────┴─────────────┴────────────────┘
(ซ้ำสำหรับ Group 3, 4, 5)
```

---

### Mini Group Numbering (ต่อเนื่อง 1-15)

| Mini # | Pairs | Parent Group |
|--------|-------|--------------|
| M1 | Pair 1-2 | Group 1 |
| M2 | Pair 3-4 | Group 1 |
| M3 | Pair 5-6 | Group 1 |
| M4 | Pair 7-8 | Group 2 |
| M5 | Pair 9-10 | Group 2 |
| M6 | Pair 11-12 | Group 2 |
| M7 | Pair 13-14 | Group 3 |
| M8 | Pair 15-16 | Group 3 |
| M9 | Pair 17-18 | Group 3 |
| M10 | Pair 19-20 | Group 4 |
| M11 | Pair 21-22 | Group 4 |
| M12 | Pair 23-24 | Group 4 |
| M13 | Pair 25-26 | Group 5 |
| M14 | Pair 27-28 | Group 5 |
| M15 | Pair 29-30 | Group 5 |

---

### ส่วนที่ต้องแก้ไข

#### 1. Constants

**ไฟล์:** `public/docs/mql5/Harmony_Dream_EA.mq5`  
**บรรทัด:** 23-27

**เปลี่ยน:**
```cpp
#define MAX_GROUPS 6           →  #define MAX_GROUPS 5
#define PAIRS_PER_GROUP 5      →  #define PAIRS_PER_GROUP 6
```

**เพิ่ม:**
```cpp
#define MAX_MINI_GROUPS 15     // 15 Mini Groups (numbered 1-15)
#define PAIRS_PER_MINI 2       // 2 pairs per Mini Group
#define MINIS_PER_GROUP 3      // 3 Mini Groups per Main Group
```

---

#### 2. เพิ่ม Mini Group Structure

**ตำแหน่ง:** หลัง GroupTarget struct (~บรรทัด 670)

```cpp
// v2.0: Mini Group Structure (2 pairs per mini, numbered 1-15)
struct MiniGroupData
{
   double closedProfit;     // Accumulated closed profit
   double floatingProfit;   // Current floating profit
   double totalProfit;      // Closed + Floating
   double closedTarget;     // Target for auto-close
   bool   targetTriggered;  // Prevent multiple triggers
};

MiniGroupData g_miniGroups[MAX_MINI_GROUPS];
```

---

#### 3. Input Parameters - Mini Group Targets

**ตำแหน่ง:** หลังจาก Group Target Settings แต่ละกลุ่ม

**ตัวอย่าง Group 1 (หลัง Pair 6):**
```cpp
input group "=== Pair 1-6 Configuration ==="
// ... pair configs ...

input group "=== Group 1 Target Settings (v2.0) ==="
input double   InpGroup1ClosedTarget = 0;       // Group Closed Target $ (0=Disable)
input double   InpGroup1FloatingTarget = 0;     // Group Floating Target $ (0=Disable)
input int      InpGroup1MaxOrderBuy = 5;        // Max Orders Buy
input int      InpGroup1MaxOrderSell = 5;       // Max Orders Sell
input double   InpGroup1TargetBuy = 10.0;       // Per-Side Target Buy $
input double   InpGroup1TargetSell = 10.0;      // Per-Side Target Sell $

input group "=== Mini Group Targets (M1-M3) ==="
input double   InpMini1Target = 0;              // Mini 1 (Pair 1-2) Target $ (0=Disable)
input double   InpMini2Target = 0;              // Mini 2 (Pair 3-4) Target $ (0=Disable)
input double   InpMini3Target = 0;              // Mini 3 (Pair 5-6) Target $ (0=Disable)
```

**รวม Mini Group Inputs:**
- Group 1: M1, M2, M3
- Group 2: M4, M5, M6
- Group 3: M7, M8, M9
- Group 4: M10, M11, M12
- Group 5: M13, M14, M15

---

#### 4. Dashboard - เพิ่ม Mini Group Column

**บรรทัด:** ~8136 (หลัง sellStartX)

**เพิ่ม:**
```cpp
// v2.0: Mini Group Column
int miniGroupWidth = 90;
int miniGroupX = sellStartX + sellWidth + 5;

// v2.0: Group Info Column (shifted right)
int groupInfoWidth = 125;
int groupInfoX = miniGroupX + miniGroupWidth + 5;

// Update PANEL_WIDTH default: 1200 → 1320
```

**เพิ่ม Mini Group Header:**
```cpp
// v2.0: Mini Group Header
CreateRectangle(prefix + "HDR_MINI", miniGroupX, headerY + 3, miniGroupWidth, headerHeight, COLOR_HEADER_GROUP, COLOR_HEADER_GROUP);
CreateLabel(prefix + "HDR_MINI_TXT", miniGroupX + 8, headerY + 8, "MINI GROUP", COLOR_HEADER_TXT, 9, "Arial Bold");

// Mini Group Column Header
CreateRectangle(prefix + "COLHDR_MINI_BG", miniGroupX, colHeaderY - 1, miniGroupWidth, colHeaderHeight, COLOR_COLHDR_GROUP, COLOR_COLHDR_GROUP);
CreateLabel(prefix + "COL_M_HDR", miniGroupX + 5, colLabelY, "#", COLOR_HEADER_TXT, 7, "Arial");
CreateLabel(prefix + "COL_M_FLT", miniGroupX + 25, colLabelY, "Float", COLOR_HEADER_TXT, 7, "Arial");
CreateLabel(prefix + "COL_M_CL", miniGroupX + 60, colLabelY, "Closed", COLOR_HEADER_TXT, 7, "Arial");
```

---

#### 5. CreatePairRow() - Mini Group Display

**บรรทัด:** ~8237+ (function CreatePairRow)

**เพิ่ม Mini Group Display ทุก 2 Pairs:**
```cpp
// v2.0: Mini Group Column (แสดงทุก 2 pairs)
if(idx % PAIRS_PER_MINI == 0)
{
   int mIdx = idx / PAIRS_PER_MINI;  // Mini Group index 0-14
   string mIdxStr = IntegerToString(mIdx);
   
   // Mini Group number (1-15)
   string miniLabel = "M" + IntegerToString(mIdx + 1);
   
   // Row 1: Mini number + Floating
   CreateLabel(prefix + "M" + mIdxStr + "_HDR", miniGroupX + 5, y + 3, miniLabel, COLOR_GOLD, 8, "Arial Bold");
   CreateLabel(prefix + "M" + mIdxStr + "_V_FLT", miniGroupX + 28, y + 3, "$0", COLOR_PROFIT, 8, "Arial");
   
   // Row 2: Closed value
   CreateLabel(prefix + "M" + mIdxStr + "_V_CL", miniGroupX + 60, y + 3, "$0", COLOR_PROFIT, 8, "Arial");
}
else
{
   // Row 2 of each Mini pair - show closed value on same visual row
   int mIdx = idx / PAIRS_PER_MINI;
   string mIdxStr = IntegerToString(mIdx);
   
   // Row 2 continuation (already created above, update position)
   // Float value is on Row 1, Closed value spans to Row 2 area
}
```

---

#### 6. GROUP INFO - เพิ่ม Mini Target Display

**บรรทัด:** ~8289-8314 (ใน CreatePairRow, GROUP INFO section)

**แก้ไข layout เพิ่ม Mini Target:**
```cpp
// === v2.0: GROUP INFO COLUMN - Updated Layout ===
if(idx % PAIRS_PER_GROUP == 0)
{
   int gIdx = idx / PAIRS_PER_GROUP;
   string gIdxStr = IntegerToString(gIdx);
   
   // Group header
   CreateLabel(prefix + "G" + gIdxStr + "_HDR", groupInfoX + 5, y + 2, "Group " + IntegerToString(gIdx + 1), COLOR_GOLD, 8, "Arial Bold");
   
   // Floating P/L row
   CreateLabel(prefix + "G" + gIdxStr + "_L_FLT", groupInfoX + 5, y + 16, "Float:", COLOR_TEXT_LABEL, 7, "Arial");
   CreateLabel(prefix + "G" + gIdxStr + "_V_FLT", groupInfoX + 45, y + 16, "$0", COLOR_PROFIT, 8, "Arial Bold");
   
   // Closed P/L row
   CreateLabel(prefix + "G" + gIdxStr + "_L_CL", groupInfoX + 5, y + 30, "Closed:", COLOR_TEXT_LABEL, 7, "Arial");
   CreateLabel(prefix + "G" + gIdxStr + "_V_CL", groupInfoX + 53, y + 30, "$0", COLOR_PROFIT, 8, "Arial Bold");
   
   // Target row
   double scaledTarget = GetRealTimeScaledClosedTarget(gIdx);
   string tgtStr = (scaledTarget > 0) ? "$" + DoubleToString(scaledTarget, 0) : "-";
   CreateLabel(prefix + "G" + gIdxStr + "_L_TGT", groupInfoX + 5, y + 44, "Target:", COLOR_TEXT_LABEL, 7, "Arial");
   CreateLabel(prefix + "G" + gIdxStr + "_V_TGT", groupInfoX + 50, y + 44, tgtStr, COLOR_GOLD, 8, "Arial");
   
   // v2.0: Mini Target row (NEW!)
   double miniTgt = GetMiniGroupSumTarget(gIdx);  // Sum of M1-M3 targets
   string miniTgtStr = (miniTgt > 0) ? "$" + DoubleToString(miniTgt, 0) : "-";
   CreateLabel(prefix + "G" + gIdxStr + "_L_MTGT", groupInfoX + 5, y + 58, "M.Tgt:", COLOR_TEXT_LABEL, 7, "Arial");
   CreateLabel(prefix + "G" + gIdxStr + "_V_MTGT", groupInfoX + 48, y + 58, miniTgtStr, COLOR_ACTIVE, 8, "Arial");
   
   // Close Group button (shifted down)
   CreateButton(prefix + "_CLOSE_GRP_" + gIdxStr, groupInfoX + 5, y + 72, 80, 14, "Close Grp", COLOR_HEADER_SELL, clrWhite);
}
```

---

#### 7. Helper Functions ใหม่

```cpp
// v2.0: Get Mini Group index from Pair index (0-29 → 0-14)
int GetMiniGroupIndex(int pairIndex)
{
   return pairIndex / PAIRS_PER_MINI;
}

// v2.0: Get Parent Group index from Mini Group index (0-14 → 0-4)
int GetGroupFromMini(int miniIndex)
{
   return miniIndex / MINIS_PER_GROUP;
}

// v2.0: Get sum of Mini Group targets for a Group
double GetMiniGroupSumTarget(int groupIndex)
{
   double sum = 0;
   int startMini = groupIndex * MINIS_PER_GROUP;
   for(int i = 0; i < MINIS_PER_GROUP; i++)
   {
      sum += g_miniGroups[startMini + i].closedTarget;
   }
   return sum;
}

// v2.0: Update Mini Group P/L
void UpdateMiniGroupProfits()
{
   for(int m = 0; m < MAX_MINI_GROUPS; m++)
   {
      int startPair = m * PAIRS_PER_MINI;
      g_miniGroups[m].floatingProfit = 0;
      
      for(int p = startPair; p < startPair + PAIRS_PER_MINI && p < MAX_PAIRS; p++)
      {
         g_miniGroups[m].floatingProfit += g_pairs[p].profitBuy + g_pairs[p].profitSell;
      }
      
      g_miniGroups[m].totalProfit = g_miniGroups[m].closedProfit + g_miniGroups[m].floatingProfit;
   }
}
```

---

#### 8. UpdateDashboard() - Mini Group Update

**เพิ่มใน UpdateDashboard():**
```cpp
// v2.0: Update Mini Group Column
for(int m = 0; m < MAX_MINI_GROUPS; m++)
{
   string mIdxStr = IntegerToString(m);
   
   // Update Floating
   double mFloat = g_miniGroups[m].floatingProfit;
   color fltColor = (mFloat >= 0) ? COLOR_PROFIT : COLOR_LOSS;
   UpdateLabel(prefix + "M" + mIdxStr + "_V_FLT", "$" + DoubleToString(mFloat, 0), fltColor);
   
   // Update Closed
   double mClosed = g_miniGroups[m].closedProfit;
   color clColor = (mClosed >= 0) ? COLOR_PROFIT : COLOR_LOSS;
   UpdateLabel(prefix + "M" + mIdxStr + "_V_CL", "$" + DoubleToString(mClosed, 0), clColor);
}
```

---

### สรุปไฟล์ที่แก้ไข

| ส่วน | บรรทัด (ประมาณ) | รายละเอียด |
|------|-----------------|------------|
| Constants | 23-27 | เปลี่ยน MAX_GROUPS=5, PAIRS_PER_GROUP=6, เพิ่ม MAX_MINI_GROUPS |
| Structure | ~670 | เพิ่ม MiniGroupData struct + g_miniGroups array |
| Input Parameters | ~462-605 | เพิ่ม Mini Target inputs (M1-M15), ปรับ Group settings |
| CreateDashboard() | ~8132-8162 | เพิ่ม miniGroupX, miniGroupWidth, Mini Group headers |
| CreatePairRow() | ~8237-8315 | เพิ่ม Mini Group display + Mini Target ใน GROUP INFO |
| UpdateDashboard() | ~8600+ | เพิ่มการ update Mini Group values |
| Helper functions | ใหม่ | GetMiniGroupIndex(), GetGroupFromMini(), UpdateMiniGroupProfits() |
| InpPanelWidth | 411 | Default 1200 → 1320 |

---

### ข้อควรระวัง

1. **ไม่แตะต้อง**: Order entry/exit logic, Grid logic, Comment format
2. **ROW_HEIGHT**: อาจต้องปรับถ้า Group Info ใช้ rows มากขึ้น (6 pairs × 18px = 108px ต่อ group)
3. **Mini Group Target Logic**: ยังไม่รวมการปิด orders อัตโนมัติ (จะทำแยกภายหลัง)

---

### Version Update

```cpp
#property version   "2.00"
#property description "v2.0: Mini Group System (5 Groups × 6 Pairs, 15 Mini Groups)"
```

