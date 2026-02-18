

## สร้าง EA ใหม่: Gold Miner EA

### แนวคิด

สร้างไฟล์ `public/docs/mql5/Gold_Miner_EA.mq5` ที่เป็น EA สมบูรณ์พร้อม compile ตาม specification ที่ให้มา โดยเป็น Hybrid strategy สำหรับ XAUUSD ที่รวม Scalping + Trend Following + Counter-Trend + Grid/Martingale Recovery

### สิ่งที่จะสร้าง

| ไฟล์ | รายละเอียด |
|------|-----------|
| `public/docs/mql5/Gold_Miner_EA.mq5` | ไฟล์ EA หลักพร้อม compile |

### โครงสร้าง EA

EA จะถูกเขียนเป็นไฟล์เดียวที่รวมทุกอย่าง ตามรูปแบบของ project:

1. **Header + Properties** - ชื่อ, version, copyright
2. **Includes** - `<Trade/Trade.mqh>`
3. **Custom Enum** - `ENUM_LOT_MODE` (FIXED_LOT, RISK_PERCENTAGE, RECOVERY_MARTINGALE)
4. **Input Parameters** ทั้งหมดตาม spec:
   - General Settings (MagicNumber, MaxSlippage, MaxOpenOrders, MaxDrawdown)
   - Trading Time Filters (UTC hours/days)
   - Lot Sizing & Money Management (3 modes + Recovery settings)
   - Indicator Settings (RSI, EMA, ATR, MACD, Bollinger Bands)
   - Entry Logic Thresholds
   - Exit Logic Thresholds (Scalp, Breakeven, Trailing, MaxHolding)
   - Grid/Recovery Settings
5. **Global Variables**
   - Indicator handles (int) สร้างใน OnInit
   - Buffers (double arrays) สำหรับ CopyBuffer
   - Order tracking structures
6. **OnInit()** - สร้าง indicator handles ทั้งหมด
7. **OnDeinit()** - ปล่อย handles
8. **OnTick()** - Main logic loop
9. **Helper Functions:**
   - `CalculateIndicators()` - CopyBuffer ทุก indicator
   - `CheckBuyEntry()` / `CheckSellEntry()` - ตรวจสอบ entry conditions
   - `CalculateLotSize()` - 3 modes
   - `ManageOpenPositions()` - Breakeven, Trailing, Time-based exit
   - `CheckDrawdownExit()` - Emergency close all
   - `ManageHedging()` - จัดการ opposing positions
   - `ManageGridRecovery()` - Grid/Martingale logic

### หลักการสำคัญที่จะปฏิบัติตาม

- **Indicator handles** สร้างใน OnInit เท่านั้น ไม่สร้างใน OnTick
- **CopyBuffer** ใช้ดึงค่า indicator ทุกครั้งใน OnTick
- **ArraySetAsSeries** ก่อน CopyBuffer เสมอ
- **ไม่ใช้ switch/case** ที่ประกาศตัวแปรข้าม case โดยไม่มี braces
- **CTrade class** สำหรับ order operations
- **Internal SL/TP** - ไม่ set SL/TP ตอน OrderSend แต่จัดการเองใน OnTick
- **ไม่ใช้ goto** ใช้ boolean flags แทน

### รายละเอียดทางเทคนิค

**Entry Logic Flow:**

```text
OnTick()
  → ตรวจสอบ new bar (ไม่คำนวณทุก tick)
  → CalculateIndicators()
  → CheckTimeFilter()
  → CheckDrawdownExit()
  → ManageOpenPositions() (Breakeven, Trailing, Time exit, Max loss)
  → ManageHedging()
  → CheckBuyEntry() → OpenBuy with CalculateLotSize()
  → CheckSellEntry() → OpenSell with CalculateLotSize()
  → ManageGridRecovery()
```

**Order Tracking Structure:**

```text
struct OrderInfo {
    ulong ticket;
    int type;           // 0=Buy, 1=Sell
    double entryPrice;
    double internalSL;
    double internalTP;
    datetime openTime;
    double lotSize;
    bool trailingActive;
    int recoveryStep;
};
```

**Lot Sizing - Recovery/Martingale:**
- นับจำนวน consecutive losses ในทิศทางเดียวกัน
- `recovery_lot = base_lot * pow(RecoveryMultiplier, consecutive_losses)`
- จำกัดไม่เกิน `RecoveryMaxSteps`
- จำกัดไม่เกิน `SymbolInfoDouble(SYMBOL_VOLUME_MAX)`

**Indicator Handles ที่จะสร้าง:**
- `iRSI(_Symbol, PERIOD_M15, RSIPeriod, RSIAppliedPrice)`
- `iMA(_Symbol, PERIOD_M15, EMA_FastPeriod, 0, MODE_EMA, EMAAppliedPrice)`
- `iMA(_Symbol, PERIOD_M15, EMA_SlowPeriod, 0, MODE_EMA, EMAAppliedPrice)`
- `iATR(_Symbol, PERIOD_M15, ATRPeriod)`
- `iMACD(_Symbol, PERIOD_M15, MACDFastPeriod, MACDSlowPeriod, MACDSignalPeriod, MACDAppliedPrice)`
- `iBands(_Symbol, PERIOD_M15, BBPeriod, 0, BBDeviation, BBAppliedPrice)`

