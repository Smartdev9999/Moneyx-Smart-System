## เพิ่มระบบ Max Drawdown แบบ Fix Dollar ใน Gold Miner EA

### สิ่งที่เพิ่ม/แก้ไข

1. **Enum ใหม่**: `ENUM_DD_MODE` (`DD_PERCENT`, `DD_FIXED_DOLLAR`)
2. **Input ใหม่**: `DrawdownMode` (เลือก % หรือ $), `MaxDrawdownDollar` (default 5000.0)
3. **CheckDrawdownExit()**: เพิ่ม branch ตาม DrawdownMode — ใช้ % หรือ fixed $ ในการตรวจสอบ
4. **Dashboard**: แสดง Current DD และ Max DD ตาม mode ที่เลือก (% หรือ $)

### สิ่งที่ไม่เปลี่ยนแปลง

- Trading Strategy Logic (SMA, ZigZag, Grid entry/exit)
- Order Execution (trade.Buy/Sell/PositionClose)
- TP/SL/Trailing/Breakeven calculations
- License / News / Time Filter core logic
- Accumulate / Matching Close logic
- Dashboard buttons functionality
- Rebate calculation system (from previous update)
