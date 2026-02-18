

## แก้ไข Per-Order Trailing Stop + ลำดับการทำงาน ManageTPSL

### ปัญหาที่พบ

**1. ManageTPSL() ปิดออเดอร์ก่อนที่ Per-Order Trailing จะทำงาน**
- ใน `OnTick()` บรรทัด 285: `ManageTPSL()` ทำงานก่อน
- บรรทัด 290: `ManagePerOrderTrailing()` ทำงานทีหลัง
- เมื่อกำไรถึงเป้า TP Dollar (เช่น $100) ระบบปิดทุกออเดอร์ก่อนที่ trailing จะได้ตั้ง SL
- นี่คือสาเหตุหลักที่ "ราคาขึ้นไปถึง 500 point แล้วปิดออเดอร์เลย" แทนที่จะกันหน้าไม้

**2. Trailing Step Logic ต้องปรับปรุง**
- ปัจจุบัน: `trailSL = bid - PerOrder_Step * point` (ห่างจากราคาปัจจุบัน step points)
- ต้องแก้ให้: เมื่อ Activation ถึง ให้ตั้ง SL ที่ breakeven (openPrice + buffer) ก่อน จากนั้นทุก step points ที่ราคาขยับ SL จะขยับตาม
- SL ต้องไม่ถอยหลัง (move in profit direction only)

### สิ่งที่จะแก้ไข

| ไฟล์ | รายละเอียด |
|------|-----------|
| `public/docs/mql5/Gold_Miner_EA.mq5` | แก้ไข OnTick, ManagePerOrderTrailing, ManageTPSL |

### การเปลี่ยนแปลง

**1. สลับลำดับ OnTick - Per-Order Trailing ต้องทำงานก่อน ManageTPSL**

```text
OnTick()
  -> ManagePerOrderTrailing() (ตั้ง SL ก่อน ทุก tick)
  -> ManageTrailingStop() (average-based, ถ้าเปิดแทน per-order)
  -> ManageTPSL() (basket TP/SL ตรวจหลัง trailing ได้ทำงานแล้ว)
  -> CheckDrawdownExit()
  -> New bar logic...
```

**2. แก้ Per-Order Trailing Logic ให้ถูกต้อง**

ตัวอย่างจากที่ผู้ใช้อธิบาย (BUY order):

```text
ตั้งค่า: Activation=200, Step=10, Buffer=5

ราคาเปิด: 2000.00
1. ราคาขึ้นมา 200 points (2002.00) -> ตั้ง SL = 2000.00 + 5 points = 2000.05 (กันหน้าไม้)
2. ราคาขึ้นอีก 10 points (2002.10) -> SL ขยับขึ้น = 2000.15
3. ราคาขึ้นอีก 10 points (2002.20) -> SL ขยับขึ้น = 2000.25
4. ราคาย่อลง (2002.10) -> SL ไม่ขยับลง ยังคงอยู่ที่ 2000.25
5. ราคาลงมาแตะ 2000.25 -> Broker ปิดออเดอร์
```

สูตรที่แก้ไข:

```text
ManagePerOrderTrailing() {
    for each position:
        profitPoints = (bid - openPrice) / point  // สำหรับ BUY
        beLevel = openPrice + Buffer * point

        if profitPoints >= Activation:
            // คำนวณ trailing SL จาก step
            stepsAboveActivation = floor((profitPoints - Activation) / Step)
            trailSL = openPrice + Buffer * point + stepsAboveActivation * Step * point
            
            // ทางเลือก: ใช้วิธี bid - step (ห่างจากราคาปัจจุบัน)
            // trailSLFromPrice = bid - Step * point
            // trailSL = max(trailSLFromPrice, beLevel)
            
            // SL ต้องไม่ถอยหลัง
            if trailSL > currentSL || currentSL == 0:
                trade.PositionModify(ticket, trailSL, tp)
}
```

**3. ป้องกัน Basket TP ปิดออเดอร์ที่กำลัง Trailing**

เมื่อ `EnablePerOrderTrailing = true`:
- Basket TP (UseTP_Dollar, UseTP_Points, UseTP_PercentBalance) ยังคงทำงานเป็น "Global Target" ปิดทั้งหมดเมื่อถึงเป้า
- แต่ต้องรัน ManagePerOrderTrailing() ก่อนเสมอ เพื่อให้ SL ถูกตั้งก่อน
- Accumulate Close ยังทำงานปกติเป็น global basket target

**4. เพิ่ม Minimum Stop Level Check**

ก่อนตั้ง SL ต้องตรวจสอบ SYMBOL_TRADE_STOPS_LEVEL ของ broker:

```text
int stopLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
// ตรวจสอบว่า SL ห่างจากราคาปัจจุบันมากกว่า stopLevel
// ถ้าไม่ถึง ให้ปรับ SL ให้ห่างพอ
```

### รายละเอียดทางเทคนิค

**OnTick Flow หลังแก้ไข:**

```text
OnTick()
  -> if EnablePerOrderTrailing:
       ManagePerOrderTrailing()  // ตั้ง SL แต่ละ order ก่อน
  -> else if EnableTrailingStop || EnableBreakeven:
       ManageTrailingStop()      // average-based trailing
  -> ManageTPSL()                // basket TP/SL (ทำงานหลัง trailing)
  -> CheckDrawdownExit()
  -> if new bar:
     -> CopyBuffers
     -> CountPositions
     -> CheckGridLoss/Profit
     -> Entry logic (SMA signal)
     -> Auto Re-Entry
  -> DrawLines + Dashboard
```

**ManagePerOrderTrailing() ที่แก้ไข (BUY):**

```text
profitPoints = (bid - openPrice) / point
beLevel = openPrice + PerOrder_BreakevenBuffer * point
stopLevel = SymbolInfoInteger(SYMBOL_TRADE_STOPS_LEVEL)

if profitPoints >= PerOrder_Activation:
    // Trail: SL ห่างจาก bid เท่ากับ Step
    trailSL = bid - PerOrder_Step * point
    // ไม่ต่ำกว่า breakeven
    trailSL = max(trailSL, beLevel)
    // ต้องห่างจาก bid มากกว่า stopLevel
    minSL = bid - stopLevel * point
    if trailSL > minSL:
        trailSL = minSL
    // SL ต้องไม่ถอยหลัง
    if trailSL > currentSL || currentSL == 0:
        trade.PositionModify(ticket, trailSL, tp)
```

**ManagePerOrderTrailing() ที่แก้ไข (SELL - กลับด้าน):**

```text
profitPoints = (openPrice - ask) / point
beLevel = openPrice - PerOrder_BreakevenBuffer * point

if profitPoints >= PerOrder_Activation:
    trailSL = ask + PerOrder_Step * point
    trailSL = min(trailSL, beLevel)
    maxSL = ask + stopLevel * point
    if trailSL < maxSL:
        trailSL = maxSL
    if currentSL == 0 || trailSL < currentSL:
        trade.PositionModify(ticket, trailSL, tp)
```

