# Golden2 EA v2.70 — Continuous Frame Maintenance

## ปัญหาที่พบ
หลังจาก initial pending order ถูก trigger หรือถูกลบ ฝั่งที่ "ว่าง" ไม่ถูกเติมกลับ ทำให้ frame เหลือฝั่งเดียวและ EA หยุดทำงาน

## โซลูชัน — Concept ใหม่
1. **เปิดกราฟ → วาง BuyStop + SellStop ทันที** ที่ระยะ `InpFrameUpperPips` / `InpFrameLowerPips`
2. **Update ทุก 1 นาที (M1 bar close)** — ขยับเข้าหาราคาเท่านั้น (toward-only, v2.5 logic คงเดิม)
3. **เมื่อฝั่งใดฝั่งหนึ่ง "ว่าง"** (ไม่มี position + ไม่มี pending) → วาง pending stop ใหม่ทันทีที่ระยะที่กำหนด
4. **ฝั่งที่ติดลบอยู่** → ปล่อยให้ Grid ทำงานต่อตามปกติ ไม่แตะ
5. **Hedge active** → freeze ทั้งหมด (v2.3 คงเดิม)

## การเปลี่ยนแปลงใน `public/docs/mql5/Golden2_EA.mq5`

### A) แทนที่ `ManageInitialReArm` ด้วย `ManageInitialFrameMaintenance(int g)`
- ทุก tick: ถ้า `!hedgeActive` และฝั่งใดมี `pendings == 0 && positions == 0`
  - วาง BuyStop ที่ `Ask + InpFrameUpperPips * pip` (TP/SL จาก `InpInitialTPPips/SLPips`)
  - หรือ SellStop ที่ `Bid - InpFrameLowerPips * pip`
- ใช้ broker safety guards จาก v2.61: STOPS_LEVEL, 5s per-side cooldown, 30s back-off เมื่อ OrderSend fail
- เคารพ `InpInitSideMode` (BOTH/BUY-only/SELL-only) + `InpSqueezeFilter_Enable`

### B) Toward-Price Trail (M1) — เก็บ logic v2.5
- คงไว้ทุกอย่าง: BuyStop ลากลงเมื่อ ask ลด, SellStop ลากขึ้นเมื่อ bid ขึ้น
- Threshold `InpFrameRecenterMinPips`
- TP/SL preserve (v2.2): shift ตาม entry delta

### C) ลบ/Deprecate Inputs ที่ซ้ำซ้อน
ทำเป็น `// DEPRECATED — kept for compatibility, no effect`:
- `InpInitTrailOpposite`
- `InpInitTrailTriggerPips`
- `InpInitTrailOnBarClose`
- `InpInitReArmAfterTP`
- `InpInitReArmDistancePips`
- `InpInitReEntryOnClose`
- `InpFrameSymmetricTrail`

(ไม่ลบ declaration ออกทั้งหมด เพื่อไม่ให้ .set file เก่าพัง — แค่ comment ว่า no-op)

### D) Version Bump → 2.70
- `#property version "2.70"`
- `#property description`
- Header comment block
- Dashboard `L_TITLE` → "Golden2 EA v2.70"
- `OnInit` log: `"[Golden2 v2.70] FrameMaintenance=ON, TowardOnly trail, Re-fill empty side"`
- เพิ่ม memory file `mem://trading/golden2-ea/v2-7-continuous-frame-maintenance.md`
- อัปเดต `mem://index.md`

## สิ่งที่ไม่เปลี่ยนแปลง (ตามกฎเหล็ก)
- ✅ Order Execution: `trade.BuyStop/SellStop/PositionClose` API calls คงเดิม (แค่เรียกจาก function ใหม่)
- ✅ Grid Loss / Grid Profit logic — ไม่แตะ
- ✅ Hedge logic (mirror, arm/disarm, Triple-Gate matching close) — ไม่แตะ
- ✅ Average TP/SL manager (v1.3) — ไม่แตะ
- ✅ Accumulate Close + Cooldown (v2.0/v2.1) — ไม่แตะ
- ✅ Squeeze Filter, Group Lock, Group Advance (v2.2/v2.3) — ไม่แตะ
- ✅ Broker safety guards v2.61 (STOPS_LEVEL, cooldown, back-off) — เก็บไว้ทั้งหมด

## ผลลัพธ์ที่คาดหวัง
- หลังเปิด EA → 2 pending วางทันที
- ราคาวิ่งหนีฝั่งใด → ฝั่งนั้นลากตาม (toward only); อีกฝั่งอยู่กับที่
- ฝั่งใดถูก trigger → market position + TP/SL → ปิดที่ TP → ฝั่งนั้นได้ pending ใหม่ทันที
- ฝั่งตรงข้ามติดลบ → Grid ทำงานต่อ; เมื่อปิด basket ได้ → ก็จะมี pending ใหม่
- วน loop แบบนี้ตลอดจนกว่า hedge จะ active