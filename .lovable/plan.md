## Golden2 EA v2.2 — Preserve Pending TP/SL on Trail + Robust Group Advance

แก้ 2 ปัญหาตามภาพและคำอธิบาย user

### ปัญหาที่พบ

**1. Stop Order TP/SL หายไปหลังถูกแก้ไข (ภาพที่ 2)**
- ภาพ 1: BuyStop/SellStop ตอนแรกมี T/P ครบ (4622.04 / 4606.23)
- ภาพ 2: หลัง trail SellStop ขยับ → T/P ผิด (4599.77 = 9.45 จากราคา แทนที่จะเป็น 3.00 ตาม `InpInitialTPPips` ตอนแรก) และในกรณีที่ user ใช้ Average TP (`InpInitialTPPips=0`), trail จะส่ง `tp=0, sl=0` เข้า `OrderModify` → **ลบ TP/SL ที่ broker จำไว้ทิ้ง**
- สาเหตุ: ใน `ManageInitialTrailOnBarClose` (บรรทัด 813–814, 827–828) คำนวณ TP/SL ใหม่จาก `InpInitialTPPips` ทุกครั้ง โดยไม่อ่านค่าเดิมจาก order

**2. Group 3 ไม่ออก หลัง Group 1 และ Group 2 โดน Hedging**
- `IsGroupSafeToAdvance(g)` (บรรทัด 2112–2119) บังคับเงื่อนไข `hh && hb && hs` (มี hedge + main BUY + main SELL ครบ) จึงจะ "ปลอดภัย"
- ในชีวิตจริง หลัง hedge match แล้ว Triple-Gate อาจปิด main ฝั่งหนึ่งบางส่วน → เหลือแค่ main ฝั่งเดียว → `hb && hs` = false → block ตลอดไป
- ผลคือ Group 2 hedge แล้ว แต่ Group 3 ไม่ออก IN frame ใหม่

### สิ่งที่ "ไม่เปลี่ยนแปลง"
- ไม่แตะ `OrderSend / trade.Buy / trade.Sell / trade.PositionClose / trade.BuyStop / trade.SellStop`
- ไม่แตะกลยุทธ์ Grid Loss / Grid Profit / Hedging entry / Average TP / Triple-Gate
- ไม่แตะ Accumulate Close cooldown ของ v2.1
- ไม่แตะเงื่อนไข trail (เลื่อนเฉพาะฝั่งที่ราคาวิ่งหนี / M1 bar close) — แค่แก้วิธีคำนวณ TP/SL ที่จะป้อนกลับเข้า `OrderModify`

---

### แก้ไข — ไฟล์เดียว: `public/docs/mql5/Golden2_EA.mq5`

#### แก้ 1: `ManageInitialTrailOnBarClose` รักษา TP/SL เดิมเสมอ
- อ่าน `OrderGetDouble(ORDER_TP)` และ `OrderGetDouble(ORDER_SL)` ของ pending ปัจจุบันก่อนแก้ไข
- คำนวณค่าใหม่ "เฉพาะเมื่อ" `InpInitialTPPips > 0` (Initial-TP mode), shift TP/SL ตามระยะ entry ใหม่ (รักษาช่อง TP/SL เดิม):
  - `newTP = oldTP + (newPx - oldPx)` (เลื่อนตามแท่ง pending)
  - `newSL = oldSL + (newPx - oldPx)`
- ถ้า `InpInitialTPPips == 0` → **ส่งค่า TP/SL เดิมเข้า `OrderModify` ตรงๆ** ไม่ใช้ 0 (ป้องกันการลบ Average-TP ที่ broker)
- เพิ่ม guard: ถ้า `oldTP == 0` ก็ส่ง 0 เหมือนเดิม (ไม่บังคับสร้าง TP)

#### แก้ 2: `IsGroupSafeToAdvance` ผ่อนเงื่อนไข + scan ทุก group ก่อนหน้า
- เปลี่ยนตรรกะใน `IsGroupSafeToAdvance(g)` ให้ "ปลอดภัย" เมื่อ:
  - main ฝั่งใดที่ "ยังเปิดอยู่" จะต้องถูก lock ด้วย hedge ที่ active แล้ว (ไม่ใช่บังคับว่าต้องมีทั้งสองฝั่ง)
  - กล่าวคือ ใช้รูปแบบ: `(buyMain == 0 || hedgeBuyLocked) && (sellMain == 0 || hedgeSellLocked)`
  - เพิ่ม helper `HasHedgeLockingSide(g, side)` — ตรวจว่ามี hedge position ของ side ตรงข้ามที่ครอบ main side นี้อยู่
- เพิ่ม `AreAllPriorGroupsSafe(curG)` — loop จาก 1..curG ตรวจทุก group ก่อนหน้า; ใช้ใน `TryAdvanceToNextGroup` เพื่อกัน group กลางๆ ที่ยังค้าง
- ใน `TryAdvanceToNextGroup`:
  - ย้ายเงื่อนไข advance ออกจาก `if(GroupHedgeJustActivated(cur))` → ตรวจทุก tick ว่า "cur hedge active + ทุก group ก่อนหน้า safe + cur safe" → ค่อยสั่ง `PlaceInitialFrame(next)`
  - คงไว้ที่ idle log throttling (60s) เพื่อกัน log spam

#### Inputs ใหม่ (1 ตัว)
```
input bool InpGroup_AdvancePerTick = true;   // v2.2: retry advance every tick (not only on hedge edge)
```

### Version Bump → 2.20
อัปเดต `#property version`, `#property description`, header comment, `Print` ใน `OnInit`, dashboard `L_TITLE` → `Golden2 EA v2.2`

### บันทึก Memory
สร้าง `mem://trading/golden2-ea/v2-2-preserve-pendingtpsl-and-robust-advance.md` พร้อมอัปเดต `mem://index.md`

### ผลที่คาดหวัง
- หลัง bar-close trail: pending stop ยังคงมี T/P (และ S/L) ตาม spec เดิม — ไม่หายไปจาก Toolbox
- เมื่อ Group N โดน hedge แล้ว main ฝั่งใดฝั่งหนึ่งถูกปิด/ลด → ระบบยังเปิด Group N+1 ได้ ตราบใดที่ฝั่งที่เหลือถูก hedge lock ครอบอยู่
- Group 3 จะออก IN frame ตามปกติหลัง Group 2 เข้า hedge state