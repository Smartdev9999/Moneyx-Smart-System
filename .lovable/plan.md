

## v6.25 — แก้ Hedge Re-trigger หลังปิด Set + เพิ่ม DD Dollar Mode

### Implementation Summary

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

### Changes (8 steps)

#### 1. Version bump: v6.24 → v6.25
- Lines 1-9: Header, `#property version`, `#property description`

#### 2. Add `HEDGE_TRIGGER_DD_DOLLAR` to enum (line 72-76)
```cpp
enum ENUM_HEDGE_TRIGGER
{
   HEDGE_TRIGGER_EXPANSION  = 0,  // Squeeze Expansion (Original)
   HEDGE_TRIGGER_DD_PERCENT = 1,  // Drawdown % per Side
   HEDGE_TRIGGER_DD_DOLLAR  = 2   // Drawdown $ per Side
};
```

#### 3. Add input `InpHedge_DDTriggerDollar` (after line 337)
```cpp
input double InpHedge_DDTriggerDollar = 500.0; // DD$ to trigger hedge (per side)
```

#### 4. Add global `g_lastHedgeCloseTime` (near line 532)
```cpp
datetime g_lastHedgeCloseTime = 0;  // v6.25: cooldown after hedge set close
```

#### 5. Update `CheckAndOpenHedgeByDD()` (lines 6692-6757)
- Accept both `HEDGE_TRIGGER_DD_PERCENT` and `HEDGE_TRIGGER_DD_DOLLAR`
- Add cooldown guard: `if(TimeCurrent() - g_lastHedgeCloseTime < InpHedge_DDCooldownSec) return;`
- Dollar mode: compare `MathAbs(buyLoss) >= InpHedge_DDTriggerDollar` directly
- Log shows $ or % based on mode

#### 6. Update OnTick routing (line 1222-1226)
- Route `HEDGE_TRIGGER_DD_DOLLAR` to same `CheckAndOpenHedgeByDD()`

#### 7. Add `g_lastHedgeCloseTime = TimeCurrent()` at all 7 deactivation points
- Line 7666 (external close)
- Line 8400 (AvgTP)
- Line 8552 (matching close)
- Line 8576 (release close)
- Line 8694 (batch close)
- Line 8811 (grid recover)
- Line 8848 (grid cleanup)

#### 8. Update Dashboard DD display (lines 3411-3445)
- Show DD info in $ when dollar mode active
- Show threshold in $ instead of %

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose) — ไม่แก้
- Trading Strategy Logic (SMA/ZigZag/Grid/TP/SL) — ไม่แก้
- Core Module Logic (License, News, Time, Data sync) — ไม่แก้
- Generation-aware isolation (v6.24) — ไม่แก้
- DD trigger threshold logic — เพิ่ม dollar mode เท่านั้น ไม่แก้ % mode
- Triple-gate exit logic — ไม่แก้
- OpenDDHedge / binding logic — ไม่แก้

