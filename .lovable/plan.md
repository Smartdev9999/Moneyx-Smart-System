

## วิเคราะห์ Bug: DetectZigZagSwing() ตรวจจับทิศทางผิด

### ปัญหาที่พบ

ฟังก์ชัน `DetectZigZagSwing()` (บรรทัด 2653-2685) มี **bug สำคัญ** ในวิธีระบุว่า swing point เป็น HIGH หรือ LOW:

```text
// โค้ดปัจจุบัน (ผิด)
if(zzBuf[i] < price)   → return "LOW"
else                    → return "HIGH"
```

มันเปรียบเทียบ swing point กับ **ราคาปัจจุบัน** ซึ่งผิดพลาด เช่น:
- Swing HIGH ที่ 2650 แต่ราคาปัจจุบัน 2700 → ระบบบอกว่า "LOW" (ผิด!)
- Swing LOW ที่ 2750 แต่ราคาร่วงมาอยู่ 2700 → ระบบบอกว่า "HIGH" (ผิด!)

### วิธีแก้ที่ถูกต้อง

ZigZag indicator มาตรฐานของ MT5 (`Examples\ZigZag`) มี **3 buffers**:
- **Buffer 0**: ZigZag line (ทุกจุด รวมกัน)
- **Buffer 1**: High Map (เฉพาะ Swing High, อื่นเป็น 0)
- **Buffer 2**: Low Map (เฉพาะ Swing Low, อื่นเป็น 0)

แก้ให้ใช้ **Buffer 1 และ 2 แยกกัน** แล้วหาว่าจุดไหนเกิดล่าสุด:

```text
// หา swing high ล่าสุดจาก buffer 1
// หา swing low ล่าสุดจาก buffer 2
// เปรียบเทียบ bar index → อันที่ใกล้กว่า (index น้อยกว่า) คือ swing ล่าสุด
// ถ้า swing low ล่าสุด → return "LOW" (BUY direction)
// ถ้า swing high ล่าสุด → return "HIGH" (SELL direction)
```

### ไฟล์ที่แก้ไข
`public/docs/mql5/Gold_Miner_EA.mq5` — แก้เฉพาะ `DetectZigZagSwing()` (~30 บรรทัด)

### สิ่งที่ไม่เปลี่ยนแปลง (กฎเหล็ก)
- Order Execution Logic — ไม่แตะ
- Grid Entry/Exit Logic — ไม่แตะ
- TP/SL/Trailing/Accumulate — ไม่แตะ
- SMA Signal Logic — ไม่แตะ
- CDC Filter Logic — ไม่แตะ
- License / News / Time Filter — ไม่แตะ
- OnTick flow / Entry conditions — ไม่แตะ (แก้แค่ฟังก์ชัน detection ที่ถูกเรียก)

