

## แก้ไข Per-Order Trailing Stop ใหม่ + เพิ่ม Trading Mode

### ปัญหาที่ต้องแก้

1. **Per-Order Trailing ยังปิดออเดอร์ทันที** - Logic ไม่ตรงมาตรฐาน ไม่มี Breakeven แยก และไม่มี TrailingStep (minimum SL movement)
2. **ออกออเดอร์แค่ฝั่ง BUY** - ไม่มี Trading Mode ให้เลือกฝั่ง
3. **Accumulate ต้องทำงานแยกจาก Trailing** - ยืนยันว่า logic ปัจจุบันถูกแล้ว แต่ต้องชัดเจนว่า Accumulate เก็บสะสม closed profit + floating PL เมื่อรวมถึงเป้าจึงปิดทั้งหมด

### สิ่งที่จะเปลี่ยน

| ไฟล์ | รายละเอียด |
|------|-----------|
| `public/docs/mql5/Gold_Miner_EA.mq5` | เขียน Trailing ใหม่ตามมาตรฐาน + เพิ่ม Trading Mode |

---

### 1. เพิ่ม Trading Mode

Input parameter ใหม่:

```text
enum ENUM_TRADE_MODE {
   TRADE_BUY_ONLY  = 0,  // Buy Only
   TRADE_SELL_ONLY = 1,  // Sell Only
   TRADE_BOTH      = 2   // Buy and Sell
};

input ENUM_TRADE_MODE TradingMode = TRADE_BOTH;
```

แก้ entry logic (บรรทัด 374-393) ให้เช็ค TradingMode:
- ก่อนเปิด BUY: ต้อง TradingMode == TRADE_BUY_ONLY หรือ TRADE_BOTH
- ก่อนเปิด SELL: ต้อง TradingMode == TRADE_SELL_ONLY หรือ TRADE_BOTH

---

### 2. เขียน Per-Order Trailing Stop ใหม่ตามมาตรฐาน

**เปลี่ยน Input Parameters** (บรรทัด 128-133):

```text
=== Per-Order Trailing Stop ===
EnablePerOrderTrailing    = true      // เปิด/ปิด Per-Order Trailing
InpEnableBreakeven        = true      // เปิด/ปิด Breakeven
InpBreakevenTarget        = 200       // กำไรกี่ points จึงเริ่มกันหน้าทุน
InpBreakevenOffset        = 5         // SL วางเหนือ/ใต้ราคาเปิดกี่ points
InpEnableTrailing         = true      // เปิด/ปิด Trailing
InpTrailingStop           = 200       // ระยะ Trailing จากราคาปัจจุบัน (points)
InpTrailingStep           = 10        // ระยะขยับขั้นต่ำ (points) ก่อน modify SL
```

**Logic มาตรฐานที่ถูกต้อง (BUY order):**

```text
ManagePerOrderTrailing() {
    for each position:
        openPrice = position.openPrice
        currentSL = position.SL
        profitPoints = (bid - openPrice) / point

        // ===== STEP 1: Breakeven =====
        if InpEnableBreakeven:
            if profitPoints >= InpBreakevenTarget:
                beLevel = openPrice + InpBreakevenOffset * point
                if currentSL == 0 || currentSL < beLevel:
                    modify SL to beLevel
                    // กันหน้าทุน: SL อยู่เหนือราคาเปิดเล็กน้อย

        // ===== STEP 2: Trailing =====
        if InpEnableTrailing:
            if profitPoints >= InpTrailingStop:
                newSL = bid - InpTrailingStop * point
                // ต้องไม่ต่ำกว่า breakeven
                newSL = max(newSL, openPrice + InpBreakevenOffset * point)
                // ต้อง move อย่างน้อย Step points จึงจะ modify
                if newSL > currentSL + InpTrailingStep * point:
                    modify SL to newSL
}
```

**ตัวอย่างตัวเลข (BUY):**

```text
ตั้งค่า: BreakevenTarget=200, BreakevenOffset=5, TrailingStop=200, TrailingStep=10

เปิด BUY ที่ 2000.00

1. ราคาขึ้นมา 200 points (Bid=2002.00)
   -> Breakeven: ตั้ง SL = 2000.00 + 5pts = 2000.05 (กันหน้าทุน)
   -> Trailing: newSL = 2002.00 - 200pts = 2000.00
     แต่ max(2000.00, 2000.05) = 2000.05 ซึ่ง = currentSL แล้ว
     -> ไม่ modify (ยังไม่ห่างพอ TrailingStep)

2. ราคาขึ้นอีก (Bid=2002.10)
   -> Trailing: newSL = 2002.10 - 200pts = 2000.10
     2000.10 > 2000.05 + 10pts(0.10)? -> 2000.10 > 2000.15? NO
     -> ไม่ modify (ขยับไม่ถึง step)

3. ราคาขึ้นอีก (Bid=2002.20)
   -> newSL = 2002.20 - 200pts = 2000.20
     2000.20 > 2000.05 + 0.10 = 2000.15? YES
     -> modify SL = 2000.20

4. ราคาขึ้นต่อ (Bid=2002.40)
   -> newSL = 2002.40 - 200pts = 2000.40
     2000.40 > 2000.20 + 0.10 = 2000.30? YES
     -> modify SL = 2000.40

5. ราคาย่อลง (Bid=2002.30)
   -> newSL = 2002.30 - 200pts = 2000.30
     2000.30 > 2000.40? NO
     -> ไม่ modify (SL ไม่ถอยหลัง!)

6. ราคาลงถึง 2000.40 -> Broker ปิดออเดอร์อัตโนมัติ
```

**SELL order - กลับด้าน:**

```text
profitPoints = (openPrice - ask) / point
beLevel = openPrice - InpBreakevenOffset * point
newSL = ask + InpTrailingStop * point
// SL ต้องไม่สูงกว่า beLevel
newSL = min(newSL, beLevel)
// ต้อง move อย่างน้อย Step points ลง
if currentSL == 0 || newSL < currentSL - InpTrailingStep * point:
    modify SL
```

---

### 3. Accumulate ยืนยันหลักการ (ไม่เปลี่ยน logic)

หลักการปัจจุบันที่ถูกต้องอยู่แล้ว:
- เก็บสะสม closed profit จาก history (g_accumulatedProfit)
- ทุก tick: เช็ค g_accumulatedProfit + floating PL >= AccumulateTarget
- ถ้าถึงเป้า: ปิดทุก order -> reset g_accumulatedProfit = 0 -> เริ่มรอบใหม่
- เมื่อไม่มี position เหลือ: Accumulate จะ reset อัตโนมัติ
- Accumulate ทำงานแยกจาก trailing (trailing ปิดแต่ละ order, accumulate ปิดทั้ง basket)

---

### 4. Basket TP เมื่อ Per-Order Trailing เปิด

ยังคงข้าม basket TP (UseTP_Dollar, UseTP_Points, UseTP_PercentBalance) เมื่อ EnablePerOrderTrailing = true ตามที่แก้ไขไปแล้ว เพราะแต่ละ order จัดการ exit เองผ่าน broker SL

ข้อยกเว้น:
- Accumulate Close ยังทำงานเป็น global basket target
- Basket SL ยังเป็น emergency safety net

---

### รายละเอียดทางเทคนิค

**ไฟล์ที่แก้: `public/docs/mql5/Gold_Miner_EA.mq5`**

**1. เพิ่ม enum ENUM_TRADE_MODE** (บรรทัด ~33)

**2. เพิ่ม input TradingMode** ใน General Settings (บรรทัด ~43)

**3. แก้ Input Per-Order Trailing** (บรรทัด 128-133):
- เปลี่ยนชื่อ parameters ตามมาตรฐาน
- เพิ่ม InpEnableBreakeven, InpBreakevenTarget, InpBreakevenOffset
- เปลี่ยน PerOrder_Step เป็น InpTrailingStop (ระยะจากราคาปัจจุบัน)
- เพิ่ม InpTrailingStep (minimum movement)

**4. แก้ Entry Logic** (บรรทัด 374-393):
- เพิ่มเช็ค TradingMode ก่อนเปิด BUY/SELL

**5. เขียน ManagePerOrderTrailing() ใหม่** (บรรทัด 739-825):
- Step 1: Breakeven check (แยกจาก trailing)
- Step 2: Trailing check with TrailingStep minimum movement
- Broker stop level check
- SL never moves backwards

**6. Dashboard** - เพิ่มแสดง Trading Mode

