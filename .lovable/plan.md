

## v6.38 — แก้บัค Orphaned Orders จาก Partial-Side Hedge

### สาเหตุที่แท้จริง

ปัญหาไม่ใช่ Race Condition (v6.37 แก้ไปแล้ว) แต่คือ **Partial-Side Orphaning** — เมื่อ Gen N มีออเดอร์ทั้ง BUY และ SELL แต่มีเพียงฝั่งเดียวที่ DD ถึง threshold:

```text
Gen 1 Orders:
  BUY:  129(0.8), 130(1.2), 131(1.04), 134(1.35) = 4.39 lots
  SELL: 127(0.8), 128(1.04), 132(1.2), 133(1.8) = 4.84 lots

BUY DD hits $5000 → GM_HEDGE_D2 (SELL 4.39) binds BUY orders
g_cycleGeneration: 1 → 2

SELL orders from Gen 1 (127,128,132,133):
  ✗ Not bound to any hedge set
  ✗ Not in g_prevHedgedTickets
  ✗ DD calc filters orderGen != curGen(2) → SKIPPED FOREVER
  → ORPHANED — floating unmanaged, accumulating loss
```

เหตุการณ์นี้เกิดซ้ำทุก Gen ที่มีออเดอร์ทั้งสองฝั่ง ทำให้ออเดอร์ orphan สะสม → พอร์ตติดลบเพิ่มขึ้นเรื่อยๆ โดยไม่มีระบบจัดการ

### แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Version bump → v6.38

#### 2. แก้ DD Loss Calculation — รวมออเดอร์จาก **ทุก Gen ที่ไม่ได้ถูกจัดการ**

ใน `CheckAndOpenHedgeByDD()` line ~6948 เปลี่ยน:
```cpp
// เดิม: เฉพาะ current gen
if(orderGen != curGen) continue;

// ใหม่ v6.38: รวม orphaned orders จาก gen เก่าที่ไม่ได้ถูก bind/hedge
if(orderGen > curGen) continue;  // skip only future gens (safety)
```

เหตุผล: ออเดอร์ที่ไม่ได้ bind, ไม่ใช่ hedge, ไม่ใช่ prevHedged — ไม่ว่าจะ Gen ไหน — ควรถูกนับเข้า DD เพื่อให้ระบบ hedge จัดการได้

#### 3. แก้ `CountUnboundOrders()` — รองรับ mode "all gens ≤ genFilter"

เปลี่ยน gen filter logic ใน `CountUnboundOrders()` line ~6706-6710:
```cpp
// เดิม: exact match
if(orderGen != genFilter) continue;

// ใหม่ v6.38: include all generations up to genFilter
if(orderGen > genFilter) continue;
```

#### 4. แก้ Binding Loop ใน `OpenDDHedge()` — bind ออเดอร์จากทุก Gen ≤ bindGen

Line ~7093 เปลี่ยน:
```cpp
// เดิม: exact match
if(orderGen != bindGen) continue;

// ใหม่ v6.38: bind unbound orders from all gens up to bindGen
if(orderGen > bindGen) continue;
```

#### 5. แก้ `boundGeneration` assignment

Line ~7101 — เก็บ gen ต่ำสุดที่ bound (เพื่อ recovery):
```cpp
// Track lowest bound generation for recovery purposes
g_hedgeSets[slot].boundGeneration = bindGen;
// (keep bindGen as the "up to" marker)
```

#### 6. อัปเดต version ทุกจุด

### ตัวอย่างการทำงานหลังแก้

```text
Gen 0: BUY orders → DD hits → GM_HEDGE_D1 binds BUY(Gen0)
       g_cycleGeneration: 0 → 1

Gen 1: BUY + SELL orders
       BUY DD hits $5000 → GM_HEDGE_D2 binds BUY(Gen1)
       g_cycleGeneration: 1 → 2
       SELL orders Gen1 = unbound, not hedged

Gen 2: SELL orders open
       Next DD check: calculates SELL loss from Gen0+Gen1+Gen2 (all unbound)
       SELL DD hits $5000 → GM_HEDGE_D3 binds ALL unbound SELL (Gen1+Gen2)
       → Gen 1 SELL orders are no longer orphaned ✓
```

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic — ไม่แก้
- Trading Strategy Logic — ไม่แก้
- Core Module Logic — ไม่แก้
- DD trigger threshold value — ไม่แก้ (ยังคง $5000 หรือ % ตามที่ตั้ง)
- Triple-gate / Matching close — ไม่แก้
- OpenDDHedge flow (เฉพาะ filter condition เปลี่ยน) — ไม่แก้ flow
- Balance Guard (v6.33/v6.35) — ไม่แก้
- Daily Target Profit (v6.32) — ไม่แก้
- Generation Race Condition fix (v6.37) — ยังคงอยู่
- Orphan Recovery / PrevHedgedTickets guard — ไม่แก้
- Safe Cycle Reset — ไม่แก้

