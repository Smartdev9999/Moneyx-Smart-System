

## Fix 2 Bugs ในระบบ Hedging — Gold Miner SQ EA (v4.4 → v4.5)

### Bug 1: Sell orders ปกติไม่ทำงานเมื่อมี Sell Hedge

**สาเหตุ**: เมื่อเปิด Sell Hedge → `sellCount > 0` (นับรวม hedge) → ระบบคิดว่ามี Sell cycle อยู่แล้ว:
- Initial Sell entry ต้องการ `sellCount == 0` → ไม่ผ่าน
- Grid Sell ต้องการ `hasInitialSell || g_initialSellPrice > 0` → ไม่ผ่าน (hedge comment เป็น `GM_HEDGE` ไม่ใช่ `GM_INIT`)

**แก้ไข**: ทุกจุดที่นับ `buyCount`/`sellCount` สำหรับ trading logic → **ข้าม orders ที่เป็น hedge** (comment มี `GM_HEDGE` / `GM_HG`)
- แก้ `CountPositions()` หรือเพิ่ม `CountNormalPositions()` ที่ skip hedge orders
- ใช้ count ใหม่นี้ใน entry logic, grid logic, `hasInitialBuy`/`hasInitialSell` check

### Bug 2: Basket TP/SL ปิด Hedge Order ด้วย

**สาเหตุ**: `CalculateFloatingPL()` และ `CalculateAveragePrice()` รวม hedge orders เข้าไปในการคำนวณ → basket TP trigger แล้วปิดทุก order ฝั่งนั้นรวม hedge

**แก้ไข**: 
- `CalculateFloatingPL()` → ข้าม orders ที่มี comment `GM_HEDGE` / `GM_HG`
- `CalculateAveragePrice()` → ข้าม orders ที่มี comment `GM_HEDGE` / `GM_HG`
- `CloseAllSide()` → ข้าม hedge orders (ให้ hedge system จัดการเอง)
- Per-order trailing/breakeven → ข้าม hedge orders

### ไฟล์ที่แก้ไข
`public/docs/mql5/Gold_Miner_EA.mq5` — ~15 จุดที่ต้องเพิ่ม `IsHedgeComment()` filter

### Version bump: v4.4 → v4.5

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant signals, Grid calculations, TP/SL formula)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge system logic (CheckAndOpenHedge, ManageHedgeSets — ยังทำงานเหมือนเดิม)
- Matching Close ปกติ (มี skip hedge อยู่แล้ว)

