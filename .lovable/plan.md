

## ปรับ Header และ Version ของ Gold Miner EA

### การแก้ไข
**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5` — Lines 1-9

เปลี่ยนจาก:
- ชื่อไฟล์: `Gold_Miner_EA.mq5` → `Gold_Miner_SQ_EA.mq5`
- Version: `v3.0` → `v4.0`
- `#property version "3.00"` → `"4.00"`
- Description: เพิ่ม `CDC Filter` → เปลี่ยนเป็น `MTF ZigZag Entry + CDC Filter + License + News + Time Filter` (คงเดิมแต่อัพ version)

ตามรูปที่อัพโหลด:
```text
Line 1-5: Header comment block — เปลี่ยนเป็น Gold_Miner_SQ_EA.mq5, v4.0
Line 8:   #property version "4.00"
Line 9:   #property description "Gold Miner EA v4.0 - MTF ZigZag Entry + CDC Filter + License + News + Time Filter"
```

