---
name: Golden2 EA v2.73 Entry Mode (PENDING/SMA/INSTANT)
description: v2.73 adds InpEntryMode input with 3 options ported from Gold Miner — G2_ENTRY_PENDING (default, original BuyStop+SellStop frame), G2_ENTRY_SMA (market entry per side filtered by SMA: BUY only when bid>SMA, SELL only when bid<SMA), G2_ENTRY_INSTANT (market BUY+SELL immediately at Ask/Bid, no indicator). PlaceInitialFrame dispatches non-PENDING modes to new PlaceInitialMarket() helper which uses trade.Buy/Sell with InpInitialLot at Ask/Bid, MakeComment("IN") tag preserved so grid/hedge/triple-gate/accumulate downstream logic stays unchanged. SMA handle (g_smaHandle, period/TF/applied price configurable) created in OnInit only when mode=SMA, released in OnDeinit. Per-group 5s cooldown + per-side Squeeze block applied in market path too. Dashboard title and OnInit log show "Entry: PENDING/SMA/INSTANT". Default G2_ENTRY_PENDING means existing .set files remain 100% backward compatible.
type: feature
---
v2.73 (file: public/docs/mql5/Golden2_EA.mq5) introduces a 3-way Entry Mode picker borrowed from Gold Miner without disturbing any existing trading logic.

Inputs (group "=== Entry Mode (v2.73) ==="):
- InpEntryMode (enum ENUM_ENTRY_MODE_G2): G2_ENTRY_PENDING=0 (default, frame), G2_ENTRY_SMA=1, G2_ENTRY_INSTANT=2
- InpSMA_Period=20, InpSMA_TF=PERIOD_CURRENT, InpSMA_AppliedPrice=PRICE_CLOSE

Behavior:
- PENDING — unchanged BuyStop+SellStop frame at mid ± InpFrameUpper/Lower with all v2.72 paths.
- SMA — market entry; placeBuy=true only if bid>SMA, placeSell=true only if bid<SMA; if SMA not ready, retry in 2s.
- INSTANT — market entry on both sides immediately (respects InpInitSideMode + per-side Squeeze block).

PlaceInitialFrame() routes non-PENDING modes to new PlaceInitialMarket(g, placeBuy, placeSell):
- 5s per-group cooldown
- Per-side Squeeze block (mirror v2.72)
- SMA filter (SMA mode only)
- trade.Buy(InpInitialLot, _Symbol, ask, sl, tp, "GxxxIN") / trade.Sell(... bid ...)
- TP/SL from InpInitialTPPips/InpInitialSLPips honouring STOPS_LEVEL
- Comment uses MakeComment(g, false, "IN") — identical to PENDING path so grid/hedge/triple-gate/accumulate all consume the new market position seamlessly

g_smaHandle created in OnInit only when InpEntryMode==G2_ENTRY_SMA, released in OnDeinit.

Dashboard L_TITLE: " Golden2 EA v2.7.3    Entry: PENDING/SMA/INSTANT    Side: ..."

What's NOT changed:
- OrderSend / trade.* logic of pending frame
- Grid Loss / Grid Profit / Hedge mirror / Triple-Gate / Accumulate Close
- v2.5 Toward-Price Trail / v2.6 Re-entry / v2.70 Continuous Frame
- v2.72 Squeeze per-side + Backtest acceleration
- License / News / Sync modules
- Default G2_ENTRY_PENDING → existing .set files work unchanged
