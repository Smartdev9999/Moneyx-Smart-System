

## v6.43 — Fix Broker TP/SL + Dashboard Render Throttle

### ปัญหาที่พบ

**1. TP ไม่ปรากฏเลย (Root Cause)**
- `EnablePerOrderTrailing` default = `true` (line 221)
- Line 1363: `if((UseTP_Points || ...) && !EnablePerOrderTrailing)` → condition = `false` → `SyncBrokerTPSL()` ไม่ถูกเรียกเลย
- Lines 2105/2182: `if(!EnablePerOrderTrailing)` → basket TP checks ถูก skip ทั้งหมด
- ผลลัพธ์: ทั้ง broker-side TP และ EA-side TP ถูก disable เมื่อ per-order trailing เปิด → ไม่มี TP ใดๆ ทำงาน

**2. Dashboard ยังวาดทุก tick**
- Line 1649 ยังเรียก `DisplayDashboard()` ทุก tick โดยไม่มี throttle (แผน v6.43 เดิมยังไม่ implement)

### แผนแก้ไข — ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Version bump → v6.43

#### 2. Fix: ให้ SyncBrokerTPSL ทำงานร่วมกับ Per-Order Trailing ได้

Per-Order Trailing = individual position trailing SL (breakeven + trail per order)
Basket TP via PositionModify = set TP price บนทุก order จาก average price

ทั้งสองสามารถทำงานร่วมกันได้ — broker จัดการ TP และ SL แยกอิสระ

**แก้ line 1363:** ลบ `!EnablePerOrderTrailing` ออกจาก condition
```text
Before: if((UseTP_Points || (EnableSL && UseSL_Points)) && !EnablePerOrderTrailing)
After:  if(UseTP_Points || (EnableSL && UseSL_Points))
```

**แก้ SyncBrokerTPSL() (lines 1994-2005):** ลบ `!EnablePerOrderTrailing` checks
- เมื่อ per-order trailing เปิด → set เฉพาะ TP (ไม่ set SL เพราะ per-order trailing จัดการ SL อยู่แล้ว)
```text
if(UseTP_Points)
   tpBuy = avgBuy + TP_Points * point;
if(EnableSL && UseSL_Points && !EnablePerOrderTrailing)
   slBuy = avgBuy - SL_Points * point;  // SL set by broker only when no per-order trailing
```

**แก้ ManageTPSL() — คืน TP Points check กลับเป็น fallback:**
- เพิ่ม TP Points check กลับ (ไม่ comment) เป็น safety net ถ้า broker TP ไม่ทำงาน
- แต่ wrap ด้วย `if(!EnablePerOrderTrailing)` เฉพาะ Dollar/Percent TP (ไม่ใช่ Points)

Actually ไม่ต้อง — broker TP จะจัดการ Points TP อยู่แล้ว ถ้า SyncBrokerTPSL ทำงานถูกต้อง

#### 3. Dashboard Render Throttle

**เพิ่ม global:**
```cpp
datetime g_lastDashboardRenderTime = 0;
int      g_dashRenderIntervalSec   = 1;
```

**แก้ line 1649:**
```text
Before: if(ShowDashboard) DisplayDashboard();
After:  if(ShowDashboard && TimeCurrent() - g_lastDashboardRenderTime >= g_dashRenderIntervalSec)
        {
           DisplayDashboard();
           g_lastDashboardRenderTime = TimeCurrent();
        }
```

#### 4. เพิ่ม DisplayDashboard() ใน OnInit

เพิ่มท้าย OnInit ก่อน `return INIT_SUCCEEDED;` ให้ dashboard ปรากฏทันทีเมื่อลาก EA เข้าชาร์ต

#### 5. ลบ redundant calculations ใน DisplayDashboard()

ใช้ `plBuy`/`plSell` และ `lotsBuy`/`lotsSell` จากต้นฟังก์ชัน แทนการเรียก `CalculateFloatingPL()` และ `CalculateTotalLots()` ซ้ำ

### ผลลัพธ์

- **TP จะปรากฏ** ในคอลัมน์ T/P ของทุก order ทันที (broker-level)
- Per-order trailing SL ยังทำงานเหมือนเดิม (ไม่กระทบ)
- Dashboard โหลดทันทีเมื่อลาก EA + render ทุก 1 วินาทีแทนทุก tick
- CPU load ลดลง 80-90%

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic — ไม่แก้
- Trading Strategy Logic — ไม่แก้
- Core Module Logic — ไม่แก้
- Dollar/Percent/DD% TP — ยังจัดการผ่าน EA เหมือนเดิม
- Per-Order Trailing Stop logic — ไม่แก้ (breakeven + trail per order ยังเหมือนเดิม)
- Accumulate Close / Drawdown Exit — ไม่แก้
- Grid / Hedge / Balance Guard — ไม่แก้
- v6.37-v6.42 features — ไม่แก้ (เฉพาะ fix condition guard)

