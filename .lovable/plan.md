## เพิ่ม Volatility Squeeze Filter (BB vs KC) ใน Gold Miner EA

### สิ่งที่เพิ่ม/แก้ไข
1. **Input Parameters** — `InpUseSqueezeFilter`, TF1/TF2/TF3, BB Period/Mult, KC Period/Mult, ATR Period, ExpThreshold, BlockOnExpansion, MinTFExpansion
2. **Global Variables** — `SqueezeState g_squeeze[3]`, `g_squeezeBlocked`
3. **OnInit** — สร้าง iBands/iMA/iATR handles สำหรับ 3 TF
4. **OnDeinit** — IndicatorRelease() สำหรับ 9 handles (3 TF × 3 indicators)
5. **UpdateSqueezeState()** — คำนวณ BB Width vs KC Width → Intensity → State (SQUEEZE/NORMAL/EXPANSION)
6. **OnTick** — เพิ่ม Squeeze check หลัง Daily Profit Pause → set g_newOrderBlocked เมื่อ Expansion
7. **Dashboard** — เพิ่ม Squeeze section แสดง State/Intensity/Bar สำหรับแต่ละ TF
8. **TimeframeToString()** — helper แปลง ENUM_TIMEFRAMES เป็น "M5"/"H1"/"H4"

### Logic
- SQUEEZE (สีแดง): BB อยู่ภายใน KC (Intensity < 1.0) → sideways จัด → เทรดได้
- NORMAL (สีเขียว): BB กับ KC ไล่เลี่ยกัน → sideways ปกติ → เทรดได้
- EXPANSION (สีฟ้า): BB ทะลุออกนอก KC (Intensity > Threshold) → เทรนด์แรง → BLOCK

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (การเปิด/ปิดออเดอร์)
- Trading Strategy Logic (SMA/ZigZag/Instant entry, Grid, TP/SL, Trailing, Accumulate, Drawdown)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Matching Close logic
- Dashboard layout เดิม (เพิ่มแถวใหม่ต่อท้าย)
