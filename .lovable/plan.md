# Golden2 EA v2.7.6 — Market Mode Per-Side Re-entry

ไฟล์: `public/docs/mql5/Golden2_EA.mq5`

## ปัญหา
ในโหมด INSTANT/SMA: เมื่อฝั่งใดฝั่งหนึ่งปิด (TP/SL) และอีกฝั่งยัง float อยู่
→ ระบบไม่เปิด initial order ฝั่งที่ปิดไปใหม่
→ ต้องรอจนฝั่งที่เหลือปิดด้วยถึงจะเปิดใหม่ทั้งคู่

## สาเหตุ
- `ManageInitialReArm` ถูก gate (v2.7.5) ให้ return ทันทีในโหมด non-PENDING
- `PlaceInitialFrame` จะถูกเรียกเฉพาะตอน group ว่าง (`TryAdvanceToNextGroup` → `FindLowestIdleGroup`)
- กรุ๊ปที่มี SELL ค้าง = ไม่ idle → ไม่มี path เรียก `PlaceInitialMarket` ฝั่ง BUY ใหม่

## แก้ไข
เพิ่ม `ManageInitialMarketReEntry(int g)` สำหรับโหมด SMA/INSTANT — ตรวจ active group ปัจจุบัน, ถ้าฝั่งใดไม่มี position + ไม่มี pending → call `PlaceInitialMarket(g, placeBuy=true/false, placeSell=...)` เฉพาะฝั่งที่หายไป

### Guards
- เฉพาะ `InpEntryMode != G2_ENTRY_PENDING`
- Skip ถ้า group นี้ hedge active แล้ว (ใช้ `GroupHedgeJustActivated(g)` หรือ pending hedge exists)
- Skip ถ้า group นี้ stripped/locked
- Skip ถ้า accum cooldown active
- Squeeze block per-side / per-group cooldown 5s ใน `PlaceInitialMarket` มีอยู่แล้ว
- เคารพ `InpInitSideMode` (BUY-only/SELL-only/BOTH)

### เรียกใน OnTick loop หลัง `ManageInitialReArm(g)` (line 3126)

### Bump version → v2.7.6
- `#property version "2.76"`
- description สั้น: `"Golden2 EA v2.7.6 — INSTANT/SMA per-side market re-entry. Closed side reopens if other side still active in same group."`
- Dashboard L_TITLE → `Golden2 EA v2.7.6`
- OnInit log

## สิ่งที่ไม่เปลี่ยนแปลง
- ❌ ไม่แตะ `trade.Buy/Sell/PositionClose`
- ❌ ไม่แตะ Hedge mirror, Grid Loss/Profit, Triple-Gate, Accumulate, Squeeze, BB
- ❌ ไม่แตะ PENDING mode (เหมือนเดิม 100%)
- ❌ ไม่แตะ v2.7.5 hard-gate ใน ManageInitialReArm
- ✅ INSTANT: BUY+SELL ออกพร้อมกัน, ฝั่งที่ปิดเปิดใหม่ทันทีในกรุ๊ปเดิม
- ✅ SMA: เหมือนกันแต่ผ่าน SMA filter
