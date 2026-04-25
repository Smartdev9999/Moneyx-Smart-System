
# Golden2 EA v2.7.7 — Squeeze Filter + ADX/EMA Multi-Confirm

ไฟล์: `public/docs/mql5/Golden2_EA.mq5`

## เป้าหมาย
เพิ่มความแม่นยำการกรอง State (Squeeze / Normal / Expansion) ของ Volatility Squeeze Filter โดยเพิ่ม **ADX + EMA** เป็นตัวคอนเฟิร์มทิศทางเทรนด์ ก่อนจะตัดสินว่าเป็น Expansion จริง

## หลักการตอบคำถาม
- **Expansion = เทรนด์ขาขึ้น/ขาลง?** ✅ ใช่ — ratio (BBwidth/KCwidth) ≥ threshold = ตลาดกำลังขยายตัว และ `dir = sign(close − BBmid)` บอกทิศทาง (ขึ้น/ลง)
- ปัจจุบันใช้แค่ BB vs KC + ทิศจาก BB-mid → บางครั้ง **false expansion** (spike สั้นๆ) ทำให้บล็อกฝั่งผิด
- เพิ่ม ADX (วัดความแรงเทรนด์) + EMA (ยืนยันทิศ) ต่อ TF เพื่อกรองสัญญาณหลอก

## Pipeline ใหม่ (ต่อ TF)
ลำดับการเช็คแบบ **AND** (ทุกตัวต้องผ่าน → จึงเป็น Expansion จริง):

1. **BB vs KC ratio** (เดิม) → ratio ≥ `InpSQ_ExpansionThreshold` (default 1.6)
2. **BB Position Check** (ใหม่) → close[1] อยู่ **เหนือ BB Upper** (ขึ้น) หรือ **ใต้ BB Lower** (ลง) — ดูราคาทะลุจริง ไม่ใช่แค่กว้าง
3. **ADX Strength** (ใหม่) → ADX[1] ≥ `InpSQ_ADXThreshold` (default **25**) + ทิศจาก +DI/-DI ตรงกับ BB direction
4. **ATR Confirm** (ใหม่) → ATR[1] ≥ ATR-MA(N) × `InpSQ_ATRMult` (ATR ปัจจุบันสูงกว่าค่าเฉลี่ย = volatility ขยายจริง)
5. **EMA Trend Confirm** (ใหม่) → close[1] **เหนือ EMA(N)** = ขึ้น / **ใต้ EMA(N)** = ลง — ทิศต้องตรงกับขั้นที่ 2-3

→ Expansion จริง **เมื่อทั้ง 5 ผ่านและทิศทางตรงกัน** ไม่งั้น = Normal/Squeeze

## Inputs ใหม่ (เพิ่มในกลุ่ม Squeeze เดิม)
```cpp
input bool   InpSQ_UseADX            = true;   // Use ADX confirmation
input int    InpSQ_ADXPeriod         = 14;     // ADX Period
input double InpSQ_ADXThreshold      = 25.0;   // ADX min for trend (std=25)

input bool   InpSQ_UseBBBreakout     = true;   // Require close beyond BB Upper/Lower
input bool   InpSQ_UseATRConfirm     = true;   // Require ATR > ATR-MA * mult
input int    InpSQ_ATRMAPeriod       = 20;     // ATR moving avg period
input double InpSQ_ATRMult           = 1.0;    // ATR multiplier vs MA

input bool   InpSQ_UseEMA            = true;   // Use EMA trend confirm
input int    InpSQ_EMAPeriod         = 50;     // EMA period
input ENUM_APPLIED_PRICE InpSQ_EMAPrice = PRICE_CLOSE;
```

ค่าเริ่มต้นมาตรฐาน: ADX 14/25, EMA 50, ATR-MA 20×1.0 — ผู้ใช้ปรับได้ภายหลัง

## Implementation
### 1. Handles ใหม่ (3 TFs × 2 indicator)
```cpp
int g_sqADX[3];   // iADX
int g_sqEMA[3];   // iMA EMA
// ATR-MA ใช้ MathMean ของ ATR buffer ที่มีอยู่แล้ว (ไม่ต้องสร้าง handle ใหม่)
```
Init ใน `OnInit` ต่อจาก `g_sqATR[i]` เดิม (line ~3040)

### 2. ขยาย `ComputeSqueezeForTF(int idx, bool &isExp, int &dir)`
- คำนวณ ratio + bbDir เดิม
- ถ้า `InpSQ_UseBBBreakout`: ต้อง close[1] > bbU[1] (dir=+1) หรือ < bbL[1] (dir=-1)
- ถ้า `InpSQ_UseADX`: อ่าน ADX main + +DI + -DI → ต้อง ADX≥thr และ DI ทิศตรงกับ dir
- ถ้า `InpSQ_UseATRConfirm`: copy ATR[1..N] → คำนวณค่าเฉลี่ย → ต้อง atr[1] ≥ mean × mult
- ถ้า `InpSQ_UseEMA`: ต้อง close[1] อยู่ฝั่งเดียวกับ EMA ตาม dir
- เก็บผลแต่ละด่านไว้ใน array ใหม่สำหรับ Dashboard:
  ```cpp
  bool g_sqPassBB[3], g_sqPassADX[3], g_sqPassATR[3], g_sqPassEMA[3];
  double g_sqADXVal[3];
  ```
- `isExp = pass1 && pass2 && pass3 && pass4 && pass5` (เฉพาะที่ enable)

### 3. Dashboard (Squeeze panel)
- คงแถวเดิม (TF1/TF2/TF3 + Overall) 
- เพิ่มสรุปต่อ TF: `BB:✓ ADX:25.3✓ ATR:✓ EMA:✓` (ย่อให้พอดี)
- Overall ยังเหมือนเดิม (Block Buy/Sell)

### 4. Version Bump
- `#property version "2.77"`
- description: `"Golden2 EA v2.7.7 — Squeeze Filter + ADX/EMA/ATR/BB-Breakout multi-confirm"`
- Header comment, OnInit log, Dashboard L_TITLE → `Golden2 EA v2.7.7`

## สิ่งที่ไม่เปลี่ยนแปลง
- ❌ ไม่แตะ `trade.Buy/Sell/PositionClose` หรือ Order execution
- ❌ ไม่แตะ Hedge mirror, Grid Loss/Profit, Triple-Gate, Accumulate, Initial Frame
- ❌ ไม่แตะ `RefreshSqueezeStateThrottled` (ยัง 1 ครั้ง/แท่ง M1 เหมือนเดิม)
- ❌ ไม่แตะ logic ของ `SqueezeBlocksSide` / Per-side block / Directional block
- ❌ ไม่แตะ Entry mode (PENDING/SMA/INSTANT) v2.7.5–v2.7.6
- ✅ เพิ่มเฉพาะตัวกรองชั้นบน → ถ้าทุก confirm ปิด (UseADX/EMA/ATR/BBBreakout=false) จะกลับมาเป็นพฤติกรรมเดิม v2.7.6 100%
- ✅ Backward compatible กับ .set ไฟล์เดิม (input ใหม่มี default แล้ว)

## Memory
- สร้าง `mem://trading/golden2-ea/v2-7-7-squeeze-multi-confirm.md`
- อัปเดต `mem://index.md`
