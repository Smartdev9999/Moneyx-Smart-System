# Golden2 EA v2.5 — One-Way Trail (Toward-Price Only)

## ผมเข้าใจผิดใน v2.4

ใน v2.4 ผมทำให้ pending **recenter ตาม mid market** = ขยับทั้ง 2 ทิศ (เข้าหา **และ** ออกห่าง) → ผิดครับ

จากภาพ log จะเห็นว่า BuyStop @ 4612.21 ถูกลากลงเรื่อยๆ ตามราคาที่ลง: 4612 → 4611 → 4610 → 4608 → 4607 → 4606 → 4604 → 4606 (เด้งขึ้นก็ตาม) → ทำให้ pending ไล่ตามราคาเหมือนเงาตามตัว และจะโดนชนเร็วเกินไป

## ความเข้าใจที่ถูกต้อง (จาก user)

**Pending order จะขยับ "เข้าหาราคา" เท่านั้น เมื่อราคาวิ่งออกห่าง**
**ห้ามขยับ "ออกห่างจากราคา" เมื่อราคาวิ่งเข้าหา**

### ตัวอย่าง BuyStop (อยู่เหนือราคา)
- ราคา**ลงห่าง** BuyStop → **ลาก BuyStop ลงเข้าหาราคา** ✅ (เพื่อให้มีโอกาสโดน trigger)
- ราคา**ขึ้นเข้าหา** BuyStop → **อยู่นิ่ง ห้ามขยับขึ้นหนี** ✅ (ปล่อยให้โดน trigger)

### ตัวอย่าง SellStop (อยู่ใต้ราคา)
- ราคา**ขึ้นห่าง** SellStop → **ลาก SellStop ขึ้นเข้าหาราคา** ✅
- ราคา**ลงเข้าหา** SellStop → **อยู่นิ่ง ห้ามขยับลงหนี** ✅

### ระยะห่างขั้นต่ำ
ขยับเข้าหาให้คงระยะ `InpFrameUpperPips` / `InpFrameLowerPips` จากราคาปัจจุบัน (ไม่ขยับเข้ามาใกล้กว่านี้)

## เปรียบเทียบ Logic

| สถานการณ์ | v1.8 (เดิม) | v2.4 (ตอนนี้ ผิด) | v2.5 (ที่ถูก) |
|---|---|---|---|
| ราคาลง, BuyStop เหนือราคา | ลากลง ✅ | ลากลง ✅ | **ลากลง** ✅ |
| ราคาขึ้น, BuyStop เหนือราคา | นิ่ง ✅ | **ลากขึ้น** ❌ | **นิ่ง** ✅ |
| ราคาขึ้น, SellStop ใต้ราคา | ลากขึ้น ✅ | ลากขึ้น ✅ | **ลากขึ้น** ✅ |
| ราคาลง, SellStop ใต้ราคา | นิ่ง ✅ | **ลากลง** ❌ | **นิ่ง** ✅ |

→ **v1.8 logic ถูกต้องอยู่แล้ว** ผมแค่ต้องย้อนกลับและเก็บ improvement อื่นของ v2.4 ไว้

## การแก้ใน v2.5 (เฉพาะ `ManageInitialTrailOnBarClose`, บรรทัด 791-910)

### 1. เปลี่ยน symmetric trail → **toward-price-only trail**

**BUY pending (BuyStop เหนือราคา):**
```cpp
double targetPx = NormalizeDouble(ask + InpFrameUpperPips * g_point, g_digits);
// ลากลงเฉพาะเมื่อ target อยู่ "ต่ำกว่า" pending ปัจจุบัน
// (= ราคาลงไปแล้ว, BuyStop ห่างเกินไป, ต้องลากลงเข้าหา)
if(targetPx < oldPx - recenterMin){
   newPx = targetPx; doMove = true;
}
// ถ้า targetPx >= oldPx → ราคาขึ้นเข้าหา → อยู่นิ่ง ไม่แตะ
```

**SELL pending (SellStop ใต้ราคา):**
```cpp
double targetPx = NormalizeDouble(bid - InpFrameLowerPips * g_point, g_digits);
// ลากขึ้นเฉพาะเมื่อ target อยู่ "สูงกว่า" pending ปัจจุบัน
if(targetPx > oldPx + recenterMin){
   newPx = targetPx; doMove = true;
}
```

### 2. ปรับ Input
- `InpFrameSymmetricTrail` → **เลิกใช้** (เปลี่ยน default = `false` และไม่อ้างอิงในโค้ดอีก หรือเปลี่ยน comment เป็น deprecated)
  - หรือทางเลือก: ตัดทิ้งเลย แต่จะเลือก **เก็บไว้แต่บังคับเป็น false** เพื่อไม่กระทบ saved set ของ user
- `InpFrameRecenterMinPips` → **คงไว้** ใช้เป็น threshold ป้องกัน micro-move (ขยับขั้นต่ำกี่ pip ถึงจะ modify)

### 3. คงไว้ทุกอย่างของ v2.2/v2.3
- ✅ Hedge-state freeze (v2.3): `if(CountGroupPositions(g, -1, 1) > 0) return;`
- ✅ Hedge matched freeze: `if(IsGroupHedgeMatched(g)) return;`
- ✅ Block-new-orders guard
- ✅ TP/SL preservation ด้วย delta shift (v2.2): `tp = oldTP + (newPx - oldPx)`
- ✅ ใช้ `ask` สำหรับ BuyStop และ `bid` สำหรับ SellStop (ไม่ใช้ mid)

### 4. Diagnostic log
```
Golden2 v2.5: TrailIn BuyStop G%d %.5f -> %.5f ask=%.5f tp=%.5f sl=%.5f
Golden2 v2.5: TrailIn SellStop G%d %.5f -> %.5f bid=%.5f tp=%.5f sl=%.5f
```

### 5. Version bump → 2.5
- `#property version "2.50"`
- `#property description` อธิบาย one-way toward-price trail
- Header comment block
- Dashboard `L_TITLE` → `"Golden2 v2.5"`
- `OnInit` log

## สิ่งที่ไม่เปลี่ยนแปลง (กฎเหล็ก)

- ✅ ไม่แตะ Order Execution: `trade.BuyStop`, `trade.SellStop`, `OrderSend`
- ✅ ไม่แตะ Trading Strategy: Grid Loss/Profit, Hedging, Triple-Gate, Accumulate Close
- ✅ ไม่แตะ Core Modules: License, News, Time filter
- ✅ ไม่แตะ `PlaceInitialFrame` (สูตรกรอบเดิม)
- ✅ ไม่แตะ `IsGroupSafeToAdvance` / orphan-aware advance ของ v2.3
- ✅ ไม่แตะ `ManageInitialTrail` (legacy) และ `ManageInitialReArm`
- ✅ ไม่แตะ Hedge freeze guard
- ✅ ไม่แตะ TP/SL preservation logic ของ v2.2

## ผลที่คาดหวัง

- BuyStop/SellStop จะ "ตามเข้าหาราคา" เมื่อราคาวิ่งหนี (รักษาระยะ Frame ที่กำหนด)
- เมื่อราคาวิ่งกลับมาหา pending จะ **อยู่นิ่ง** → trigger ตามแผน
- ไม่มีอาการ "ไล่ตามราคาเหมือนเงา" แบบใน log v2.4
- ลดโอกาสเกิด orphan position หลัง advance group

## ไฟล์ที่แก้

- `public/docs/mql5/Golden2_EA.mq5`
- บันทึก `mem://trading/golden2-ea/v2-5-toward-price-only-trail.md` (และ deprecate v2-4 memo)

ขออนุมัติเพื่อ implement v2.5 ครับ
