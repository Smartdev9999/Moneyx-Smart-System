

## v6.53 — Fix: Persist g_cycleGeneration + CalculateTotalLots กรอง bound orders

### หลักการ

1. **ปัญหา**: `g_cycleGeneration` เป็น RAM variable → หายเมื่อ restart → ออเดอร์ใหม่ใช้ "GM" แทน "GM1" → TP ถูกตั้งกลับให้ bound orders
2. **Fix 1**: ใช้ `GlobalVariableSet/Get` persist `g_cycleGeneration` ข้าม restart + เปรียบเทียบกับ `RecoverHedgeSets()` ใช้ค่าที่สูงกว่า
3. **Fix 2**: `CalculateTotalLots()` กรอง bound/hedge orders → TP คำนวณจาก lots ที่ถูกต้อง
4. **Version bump**: v6.52 → v6.53

### ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic — ไม่แก้
- Trading Strategy Logic — ไม่แก้
- Core Module Logic — ไม่แก้
- Grid entry/exit logic — ไม่แก้
- Hedge Matching Close / Balance Guard — ไม่แก้
- SyncBrokerTPSL modify loop — ไม่แก้
- Deferred Data Sync (v6.49) / InstantTP (v6.50) / UseMatchingClose (v6.52) — ไม่แก้
- v6.37-v6.52 features — ไม่แก้
