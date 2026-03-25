

## Fix: Grid หยุดทำงานหลังเปลี่ยน Parameter กลางคัน — Gold Miner SQ EA (v6.4 → v6.5)

### สาเหตุของปัญหา

เมื่อผู้ใช้เปลี่ยน Input Parameter ใน MT5 (เช่น ปรับ `GridLoss_MaxTrades`) → **EA จะรัน `OnInit()` ใหม่** → ตัวแปร `g_initialBuyPrice` / `g_initialSellPrice` ถูก **reset เป็น 0** (line 651-652)

จากนั้น `RecoverInitialPrices()` (line 788) พยายามกู้คืน แต่มันหาได้เฉพาะ **INIT order ที่ยังเปิดอยู่เท่านั้น** ถ้า INIT order ถูกปิดไปแล้ว (โดย matching close, TP, หรือ accumulate) → กู้คืนไม่ได้ → `g_initialBuyPrice = 0`

เงื่อนไขเปิด Grid ใน OnTick (line 1203):
```cpp
(hasInitialBuy || g_initialBuyPrice > 0) && gridLossBuy < GridLoss_MaxTrades
```
ทั้ง `hasInitialBuy` = false (ไม่มี INIT เปิดอยู่) และ `g_initialBuyPrice` = 0 (กู้คืนไม่ได้) → **condition fail → Grid หยุดทำงานเลย**

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. แก้ `RecoverInitialPrices()` — กู้คืนจาก GL order เก่าสุดถ้าไม่มี INIT

```text
Logic:
1. สแกนเหมือนเดิม — หา INIT orders ก่อน
2. ถ้าไม่เจอ INIT แต่มี GL orders อยู่ฝั่งนั้น:
   - หา GL order เก่าสุด (oldest open time)
   - ใช้ราคาเปิดของ GL#1 เก่าสุด เป็น fallback initial price
   - Print log: "Recovered initial price from oldest GL order"
```

#### 2. เพิ่ม fallback condition ใน OnTick — ถ้ามี GL orders อยู่แล้วให้ grid ทำงานต่อ

แก้เงื่อนไขทั้ง 2 จุด (line 1203, 1207 และ line 1339, 1341):
```cpp
// เดิม:
(hasInitialBuy || g_initialBuyPrice > 0) && gridLossBuy < GridLoss_MaxTrades && buyCount > 0

// ใหม่ — เพิ่ม gridLossBuy > 0 เป็น fallback:
(hasInitialBuy || g_initialBuyPrice > 0 || gridLossBuy > 0) && gridLossBuy < GridLoss_MaxTrades && buyCount > 0
```

เหตุผล: ถ้ามี GL orders อยู่แล้ว แสดงว่า cycle เคยเริ่มไปแล้ว ต้องปล่อยให้ grid ทำงานต่อได้

#### 3. Version bump: v6.4 → v6.5

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge system logic ทั้งหมด (รวม Reverse Hedge ใหม่)
- Orphan Recovery system

