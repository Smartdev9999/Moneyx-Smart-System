---
name: Gold Miner EA v7.09 — Hero Auto-Release on Zero Tickets
description: BuildHeroTicketCache now auto-releases Hero ownership when phase==BE_GUARD but sideHeroTagged==0. Covers all Hero close paths beyond CloseHeroOnSide (Broker TP/SL race, manual close, Daily Target / Balance Guard force-close). Without this, owner lock stayed forever after non-EA close paths and blocked the opposite side from ever activating its own Hero — even after the surviving GM(N+1) basket was the only thing left. Stamps g_heroJustClosed_<side> so v7.03 post-close grace gates re-tag while broker settles. g_sideGen / g_heroOwnedGen still managed by v7.08 MaintainSideGenAfterHeroClose so GM(N+1) basket continues normal grid/TP/Avg-trail.
type: feature
---

# v7.09

## Bug
Dashboard showed `Hero BUY: 240/100 GL:0 Hero:0 BE_GUARD` + `Hero Owner: BUY (locked)` while `Hero SELL: 19/100 ... READY` (yellow) couldn't activate. SELL had crossed the order-count threshold and was logically eligible to become a Hero candidate, but `BuildHeroTicketCache` Single-Side Lock at L2445 force-cleared SELL's phase every tick because `GetHeroOwnerSide()` still returned BUY.

Root cause: `g_heroPhase_<side>` was downgraded from BE_GUARD (3) → NONE (0) **only inside `CloseHeroOnSide()`**. If Hero tickets closed via any other path (Broker-side TP/SL hitting before EA closes them, manual close, Daily Target / Balance Guard global force-close, license expire close), phase stayed at 3 forever → `GetHeroOwnerSide()` kept reporting that side as owner → opposite side blocked indefinitely.

## Fix
- `BuildHeroTicketCache()` (just before per-side phase update): if `g_heroPhase_<side> == 3` AND `sideHeroTagged[s] == 0`, log AUTO-RELEASE, reset `g_heroPhase_<side> = 0`, clear `g_heroBE_Applied_<side>`, stamp `g_heroJustClosed_<side> = TimeCurrent()` so v7.03 post-close grace prevents re-tag while broker settling.
- `g_sideGen_<side>` / `g_heroOwnedGen_<side>` are NOT cleared here — left to v7.08 `MaintainSideGenAfterHeroClose()` so the surviving GM(N+1) basket keeps full visibility (grid / TP / Avg-trail / Accumulate) until it flattens naturally.
- `GetHeroOwnerSide()` immediately returns -1 next tick → opposite side's Single-Side Lock gate (L2445) opens → SELL CAN ARMED → if SELL basket clears first → SELL becomes new BE_GUARD owner.
- Version bumped to **7.09** at `#property version`, `#property description`, header banner comment, OnInit/OnDeinit Print, dashboard title.

## Flow After Fix
```
1. BUY ARMED -> BE_GUARD (owner). g_sideGen_Buy: GM1->GM2.
2. Hero BUY tickets close via Broker TP race (NOT through CloseHeroOnSide).
3. Next tick BuildHeroTicketCache: sideHeroTagged[BUY]=0 but g_heroPhase_Buy==3
   -> AUTO-RELEASE: phase=0, grace timer stamped.
4. GetHeroOwnerSide() returns -1.
5. SELL meets threshold -> Single-Side Lock gate opens -> SELL ARMED (CANDIDATE).
6. If SELL basket flattens -> SELL becomes BE_GUARD (new owner).
7. GM2 BUY basket still managed (g_sideGen_Buy=GM2 preserved by v7.08).
8. When GM2 BUY flattens -> MaintainSideGenAfterHeroClose reverts g_sideGen_Buy=0.
9. Next BUY INIT opens as GM1_INIT -> Hero subsystem re-armable on BUY too.
```

## Not Touched
- OrderSend / `trade.Buy/Sell/PositionClose`
- Entry strategy (SMA/EMA/Squeeze/BB/ZigZag), grid lot/distance/candle confirm
- TP/SL/Trailing/Breakeven/Avg-TP formulae
- Hedge / Triple-Gate / Recovery / DD% TP / Daily Target / Balance Guard
- License / News / Sync modules
- Hero formula (`ComputeHeroLockProfitSL`, `ValidateHeroLockProfitSL`, `ApplyHeroLockProfitSL`, BE_GUARD apply path, OnTradeTransaction audit)
- `CloseHeroOnSide` (normal close path unchanged)
- v7.04 `GetActiveGenForSide` filter sites (11 places), v7.05 unblock helpers, v7.06 GL-pool gen-lock, v7.07 candidate-vs-owner, v7.08 deferred sideGen revert
