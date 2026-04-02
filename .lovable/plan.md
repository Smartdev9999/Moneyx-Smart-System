

## v6.28 — เพิ่ม Balance Guard (ปิดทุกออเดอร์เมื่อ Equity กลับถึงเป้า Balance)

### หลักการทำงาน
เมื่อเกิด Hedging (มี active hedge set) ระบบจะเริ่ม track Equity → พอ Equity >= `InpBalanceGuardTarget` (เช่น 1000$) → ปิดทุกออเดอร์ทันที (รวม hedge) แล้วเริ่มใหม่

### Changes (5 steps)

#### 1. Version bump v6.27 → v6.28
- `#property version`, `#property description`, header comment, dashboard

#### 2. เพิ่ม input parameters (หลัง line 341)
```cpp
input bool     InpBalanceGuard_Enable = false;  // Balance Guard: Enable
input double   InpBalanceGuard_Target = 1000.0; // Balance Guard: Target Equity ($)
```

#### 3. เพิ่ม global state (หลัง line 540)
```cpp
bool g_balanceGuardActive = false;  // v6.28: activated when hedge set opens
```

#### 4. เพิ่ม `CheckBalanceGuard()` function
- เช็คว่า `InpBalanceGuard_Enable` เปิดอยู่ และ `g_hedgeSetCount > 0` (มี hedge active)
- ถ้ามี hedge → set `g_balanceGuardActive = true`
- เช็ค `AccountInfoDouble(ACCOUNT_EQUITY) >= InpBalanceGuard_Target`
- ถ้าถึงเป้า → เรียก `CloseAllPositions()` → reset state → Print log
- Reset `g_balanceGuardActive` เมื่อ flat

#### 5. เรียก `CheckBalanceGuard()` ใน OnTick
- วางหลัง hedging check block (หลัง line 1236) ก่อน original trading logic
- แสดงสถานะ Balance Guard บน Dashboard (BG: Active/Inactive, Equity/Target)

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose) — ไม่แก้
- Trading Strategy Logic (SMA/ZigZag/Grid/TP/SL) — ไม่แก้
- Core Module Logic (License, News, Time, Data sync) — ไม่แก้
- DD trigger / Triple-gate / Matching close — ไม่แก้
- OpenDDHedge / binding / generation logic — ไม่แก้
- Safe Cycle Reset (v6.27) — ไม่แก้

