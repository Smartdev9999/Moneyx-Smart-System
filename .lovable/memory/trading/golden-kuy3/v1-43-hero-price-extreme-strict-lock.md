---
name: Golden Kuy3 v1.43 Hero Price-Extreme + Strict Single-Side Lock
description: BuildHeroTicketCache เลือก Hero ตามราคาเปิด (BUY = ต่ำสุด N ตัว, SELL = สูงสุด N ตัว) แทน POSITION_TIME_MSC. STRICT Single-Side Lock — ฝั่งใด phase != NONE คือ owner; อีกฝั่งห้ามเริ่ม Hero ใหม่จนกว่าฝั่งนั้นจะปิด/grace. เพิ่ม PRE-GUARD ล้าง state dual-side ที่ค้างจาก v1.42. Audit log แสดงราคา Hero ทุกตัว.
type: feature
---

## Bugs (v1.42)
1. Sort ด้วย `POSITION_TIME_MSC` + ticket → Hero BUY ไปติดออเดอร์เปิดทีหลัง ไม่ใช่ตัวล่างสุดตามสเปก
2. `GetHeroOwnerSide` คืน owner เฉพาะ phase==BE_GUARD → BUY กับ SELL ขึ้น ARMED พร้อมกันได้ แล้วต่างก็ไหลไป BE_GUARD พร้อมกัน (dashboard เห็น Owner=NONE แต่ทั้งสองฝั่ง BE_GUARD)

## Fix v1.43
- `pxPool[]` (POSITION_PRICE_OPEN) แทน `ttMs[]`. BUY sort ascending, SELL sort descending. tie-break = ticket ascending (เก่าก่อน)
- `GetHeroOwnerSide`: `buyOwns = (phase != 0)`, `sellOwns = (phase != 0)` → เคลม owner ตั้งแต่ ARMED
- `BuildHeroTicketCache` PRE-GUARD: ถ้าเจอทั้ง 2 ฝั่ง phase != 0 พร้อมกัน เก็บฝั่ง phase สูงกว่า (BE_GUARD > ARMED) tie-break = order count, อีกฝั่ง force reset + grace
- ใน loop ภายใน: หลัง tag Hero ฝั่งใดเสร็จ อัปเดต `activeOwner` ทันที กันเคส iteration BUY ก่อน SELL ที่อาจตามขึ้น ARMED ใน tick เดียวกัน
- Audit log v1.43 พิมพ์ `#ticket@price` ของ Hero ทุกตัว (debug ราคาเลือก)
- Dashboard Hero Cfg แสดง `Mode=PRICE_EXTREME Lock=STRICT/OFF`
- Version bump 1.42 → 1.43 ทุกจุด (header / `#property` / dashboard / OnInit / OnDeinit)

## ตัวอย่างผลลัพธ์
BUY pool: #431@3363.38, #484@3361.83 → Hero (N=2) = [#484, #431]  (ล่างสุดก่อน)
SELL pool: #1071@3327.39, #1109@3319.37, #1145@3300.76, #1147@3306.01 → Hero (N=2) = [#1071, #1109]  (บนสุดก่อน)

## ไม่เปลี่ยน (กฎเหล็ก)
- ❌ OrderSend / trade.Buy/Sell/PositionClose/PositionModify (pattern เดิม)
- ❌ OpenInitial / OpenGrid / ManageInitialEntry / ManageGridEntry
- ❌ CalcGridLot v1.2 (MathCeil + force-step)
- ❌ Per-Order BE/Trail สูตร, Avg-Trail strict-2-cross
- ❌ TP modes (FixedDollar / Points push / %Bal)
- ❌ Accumulate Close + cycle-reset v1.42
- ❌ Cost-Hit Restart core
- ❌ ไม่มี License / News / Sync / Hedge / Squeeze
- `InpHero_Enabled=false` → พฤติกรรม = v1.42 ทุกบรรทัด
