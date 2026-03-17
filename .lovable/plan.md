

## เพิ่ม Volatility Squeeze Filter ใน Jutlameasu EA (2 Timeframes)

### แนวคิด — ตรงข้ามกับ Gold Miner
- **Gold Miner**: เทรดเฉพาะ Squeeze/Normal → block เมื่อ Expansion
- **Jutlameasu**: เทรดเฉพาะ **Expansion** → block เมื่อ Squeeze/Normal
- เหตุผล: ระบบ Cross-Over Hedging ต้องการการเคลื่อนไหวแรงๆ ไปทิศทางเดียว ถ้า sideways จะเด้งไปเด้งมาเพิ่มความเสี่ยง

### Logic
```text
SQUEEZE  (สีแดง)  = BB อยู่ภายใน KC → BLOCK (ตลาดบีบ ไม่มีทิศทาง)
NORMAL   (สีเขียว) = BB ≈ KC        → BLOCK (sideways ปกติ)
EXPANSION(สีฟ้า)  = BB ทะลุ KC     → ALLOW (มีแนวโน้มแรง → วาง Stop Order ได้)
```

ใช้ 2 Timeframes เท่านั้น (เช่น M15, H1) — ต้องมี Expansion อย่างน้อย N TF จึงจะอนุญาต

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Jutlameasu_EA.mq5`

#### 1. Input Parameters ใหม่ (หลัง News Filter ~line 143)
```cpp
input group "=== Volatility Squeeze Filter ==="
input bool             InpUseSqueezeFilter      = false;
input ENUM_TIMEFRAMES  InpSqueeze_TF1           = PERIOD_M15;
input ENUM_TIMEFRAMES  InpSqueeze_TF2           = PERIOD_H1;
input int              InpSqueeze_BB_Period     = 20;
input double           InpSqueeze_BB_Mult       = 2.0;
input int              InpSqueeze_KC_Period     = 20;
input double           InpSqueeze_KC_Mult       = 1.5;
input int              InpSqueeze_ATR_Period    = 14;
input double           InpSqueeze_ExpThreshold  = 1.5;
input int              InpSqueeze_MinTFExpansion = 1;  // Min TFs in Expansion to ALLOW (1-2)
```

#### 2. Global Variables ใหม่ (~line 219)
```cpp
struct SqueezeState {
   ENUM_TIMEFRAMES tf;
   string          tfLabel;
   int             handleBB;
   int             handleATR;
   int             handleEMA;
   int             state;      // 0=Normal, 1=Squeeze, 2=Expansion
   double          intensity;
};
SqueezeState g_squeeze[2];  // 2 TFs only
bool g_squeezeBlocked = false;
```

#### 3. OnInit — สร้าง indicator handles (~line 287)
สร้าง `iBands`, `iMA(EMA)`, `iATR` สำหรับ 2 TFs

#### 4. OnDeinit — cleanup (~line 300)
`IndicatorRelease()` สำหรับ 6 handles (2 TF × 3 indicators)

#### 5. Helper: `UpdateSqueezeState()` + `TimeframeToString()`
เหมือน Gold Miner แต่วน 2 TFs แทน 3

#### 6. OnTick — Squeeze check (line ~948-951, ก่อน MAIN LOGIC)
```cpp
// เพิ่มหลัง Time Filter check
if(InpUseSqueezeFilter) {
   UpdateSqueezeState();
   // นับ TF ที่เป็น EXPANSION
   int expansionCount = 0;
   for(int i = 0; i < 2; i++)
      if(g_squeeze[i].state == 2) expansionCount++;
   // BLOCK ถ้า Expansion ไม่ถึง threshold
   g_squeezeBlocked = (expansionCount < InpSqueeze_MinTFExpansion);
   if(g_squeezeBlocked) g_newOrderBlocked = true;
}
```

**จุดสำคัญ**: `g_newOrderBlocked` ถูกใช้แล้วใน STATE 1 (line 999) และ STATE 3 (line 1107) เพื่อ block `StartNewCycle()` → ไม่ต้องแตะ trading logic เลย

#### 7. Dashboard — เพิ่ม Squeeze Section (ก่อน Buttons ~line 1661)
```text
=== SQUEEZE FILTER ===
M15  NORMAL     1.15  |#####....|
H1   EXPANSION  2.28  |#########|
Squeeze Status   ALLOWED / BLOCKED
```

- สีแดง = SQUEEZE, สีเขียว = NORMAL, สีฟ้า = EXPANSION
- Status: ALLOWED (มี Expansion เพียงพอ) / BLOCKED (สีแดง)

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.BuyStop, trade.SellStop, trade.PositionClose)
- Trading Strategy Logic (Cross-Over TP/SL, Martingale, Grid Profit, Accumulate Close)
- Core Module Logic (License, News filter, Time filter, Data sync)
- StartNewCycle / PlaceNextPendingOrder logic (ใช้ `g_newOrderBlocked` ที่มีอยู่แล้ว)
- Dashboard layout เดิม (เพิ่มแถวใหม่ต่อท้าย)

