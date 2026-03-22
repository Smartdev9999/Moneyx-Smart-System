

## Fix: Grid Loss ไม่ออกออเดอร์ใน Cycle B เมื่อมี Cycle A ถูก Hedge (v5.7 → v5.8)

### สาเหตุ

ฟังก์ชัน 3 ตัวที่ใช้ในการคำนวณ Grid **ไม่ skip order ที่ bound กับ hedge set** → order จาก Cycle A ที่ถูกผูกกับ hedge ถูกนับรวมใน Cycle B:

1. **`CountPositions()`** (line 1380) — นับ `gridLossBuy` รวม order ที่ bound → ถ้า Cycle A มี 5 GL orders ที่ bound อยู่ → `gridLossBuy = 5` → ถึง `GridLoss_MaxTrades` → Cycle B เปิด GL ไม่ได้
2. **`FindLastOrder()`** (line 2373) — หา last order จากทุก cycle → ได้ราคาจาก Cycle A → ระยะ grid ผิดสำหรับ Cycle B
3. **`FindMaxLotOnSide()`** (line 2177) — หา max lot จากทุก cycle → Cycle B เริ่มต้นด้วย lot ที่ใหญ่เกินไป

**Grid Profit เปิดได้** เพราะ Cycle A อาจไม่มี GP orders มาก (หรือไม่ถึง max) → count ยังไม่เต็ม

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. แก้ `CountPositions()` — skip bound orders

เพิ่มหลัง `IsHedgeComment(comment) continue` (line 1400):
```cpp
if(IsTicketBound(ticket)) continue;  // managed by hedge system, don't count for normal grid
```

#### 2. แก้ `FindLastOrder()` — skip bound orders

เพิ่มหลัง symbol check (line 2385):
```cpp
string comment = PositionGetString(POSITION_COMMENT);
if(IsHedgeComment(comment)) continue;
if(IsTicketBound(ticket)) continue;
```

#### 3. แก้ `FindMaxLotOnSide()` — skip bound orders

เพิ่มหลัง type check (line 2186):
```cpp
if(IsTicketBound(ticket)) continue;
```

#### 4. Version bump: v5.7 → v5.8

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic, Trading Strategy Logic
- Hedge logic ทั้งหมด (Partial/Matching/Grid Close)
- Grid Profit / Grid Loss calculation formula
- Dashboard / Hedge Cycle Monitor

