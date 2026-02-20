
## Gold Miner EA v2.4 - Fix Accumulate + Dashboard + ATR Grid Mode

### Issue 1: Dashboard - Remove Cycle rows, Add History metrics

**Remove:**
- "BUY Cycle" row (line 1714)
- "SELL Cycle" row (line 1715)

**Add new rows in INFO section:**
- Total Current Lot (sum of all open position lots)
- Total Closed Lot (from deal history)
- Total Closed Orders (from deal history)
- Monthly P/L (deals closed within current month)
- Total P/L (all history profit)

**New helper functions:**

```text
double CalcTotalClosedLots()
- Scan HistoryDealsTotal() filtered by MagicNumber + Symbol
- Sum DEAL_VOLUME for DEAL_ENTRY_OUT / DEAL_ENTRY_INOUT

int CalcTotalClosedOrders()
- Count deals with DEAL_ENTRY_OUT / DEAL_ENTRY_INOUT

double CalcMonthlyPL()
- HistorySelect() from first day of current month to TimeCurrent()
- Sum DEAL_PROFIT + DEAL_SWAP for matching deals
```

### Issue 2: Accumulate Close - ปิดรวบทั้งที่ยังติดลบ + EA หยุดหลังปิด

**Root Cause:**
OnInit sets `g_accumulateBaseline = 0` which means ALL past history counts as accumulated profit. If total history profit already exceeds AccumulateTarget, the EA closes everything immediately on the first tick.

**Fix 1: OnInit baseline = totalHistory (fresh start each time EA loads)**

```text
// Change OnInit (line 240-246):
if(UseAccumulateClose)
{
   double totalHistory = CalcTotalHistoryProfit();
   g_accumulateBaseline = totalHistory;  // <-- FIX: start fresh
   g_accumulatedProfit = 0;              // <-- FIX: nothing accumulated yet
   Print("Accumulate init: baseline=", g_accumulateBaseline, " accumulated=0 (fresh start)");
}
```

This way, only NEW closed deals (after EA starts) count toward the accumulate target.

**Fix 2: EA ไม่ออกออเดอร์หลัง Accumulate Close**

The issue is `CloseAllPositions()` sets `justClosedBuy/Sell = true` and resets `g_initialBuyPrice/Sell = 0`. But the entry logic at line 428 requires `buyCount == 0 && g_initialBuyPrice == 0` which IS satisfied. The problem is `shouldEnterBuy` logic:

```text
if(justClosedBuy && EnableAutoReEntry) shouldEnterBuy = true;
else if(!justClosedBuy && buyCount == 0) shouldEnterBuy = true;
```

After accumulate close, `justClosedBuy = true`. If `EnableAutoReEntry = true`, `shouldEnterBuy = true` -- this should work. BUT `justClosedBuy` is reset to false at line 462 at end of new bar. The accumulate close happens in `ManageTPSL()` which runs BEFORE the new bar check. So when the next new bar comes, `justClosedBuy` is already false (reset on previous bar), and the entry check `!justClosedBuy && buyCount == 0` should be true.

Actually the real issue is: after Accumulate Close, the EA has `g_initialBuyPrice = 0` and `g_initialSellPrice = 0` (set by `CloseAllPositions()`). The auto-detect block at line 379 only fires when `buyCount == 0 && g_initialBuyPrice != 0`, which won't trigger because initialPrice is already 0. So entry should work normally.

Wait - the screenshots show Accum.Closed = $1478.33 which is ABOVE the $500 target, BUT the EA has 0 positions and is idle. Let me re-examine:

The accumulate close with `Sleep(500)` at line 818 blocks the EA for 500ms. After that, it resets baseline. On the next tick, everything should be clean. The entry only runs on new bars. So after accumulate close, the EA waits for next new bar, then should enter normally.

Potential issue: `justClosedBuy = true` and `justClosedSell = true` are set by `CloseAllPositions()` but the entry logic processes them and resets them in the SAME new bar cycle. If accumulate close happens mid-tick (not during new bar), the flags get set but then reset on the NEXT new bar before entry logic can use them properly.

Actually looking more carefully - the flow is:
1. ManageTPSL() -> Accumulate close -> CloseAllPositions() -> sets justClosedBuy/Sell = true, resets initialPrices = 0
2. Next new bar: justClosedBuy is true, EnableAutoReEntry is true -> shouldEnterBuy = true
3. Entry check: buyCount == 0 && g_initialBuyPrice == 0 && canOpenMore -> ALL TRUE
4. Signal check: price > sma -> open BUY

This should work. Unless the issue is that after the EA restarts (or after a long delay), the `g_accumulateBaseline` gets set wrong.

**Additional safety: Add guard against negative accumulate total closing**

```text
// In ManageTPSL accumulate section:
if(accumTotal >= AccumulateTarget && accumTotal > 0)  // <-- Add accumTotal > 0 guard
```

This prevents the unlikely case of a negative total triggering a close.

### Issue 3: ATR Grid Mode - Initial vs Dynamic + Minimum Gap

**Add new enum:**

```text
enum ENUM_ATR_REF
{
   ATR_REF_INITIAL  = 0,  // From Initial Order (cumulative)
   ATR_REF_DYNAMIC  = 1   // From Last Grid Order
};
```

**Add new inputs (Grid Loss + Grid Profit sections):**

```text
input ENUM_ATR_REF GridLoss_ATR_Reference = ATR_REF_DYNAMIC;  // ATR Reference Point
input int          GridLoss_MinGapPoints  = 100;               // Minimum Grid Gap (points)

input ENUM_ATR_REF GridProfit_ATR_Reference = ATR_REF_DYNAMIC; // ATR Reference Point
input int          GridProfit_MinGapPoints  = 100;              // Minimum Grid Gap (points)
```

**Change GetGridDistance() to return ATR distance based on mode:**

```text
// ATR mode:
double atrValue = bufATR[1];  // <-- Use index 1 (closed bar) to prevent repaint
double atrDistance = atrValue * multiplier / point;

// Apply minimum gap
atrDistance = MathMax(atrDistance, (double)minGapPoints);

return atrDistance;
```

**Change CheckGridLoss() and CheckGridProfit() for ATR_REF_INITIAL mode:**

For Initial mode, distance is cumulative from initial price:

```text
NextPrice = InitialPrice +/- (ATR * Multiplier * OrderCount)
```

For Dynamic mode (current behavior), distance is from last order:

```text
NextPrice = LastOrderPrice +/- (ATR * Multiplier)
```

Implementation: Modify `CheckGridLoss()` and `CheckGridProfit()` to use initial price as reference when ATR_REF_INITIAL is selected, and multiply distance by (currentGridCount + 1).

```text
// In CheckGridLoss:
double distance = GetGridDistance(currentGridCount, true);

if(isATR_Initial_Mode)
{
   // Use initial price as reference, cumulative distance
   double initialRef = (side == BUY) ? g_initialBuyPrice : g_initialSellPrice;
   double totalDistance = distance * (currentGridCount + 1);
   // Check if price moved totalDistance from initial
   shouldOpen = (side == BUY) ? 
      currentPrice <= initialRef - totalDistance * point :
      currentPrice >= initialRef + totalDistance * point;
}
else
{
   // Current behavior: use lastPrice, single distance
   shouldOpen = (side == BUY) ?
      currentPrice <= lastPrice - distance * point :
      currentPrice >= lastPrice + distance * point;
}
```

### Summary of Changes

| File | Changes |
|------|---------|
| `public/docs/mql5/Gold_Miner_EA.mq5` | All changes below |

**Version bump:** v2.3 -> v2.4

1. Add `ENUM_ATR_REF` enum
2. Add 4 new input parameters (ATR Reference + Min Gap for Loss and Profit)
3. Fix OnInit accumulate baseline (baseline = totalHistory, not 0)
4. Add `CalcTotalClosedLots()`, `CalcTotalClosedOrders()`, `CalcMonthlyPL()` functions
5. Modify `GetGridDistance()` to use ATR index 1 + min gap
6. Modify `CheckGridLoss()` / `CheckGridProfit()` to support Initial reference mode
7. Add `accumTotal > 0` guard in ManageTPSL accumulate check
8. Update `DisplayDashboard()`: remove BUY/SELL Cycle rows, add 5 new history rows
