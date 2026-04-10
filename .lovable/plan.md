

## v6.46 — Fix: Bound Orders TP/SL ไม่ถูก Clear เพราะ Trigger ไม่เคย Active

### หลักการ

1. **Root Cause**: `SyncBrokerTPSL()` ใช้ `g_hedgeBalancedLock` เป็น trigger แต่ `ManageHedgeSets()` บังคับ reset เป็น `false` ทุก tick → `ClearBrokerTPSL()` ไม่เคยถูกเรียก
2. **New Helper**: เพิ่ม `HasActiveBoundHedgeSet()` — loop `g_hedgeSets[]` ตรวจ `active && boundTicketCount > 0` โดยตรง
3. **Fix Trigger**: เปลี่ยน `SyncBrokerTPSL()`, `ManageTPSL()`, `ManageTPSL_TF()`, `ManageMatchingClose()` จาก `g_hedgeBalancedLock && g_hedgeSetCount > 0` → `HasActiveBoundHedgeSet()`
4. **Precise Clear**: `ClearBrokerTPSL()` clear เฉพาะ bound orders (ใส่ `IsTicketBound` กลับเป็น **require** แทน skip)
5. **Version bump**: v6.45 → v6.46

### ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic — ไม่แก้
- Trading Strategy Logic — ไม่แก้
- Core Module Logic — ไม่แก้
- SyncBrokerTPSL TP/SL calculation — ไม่แก้
- Hedge recovery / Triple Gate / Matching Close logic — ไม่แก้
- Per-Order Trailing / DD trigger — ไม่แก้
- v6.37-v6.45 features — ไม่แก้
