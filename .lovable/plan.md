

## แปลง Asset Miner EA เป็น Multi-Pair (5 คู่เงิน)

### ขอบเขตงาน

EA ปัจจุบัน (~5,500 บรรทัด) ทำงานกับ symbol เดียว (chart symbol) — ต้องรีสร้างโครงสร้างใหม่เพื่อรองรับ 5 คู่เงินที่ทำงานอิสระบน chart เดียวกัน

### โครงสร้าง Input Parameters (จัดกลุ่มตาม Set)

```text
=== Set1 Settings ===
  Set1_Enable        = true
  Set1_Symbol        = "XAUUSD"
  Set1_MagicOffset   = 1          (Magic = MagicNumber + offset)
  Set1_InitialLot    = 0.01
  --- Set1 Grid Loss ---
  Set1_GridLoss_MaxTrades, Set1_GridLoss_LotMode, Set1_GridLoss_Points ...
  --- Set1 Grid Profit ---
  Set1_GridProfit_Enable, Set1_GridProfit_MaxTrades ...
  --- Set1 Accumulate Close ---
  Set1_UseAccumulateClose, Set1_AccumulateTarget
  --- Set1 Matching Close ---
  Set1_UseMatchingClose, Set1_MatchingMinProfit, Set1_MatchingMaxLossOrders, Set1_MatchingMinProfitOrders

=== Set2 Settings === (เหมือน Set1 แต่ default symbol ต่างกัน)
...
=== Set3-5 Settings ===
...
=== Global Accumulate Close (รวม 5 คู่) ===
  UseGlobalAccumulate = false
  GlobalAccumulateTarget = 50000.0

=== Shared Settings (ใช้ร่วมกันทุกคู่) ===
  General, SMA, TP/SL, Trailing, Dashboard, License, Time/News Filter, ZigZag, CDC
```

### โครงสร้าง Data (Struct per Pair)

```text
struct PairState {
   bool     enabled;
   string   symbol;
   int      magic;
   int      handleSMA, handleATR_Loss, handleATR_Profit;
   double   initialBuyPrice, initialSellPrice;
   datetime lastBarTime, lastInitialCandle, lastGridLossCandle, lastGridProfitCandle;
   bool     justClosedBuy, justClosedSell;
   double   trailSL_Buy, trailSL_Sell;
   bool     trailActive_Buy/Sell, beDone_Buy/Sell;
   double   accumulatedProfit, accumulateBaseline;
   bool     hadPositions;
   // Grid/Accumulate/Matching settings (copied from inputs on init)
   double   initialLot;
   int      gridLossMax, gridProfitMax;
   bool     useAccumulate, useMatching;
   double   accumTarget, matchMinProfit;
   int      matchMaxLoss, matchMinProfitOrders;
   // ... (all per-pair settings)
};
PairState g_pairs[5];
int g_pairCount = 0;
```

### Logic Flow (OnTick)

```text
OnTick():
  1. License/News/Time checks (shared — once)
  2. for each enabled pair:
     a. Get symbol data (bid/ask/SMA/ATR) using pair's handles
     b. Check new bar for THAT symbol
     c. Run grid logic (loss/profit) for that pair
     d. Run TP/SL for that pair
     e. Run per-pair accumulate close
     f. Run per-pair matching close
     g. Run trailing/breakeven for that pair
     h. Run drawdown check for that pair
  3. Run global accumulate (if enabled) — sum floating P/L across all 5 pairs
  4. Update dashboard (show all pairs)
```

### ฟังก์ชันที่ต้องแก้ไข

ฟังก์ชันหลักทุกตัวต้องรับ parameter `int pairIdx` เพื่อระบุว่าทำงานกับคู่ไหน:
- `TotalOrderCount(pairIdx)` — นับ orders ตาม magic + symbol ของ pair นั้น
- `ManageTPSL(pairIdx)` — ใช้ settings ของ pair นั้น
- `ManageMatchingClose(pairIdx)`
- `ManageTrailingStop(pairIdx)` / `ManagePerOrderTrailing(pairIdx)`
- `CheckDrawdownExit(pairIdx)`
- `CalcTotalHistoryProfit(pairIdx)` — filter ด้วย magic + symbol
- Grid entry functions — ใช้ pair's symbol + settings
- Dashboard — แสดงทุก pair ในตาราง

### ข้อจำกัดสำคัญ (MQL5)

- **Input arrays ไม่ได้** — ต้องประกาศ input แยก 5 ชุด (Set1_, Set2_, ..., Set5_)
- **Indicator handles ต้องระบุ symbol** — `iMA(Set1_Symbol, ...)`, `iATR(Set2_Symbol, ...)`
- **PositionGetTicket ต้อง filter ทั้ง magic + symbol** — ป้องกัน cross-pair interference
- **ไฟล์จะยาวมาก (~8,000-10,000 บรรทัด)** เนื่องจาก input 5 ชุด + struct + refactored functions

### ไฟล์ที่แก้ไข
`public/docs/mql5/Asset_Miner_EA.mq5` — rewrite ขนาดใหญ่

### สิ่งที่ไม่เปลี่ยนแปลง (กฎเหล็ก)
- **Trading Strategy Logic** (SMA signal, ZigZag MTF, Grid entry/exit conditions) — logic เดิม 100% แค่ wrap ด้วย pairIdx
- **Order Execution** (trade.Buy/Sell/PositionClose) — ไม่แตะ logic, เพิ่มแค่ symbol parameter
- **License / News / Time Filter** — ยังทำงานแบบ shared (ไม่แก้ core)
- **TP/SL/Trailing/Breakeven calculations** — formula เดิม, แค่อ่านค่าจาก PairState

### หมายเหตุ
นี่เป็นการ refactor ขนาดใหญ่มาก (~5,500 → ~9,000+ บรรทัด) ควรทำเป็นขั้นตอน หากอนุมัติจะเริ่มจาก input parameters + struct → OnInit → OnTick loop → refactor functions ทีละกลุ่ม

