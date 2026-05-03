## Goal
After a Hero is closed, the surviving GM(N+1) basket on that side must keep being managed normally; only **after** that GM(N+1) basket also closes should the side revert to GM1 so the next INIT can re-arm the Hero subsystem.

## Current Bug
In `CloseHeroOnSide()` (line 2606) the EA **immediately** zeroes `g_sideGen_<side>` and `g_heroOwnedGen_<side>` the moment the Hero closes. If GM2 grid orders are still alive on that side, the very next tick `GetActiveGenForSide(side)` returns GM1, the 11+ counter sites filter GM2 tickets out as "older gen", and the surviving GM2 basket becomes invisible to grid / TP / Avg-trail / accumulate. Result: GM2 stays frozen, no Hero can re-arm because the previous side-gen state was wiped while orders remain.

## Plan (v7.08 — Deferred Side-Gen Reset)

### Change 1 — `CloseHeroOnSide(side, reason)` (around line 2606)
Stop wiping `g_sideGen_<side>` / `g_heroOwnedGen_<side>` here. Only do the **Hero-specific** state reset (phase, BE flag, post-close grace).

```cpp
// v7.08: Do NOT reset g_sideGen_<side> here — GM(N+1) basket may still be alive.
//        Reset is deferred to MaintainSideGenAfterHeroClose() which fires only
//        when (Hero count == 0) AND (non-Hero main on this side == 0).
if(side == POSITION_TYPE_BUY) {
   g_heroPhase_Buy = 0; g_heroBE_Applied_Buy = false;
   g_heroJustClosed_Buy = TimeCurrent();
} else {
   g_heroPhase_Sell = 0; g_heroBE_Applied_Sell = false;
   g_heroJustClosed_Sell = TimeCurrent();
}
```

### Change 2 — New helper `MaintainSideGenAfterHeroClose()` 
Add next to `CloseHeroOnSide`. Per-tick, per-side check:

```cpp
void MaintainSideGenAfterHeroClose()
{
   // BUY
   if(g_sideGen_Buy > 0
      && CountHeroOnSide(POSITION_TYPE_BUY) == 0
      && CountNonHeroMainOnSide(POSITION_TYPE_BUY) == 0)
   {
      Print("v7.08 SideGen REVERT BUY: GM", g_sideGen_Buy,
            " -> GM", (g_cycleGeneration<1?1:g_cycleGeneration),
            " (Hero gone, GM2 basket flat) — Hero subsystem re-armable");
      g_sideGen_Buy = 0;
      g_heroOwnedGen_Buy = 0;
   }
   // SELL — same pattern
   if(g_sideGen_Sell > 0
      && CountHeroOnSide(POSITION_TYPE_SELL) == 0
      && CountNonHeroMainOnSide(POSITION_TYPE_SELL) == 0)
   {
      Print("v7.08 SideGen REVERT SELL: GM", g_sideGen_Sell,
            " -> GM", (g_cycleGeneration<1?1:g_cycleGeneration),
            " (Hero gone, GM2 basket flat) — Hero subsystem re-armable");
      g_sideGen_Sell = 0;
      g_heroOwnedGen_Sell = 0;
   }
}
```

Call once per tick in `OnTick()` next to the existing Hero maintenance (immediately after `BuildHeroTicketCache` / before `OpenOrder` decisions).

### Change 3 — Counter visibility
`CountNonHeroMainOnSide(side)` (line 2546) currently filters by `GetActiveGenForSide(side)` (v7.05). That is correct — while `g_sideGen_<side> > 0` it sees the GM(N+1) basket; the new helper above uses the same view, so the revert fires exactly when that GM(N+1) basket flattens. No change needed here.

### Change 4 — Version bump to **v7.08**
Update `#property version`, `#property description`, header banner comment, `OnInit` / `OnDeinit` Print, and dashboard title (line 5105 area `Gold Miner EA v7.07` → `v7.08`).

## Resulting Flow

```text
1. Both sides ARMED (CANDIDATE).
2. SELL basket closes by TP -> SELL becomes Hero OWNER (BE_GUARD).
   g_sideGen_Sell bumps GM1 -> GM2, g_heroOwnedGen_Sell = 1.
3. Hero SELL closes (opposite-basket close / SL / etc.)
   -> CloseHeroOnSide resets phase + grace timer ONLY.
   -> g_sideGen_Sell stays GM2; surviving GM2 basket keeps being managed.
4. GM2 basket flattens via TP / Avg-trail / Accumulate.
5. MaintainSideGenAfterHeroClose() detects (Hero=0, NonHero=0) on SELL
   -> g_sideGen_Sell = 0 (revert to GM1).
6. Next INIT on SELL opens as GM1_INIT -> Hero subsystem can re-arm.
```

## สิ่งที่ไม่เปลี่ยนแปลง (per project rule)
- ห้ามแก้ Order Execution: `OrderSend`, `trade.Buy/Sell/PositionClose` — ไม่แตะ
- Entry strategy (SMA/EMA/Squeeze/BB/ZigZag), grid lot/distance/candle confirm — ไม่แตะ
- TP/SL/Trailing/Breakeven/Avg-TP formulae — ไม่แตะ
- Hedge / Triple-Gate / Recovery / DD% TP / Daily Target / Balance Guard — ไม่แตะ
- License / News / Sync modules — ไม่แตะ
- Hero formula (`ComputeHeroLockProfitSL`, `ValidateHeroLockProfitSL`, `ApplyHeroLockProfitSL`, BE_GUARD apply path, Post-Close Grace, OnTradeTransaction audit) — ไม่แตะ
- v7.04 `GetActiveGenForSide` filter sites (11 places), v7.05 unblock helpers, v7.06 GL-pool gen-lock, v7.07 candidate-vs-owner — ไม่แตะ
- Cycle reset paths (line 9697, 9797) ที่เคลียร์ `g_sideGen_*` ตอนรีเซ็ต cycle ทั้งระบบ — คงไว้

ยืนยันว่าไม่มีการเปลี่ยนแปลง trading logic ใดๆ; การแก้ไขเป็นการเลื่อนเวลา reset ของ side-gen state ให้สอดคล้องกับ lifetime ของ basket จริง

## Files
- `public/docs/mql5/Gold_Miner_EA.mq5` — edits above
- `.lovable/memory/trading/gold-miner-ea/sidegen-revert-after-basket-flat-v7-08.md` — new memory entry
- `mem://index.md` — append entry
