## v6.58 — Sequential Recovery One-Per-Tick + Re-Hedge Guard

### ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

### สิ่งที่แก้
1. **Sequential Recovery ปลดทีละชุดต่อ tick** — เพิ่ม `sequentialActed` flag ใน `ManageHedgeSets()` → H1 ทำงาน → H2/H3 รอ tick ถัดไป (เลิกปลดทุกชุดในรอบเดียว)
2. **Re-Hedge Guard** — เพิ่ม `IsPrevHedgedTicket()` check ที่ทุกจุด bind/scan ของ hedge (Expansion ~7739, Hedge OPEN ~7884, DD bind ~8136, Orphan link ~8323) → ออเดอร์ที่เพิ่ง release จาก hedge จะไม่ถูก hedge ซ้ำ
3. **Dashboard** — โชว์ "Acting: Hx (1/tick)" + "PrevHedged: N ticket(s) locked"

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution / Trading Strategy / Core Module — ไม่แก้
- Grid Loss/Profit/AvgTP ของออเดอร์ปกติ — ไม่แก้
- ManageHedgeMatchingClose / BoundAvgTP / PartialClose ตรรกะภายใน — ไม่แก้
- Recovery Grid v6.57 / BB Filter v6.56 / Triple Gate / Balance Guard — ไม่แก้
- v6.37–v6.57 features — ไม่แก้
