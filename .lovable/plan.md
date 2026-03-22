

## เพิ่มทิศทาง Expansion (Buy/Sell) บน Dashboard — Gold Miner SQ EA

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5` (line 2911)

#### แก้ไข Dashboard Squeeze Section — แสดงทิศทางเมื่อ Expansion

เปลี่ยน line 2911 จาก:
```cpp
else if(g_squeeze[sq].state == 2)  { stateStr = "EXPANSION"; stateClr = clrDodgerBlue; }
```
เป็น:
```cpp
else if(g_squeeze[sq].state == 2)
{
   if(g_squeeze[sq].direction == 1)       { stateStr = "EXPANSION BUY";  stateClr = clrDodgerBlue; }
   else if(g_squeeze[sq].direction == -1) { stateStr = "EXPANSION SELL"; stateClr = clrOrangeRed;  }
   else                                   { stateStr = "EXPANSION";      stateClr = clrDodgerBlue; }
}
```

**ผล:** เมื่อ TF ใดเป็น Expansion จะแสดง `EXPANSION BUY` (สีฟ้า) หรือ `EXPANSION SELL` (สีแดงส้ม) ตาม `direction` ที่คำนวณจาก Close vs EMA อยู่แล้วใน `UpdateSqueezeState()`

### สิ่งที่ไม่เปลี่ยนแปลง
- Trading logic, Hedge logic, Squeeze filter logic ทั้งหมด
- `direction` field คำนวณอยู่แล้ว — ใช้ค่าที่มีอยู่เท่านั้น

