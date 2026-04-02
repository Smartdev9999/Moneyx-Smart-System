


## Implemented: v6.29 — Balance Guard Mode Selection (Fixed / Dynamic)

### หลักการทำงาน
Balance Guard มี 2 โหมด:
1. **Fixed** — ใช้ค่า `InpBalanceGuard_Target` คงที่ตามที่ตั้ง
2. **Dynamic** — อัปเดต target อัตโนมัติจาก Balance ล่าสุดเมื่อ account flat (ไม่มี order ค้าง)

เมื่อเกิด Hedging → ระบบ track Equity → ถึง target → ปิดทุกออเดอร์ → reset → (Dynamic mode) อัปเดต target ใหม่จาก balance ปัจจุบัน

### Changes Made (v6.28 → v6.29)

1. **Version bump**: v6.28 → v6.29
2. **New enum**: `ENUM_BALGUARD_MODE` (BALGUARD_FIXED / BALGUARD_DYNAMIC)
3. **New input**: `InpBalanceGuard_Mode` — เลือกโหมด Fixed หรือ Dynamic
4. **New global**: `g_balanceGuardDynamicTarget` — เก็บ target ที่อัปเดตอัตโนมัติ
5. **OnInit**: Dynamic mode เริ่มต้น target จาก `AccountInfoDouble(ACCOUNT_BALANCE)`
6. **CheckBalanceGuard()**: ใช้ `effectiveTarget` จาก mode ที่เลือก, อัปเดต dynamic target เมื่อ flat
7. **Dashboard**: แสดงโหมด (Fix/Dyn) + สถานะ Active/Standby + Equity vs Target

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Grid/TP/SL)
- Core Module Logic (License, News, Time, Data sync)
- DD trigger / Triple-gate / Matching close
- OpenDDHedge / binding / generation logic
- Safe Cycle Reset (v6.27)
- Balance Guard core trigger logic (v6.28)
