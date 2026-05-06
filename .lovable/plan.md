## แผน v1.59: Max Lot + Max DD Close (minimal)

### Inputs ที่เพิ่ม (น้อยที่สุด)

**Group ใหม่ `=== Risk Limits ===`**
- `InpMaxLotPerOrder` (double, default 0) — 0 = ไม่จำกัด, ค่ามากกว่า 0 = cap lot ต่อ order
- `ENUM_GK_DD_MODE { GK_DD_OFF=0, GK_DD_PERCENT=1, GK_DD_DOLLAR=2 }`
- `InpMaxDDMode` (enum, default GK_DD_OFF)
- `InpMaxDDValue` (double, default 20.0) — ความหมายตาม mode (% ของ balance หรือ $ floating loss)

แค่ 3 inputs

### การทำงาน

**1. Max Lot per Order**
- แก้ `CalcGridLot()` (line 1163) เพิ่ม cap ก่อน normalize:
  - ถ้า `InpMaxLotPerOrder > 0` และ `out > InpMaxLotPerOrder` → `out = InpMaxLotPerOrder`
- ป้องกัน lot โตเกินตอนคูณไปไกลๆ
- ไม่กระทบ `InpInitialLot` หรือ FIXED/ADD/MULTIPLY logic

**2. Max DD Close**
- helper `ManageMaxDDClose()` รันต้น `OnTick` ก่อน `ManageTakeProfit`
- ถ้า `InpMaxDDMode == GK_DD_OFF` → return
- คำนวณ floating รวมทั้ง 2 ฝั่ง (รวม Hero ด้วยเพื่อความปลอดภัย)
- เช็ค trigger:
  - `GK_DD_PERCENT`: ถ้า `floating < 0` และ `|floating|/balance*100 >= InpMaxDDValue` → ยิง
  - `GK_DD_DOLLAR`: ถ้า `floating <= -InpMaxDDValue` → ยิง
- เมื่อ trigger:
  - set `g_oppCloseIntent_AvgTP_Buy/Sell = true` (ให้ Hero ปิดตามตามกติกา v1.51/v1.57)
  - เรียก `CloseAllOurs()` (ฟังก์ชันที่มีอยู่แล้ว)
  - log throttled
- ใช้ cooldown 30s ภายใน (hardcoded) กันยิงซ้ำ

### Dashboard (1 บรรทัด)
ใน section `=== TAKE PROFIT ===` เพิ่มหลัง row Accumulate:
- `Risk Limits`: `MaxLot:1.00  DD:PERCENT 20.0% (curr 4.3%)`
  - หรือ `MaxLot:OFF  DD:OFF` ถ้าปิดทั้งคู่

### Version bump v1.58 → v1.59
- `#property version "1.59"`, description, header (สั้น), dashboard title

### ไฟล์
- `public/docs/mql5/Golden_Kuy3_EA.mq5`
- create `mem://trading/golden-kuy3/v1-59-max-lot-and-max-dd-close`
- update `mem://index.md`

### สิ่งที่ไม่เปลี่ยนแปลง (กฎเหล็ก)
- ไม่แตะ `OrderSend` / `trade.Buy` / `trade.Sell` / `trade.PositionClose` (ใช้ `CloseAllOurs()` เดิม)
- ไม่แตะ Grid entry / new-candle gate / distance check / lot mode logic
- ไม่แตะ Per-Order BE/Trail, Avg-TP, Avg-Trail strict 2-cross, Accumulate, Cost-Hit
- ไม่แตะ Hero logic ทั้งหมด (Handoff Reserve, Conditional Lock, Alternation, Single-Side Lock, IsHeroProtectedTicket, ApplyHeroLockProfitSL, TP-event latch)
- ไม่แตะ Auto re-entry / Init side mode
- `InpMaxLotPerOrder=0` + `InpMaxDDMode=OFF` → behavior เหมือน v1.58 ทุกประการ
