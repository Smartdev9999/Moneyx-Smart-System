---
name: Gold Miner EA v6.87 — Grid Refill Fix (Breakeven-only triggers)
description: v6.87 fixes Grid Refill not firing when only Breakeven (no Trailing) is enabled. Removes over-strict generation-prefix and IsTicketBound filters in RefillScanAndDetectCloses so all generations + bound orders are tracked. Adds genPrefix field to GridRefillSlot so re-opens use the original generation comment. Adds OnTradeTransaction fallback (RefillCaptureFromHistory) for live mode when tick-based diff misses a close. Adds rich diagnostic Print logs.
type: feature
---

# Gold Miner EA v6.87 — Grid Refill Fix

ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

## ปัญหาที่แก้ (จาก v6.86)
User เปิดเฉพาะ Breakeven (`InpEnableBreakeven=true`) โดยไม่เปิด Trailing → BE ปิดออเดอร์ผ่าน broker SL → แต่ refill ไม่ทำงาน

### Root causes ใน v6.86
1. **`StringFind(c, genPrefix + "_") != 0`** — track เฉพาะ generation ปัจจุบันเท่านั้น → ออเดอร์ gen เก่าไม่เคยเข้า tracker → diff ไม่เห็น close
2. **`IsTicketBound(tk)` filter** — ออเดอร์ที่ bound กับ hedge ถูก skip แม้ BE ยังปิดได้
3. ไม่มี fallback path เมื่อ tick-based diff พลาด

## การแก้ไข
1. **`RefillScanAndDetectCloses()`**: ลบ filter `genPrefix` + `IsTicketBound` → track ทุก GL/GP ของ EA นี้ (ทุก gen, รวม bound)
2. **`GridRefillSlot.genPrefix`** (field ใหม่): เก็บ generation เดิมจาก comment (`GM`, `GM2`, ...) → ใช้ตอน refill เพื่อรักษา generation
3. **`TryRefillGridSlot()`**: ใช้ `slot.genPrefix` แทน `GetCommentPrefix()` ในการสร้าง comment ใหม่
4. **`OnTradeTransaction`**: เพิ่ม fallback `RefillCaptureFromHistory(posId)` เมื่อ deal เป็น `DEAL_REASON_SL/TP/EXPERT` (live mode เท่านั้น — tester ไม่ใช้ branch นี้)
5. **Diagnostic logs**: `v6.87 RefillSlot ADD`, `v6.87 RefillFire`, `v6.87 RefillFire FAILED` (rate-limited 10s)

## ไม่กระทบ
- ไม่แตะ Order Execution (`trade.*`)
- ไม่แตะ BE/Trailing math, Grid entry, TP/SL, OpenOrder math
- ไม่แตะ Hedge / Triple-Gate / DD% / Squeeze / Accumulate / Recovery / Match Close
- ไม่แตะ License / News / Sync logic เดิม
- Default `EnableGridRefill=false` → backward compat 100%
