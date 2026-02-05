

## แผนอัปเดต Harmony Dream EA v2.2.9 - Progressive ATR Distance Mode

---

### สรุปปัญหาปัจจุบัน

| สถานการณ์ | ค่าที่ใช้ปัจจุบัน | ค่าที่ต้องการ |
|-----------|------------------|---------------|
| Initial → GL#1 | ATR × 3 = 100 pips | 100 pips |
| GL#1 → GL#2 | ATR × 3 = 100 pips | 100 × 3 = 300 pips |
| GL#2 → GL#3 | ATR × 3 = 100 pips | 300 × 3 = 900 pips |

**สาเหตุ:** `CalculateGridDistance()` คืนค่าคงที่ `ATR × Multiplier` ทุก Level โดยไม่คำนึงถึง Grid Level ปัจจุบัน

---

### โซลูชัน: เพิ่ม Progressive Distance Option

เพิ่มตัวเลือกให้ผู้ใช้เลือกระหว่าง:
1. **Fixed Distance** (เหมือนปัจจุบัน): ทุก Level ใช้ระยะห่างเท่ากัน
2. **Progressive Distance** (ใหม่): ระยะห่างเพิ่มขึ้นแบบ Exponential ตาม Multiplier

---

### การแก้ไขทั้งหมด

#### Part A: อัปเดต Version

**ไฟล์:** `public/docs/mql5/Harmony_Dream_EA.mq5`

```cpp
#property version   "2.29"
#property description "v2.2.9: Add Progressive ATR Distance Mode for Grid"
```

---

#### Part B: เพิ่ม Enum สำหรับ Distance Scaling Mode

**ตำแหน่ง:** หลัง `ENUM_GRID_DISTANCE_MODE`

```cpp
//+------------------------------------------------------------------+
//| GRID DISTANCE SCALING MODE (v2.2.9)                                |
//+------------------------------------------------------------------+
enum ENUM_GRID_DIST_SCALE
{
   GRID_SCALE_FIXED = 0,       // Fixed (Same Distance Every Level)
   GRID_SCALE_PROGRESSIVE      // Progressive (Distance × Mult Each Level)
};
```

---

#### Part C: เพิ่ม Input Parameters

**Grid Loss Settings:**
```cpp
input group "=== Grid Loss Side Settings (v1.6) ==="
input bool     InpEnableGridLoss = true;
input ENUM_GRID_DISTANCE_MODE InpGridLossDistMode = GRID_DIST_ATR;
input ENUM_GRID_DIST_SCALE    InpGridLossDistScale = GRID_SCALE_FIXED;  // v2.2.9: Distance Scaling Mode
```

**Grid Profit Settings:**
```cpp
input group "=== Grid Profit Side Settings (v1.6) ==="
input bool     InpEnableGridProfit = false;
input ENUM_GRID_DISTANCE_MODE InpGridProfitDistMode = GRID_DIST_ATR;
input ENUM_GRID_DIST_SCALE    InpGridProfitDistScale = GRID_SCALE_FIXED;  // v2.2.9: Distance Scaling Mode
```

---

#### Part D: อัปเดต `CalculateGridDistance()` Function

**แก้ไข function signature เพิ่ม 2 parameters:**
```cpp
double CalculateGridDistance(int pairIndex, ENUM_GRID_DISTANCE_MODE mode, 
                              ENUM_GRID_DIST_SCALE scaleMode,  // v2.2.9: NEW
                              int gridLevel,                    // v2.2.9: NEW (0-based)
                              double atrMultForex, double atrMultGold, double minDistPips,
                              double fixedPoints, double fixedPips,
                              ENUM_TIMEFRAMES atrTimeframe, int atrPeriod,
                              bool isProfitSide = false)
```

**แก้ไข ATR calculation logic:**
```cpp
case GRID_DIST_ATR:
{
   // Get cached ATR based on side
   double atr = isProfitSide ? g_pairs[pairIndex].cachedGridProfitATR 
                             : g_pairs[pairIndex].cachedGridLossATR;
   
   if(atr <= 0)
   {
      atr = CalculateSimplifiedATR(symbolA, atrTimeframe, atrPeriod);
      if(isProfitSide)
         g_pairs[pairIndex].cachedGridProfitATR = atr;
      else
         g_pairs[pairIndex].cachedGridLossATR = atr;
   }
   
   double mult = IsGoldPair(symbolA) ? atrMultGold : atrMultForex;
   
   // v2.2.9: Apply Progressive Scaling
   double baseDistance = atr * mult;
   double finalDistance = baseDistance;
   
   if(scaleMode == GRID_SCALE_PROGRESSIVE && gridLevel > 0)
   {
      // Progressive formula: distance = base × mult^level
      finalDistance = baseDistance * MathPow(mult, gridLevel);
   }
   
   double minDistance = minDistPips * pipSize;
   return MathMax(finalDistance, minDistance);
}
```

---

#### Part E: อัปเดต `CheckGridLossForSide()`

```cpp
void CheckGridLossForSide(int pairIndex, string side)
{
   if(InpGridLossDistMode == GRID_DIST_ZSCORE)
   {
      CheckGridLossZScore(pairIndex, side);
   }
   else
   {
      // v2.2.9: Get current grid level for progressive calculation
      int gridLevel = (side == "BUY") ? g_pairs[pairIndex].avgOrderCountBuy 
                                      : g_pairs[pairIndex].avgOrderCountSell;
      
      double gridDist = CalculateGridDistance(pairIndex, InpGridLossDistMode,
                                               InpGridLossDistScale,  // v2.2.9
                                               gridLevel,              // v2.2.9
                                               InpGridLossATRMultForex,
                                               InpGridLossATRMultGold,
                                               InpGridLossMinDistPips,
                                               InpGridLossFixedPoints,
                                               InpGridLossFixedPips,
                                               InpGridLossATRTimeframe,
                                               InpGridLossATRPeriod,
                                               false);
      if(gridDist <= 0) return;
      
      CheckGridLossPrice(pairIndex, side, gridDist);
   }
}
```

---

#### Part F: อัปเดต `CheckGridProfitForSide()`

```cpp
void CheckGridProfitForSide(int pairIndex, string side)
{
   if(InpGridProfitDistMode == GRID_DIST_ZSCORE)
   {
      CheckGridProfitZScore(pairIndex, side);
   }
   else
   {
      // v2.2.9: Get current grid level for progressive calculation
      int gridLevel = (side == "BUY") ? g_pairs[pairIndex].gridProfitCountBuy 
                                      : g_pairs[pairIndex].gridProfitCountSell;
      
      double gridDist = CalculateGridDistance(pairIndex, InpGridProfitDistMode,
                                               InpGridProfitDistScale,  // v2.2.9
                                               gridLevel,                // v2.2.9
                                               InpGridProfitATRMultForex,
                                               InpGridProfitATRMultGold,
                                               InpGridProfitMinDistPips,
                                               InpGridProfitFixedPoints,
                                               InpGridProfitFixedPips,
                                               InpGridProfitATRTimeframe,
                                               InpGridProfitATRPeriod,
                                               true);
      if(gridDist <= 0) return;
      
      CheckGridProfitPrice(pairIndex, side, gridDist);
   }
}
```

---

### Backtest/Live Parity Verification

| ตัวแปร | วิธี Restore | ผลลัพธ์ |
|--------|-------------|---------|
| `avgOrderCountBuy/Sell` | นับ `_GL` orders จาก comment | Grid Level ถูกต้องหลัง restart |
| `gridProfitCountBuy/Sell` | นับ `_GP` orders จาก comment | Grid Level ถูกต้องหลัง restart |
| `lastAvgPrice/lastProfitPrice` | ดึงจาก open price ของ order ล่าสุด | ระยะห่างคำนวณถูกต้อง |

**สรุป:** ระบบ `RestoreOpenPositions()` ที่มีอยู่จะ restore grid level ได้ถูกต้อง ทำให้ Progressive Mode ทำงานเหมือนกันทั้ง Backtest และ Live

---

### สรุปไฟล์ที่แก้ไข

| ไฟล์ | ส่วนที่แก้ไข | รายละเอียด |
|------|-------------|------------|
| `Harmony_Dream_EA.mq5` | Version | อัปเดตเป็น v2.29 |
| `Harmony_Dream_EA.mq5` | Enum | เพิ่ม `ENUM_GRID_DIST_SCALE` |
| `Harmony_Dream_EA.mq5` | Inputs | เพิ่ม `InpGridLossDistScale` และ `InpGridProfitDistScale` |
| `Harmony_Dream_EA.mq5` | `CalculateGridDistance()` | เพิ่ม `scaleMode` และ `gridLevel` parameters + Progressive logic |
| `Harmony_Dream_EA.mq5` | `CheckGridLossForSide()` | ส่ง `gridLevel` และ `scaleMode` |
| `Harmony_Dream_EA.mq5` | `CheckGridProfitForSide()` | ส่ง `gridLevel` และ `scaleMode` |

---

### ตัวอย่างการทำงาน Progressive Mode

**Settings:**
- ATR = 33 pips
- ATR Multiplier = 3
- Distance Scaling = **Progressive**

**Grid Loss:**
```text
Level 0 (Initial → GL#1): 33 × 3 = 100 pips
Level 1 (GL#1 → GL#2):    100 × 3 = 300 pips  
Level 2 (GL#2 → GL#3):    100 × 3² = 900 pips
Level 3 (GL#3 → GL#4):    100 × 3³ = 2,700 pips
```

**Grid Profit:**
```text
Level 0 (Entry → GP#1):   33 × 3 = 100 pips
Level 1 (GP#1 → GP#2):    100 × 3 = 300 pips
Level 2 (GP#2 → GP#3):    100 × 3² = 900 pips
```

---

### หมายเหตุสำคัญ

1. **Default = Fixed**: ค่าเริ่มต้นเป็น "Fixed" เพื่อให้ระบบทำงานเหมือนเดิม
2. **สูตร Progressive**: `finalDistance = baseDistance × mult^level`
3. **Minimum Distance**: ยังคงใช้ fallback minimum เหมือนเดิม
4. **แยก Grid Loss/Profit**: สามารถตั้งค่า Scaling Mode แยกอิสระได้
5. **รองรับทุก Distance Mode**: Progressive ทำงานกับ ATR, Fixed Points, และ Fixed Pips

