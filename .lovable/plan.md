

## Fix: Grid Recovery ไม่ออก Order ชุด E + เพิ่ม Group H/I/J (v5.13 → v5.14)

### ปัญหาที่ 1: Grid Recovery ชุด E ไม่เปิด Order

**สาเหตุ 2 จุด:**

**จุดที่ A (line 6407-6418):** เมื่อ `ManageHedgeMatchingClose()` ปิด hedge order สำเร็จแต่ไม่มี loss orders ที่ match ได้ (`lossUsed == 0`):
```text
trade.PositionClose(g_hedgeSets[idx].hedgeTicket);  // ปิด hedge
g_hedgeSets[idx].gridMode = true;
// ← ไม่ได้ set hedgeTicket = 0 !!!
```

จากนั้นใน `ManageHedgeGridMode()` (line 6820):
```text
if(g_hedgeSets[idx].hedgeTicket == 0)  // hedgeTicket ยังเป็นค่าเก่า → false!
   ManageGridRecoveryMode(idx);        // ← ไม่ถูกเรียก
   return;
```

แล้วไปที่ line 6829: `PositionSelectByTicket(hedgeTicket)` → position ถูกปิดแล้ว → `mainHedgeExists = false` → ไม่มี grid profit → ไม่ทำอะไร

**จุดที่ B (line 6770):** `currentGridCount <= g_hedgeSets[idx].gridLevel + 3` — ค่า `gridLevel` ที่ set ไว้ที่ line 6416 เป็น 0 → `0 + 3 = 3` ซึ่งอาจจำกัดเกินไปถ้ามี bound orders เยอะ ควรคำนวณจาก lots ที่เหลือจริง

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. แก้ `ManageHedgeMatchingClose()` — set `hedgeTicket = 0` ทุก path

Line 6410-6418: เพิ่ม `g_hedgeSets[idx].hedgeTicket = 0;` หลัง `trade.PositionClose()`:
```cpp
trade.PositionClose(g_hedgeSets[idx].hedgeTicket);
g_hedgeSets[idx].hedgeTicket = 0;  // ← เพิ่มบรรทัดนี้
```

และคำนวณ `gridLevel` จาก bound lots จริง:
```cpp
g_hedgeSets[idx].gridLevel = CalculateEquivGridLevel(
   CalculateRemainingBoundLots(idx));
```

#### 2. แก้ `ManageHedgeGridMode()` — เพิ่ม fallback เมื่อ hedge ticket ไม่ valid

Line 6829-6834: ถ้า `PositionSelectByTicket` fail (hedge ถูกปิดไปแล้ว) → set `hedgeTicket = 0` แล้วเรียก `ManageGridRecoveryMode()`:
```cpp
if(g_hedgeSets[idx].hedgeTicket > 0 && PositionSelectByTicket(g_hedgeSets[idx].hedgeTicket))
{
   mainHedgeExists = true;
   ...
}
else if(g_hedgeSets[idx].hedgeTicket > 0)
{
   // Hedge ticket invalid (closed externally or via matching close)
   g_hedgeSets[idx].hedgeTicket = 0;
   ManageGridRecoveryMode(idx);
   return;
}
```

---

### ปัญหาที่ 2: เพิ่ม Group H/I/J (10 Groups, 10 Cycles)

#### 3. เพิ่ม MAX_CYCLES จาก 7 เป็น 10

- `FindLowestFreeCycle()`: loop `c < 7` → `c < 10`
- `suffixes[]` array: เพิ่ม `"_H", "_I", "_J"`
- `GetCycleSuffix()`: เพิ่ม case 7-9 return "_H", "_I", "_J"
- Cycle limit checks: `g_currentCycleIndex < 6` → `g_currentCycleIndex < 9`

#### 4. Hedge Cycle Monitor Dashboard — 7 คอลัมน์ → 10 คอลัมน์

- ขยาย arrays ทั้งหมดจาก `[7]` → `[10]`
- เพิ่ม Group H (สี), I (สี), J (สี)
- ลูปทุกจุด `g < 7` → `g < 10`
- ปรับ `colW` ให้แคบลงเล็กน้อยเพื่อรองรับ 10 คอลัมน์ หรือทำเป็น 2 แถว (5+5)

#### 5. FindLowestFreeCycle — ยืนยันว่า recycle ถูกต้อง

ตรวจสอบว่า `FindLowestFreeCycle()` scan ทั้ง 10 cycles, เช็คทั้ง active hedge sets + open orders ที่มี suffix ตรง → return cycle แรกที่ว่างเสมอ (เริ่มจาก A)

#### 6. MAX_HEDGE_SETS — 16 → 20

เพิ่มเป็น 20 slots เพื่อรองรับ 10 groups × 2 hedges ต่อ group ในกรณีเลวร้าย

#### 7. Version bump: v5.13 → v5.14

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge Guards (cycle-aware, squeeze directional block)
- Normal Matching Close logic
- Dashboard หลัก (ข้อมูลอื่นๆ)

