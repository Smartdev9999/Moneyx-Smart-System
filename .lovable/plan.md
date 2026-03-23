

## เพิ่ม Comment Generation System แยก Bound Orders จาก New Cycle — Gold Miner SQ EA (v5.8 → v5.9)

### สิ่งที่แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. เพิ่ม Global `g_cycleGeneration` + Helper Functions
- `GetCommentPrefix()`: return "GM", "GM1", "GM2"... ตาม generation
- `MatchGMSuffix()`: match comment จากทุก generation ด้วย suffix
- `MatchTFPrefix()`: match TF comment จากทุก generation
- `ExtractGeneration()`: แยก generation number จาก comment

#### 2. เพิ่ม `boundGeneration` ใน HedgeSet struct

#### 3. แก้ทุกจุดสร้าง Comment → ใช้ `GetCommentPrefix()`
- SMA Entry: `GetCommentPrefix() + "_INIT"`
- Instant Entry: `GetCommentPrefix() + "_INIT"`
- Grid Loss: `GetCommentPrefix() + "_GL#N"`
- Grid Profit: `GetCommentPrefix() + "_GP#N"`
- ZigZag TF: `GetCommentPrefix() + "_" + tfLabel + "_" + suffix`

#### 4. แก้ทุกจุด Scan/Match Comment → ใช้ helpers
- CountPositions, FindMaxLotOnSide, FindLastOrder
- CountPositionsTF, CalculateAveragePriceTF, CalculateFloatingPL_TF
- FindLastOrderTF, CloseAllSideTF, ApplyTrailingSL_TF
- RecoverInitialPrices, RecoverTFInitialPrices

#### 5. CheckAndOpenHedge → increment `g_cycleGeneration`
- Store `boundGeneration` ก่อน increment

#### 6. RecoverHedgeSets → gen-aware rebind
- Step 0: Scan positions หา max generation → set `g_cycleGeneration`
- Step 2: Bind เฉพาะ orders ที่ gen < g_cycleGeneration

#### 7. Version bump: v5.8 → v5.9

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge system logic ทั้งหมด (Matching/Partial/AvgTP/Grid)
- Squeeze filter logic
