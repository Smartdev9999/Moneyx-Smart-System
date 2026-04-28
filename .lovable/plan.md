# Gold Miner EA v6.87 — Fix Grid Refill ไม่ทำงานเมื่อเปิดเฉพาะ Breakeven

## ปัญหาที่พบ

จากการตรวจสอบโค้ด `RefillScanAndDetectCloses()` (บรรทัด 3655–3735) มี **3 bugs** ที่ทำให้ refill ไม่ trigger เมื่อ Breakeven ปิดออเดอร์:

### Bug #1 — Generation prefix filter เข้มเกินไป (บรรทัด 3672)
```cpp
if(StringFind(c, genPrefix + "_") != 0) continue;
```
`GetCommentPrefix()` คืนเฉพาะ generation **ปัจจุบัน** (เช่น `GM2`) → ออเดอร์ generation เก่า/orphan ไม่ถูก track → ถ้า BE ปิดออเดอร์เก่าจะตรวจ "หายไป" ไม่ได้

### Bug #2 — กรอง `IsTicketBound` ทิ้ง (บรรทัด 3671)
ออเดอร์ที่ bound กับ hedge ยังสามารถ trigger BE ได้ (TP/SL ของมันถูก clear/restore ตามจังหวะ) → ถูก skip ออกจาก tracker → diff ไม่เห็น close

### Bug #3 — Tracker จะรีเซ็ตทุก tick ที่ EA หยุดก่อน Sync
`g_trackedTickets[]` rebuild ทุก tick แบบไม่บันทึกประวัติ → ถ้า BE ปิดในช่วง tick เดียวกับที่ EA ข้าม `RefillScanAndDetectCloses()` (เช่น `g_eaStopped`, license fail) → snapshot หาย → diff หาว่า ticket "หายไป" ไม่เจอเพราะ snapshot ก่อนหน้าก็ไม่มี

นอกจากนี้ยังเจอว่า log ไม่แสดง `v6.86 RefillSlot:` เลย ยืนยันว่า detection step ไม่เคย fire

## แผนแก้ไข v6.87

### 1. ขยายขอบเขต Tracker ให้ครอบคลุม
ใน `RefillScanAndDetectCloses()`:
- **ลบ** filter `if(StringFind(c, genPrefix + "_") != 0)` → track ทุก GL/GP ทุก generation ของ EA นี้ (เทียบจาก MagicNumber + comment ขึ้นต้น `GM`)
- **ลบ** filter `if(IsTicketBound(tk)) continue;` → track ออเดอร์ที่ bound ด้วย เพราะ BE/Trailing ยังสามารถปิดได้
- เพิ่ม `genPrefix` field ใน `GridRefillSlot` เพื่อจำว่าเป็นของ gen ไหน → ตอน refill จะใช้ comment เดิม (gen เดิม) แทนที่จะใช้ gen ปัจจุบัน

### 2. เพิ่ม Hook ใน OnTradeTransaction (สำรอง)
ใช้ `OnTradeTransaction` ดักจังหวะ `TRADE_TRANSACTION_DEAL_ADD` ที่ deal เป็น `DEAL_REASON_SL` (broker SL hit) → เป็น secondary capture path เผื่อ tick-based diff พลาด

### 3. Hook ใน TryRefillGridSlot
- ใช้ `slot.genPrefix` แทน `GetCommentPrefix()` ในการสร้าง comment ใหม่ (เคารพ generation เดิม)
- ผ่อน `if(g_newOrderBlocked) return false;` → log เหตุผลที่ block แทนเงียบ

### 4. Diagnostic Logs
- Print เมื่อ track ครั้งแรก (`v6.87 RefillTrack: #ticket added`)
- Print เมื่อ slot ถูก reject ด้วย overlap / out-of-tolerance (rate-limited)
- Print เมื่อ `OpenOrder()` คืน false พร้อมเหตุผล (BB filter / candle / max orders)

### 5. Versioning
- v6.86 → **v6.87**
- อัปเดต `#property version`, `#property description`, header comment, OnInit/Deinit log, Dashboard headerVersion

## สิ่งที่ไม่เปลี่ยนแปลง (ตามกฎเหล็ก)
- ไม่แตะ Order Execution: `trade.Buy/Sell/PositionClose/PositionModify`
- ไม่แตะ Strategy Logic: SMA/Grid entry/TP/SL/Breakeven/Trailing math
- ไม่แตะ License / News / Time filter / Sync
- ไม่แตะ Hedge / Triple-Gate / DD% / Squeeze / Accumulate / Recovery / Match Close
- ไม่แตะ `ManagePerOrderTrailing()`, `ManageTrailingStop()`, `OpenOrder()` math
- Default `EnableGridRefill=false` → backward compat 100%

## ไฟล์ที่แก้
- `public/docs/mql5/Gold_Miner_EA.mq5`
- `.lovable/memory/trading/gold-miner-ea/grid-refill-fix-v6-87.md` (memory ใหม่)
- `.lovable/memory/index.md` (เพิ่ม reference)
- `.lovable/plan.md`

อนุมัติเพื่อให้ผมลงมือแก้ได้เลยครับ
