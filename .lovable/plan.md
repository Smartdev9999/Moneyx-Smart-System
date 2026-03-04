

## Gold Miner EA - เปลี่ยน ATR จาก Indicator Handle เป็น Simplified ATR (เร่ง Backtest)

### ปัญหา
ATR ใช้ `iATR()` indicator handle ซึ่งสร้าง subwindow บนชาร์ต แม้จะมี logic ลบ subwindow อยู่แล้ว (v2.9) แต่ตัว handle ยังทำงานอยู่ทำให้ backtest ช้า

### วิธีแก้ไข
เพิ่ม input `InpSkipATRInTester` — เมื่อเปิดใช้ + อยู่ใน tester จะ **ไม่สร้าง iATR handle เลย** และใช้ `CalculateSimplifiedATR()` (คำนวณ True Range ด้วย iHigh/iLow/iClose โดยตรง) แทน

### ไฟล์ที่แก้ไข
`public/docs/mql5/Gold_Miner_EA.mq5` (ไฟล์เดียว)

---

### 1. เพิ่ม Input Parameter (ในกลุ่ม Backtest Optimization)

```text
input bool     InpSkipATRInTester = true;  // Skip ATR Indicator in Tester (use Simplified)
```

### 2. เพิ่มฟังก์ชัน `CalculateSimplifiedATR()` (port จาก Statistical EA)

คำนวณ ATR แบบ manual โดยไม่ต้องใช้ indicator handle — ใช้ `iHigh()`, `iLow()`, `iClose()` โดยตรง

### 3. แก้ไข OnInit — ข้าม iATR() เมื่ออยู่ใน Tester

```text
if(!(g_isTesterMode && InpSkipATRInTester))
{
   handleATR_Loss = iATR(_Symbol, GridLoss_ATR_TF, GridLoss_ATR_Period);
   handleATR_Profit = iATR(_Symbol, GridProfit_ATR_TF, GridProfit_ATR_Period);
}
else
{
   handleATR_Loss = INVALID_HANDLE;
   handleATR_Profit = INVALID_HANDLE;
}
```

### 4. แก้ไข OnTick — ข้าม CopyBuffer เมื่อ handle ไม่มี

```text
if(handleATR_Loss != INVALID_HANDLE)
   CopyBuffer(handleATR_Loss, 0, 0, 3, bufATR_Loss);
if(handleATR_Profit != INVALID_HANDLE)
   CopyBuffer(handleATR_Profit, 0, 0, 3, bufATR_Profit);
```

### 5. แก้ไข `GetGridDistance()` — ใช้ Simplified ATR เมื่ออยู่ใน Tester

เมื่อ `g_isTesterMode && InpSkipATRInTester` แทนที่จะอ่านจาก `bufATR_Loss[1]` ให้เรียก `CalculateSimplifiedATR()` แทน

### 6. ลบ ATR hide logic ออก (ไม่จำเป็นแล้ว)

เนื่องจากไม่สร้าง iATR handle ใน tester จึงไม่มี subwindow ให้ลบ — logic บรรทัด 681-704 จะไม่ทำงาน (สามารถเก็บไว้เป็น fallback หรือลบออกได้)

---

### สิ่งที่ไม่เปลี่ยนแปลง (ตามกฎเหล็ก)

- Order Execution Logic — ไม่แตะ
- Grid Entry/Exit Logic — ไม่แตะ (เปลี่ยนแค่แหล่งข้อมูล ATR ไม่ใช่ logic)
- TP/SL/Trailing/Accumulate — ไม่แตะ
- SMA Signal / shouldEnterBuy/Sell — ไม่แตะ
- License / News / Time Filter — ไม่แตะ
- ZigZag MTF Logic — ไม่แตะ
- **Live Trading**: ไม่กระทบ (ใช้ iATR handle ตามปกติเมื่อไม่อยู่ใน tester)

