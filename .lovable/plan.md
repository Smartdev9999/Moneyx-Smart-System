

## v6.80 — Stuck-Hedge Scanner (วินิจฉัย + Auto-Heal hedge ที่ไม่ขยับ)

### ปัญหาจากภาพ
ภาพแสดง `Hedge #1: BUY 0.55L PnL:$1703.90 B:5` พร้อม `Gate T:DD% Cy:Ready Z:OUT OK 3097pts` — แปลว่าราคาผ่าน Triple Gate (Cycle ready, Zone OUT, Distance OK) และ hedge กำไรอยู่ +$1703 แต่ **set ไม่ release / ไม่ match / ไม่กรีดต่อ** ค้างนิ่งอยู่อย่างนั้น

สาเหตุที่เป็นไปได้ (จากการอ่านโค้ด `ManageHedgeSets`):
1. **FIFO Block** — มี set อื่นเก่ากว่า (oldest) ที่ยังไม่จบ → set นี้ถูก defer
2. **Owner Lock** — `g_sequentialRecoveryActive = true` ของ gen อื่น → block ทุก set ที่ไม่ใช่ oldest
3. **Unlock Delay** — `IsSequentialUnlockDelayActive()` ค้าง
4. **Stale flag** — `matchingDone = true` ค้าง (ปกติถูก reset ทุก tick v6.64 แล้ว แต่เป็นไปได้ในบาง path)
5. **seenExpansionSinceHedge ไม่ trigger** — แม้ dashboard โชว์ Cy:Ready แต่ flag จริงยังไม่ติด
6. **Owner gen ไม่มีออเดอร์เหลือแล้ว** แต่ `ClearSequentialRecoveryOwner` ไม่ได้ถูกเรียก

### ไฟล์ที่จะแก้
- `public/docs/mql5/Gold_Miner_EA.mq5`

### สิ่งที่จะเพิ่ม

**1) Inputs ใหม่ (อยู่หมวดเดียวกับ v6.79 StuckTP Scanner)**
- `InpStuckHedge_ScanEnable` (bool, default `true`) — เปิด scanner
- `InpStuckHedge_ScanIntervalMin` (int, default `5`) — รอบสแกน (นาที) — ใช้ค่าเดียวกับ StuckTP ได้/แยกได้
- `InpStuckHedge_StuckThresholdMin` (int, default `15`) — set ต้องนิ่ง ≥ N นาที (ไม่มี action ใดเกิดขึ้น) ถึงจะถือว่า "ตกหล่น"
- `InpStuckHedge_AutoHeal` (bool, default `true`) — เปิด auto-heal (clear stale flags ถ้าตรวจพบ)
- `InpStuckHedge_LogVerbose` (bool, default `true`)

**2) State ใหม่ใน `HedgeSet` struct**
- `datetime lastActionTime` — อัปเดตทุกครั้งที่ set ทำ action (matching, avg TP, partial, grid step) → ใช้วัด "นิ่งไปกี่นาทีแล้ว"

**3) Helper ใหม่: `ScanAndDiagnoseStuckHedgeSets()`**
- เรียกใน `OnTick()` time-gated เหมือน StuckTP scanner
- วน `g_hedgeSets[]` ที่ active:
  - คำนวณ `idleSec = TimeCurrent() - lastActionTime`
  - ถ้า `idleSec < InpStuckHedge_StuckThresholdMin*60` → ข้าม
  - ประเมินสภาพ set:
    - `gateOK = IsHedgeCloseAllowed(h)`
    - `oldestIdx = FindOldestActiveHedgeSet()`
    - `isOldest = (h == oldestIdx)`
    - `ownerActive = g_sequentialRecoveryActive`
    - `ownerOrdersLeft = ownerActive ? CountSequentialOwnerOrders(g_sequentialRecoveryGen) : 0`
    - `unlockDelay = IsSequentialUnlockDelayActive()`
    - `hedgePnL` ปัจจุบัน
  - **จำแนก blocker** แล้ว log:
    - `STUCK#1 (FIFO): Set#3 idle 22m | gate=PASS pnl=+$1703 | blocked by oldest Set#1`
    - `STUCK#2 (OWNER): Set#3 | owner=Gen2 ordersLeft=0 → STALE OWNER`
    - `STUCK#3 (UNLOCK_DELAY): remain 47s`
    - `STUCK#4 (GATE_FAIL): seenExp=false zone=IN distPts=200`
    - `STUCK#5 (NO_ACTION_CLEAR): gate=PASS isOldest=Y ownerActive=N → matchingDone stuck?`
  - **Auto-Heal (ถ้า `InpStuckHedge_AutoHeal=true`)**:
    - Case `STALE OWNER` (`ownerActive && ownerOrdersLeft==0`) → เรียก `ClearSequentialRecoveryOwner("v6.80 stuck-heal: owner ordersLeft=0")`
    - Case `NO_ACTION_CLEAR` (gate ผ่าน, isOldest, ownerInactive, idle ≥ threshold) → reset `matchingDone=false` + `seenExpansionSinceHedge=true` (force re-eval)
    - Case `UNLOCK_DELAY` ที่ค้างเกิน 2× threshold → log warning (ไม่ heal — เพราะอาจจะ user ตั้งจริง)
    - Case `FIFO BLOCK` → ไม่ heal (ทำงานตามดีไซน์ — แค่ log ให้ user รู้)
  - อัปเดต `lastActionTime = TimeCurrent()` ทุกที่ที่ set ทำ action จริง (เพิ่ม hook 4–5 จุด: `ManageHedgeMatchingClose`, `ManageHedgeBoundAvgTP`, `ManageHedgePartialClose`, `ManageHedgeGridMode`, `OpenDDHedge`/`OpenHedgeOrder` ตอน bind)

**4) Dashboard**
- เพิ่มแถว `StuckHedge Scan`: `Every 5m | Threshold 15m | Next 2m18s | Detected: 1 | Healed: 0` (หรือ `OFF`)
- เมื่อ scan รอบนั้นเจอ stuck set → แถวเตือน `⚠ Stuck Set#3 idle 22m (FIFO)` (สีส้ม)

**5) Version bump → v6.80**
- `#property version`, `#property description`, header, `OnInit` print, dashboard header

### สิ่งที่ "ไม่เปลี่ยนแปลง"
- ไม่แก้ `OrderSend / trade.Buy / trade.Sell / trade.PositionClose`
- ไม่แก้ `ManageHedgeMatchingClose / ManageHedgeBoundAvgTP / ManageHedgePartialClose / ManageHedgeGridMode` ตรรกะภายใน — แค่เพิ่ม `lastActionTime = TimeCurrent()` 1 บรรทัดในแต่ละฟังก์ชัน
- ไม่แก้ `IsHedgeCloseAllowed / IsSequentialRecoveryComplete / FindOldestActiveHedgeSet`
- ไม่แก้ Triple Gate / FIFO / Owner / Unlock Delay logic — scanner เพียงวินิจฉัยและล้าง stale flag เท่านั้น
- ไม่แก้ DD threshold / Hedge Open Delay (v6.78) / NoReHedge (v6.74) / StuckTP Scanner (v6.79)
- ไม่แก้ License / News / Time filter

### ผลลัพธ์ที่คาดหวัง
- ทุก 5 นาที (ตั้งได้) ระบบไล่ตรวจ set ที่ "นิ่งเกิน 15 นาที" → log ระบุชัดว่าติดเพราะอะไร (FIFO / Owner / Gate / Stale)
- `STALE OWNER` (ออเดอร์ owner gen ปิดไปแล้วแต่ flag ค้าง) → auto-clear → set ถัดไปได้ทำงานทันที
- `NO_ACTION_CLEAR` (gate ผ่านแล้วแต่ matchingDone ค้าง) → reset → set พร้อม match รอบถัดไป
- `FIFO BLOCK` → log ให้ user เห็นว่า set อื่นเก่ากว่ายังต้องจบก่อน (ตามดีไซน์)
- ในเคสภาพที่แชร์มา → จะเห็น log บอกชัดว่าทำไม Hedge #1 ที่ +$1703 ไม่ release

### ความเสี่ยง & Mitigation
- **Risk:** Auto-heal ล้าง flag ผิดจังหวะ → กระทบ matching cycle
- **Mitigation:** heal เฉพาะกรณีที่ idle ≥ threshold (default 15 นาที) + ปิดได้ด้วย `InpStuckHedge_AutoHeal=false` (เหลือแค่ log)
- **Risk:** log spam ถ้า threshold ต่ำเกิน
- **Mitigation:** default 15 นาที + LogVerbose toggle + log สรุปครั้งเดียวต่อ scan รอบ
- **Risk:** `lastActionTime` ไม่ถูก set ตอน restart
- **Mitigation:** init = `TimeCurrent()` ตอน hedge เปิด/ตอน OnInit detect set ที่ active อยู่แล้ว

