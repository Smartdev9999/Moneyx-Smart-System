

## Fix New Cycle ถูก Block + เพิ่ม Max Hedge Sets Input — Gold Miner SQ EA (v5.2 → v5.3)

### วิเคราะห์ปัญหา #1: New Cycle ไม่ออก Order

**สาเหตุ:** `GetHedgeLotCap()` (line 5878) คำนวณ `allowed = hedgeLots - boundLots` สำหรับ **ทุก** hedge set ที่ counterSide ตรงกัน

จากภาพ: Hedge #1 SELL 1.27L B:14 + Hedge #2 SELL 0.19L B:1 → Buy ทั้ง 15 orders ถูก bound หมด

เมื่อ hedge ถูก partial close → hedgeLots ลดลง (เช่น 1.27→1.0) แต่ boundLots ยังเท่าเดิม (เช่น 1.2L) → `allowed = 1.0 - 1.2 = -0.2` → **block ทุก buy order ใหม่**

ทำให้ new cycle ไม่สามารถเปิด order ได้เลย แม้ราคาจะกลับตัวขึ้นแล้ว

**แก้ไข:** `GetHedgeLotCap()` ควร return `-1` (no cap) เมื่อ bound orders ครอบคลุม hedge เต็มแล้ว (`allowed <= 0`) เพราะ orders ใหม่ที่เปิดจะเป็น **cycle อิสระ** ไม่ได้อยู่ภายใต้ hedge set เดิม — ไม่ต้อง cap

```text
เดิม:
  allowed = hedgeLots - boundLots
  → ถ้า allowed <= 0 → cap = 0 → block ทุก order

ใหม่:
  allowed = hedgeLots - boundLots  
  → ถ้า allowed <= 0 → skip set นี้ (ไม่ cap) — hedge เต็มแล้ว, order ใหม่เป็น independent cycle
  → ถ้า allowed > 0 → cap ตามเดิม (ยังมีที่ว่างอยู่ภายใต้ hedge)
```

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5` line 5896-5901

---

### แก้ไขจุดที่ 2: เพิ่ม Input จำกัดจำนวน Hedge Sets สูงสุด

**Input ใหม่ (line 321):**
```cpp
input int      InpHedge_MaxSets             = 10;     // Max Active Hedge Sets (1-10)
```

**แก้ไข `CheckAndOpenHedge()` (line 6010):** เพิ่ม guard ก่อน `FindFreeHedgeSlot()`:
```cpp
// Check max active sets limit
int activeCount = 0;
for(int h = 0; h < MAX_HEDGE_SETS; h++)
   if(g_hedgeSets[h].active) activeCount++;
if(activeCount >= InpHedge_MaxSets) return;
```

**ผล:** เมื่อตั้ง `InpHedge_MaxSets = 1` → ระบบเปิด Hedge ได้แค่ 1 ชุด ถ้าเกิด expansion อีกครั้ง → order ใหม่จะเป็น cycle ปกติ ไม่ hedge เพิ่ม จนกว่าชุดแรกจะแก้หมด

---

### Version bump: v5.2 → v5.3

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync, Squeeze)
- Hedge Matching/Partial Close/Grid Mode logic
- Bound ticket management (bind/unbind/refresh)
- Accumulate/Drawdown close logic

