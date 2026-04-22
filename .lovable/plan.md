## v6.58 — Sequential Release: Block Recovery Grid on Frozen Generations

### หลักการ
- v6.57 freeze เฉพาะ `ManageHedgeSets()` แต่ orphan grid + main per-gen grid ยังออก order พร้อมกัน
- v6.58 เพิ่ม `GetSequentialAllowedGeneration()`:
  - ON + มี hedge set active → allowed = oldest hedge slot index (= bound gen, v6.68)
  - ON + ไม่มี hedge แต่มี orphan → allowed = oldest orphan generation
  - ON + ไม่มีอะไรเลย → -1 (unrestricted)
  - OFF → -1
- OnTick คำนวณ `g_seqAllowedGen` ก่อน flag → ถ้า allowed != current `g_cycleGeneration` → set `g_newOrderBlocked = true` (block initial + grid loss/profit ใหม่ทั้งหมดของ cycle gen)
- `ManageOrphanGrid()` skip orphan group ที่ generation != allowed

### ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`
- Version → v6.58 (#property version, description, init/deinit/header logs)
- Global var `g_seqAllowedGen`
- Helper `GetSequentialAllowedGeneration()` (วางถัดจาก `GetOldestActiveHedgeSetIndex`)
- OnTick: คำนวณ allowed gen → block current cycle gen ถ้าไม่ match
- `ManageOrphanGrid()` loop: skip non-allowed orphan generations
- Dashboard "Seq Release" แสดง Allowed Gen + Frozen Hedge + Frozen Orphans

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution / Strategy / Core Module Logic — ไม่แก้
- Hedge open/close, Triple Gate, Matching, BoundAvgTP, PartialClose — ไม่แก้
- Balance Guard, BB Filter, News/Time/License — ไม่แก้
- Grid distance/lot/candle confirmation — ไม่แก้
- Hedge orders เปิดได้ปกติทุก gen
- v6.37–v6.57 features — ไม่แก้
