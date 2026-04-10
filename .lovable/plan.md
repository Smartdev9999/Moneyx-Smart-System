


## v6.43 — Fix Broker TP/SL + Dashboard Render Throttle

### หลักการ

1. **Fix Broker TP/SL**: ลบ `!EnablePerOrderTrailing` guard ที่ block `SyncBrokerTPSL()` → TP จะปรากฏในออเดอร์ทันที
2. **Dashboard Render Throttle**: render dashboard ทุก 1 วินาทีแทนทุก tick ลด CPU 80-90%
3. **OnInit Dashboard**: แสดง dashboard ทันทีเมื่อลาก EA เข้าชาร์ต
4. **Redundant Calc Fix**: ลบ redundant `CalculateFloatingPL()` / `CalculateTotalLots()` calls

### ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

#### Changes
- Version bump → v6.43
- ลบ `!EnablePerOrderTrailing` จาก SyncBrokerTPSL call condition (OnTick)
- แก้ SyncBrokerTPSL(): set TP เสมอ, set SL เฉพาะเมื่อไม่มี per-order trailing
- เพิ่ม dashboard render throttle (1 วินาที) ใน OnTick
- เพิ่ม `DisplayDashboard()` ใน OnInit
- ลบ redundant `CalculateFloatingPL()` ใน DD%TP section → ใช้ plBuy/plSell จากต้นฟังก์ชัน
- ลบ redundant `CalculateTotalLots()` ใน INFO section → ใช้ lotsBuy+lotsSell

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic — ไม่แก้
- Trading Strategy Logic — ไม่แก้
- Core Module Logic — ไม่แก้
- Dollar/Percent/DD% TP — ยังจัดการผ่าน EA เหมือนเดิม
- Per-Order Trailing Stop logic — ไม่แก้
- Accumulate Close / Drawdown Exit — ไม่แก้
- Grid / Hedge / Balance Guard — ไม่แก้
- v6.37-v6.42 features — ไม่แก้
