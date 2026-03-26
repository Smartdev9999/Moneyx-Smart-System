

## แก้ไขแผน: TP แบบ % ของ Max DD — Gold Miner EA v6.6 → v6.7

### หลักการที่ถูกต้อง (แก้ไขแล้ว)

**เดิม (ผิด):** ปิดเมื่อ PL ฟื้นตัวจากจุดต่ำสุด → อาจปิดขาดทุนอยู่
**ใหม่ (ถูก):** ใช้ Max DD เป็นตัวกำหนด **เป้ากำไร** → ปิดเมื่อ PL เป็น **บวก** เสมอ

```text
ตัวอย่าง:
  Buy 10 orders → ลากลงไปลบสูงสุด -$500 (นี่คือ Max DD)
  ตั้ง TP_DDPercent = 10%
  เป้ากำไร = 10% × $500 = +$50

  เมื่อราคาตีกลับ → floating PL ของฝั่ง Buy = +$50
  → ปิดทุก order ฝั่ง Buy → ได้กำไร +$50

  *** ทุกครั้งที่ปิดจะต้องปิดบวกเสมอ ***
```

---

### ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Input Parameters ใหม่
```cpp
input bool     UseTP_DDPercent = false;  // Use TP % of Max Drawdown
input double   TP_DDPercent    = 10.0;   // TP DD % (profit target = X% of max DD)
```

#### 2. Global Variables
```cpp
double g_maxDDBuy;   // Max drawdown (most negative) of BUY side
double g_maxDDSell;  // Max drawdown (most negative) of SELL side
```
Reset เป็น 0 ใน OnInit และเมื่อปิดชุดฝั่งนั้นหมด

#### 3. OnTick — Track Max DD ทุก tick
```cpp
double plBuy = CalculateFloatingPL(POSITION_TYPE_BUY);
if(plBuy < g_maxDDBuy) g_maxDDBuy = plBuy;  // เก็บค่าลบสูงสุด
```

#### 4. ManageTPSL — TP Check (หลักการใหม่)
```cpp
if(UseTP_DDPercent && g_maxDDBuy < 0)
{
   double tpTarget = MathAbs(g_maxDDBuy) * TP_DDPercent / 100.0;
   // ปิดเมื่อ PL เป็นบวกและ >= เป้ากำไร
   if(plBuy >= tpTarget && plBuy > 0)
      closeTP = true;
}
```

**จุดสำคัญ:** เช็ค `plBuy > 0` เพิ่มเพื่อรับประกันว่าปิดบวกเสมอ  
เช่น DD = -$500, 10% → tpTarget = $50 → ปิดเมื่อ floating PL ≥ +$50

#### 5. Reset เมื่อปิดชุด
เมื่อ close all buy → `g_maxDDBuy = 0`  
เมื่อ close all sell → `g_maxDDSell = 0`

#### 6. Dashboard แสดงสถานะ
```text
DD% TP Buy: MaxDD=-$500 | Target=+$50 | Current=+$32
```

#### 7. Version bump: v6.6 → v6.7

---

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge system logic ทั้งหมด (Matching/Partial/AvgTP/Grid/Reverse)
- Orphan Recovery system
- TP/SL เดิมทั้งหมด (Dollar, Points, %Balance, Accumulate) ยังทำงานเหมือนเดิม

