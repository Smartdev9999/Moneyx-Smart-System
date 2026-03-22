

## Fix: Basket TP ปิด Order ที่ Bound กับ Hedge — ต้อง Skip Orders ที่อยู่ในระบบ Hedge (v5.6 → v5.7)

### สาเหตุ

เมื่อเกิด Hedge แล้ว order ฝั่ง Buy (ตัวอย่าง) ถูกผูกเข้า `boundTickets[]` ของ hedge set แต่:

1. **`CalculateAveragePrice()`** (line 1477) — skip เฉพาะ `IsHedgeComment()` แต่ **ไม่ skip order ที่ bound** → Average Price ยังรวม order เหล่านี้
2. **`CalculateFloatingPL()`** (line 1507) — เหมือนกัน ไม่ skip bound orders → P/L รวม order ที่ควรจัดการโดย hedge system
3. **`CloseAllSide()`** (line 1564) — skip เฉพาะ hedge comment → ปิด bound orders ทิ้ง → hedge set เสียหาย
4. **`ManageTPSL()`** (line 1628) — ใช้ค่าจาก (1) และ (2) → เมื่อราคาดีดกลับ TP Hit → ปิด bound buy orders → hedge ซอยไม่ได้

**ผล:** กราฟดีดกลับ → TP Hit (BUY) → ปิด Buy orders ที่ผูกกับ hedge → hedge sell ค้างโดยไม่มี counter orders

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. แก้ `CalculateAveragePrice()` — skip bound orders (line 1491)

```text
เพิ่มหลัง IsHedgeComment check:
  ulong ticket = PositionGetTicket(i);
  if(IsTicketBound(ticket)) continue;  // managed by hedge system
```

#### 2. แก้ `CalculateFloatingPL()` — skip bound orders (line 1519)

```text
เพิ่มหลัง IsHedgeComment check:
  if(IsTicketBound(ticket)) continue;
```

#### 3. แก้ `CloseAllSide()` — skip bound orders (line 1575)

```text
เพิ่มหลัง IsHedgeComment check:
  if(IsTicketBound(ticket)) continue;
```

#### 4. แก้ `CalculateAveragePriceTF()` (line ~3477) — skip bound + hedge

ตรวจสอบว่ามี `IsHedgeComment` + `IsTicketBound` skip เหมือนกัน (TF-based version)

#### 5. แก้ `CloseAllSideTF()` (line ~3561) — skip bound orders

เพิ่ม `IsTicketBound(ticket) continue` เหมือน `CloseAllSide()`

#### 6. Version bump: v5.6 → v5.7

### สิ่งที่ไม่เปลี่ยนแปลง
- Hedge logic ทั้งหมด (Partial/Matching/Grid Close)
- Normal Matching Close logic
- Trading Strategy Logic
- Dashboard / Hedge Cycle Monitor

