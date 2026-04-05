

## v6.36 — เพิ่ม Max Hedge Sets จาก 10 เป็น 50

### แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Version bump → v6.36

#### 2. แก้ `#define MAX_HEDGE_SETS` (line 503)
```cpp
#define MAX_HEDGE_SETS 50  // v6.36: expanded from 10 to support up to 50 sets
```

#### 3. แก้ input parameter (line 340)
```cpp
input int      InpHedge_MaxSets              = 10;    // Max Active Hedge Sets (1-50)
```
เปลี่ยน comment จาก `(1-10)` เป็น `(1-50)` — ค่า default ยังเป็น 10

#### 4. อัปเดต version ทุกจุด
- `#property version`
- `#property description`
- Header comment block
- Dashboard display
- OnInit Print log

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic — ไม่แก้
- Trading Strategy Logic — ไม่แก้
- Core Module Logic — ไม่แก้
- DD trigger / Triple-gate / Matching close — ไม่แก้
- OpenDDHedge / binding / generation logic — ไม่แก้
- Balance Guard (v6.33/v6.35) — ไม่แก้
- Daily Target Profit (v6.32) — ไม่แก้
- Loop logic ทั้งหมดใช้ `MAX_HEDGE_SETS` อยู่แล้ว จึงรองรับอัตโนมัติ

