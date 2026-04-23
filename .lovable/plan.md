

## v6.79 — Scheduled "Stuck-TP Scanner" สำหรับออเดอร์ที่ถูก Hedge-Lock

### ปัญหา
บางครั้งออเดอร์ที่ถูก hedge ปลด TP ไม่หมด (TP ค้างที่ broker) ทำให้ราคาวิ่งไปชน TP แล้วหลุดจากการ lock โดยไม่ตั้งใจ ระบบ `EnforceClearTPOnAllBound()` (v6.72) ทำงานทุก tick แต่ผู้ใช้ต้องการ scanner เสริมที่ยิงเป็นรอบเวลา (เช่น ทุก 5 นาที) เป็น safety net เพื่อไล่เก็บ TP ค้างของออเดอร์ที่ "ยังมีคู่ hedge lock อยู่จริง" โดยข้ามออเดอร์ที่กำลังถูก recover หรือออเดอร์ของ cycle ใหม่

### ไฟล์ที่จะแก้
- `public/docs/mql5/Gold_Miner_EA.mq5`

### สิ่งที่จะเพิ่ม

**1) Input ใหม่**
- `InpStuckTP_ScanEnable` (bool, default `true`) — เปิด/ปิด scanner
- `InpStuckTP_ScanIntervalMin` (int, default `5`) — รอบสแกน (นาที)
- `InpStuckTP_LogVerbose` (bool, default `true`) — log รายละเอียดทุกครั้งที่เคลียร์

**2) Helper ใหม่: `ScanAndClearStuckHedgeLockTP()`**
- เรียกใน `OnTick()` แบบ time-gated โดยตัวแปร `g_lastStuckTPScan` (เปรียบเทียบ `TimeCurrent() - g_lastStuckTPScan >= InpStuckTP_ScanIntervalMin*60`)
- วน `g_hedgeSets[]` ทุก slot ที่ `active==true`
- สำหรับแต่ละ `boundTickets[b]`:
  - **เงื่อนไขนับ (ต้องผ่านทั้งหมด)**:
    1. `PositionSelectByTicket(tk)` ผ่าน → ออเดอร์ยังมีชีวิต
    2. set นั้นยังมี hedge order ฝั่งตรงข้ามจริง (เช็คด้วย comment prefix เดิมของ set + ฝั่ง counter) — ยืนยันว่ายังมี **คู่ hedge lock อยู่จริง**
    3. `PositionGetDouble(POSITION_TP) != 0 || POSITION_SL != 0`
  - **เงื่อนไขข้าม (skip)**:
    - ออเดอร์อยู่ใน generation ที่กำลัง sequential recovery (`g_sequentialRecoveryActive && og == g_sequentialRecoveryGen`) — กำลังถูกกรีดแก้
    - ออเดอร์เป็น recovery seed ของ gen ที่กำลัง recover (`IsRecoverySeedTicket`)
    - ออเดอร์เป็น cycle ใหม่ (generation > `g_cycleGeneration` หรือ comment ไม่ตรงกับ set ใด — ใช้ `IsBoundTicketInAnyHedgeSet` เป็น final check) → ถ้าไม่ใช่ bound ของ set ที่ยังมี hedge counter → ข้าม
    - hedge set นั้นไม่มีออเดอร์ฝั่ง hedge ค้างแล้ว (กำลัง release/closing) → ข้าม
- ถ้าเข้าเงื่อนไข → `trade.PositionModify(tk, 0, 0)` + log: `v6.79 StuckTP-Scan: set#X ticket #Y TP=...→0 SL=...→0`
- จบรอบ → อัปเดต `g_lastStuckTPScan = TimeCurrent()` + log สรุป (เช็ค N tickets, เคลียร์ M)

**3) Dashboard**
- เพิ่มแถว `StuckTP Scan`: แสดง `OFF` หรือ `Every 5m | Next in 2m18s | Cleared: 3`

**4) Version bump**
- `#property version`, `#property description`, header block, `OnInit/OnDeinit` print, dashboard header → **v6.79**

### สิ่งที่ "ไม่เปลี่ยนแปลง"
- ไม่แก้ `OrderSend / trade.Buy / trade.Sell / trade.PositionClose`
- ไม่แก้ `EnforceClearTPOnAllBound()` (v6.72) ที่ทำงานทุก tick — scanner ใหม่เป็น **เสริม** ไม่ใช่แทน
- ไม่แก้ trading strategy / Grid / Recovery / DD threshold / Matching Close / Hedge Open Delay (v6.78) / NoReHedge (v6.74) / Cross-gen guard
- ไม่แก้ License / News / Time filter

### ผลลัพธ์ที่คาดหวัง
- ทุก 5 นาที (ตั้งได้) ระบบไล่ scan ออเดอร์ทุกตัวที่มีคู่ hedge lock อยู่จริง → เคลียร์ TP/SL ที่ค้างให้เป็น 0
- ออเดอร์ที่กำลังถูก recovery (กรีดแก้) จะไม่ถูกแตะ → ไม่กระทบ recovery flow
- ออเดอร์ของ cycle ใหม่ที่ไม่มี hedge counter จะไม่ถูกแตะ → ไม่กระทบ TP ปกติ
- ลดโอกาสราคาวิ่งชน TP ค้างแล้ว lock หลุดโดยไม่ตั้งใจ

### ความเสี่ยง & Mitigation
- **Risk:** scanner ไปเคลียร์ TP ของออเดอร์ที่ user ตั้งเองตั้งใจ
- **Mitigation:** scan เฉพาะ tickets ที่อยู่ใน `g_hedgeSets[].boundTickets[]` (ระบบ bind เอง) เท่านั้น — ไม่แตะออเดอร์นอกระบบ
- **Risk:** Interval สั้นเกิน → log spam
- **Mitigation:** default 5 นาที + toggle `LogVerbose` ปิดได้

