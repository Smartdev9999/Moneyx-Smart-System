# Gold Miner EA v6.95 — Hero Order Minimum Activation Threshold

## ปัญหาปัจจุบัน (v6.94)
ใน `BuildHeroTicketCache()` ใช้เงื่อนไข:
```cpp
if(n <= InpHero_OrderCount) continue;
```
หมายความว่าถ้าตั้ง `InpHero_OrderCount=2` พอออเดอร์ฝั่งนั้นถึง **3 ตัว** ระบบจะเริ่มกัน 2 ตัวล่าสุดเป็น Hero ทันที — ซึ่งยังเร็วเกินไปสำหรับบางสไตล์เทรด ผู้ใช้ต้องการกำหนดได้เองว่า "ต้องมีออเดอร์ขั้นต่ำเท่าไหร่ ระบบถึงเริ่มทำงาน Hero"

## เป้าหมาย v6.95
เพิ่ม **input ใหม่ตัวเดียว** ให้ผู้ใช้กำหนด minimum threshold ของจำนวนออเดอร์ฝั่งเดียวกันก่อนที่ Hero logic จะเริ่มทำงาน โดยแยกอิสระจาก `InpHero_OrderCount`

ตัวอย่างการใช้งาน:
- `InpHero_MinOrdersToActivate=5`, `InpHero_OrderCount=2`
  - ออเดอร์ฝั่ง BUY = 1,2,3,4 ตัว → **ยังไม่มี Hero** (basket เดินปกติ, GL/GP ทำงาน)
  - ออเดอร์ฝั่ง BUY = 5 ตัว → **เริ่มกัน 2 ตัวล่าสุดเป็น Hero**, basket เหลือ 3 ตัว
  - ออเดอร์ฝั่ง BUY = 8 ตัว → กัน 2 ตัวล่าสุดเป็น Hero, basket เหลือ 6 ตัว

## สิ่งที่จะแก้ใน `public/docs/mql5/Gold_Miner_EA.mq5`

### 1. เพิ่ม input parameter ใหม่ (หลังบรรทัด 131)
```cpp
input int InpHero_MinOrdersToActivate = 5; // Min orders on side before Hero activates (0=use OrderCount only)
```
- Default = 5 (ปลอดภัย, ไม่กระตุ้นเร็วเกินไป)
- ถ้าตั้ง = 0 → fallback เป็นพฤติกรรม v6.94 เดิม (กระตุ้นเมื่อ n > InpHero_OrderCount)

### 2. แก้เงื่อนไขใน `BuildHeroTicketCache()` (บรรทัด 2301)
เปลี่ยนจาก:
```cpp
if(n <= InpHero_OrderCount) continue;
```
เป็น:
```cpp
int activateThreshold = (InpHero_MinOrdersToActivate > 0)
                        ? InpHero_MinOrdersToActivate
                        : InpHero_OrderCount + 1;
if(n < activateThreshold) continue;
int take = MathMin(InpHero_OrderCount, n - 1); // กัน basket อย่างน้อย 1 ตัวเสมอ
```

### 3. อัปเดต Audit Log (บรรทัด ~2310)
เพิ่ม `minActivate` ใน log เพื่อให้ debug ง่าย:
```text
v6.95 Hero CACHE: total=N heroBUY=.. heroSELL=.. nonHeroBUY=.. nonHeroSELL=.. minActivate=5
```

### 4. Version Bump
อัปเดตทุกจุด:
- `#property version`
- `#property description`
- Header comment block
- OnInit log
- Dashboard version display
- log tag `v6.94 Hero ...` → `v6.95 Hero ...` เฉพาะจุดที่แก้

## สิ่งที่ไม่เปลี่ยน (ยืนยันตามกฎเหล็ก)
- ❌ Order execution (OrderSend, trade.Buy/Sell/PositionClose)
- ❌ Entry conditions / SMA / EMA / Squeeze / BB / Z-Score
- ❌ Grid Loss / Grid Profit lot, distance, candle confirm
- ❌ Hedge / Triple-Gate / Matching close / Recovery / Auto Recovery
- ❌ DD% TP / Daily Target / Balance Guard
- ❌ Trailing-stop calculations (Hero guards จาก v6.93/94 ยังคงเดิม)
- ❌ License / News / Time / Sync
- ❌ `ShouldBlockSameSideGridForHero` logic (v6.94 survivor-only block)
- ❌ `ManageHeroSameSideClose` (v6.93 same-side close)
- ❌ `IsHeroTicket` integration ทุกจุด (avg, PL gate, trailing exclusion)

## Test Checklist
1. ตั้ง `InpHero_MinOrdersToActivate=5`, `InpHero_OrderCount=2`
2. เปิด BUY 1→4 ตัว → log `heroBUY=0` (ยังไม่กระตุ้น)
3. เปิด BUY ตัวที่ 5 → log `heroBUY=2`, basket = 3 ตัว
4. GL/GP ฝั่ง BUY ยังเปิดได้ (เพราะ non-Hero basket > 0)
5. ตั้ง `InpHero_MinOrdersToActivate=0` → behavior กลับเป็น v6.94 (กระตุ้นที่ n=3 เมื่อ OrderCount=2)
6. ขอบ edge: ถ้า `InpHero_OrderCount=5` แต่มีออเดอร์ 5 ตัวพอดี → กันได้แค่ 4 ตัว (เหลือ basket 1 ตัวเสมอ ป้องกัน Hero กลืน basket หมด)
