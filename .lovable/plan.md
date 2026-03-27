

## แก้ไข: Gold Miner EA v6.7 → v6.8 (Reverse Hedge NET + Dual-Track Recovery)

### สิ่งที่แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Reverse Hedge แบบ NET Calculation (v6.8)
- คำนวณ totalBuyLots vs totalSellLots จาก **ทุก order** (Buy, Sell, Bound, Hedge, Grid, Reverse เก่า)
- เปิด Reverse Hedge เท่ากับ NET difference ของ 2 ฝั่ง (ไม่ใช่แค่ฝั่ง hedge)
- ถ้า NET = 0 → ไม่เปิด Reverse

#### 2. Multiple Reverse Hedges (v6.8)
- เปลี่ยนจาก single ticket → array `g_reverseHedgeTickets[MAX_REVERSE_HEDGES]`
- ไม่จำกัดจำนวน Reverse Hedge (สูงสุด 10)
- Comment: `GM_RHEDGE_1`, `GM_RHEDGE_2`, ...
- Recovery: `RecoverHedgeSets()` สแกน GM_RHEDGE ทั้งหมดเข้า array

#### 3. Balanced Lock — TP/SL/Matching Disabled (v6.8)
- Global flag: `g_hedgeBalancedLock`
- เมื่อ totalBuyLots == totalSellLots → TP/SL/Matching Close ถูกปิด
- ManageTPSL(), ManageTPSL_TF(), ManageMatchingClose() มี guard: `if(g_hedgeBalancedLock && g_hedgeSetCount > 0) return;`
- Flag reset อัตโนมัติเมื่อ NET ≠ 0

#### 4. Global Matching Close เมื่อ Normal (v6.8)
- ManageReverseHedge: สแกนทุก order (ไม่จำแนกชุด) → กำไร vs ขาดทุน
- ปิดขาดทุน (oldest first) ด้วย budget จากกำไรรวม
- ปิด profit orders ทั้งหมด (รวม reverse hedges)

#### 5. Dual-Track Grid Recovery (v6.8)
- HedgeSet เพิ่ม fields: `combinedGridMode`, `combinedGridLevel`, `combinedLots`
- Track A: Bound Orders → Grid Recovery เดิม (ไม่เปลี่ยน)
- Track B: Hedge + Reverse → รวม lots → คำนวณ EquivGridLevel → Grid Recovery ชุดใหม่
- CheckAndSetupDualTrackRecovery() ทำงานหลัง global matching close

#### 6. Version bump: v6.7 → v6.8

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge system logic หลัก (Matching/Partial/AvgTP/Grid)
- Orphan Recovery system
- Grid Recovery Track A สำหรับ bound orders (logic เดิม 100%)
- TP/SL เดิมทั้งหมดทำงานปกติเมื่อไม่อยู่ในสถานะ balanced lock
