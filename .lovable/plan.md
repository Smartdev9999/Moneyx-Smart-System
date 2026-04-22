## v6.59 — Sequential Release: Allow New Cycle Initial Entries

### ปัญหา
v6.58 ตั้ง `g_newOrderBlocked = true` เมื่อ allowedGen != g_cycleGeneration → block initial entry ของ gen ใหม่ → ระบบหยุดเทรดหลัง hedge ครั้งแรก

### แก้
- ลบ `g_newOrderBlocked = true` จาก OnTick (line 1271–1276)
- เก็บแค่ `g_seqAllowedGen = GetSequentialAllowedGeneration()` ไว้ใช้ที่ ManageOrphanGrid + dashboard
- Initial entry / new cycle gen → เปิดได้เสมอ
- Recovery grid (orphan) → ยังถูก gate ทีละ gen ตามเดิม (ManageOrphanGrid)

### ไฟล์
- `public/docs/mql5/Gold_Miner_EA.mq5` → v6.59 (header/property/init/deinit/dashboard)
- Comment block + dashboard label "New cycle entries: ALLOWED"

### ไม่เปลี่ยน
- Order Execution / Strategy / Core Module — ไม่แก้
- Hedge / Triple Gate / Matching / BoundAvgTP / PartialClose — ไม่แก้
- Balance Guard / News / Time / License / BB Filter — ไม่แก้
- ManageOrphanGrid sequential gate — ไม่แก้
- v6.37–v6.58 features — ไม่แก้
