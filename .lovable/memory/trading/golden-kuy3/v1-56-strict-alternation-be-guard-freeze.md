---
name: Kuy3 v1.56 Strict Side-Alternation + BE_GUARD Freeze
description: Hero set FROZEN once phase=BE_GUARD (no new same-side ticket can extend Hero owner); after CloseHero/auto-release, g_heroNextAllowedSide bound to opposite — same side cannot re-arm until opposite completes its Hero cycle
type: feature
---

## ปัญหา v1.55
1. Branch A ใช้ `curPhase != 0` ทำให้ Dynamic Refresh ทำงานทั้ง ARMED และ BE_GUARD → BUY ที่เข้า BE_GUARD แล้วยังมี order ใหม่ดันราคามาแทน Hero เก่า → BUY Hero ต่ออายุตัวเองไม่จบ
2. v1.46 Side-Alternation Lock ปลดล็อคง่ายเกินไป (ดูแค่ opp active หรือ self flat) ทำให้ BUY กลับมาเป็น Hero ซ้ำได้ก่อนที่ SELL Hero จะเกิดและปิดจบ

## หลักการ v1.56
- **BE_GUARD Freeze**: Branch A refresh เฉพาะ `curPhase==2` (ARMED). `curPhase==3` (BE_GUARD) ถูก freeze — ไม้ใหม่ฝั่งเดียวกันไม่สามารถแทนที่ Hero ได้ Prune (STEP 1) ยังคงลบไม้ที่ปิดออก
- **Strict Next-Allowed**: ตัวแปรใหม่ `g_heroNextAllowedSide` (-1=ANY, BUY, SELL)
  - ตั้งค่าเมื่อ `CloseHeroOnSide` / Auto-Release / External Close → opposite ของฝั่งที่เพิ่งปิด
  - Branch B activation block ฝั่งที่ไม่ตรงกับ next-allowed
  - เคลียร์เป็น -1 เมื่อฝั่งที่ตรง next-allowed activate Hero สำเร็จ
- **Dashboard**: เพิ่ม `Next Allowed` row และเปลี่ยน Mode เป็น `ARMED-DYN`

## จุดแก้ใน `public/docs/mql5/Golden_Kuy3_EA.mq5`
- `#property version` 1.55 → 1.56, header, description
- เพิ่ม `g_heroNextAllowedSide` global
- `BuildHeroTicketCache()` Branch A: `curPhase==3` → continue (freeze); `curPhase==2` → dynamic refresh
- Branch B: เพิ่ม next-allowed gate ก่อน activation gate (throttled log 30s)
- Activation success: เคลียร์ next-allowed ถ้า side ตรง + log `STABLE-SET FROZEN`
- STEP 1 external-close: stamp next-allowed เป็น opposite
- STEP 5 auto-release BUY/SELL: stamp next-allowed เป็น opposite
- `CloseHeroOnSide()`: stamp `g_heroNextAllowedSide = opposite(side)`
- Dashboard: header `(v1.56)`, Mode `ARMED-DYN`, เพิ่ม `Next Allowed` row, title `Golden Kuy3 v1.56`

## ไม่เปลี่ยน (กฎเหล็ก)
- ❌ `trade.Buy/Sell/PositionClose`/OrderSend
- ❌ Grid entry/exit/lot multiplier, Per-Order BE/Trail/SL/TP/Cost-Hit
- ❌ Avg-TP/Avg-Trail strict-2-cross, Accumulate, Master TP modes
- ❌ `ApplyHeroLockProfitSL`/`ComputeHeroLockProfitSL`/`StripBrokerTPSLFromHeroTickets`
- ❌ v1.45 Single-Side Lock (BE_GUARD owner only), v1.46 Alternation Lock เดิมยังอยู่ทำงานคู่กับ next-allowed
- ❌ v1.50/v1.51 Hero opposite-close gate (Avg-TP intent / TP realized)
- ❌ `IsHeroProtectedTicket` 9 guards
- `InpHero_Enabled=false` → behavior เดิม
