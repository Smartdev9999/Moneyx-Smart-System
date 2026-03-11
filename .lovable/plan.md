## เพิ่ม Entry Mode แบบ Instant (ไม่ใช้ Indicator) ใน Gold Miner EA

### สิ่งที่เพิ่ม
1. **Enum**: `ENTRY_INSTANT = 2` ใน `ENUM_ENTRY_MODE`
2. **Instant Entry Block**: เปิด BUY+SELL ทันทีเมื่อฝั่งนั้นว่าง (buyCount==0 / sellCount==0) โดยไม่ต้องรอสัญญาณ SMA/ZigZag
3. **Guard ยังคงใช้เหมือนเดิม**: g_newOrderBlocked, g_eaStopped, MaxOpenOrders, DontOpenSameCandle, TradingMode

### สิ่งที่ไม่เปลี่ยนแปลง
- Trading Strategy Logic (SMA signal, ZigZag signal)
- Order Execution (trade.Buy/Sell/PositionClose)
- TP/SL/Trailing/Breakeven/Grid calculations
- License / News / Time Filter core logic
- Accumulate / Matching Close / Drawdown exit logic
- Dashboard / Rebate system
