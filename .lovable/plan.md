

## Fix: Hedge Grid Matching ไม่ใช้ InpHedge_PartialMinProfitOrders (v4.8 → v4.9)

### วิเคราะห์ปัญหา

ตอนนี้มี 2 inputs ที่ควบคุม min profit orders แยกกัน:
- `InpHedge_PartialMinProfitOrders = 3` → ใช้ใน `ManageHedgePartialClose()` (Scenario 2 ฝั่งตรงข้าม) ✅ ทำงาน
- `InpHedge_MatchMinProfitOrders = 2` → ใช้ใน `ManageHedgeGridMode()` (Grid matching) ← **ปัญหาอยู่ตรงนี้**

จากภาพ: มี grid profit orders 4 ตัว (GL19=747, GL18=484, GL17=257, GL16=78) แต่ไม่ซอย hedge → แสดงว่า logic ใน grid mode ใช้ input คนละตัว หรือเงื่อนไขอื่นไม่ผ่าน

**ผู้ใช้ต้องการ**: input `InpHedge_PartialMinProfitOrders` ใช้ได้กับ **ทั้ง** Scenario 2 (counter-side orders) **และ** Grid Matching (grid orders ฝั่งเดียวกับ hedge) เป็นตัวเดียวกัน

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. แก้ ManageHedgeGridMode() line 6267
เปลี่ยนจาก:
```cpp
if(mainHedgeExists && mainHedgePnL < 0 && gridProfitCount >= InpHedge_MatchMinProfitOrders)
```
เป็น:
```cpp
if(mainHedgeExists && mainHedgePnL < 0 && gridProfitCount >= InpHedge_PartialMinProfitOrders)
```

#### 2. (ถ้าต้องการ) ลบ input `InpHedge_MatchMinProfitOrders` ที่ซ้ำซ้อน
หรือเปลี่ยนให้ใช้ `InpHedge_PartialMinProfitOrders` แทนทั้งสองจุด เพื่อไม่ให้สับสน

#### 3. Version bump: v4.8 → v4.9

### สิ่งที่ไม่เปลี่ยนแปลง
- Logic อื่นทั้งหมดใน ManageHedgeGridMode (distance, lot calculation, grid opening)
- ManageHedgePartialClose, ManageHedgeMatchingClose
- Trading logic ปกติ, Matching Close ปกติ

