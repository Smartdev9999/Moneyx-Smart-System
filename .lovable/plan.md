## แก้ไข Grid Lot ไม่ต่อเนื่องหลัง Matching Close (Gold Miner EA)

### สิ่งที่แก้ไข
1. เพิ่ม `FindMaxLotOnSide()` — หา lot ใหญ่สุดของ GM_GL/GM_INIT ที่เหลืออยู่
2. แก้ `CheckGridLoss()` — เทียบ lot ที่คำนวณกับ maxExisting, ถ้าเล็กกว่าให้ต่อ martingale จาก lot ใหญ่สุด
3. แก้ `CheckGridLossTF()` — logic เดียวกันสำหรับ ZigZag mode

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (OpenOrder, CloseAllPositions)
- Trading Strategy Logic (SMA/EMA signals, Entry conditions)
- Matching Close logic (ManageMatchingClose)
- Accumulate / Drawdown / TP/SL / Trailing / Breakeven
- License / News / Time Filter / Data Sync
- OnChartEvent buttons / Dashboard
