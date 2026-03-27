

## Fix: Squeeze Direction กลับด้าน — ราคาวิ่งขึ้นแต่แสดง EXPANSION SELL

### สาเหตุ

Direction คำนวณจาก `iClose(_Symbol, g_squeeze[sq].tf, 0)` vs `EMA` — แต่ใน Strategy Tester, `iClose` บน timeframe สูงกว่า (M5, M30) จะคืนค่า close ของ **แท่งเทียนที่สร้างเสร็จล่าสุด** ไม่ใช่ราคาปัจจุบัน ทำให้ตอนกราฟ M1 ดีดขึ้นแล้ว แต่ close ของ M5/M30 ยังเป็นค่าเก่าที่ต่ำกว่า EMA → direction = -1 (SELL) แทนที่จะเป็น 1 (BUY)

### แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. เปลี่ยน Direction calc จาก `iClose` เป็น `SymbolInfoDouble(SYMBOL_BID)`

```cpp
// Direction: Bid vs EMA (for directional block) — v6.10
g_squeeze[sq].direction = 0;
if(g_squeeze[sq].state == 2)
{
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid > ema)
      g_squeeze[sq].direction = 1;   // Bullish
   else if(bid < ema)
      g_squeeze[sq].direction = -1;  // Bearish
   // bid == ema → direction stays 0 (v6.9 safety: won't block anything)
}
```

ใช้ Bid ตรงๆ เพราะเป็นราคาปัจจุบันจริง ไม่ขึ้นกับว่าแท่งเทียน TF ไหนสร้างเสร็จหรือยัง

#### 2. Version bump: v6.9 → v6.10

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic, Trading Strategy Logic, Core Module Logic
- Hedge system ทั้งหมด (Matching/Partial/AvgTP/Grid/Reverse)
- Squeeze Filter logic อื่นๆ (state detection, blocking threshold, CloseOnExpansion)
- Orphan Recovery system

