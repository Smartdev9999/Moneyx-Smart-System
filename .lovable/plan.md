

## v6.19 — Expansion Hedge ต้อง Generation-Aware เหมือน DD Mode

### ปัญหาที่พบ

**`CheckAndOpenHedge()` (Expansion mode) ไม่ filter generation**

- Line 6474: `CountUnboundOrders(counterSide, counterLots, counterPL)` — ไม่ส่ง `genFilter` (default = -1 = นับทุก gen)
- Lines 6530-6545: Binding loop ไม่ filter generation — bind ทุก unbound order ไม่ว่า GM, GM1, GM2

**ผลลัพธ์:**
1. Set#1 binds **ทุก** unbound BUY orders (GM + อื่นๆ) → เปิด SELL hedge → cycle เป็น GM1
2. Set#2 binds **ทุก** unbound SELL orders (GM1 + อื่นๆ) → เปิด BUY hedge → cycle เป็น GM2
3. Set#3 → `CountUnboundOrders` return 0 ทั้ง 2 ฝั่ง เพราะทุก order ถูก bound หมดแล้ว → **ไม่สามารถเปิด Hedge ชุดที่ 3 ได้**

DD mode แก้ไปแล้วใน v6.18 แต่ Expansion mode ยังไม่ได้แก้

### แผนแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. แก้ `CheckAndOpenHedge()` — เพิ่ม generation filter ตอนนับ

```cpp
// เดิม (line 6474):
int counterCount = CountUnboundOrders(counterSide, counterLots, counterPL);

// แก้เป็น:
int counterCount = CountUnboundOrders(counterSide, counterLots, counterPL, g_cycleGeneration);
```

#### 2. แก้ Binding loop ใน `CheckAndOpenHedge()` — filter by generation

เพิ่ม generation filter ใน binding loop (lines 6530-6545) เหมือนที่ทำใน `OpenDDHedge()`:

```cpp
int bindGen = g_cycleGeneration;
for(int i = PositionsTotal() - 1; i >= 0; i--)
{
   // ... existing checks ...
   string cmt = PositionGetString(POSITION_COMMENT);
   if(IsHedgeComment(cmt)) continue;
   if(IsTicketBound(ticket)) continue;
   // เพิ่ม: Generation filter
   int orderGen = ExtractGeneration(cmt);
   if(orderGen < 0) continue;
   if(orderGen != bindGen) continue;
   // bind ticket...
}
```

#### 3. Version bump: v6.18 → v6.19

### ตัวอย่างหลังแก้

```text
Set#1: binds เฉพาะ GM BUY orders → cycle เป็น GM1
Set#2: binds เฉพาะ GM1 SELL orders → cycle เป็น GM2
Set#3: binds เฉพาะ GM2 orders → สามารถเปิดได้ ✅

GM เดิมยังอยู่ใน Set#1 จัดการของตัวเอง
GM1 อยู่ใน Set#2 จัดการของตัวเอง
```

### สิ่งที่ไม่เปลี่ยนแปลง

- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Gate 1/2/3 (Expansion Cycle + Price Zone + TP Distance) — ไม่แก้
- Matching Close / Grid Mode logic ภายใน — ไม่แก้
- Accumulate Close — ทำงานรวมเหมือนเดิม
- DD% trigger logic (`CheckAndOpenHedgeByDD` / `OpenDDHedge`) — ไม่แก้ (แก้ไปแล้วใน v6.18)
- Bound ticket isolation (`IsTicketBound`) — ไม่แก้
- Orphan Recovery / Squeeze detection — ไม่แก้

