

## Fix: Grid Hedging ออก order ระหว่าง Expansion ก่อนปิด Hedge/Reverse

### ปัญหา

มี 2 จุดที่ทำให้ Grid Hedging เปิดก่อนเวลา:

1. **Line 7164**: `ManageHedgeGridMode(h)` ถูกเรียก **โดยไม่เช็ค `isExpansion`** — เมื่อ `gridMode = true` มันจะเปิด grid orders ทันทีแม้ยังอยู่ใน Expansion
2. **Line 7199-7206**: เมื่อยังอยู่ใน Expansion แต่ `boundTicketCount == 0` → ระบบเข้า Grid Mode ทันที **โดยไม่รอให้กลับ Normal ก่อน** และไม่รอ matching close ของ hedge/reverse

```text
ลำดับที่ถูกต้อง:
  Expansion → hedge + reverse ยังค้าง
  กลับ Normal → Matching Close (กำไร vs ขาดทุน)
  เหลือ order → คำนวณ Grid Recovery
  
ลำดับที่เกิด (bug):
  Expansion → boundTicketCount == 0
  → gridMode = true ทันที!
  → เปิด grid orders ระหว่าง expansion!
```

### แก้ไข — 3 จุด

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Gate `ManageHedgeGridMode()` ด้วย `!isExpansion`

```cpp
// เดิม (line 7164):
if(g_hedgeSets[h].gridMode)
{
   ManageHedgeGridMode(h);
}

// แก้เป็น:
if(g_hedgeSets[h].gridMode)
{
   if(!isExpansion)
      ManageHedgeGridMode(h);
   continue;  // ยังอยู่ expansion → ไม่ทำอะไร รอ normal
}
```

#### 2. ลบ Grid Mode entry ระหว่าง Expansion (line 7199-7206)

Block `else` (ยังอยู่ใน expansion) ไม่ควรเข้า Grid Mode — ควรรอให้กลับ Normal ก่อนแล้วค่อย matching close → เหลือเท่าไหร่ค่อยเข้า grid

```cpp
// เดิม (line 7197-7206):
else
{
   if(g_hedgeSets[h].boundTicketCount == 0 && hedgeExists)
   {
      g_hedgeSets[h].gridMode = true;  // ← BUG: เข้า grid ระหว่าง expansion!
      ...
   }
}

// แก้เป็น:
else
{
   // Still in expansion — do nothing, wait for normal state
   // Grid mode will be entered after matching close in normal state
}
```

#### 3. Version bump: v6.10 → v6.11

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge Matching Close / Partial Close / AvgTP logic
- Reverse Hedging logic (NET calculation, balanced lock)
- Orphan Recovery system
- Grid Mode logic ตัวเอง (ManageHedgeGridMode) ไม่เปลี่ยน — แค่เพิ่ม guard ว่าต้อง Normal ก่อนถึงจะทำงาน

