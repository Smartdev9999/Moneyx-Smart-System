

## แผนแก้ไข: Mini Group Profit Accumulation Fix (v2.1.3)

### สรุปปัญหา

เมื่อ **คู่เดียว** (Individual Pair) ถึง target ของตัวเองแล้วปิด:
- กำไรถูกบวกเข้า **Group closedProfit** เท่านั้น
- แต่ **ไม่ได้บวกเข้า Mini Group closedProfit**
- ทำให้ Mini Group dashboard แสดง Closed = $0 ตลอด

### Logic ที่ต้องการ

```text
Pair 5 (อยู่ใน M3) ปิดกำไร $1000:
┌───────────────────────────────────────────────────────┐
│ 1. CloseBuySide(4) / CloseSellSide(4) ถูกเรียก        │
│                                                       │
│ 2. บวก profit เข้า:                                    │
│    ├─ g_pairs[4].closedProfitBuy += $1000 (เดิม)      │
│    ├─ g_groups[groupIdx].closedProfit += $1000 (เดิม)│
│    └─ g_miniGroups[miniIdx].closedProfit += $1000 ← ใหม่! │
│                                                       │
│ 3. Mini Group M3 dashboard แสดง Closed = $1000        │
│                                                       │
│ 4. ถ้า M3 total (closed + floating) >= 2000           │
│    → CloseMiniGroup(2) ถูก trigger                    │
│    → Reset M3.closedProfit = 0                        │
│    → โอน profit ไป Group                              │
└───────────────────────────────────────────────────────┘
```

---

### ส่วนที่ต้องแก้ไข

#### 1. แก้ไข CloseBuySide() - บรรทัด 7211-7218

**จาก:**
```cpp
// v1.1: Add to GROUP instead of global basket (unless group is closing all)
if(!g_groups[groupIdx].closeMode)
{
   g_groups[groupIdx].closedProfit += g_pairs[pairIndex].profitBuy;
   PrintFormat("GROUP %d: Added %.2f from Pair %d BUY | Group Total: %.2f | Target: %.2f",
               groupIdx + 1, g_pairs[pairIndex].profitBuy, pairIndex + 1, 
               g_groups[groupIdx].closedProfit, g_groups[groupIdx].closedTarget);
}
```

**เป็น:**
```cpp
// v2.1.3: Add to MINI GROUP for basket accumulation
int miniIdx = GetMiniGroupIndex(pairIndex);
if(!g_miniGroups[miniIdx].targetTriggered)
{
   g_miniGroups[miniIdx].closedProfit += g_pairs[pairIndex].profitBuy;
   PrintFormat("MINI GROUP %d: Added $%.2f from Pair %d BUY | Mini Total: $%.2f | Target: $%.2f",
               miniIdx + 1, g_pairs[pairIndex].profitBuy, pairIndex + 1, 
               g_miniGroups[miniIdx].closedProfit, g_miniGroups[miniIdx].closedTarget);
}

// v1.1: Also add to GROUP for Group-level tracking (unless group is closing all)
if(!g_groups[groupIdx].closeMode)
{
   g_groups[groupIdx].closedProfit += g_pairs[pairIndex].profitBuy;
   PrintFormat("GROUP %d: Added $%.2f from Pair %d BUY | Group Total: $%.2f | Target: $%.2f",
               groupIdx + 1, g_pairs[pairIndex].profitBuy, pairIndex + 1, 
               g_groups[groupIdx].closedProfit, g_groups[groupIdx].closedTarget);
}
```

---

#### 2. แก้ไข CloseSellSide() - บรรทัด 7335-7342

**จาก:**
```cpp
// v1.1: Add to GROUP instead of global basket (unless group is closing all)
if(!g_groups[groupIdx].closeMode)
{
   g_groups[groupIdx].closedProfit += g_pairs[pairIndex].profitSell;
   PrintFormat("GROUP %d: Added %.2f from Pair %d SELL | Group Total: %.2f | Target: %.2f",
               groupIdx + 1, g_pairs[pairIndex].profitSell, pairIndex + 1, 
               g_groups[groupIdx].closedProfit, g_groups[groupIdx].closedTarget);
}
```

**เป็น:**
```cpp
// v2.1.3: Add to MINI GROUP for basket accumulation
int miniIdx = GetMiniGroupIndex(pairIndex);
if(!g_miniGroups[miniIdx].targetTriggered)
{
   g_miniGroups[miniIdx].closedProfit += g_pairs[pairIndex].profitSell;
   PrintFormat("MINI GROUP %d: Added $%.2f from Pair %d SELL | Mini Total: $%.2f | Target: $%.2f",
               miniIdx + 1, g_pairs[pairIndex].profitSell, pairIndex + 1, 
               g_miniGroups[miniIdx].closedProfit, g_miniGroups[miniIdx].closedTarget);
}

// v1.1: Also add to GROUP for Group-level tracking (unless group is closing all)
if(!g_groups[groupIdx].closeMode)
{
   g_groups[groupIdx].closedProfit += g_pairs[pairIndex].profitSell;
   PrintFormat("GROUP %d: Added $%.2f from Pair %d SELL | Group Total: $%.2f | Target: $%.2f",
               groupIdx + 1, g_pairs[pairIndex].profitSell, pairIndex + 1, 
               g_groups[groupIdx].closedProfit, g_groups[groupIdx].closedTarget);
}
```

---

#### 3. แก้ไข CloseMiniGroup() - ป้องกันการบวกซ้ำ

เนื่องจาก profit ถูกบวกเข้า Mini Group แล้วตอนปิดคู่ เราต้องป้องกันไม่ให้ `CloseMiniGroup()` บวก profit ซ้ำอีกรอบ

**ตำแหน่ง:** บรรทัด 4381-4396

**จาก:**
```cpp
for(int p = startPair; p < startPair + PAIRS_PER_MINI && p < MAX_PAIRS; p++)
{
   if(!g_pairs[p].enabled) continue;
   
   // Track profit before closing
   double pairProfit = g_pairs[p].profitBuy + g_pairs[p].profitSell;
   
   // Close Buy side
   if(g_pairs[p].directionBuy == 1)
   {
      closedProfit += g_pairs[p].profitBuy;
      CloseBuySide(p);
   }
   
   // Close Sell side
   if(g_pairs[p].directionSell == 1)
   {
      closedProfit += g_pairs[p].profitSell;
      CloseSellSide(p);
   }
}
```

**เป็น:**
```cpp
for(int p = startPair; p < startPair + PAIRS_PER_MINI && p < MAX_PAIRS; p++)
{
   if(!g_pairs[p].enabled) continue;
   
   // Close Buy side (profit is added to Mini Group inside CloseBuySide)
   if(g_pairs[p].directionBuy == 1)
   {
      CloseBuySide(p);
   }
   
   // Close Sell side (profit is added to Mini Group inside CloseSellSide)
   if(g_pairs[p].directionSell == 1)
   {
      CloseSellSide(p);
   }
}

// v2.1.3: Use accumulated closed profit from Mini Group (already updated by CloseBuySide/CloseSellSide)
double closedProfitTotal = g_miniGroups[miniIndex].closedProfit;
```

---

#### 4. อัปเดต CloseMiniGroup() - ใช้ closedProfit ที่สะสมไว้แล้ว

**ตำแหน่ง:** บรรทัด 4399-4406

**จาก:**
```cpp
// v2.1.2: Add closed profit to PARENT GROUP (for Group tracking)
g_groups[groupIdx].closedProfit += closedProfit;

// v2.1.2: Reset Mini Group closed profit for NEW CYCLE
g_miniGroups[miniIndex].closedProfit = 0;

PrintFormat("[v2.1.2] Mini Group %d TARGET CLOSED | Profit: $%.2f → Group %d | Mini RESET to $0",
            miniIndex + 1, closedProfit, groupIdx + 1);
```

**เป็น:**
```cpp
// v2.1.3: Get total accumulated closed profit from Mini Group
double finalClosedProfit = g_miniGroups[miniIndex].closedProfit;

// v2.1.3: Note - profit was already added to Group via CloseBuySide/CloseSellSide
// No need to add again here to avoid double-counting

// v2.1.3: Reset Mini Group closed profit for NEW CYCLE
g_miniGroups[miniIndex].closedProfit = 0;

PrintFormat("[v2.1.3] Mini Group %d TARGET CLOSED | Accumulated: $%.2f | Mini RESET to $0 for new cycle",
            miniIndex + 1, finalClosedProfit);
```

---

### Flow ใหม่หลังแก้ไข

```text
ตัวอย่าง: M3 มี Pair 5 และ Pair 6 | Target = $2000

ขั้นตอนที่ 1: Pair 5 ถึง target $1000 แล้วปิด
├─ CloseSellSide(4) ถูกเรียก
├─ บวก $1000 → g_miniGroups[2].closedProfit (M3)
├─ บวก $1000 → g_groups[1].closedProfit (Group 2)
└─ Dashboard: M3 Closed = $1000 ✓

ขั้นตอนที่ 2: Pair 6 ยังเปิดอยู่ Floating = $300
├─ UpdateMiniGroupProfits() คำนวณ:
│   M3.floatingProfit = $300
│   M3.totalProfit = $1000 + $300 = $1300
└─ Dashboard: M3 Float = $300, Closed = $1000 ✓

ขั้นตอนที่ 3: M3 total ถึง $2000
├─ CheckMiniGroupTargets() trigger
├─ CloseMiniGroup(2) ถูกเรียก
├─ ปิด Pair 5, Pair 6 (ถ้ายังเปิด)
├─ Reset M3.closedProfit = 0
└─ Dashboard: M3 Closed = $0 (เริ่มรอบใหม่) ✓
```

---

### สรุปไฟล์และบรรทัดที่แก้ไข

| ไฟล์ | Function | บรรทัด (ประมาณ) | รายละเอียด |
|------|----------|-----------------|------------|
| `Harmony_Dream_EA.mq5` | CloseBuySide() | 7211-7218 | เพิ่มการบวก profit เข้า Mini Group |
| `Harmony_Dream_EA.mq5` | CloseSellSide() | 7335-7342 | เพิ่มการบวก profit เข้า Mini Group |
| `Harmony_Dream_EA.mq5` | CloseMiniGroup() | 4381-4406 | ลบการบวก closedProfit ซ้ำ, ใช้ค่าที่สะสมไว้แล้ว |

---

### Version Update

```cpp
#property version   "2.13"
#property description "v2.1.3: Mini Group Profit Accumulation Fix - Individual Pair Close"
```

