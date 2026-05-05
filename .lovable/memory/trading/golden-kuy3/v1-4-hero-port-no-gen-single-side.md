---
name: Golden Kuy3 v1.4 Hero Order ported from Gold Miner v7.09
description: Drops v1.3 Hero (RefreshHero/ManageHeroAvgTP/CloseAllExceptHero). Ports Gold Miner v7.09 Hero subsystem — single-side lock, sticky-tag rolling latest-N, lock-profit BE-SL on basket-clear, tick-based opp-clear, post-close grace, auto-release. No gen / no hedge adapter (Kuy3 has neither).
type: feature
---

ไฟล์: `public/docs/mql5/Golden_Kuy3_EA.mq5` (v1.30 → v1.40, `#property version "1.40"`)

## Inputs (กลุ่ม `===== Hero Order (v7.09) =====`)
- `InpHero_Enabled` = false (master)
- `InpHero_OrderCount` = 2 (newest N per side)
- `InpHero_MinOrdersToActivate` = 5 (0 = OrderCount+1)
- `InpHero_BE_OffsetPoints` = 50 (lock-profit SL offset, POINTS)
- `InpHero_BlockSameSideGrid` = true (block survivor-only side)
- `InpHero_IncludeInMaxOrders` = true
- `InpHero_PostCloseGraceSec` = 5
- `InpHero_SingleSideLock` = true (สลับฝั่ง — ทีละฝั่ง)
- `InpHero_CloseWithOpposite` = true (DEPRECATED, .set compat)
- `InpHero_RequireNetProfit` = false (DEPRECATED)

## State
`g_heroTickets[200]`, `g_heroTicketCount`, `g_heroPhase_Buy/Sell` (0=NONE/2=ARMED/3=BE_GUARD), `g_heroBE_Applied_Buy/Sell`, `g_heroJustClosed_Buy/Sell`, dashboard mirrors.

## Functions ported จาก Gold Miner v7.09 (ตัด gen + hedge)
`GetHeroOwnerSide`, `IsHeroTicket`, `CountHeroOnSide`, `CountNonHeroMainOnSide`, `SumHeroLotsOnSide`, `SumHeroProfitOnSide`, `ShouldBlockSameSideGridForHero`, `BuildHeroTicketCache` (rolling latest-N + sticky + auto-release v7.09 + Single-Side Lock v7.04), `ComputeHeroLockProfitSL`, `ValidateHeroLockProfitSL` (v7.02 fixed comparisons), `ApplyHeroLockProfitSL`, `StripBrokerTPSLFromHeroTickets`, `CloseHeroOnSide`, `DetectSameSideBasketClearedForHero`, `ResetHeroStateIfFlat`, `ManageHeroOppositeClose` (orchestrator + tick-based opp-clear).

ไม่ port: `MaintainSideGenAfterHeroClose`, `GetActiveGenForSide`, `g_sideGen_*`, `g_heroOwnedGen_*`, `EnsureHeroProtection` (Kuy3 ไม่มี SyncBrokerTPSL — strip ทุก tick พอ).

## Adapter
- ไม่มี `IsHedgeComment` / `IsTicketBound` — pool = ทุก position ของ magic ฝั่งเดียวกัน
- ไม่มี gen filter — Hero pool = ทุก ticket ฝั่งนั้น
- ใช้ `InpMagicNumber` ของ Kuy3 แทน `MagicNumber`
- `g_stopsLevel` ของ Kuy3 (โหลดใน OnInit) แทน `SymbolInfoInteger` per-call

## Hooks ใน OnTick (เพิ่มที่ต้นสุด)
```cpp
BuildHeroTicketCache();
ManageHeroOppositeClose();
```

## Skip-Hero (มีอยู่แล้วใน v1.3 ใช้ต่อได้)
`ManagePerOrderTrailing`, `EnforceClearTPIfDisabled`, `CloseAllOurs`, `CloseAllSide`, `CalcSideAvgPrice_NonHero`, `CalcSideFloating_NonHero`, AvgTrail apply loop, TP Points modify loop. Cost-Hit Restart grace ผ่าน `GetHeroLastCloseTime()` (max ของ 2 ฝั่ง).

## Grid block hook
`ManageGridEntry` ทั้ง BUY/SELL: `if(!ShouldBlockSameSideGridForHero(side)) OpenGrid(...)`

## Dashboard (`=== HERO ORDER (v7.09) ===`)
Hero Cfg | Hero Owner (NONE/BUY/SELL/locked) | Hero BUY (active/threshold + tagged + phase) | Tix BUY | Hero SELL | Tix SELL.

## พฤติกรรม Single-Side Lock (สเปก user)
- ฝั่งใดถึง threshold ก่อน → tag Hero, phase=ARMED (CANDIDATE)
- ฝั่งตรงข้าม phase=NONE → block first activation (อีกฝั่งรอ)
- พอ basket non-Hero ของฝั่ง CANDIDATE clear → phase=BE_GUARD = OWNER จริง
- Apply lock-profit SL (BUY=open+50pt, SELL=open-50pt)
- รอ basket ฝั่งตรงข้าม clear (Avg-TP / Avg-Trail / TP Points) → tick detector ปิด Hero
- หลัง close: post-close grace 5s → ฝั่งใดเข้าเงื่อนไขใหม่ก็เป็น Hero ถัดไป (สลับได้)

## ไม่เปลี่ยน (กฎเหล็ก)
- ไม่แตะ `OrderSend` / `trade.Buy/Sell/PositionClose/PositionModify` pattern
- ไม่แตะ `CalcGridLot` v1.2 / Avg-Trail strict-2-cross / TP modes / Accumulate / Cost-Hit core
- ไม่แตะ Per-Order BE สูตร (เพิ่มแค่ skip Hero — มีอยู่แล้ว)
- ไม่มี License / News / Sync / Hedge / Squeeze
- `InpHero_Enabled=false` → พฤติกรรม = v1.2 ทุกบรรทัด
