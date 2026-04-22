

## v6.58 — Sequential Release: Block Recovery Grid on Frozen Generations

### ปัญหาที่เจอ (จาก screenshot v6.57)

Dashboard แสดง: `Seq Release ON | Active: Set#6 (Oldest) | Frozen: 0` แต่ Gen0–Gen4 ยังออก grid loss พร้อมกันหมด

**สาเหตุ:** v6.57 freeze ถูกแค่ `ManageHedgeSets()` (matching/avgTP/partial/grid) แต่ **ไม่ได้ block:**
1. **`ManageOrphanGrid()`** — bound orders เก่าที่ถูก release (จาก hedge set ที่ deactivate ไปแล้ว) กลายเป็น orphan → ฟังก์ชันนี้ออก grid loss ให้ **ทุก orphan group พร้อมกัน**
2. **Normal Gen grid loop** (line 1509, 1651) — ออก grid loss ให้ทุก generation ที่มี active orders พร้อมกัน

ผลคือ recovery (การออก grid เพิ่มเพื่อปิดออเดอร์) ยังเกิดขึ้นพร้อมกันหลาย gen

### สิ่งที่ผู้ใช้ต้องการ

ทำงาน recovery ทีละชุดจริงๆ — **เฉพาะ generation ของ oldest active hedge set เท่านั้น** ที่ได้รับอนุญาตให้:
- ออก grid loss orders ใหม่
- ออก grid profit orders ใหม่
- ออก initial orders ใหม่ (ถ้ามี)

generation อื่น (ทั้งที่ยัง bound กับ hedge ที่ frozen และที่ release ไปเป็น orphan แล้ว) → **ห้ามเพิ่ม order ใดๆ** จนกว่า oldest set จะปิดออเดอร์ในชุดนั้นได้หมด

### หลักการกำหนด "Allowed Generation"

```text
InpHedge_SequentialRelease = true:
  oldest active hedge set ที่ slot index = N
  → "allowed generation" = N (เพราะ slot index === bound generation per v6.68)
  
  ถ้าไม่มี hedge set active เลย:
  → ถ้ายังมี orphan groups → allowed = generation ที่เก่าที่สุด (slot ต่ำสุด) ใน orphan
  → ถ้าไม่มีอะไรเลย → allowed = current g_cycleGeneration (ออเดอร์ใหม่ปกติ)
```

### แผนแก้ไข — `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Version bump → v6.58

#### 2. Helper function ใหม่: `GetSequentialAllowedGeneration()`

```cpp
// v6.58: คืน generation ที่ได้รับอนุญาตให้ออก order ใหม่ตอน Sequential Release ON
// คืน -1 = ไม่จำกัด (เมื่อ feature OFF)
// คืน N = อนุญาตเฉพาะ Gen N เท่านั้น
int GetSequentialAllowedGeneration()
{
   if(!InpHedge_SequentialRelease) return -1;
   
   int oldestHedge = GetOldestActiveHedgeSetIndex();
   if(oldestHedge >= 0) return oldestHedge;  // slot index === gen (v6.68)
   
   // ไม่มี hedge active → หา oldest orphan generation
   int oldestOrphan = INT_MAX;
   for(int g = 0; g < MAX_ORPHAN_GROUPS; g++)
      if(g_orphanGroups[g].active && g_orphanGroups[g].generation < oldestOrphan)
         oldestOrphan = g_orphanGroups[g].generation;
   if(oldestOrphan != INT_MAX) return oldestOrphan;
   
   return -1;  // ทุกอย่างเคลียร์แล้ว → ออก order ใหม่ได้ปกติ
}
```

#### 3. Guard ใน `ManageOrphanGrid()` (ที่ line 8615 — loop แต่ละ orphan group)

```cpp
int allowedGen = GetSequentialAllowedGeneration();

for(int g = 0; g < MAX_ORPHAN_GROUPS; g++)
{
   if(!g_orphanGroups[g].active) continue;
   
   // v6.58: Sequential gate — block recovery grid for non-allowed generations
   if(allowedGen != -1 && g_orphanGroups[g].generation != allowedGen)
      continue;
   
   // ... โค้ดเดิม ...
}
```

#### 4. Guard ใน main grid loop (line 1509–1660 ใน OnTick)

ค้นหา loop ที่วนทุก generation เปิด grid loss/profit/initial → เพิ่ม:

```cpp
int allowedGen = GetSequentialAllowedGeneration();

// ในแต่ละ generation iteration:
if(allowedGen != -1 && currentGen != allowedGen)
   continue;  // skip new orders for this gen
```

ครอบคลุม:
- BUY grid loss (line 1511, 1653)
- SELL grid loss (line 1515, 1655)
- Grid profit (line 1522, 1660)
- Initial entry (line 1567, 1588) — ถ้า allowedGen != -1 และ != current cycle gen → skip

#### 5. Dashboard อัปเดต

แก้บรรทัด "Seq Release" ให้แสดง allowed gen ที่ถูกต้อง:
```
Seq Release | ON | Allowed: Gen6 | Frozen Hedge: 0 | Frozen Orphans: 4
Seq Release | ON | No active sets — open orders allowed
Seq Release | OFF | Parallel recovery
```

### พฤติกรรมหลังแก้ (ตัวอย่างจาก screenshot)

**ก่อน v6.58:** Active Set#6, Gen0–Gen4 แต่ละตัวออก grid loss พร้อมกัน
**หลัง v6.58:** Active Set#6 → allowedGen = 5 (slot 5 = Gen5 หรือ Gen6 ขึ้นกับ mapping) → **เฉพาะ Gen นั้นเท่านั้น** ที่ออก grid loss/profit ใหม่ได้ → Gen อื่นค้างไว้รอคิว

เมื่อ Gen ที่ allowed ปิดออเดอร์ครบ → set deactivate → tick ถัดไป allowed เลื่อนไป Gen ถัดไป (oldest ใหม่) อัตโนมัติ

### สิ่งที่ไม่เปลี่ยนแปลง

- Order Execution Logic (`trade.Buy/Sell/PositionClose`) — ไม่แก้
- Trading Strategy (entry signals, TP/SL/Trailing) — ไม่แก้
- Core Module (License/News/Time/DataSync) — ไม่แก้
- Hedge open trigger / Triple Gate / Balance Guard — ไม่แก้
- Matching Close / BoundAvgTP / PartialClose / GridMode — ไม่แก้ (ถูกควบคุมโดย v6.57 อยู่แล้ว)
- Grid distance/lot calculation — ไม่แก้ (เพิ่มแค่ guard เปิด/ไม่เปิด)
- Hedge orders — ออกได้ตามปกติแม้ไม่ใช่ allowed gen (recovery mechanism)
- การปิดออเดอร์ทุกประเภท — ไม่แก้ (block แค่การเปิดใหม่)
- v6.37–v6.57 features — ไม่แก้

### ผลลัพธ์

- `InpHedge_SequentialRelease = false` → เหมือนเดิม 100%
- `InpHedge_SequentialRelease = true` → recovery grid ออกได้ **เฉพาะ generation ของ oldest active hedge set เดียวเท่านั้น** → จบชุด → เลื่อนต่อไปอัตโนมัติ → ทำงานทีละชุดจริงตามที่ต้องการ

