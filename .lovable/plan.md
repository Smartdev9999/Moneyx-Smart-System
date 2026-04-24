

## Golden2 EA v1.1 — Group Settings + Average TP/SL + Auto-Strip Broker TP/SL on Hedge Match

จัดระเบียบ inputs ใหม่เป็น 3 กลุ่มย่อยสำหรับ **TP / SL / Hedging**, เพิ่มระบบบริหาร TP/SL แบบ **Average Price** เลียนแบบ Gold Miner, และเพิ่มกลไก **ถอด Broker TP/SL อัตโนมัติทันทีเมื่อมีการ "จับคู่" เป็น Hedging set**

### ไฟล์ที่จะแก้
- `public/docs/mql5/Golden2_EA.mq5` (ไฟล์เดียว)

### 1) จัดกลุ่ม Settings ใหม่ (ใช้ comment header `===` ให้ MT5 จัดเป็น collapsible group)

```
=== General ===
=== Frame & Initial Order ===
=== Grid ===
=== Group / Queue ===
=== Take Profit (Average) ===          ← ใหม่
=== Stop Loss (Average) ===            ← ใหม่
=== Hedging ===                        ← รวม inputs hedge ทั้งหมดมาไว้ที่นี่
=== Exit Triple Gate ===
=== Dashboard ===
```
*ไม่ลบ input เดิม*, แค่ย้าย/เพิ่ม comment header เพื่อให้ MT5 แสดงเป็นกลุ่ม

### 2) เพิ่ม Inputs ใหม่: TP / SL แบบ Average Price (เลียนแบบ Gold Miner)

**Take Profit Group**
- `InpTP_UseFixedDollar` (bool, false) + `InpTP_DollarAmount` (100)
- `InpTP_UsePointsFromAvg` (bool, true) + `InpTP_PointsFromAvg` (1000)
- `InpTP_UsePctBalance` (bool, false) + `InpTP_PctBalance` (26.0)
- `InpTP_UseAccumulateClose` (bool, false) + `InpTP_AccumulateTarget` (1000)
- `InpTP_UsePctMaxDD` (bool, false) + `InpTP_PctMaxDD` (50.0)
- `InpTP_ShowAvgLine` (true), `InpTP_ShowTPLine` (true)
- สี: `InpTP_AvgBuyColor` (DodgerBlue), `InpTP_AvgSellColor` (OrangeRed), `InpTP_BuyLineColor` (Lime), `InpTP_SellLineColor` (Magenta)

**Stop Loss Group**
- `InpSL_Enable` (false)
- `InpSL_ActionMode` enum: `SL_CLOSE_POSITIONS` (Stop Loss action)
- `InpSL_UseFixedDollar` (false) + `InpSL_DollarAmount` (50)
- `InpSL_UsePointsFromAvg` (false) + `InpSL_PointsFromAvg` (1000)
- `InpSL_UsePctBalance` (false) + `InpSL_PctBalance` (3.0)
- `InpSL_ShowSLLine` (true), `InpSL_LineColor` (Black)

### 3) ระบบ Average TP/SL Manager (ใหม่)

ฟังก์ชันหลักที่จะเพิ่ม:
- `ComputeGroupAveragePerSide(g, side, hedgeFilter)` — ค่าเฉลี่ยน้ำหนักด้วย lot
- `ComputeAvgTPPrice(g, side, hedgeFilter)` — average + `InpTP_PointsFromAvg` (Buy บวก / Sell ลบ)
- `ComputeAvgSLPrice(g, side, hedgeFilter)` — average ± `InpSL_PointsFromAvg`
- `CheckAndCloseByAverageTP(g)` — เช็ค **per side** ของแต่ละ group ทั้ง main และ hedge แยกกัน เรียงตามลำดับ:
  1. ถ้า `InpTP_UseFixedDollar` → ปิดทั้ง side เมื่อ floating ≥ amount
  2. ถ้า `InpTP_UsePointsFromAvg` → ปิดทั้ง side เมื่อราคา ≥/≤ avg ± points
  3. `InpTP_UsePctBalance` → ปิดเมื่อ floating ≥ balance × pct/100
  4. `InpTP_UseAccumulateClose` → รวม PL ทั้ง group ≥ target → ปิดทั้ง group
  5. `InpTP_UsePctMaxDD` → ปิดเมื่อ floating ≥ maxDD × pct/100
- `CheckAndCloseByAverageSL(g)` — โครงสร้างเดียวกัน ใช้ตอน loss ถึงเกณฑ์
- `DrawAverageAndTPLines(g)` — วาดเส้น Avg Buy / Avg Sell / TP Buy / TP Sell / SL บนชาร์ต ใช้ `OBJ_HLINE` มี object name เช่น `G2_AVG_B_G%d`, `G2_TP_B_G%d`

**สำคัญ**: เงื่อนไข TP/SL average จะ **ทำงานก็ต่อเมื่อ group ยังไม่มี hedge** (main ฝั่งเดียว) — ถ้ามี hedge แล้ว ปล่อยให้ **Triple-Gate Matching Close** เป็นคนจัดการเหมือนเดิม (ไม่ทับ logic เก่า)

### 4) ถอด Broker TP/SL อัตโนมัติเมื่อจับคู่ Hedge

ฟังก์ชันใหม่:
```cpp
void StripBrokerTPSL_OnHedgeMatch(int g);
```

**Trigger**: เรียกทันทีเมื่อ `CountGroupPositions(g, -1, 1) > 0` (มี hedge position) **และ** `CountGroupPositions(g, -1, 0) > 0` (มี main position) — คือ "matched set"

**Action**: วน positions ทั้ง main + hedge ของ group นั้น → ใช้ `trade.PositionModify(ticket, 0, 0)` set ทั้ง SL=0 และ TP=0

**ตำแหน่งเรียก**:
- ใน `OnTick()` หลัง loop จัดการ group: เพิ่ม `if (IsGroupHedgeMatched(g)) StripBrokerTPSL_OnHedgeMatch(g);`
- มี guard `g_stripped[g]` (bool array ขนาด 51) กันเรียกซ้ำทุก tick → set true หลังถอดสำเร็จ, reset เมื่อ group หมดออเดอร์

หมายเหตุ: หลังถอดแล้ว → ระบบรอสัญญาณจาก **Average TP/SL Manager** หรือ **Triple-Gate Matching Close** เป็นผู้สั่งปิดทีหลัง (ตามที่ user ต้องการ)

### 5) Dashboard เพิ่ม
- บรรทัดแสดง avg/TP/SL แต่ละ side ของ group ที่ active
- บรรทัด "TP-Stripped: G1,G3" แสดง group ที่ถอด broker TP/SL แล้ว

### 6) Version Bump → v1.1
- `#property version "1.10"`
- `#property description` อัปเดต
- Header comment block, dashboard text, log prints ทุกจุด

### สิ่งที่ "ไม่เปลี่ยนแปลง" (ตามกฎเหล็ก)
- **ไม่แตะ** logic เปิดออเดอร์: `PlaceInitialFrame`, `TryPlaceGridLoss`, `PlaceHedgePendingSet`, `PlaceContinuationGridIfNeeded`
- **ไม่แตะ** Hedge arm/disarm thresholds, mutex, cooldown
- **ไม่แตะ** `TryMatchingCloseForGroup` (Triple Gate), `ShredCloseLosingSide`, `IsExpansionToNormal`
- **ไม่แตะ** `TryAdvanceToNextGroup` (group lifecycle)
- ไม่แตะไฟล์อื่นใน `public/docs/mql5/` หรือ React/Supabase

### ความเสี่ยง & Mitigation
- Average TP/SL อาจปิดก่อน Triple Gate → จำกัดให้ทำงาน "ก่อนมี hedge" เท่านั้น
- ถอด broker TP/SL = สูญเสีย safety net ถ้าระบบ crash → log ทุกครั้งที่ strip + dashboard แสดงสถานะ + user ปิด `InpAllowTrade` ก็หยุดได้

### Technical Detail
- Average price: `Σ(price × lot) / Σ(lot)` per (group, side, hedge?) — ฟังก์ชัน `GroupAveragePrice` มีอยู่แล้ว ใช้ซ้ำได้
- TP price (Buy): `avg + points × _Point`; (Sell): `avg - points × _Point`
- Strip TP/SL: `MqlTradeRequest` action `TRADE_ACTION_SLTP` หรือ `CTrade::PositionModify(ticket, 0.0, 0.0)`
- HLine objects: ใช้ prefix `G2L_` แล้วลบ/อัปเดตทุก tick ตาม group ที่ active
- Dashboard ขยายอีก ~3 บรรทัดต่อ group active

