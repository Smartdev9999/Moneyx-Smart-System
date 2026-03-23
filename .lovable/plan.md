

## Fix: Orphan Hedge Grid Orders + Recovery System — Gold Miner SQ EA (v5.6 → v5.7)

### สิ่งที่แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. เพิ่ม `CloseAllHedgeGridOrders(int idx)` — ปิด GM_HG grid orders ก่อน deactivate
- เรียกก่อนทุกจุดที่ set ถูก deactivate (6 จุด)
- ManageHedgeMatchingClose (matched + no matchable), ManageHedgeBoundAvgTP, ManageHedgePartialClose, ManageHedgeSets (external close), ManageHedgeGridMode (full recovery)

#### 2. เพิ่ม `RecoverHedgeSets()` — กู้ set จาก comment ตอน OnInit
- สแกน GM_HEDGE_N → rebuild active set
- Rebind counter-side unbound orders
- ตรวจ orphan GM_HG → ปิดทิ้ง
- รองรับ EA restart/TF change/crash

#### 3. เพิ่ม `DetectOrphanHedgeOrders()` — แจ้งเตือนบน Dashboard
- ทุก tick สแกน GM_HG ที่ไม่มี active set ดูแล
- Dashboard แสดง "⚠ ORPHAN GRID ORDERS DETECTED" สีแดง
- ไม่บล็อกการเทรด

#### 4. Version bump: v5.6 → v5.7

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter, Time filter, Data sync)
- ManageHedgeMatchingClose, ManageHedgePartialClose, ManageHedgeBoundAvgTP logic (เพิ่มแค่ cleanup ก่อน deactivate)
- ManageHedgeGridMode logic
- Bound ticket management, Lot Cap
- Accumulate/Drawdown close logic
