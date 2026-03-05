

## แก้ไข Accumulate Close — Reset Baseline เมื่อไม่มี Order เหลือ

### ปัญหา
`CalcTotalHistoryProfit()` รวมกำไรทุก deal ตั้งแต่ต้น ดังนั้น `g_accumulatedProfit = totalHistory - g_accumulateBaseline` จะยังจำกำไรจาก order ที่ปิดไปก่อนหน้า (เช่น ปิดจาก TP, Matching Close, หรือ manual) แม้ว่าจะไม่มี order เหลือแล้วก็ตาม เมื่อเปิด order ชุดใหม่ ระบบยังนับกำไรเก่าต่อ ทำให้อาจ trigger AccumulateTarget เร็วเกินไป

### วิธีแก้ไข
เพิ่ม global flag `g_hadPositions` เพื่อตรวจจับว่า "เคยมี order → ตอนนี้ไม่มีแล้ว" (transition to zero) แล้ว reset baseline ทันที:

```text
// Global
bool g_hadPositions = false;

// ใน Accumulate logic (ทั้ง SMA และ ZigZag mode):
int currentCount = TotalOrderCount();
if(g_hadPositions && currentCount == 0)
{
   // ไม่มี order เหลือแล้ว → reset baseline เริ่มนับรอบใหม่
   g_accumulateBaseline = CalcTotalHistoryProfit();
   g_accumulatedProfit = 0;
   g_hadPositions = false;
   Print("Accumulate auto-reset: no positions left. New baseline: ", g_accumulateBaseline);
   return;
}
if(currentCount > 0) g_hadPositions = true;

// จากนั้นทำ accumulate logic ปกติ...
```

แก้ 3 จุด:
1. เพิ่ม `g_hadPositions` global variable + init ใน OnInit
2. เพิ่ม reset logic ใน `ManageTPSL()` (SMA mode, ~บรรทัด 1357)
3. เพิ่ม reset logic ใน `ManageAccumulateShared()` (ZigZag mode, ~บรรทัด 3395)

### ไฟล์ที่แก้ไข
`public/docs/mql5/Gold_Miner_EA.mq5` (ไฟล์เดียว)

### สิ่งที่ไม่เปลี่ยนแปลง (กฎเหล็ก)
- Order Execution Logic — ไม่แตะ
- Grid Entry/Exit Logic — ไม่แตะ
- TP/SL/Trailing/Accumulate calculation formula — ไม่แตะ (แก้แค่ timing ของ baseline reset)
- SMA Signal / ZigZag MTF Signal — ไม่แตะ
- License / News / Time Filter — ไม่แตะ
- Matching Close Logic — ไม่แตะ

