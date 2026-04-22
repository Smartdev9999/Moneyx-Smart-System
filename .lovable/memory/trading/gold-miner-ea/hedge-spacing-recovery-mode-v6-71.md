---
name: Hedge MinSpacing + Recovery Close Mode v6.71
description: Gold Miner EA v6.71 — minutes-based MinSpacing gate between hedge sets across all triggers (Expansion/DD%/DD$); choice of MATCHING_CLOSE (legacy) vs AVERAGE_TP recovery mode where the entire set basket gets one weighted-avg broker TP at avg+/-N points.
type: feature
---
- New inputs: `InpHedge_MinSpacingMin` (default 30, 0=Off), `InpRecovery_CloseMode` (MATCHING/AVG_TP), `InpRecovery_AvgTPDistance` (default 500p).
- Global tracker `g_lastHedgeOpenTime` set after every successful hedge open (Expansion + DD).
- `RecoverHedgeSets()` honors spacing across restart by seeding from max(active hedge openTime).
- `ManageRecoveryAvgTP(idx)` builds dedup basket of {hedge + bound + recovery grid + comment-match `GM_HD<gen>_*`}, computes weighted-avg break-even per side, derives net break-even, applies `trade.PositionModify` to ALL tickets with TP = BE +/- AvgTPDistance points.
- AVG_TP mode skips matching/partial entirely but still permits grid expansion.
- Dashboard shows spacing countdown + active recovery mode.
