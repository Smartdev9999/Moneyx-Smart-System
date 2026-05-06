---
name: Kuy3 v1.61 Hero Dashboard Tix Rows Widened
description: New DashRowWide() helper renders Tix BUY/SELL with extra width (+260px) and smaller font (8) so all Hero ticket IDs are visible; cap raised 10→20
type: feature
---

## Bug v1.60
หน้าต่าง dashboard แสดง Tix BUY ไม่ครบ — บน chart เห็น Hero BUY 5 ตัว (#3465 #3463 #3452 #3448 #3351) แต่ dashboard ขาด #3463
สาเหตุ: `DashRow` ใช้ width `InpDashColW1+InpDashColW2 = 320px` + font 9 → string ยาวๆ ถูกตัดออกนอกพื้นที่ render
และ `g_heroDash_*Tickets[10]` cap = 10 อาจไม่พอเมื่อ N สูง

## Fix v1.61
- เพิ่ม helper `DashRowWide(label, value, valColor, extraW, fontSize=8)` — bg + value cell ขยาย +extraW px (label width เท่าเดิม)
- เปลี่ยน `Tix BUY` / `Tix SELL` ใช้ `DashRowWide(..., 260, 8)` (รวม ~580px, font 8)
- ขยาย cap dashboard ticket array `[10] → [20]` ทั้ง BUY/SELL + loop bound
- Version bump 1.60 → 1.61 (header / `#property` / dashboard / OnInit / OnDeinit / log strings)

## ไม่กระทบ (กฎเหล็ก)
- ❌ `BuildHeroTicketCache` selection / price-extreme sort / ARMED-refresh / BE_GUARD freeze
- ❌ Hero phase machine, IsHeroProtectedTicket, lock-profit SL, TP-event latch
- ❌ OrderSend / trade.* / Open* / Manage*Entry / CalcGridLot
- ❌ Per-Order BE/Trail / Avg-Trail strict-2-cross / TP modes / Accumulate v1.60 / Cost-Hit
- ❌ MaxLot cap / MaxDDClose v1.59
- เปลี่ยนเฉพาะ presentation layer (DashRow ปกติยังคงเดิม — DashRowWide ใช้เฉพาะ Tix rows)
