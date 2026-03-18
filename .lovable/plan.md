

## เพิ่ม Max Lot Size ใน Gold Miner SQ EA (v4.1 → v4.2)

### แนวคิด
เพิ่ม input parameter `InpMaxLotSize` เพื่อจำกัดขนาด Lot สูงสุดที่ EA จะเปิดได้ ป้องกันไม่ให้ Grid Martingale ขยาย Lot จนเกินที่ผู้ใช้ต้องการ

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Input Parameter ใหม่ (หลัง InitialLotSize ~line 116)
```cpp
input double   InpMaxLotSize      = 0.0;      // Max Lot Size (0=No Limit)
```
ค่า 0 = ไม่จำกัด (ใช้ broker max), ค่า > 0 = จำกัดตามที่ตั้ง

#### 2. แก้ OpenOrder() (~line 1298-1300)
เพิ่ม user max lot cap ก่อน normalize:
```cpp
double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
if(InpMaxLotSize > 0) maxLot = MathMin(maxLot, InpMaxLotSize);
```
จุดนี้เป็นจุดเดียวที่ทุกออเดอร์ผ่าน → ครอบคลุมทั้ง Initial, Grid Loss, Grid Profit

#### 3. Version bump: v4.1 → v4.2
- `#property version "4.20"`
- `#property description` → v4.2
- Header comment → v4.2
- Dashboard display → v4.2

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell ไม่เปลี่ยน — แค่ cap ค่า lot ก่อนส่ง)
- Trading Strategy Logic (SMA/ZigZag/Instant signals, Grid calculations, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync, Squeeze filter)
- Matching Close / Accumulate / Drawdown logic

