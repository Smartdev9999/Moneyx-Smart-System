

## เพิ่ม Entry Mode แบบ Instant (ไม่ใช้ Indicator) ใน Gold Miner EA

### แนวคิด
เพิ่มตัวเลือกที่ 3 ใน `ENUM_ENTRY_MODE` → `ENTRY_INSTANT` ซึ่งจะ:
- เปิด BUY + SELL ทันทีเมื่อ EA เริ่มทำงาน (ไม่ต้องรอสัญญาณ SMA/ZigZag)
- เมื่อฝั่งใดฝั่งหนึ่งถูกปิด → เปิดออเดอร์ใหม่ทันทีในฝั่งที่ปิดไป
- เมื่อปิดรวบทั้งหมด → เปิดใหม่ทั้ง BUY + SELL
- **ระบบปิดออเดอร์ยังคงเหมือนเดิมทุกอย่าง** (Grid, TP, SL, Trailing, Accumulate, Drawdown exit ฯลฯ)

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

**1. เพิ่ม Enum (line ~48-52):**
```cpp
enum ENUM_ENTRY_MODE
{
   ENTRY_SMA      = 0,  // SMA Mode (Original)
   ENTRY_ZIGZAG   = 1,  // ZigZag Multi-Timeframe Mode
   ENTRY_INSTANT  = 2   // Instant Mode (No Indicator)
};
```

**2. เพิ่ม block ใหม่หลัง ZigZag block (line ~1036):**
```cpp
if(EntryMode == ENTRY_INSTANT)
{
   // ใช้ guard เหมือนเดิม: g_newOrderBlocked, MaxOpenOrders, g_eaStopped
   // ไม่ต้องเช็ค SMA/ZigZag signal
   // BUY: ถ้า buyCount==0 && TradingMode อนุญาต → OpenOrder BUY ทันที
   // SELL: ถ้า sellCount==0 && TradingMode อนุญาต → OpenOrder SELL ทันที
   // ยังคงใช้ DontOpenSameCandle guard ตามปกติ
}
```

Logic จะคล้าย SMA mode แต่ตัดเงื่อนไข `currentPrice > smaValue` ออก — เปิดทันทีเมื่อฝั่งนั้นว่าง

### สิ่งที่ไม่เปลี่ยนแปลง
- Trading Strategy Logic (SMA signal, ZigZag signal) — ไม่แตะ
- Order Execution (trade.Buy/Sell/PositionClose)
- TP/SL/Trailing/Breakeven/Grid calculations
- License / News / Time Filter core logic
- Accumulate / Matching Close / Drawdown exit logic
- Dashboard / Rebate system

