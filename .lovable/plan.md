

## v6.54 — เพิ่มโหมด "Start Order Grid" สำหรับ Max Grid Average Trailing Stop

### หลักการ

ปัจจุบัน Max Grid Trailing ทำงานเมื่อ `glCount >= GridLoss_MaxTrades` เท่านั้น (เช่น ถึง 30 orders) ผู้ใช้ต้องการโหมดใหม่ที่ trailing เริ่มทำงานเมื่อถึง order ที่กำหนด (เช่น GL#10) โดยไม่ต้องรอถึง max — ระบบยังเปิด grid ต่อได้จนถึง max แต่ trailing เริ่มทำงานแล้ว

### แผนแก้ไข — ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Version bump → v6.54

#### 2. เพิ่ม input parameters ใหม่ 2 ตัว

```cpp
input group "=== Max Grid Average Trailing Stop ==="
input bool           MaxGrid_TrailEnable     = false;
input int            MaxGrid_TrailMode       = 0;      // Mode: 0=Max Order Grid, 1=Start Order Grid  ← NEW
input int            MaxGrid_StartOrders     = 10;     // Start Trail at N orders (Mode 1 only)        ← NEW
input int            MaxGrid_TrailActivation = 100;
input int            MaxGrid_TrailStep       = 50;
input int            MaxGrid_BreakevenBuffer = 10;
```

- **Mode 0 (Max Order Grid)**: ทำงานเหมือนเดิม — trailing เริ่มเมื่อ `glCount >= GridLoss_MaxTrades`
- **Mode 1 (Start Order Grid)**: trailing เริ่มเมื่อ `glCount >= MaxGrid_StartOrders` — grid ยังเปิดต่อได้

#### 3. แก้เงื่อนไขใน `ManageMaxGridTrailing()` (2 จุด: BUY และ SELL)

เปลี่ยนจาก:
```cpp
if(glCount >= GridLoss_MaxTrades)
```

เป็น:
```cpp
int requiredOrders = (MaxGrid_TrailMode == 1) ? MaxGrid_StartOrders : GridLoss_MaxTrades;
if(glCount >= requiredOrders)
```

ทำทั้ง BUY side (~line 3009-3010) และ SELL side (~line 3060-3061)

#### 4. อัปเดต Dashboard display

แสดงโหมดและจำนวน order ที่ต้องถึง:
```
MaxGrid Trail | ON | Mode: Start@10 | Mon: GM
```

#### 5. สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic — ไม่แก้
- Trading Strategy Logic — ไม่แก้
- Core Module Logic — ไม่แก้
- Grid entry/exit logic — ไม่แก้ (grid ยังเปิดต่อได้ตามปกติ)
- Hedge Matching Close / Balance Guard — ไม่แก้
- ManageMaxGridTrailing trailing/activation/close logic — ไม่แก้ (แก้แค่เงื่อนไขเริ่มต้น)
- v6.37-v6.53 features — ไม่แก้

### ผลลัพธ์
- **Mode 0**: เหมือนเดิมทุกอย่าง
- **Mode 1**: เช่น `MaxGrid_StartOrders = 10`, `GridLoss_MaxTrades = 30` → trailing เริ่มทำงานตั้งแต่ GL#10 → grid ยังออก order ต่อถึง GL#30 ได้ → แต่ถ้าราคากลับมาถึง avg + activation → ปิดทั้งหมดเลย

