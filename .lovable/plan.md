

## v6.30 — แก้ Dynamic Balance Guard ไม่อัปเดต target เมื่อ flat

### สาเหตุ
`CheckBalanceGuard()` มี early return ที่ line 6564:
```cpp
if(!g_balanceGuardActive) return;  // ← blocks everything below
```
Dynamic target update อยู่ที่ line 6594-6604 ซึ่งอยู่ **หลัง** early return นี้ → เมื่อ guard deactivate แล้ว function จะ return ก่อนถึง update block ทุก tick → target ค้างที่ค่าเริ่มต้นตลอด

### แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Version bump v6.29 → v6.30

#### 2. ย้าย Dynamic target update ขึ้นมาก่อน early return
ปรับโครงสร้าง `CheckBalanceGuard()` ให้:

```text
CheckBalanceGuard()
├── if(!Enable) return
├── [NEW] Dynamic update block — ทำงานทุก tick เมื่อ flat (ไม่ขึ้นกับ g_balanceGuardActive)
│   └── if(BALGUARD_DYNAMIC && TotalOrderCount()==0) → update target จาก ACCOUNT_BALANCE
├── Activate guard when g_hedgeSetCount > 0
├── if(!g_balanceGuardActive) return   ← early return ยังอยู่
├── Check equity >= target → CloseAll
└── Deactivate if flat
```

จุดสำคัญ: Dynamic update block ต้องอยู่ **ก่อน** `if(!g_balanceGuardActive) return;` เพื่อให้ทำงานทุก tick ที่ไม่มี order โดยไม่สนว่า guard active หรือไม่

#### 3. Dashboard — แสดง target ที่อัปเดตแล้ว (ใช้ของเดิม ไม่ต้องแก้)

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic — ไม่แก้
- Trading Strategy Logic — ไม่แก้
- Core Module Logic — ไม่แก้
- DD trigger / Triple-gate / Matching close — ไม่แก้
- OpenDDHedge / binding / generation logic — ไม่แก้
- Safe Cycle Reset (v6.27) — ไม่แก้
- Balance Guard trigger/close logic — ไม่แก้ (แค่ย้ายตำแหน่ง dynamic update)

