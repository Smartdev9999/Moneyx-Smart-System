

## สาเหตุ: Drawdown Protection ปิดออเดอร์อัตโนมัติ

จากภาพ Dashboard: **Max DD% = 61.35%** ซึ่งเกิน **InpMaxDrawdownPct = 50.0%** (ค่า default)

→ `CheckDrawdownExit()` ทำงาน → ปิดออเดอร์ทั้งหมดทันที!

ปัจจุบันไม่มี input สำหรับ **ปิดการใช้งาน** Drawdown Protection — มีแค่ `InpStopOnDrawdown` ที่ควบคุมว่า EA จะหยุดทำงานหลัง DD close หรือไม่ แต่การปิดออเดอร์ยังทำงานเสมอ

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Jutlameasu_EA.mq5`

1. **เพิ่ม Input Parameter:**
```cpp
input bool     InpUseDrawdownExit  = false;     // Enable Drawdown Protection (default OFF)
```

2. **แก้ `CheckDrawdownExit()` — เพิ่ม guard:**
```cpp
void CheckDrawdownExit()
{
   if(!InpUseDrawdownExit) return;  // ← เพิ่มบรรทัดนี้
   // ... logic เดิม
}
```

3. **เปลี่ยน default `InpMaxDrawdownPct` เป็น 0** (หรือคงที่ 50 แต่ default OFF) เพื่อให้ชัดว่าต้องเปิดใช้งานเอง

ด้วยการเปลี่ยน default เป็น `false` → ระบบจะไม่ปิดออเดอร์จาก DD อีก → martingale จะเด้งไปเด้งมาได้เรื่อยๆตาม design

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic, Trading Strategy Logic (Martingale, TP/SL, Cross-Over)
- STATE 1, STATE 2, STATE 2.5, STATE 3, STATE 4 flow
- StartNewCycle, PlaceNextPendingOrder, DeletePendingByType
- License / News / Time Filter / Data Sync / Dashboard / OnChartEvent

