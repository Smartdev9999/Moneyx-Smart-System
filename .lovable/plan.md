

## Fix: Hedge Grid ออกออเดอร์รัวในจุดเดียวกัน — Gold Miner SQ EA (v4.6 → v4.7)

### สาเหตุ

**Line 6385** ใน `ManageHedgeGridMode()` ใช้ `GridLoss_Points` (ค่า raw จาก input) ตรงๆ แทนที่จะเรียก `GetGridDistance()` ที่คำนวณ ATR-based / Custom distance

```text
ปัจจุบัน (ผิด):
   if(distance >= GridLoss_Points)    ← ใช้ค่า fixed เสมอ

ควรเป็น:
   if(distance >= GetGridDistance(currentGridCount+1, true))  ← ใช้ระบบเดียวกับ grid ปกติ
```

ถ้าผู้ใช้ตั้ง `GridLoss_GapType = ATR` → `GetGridDistance()` จะคืนค่า ATR × Multiplier ซึ่งอาจเป็นหลายพัน points แต่ `GridLoss_Points` (fallback) อาจเป็นแค่ 500 points → ทำให้เงื่อนไข distance ผ่านทุก tick → ออกออเดอร์รัวๆ

**ปัญหาที่ 2**: ไม่มี cooldown หลังเปิด grid order → tick ถัดไปยังไม่ทันเห็น order ใหม่ → เปิดซ้ำอีก

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. แก้ ManageHedgeGridMode() — ใช้ GetGridDistance() แทน GridLoss_Points
```cpp
// Line 6385: เปลี่ยนจาก
if(distance >= GridLoss_Points)
// เป็น
double requiredGap = GetGridDistance(currentGridCount + 1, true);
if(distance >= requiredGap)
```

#### 2. เพิ่ม Cooldown ป้องกันออก order รัว
เพิ่ม `datetime g_lastHedgeGridTime = 0;` ใน globals แล้วเช็คก่อนเปิด:
```cpp
if(TimeCurrent() - g_lastHedgeGridTime < 5) return;  // 5 seconds cooldown
// ... open order ...
g_lastHedgeGridTime = TimeCurrent();
```

#### 3. Version bump: v4.6 → v4.7

### สิ่งที่ไม่เปลี่ยนแปลง
- Hedge matching/partial close logic
- Normal grid logic, Matching Close, TP/SL
- ทุก module อื่น (License, News, Time, Squeeze, DirectionalBlock)

