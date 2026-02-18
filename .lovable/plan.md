

## ปรับปรุง Gold Miner EA v2.0 - Trailing Stop แบบค่าเฉลี่ย

### สรุปการเปลี่ยนแปลงทั้งหมด

เขียน `public/docs/mql5/Gold_Miner_EA.mq5` ใหม่ทั้งหมดตามแผนที่ approve ไปแล้ว (SMA entry + Grid system) พร้อมอัปเดต Trailing Stop logic ตามที่อธิบายเพิ่มเติม

### สิ่งที่จะเปลี่ยน

| ไฟล์ | รายละเอียด |
|------|-----------|
| `public/docs/mql5/Gold_Miner_EA.mq5` | เขียนใหม่ทั้งหมด ~1200 บรรทัด |

### Trailing Stop Logic ใหม่ (ใช้ค่าเฉลี่ย)

**หลักการ:**
- คำนวณ "ราคาเฉลี่ยถ่วงน้ำหนัก" (Weighted Average Price) ของทุก position ที่เปิดอยู่ในฝั่งเดียวกัน (Initial + Grid Loss + Grid Profit)
- ใช้ค่าเฉลี่ยนี้เป็นจุดอ้างอิงสำหรับ Breakeven และ Trailing Stop

**ตัวอย่างจากที่อธิบาย:**

```text
Initial Buy @ 2000$, Grid #1 Buy @ 2002$
Average Price = (2000 + 2002) / 2 = 2001

ตั้งค่า:
- TrailingActivation = 100 points (ราคาต้องห่างจาก average 100 points ถึงจะเริ่ม trail)
- BreakevenBuffer = 10 points (กันหน้าไม้อยู่เหนือ average 10 points)

Flow:
1. Average = 2001
2. Breakeven level = 2001 + 10 points = 2001.10
3. เมื่อราคาขึ้นถึง 2001 + 100 points = 2002.00 → เริ่ม trailing
4. Trailing SL จะตามราคาโดยห่าง TrailingStep points
5. Trailing SL จะไม่ต่ำกว่า Breakeven level (2001.10)
```

**สำหรับ SELL (กลับด้าน):**

```text
Average = 2001
Breakeven level = 2001 - 10 points = 2000.90
เริ่ม trail เมื่อราคาลงถึง 2001 - 100 points = 2000.00
Trailing SL ตามราคาขึ้น ห่าง TrailingStep points
SL จะไม่สูงกว่า Breakeven level
```

### Input Parameters สำหรับ Trailing Stop

```text
=== Trailing Stop (Average-Based) ===
EnableTrailingStop      = true       // เปิด/ปิดระบบ trailing
TrailingActivation      = 100        // Points จาก average ที่ต้องถึงก่อนเริ่ม trail
TrailingStep            = 50         // ระยะห่างของ trailing SL จากราคาปัจจุบัน
BreakevenBuffer         = 10         // Points เหนือ/ใต้ average สำหรับกันหน้าไม้
EnableBreakeven         = true       // เปิด/ปิด breakeven
BreakevenActivation     = 50         // Points จาก average ที่ต้องถึงก่อน move SL ไป breakeven
```

### โครงสร้าง EA ทั้งหมด (v2.0)

**1. Entry - SMA 20 เส้นเดียว:**
- Price > SMA = Buy, Price < SMA = Sell
- Auto re-entry เมื่อปิด position แล้วสัญญาณยังอยู่
- ป้องกันเปิดซ้ำในแท่งเทียนเดียวกัน

**2. Grid Loss Side:**
- Max 5 levels
- Lot Mode: Add Lot / Custom Lot / Multiply
- Gap Type: Fixed / Custom Distance / ATR-Based
- Only in Signal / Only New Candle options

**3. Grid Profit Side:**
- Max 3 levels
- แยกตั้งค่าอิสระจาก Loss Side

**4. Take Profit:**
- Fixed Dollar / Points from Average / % of Balance
- Accumulate Close (target สะสม)
- แสดงเส้น Average (Yellow) + TP Line (Lime)

**5. Stop Loss:**
- Fixed Dollar / Points from Average / % of Balance
- แสดงเส้น SL (Red)

**6. Trailing Stop (ใหม่ - ค่าเฉลี่ย):**
- คำนวณ Weighted Average Price ของทุก position ในฝั่งเดียวกัน
- Breakeven: ย้าย SL ไป average + buffer เมื่อราคาถึง activation
- Trailing: เริ่ม trail เมื่อราคาห่างจาก average ถึง activation, ตาม step
- SL ไม่ถอยหลัง (move in profit direction only)

### รายละเอียดทางเทคนิค

**ฟังก์ชัน CalculateAveragePrice():**

```text
CalculateAveragePrice(int side) {
    totalLots = 0
    totalWeightedPrice = 0
    for each position with MagicNumber on same Symbol & side:
        totalLots += volume
        totalWeightedPrice += openPrice * volume
    if totalLots > 0:
        return totalWeightedPrice / totalLots
    return 0
}
```

**ฟังก์ชัน ManageTrailingStop():**

```text
ManageTrailingStop() {
    avgBuy = CalculateAveragePrice(BUY)
    avgSell = CalculateAveragePrice(SELL)

    if avgBuy > 0 && EnableTrailingStop:
        // BUY side
        beLevel = avgBuy + BreakevenBuffer * point
        trailActivation = avgBuy + TrailingActivation * point

        if Bid >= trailActivation:
            trailSL = Bid - TrailingStep * point
            trailSL = max(trailSL, beLevel)  // ไม่ต่ำกว่า breakeven
            // Apply to all BUY positions if trailSL > current SL

        else if EnableBreakeven && Bid >= avgBuy + BreakevenActivation * point:
            // Move SL to beLevel for all BUY positions

    // Mirror logic for SELL side
}
```

**OnTick Flow:**

```text
OnTick()
  → ManageTPSL() (ทุก tick - check TP/SL conditions)
  → ManageTrailingStop() (ทุก tick)
  → CheckDrawdownExit()
  → ถ้า new bar:
     → CopyBuffer SMA + ATR
     → CheckGridLoss()
     → CheckGridProfit()
     → ถ้าไม่มี position:
        → Price > SMA = Buy
        → Price < SMA = Sell
     → ถ้า EnableAutoReEntry + เพิ่งปิด + สัญญาณยังอยู่ = เปิดใหม่
  → DrawLines() (Average, TP, SL)
  → DisplayDashboard()
```

**Chart Lines ที่จะวาด:**
- เส้น Average Price (Yellow) - คำนวณจาก weighted average ของทุก position
- เส้น TP (Lime) - average +/- TP points
- เส้น SL (Red) - average +/- SL points / trailing SL level
- เส้น SMA (DodgerBlue) - indicator value

**Indicator Handles:**
- `iMA` (SMA) - สำหรับ entry signal
- `iATR` - สำหรับ grid distance (ATR mode เท่านั้น)

