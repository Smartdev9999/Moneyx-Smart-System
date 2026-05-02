# Gold Miner EA v6.93 — Hero Order Bugfix

ปัญหาที่ user รายงาน (จากภาพ v6.92):
1. Average Trailing Stop / basket TP ฝั่ง BUY ปิดสำเร็จ แต่ **Hero BUY ถูกปิดไปด้วย** → ไม่เหลือ Hero ตามต้องการ
2. มี Hero BUY ค้างอยู่ แต่ระบบยังออก `GM1_GL#1..GL#22 + GM1_GP#1` ฝั่ง BUY ต่อเรื่อยๆ → **Block ไม่ทำงาน**
3. Hero ที่คงเหลือ ต้อง **ปิดพร้อม same-side basket trail สำเร็จ** (ตาม user: "ฮีโร่ order นี้จะปิดพร้อมกันกับ Average trailing stop **buy**") — ไม่ใช่ปิดเมื่อ opposite-side ปิด

## Root Causes ที่พบใน v6.92

### Bug A — `BuildHeroTicketCache` รัน throttle 1/sec แต่ถูก reset ทุก tick
บรรทัด 2259: `g_heroTicketCount = 0;` ถูกตั้งค่าเป็น 0 **ก่อน** check throttle (บรรทัด 2261). ผลคือทุก tick ที่ throttle hit, cache จะถูก clear เหลือ 0 → `IsHeroTicket()` คืน false ทั้งหมด → Hero ไม่ถูก exclude จาก basket, ไม่ block ออเดอร์ใหม่ → Bug ใหญ่ที่สุด ทำให้ feature เสมือนปิดอยู่ตลอด

### Bug B — Logic "ปิด Hero" สลับฝั่งผิด (Spec mismatch)
บรรทัด 2492-2496 + 3673-3677: เมื่อ `CloseGenSide(side)` หรือ `CloseAllSide(side)` ทำงาน → set `g_heroOppCloseSide = OPPOSITE(side)`. แต่ user ต้องการให้ Hero ปิดพร้อม **same-side** basket trail สำเร็จ → ต้องใช้ `side` ตรงๆ ไม่กลับด้าน

### Bug C — Block ไม่ทำงานเพราะ Bug A
เมื่อ cache=0 ตลอด → `CountHeroOnSide()` คืน 0 → guard ที่ `OpenOrder` ไม่เคย trigger → grid ขยายต่อได้ทั้งฝั่งที่ควรถูกล็อก

## สิ่งที่จะแก้ (v6.93)

### 1. Fix `BuildHeroTicketCache()` (สำคัญสุด)
- ย้าย throttle check ขึ้นไป **ก่อน** `g_heroTicketCount = 0`
- รหัสใหม่:
  ```
  if(!InpHero_Enabled || InpHero_OrderCount <= 0) { g_heroTicketCount = 0; return; }
  if(g_heroLastBuildTime == TimeCurrent() && g_heroTicketCount > 0) return; // keep last build
  g_heroLastBuildTime = TimeCurrent();
  g_heroTicketCount = 0;
  // ... rebuild ...
  ```
- เพิ่ม debug log ครั้งแรกที่พบ Hero (throttled 30s) เพื่อช่วยตรวจสอบ

### 2. เปลี่ยน "ปิด Hero" เป็น same-side
- เปลี่ยนชื่อ input `InpHero_CloseWithOpposite` → `InpHero_CloseWithSameSide` (default `true`)
- คงตัวแปรเก่าไว้เป็น deprecated alias (no-op) เพื่อไม่ break .set ไฟล์เก่า
- ในจุดที่ signal (`CloseGenSide` line 2493 + `CloseAllSide` line 3674):
  ```
  g_heroOppCloseSide = side;   // ❗ เปลี่ยนจาก OPPOSITE → SAME side
  ```
- เปลี่ยนชื่อตัวแปร global → `g_heroSameCloseSide` / `g_heroSameCloseTime` เพื่ออ่านง่าย
- เปลี่ยน `ManageHeroOppositeClose()` → `ManageHeroSameSideClose()`
- log ใหม่: `"v6.93 Hero CLOSE: SameSideBasketClosed side=BUY"`

### 3. รับประกัน Block ออเดอร์ใหม่ (เสริมความแน่น)
- บรรทัด 2107: ใช้ `CountHeroOnSide()` ที่ verify ผ่าน `PositionSelectByTicket` แล้ว → ไม่ต้องแก้ logic, จะทำงานทันทีหลัง Bug A หาย
- เพิ่ม log แบบ throttled 60s ทุกครั้งที่ block เพื่อให้ user เห็น
- ✅ ครอบคลุมทุก order type: `_INIT`, `_GL`, `_GP` (เดิมแล้ว)

### 4. ตรวจสอบจุด exclude Hero ครบถ้วน (audit)
ตรวจสอบให้ครบทุกจุดที่ `IsHeroTicket()` ควรถูกใช้:
- ✅ บรรทัด 2387 — `CalculateAveragePrice` (basket avg)
- ✅ บรรทัด 2417 — `CalculateFloatingPL` (basket PL gate)
- ✅ บรรทัด 2477 — `CloseGenSide` (skip Hero ตอนปิด basket)
- ✅ บรรทัด 3571, 3601, 3635 — `CalcGenAveragePrice`, `CountGenOrders`, `CountGenGridAll`
- ✅ บรรทัด 3663 — `CloseAllSide` (skip Hero)
- 🔍 จะ scan เพิ่ม: `ManageMaxGridTrailing`, `ManagePerOrderTrailing`, `ManageTrailingStop` — เพื่อให้แน่ใจว่า trail คำนวณจาก non-Hero เท่านั้น
- 🔍 จะ scan: ทุกจุดที่นับ `MaxOpenOrders` — ถ้า `InpHero_IncludeInMaxOrders=false` ต้อง skip Hero (ตอนนี้ input มีอยู่แต่ยังไม่ผูกที่ไหน → จะผูกให้ทำงานจริง)

### 5. Dashboard
เพิ่ม row แสดง:
- `Hero BUY: 5 ord 0.43L $-152.30`
- `Hero SELL: 0 ord`
ใส่สีเหลือง/ส้มเพื่อแยกจาก main basket

### 6. Version bump
- v6.92 → **v6.93** ทุกจุด:
  - `#property version`
  - `#property description` (อัปเดตข้อความ: "Hero closes WITH same-side basket trail; cache-rebuild fix; block enforced")
  - Header comment block
  - `OnInit` log
  - Dashboard header ทุก mode

## สิ่งที่ไม่เปลี่ยนแปลง (ยืนยัน)

ตามกฎเหล็ก MQL5 ของโปรเจกต์:
- ❌ ไม่แตะ `OrderSend` / `trade.Buy` / `trade.Sell` / `trade.PositionClose` execution
- ❌ ไม่แตะ entry conditions / SMA / EMA / Squeeze / BB filter
- ❌ ไม่แตะ Grid loss/profit lot/distance calculation
- ❌ ไม่แตะ Hedge / Triple-Gate / Matching close / Recovery / Auto Recovery
- ❌ ไม่แตะ DD% TP / Daily Target / Balance Guard
- ❌ ไม่แตะ Trailing-stop **value calculation** (แค่เพิ่ม guard `IsHeroTicket`)
- ❌ ไม่แตะ License / News / Time filter / Sync
- ✅ เปลี่ยนเฉพาะ Hero Order subsystem + dashboard rows

## Backward Compatibility
- `.set` ไฟล์เก่าที่มี `InpHero_CloseWithOpposite=true` → จะถูก map ไป `InpHero_CloseWithSameSide=true` (semantic ถูก เพราะ user ต้องการ same-side อยู่แล้ว — input เก่าเข้าใจผิดเอง)
- เพื่อไม่ให้ MQL5 compile error: คงชื่อ input เดิม `InpHero_CloseWithOpposite` ไว้ แต่เปลี่ยน **comment label** เป็น `"Close Hero WITH same-side basket trail"` และเปลี่ยน behavior internal → เป็น same-side  
  (ทางเลือก: เพิ่ม input ใหม่แยกก็ได้ แจ้งให้ทราบในแผนถ้าต้องการ)

## Testing Checklist หลัง deploy
1. เปิด `InpHero_Enabled=true, InpHero_OrderCount=2`
2. ให้เปิด BUY 5 ตัว → check log `BuildHeroTicketCache` มี Hero=2
3. ราคาลง → ควร **ไม่** มี GL ใหม่ฝั่ง BUY (block ทำงาน) → check log `Hero BLOCK`
4. ราคาเด้งขึ้น → basket BUY (3 ตัวที่ไม่ใช่ Hero) trail สำเร็จ → ปิด → Hero BUY 2 ตัวควรปิดพร้อมกัน (ภายใน 5 วินาที) → check log `Hero CLOSE: SameSideBasketClosed`
5. หลังปิดหมด ระบบ entry ใหม่ปกติ
