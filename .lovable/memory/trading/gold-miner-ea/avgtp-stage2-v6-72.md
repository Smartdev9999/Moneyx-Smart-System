---
name: AvgTP Stage 2 v6.72
description: AVG_TP recovery mode runs as Stage 2 only after Matching Close unlocks the main hedge ticket
type: feature
---
v6.72 fixes v6.71 bug where RECOVERY_CLOSE_AVG_TP skipped matching entirely (main hedge stuck at large loss).

Flow:
- Stage 1: ManageHedgeMatchingClose / BoundAvgTP / PartialClose runs every tick (unchanged).
- Stage 2: After matching releases the main hedge (hedgeTicket==0 or PositionSelectByTicket fails) AND CountHedgeGridOrders(h) > 0, ManageRecoveryAvgTP(h) sets a unified broker TP across remaining bound + recovery basket at InpRecovery_AvgTPDistance points from weighted-avg net price.

Trigger placed at end of per-set loop in ManageHedgeSets, after SyncRecoveryBasketTP block. MATCHING mode behaves exactly like v6.71. Dashboard label: "MATCHING+AVGTP (dist=Np)" when AVG_TP selected. Log prefix: "v6.72 AVGTP-S2".
