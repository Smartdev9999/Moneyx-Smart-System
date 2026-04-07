## Implemented: v6.37 — แก้บัค Hedge ไม่ครบทั้งสองฝั่ง (Generation Race Condition)

### สาเหตุ
เมื่อทั้ง BUY และ SELL ถึง DD threshold พร้อมกัน → ฝั่งแรก hedge แล้ว `g_cycleGeneration++` → ฝั่งที่สองใช้ gen ใหม่ → หาออเดอร์ไม่เจอ → ไม่โดนล็อค

### แก้ไข (v6.37)
1. **Version bump**: v6.36 → v6.37
2. **`CheckAndOpenHedgeByDD()`**: บันทึก `curGen = g_cycleGeneration` เป็น snapshot ก่อนเริ่ม hedge
3. **`OpenDDHedge()` signature**: เพิ่ม parameter `int bindGen` — ใช้แทน `g_cycleGeneration` ทุกจุดภายใน
4. **ทุกจุดเรียก `OpenDDHedge()`**: ส่ง `curGen` (snapshot) แทนการอ่าน global ตรง

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic, Trading Strategy Logic, Core Module Logic
- DD trigger threshold / Triple-gate / Matching close
- OpenDDHedge binding flow (เฉพาะ parameter source เปลี่ยน)
- Balance Guard (v6.33/v6.35)
- Daily Target Profit (v6.32)
- Orphan Recovery / PrevHedgedTickets guard
