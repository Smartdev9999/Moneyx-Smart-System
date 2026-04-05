

## v6.35 — เพิ่ม Profit for Balance Guard

### หลักการ
เมื่อ Balance Guard โหมด Dynamic บันทึก balance ล่าสุดตอน flat (เช่น $102,000) → ปกติ target = $102,000 → ระบบปิดเมื่อ equity >= $102,000

**ใหม่**: เพิ่ม input `InpBalanceGuard_Profit` (เช่น $2,000) → target จริง = $102,000 + $2,000 = **$104,000** → ระบบจะปิดเมื่อ equity >= $104,000 เพื่อให้มีกำไรขั้นต่ำแม้จะมีออเดอร์ค้าง (กาก)

### แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Version bump → v6.35

#### 2. เพิ่ม input parameter ใหม่ (หลัง line 352)
```cpp
input double   InpBalanceGuard_Profit       = 0.0;   // Balance Guard: Min Profit ($) added to target
```

#### 3. แก้ `CheckBalanceGuard()` — เพิ่ม profit เข้า effectiveTarget
```cpp
double effectiveTarget = (InpBalanceGuard_Mode == BALGUARD_DYNAMIC) 
                         ? g_balanceGuardDynamicTarget : InpBalanceGuard_Target;
effectiveTarget += InpBalanceGuard_Profit;  // v6.35: Add minimum profit to target
```

#### 4. แก้ Dashboard display (line ~3509) — แสดง target รวม profit
```cpp
double bgTarget = ((InpBalanceGuard_Mode == BALGUARD_DYNAMIC) 
                   ? g_balanceGuardDynamicTarget : InpBalanceGuard_Target)
                  + InpBalanceGuard_Profit;
```

### ตัวอย่างการทำงาน
- Balance ตอน flat = $102,000 → `g_balanceGuardDynamicTarget` = $102,000
- `InpBalanceGuard_Profit` = $2,000
- effectiveTarget = $102,000 + $2,000 = **$104,000**
- ระบบปิดทุกออเดอร์เมื่อ Equity >= $104,000

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic, Trading Strategy Logic, Core Module Logic — ไม่แก้
- DD trigger / Triple-gate / Matching close — ไม่แก้
- OpenDDHedge / binding / generation logic — ไม่แก้
- Balance Guard dynamic update logic (v6.33) — ไม่แก้
- Daily Target Profit (v6.32) — ไม่แก้

