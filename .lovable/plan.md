


## Fix: Hedge Set ค้าง + Comment หาย + Hedge ไม่เปิดใหม่ (v5.16 → v5.17)

### สิ่งที่แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Hedge Ticket Lookup — trade.ResultDeal() (broker-proof)
- ใช้ `trade.ResultDeal()` → `DEAL_POSITION_ID` เป็น primary lookup
- Fallback เป็น comment scan เหมือนเดิม
- แม้ broker strip comment → ยังได้ ticket ถูกต้อง

#### 2. Full Cleanup Deactivation
- เพิ่ม cleanup block: ถ้า hedge ไม่อยู่ + bound หมด → scan grid orders (GM_HG)
- ถ้าไม่มี grid orders → deactivate set ทันที (ไม่ว่า gridMode จะเป็นอะไร)
- ป้องกัน stale set ค้างถาวร

#### 3. hedgeTicket Reset ทันทีเมื่อ Position หาย
- เพิ่ม `hedgeTicket = 0` เมื่อ !hedgeExists ไม่ว่า gridMode
- ทำให้ routing logic เข้า ManageHedgeGridMode แทน ManageGridRecoveryMode

#### 4. g_hedgeSetCount Safety
- ทุกจุด `g_hedgeSetCount--` → `MathMax(0, g_hedgeSetCount - 1)`
- ป้องกัน counter ติดลบ

#### 5. Version bump: v5.16 → v5.17

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge Guards (cycle-aware, squeeze directional block)
- Normal Matching Close logic
- Grid Recovery lot calculation + direction logic
- Dashboard / Hedge Cycle Monitor layout
