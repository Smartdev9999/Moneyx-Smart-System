## ✅ แผนเพิ่ม: Reset Mini Group Trigger + ปุ่ม Close Mini Group (v2.1) - COMPLETED

### สรุปความต้องการ

1. **Reset Mini Group target trigger** เมื่อเปิด position ใหม่หลังจากปิดตาม target แล้ว
2. **เพิ่มปุ่ม Close Mini Group** สำหรับปิด positions ของ Mini Group เฉพาะตัวด้วยตนเอง

---

### ส่วนที่ต้องแก้ไข

#### 1. Reset Target Trigger เมื่อเปิด Position ใหม่

**ไฟล์:** `public/docs/mql5/Harmony_Dream_EA.mq5`

**ตำแหน่ง:** ฟังก์ชัน `OpenBuySideTrade()` (~บรรทัด 6880-6905)

**เพิ่ม:**
```cpp
// v2.1: Reset Mini Group target trigger when new position opened
int miniIdx = GetMiniGroupIndex(pairIndex);
if(g_miniGroups[miniIdx].targetTriggered)
{
   g_miniGroups[miniIdx].targetTriggered = false;
   PrintFormat("[v2.1] Mini Group %d target trigger RESET (new BUY position opened)", miniIdx + 1);
}
```

**ตำแหน่ง:** ฟังก์ชัน `OpenSellSideTrade()` (~บรรทัด 7080-7105)

**เพิ่มเหมือนกัน:**
```cpp
// v2.1: Reset Mini Group target trigger when new position opened
int miniIdx = GetMiniGroupIndex(pairIndex);
if(g_miniGroups[miniIdx].targetTriggered)
{
   g_miniGroups[miniIdx].targetTriggered = false;
   PrintFormat("[v2.1] Mini Group %d target trigger RESET (new SELL position opened)", miniIdx + 1);
}
```

---

#### 2. เพิ่มปุ่ม Close Mini Group บน Dashboard

**ตำแหน่ง:** ฟังก์ชัน `CreatePairRow()` (~บรรทัด 8545-8556)

**แก้ไข MINI GROUP Column:**
```cpp
// === v2.0: MINI GROUP COLUMN (Display every 2 pairs) ===
if(idx % PAIRS_PER_MINI == 0)
{
   int mIdx = idx / PAIRS_PER_MINI;
   string mIdxStr = IntegerToString(mIdx);
   string miniLabel = "M" + IntegerToString(mIdx + 1);
   
   // Row 1: Mini number + Float value + Closed value
   CreateLabel(prefix + "M" + mIdxStr + "_HDR", miniGroupX + 3, y + 3, miniLabel, COLOR_GOLD, 8, "Arial Bold");
   CreateLabel(prefix + "M" + mIdxStr + "_V_FLT", miniGroupX + 22, y + 3, "$0", COLOR_PROFIT, 7, "Arial");
   CreateLabel(prefix + "M" + mIdxStr + "_V_CL", miniGroupX + 52, y + 3, "$0", COLOR_PROFIT, 7, "Arial");
   
   // v2.1: Close Mini Group button (smaller X button)
   CreateButton(prefix + "_CLOSE_MINI_" + mIdxStr, miniGroupX + 75, y + 2, 12, 12, "X", clrRed, clrWhite);
}
```

---

#### 3. เพิ่ม Event Handler สำหรับปุ่ม Close Mini Group

**ตำแหน่ง:** ฟังก์ชัน `OnChartEvent()` (~บรรทัด 2663-2680)

**เพิ่มหลัง Close Group handler:**
```cpp
// v2.1: Close Mini Group button handler
else if(StringFind(sparam, prefix + "_CLOSE_MINI_") >= 0)
{
   int miniIdx = (int)StringToInteger(StringSubstr(sparam, StringLen(prefix + "_CLOSE_MINI_")));
   
   // Confirmation popup
   int startPair = miniIdx * PAIRS_PER_MINI + 1;
   int endPair = startPair + PAIRS_PER_MINI - 1;
   string msg = StringFormat("Close ALL orders in Mini Group %d (Pairs %d-%d)?", 
                             miniIdx + 1, startPair, endPair);
   int result = MessageBox(msg, "Confirm Close Mini Group", MB_YESNO | MB_ICONWARNING);
   if(result != IDYES)
   {
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      return;
   }
   
   CloseMiniGroup(miniIdx);
   ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
   PrintFormat("[v2.1] Manual Close Mini Group %d completed", miniIdx + 1);
}
```

---

### สรุปการเปลี่ยนแปลง

| ส่วน | รายละเอียด | บรรทัด (ประมาณ) |
|------|------------|-----------------|
| OpenBuySideTrade() | เพิ่ม reset trigger เมื่อเปิด BUY | ~6900 |
| OpenSellSideTrade() | เพิ่ม reset trigger เมื่อเปิด SELL | ~7080 |
| CreatePairRow() | เพิ่มปุ่ม X สำหรับ Close Mini Group | ~8550 |
| OnChartEvent() | เพิ่ม handler สำหรับ _CLOSE_MINI_ | ~2680 |

---

### Dashboard Layout ใหม่ (MINI GROUP Column)

```text
┌─────────────────────────────────────────────────┐
│           MINI GROUP (90px)                     │
├─────────────────────────────────────────────────┤
│ M1   $50     $0      [X]     ← Float/Closed/X   │
│                                                 │
│ M2   $30     $100    [X]                        │
│                                                 │
│ M3   $20     $0      [X]                        │
│                                                 │
└─────────────────────────────────────────────────┘
```

---

### Logic Flow (Reset Trigger)

```text
1. Mini Group M1 profit reaches target ($100)
   ↓
2. CheckMiniGroupTargets() triggers:
   - g_miniGroups[0].targetTriggered = true
   - CloseMiniGroup(0) executed
   ↓
3. Later: New position opened on Pair 1 or 2
   ↓
4. OpenBuySideTrade() or OpenSellSideTrade():
   - Check if targetTriggered == true
   - Reset to false
   - Log: "Mini Group 1 target trigger RESET"
   ↓
5. CheckMiniGroupTargets() can trigger again when target reached
```

---

### ข้อควรระวัง

1. **ปุ่ม X ขนาดเล็ก (12x12px)** เพื่อประหยัดพื้นที่ใน MINI GROUP column
2. **Confirmation Popup** ก่อนปิดทุกครั้ง เพื่อป้องกันการกดผิด
3. **Reset Trigger** เฉพาะเมื่อเปิด position ใหม่ใน Mini Group นั้นๆ เท่านั้น
4. **ไม่แตะต้อง** Order entry logic, Grid logic, Comment format อื่นๆ

---

### Version Update

```cpp
#property version   "2.10"
#property description "v2.1: Mini Group Close Button + Target Trigger Reset"
```
