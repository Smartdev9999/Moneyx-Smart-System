

## Hedge Set Isolation System — Gold Miner SQ EA (v5.0 → v5.1)

### ปัญหาปัจจุบัน

ระบบ v5.0 มีจุดอ่อนสำคัญ:

1. **ไม่ track ว่า order ไหนเป็นของ Hedge Set ไหน** — `CountNormalOrders()` นับ global → ทุก set แย่งกันปิด order เดียวกัน
2. **ไม่สามารถ re-hedge ในชุดเดิม** — `HedgeExistsForSide()` block ทุก hedge ฝั่งเดียวกัน
3. **Order ใหม่หลัง hedge ไม่แยกจาก order เก่า** — ไม่มี comment ที่ระบุ set
4. **MQL5 ข้อจำกัด**: ไม่สามารถแก้ไข comment ของ position ที่เปิดอยู่แล้ว

### แนวทางแก้ไข

#### 1. เพิ่ม Internal Ticket Tracking ใน HedgeSet

```text
struct HedgeSet {
   // ... existing fields ...
   ulong    boundTickets[];     // tickets ของ order ฝั่งตรงข้ามที่ผูกไว้ตอน hedge เปิด
   int      boundTicketCount;   // จำนวน bound tickets
};
```

- เมื่อเปิด Hedge → สแกน counter-side orders ทั้งหมด → เก็บ ticket ไว้ใน `boundTickets[]`
- `ManageHedgePartialClose()` / `ManageHedgeMatchingClose()` → ใช้เฉพาะ `boundTickets[]` แทนการสแกน global
- เมื่อ order ถูกปิดโดย normal TP หรือ matching close → ลบ ticket ออกจาก array

#### 2. Comment Scheme สำหรับ Order ใหม่หลัง Hedge

เนื่องจากแก้ comment เดิมไม่ได้ → order เดิมใช้ `boundTickets[]` track แทน

Order ใหม่ที่เปิดหลัง hedge (grid ต่อจาก counter-side):
- ไม่มีการเปลี่ยนแปลง — order ใหม่เปิดเป็น cycle ใหม่ปกติ (`GM_INIT`, `GM_GL`, `GM_GP`)
- order ใหม่เหล่านี้ **ไม่ผูก** กับ hedge set ใดๆ → เป็นอิสระ
- ถ้า expansion เกิดอีกครั้ง → สร้าง hedge set ใหม่ + ผูก order ใหม่เหล่านี้

Hedge Grid orders: ยังใช้ `GM_HG1_GL1`, `GM_HG2_GL1` ตามเดิม (แยก set ชัดเจน)

#### 3. Re-Hedge ในชุดเดิม

แก้ `CheckAndOpenHedge()`:
- เปลี่ยนจาก `HedgeExistsForSide()` block ทั้งหมด → อนุญาตให้เปิด hedge ซ้ำฝั่งเดียวกันเมื่อเป็นคนละ set
- เงื่อนไข: ต้องเป็น order ที่ยังไม่ถูกผูกกับ set อื่น (`IsTicketBound()` helper)
- เมื่อ set เก่ายังเหลือ order + grid อยู่ แต่เกิด expansion ใหม่ → คำนวณ lot จาก unbound orders → เปิด hedge ใหม่เป็น set ใหม่

#### 4. แก้ไขฟังก์ชันหลัก

| ฟังก์ชัน | สิ่งที่แก้ |
|---|---|
| `CheckAndOpenHedge()` | ใช้ `CountUnboundOrders()` แทน `CountNormalOrders()` + เก็บ tickets ใน `boundTickets[]` |
| `ManageHedgePartialClose()` | สแกนเฉพาะ `boundTickets[]` แทน global scan |
| `ManageHedgeMatchingClose()` | สแกนเฉพาะ `boundTickets[]` แทน global scan |
| `ManageHedgeSets()` | เช็ค `boundTicketCount == 0` → enter grid mode (แทน `CountNormalOrders() == 0`) |
| `HedgeExistsForSide()` | ลบ/แก้ → อนุญาตหลาย set ฝั่งเดียวกัน |

#### 5. Helper Functions ใหม่

```text
CountUnboundOrders(side)     — นับ orders ที่ไม่ผูกกับ set ใดเลย
IsTicketBound(ticket)        — เช็คว่า ticket นี้ถูกผูกกับ set ไหนหรือยัง
RemoveBoundTicket(idx, ticket) — ลบ ticket ออกจาก set เมื่อถูกปิด
RefreshBoundTickets(idx)     — สแกน boundTickets[] ลบ ticket ที่ไม่มีอยู่แล้ว
```

#### 6. Flow สรุป

```text
Expansion เกิด:
  1. สแกน unbound counter-side orders
  2. เปิด Hedge → สร้าง Set #N
  3. ผูก counter-side tickets ทั้งหมดเข้า Set #N.boundTickets[]
  4. Orders ใหม่หลังจากนี้ = cycle ใหม่ (ไม่ผูก)

จัดการ Set #N:
  - ทุก tick: RefreshBoundTickets(N) → ลบ tickets ที่ปิดไปแล้ว
  - Partial/Matching Close → ใช้เฉพาะ boundTickets[]
  - boundTicketCount == 0 → Grid Mode
  - Expansion กลับมา → re-hedge กับ remaining boundTickets[]

Accumulate Close:
  - ปิดทุกอย่างรวม hedge ทุก set (ไม่เปลี่ยน)
```

### Version bump: v5.0 → v5.1

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Normal Matching Close logic
- Hedge Grid order opening/distance logic
- Accumulate/Drawdown close logic
- DirectionalBlock logic

