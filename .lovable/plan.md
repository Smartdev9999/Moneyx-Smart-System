

## ปรับปรุง Dashboard ของ Asset Miner EA ให้ครบถ้วนเทียบเท่า Gold Miner EA

### สิ่งที่หายไปจาก Dashboard (เทียบกับ Gold Miner reference)

ตรวจสอบแล้ว Asset Miner Dashboard ปัจจุบันแสดงเพียง 7-8 แถว ในขณะที่ Gold Miner มี 20+ แถว ต่อไปนี้คือรายการที่หายไป:

**Section 1 — ข้อมูลหลัก (ขาดหายไป):**
- Signal (SMA/ZZ) direction
- Position BUY (P/L + Lots + Orders รวมทุก pair)
- Position SELL (P/L + Lots + Orders รวมทุก pair)
- Current DD% และ Max DD% แยกเป็น 2 แถว

**Section 2 — Per-Pair Detail (ต้องขยาย):**
- แต่ละ pair ให้แสดง Lots รวมด้วย (ปัจจุบันแค่ B/S count + P/L)
- เพิ่ม Accum info ต่อ pair (ถ้าเปิดใช้)

**Section 3 — Accumulate (ขาดหายไปทั้งหมด per-pair):**
- Accum. Closed per pair
- Accum. Floating per pair
- Accum. Total + Target + Need per pair

**Section 4 — Trailing (ขาดหายไป):**
- Per-Order Trailing info (BE/Trail status)
- Average Trailing SL info

**Section 5 — History Metrics (ขาดหายไปทั้งหมด + ไม่มี helper functions):**
- Total Current Lot (all pairs)
- Total Closed Lot (all pairs)
- Total Closed Orders (all pairs)
- Monthly P/L (all pairs)
- Total P/L (all pairs)

**Section 6 — Status (ขาดหายไปหรือย่อเกินไป):**
- Auto Re-Entry status
- Daily Profit pause + progress
- System Status (detailed: Working/SUSPENDED/EXPIRED/PAUSED/BLOCKED)
- Time Filter status
- News Filter with countdown timer + event count
- Resume Daily button

### แผนการแก้ไข

**ขั้นที่ 1 — สร้าง Helper Functions ใหม่ (ไม่มีใน Asset Miner):**
- `CalcTotalClosedLotsPair(p)` — sum closed deal volumes per pair (filter by magic + symbol)
- `CalcTotalClosedLotsAll()` — sum ทุก pair
- `CalcTotalClosedOrdersPair(p)` — count closed deals per pair
- `CalcTotalClosedOrdersAll()` — count ทุก pair
- `CalcMonthlyPLPair(p)` — monthly profit per pair
- `CalcMonthlyPLAll()` — monthly profit all pairs
- `CalculateTotalLotsPair(p, side)` — current open lots per pair per side
- `CalculateTotalLotsAll(side)` — current open lots all pairs per side

**ขั้นที่ 2 — ปรับ DisplayDashboard() ให้ครบถ้วน:**

```text
Layout ใหม่:
┌──────────────────────────────────────┐
│ Asset Miner v4.0 [SMA] Multi-Pair   │ Mode: Both
├──────────────────────────────────────┤
│ Balance          $102,798.57         │
│ Equity           $102,778.29         │
│ Floating P/L     $-20.28            │
│ Signal (SMA20)   BUY ▲              │
│ Total BUY        $xx  0.05L  3ord   │
│ Total SELL       $xx  0.09L  5ord   │
│ Current DD%      0.02%              │
│ Max DD%          10.62%             │
├── Per-Pair ──────────────────────────┤
│ P1 XAUUSD  3B/0S 0.03L  $-8.47     │
│ P2 XAUEUR  3B/2S 0.06L  $-11.81    │
│ P3 ...                              │
├── Accumulate ────────────────────────┤
│ Accum. Closed    $205.90            │
│ Accum. Floating  $-20.28            │
│ Accum. Total     $185.62 Tg:$3000   │
├── Trailing ──────────────────────────┤
│ Per-Order   BE:200/5  Trail:200/10  │
├── History ───────────────────────────┤
│ Total Cur. Lot   0.14 L             │
│ Total Closed Lot 5300.58 L          │
│ Total Closed Ord 2837 orders        │
│ Monthly P/L      $13,839.84         │
│ Total P/L        $133,939.84        │
├── Status ────────────────────────────┤
│ Auto Re-Entry    ON                 │
│ Daily Profit     $85.50/$100 PAUSED │
│ System Status    Working            │
│ License          LIFETIME           │
│ Time Filter      ACTIVE             │
│ News Filter      No Important news  │
├──────────────────────────────────────┤
│          ⏸ Pause                     │
│  Close All Buy  │  Close All Sell   │
│         Close All Pairs              │
│         ▶ Resume Daily               │
└──────────────────────────────────────┘
```

**ขั้นที่ 3 — เพิ่ม Resume Daily button:**
- แสดงเฉพาะเมื่อ `InpEnableDailyProfitPause && g_dailyProfitPaused`
- เพิ่ม OnChartEvent handler สำหรับปุ่มนี้

### ไฟล์ที่แก้ไข
`public/docs/mql5/Asset_Miner_EA.mq5` — เพิ่ม ~8 helper functions + rewrite DisplayDashboard() (~120 → ~200 บรรทัด)

### สิ่งที่ไม่เปลี่ยนแปลง
- Trading Strategy Logic — ไม่แตะ
- Order Execution — ไม่แตะ
- Grid / TP/SL / Trailing / Accumulate / Matching Close logic — ไม่แตะ
- License / News / Time Filter core logic — ไม่แตะ
- OnChartEvent buttons เดิม (Pause, Close Buy/Sell/All) — คงเดิม, เพิ่มแค่ Resume Daily

