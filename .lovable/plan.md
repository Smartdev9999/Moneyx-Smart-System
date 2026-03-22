

## Fix: Hedge เปิดผิดฝั่ง — SELL Hedge เปิดขณะ Expansion BUY (v5.10 → v5.11)

### สาเหตุ

`CheckAndOpenHedge()` ใช้ `bestDir` จาก **TF สูงสุดที่เป็น expansion** ณ tick นั้น เพื่อกำหนดทิศ hedge ปัญหาคือ:

- ถ้า tick หนึ่ง H1 ยังไม่เข้า expansion แต่ M15 หรือ M30 เข้า expansion SELL → bestDir = -1 → เปิด SELL hedge
- tick ถัดมา H1 เข้า expansion BUY → dashboard แสดง EXPANSION BUY + SELL BLOCKED
- แต่ SELL hedge ถูกเปิดไปแล้วใน tick ก่อน

**ไม่มี guard ที่ป้องกัน hedge direction ไม่สอดคล้องกับ squeeze block status**

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. เพิ่ม Guard: Hedge ต้องสอดคล้องกับ Squeeze Block

หลัง line 6074 (คำนวณ hedgeSide แล้ว) เพิ่ม:

```cpp
// v5.11: ห้าม hedge ผิดฝั่งกับ squeeze directional block
// ถ้า SELL ถูก block (expansion BUY) → ห้ามเปิด SELL hedge
// ถ้า BUY ถูก block (expansion SELL) → ห้ามเปิด BUY hedge
if(g_squeezeSellBlocked && hedgeSide == POSITION_TYPE_SELL) return;
if(g_squeezeBuyBlocked  && hedgeSide == POSITION_TYPE_BUY)  return;
```

**Logic:**
- Expansion BUY → `g_squeezeSellBlocked = true` → SELL hedge ถูก block → เปิดได้แค่ BUY hedge (ล็อค SELL orders ที่ติด) ✓
- Expansion SELL → `g_squeezeBuyBlocked = true` → BUY hedge ถูก block → เปิดได้แค่ SELL hedge (ล็อค BUY orders ที่ติด) ✓

#### 2. Version bump: v5.10 → v5.11

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge Partial/Matching/Grid Close logic
- Net Lot Calculation, Cycle Labeling
- Dashboard / Hedge Cycle Monitor

