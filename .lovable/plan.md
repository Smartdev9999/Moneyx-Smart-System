## เพิ่ม Grid Profit Side ให้ Jutlameasu EA

### สิ่งที่เพิ่ม/แก้ไข
1. **Input Parameters** — `InpGP_Enable`, `InpGP_MaxTrades`, `InpGP_LotMultiplier`, `InpGP_Points`, `InpGP_OnlyNewCandle`
2. **Global Variables** — `g_lastGPCandleTime`, `g_gpBuyCount`, `g_gpSellCount`
3. **Helper Functions** — `CountGPPositions()`, `FindLastGPOrInitialPrice()`, `CalculateGPLot()`
4. **CheckGridProfit()** — ตรวจ distance จาก GP/initial ตัวล่าสุด → เปิด market order + update expected counts
5. **ModifyOppositePendingAfterGP()** — ลบ pending stop ฝั่งตรงข้าม → วางใหม่ด้วย lot = sum(positions) × multiplier
6. **OnTick** — เพิ่ม GP check หลัง Accumulate Close
7. **RecoverState** — recover g_gpBuyCount/g_gpSellCount + set g_expectedBuyCount/g_expectedSellCount
8. **Dashboard** — เพิ่มแสดง GP status (ON/OFF, counts, distance)
9. **Cycle Reset** — reset GP counters ทุกจุดที่ reset cycle

### สูตร Lot
- GP Lot = last position lot × InpGP_LotMultiplier
- Opposite Pending Lot = sum(all positions on GP side) × InpLotMultiplier

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (BuyStop, SellStop placement mechanics)
- Cross-Over TP/SL Hedging strategy (StartNewCycle, level calculation)
- Spread Compensation logic
- Accumulate / Drawdown / Custom TP/SL Distance
- License / News / Time Filter / Data Sync
- OnChartEvent buttons
