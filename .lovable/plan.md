

## Fix: Squeeze Directional Block แสดง "BLOCKED ALL" ทั้งที่ตั้ง DirectionalBlock = true

### ปัญหาที่พบ

จากภาพ Dashboard แสดง:
- M5/M15/M30 ล้วนแสดง **"EXPANSION"** (ไม่มี BUY หรือ SELL)
- Squeeze Status: **BLOCKED ALL** (สีแดง)
- ทั้งที่ตั้ง **Directional Block = true** ในตัวเลือก

### สาเหตุ

`g_squeeze[sq].direction` เป็น **0** ทั้ง 3 TF ทำให้ `bestDir = 0`:

```text
Line 1145: if(InpSqueeze_DirectionalBlock && bestDir != 0)
                                             ^^^^^^^^^^^
                                             bestDir == 0 → FALSE
                                             → ตกไป else → BLOCK ALL!
```

Direction คำนวณจาก `iClose vs EMA` (line 8536-8540) — ใน Strategy Tester บาง tick ราคา close กับ EMA อาจเท่ากันพอดี หรือข้อมูล multi-timeframe ไม่ sync ทำให้ direction ไม่ถูกกำหนด

### แก้ไข — 2 จุด

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Direction fallback ใน `UpdateSqueezeState()`

เมื่อ `closePrice == ema` (direction ยังเป็น 0) → ใช้ **Bid vs EMA** เป็น fallback:

```cpp
// Direction: Close vs EMA (for directional block)
g_squeeze[sq].direction = 0;
if(g_squeeze[sq].state == 2)
{
   double closePrice = iClose(_Symbol, g_squeeze[sq].tf, 0);
   if(closePrice > ema)
      g_squeeze[sq].direction = 1;
   else if(closePrice < ema)
      g_squeeze[sq].direction = -1;
   else
   {
      // Fallback: use current Bid vs EMA
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      if(bid > ema)      g_squeeze[sq].direction = 1;
      else if(bid < ema) g_squeeze[sq].direction = -1;
   }
}
```

#### 2. Safety fallback ใน Directional Block logic

เมื่อ `InpSqueeze_DirectionalBlock = true` แต่ `bestDir` ยังเป็น 0 → **ไม่บล็อกเลย** (แทนที่จะบล็อกทุกอย่าง):

```cpp
if(expCount >= InpSqueeze_MinTFExpansion)
{
   if(InpSqueeze_DirectionalBlock)
   {
      if(bestDir == 1)
         g_squeezeSellBlocked = true;
      else if(bestDir == -1)
         g_squeezeBuyBlocked = true;
      // bestDir == 0 → ไม่บล็อกเลย (ไม่รู้ทิศทาง จะไม่ block ทั้งหมด)
   }
   else
   {
      g_squeezeBlocked = true;
      g_newOrderBlocked = true;
   }
   // ... CloseOnExpansion logic unchanged ...
}
```

#### 3. Version bump: v6.8 → v6.9

---

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge system logic ทั้งหมด (Matching/Partial/AvgTP/Grid/Reverse)
- Orphan Recovery system
- Squeeze Filter เมื่อ DirectionalBlock = false ยังทำงานเหมือนเดิม 100%

