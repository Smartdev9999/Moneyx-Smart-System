---
name: Golden Kuy3 EA v1.0 Init
description: New standalone EA — Instant entry (no indicator) + single-set Grid (BOTH/UP/DOWN relative to last ticket) + per-order trailing + average TP + average trailing (Gold Miner v6.85/86/90/91 ports). Auto re-entry per side when flat.
type: feature
---

ไฟล์: `public/docs/mql5/Golden_Kuy3_EA.mq5` (v1.0)

## Modules
1. **Instant Entry** — `InpInitSideMode` (BOTH/BUY/SELL); ฝั่งใดว่าง → market BUY at Ask / SELL at Bid; comment `GK_INIT_BUY` / `GK_INIT_SELL`; `InpAutoReEntry` + `InpReEntryCooldownSec=5`. ราคา open ของ INIT เก็บเป็น `g_initPrice_<side>` (รีเคิฟตอน OnInit ถ้ามี position อยู่)
2. **Single Grid** — `InpGridSideMode` (BOTH/UP/DOWN) เทียบจาก ticket "ล่าสุด" (ticket id มากสุด) ของฝั่งนั้น; `InpGridDistancePips` / `InpGridLotMode` (FIXED/ADD/MULTIPLY) / `InpMaxGridOrders` / `InpGridOnlyNewCandle` (M1). ไม่แยก Loss/Profit. Comment `GK_GRID_<SIDE>_<n>`
3. **Per-Order Trailing** — port Gold Miner: BE @ activation pips → step trail @ activation+step. Push เป็น broker SL จริง
4. **Average TP** — basket avg ± `InpAverageTPPips` push ทุก ticket เมื่อ count ≥ `InpAvgTP_MinOrders`
5. **Average Trailing** — Gold Miner v6.85/86/90/91: arm เมื่อ profit ≥ activation, trail by step, BE buffer, **strict 2-cross** ARM gate (BUY ต้อง bid<avg-buffer ก่อน), ปิดทุก ticket ฝั่งนั้นเมื่อ SL hit (per-side reset แบบ v6.84)

## Priority TP/SL
AvgTrail SL > PerOrder SL > Initial SL/TP. AvgTP overrides initial TP เมื่อ count ≥ MinOrders. ทั้งหมดเคารพ `SYMBOL_TRADE_STOPS_LEVEL`.

## NOT included (ตามกฎเหล็ก)
ไม่มี License / News / Sync / Hedge / Triple-Gate / Recovery / Hero / Squeeze / SMA / EMA / ZigZag / BB

## Defaults
Magic 33001, Lot 0.01, GridDist 150pip MULTx1.5 max 20, AvgTP 50pip ≥2 orders, AvgTrail 100pip act / 20 step / 20 BE / ≥3 orders strict 2-cross
