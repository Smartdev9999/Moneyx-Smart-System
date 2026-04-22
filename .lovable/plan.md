## v6.61 — Sequential Gate ใช้ Hedge Comments เท่านั้น

### ปัญหา
v6.60 scan bound+hedge → หลัง matching close ปิด hedge Gen0 แต่ bound loss orders (`GM_GL#*`) ถูก release เป็น orphan → ParseGen=0 → allowed ค้างที่ 0 → Set#2-#6 freeze ค้าง

### แก้
- `GetSequentialAllowedGeneration()` — เพิ่ม filter `if(StringFind(c, "GM_HD") != 0) continue;` → นับเฉพาะ hedge comments
- `ManageOrphanGrid()` gate — เปลี่ยน `gen != seqAllowed` → `gen > seqAllowed` (orphan เก่า/เท่า → recover ได้, orphan ใหม่กว่า hedge → freeze)
- Dashboard: `Allowed Hedge: GenN (GM_HD(N+1))` / `No active hedge — full trading + free orphan recovery`

### ไฟล์
- `public/docs/mql5/Gold_Miner_EA.mq5` → v6.61

### ไม่เปลี่ยน
- Order Execution / Strategy / Entry / Grid distance / Lot calc
- License / News / Time / Triple Gate / Hedge open trigger / Matching Pool (v6.60) / BB Filter / Balance Guard
- `ParseGenerationFromComment()` / `ManageHedgeSets()` freeze logic
- Initial entry ของ new cycle (v6.59)
- v6.37–v6.60 features
