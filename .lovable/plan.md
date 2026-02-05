
## แผนแก้ไข v2.3.4 HF1: ปรับปรุง Dashboard Layout และลด Log ที่ไม่จำเป็น

---

### สรุปปัญหาจากรูปภาพ

| ปัญหา | รายละเอียด |
|-------|-----------|
| **1. Log ATR วิ่งตลอดเวลา** | `[v2.2.9 GRID ATR] Pair X GL/GP Lv0 [PROG]` แสดงทุกครั้งที่มีการตรวจสอบ Grid |
| **2. Trend ทับ Pair** | ชื่อ Pair ยาว (เช่น "EURJPY.v-CADJPY.v") ยังชนกับ Trend column |

---

### สาเหตุ

**ปัญหา 1 - Log ATR เยอะ:**
- Function `CalculateGridDistance()` ถูกเรียกทุก Tick เพื่อตรวจสอบว่าควรเปิด Grid หรือไม่
- แต่ Debug log แสดงทุกครั้งที่เรียก (ไม่ใช่แค่ตอน ATR Cache อัปเดต)
- H1 Timeframe ไม่ควรต้อง Log ทุก Tick เพราะ ATR ไม่เปลี่ยนจนกว่าจะมี New Bar

**ปัญหา 2 - Dashboard Layout:**
- ปัจจุบัน centerWidth = 390px
- Pair names อยู่ที่ centerX + 10
- Trend column อยู่ที่ centerX + 175 (แค่ 165px จาก Pair)
- ชื่อ Pair ยาว 20 ตัวอักษร ("EURJPY.v-CADJPY.v") ใช้พื้นที่ ~160px → ทับกัน

---

### โซลูชัน

#### Part A: ลด Log ใน CalculateGridDistance()

**บรรทัด 7262-7269:**

**เปลี่ยนจาก:**
```cpp
// v2.2.9: Debug log with scaling info
if(InpDebugMode && (!g_isTesterMode || !InpDisableDebugInTester))
{
   string scaleStr = (scaleMode == GRID_SCALE_PROGRESSIVE) ? "PROG" : "FIXED";
   PrintFormat("[v2.2.9 GRID ATR] Pair %d %s Lv%d [%s]: Base=%.1f pips...",
               pairIndex + 1, isProfitSide ? "GP" : "GL", gridLevel, scaleStr, ...);
}
```

**เป็น (v2.3.4 HF1):**
```cpp
// v2.3.4 HF1: Only log ATR on NEW BAR (not every grid check)
// This log is now in UpdateATRCache() which runs once per bar
// Remove debug log here to prevent excessive logging every tick
```

**หมายเหตุ:** Log ใน `UpdateATRCache()` (บรรทัด 7444-7450) ยังคงอยู่ → จะแสดงเฉพาะตอน ATR Cache อัปเดต (1 ครั้งต่อ Bar)

---

#### Part B: ขยาย Dashboard Layout

**เพิ่ม centerWidth และขยับ Columns:**

| Column | ก่อน | หลัง | เปลี่ยนแปลง |
|--------|------|------|-------------|
| centerWidth | 390px | **430px** | +40px |
| Pair | +10 | +10 | เท่าเดิม |
| Trend | +175 | **+195** | +20px |
| C-% | +235 | **+255** | +20px |
| Type | +285 | **+305** | +20px |
| Tot P/L | +345 | **+365** | +20px |

**ไฟล์ที่แก้ไข:**

1. **บรรทัด 9812** - เพิ่ม centerWidth:
```cpp
int centerWidth = 430;  // v2.3.4 HF1: Increased from 390 to 430
```

2. **บรรทัด 9879-9882** - Header columns:
```cpp
CreateLabel(prefix + "COL_C_TRD", centerX + 195, colLabelY, "Trend", ...);
CreateLabel(prefix + "COL_C_CR", centerX + 255, colLabelY, "C-%", ...);
CreateLabel(prefix + "COL_C_TY", centerX + 305, colLabelY, "Type", ...);
CreateLabel(prefix + "COL_C_TP", centerX + 365, colLabelY, "Tot P/L", ...);
```

3. **บรรทัด 9970-9973** - Data rows (CreatePairRow):
```cpp
CreateLabel(prefix + "P" + idxStr + "_CDC", centerX + 195, y + 3, "-", ...);
CreateLabel(prefix + "P" + idxStr + "_CORR", centerX + 255, y + 3, "0%", ...);
CreateLabel(prefix + "P" + idxStr + "_TYPE", centerX + 305, y + 3, "Pos", ...);
CreateLabel(prefix + "P" + idxStr + "_TOTAL", centerX + 365, y + 3, "0.00", ...);
```

---

### สรุปการแก้ไขทั้งหมด

| ลำดับ | ส่วน | การแก้ไข |
|------|------|---------|
| 1 | `CalculateGridDistance()` | **ลบ** Debug log ออกเพื่อไม่ให้ Log ทุก Tick |
| 2 | `centerWidth` | เพิ่มจาก 390 → 430 |
| 3 | Header columns | ขยับ Trend, C-%, Type, Tot P/L ไปทางขวา +20px |
| 4 | Data rows | ขยับ _CDC, _CORR, _TYPE, _TOTAL ตาม Header |

---

### ผลลัพธ์ที่คาดหวัง

**Log หลังแก้ไข:**
- ATR Log จะแสดงเฉพาะตอน New Bar (1 ครั้งต่อ H1 = 1 ครั้ง/ชั่วโมง)
- ไม่มี Log วิ่งทุกวินาทีอีกต่อไป

**Dashboard หลังแก้ไข:**
```
 Pair                      Trend   C-%   Type   Tot P/L
 1. EURJPY.v-CADJPY.v      Up      85%   Pos    +1.23
```
- ระยะห่างระหว่าง Pair name กับ Trend เพิ่มจาก 165px → 185px
- ไม่มีข้อความทับกันอีก

---

### ไฟล์ที่แก้ไข

`public/docs/mql5/Harmony_Dream_EA.mq5` เท่านั้น
