## v6.57 — Sequential Recovery Manager + Comment Reset Fix

### ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

### สิ่งที่เพิ่ม
1. **Recovery Grid แยก** จาก Grid Loss (`Recovery_UseSeparate` toggle + พารามิเตอร์ครบชุด) ใช้กับ orphan/bound recovery เท่านั้น
2. **Sequential Hedge Recovery** (`InpHedge_SequentialRecovery`) — ปลดทีละชุดเริ่ม oldest (FIFO ผ่าน `hedgeOpenTime`) แต่ยังเปิด hedge ใหม่ได้
3. **Flat-Detect Reset** — auto-reset `g_cycleGeneration` ใน `OnTick` และ `RecoverHedgeSets` เมื่อ account flat → comment กลับเป็น `GM`

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution / Strategy / Core Module Logic — ไม่แก้
- Grid Loss ของออเดอร์ปกติ — ไม่แก้
- Hedge open / Triple Gate / Matching Close ตรรกะภายใน — ไม่แก้
- Balance Guard / News / License — ไม่แก้
- v6.37–v6.56 features — ไม่แก้
