

## แก้ไขแผน: Reverse Hedging คำนวณ Total Lots รวมทุกตัว — Gold Miner SQ EA (v6.3 → v6.4)

### สิ่งที่เปลี่ยนจากแผนเดิม

**เดิม:** คำนวณ lots เฉพาะ orders ปกติฝั่งเดียวกับ hedge (ไม่รวม bound, ไม่รวม hedge/grid hedge)

**ใหม่:** คำนวณ **ทุก order** ที่อยู่ฝั่งเดียวกับ hedge รวมทั้งหมด:
- Orders ปกติ (GM1_GL, GM1_INIT...)
- Bound orders (GM_GL ที่ถูก bind)
- Main Hedge order (GM_HEDGE_1)
- Grid Hedge orders (GM_HG1_GL...)

รวมทั้งหมด = Reverse Hedge lots

### ตัวอย่าง

```text
Hedge Set 1: SELL side
  GM_HEDGE_1 (SELL)     = 0.30 lots
  GM_HG1_GL1 (SELL)     = 0.10 lots   ← grid hedge
  GM_GL#5 (SELL, bound) = 0.20 lots   ← bound order
  GM1_GL#1 (SELL)       = 0.15 lots   ← new cycle order
  GM1_GL#2 (SELL)       = 0.25 lots   ← new cycle order
  ─────────────────────────────────
  Total SELL             = 1.00 lots

→ เปิด BUY GM_RHEDGE 1.00 lots
```

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1-2. Input Parameters + Global Variables — เหมือนแผนเดิม

#### 3. `IsReverseHedgeComment()` + อัพเดท `IsHedgeComment()` — เหมือนเดิม

#### 4. แก้ `CheckAndOpenReverseHedge()` — คำนวณ lots รวมทุกตัว

```text
Logic:
1. Guards เหมือนเดิม (feature disabled, already active, no hedge set)
2. ตรวจ expansion กลับทิศ (เหมือนเดิม)
3. คำนวณ total lots:
   - สแกน ALL positions ฝั่งเดียวกับ hedge
   - รวมทุกตัว: normal orders + bound orders + hedge + grid hedge
   - Skip เฉพาะ GM_RHEDGE (ตัว reverse เอง ถ้ามี)
4. เปิด reverse order ด้วย total lots + comment "GM_RHEDGE"
```

#### 5. `ManageReverseHedge()` — Matching Close เมื่อ Normal

เมื่อสถานะกลับ Normal:
1. คำนวณ `reverseProfit` จาก GM_RHEDGE
2. `budget = reverseProfit - MinProfit`
3. สแกน orders ฝั่งเดียวกับ hedge **ทุกตัว** (normal + bound + hedge + grid hedge) เรียงจากเก่าสุด
4. จับคู่ปิด loss orders จนหมด budget
5. ปิด GM_RHEDGE

#### 6-10. เรียกใน ManageHedgeSets, CountPositions skip, Recovery, Dashboard, Version bump — เหมือนแผนเดิม

### Flow สรุป

```text
Hedge SELL active, ราคาดีดขึ้น (bullish expansion ≥ 2 TF):
  → สแกน ALL SELL orders = 1.00 lots
  → เปิด BUY GM_RHEDGE 1.00 lots (ล็อคทั้งหมด)

สถานะกลับ Normal:
  → reverseProfit = $120
  → budget = $119.50
  → ปิด loss orders จากเก่าสุด (ทุกประเภท) จนหมด budget
  → ปิด GM_RHEDGE
```

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge system logic (Matching/Partial/AvgTP/Grid)
- Orphan Recovery system, Comment Generation logic

