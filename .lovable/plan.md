## Gold Miner EA v2.9 - Completed

All changes implemented in `public/docs/mql5/Gold_Miner_EA.mq5` (v2.80 → v2.90).

### Changes Made

1. **Fix Time Filter Resume Bug**: Moved `justClosedBuy`/`justClosedSell` reset inside `if(!g_newOrderBlocked)` block so flags persist during filter blocks
2. **Manual Pause**: Added `g_eaIsPaused` global + integrated into `g_newOrderBlocked` logic
3. **Dashboard - System Status**: Shows Working/Paused/Blocked/Invalid/Expired
4. **Dashboard - News Countdown**: Shows news title + countdown timer when paused
5. **Dashboard - Control Buttons**: Pause/Start, Close Buy, Close Sell, Close All with MessageBox confirmation
6. **OnChartEvent()**: Handles button clicks
7. **CloseAllPositionsByType()**: Closes positions by BUY/SELL type
8. **CreateDashButton()**: OBJ_BUTTON helper function
9. **OnDeinit cleanup**: Added `ObjectsDeleteAll(0, "GM_Btn")`

### Untouched (guaranteed)
- SMA Signal Logic, Grid Entry/Exit, TP/SL/Trailing/Breakeven, Accumulate Close, Drawdown Exit, License Module, News/Time Filter core logic
