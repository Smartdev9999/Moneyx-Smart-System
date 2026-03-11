## เพิ่ม 2 ฟีเจอร์ให้ Jutlameasu EA v1.0

### ฟีเจอร์ 1: Custom TP/SL Distance
- **Input ใหม่:** `InpUseCustomTPSL`, `InpTPDistance`, `InpSLDistance`
- แยก TP/SL distance ออกจาก Zone → สามารถตั้งกรอบ TP/SL กว้างกว่า Entry Zone ได้
- อัปเดต `StartNewCycle()` ใช้ `tpDist/slDist` แทน `zonePrice` ในการคำนวณ cross-over levels
- Dashboard แสดง Buy SL / Sell SL แยก + โหมด TP/SL Distance

### ฟีเจอร์ 2: Accumulate Close
- **Input ใหม่:** `InpUseAccumulate`, `InpAccMinOrders`, `InpAccTarget`
- เมื่อจำนวน positions >= MinOrders และ floating P/L >= Target → ปิดทั้งหมด + รีเซ็ต cycle
- ฟังก์ชัน `CheckAccumulateClose()` เรียกใน `OnTick()` หลัง `CheckDrawdownExit()`
- Dashboard แสดง Accumulate status + target + floating P/L

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (BuyStop, SellStop, PlaceNextPendingOrder)
- STATE 1-4 flow logic, Martingale level/lot calculation
- Spread Compensation logic
- License / News / Time Filter / Data Sync
- OnChartEvent buttons / Drawdown Protection
