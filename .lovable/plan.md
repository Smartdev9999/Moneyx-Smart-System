## v6.65 — Netting Pre-Gate + Orphan Continuous GL

### ปัญหา
Gen1 (Set#2 bound) มีกำไรล้วน +$3,290 แต่ระบบไม่ปิด เพราะ Triple Gate ของ Set#2 ยังไม่ผ่าน → netting v6.64 ที่อยู่หลัง gate ไม่เคยรัน. Orphan GL ออกได้แค่ 1 ตัว/แท่งเพราะ global `g_lastOrphanGridCandleTime` block

### แก้
- ย้าย `RunBoundProfitLossNetting` ใน `ManageHedgeSets()` มา **ก่อน** `IsHedgeCloseAllowed()` (netting แตะแค่ bound, skip hedge — ปลอดภัยต่อ Triple Gate)
- เพิ่ม per-tick netting fallback ที่ต้น `ManageHedgeSets()` (1 ครั้ง/tick สำหรับ `seqAllowedGen`) เพื่อ scan รวม bound ที่กระจายระหว่าง active set + orphan group
- ลบ global `g_lastOrphanGridCandleTime` gate ใน `ManageOrphanGrid()` (และ 2 จุด assignment) → orphan GL ขยาย level ต่อเนื่องในแท่งเดียวได้ตามระยะราคา (ยังถูก gate ด้วย distance check + MaxOpenOrders + GridLoss_MaxTrades)
- Version → v6.65

### ไฟล์
- `public/docs/mql5/Gold_Miner_EA.mq5` → v6.65

### ไม่เปลี่ยน
- Order Execution / Strategy / Entry / Grid distance / Lot calc
- License / News / Time / Triple Gate logic / Hedge open trigger / BB Filter / Balance Guard
- `RunBoundProfitLossNetting()` core algorithm (แค่ย้ายตำแหน่งเรียก)
- `ManageHedgeMatchingClose()` / `ManageHedgeBoundAvgTP()` / `ManageHedgePartialClose()`
- Sequential gate v6.63 / Initial entry v6.59
- v6.37–v6.64 features
