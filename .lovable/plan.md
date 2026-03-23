

## เพิ่ม Reverse Hedging พร้อม Matching Close — Gold Miner SQ EA (v6.3 → v6.4)

### สิ่งที่แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. เพิ่ม Input Parameters
- `InpHedge_ReverseEnable` (default false)
- `InpHedge_ReverseMinTFConfirm` (default 2)
- `InpHedge_ReverseMatchMinProfit` (default 0.50)

#### 2. เพิ่ม Global Variables สำหรับ Reverse Hedge State
- `g_reverseHedgeActive`, `g_reverseHedgeTicket`, `g_reverseHedgeLots`, `g_reverseHedgeSide`, `g_reverseForSetIndex`

#### 3. เพิ่ม `IsReverseHedgeComment()` + อัพเดท `IsHedgeComment()` ให้รวม GM_RHEDGE

#### 4. เพิ่ม `CheckAndOpenReverseHedge()` — คำนวณ total lots ทุกตัวฝั่ง hedge

#### 5. เพิ่ม `ManageReverseHedge()` — Matching Close เมื่อ Normal

#### 6. เพิ่ม Recovery ใน `RecoverHedgeSets()` — สแกน GM_RHEDGE rebuild state

#### 7. Dashboard — แสดง Reverse Hedge status

#### 8. เรียกใน `ManageHedgeSets()` — ManageReverseHedge + CheckAndOpenReverseHedge

#### 9. Version bump: v6.3 → v6.4

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge system logic (Matching/Partial/AvgTP/Grid)
- Orphan Recovery system, Comment Generation logic
