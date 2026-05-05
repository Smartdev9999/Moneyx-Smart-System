## เป้าหมาย
สร้าง EA ใหม่ `public/docs/mql5/Golden_Kuy3_EA.mq5` v1.0 — เน้นความเรียบง่าย: Instant entry + Grid ชุดเดียว (เลือก Both/Buy/Sell) + ระบบ TP/Trailing แบบ Gold Miner ครบชุด ไม่มี indicator, ไม่มี Hedge/News/License/Sync

---

## 1. Instant Entry (ไม่มี indicator)
- `InpInitSideMode` — `BOTH` / `BUY_ONLY` / `SELL_ONLY`
- เมื่อ EA โหลด/ฝั่งใดว่าง → เปิด market BUY ที่ Ask และ/หรือ SELL ที่ Bid ทันทีด้วย `InpInitialLot`
- Comment ฝั่ง init: `GK_INIT_BUY` / `GK_INIT_SELL` (ใช้ตรวจ initial price กลาง)
- Re-entry: ฝั่งใดถูกปิดหมด (เหลือ 0 position ฝั่งนั้น) → เปิด initial ใหม่ตามฝั่งที่อนุญาต

## 2. Grid ชุดเดียว (Up/Down รอบ Initial เป็นจุดกลาง)
หลักการ: ไม่มี Loss/Profit grid แยก — ใช้ลำดับ ticket จากน้อย→มากต่อฝั่ง
- `InpGridSideMode` — `BOTH` / `UP_ONLY` / `DOWN_ONLY`
  - UP = ออก grid ขึ้นไปด้านบน (ใช้กับฝั่ง BUY ที่ราคา > initial หรือ SELL ที่ราคา > initial)
  - DOWN = ตรงข้าม
- `InpGridDistancePips` — ระยะห่างขั้นต่ำจาก ticket ล่าสุดของฝั่งนั้น
- `InpGridLotMode` — `FIXED` / `ADD` / `MULTIPLY`
  - FIXED: lot คงที่ = `InpGridLotValue`
  - ADD: lot ของ grid ใหม่ = lot ticket ล่าสุด + `InpGridLotValue`
  - MULTIPLY: lot ของ grid ใหม่ = lot ticket ล่าสุด × `InpGridLotValue`
- `InpMaxGridOrders` — จำนวน grid สูงสุดต่อฝั่ง (ไม่นับ initial)
- `InpGridOnlyNewCandle` (bool, M1) — รอแท่งใหม่ก่อนยิง grid ถัดไป
- ตัวกลาง = ราคาเปิดของ initial ticket ฝั่งนั้น (เก็บไว้ใน global เมื่อ initial เปิด)
- ทิศทาง: เทียบ Ask/Bid ปัจจุบันกับ "ticket ล่าสุดของฝั่ง" (เรียง ticket น้อย→มาก, ตัวล่าสุด = ticket มากสุด)
  - ฝั่ง BUY: ราคา ≤ ticket ล่าสุด − distance → ลง grid DOWN; ราคา ≥ ticket ล่าสุด + distance → ลง grid UP
  - ฝั่ง SELL: เช่นเดียวกัน
- Comment grid: `GK_GRID_BUY_<n>` / `GK_GRID_SELL_<n>`

## 3. Trailing Stop Per Order (จาก Gold Miner)
- `InpEnablePerOrderTrailing` (bool)
- `InpTrailingActivationPips`, `InpTrailingStepPips`, `InpBreakevenActivationPips`, `InpBreakevenBufferPips`
- Logic: ทุก ticket (init+grid) → เมื่อกำไร ≥ Activation pips → set SL = entry + Breakeven buffer; กำไรเพิ่ม → trail SL ตาม Step pips
- Push เป็น broker SL จริง (เหมือน v6.85 Gold Miner) ผ่าน `SyncBrokerTPSL`

## 4. Average TP (จาก Gold Miner)
- `InpEnableAverageTP` (bool)
- `InpAverageTPPips` — ระยะ pips จาก average price
- คำนวณ weighted average price ต่อฝั่ง (ทุก ticket รวม init+grid)
- เมื่อจำนวน position ฝั่งนั้น ≥ `InpAvgTP_MinOrders` → push broker TP ของทุก ticket ฝั่งนั้นให้ตรงกัน = avg ± Average TP pips
- ถ้าจำนวน = 1 → คงค่า TP เริ่มต้นจาก initial (โหมด Initial TP)
- `InpInitialTPPips`, `InpInitialSLPips` — TP/SL เริ่มต้นของ ticket แรกต่อฝั่ง
- เคารพ `STOPS_LEVEL` ของโบรก

## 5. Average Trailing Stop (จาก Gold Miner v6.85/v6.86/v6.90/v6.91)
- `InpEnableAvgTrailing` (bool)
- `InpAvgTrail_ActivationPips` — กำไร basket (จาก avg price) ต้องถึงค่านี้ถึงจะ ARM
- `InpAvgTrail_StepPips` — เลื่อน SL ตาม step
- `InpAvgTrail_BE_Buffer` — buffer breakeven หลัง trail
- `InpAvgTrail_MinOrders` — จำนวน position ขั้นต่ำต่อฝั่งที่จะเปิดใช้
- Strict 2-Cross ARM (v6.91): BUY ต้องเห็นราคา < avg ก่อน แล้ว cross กลับมา > avg+activation จึง ARM (กัน ARM-then-close ทันที); SELL กลับด้าน
- เมื่อ Trail SL โดน hit → ปิดทุก ticket ฝั่งนั้นพร้อมกัน (per-side reset แบบ v6.84 — อีกฝั่งไม่ถูกล้าง state)
- Push broker SL จริงทุก ticket (avg trailing) — ลำดับความสำคัญสูงกว่า Per-Order Trailing

---

## Module Boundaries (ห้ามใส่ตามกฎเหล็ก #7)
- ❌ ไม่มี License / News / Sync / Hedge / Triple-Gate / Recovery / Hero
- ❌ ไม่มี Squeeze / BB / SMA / EMA / ZigZag (Instant only ไม่มี indicator)

## Dashboard
แผงเดียวบน chart — แสดง:
- Header: `Golden Kuy3 v1.0  Side:BOTH/BUY/SELL  Grid:BOTH/UP/DOWN`
- BUY block: count, total lot, avg price, floating P/L, last grid ticket, trailing state
- SELL block: เหมือนกัน
- Avg TP / Avg Trail สถานะ (WAIT/READY/ARMED) ต่อฝั่ง

## โครงไฟล์
```
public/docs/mql5/Golden_Kuy3_EA.mq5  (~1500-2000 บรรทัด)
├─ Inputs (5 group: General / Grid / Per-Order Trail / Avg TP / Avg Trail)
├─ Globals (initial price ต่อฝั่ง, ticket ล่าสุด, trailing SL state, avg trail state)
├─ OnInit / OnDeinit / OnTick / OnChartEvent
├─ Helpers: GetLastTicketLot/Price, CalcAvgPrice, CountSide, MakeComment
├─ ManageInitialEntry()
├─ ManageGridEntry()
├─ ManagePerOrderTrailing()
├─ ManageAverageTP()
├─ ManageAverageTrailing()
├─ SyncBrokerTPSL()  (รวม priority: AvgTrail > PerOrder > Initial)
└─ DrawDashboard()
```

## Inputs สำคัญ (สรุป)
```
=== General ===
InpMagicNumber=33001, InpInitSideMode=BOTH, InpInitialLot=0.01,
InpInitialTPPips=200, InpInitialSLPips=0
=== Grid ===
InpEnableGrid=true, InpGridSideMode=BOTH, InpGridDistancePips=150,
InpGridLotMode=MULTIPLY, InpGridLotValue=1.5, InpMaxGridOrders=20,
InpGridOnlyNewCandle=true
=== Per-Order Trailing ===
InpEnablePerOrderTrailing=false, InpTrailingActivationPips=80,
InpTrailingStepPips=20, InpBreakevenActivationPips=50, InpBreakevenBufferPips=10
=== Average TP ===
InpEnableAverageTP=true, InpAverageTPPips=50, InpAvgTP_MinOrders=2
=== Average Trailing ===
InpEnableAvgTrailing=true, InpAvgTrail_ActivationPips=100,
InpAvgTrail_StepPips=20, InpAvgTrail_BE_Buffer=20, InpAvgTrail_MinOrders=3
```

## สิ่งที่ไม่เปลี่ยนแปลง
- ไม่แตะ EA ตัวอื่น (Gold Miner / Golden2 / Asset Miner / Jutlameasu / Harmony / MoneyX)
- ไม่เปลี่ยน schema / supabase / frontend

## Files
- `public/docs/mql5/Golden_Kuy3_EA.mq5` — สร้างใหม่
- `.lovable/memory/trading/golden-kuy3/v1-0-init.md` — บันทึก spec
- `mem://index.md` — append entry

## ขอยืนยัน 2 จุดก่อนสร้าง
1. **Initial re-entry**: ฝั่งที่ปิดหมดแล้วต้องการให้ EA เปิด init ใหม่ทันที **ทุกครั้ง** ใช่ไหม? หรือเปิดครั้งเดียวตอน OnInit เท่านั้น?
2. **เมื่อ Avg TP / Avg Trail ปิด basket ฝั่งใดฝั่งหนึ่ง** — ต้องการให้ EA เปิด initial ฝั่งนั้นใหม่อัตโนมัติเลย หรือรอ user (โดย default ผมจะทำเป็น auto re-entry ตามข้อ 1)
