---
name: Golden Kuy3 v1.1 BE/Trail split + TP modes + Avg/TP lines + table dashboard
description: Per-order trailing split into independent InpEnableBreakevenLock + InpEnableTrailingStop; full Gold-Miner Take Profit modes (Dollar/Points/%Bal/Accumulate) with master InpUseTakeProfit; auto-strip stale broker TP when Points mode OFF; OBJ_HLINE avg + TP lines per side; Gold-Miner-style table dashboard with rectangle-bg rows
type: feature
---

ไฟล์: `public/docs/mql5/Golden_Kuy3_EA.mq5` (v1.0 → v1.1)

## 1. Per-Order BE Lock / Trailing — Split toggles
- `InpEnablePerOrderTrailing` (เก่า, รวม) → ลบ
- `InpEnableBreakevenLock` (default ON) — เมื่อกำไร ≥ `InpBreakevenActivationPips` ตั้ง broker SL = `open ± InpBreakevenBufferPips` ของใครของมัน ทุก ticket BUY/SELL
- `InpEnableTrailingStop` (default OFF) — เมื่อกำไร ≥ `InpTrailingActivationPips` ลาก SL = `open ± (profitPips - InpTrailingStepPips)`; ถ้า BE ON ด้วย ใช้ค่าที่ป้องกันมากกว่า
- ใช้เดี่ยว / คู่ / ปิดทั้งคู่

## 2. Take Profit — โหมดครบเหมือน Gold Miner
Inputs ใหม่ (group `=== Take Profit ===`):
- `InpUseTakeProfit` (master, default ON)
- `InpUseTPFixedDollar` + `InpTPDollarAmount` — ปิดฝั่งเมื่อ floating ≥ $
- `InpUseTPPoints` + `InpTPPointsFromAverage` — push broker TP ที่ `avg ± points` (ใช้ `g_point`)
- `InpUseTPPercentBalance` + `InpTPPercentOfBalance` — ปิดฝั่งเมื่อ floating ≥ `% × balance`
- `InpUseAccumulateClose` + `InpAccumulateTarget` — ปิด **ทั้ง 2 ฝั่ง** เมื่อ `realized + floating ≥ target`
- `InpAvgTP_MinOrders` ใช้ร่วมกับโหมด Points

`ManageTakeProfit()` เช็คเรียง: Accumulate → Dollar → %Bal → Points

## 3. Stale Broker TP Fix
`OpenInitial()` ส่ง TP ก็ต่อเมื่อ `InpUseTakeProfit && !InpUseTPPoints && InpInitialTPPips>0`. `EnforceClearTPIfDisabled()` รัน throttle 5s → ถ้า Points mode OFF → modify ทุก ticket ของเราที่ TP>0 → ตั้ง TP=0 (เคลียร์เส้น TP บนชาร์ตที่ค้าง)

## 4. Chart Lines (Avg + TP)
Group `=== Chart Lines ===`:
- `InpShowAvgLine` + `InpAvgBuyLineColor`/`InpAvgSellLineColor` — `OBJ_HLINE` width 3 SOLID
- `InpShowTPLine` + `InpTPBuyLineColor`/`InpTPSellLineColor` — width 1 DASH, วาดเฉพาะตอน Points mode ON และ count ≥ MinOrders
- ลบเมื่อฝั่งนั้น 0 ออเดอร์ หรือ toggle OFF; `OnDeinit` ลบทั้งหมด (`g_linePrefix = "GK_LINE_"`)

## 5. Dashboard ตารางแบบ Gold Miner
- ใช้ `OBJ_RECTANGLE_LABEL` พื้นหลังต่อ row + `OBJ_LABEL` 2 คอลัมน์ (label / value)
- 6 sections: Title / ACCOUNT / POSITIONS / MODULES / TAKE PROFIT / AVG TRAIL STATE / SYSTEM
- Inputs: `InpDashX/Y/RowH/ColW1/ColW2/HeaderColor/RowBgColor/AltRowBgColor/HeaderBgColor`
- รี-แดรว์ทั้งกระดาน (DelDash + redraw) ตาม `InpDashRefreshSec`

## 6. Realized Cycle Tracking
`OnTradeTransaction` หา deal type=DEAL_ADD entry=OUT/INOUT ของ magic+symbol → สะสมใน `g_realizedCycle` (ใช้กับ Accumulate Close + แสดงใน dashboard)

## ไม่เปลี่ยน (กฎเหล็ก MQL5)
- ❌ ไม่แตะ `OrderSend` / `trade.Buy` / `trade.Sell` / `trade.PositionClose` (เพิ่มเฉพาะ tp=0 condition ใน OpenInitial)
- ❌ ไม่แตะ Grid distance / lot calc / new-candle gate
- ❌ ไม่แตะ Auto re-entry / Init side mode
- ❌ ไม่แตะ Avg Trailing (strict 2-cross + step + BE buffer ตาม v6.91 เดิม)
- ❌ ไม่มี License / News / Sync / Hedge / Hero / Squeeze

## Version
v1.0 → v1.1 (`#property version "1.10"`, description, header banner, init/deinit Print, dashboard title)
