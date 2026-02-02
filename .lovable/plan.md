

## แผนรวม: Mini Group Complete Update (v2.1.2) ✅ COMPLETED

### สรุปทั้งหมดที่ทำเสร็จแล้ว

| หมวด | รายละเอียด | สถานะ |
|------|------------|-------|
| **UI** | ขยาย Mini Group Column (90→110px), สีน้ำเงินแยกชัด, ปุ่ม Close Mini ไป Row 2 | ✅ |
| **Display** | M.Tgt แสดงเป็น `1000/1000/1000` แทนผลรวม `$3000` | ✅ |
| **Logic** | Reset `closedProfit = 0` เมื่อ Mini Group ถึง target และปิดแล้ว เพื่อเริ่มรอบใหม่ | ✅ |

---

### การเปลี่ยนแปลงที่ดำเนินการแล้ว

#### 1. UI Improvements
- เพิ่มสี Mini Group เฉพาะ (COLOR_HEADER_MINI, COLOR_COLHDR_MINI, COLOR_MINI_BG, COLOR_MINI_BORDER)
- ขยาย miniGroupWidth จาก 90 เป็น 110px
- เปลี่ยนสี header และ row background ของ Mini Group เป็นโทนสีน้ำเงิน
- ย้ายปุ่ม "Close Mini" ไปที่ Row 2 ของแต่ละ Mini Group

#### 2. M.Tgt Display Format
- เพิ่ม function ใหม่ `GetMiniGroupTargetString(int groupIndex)` 
- แสดง M.Tgt เป็น format "1000/1000/1000" แทนที่จะรวมเป็น "$3000"

#### 3. Reset Logic เมื่อถึง Target
- แก้ไข `CloseMiniGroup()` ให้โอน profit ไป parent group แล้ว reset Mini Group เป็น $0 เพื่อเริ่มรอบใหม่

---

### Version Update

```cpp
#property version   "2.12"
#property description "v2.1.2: Mini Group UI + M.Tgt Format + Reset Cycle Logic"
```
