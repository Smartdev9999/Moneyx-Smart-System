

## Fix: Hedge Lot ถูก Cap โดย InpMaxLotSize — Gold Miner SQ EA (v4.5 → v4.6)

### ปัญหา
Sell orders รวม 1.21 lot แต่ Hedge Buy เปิดได้แค่ 1.00 lot เพราะ `OpenOrder()` (line 1356) ใช้ `InpMaxLotSize` cap ทุก order รวมถึง Hedge

```text
OpenOrder() line 1356:
if(InpMaxLotSize > 0) maxLot = MathMin(maxLot, InpMaxLotSize);
→ InpMaxLotSize = 1.0 → hedge 1.21 ถูกตัดเหลือ 1.00
```

### แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. แก้ OpenOrder() — ข้าม MaxLotSize สำหรับ Hedge orders
เพิ่ม check comment ว่าเป็น hedge หรือไม่ → ถ้าใช่ไม่ต้อง cap:

```cpp
bool OpenOrder(ENUM_ORDER_TYPE orderType, double lots, string comment)
{
   ...
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   // Don't apply user MaxLotSize cap for hedge orders — hedge must match exact counter-side volume
   if(InpMaxLotSize > 0 && !IsHedgeComment(comment))
      maxLot = MathMin(maxLot, InpMaxLotSize);
   ...
}
```

#### 2. Version bump: v4.5 → v4.6
- `#property version "4.60"`, description, header, Dashboard

### สิ่งที่ไม่เปลี่ยนแปลง
- ออเดอร์ปกติ (GM_INIT, GM_GL, GM_GP) ยังถูก cap ด้วย InpMaxLotSize เหมือนเดิม
- Trading logic, Hedge system logic, Matching Close ทุกอย่างไม่เปลี่ยน

