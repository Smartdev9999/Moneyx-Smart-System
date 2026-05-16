# Memory Index

(append) v2.8.7: [Purge Inputs + Reserve Profit Fix](mem://trading/golden2-ea/v2-8-7-purge-inputs-and-reserve-profit-fix) — deletes deprecated multi-confirm Squeeze inputs/globals/handles; replaces broken MinGain-delta HOLD gate with `winProfit >= ReserveProfitUSD + MinGainUSD`; shred passes use `InpExit_ReserveProfitUSD` as actual KEEP floor (was hardcoded MinNetUSD=$1)

(append) v2.8.8: [Recovery Grid Continuation](mem://trading/golden2-ea/v2-8-8-recovery-grid-continuation) — TryPlaceRecoveryGridContinuation runs every tick while g_groupInRecovery; fires RC#2..N at GridLoss distance via PlaceRecoveryGridIfNeeded so the multiplier ladder advances instead of stranding RC#1

(append) v2.8.9: [Recovery-Mode Order Lock + Prior-Advance Bypass](mem://trading/golden2-ea/v2-8-9-recovery-lock-and-prior-advance-bypass) — freezes GL/GP/Initial-trail/IN-rearm/IN-market-reentry when g_groupInRecovery; IsPriorGroupSafeForAdvance treats post-match (g_groupHedgeUsed && g_groupPostMatchAvgActive) or g_groupRecoveryLevel>0 as safe-pass to unblock prior-group advance queue

(append) v2.9.0: [Recovery Seed Lock](mem://trading/golden2-ea/v2-9-0-recovery-seed-lock) — locks PlaceRecoveryGridIfNeeded seedLot once per group (excludes RC# tickets from scan) so Multiplier^level applies to a stable base; fixes RC lot exponential explosion


(append) v2.9.1: [Backtest Performance Pack](mem://trading/golden2-ea/v2-9-1-backtest-performance-pack) — tester-aware silencing of verbose logs (g_verboseEffective), skip Avg/TP chart draw in Tester, aux-chart sweep limited to visual Tester, optional InpTester_TickStrideMs throttle; zero trading-logic changes
