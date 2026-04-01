

## v6.20 — แก้ BUY Order ไม่ออกหลังโดน Hedging2: TotalOrderCount() นับรวม Hedge/Bound

### ปัญหาที่พบ

`TotalOrderCount()` (line 1587-1598) นับ **ทุก position** ของ EA โดยไม่ข้าม hedge orders หรือ bound orders

```text
TotalOrderCount() → นับ: normal + hedge + hedge_grid + bound = ทั้งหมด
```

ผลลัพธ์: หลัง Hedging2 เปิด มี order จำนวนมาก (จากภาพ: Hedge#1 B:15, Hedge#2 B:17 = 32+ bound orders + hedge orders เอง) → `TotalOrderCount() >= MaxOpenOrders` = **true** → `canOpenMore = false` → BUY entry ถูก block

จุดที่ใช้ `TotalOrderCount()` ตรวจ MaxOpenOrders:
- Line 1365: SMA/ZigZag entry
- Line 1494: Instant entry  
- Line 2433: CheckGridLoss
- Line 2534: CheckGridProfit
- Line 3926: TF GridLoss
- Line 4020: TF GridProfit
- Line 4505: TF ZigZag entry
- Line 7348, 7399: Orphan recovery

**หมายเหตุ**: `CountPositions()` (line 1540) **ข้าม** hedge/bound ถูกต้องแล้ว (ทำให้ `buyCount=0` ถูกต้อง) แต่ `TotalOrderCount()` ไม่ข้าม → เลยเป็น bottleneck

### แผนแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. สร้าง `NormalOrderCount()` — นับเฉพาะ order ปกติ

```cpp
int NormalOrderCount()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      string comment = PositionGetString(POSITION_COMMENT);
      if(IsHedgeComment(comment)) continue;
      if(IsTicketBound(ticket)) continue;
      count++;
   }
   return count;
}
```

#### 2. เปลี่ยนทุกจุดที่ใช้ `TotalOrderCount()` เพื่อเช็ค MaxOpenOrders

แทนที่ด้วย `NormalOrderCount()` ใน **8 จุด**:
- Entry logic (SMA, Instant, ZigZag) — 3 จุด
- Grid entry (GridLoss, GridProfit ทั้ง main + TF) — 4 จุด
- Orphan recovery — 2 จุด

**คง `TotalOrderCount()` ไว้** สำหรับจุดอื่นที่ต้องนับจริงทั้งหมด (เช่น cycle reset detection, accumulate baseline)

#### 3. Version bump: v6.19 → v6.20

### ตัวอย่างหลังแก้

```text
สถานการณ์: MaxOpenOrders = 50
- Normal orders: BUY 0, SELL 3
- Hedge#1: 1 hedge + 15 bound = 16
- Hedge#2: 1 hedge + 17 bound = 18
- Total: 38 orders

เดิม: TotalOrderCount() = 38 → ถ้า MaxOpenOrders=30 → BLOCKED
ใหม่: NormalOrderCount() = 3 → canOpenMore = true → BUY เข้าได้ ✅
```

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose) — ไม่แก้
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL) — ไม่แก้ logic เพียงเปลี่ยนตัวนับ
- Core Module Logic (License, News filter, Time filter, Data sync) — ไม่แก้
- Triple-gate close (Expansion + Zone + TP Distance) — ไม่แก้
- Matching Close / Grid Mode / Accumulate Close — ไม่แก้
- DD% trigger / Generation-aware isolation — ไม่แก้
- `CountPositions()` — ไม่แก้ (ทำงานถูกต้องอยู่แล้ว)
- `TotalOrderCount()` — ยังคงอยู่สำหรับใช้งานอื่น

