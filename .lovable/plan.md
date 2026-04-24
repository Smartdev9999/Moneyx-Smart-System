## Golden2 EA v2.30 — Fix ระบบหยุดออกออเดอร์หลัง Hedging Group 1

แก้ปัญหาที่ Group 2 ไม่ถูกเปิดหลัง G1 hedge แล้ว โดยอาการที่เห็นตรงกับ log/screenshot:
- `hold G1->G2 (cur safe=0 ... BUY=1 SELL=13 hedgeBuy=13 hedgeSell=0)`
- มี `G1_IN` ฝั่ง Buy ค้าง/ถูกยิงขึ้นมาหลัง hedge แล้ว ทำให้ระบบมองว่า G1 ยังมี main ฝั่ง Buy ที่ “ไม่ถูก lock” จึงบล็อกการ advance ไป G2 ตลอด

### ไฟล์ที่จะแก้
- `public/docs/mql5/Golden2_EA.mq5` — bump version `2.20` → `2.30`

### สิ่งที่ไม่เปลี่ยนแปลง
- ไม่แตะ `OrderSend / trade.Buy / trade.Sell / trade.PositionClose`
- ไม่แตะสูตร Grid Loss / Grid Profit / Frame distance / Multiplier
- ไม่แตะ Average TP/SL core logic
- ไม่แตะ Triple-Gate core exit logic
- ไม่แตะ Accumulate Close logic
- แก้เฉพาะ guard, state tracking, pending cleanup, และ advance condition เพื่อให้ flow หลัง hedge เดินต่อได้ตามเดิม

## สิ่งที่จะทำ

### 1) Freeze initial-frame maintenance ทันทีเมื่อ “มี hedge position แล้ว”
ตอนนี้บางส่วนยังอาศัย `IsGroupHedgeMatched(g)` ทำให้มีช่องที่ `IN` pending/re-arm ยังถูกขยับหรือสร้างใหม่ได้หลัง hedge เริ่มทำงานแล้ว

จะเปลี่ยน guard ของฟังก์ชันพวก initial-frame ให้หยุดทันทีเมื่อ group นั้นมี hedge position อย่างน้อย 1 ตัว เช่น:
- `ManageInitialTrailOnBarClose()`
- `ManageInitialTrail()`
- `ManageInitialReArm()`

ผลลัพธ์:
- หลัง hedge เริ่มแล้ว จะไม่ trail initial stop ต่อ
- จะไม่ re-arm `Gx_IN` ใหม่หลัง hedge แล้ว
- ลดโอกาสเกิด orphan `G1_IN` หลัง hedge

### 2) ลบ leftover initial pending ของ group ทันทีหลัง hedge เริ่ม active
เพิ่ม helper ใหม่ประมาณนี้:
- `DeleteLeftoverInitialPendingsAfterHedge(g)`

หน้าที่:
- ลบเฉพาะ main pending ที่เป็น tag `IN`
- ไม่แตะ hedge pending/hedge position
- ไม่แตะ grid/main positions ที่เปิดแล้ว

เหตุผล:
- ถ้ายังปล่อย `G1_IN` pending ค้างไว้ มันอาจโดนราคา trigger ภายหลังและกลายเป็น orphan main position ที่ไม่มี hedge คู่ตรงข้าม

### 3) ทำ advance check ให้ “tag-aware” และไม่ติด residual post-hedge `IN`
ปรับ `IsGroupSafeToAdvance(g)` จากการนับจำนวนฝั่งแบบกว้าง ๆ เป็นการมองเฉพาะ exposure ที่ควรใช้บล็อกจริง

จะเพิ่ม helper แนวนี้:
- `IsResidualPostHedgeInitialOrphan(...)`
- `CountBlockingMainPositionsForAdvance(g, side)`

กติกาใหม่:
- main ที่ยังต้องใช้บล็อก advance = main exposure ปกติที่ยังไม่ถูก hedge-lock
- แต่ `IN` residual ที่เกิดหลัง hedge active แล้ว และเป็น leftover จาก initial frame จะไม่นับเป็น blocker ของการเปิด group ถัดไป
- จะมี log แยกชัดเจนว่าพบ residual orphan อะไรบ้าง เพื่อ debug backtest ง่ายขึ้น

ผลลัพธ์:
- เคสแบบในรูป `BUY=1 SELL=13 hedgeBuy=13 hedgeSell=0` จะไม่ค้างทั้งระบบเพียงเพราะ `G1_IN` residue 1 ไม้
- G2 จะเปิดได้เมื่อ exposure หลักของ G1 ถูก lock แล้วจริง

### 4) เพิ่ม diagnostic log ให้เห็นสาเหตุการ hold แบบละเอียด
เวลาระบบ hold `G1->G2` จะ log เพิ่มว่า blocker มาจากอะไร เช่น:
- ticket ไหน
- comment/tag อะไร (`IN`, `GL#n`, `GP#n`)
- เป็น main หรือ hedge
- ถูกจัดเป็น residual orphan หรือ blocker จริง

จะช่วยแยกได้ชัดว่าเป็น:
- leftover initial
- unmatched main จริง
- หรือ prior group ยังไม่ safe จริง

### 5) Version bump → v2.30
อัปเดตทุกจุดที่แสดง version:
- `#property version`
- `#property description`
- header comment block
- `OnInit` log / startup print
- dashboard title (`Golden2 EA v2.3` / `v2.30` ให้ตรงกันทั้งไฟล์)

## Technical details

### Root cause
ปัญหาไม่ได้อยู่ที่การเปิด hedge order เอง แต่เกิดจาก flow หลัง hedge:
1. G1 hedge เปิดแล้ว
2. ยังมี `G1_IN` pending หรือ re-arm logic ทำงานต่อ
3. `G1_IN` ถูก trigger กลายเป็น main Buy เพิ่มหลัง hedge
4. `IsGroupSafeToAdvance()` มองว่าฝั่ง Buy main ยังไม่มี sell-hedge มาล็อก
5. ระบบ hold `G1->G2` ตลอด แม้ฝั่ง loss-side หลักจะถูก hedge แล้ว

### แนวทางแก้เชิงโครงสร้าง
```text
Before:
hedge active -> initial logic ยังอาจวิ่ง -> IN residue โผล่ -> safe=false -> G2 ไม่เปิด

After:
hedge active
  -> freeze initial logic
  -> delete leftover IN pendings
  -> advance check ไม่นับ residual post-hedge IN เป็น blocker
  -> G2 เปิดต่อได้
```

### Input ใหม่
ยังไม่จำเป็นต้องเพิ่ม input ถ้า logic fix นี้ควรเป็น default behavior ที่ถูกต้อง
ถ้าระหว่างแก้พบว่าควรเปิด/ปิดได้ จะเพิ่มเฉพาะกรณีจำเป็นจริงเท่านั้น

### Memory
บันทึก memory ใหม่:
- `mem://trading/golden2-ea/v2-3-post-hedge-in-orphan-advance-fix.md`

หาก approve ผมจะ implement ตามแผนนี้ใน `public/docs/mql5/Golden2_EA.mq5` เท่านั้น.