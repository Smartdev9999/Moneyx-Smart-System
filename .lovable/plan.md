

## v6.57 — Sequential Hedge Release (Oldest-First, One-at-a-Time)

### หลักการ

ปัจจุบัน `ManageHedgeSets()` วนลูปทุก hedge set พร้อมกันทุก tick → set ไหนผ่าน Triple Gate + เงื่อนไขกำไร จะถูก release พร้อมกันได้หลายชุด

**โหมดใหม่ (toggle เปิด/ปิดได้):** ปลด hedge **ทีละชุด** เริ่มจาก **ชุดที่เก่าที่สุด** เท่านั้น
- ขณะที่ Set#1 ยังไม่จบ recovery (bound orders ยังเหลือ + grid recovery ยัง active) → Set#2, #3, ... ทุกชุดจะถูก **freeze** (ไม่ทำ matching/avgTP/partial/grid)
- เมื่อ Set#1 recovery เสร็จ (ออเดอร์ในชุดหมด) → ระบบเลื่อนไป Set#2 → ทำต่อจนหมด
- เมื่อ hedge ทุกชุดถูก release จนหมด → reset แล้วเริ่มนับใหม่จาก oldest set ใหม่อีกครั้ง

### แผนแก้ไข — `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Version bump → v6.57

#### 2. Input parameter ใหม่ (1 ตัว)

```cpp
input bool InpHedge_SequentialRelease = false;  // v6.57: Release hedge sets one-at-a-time (oldest first)
```

วางใต้ `InpHedge_UseMatchingClose` (line 369)

#### 3. Helper function ใหม่: หา oldest active set

```cpp
// v6.57: Returns index ของ active hedge set ที่เก่าที่สุด (slot ต่ำสุด)
// คืน -1 ถ้าไม่มี active set
int GetOldestActiveHedgeSetIndex()
{
   for(int h = 0; h < MAX_HEDGE_SETS; h++)
      if(g_hedgeSets[h].active) return h;
   return -1;
}
```

หมายเหตุ: ตาม `mem://generation-locked-hedge-slot-v6-68`, slot index = generation order, slot ต่ำสุด = ชุดที่เปิดก่อน = oldest

#### 4. แก้ `ManageHedgeSets()` loop (line 8766)

เพิ่ม guard ก่อน processing:

```cpp
// v6.57: Sequential release mode — only oldest active set is allowed to recover
int oldestIdx = -1;
if(InpHedge_SequentialRelease)
   oldestIdx = GetOldestActiveHedgeSetIndex();

for(int h = 0; h < MAX_HEDGE_SETS; h++)
{
   if(!g_hedgeSets[h].active) continue;

   // Refresh bound tickets (ต้องทำก่อน sequential check เพื่อให้ deactivate logic ทำงาน)
   RefreshBoundTickets(h);

   // v6.57: Sequential gate — freeze ทุก set ยกเว้น oldest
   bool sequentialFreeze = (InpHedge_SequentialRelease && oldestIdx != -1 && h != oldestIdx);

   // ... track expansion (ทำได้ปกติ ไม่กระทบ trading) ...

   // v6.57: ถ้าถูก freeze → skip ทั้ง matching/avgTP/partial/grid
   if(sequentialFreeze)
   {
      g_hedgeSets[h].matchingDone = false;  // reset flag เผื่อภายหลังถึงคิว
      continue;
   }

   // ... โค้ดเดิมทั้งหมด (Triple Gate, matching, avgTP, partial, grid) ...
}
```

**สำคัญ:** Hedge ที่ถูก freeze ยังคง:
- มี hedge order เปิดอยู่ตามปกติ (ไม่ปิด ไม่แก้)
- bound orders ค้างอยู่ตามปกติ
- ถูก track expansion (เพื่อให้พร้อมเมื่อถึงคิว)
- ไม่ block การเปิด hedge set ใหม่ (ระบบยังเปิด set ใหม่ได้ตาม `InpHedge_MaxSets`)

#### 5. Auto-reset behavior

เมื่อ Set#1 recovery เสร็จ → `g_hedgeSets[1].active = false` (โดยโค้ด deactivate ที่มีอยู่แล้ว) → tick ถัดไป `GetOldestActiveHedgeSetIndex()` คืน Set#2 อัตโนมัติ → ไม่ต้องเขียน reset logic เพิ่ม

เมื่อทุก set ถูก release หมด → `oldestIdx = -1` → loop จบ → ระบบรอ hedge ใหม่ → เมื่อมี hedge ใหม่เปิด → เริ่มนับ oldest ใหม่อัตโนมัติ ✅

#### 6. Dashboard display

เพิ่มบรรทัด:
```
Seq Release | ON  | Active: Set#1 (Oldest)  | Frozen: 4 sets
Seq Release | OFF | All sets recover in parallel
```

### สิ่งที่ไม่เปลี่ยนแปลง

- Order Execution Logic (trade.Buy/Sell/PositionClose) — ไม่แก้
- Trading Strategy / Grid entry/exit / TP/SL / Trailing — ไม่แก้
- License / News / Time / Data Sync — ไม่แก้
- Triple Gate logic (`IsHedgeCloseAllowed`) — ไม่แก้
- ManageHedgeMatchingClose / BoundAvgTP / PartialClose / GridMode — **ไม่แก้** (แค่ skip การเรียก)
- Hedge open trigger logic — ไม่แก้ (set ใหม่เปิดได้ตามปกติ)
- Balance Guard — ไม่แก้ (ยังทำงานทั่วทั้งระบบ)
- Generation Locked Slot (v6.68) — ไม่แก้ (ใช้ slot index เป็น oldest indicator)
- v6.37–v6.56 features — ไม่แก้

### ผลลัพธ์

- `InpHedge_SequentialRelease = false` → ทำงานเหมือนเดิม 100% (parallel recovery)
- `InpHedge_SequentialRelease = true`:
  - Set#1 recovery เท่านั้นที่ active → ออก grid + matching close จนชุดนี้จบ
  - Set#2…#10 freeze (hedge ค้างไว้ ไม่ทำอะไร)
  - Set#1 จบ → Set#2 เริ่มทำงาน → ทำต่อเรื่อยๆ
  - หมดทุก set → reset → รอ cycle hedge ใหม่ → เริ่มนับ oldest ใหม่

