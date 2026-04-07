## Implemented: v6.38 — แก้บัค Orphaned Orders จาก Partial-Side Hedge

### สาเหตุ
เมื่อ Gen N มีออเดอร์ทั้ง BUY และ SELL แต่มีเพียงฝั่งเดียวที่ DD ถึง threshold → ฝั่งที่ hedge แล้วทำให้ `g_cycleGeneration++` → ออเดอร์ฝั่งตรงข้ามจาก Gen N ถูก filter ออกเพราะ `orderGen != curGen` → กลายเป็น orphan สะสมไม่มีระบบจัดการ

### แก้ไข (v6.38)
1. **Version bump**: v6.37 → v6.38
2. **DD Loss Calc** (`CheckAndOpenHedgeByDD`): เปลี่ยน `orderGen != curGen` → `orderGen > curGen` — รวม orphaned orders จากทุก gen เก่า
3. **`CountUnboundOrders()`**: เปลี่ยน `orderGen != genFilter` → `orderGen > genFilter` — นับออเดอร์จากทุก gen ≤ genFilter
4. **Binding Loop** (`OpenDDHedge`): เปลี่ยน `orderGen != bindGen` → `orderGen > bindGen` — bind ออเดอร์จากทุก gen ≤ bindGen

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic, Trading Strategy Logic, Core Module Logic
- DD trigger threshold / Triple-gate / Matching close
- OpenDDHedge flow (เฉพาะ filter condition เปลี่ยน)
- Balance Guard (v6.33/v6.35)
- Daily Target Profit (v6.32)
- Generation Race Condition fix (v6.37)
- Orphan Recovery / PrevHedgedTickets guard
