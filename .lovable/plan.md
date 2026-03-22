

## Fix: เพิ่ม Hedge Slots เป็น 16 + Hedge Cycle Groups เป็น 7 (v5.9 → v5.10)

### สิ่งที่แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. MAX_HEDGE_SETS 4 → 16
- รองรับ hedge sets หลายตัวพร้อมกัน (H1-H4 × 7 groups)

#### 2. Cycle Limit 3 → 6 (7 groups: A-G)
- แก้ทุกจุดที่มี `g_currentCycleIndex < 3` → `< 6` (6 จุด)

#### 3. Hedge Cycle Monitor Dashboard — 7 คอลัมน์
- Arrays ขยายจาก `[4]` → `[7]`
- เพิ่ม Group E (Cyan), F (Pink), G (Silver)
- ลูปทุกจุด `g < 4` → `g < 7`
- Column width ปรับจาก 110 → 68 เพื่อรองรับ 7 คอลัมน์

#### 4. Version bump: v5.9 → v5.10

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge Guards logic (cycle-aware guards ยังเหมือนเดิม)
- Hedge Partial/Matching/Grid Close logic
- Dashboard หลัก
