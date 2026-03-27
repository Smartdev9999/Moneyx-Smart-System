
## วิเคราะห์สาเหตุ (จากโค้ด v6.12 ปัจจุบัน)

อาการที่คุณเจอ “ยังมี 1 TF เป็น EXPANSION แต่ Grid Hedge/Reverse Grid โผล่” มีโอกาสเกิดจาก 2 จุดหลักพร้อมกัน:

1) **State ของ Squeeze ใช้ค่าแท่งปัจจุบัน (index 0)**
- `UpdateSqueezeState()` ใช้ `CopyBuffer(..., 0, 0, 1, ...)`
- ทำให้สถานะ TF แกว่งได้ระหว่าง tick (Normal ↔ Expansion) ก่อนแท่งปิด
- จึงมีจังหวะ “หลุดเป็น Normal ชั่วคราว 1 tick” แล้ว logic recovery/grid รันได้ แม้ภาพรวมยังดูเหมือน Expansion

2) **ลำดับใน `ManageHedgeSets()` ยังมีทางเข้า Grid ก่อน Matching บางกรณี**
- ในบล็อก `!isExpansion` มีเงื่อนไขเข้า grid mode ทันทีเมื่อ `boundTicketCount == 0 && !HasProfitableReverseOrders()`
- ทำให้เกิดกรณี “ยังไม่ได้ทำ matching cycle ตามที่ต้องการ” แต่เข้าสู่ grid mode แล้ว

---

## แผนแก้ไข (v6.12 → v6.13)

1) **ทำ Gate กลางแบบเคร่งครัด: ต้อง “ครบ 3 TF Normal” จริงก่อน Recovery/Grid**
- เพิ่ม helper กลาง เช่น `IsAllSqueezeTFNormalStrict()`
- ใช้เงื่อนไขเดียวกันทุกจุด (ManageReverseHedge / ManageHedgeSets / จุดเข้า gridMode)
- ไม่ให้แต่ละฟังก์ชันตีความ Normal เองคนละแบบ

2) **ลดการกระพริบสถานะ Squeeze**
- ปรับคำนวณ state จาก “แท่งปิดแล้ว” (index 1) สำหรับ BB/KC intensity
- เพื่อไม่ให้เกิด false-normal ระหว่างแท่งกำลังก่อตัว
- Direction display ยังคงได้ แต่ gate ควรอิง state ที่เสถียรกว่า

3) **บังคับลำดับ Recovery ใหม่ให้ตายตัว**
- เมื่อยังมี Hedge set active:
  - ถ้าไม่ครบ 3 TF Normal → **ห้าม** matching / **ห้าม** grid entry
  - ครบ 3 TF Normal แล้ว → ทำ **Matching/Close cycle ก่อนเสมอ**
  - หลัง matching แล้วค่อยเช็คว่าเหลืออะไรจึงค่อยเข้า combined grid
- ตัดทางเข้า grid ลัดที่ข้าม matching cycle

4) **รวมจุดเข้า Grid ให้เหลือฟังก์ชันเดียว**
- ย้ายการตั้ง `gridMode=true` จากหลายจุด (main loop / AvgTP / PartialClose / dual-track setup) ไปผ่าน `TryEnterCombinedGridMode(idx)` จุดเดียว
- ภายในฟังก์ชันเดียวนี้ตรวจครบ:
  - all 3 TF normal
  - ไม่มี reverse ที่เป็นบวกค้าง
  - matching phase สำหรับรอบนั้นเสร็จแล้ว
  - bound เหลือ 0 ตามเงื่อนไขจริง

5) **ป้องกันการยิง Grid รัวซ้ำรอบ**
- เพิ่ม phase flag ต่อ hedge set (เช่น reset ตอนเจอ expansion, mark done หลัง matching pass)
- กันการเข้า grid ซ้ำก่อน state transition รอบถัดไป

6) **Version bump ตามกฎ**
- อัปเดต v6.13 ทุกจุด: `#property version`, `#property description`, header comment, dashboard version, startup logs

---

## Technical details (สรุปจุดโค้ดที่จะจับ)

- `UpdateSqueezeState()` → เปลี่ยนแหล่งข้อมูล state ให้เสถียร (closed bar)
- `ManageHedgeSets()` → reorder flow: strict normal gate → matching first → then grid decision
- `ManageHedgeBoundAvgTP()` / `ManageHedgePartialClose()` → หยุดตั้ง `gridMode` ตรงๆ, เรียกผ่าน gate กลาง
- `CheckAndSetupDualTrackRecovery()` → ไม่ force grid ทันที ถ้ายังไม่ผ่าน strict gate
- เพิ่ม helper กลาง:
  - `IsAllSqueezeTFNormalStrict()`
  - `CanRunRecoveryCycle(idx)`
  - `TryEnterCombinedGridMode(idx)`

---

## สิ่งที่ไม่เปลี่ยนแปลง

- **Order Execution Logic** (`trade.Buy/Sell/PositionClose`) ไม่เปลี่ยนวิธีส่งคำสั่ง
- **Trading Strategy Logic** (SMA/ZigZag/Instant, Grid หลัก, TP/SL) ไม่แก้สูตรกลยุทธ์
- **Core Module Logic** (License, News/Time filter core, Data sync) ไม่แตะ
- แก้เฉพาะ **sequencing + state gate + recovery orchestration** ของ Hedge/Reverse/Grid เพื่อให้ทำงานตามลำดับที่คุณกำหนดเท่านั้น
