

## Fix: Grid Recovery ไม่ออก Order ชุด E + เพิ่ม Group H/I/J (v5.13 → v5.14)

### สิ่งที่แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Grid Recovery — hedgeTicket = 0 ทุก path
- `ManageHedgeMatchingClose()`: เพิ่ม `hedgeTicket = 0` หลัง `trade.PositionClose()` ในกรณี no matchable losses
- `ManageHedgeGridMode()`: เพิ่ม fallback เมื่อ hedgeTicket > 0 แต่ position ไม่ valid → set hedgeTicket = 0 → เข้า ManageGridRecoveryMode()
- คำนวณ gridLevel จาก `CalculateRemainingBoundLots()` แทน hardcode 0

#### 2. ขยายเป็น 10 Groups (A-J) + 20 Hedge Slots
- `MAX_HEDGE_SETS`: 16 → 20
- `FindLowestFreeCycle()`: scan 0-9 แทน 0-6, suffixes เพิ่ม "_H", "_I", "_J"
- `GetCycleSuffix()`: ใช้ `CharToString('A' + index)` รองรับอัตโนมัติ

#### 3. Dashboard — 10 คอลัมน์แบบ 2 แถว (5+5)
- Groups A-E แถวบน, F-J แถวล่าง
- เพิ่มสี Group H (Purple), I (Gold), J (Teal)
- คง layout 4 rows (H1-H4) ต่อ set

#### 4. Version bump: v5.13 → v5.14

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge Guards (cycle-aware, squeeze directional block)
- Normal Matching Close logic
- Dashboard หลัก (ข้อมูลอื่นๆ)
