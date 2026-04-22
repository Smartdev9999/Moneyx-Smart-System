## v6.63 — Strict Sequential Unlock by Lowest Live Generation

### ปัญหา
v6.62 scan เฉพาะ hedge comment `GM_HEDGE_*` → allowed = lowest live HEDGE gen เท่านั้น และ `ManageOrphanGrid()` ใช้ `gen > seqAllowed` → orphan gen ต่ำกว่า allowed วิ่งพร้อมกันได้ทั้งหมด ทำให้หลาย GM ปลดพร้อมกัน

### แก้
- `GetSequentialAllowedGeneration()` v6.63 — scan ทุก position ของ symbol+magic, parse gen จาก comment ใดๆ (bound/hedge/orphan/DD), คืน lowest live gen
- `ParseGenerationFromComment()` — รองรับ `GM_HEDGE_D<n>` (DD-triggered hedge) เพิ่มเติม
- `ManageOrphanGrid()` — gate เปลี่ยนเป็น `gen != seqAllowed` (strict, gen เดียว)
- Dashboard "Seq Release" — แสดง `Allowed Gen: GenN (GM/GMn) | Strict one-by-one`, frozen orphan นับด้วย `!=`
- Version → v6.63 (header / `#property` / dashboard / init+deinit log)

### ไฟล์
- `public/docs/mql5/Gold_Miner_EA.mq5` → v6.63

### ไม่เปลี่ยน
- Order Execution / Strategy / Entry / Grid distance / Lot calc
- License / News / Time / Triple Gate / Hedge open trigger / Matching Pool / BB Filter / Balance Guard
- `ManageHedgeSets()` freeze logic (ใช้ค่าใหม่อัตโนมัติ)
- Initial entry (v6.59 rule preserved)
- v6.37–v6.62 features
