

## เพิ่ม Volatility Squeeze Filter (BB vs KC) ใน Gold Miner EA

### แนวคิด
ใช้หลักการ **Bollinger Bands Squeeze** — เปรียบเทียบความกว้างของ Bollinger Bands กับ Keltner Channels เพื่อแบ่งสถานะตลาดเป็น 3 ระดับ:

```text
SQUEEZE  (สีแดง)  = BB อยู่ภายใน KC → ตลาดบีบตัว (sideways จัด)
NORMAL   (สีเขียว) = BB กับ KC ไล่เลี่ยกัน → sideways ปกติ  
EXPANSION(สีฟ้า)  = BB ทะลุออกนอก KC → กำลังเลือกทาง/เทรนด์แรง
```

จากข้อมูลออนไลน์ (MQL5 community) วิธีนี้เป็นมาตรฐานที่ดีที่สุดในการตรวจจับ sideways vs breakout — ใช้กันแพร่หลายในชื่อ "TTM Squeeze" / "Bollinger Squeeze"

### เพิ่ม Intensity Ratio
นอกจากสถานะ 3 แบบ ยังคำนวณ **Intensity = BB Width / KC Width** เพื่อแสดงระดับความรุนแรง:
- Intensity < 1.0 = Squeeze (BB แคบกว่า KC)
- Intensity ≈ 1.0 = Normal
- Intensity > Expansion Threshold (เช่น 1.5) = Expansion

### Timeframes ที่สแกน
ตาม dashboard ในรูป: **M5, H1, H4** — สแกน 3 timeframes พร้อมกัน

### การใช้เป็น Filter
- เมื่อเปิดใช้งาน → EA จะ **block new orders** เฉพาะเมื่อ **Expansion** ถูกตรวจพบ (ตลาดมีแนวโน้มแรง ไม่ใช่ sideways)
- SQUEEZE + NORMAL = อนุญาตให้เทรด (เป็นสภาวะ sideways ที่ EA ต้องการ)
- ใช้ `g_newOrderBlocked = true` เหมือน News/Time filter — ไม่แตะ trading logic

---

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Input Parameters ใหม่
```text
input group "=== Volatility Squeeze Filter ==="
input bool             InpUseSqueezeFilter     = false;          // Enable Squeeze Filter
input ENUM_TIMEFRAMES  InpSqueeze_TF1          = PERIOD_M5;      // Timeframe 1
input ENUM_TIMEFRAMES  InpSqueeze_TF2          = PERIOD_H1;      // Timeframe 2
input ENUM_TIMEFRAMES  InpSqueeze_TF3          = PERIOD_H4;      // Timeframe 3
input int              InpSqueeze_BB_Period    = 20;              // BB Period
input double           InpSqueeze_BB_Mult      = 2.0;             // BB Multiplier
input int              InpSqueeze_KC_Period    = 20;              // KC Period (EMA)
input double           InpSqueeze_KC_Mult      = 1.5;             // KC Multiplier (ATR)
input int              InpSqueeze_ATR_Period   = 14;              // ATR Period for KC
input double           InpSqueeze_ExpThreshold = 1.5;             // Expansion Threshold (Intensity)
input bool             InpSqueeze_BlockOnExpansion = true;        // Block New Orders on Expansion
input int              InpSqueeze_MinTFExpansion = 1;             // Min TFs in Expansion to Block (1-3)
```

#### 2. Global Variables ใหม่
```text
// Squeeze Filter State
struct SqueezeState {
   ENUM_TIMEFRAMES tf;
   string          tfLabel;
   int             handleBB;       // iBands handle
   int             handleATR;      // iATR handle  
   int             handleEMA;      // iMA handle (for KC center)
   int             state;          // 0=Normal, 1=Squeeze, 2=Expansion
   double          intensity;      // BB_Width / KC_Width
};
SqueezeState g_squeeze[3];
```

#### 3. OnInit — สร้าง indicator handles
สำหรับแต่ละ TF:
- `iBands(_Symbol, tf, BB_Period, 0, BB_Mult, PRICE_CLOSE)` — Bollinger Bands
- `iMA(_Symbol, tf, KC_Period, 0, MODE_EMA, PRICE_CLOSE)` — KC center (EMA)
- `iATR(_Symbol, tf, ATR_Period)` — สำหรับ KC bands

#### 4. Helper Function: `UpdateSqueezeState()`
ทุก tick (หรือ new bar ของแต่ละ TF):
```text
สำหรับแต่ละ TF:
  1. CopyBuffer เอาค่า BB Upper/Lower, EMA, ATR
  2. BB Width = Upper BB - Lower BB
  3. KC Upper = EMA + KC_Mult × ATR
  4. KC Lower = EMA - KC_Mult × ATR  
  5. KC Width = KC Upper - KC Lower
  6. Intensity = BB Width / KC Width
  7. ถ้า Upper BB < Upper KC AND Lower BB > Lower KC → SQUEEZE
     ถ้า Intensity > ExpThreshold → EXPANSION
     อื่นๆ → NORMAL
```

#### 5. OnTick — เพิ่ม Squeeze check (ก่อน trading logic)
```text
if(InpUseSqueezeFilter) {
   UpdateSqueezeState();
   if(InpSqueeze_BlockOnExpansion) {
      int expansionCount = นับจำนวน TF ที่เป็น EXPANSION;
      if(expansionCount >= InpSqueeze_MinTFExpansion)
         g_newOrderBlocked = true;
   }
}
```

#### 6. Dashboard — เพิ่ม Squeeze Section
แสดงตารางแนวตั้งต่อจาก section เดิม:
```text
=== SQUEEZE FILTER ===
M5   NORMAL     1.44 X |████████    .|
H1   NORMAL     1.24 X |███████  .. |
H4   SQUEEZE    0.91 X |██████....  |
```

แต่ละ TF แสดง: State (สี), Intensity, Progress Bar (ใช้ character art "|████..|")
- สีแดง = SQUEEZE
- สีเขียว = NORMAL  
- สีฟ้า = EXPANSION

#### 7. OnDeinit — cleanup handles
`IndicatorRelease()` สำหรับทุก handle ที่สร้าง

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (การเปิด/ปิดออเดอร์)
- Trading Strategy Logic (SMA/ZigZag/Instant entry, Grid, TP/SL, Trailing, Accumulate, Drawdown)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Matching Close logic
- Dashboard layout เดิม (เพิ่มแถวใหม่ต่อท้าย)

