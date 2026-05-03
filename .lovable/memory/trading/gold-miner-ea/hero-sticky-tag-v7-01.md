---
name: Gold Miner EA v7.01 — Hero Sticky Tag (Survives Basket Shrinkage)
description: BuildHeroTicketCache activation threshold now applies ONLY when phase==NONE. Once tagged (ARMED/BE_GUARD), Hero stays tagged even when side total falls below threshold; take=min(N, nGL) instead of nGL-1. Fixes bug where SELL basket closing under 20-order threshold dropped Hero tag → trailing/SyncBrokerTPSL closed Hero.
type: feature
---

# v7.01

## Bug
v7.00 BuildHeroTicketCache re-evaluated `nAll < activateThreshold` every tick. When SELL basket closed via Avg TP/Trail and dropped from 21 → 8 active, threshold gate (>=20) failed → `continue` → g_heroTicketCount=0 → Hero tickets no longer skipped by ManagePerOrderTrailing/SyncBrokerTPSL → SL/TP overwritten → Hero closed alongside basket.

## Fix
- Threshold gate guarded by `curPhase == 0 /*NONE*/` — only first activation enforces it.
- Once ARMED or BE_GUARD: gate bypassed; `take = min(InpHero_OrderCount, nGL)` (not nGL-1) so all surviving GL stay tagged.
- ResetHeroStateIfFlat still clears phase when truly flat (no Hero + no basket).

## Not Changed
OrderSend, entry conditions, GL/GP lot/distance, Avg TP/Trail formulas, Hedge/Triple-Gate/Recovery, Lock-profit BE-SL, OppositeBasketClose hook, License/News/Sync.
