
# Gold Miner EA v6.83 — Trailing Stop Throttle Fix

## ปัญหาที่พบ (จาก Journal log + screenshot)
ทุก tick ระบบยิง `CTrade::OrderSend: modify position #X ... sl: 4467.93, tp: 4512.37 [done]` ครบทุก ticket — เพราะ:

1. **`ManageTrailingStop()` (Average-Based)** เรียก `ApplyTrailingSL(side, slPrice)` ทันทีที่ `newSL > g_trailingSL_Buy` — แต่ใน `ApplyTrailingSL()` เงื่อนไข modify คือ `slPrice > currentSL` เท่านั้น ไม่มี **TrailingStep buffer** → ทุกๆ point ที่ราคาขยับ จะ modify ทุก ticket (24 ticket = 24 modify/tick)
2. **`ManageMaxGridTrailing()`** เก็บ SL ใน global var แต่ไม่ได้ push ไป broker — **อันนี้ไม่มีปัญหา** (ปิดเองในโค้ด)
3. **`ManagePerOrderTrailing()`** มี `InpTrailingStep` กันอยู่แล้ว — ปัญหาน้อย แต่จะเสริม guard ป้องกัน SL เท่ากันด้วย

## สิ่งที่จะทำ (v6.83)

### A. ใส่ Step Threshold ใน Average-Based Trailing
- ใน `ManageTrailingStop()` BUY/SELL: เปลี่ยนเงื่อนไข push SL จาก `newSL > g_trailingSL_Buy` → `newSL >= g_trailingSL_Buy + TrailingStep * point` (เลื่อน SL อย่างน้อย `TrailingStep` points จึงจะส่ง modify)
- ฝั่ง SELL: `newSL <= g_trailingSL_Sell - TrailingStep * point`
- กรณี `g_trailingSL_Buy == 0` (ครั้งแรก) → ส่ง modify ปกติ

### B. ป้องกัน Modify ซ้ำใน `ApplyTrailingSL()`
- เพิ่ม guard: ก่อนเรียก `trade.PositionModify(ticket, slPrice, tp)` เช็ค `MathAbs(currentSL - slPrice) >= point` (ถ้า SL ที่อยู่บน ticket นั้นเท่ากับ slPrice อยู่แล้ว → skip)
- สำหรับ ticket ที่ยังไม่มี SL (`currentSL == 0`) ให้ modify ปกติ

### C. ป้องกัน Modify ซ้ำใน `ManagePerOrderTrailing()` (เสริม)
- BUY/SELL: เช็คเพิ่มก่อน `trade.PositionModify(...)` ทั้ง Step 1 (Breakeven) และ Step 2 (Trailing) ว่า `MathAbs(currentSL - newSL) >= point` ไม่งั้น skip

### D. (Optional) Throttle Per-Tick → Per-N-Seconds
- เพิ่ม global `g_lastTrailModifyTime` + input `InpTrail_MinIntervalMs = 250` (ms) — ถ้า tick ก่อนหน้าเพิ่งยิง modify ภายใน 250ms ให้ skip
- **ค่า default 0 = ปิด** เพื่อไม่กระทบพฤติกรรมเดิม (เปิดเฉพาะ broker ที่อ่อนไหว)

### E. Version Bump
- `#property version "6.83"`, header comment, OnInit log, Dashboard title → v6.83

## ✅ สิ่งที่ไม่เปลี่ยนแปลง (รับประกัน)
- **Trading logic ทั้งหมดคงเดิม**: SMA/Grid/Hedge/Triple-Gate/Accumulate/DD/Squeeze
- **ค่า SL ที่คำนวณเหมือนเดิม** — แค่ลดความถี่ในการ push ไป broker
- **เงื่อนไข Activation/Breakeven/TrailingActivation คงเดิม** ทุกตัว
- **Max Grid Average Trailing logic คงเดิม** (ไม่ได้ push SL ไป broker อยู่แล้ว)
- ไม่แตะ OrderSend / PositionClose / Hedge module / News / License

## ผลลัพธ์ที่คาดหวัง
- จากภาพ log: 24 modify/tick → เหลือ modify เฉพาะตอน SL ขยับครบ `TrailingStep` (เช่นทุก 50 points)
- ลดโหลด broker server, ลด log spam, ลดโอกาส requote/timeout

## ไฟล์ที่จะแก้
- `public/docs/mql5/Gold_Miner_EA.mq5`
- `.lovable/memory/trading/gold-miner-ea/trailing-modify-throttle-v6-83.md` (new)
- `.lovable/plan.md`
