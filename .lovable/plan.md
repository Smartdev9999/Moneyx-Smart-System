

## Fix: Stalled Hedge Recovery + IsHedgeTicket + Counter-Side Grid (v5.14 → v5.15)

### สิ่งที่แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Stalled Hedge Detection ใน ManageHedgePartialClose()
- เมื่อไม่มี profit orders (profitCount==0) + hedge+bound ติดลบทั้งหมด → เข้า gridMode ทันที
- คำนวณ gridLevel จาก totalLots (hedge + bound) ด้วย CalculateEquivGridLevel()

#### 2. ManageGridRecoveryMode() — รองรับ 2 สถานะ
- `hedgeTicket > 0`: grid เปิดฝั่ง counter-side (ตรงข้าม hedge) สร้าง profit ไป partial close hedge
- `hedgeTicket == 0`: grid เปิดฝั่ง same-side (เหมือนเดิม) match bound orders
- Lot calculation ใช้ total remaining (hedge+bound) ผ่าน CalculateEquivGridLevel()
- Grid limit ขยายเป็น equivLevel + 5 (จาก +3)

#### 3. ManageHedgeSets() Routing — แยก gridMode + hedge ยังอยู่
- `gridMode && hedgeTicket == 0` → ManageHedgeGridMode() (เดิม)
- `gridMode && hedgeTicket > 0` → ManageGridRecoveryMode() (ใหม่ v5.15)

#### 4. IsHedgeTicket() Helper — จับ hedge order ที่ไม่มี comment
- สแกน g_hedgeSets[].hedgeTicket เทียบกับ ticket
- เพิ่มใน 12 จุดที่ใช้ IsHedgeComment: CountPositions, CalculateAveragePrice, CalculateFloatingPL, CloseAllSide, FindMaxLotOnSide, FindLastOrder, CalculateAveragePriceTF, CalculateFloatingPL_TF, CloseAllSideTF, CountNormalOrders, CountUnboundOrders, CheckAndOpenHedge

#### 5. Version bump: v5.14 → v5.15

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge Guards (cycle-aware, squeeze directional block)
- Normal Matching Close logic
- Dashboard หลัก (ข้อมูลอื่นๆ)
