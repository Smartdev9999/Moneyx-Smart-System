## Golden Kuy3 EA — Upgrade to v1.1

ไฟล์ที่แก้: `public/docs/mql5/Golden_Kuy3_EA.mq5`
เอกสารใหม่: `.lovable/memory/trading/golden-kuy3/v1-1-be-trail-split-avgtp-modes-dashboard.md`

---

### 1) Per-Order Trailing — แยก Break-even / Trailing เลือกได้อิสระ

แทน `InpEnablePerOrderTrailing` ตัวเดียว เป็น 2 toggle:

- `InpEnableBreakevenLock` (default `true`) — ล็อกหน้าทุนต่อ ticket
  - กระตุ้นเมื่อกำไรจาก `openPrice` ถึง `InpBreakevenActivationPips`
  - ตั้ง broker SL = `openPrice ± InpBreakevenBufferPips` (BUY = บวก, SELL = ลบ)
  - ของใครของมัน เปิดเฉพาะตัวที่กำไรพอ ทำงานทั้งฝั่ง BUY/SELL ทุกออเดอร์ (initial + grid)
- `InpEnableTrailingStop` (default `false`) — ลากต่อจาก BE
  - ทำงานเฉพาะเมื่อกำไรถึง `InpTrailingActivationPips`
  - SL = `openPrice ± (profitPips - InpTrailingStepPips)`, เพดานล่าง = `BreakevenBufferPips`
  - ใช้ได้เดี่ยว / ใช้คู่กับ Breakeven / ปิดทั้งคู่

`ComputePerOrderSL()` ปรับ logic:
1. ถ้า BreakevenLock ON และ `profit ≥ BeAct` → set SL = BE+buffer
2. ถ้า TrailingStop ON และ `profit ≥ TrailAct` → wrap SL = trailing (overrides BE ถ้าไกลกว่า)
3. ถ้าไม่เข้าเงื่อนไขเลย → return 0 (ไม่ modify)

ผลลัพธ์: เลือกใช้ BE-only ก็ได้ (ทุก order มี SL กันทุนของตัวเอง), Trailing-only ก็ได้, ทั้งคู่ก็ได้

---

### 2) Take Profit — เพิ่มโหมดให้ครบเหมือน Gold Miner + แก้ stale TP บนชาร์ต

#### Bug fix
ตอนนี้แม้ `InpEnableAverageTP=false` ออเดอร์ initial ยังถูก push `InpInitialTPPips` (default 200) จาก `OpenInitial()` → ชาร์ตจึงยังขีดเส้น TP. แก้:

- เพิ่ม master toggle `InpUseTakeProfit` (default `true`). ถ้า `false`:
  - `OpenInitial()` ส่ง `tp=0`
  - `EnforceClearTPIfDisabled()` วน positions ของเรา ทุกตัวที่ `pos.TakeProfit()>0` → `PositionModify(sl, 0)` (throttled 5s)
- `InpEnableAverageTP`/`InpUseTPDollar`/`InpUseTPPoints`/`InpUseTPPercent` ทั้งหมด OFF → ก็เคลียร์เช่นกัน

#### โหมด TP ใหม่ (port จาก Gold Miner ในรูป)
เพิ่มกลุ่ม `=== Take Profit ===`:

| Input | Default | หมายเหตุ |
|---|---|---|
| `InpUseTakeProfit` | true | master |
| `InpUseTPFixedDollar` | false | ปิดทั้งฝั่งเมื่อ floating PL ฝั่งนั้น ≥ `InpTPDollarAmount` |
| `InpTPDollarAmount` | 100.0 | $ |
| `InpUseTPPoints` | true | push broker TP ที่ `avg ± points` |
| `InpTPPointsFromAverage` | 500.0 | points (เดิมใช้ `InpAverageTPPips`; เก็บไว้เป็น alias) |
| `InpUseTPPercentBalance` | false | ปิดเมื่อ floating ฝั่งนั้น ≥ `% × balance` |
| `InpTPPercentOfBalance` | 26.0 | % |
| `InpUseAccumulateClose` | false | ปิดทั้ง 2 ฝั่งเมื่อ realized+floating ≥ `InpAccumulateTarget` (cycle reset เมื่อทุก ticket flat) |
| `InpAccumulateTarget` | 20000 | $ |
| `InpAvgTP_MinOrders` | 2 | (เดิม) |

`ManageTakeProfit()` รวมทุกโหมด (เรียงลำดับ): Accumulate → Dollar → Percent → Points (push broker TP)
- 3 โหมดแรก → close ฝั่ง / ทั้งคู่
- โหมด Points → push broker TP ทุก ticket ฝั่งนั้น
- ถ้าโหมด Points OFF → ไม่ push broker TP เลย → คู่กับ `EnforceClearTPIfDisabled()` กันเส้น TP ค้าง

`InpEnableAverageTP`/`InpAverageTPPips` deprecate เป็น alias (ไม่กระทบ .set เดิม)

---

### 3) เส้นค่าเฉลี่ย + เส้น TP บนชาร์ต (Gold Miner style)

กลุ่ม `=== Chart Lines ===`:

- `InpShowAvgLine` (true)
- `InpAvgBuyLineColor` (`clrDodgerBlue`)
- `InpAvgSellLineColor` (`clrOrangeRed`)
- `InpShowTPLine` (true)
- `InpTPBuyLineColor` (`clrLime`)
- `InpTPSellLineColor` (`clrMagenta`)

`DrawAvgAndTPLines()` ใช้ `OBJ_HLINE` prefix `GK_LINE_` 4 เส้น (avg buy / avg sell / tp buy / tp sell), update ทุกครั้งใน `OnTick` หลังคำนวณ avg + tp; ลบเส้นเมื่อฝั่งนั้น 0 ออเดอร์ หรือ toggle OFF; ลบทั้งหมดใน `OnDeinit`

---

### 4) Dashboard ตารางแบบ Gold Miner

ใช้ `OBJ_RECTANGLE_LABEL` พื้นหลังต่อ row + `OBJ_LABEL` 2 คอลัมน์ (label / value) เหมือน Golden2 v1.5 และ Gold Miner หน้าตัวอย่าง:

```
=== ACCOUNT ===
Balance / Equity / Floating P/L
=== POSITIONS ===
BUY P/L Lot Ord
SELL P/L Lot Ord
Total Cur. Lot
=== MODULES ===
Init Side / Grid / Per-Order Trail / BE Lock / Avg TP / Avg Trail
=== TP MODES ===
Dollar / Points / %Bal / Accumulate (ON/OFF + target)
=== AVG TRAIL ===
BUY: WAIT/READY/ARMED  SL:xxx
SELL: WAIT/READY/ARMED SL:xxx
=== SYSTEM ===
Cycle realized / TP-stripped status
```

Inputs: `InpDashX` `InpDashY` `InpDashRowH` `InpDashColW1` `InpDashColW2` `InpDashHeaderColor` `InpDashRowBgColor` `InpDashAltRowBgColor` (โทนเดียวกับรูป Golden2)

Throttle ตาม `InpDashRefreshSec`

---

### 5) Internals / Plumbing

- เพิ่ม globals: `g_realizedCycle`, `g_lastTpClearScan`, `g_tpStripped` (bool diag), line-update cache
- `OnTradeTransaction` (ถ้ายังไม่มี): เก็บ realized profit สะสม cycle, reset เมื่อทุก ticket flat
- `EnforceClearTPIfDisabled()` เรียกทุก ~5s ใน OnTick
- `OnDeinit`: ลบ dashboard + ลบเส้น avg/TP

---

### 6) Version + Memory

- `#property version "1.10"`, description, header banner, dashboard title อัปเดตเป็น `v1.1`
- เพิ่มไฟล์ memory + อัปเดต `mem://index.md` แทรกบรรทัด:
  `- [Kuy3 v1.1 BE/Trail+TP Modes](mem://trading/golden-kuy3/v1-1-be-trail-split-avgtp-modes-dashboard) — BE/Trail toggle split, full TP modes (Dollar/Points/%Bal/Accumulate), avg+TP chart lines, Gold-Miner-style dashboard, stale-TP fix`

---

### สิ่งที่ "ไม่เปลี่ยน" (ตามกฎเหล็ก MQL5)

- ❌ ไม่แตะ `OrderSend` / `trade.Buy` / `trade.Sell` / `trade.PositionClose` (เพิ่มเฉพาะ TP=0 เป็น parameter เมื่อ master OFF)
- ❌ ไม่แตะ Grid entry distance / lot calc / new-candle gate
- ❌ ไม่แตะ Auto re-entry / Init side mode
- ❌ ไม่แตะ Avg Trailing strict-2-cross + step + BE_Buffer (ยังคง v6.91 ตามเดิม)
- ❌ ไม่มี License / News / Sync / Hedge / Hero / Squeeze (โครงสร้างยังคงเดิม)
- ✅ แก้/เพิ่มเฉพาะ: TP modes, BE/Trail split, Chart lines, Dashboard, Stale-TP cleanup
