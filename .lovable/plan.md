## v6.63 — In-Set Match Always + Persistent Hedge Slot Numbering

### ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

### สิ่งที่แก้
1. `ManageHedgeSets()`: ปลด block ของ Sequential Recovery Owner สำหรับ matching/AvgTP/PartialClose — ทุก set รัน in-set matching ของตัวเองได้ทุก tick (v6.62 strict in-set ปลอดภัย ไม่ leak)
2. ใช้ flag `blockGridForThisSet` แทน `continue` — owner lock จะ block เฉพาะ recovery grid (TryEnterCombinedGridMode + ManageHedgeGridMode) ของ non-owner sets เท่านั้น
3. คง one-tick handoff `g_sequentialRecoveryCompletedThisTick` — ยัง pause เต็ม tick หลังจบ owner
4. `FindFreeHedgeSlot()` เขียนใหม่: หา `maxActiveSlot` แล้วคืน slot+1 (ไม่ reuse ช่องว่างกลาง) จนกว่า array จะ flat ทั้งหมด → reset เป็น slot 0 = GM_HEDGE_1
5. Fallback: ถ้า slot ปลายเต็ม → หาช่องว่างกลางกัน overflow
6. Logging v6.63: SLOT ASSIGN log ทุกการจัด hedge slot
7. Version bump v6.62 → v6.63 ทุกจุด

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution / Strategy / Signal / Initial/Loss/Profit Grid — ไม่แก้
- `ManageHedgeMatchingClose()` v6.62 strict in-set pool — ไม่แก้
- `ManageHedgeBoundAvgTP()` / `ManageHedgePartialClose()` / `ProbeSetProfit()` — ไม่แก้
- Hedge open trigger / Triple Gate / DD threshold / Reverse logic — ไม่แก้
- Sequential Recovery Owner concept v6.59-v6.60 — คง (ปรับเฉพาะ scope: block grid ไม่ block matching)
- `RecoverHedgeSetsFromOpenPositions()` — ไม่แก้ (comment number = array index ตรงเดิม)
- Re-hedge Guard v6.58 / BB Filter v6.56 / Recovery Grid v6.57 / Match Pool v6.61 / Strict In-Set v6.62 — ไม่แก้
- Accumulate Close / Balance Guard / News / License / Time Filter — ไม่แก้
