

## Golden2 EA v1.8 — Bar-Close Frame Trail + Immediate Grid Loss Trigger + Gold-Miner-style Squeeze Panel

แก้ 2 จุดที่พบจากเทรดจริง + เสริม Squeeze Panel ให้เห็นสถานะรายตัวเหมือน Gold Miner

### ไฟล์ที่จะแก้
- `public/docs/mql5/Golden2_EA.mq5` (ไฟล์เดียว) — bump version → `1.80`

### สิ่งที่ "ไม่เปลี่ยนแปลง" (ยืนยันไม่กระทบ trading logic)
- ไม่แตะ `OrderSend / trade.Buy / trade.Sell / trade.PositionClose`
- ไม่แตะสูตร Grid Loss / Grid Profit / Initial Frame / Hedging mirror / Avg TP-SL / Triple-Gate
- ไม่แตะ License / News / Time filter / Squeeze BB-KC math
- ไม่แตะ ReArm logic (ทำงานหลังออกจาก TP เหมือนเดิม)

---

### 1) Bar-Close Frame Trail (ทุก 1 นาทีปิดแท่ง — ขยับ stop ฝั่งตรงข้ามเท่านั้น)

**ปัญหาปัจจุบัน:** `ManageInitialTrail` (v1.7) ขยับ stop ฝั่งตรงข้ามเฉพาะตอน "ราคาเข้าใกล้ trigger" และทำงาน per-tick → ภาพที่เห็นไม่มีการอัปเดตเลยเพราะเงื่อนไขไม่ถึง

**Fix:**
- เพิ่ม input:
  ```
  input bool InpInitTrailOnBarClose = true;  // [v1.8] Trail opposite stop on every M1 bar close
  input ENUM_TIMEFRAMES InpInitTrailTF = PERIOD_M1; // [v1.8] Trail timer TF
  ```
- เพิ่ม `g_lastTrailBar[MAX_GROUPS]` เก็บเวลา bar ที่ trail ล่าสุด
- ในลูป `OnTick` ต่อกรุ๊ป: เรียก `ManageInitialTrailOnBarClose(g)` **ก่อน** `ManageInitialTrail(g)` เดิม
- พฤติกรรม `ManageInitialTrailOnBarClose`:
  1. อ่านเวลาแท่งล่าสุดของ TF (`iTime(_Symbol, InpInitTrailTF, 0)`); ถ้า `== g_lastTrailBar[g]` → return (อัปเดตแล้ว)
  2. ต้องเป็นกรุ๊ป active (มี position หรือ pending อย่างน้อย 1) และ **ไม่ใช่** post-hedge lock
  3. สำหรับฝั่งที่ "ไม่มี position" + "มี pending IN":
     - ถ้าฝั่งตรงข้ามมี position หรือมี pending IN → **คำนวณราคาขยับใหม่จากราคาปัจจุบัน**
     - BUY pending: `newPx = ask + InpFrameUpperPips*g_point` (ขยับ "ตามราคา" ไปด้านบน)
     - SELL pending: `newPx = bid - InpFrameLowerPips*g_point`
  4. **ขยับเฉพาะฝั่งที่ "ราคาวิ่งห่างออก"** (ฝั่งตรงข้ามทิศที่ราคาวิ่ง):
     - ถ้า `newPx > oldPx` (BUY stop) หรือ `newPx < oldPx` (SELL stop) → modify
     - ถ้าราคาวิ่งเข้าหา stop ฝั่งนั้น (ใกล้ชน) → **ไม่ modify** (ตามคำสั่ง user)
  5. อัปเดต TP/SL ให้สัมพันธ์กับ open price ใหม่ (ใช้สูตรเดียวกับ `PlaceInitialFrame`)
  6. `g_lastTrailBar[g] = curBar`

**ตัวอย่าง:** ราคาขึ้น 100 จุด → ปิดแท่ง M1 → SellStop เดิม (ห่าง 200) ถูกขยับขึ้นตามให้ห่างจาก bid ใหม่ 200 จุดเท่าเดิม. BuyStop (ฝั่งที่ราคาวิ่งเข้าหา) ไม่ขยับ.

- ปิด `ManageInitialTrail` (v1.7 trigger-based) ด้วย toggle: ถ้า `InpInitTrailOnBarClose=true` → ข้าม `ManageInitialTrail` เดิม (กัน double modify)

### 2) Grid Loss ทำงานทันทีหลัง Initial fill

**ปัญหา:** หลัง initial pending ถูก fill เป็น position แล้ว ราคาวิ่งสวนถึงเกณฑ์ grid แต่ระบบไม่ออก GL ทันที — ต้องรอ tick ถัดไป/แท่งใหม่

**Root cause:** มี guard `GridLoss_OnlyNewCandle` หรือ `GridLoss_DontSameCandle` หรือ `GridLoss_CandleConfirm` ที่ block ในแท่งเดียวกับที่ initial เพิ่ง fill

**Fix (ไม่แตะสูตร):**
- เพิ่ม input toggle:
  ```
  input bool InpGL_ImmediateAfterInitial = true; // [v1.8] Bypass candle-guards for GL#1 right after initial fill
  ```
- ใน `TryPlaceGridLoss`: ถ้า `gl == 0` (กำลังจะออก GL#1 ตัวแรก) **และ** `InpGL_ImmediateAfterInitial=true`:
  - ข้าม `GridLoss_OnlyNewCandle` check
  - ข้าม `GridLoss_DontSameCandle` check
  - ข้าม `GridLoss_CandleConfirm` check
  - **ไม่ข้าม** trigger gap check (ยังต้องถึงระยะ gap จริง)
- ตั้งแต่ GL#2 ขึ้นไป → ใช้ guards เดิมตามปกติ

**เพิ่มเติม:** หลัง `PlaceInitialFrame` fill เสร็จ (detect ในลูป `OnTick`) — เรียก `TryPlaceGridLoss(g)` ในรอบเดียวกันได้เลย (ลำดับเดิมก็เป็นแบบนี้อยู่แล้ว: line 2209) — แค่ต้องไม่ถูก guard บล็อก

### 3) Squeeze Panel แบบ Gold Miner (สถานะรายตัว + bar visual)

อ้างอิงภาพ user upload (`--- SQUEEZE ---`, `M1 NORMAL 0.97 |####......|`, `M5 EXPANSION BUY 2.04 |##########|`, `Squeeze Status SELL BLOCKED`)

**เพิ่มใน Dashboard ฝั่งซ้าย** (ต่อจากแถว `L_SQ` เดิม):
- แทนที่ `L_SQ` ตัวเดียว → block หลายแถว:
  ```
  === SQUEEZE ===
  M1     NORMAL 0.97       |####......|
  M5     EXPANSION BUY 2.04 |##########|
  M15    EXPANSION BUY 3.70 |##########|
  Squeeze Status  SELL BLOCKED
  ```
- เพิ่ม helper:
  - `SqueezeRatioForTF(int i)` → return BBwidth/KCwidth (cache จาก `RefreshSqueezeState`)
  - `SqueezeBarString(double ratio)` → 10-char bar; fill = `MathMin(10, (int)(ratio/InpSQ_ExpansionThreshold * 10))`; ใช้ `#` เติม + `.` ส่วนที่เหลือ
  - `SqueezeStateLabel(int i)` → "NORMAL" / "EXPANSION BUY" / "EXPANSION SELL" ตาม `g_sqExpansion[i]` + `g_sqDir[i]`
  - `SqueezeOverallLabel()` → "READY" / "BUY BLOCKED" / "SELL BLOCKED" / "BOTH BLOCKED"
- Cache ratio: เพิ่ม `double g_sqRatio[3]` set ใน `ComputeSqueezeForTF` (ปรับให้ส่ง ratio out)
- สีแถว: NORMAL=DashColor, EXPANSION+block matching=DashBad, EXPANSION+ไม่ block=DashAccent
- แสดงเฉพาะเมื่อ `InpSQ_Enable=true`; ถ้า OFF → แสดง 1 บรรทัด `Squeeze: OFF`

**ฝั่งขวา (Hedging Table):** ไม่กระทบ

### Inputs ใหม่ (สรุป)
```
input bool            InpInitTrailOnBarClose    = true;
input ENUM_TIMEFRAMES InpInitTrailTF            = PERIOD_M1;
input bool            InpGL_ImmediateAfterInitial = true;
```

### Technical Notes
- `g_lastTrailBar[]` reset ใน `OnInit` เป็น 0
- Bar-close trail ทำงานบน `iTime(_Symbol, InpInitTrailTF, 0)` change detection — ทำงานครั้งเดียวต่อแท่ง
- ขยับ stop ใช้ `trade.OrderModify` เดียวกับ ManageInitialTrail v1.7 (ไม่สร้างฟังก์ชันส่ง order ใหม่)
- Squeeze ratio `BBwidth/KCwidth` คำนวณแล้วใน `ComputeSqueezeForTF` — แค่ expose ออกมาเก็บใน `g_sqRatio[]`
- บันทึก memory: `mem://trading/golden2-ea/v1-8-barclose-trail-immediate-gl-sq-panel.md`
- Bump version `1.80` ทุกจุด: `#property version`, `#property description`, header comment, `Print` ใน OnInit, dashboard title

