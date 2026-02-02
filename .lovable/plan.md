

## แผนรวม: Mini Group Complete Update (v2.1.2)

### สรุปทั้งหมดที่จะทำ

| หมวด | รายละเอียด |
|------|------------|
| **UI** | ขยาย Mini Group Column (90→110px), สีน้ำเงินแยกชัด, ปุ่ม Close Mini ไป Row 2 |
| **Display** | M.Tgt แสดงเป็น `1000/1000/1000` แทนผลรวม `$3000` |
| **Logic** | Reset `closedProfit = 0` เมื่อ Mini Group ถึง target และปิดแล้ว เพื่อเริ่มรอบใหม่ |

---

### ส่วนที่ 1: UI Improvements

#### 1.1 เพิ่มสีใหม่สำหรับ Mini Group

**ตำแหน่ง:** Color definitions (~บรรทัด 106-130)

```cpp
// v2.1.2: Mini Group specific colors (distinct from Group Info)
#define COLOR_HEADER_MINI        C'25,45,80'     // Dark blue header
#define COLOR_COLHDR_MINI        C'30,50,90'     // Column header blue
#define COLOR_MINI_BG            C'20,35,60'     // Row background blue
#define COLOR_MINI_BORDER        C'40,60,100'    // Border blue
```

#### 1.2 ขยาย Mini Group Column Width

**ตำแหน่ง:** CreateDashboard() - บรรทัด 8400-8402

```cpp
// v2.1.2: Mini Group Column (EXPANDED)
int miniGroupWidth = 110;  // Increased from 90 to 110
```

#### 1.3 เปลี่ยนสี Mini Group Headers และ Row Backgrounds

- ใช้ `COLOR_HEADER_MINI` แทน `COLOR_HEADER_GROUP`
- ใช้ `COLOR_COLHDR_MINI` แทน `COLOR_COLHDR_GROUP`  
- ใช้ `COLOR_MINI_BG` และ `COLOR_MINI_BORDER` สำหรับ row backgrounds

#### 1.4 ย้าย Close Mini Button ไป Row 2

**ตำแหน่ง:** CreatePairRow() - บรรทัด 8564-8578

```cpp
// Row 1 (idx % 2 == 0): แสดง M1, Float, Closed
if(idx % PAIRS_PER_MINI == 0)
{
   // Mini label + Float + Closed values only
   CreateLabel(... "M1", ...);
   CreateLabel(... "$0", ...);  // Float
   CreateLabel(... "$0", ...);  // Closed
}
// Row 2 (idx % 2 == 1): แสดงปุ่ม Close Mini
else if(idx % PAIRS_PER_MINI == 1)
{
   // Close Mini button on Row 2 (larger, centered)
   CreateButton(... "Close Mini", ...);
}
```

---

### ส่วนที่ 2: M.Tgt Display Format

#### 2.1 เพิ่ม Helper Function ใหม่

**ตำแหน่ง:** หลัง GetMiniGroupSumTarget() (~บรรทัด 1858)

```cpp
//+------------------------------------------------------------------+
//| v2.1.2: Get Mini Group Targets as formatted string               |
//+------------------------------------------------------------------+
string GetMiniGroupTargetString(int groupIndex)
{
   int startMini = groupIndex * MINIS_PER_GROUP;
   string result = "";
   
   for(int i = 0; i < MINIS_PER_GROUP; i++)
   {
      double target = GetScaledMiniGroupTarget(startMini + i);
      if(i > 0) result += "/";
      
      if(target > 0)
         result += IntegerToString((int)target);
      else
         result += "0";
   }
   
   return result;  // Format: "1000/1000/1000"
}
```

#### 2.2 อัปเดต M.Tgt Display

**ตำแหน่ง:** CreatePairRow() และ UpdateDashboard()

```cpp
// แทนที่:
double miniTgt = GetMiniGroupSumTarget(gIdx);
string miniTgtStr = "$" + DoubleToString(miniTgt, 0);

// ด้วย:
string miniTgtStr = GetMiniGroupTargetString(gIdx);  // "1000/1000/1000"
```

---

### ส่วนที่ 3: Reset Logic เมื่อถึง Target

#### 3.1 แก้ไข CloseMiniGroup()

**ตำแหน่ง:** CloseMiniGroup() - บรรทัด 4359-4366

**จาก:**
```cpp
// Add closed profit to Mini Group's accumulated closed
g_miniGroups[miniIndex].closedProfit += closedProfit;
```

**เป็น:**
```cpp
// v2.1.2: Add closed profit to PARENT GROUP (for Group tracking)
int groupIdx = GetGroupFromMini(miniIndex);
g_groups[groupIdx].closedProfit += closedProfit;

// v2.1.2: Reset Mini Group closed profit for NEW CYCLE
g_miniGroups[miniIndex].closedProfit = 0;

PrintFormat("[v2.1.2] Mini Group %d TARGET CLOSED | Profit: $%.2f → Group %d | Mini RESET to $0",
            miniIndex + 1, closedProfit, groupIdx + 1);
```

---

### Logic Flow หลังแก้ไข

```text
Mini Group M1 ทำงาน:
┌───────────────────────────────────────────────────────────┐
│ 1. Pair 1-2 เทรดสะสม → Dashboard แสดง Closed = $800      │
│                                                           │
│ 2. M1 total profit ถึง Target ($1000)                     │
│                                                           │
│ 3. CloseMiniGroup(0) executes:                            │
│    ├─ ปิด positions ทั้งหมดใน Pair 1-2                     │
│    ├─ บวก $1000 ไปที่ Group 1 closedProfit (สะสมไว้)       │
│    ├─ Reset g_miniGroups[0].closedProfit = 0  ← ใหม่!     │
│    └─ Set targetTriggered = true                          │
│                                                           │
│ 4. Dashboard แสดง M1 Closed = $0 (เริ่มรอบใหม่)           │
│                                                           │
│ 5. เปิด position ใหม่ → Reset targetTriggered = false     │
│                                                           │
│ 6. M1 พร้อมเก็บสะสมรอบใหม่ได้แล้ว                          │
└───────────────────────────────────────────────────────────┘
```

---

### Dashboard Display เปรียบเทียบ

**ก่อนแก้ไข:**
```text
GROUP INFO                    │ MINI GROUP (90px, สีม่วง)
├─ Float: $-1154              │ M1 $1000 $1000 [X]  ← ยังค้าง $1000
├─ Closed: $1000              │                     ← Row 2 ว่าง
├─ Target: $2000              │
└─ M.Tgt: $3000  ← ผลรวมสับสน │
```

**หลังแก้ไข:**
```text
GROUP INFO                    │ MINI GROUP (110px, สีน้ำเงิน)
├─ Float: $-1154              │ M1    $0      $0       ← Reset เป็น $0 แล้ว
├─ Closed: $2000 (รวม Mini)   │ [ Close Mini ]        ← ปุ่มอยู่ Row 2
├─ Target: $2000              │
└─ M.Tgt: 1000/1000/1000      │ ← แยกชัดเจน
```

---

### สรุปไฟล์ที่แก้ไข

| ไฟล์ | ส่วนที่แก้ไข |
|------|-------------|
| `public/docs/mql5/Harmony_Dream_EA.mq5` | Color definitions, CreateDashboard(), CreatePairRow(), UpdateDashboard(), CloseMiniGroup(), เพิ่ม GetMiniGroupTargetString() |
| `.lovable/plan.md` | อัปเดตสถานะแผน v2.1.2 |

---

### Version Update

```cpp
#property version   "2.12"
#property description "v2.1.2: Mini Group UI + M.Tgt Format + Reset Cycle Logic"
```

