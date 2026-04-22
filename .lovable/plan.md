## v6.62 — Fix Hedge Comment Prefix (`GM_HEDGE_` not `GM_HD`)

### ปัญหา
v6.61 ใช้ filter `"GM_HD"` แต่ comment จริงคือ `"GM_HEDGE_<n>"` → `StringFind("GM_HEDGE_6","GM_HD")==0` ผ่าน filter แต่ ParseGen ตัด substring ผิด → คืน -1 → gate ปิด → ทุก hedge set ทำงานพร้อมกัน

### แก้
- `ParseGenerationFromComment()` — branch hedge ใช้ prefix `"GM_HEDGE_"` + `StringSubstr(c, 9)`
- `GetSequentialAllowedGeneration()` — filter `if(StringFind(c, "GM_HEDGE_") != 0) continue;`
- Dashboard label: `(GM_HEDGE_(N+1))`
- Version → v6.62 (header / `#property` / dashboard / init+deinit log)

### ไฟล์
- `public/docs/mql5/Gold_Miner_EA.mq5` → v6.62

### ไม่เปลี่ยน
- Order Execution / Strategy / Entry / Grid distance / Lot calc
- License / News / Time / Triple Gate / Hedge open trigger / Matching Pool (v6.60) / BB Filter / Balance Guard
- `ManageHedgeSets()` freeze logic / `ManageOrphanGrid()` gate (รับค่า g_seqAllowedGen ที่ถูกต้องอัตโนมัติ)
- Hedge slot persistence (v6.68) / commentPrefix format
- v6.37–v6.61 features
