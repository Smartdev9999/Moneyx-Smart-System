

## เพิ่ม Minimum Orders Threshold สำหรับ Matching Close (v4.2 → v4.3)

### แนวคิด
เพิ่ม input parameter ใหม่เพื่อกำหนดจำนวนออเดอร์ขั้นต่ำในฝั่งเดียวกันก่อนที่ Matching Close จะเริ่มทำงาน เช่น ตั้งไว้ 10 → ถ้ามีออเดอร์ BUY รวม 8 ตัว ระบบจะปิดด้วย TP ตามปกติ แต่พอถึง 10 ตัวขึ้นไป Matching Close จะเริ่มจับคู่ปิด

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Input Parameter ใหม่ (หลัง line 294 ในกลุ่ม Matching Close)
```cpp
input int      MatchingMinTotalOrders  = 0;   // Min Total Orders to Activate (0=Always)
```
ค่า 0 = ทำงานทันทีเหมือนเดิม, ค่า > 0 = ต้องมีออเดอร์ฝั่งเดียวกันถึงจำนวนนี้ก่อน

#### 2. แก้ ManageMatchingClose() (~line 5691 หลังนับ profitCount + lossCount)
หลังจากนับ profitCount และ lossCount เสร็จ เพิ่มเช็ค:
```cpp
int totalSideOrders = profitCount + lossCount;
if(MatchingMinTotalOrders > 0 && totalSideOrders < MatchingMinTotalOrders)
   break;  // ออเดอร์ยังไม่ถึงเกณฑ์ — ปล่อยให้ TP ทำงานปกติ
```

#### 3. Version bump: v4.2 → v4.3
- `#property version "4.30"`
- `#property description` → v4.3
- Header comment → v4.3
- Dashboard display → v4.3

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose ไม่เปลี่ยน)
- Trading Strategy Logic (SMA/ZigZag/Instant signals, Grid calculations, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync, Squeeze filter)
- Matching Close internal logic (Budget-based, sorting, pairing — ไม่เปลี่ยน แค่เพิ่ม guard condition ก่อนเข้า)
- เมื่อ `MatchingMinTotalOrders = 0` → behavior เหมือนเดิม 100%

