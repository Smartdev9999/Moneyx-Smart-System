

## Fix: H2-H4 Net Lot Calculation + Partial Close Orphan Bug (v5.17 → v5.18)

### สิ่งที่แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. H2-H4 Net Imbalance Calculation (แทน unboundCounterLots)
- คำนวณ `cycleBuyLots` vs `cycleSellLots` รวมทุก order ใน cycle (normal + hedge + grid)
- ใช้ `IsBelongsToCycle()` เช็คว่า order อยู่ใน cycle ไหน
- `hedgeLots = MathAbs(buyLots - sellLots)` → ล็อค net exposure เป็น 0 ทุก level

#### 2. เพิ่ม `IsBelongsToCycle()` helper function
- เช็ค bound tickets, hedge tickets, grid tickets ของ sets ใน cycle นั้น
- Unbound normal orders → belongs to current active cycle

#### 3. ManageHedgePartialClose — ป้องกัน Orphan Orders
- เมื่อ hedge ถูกปิดหมด (`closeLots >= hedgeLots`) → เช็ค boundTicketCount
- ถ้ายังมี bound orders → เข้า Grid Recovery (gridMode = true)
- ถ้าไม่มี → deactivate set ตามปกติ

#### 4. Version bump: v5.17 → v5.18

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Normal Matching Close logic
- Dashboard / Hedge Cycle Monitor
- Grid Recovery lot calculation + direction logic
- Hedge Guards 1-3 (hasCounterOrders, same-direction, alternate-direction)
