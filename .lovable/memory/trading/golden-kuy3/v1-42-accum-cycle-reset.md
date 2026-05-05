---
name: Golden Kuy3 v1.42 Accumulate Cycle Reset
description: g_realizedCycle auto-resets to 0 when account is fully flat (no EA position either side). New TryResetAccumulateCycleIfFlat() called from OnTick (every tick) and OnTradeTransaction (on every DEAL_ADD). Fixes bug where realized accumulated across cycles and triggered Accumulate Close immediately at next near-zero floating.
type: feature
---

## Bug
Log: `GK ACCUM CLOSE — realized=20008.26 floating=-6.31 tgt=20000.0` while only 2 fresh INIT orders existed (floating ≈ -20). v1.41 OnTradeTransaction had an empty block intended to reset, comment said "reset on next OpenInitial cycle" but OpenInitial() never reset. → realized accumulated forever → Accumulate triggered on every near-zero floating after cumulative profit ≥ target.

## Fix
- New `TryResetAccumulateCycleIfFlat()`: if both `CountSideSimple(BUY)==0 && CountSideSimple(SELL)==0` and `|g_realizedCycle|>0.0001` → log + zero `g_realizedCycle`.
- Called from **OnTick** (top, before BuildHeroTicketCache) and **OnTradeTransaction** (on `TRADE_TRANSACTION_DEAL_ADD`). Idempotent.
- Forward declaration added at globals section so OnTradeTransaction can call it.

## Not Changed
OrderSend / trade.* / Entry / Grid distance / CalcGridLot / Cost-Hit core / Per-Order BE+Trail / Avg-Trail strict 2-cross / TP modes (FixedDollar / AvgTP push / %Bal) / Hero v1.4 (BuildHeroTicketCache, ManageHeroOppositeClose, BE-Lock SL, Single-Side Lock, sticky tag, Post-Close Grace).
