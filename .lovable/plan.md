# Gold Miner EA v6.86 — Max Grid Avg Trailing: นับ Grid Profit ใน Generation เดียวกันด้วย

ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

## ปัญหา

ฟังก์ชัน Max Grid Average Trailing Stop ตอนนี้คำนวณค่าเฉลี่ยจากแค่ `INIT + GL` (Grid Loss) ของ generation เดียวกันเท่านั้น — ไม่นับ `GP` (Grid Profit) ทำให้ค่าเฉลี่ยไม่สะท้อนภาพจริงของ basket เมื่อมี Grid Profit เปิดอยู่

ผู้ใช้ต้องการให้ค่าเฉลี่ย = INIT + GL + **GP** ภายใน generation + side เดียวกัน

## การแก้ไข (เฉพาะ helper functions ที่ใช้กับ MaxGridTrailing เท่านั้น)

แก้ 3 จุดใน `Gold_Miner_EA.mq5` (ทั้งหมดเป็น helper ของ Max Grid Trailing เท่านั้น — ไม่กระทบ trading logic อื่น):

### 1. `CalcGenAveragePrice(gen, side)` — บรรทัด 3332-3358
- เปลี่ยน filter จาก `_INIT || _GL` → `_INIT || _GL || _GP`
- ใช้ weighted average เดิม (price × lots / total lots)

### 2. `CountGenOrders(gen, side)` — บรรทัด 3363-3381
- เพิ่ม `_GP` ในการนับ เพื่อให้ logic auto-advance generation (ที่เช็คว่า gen นั้นยังมี order อยู่หรือไม่) เห็น GP ด้วย
- ป้องกันกรณี gen นั้นเหลือแค่ GP แล้ว trailing เลื่อนข้าม gen ทิ้งไป

### 3. `CloseGenSide(gen, side)` — บรรทัด 3386-3404
- เมื่อ trailing SL ยิง ให้ปิด `_INIT + _GL + _GP` ของ gen+side นั้น (ครบทั้ง basket ของ generation)
- เดิมปิดเฉพาะ INIT+GL ทำให้เหลือ GP ค้าง

### 4. ห้ามแตะ `CountGenGridLoss()`
- ใช้ตัวเลขนี้เป็นเกณฑ์เปิดใช้ trailing (`requiredOrders_Buy/Sell`) — ต้องนับเฉพาะ GL ตามเดิม ไม่งั้นเงื่อนไข "ถึง MaxGridTrades แล้ว" จะเพี้ยน

## สิ่งที่ไม่เปลี่ยนแปลง (ยืนยัน)

- ❌ ไม่แตะ Order Execution (OrderSend / trade.Buy / trade.Sell)
- ❌ ไม่แตะ Strategy Logic (SMA/EMA, Grid entry/exit, TP/SL ปกติ, Accumulate, Drawdown exit, Hedge, Triple-Gate)
- ❌ ไม่แตะ `CalculateAveragePrice()` (avg ของระบบ TP/SL หลัก) — ยังคงนับ INIT+GL+GP เหมือนเดิมเพราะมันรวมทุกตัวอยู่แล้ว
- ❌ ไม่แตะ `ManageTrailingStop()` (Average Trailing ตัวหลัก v6.85)
- ❌ ไม่แตะ License / News / Time Filter / Sync
- ❌ ไม่แตะ `CountGenGridLoss()` (เกณฑ์ trigger)
- ❌ ไม่แตะ Recovery / Orphan / Hedge Set logic

## Version Bump

v6.85 → **v6.86** อัปเดตทุกจุด:
- `#property version "6.86"`
- `#property description` เพิ่มบรรทัด: "v6.86: Max Grid Avg Trailing now includes Grid Profit orders in the same generation (avg price + close set)"
- Header comment block
- OnInit/OnDeinit log
- Dashboard `headerVersion`

## Memory

สร้าง `mem://trading/gold-miner-ea/maxgrid-trail-include-gp-v6-86.md` บันทึกว่า MaxGridTrailing คำนวณ avg + close จาก INIT+GL+GP ของ gen+side เดียวกัน และอัปเดต index
