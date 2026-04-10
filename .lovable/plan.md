

## v6.45 — Fix: Broker TP ไม่ถูก Clear จาก Bound Orders เมื่อ Hedge Active

### สาเหตุ (Root Cause)

จากภาพ: มี BUY 4 orders (GM_INIT, GM_GL#1-3) + SELL 1 order (GM_HEDGE_D1) → hedge lock active

**ปัญหา**: `ClearBrokerTPSL()` มี guard `if(IsTicketBound(ticket)) continue;` (line 2120) ที่ **ข้าม** bound orders → TP ที่เคย set ไว้ก่อนหน้ายังค้างอยู่ → เมื่อราคาวิ่งชน TP → **broker ปิด bound orders ทันที** → hedge แตก

**Flow ที่ผิด:**
1. EA set broker TP = 5329.29 ให้ BUY orders (ก่อน hedge)
2. DD trigger → เปิด SELL hedge → `g_hedgeBalancedLock = true`
3. `SyncBrokerTPSL()` → detect hedge lock → `ClearBrokerTPSL()`
4. `ClearBrokerTPSL()` → skip bound orders (line 2120) → **TP 5329.29 ยังค้างอยู่**
5. ราคาวิ่งขึ้นชน 5329.29 → broker ปิด BUY orders → hedge แตก

### แผนแก้ไข — ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Version bump → v6.45

#### 2. ลบ `if(IsTicketBound(ticket)) continue;` ออกจาก `ClearBrokerTPSL()`

Bound orders **ต้อง** ถูก clear TP/SL เมื่อ hedge active — ไม่งั้น broker จะปิดก่อนที่ hedge recovery จะทำงาน

```text
// Line 2120 — REMOVE this line:
if(IsTicketBound(ticket)) continue;
```

ยังคง skip hedge orders (`IsHedgeComment`) เพราะ hedge orders จัดการ TP/SL แยก

#### 3. เพิ่ม Print log เมื่อ clear bound order TP

```text
Print("v6.45 ClearTP: Cleared bound order #", ticket, " TP=", curTP, "→0");
```

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic — ไม่แก้
- Trading Strategy Logic — ไม่แก้
- Core Module Logic — ไม่แก้
- SyncBrokerTPSL (set TP logic) — ไม่แก้ (ยังข้าม bound orders ตอน set TP ซึ่งถูกต้อง)
- Hedge recovery / Triple Gate / Matching Close — ไม่แก้
- Per-Order Trailing / DD trigger — ไม่แก้
- v6.37-v6.44 features — ไม่แก้

