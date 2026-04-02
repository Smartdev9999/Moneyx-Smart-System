

## Implemented: v6.28 — Balance Guard (ปิดทุกออเดอร์เมื่อ Equity กลับถึงเป้า Balance)

### หลักการทำงาน
เมื่อเกิด Hedging (มี active hedge set) ระบบเริ่ม track Equity → เมื่อ Equity >= `InpBalanceGuard_Target` → ปิดทุกออเดอร์ทันที (รวม hedge) แล้วเริ่มใหม่

### Changes Made

1. **Version bump**: v6.27 → v6.28
2. **Input parameters**: `InpBalanceGuard_Enable`, `InpBalanceGuard_Target`
3. **Global state**: `g_balanceGuardActive` — activated when hedge set opens
4. **`CheckBalanceGuard()` function**:
   - Activates when `g_hedgeSetCount > 0`
   - Checks `AccountInfoDouble(ACCOUNT_EQUITY) >= InpBalanceGuard_Target`
   - If triggered → `CloseAllPositions()` → full cycle reset
   - Auto-deactivates when flat
5. **OnTick integration**: Called after hedging check block
6. **Dashboard**: Shows "Bal Guard" row with Active/Standby status, current Equity vs Target

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Grid/TP/SL)
- Core Module Logic (License, News, Time, Data sync)
- DD trigger / Triple-gate / Matching close
- OpenDDHedge / binding / generation logic
- Safe Cycle Reset (v6.27)
