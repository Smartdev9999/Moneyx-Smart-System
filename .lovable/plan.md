

## Golden2 EA v1.2 — Grid Settings เหมือน Gold Miner (Grid Loss / Max Grid Trailing / Grid Profit)

ขยายระบบกริดของ Golden2 ให้มีโครงสร้าง input และความสามารถเหมือน Gold Miner ครบทั้ง **3 กลุ่ม** โดยไม่แตะ logic เปิด/ปิดออเดอร์เดิม (ปรับเฉพาะส่วนคำนวณ lot/gap/level เพื่อรองรับ input ใหม่)

### ไฟล์ที่จะแก้
- `public/docs/mql5/Golden2_EA.mq5` (ไฟล์เดียว)

### 1) เพิ่ม Enums (เลียนแบบ Gold Miner)
```cpp
enum ENUM_LOT_MODE_G2  { G2_LOT_CUSTOM=0, G2_LOT_ADD=1, G2_LOT_MULTIPLY=2 };
enum ENUM_GAP_TYPE_G2  { G2_GAP_FIXED=0,  G2_GAP_CUSTOM=1, G2_GAP_ATR=2 };
enum ENUM_ATR_REF_G2   { G2_ATR_REF_DYNAMIC=0, G2_ATR_REF_LAST_GRID=1 };
```

### 2) แทนที่บล็อก `=== Grid ===` เดิม ด้วย 3 กลุ่มใหม่

**=== Grid Loss Side ===**
- `GridLoss_MaxTrades` (30) — Max Grid Loss Trades
- `GridLoss_LotMode` (G2_LOT_MULTIPLY) — Custom / Add / Multiply
- `GridLoss_CustomLots` ("0.01;0.01;0.01;…") — semicolon separated
- `GridLoss_AddLotPerLevel` (0.4) — multiplied by InpInitialLot
- `GridLoss_MultiplyFactor` (1.4) — for Multiply mode
- `GridLoss_GapType` (G2_GAP_FIXED)
- `GridLoss_Points` (50) — Fixed gap (points)
- `GridLoss_CustomDistance` ("100;200;300;…") — Custom gap per level
- `GridLoss_ATR_TF` (PERIOD_H1), `GridLoss_ATR_Period` (14), `GridLoss_ATR_Multiplier` (2.0), `GridLoss_ATR_Reference` (G2_ATR_REF_LAST_GRID)
- `GridLoss_MinGapPoints` (50)
- `GridLoss_CandleConfirm` (1) — N candles confirm before GL
- `GridLoss_OnlyInSignal` (false)
- `GridLoss_OnlyNewCandle` (true)
- `GridLoss_DontSameCandle` (true)

**=== Max Grid Average Trailing Stop ===**
- `MaxGrid_TrailEnable` (false)
- `MaxGrid_TrailMode` (1) — 0=Max Order Grid, 1=Start Order Grid
- `MaxGrid_StartOrders` (8)
- `MaxGrid_TrailActivation` (100) — points from average (0=off)
- `MaxGrid_TrailStep` (50)
- `MaxGrid_BreakevenBuffer` (10)

**=== Grid Profit Side ===**
- `GridProfit_Enable` (false)
- `GridProfit_MaxTrades` (2)
- `GridProfit_LotMode` (G2_LOT_MULTIPLY)
- `GridProfit_CustomLots` ("0.01;0.01;…")
- `GridProfit_AddLotPerLevel` (0.2)
- `GridProfit_MultiplyFactor` (1.4)
- `GridProfit_GapType` (G2_GAP_FIXED)
- `GridProfit_Points` (100)
- `GridProfit_CustomDistance` ("100;200;500")
- `GridProfit_ATR_TF` (PERIOD_H1), `GridProfit_ATR_Period` (14), `GridProfit_ATR_Multiplier` (2.0), `GridProfit_ATR_Reference` (G2_ATR_REF_LAST_GRID)
- `GridProfit_MinGapPoints` (100)
- `GridProfit_OnlyNewCandle` (true)

### 3) Helper functions ใหม่ (รองรับ inputs ใหม่)
- `ParseCSVDouble(str, idx, fallback)` / `ParseCSVInt(str, idx, fallback)` — อ่านค่าจาก semicolon list
- `ResolveLot(level, mode, customStr, addPerLvl, mulFactor)` — แทนที่ `LotForLevel()` เดิม (ฝั่ง Loss/Profit ใช้ตัวเดียวกัน)
- `ResolveGapPoints(level, gapType, fixedPts, customStr, atrTF, atrPeriod, atrMult, atrRef, lastGridPrice, minGap)` — คำนวณระยะห่าง grid
- `GetATRPoints(tf, period, mult)` — copy ATR ผ่าน handle (cache เพื่อกัน leak)
- `IsNewCandleSinceLast(g, side, hedge, family)` — สำหรับ OnlyNewCandle / DontSameCandle / CandleConfirm
- `CountConfirmingCandles(side, n)` — เช็ค N candles ฝั่งเดียวกันก่อน GL

### 4) อัปเดตการเรียกใช้ใน `TryPlaceGridLoss(g)`
- เปลี่ยน `if(gl >= InpMaxGridLevels)` → ใช้ `GridLoss_MaxTrades`
- เปลี่ยน `LotForLevel(gl+1)` → `ResolveLot(gl+1, GridLoss_LotMode, …)`
- เปลี่ยน `InpGridStepPips*g_point` → `ResolveGapPoints(gl+1, GridLoss_GapType, …)*g_point`
- เพิ่ม guard:
  - `GridLoss_OnlyNewCandle` / `GridLoss_DontSameCandle`
  - `GridLoss_CandleConfirm` (ถ้า >0)
  - `GridLoss_OnlyInSignal` (ตอนนี้ Golden2 ยังไม่มี signal — จะ map ไปเป็น "ฝั่งที่ floating loss" เพื่อความเข้ากันได้)
- คงโครงสร้างเปิด market order เดิม (`trade.Buy/Sell`) — ไม่แตะ execution

### 5) เพิ่มฟังก์ชัน `TryPlaceGridProfit(g)` (ใหม่)
- ทำงานเมื่อ `GridProfit_Enable=true` และฝั่งนั้น floating > 0
- ใช้ `ResolveLot/ResolveGapPoints` ของชุด Profit
- เปิดตามทิศทางเดียวกับฝั่งกำไร เมื่อราคาวิ่งไปต่ออีก gap
- เรียกใน `OnTick()` หลัง `TryPlaceGridLoss(g)`

### 6) เพิ่มฟังก์ชัน `ManageMaxGridTrailing(g)` (ใหม่)
- คำนวณ avg ของฝั่งที่กริดเปิดเยอะสุด
- เงื่อนไข Activation:
  - **Mode 0** (Max Order Grid): ทำงานเมื่อจำนวนกริด = `GridLoss_MaxTrades`
  - **Mode 1** (Start Order Grid): ทำงานเมื่อจำนวนกริด ≥ `MaxGrid_StartOrders`
- เมื่อราคาวิ่งจาก avg ≥ `MaxGrid_TrailActivation` → set virtual SL = `avg ± MaxGrid_BreakevenBuffer`
- ขยับตาม `MaxGrid_TrailStep`
- ปิดทั้งฝั่งเมื่อราคาแตะ virtual SL (ใช้ market close — ไม่แก้ broker SL เพราะกฎหลัง hedge match strip TP/SL)
- เก็บ state ใน `double g_maxGridTrailSL[51][2]` (group × side)
- เรียกใน `OnTick()` ถ้า `MaxGrid_TrailEnable`

### 7) Dashboard เพิ่มบรรทัด
- "GL Trades: x/MAX | GP Trades: x/MAX"
- "MaxGrid Trail: ON/OFF (Mode N) | Virtual SL: …"

### 8) Version Bump → v1.2
- `#property version "1.20"`
- `#property description` อัปเดต
- Header comment block, dashboard, log prints ทุกจุด

### สิ่งที่ "ไม่เปลี่ยนแปลง"
- ❌ ไม่แตะ `PlaceInitialFrame` (frame เปิด BUY_STOP/SELL_STOP)
- ❌ ไม่แตะ `PlaceHedgePendingSet`, `ManageGroupHedgeArm`, hedge cooldown, mutex
- ❌ ไม่แตะ `TryMatchingCloseForGroup` (Triple-Gate), shred-close
- ❌ ไม่แตะ Average TP/SL Manager (v1.1) และ `StripBrokerTPSL_OnHedgeMatch`
- ❌ ไม่แตะ group lifecycle / sequential queue
- ❌ ไม่แก้ไข execution function (`trade.Buy/Sell/BuyStop/SellStop/PositionClose`)
- ✅ แก้เฉพาะ "วิธีคำนวณ lot/gap/level" และเพิ่ม guard ก่อนเรียก execution

### ความเสี่ยง & Mitigation
- input ใหม่จำนวนมาก → user งง: คงค่า default ที่ปลอดภัย (Multiply 1.4, MaxTrades 30, candle confirm 1)
- ATR handle leak: cache handle เป็น static + release ใน `OnDeinit`
- Profit grid อาจเร่งให้ DD รวมโต: default `Enable=false`
- Max Grid Trailing virtual SL อาจขัดกับ Triple-Gate: ทำงานเฉพาะตอน group **ยังไม่มี hedge** เท่านั้น (เหมือน Average TP/SL)

### Technical Detail
- Lot resolve:
  - CUSTOM: `ParseCSVDouble(GridLoss_CustomLots, level-1, InpInitialLot)`
  - ADD: `InpInitialLot + (level × GridLoss_AddLotPerLevel × InpInitialLot)`
  - MULTIPLY: `InpInitialLot × pow(GridLoss_MultiplyFactor, level)`
- Gap resolve:
  - FIXED: `GridLoss_Points`
  - CUSTOM: `ParseCSVInt(GridLoss_CustomDistance, level-1, GridLoss_Points)`
  - ATR: `(int)(ATR_value × GridLoss_ATR_Multiplier / _Point)` แล้ว `MathMax(result, GridLoss_MinGapPoints)`
- ATR ref:
  - `DYNAMIC`: ATR ปัจจุบัน
  - `LAST_GRID`: ATR ณ เวลาเปิดไม้ก่อนหน้า (cache `g_atrAtLastGrid[51][2]`)

