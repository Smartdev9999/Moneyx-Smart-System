## Golden2 EA v2.7.4 — Allow Group Advance When Unhedged Side Is Profitable (INSTANT / SMA fix)

ไฟล์เดียวที่แก้: `public/docs/mql5/Golden2_EA.mq5`

### ปัญหาที่พบ (จาก log + screenshot ของผู้ใช้)
ใน INSTANT / SMA mode:
- Group 1 เปิด Market BUY + SELL ทันที (ไม่มี pending frame)
- เมื่อฝั่งหนึ่ง (เช่น SELL) ติด DD จนยิง Hedge → Hedge mirror lock เฉพาะฝั่ง SELL
- ฝั่ง BUY ที่กำไรอยู่ ไม่มี hedge มา cover (เพราะไม่ขาดทุน → mirror ไม่ทำงาน)
- `IsGroupSafeToAdvance()` ปัจจุบันต้องการให้ "ทุก main position ถูก hedge"
- ผล: G1 ค้างตลอดกาล (`blkBUY=12 hedgeBuy=0`) → G2 ไม่ถูกเปิด → ระบบหยุดทำงาน
- ใน PENDING mode ไม่เกิดเพราะ pending frame ทั้งสองฝั่งจะถูก hedge mirror ก่อนเสมอ

### Concept แก้
ฝั่งที่ "กำไรอยู่ + ไม่มี hedge" ถือว่า **ปลอดภัย** สำหรับ advance ได้ เพราะ:
- ถ้ากำไรลดลงจนติด DD trigger → hedge mirror จะทำงานเอง (logic เดิม)
- ไม่มีเหตุผลต้องบล็อก G2 เพราะ G1 ฝั่งกำไร

### Inputs ใหม่
- `InpAdvance_AllowProfitSideUnhedged = true` (default ON) — toggle behavior

### Implementation
1. **Helper ใหม่** `IsSideEffectivelySafeForAdvance(int g, int side)`:
   - คืน `true` ถ้า:
     - ฝั่งนั้นไม่มี main position เหลือเลย (count==0), **หรือ**
     - ฝั่งนั้นมี hedge position active (logic เดิม), **หรือ**
     - `InpAdvance_AllowProfitSideUnhedged==true` AND floating P/L ของฝั่งนั้น >= 0

2. **แก้ `IsGroupSafeToAdvance(g)`**:
   - แทนที่ลูปนับ `blkBUY/blkSELL` แบบเดิม
   - เรียก `IsSideEffectivelySafeForAdvance(g, 0)` AND `IsSideEffectivelySafeForAdvance(g, 1)`

3. **Helper P/L per-side** `GetGroupSideFloatingPL(int g, int side)`:
   - Loop PositionsTotal scan magic+comment(group,side) → sum `PositionGetDouble(POSITION_PROFIT) + SWAP + (commission ถ้ามี)`

4. **Hold log enhancement** เพิ่ม `plBUY=xx.xx plSELL=yy.yy` ใน hold-message เพื่อ debug ง่ายขึ้น

### Version
- Bump → **2.7.4**
- อัปเดต: `#property version`, header block, `OnInit` log, Dashboard `L_TITLE`

### สิ่งที่ "ไม่เปลี่ยน"
- ❌ ไม่แตะ OrderSend / trade.* (Initial / Grid / Hedge mirror / Triple-Gate / Accumulate)
- ❌ ไม่แตะ Hedge mirror trigger (DD% logic เดิม)
- ❌ ไม่แตะ v2.5 Trail / v2.6 Re-entry / v2.70 Continuous Frame / v2.72 Squeeze per-side / v2.73 Entry Mode
- ❌ ไม่แตะ License / News / Sync
- ✅ Default `InpAdvance_AllowProfitSideUnhedged=true` — แก้ปัญหา INSTANT/SMA ทันที, PENDING mode ไม่ได้รับผลกระทบ (เพราะปกติทั้งสองฝั่ง hedge ครบอยู่แล้ว)
- ✅ ผู้ใช้ปิด toggle = false → กลับไปพฤติกรรมเดิม 100%