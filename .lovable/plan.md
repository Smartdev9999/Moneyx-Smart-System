

## สร้าง EA ใหม่: Jutlameasu - Cross-Over TP/SL Hedging System

### แนวคิดกลยุทธ์
ระบบ Hedging แบบ Cross-Over ที่ใช้ Pending Orders (Buy Stop / Sell Stop) โดย:
- เมื่อ EA เริ่ม → วาง Buy Stop ที่ราคากลาง+Zone และ Sell Stop ที่ราคากลาง-Zone
- เมื่อ Buy Stop ถูกกระตุ้น → TP = Entry+Zone, SL = Entry-2*Zone (ครอบคลุม Sell entry)
- วาง Sell Stop ใหม่ที่ราคากลาง-Zone ด้วย Lot x2 (Martingale)
- TP ของ Sell = SL ของ Buy (ไขว้กัน) และสลับกันไปเรื่อยๆ
- Lot เพิ่มเป็น 2 เท่าทุกครั้งที่สลับฝั่ง (0.1 → 0.2 → 0.4 → 0.8...)

### ไฟล์ที่สร้างใหม่
**`public/docs/mql5/Jutlameasu_EA.mq5`** — EA ไฟล์เดียวสมบูรณ์

### โครงสร้าง EA

**1. Input Parameters:**
- `MagicNumber`, `MaxSlippage`
- `InpZonePoints` — ระยะ Zone (points, default 1000 = 10 USD สำหรับ XAUUSD)
- `InpInitialLot` — Lot เริ่มต้น (default 0.10)
- `InpLotMultiplier` — ตัวคูณ Lot (default 2.0)
- `InpMaxLevel` — จำนวนรอบ Martingale สูงสุด (default 8)
- `InpMaxDrawdownPct` — Drawdown สูงสุด (%)
- `InpResetOnProfit` — รีเซ็ตกลับ Lot เริ่มต้นเมื่อได้กำไร
- Dashboard settings (Show, X, Y, Color, Scale)
- License, Time Filter, News Filter (ใช้ module เดียวกับ Gold Miner)

**2. Core Logic (OnTick):**
```text
1. ตรวจสอบ License / News / Time Filter
2. ถ้าไม่มี Pending Orders และไม่มี Positions → คำนวณราคากลาง → วาง Buy Stop + Sell Stop (Lot เริ่มต้น)
3. ตรวจจับว่ามี Pending ถูก Activate → ตั้ง TP/SL แบบ Cross-Over
4. ตรวจจับว่ามี Position ปิด (TP หรือ SL):
   - ถ้าปิดด้วย TP → ลบ Pending ที่เหลือ → รีเซ็ต → วาง Pending ใหม่ (Lot เริ่มต้น)
   - ถ้าปิดด้วย SL → Pending ฝั่งตรงข้ามจะถูกกระตุ้นอยู่แล้ว (เพราะ SL = Entry ของอีกฝั่ง)
     → วาง Pending ใหม่ฝั่งเดิมด้วย Lot x2
5. Drawdown protection
```

**3. ระดับราคาคงที่ (Fixed Price Levels):**
```text
ราคากลาง (Mid) = คำนวณครั้งเดียวตอนเริ่ม cycle
Buy Entry  = Mid + Zone/2  (เช่น 2005.00)
Sell Entry = Mid - Zone/2  (เช่น 1995.00)
Buy TP     = Buy Entry + Zone  (เช่น 2015.00)
Buy SL     = Sell Entry - Zone (เช่น 1985.00)
Sell TP    = Sell Entry - Zone (เช่น 1985.00) = Buy SL
Sell SL    = Buy Entry + Zone  (เช่น 2015.00) = Buy TP
```

**4. Dashboard:**
- แสดง: EA Name, Symbol, Timeframe, Entry Mode
- ราคากลาง, Buy/Sell Entry levels
- Current Level, Current Lot, Total Lot Exposure
- P/L ปัจจุบัน, Drawdown
- สถานะ Pending Orders
- License / News / Time Filter status
- สีเขียว/แดงตามสถานะกำไร/ขาดทุน

### สิ่งที่ใช้ร่วมกับระบบเดิม
- License verification module (เชื่อมต่อ backend เดียวกัน)
- News Filter module
- Time Filter module
- Data Sync module
- Dashboard pattern (Comment-based)

### สิ่งที่แตกต่างจาก EA อื่น
- ไม่ใช้ Grid Loss/Profit แบบเดิม — ใช้ Pending Order Cross-Over แทน
- ไม่ใช้ SMA/ZigZag signal — ใช้ Pending Orders เป็นตัวกำหนด entry
- TP/SL ตั้งแบบ fixed price level (ไม่ใช่ average-based)
- Martingale lot doubling built-in

