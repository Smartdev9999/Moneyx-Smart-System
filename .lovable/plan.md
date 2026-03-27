

## Fix: Grid Mode Guard — เช็ค "ไม่มี reverse ที่เป็นบวก" แทน "ไม่มี reverse เลย"

### สาเหตุที่ต้องแก้

Plan v6.12 เดิมกำหนดว่า `gridMode = true` ได้ก็ต่อเมื่อ **ไม่มี reverse order เหลือเลย** — แต่นี่ผิด เพราะ:

- Reverse orders หลายตัวอาจมีทั้ง **บวกและลบ**
- ตัว **บวก** ต้องนำไปรวม budget ใน matching close ก่อน (ปิดคู่กับ loss)
- ตัว **ลบ** ที่เหลือหลัง matching close → เข้า combined grid recovery ได้เลย
- ถ้าบล็อกจนกว่า reverse = 0 → reverse ที่ติดลบจะไม่มีทางถูกกู้คืนด้วย grid

### เงื่อนไขที่ถูกต้อง

```text
เข้า Grid Mode ได้เมื่อ:
  1. ไม่มี TF ใดเป็น Expansion
  2. boundTicketCount == 0  
  3. ไม่มี reverse order ที่กำไร > 0 ค้างอยู่
     (reverse ที่ติดลบ → ปล่อยเข้า combined grid ได้)
```

### แผนแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. เพิ่ม helper: `HasProfitableReverseOrders()`

```cpp
bool HasProfitableReverseOrders()
{
   for(int i = 0; i < g_reverseHedgeCount; i++)
   {
      if(PositionSelectByTicket(g_reverseHedgeTickets[i]))
      {
         double pnl = PositionGetDouble(POSITION_PROFIT) 
                     + PositionGetDouble(POSITION_SWAP);
         if(pnl > 0) return true;
      }
   }
   return false;
}
```

#### 2. แก้ทุกจุดที่ตั้ง `gridMode = true` — ใช้ `!HasProfitableReverseOrders()` แทน `g_reverseHedgeCount == 0`

จุดที่ต้องแก้:
- **ManageHedgeSets loop** (line 7174): `boundTicketCount == 0` → เพิ่ม `&& !HasProfitableReverseOrders()`
- **ManageHedgeBoundAvgTP** (line 7785): เพิ่ม guard เดียวกัน
- **ManageHedgePartialClose** (line 7924): เพิ่ม guard เดียวกัน

#### 3. ปรับ Matching Close ให้รวม reverse profit เข้า budget

ใน `ManageHedgeMatchingClose()` (line 7803):
- สแกน reverse orders ที่กำไร → รวมเข้า budget
- ปิด reverse ที่กำไรพร้อม hedge ticket
- เหลือ reverse ที่ติดลบ → เข้า combined grid

```text
budget = hedgeProfit + sum(profitableReverseOrders) - minProfit
→ ปิด loss orders จากเก่าสุดตาม budget  
→ ปิด hedge + profitable reverse ที่ใช้กำไรไปด้วย
→ reverse ที่ติดลบยังอยู่ → เข้า combined grid recovery
```

#### 4. ปรับ `ManageReverseHedge()` global matching

ตรรกะเดิมปิด **ทุก** profit order (รวม reverse) แล้ว reset `g_reverseHedgeCount = 0` — ต้องแก้ให้:
- ปิดเฉพาะ reverse ที่กำไร + order อื่นที่กำไร
- **ไม่ปิด** reverse ที่ติดลบ → ยังคงอยู่ใน array
- หลัง matching → เช็คว่า reverse ที่เหลือล้วนติดลบ → safe เข้า grid

#### 5. Version bump: v6.11 → v6.12

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Orphan Recovery system
- Grid Mode logic ตัวเอง (ManageHedgeGridMode) — แค่เพิ่ม guard ก่อนเข้า
- Reverse Hedge opening logic (NET calculation)
- Squeeze Filter / Directional Block

