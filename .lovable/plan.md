## v6.57 — Sequential Hedge Release (Oldest-First, One-at-a-Time)

### หลักการ
- เพิ่ม toggle `InpHedge_SequentialRelease` (default false)
- เมื่อ ON → recovery ทำเฉพาะ hedge set ที่เก่าที่สุด (slot index ต่ำสุด) เท่านั้น
- Set อื่นๆ freeze: ไม่ทำ matching/avgTP/partial/grid (แต่ hedge order, bound orders, expansion tracking ยังอยู่ครบ)
- Set ที่ active เสร็จ → ตัวถัดไปขึ้นมาอัตโนมัติ → หมดทุก set → เริ่มนับใหม่เมื่อมี hedge set ใหม่

### ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`
- เพิ่ม input `InpHedge_SequentialRelease`
- เพิ่ม helper `GetOldestActiveHedgeSetIndex()`
- ใส่ sequential gate ใน `ManageHedgeSets()` ก่อน expansion tracking และ recovery logic
- เพิ่ม Dashboard row "Seq Release" แสดง ON/OFF + Active set + Frozen count

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution / Strategy / Core Module Logic — ไม่แก้
- Triple Gate, Matching Close, BoundAvgTP, PartialClose, Grid Mode — ไม่แก้ (แค่ skip การเรียก)
- Hedge open trigger, Balance Guard, Generation Locked Slot — ไม่แก้
- v6.37–v6.56 features — ไม่แก้
