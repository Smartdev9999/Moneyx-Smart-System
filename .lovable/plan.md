
## Gold Miner EA v2.5 - Fix "Unknown Position Closure" Bug

### สาเหตุที่แท้จริงของการปิดออเดอร์โดยไม่ทราบสาเหตุ

จากการวิเคราะห์ภาพ Journal Log และโค้ด พบ **3 สาเหตุ** ที่ทำให้ระบบปิดออเดอร์ทั้งที่ยังติดลบและ EA หยุดทำงาน:

---

### Bug #1: SL Dollar ทำงานต่อให้กับ TP Basket (Critical)

**ปัญหา:** `ManageTPSL()` มี SL check ที่ทำงานแยกกับ Per-Order Trailing อย่างสมบูรณ์ แต่ TP check มี guard `if(!EnablePerOrderTrailing)` ขณะที่ **SL check ไม่มี guard นี้**

```text
// TP Check (CORRECT - has guard)
if(!EnablePerOrderTrailing)
{
   if(UseTP_Dollar && plBuy >= TP_DollarAmount) closeTP = true;
}

// SL Check (BUG - no guard!)
if(EnableSL)
{
   if(UseSL_Dollar && plBuy <= -SL_DollarAmount) closeSL = true;  // <-- fires even with Per-Order trailing ON
}
```

เมื่อใช้ Per-Order Trailing (ปิดออเดอร์แต่ละตัวผ่าน SL ที่ broker) กับ Grid system ที่มีหลายออเดอร์สะสมอยู่ floating loss รวมอาจเกิน `SL_DollarAmount = $50` ทำให้ `ManageTPSL()` ปิดออเดอร์ทั้งหมดโดยที่ผู้ใช้ไม่ได้ตั้งใจ

**หลักฐานจาก Journal:** บรรทัด log แสดงการปิดออเดอร์หลายตัวพร้อมกันในเวลาเดียวกัน ซึ่งเป็น pattern ของ `CloseAllSide()` ไม่ใช่ broker-side SL

**วิธีแก้:**

```text
// SL check ต้องมี guard เช่นเดียวกับ TP check
// เมื่อ EnablePerOrderTrailing = true ควร skip basket SL
// เพราะ Per-Order Trailing จะดูแลการปิดออเดอร์แต่ละตัวผ่าน broker SL

if(EnableSL && !EnablePerOrderTrailing)  // <-- ADD guard
{
   if(UseSL_Dollar && plBuy <= -SL_DollarAmount) closeSL = true;
   ...
}
```

---

### Bug #2: Accumulate Close นับ Floating ออเดอร์ที่ Breakeven แล้วเป็น "กำไร"

**ปัญหา:** `accumTotal = g_accumulatedProfit + totalFloating` รวม floating P/L ของออเดอร์ที่ผ่าน Breakeven แล้ว (SL อยู่ที่ open price) เข้าไปด้วย ทำให้ accumTotal อาจถึง Target ได้แม้ closed profit ยังต่ำ

**วิธีแก้:** เพิ่ม minimum closed profit threshold ก่อน trigger accumulate close:

```text
// Only trigger if enough CLOSED profit has been accumulated
// Prevent floating-only reaching target
if(accumTotal >= AccumulateTarget && accumTotal > 0 && g_accumulatedProfit > 0)
```

---

### Bug #3: EA หยุดหลัง Accumulate/SL Close เพราะ justClosedBuy/Sell ถูก reset ก่อน entry logic

**ปัญหา:** `CloseAllPositions()` -> `justClosedBuy = true`, `justClosedSell = true` แต่ใน `OnTick()` หลัง ManageTPSL() กลับไม่มี early return ถ้าเพิ่ง close ดังนั้น new bar loop จะยัง run และ reset flags ก่อน entry logic จะทำงานได้บน next bar

ที่แย่กว่านั้น: หลัง accumulate close ระบบ reset `g_initialBuyPrice = 0` และ `g_initialSellPrice = 0` แต่ `justClosedBuy = true` / `justClosedSell = true` ถ้า `EnableAutoReEntry = false` ตัว entry logic `shouldEnterBuy = false` จะไม่เข้าเงื่อนไข `!justClosedBuy && buyCount == 0` เพราะ `justClosedBuy = true` อยู่

**วิธีแก้:** เพิ่ม early return ใน OnTick() หลัง ManageTPSL() ถ้าเพิ่งปิดออเดอร์:

```text
ManageTPSL();
if(justClosedBuy || justClosedSell) return;  // Skip new bar logic this tick
```

และแก้ shouldEnter logic:

```text
// After accumulate close: justClosed is true but we WANT to re-enter
// Solution: after accumulate close, reset justClosed flags immediately
// OR make shouldEnter work correctly regardless

bool shouldEnterBuy = false;
if(buyCount == 0 && g_initialBuyPrice == 0)
{
   if(justClosedBuy && EnableAutoReEntry) shouldEnterBuy = true;
   else if(!justClosedBuy) shouldEnterBuy = true;
}
```

---

### Bug #4: Per-Order Trailing Breakeven Logic ผิด (สำหรับ SELL)

**ปัญหา:** ใน SELL Trailing:

```text
double beCeiling = NormalizeDouble(openPrice - InpBreakevenOffset * point, digits);
if(newSL > beCeiling) newSL = beCeiling;  // BUG! ควรเป็น > สำหรับ SELL ทิศทางกลับ
```

สำหรับ SELL, SL ต้องอยู่ต่ำกว่า openPrice (ฝั่ง ask) breakeven = openPrice - offset ซึ่ง SL ใหม่ควรไม่ต่ำกว่า beCeiling (สำหรับ SELL SL เคลื่อนลง) ตรรกะควรเป็น:

```text
if(newSL < beCeiling) newSL = beCeiling;  // SELL: SL ต้องไม่ต่ำกว่า BE floor
```

---

### สรุปการเปลี่ยนแปลง

| ลำดับ | ไฟล์ | การเปลี่ยนแปลง |
|-------|------|----------------|
| 1 | Gold_Miner_EA.mq5 | เพิ่ม `&& !EnablePerOrderTrailing` guard ให้กับ SL check ทั้ง BUY และ SELL |
| 2 | Gold_Miner_EA.mq5 | เพิ่ม `&& g_accumulatedProfit > 0` ให้กับ Accumulate trigger guard |
| 3 | Gold_Miner_EA.mq5 | เพิ่ม early return หลัง ManageTPSL() ถ้าเพิ่ง close `if(justClosedBuy || justClosedSell) return;` |
| 4 | Gold_Miner_EA.mq5 | แก้ SELL Trailing BE floor ใช้ `<` แทน `>` |
| 5 | Gold_Miner_EA.mq5 | เพิ่ม Print log เมื่อ SL trigger เพื่อระบุสาเหตุการปิดชัดเจน เช่น "SL_BASKET_DOLLAR HIT (BUY)" |
| 6 | Gold_Miner_EA.mq5 | Version bump 2.4 -> 2.5 |

### รายละเอียดทางเทคนิค

**ManageTPSL() BUY SL Check (บรรทัด 799-823):**

```text
// BEFORE (Bug):
if(EnableSL)
{
   if(UseSL_Dollar && plBuy <= -SL_DollarAmount) closeSL = true;
   ...
}

// AFTER (Fixed):
if(EnableSL && !EnablePerOrderTrailing)  // Skip basket SL when per-order manages individual closes
{
   if(UseSL_Dollar && plBuy <= -SL_DollarAmount)
   {
      Print("SL_BASKET_DOLLAR HIT (BUY): PL=", plBuy, " Limit=", -SL_DollarAmount);
      closeSL = true;
   }
   ...
}
```

**ManageTPSL() SELL SL Check (บรรทัด 855-879):**

เช่นเดียวกับ BUY เพิ่ม `&& !EnablePerOrderTrailing`

**Accumulate trigger (บรรทัด 891):**

```text
// BEFORE:
if(accumTotal >= AccumulateTarget && accumTotal > 0)

// AFTER:
if(accumTotal >= AccumulateTarget && accumTotal > 0 && g_accumulatedProfit > 0)
```

**OnTick() early return (หลังบรรทัด 418):**

```text
ManageTPSL();

// If positions were just closed by TPSL, skip new bar entry this tick
// to prevent same-tick re-entry race condition
if(g_eaStopped) return;
```

**SELL Trailing Breakeven floor (บรรทัด 1017-1018):**

```text
// BEFORE (Bug):
double beCeiling = NormalizeDouble(openPrice - InpBreakevenOffset * point, digits);
if(newSL > beCeiling) newSL = beCeiling;

// AFTER (Fixed):
double beFloor = NormalizeDouble(openPrice - InpBreakevenOffset * point, digits);
if(newSL < beFloor) newSL = beFloor;  // SELL: SL must not go below BE level
```
