

## Golden2 EA v1.6 — Disarm Fix + Volatility Squeeze Filter + Post-Hedge Grid Lock + Triple-Gate Toggle

แก้ 3 ปัญหาที่พบจากการเทรดจริง พร้อมพอร์ตฟีเจอร์ Volatility Squeeze จาก Gold Miner เข้ามา

### ไฟล์ที่จะแก้
- `public/docs/mql5/Golden2_EA.mq5` (ไฟล์เดียว)

### สิ่งที่ "ไม่เปลี่ยนแปลง" (ยืนยันไม่กระทบ trading logic)
- ไม่แตะ `OrderSend / trade.Buy / trade.Sell / trade.PositionClose` ใน strategy หลัก
- ไม่แตะสูตร Grid Loss / Grid Profit / Max-Grid Trailing / Initial Frame
- ไม่แตะ Average TP/SL sync (v1.3), Mirror 1:1 (v1.4), Strip-Broker-TPSL
- ไม่แตะ License/News/Time filter, Dashboard 2-panel (v1.5)
- ไม่แตะสูตรคำนวณ DD% (`lossUSD/InpHedgeTriggerUSD × 100`)

---

### 1) แก้บั๊ก Disarm Pending Hedge (กรุ๊ปดีดกลับ < 70% แต่ไม่ลบ pending)

**Root cause:** ใน `ManageGroupHedgeArm` ลำดับเงื่อนไข `if(!hedgePosExists && hedgePendingExists){ ... }` ทำงานถูกต้องเฉพาะเมื่อกรุ๊ปนั้น **ยังไม่มีhedge position activate**. แต่ภาพที่ user ส่งมา G1 hedge activate แล้ว ทำให้ลูป arm ของ G2 อาจถูกข้ามด้วย mutex/queue หรือเงื่อนไข sequential. นอกจากนี้ `hedgePendingExists` ถูกเช็คก่อน `pct` recalc ทุก tick — แต่ถ้า `g_blockNewOrders[g]` ค้าง = true จากรอบก่อน อาจไม่มีปัญหาตรงนี้

**Fix:**
- ปรับเงื่อนไข disarm ให้เป็น **unconditional pre-check** ที่ต้นฟังก์ชัน (ก่อน `hedgePosExists` early return): ถ้า `hedgePendingExists && !hedgePosExists && pct < InpHedgeDisarmPercent` → ลบทันที + reset `g_blockNewOrders[g]=false` + return
- เพิ่ม secondary disarm trigger: ถ้า `GroupLossSide(g) < 0` (ทั้ง 2 ฝั่งกำไรแล้ว) → ลบ pending hedge ทิ้ง
- เพิ่ม log: `"Golden2 v1.6: HD DISARM G%d pct=%.1f reason=%s (recover|noLossSide)"`

### 2) เพิ่ม Volatility Squeeze Filter (พอร์ตจาก Gold Miner)

เพิ่ม input group `=== Volatility Squeeze Filter ===` ตรงตามภาพ user upload:
```
input bool   InpSQ_Enable             = true;   // Enable Squeeze Filter
input ENUM_TIMEFRAMES InpSQ_TF1       = PERIOD_M1;
input ENUM_TIMEFRAMES InpSQ_TF2       = PERIOD_M5;
input ENUM_TIMEFRAMES InpSQ_TF3       = PERIOD_M15;
input int    InpSQ_BBPeriod           = 15;
input double InpSQ_BBMult             = 2.0;
input int    InpSQ_KCPeriod           = 15;
input double InpSQ_KCMult             = 1.5;
input int    InpSQ_ATRPeriod          = 14;
input double InpSQ_ExpansionThreshold = 1.6;     // BBwidth/KCwidth ≥ this = Expansion
input bool   InpSQ_BlockNewOrders     = true;    // Block new orders on Expansion
input int    InpSQ_MinExpansionTFs    = 1;       // 1..3 TFs in expansion = block
input bool   InpSQ_DirectionalBlock   = true;    // Only block counter-trend
input bool   InpSQ_CloseOnExpansion   = false;   // Close all on expansion (default off)
```

**Implementation (พอร์ต logic จาก Gold Miner v6.14):**
- Helper `IsSqueezeExpansion(tf, &dirUp)`: คำนวณ BB/KC บน bar index 1 (closed bar เพื่อ stability v6.13), return true ถ้า `BBwidth/KCwidth ≥ Threshold` + ทิศทาง = sign(close − BBmid)
- Helper `CountExpansionTFs(&blockBuy, &blockSell)`: นับว่า TF ใดอยู่ใน expansion พร้อมตั้ง flag block ตาม direction (ถ้า `DirectionalBlock=true`: expansion-up บล็อก SELL, expansion-down บล็อก BUY; ถ้า false บล็อกทั้ง 2)
- Guard ที่ "ทางเข้า" — เพิ่มแถวเดียวต้นฟังก์ชัน (ไม่แตะลอจิกข้างใน):
  - `PlaceInitialFrame(g)`: ถ้า expansion ≥ MinExpansionTFs → return
  - `TryPlaceGridLoss(g)`: ถ้า block ฝั่งนั้น → continue
  - `TryPlaceGridProfit(g)`: ถ้า block ฝั่งนั้น → continue
- ถ้า `InpSQ_CloseOnExpansion=true` → ปิดทุกออเดอร์ของกรุ๊ปที่ยังไม่ matched (ใช้ใน emergency เท่านั้น default off)
- **ยกเว้น**: pending hedge mirror (1:1) ไม่ถูกบล็อกโดย squeeze (เหมือน Gold Miner v6.56 ที่ exempt hedge orders)
- Cache handle ต่อ TF เพื่อไม่ recreate ทุก tick: `g_sqBB[3], g_sqKC_EMA[3], g_sqATR[3]` สร้างใน `OnInit`, release ใน `OnDeinit`

### 3) Post-Hedge Grid Lock (กรุ๊ปที่ hedge activate แล้ว ห้ามออก grid ต่อ จนกว่าจะผ่าน Triple-Gate)

**ปัญหา:** ปัจจุบัน `PlaceContinuationGridIfNeeded(g)` ถูกเรียกใน flow matching close (line 1480) — เปิด grid ต่อทันทีหลัง partial match. user ต้องการให้ **เมื่อ hedge activate แล้ว หยุด grid ใหม่** จนกว่าจะมีการ matching close (Triple Gate) ผ่าน

**Fix:**
- ใน `TryPlaceGridLoss` และ `TryPlaceGridProfit`: เพิ่ม guard `if(IsGroupHedgeMatched(g)) return;` ที่ต้นฟังก์ชัน (Grid Profit มีอยู่แล้ว, Grid Loss ยังขาด)
- ใน `ManageMaxGridTrailing` มี check แล้ว ✓
- `PlaceContinuationGridIfNeeded` (line 1480): เพิ่ม input toggle `InpPostHedge_AllowContinuation` (default `false`) — ถ้า false → return; ถ้า true → ทำงานเดิม
- ผลลัพธ์: หลัง hedge activate, ทั้งกรุ๊ปจะ "freeze" รอ Triple-Gate matching close เท่านั้น (ตาม Gold Miner behavior)

### 4) Triple-Gate Master Toggle เปิด/ปิดได้

เพิ่ม input:
```
input bool InpExitTripleGate_Enable = true;   // Enable Triple-Gate matching close
```
- ถ้า `false`: 
  - `IsExpansionToNormal()` return `true` (bypass gate — ใช้แค่ Average TP/SL + broker TP เท่านั้น)
  - หรือ early-return ใน `TryMatchingCloseForGroup(g)` เพื่อปิดทั้ง flow
  - เลือกแบบ early-return เพื่อให้ user ตัดทั้ง matching close ออกถ้าต้องการ
- Dashboard ฝั่งซ้ายเพิ่มแถว `Triple-Gate: ON/OFF`

### 5) Dashboard อัปเดต
- ฝั่งซ้าย: เพิ่ม `Squeeze: TF_M1/M5/M15 [E:1↑] BLK_BUY` แสดงสถานะ expansion ของแต่ละ TF + ทิศทาง block
- ฝั่งซ้าย: เพิ่ม `Triple-Gate: ON/OFF`
- ฝั่งขวา (Hedging table): เพิ่มคอลัมน์ `LOCK` แสดง `Y` เมื่อกรุ๊ปนั้น hedge activated และถูก post-hedge lock

### Inputs ใหม่ (สรุป)
```
input bool InpExitTripleGate_Enable        = true;   // Triple-Gate master on/off
input bool InpPostHedge_AllowContinuation  = false;  // Allow continuation grid after hedge activate
// + Squeeze group ทั้งบล็อก (ข้อ 2)
```

### Technical Detail
- Squeeze BB calc: `BB = iBands(_Symbol, tf, period, 0, mult, PRICE_CLOSE)`, `KC_mid = iMA(EMA, period)`, `KC_width = 2 × mult × ATR(period)`. expansion = `(BBupper − BBlower)/KCwidth ≥ Threshold` บน shift=1
- Disarm fix: ย้าย disarm block ขึ้นไปก่อน `if(hedgePosExists) return` เพื่อ guarantee execution
- Bump version → `1.60` ทุกจุด (`#property version`, `description`, header, dashboard)
- บันทึก memory: `mem://trading/golden2-ea/v1-6-disarm-squeeze-postlock.md`

