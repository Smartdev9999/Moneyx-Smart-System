## v2.8.6 — รวม 2 งานในไฟล์ `public/docs/mql5/Golden2_EA.mq5`

---

# Part A — Squeeze Filter: ตัด Multi-Confirm ออก (เหลือ BB/KC ratio เหมือน Gold Miner Original)

## ปัญหา
v2.7.7 เพิ่ม BB Breakout + ADX + ATR-MA + EMA เป็นเงื่อนไข AND กับ ratio → ratio ผ่าน 1.6 แล้ว แต่ตัวอื่นไม่ผ่าน → `g_sqExpansion[tf]` = false → `g_groupSeenExp[g]` ไม่ latch → Triple-Gate ไม่เปิด → Matching Close pool-based ลั่นปิด Hedging เร็วเกินไป

## สิ่งที่จะทำ
1. **ลบ logic Multi-Confirm ออกจาก `ComputeSqueezeForTF()`** — เหลือเฉพาะ BB upper-lower / KC upper-lower → `ratio = bbWidth / kcWidth`
   - `g_sqExpansion[tf] = (ratio >= InpSQ_ExpansionThreshold)` ตรง ๆ
   - `g_sqNormal[tf]    = (ratio <  InpSQ_ExpansionThreshold)`
2. **ลบ Input ที่ไม่ใช้แล้ว** (เก็บไว้เป็น `const` no-op เพื่อให้ `.set` ไฟล์เก่ายังโหลดได้):
   - `InpSQ_UseBBBreakout`
   - `InpSQ_UseADX`, `InpSQ_ADXPeriod`, `InpSQ_ADXThreshold`
   - `InpSQ_UseATRConfirm`, `InpSQ_ATRMAPeriod`, `InpSQ_ATRMult`
   - `InpSQ_UseEMA`, `InpSQ_EMAPeriod`, `InpSQ_EMAPrice`
3. **ลบ indicator handle ที่เกี่ยวข้อง** (`g_adxHandle[3]`, `g_atrHandleSQ[3]`, `g_emaHandle[3]`) + `IndicatorRelease` ใน `OnDeinit`
4. **Dashboard** — แถว `Confirm BB:v ADX:v ATR:v EMA:v` ออก เหลือ `TF1/TF2/TF3  ratio=X.XX  EXP/NORMAL`
5. **Init log** — ตัด `MultiConfirm=ON` ออก

## ผลข้างเคียงที่ได้ฟรี (ไม่ต้องแก้แยก)
- `RefreshGroupExpansionLatch(g)` อ่าน `g_sqExpansion[2]` เหมือนเดิม แต่ตอนนี้สะท้อน ratio จริง → latch ทำงานได้ทันที (ไม่ต้องเพิ่ม `g_sqExpansionRaw[]` แยก)
- Block New Orders / Close-on-Expansion ใช้ ratio เดียวกัน → พฤติกรรมเทียบเท่า Gold Miner Original

---

# Part B — Hedge Orphan Offset (ตามภาพที่ส่งมา)

## ปัญหา
`MirrorLossSideToHedgePendings(g, lossSide)` วาง pending hedge 1:1 ต่อ loss-side ticket โดยไม่หัก orphan main ฝั่งตรงข้ามที่มีอยู่ก่อน
ผล: BUY 8 + SELL orphan 4 → SELL_STOP 8 ตัว trigger ครบ = SELL 12 vs BUY 8 ไม่บาลานซ์

## ตัวอย่างตามภาพ
- BUY (loss side, 8 ไม้): `IN, GL#1..GL#7`
- SELL orphan main (4 ไม้): `IN, GL#1..GL#3`
- ที่ถูก: วาง pending hedge เฉพาะ `HD_GL#4..HD_GL#7` = 4 ตัว lot ต่อจาก orphan ตัวสุดท้าย

## สิ่งที่จะทำ
1. ฟังก์ชันใหม่ `CountOrphanMainOnHedgeSide(g, hedgeSide)` — นับ position group `g`, side=`hedgeSide`, `hd==false`
2. แก้ `MirrorLossSideToHedgePendings`:
   - Sort `lossTags[]` เก่า→ใหม่ ตาม `POSITION_TIME_MSC`
   - `int skipN = CountOrphanMainOnHedgeSide(g, oppositeSide)`
   - **ข้าม `skipN` ตัวแรก** (loss เก่าถือว่าถูก orphan ฝั่งตรงข้าม hedge แทนแล้ว)
   - ถ้า `skipN >= ArraySize(lossTags)` → ไม่วาง hedge เลย + ลบ pending hedge เก่าทั้งหมด
   - วาง pending เฉพาะ tag/lot ของ loss ที่เหลือ (lot = lot ของ loss ticket นั้น)
3. แก้ block "Remove orphan hedge pendings":
   - `keepTags[]` = `lossTags[skipN..end]` (ไม่ใช่ทั้ง array)
4. Log: `Golden2 v2.8.6: HD-MIRROR G%d lossSide=%s lossN=%d orphanOnHedge=%d → mirror=%d (skip oldest %d)`
5. Dashboard: เพิ่ม `Orph:<n>` ใต้แถว `Hedge USED/LOCKED` ต่อกรุ๊ป

---

# Version + Memory
- `#property version "2.86"` + description + header banner + Dashboard title + OnInit log → v2.8.6
- Init log: `HedgeOrphanOffset=ON  Squeeze=BB/KC-ratio-only`
- Memory: `.lovable/memory/trading/golden2-ea/v2-8-6-hedge-orphan-offset-and-squeeze-simplify.md` + อัปเดต `index.md`

---

# สิ่งที่ไม่เปลี่ยนแปลง (ตามกฎเหล็ก)
- ไม่แตะ `trade.SellStop/BuyStop/OrderDelete/PositionClose/OrderSend`
- ไม่แตะ `LotForLevel`, `HedgePendingAnchorPrice`, `ParseComment`, `MakeComment`, `HighestGridLevel`
- ไม่แตะ Trigger: `pct >= InpHedgeArmPercent`, mutex, hedge open delay
- ไม่แตะ v2.8.5 One-Hedge-Per-Group, Strip TP/SL, Post-Match Avg TP
- ไม่แตะ Triple-Gate / Matching Close / Recovery Grid
- ไม่แตะ Entry mode PENDING/SMA/INSTANT, Grid Loss/Profit, Per-order trail, Accumulate
- ไม่แตะ License / News / Time / Sync
- ไม่แตะการคำนวณ BB/KC pipeline (เก็บแค่ ratio path, ตัด ADX/ATR/EMA/BB-breakout ที่เคยเพิ่มใน v2.7.7)

# ไฟล์
- `public/docs/mql5/Golden2_EA.mq5`
- `.lovable/memory/trading/golden2-ea/v2-8-6-hedge-orphan-offset-and-squeeze-simplify.md` (สร้าง)
- `.lovable/memory/index.md` (อัปเดต entry)
