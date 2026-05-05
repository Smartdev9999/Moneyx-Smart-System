## Golden Kuy3 EA v1.1 → v1.2

ไฟล์: `public/docs/mql5/Golden_Kuy3_EA.mq5`
เอกสารใหม่: `.lovable/memory/trading/golden-kuy3/v1-2-dash-flicker-grid-fix-cost-hit-restart.md`

---

### 1) แก้แดชบอร์ดกระพริบ (Dashboard Flicker Fix)

ปัญหา: `DrawDashboard()` เรียก `DelDash()` ทุก refresh (default 1s) ลบ object ทั้งหมดแล้วสร้างใหม่ → ตา MT5 เห็นเป็นเฟรมกระพริบเปิด-ปิด

แก้:
- ลบ `DelDash()` ออกจาก `DrawDashboard()` (เก็บไว้ใช้ที่ `OnDeinit`)
- `SetRectBg()` / `SetCell()` ใช้ `ObjectFind` อยู่แล้ว → update in-place ไม่ต้อง recreate
- เพิ่ม "high-water row tracker" `g_dashRowMax` — ถ้า row count รอบนี้น้อยกว่ารอบก่อน ให้ลบเฉพาะ row ส่วนเกิน (ไม่กวาดทั้งกระดาน)
- ใช้ `ChartSetInteger(0, CHART_FOREGROUND, false)` ครั้งเดียวก็พอ ไม่ต้องสั่งทุก tick

ผลลัพธ์: dashboard นิ่ง อัปเดตค่าเฉพาะ cell ที่เปลี่ยน

---

### 2) แก้ Grid Multiplier / Add Lot ไม่ทำงาน

ปัญหา 2 ชั้น:
- `NormalizeLot()` ใช้ `MathRound(lot/step)*step`. ด้วย step ปกติ 0.01 และ mult 1.1: `0.01*1.1=0.011 → round(1.1)=1 → 0.01` (เท่าเดิม) ทำให้ทุก grid ยังเป็น 0.01 → ดูเหมือน "ไม่ทำงาน"
- ADD โหมดที่ค่า value < step ก็เจอปัญหาเดียวกัน

แก้ใน `CalcGridLot(double lastLot)`:
1. คำนวณ raw target lot ตามโหมด (FIXED/ADD/MULTIPLY) เหมือนเดิม
2. **Force minimum increment**: ถ้าโหมดเป็น ADD/MULTIPLY และ target ที่ normalize แล้ว ≤ lastLot → บังคับเพิ่ม 1 × `SYMBOL_VOLUME_STEP` จาก lastLot
3. ใช้ `MathCeil` แทน `MathRound` สำหรับโหมด ADD/MULTIPLY (กันการปัดลง)

เพิ่ม diagnostic Print ตอน open grid: `lastLot=… mult=… raw=… normalized=…` เพื่อดูค่าใน Experts log

ไม่แตะ logic การวัดระยะ / เงื่อนไข fire grid / `OrderSend` / `trade.Buy/Sell`

---

### 3) ฟีเจอร์ใหม่: Cost-Hit Restart Grid

แนวคิด: เมื่อออเดอร์ใดถูกปิดเพราะชนกันทุน (BE-Lock SL หรือ Trailing SL) ฝั่งนั้นจะ "เกิดใหม่" ด้วยขนาด initial lot ทันทีที่ราคาปิดออเดอร์ตัวนั้น แล้ว grid multiplier เริ่มนับจากตัวใหม่

#### Inputs ใหม่ (กลุ่ม `=== Grid (single set) ===`)
| Input | Default | หมายเหตุ |
|---|---|---|
| `InpEnableCostHitRestart` | `false` | master toggle |
| `InpCostHitMinSpacingPips` | `100.0` | ระยะขั้นต่ำที่ออเดอร์ใหม่ต้องห่างจาก position เดิมฝั่งเดียวกันที่ใกล้ที่สุด |
| `InpCostHitCooldownSec` | `2` | กัน double-fire ต่อฝั่ง |

#### กลไก
1. **ตรวจจับการชนกันทุน** ใน `OnTradeTransaction` (deal type = `DEAL_ADD`, entry = `DEAL_ENTRY_OUT/INOUT/OUT_BY`):
   - อ่าน reason ผ่าน `HistoryDealGetInteger(deal, DEAL_REASON)`
   - นับเป็น "cost-hit" เมื่อ reason ∈ `{DEAL_REASON_SL, DEAL_REASON_TP}` และ deal ของเรา (magic+symbol ตรง)
   - เก็บ `g_costHit_Pending_Buy/Sell = true`, `g_costHit_Price_Buy/Sell = closePrice`, `g_costHit_Time_*`
2. **Re-open ใน `OnTick`** (ฟังก์ชันใหม่ `ManageCostHitRestart()`) ก่อน `ManageInitialEntry`/`ManageGridEntry`:
   - ถ้า pending ฝั่งนั้น = true และ cooldown หมด:
     - เช็ค **Distance Guard**: ออเดอร์ใหม่ต้องห่างจากทุก position ฝั่งเดียวกันที่เหลืออยู่ ≥ `InpCostHitMinSpacingPips` (วัดจากราคาตลาดปัจจุบัน)
     - ถ้า OK → เปิด initial lot ใหม่ฝั่งเดิมที่ราคาตลาด (comment = `GK_RESTART_BUY/SELL`) แล้ว clear pending
     - ถ้าใกล้เกิน → คงสถานะ pending ไว้ รอราคาเลื่อนห่าง (ทุกๆ tick re-check)
3. **Grid ถัดไป**: เพราะ `CountSide()` คืน "last by highest ticket" อยู่แล้ว ออเดอร์ restart (ticket ใหม่สุด) จะกลายเป็น base ของ multiplier โดยอัตโนมัติ → mult-chain เริ่มจาก `InitialLot` ใหม่ตามที่ user ต้องการ
4. **Distance Guard ก่อนยิง grid** (ปรับ `ManageGridEntry` เล็กน้อย):
   - เพิ่ม helper `HasNearbyPosition(side, refPrice, minPips)` ตรวจว่ามี position ฝั่งเดียวกันอยู่ภายใน `InpGridDistancePips` จาก `refPrice` ปัจจุบันหรือไม่
   - ถ้ามี → skip grid (รอราคาเลื่อนต่อ) — ป้องกันออเดอร์ทับซ้อนหลัง restart
   - ใช้ guard นี้เฉพาะเมื่อ `InpEnableCostHitRestart=true` (โหมด default ไม่กระทบ)

#### ทำไมไม่แตะ logic ปิดออเดอร์
- ใช้เฉพาะ `OnTradeTransaction` เป็น "ผู้สังเกต" (read-only)
- ไม่ปิด/ไม่เลื่อน SL ของ BE-Lock หรือ Trailing — ปล่อยให้ broker ปิดเองตามปกติ
- Re-open ใช้ `trade.Buy/Sell` ผ่าน path เดิม (ไม่สร้างฟังก์ชัน OrderSend ใหม่)

#### Dashboard
เพิ่ม row ในกลุ่ม `=== MODULES ===`:
```
Cost-Hit Restart  ON/OFF  spc=100p cd=2s
```
และ row pending status ใน `=== SYSTEM ===`:
```
Restart Pending   BUY:- SELL:WAIT@1234.56
```

---

### 4) Version + Memory

- `#property version "1.20"`, description, header banner, dashboard title → `Golden Kuy3 v1.2`
- เพิ่ม `mem://trading/golden-kuy3/v1-2-dash-flicker-grid-fix-cost-hit-restart`
- อัปเดต `mem://index.md`

---

### สิ่งที่ "ไม่เปลี่ยน" (กฎเหล็ก MQL5)

- ไม่แตะ `OrderSend` / `trade.Buy` / `trade.Sell` / `trade.PositionClose` / `trade.PositionModify` (เรียกใช้ตามแพทเทิร์นเดิม)
- ไม่แตะ Grid distance / lot calc สูตร (เพิ่มเฉพาะ ceil + min-step floor)
- ไม่แตะ Per-Order BE / Trailing / Avg Trailing (strict 2-cross v6.91)
- ไม่แตะ TP modes (Dollar/Points/%Bal/Accumulate) และ EnforceClearTPIfDisabled
- ไม่แตะ Auto Re-Entry / Init Side Mode (Cost-Hit Restart เป็นเลเยอร์แยก ทำงานก่อน Auto Re-Entry; ถ้า Cost-Hit OFF พฤติกรรมเดิมทุกอย่าง)
- ไม่มี License / News / Sync / Hedge / Hero / Squeeze
