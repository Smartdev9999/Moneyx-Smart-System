---
name: Golden Kuy3 v1.54 Live Hero Refresh After Entries
description: BuildHeroTicketCache + ManageHeroOppositeClose run a second time in OnTick after ManageInitialEntry/ManageGridEntry so brand-new tickets get Hero price-extreme selection in the same tick (no stale dashboard / no waiting next tick).
type: feature
---

## ปัญหา v1.53
`BuildHeroTicketCache()` ทำ dynamic refresh แค่รอบเดียวต้น `OnTick()` แต่ `ManageGridEntry()` อาจเปิดออเดอร์ใหม่ในรอบ tick เดียวกัน ทำให้ Hero set / Dashboard ค้างที่ ticket เก่า (เช่น SELL `#42 #41 #39 #29 #28`) จนกว่า tick ถัดไป

## หลักการ v1.54
- รัน `BuildHeroTicketCache()` + `ManageHeroOppositeClose()` รอบที่ 2 หลัง entry modules
- order ใหม่ที่เปิดใน tick เดียวกันถูกคัด Hero ทันที
- `RestoreInitialTPOnDemoted` เพิ่ม idempotency check (skip ถ้า SL+TP ตรงค่าเป้าหมายอยู่แล้ว) ลด `PositionModify` spam ตอน refresh ถี่
- v1.53 dynamic refresh + demote restore + v1.51 Avg-TP intent + v1.46 alternation lock + v1.45 single-side lock เก็บไว้ครบ

## จุดแก้ใน `public/docs/mql5/Golden_Kuy3_EA.mq5`
- `#property version` 1.53 → 1.54, header + description
- Dashboard `Golden Kuy3 v1.54` + `HERO ORDER (v1.54)`
- Init/Deinit log v1.54
- `RestoreInitialTPOnDemoted()` เพิ่ม curSL/curTP idempotency check + log v1.54
- `OnTick()` แทรก `BuildHeroTicketCache(); ManageHeroOppositeClose();` หลัง `ManageGridEntry()`

## ไม่เปลี่ยน (กฎเหล็ก)
- ❌ `trade.Buy/Sell/PositionClose`/OrderSend
- ❌ Grid entry/exit/lot multiplier, Per-Order BE/Trail/SL/TP/Cost-Hit
- ❌ Avg-TP / Avg-Trail strict-2-cross / Accumulate
- ❌ `ApplyHeroLockProfitSL`/`ComputeHeroLockProfitSL`/`StripBrokerTPSLFromHeroTickets`
- ❌ Side-Alternation v1.46, Single-Side Lock v1.45, Post-close grace
- ❌ v1.50 oppRealized gate, v1.51 Avg-TP intent flag
- ❌ `IsHeroProtectedTicket` 9 guards
- `InpHero_Enabled=false` → behavior เดิม
- `InpHero_StickySet=true` → fallback v1.52 sticky behavior
