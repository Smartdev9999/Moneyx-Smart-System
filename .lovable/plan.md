

## v6.37 — แก้บัค Hedge ไม่ครบทั้งสองฝั่ง (Generation Race Condition)

### สาเหตุที่พบ

เมื่อทั้งฝั่ง BUY และ SELL ติดลบถึง $5,000 พร้อมกัน (หรือใกล้กัน):

1. ฝั่ง BUY ถึง threshold → `OpenDDHedge()` ทำงาน → **bind ออเดอร์ BUY จาก Gen N** → `g_cycleGeneration++` (เป็น N+1)
2. ถัดมาฝั่ง SELL ถึง threshold → `OpenDDHedge()` เรียก `CountUnboundOrders(SELL, ..., g_cycleGeneration)` → ใช้ Gen **N+1** → **ไม่เจอออเดอร์ SELL เพราะมันเป็น Gen N** → `counterCount == 0` → **ไม่เปิด hedge!**

ผลคือ: ออเดอร์ SELL ฝั่งตรงข้ามจาก Gen N กลายเป็น "หลุด" ไม่โดนล็อค เพราะ generation ถูกเลื่อนไปแล้ว และ DD check ในรอบถัดไปก็ไม่เห็นมันอีก (เพราะ `orderGen != curGen`)

```text
Timeline:
─────────────────────────────────────────────
Tick 1: BUY DD=$5200, SELL DD=$5100 (both Gen 7)

CheckAndOpenHedgeByDD():
  ├─ buyLoss calculated from Gen 7 orders ✓
  ├─ sellLoss calculated from Gen 7 orders ✓
  ├─ BUY side triggers → OpenDDHedge(BUY, SELL)
  │   ├─ Binds BUY orders (Gen 7)
  │   └─ g_cycleGeneration: 7 → 8  ← HERE
  ├─ SELL side triggers → OpenDDHedge(SELL, BUY)
  │   ├─ CountUnboundOrders(BUY, ..., Gen 8) ← uses NEW gen
  │   └─ Finds 0 orders → SKIP! ✗ BUG
  └─ SELL orders from Gen 7 = ORPHANED, never hedged
─────────────────────────────────────────────
```

### แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Version bump → v6.37

#### 2. แก้ `OpenDDHedge()` — เพิ่ม parameter `bindGen`
เปลี่ยน signature จาก:
```cpp
bool OpenDDHedge(ENUM_POSITION_TYPE counterSide, ENUM_POSITION_TYPE hedgeSide)
```
เป็น:
```cpp
bool OpenDDHedge(ENUM_POSITION_TYPE counterSide, ENUM_POSITION_TYPE hedgeSide, int bindGen)
```

ใช้ `bindGen` แทน `g_cycleGeneration` ในทุกจุดภายในฟังก์ชัน:
- `CountUnboundOrders(counterSide, ..., bindGen)` (line 7021)
- Binding loop filter: `if(orderGen != bindGen) continue;` (line 7093)
- `g_hedgeSets[slot].boundGeneration = bindGen;` (line 7101)

#### 3. แก้ `CheckAndOpenHedgeByDD()` — บันทึก origGen ก่อน hedge
```cpp
int origGen = g_cycleGeneration;  // v6.37: snapshot before any hedge opens

// ... calculate buyLoss, sellLoss using origGen ...

if(buyLossAbs >= threshold)
   OpenDDHedge(BUY, SELL, origGen);   // bind from origGen

if(sellLossAbs >= threshold)
   OpenDDHedge(SELL, BUY, origGen);   // bind from origGen (ยังเจอออเดอร์)
```

เปลี่ยน DD calculation loop ด้วย: ใช้ `origGen` แทน `curGen` (line 6933/6948)

#### 4. แก้ `CheckAndOpenHedge()` (Expansion mode) — ส่ง `g_cycleGeneration` เหมือนเดิม
ค้นหาจุดเรียก `OpenDDHedge` ในโหมด Expansion (ถ้ามี) ให้ส่ง `g_cycleGeneration` ตรงๆ

#### 5. อัปเดต version ทุกจุด

### ตัวอย่างการทำงานหลังแก้
```text
Tick 1: BUY DD=$5200, SELL DD=$5100 (both Gen 7)
origGen = 7

CheckAndOpenHedgeByDD():
  ├─ buyLoss from Gen 7 ✓, sellLoss from Gen 7 ✓
  ├─ BUY side → OpenDDHedge(BUY, SELL, bindGen=7)
  │   ├─ CountUnboundOrders(SELL, ..., Gen 7) → finds orders ✓
  │   ├─ Binds BUY orders from Gen 7
  │   └─ g_cycleGeneration: 7 → 8
  ├─ SELL side → OpenDDHedge(SELL, BUY, bindGen=7)
  │   ├─ CountUnboundOrders(BUY, ..., Gen 7) → finds orders ✓ 
  │   ├─ Binds SELL orders from Gen 7
  │   └─ g_cycleGeneration: 8 → 9
  └─ ทั้งสองฝั่งโดนล็อคครบ ✓
```

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic — ไม่แก้
- Trading Strategy Logic — ไม่แก้
- Core Module Logic — ไม่แก้
- DD trigger threshold / Triple-gate / Matching close — ไม่แก้
- OpenDDHedge binding/generation logic — เฉพาะ parameter, ไม่แก้ flow
- Balance Guard (v6.33/v6.35) — ไม่แก้
- Daily Target Profit (v6.32) — ไม่แก้
- Orphan Recovery — ไม่แก้
- PrevHedgedTickets guard — ไม่แก้

