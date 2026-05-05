---
name: Golden Kuy3 v1.3 Hero Order
description: Locks newest N tickets of burden side as Hero (skipped from Accumulate/AvgTP/AvgTrail/PerOrderTrail). Hero AvgTP closes cycle when opp non-Hero (excl top-N keep) avg moves InpHero_AvgTP_Points; survivor opp top-N kept with stripped SL as next-cycle seed; Hero gets one-shot BE-Lock SL at open±offset. Cost-Hit Restart suppressed during PostCloseGrace.
type: feature
---

ไฟล์: `public/docs/mql5/Golden_Kuy3_EA.mq5` (v1.2 → v1.3, `#property version "1.30"`)

## Inputs (กลุ่ม `=== Hero Order ===`)
- `InpEnableHero` (default false) — master
- `InpHero_Count` = 3
- `InpHero_MinSideOrders` = 5
- `InpHero_BE_OffsetPips` = 5.0
- `InpHero_AvgTP_Points` = 300
- `InpHero_AvgTP_MinOrders` = 2
- `InpHero_KeepLatestN_Opp` = 3
- `InpHero_StripBE_OnSurvivor` = true
- `InpHero_PostCloseGraceSec` = 5

## State
`g_hero_Active`, `g_hero_Side`, `g_hero_Tickets[]`, `g_hero_LastCloseTime`, `g_hero_LastOppAvg/Cnt`

## Flow
1. `RefreshHero()` ทุก tick (ก่อน module อื่น): เลือก burden side (floating ติดลบมากกว่า + count >= MinSide), tag top-N newest tickets, apply BE-Lock SL ครั้งเดียว. ถ้า side count < Count → release.
2. `ManageHeroAvgTP()`: คำนวณ avg ฝั่งตรงข้าม Hero โดย exclude Hero และ top-`KeepLatestN_Opp` ticket ของฝั่งนั้น. เมื่อราคาห่าง avg >= `AvgTP_Points * point` ในทิศทำกำไร → `CloseAllExceptHeroAndOppSurvivor()`: ปิดทุก ticket ยกเว้น Hero + opp top-N (strip SL/TP จาก survivor).
3. Hero ticket ถูก skip จาก: `ManagePerOrderTrailing`, `EnforceClearTPIfDisabled`, `CloseAllSide`, `CloseAllOurs`, Avg-Trail apply loop, TP Points modify loop.
4. Accumulate / TP Dollar / TP %Bal / TP Points / Avg-Trail ใช้ `CalcSideFloating_NonHero` + `CalcSideAvgPrice_NonHero` แทน.
5. Cost-Hit Restart: skip การ register pending เมื่ออยู่ใน `PostCloseGraceSec` หลัง cycle-close.

## Dashboard (เพิ่ม section `=== HERO ORDER ===`)
- Hero Module ON/OFF + cnt + minSide
- Hero Status WAIT/ACTIVE side ticket-ids
- Hero AvgTP target/avg/cur dist
- Survivor Strip ON/OFF keepN

## ไม่เปลี่ยน
- `OrderSend` / `trade.Buy/Sell/PositionClose/PositionModify` (ใช้ pattern เดิม)
- Grid distance / lot calc / Cost-Hit core
- Per-Order BE/Trailing สูตร, Avg-Trail strict 2-cross, TP modes
- ถ้า `InpEnableHero=false` พฤติกรรม EA = v1.2 ทุกบรรทัด (helper IsHeroTicket short-circuit)
