---
name: Golden Kuy3 v1.53 Hero Dynamic Refresh + Demote Restore
description: Default ON dynamic Hero refresh tracks current price-extreme every tick; demoted Hero tickets get Initial TP restored and lock-profit SL cleared so they re-join the normal basket. InpHero_StickySet=true falls back to v1.52.
type: feature
---

## ปัญหา v1.52
Sticky set ทำให้ Hero ticket ล็อคที่ออเดอร์แรกตอน activate ถาวร (เช่น SELL #41,#42) แม้ราคาจะดันต่อให้ Grid เปิดออเดอร์ใหม่ที่ราคาแย่กว่า (สูงกว่าใน SELL / ต่ำกว่าใน BUY) ก็ไม่อัปเดต ทำให้ Hero ไม่ตรงกับ "ไม้ที่อยู่ขอบสุด" จริง

## หลักการ v1.53
- **Default Dynamic Refresh** — `InpHero_StickySet = false` ทำให้ Branch A เลือก Hero ใหม่ทุก tick ตาม price-extreme (BUY ขึ้นต่ำ→สูง / SELL ลงสูง→ต่ำ) เหมือน v1.48/v1.51
- **Demote Restore (ใหม่)** — เมื่อ stable set เปลี่ยน, ticket เก่าที่ถูกผลักออก (ไม่อยู่ใน newSet) จะถูก:
  - คืน TP เริ่มต้นจาก `InpInitialTPPips` (เคารพ `GetMinStopPrice()`)
  - เคลียร์ lock-profit SL (= 0) เพื่อให้ Per-Order BE/Trail/Cost-Hit เข้ามาจัดการเอง
  - log: `v1.53 Hero DEMOTE restore side=… count=N (TP restored, lock-SL cleared): #t@open=…->TP=…`
- **Promote** — `g_heroBE_Applied_<side> = false` เมื่อ phase==BE_GUARD และ set เปลี่ยน → `ApplyHeroLockProfitSL` วาง BE-SL ลง Hero ใหม่รอบถัดไป

## จุดแก้ใน `public/docs/mql5/Golden_Kuy3_EA.mq5`
- `#property version` 1.52 → 1.53, header + description
- `InpHero_StickySet` default `true` → `false`
- Branch A `if(changed)` block: log `v1.53` + เรียก `RestoreInitialTPOnDemoted(prevSet, prevCnt, tkPool, takeA, side)`
- ใหม่: ฟังก์ชัน `RestoreInitialTPOnDemoted()` วางก่อน `BuildHeroTicketCache()`
- Dashboard `Golden Kuy3 v1.53` + `HERO ORDER (v1.53)`

## ไม่เปลี่ยน (กฎเหล็ก)
- ❌ `trade.Buy/Sell/PositionClose`/OrderSend
- ❌ Grid entry/exit/lot multiplier, Per-Order BE/Trail/SL/TP/Cost-Hit
- ❌ Avg-TP/Avg-Trail strict-2-cross, Accumulate
- ❌ `ApplyHeroLockProfitSL`/`ComputeHeroLockProfitSL`/`StripBrokerTPSLFromHeroTickets`
- ❌ Single-Side Lock v1.45, Side-Alternation v1.46, Post-close grace
- ❌ v1.50 oppRealized gate, v1.51 Avg-TP intent flag (5 set + Master TP safety + 60s expiry)
- ❌ `IsHeroProtectedTicket` 9 guards
- `InpHero_Enabled=false` → behavior เดิม
- `InpHero_StickySet=true` → fallback v1.52 sticky behavior เป๊ะ ๆ
