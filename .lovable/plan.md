

## ปรับระบบ Hedging ให้ Bound Orders แยกจากระบบปกติสมบูรณ์ — Gold Miner SQ EA (v5.1 → v5.2)

### สิ่งที่แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### กลุ่ม 1: เพิ่ม `IsTicketBound(ticket) continue` ใน 4 ฟังก์ชัน
- `CalculateAveragePrice()` — ไม่นับ bound orders ในการคำนวณ avg price
- `CalculateFloatingPL()` — ไม่นับ bound orders ใน floating PL
- `CloseAllSide()` — ไม่ปิด bound orders ผ่าน basket TP/SL
- `ManageMatchingClose()` — ไม่ใช้ bound orders ใน matching close ปกติ

#### กลุ่ม 2: ManageHedgePartialClose ปิดเฉพาะ N orders ใหม่สุด
- เรียงตาม open time (newest first)
- ปิดเฉพาะ `InpHedge_PartialMinProfitOrders` orders ไม่ใช่ทั้งหมด
- bound orders เก่ายังอยู่ → รอกำไรรอบถัดไป

#### กลุ่ม 3: GetHedgeLotCap + Lot Cap ใน OpenOrder
- `GetHedgeLotCap(side)` → คำนวณ `hedgeLots - boundLots`
- `OpenOrder()` → cap lot ไม่ให้เกิน allowedLots, block ถ้า ≤ 0

#### Version bump: v5.1 → v5.2

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL calculations)
- Core Module Logic (License, News filter, Time filter, Data sync, Squeeze)
- Hedge Grid distance/direction logic
- ManageHedgeMatchingClose (Scenario 1) logic
- Accumulate/Drawdown close logic
