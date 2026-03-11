## แก้ไข Grid ไม่ทำงานใน Instant Mode - Gold Miner EA

### สิ่งที่แก้ไข
1. **Line 844**: เพิ่ม `ENTRY_INSTANT` ให้ ManageTrailingStop ทำงาน
2. **Line 850**: เพิ่ม `ENTRY_INSTANT` ให้ ManageTPSL ทำงาน
3. **ENTRY_INSTANT block**: เพิ่ม Grid Loss, Grid Profit, auto-detect broker-closed, justClosed reset

### สิ่งที่ไม่เปลี่ยนแปลง
- Trading Strategy Logic (SMA signal, ZigZag signal)
- Order Execution (trade.Buy/Sell/PositionClose)
- Grid calculation logic (CheckGridLoss, CheckGridProfit functions)
- TP/SL/Trailing/Breakeven calculation functions
- License / News / Time Filter core logic
- Accumulate / Matching Close / Drawdown exit logic
- Dashboard / Rebate system
