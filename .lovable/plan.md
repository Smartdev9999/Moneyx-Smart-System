

## Fix: Order Buy ชุดใหม่ไม่ออก เมื่อมี Hedge Set Active — Gold Miner SQ EA (v5.7 → v5.8)

### วิเคราะห์สาเหตุ

**ปัญหาอยู่ที่ `CountPositions()` (line 1302)**

`CountPositions()` skip เฉพาะ `IsHedgeComment()` (GM_HEDGE_N, GM_HG) แต่ **ไม่ skip `IsTicketBound()`** → bound orders ที่เป็น BUY ยังถูกนับรวมใน `buyCount`

**Flow ที่เกิดปัญหา:**
1. มี Hedge Set 1: SELL hedge, counterSide=BUY → bound orders เป็นฝั่ง BUY
2. `CountPositions()` นับ bound BUY orders → `buyCount = 10` (ตัวอย่าง)
3. Entry logic เช็ค `buyCount == 0` (line 1151) → **false** → ไม่เปิด Buy ใหม่

ทั้งที่ bound orders ถูกจัดการโดยระบบ Hedge แยกออกไปแล้ว ระบบปกติไม่ควรนับ → ควรเห็น `buyCount = 0` → เปิด Buy ชุดใหม่ได้

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. เพิ่ม `IsTicketBound` skip ใน `CountPositions()` (line 1322)

```cpp
// Skip hedge orders — they are managed by the Hedge system separately
if(IsHedgeComment(comment)) continue;

// Skip bound orders — managed by Hedge system, not normal trading cycle
if(IsTicketBound(ticket)) continue;
```

**ผล:** Bound orders จะไม่ถูกนับใน buyCount/sellCount → ระบบปกติเห็น buyCount=0 → เปิด Buy ชุดใหม่ได้ตามปกติ

#### 2. Version bump: v5.7 → v5.8

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge system logic ทั้งหมด (Matching/Partial/AvgTP/Grid)
- Squeeze filter logic

