

## v6.31 — แก้ Dynamic Balance Guard ให้อัปเดต target ทันทีเมื่อ flat

### สาเหตุที่ไม่เสถียร

ปัญหามี 2 จุด:

1. **Tick timing**: Dynamic update ใน `CheckBalanceGuard()` เช็ค `TotalOrderCount() == 0` แต่ถ้าออเดอร์ปิดแล้วออเดอร์ใหม่เปิดภายใน tick เดียวกัน (EA ออกออเดอร์เร็ว) → ไม่เคยเห็น flat state → ไม่อัปเดต
2. **ตำแหน่งเดียว**: อัปเดตเฉพาะใน `CheckBalanceGuard()` ซึ่งเรียกแค่ครั้งเดียวต่อ tick — ถ้า flat state เกิดแล้วหายภายใน tick เดียวกัน ก็พลาด

### แนวทางแก้

เพิ่มการอัปเดต dynamic target ไว้ใน **จุดที่รู้แน่ว่า flat** — คือ `TryResetCycleStateIfFlat()` และ flat-detection points ที่มีอยู่แล้ว ไม่ต้องรอ tick ถัดไป

### แผนแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Version bump → v6.31

#### 2. สร้าง helper `UpdateDynamicBalanceGuardTarget()`
```cpp
void UpdateDynamicBalanceGuardTarget()
{
   if(!InpBalanceGuard_Enable) return;
   if(InpBalanceGuard_Mode != BALGUARD_DYNAMIC) return;
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   if(MathAbs(bal - g_balanceGuardDynamicTarget) > 0.01)
   {
      Print("v6.31 BG Dynamic: Target updated $", 
            DoubleToString(g_balanceGuardDynamicTarget,2),
            " → $", DoubleToString(bal,2));
      g_balanceGuardDynamicTarget = bal;
   }
}
```

#### 3. เรียก helper ทันทีในทุกจุดที่ตรวจพบ flat

- **`TryResetCycleStateIfFlat()`** — เพิ่ม `UpdateDynamicBalanceGuardTarget()` ตรง "Truly flat" block (ก่อน/หลัง reset generation)
- **Accumulate reset** (line ~2066) — เพิ่มหลัง `g_hadPositions && currentCount == 0`
- **ZZ accumulate reset** (line ~4505) — เช่นกัน
- **Standalone clear** (line ~1358) — เช่นกัน

#### 4. คง dynamic update ใน `CheckBalanceGuard()` ไว้เป็น fallback
ใช้ helper เดียวกัน แทน inline code เดิม

### ผลลัพธ์
```text
Orders ปิดหมด → flat detected ที่จุดใดก็ตาม
→ UpdateDynamicBalanceGuardTarget() ทำงานทันที
→ target อัปเดตก่อนที่ออเดอร์ใหม่จะเปิด
→ ไม่พลาดแม้ EA ออกออเดอร์เร็วมาก
```

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic — ไม่แก้
- Trading Strategy Logic — ไม่แก้
- Core Module Logic — ไม่แก้
- DD trigger / Triple-gate / Matching close — ไม่แก้
- OpenDDHedge / binding / generation logic — ไม่แก้
- Safe Cycle Reset (v6.27) — ไม่แก้ (เพิ่มเรียก helper เท่านั้น)
- Balance Guard trigger/close logic — ไม่แก้

