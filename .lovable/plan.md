## v6.56 — Bollinger Band Entry Filter (Block New Orders Only)

### หลักการ
- เพิ่ม BB indicator (Upper/Middle/Lower) เป็น Entry Filter
- Block เฉพาะการเปิดออเดอร์ใหม่ (initial + grid loss + grid profit) ผ่าน `OpenOrder()`
- ยกเว้น hedge orders (ใช้ `IsHedgeComment()` guard)

### ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution / Strategy / Core Module Logic — ไม่แก้
- Hedge open/close, Matching Close, Balance Guard, Triple Gate — ไม่แก้
- v6.37–v6.55 features — ไม่แก้
