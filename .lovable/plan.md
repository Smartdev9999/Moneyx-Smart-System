## เป้าหมาย
ทำให้ Backtest ของ Golden2 EA เร็วขึ้นอย่างมีนัยสำคัญ และยังคงความแม่นยำ (หรือเพิ่มขึ้น) — โดย **ไม่แตะ Trading Logic / Order Execution / Strategy** ตามกฎเหล็กของโปรเจกต์

---

## วิเคราะห์จุดที่ทำให้ Backtest ช้า (จากการสำรวจไฟล์)

1. **`Print` / `PrintFormat` จำนวนมาก** เมื่อ `InpVerboseLog=true` — log แต่ละบรรทัดใน Tester ช้ามาก (เรียกหลายร้อยครั้งต่อ session)
2. **`HideAuxiliaryTesterCharts()` + `CleanupChartIndicatorsInTester()` ทุก 60 วินาที** ของ TimeCurrent — ใน Tester นาฬิกาเดินเร็ว ทำให้ trigger บ่อยและเรียก ChartIndicatorDelete ทั้ง chart
3. **Dashboard rendering** — แม้มี throttle 1 วินาทีแล้ว แต่ใน tester non-visual ก็ยังเสีย CPU เปล่า ๆ
4. **`DrawAverageAndTPLinesForGroup(g)`** — วาดเส้นบน chart ทุก tick ทุกกลุ่ม (สูงสุด ~50 กลุ่ม)
5. **License `OnTick()` check** — ส่ง WebRequest ใน Tester ไม่มีประโยชน์ ควร bypass สมบูรณ์
6. **News refresh / Sync account data** — เรียก WebRequest ใน Tester ไร้ความหมาย
7. **`MakeComment`/`ParseComment` ParseString ทุก position ทุก tick** — รวมเป็นต้นทุนใหญ่ แต่เลี่ยงยากโดยไม่แตะ logic
8. **ความแม่นยำ**: ผู้ใช้น่าจะรัน "Every tick" หรือ "Every tick based on real ticks" → ช้ามาก แต่ผลลัพธ์ใกล้จริงสุด

---

## แผนการแก้ไข (v2.9.1 — Backtest Performance Pack)

### A) Tester-Aware Throttles & Bypass (ไม่กระทบสด)
ทุกข้อใช้ guard `g_isTesterMode` เพื่อให้ Live trading ทำงานเหมือนเดิม 100%

1. **Silent log ใน Tester**
   - เพิ่ม input `InpTester_SilenceLogs = true` (default ON)
   - สร้าง macro/helper `LOGF(...)` ที่ในโหมด Tester + flag = ON → return ทันที (ไม่เรียก `PrintFormat`)
   - **ไม่แก้** ข้อความหรือเงื่อนไข log เดิม แค่ wrap call
   - คาดผล: เร็วขึ้น 20-40% บนกราฟที่ verbose

2. **Dashboard OFF อัตโนมัติใน Tester non-visual**
   - เพิ่ม input `InpTester_DisableDashboard = true`
   - ใน `RenderDashboardThrottled` ถ้า `g_isTesterMode && !MQLInfoInteger(MQL_VISUAL_MODE) && InpTester_DisableDashboard` → return
   - คาดผล: เร็วขึ้น 5-15%

3. **ปิด Chart Drawing ใน Tester non-visual**
   - เพิ่ม input `InpTester_DisableChartDraw = true`
   - ใน `DrawAverageAndTPLinesForGroup` guard return เมื่อ tester non-visual
   - คาดผล: เร็วขึ้น 5-10% โดยเฉพาะเมื่อมีหลายกลุ่ม

4. **Skip Aux-Chart Sweep หลังครั้งแรกใน Tester non-visual**
   - ครั้งแรกใน OnInit ยังเรียก เพื่อ strip subwindows
   - ใน OnTick ข้าม sweep 60s ถ้า non-visual (ไม่มีจอแสดงผลให้ทำความสะอาด)
   - คาดผล: เร็วขึ้น 3-8%

5. **Bypass License + News + Sync ใน Tester**
   - License: ใน Tester return `LICENSE_VALID` ทันที (มีอยู่บางส่วนแล้ว — ตรวจให้ครบ)
   - News refresh + Sync account data: skip WebRequest ใน Tester
   - คาดผล: ลดความค้างจาก network timeout

6. **Throttle เพิ่มสำหรับ Tester (เลือกใช้)**
   - `InpTester_TickStrideMs = 0` (default 0 = ทุก tick เหมือนเดิม)
   - ถ้าตั้ง > 0 → ใน Tester ข้าม OnTick ที่ห่างจาก tick ก่อนหน้าน้อยกว่าค่านี้ (มิลลิวินาที model time)
   - ใช้เมื่อยอมแลก accuracy เล็กน้อยเพื่อความเร็ว (default OFF เพื่อรักษาความแม่นยำ)

### B) คำแนะนำการตั้งค่า Tester (ในเอกสาร — ไม่แก้โค้ด)
ใส่ในส่วน comment ด้านบนไฟล์ + ใน `.lovable/memory/...` :

- **Modeling**:
  - ความเร็วสูงสุด: `Open prices only` (เหมาะกับ EA ที่ทำงาน new-bar เป็นหลัก — Golden2 ใช้ ATR snapshot/new-bar trail หลายจุด)
  - สมดุล: `1 minute OHLC` — เร็ว + แม่นยำพอใช้สำหรับ Grid/Hedge
  - แม่นยำสูงสุด: `Every tick based on real ticks` (ช้าที่สุด ใช้เฉพาะ final verification)
- **Optimization**: ใช้ `Math calculation` + Genetic + Forward เพื่อลดจำนวน pass
- ปิด Visual mode เมื่อไม่ debug
- ตั้งค่า `InpVerboseLog=false` เมื่อรัน optimization
- ปิด `InpShowDashboard=false` เมื่อ optimization
- เปิด local agents หลายตัว (Tools → Strategy Tester → Settings → Number of local agents)

### C) สิ่งที่ "เพิ่มความแม่นยำ" โดยไม่ลดความเร็ว
1. ใช้ **Real Tick data** (ดาวน์โหลดจาก History Center) เฉพาะตอน final test
2. ตรวจ **Spread setting** — ใช้ `Current` หรือ custom ตรงกับโบรกเกอร์จริง (default 20 points อาจเพี้ยน)
3. ตั้ง **Initial deposit / Leverage / Commission** ให้ตรงบัญชีจริง
4. ใช้ **Custom Symbol** ที่ import ticks จากโบรกเกอร์เป้าหมาย (แม่นยำสุดสำหรับ XAUUSD)

---

## สิ่งที่ไม่เปลี่ยนแปลง (ยืนยันตามกฎเหล็ก)
- ❌ ไม่แตะ `trade.Buy / Sell / PositionClose / OrderModify / OrderSend / BuyStop / SellStop / OrderDelete`
- ❌ ไม่แตะ Entry (SMA/INSTANT/PENDING), Grid Loss/Profit logic, Recovery Grid ladder, Hedge mirror, Triple-Gate, Avg TP/SL, Trailing, Squeeze BB/KC
- ❌ ไม่แตะ License verification core, News filter core, Time filter core, Sync data logic
- ❌ ไม่แตะ `MakeComment` / `ParseComment` semantics
- ✅ แตะเฉพาะ: log wrapping, dashboard/chart draw guards ใน Tester, throttle เพิ่มเติม (input ใหม่), bypass network call ใน Tester

---

## ไฟล์ที่จะแก้ (เมื่อ approve)
- `public/docs/mql5/Golden2_EA.mq5` — bump version → **2.9.1**, header + #property + Dashboard title
- `.lovable/memory/trading/golden2-ea/v2-9-1-backtest-performance-pack.md` — สร้างใหม่
- `.lovable/memory/index.md` — append

## ผลลัพธ์ที่คาดหวัง
- Backtest เร็วขึ้นรวม **30-60%** บน EURUSD/XAUUSD ระยะ 1 ปี (ขึ้นกับ verbose/dashboard เดิม)
- Optimization (Genetic) เร็วขึ้นมากกว่านั้นเพราะแต่ละ pass สั้นลง
- Live trading: ไม่เปลี่ยนแปลงพฤติกรรมใด ๆ
