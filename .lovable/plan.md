## v6.60 — Sequential Release: Comment-Based Gen Scan + Match Pool (Bound Profit)

### ปัญหาเดิม
1. **Match Close**: pool รวมแค่ hedge+reverse → ปิดเฉพาะ bound ที่ขาดทุน, bound ที่กำไรค้างไว้ → ชุดไม่สมดุล
2. **Sequential Recovery**: gate ใช้ `GetOldestActiveHedgeSetIndex()` → หลัง deactivate set#A ทันที set#B เริ่ม recovery ทั้งที่ orphan ของ A ยังไม่หมด → 2 ชุดทำงานพร้อมกัน

### แก้
- `ParseGenerationFromComment()` — map "GM"/"GM_*"→0, "GMN_*"→N, "GM_HD(N+1)"→N
- `GetSequentialAllowedGeneration()` — scan PositionsTotal() คืน gen ต่ำสุดที่ยังมีออเดอร์จริง (bound+hedge)
- `ManageHedgeSets()` seqFreeze ใช้ `boundGeneration != g_seqAllowedGen` แทน slot index
- `ManageHedgeMatchingClose()` — รวม `boundProfitPool` ของ counterSide ที่ pnl>0 เข้า budget + ปิด tickets เหล่านั้นหลัง close reverse
- Dashboard: `Seq Release | ON | Allowed: GenN (GMN_*+GM_HD(N+1)) | Frozen Hedge: X | Frozen Orphans: Y`

### ไฟล์
- `public/docs/mql5/Gold_Miner_EA.mq5` → v6.60

### ไม่เปลี่ยน
- Order Execution / Strategy / Entry signals / Grid distance / Lot calc
- License / News / Time / Triple Gate / Hedge open trigger / Balance Guard / BB Filter
- Initial entry ของ new cycle (v6.59) — ไม่ block
- ManageOrphanGrid sequential gate (v6.58) — ใช้ `g_seqAllowedGen` ค่าใหม่
- v6.37–v6.59 features
