

## แก้ไข Gold Miner EA v2.0 - ปัญหาไม่ออกออเดอร์ + เพิ่ม Per-Order Trailing Stop

### ปัญหาที่พบ

**1. Auto Re-Entry ไม่ทำงาน (สาเหตุหลักที่ไม่ออกออเดอร์)**
- `EnableAutoReEntry` ถูกประกาศเป็น input แต่ไม่เคยถูกใช้ในโค้ดเลย
- Entry logic (บรรทัด 302) ตรวจสอบ `totalPositions == 0` เท่านั้น ทำให้เมื่อปิด position ไปแล้ว ถ้าสัญญาณยังอยู่ฝั่งเดิม ก็ไม่เปิดออเดอร์ใหม่

**2. Trailing Stop ปิดทุก order ในฝั่งเดียวกัน**
- เมื่อ trailing SL โดน hit จะเรียก `CloseAllSide()` ปิดทั้ง initial + grid ทั้งหมดในฝั่งนั้น
- ผู้ใช้ต้องการ per-order trailing ที่ปิดเฉพาะ order ที่โดน trailing แต่ละตัว

**3. GridLoss_OnlyNewCandle ไม่ถูกตรวจสอบ**
- ประกาศ input ไว้แต่ไม่มีโค้ดตรวจสอบใน `CheckGridLoss()` ทำให้ grid อาจไม่เปิดออเดอร์ในบางกรณี

**4. Grid ไม่เปิดซ้ำหลัง trailing close**
- `FindLastOrder()` ค้นหาเฉพาะ position ที่ยังเปิดอยู่ ถ้า trailing ปิดไปแล้วจะหา reference price ไม่เจอ ทำให้ grid ไม่ออกออเดอร์ซ้ำ

### สิ่งที่จะแก้ไข

| ไฟล์ | รายละเอียด |
|------|-----------|
| `public/docs/mql5/Gold_Miner_EA.mq5` | แก้ไขทั้งหมด |

### การเปลี่ยนแปลงหลัก

**1. เพิ่ม Per-Order Trailing Stop Mode (ใหม่)**

Input parameters ใหม่:
```text
=== Per-Order Trailing Stop ===
EnablePerOrderTrailing    = true      // เปิด/ปิด per-order trailing
PerOrder_Activation       = 100       // Points กำไรจาก open price ของแต่ละ order ก่อนเริ่ม trail  
PerOrder_Step             = 50        // Trailing step (points จากราคาปัจจุบัน)
PerOrder_BreakevenBuffer  = 10        // กันหน้าไม้ (points เหนือ/ใต้ open price)
```

หลักการทำงาน:
- ทุก order (initial, grid loss, grid profit) มี trailing stop แยกกัน
- คำนวณจาก open price ของแต่ละ order ไม่ใช่ average price
- เมื่อ order ถูกปิดโดย trailing ออเดอร์อื่นยังคงเปิดอยู่
- Grid สามารถเปิดซ้ำที่จุดเดิมได้หากเงื่อนไขเข้า

ตัวอย่าง SELL:
```text
SELL Initial @ 2000, Grid #1 @ 2002, Grid #2 @ 2004
ราคาลงมา → #2 กำไร 100 points → เริ่ม trail #2
ราคาดีดกลับ → #2 โดนปิดโดย trailing
ราคาขึ้นไปอีก ถึงระยะ grid → เปิด #2 ใหม่อีกรอบ
```

**2. แก้ Auto Re-Entry**
- เมื่อ `justClosedPositions == true` และไม่มี position เหลือ
- ตรวจสอบสัญญาณ SMA ว่ายังอยู่ฝั่งเดิมหรือไม่
- ถ้ายังอยู่ → เปิด initial order ใหม่ทันที (ในแท่งเทียนถัดไปถ้า DontOpenSameCandle เปิดอยู่)

**3. แก้ Grid Re-Entry หลัง trailing close**
- เปลี่ยน `FindLastOrder()` ให้ค้นหาจาก position ที่เปิดอยู่ + ใช้ initial order price เป็น fallback
- Grid count จาก open positions เท่านั้น (ถูกต้องอยู่แล้ว) ทำให้เมื่อ order ถูกปิด count จะลดลงและเปิดได้ใหม่
- ถ้าไม่เจอ reference order ของฝั่งนั้น ให้ใช้ initial order price เป็น base

**4. แก้ GridLoss_OnlyNewCandle**
- เพิ่มการตรวจสอบ `GridLoss_OnlyNewCandle` ใน `CheckGridLoss()`
- เพิ่มการตรวจสอบ `GridProfit_OnlyNewCandle` ใน `CheckGridProfit()`

**5. ตรวจสอบ Accumulate Close**
- Logic ปัจจุบันถูกต้อง: สะสมกำไรจาก history + floating PL เทียบกับ target
- เพิ่ม: เมื่อถึง target ให้ปิดทุก order แต่ไม่หยุด EA (เปลี่ยนจาก `g_eaStopped = true` เป็น reset แล้วเริ่มรอบใหม่)

### รายละเอียดทางเทคนิค

**Per-Order Trailing Logic:**

```text
ManagePerOrderTrailing() {
    for each open position with MagicNumber:
        openPrice = position.openPrice
        ticket = position.ticket
        
        if BUY:
            profitPoints = (Bid - openPrice) / point
            beLevel = openPrice + PerOrder_BreakevenBuffer * point
            
            if profitPoints >= PerOrder_Activation:
                trailSL = Bid - PerOrder_Step * point
                trailSL = max(trailSL, beLevel)
                if trailSL > currentSL or currentSL == 0:
                    trade.PositionModify(ticket, trailSL, 0)
                    
        if SELL:
            profitPoints = (openPrice - Ask) / point
            beLevel = openPrice - PerOrder_BreakevenBuffer * point
            
            if profitPoints >= PerOrder_Activation:
                trailSL = Ask + PerOrder_Step * point
                trailSL = min(trailSL, beLevel)
                if trailSL < currentSL or currentSL == 0:
                    trade.PositionModify(ticket, trailSL, 0)
}
```

**เมื่อ per-order trailing เปิดใช้:**
- ไม่ต้อง check internal SL hit เพราะ broker จัดการปิดให้อัตโนมัติ
- ไม่ใช้ `CloseAllSide()` - broker ปิดเฉพาะ order ที่ SL ถูก hit
- Grid count จะลดลงอัตโนมัติเมื่อ position ถูกปิด → เปิดซ้ำได้

**แก้ FindLastOrder ให้ใช้ reference จากฝั่ง grid ที่ถูกต้อง:**
- Grid Loss: วัดจาก initial order หรือ grid loss ตัวล่าสุดที่ยังเปิดอยู่
- Grid Profit: วัดจาก initial order หรือ grid profit ตัวล่าสุดที่ยังเปิดอยู่
- ถ้าไม่มี grid order เหลือ → ใช้ initial order price เป็น reference (ทำงานได้ถูกอยู่แล้ว)

**OnTick Flow ใหม่:**

```text
OnTick()
  -> ManageTPSL() (basket TP/SL ทุก tick)
  -> if EnablePerOrderTrailing:
       ManagePerOrderTrailing() (per-order trailing ทุก tick)
  -> else if EnableTrailingStop:
       ManageTrailingStop() (average-based trailing ทุก tick)
  -> CheckDrawdownExit()
  -> if new bar:
     -> CopyBuffer SMA + ATR
     -> Count positions
     -> CheckGridLoss() (+ OnlyNewCandle check)
     -> CheckGridProfit() (+ OnlyNewCandle check)
     -> if no positions && (EnableAutoReEntry || first time):
        -> Price > SMA = Buy
        -> Price < SMA = Sell
  -> DrawLines() + Dashboard
```

**Accumulate Close แก้ไข:**
- เมื่อถึง target: ปิดทุก order → reset `g_accumulatedProfit = 0` → เริ่มรอบใหม่
- ไม่ set `g_eaStopped = true` เพื่อให้ EA ทำงานต่อได้

