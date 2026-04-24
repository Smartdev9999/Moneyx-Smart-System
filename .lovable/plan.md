

## Golden2 EA v1.0 — Multiplier Pending-Stop Hedging EA (สร้างไฟล์ใหม่)

สร้าง EA ตัวใหม่แยกจาก Gold Miner ทั้งหมด ไม่แตะของเดิมแม้แต่บรรทัดเดียว — เป็นระบบ **Pending Stop Hedging แบบต่อเนื่อง** ที่วาง pending order ทั้งสองฝั่งของกรอบ และเปิด hedge เป็น "ชุด pending" รอเมื่อ DD ฝั่งใดฝั่งหนึ่งถึง 80% ของ trigger ที่กำหนด

### ไฟล์ที่จะสร้าง
- `public/docs/mql5/Golden2_EA.mq5` (ไฟล์ใหม่ ไฟล์เดียว)

### โครงสร้าง Order Comment
- Initial: `G{n}_IN` (1 lot)
- Grid Loss: `G{n}_GL#1` (2 lot), `G{n}_GL#2` (4 lot), `G{n}_GL#3` (8 lot), `G{n}_GL#4` (16 lot)
- Grid Profit: `G{n}_GP#1..#k`
- Hedge Initial: `G{n}_HD_IN`
- Hedge Grid Loss: `G{n}_HD_GL#1..#k` (lot ตรงกับฝั่งตรงข้าม 1:1)
- Hedge Grid Profit: `G{n}_HD_GP#1..#k`

`{n}` คือหมายเลข Group ตั้งแต่ 1..50 (`InpMaxGroups`)

### Inputs หลัก
1. **Entry & Frame**
   - `InpFrameUpperPips` / `InpFrameLowerPips` — ระยะวาง Buy Stop / Sell Stop จากราคากลาง
   - `InpInitialLot = 1.0`, `InpMultiplier = 2.0`, `InpMaxGridLevels = 4`
   - `InpInitialTPPips`, `InpInitialSLPips` (SL = 0 = ไม่ใช้)
2. **Grid**
   - `InpGridStepPips` (ระยะระหว่างไม้ grid)
   - `InpGridProfitTPPips`, `InpGridLossEnable`
3. **Hedging**
   - `InpHedgeTriggerUSD = 1000.0` (จุดที่ DD ฝั่งนั้นจะ "ครบเกณฑ์")
   - `InpHedgeArmPercent = 80.0` (วาง pending hedge เมื่อ DD ถึง 80% ของ trigger)
   - `InpHedgeDisarmPercent = 70.0` (ถอน pending hedge เมื่อ DD กลับลงต่ำกว่า 70%)
   - `InpHedgeLotMatch1to1 = true` (lot hedge = lot ฝั่งตรงข้าม ไม้ต่อไม้)
   - `InpHedge_OpenDelayMin = 0` (cooldown แบบเดียวกับ Gold Miner v6.78)
4. **Group & Sequencing**
   - `InpMaxGroups = 50`
   - `InpSequentialQueue = true` (จัดการทีละ group ตามคิว 1→2→3 ห้ามปิด/แก้พร้อมกัน)
5. **Exit Triple Gate** (เลียนแบบ Gold Miner)
   - `InpExitTF = PERIOD_H4` (ต้องผ่าน Expansion → Normal บน TF ใหญ่)
   - `InpExitBreakoutPips = 300` (ราคาต้องออกนอกกรอบจาก average ฝั่ง buy/hedge)
   - `InpExitMinNetUSD` (กำไรสุทธิขั้นต่ำที่จะอนุญาตปิด)
6. **General**
   - `InpMagic = 22220001`, `InpSlippage`, `InpAllowTrade`

### Logic Flow

**1) Frame & Initial Pending (Group ปัจจุบัน)**
- เมื่อไม่มี Group active → คำนวณ mid price → วาง `BUY_STOP` ที่ mid+upper, `SELL_STOP` ที่ mid-lower (1 lot ทั้งคู่) คอมเมนต์ `G{n}_IN`
- ทั้งสองฝั่งมี TP ตั้งล่วงหน้า; ฝั่งที่ trigger ก่อน → ฝั่งตรงข้ามถูกลบ
- เมื่อ trigger แล้วราคาไม่ถึง TP และวิ่งสวน → วาง grid `G{n}_GL#1..#k` ตาม `InpGridStepPips` × `InpMultiplier`

**2) Hedge Arming (ต่อ Group)**
- คำนวณ `floatLossSide = SUM(profit ของฝั่งหลักใน group นี้ ที่เป็นลบ)`
- เมื่อ `|floatLoss| >= InpHedgeTriggerUSD * InpHedgeArmPercent/100`:
  - คำนวณราคาที่ "ถ้าเปิด ณ จุดนี้แล้ว floating รวมของ group = `InpHedgeTriggerUSD`"
  - วาง pending stop ฝั่งตรงข้ามทั้งชุด (1, 2, 4, 8, 16 lot) **ที่ราคาเดียวกันทั้งหมด** (วางซ้อนจุดเดียว) — comment `G{n}_HD_IN`, `G{n}_HD_GL#1..#k`
- ถ้า DD กลับลงต่ำกว่า `InpHedgeDisarmPercent` ก่อนชน → **ลบ pending hedge ทั้งชุด** (disarm)
- ถ้า DD ถึง 100% → pending จะ trigger เอง → ระบบยืนยันว่า "ติด hedge" → เปิด **Group ใหม่ (n+1)** ทันทีตามขั้นตอนข้อ 1
- รองรับสูงสุด `InpMaxGroups` = 50 ชุด

**3) Sequential Queue (กันชนกัน)**
- มี `g_activeOpsGroup` (-1 = ว่าง). ทุก action ที่จะปิด/แก้ต้อง claim mutex นี้ก่อน
- คิวทำงานเรียง group 1 → 2 → ... ห้ามทำพร้อมกัน เพื่อจำกัด DD spike ตอนปิด

**4) Recovery / Matching Close (Triple Gate)**
- Gate A: TF ใหญ่ผ่าน Expansion → Normal (ใช้ BB vs Keltner เหมือน Gold Miner)
- Gate B: ราคา breakout เกินกรอบจาก average ของฝั่ง main vs hedge ≥ `InpExitBreakoutPips`
- Gate C: net USD ≥ `InpExitMinNetUSD`
- เมื่อผ่านครบ:
  - ฝั่งกำไร (เช่นราคาขึ้น → ฝั่ง buy กำไร) ปิด **ทั้งชุด 5 ไม้**
  - กำไรที่ได้ → ใช้ "ซอยปิด" ฝั่งตรงข้าม (hedge sell) จากไม้กำไรที่สุด → จนเหลือไม้ติดลบน้อยที่สุดที่กำไรรวมยังเป็น ≥ `InpExitMinNetUSD`
  - ไม้ที่เหลือ (เช่น `G{n}_HD_GL#3`, `#4`) → ใช้ **ลำดับล่าสุด** เป็นเกณฑ์ → grid ต่อไปจะเป็น `G{n}_HD_GL#5` (32 lot) ตาม multiplier
  - คำนวณ average รวม "ไม้เหลือ + ไม้ grid ใหม่" → วาง TP ใหม่ห่าง average ตาม `InpExitBreakoutPips`
- ทำงานเหมือนกันถ้าราคาวิ่งลง (hedge เป็นฝ่ายกำไร, main คือฝ่ายเหลือ)
- จัดการทีละ group ตามคิว

### Helper Modules ที่ต้องสร้าง
- `BuildGroupComment(int g, string suffix)`
- `CountGroupOrders(int g, ENUM side, bool hedgeOnly)`
- `GroupFloatingPL(int g, ENUM side)` / `GroupAveragePrice(int g, ENUM side)`
- `ComputeHedgeArmPrice(int g)` — แก้สมการให้ floating รวม = `InpHedgeTriggerUSD`
- `PlaceHedgePendingSet(int g)` / `RemoveHedgePendingSet(int g)`
- `IsExpansionToNormal(ENUM_TIMEFRAMES tf)` — BB/Keltner gate
- `TryMatchingCloseForGroup(int g)` — Triple gate + ซอยปิด + grid ต่อ
- `AdvanceQueue()` — เลื่อน mutex ไป group ถัดไปเมื่อ idle
- Dashboard แสดง: Group active, lot ของแต่ละ comment, floating, hedge arm %, queue state, version

### Safety Guards
- Mutex `g_activeOpsGroup` กัน race
- Hedge cooldown (`InpHedge_OpenDelayMin`) กัน false signal
- Disarm pending เมื่อ DD ลด — ไม่ให้ hedge ค้างเปล่าๆ
- Max 50 groups — ถึง limit แล้วหยุดเปิด initial ใหม่ + log เตือน
- Magic + comment prefix ป้องกันชนกับ EA อื่น

### Dashboard
- Header: `Golden2 EA v1.0 | Magic: 22220001`
- ตาราง 50 แถว (เฉพาะ group active): `G{n} | mainLot | hedgeLot | floatPL | armPct | queue | gateA/B/C`
- Hedge cooldown remaining (ถ้ามี)

### สิ่งที่ "ไม่เปลี่ยนแปลง"
- ไม่แตะไฟล์ `Gold_Miner_EA.mq5`, `Asset_Miner_EA.mq5`, `Jutlameasu_EA.mq5`, `Harmony_*`
- ไม่แตะ React app, Supabase, edge functions
- เป็นไฟล์ MQL5 ใหม่ standalone — ใช้ `<trade/Trade.mqh>` เท่านั้น
- ไม่ผูก license module (เพิ่มภายหลังได้)

### Versioning
- `#property version "1.00"`, header block, dashboard → **Golden2 v1.0**

### ผลลัพธ์ที่คาดหวัง
- EA ใหม่ทำงานเป็น "ชุดต่อชุด" สูงสุด 50 ชุด, ทุกชุดมี main + hedge แบบ pending 1:1, ระบบ arm/disarm hedge ตาม DD%, ปิดด้วย Triple Gate + ซอยปิด + ออก grid ต่อ ตามที่อธิบาย
- จัดการทีละ group ตามคิว ลด DD spike

### ความเสี่ยง & Mitigation
- **Risk:** ขนาด lot ทบทวีคูณ (1→2→4→8→16→32) → margin หนักมาก
- **Mitigation:** input ปรับ multiplier/maxLevels ได้, แนะนำเริ่ม `InpInitialLot=0.01`
- **Risk:** Pending hedge วางจุดเดียวกัน 5 ไม้ — บาง broker จำกัด
- **Mitigation:** offset 1 point ระหว่างไม้อัตโนมัติถ้า broker reject (fallback)
- **Risk:** ระบบใหม่ ยังไม่ผ่านการทดสอบ
- **Mitigation:** เริ่มที่ demo + lot เล็ก, มี `InpAllowTrade` toggle หยุดเทรดทันที

