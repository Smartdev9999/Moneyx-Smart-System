## v6.59 — Sequential Recovery Owner Lock + Per-Generation Orphan Gate

### ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

### สิ่งที่แก้
1. **Sequential Recovery Owner**: เพิ่ม state `g_sequentialRecoveryGen / g_sequentialRecoverySetIdx / g_sequentialRecoveryActive / g_sequentialRecoveryCompletedThisTick` + helpers (`SetSequentialRecoveryOwner / ClearSequentialRecoveryOwner / IsSequentialRecoveryComplete / CountAllGenPositions`)
2. **`ManageHedgeSets()` ล็อกชุดอื่นทั้งหมดเมื่อ owner active** — H2/H3 ห้ามทำ matching/avgTP/partial/grid recovery จนกว่า owner generation จะปิดหมด + เพิ่ม one-tick handoff guard
3. **`ManageOrphanGrid()` รัน recovery เฉพาะ owner gen** — gen อื่นถูกข้ามทันที (พร้อม throttled log 30 วินาที)
4. **Set owner ใน 5 release paths**: external close, AvgTP release, matching close (with losses), release close (no matchable losses), grid recover, grid cleanup
5. **Auto-clear owner**: ทุก tick เริ่มของ `ManageHedgeSets()` ตรวจ `IsSequentialRecoveryComplete()` → clear แล้วบล็อก H2 release ใน tick นั้น (handoff)
6. **Dashboard อัปเกรด**: แสดง "LOCKED | Owner GenX (Src Hn) | N order(s) left" เมื่อล็อก, "Sequential | Next Unlock: Hn" เมื่อไม่ล็อก

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution / Trading Strategy / Core Module — ไม่แก้
- `ManageHedgeMatchingClose / BoundAvgTP / PartialClose` ตรรกะภายใน — ไม่แก้
- `FindOldestActiveHedgeSet()` / Triple Gate / DD trigger / Balance Guard — ไม่แก้
- `SaveBoundTicketsToPrevHedged / IsPrevHedgedTicket` — ไม่แก้
- v6.58 `sequentialActed` 1-per-tick guard — คงไว้ (ใช้เป็น fallback กรณี owner ยังไม่ active)
- Recovery Grid v6.57 / BB Filter v6.56 / v6.37–v6.58 features — ไม่แก้
