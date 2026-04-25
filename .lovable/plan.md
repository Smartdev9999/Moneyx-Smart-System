## Golden2 EA v2.7.8 — Force-Close Unhedged Opposite Side on Hedge Lock

ไฟล์: `public/docs/mql5/Golden2_EA.mq5`

### ปัญหา
จาก log: `G2 hold G2->G3 ... blkBUY=2 blkSELL=12 hedgeBuy=13 hedgeSell=0 plBUY=+270 plSELL=-13927`
- ฝั่ง SELL ติดลบ → ถูก hedge ด้วย BUY 13 ไม้ (locked OK)
- ฝั่ง BUY มี main 2 ไม้ที่เปิดในกรุ๊ปเดียวกัน **ไม่มี hedge SELL คุม**
- ทำให้ G3 ออกไม่ได้ และยังเสี่ยงทำให้ hedge ไม่สมบูรณ์

User ต้องการ: **เมื่อกรุ๊ปใดถูก hedge-lock ฝั่งใดฝั่งหนึ่ง → ปิด main ฝั่งตรงข้ามที่ไม่ matching ทิ้งทันที** (ไม่สนกำไร/ขาดทุน) เพื่อให้ hedge สมบูรณ์ และระบบไป G ใหม่ได้

### สิ่งที่ทำ

**1. Input ใหม่ (default ON)**
```cpp
input group   "=== Hedge: Force-Close Opposite Unhedged ==="
input bool    InpHedge_ForceCloseOppUnhedged   = true;  // [v2.7.8] เมื่อกรุ๊ปถูก hedge-lock ฝั่งใดฝั่งหนึ่ง ปิด main ฝั่งตรงข้ามที่ไม่ถูก hedge ทิ้งทันที
input int     InpHedge_ForceCloseDelaySec      = 3;     // [v2.7.8] หน่วงก่อนปิด (กัน race condition ตอน hedge เพิ่งเปิด)
```

**2. ฟังก์ชันใหม่ `ForceCloseUnhedgedOppositeSide(int g)`**
- เงื่อนไขทำงาน: `InpHedge_ForceCloseOppUnhedged==true` AND กรุ๊ป g มี hedge position อย่างน้อย 1 ไม้
- ตรวจ "ฝั่งที่ถูก hedge": ฝั่งที่มี hedge ฝั่งตรงข้ามคุม
  - ถ้า `CountGroupPositions(g, 1, 1) > 0` (hedge SELL ทำงาน) → main BUY ถูก lock → ฝั่งตรงข้ามที่ต้องปิด = main SELL (แต่ปกติ SELL ไม่มีในกรณีนี้)
  - ถ้า `CountGroupPositions(g, 0, 1) > 0` (hedge BUY ทำงาน) → main SELL ถูก lock → **ฝั่งตรงข้ามที่ต้องปิด = main BUY ที่เหลือใน G เดียวกัน**
- ลูปปิด `trade.PositionClose(ticket)` เฉพาะ main (`hd==false`) ฝั่งตรงข้าม + `tag != "IN"` ไม่บังคับ (ปิดทุกแบบ GL/GP/IN)
- **ไม่แตะ hedge positions / ไม่แตะ pendings** (pending hedge frame ที่รอ activate และ pending IN/GL ฝั่งตรงข้ามถูกจัดการโดย v2.3 `DeleteLeftoverInitialPendingsAfterHedge` อยู่แล้ว)
- log throttle ต่อ ticket ปิด

**3. Hook ใน `TryAdvanceToNextGroup()`**
- เพิ่มเรียก `ForceCloseUnhedgedOppositeSide(cur)` **หลัง** `DeleteLeftoverInitialPendingsAfterHedge(cur)` และ **ก่อน** เช็ค `IsGroupSafeToAdvance`
- หน่วง `InpHedge_ForceCloseDelaySec` วินาทีจาก `g_groupHedgeFirstSeen[g]` (เก็บ timestamp ครั้งแรกที่เห็น hedge)

**4. Variable ใหม่**
```cpp
datetime g_groupHedgeFirstSeen[MAX_GROUPS+1];  // ตอน group เริ่มมี hedge ครั้งแรก (สำหรับ delay)
```
อัปเดตใน `TryAdvanceToNextGroup()` ก่อน hook ใหม่

**5. Dashboard**
- เพิ่มแถวใน Hedging panel: `Force-Close Opp: ON (3s)` / `OFF`

**6. Version & Logs**
- `#property version "2.78"`, `#property description` อัปเดต
- Header comment block (v2.7.8 เพิ่ม "Force-close opposite unhedged side on hedge lock")
- Dashboard `L_TITLE = "Golden2 v2.7.8"`
- `OnInit` log
- log เมื่อปิด: `Golden2 v2.7.8: G%d force-close opp main #%I64u side=%s pl=%.2f (hedge-lock cleanup)`

### สิ่งที่ "ไม่เปลี่ยนแปลง" (ตามกฎเหล็ก)
- ❌ ไม่แตะ Order execution (OrderSend, trade.Buy/Sell, trade.PositionClose ใช้ตามเดิมแค่เรียกในฟังก์ชันใหม่)
- ❌ ไม่แตะ Trading strategy logic (SMA/INSTANT/PENDING entry, Grid loss/profit, TP/SL/Trailing, Accumulate close, DD trigger, hedge mirror)
- ❌ ไม่แตะ License/News/Time/Sync modules
- ❌ ไม่แตะ `IsGroupSafeToAdvance` / `IsSideEffectivelySafeForAdvance` / `CountBlockingMainPositionsForAdvance` (ฟังก์ชันใหม่ทำงานก่อนให้กรุ๊ป "สะอาด" เอง)
- ❌ ไม่แตะ Squeeze v2.7.7 multi-confirm
- ❌ ไม่แตะ v2.3 `DeleteLeftoverInitialPendingsAfterHedge`
- ✅ Backward compatible 100% (input ใหม่มี default; ปิด `InpHedge_ForceCloseOppUnhedged=false` = พฤติกรรม v2.7.7 เดิม)

### ผลลัพธ์ที่คาดหวัง
จาก log ตัวอย่าง: G2 hedgeBuy=13 + main BUY 2 ไม้ค้าง → 3 วินาทีหลัง hedge เกิด ระบบจะปิด BUY 2 ไม้นั้นทิ้ง (ไม่สน +270) → G2 เหลือเฉพาะ {main SELL 12 + hedge BUY 13} = matched clean → G3 เปิดได้ทันที

### Memory & Index
- สร้าง `mem://trading/golden2-ea/v2-7-8-force-close-opp-unhedged.md`
- อัปเดต `mem://index.md`
