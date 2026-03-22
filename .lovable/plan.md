


## Fix: Basket TP ปิด Order ที่ Bound กับ Hedge — Skip Bound Orders (v5.6 → v5.7)

### สิ่งที่แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. `CalculateAveragePrice()` — เพิ่ม `IsTicketBound(ticket) continue`
- Basket TP ไม่รวม order ที่ผูกกับ hedge set ในการคำนวณ Average Price

#### 2. `CalculateFloatingPL()` — เพิ่ม `IsTicketBound(ticket) continue`
- Floating P/L ไม่รวม order ที่ผูกกับ hedge set

#### 3. `CloseAllSide()` — เพิ่ม `IsTicketBound(ticket) continue`
- TP Hit ไม่ปิด order ที่ผูกกับ hedge set

#### 4. `CalculateAveragePriceTF()` — เพิ่ม skip hedge + bound
#### 5. `CalculateFloatingPL_TF()` — เพิ่ม skip hedge + bound
#### 6. `CloseAllSideTF()` — เพิ่ม skip hedge + bound

#### 7. Version bump: v5.6 → v5.7

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge logic ทั้งหมด (Partial/Matching/Grid Close)
- Normal Matching Close logic
- Dashboard / Hedge Cycle Monitor
