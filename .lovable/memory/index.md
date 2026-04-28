# Memory: index.md
Updated: today

# Project Memory
- [Grid Refill Fix v6.87](mem://trading/gold-miner-ea/grid-refill-fix-v6-87) — Tracks all gens + bound orders, OnTradeTransaction fallback, fixes Breakeven-only mode not refilling

## Core
- **Parity**: Absolute parity between backtest and live trading. Restore grid states and positions identically across EA restarts.
- **MQL5 Rules**: Init handles in `OnInit`, explicit casting, dynamic arrays for series. Ask before adding News/License/Sync modules.
- **Versioning**: Increment minor version for logic/UI changes. Update `#property`, headers, dashboard, and logs simultaneously.
- **Security & APIs**: Edge functions use fail-closed pattern for `EA_API_SECRET`. License sync requires `x-api-key` header exclusively.

## Memories
- [Grid Refill After Trailing v6.86](mem://trading/gold-miner-ea/grid-refill-after-trailing-v6-86) — Re-open GL/GP at price gaps left by Per-Order Trailing/Breakeven closes; default OFF
- [Avg Trailing Broker SL v6.85](mem://trading/gold-miner-ea/avg-trailing-broker-sl-v6-85) — SyncBrokerTPSL respects g_trailingSL when active; preserves existing broker SL
- [Per-Side Trailing Reset v6.84](mem://trading/gold-miner-ea/per-side-trailing-reset-v6-84) — Per-side reset funcs prevent one side wiping the other's trailing state
- [Trailing Modify Throttle v6.83](mem://trading/gold-miner-ea/trailing-modify-throttle-v6-83) — Step-gated PositionModify throttle on trailing/breakeven SL
- [Grid Profit Candle Confirm v6.82](mem://trading/gold-miner-ea/grid-profit-candle-confirm-v6-82) — N consecutive confirming candles before next GP order
- [Stuck-Hedge Scanner v6.80](mem://trading/gold-miner-ea/stuck-hedge-scanner-v6-80) — Diagnoses & auto-heals stale hedge sets/owner locks
- [Stuck-TP Scanner v6.79](mem://trading/gold-miner-ea/stuck-tp-scanner-v6-79) — Clears stale TP/SL on bound tickets with live hedge
- [Hedge Open Delay v6.78](mem://trading/gold-miner-ea/hedge-open-delay-v6-78) — Cooldown gating Expansion + DD% hedge opens
- [Cross-Gen INIT Guard v6.76](mem://trading/gold-miner-ea/cross-gen-init-guard-v6-76) — Blocks INIT entry while older-gen normal orders alive
- [Gen Flow Mutex v6.74](mem://trading/gold-miner-ea/gen-flow-mutex-v6-74) — Blocks DD hedge/recovery grid collisions
- [No-ReHedge Gen-Side Lock v6.74](mem://trading/gold-miner-ea/no-rehedge-gen-side-lock-v6-74) — Locks (gen,side) after first hedge release
- [Orphan Hedge Auto-Heal v6.73](mem://trading/gold-miner-ea/orphan-hedge-auto-heal-v6-73) — Closes orphan hedges; trims inflated hedges
- [Clear Bound TP On Bind v6.72](mem://trading/gold-miner-ea/clear-bound-tp-on-bind-v6-72) — Force-clears broker TP/SL on bound tickets at hedge open
- [Match Pool Both Sides v6.61](mem://trading/gold-miner-ea/match-close-pool-v6-61) — Pools profits both sides as budget for partial close
- [Sequential Recovery Owner v6.59](mem://trading/gold-miner-ea/sequential-recovery-owner-v6-59) — Locks recovery to one gen until flat
- [BB Entry Filter v6.56](mem://trading/gold-miner-ea/bb-entry-filter-v6-56) — Bollinger Band filter blocking new initial/grid orders
- [Max Grid Trailing Stop v6.54](mem://trading/gold-miner-ea/max-grid-trailing-stop-v6-54) — Start/Max Order trail logic for deep grids
- [Generation Persistence v6.53](mem://trading/gold-miner-ea/generation-persistence-v6-53) — MQL5 GlobalVariables for cycle iterations
- [Hedge Recovery Toggle v6.52](mem://trading/gold-miner-ea/hedge-recovery-toggle-v6-52) — Master toggle to bypass automated matching close
- [Comment Structure v6.50](mem://trading/gold-miner-ea/comment-structure-v6-50) — Independent BUY/SELL baskets per generation
- [Broker TP Sync v6.50](mem://trading/gold-miner-ea/broker-side-tp-sl-sync-v6-50) — Sync TP/SL directly to broker side
- [TP Sync Reliability v6.50](mem://trading/gold-miner-ea/broker-tp-sync-reliability-v6-50) — Zero-delay init syncing
- [Grid Loss Candle Confirm v6.40](mem://trading/gold-miner-ea/grid-loss-candle-confirmation-v6-40) — N confirming candles before GL
- [Hedge Side Pause v6.39](mem://trading/gold-miner-ea/hedge-side-pause-v6-39) — Trend entry block after hedge triggers
- [Generation Aware Isolation v6.38](mem://trading/gold-miner-ea/generation-aware-isolation-v6-38) — Independent generation management
- [Hedge Set Capacity v6.36](mem://trading/gold-miner-ea/hedge-set-capacity-v6-36) — 50 concurrent hedge sets
- [Balance Guard v6.35](mem://trading/gold-miner-ea/balance-guard-v6-35) — Equity monitoring when hedging active
- [Max DD Tracking v6.34](mem://trading/gold-miner-ea/max-dd-percent-tracking-v6-34) — Records Max DD% as % of balance
- [Daily Equity Target v6.32](mem://trading/gold-miner-ea/daily-target-profit-equity-v6-32) — Equity-based daily profit target
- [DD Trigger Threshold v6.21](mem://trading/gold-miner-ea/dd-trigger-threshold-logic-v6-21) — Constant DD trigger per generation
- [Safe Cycle Reset v6.27](mem://trading/gold-miner-ea/safe-cycle-reset-v6-27) — Prevents released orders re-triggering
- [Prev Hedged Tracking v6.26](mem://trading/gold-miner-ea/prev-hedged-ticket-tracking-v6-26) — Prevents re-triggering on closure
- [Hedge Exit Triple Gate v6.25](mem://trading/gold-miner-ea/hedge-exit-triple-gate-v6-25) — Triple Gate safety for exits
- [Hedge Trigger Modes v6.25](mem://trading/gold-miner-ea/hedge-trigger-modes-v6-25) — EXPANSION / DD% / DOLLAR triggers
- [Hedge Recovery Sequencing v6.24](mem://trading/gold-miner-ea/hedge-recovery-sequencing-v6-24) — Sequential recovery process
- [Hedge Set State Persistence v6.24](mem://trading/gold-miner-ea/hedge-set-state-persistence-v6-24) — Independent hedge set states
- [Order Limit Logic v6.24](mem://trading/gold-miner-ea/order-limit-logic-v6-24) — NormalOrderCount for MaxOpenOrders
- [News Sync Safety v6.17](mem://trading/gold-miner-ea/safety-and-news-v6-17) — UTC news timestamp sync via serverGMTOffset
- [Directional Filter v6.14](mem://trading/gold-miner-ea/volatility-squeeze-filter-v6-14) — Directional Agreement before hedge
- [Squeeze Stability v6.13](mem://trading/gold-miner-ea/squeeze-state-stability-v6-13) — Stable volatility state via prev closed bar
- [Orphan Generation Recovery v6.3](mem://trading/gold-miner-ea/orphan-generation-recovery-v6-3) — Manages older cycle positions
- [DD% TP Logic v6.7](mem://trading/gold-miner-ea/dd-percent-tp-logic-v6-7) — TP based on DD recovery
- [Account Auto-Linking](mem://technical/sync-account-data-auto-linking-v3) — Connect MT5 names to DB
- [Grid Parameter Recovery v6.5](mem://trading/gold-miner-ea/grid-parameter-recovery-v6-5) — Resilience for mid-trade param changes
- [Customer Portal](mem://auth/customer-portal-access-and-onboarding) — Customer RLS view-only access
- [Customer Profiles](mem://auth/customer-profile-management) — Admin-managed customer profiles
- [Admin User Tools](mem://auth/admin-customer-user-management-tools) — Service role for customer accounts
- [Fund Mgmt Core](mem://features/fund-management-core-logic) — USDT tracking
- [Fund Mgmt Realtime](mem://features/fund-management-automation-and-realtime) — pg_cron + realtime
- [Fail-Closed Security](mem://technical/edge-function-security-fail-closed) — EA_API_SECRET enforcement
- [DB Data Retention](mem://technical/database-retention-and-cleanup-v2) — 60-day retention
- [Economic News API](mem://technical/economic-news-api-spec) — Edge function spec
- [EA Tracker MQL5](mem://technical/ea-strategy-tracker-mql5) — Market data capture
- [History Sync](mem://technical/ea-strategy-tracker-history-sync) — HistorySelect trade history
- [Timeframe Aggregation](mem://trading/ai-advisor/multi-timeframe-aggregation) — H1→H4/D1 fallback
- [Golden2 EA family](mem://trading/golden2-ea/v2-7-6-instant-sma-per-side-reentry) — Latest v2.7.6 + earlier docs in trading/golden2-ea/
- [Harmony Dream EA family](mem://trading/harmony-dream-state-reset-logic-v2-37) — Latest v2.3.7
- [Asset Miner EA](mem://trading/asset-miner/multi-pair-logic) — 5-pair isolated grids
- [Jutlameasu EA](mem://trading/jutlameasu/strategy-spec) — Cross-Over hedging strategy
- [MQL5 Market Bypass](mem://trading/mql5-market-tester-bypass) — Tester license bypass
- [ATR Dynamic Grid](mem://trading/atr-dynamic-grid-v2) — ATR grid spacing
- [Shared CDC Logic](mem://trading/shared-cdc-reliability-logic-v1-7-0) — Decoupled trend filter
- [Scalper Init](mem://project/moneyx-precision-scalper-init) — XAUUSD SMC scalper
- [GM Grid Refill Decoupled v6.88](mem://trading/gold-miner-ea/grid-refill-decoupled-v6-88) — ManageGridRefill() runs every tick decoupled from CheckGridLoss/Profit gates; preserves original level#; throttled reject logs
