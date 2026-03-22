

## Fix: Cycle ไม่ควรเปลี่ยนเมื่อไม่มี Hedge + เพิ่ม Dashboard Width Input (v5.3 → v5.4)

### ปัญหาที่ 1: Cycle A→B→C→D เลื่อนขึ้นเรื่อยๆ ทั้งที่ไม่โดน Hedge

**สาเหตุ:** ทุกจุดที่เปิด INIT order (SMA line 1200, 1223, ZigZag line 1310, 1326, Instant line 4116, 4139) มี:
```cpp
if(g_hedgeSetCount > 0 && g_currentCycleIndex < 3) g_currentCycleIndex++;
```
ปัญหาคือ `g_hedgeSetCount > 0` เช็คว่ามี hedge **จากชุดก่อนหน้า** แต่เมื่อ order ชุดใหม่ (B) เปิด-ปิดปกติโดยไม่โดน hedge แล้วเปิด INIT อีกครั้ง → ถ้า hedge set เก่ายังไม่หมด → `g_hedgeSetCount > 0` ยังเป็น true → cycle เลื่อนเป็น C, D ทั้งที่ B ไม่โดน hedge

**แก้ไข:** เพิ่ม flag `g_cycleHedged` เพื่อ track ว่า cycle **ปัจจุบัน** ถูก hedge หรือยัง

```text
เพิ่ม global:
  bool g_cycleHedged = false;

แก้ทุกจุด INIT order (6 จุด):
  เดิม: if(g_hedgeSetCount > 0 && g_currentCycleIndex < 3) g_currentCycleIndex++;
  ใหม่: if(g_cycleHedged && g_currentCycleIndex < 3) { g_currentCycleIndex++; g_cycleHedged = false; }

แก้ CheckAndOpenHedge() หลังเปิด hedge สำเร็จ:
  เพิ่ม: g_cycleHedged = true;

Reset ใน CloseAllPositions() + OnInit:
  g_cycleHedged = false;

Reset เมื่อไม่มี order เลย (PositionsTotal for magic == 0):
  g_currentCycleIndex = 0; g_cycleHedged = false;
```

**ผล:** Cycle B→C เกิดขึ้นเฉพาะเมื่อ cycle B **ถูก hedge จริง** ไม่ใช่แค่เพราะ hedge set เก่ายังค้างอยู่

---

### ปัญหาที่ 2: Dashboard ตารางแคบ ข้อมูลล้นออกนอก

**สาเหตุ:** `tblW = (int)(340 * sc)` เป็นค่า hardcode ที่ 340px base width

**แก้ไข:** เพิ่ม input parameter ใหม่:
```cpp
input int DashboardWidth = 340;  // Dashboard Table Width (300-500)
```

แก้ `DrawTableRow()` และ `DisplayDashboard()`:
- เปลี่ยน `(int)(340 * sc)` → `(int)(DashboardWidth * sc)` ทุกจุด
- ปรับ `valueX` ให้สัมพันธ์: `x + (int)((DashboardWidth * 0.53) * sc)` (ประมาณ 53% ของ width)

---

### Version bump: v5.3 → v5.4

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Net Lot Calculation, Hedge Guards, Cross-Set Matching
- Hedge Partial/Matching Close, Grid Mode logic

