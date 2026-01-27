

## แผนแก้ไข Total Basket Accumulation Bug - Harmony Dream EA v1.8.7 (Hotfix 2)

### สรุปปัญหาที่พบ (2 ปัญหา):

#### ปัญหาที่ 1: Total Target แสดงค่า 100 แทนค่าที่ตั้งไว้
- Dashboard แสดง `g_totalTarget = 100` (default)
- แต่ Logic ใช้ `InpTotalBasketTarget` (10,000 หรือ 50,000 ที่ผู้ใช้ตั้ง)

#### ปัญหาที่ 2: Total Basket Reset เมื่อ Group ปิด (ปัญหาหลัก)
**สาเหตุ:**
1. เมื่อ Group 5 ถึง Target → เรียก `ResetGroupProfit(5)`
2. `ResetGroupProfit(5)` set `g_groups[5].closedProfit = 0`
3. ใน `CheckTotalTarget()` ทุก tick: `g_basketClosedProfit` คำนวณจากผลรวมของ `g_groups[g].closedProfit` ทุก group
4. เมื่อ Group 5 ถูก reset → Total Basket สูญเสียกำไรที่ปิดไปแล้ว

**พฤติกรรมที่ผู้ใช้ต้องการ:**
- เมื่อ Group 5 ปิด → กำไรควรถูก **สะสม** ไว้ใน Total Basket
- Total Basket ควร trigger Close All เมื่อกำไรสะสมถึง Total Target
- ไม่ใช่ Reset พร้อมกับ Group

---

### แนวทางแก้ไข:

#### 1. เพิ่มตัวแปร Global สำหรับเก็บกำไรสะสม

**ตำแหน่ง:** หลังบรรทัด 813 (หลัง `g_basketTotalProfit`)

```text
// v1.8.7 HF2: Accumulated profit from groups that have already closed their targets
double g_accumulatedBasketProfit = 0;   // Preserved when individual group closes
```

---

#### 2. แก้ไข CheckTotalTarget() - เก็บกำไรสะสมก่อน Reset

**ตำแหน่ง:** บรรทัด 7556-7562

**เดิม:**
```text
// Reset this group's profit
PrintFormat(">>> GROUP %d RESET: Previous Closed %.2f | New: 0.00 <<<",
            g + 1, g_groups[g].closedProfit);
ResetGroupProfit(g);
```

**แก้ไขเป็น:**
```text
// v1.8.7 HF2: Accumulate this group's closed profit to basket BEFORE reset
double groupRealizedProfit = g_groups[g].closedProfit + g_groups[g].floatingProfit;
g_accumulatedBasketProfit += groupRealizedProfit;

PrintFormat(">>> GROUP %d REALIZED: $%.2f | Accumulated Basket: $%.2f <<<",
            g + 1, groupRealizedProfit, g_accumulatedBasketProfit);
PrintFormat(">>> GROUP %d RESET: Previous Closed %.2f | New: 0.00 <<<",
            g + 1, g_groups[g].closedProfit);
ResetGroupProfit(g);
```

---

#### 3. แก้ไข CheckTotalTarget() - คำนวณ Total Basket รวม Accumulated

**ตำแหน่ง:** บรรทัด 7454

**เดิม:**
```text
g_basketTotalProfit = g_basketClosedProfit + g_basketFloatingProfit;
```

**แก้ไขเป็น:**
```text
// v1.8.7 HF2: Include accumulated profit from already-closed groups
g_basketTotalProfit = g_accumulatedBasketProfit + g_basketClosedProfit + g_basketFloatingProfit;
```

---

#### 4. แก้ไข Total Basket Close - Reset Accumulated หลังปิดทุก Group

**ตำแหน่ง:** บรรทัด 7484-7488 (หลัง loop ปิดทุก Group)

**เพิ่ม:**
```text
// v1.8.7 HF2: Reset accumulated basket after closing all groups
g_accumulatedBasketProfit = 0;
PrintFormat(">>> TOTAL BASKET RESET: Accumulated = 0 <<<");
```

---

#### 5. แก้ไข CloseGroupOrders() (Manual Close) - สะสมกำไรก่อน Reset

**ตำแหน่ง:** บรรทัด 7601-7602

**เดิม:**
```text
// Reset group's profit after manual close
ResetGroupProfit(groupIdx);
```

**แก้ไขเป็น:**
```text
// v1.8.7 HF2: Accumulate this group's profit before reset
double groupRealizedProfit = g_groups[groupIdx].closedProfit + g_groups[groupIdx].floatingProfit;
g_accumulatedBasketProfit += groupRealizedProfit;
PrintFormat(">>> GROUP %d MANUAL CLOSE: Realized $%.2f | Accumulated: $%.2f <<<",
            groupIdx + 1, groupRealizedProfit, g_accumulatedBasketProfit);

// Reset group's profit after manual close
ResetGroupProfit(groupIdx);
```

---

#### 6. แก้ไข Dashboard Display - แสดง Total Target ถูกต้อง

**ตำแหน่ง CreateAccountSummary():** บรรทัด ~7965

**เดิม:**
```text
CreateEditField(prefix + "_TOTAL_TARGET", box1X + 230, y + 38, 50, 16, DoubleToString(g_totalTarget, 0));
```

**แก้ไขเป็น:**
```text
// v1.8.7 HF2: Show InpTotalBasketTarget value (user-defined)
double displayTarget = InpEnableTotalBasket ? InpTotalBasketTarget : g_totalTarget;
CreateEditField(prefix + "_TOTAL_TARGET", box1X + 230, y + 38, 60, 16, DoubleToString(displayTarget, 0));
```

---

#### 7. แก้ไข UpdateDashboard() - แสดง Basket รวม Accumulated

**ตำแหน่ง:** บรรทัด ~8199-8206

**เดิม:**
```text
// v3.6.0 HF2: Show Basket info instead of floating P/L
double basketNeed = g_totalTarget - g_basketClosedProfit;
if(basketNeed < 0) basketNeed = 0;

// If Basket Target is enabled, show Basket Closed; otherwise show Floating P/L
if(g_totalTarget > 0)
{
   UpdateLabel(prefix + "V_TPL", DoubleToString(g_basketClosedProfit, 2), g_basketClosedProfit >= 0 ? COLOR_PROFIT : COLOR_LOSS);
```

**แก้ไขเป็น:**
```text
// v1.8.7 HF2: Show Basket including accumulated profit from closed groups
double displayBasket = g_accumulatedBasketProfit + g_basketClosedProfit;
double displayTarget = InpEnableTotalBasket ? InpTotalBasketTarget : g_totalTarget;
double basketNeed = displayTarget - displayBasket;
if(basketNeed < 0) basketNeed = 0;

// If Basket Target is enabled, show Basket (with accumulated); otherwise show Floating P/L
if(displayTarget > 0)
{
   UpdateLabel(prefix + "V_TPL", DoubleToString(displayBasket, 2), displayBasket >= 0 ? COLOR_PROFIT : COLOR_LOSS);
```

---

#### 8. อัพเดท OnInit() - Sync g_totalTarget (Optional)

**ตำแหน่ง:** หลัง InitializeThemeColors() (~line 858)

```text
// v1.8.7 HF2: Sync g_totalTarget with InpTotalBasketTarget if enabled
if(InpEnableTotalBasket && InpTotalBasketTarget > 0)
{
   g_totalTarget = InpTotalBasketTarget;
}
```

---

### สรุปไฟล์ที่ต้องแก้ไข:

| ไฟล์ | การเปลี่ยนแปลง |
|------|----------------|
| `public/docs/mql5/Harmony_Dream_EA.mq5` | 1) เพิ่ม g_accumulatedBasketProfit 2) แก้ CheckTotalTarget() 3) แก้ CloseGroupOrders() 4) แก้ CreateAccountSummary() 5) แก้ UpdateDashboard() 6) Sync OnInit() |

---

### สิ่งที่ไม่แตะต้อง:

- Trading Logic (Entry/Exit conditions)
- ADX / CDC / Correlation Calculation
- Grid Distance และ Lot Sizing Logic
- License System
- Theme System

---

### ผลลัพธ์ที่คาดหวัง:

**Scenario (เหมือนในภาพ):**
1. Group 4 เปิด: Float $8603
2. Group 5 เปิด: Float -$405, Target $2000 → ถึงเป้าหมาย → ปิด → กำไร $2000 สะสมเข้า Accumulated
3. Total Basket = $0 (เดิม) + $2000 (จาก Group 5) = **$2000** ← แสดงค่านี้
4. Group 4 ยังเปิดอยู่: Float $8603
5. เมื่อ Group 4 ปิด: Total Basket = $2000 + $8603 = $10,603 → ถ้า >= Total Target → ปิดทุกอย่าง

**Dashboard Display:**
- Total Target: **50,000** (จาก InpTotalBasketTarget)
- Basket: **$10,603** (Accumulated + Current Closed)

