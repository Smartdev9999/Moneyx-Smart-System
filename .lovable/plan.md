

## Fix: Orphan Hedge Grid Orders + Recovery System — Gold Miner SQ EA (v5.6 → v5.7)

### วิเคราะห์ปัญหา

จากรูป: มี GM_HG1_GL1 ถึง GL7 ค้างอยู่ด้านล่างโดยไม่มี Hedge Set ดูแล

**สาเหตุ:** เมื่อ `ManageHedgeMatchingClose()` ปิด main hedge (กำไร) + deactivate set → แต่ไม่ได้เช็คว่ามี GM_HG grid orders ยังเปิดอยู่ → orders เหล่านี้กลายเป็น orphan ไม่มีใครจัดการ

เกิดในสถานการณ์:
1. Bound orders หมด → เข้า Grid Mode → เปิด GM_HG orders
2. ราคากลับตัว → สถานะเป็น Normal → main hedge กำไร → `ManageHedgeMatchingClose` ปิด hedge + deactivate
3. **แต่ GM_HG orders ยังอยู่** → ไม่มี set ดูแล → orphan ตลอดไป

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. เพิ่ม Helper: `CloseAllHedgeGridOrders(int idx)`

ก่อน deactivate set ใดๆ → ปิด GM_HG grid orders ทั้งหมดของ set นั้นก่อน:
```text
void CloseAllHedgeGridOrders(int idx)
   สแกน positions → ปิดทุก order ที่ comment มี "GM_HG" + (idx+1) prefix
```

#### 2. แก้ทุกจุดที่ deactivate set → เรียก `CloseAllHedgeGridOrders` ก่อน

| จุดที่ deactivate | Line | สิ่งที่เพิ่ม |
|---|---|---|
| `ManageHedgeMatchingClose` (matched losses) | 6403 | `CloseAllHedgeGridOrders(idx);` ก่อน deactivate |
| `ManageHedgeMatchingClose` (no matchable) | 6419 | `CloseAllHedgeGridOrders(idx);` ก่อน deactivate |
| `ManageHedgeBoundAvgTP` (fully closed) | 6283 | `CloseAllHedgeGridOrders(idx);` ก่อน deactivate |
| `ManageHedgePartialClose` (fully closed) | 6533 | `CloseAllHedgeGridOrders(idx);` ก่อน deactivate |
| `ManageHedgeSets` (hedge gone externally) | 6114 | `CloseAllHedgeGridOrders(h);` ก่อน deactivate |

#### 3. เพิ่ม `RecoverHedgeSets()` — กู้คืน set จาก comment ตอน init

เรียกใน `OnInit()` หลัง Hedging Init:
```text
void RecoverHedgeSets()
  1. สแกน positions หา comment "GM_HEDGE_N" → rebuild set (hedgeTicket, hedgeSide, hedgeLots)
  2. สแกน positions หา "GM_HG" ที่ไม่มี main hedge → ปิดทิ้ง (orphan cleanup)
  3. สแกน bound orders → rebind ด้วย counter-side unbound orders ที่มีอยู่
  4. Print สรุปว่า recover ได้กี่ set
```

วิธีนี้รองรับ: EA restart, TF change, crash recovery

#### 4. เพิ่ม `DetectOrphanHedgeOrders()` — Dashboard Warning

ทุก tick ใน `ManageHedgeSets()`: สแกนหา GM_HG orders ที่ไม่ตรงกับ active set ใดๆ
- ถ้าพบ → `g_hedgeOrphanWarning = true` + Print warning
- Dashboard แสดง "⚠ ORPHAN" สีแดง ใน Hedge section

**ไม่บล็อกการเทรด** — แค่แจ้งเตือน

#### 5. Version bump: v5.6 → v5.7

### Flow สรุป

```text
EA Init:
  → RecoverHedgeSets() → กู้ set จาก comment + ปิด orphan grid orders

ทุก tick:
  → ManageHedgeSets() → DetectOrphanHedgeOrders() → warning ถ้าพบ

Deactivate set (ทุกสาเหตุ):
  → CloseAllHedgeGridOrders(idx) → ปิด GM_HG ทั้งหมดก่อน
  → deactivate set ตามปกติ
```

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter, Time filter, Data sync)
- ManageHedgeMatchingClose, ManageHedgePartialClose, ManageHedgeBoundAvgTP logic (เพิ่มแค่ cleanup ก่อน deactivate)
- ManageHedgeGridMode logic
- Bound ticket management, Lot Cap
- Accumulate/Drawdown close logic

