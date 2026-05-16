---
name: Golden2 v2.8.6 Hedge Orphan Offset + Squeeze BB/KC-only
description: Squeeze reverted to pure BB/KC ratio (BB-breakout/ADX/ATR-MA/EMA removed); MirrorLossSideToHedgePendings now sorts loss tickets oldest→newest and skips N=CountOrphanMainOnHedgeSide(g,hedgeSide) so total volume stays balanced
type: feature
---
**Part A — Squeeze simplification**
- `ComputeSqueezeForTF` reduced to BB(idx)+ATR(idx) → `ratio = (bbU-bbL)/(2·KCMult·atr)`; `isExp = ratio >= InpSQ_ExpansionThreshold`
- ADX + EMA handles no longer created in OnInit (left INVALID_HANDLE)
- Dashboard `Confirm` row removed; `RefreshGroupExpansionLatch` now latches the moment ratio crosses threshold (fixes early Hedging close)
- Inputs `InpSQ_UseBBBreakout/UseADX/ADXPeriod/ADXThreshold/UseATRConfirm/ATRMAPeriod/ATRMult/UseEMA/EMAPeriod/EMAPrice` retained as no-op (.set backward compat)

**Part B — Hedge orphan offset**
- `CountOrphanMainOnHedgeSide(g, hedgeSide)` counts same-group main positions on opposite-of-loss side
- `MirrorLossSideToHedgePendings` sorts loss tickets by POSITION_TIME_MSC; skips oldest `skipN = orphanOnHedge` tickets
- Place pendings only for `lossTags[skipN..end]`; orphan-pending deletion uses same KEEP slice
- Example: BUY loss×8 + SELL orphan×4 → 4 SELL_STOP placed for newest 4 BUYs (not 8)
- Dashboard adds `Orph  B:n  S:n` row per active hedge group

**Untouched:** Triple-Gate, One-Hedge-Per-Group, Post-Match Avg TP, Recovery Grid, Matching Close, Entry modes, Grid Loss/Profit, per-order trail, hedge trigger %, license/news/time/sync, BB/KC pipeline itself.
