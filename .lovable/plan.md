
# Gold Miner EA v6.91 — Strict 2-Cross ARM สำหรับ Max Grid Trailing Stop

## เข้าใจเจตนาของฟีเจอร์ (สรุปจากที่ user อธิบาย)

`Max Grid Trailing Stop` ไม่ใช่ trailing ปกติ — มันคือ **safety net สำหรับ basket ที่ติดลึก** เมื่อ:
1. ออก grid order ครบจำนวนที่กำหนด (`MaxGrid_StartOrders` หรือ `GridLoss_MaxTrades`)
2. ราคาวิ่งสวนไปไกลจน Average TP ปกติทำงานไม่ได้
3. **แล้ววันหนึ่งราคาดีดกลับมาผ่านเส้น avg** → basket กลับมาเป็นบวก
4. รอราคาวิ่งต่อไปอีกจน "ผ่าน avg + activation" → **ARM**
5. ราคาย่อกลับมาแตะ trailing SL → **ปิด basket**
6. ต้องอยู่ในสถานะ Normal (Squeeze ไม่ pause) → กันไม่ให้ทำซ้ำซ้อนกับ Avg TP/SL ปกติ

## ปัญหาปัจจุบัน (v6.90)

โค้ดที่ line 3537-3590 (BUY) และ 3592-3645 (SELL):

```cpp
if(glCount >= requiredOrders_Buy)              // Gate: count ถึง
{
   if(!g_maxGridTrailActive_Buy) {
      if(bid >= activationPrice)               // ARM ทันทีถ้าผ่าน activation
         g_maxGridTrailActive_Buy = true;
   }
}
```

**ขาดเงื่อนไข "ราคาเคยอยู่ใต้ avg มาก่อน"** → ผลคือ:

- กรณี A (ปกติ basket ติด): ราคาตกใต้ avg → count ถึงเกณฑ์ → ราคาดีดกลับ → cross avg ขึ้น → ผ่าน activation → ARM ✅ ถูกต้อง
- กรณี B (ปัญหา): basket BUY ที่ราคาวิ่งขึ้นตลอด แต่ count ครบ (จาก _GP มาก) → ราคาอยู่เหนือ activation อยู่แล้ว → **ARM ทันทีตอน gate เปิด** → trailing SL วางใต้ราคาแค่ TrailStep → ราคาย่อนิดเดียวก็ปิด ❌

User ต้องการให้ **บังคับ cross 2 ขาเสมอ**: ลงใต้ avg ก่อน → ขึ้นเหนือ activation → ARM

## แผนแก้ไข v6.91

### 1. เพิ่ม state ติดตาม "ผ่าน avg ไปฝั่งขาดทุน"

```cpp
// ต่อ generation, ต่อ side: เคย "ลึกเกิน avg" ในรอบ monitor นี้หรือยัง
bool   g_maxGridArmReady_Buy[100]  = {false};
bool   g_maxGridArmReady_Sell[100] = {false};
```

หรือ simple version: 2 ตัวแปร global (เพราะ monitor ทีละ gen):
```cpp
bool g_maxGridArmReady_Buy  = false;
bool g_maxGridArmReady_Sell = false;
int  g_maxGridArmReadyGen   = -1;   // gen ที่ state นี้อ้างถึง
```

### 2. Logic ใหม่ใน `ManageMaxGridTrailing()`

**ฝั่ง BUY** (เปลี่ยน line 3537-3590):
```cpp
if(glCount >= requiredOrders_Buy)
{
   double avgPrice = CalcGenAveragePrice(gen, POSITION_TYPE_BUY);
   if(avgPrice > 0)
   {
      // [v6.91] รีเซ็ต armReady ถ้าเปลี่ยน gen
      if(g_maxGridArmReadyGen != gen) {
         g_maxGridArmReady_Buy  = false;
         g_maxGridArmReady_Sell = false;
         g_maxGridArmReadyGen   = gen;
      }

      // [v6.91] STEP 1: ราคาต้องเคย <= avg (basket ติดจริง) ก่อน ARM ได้
      double underThreshold = avgPrice - InpMaxGridArm_UnderAvgBuffer * point;
      if(!g_maxGridArmReady_Buy && bid <= underThreshold) {
         g_maxGridArmReady_Buy = true;
         Print("v6.91 MaxGridTrail BUY ARM-READY: Gen=", gen,
               " bid=", bid, " <= avgUnder=", underThreshold);
      }

      double activationPrice = avgPrice + MaxGrid_TrailActivation * point;

      if(!g_maxGridTrailActive_Buy)
      {
         // [v6.91] STEP 2: ARM ก็ต่อเมื่อ armReady=true AND ราคาผ่าน activation
         if(g_maxGridArmReady_Buy && bid >= activationPrice) {
            g_maxGridTrailActive_Buy = true;
            g_maxGridTrailSL_Buy = avgPrice + MaxGrid_BreakevenBuffer * point;
            Print("v6.91 MaxGridTrail BUY ACTIVATED: Gen=", gen,
                  " AvgPrice=", avgPrice, " SL=", g_maxGridTrailSL_Buy,
                  " count=", glCount, " (2-cross confirmed)");
         }
      }
      else
      {
         // ... trailing SL + close logic เหมือนเดิม (ไม่แตะ)
      }
   }
}
else
{
   // count ไม่ถึง → reset ทุกอย่าง รวม armReady
   g_maxGridTrailActive_Buy = false;
   g_maxGridTrailSL_Buy = 0;
   g_maxGridArmReady_Buy = false;
}
```

**ฝั่ง SELL**: mirror เหมือนกัน (`bid` → `ask`, `<=` → `>=`, `+` ↔ `-`)

### 3. เพิ่ม Input parameter

```cpp
input string ___MaxGrid_2Cross___ = "===== Max Grid Trail 2-Cross ARM (v6.91) =====";
input bool   InpMaxGridArm_Strict2Cross    = true;   // v6.91: บังคับ ARM แบบ 2-cross (false = เก่า)
input int    InpMaxGridArm_UnderAvgBuffer  = 0;      // v6.91: points ใต้ avg ที่ถือว่า "ติด" (0 = แตะ avg พอ)
```

ถ้า `InpMaxGridArm_Strict2Cross = false` → ใช้ logic v6.90 เดิม (backward compat)

### 4. Reset state ใน OnInit/OnDeinit + เมื่อปิด gen

- เพิ่ม `g_maxGridArmReady_Buy = false; g_maxGridArmReady_Sell = false; g_maxGridArmReadyGen = -1;` ใน OnInit (~line 9248)
- หลัง `CloseGenSide(gen, POSITION_TYPE_BUY)` ใน trail-hit branch → reset `g_maxGridArmReady_Buy = false`
- ใน `Squeeze pause strip` v6.89 → reset armReady ด้วย (กัน state ค้าง)

### 5. Dashboard

เพิ่มแถวแสดงสถานะ ARM-READY ใน MaxTrail panel (~line 4812):
```
MG BUY Trail   | READY (waiting cross-up)   | สีเหลือง
MG BUY Trail   | ACTIVE SL=xxxx              | สีเขียว
```

### 6. Versioning

- `#property version "6.91"`
- `#property description` เพิ่มบรรทัด v6.91
- Header comment block, Dashboard headerVersion ทุก mode (INST/SMA/ZZ)
- OnInit/OnDeinit log

## สิ่งที่ไม่เปลี่ยน (ยืนยันไม่กระทบ trading logic)

- ❌ ไม่แตะ `OrderSend` / `trade.Buy/Sell/PositionClose`
- ❌ ไม่แตะ Strategy entry (SMA/INSTANT/ZZ signal)
- ❌ ไม่แตะ Grid Loss/Profit entry logic, lot calc, spacing
- ❌ ไม่แตะ Hedge trigger/release/Triple-Gate/Matching
- ❌ ไม่แตะ Average TP / DD% TP / Daily Target / Balance Guard
- ❌ ไม่แตะ Per-order trailing / TF trailing
- ❌ ไม่แตะ `CalcGenAveragePrice` / `CountGenGridAll` / `CloseGenSide` (v6.86, v6.90)
- ❌ ไม่แตะ Squeeze Pause Trailing v6.87-89 (gate ที่ line 3167 ยังครอบเหมือนเดิม)
- ❌ ไม่แตะ License / News / Time / Sync modules
- ✅ แตะเฉพาะ "เงื่อนไข ARM" ใน `ManageMaxGridTrailing()` — trailing SL movement + close logic ยังเหมือนเดิม 100%

## ไฟล์ที่แก้

- `public/docs/mql5/Gold_Miner_EA.mq5`
- `.lovable/memory/trading/gold-miner-ea/maxgrid-trail-strict-2cross-v6-91.md` (new)
- `.lovable/memory/index.md` (เพิ่ม 1 บรรทัด)

## พฤติกรรมหลังแก้ (สรุปสำหรับ user)

```text
[Count ถึงเกณฑ์]
        |
        v
[STEP 1: รอราคา cross ลงใต้ avg]  <-- ใหม่ใน v6.91
        |
        v
[ARM-READY = true]
        |
        v
[STEP 2: รอราคาดีดกลับ ผ่าน avg + activation]
        |
        v
[ARM] -> วาง trailing SL ที่ avg + breakeven
        |
        v
[Trailing SL เลื่อนตามราคา] (Squeeze ต้อง = Normal)
        |
        v
[ราคาย่อแตะ SL] -> CloseGenSide -> reset armReady
```

ถ้าราคาวิ่งฝั่งบวกตลอดไม่เคยลงใต้ avg → **จะไม่ ARM เลย** → Avg TP ปกติทำหน้าที่ปิดแทน (ตามเจตนา user: "กันซ้ำซ้อนกับ Avg TP/SL")
