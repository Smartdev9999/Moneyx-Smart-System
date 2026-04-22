## v6.60 — Gen0 Owner Fix + Strict Owner Counter

### ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

### สิ่งที่แก้
1. **Gen0 (GM) claim owner ได้แล้ว**: เปลี่ยน guard ใน `SetSequentialRecoveryOwner()` จาก `gen <= 0` → `gen < 0`
2. **`CountSequentialOwnerOrders(gen)` ใหม่**: นับเฉพาะออเดอร์ recovery ปกติของ generation นั้น โดยใช้ exact prefix (`GM_` สำหรับ Gen0, `GM<n>_` สำหรับ Gen>0) และ **ข้าม** `GM_HEDGE_*`, `GM_HG*`, `GM_RHEDGE*`
3. **`IsSequentialRecoveryComplete()` ใช้ตัวนับใหม่** — owner clear เมื่อ recovery orders จริงปิดหมด ไม่ปนกับ hedge comments
4. **Dashboard ใช้ตัวนับใหม่** (`ownerRemain`) → สะท้อน "N order(s) left" จริง
5. **Log v6.60**: SEQ OWNER claim/skip/complete แสดงชัดเจน

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution / Trading Strategy / Core Module — ไม่แก้
- `ManageHedgeSets()` owner-lock structure / `ManageOrphanGrid()` skip-non-owner — โครง v6.59 คงไว้
- Triple Gate / Matching Close / BoundAvgTP / PartialClose — ไม่แก้
- Re-hedge guard `IsPrevHedgedTicket()` v6.58 / Recovery Grid v6.57 / BB Filter v6.56 — ไม่แก้
- v6.37–v6.59 features — ไม่แก้
- `CountAllGenPositions()` ยังอยู่ (ใช้ที่อื่นใน orphan scan)
