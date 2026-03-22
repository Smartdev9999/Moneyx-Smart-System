


## Fix: Hedge Guard + Cycle Labeling — Gold Miner SQ EA (v5.2 → v5.3)

### สิ่งที่แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Guard 1: ต้องมี order ฝั่ง counterSide จริง
- สแกนทุก position (รวม bound) ว่ามี counterSide อยู่หรือไม่
- `if(!hasCounterOrders) return;` → ไม่มี order ติดฝั่งผิด → ไม่ hedge

#### 2. Guard 2: ห้ามเปิด hedge ซ้ำทิศเดียวกัน
- เช็คทุก active hedge set → ถ้ามี hedgeSide เดียวกันอยู่แล้ว → return

#### 3. Guard 3: Hedge #2+ ต้อง expansion เปลี่ยนทิศ
- เพิ่ม `g_lastHedgeExpansionDir` global
- `if(g_hedgeSetCount > 0 && bestDir == g_lastHedgeExpansionDir) return;`

#### 4. Cycle Labeling แก้ไข
- ลบ `g_currentCycleIndex++` จาก `CheckAndOpenHedge()`
- ย้ายไปใส่ก่อน INIT order ทุกจุด (SMA, Instant, ZigZag)
- เงื่อนไข: `if(g_hedgeSetCount > 0 && g_currentCycleIndex < 3) g_currentCycleIndex++`
- Cycle increment เฉพาะเมื่อมี hedge active อยู่ → order ใหม่เป็น cycle ถัดไป

#### 5. Version bump: v5.2 → v5.3

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Net Lot Calculation (`CalculateNetHedgeLots`)
- Hedge Partial/Matching Close, Grid Mode logic
- Normal Matching Close logic
- `boundTickets[]` tracking
