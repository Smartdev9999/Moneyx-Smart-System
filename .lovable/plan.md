

## แผน: เพิ่ม Grid Profit Side ให้ Jutlameasu EA

**ไฟล์:** `public/docs/mql5/Jutlameasu_EA.mq5`

### สูตร Lot ที่ยืนยันแล้ว
เมื่อ GP order เปิดฝั่ง Buy → Sell Stop ฝั่งตรงข้ามต้องถูกแก้ไข:
```text
Sell Stop Lot = sum(all Buy positions) × InpLotMultiplier
```

ตัวอย่าง: Buy 0.1 + GP#1 Buy 0.2 = 0.3 → Sell Stop = 0.3 × 2 = 0.6

---

### 1. เพิ่ม Input Parameters

```cpp
input group "=== Grid Profit Side ==="
input bool     InpGP_Enable         = false;    // Enable Grid Profit
input int      InpGP_MaxTrades      = 3;        // Max GP Trades per Side
input double   InpGP_LotMultiplier  = 2.0;      // GP Lot Multiplier (จาก lot ก่อนหน้า)
input int      InpGP_Points         = 500;      // GP Distance (points)
input bool     InpGP_OnlyNewCandle  = true;     // GP Only on New Candle
```

### 2. เพิ่ม Global Variables

```cpp
datetime g_lastGPCandleTime = 0;   // OnlyNewCandle tracking
int      g_gpBuyCount = 0;         // จำนวน GP Buy ที่เปิดอยู่
int      g_gpSellCount = 0;        // จำนวน GP Sell ที่เปิดอยู่
```

### 3. เพิ่ม Helper Functions

- **`CountGPPositions()`** — นับ GP orders แยก Buy/Sell (comment มี "JM_GP")
- **`FindLastGPOrInitialPrice(side)`** — หาราคาเปิดของ GP ตัวล่าสุด หรือ initial order ถ้ายังไม่มี GP
- **`CalculateTotalLotsOnSide(side)`** — รวม lot ทั้งหมดของฝั่งนั้น (ใช้ `CalculateTotalLots()` ที่มีอยู่แล้ว)

### 4. เพิ่ม `CheckGridProfit()` Function

```cpp
void CheckGridProfit(ENUM_POSITION_TYPE side, int currentGPCount)
{
   if(currentGPCount >= InpGP_MaxTrades) return;
   
   // OnlyNewCandle check
   if(InpGP_OnlyNewCandle) {
      datetime barTime = iTime(_Symbol, PERIOD_CURRENT, 0);
      if(barTime == g_lastGPCandleTime) return;
   }
   
   // Find last order price (GP or initial)
   double lastPrice = FindLastGPOrInitialPrice(side);
   if(lastPrice == 0) return;
   
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double currentPrice = (side == POSITION_TYPE_BUY) ? 
      SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Check distance condition
   bool shouldOpen = false;
   if(side == POSITION_TYPE_BUY && currentPrice >= lastPrice + InpGP_Points * point)
      shouldOpen = true;
   else if(side == POSITION_TYPE_SELL && currentPrice <= lastPrice - InpGP_Points * point)
      shouldOpen = true;
   
   if(shouldOpen) {
      // GP lot = last GP lot × multiplier (or initial lot for GP#1)
      double lots = CalculateGPLot(side, currentGPCount);
      string comment = "JM_GP#" + IntegerToString(currentGPCount + 1);
      
      // Open market order (เพราะราคาถึงแล้ว)
      if(side == POSITION_TYPE_BUY)
         trade.Buy(NormalizeLot(lots), _Symbol, 0, 0, 0, comment);
      else
         trade.Sell(NormalizeLot(lots), _Symbol, 0, 0, 0, comment);
      
      g_lastGPCandleTime = iTime(_Symbol, PERIOD_CURRENT, 0);
      
      // *** แก้ไข Pending Stop ฝั่งตรงข้าม ***
      ModifyOppositePendingAfterGP(side);
   }
}
```

### 5. เพิ่ม `ModifyOppositePendingAfterGP()` — หัวใจสำคัญ

เมื่อ GP เปิดฝั่ง Buy → ลบ Sell Stop เดิม → วาง Sell Stop ใหม่ด้วย lot = sum(Buy lots) × multiplier

```cpp
void ModifyOppositePendingAfterGP(ENUM_POSITION_TYPE gpSide)
{
   if(gpSide == POSITION_TYPE_BUY)
   {
      // GP เปิดฝั่ง Buy → แก้ Sell Stop
      double totalBuyLots = CalculateTotalLots(POSITION_TYPE_BUY);
      double newSellLot = NormalizeLot(totalBuyLots * InpLotMultiplier);
      
      DeletePendingByType(ORDER_TYPE_SELL_STOP);
      // วาง Sell Stop ใหม่ด้วย lot ที่คำนวณใหม่
      g_currentLot = newSellLot; // override lot
      PlaceNextPendingOrder("SELL");
   }
   else
   {
      double totalSellLots = CalculateTotalLots(POSITION_TYPE_SELL);
      double newBuyLot = NormalizeLot(totalSellLots * InpLotMultiplier);
      
      DeletePendingByType(ORDER_TYPE_BUY_STOP);
      g_currentLot = newBuyLot;
      PlaceNextPendingOrder("BUY");
   }
}
```

### 6. แก้ไข OnTick — เพิ่ม GP Check

หลัง Accumulate Close check (line ~714) เพิ่ม:
```cpp
// === GRID PROFIT CHECK ===
if(!g_newOrderBlocked && InpGP_Enable && g_cycleActive)
{
   int gpBuy = 0, gpSell = 0;
   CountGPPositions(gpBuy, gpSell);
   
   if(buyCount > 0 && gpBuy < InpGP_MaxTrades)
      CheckGridProfit(POSITION_TYPE_BUY, gpBuy);
   if(sellCount > 0 && gpSell < InpGP_MaxTrades)
      CheckGridProfit(POSITION_TYPE_SELL, gpSell);
}
```

### 7. แก้ไข STATE 2 — Pending Stop Activation

เมื่อ Stop ถูก activate (ไม่มี GP ใหม่): lot ยังคำนวณจาก `g_currentLot` ที่อาจถูก override แล้วจาก GP → ไม่ต้องแก้ logic เดิม เพราะ `PlaceNextPendingOrder` อ่านจาก `g_currentLot` อยู่แล้ว

แต่ต้องเพิ่ม: เมื่อ Stop activate → **update g_expectedBuyCount/g_expectedSellCount** ให้รวม GP orders ด้วย เพื่อไม่ให้ detect ผิด

### 8. อัปเดต Dashboard

เพิ่มแสดง: `GP: ON | B:1 S:0 | Max:3` และ `GP Dist: 500pts`

### 9. อัปเดต RecoverState

Recover g_gpBuyCount / g_gpSellCount จาก comment "JM_GP" ที่มีอยู่

---

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (BuyStop, SellStop placement mechanics)
- Cross-Over TP/SL Hedging strategy (StartNewCycle, level calculation)
- Spread Compensation logic
- Accumulate / Drawdown / Custom TP/SL Distance
- License / News / Time Filter / Data Sync
- OnChartEvent buttons

