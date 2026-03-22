

## Fix: Cycle Labeling + Dashboard Width — Gold Miner SQ EA (v5.3 → v5.4)

### สิ่งที่แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Cycle ไม่เปลี่ยนเมื่อไม่โดน Hedge
- เพิ่ม `g_cycleHedged` flag — track ว่า cycle ปัจจุบันถูก hedge หรือยัง
- แก้ 6 จุด INIT order: `if(g_cycleHedged && ...) { increment; g_cycleHedged = false; }`
- `CheckAndOpenHedge()` สำเร็จ → `g_cycleHedged = true`
- Reset ใน `CloseAllPositions()`, `OnInit`, และเมื่อไม่มี position

#### 2. Reset Cycle เมื่อไม่มี Order
- เพิ่มใน OnTick: สแกน positions ถ้า myPositions == 0 → reset cycle A, clear flags

#### 3. Dashboard Width ปรับได้
- เพิ่ม `input int DashboardWidth = 340` (300-500)
- `DrawTableRow()` + `DisplayDashboard()` ใช้ DashboardWidth แทน hardcode 340
- valueX คำนวณจาก `DashboardWidth * 0.53`

#### 4. Version bump: v5.3 → v5.4

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Net Lot Calculation, Hedge Guards, Cross-Set Matching
- Hedge Partial/Matching Close, Grid Mode logic
- Normal Matching Close logic
