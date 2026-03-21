

## ปรับ Dashboard Hedge Section — ซ่อนเมื่อไม่มี Hedge Active

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5` (line 2934-2966)

#### 1. ลบ "STANDBY" row — ไม่แสดงอะไรเลยเมื่อไม่มี Hedge active

เปลี่ยนจาก:
```cpp
if(!anyActive)
{
   DrawTableRow(row, "Hedge Mode", "STANDBY", clrGray, C'130,50,180'); row++;
}
```
เป็น: **ลบออกทั้งบล็อก** — เมื่อไม่มี active hedge set → ไม่แสดง section นี้เลย

#### 2. เพิ่ม validation ก่อนแสดง Hedge Set

ในลูปที่แสดง Hedge Set → เพิ่มเงื่อนไขเช็คว่า hedge ticket ยังมี position อยู่จริง:
```cpp
if(g_hedgeSets[h].active && PositionSelectByTicket(g_hedgeSets[h].hedgeTicket))
```
ป้องกันกรณี `active = true` แต่ position ถูกปิดไปแล้ว (ยังไม่ทัน deactivate)

### สิ่งที่ไม่เปลี่ยนแปลง
- Hedge logic ทั้งหมด (เปลี่ยนแค่ Dashboard display)
- เมื่อมี active hedge → แสดงข้อมูลเหมือนเดิม

