

## แก้ไข Grid ไม่ทำงานใน Instant Mode - Gold Miner EA

### สาเหตุ
Grid Loss, Grid Profit, TP/SL management และ Trailing Stop อยู่ภายใน block `if(EntryMode == ENTRY_SMA)` (line 881-1027) ทำให้เมื่อใช้ `ENTRY_INSTANT` โค้ดเหล่านี้ไม่ถูกเรียกเลย

ส่วนที่ขาดหายไปใน Instant Mode:
1. **Grid Loss** (CheckGridLoss) — ไม่ถูกเรียก
2. **Grid Profit** (CheckGridProfit) — ไม่ถูกเรียก
3. **TP/SL Management** (ManageTPSL) — ไม่ถูกเรียก
4. **Trailing Stop** (ManageTrailingStop) — ไม่ถูกเรียก (line 844 เช็คเฉพาะ SMA)
5. **Auto-detect broker-closed positions** — ไม่ถูกเรียก
6. **justClosed flags reset** — ไม่ถูกเรียก

### การแก้ไข
**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

**1. Line 844:** เพิ่ม `ENTRY_INSTANT` ให้ใช้ ManageTrailingStop ด้วย:
```cpp
if(EntryMode == ENTRY_SMA || EntryMode == ENTRY_INSTANT)
   ManageTrailingStop();
```

**2. Line 850:** เพิ่ม `ENTRY_INSTANT` ให้ใช้ ManageTPSL ด้วย:
```cpp
if(EntryMode == ENTRY_SMA || EntryMode == ENTRY_INSTANT)
   ManageTPSL();
```

**3. Line 1040-1083:** เพิ่ม Grid management + auto-detect + justClosed reset ใน Instant Mode block:
```cpp
if(EntryMode == ENTRY_INSTANT)
{
   datetime currentBarTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   bool isNewBar = (currentBarTime != lastBarTime);
   
   if(isNewBar)
   {
      lastBarTime = currentBarTime;
   }
   
   int buyCount = 0, sellCount = 0;
   int gridLossBuy = 0, gridLossSell = 0;
   int gridProfitBuy = 0, gridProfitSell = 0;
   bool hasInitialBuy = false, hasInitialSell = false;
   CountPositions(buyCount, sellCount, gridLossBuy, gridLossSell, 
                  gridProfitBuy, gridProfitSell, hasInitialBuy, hasInitialSell);

   // Auto-detect broker-closed positions
   if(buyCount == 0 && g_initialBuyPrice != 0) { g_initialBuyPrice = 0; }
   if(sellCount == 0 && g_initialSellPrice != 0) { g_initialSellPrice = 0; }

   // Grid Loss management
   if(!g_newOrderBlocked)
   {
      if((hasInitialBuy || g_initialBuyPrice > 0) && gridLossBuy < GridLoss_MaxTrades && buyCount > 0)
         CheckGridLoss(POSITION_TYPE_BUY, gridLossBuy);
      if((hasInitialSell || g_initialSellPrice > 0) && gridLossSell < GridLoss_MaxTrades && sellCount > 0)
         CheckGridLoss(POSITION_TYPE_SELL, gridLossSell);
   }

   // Grid Profit management
   if(!g_newOrderBlocked && GridProfit_Enable)
   {
      if((hasInitialBuy || g_initialBuyPrice > 0) && gridProfitBuy < GridProfit_MaxTrades && buyCount > 0)
         CheckGridProfit(POSITION_TYPE_BUY, gridProfitBuy);
      if((hasInitialSell || g_initialSellPrice > 0) && gridProfitSell < GridProfit_MaxTrades && sellCount > 0)
         CheckGridProfit(POSITION_TYPE_SELL, gridProfitSell);
   }

   // Entry logic (เดิม - ไม่เปลี่ยน)
   if(!g_eaStopped && !g_newOrderBlocked)
   {
      bool canOpenOnThisCandle = !(DontOpenSameCandle && currentBarTime == lastInitialCandleTime);
      bool canOpenMore = TotalOrderCount() < MaxOpenOrders;
      // ... BUY/SELL instant entry เหมือนเดิม ...
   }

   // Reset justClosed flags
   if(!g_newOrderBlocked)
   {
      justClosedBuy = false;
      justClosedSell = false;
   }
}
```

### สิ่งที่ไม่เปลี่ยนแปลง
- Trading Strategy Logic (SMA signal, ZigZag signal) — ไม่แตะ
- Order Execution (trade.Buy/Sell/PositionClose)
- Grid calculation logic (CheckGridLoss, CheckGridProfit functions)
- TP/SL/Trailing/Breakeven calculation functions
- License / News / Time Filter core logic
- Accumulate / Matching Close / Drawdown exit logic
- Dashboard / Rebate system

