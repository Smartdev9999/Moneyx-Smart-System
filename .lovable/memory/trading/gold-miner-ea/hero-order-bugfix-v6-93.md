---
name: Gold Miner EA v6.93 — Hero Order Bugfix
description: Fixes 3 critical Hero Order bugs from v6.92 — cache reset every tick (feature dead), close-direction inverted (closed wrong side), ApplyTrailingSL force-closing Hero with basket; now Hero closes WITH same-side basket trail
type: feature
---

# Gold Miner EA v6.93 — Hero Order Bugfix

ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

## Bugs ที่แก้ใน v6.92 → v6.93

### Bug A — `BuildHeroTicketCache` reset cache ทุก tick
v6.92 ลำดับผิด: `g_heroTicketCount = 0` วางก่อน throttle check → ทุก tick ที่ throttle hit, cache เหลือ 0 → `IsHeroTicket()` คืน false ตลอด → feature ตาย
v6.93: ย้าย gate ขึ้นก่อน clear; ถ้า throttle hit AND cache>0 ให้ keep build เดิม

### Bug B — Close direction inverted
v6.92: `CloseGenSide(BUY)` → set `g_heroOppCloseSide = SELL` → ปิด Hero ฝั่ง SELL (ผิดสเปก)
User spec: Hero ปิดพร้อม basket **same-side** ที่ trail/TP สำเร็จ
v6.93: ทั้ง 2 signal sites (`CloseGenSide` line 2503, MaxGridTrail close line 3685) → `g_heroOppCloseSide = (int)side` (same)

### Bug C — ApplyTrailingSL ใส่ broker SL บน Hero ticket
v6.92 จุดที่ user เห็นในภาพ: basket trail สำเร็จ → ApplyTrailingSL push SL ไปยังทุก ticket รวม Hero → ราคาเด้งแตะ SL → broker ปิด Hero ตาม → ไม่เหลือ Hero
v6.93: เพิ่ม `if(IsHeroTicket(ticket)) continue;` ทั้งใน `ApplyTrailingSL` (line 3375) และ `ApplyTrailingSL_TF` (line 6245)

## เปลี่ยนเสริม
- Input label: `InpHero_CloseWithOpposite` ตัวเดิม (เก็บไว้เพื่อ .set compat) แต่ comment เปลี่ยนเป็น "Close Hero WITH same-side basket trail/TP"
- `InpHero_IncludeInMaxOrders` ผูกเข้า `NormalOrderCount` แล้วจริง (v6.92 ลืมผูก)
- Audit log throttled 30s ใน `BuildHeroTicketCache` แสดง `heroBUY=N heroSELL=M`
- Renamed close reason: `OppositeBasketClosed` → `SameSideBasketClosed`

## ไม่เปลี่ยน (ตามกฎเหล็ก)
- ❌ OrderSend / trade.Buy/Sell/PositionClose execution
- ❌ Entry conditions / SMA / EMA / Squeeze / BB / Z-Score
- ❌ Grid loss/profit lot / distance / candle confirm
- ❌ Hedge / Triple-Gate / Matching close / Recovery / Auto Recovery
- ❌ DD% TP / Daily Target / Balance Guard
- ❌ Trailing-stop **value calculation** (เพิ่มแค่ Hero guard)
- ❌ License / News / Time / Sync
- ❌ ManagePerOrderTrailing — Hero ยังมี per-ticket BE/Trail ของตัวเองได้ (ตามสเปก)

## Test Steps
1. Set `InpHero_Enabled=true, InpHero_OrderCount=2`
2. เปิด BUY 5 ตัว → log `v6.93 Hero CACHE: total=2 heroBUY=2`
3. ราคาลง → ไม่เห็น GL ใหม่ฝั่ง BUY → log `v6.92 Hero BLOCK` (ยังเป็น v6.92 ใน log message — fine)
4. ราคาเด้ง → basket BUY (3 ตัว non-Hero) trail สำเร็จ → ปิด → ภายใน 5s Hero BUY 2 ตัวปิดด้วย → log `Hero CLOSE: SameSideBasketClosed`
