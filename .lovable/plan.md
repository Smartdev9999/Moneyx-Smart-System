## v6.62 — Strict In-Set Pooling (Hedge/Reverse/Bound treated uniformly)

### ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

### สิ่งที่แก้
1. `ManageHedgeMatchingClose()` เขียนใหม่ — unified pool: hedge + reverse + bound เป็นสมาชิก set เดียวกัน
2. ทุก position บวก → profit pool / ทุก position ลบ → loss pool (รวม hedge ที่ติดลบด้วย)
3. Greedy fit by `|loss|` desc, partial close คง set ACTIVE → recovery grid ทำงานต่อ
4. เพิ่ม `ProbeSetProfit(idx)` → quick scan in-set profit
5. Trigger gate ใน `ManageHedgeSets()`: เปลี่ยนจาก `if(hedgePnL > 0)` → `if(ProbeSetProfit > MatchMin)` → matching เข้าได้แม้ hedge ติดลบ ถ้า bound ฝั่งตรงข้ามบวก
6. Cleanup ตาม kind: hedge=0 / RemoveReverseHedgeTicket / RemoveBoundTicket
7. Strict isolation: ไม่แตะ ticket ของ set อื่น (no cross-set leak)
8. Version bump v6.61 → v6.62 ทุกจุด

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution / Strategy / Signal / Initial Grid — ไม่แก้
- `ManageHedgeBoundAvgTP()` / `ManageHedgePartialClose()` — ไม่แก้
- Hedge trigger / Triple Gate / DD threshold / Reverse trigger — ไม่แก้
- Sequential Recovery Owner v6.59-v6.60 — ไม่แตะ
- Re-hedge guard v6.58 / BB Filter v6.56 / Recovery Grid v6.57 — ไม่แก้
- Accumulate Close — ไม่แก้ (กลไกเดียวที่ข้าม set ได้ตามที่ user ระบุ)
- Balance Guard / News / License / Time Filter — ไม่แก้
