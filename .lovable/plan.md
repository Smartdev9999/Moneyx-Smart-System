

## ปรับระบบ Hedging ให้ Bound Orders แยกจากระบบปกติสมบูรณ์ — Gold Miner SQ EA (v5.1 → v5.2)

### สรุปสิ่งที่ต้องทำ

ผู้ใช้ต้องการ 3 กลุ่มการเปลี่ยนแปลง:

---

### กลุ่ม 1: Bound Orders ต้องไม่ถูกปิดโดย TP/SL หรือ Matching Close ปกติ

**ปัญหาปัจจุบัน:** `CalculateAveragePrice()`, `CalculateFloatingPL()`, `CloseAllSide()`, และ `ManageMatchingClose()` skip เฉพาะ `IsHedgeComment()` แต่ไม่ skip `IsTicketBound()` → order ปกติที่ bound กับ hedge set ยังถูกนับรวมใน basket TP/SL และถูกปิดได้

**แก้ไข 4 ฟังก์ชัน:**

| ฟังก์ชัน | Line | เพิ่ม |
|---|---|---|
| `CalculateAveragePrice()` | 1407 | `if(IsTicketBound(ticket)) continue;` |
| `CalculateFloatingPL()` | 1435 | `if(IsTicketBound(ticket)) continue;` |
| `CloseAllSide()` | 1491 | `if(IsTicketBound(ticket)) continue;` |
| `ManageMatchingClose()` | 6578 | `if(IsTicketBound(ticket)) continue;` |

**ผล:** Order ที่ bound กับ hedge set จะถูกจัดการโดยระบบ Hedge เท่านั้น ไม่มีการปิดด้วย TP/SL basket หรือ Matching Close ปกติ

---

### กลุ่ม 2: ชี้แจง/ยืนยัน Logic การปิดในระบบ Hedge (4 ตัว)

ตรวจสอบ logic ที่มีอยู่ให้ตรงกับที่ผู้ใช้อธิบาย:

**2a. Min Profit for Hedge Matching (`InpHedge_MatchMinProfit`):**
- ใช้ใน `ManageHedgeMatchingClose()` line 6105 ✅ — ถูกต้องแล้ว
- Hedge order ต้องบวกเกินเกณฑ์ → จับคู่กับ order ที่ขาดทุน
- ทำงานเฉพาะเมื่อ `!isExpansion` (line 6068) ✅

**2b. Min Profit Orders for Hedge Grid Matching (`InpHedge_PartialMinProfitOrders`):**
- ใช้ใน `ManageHedgeGridMode()` line 6384 ✅ — ถูกต้องแล้ว
- Grid order ของ hedge set ต้องมีจำนวนบวกถึงเกณฑ์ → ซอย hedge หลัก

**2c. Min Profit for Partial Close (`InpHedge_PartialMinProfit`):**
- ใช้ใน `ManageHedgePartialClose()` line 6270 ✅ — ถูกต้องแล้ว
- กำไรรวมจาก bound orders ต้องเกินเกณฑ์ → ซอย hedge

**2d. Min Profit Orders for Partial Close (`InpHedge_PartialMinProfitOrders`):**
- ใช้ใน `ManageHedgePartialClose()` line 6258 ✅ — ถูกต้องแล้ว
- **ปัจจุบัน:** ปิด bound orders ทั้งหมดที่บวก → ซอย hedge → **ปัญหา:** bound orders หมดเร็ว
- **แก้ไข:** เปลี่ยนเป็นปิดเฉพาะ **N orders ที่ใหม่สุด** (ที่มีค่าบวก) แทนที่จะปิดทั้งหมด → bound orders เก่ายังอยู่ → สามารถรอกำไรรอบถัดไปได้
- ทำงานเฉพาะ `!isExpansion` ✅ (guard อยู่ที่ `ManageHedgeSets()` line 6068)

---

### กลุ่ม 3: Lot Cap สำหรับ Order ใหม่เมื่อ Bound Orders ยังเหลืออยู่

**ปัญหา:** เมื่อราคากลับตัว → เปิด grid order ใหม่ (ที่จะถูก bound ในรอบถัดไปหรือเป็น cycle ใหม่) → รวม lot กับ bound เก่า อาจเกินขนาด hedge → เสี่ยงที่ lock จะไม่ครอบคลุม

**Logic ใหม่:** ในระบบ entry/grid ปกติ เมื่อ hedge set ยังมี bound orders ของฝั่งนั้นอยู่:
- คำนวณ `remainingBoundLots` = lot รวมของ bound orders ที่ยังเหลือ
- คำนวณ `hedgeLots` = lot ของ hedge order
- `allowedNewLots` = `hedgeLots - remainingBoundLots`
- ถ้า `allowedNewLots <= 0` → **ห้ามเปิด order ใหม่ฝั่งนั้น**
- ถ้า `allowedNewLots > 0` → cap lot ของ order ใหม่ไม่ให้เกิน `allowedNewLots`

**เพิ่ม helper function:**
```text
double GetHedgeLotCap(ENUM_POSITION_TYPE side)
  → scan active hedge sets ที่มี counterSide == side
  → return hedgeLots - sum(boundTickets lots)
  → return -1 ถ้าไม่มี hedge set สำหรับ side นี้ (ไม่ cap)
```

**แก้ไข OpenOrder():** เพิ่ม lot cap check ก่อนเปิดจริง

---

### กลุ่ม 4: Hedge Grid → เริ่ม Lot จาก EquivLevel ที่ถูกต้อง

**ปัจจุบัน (line 6464):** `CalculateEquivGridLevel()` คำนวณจาก `remainingLots` (hedge volume)

**ตรงกับที่ผู้ใช้อธิบาย:** สมมุติ hedge เหลือ 0.2 lot → คำนวณหา level ที่ cumulative lots ไม่เกิน 0.2 → grid ตัวแรกเริ่มจาก level ถัดไป ✅ ถูกต้องแล้ว

**เพิ่ม:** เมื่อ hedge grid ทำกำไร + ซอย hedge จนหมด → รีเซ็ต set ทั้งหมด ✅ มีอยู่แล้ว (line 6409-6411)

---

### กลุ่ม 5: เมื่อ Hedge Set ปิดหมด → Order ที่เกี่ยวข้องกลับเป็นปกติ

**ปัจจุบัน:** เมื่อ `g_hedgeSets[idx].active = false` → `IsTicketBound()` จะไม่พบ ticket นี้อีก → order กลับเป็นปกติ ✅ ถูกต้องแล้ว (ไม่ต้องแก้เพิ่ม)

---

### Version bump: v5.1 → v5.2

อัปเดต: `#property version "5.20"`, description, header, Dashboard

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL calculations)
- Core Module Logic (License, News filter, Time filter, Data sync, Squeeze)
- Hedge Grid distance/direction logic
- ManageHedgeMatchingClose (Scenario 1) logic
- Accumulate/Drawdown close logic

