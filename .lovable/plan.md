

## v6.55 — Matching Close ไม่ปิด Bound Orders (ปล่อยเป็น Recovery แทน)

### ปัญหาปัจจุบัน

`ManageHedgeMatchingClose()` เมื่อ Triple Gate ผ่าน + hedge มีกำไร → ปิด hedge order + ปิด bound loss orders (matching กำไร vs ขาดทุน) → **bound orders ถูกปิดทิ้ง**

ผู้ใช้ต้องการ:
1. **Bound orders ที่ยังผูก hedge → ห้ามปิด** — Matching Close ไม่ทำอะไรกับ bound orders
2. **Matching Close ทำงานกับ non-bound orders เท่านั้น** (order generation ใหม่ที่ไม่ได้ถูกผูก)
3. **เมื่อ hedge set ถูกปลด (deactivate)** → bound orders ถูก release กลับเป็น "recovery" orders → ระบบ orphan recovery / normal grid จัดการต่อ
4. **ถ้า InpHedge_UseMatchingClose = false** → ไม่ทำอะไรเลย รอ Balance Guard เท่านั้น (ยังเหมือนเดิม)

### แผนแก้ไข — ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Version bump → v6.55

#### 2. แก้ `ManageHedgeMatchingClose()` — ไม่ปิด bound loss orders

**เดิม** (lines 9538-9544):
```cpp
// Close matched losses + remove from boundTickets
for(int cl = 0; cl < lossUsed; cl++)
{
   trade.PositionClose(lossTickets[li]);
   RemoveBoundTicket(idx, lossTickets[li]);
}
```

**ใหม่**: ลบ loop ปิด bound orders ออก → เมื่อ hedge มีกำไรพอ → ปิดแค่ hedge order + reverse orders → **release** bound orders กลับเป็น normal (ไม่ปิดทิ้ง)

```cpp
// v6.55: Do NOT close bound loss orders — release them as recovery orders
// Only close hedge order + reverse orders
trade.PositionClose(g_hedgeSets[idx].hedgeTicket);

// Close profitable reverse orders
for(pr...) { trade.PositionClose(profitableReverseTickets[pr]); }

// Release bound orders → they become recovery orders
Print("v6.55 RELEASE: ", g_hedgeSets[idx].boundTicketCount, " bound orders → recovery");
SaveBoundTicketsToPrevHedged(idx);
// Deactivate set (bound orders remain open as recovery)
g_hedgeSets[idx].active = false;
g_hedgeSets[idx].boundTicketCount = 0;
```

#### 3. แก้ branch "no matchable losses" ให้เหมือนกัน

Branch `else` (lines 9558-9578) ปัจจุบันก็ release อยู่แล้ว — **ไม่ต้องแก้** (ทำงานถูกต้องแล้ว)

#### 4. แก้ `ManageHedgeBoundAvgTP()` และ `ManageHedgePartialClose()` — ไม่ปิด bound orders

ทั้ง 2 ฟังก์ชันนี้ก็ปิด bound orders เช่นกัน:
- `ManageHedgeBoundAvgTP`: ปิด bound orders ด้วย avg TP
- `ManageHedgePartialClose`: ปิด bound orders บางส่วน + partial close hedge

ต้องแก้ให้ **ไม่ปิด bound orders** เช่นกัน — เมื่อ hedge in loss → ปล่อยไว้ → รอ Balance Guard หรือ hedge กลับมามีกำไรแล้ว release

#### 5. ผลลัพธ์สรุป

```text
Hedge active + bound orders → Matching Close = ปิดแค่ hedge (ถ้ามีกำไร) + release bounds
                             → BoundAvgTP = ข้าม (ไม่ปิด bound)
                             → PartialClose = ข้าม (ไม่ปิด bound)
Hedge released → bound orders กลับเป็น recovery → orphan recovery/normal grid จัดการ
UseMatchingClose = false → ข้ามทุกอย่าง → รอ Balance Guard
```

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic — ไม่แก้
- Trading Strategy Logic — ไม่แก้
- Core Module Logic — ไม่แก้
- Grid entry/exit logic — ไม่แก้
- Balance Guard — ยังทำงานปกติ
- Triple Gate logic — ไม่แก้
- `IsTicketBound` / `IsHedgeComment` guards — ไม่แก้
- v6.37-v6.54 features — ไม่แก้

