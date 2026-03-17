## เพิ่ม Volatility Squeeze Filter ใน Jutlameasu EA (2 Timeframes)

### แนวคิด — ตรงข้ามกับ Gold Miner
- **Gold Miner**: เทรดเฉพาะ Squeeze/Normal → block เมื่อ Expansion
- **Jutlameasu**: เทรดเฉพาะ **Expansion** → block เมื่อ Squeeze/Normal

### สิ่งที่เพิ่ม/แก้ไข
1. **Input Parameters** — `InpUseSqueezeFilter`, TF1/TF2, BB Period/Mult, KC Period/Mult, ATR Period, ExpThreshold, MinTFExpansion
2. **Global Variables** — `SqueezeState g_squeeze[2]`, `g_squeezeBlocked`
3. **OnInit** — สร้าง iBands/iMA/iATR handles สำหรับ 2 TF
4. **OnDeinit** — IndicatorRelease() สำหรับ 6 handles (2 TF × 3 indicators)
5. **UpdateSqueezeState()** — คำนวณ BB Width vs KC Width → Intensity → State
6. **OnTick** — Squeeze check: block เมื่อ Expansion ไม่ถึง threshold
7. **Dashboard** — เพิ่ม Squeeze section แสดง State/Intensity/Bar สำหรับแต่ละ TF
8. **TimeframeToStringSQ()** — helper แปลง ENUM_TIMEFRAMES

### Logic
- SQUEEZE (สีแดง): BB อยู่ภายใน KC → BLOCK
- NORMAL (สีเขียว): BB ≈ KC → BLOCK
- EXPANSION (สีฟ้า): BB ทะลุ KC → ALLOW

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.BuyStop, trade.SellStop, trade.PositionClose)
- Trading Strategy Logic (Cross-Over TP/SL, Martingale, Grid Profit, Accumulate Close)
- Core Module Logic (License, News filter, Time filter, Data sync)
- StartNewCycle / PlaceNextPendingOrder logic
- Dashboard layout เดิม (เพิ่มแถวใหม่ต่อท้าย)
