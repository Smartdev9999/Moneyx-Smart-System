

## v6.73 — Same-Side Older-Gen Guard + Owner Skip-Forward + No-Re-Hedge Released Tickets

### วินิจฉัยจากภาพ image-963 / image-964 + ข้อกำหนดใหม่

**อาการ 1 (image-964):** ฝั่ง buy GM1 ติด hedge `GM_Hedge_E1` (1.04 lot lock) แต่ฝั่ง sell ยังมี **GM1_INIT (ticket 206)** ลอย ไม่ติด hedge และมี TP ปกติ → ระบบกลับเปิด **GM2_INIT sell (ticket 224)** ทับลงไปอีก → GM1 + GM2 ฝั่ง sell ปนกัน

**อาการ 2:** เมื่อ hedge GM1 ปลด ระบบยังทำงานต่อใน GM1 sell แทนที่จะข้ามไป GM2

**อาการ 3 (ใหม่):** ออเดอร์ที่เคยถูก bind เข้า hedge set แล้วถูก **release** ออกมาเพราะเงื่อนไขปลดล็อคถึงเกณฑ์ — ถ้าราคาวิ่งกลับลึกอีกครั้ง ระบบเปิด hedge set ใหม่มา **lock ตั๋วเดิมซ้ำ** → วงจร hedge ไม่จบสักที ควรปล่อยให้ "กรีดแก้ต่อ" (Grid Loss/Profit) จัดการจนปิดเอง

### Root Cause

1. `OpenOrder()` ไม่มี guard เช็คว่ามีออเดอร์ปกติของ gen ก่อนหน้าฝั่งเดียวกันที่ยังลอยและปิดเองได้ (memory `cross-gen-init-guard-v6-76` ถูก plan แต่ยังไม่ได้ลงโค้ดจริง — current = v6.72)
2. หลัง hedge release ไม่มี logic ย้าย sequential-recovery owner จาก gen เก่าไป gen ใหม่
3. มี `AddPrevHedgedTicket / SaveBoundTicketsToPrevHedged` อยู่แล้ว (ใช้กับ DD-trigger) แต่ตอนเปิด hedge **logic เลือก side ไม่ได้ exclude prev-hedged** → ตั๋วเดิมถูก rebind ซ้ำ

### แผนแก้ v6.73 (Fix-only)

ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1) Helper `CountFreeOlderGenOnSide(side)`
นับออเดอร์ปกติฝั่งนั้นที่ `gen >= 1 && gen < g_cycleGeneration`, ไม่ใช่ hedge comment, ไม่ `IsTicketBound`, ไม่ใช่ owner-gen ที่ถูก lock

#### 2) Cross-gen INIT Guard ใน `OpenOrder` + `OpenOrderTF`
ก่อน `trade.Buy/Sell`: ถ้า `comment` มี `_INIT` และ `!IsHedgeComment` และ `CountFreeOlderGenOnSide(psd) > 0` → return false + log throttle 30s
```
v6.73 INIT BLOCKED: GM2_INIT(sell) — 1 older-gen sell still free, must self-close first
```

#### 3) Owner-Gen Skip-Forward
Helper `AdvanceSequentialOwnerIfFlat()` เรียกใน `OnTick` ต่อจาก `ManageRecoveryOwnerAvgTP`:
- ถ้า `g_sequentialRecoveryActive` และ `IsSequentialRecoveryComplete()` = true:
  - หา `nextGen` = MIN gen ที่ยังมีออเดอร์ปกติเหลือ (>old)
  - ถ้ามี hedge set ที่ `boundGeneration == nextGen` → `ClearSequentialRecoveryOwner()` แล้ว `SetSequentialRecoveryOwner(slot, nextGen)`
  - ถ้าไม่มี hedge set แต่มีออเดอร์ปกติ → `ClearSequentialRecoveryOwner()` ปล่อย flow ปกติทำงาน
- gate 1 วินาที + idempotent

#### 4) **No-Re-Hedge ของ Released Tickets** (ฟีเจอร์ใหม่หลัก)

**4.1 ขยาย prev-hedged tracking:**
- `AddPrevHedgedTicket` ถูกเรียกอยู่แล้วเฉพาะ DD-trigger — เพิ่มให้บันทึก **ทุกตั๋วที่ถูก release/closed จาก hedge set ทุกประเภท** (matching close, partial close, manual unlock) ผ่าน helper ใหม่ `MarkTicketAsPrevHedged(ticket)` เรียกในจุดที่ตั๋วหลุด bind:
  - `ManageHedgeMatchingClose` (จุดที่ partial-close ตั๋ว bound)
  - `ReleaseHedgeSet` / unlock paths
  - Triple Gate exit paths

**4.2 Helper `CountUnboundOrders` filter:**
เพิ่มพารามิเตอร์ใหม่ `excludePrevHedged = true` (default true ในเส้นทางเปิด hedge ใหม่)
- เมื่อ true → ตั๋วที่ `IsPrevHedgedTicket(ticket)` ถูก **ตัดออกจากการนับ** lots/PL/count
- ผลลัพธ์: side ที่มีแต่ตั๋ว released → `counterCount=0` → DD hedge / Triple Gate / volatility hedge **จะไม่เปิด hedge ใหม่** มา lock ตั๋วเดิมอีก

**4.3 ปล่อยให้ Grid system จัดการต่อ:**
- ตั๋ว released ยังถูกนับใน `CountPositions / NormalOrderCount` (current-gen filter เดิม) → Grid Loss/Profit ยังทำงานปกติ
- Avg TP / per-order trailing / breakeven ทำงานตามปกติ — ไม่ถูก guard ใหม่บล็อก
- ถ้าราคาเด้งกลับ → กรีดปกติปิดทำกำไร; ถ้าวิ่งสวน → grid loss กระทบ DD แต่ไม่เปิด hedge ใหม่ — ตามที่ user ต้องการ "ใช้กรีดแก้ต่อให้จบ"

**4.4 Auto-clear prev-hedged เมื่อตั๋วปิดจริง:**
ใน `OnTick` (gate 5s) วน `g_prevHedgedTickets[]` — ถ้า `!PositionSelectByTicket(t)` → ลบออกจาก list เพื่อกัน list บวมและรองรับ cycle reset

#### 5) Toggles
- `input bool InpCrossGen_InitGuard      = true;`
- `input bool InpOwnerAutoAdvance        = true;`
- `input bool InpHedge_NoReHedgeReleased = true;`  // ปิดได้ถ้าอยากกลับพฤติกรรมเดิม

#### 6) Dashboard
- แถว "ReEntryGuard": `LegacyB={n} LegacyS={m} | INIT={ALLOW|BLOCK}`
- แถว "Released": `Tracked={k}` — จำนวนตั๋วที่ถูก mark ห้าม re-hedge
- Sequential Owner row: "Gen{x} → next Gen{y}" ตอน advance

#### 7) Version bump → v6.73
- `#property version "6.73"`
- `#property description "Gold Miner EA v6.73 - v6.72 + Cross-gen INIT guard + Owner auto skip-forward + No-Re-Hedge released tickets (let grid recover)"`
- Header block, OnInit/OnDeinit prints, dashboard headers (ทั้ง 3 mode)

### สิ่งที่ไม่เปลี่ยนแปลง (กฎเหล็ก)
- ไม่แตะ `trade.Buy / trade.Sell / trade.PositionClose / OrderSend / OrderModify`
- ไม่แก้ logic เปิด GL/GP / TP-SL sync (v6.72) / Triple Gate / Strict FIFO / lot sizing / matching close pool / Bollinger filter / candle confirm / DD threshold
- ไม่แก้ License / News / Time filter
- ไม่แก้ `CountPositions / NormalOrderCount / CountSequentialOwnerOrders` — เพิ่ม helper ใหม่อย่างเดียว
- `prevHedgedTickets[]` array + `IsPrevHedgedTicket / AddPrevHedgedTicket / ClearPrevHedgedTickets` ของเดิมยังใช้ครบ — แค่ขยาย callsite และเพิ่ม filter param

### ผลลัพธ์ที่คาดหวัง
- **อาการ 1 หาย:** มี GM1_INIT sell ลอย → ระบบไม่เปิด GM2_INIT sell ทับ
- **อาการ 2 หาย:** GM1 ปิดครบ → owner ข้าม GM2 ทันที
- **อาการ 3 หาย:** ตั๋วที่เคยติด hedge แล้วถูก release → ราคาวิ่งกลับลึกใหม่จะ **ไม่ถูก lock ซ้ำ** — Grid Loss/Profit + Avg TP จัดการปิดเอง ตามที่ user ระบุ "ใช้กรีดแก้ต่อให้จบ"
- เมื่อบัญชี flat → cycle reset + clear prev-hedged ปกติ

### ความเสี่ยง & Mitigation
- **Risk:** ตั๋ว released ขาดทุนหนักโดยไม่มี hedge ป้องกัน → DD ยาว
- **Mitigation:** Balance Guard, Max Grid Trailing, Daily Target ยังทำงานครบ + toggle `InpHedge_NoReHedgeReleased=false` เปิด hedge ซ้ำได้ตามเดิม
- **Risk:** prev-hedged list บวมเมื่อ cycle ยาว
- **Mitigation:** auto-clear ทุก 5s ตัวที่ ticket ปิดจริง + clear ตอน cycle reset (`TryResetCycleStateIfFlat`) ที่มีอยู่แล้ว
- **Risk:** Owner advance race กับ matching-close
- **Mitigation:** gate 1s + เช็ค `IsSequentialRecoveryComplete()` ก่อน + ใช้ฟังก์ชันเดิม

