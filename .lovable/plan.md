## v6.61 — Match-Close Pool Both Sides + Partial Close Keeps Set Active

### ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

### สิ่งที่แก้
1. `ManageHedgeMatchingClose()` เขียนใหม่ — pool budget = max(hedge,0) + reverseProfit + boundProfit (ทั้ง 2 ฝั่ง)
2. Loss pool รวม bound losses ทั้ง 2 ฝั่ง (ลบ filter counterSide), sort by magnitude DESC, greedy fit
3. Close: hedge (ถ้า +) + bound profit ที่ใช้เป็น budget + reverse profit + matched losses
4. ใช้ `RemoveBoundTicket()` ตัด ticket ที่ปิดออกจาก boundTickets[] (ไม่ clear ทั้ง array)
5. **Partial close** → set ยัง ACTIVE ต่อ → recovery grid ทำงานต่อ → owner ยังไม่ claim
6. **Full close** (boundCount==0) → deactivate + claim sequential owner ตามเดิม
7. Version bump v6.60 → v6.61 ทุกจุด (property/header/init/deinit/dashboard)

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution / Strategy / Signal / Initial Grid — ไม่แก้
- `ManageHedgeBoundAvgTP()` / `ManageHedgePartialClose()` — ไม่แก้
- Hedge trigger / Triple Gate / DD threshold — ไม่แก้
- Sequential Recovery Owner v6.59-v6.60 / Re-hedge guard v6.58 / BB Filter / Recovery Grid v6.57 — ไม่แก้
- Balance Guard / News / License / Time Filter — ไม่แก้
