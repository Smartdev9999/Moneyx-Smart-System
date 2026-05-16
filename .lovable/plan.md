## v2.8.7 — ลบ Deprecated Squeeze Inputs + ซ่อม Triple-Gate Reserve-Profit ให้คำนวณถูก

ไฟล์เดียว: `public/docs/mql5/Golden2_EA.mq5`

---

# Part A — ลบ Input multi-confirm Squeeze ออกจริง (จาก v2.8.6)

ที่ v2.8.6 เก็บไว้เป็น no-op เพื่อ backward-compat — user ยืนยันว่า "ไม่ใช้แล้ว" ให้ลบทิ้ง

### Input ที่จะลบ (10 ตัว)
- `InpSQ_UseBBBreakout`
- `InpSQ_UseADX`, `InpSQ_ADXPeriod`, `InpSQ_ADXThreshold`
- `InpSQ_UseATRConfirm`, `InpSQ_ATRMAPeriod`, `InpSQ_ATRMult`
- `InpSQ_UseEMA`, `InpSQ_EMAPeriod`, `InpSQ_EMAPrice`

### Global ที่จะลบตาม
- `g_sqADX[3]`, `g_sqEMA[3]` (indicator handles)
- `g_sqPassBB[3]`, `g_sqPassADX[3]`, `g_sqPassATR[3]`, `g_sqPassEMA[3]`, `g_sqADXVal[3]`

### จุดแก้ตาม
- `ComputeSqueezeForTF()` — ลบบรรทัด assign no-op
- `OnInit` — ลบ init handles ADX/EMA
- `OnDeinit` — ลบ `IndicatorRelease(g_sqADX[i])` / `IndicatorRelease(g_sqEMA[i])`
- Init log — ลบข้อความ MultiConfirm

ผลข้างเคียง .set เก่า: MT5 warn "unknown parameter" แต่ EA ยังโหลดได้ปกติ (user รับได้แล้ว)

---

# Part B — ซ่อม Triple-Gate Reserve-Profit (เหตุที่ออเดอร์ไม่ปิด)

## ปัญหาที่ user รายงาน
หลังเข้า Zone + Cycle OK + Distance OK แล้ว Matching Close ควรปิดออเดอร์ลบ "โดยใช้กำไรฝั่งถูก หักลบไม้ลบทีละไม้ และต้องเหลือกำไรขั้นต่ำไว้" แต่ตอนนี้ไม่ปิดออเดอร์ลบเลย → ตรวจสอบโค้ดพบ 2 จุดที่คำนวณผิดเจตนา

## จุดที่ผิด

### 1) `InpExit_MinGainUSD = 100` เป็น HOLD-Gate (บรรทัด 2528–2539)
ปัจจุบันใช้เป็น "ห้ามเข้าโซน close จนกว่า netCheck จะดีขึ้น $100 จาก snapshot ตอน hedge เปิด" — เมื่อ group ติดลบหนัก netCheck แทบไม่ขยับ → block ตลอด → ไม่ปิดเลย
ที่ user ต้องการ: ค่านี้คือ "กำไรที่ต้องเหลือไว้หลัง shred" ไม่ใช่ "delta ที่ต้องดีขึ้น"

### 2) `pool + p >= InpExitMinNetUSD` (บรรทัด 2645 + 2768)
ใช้ `InpExitMinNetUSD = 1.0` เป็น floor ของ pool หลังหักไม้ลบ — แปลว่า reserve = $1 (เกือบ 0) ทุก match-close
ที่ user ต้องการ: reserve ต้องเท่ากับค่าที่ตั้งไว้ ไม่ใช่ $1 hardcoded floor

## สิ่งที่จะแก้

### Input ใหม่
```cpp
input double InpExit_ReserveProfitUSD = 50.0; // [v2.8.7] กำไรขั้นต่ำที่ต้องเหลือหลัง Matching Close (ก่อน Recovery)
```
- เก็บ `InpExitMinNetUSD` (1.0) ไว้ใช้เป็น sanity floor เดิม
- เก็บ `InpExit_MinGainUSD` เป็น input แต่เปลี่ยน semantic → ใช้เป็น **เกณฑ์ขั้นต่ำของ winProfit ก่อนเริ่ม shred** (แทน gate netCheck delta) เพื่อกัน choppy

### Logic ใหม่ใน `TryMatchingCloseForGroup` (2516–2540)
ลบ block "MinGain hold" delta ที่ block หนัก ๆ ทิ้ง เปลี่ยนเป็น:
```cpp
double winProfit = ...; // เดิม
if(winProfit < InpExit_ReserveProfitUSD + InpExit_MinGainUSD) {
  // ยังไม่มีกำไรพอแม้แต่จะ "เหลือไว้ + เริ่ม shred"
  log("MinGain hold winProfit=%.2f need=%.2f (reserve+minGain)"); return;
}
```
- ลบการอ้าง `g_groupNetAtHedgeStart[g]` ใน gate นี้ (snapshot baseline เก็บไว้สำหรับ dashboard อย่างเดียว)

### Logic ใหม่ใน `ShredCloseLosingSide` (2614–2653)
```cpp
// pool เริ่มจาก winProfit (snapshot ก่อน CloseAllGroupSide)
// reserve เป็นเงินที่ "ห้ามแตะ"
double reserve = InpExit_ReserveProfitUSD;
for each loss ticket (sorted profit desc / loss น้อยสุดก่อน) {
   if(pool + p >= reserve) { close; pool += p; }
   else break;
}
```
แทนที่ `>= InpExitMinNetUSD` ทั้งใน `ShredCloseLosingSide` และ `ShredAllNegativeFromAllProfit`

### Logic ใหม่ใน `ShredAllNegativeFromAllProfit` (2730–2777)
- เพิ่ม pool เดิม (= reserve ที่เหลือจาก pass 1) แทนเริ่ม pool=0
- ใช้ `>= InpExit_ReserveProfitUSD` แทน MinNetUSD
- (ทางเลือก) ส่ง `poolRemaining` ผ่าน arg เพื่อ chain ระหว่าง pass 1 → pass 2 ให้ reserve นับรวมทั้งกรุ๊ป

### Recovery Grid
- คงเดิม: ออก RC#N เฉพาะเมื่อยังมีไม้ลบเหลือหลัง shred — ตอนนี้จะออกเฉพาะเมื่อ reserve โดน "กิน" เต็มที่แล้วและยังมีไม้ลบเกิน
- เพิ่ม log: `Golden2 v2.8.7: G%d RECOVERY trigger residualLoss=%d reserveLeft=$%.2f`

### Dashboard (Right Panel, TripleGrid row)
เปลี่ยนจาก: `G:$winProfit/$MinGain`
เป็น: `Win:$X Resv:$Y/$Z` — แสดง winProfit / reserveAfterShred / reserveTarget
สี: เขียวเมื่อ `winProfit >= reserve + minGain`, เหลืองเมื่อกำลัง shred, แดงเมื่อ block

### Init Log
```
ReserveProfitUSD=%.1f  MinGainUSD=%.1f  MinNetUSD=%.1f
```

---

# Version
- `#property version "2.87"` + description + header banner + dashboard title + OnInit log → v2.8.7

---

# สิ่งที่ไม่เปลี่ยนแปลง (กฎเหล็ก MQL5)
- ไม่แตะ `trade.Buy/Sell/PositionClose/OrderSend/SellStop/BuyStop/OrderDelete`
- ไม่แตะ Entry mode PENDING/SMA/INSTANT
- ไม่แตะ Squeeze BB/KC ratio computation (v2.8.6)
- ไม่แตะ Hedge Orphan Offset (v2.8.6) / Mirror 1:1 / arm-disarm / Block percent / Force-close opp
- ไม่แตะ One-Hedge-Per-Group / Strip TP/SL / Post-Match Avg TP (เพิ่มแค่ค่า reserve ใหม่)
- ไม่แตะ Grid Loss/Profit lot/distance/candle confirm
- ไม่แตะ Per-order trail / Bar-close trail / Accumulate / Cost-Hit
- ไม่แตะ ParseComment / MakeComment B_/S_ tags
- ไม่แตะ License / News / Time / Sync
- ไม่แตะ Sequential Queue gate / Squeeze TF3 latch / Zone breakout dist gate
- การปิด `CloseAllGroupSide(winSide)` ฝั่งถูก ยังคงเดิม (ไม่ทอน winProfit ก่อน close)

---

# ไฟล์ที่แก้
- `public/docs/mql5/Golden2_EA.mq5`
- สร้าง `.lovable/memory/trading/golden2-ea/v2-8-7-purge-inputs-and-reserve-profit-fix.md`
- อัปเดต `.lovable/memory/index.md` (เพิ่ม entry v2.8.7, แทน v2.8.6 อันเดิมไม่ลบ)
