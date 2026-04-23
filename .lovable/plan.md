

## v6.78 — Hedge Confirmation Delay (Cooldown เป็น "นาที") กัน False Signal

### เป้าหมาย
เพิ่มดีเลย์/คูลดาวน์เป็น **นาที** ก่อนที่เงื่อนไขเปิด Hedge จะทำงานอีกครั้ง เพื่อกัน false signal ตอนตลาดสะบัด เช่น ตั้ง 30 นาที → หลังเปิด hedge ครั้งล่าสุด (หรือหลังปิด hedge ครั้งล่าสุด) ระบบจะรออย่างน้อย 30 นาทีจึงเปิด hedge ใหม่ได้

### ไฟล์ที่จะแก้
- `public/docs/mql5/Gold_Miner_EA.mq5`

### สิ่งที่จะเพิ่ม
1) **Input ใหม่ (นาที)**
   - `InpHedge_OpenDelayMin` (default `0` = ปิดฟีเจอร์, ตั้ง `30` = รอ 30 นาที)
   - `InpHedge_OpenDelayMode` enum: `AFTER_LAST_OPEN` (นับจาก hedge ล่าสุดที่เปิด) | `AFTER_LAST_CLOSE` (นับจาก hedge ล่าสุดที่ปิด) | `BOTH` (ใช้ค่ามากสุดของทั้งสอง) — default `BOTH`
   - ใช้ตัวแปรเดิม `g_lastHedgeBuyTime` / `g_lastHedgeSellTime` (เปิดล่าสุด) และ `g_lastHedgeCloseTime` (ปิดล่าสุด) ที่มีอยู่แล้ว — ไม่เพิ่มสถานะใหม่

2) **Helper ใหม่ (read-only gate)**
   - `bool IsHedgeOpenDelayActive(int &remainSec)` — คืน true ถ้ายังอยู่ในช่วงดีเลย์ พร้อมเวลาที่เหลือ (วินาที) สำหรับโชว์ dashboard
   - คำนวณ `elapsed = TimeCurrent() - referenceTime` เทียบกับ `InpHedge_OpenDelayMin*60`

3) **จุดที่บังคับใช้ delay (เฉพาะชั้น "ขออนุญาตเปิด hedge")**
   - ต้นฟังก์ชัน `CheckAndOpenHedge()` (Expansion trigger) → ถ้า delay active → return + log throttled
   - ต้นฟังก์ชัน `CheckAndOpenHedgeByDD()` (DD%/DD$ trigger) → ถ้า delay active → return + log throttled
   - **ไม่แตะ** `OpenOrder/trade.Buy/trade.Sell`, ไม่แตะเงื่อนไข Squeeze/Expansion/DD threshold, ไม่แตะ Grid/TP/SL/Recovery

4) **Dashboard**
   - เพิ่มแถว `HedgeDelay`: แสดง `OFF` หรือ `WAIT 22m13s (mode=BOTH, 30m)` เมื่อ active

5) **Log throttle**
   - พิมพ์ครั้งเดียวต่อ 60s: `v6.78 HEDGE DELAY: wait 22m13s before next hedge (mode=BOTH, cfg=30m)`

6) **Version bump**
   - `#property version`, `#property description`, header block, `OnInit/OnDeinit`, dashboard header → **v6.78**

### สิ่งที่ "ไม่เปลี่ยนแปลง"
- ไม่แก้ `OrderSend / trade.Buy / trade.Sell / trade.PositionClose / trade.PositionClosePartial`
- ไม่แก้กลยุทธ์เข้าออเดอร์ (BB/Squeeze/Entry conditions)
- ไม่แก้ Grid Loss / Grid Profit / TP / SL / Trailing / Breakeven
- ไม่แก้ DD threshold / Triple Gate / Matching Close / Sequential Recovery
- ไม่แก้ License / News / Time filter / Data sync
- ไม่แก้ logic v6.72–v6.77 (ClearTP, NoReHedge gen-side, Cross-gen guard, Owner skip-forward, ฯลฯ)

### ผลลัพธ์ที่คาดหวัง
- ตั้ง `InpHedge_OpenDelayMin = 30` → หลัง hedge ล่าสุดเปิด/ปิด ระบบจะ **บล็อก** การเปิด hedge ใหม่ทุกชนิด (Expansion + DD%/DD$) เป็นเวลา 30 นาที
- ถ้าตลาดเป็น false signal ที่กลับตัวภายใน 30 นาที → hedge ไม่ถูกเปิดเพิ่ม → ลด over-hedge
- ตั้ง `0` = ทำงานเหมือนเดิมทุกประการ (backward-compatible)

### ความเสี่ยง & Mitigation
- **Risk:** ถ้าตลาดวิ่งแรงในช่วง delay จริงๆ → DD ลึกกว่าปกติเพราะยังไม่เปิด hedge
- **Mitigation:** Balance Guard, Max Grid Trailing, Daily Target ยังทำงานครบ + ผู้ใช้ปรับค่า delay ได้เอง (แนะนำเริ่ม 15–30 นาที)
- **Risk:** ผู้ใช้ลืมว่ากำลัง delay อยู่
- **Mitigation:** Dashboard แสดงนับถอยหลังเหลือกี่นาทีกี่วินาทีตลอดเวลา

