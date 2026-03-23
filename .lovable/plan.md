

## เพิ่ม Input กำหนดจำนวน TF Expansion สำหรับ Hedge Entry — Gold Miner SQ EA (v5.9 → v6.0)

### ปัญหา

ปัจจุบัน `CheckAndOpenHedge()` (line 6062) ใช้ `InpSqueeze_MinTFExpansion` ซึ่งเป็นค่าเดียวกับที่ใช้บล็อก entry ปกติ → เมื่อ expansion เกิดแค่ 1 TF ก็เปิด hedge ทันที → โดนหลอกบ่อย

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. เพิ่ม Input (หลัง InpHedge_BoundAvgTPPoints ~line 322)
```cpp
input int      InpHedge_MinTFConfirm        = 1;      // Min TF Expansion to Confirm Hedge (1-3)
```

#### 2. แก้ `CheckAndOpenHedge()` line 6062

```text
เดิม:
  if(expCount < InpSqueeze_MinTFExpansion || bestDir == 0) return;

ใหม่:
  if(expCount < InpHedge_MinTFConfirm || bestDir == 0) return;
```

**ผล:**
- `InpHedge_MinTFConfirm = 1` → เหมือนเดิม (expansion 1 TF ก็เปิด hedge)
- `InpHedge_MinTFConfirm = 2` → ต้องมี 2 TF เป็น expansion ถึงจะเปิด hedge
- `InpHedge_MinTFConfirm = 3` → ต้องครบ 3 TF ถึงเปิด (เข้มงวดสุด)

#### 3. Version bump: v5.9 → v6.0

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge system logic ทั้งหมด (Matching/Partial/AvgTP/Grid)
- Squeeze filter logic สำหรับ entry ปกติ (ยังใช้ InpSqueeze_MinTFExpansion เหมือนเดิม)

