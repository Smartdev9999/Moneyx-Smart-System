

## แก้ปัญหา Per-Order Trailing ถูก Basket TP ปิดทับ

### สาเหตุที่แท้จริง

เมื่อ `EnablePerOrderTrailing = true` และ `UseTP_Dollar = true` ($100) ทำงานพร้อมกัน:

```text
Tick เดียวกัน:
1. ManagePerOrderTrailing() -> ตั้ง SL กันหน้าไม้ที่ open+5 points (ถูกต้อง)
2. ManageTPSL() -> เช็ค basket PL >= $100 -> CloseAllSide() ปิดทุกออเดอร์ทันที!
```

ผลคือ: SL ถูกตั้งแล้ว แต่ยังไม่ทันได้ใช้เพราะ ManageTPSL ปิดทุกอย่างทับในคำสั่งถัดไปของ tick เดียวกัน ดูเหมือนว่า "ปิดเลย" แทนที่จะ "กันหน้าไม้"

### การแก้ไข

| ไฟล์ | รายละเอียด |
|------|-----------|
| `public/docs/mql5/Gold_Miner_EA.mq5` | แก้ ManageTPSL ให้ข้าม basket TP เมื่อใช้ Per-Order Trailing |

### สิ่งที่จะเปลี่ยน

**ManageTPSL() - ข้าม TP checks เมื่อ Per-Order Trailing เปิดอยู่:**

```text
void ManageTPSL() {
    // เมื่อ EnablePerOrderTrailing = true:
    //   - ข้าม basket TP (UseTP_Dollar, UseTP_Points, UseTP_PercentBalance) 
    //     เพราะแต่ละ order จะถูกจัดการโดย trailing SL ของมันเอง
    //   - ยังคงเช็ค basket SL (emergency stop loss) ตามปกติ
    //   - ยังคงเช็ค Accumulate Close ตามปกติ (เป็น global target)
    
    if(!EnablePerOrderTrailing) {
        // TP checks ปกติ (UseTP_Dollar, UseTP_Points, UseTP_PercentBalance)
        if(closeTP) CloseAllSide()...
    }
    
    // SL checks ยังทำงานเสมอ (เป็น emergency exit)
    if(EnableSL) { ... }
    
    // Accumulate Close ยังทำงานเสมอ
}
```

**หลักการ:**
- Per-Order Trailing = แต่ละ order จัดการ exit เอง ผ่าน broker SL
- Basket TP ไม่จำเป็นเมื่อใช้ per-order trailing (เพราะแต่ละตัวปิดเองตาม trailing)
- Basket SL ยังเป็น safety net สำหรับ emergency
- Accumulate Close ยังทำงานเป็น global target

### รายละเอียดทางเทคนิค

แก้ไขใน `ManageTPSL()` (บรรทัด 599-724):

**BUY side (บรรทัด ~613-628):**
```text
// เปลี่ยนจาก:
if(UseTP_Dollar && plBuy >= TP_DollarAmount) closeTP = true;
...

// เป็น:
if(!EnablePerOrderTrailing) {
    if(UseTP_Dollar && plBuy >= TP_DollarAmount) closeTP = true;
    if(UseTP_Points && bid >= avgBuy + TP_Points * point) closeTP = true;
    if(UseTP_PercentBalance && plBuy >= balance * TP_PercentBalance / 100.0) closeTP = true;
}
```

**SELL side - เหมือนกัน**

ส่วน SL checks และ Accumulate Close ไม่เปลี่ยนแปลง ยังทำงานตามปกติ

