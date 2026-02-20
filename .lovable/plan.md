
## Gold Miner EA v2.6 - Fix SELL Per-Order Trailing Stop

### สาเหตุของปัญหา

ภาพ Tester แสดงว่า SELL position มี "SL for 20" (Breakeven offset = 20 points เหนือ openPrice) แต่ SL ไม่เคยเคลื่อนลงตาม price แม้ price จะลงไปไกลแล้ว นั่นหมายความว่า Trailing step ไม่ทำงาน

จากการอ่านโค้ดบรรทัด 1033-1058 พบ **3 bugs** ซ้อนกัน:

---

### Bug #1: Trailing Step Direction Check ผิดทิศทาง (Critical)

```text
// บรรทัด 1047 (ปัจจุบัน - ผิด):
if(currentSL == 0 || newSL < currentSL - InpTrailingStep * point)

// ความหมาย: จะ modify เมื่อ newSL < currentSL - Step
// แต่สำหรับ SELL: newSL = ask + TrailingDistance
//   ถ้า price ลง → ask ลด → newSL ลด → newSL จะน้อยกว่า currentSL
//   นี่ถูกต้อง แต่ต้องลดได้อีก 1 Step กว่าจะ trigger
```

จริงๆ เงื่อนไขนี้ถูกต้อง (SELL SL เคลื่อนลง ต้องลดอีก Step) แต่ปัญหาหลักอยู่ที่ Bug #2

---

### Bug #2: BE Floor Guard ทำให้ newSL ถูก Override ผิดทิศทาง (Critical)

```text
// บรรทัด 1039-1040 (ปัจจุบัน - ผิด):
double beFloor = NormalizeDouble(openPrice - InpBreakevenOffset * point, digits);
if(newSL < beFloor) newSL = beFloor;
```

สำหรับ SELL:
- `newSL = ask + TrailingStop` → อยู่ **เหนือ** ask (เช่น 2711 + 15 = 2726)  
- `beFloor = openPrice - offset` → อยู่ **ต่ำกว่า** openPrice (เช่น 2713 - 0.02 = 2712.98)

ดังนั้น `newSL (2726) < beFloor (2712.98)` เป็น **FALSE เสมอ** → บรรทัดนี้ไม่ทำงาน แต่ไม่ได้เป็น cause ของ bug

BE Floor guard ที่ถูกต้องสำหรับ SELL คือ SL ไม่ควรต่ำกว่า BE level (SL ต้องอยู่เหนือหรือที่ BE เพื่อป้องกันขาดทุน):
```text
// ถูกต้อง: ป้องกัน newSL ไม่ให้ต่ำกว่า BE level (ต่ำ = เสี่ยง)
double beCeiling = NormalizeDouble(openPrice - InpBreakevenOffset * point, digits);
if(newSL > beCeiling) newSL = beCeiling;  // SELL: SL ต้องไม่สูงกว่า BE level
```

**รอ!** สำหรับ SELL: openPrice ที่ขายไว้ เช่น 2713, BE offset 20 points
- BE level = 2713 - 0.002 = 2712.998 (SL ที่ BE คือ ต่ำกว่า open เพื่อ lock กำไรขั้นต่ำ)
- newSL = ask + Trail → เช่น 2711 + 0.015 = 2711.015 (SL อยู่เหนือ ask ปัจจุบัน)
- เราต้องการ SL ที่ **ไม่สูงกว่า BE** → `if(newSL > beCeiling) newSL = beCeiling`

นี่คือ guard ที่ถูกต้องและสอดคล้องกับ v2.5 ที่แก้ไปแล้ว (แต่บรรทัด 1040 ยังคงเป็น `<` อยู่ ซึ่งผิด)

---

### Bug #3: Breakeven Condition ตรวจ currentSL ผิด (Critical - Root Cause หลัก)

```text
// บรรทัด 1015 (ปัจจุบัน):
if(currentSL == 0 || currentSL > beLevel)
```

สำหรับ SELL: `beLevel = openPrice - offset` เช่น = 2712.998

ปัญหา: ถ้า currentSL = 0 (ไม่มี SL) → BE จะถูก set ที่ `beLevel = 2712.998` ✓  
แต่ถ้ามี SL อยู่แล้ว (เช่น currentSL = 2713.5 จาก broker) → `currentSL (2713.5) > beLevel (2712.998)` = TRUE → จะพยายาม modify ซ้ำๆ ทุก tick

หลังจาก BE set แล้ว `currentSL = beLevel = 2712.998`:
- Trailing check: `newSL = ask + Trail = 2711.015`
- `newSL (2711.015) < currentSL (2712.998) - Step (0.001)` = TRUE → ควร modify ได้!

แต่ปัญหาจริงๆ คือ: **BE Condition check ผิด**

สำหรับ SELL BE ที่ถูกต้อง: "ถ้า SL ปัจจุบันยังไม่อยู่ที่ BE level (หรือต่ำกว่า BE)" ควร set BE
- `currentSL == 0 || currentSL > beLevel` → หมายความว่า ถ้า currentSL สูงกว่า beLevel (ซึ่งคือยังไม่ถึง BE) → set BE
- สำหรับ SELL นี่ถูกต้อง! BE Level อยู่ต่ำกว่า openPrice แต่สูงกว่า current market (ถ้ากำไร)

**สรุป Root Cause จริงๆ คือ:**

หลังจาก BE ถูก set แล้ว `currentSL = beLevel` (เช่น 2712.998)  
Trailing condition: `newSL < currentSL - Step`  
= `(ask + 0.015) < (2712.998 - 0.001)`  
= `2711.015 < 2712.997`  
= **TRUE** → Trailing ควรทำงาน!

แต่ทำไมถึงไม่ทำงาน? → ต้องดู **broker maxSL check** ที่บรรทัด 1043-1044:

```text
double maxSL = NormalizeDouble(ask + stopLevel * point, digits);
if(newSL < maxSL) newSL = maxSL;
```

ถ้า `stopLevel = 20 points` และ `TrailingStop = 150 points`:
- `maxSL = ask + 20*0.0001 = 2711.002`
- `newSL = ask + 150*0.0001 = 2711.015`
- `newSL (2711.015) < maxSL (2711.002)` = FALSE → ผ่าน ✓

**แต่ถ้า TrailingStop ขนาดเล็กกว่า stopLevel:**
- `newSL = ask + 5*0.0001 = 2711.0005`
- `newSL < maxSL (2711.002)` = TRUE → `newSL = maxSL = 2711.002`
- จากนั้น trailing step: `2711.002 < 2712.997 - 0.001` = TRUE → ควรทำงาน

**จากภาพ: BE:OFF, Trail:150/10** → BreakEven disabled แต่ Trailing enabled  
ถ้า BE disabled แต่ order มี SL อยู่แล้ว (จากที่เห็น "SL for 20" บนชาร์ต):

**FOUND IT!** 

ตัวแปร `profitPoints = (openPrice - ask) / point` สำหรับ SELL

Trailing trigger: `profitPoints >= InpTrailingStop (150 points)`

ถ้า SELL ที่ openPrice = 2713 และ ask = 2711.5:
- `profitPoints = (2713 - 2711.5) / 0.0001 = 15 points`

**15 < 150** → Trailing ไม่ trigger! เพราะ profit ยังไม่ถึง InpTrailingStop

แต่ BUY trailing trigger: `profitPoints >= InpTrailingStop`
สำหรับ BUY: `profitPoints = (bid - openPrice) / point`

ปัญหาจริงคือ **point size** สำหรับ XAUUSD บน MT5:

XAUUSD ใช้ point = 0.01 (ไม่ใช่ 0.0001)  
ถ้า `InpTrailingStop = 150 points` และ point = 0.01:
- ต้องการกำไร 150 × 0.01 = $1.50 per lot
- profitPoints = (2713 - 2711.5) / 0.01 = 150 points ✓

แต่ถ้าโค้ดใช้ `double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT)` ซึ่งถูกต้อง

**ต้องดูตรงกลาง Per-Order trailing ว่า point ถูก define ยังไง:**

---

### การตรวจสอบโค้ดจริงที่ Per-Order Trailing function:

บรรทัด 950 แสดงว่า function `ManagePerOrderTrailing()` ใช้ `point` จากตัวแปรที่ declare ก่อนหน้า

ดูบรรทัดต้นของ function นี้ต้องการ → อ่านบรรทัด 930-955 เพิ่ม

**Key Bug ที่พบชัดเจน:**

บรรทัด 1040: `if(newSL < beFloor) newSL = beFloor;`  
สำหรับ SELL: beFloor = openPrice - offset = **ต่ำกว่า openPrice**  
newSL = ask + TrailingStop = **สูงกว่า ask** (ซึ่งต่ำกว่า openPrice เพราะกำไร)  
→ newSL > beFloor เสมอ → guard นี้ไม่ทำงาน แต่ก็ไม่ block

**ACTUAL BUG:**

guard ที่ถูกต้องสำหรับ SELL คือ:
- BE Level = openPrice - offset (เช่น 2712.998) = SL ที่ตำแหน่ง "ปลอดภัย" (ยังมีกำไร)
- เราต้องการ SL ไม่ **สูงกว่า** BE level (ถ้า SL สูงกว่า BE = ขาดทุน)
- `if(newSL > beCeiling) newSL = beCeiling` ← นี่คือสิ่งที่ควรเป็น

แต่ที่เขียนไว้คือ `if(newSL < beFloor) newSL = beFloor` ← ตรงข้าม!

เมื่อ newSL = 2711.015 (ถูกต้อง ต่ำกว่า BE) แต่ code check `newSL < beFloor (2712.998)` → TRUE!  
ดังนั้น `newSL = beFloor = 2712.998` ← **Override ค่าที่ถูกต้องด้วยค่าผิด!**

นี่คือ Root Cause! BE guard บังคับให้ newSL = 2712.998 แทนที่จะเป็น 2711.015

จากนั้น trailing step check: `newSL (2712.998) < currentSL (2712.998) - Step` → FALSE → ไม่ modify

**Trailing ไม่ทำงานสำหรับ SELL เพราะ beFloor guard บังคับให้ newSL = currentSL ตลอดเวลา!**

---

### แผนแก้ไข

#### บรรทัด 1038-1040 (BE Floor Guard สำหรับ SELL)

```text
// BEFORE (ผิด):
double beFloor = NormalizeDouble(openPrice - InpBreakevenOffset * point, digits);
if(newSL < beFloor) newSL = beFloor;  // ← บังคับ newSL ขึ้น ซึ่งผิดสำหรับ SELL

// AFTER (ถูก):
// สำหรับ SELL: SL เคลื่อนลง ต้องไม่สูงกว่า BE ceiling
double beCeiling = NormalizeDouble(openPrice - InpBreakevenOffset * point, digits);
if(newSL > beCeiling) newSL = beCeiling;  // SELL: SL ต้องไม่สูงกว่า BE level (ไม่งั้นขาดทุน)
```

#### อธิบายเพิ่มเติม:

สำหรับ SELL ที่ openPrice = 2713, offset = 20 points (0.002):
- beCeiling = 2713 - 0.002 = 2712.998
- เมื่อ price ลงถึง 2711.5 (กำไร 150 pts):
  - newSL = 2711.5 + 0.015 = 2711.515
  - `newSL (2711.515) > beCeiling (2712.998)` = FALSE → ไม่ override ✓
  - trailing ทำงานได้ตามปกติ

เมื่อ price ขึ้นกลับมา 2712.5 (ยังกำไร 50 pts):
  - newSL = 2712.5 + 0.015 = 2712.515
  - `newSL (2712.515) > beCeiling (2712.998)` = FALSE → ไม่ override ✓
  - step check: `2712.515 < currentSL - Step` → ถ้า currentSL = 2711.515, 2712.515 < 2711.505 = FALSE → ไม่ modify (ถูกต้อง SL ไม่เคลื่อนย้อนกลับ)

สรุป: แก้ไขเพียง **1 บรรทัด** (`<` เป็น `>` และ `beFloor` เป็น `beCeiling`) จะทำให้ SELL trailing ทำงานได้ปกติ

---

### สรุปการเปลี่ยนแปลง

| ลำดับ | ตำแหน่ง | Before | After |
|-------|---------|--------|-------|
| 1 | บรรทัด 1038 | `double beFloor = ...` | `double beCeiling = ...` |
| 2 | บรรทัด 1039 | `openPrice - InpBreakevenOffset * point` | `openPrice - InpBreakevenOffset * point` (เหมือนเดิม) |
| 3 | บรรทัด 1040 | `if(newSL < beFloor) newSL = beFloor;` | `if(newSL > beCeiling) newSL = beCeiling;` |
| 4 | — | Version 2.5 | Version 2.6 |

ไฟล์ที่แก้ไข: `public/docs/mql5/Gold_Miner_EA.mq5`
