---
name: Golden Kuy3 v1.46 Hero Side-Alternation Lock
description: หลัง CloseHeroOnSide ฝั่งที่เพิ่งปิดถูก lock จาก re-arm จนกว่าฝั่งตรงข้ามจะ ARMED/BE_GUARD หรือฝั่งเดิมกลับมา flat สนิท บังคับสลับฝั่ง Hero
type: feature
---

## Bug v1.45
หลัง Hero BUY ปิด → grace 5s ผ่าน → BUY ฝั่งเดิมยังถึง threshold ได้ → tag Hero BUY ซ้ำ ทั้งที่ราคาวิ่งลงและ SELL กำลังเป็นฝั่งภาระจริง

## Fix v1.46
- เพิ่ม state `g_heroLastClosedSide = -1` (BUY/SELL/-1)
- `CloseHeroOnSide(side)` stamp `g_heroLastClosedSide = (int)side` หลัง reset phase
- `BuildHeroTicketCache` หลัง Post-close grace + ก่อน activation gate:
  - ถ้า `InpHero_AlternateSides && lastClosed == sideId && curPhase == 0`
  - คำนวณ `oppActive = (oppPhase == ARMED || BE_GUARD)`, `selfFlat = (Hero+normal == 0)`
  - `oppActive || selfFlat` → ปลด lock (`g_heroLastClosedSide = -1`)
  - else → ทำให้ side นี้ phase=0 + continue (ห้าม tag)
- `ResetHeroStateIfFlat(side)` → ถ้า side == lastClosed เคลียร์ lock
- Input ใหม่ `InpHero_AlternateSides = true` (default ON)
- Dashboard Hero Cfg เพิ่ม `Alt=ON/OFF` + แถวใหม่ `Last Closed: BUY/SELL/-`
- Audit log เพิ่ม `lastClosed=`
- Version bump 1.45 → 1.46 (header / `#property` / dashboard / OnInit / OnDeinit)

## Flow ที่คาดหวัง
1. Hero BUY ปิด → `g_heroLastClosedSide = BUY`
2. ราคาวิ่งลงต่อ → BUY orders เปิดเพิ่ม → ถึง threshold
3. Side-Alt guard บล็อก BUY (lastClosed=BUY, opp=NONE, BUY ยังมี orders)
4. SELL ถึง threshold → SELL ARMED → guard เห็น oppActive → ปลด lock
5. SELL ดำเนินการเป็น candidate / owner ตามปกติ

## ไม่เปลี่ยน (กฎเหล็ก)
- ❌ OrderSend / `trade.*` / Open* / Manage*Entry / CalcGridLot
- ❌ Per-Order BE/Trail / Avg-Trail strict-2-cross / TP modes / Accumulate v1.42 / Cost-Hit Restart
- ❌ StripBrokerTPSLFromHeroTickets v1.44 (TP only, SL kept)
- ❌ ComputeHeroLockProfitSL / ApplyHeroLockProfitSL (BE_GUARD path)
- ❌ BuildHeroTicketCache price-extreme sort v1.43
- ❌ DetectSameSideBasketClearedForHero / ManageHeroOppositeClose
- ❌ v1.45 CANDIDATE-vs-OWNER (GetHeroOwnerSide BE_GUARD-only)
- `InpHero_Enabled=false` หรือ `InpHero_AlternateSides=false` → พฤติกรรม = v1.45
