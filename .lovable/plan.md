

## v6.52 — ปิด Matching Close = ปิดกลไกปิด Hedge ทั้งหมด (เหลือแค่ Balance Guard)

### หลักการ

1. **ปัญหา**: v6.51 ปิดแค่ `ManageHedgeMatchingClose()` แต่ระบบยังรัน BoundAvgTP, PartialClose, GridMode
2. **Fix**: เมื่อ `InpHedge_UseMatchingClose = false` → `continue` ข้ามทั้ง STEP 1 + STEP 2 → Balance Guard เป็นตัวเดียวที่ปิด hedge ได้
3. **Version bump**: v6.51 → v6.52

### ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

### สิ่งที่ไม่เปลี่ยนแปลง
- Balance Guard — ยังทำงานปกติ
- Order Execution Logic — ไม่แก้
- Trading Strategy Logic — ไม่แก้
- Core Module Logic — ไม่แก้
- `ManageHedgeMatchingClose()` function body — ไม่แก้
- Grid entry/exit logic — ไม่แก้
- Deferred Data Sync (v6.49) / InstantTP (v6.50) — ไม่แก้
- v6.37-v6.51 features — ไม่แก้
