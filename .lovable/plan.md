

## v6.32 — แก้ Daily Profit Pause ให้ใช้ Equity เทียบ Balance เริ่มต้นวัน และหยุดเมื่อ flat เท่านั้น

### ปัญหาปัจจุบัน
1. `CalcDailyPL()` นับเฉพาะ **closed deals** (กำไรที่ปิดแล้ว) → Balance เพิ่มจาก closed profit ก็ trigger ทันที ทั้งที่ยังมีออเดอร์ floating อยู่
2. ระบบ pause ทันทีเมื่อ target ถึง → block ออเดอร์ใหม่ทั้งที่ยังมีออเดอร์เปิดค้างอยู่ ทำให้ grid/hedge ค้าง

### แนวทางแก้
- **บันทึก Balance เริ่มต้นของวัน** (`g_dailyStartBalance`) ตอนวันใหม่เริ่ม
- **เปลี่ยนเงื่อนไข trigger**: ใช้ `Equity - g_dailyStartBalance >= Target` แทน `CalcDailyPL()`
- **เพิ่มเงื่อนไข flat**: trigger ได้เฉพาะเมื่อ `TotalOrderCount() == 0` (ไม่มีออเดอร์เลย)

### Changes

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Version bump → v6.32

#### 2. เพิ่ม global variable
```cpp
double g_dailyStartBalance = 0;  // v6.32: Balance snapshot at day start
```

#### 3. แก้ Daily Profit Pause check (line ~1173-1202)
```text
เมื่อวันใหม่เริ่ม:
├── Reset g_dailyProfitPaused = false
├── g_dailyStartBalance = AccountInfoDouble(ACCOUNT_BALANCE)  ← snapshot

เช็ค target:
├── dailyPL = AccountInfoDouble(ACCOUNT_EQUITY) - g_dailyStartBalance
├── ถ้า dailyPL >= target AND TotalOrderCount() == 0
│   └── trigger pause
├── ถ้า dailyPL >= target แต่ยังมี order
│   └── ยังไม่ pause, ปล่อยให้ทำงานต่อจนกว่า flat
```

#### 4. อัปเดต Dashboard (line ~3247-3254)
- แสดง Equity-based daily PL แทน closed PL เดิม
- แสดง `$equity_PL / $target` ที่ถูกต้อง

#### 5. คง `CalcDailyPL()` ไว้ — ไม่ลบ (อาจใช้ที่อื่น)

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic — ไม่แก้
- Trading Strategy Logic — ไม่แก้
- Core Module Logic — ไม่แก้
- DD trigger / Triple-gate / Matching close — ไม่แก้
- OpenDDHedge / binding / generation logic — ไม่แก้
- Balance Guard (v6.31) — ไม่แก้
- Resume Daily Profit button — ยังทำงานเหมือนเดิม

