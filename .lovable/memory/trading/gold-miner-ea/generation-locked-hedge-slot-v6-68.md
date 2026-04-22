---
name: Generation-Locked Hedge Slot v6.68
description: Hedge slot index === bound generation; comment GM_HEDGE_(gen+1); never reuse slot id while same-gen hedge active; InpHedge_MaxSets caps concurrent active sets only
type: feature
---
Gold Miner EA v6.68 enforces a strict 1:1 mapping between hedge slot index and bound cycle generation:
- `FindGenerationHedgeSlot(bindGen)` replaces `FindFreeHedgeSlot()`. Returns `bindGen` if free, else -1 (never reuses slot id).
- Comment is always `GM_HEDGE_(slot+1)` so `GM_HEDGE_1↔gen0`, `GM_HEDGE_2↔gen1`, `GM_HEDGE_3↔gen2`, ...
- Expansion trigger passes `g_cycleGeneration`; DD trigger passes `bindGen` snapshot — both bind to the gen they're hedging.
- `InpHedge_MaxSets` still caps the number of *concurrently active* hedge sets (independent of slot id). When old hedges still float and new generations form, system can open `GM_HEDGE_5`, `GM_HEDGE_6`, etc., as long as activeCount < MaxSets.
- `RecoverHedgeSets()` already parses slot from `GM_HEDGE_N` comment (slot=N-1); v6.68 additionally overrides `boundGeneration = slot` to enforce invariant across restarts (warns if oldest bound gen differs).
- All v6.66 features (reverse-walk seed, combined avg TP, one-time shred, MaxGridTrades cap) operate on the new gen-locked slot unchanged.
- Persistence GVs (`GME_HEDGE_TICKET_<slot>`, `GME_HEDGE_SHRED_<slot>`) now keyed by gen-locked slot.
