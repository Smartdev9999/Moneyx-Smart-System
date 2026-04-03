## Implemented: v6.32 — แก้ Daily Profit Pause ให้ใช้ Equity เทียบ Balance เริ่มต้นวัน และหยุดเมื่อ flat เท่านั้น

### ปัญหาเดิม
1. `CalcDailyPL()` นับเฉพาะ closed deals → Balance เพิ่มจาก closed profit ก็ trigger ทันที ทั้งที่ยังมีออเดอร์ floating อยู่
2. ระบบ pause ทันทีเมื่อ target ถึง → block ออเดอร์ใหม่ทั้งที่ยังมีออเดอร์เปิดค้าง

### แก้ไข (v6.32)
1. **Version bump**: v6.31 → v6.32
2. **เพิ่ม `g_dailyStartBalance`** — snapshot Balance ตอนวันใหม่เริ่ม + OnInit
3. **เปลี่ยนเงื่อนไข trigger**: `Equity - g_dailyStartBalance >= Target` AND `TotalOrderCount() == 0`
4. **Dashboard**: แสดง Equity-based PL + สถานะ "(wait flat)" เมื่อ target ถึงแต่ยังมี order

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic
- Trading Strategy Logic
- Core Module Logic
- DD trigger / Triple-gate / Matching close
- OpenDDHedge / binding / generation logic
- Balance Guard (v6.31) — ไม่แก้
- Resume Daily Profit button — ยังทำงานเหมือนเดิม
- `CalcDailyPL()` — คงไว้ไม่ลบ
