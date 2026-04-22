## v6.64 — Profit-Loss Netting (ซอย/หักลบ) สำหรับ Allowed Generation

### ปัญหา
v6.63 ปลด Set#1 ได้ แต่พอ allowed เลื่อนเป็น Gen1 ที่มีออเดอร์กำไรล้วน ระบบไม่ทำอะไร — ไม่ปิดกำไร, ไม่หักลบ loss orders, แค่เปิด GL grid เพิ่ม

### Root Cause
- `ManageHedgeMatchingClose()` exit เมื่อ `hedgePnL <= 0` → bound profit pool ไม่ถูกใช้
- `ManageOrphanGrid()` ไม่มี netting logic — มีแต่ grid expansion

### แก้
- เพิ่ม `RunBoundProfitLossNetting(int gen)` — รวบรวม bound orders ของ gen, แยก profit/loss, ใช้ profit pool หัก loss orders เก่าสุดด้วย greedy match (budget = totalProfit − InpHedge_MatchMinProfit), ปิด profit-only ถ้าไม่มี loss
- เรียก netting ใน `ManageOrphanGrid()` ก่อน count/expansion
- เรียก netting ใน `ManageHedgeSets()` หลัง gate-pass เมื่อ `boundGeneration == g_seqAllowedGen` (ไม่สนว่า hedge profit/loss)
- Skip ทั้งหมดถ้า `InpHedge_UseMatchingClose = false` หรือ `gen != g_seqAllowedGen` (ใน sequential mode)
- Dashboard แถว "Netting" แสดง last result + net + เวลา
- Version → v6.64

### ไฟล์
- `public/docs/mql5/Gold_Miner_EA.mq5` → v6.64

### ไม่เปลี่ยน
- Order Execution / Strategy / Entry / Grid distance / Lot calc
- License / News / Time / Triple Gate / Hedge open trigger / Matching Pool / BB Filter / Balance Guard
- `GetSequentialAllowedGeneration()` v6.63
- `ParseGenerationFromComment()` v6.63
- `ManageHedgeMatchingClose()` (profitable hedge path)
- `ManageHedgeBoundAvgTP()` / `ManageHedgePartialClose()`
- v6.37–v6.63 features
