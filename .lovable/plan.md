

## v6.22 — CountPositions ต้อง Generation-Aware: Order เก่าที่ไม่ได้ bound บล็อก Entry ใหม่

### ปัญหาที่พบ

เมื่อ DD Hedge trigger:
- H1 (SELL hedge): bind เฉพาะ **GM BUY** orders (ฝั่งที่ขาดทุน) → GM SELL orders ไม่ถูก bind
- H2 (BUY hedge): bind เฉพาะ **GM1 SELL** orders (ฝั่งที่ขาดทุน) → GM1 BUY orders ไม่ถูก bind
- `g_cycleGeneration` = 2 (GM2)

`CountPositions()` ข้าม hedge/bound แต่ **ไม่ filter generation** → นับ orders ฝั่งกำไรของ gen เก่า:

```text
CountPositions() เห็น:
- GM1 BUY orders (ไม่ bound, ไม่ hedge) → buyCount > 0
- GM SELL orders (ไม่ bound, ไม่ hedge) → sellCount > 0

Entry condition: buyCount == 0 → FALSE → ไม่เปิด BUY ✗
```

เมื่อ GM SELL orders ปิดหมด (TP/trailing) → `sellCount == 0` → SELL entry เปิดได้
แต่ GM1 BUY orders ยังค้าง → BUY entry ถูก block ตลอด

### แผนแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. เพิ่ม generation filter ใน `CountPositions()`

```cpp
void CountPositions(int &buyCount, int &sellCount, ...)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      // ... existing magic/symbol/hedge/bound checks ...
      
      // v6.22: Skip orders from previous generations
      string comment = PositionGetString(POSITION_COMMENT);
      int orderGen = ExtractGeneration(comment);
      if(orderGen >= 0 && orderGen != g_cycleGeneration) continue;
      
      // ... count buy/sell/grid ...
   }
}
```

#### 2. เพิ่ม generation filter ใน `NormalOrderCount()`

เพื่อให้สอดคล้องกัน — นับเฉพาะ current gen:

```cpp
int NormalOrderCount()
{
   // ... existing checks ...
   int orderGen = ExtractGeneration(comment);
   if(orderGen >= 0 && orderGen != g_cycleGeneration) continue;
   count++;
}
```

#### 3. Version bump: v6.21 → v6.22

### ตัวอย่างหลังแก้

```text
g_cycleGeneration = 2 (GM2)

CountPositions() เห็น:
- GM BUY (bound to H1) → skip (bound)
- GM SELL (gen 0, ≠ 2) → skip (wrong gen) ← NEW
- GM1 SELL (bound to H2) → skip (bound)
- GM1 BUY (gen 1, ≠ 2) → skip (wrong gen) ← NEW
- GM2 orders → count ✓

buyCount = 0 → BUY entry เปิดได้ ✅
sellCount = 0 → SELL entry เปิดได้ ✅
```

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL) — logic เดิม เปลี่ยนแค่ scope ตัวนับ
- Core Module Logic (License, News filter, Time filter, Data sync)
- Triple-gate close (Expansion + Zone + TP Distance)
- Generation-aware binding/counting ใน hedge system (v6.18/v6.19)
- DD trigger threshold logic (v6.21)
- `TotalOrderCount()` — ไม่แก้

