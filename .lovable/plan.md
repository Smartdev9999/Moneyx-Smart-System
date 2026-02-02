

## แผนแก้ไข: Hierarchical Basket Reset System (v2.1.5)

### สรุปปัญหา

ปัจจุบัน reset logic ไม่ถูกต้องตาม hierarchy:

| Level | ปิด Target แล้ว | ควรรีเซ็ท | ปัจจุบัน |
|-------|----------------|----------|---------|
| **Mini Group** | M3 ถึง $2000 | M3 เท่านั้น | ✅ ถูกต้อง |
| **Group** | Group 1 ถึง $4000 | M1, M2, M3 + Group 1 | ❌ รีเซ็ทเฉพาะ Group 1 |
| **Total Basket** | Total ถึง $10000 | All M1-M15 + All Groups + Total | ❌ รีเซ็ทเฉพาะ Groups + Total |

### Hierarchy ที่ถูกต้อง

```text
โครงสร้าง:
┌─────────────────────────────────────────────────────────────┐
│ Total Basket                                                │
│   ├── Group 1                                               │
│   │     ├── M1 (Pair 1-2)                                   │
│   │     ├── M2 (Pair 3-4)                                   │
│   │     └── M3 (Pair 5-6)                                   │
│   ├── Group 2                                               │
│   │     ├── M4 (Pair 7-8)                                   │
│   │     ├── M5 (Pair 9-10)                                  │
│   │     └── M6 (Pair 11-12)                                 │
│   └── ... (Group 3-5)                                       │
└─────────────────────────────────────────────────────────────┘

Reset Rules (เล็กไปใหญ่):
- Mini Group reset → รีเซ็ท Mini Group ตัวเองเท่านั้น
- Group reset → รีเซ็ท Mini Groups ใน Group + Group ตัวเอง
- Total Basket reset → รีเซ็ท ALL Mini Groups + ALL Groups + Total Basket
```

---

### ส่วนที่ต้องแก้ไข

#### 1. สร้าง ResetMiniGroupProfit() Function ใหม่

**ตำแหน่ง:** หลัง `ResetGroupProfit()` (~บรรทัด 1998)

```cpp
//+------------------------------------------------------------------+
//| v2.1.5: Reset Mini Group Profit                                    |
//+------------------------------------------------------------------+
void ResetMiniGroupProfit(int miniIndex)
{
   if(miniIndex < 0 || miniIndex >= MAX_MINI_GROUPS) return;
   
   g_miniGroups[miniIndex].closedProfit = 0;
   g_miniGroups[miniIndex].floatingProfit = 0;
   g_miniGroups[miniIndex].totalProfit = 0;
   g_miniGroups[miniIndex].targetTriggered = false;
   
   PrintFormat("[v2.1.5] Mini Group %d RESET: closedProfit = 0, targetTriggered = false",
               miniIndex + 1);
}
```

---

#### 2. แก้ไข ResetGroupProfit() - รีเซ็ท Mini Groups ภายในด้วย

**ตำแหน่ง:** `ResetGroupProfit()` (~บรรทัด 1988-1997)

**จาก:**
```cpp
void ResetGroupProfit(int groupIndex)
{
   if(groupIndex < 0 || groupIndex >= MAX_GROUPS) return;
   
   g_groups[groupIndex].closedProfit = 0;
   g_groups[groupIndex].floatingProfit = 0;
   g_groups[groupIndex].totalProfit = 0;
   g_groups[groupIndex].targetTriggered = false;
   g_groups[groupIndex].closeMode = false;
}
```

**เป็น:**
```cpp
void ResetGroupProfit(int groupIndex)
{
   if(groupIndex < 0 || groupIndex >= MAX_GROUPS) return;
   
   // v2.1.5: Reset all Mini Groups within this Group FIRST (hierarchy: small → big)
   int startMini = groupIndex * MINIS_PER_GROUP;
   for(int m = startMini; m < startMini + MINIS_PER_GROUP && m < MAX_MINI_GROUPS; m++)
   {
      ResetMiniGroupProfit(m);
   }
   
   // Reset Group itself
   g_groups[groupIndex].closedProfit = 0;
   g_groups[groupIndex].floatingProfit = 0;
   g_groups[groupIndex].totalProfit = 0;
   g_groups[groupIndex].targetTriggered = false;
   g_groups[groupIndex].closeMode = false;
   
   PrintFormat("[v2.1.5] Group %d RESET: closedProfit = 0, Mini Groups M%d-M%d also reset",
               groupIndex + 1, startMini + 1, startMini + MINIS_PER_GROUP);
}
```

---

#### 3. Total Basket Close - Already correct (เรียก ResetGroupProfit ซึ่งจะ reset Mini Groups ด้วย)

เมื่อแก้ไข `ResetGroupProfit()` แล้ว Total Basket close จะทำงานถูกต้องโดยอัตโนมัติ:

```text
Total Basket Close Flow (v2.1.5):
1. g_basketTotalProfit >= InpTotalBasketTarget
2. Loop all Groups: ResetGroupProfit(grp)
3. ResetGroupProfit(0):
   ├── ResetMiniGroupProfit(0) → M1 = 0
   ├── ResetMiniGroupProfit(1) → M2 = 0  
   ├── ResetMiniGroupProfit(2) → M3 = 0
   └── Group 1 = 0
4. ResetGroupProfit(1):
   ├── ResetMiniGroupProfit(3) → M4 = 0
   ├── ...
5. ... (All 5 Groups and 15 Mini Groups reset)
6. g_accumulatedBasketProfit = 0 → Total Basket = 0
```

---

#### 4. ปรับ CloseMiniGroup() - ใช้ ResetMiniGroupProfit() แทน

**ตำแหน่ง:** `CloseMiniGroup()` บรรทัด 4401-4402

**จาก:**
```cpp
// v2.1.3: Reset Mini Group closed profit for NEW CYCLE
g_miniGroups[miniIndex].closedProfit = 0;
```

**เป็น:**
```cpp
// v2.1.5: Use dedicated reset function
ResetMiniGroupProfit(miniIndex);
```

---

### Flow หลังแก้ไข

```text
ตัวอย่าง 1: M3 ถึง Target $2000
├── CloseMiniGroup(2) ถูกเรียก
├── ResetMiniGroupProfit(2) → M3 = 0, targetTriggered = false
└── M1, M2 ไม่ถูกกระทบ ✅

ตัวอย่าง 2: Group 1 ถึง Target $4000
├── ResetGroupProfit(0) ถูกเรียก
│   ├── ResetMiniGroupProfit(0) → M1 = 0
│   ├── ResetMiniGroupProfit(1) → M2 = 0
│   ├── ResetMiniGroupProfit(2) → M3 = 0
│   └── Group 1 = 0
└── Group 2-5 ไม่ถูกกระทบ ✅

ตัวอย่าง 3: Total Basket ถึง Target $10000
├── Loop all Groups: ResetGroupProfit(grp)
│   ├── ResetGroupProfit(0) → M1,M2,M3 + G1 = 0
│   ├── ResetGroupProfit(1) → M4,M5,M6 + G2 = 0
│   ├── ResetGroupProfit(2) → M7,M8,M9 + G3 = 0
│   ├── ResetGroupProfit(3) → M10,M11,M12 + G4 = 0
│   └── ResetGroupProfit(4) → M13,M14,M15 + G5 = 0
├── g_accumulatedBasketProfit = 0
└── ALL reset ✅
```

---

### สรุปไฟล์และบรรทัดที่แก้ไข

| ไฟล์ | Function | บรรทัด (ประมาณ) | รายละเอียด |
|------|----------|-----------------|------------|
| `Harmony_Dream_EA.mq5` | ResetMiniGroupProfit() | ~1998 (ใหม่) | สร้าง function reset Mini Group |
| `Harmony_Dream_EA.mq5` | ResetGroupProfit() | 1988-1997 | เพิ่ม loop reset Mini Groups ก่อน reset Group |
| `Harmony_Dream_EA.mq5` | CloseMiniGroup() | ~4401 | ใช้ ResetMiniGroupProfit() แทน |

---

### Version Update

```cpp
#property version   "2.15"
#property description "v2.1.5: Hierarchical Basket Reset System (Mini→Group→Total)"
```

---

### ผลลัพธ์ที่คาดหวัง

Dashboard หลังแก้ไข:

| Event | M1 | M2 | M3 | Group 1 |
|-------|-----|-----|-----|---------|
| **เริ่มต้น** | $0 | $0 | $0 | $0 |
| **M3 ถึง $2000** | $500 | $300 | **$0** | $1003 |
| **Group 1 ถึง $4000** | **$0** | **$0** | **$0** | **$0** |

