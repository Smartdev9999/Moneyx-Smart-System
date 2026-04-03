

## v6.33 — แก้ Dynamic Balance Guard ให้อัปเดต target เฉพาะเมื่อไม่มีออเดอร์เท่านั้น

### ปัญหา
`UpdateDynamicBalanceGuardTarget()` ไม่มีเงื่อนไขเช็ค `TotalOrderCount()` — มันอัปเดต `g_balanceGuardDynamicTarget` จาก `ACCOUNT_BALANCE` ทุกครั้งที่ balance เปลี่ยน ไม่ว่าจะยังมีออเดอร์อยู่หรือไม่

ผลคือ: เมื่อ EA เปิดชุดใหม่ทำกำไรปิดไป → Balance เพิ่ม → target ถูกอัปเดตขึ้นไปเรื่อยๆ → ชุดที่โดน hedge ล็อคไว้ไม่มีทาง trigger Balance Guard ได้เพราะ target วิ่งหนีไปตลอด

### แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Version bump → v6.33

#### 2. เพิ่ม guard condition ใน `UpdateDynamicBalanceGuardTarget()`
```cpp
void UpdateDynamicBalanceGuardTarget()
{
   if(!InpBalanceGuard_Enable) return;
   if(InpBalanceGuard_Mode != BALGUARD_DYNAMIC) return;
   if(TotalOrderCount() != 0) return;  // v6.33: อัปเดตเฉพาะเมื่อ flat เท่านั้น
   // ... update logic เหมือนเดิม
}
```

เพียงเพิ่มบรรทัดเดียว — ทุกจุดที่เรียก helper นี้จะถูก guard โดยอัตโนมัติ

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic, Trading Strategy Logic, Core Module Logic — ไม่แก้
- DD trigger / Triple-gate / Matching close — ไม่แก้
- OpenDDHedge / binding / generation logic — ไม่แก้
- Balance Guard trigger/close logic — ไม่แก้
- Daily Target Profit (v6.32) — ไม่แก้

