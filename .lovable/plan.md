

## Implemented: v6.16 — Hedge Trigger Mode: Expansion vs DD%

### Changes Made

1. **`ENUM_HEDGE_TRIGGER`**: New enum with `HEDGE_TRIGGER_EXPANSION` (original) and `HEDGE_TRIGGER_DD_PERCENT` (new)

2. **New Input Parameters**:
   - `InpHedge_TriggerMode` — choose between Expansion or DD% trigger
   - `InpHedge_DDTriggerPct` — DD% to trigger first hedge (default 5%)
   - `InpHedge_DDStepPct` — DD% step for subsequent hedges (default 5%)
   - `InpHedge_DDCooldownSec` — min seconds between DD hedges (default 60)

3. **`HedgeSet.triggerType`**: New field (0=expansion, 1=DD%) for per-set gate logic

4. **`CheckAndOpenHedgeByDD()`**: Calculates floating loss % per side (BUY/SELL) against balance, opens hedge when threshold reached

5. **`OpenDDHedge()`**: Opens DD-triggered hedge with `GM_HEDGE_D` comment prefix for recovery identification

6. **`IsHedgeCloseAllowed()`**: Gate 1 (Expansion Cycle) is skipped for DD-triggered sets (triggerType==1). Gates 2+3 remain mandatory for all types

7. **`ManageHedgeSets()`**: Added DD trigger recalculation at end of loop based on remaining active DD sets

8. **`RecoverHedgeSets()`**: Detects `GM_HEDGE_D` prefix to recover triggerType + recalculates DD thresholds

9. **OnTick flow**: Routes to `CheckAndOpenHedge()` or `CheckAndOpenHedgeByDD()` based on `InpHedge_TriggerMode`

10. **Dashboard**: Shows trigger type per set (Exp/DD%), cycle status shows "Skip(DD)" for DD sets, added DD trigger info row

11. **Version bump**: v6.15 → v6.16

### กฎที่บังคับใช้

```text
Hedge Trigger Mode:
- Expansion: เปิด Hedge เมื่อ Squeeze Expansion ผ่าน (เดิม)
- DD%: เปิด Hedge เมื่อ floating loss ฝั่ง BUY หรือ SELL ถึง % ที่กำหนด
  - ทำงานแยกฝั่ง: BUY loss → SELL hedge, SELL loss → BUY hedge
  - Threshold เพิ่มขึ้นทีละ step (5% → 10% → 15%...)
  - Cooldown ป้องกัน hedge ถี่เกินไป

การปิด Hedge:
- DD sets: ข้าม Gate 1 (Expansion Cycle) → ใช้แค่ Gate 2+3
- Expansion sets: ต้องผ่านครบ 3 Gates เหมือนเดิม
- Accumulate Close ยังทำงานรวมเหมือนเดิม
```

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Expansion Hedge logic — ทำงานเหมือนเดิมเมื่อเลือกโหมด EXPANSION
- Matching Close / Grid Mode logic ภายใน — ไม่แก้
- Accumulate Close — ทำงานรวมเหมือนเดิม
- Orphan Recovery / Squeeze detection — ไม่แก้
