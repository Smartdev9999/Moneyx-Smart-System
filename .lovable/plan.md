

## v6.34 — แก้ Max DD ให้แสดงเป็น % เสมอทุกโหมด

### ปัญหา
- โหมด Dollar: แปลง `g_maxDD` (ซึ่งเก็บเป็น %) กลับเป็น $ ด้วย `g_maxDD / 100.0 * balance` → ค่าผิดเพราะ balance เปลี่ยนตลอด
- ผู้ใช้ต้องการให้ **Max DD แสดงเป็น % เสมอ** ไม่ว่าจะตั้ง Cut Loss เป็นโหมดไหน

### แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Version bump → v6.34

#### 2. แก้ Dashboard display (line ~3151-3152)
เปลี่ยนจาก:
```cpp
DrawTableRow(row, "Max DD", "$" + DoubleToString(g_maxDD / 100.0 * balance, 2), ...);
```
เป็น:
```cpp
DrawTableRow(row, "Max DD%", DoubleToString(g_maxDD, 2) + "%",
             (g_maxDD > 15 ? COLOR_LOSS : COLOR_TEXT), COLOR_SECTION_DETAIL); row++;
```

ให้เหมือนกับโหมด % (line 3158-3159) — ทั้งสองโหมดแสดง Max DD เป็น % เหมือนกัน

#### 3. อัปเดต version ทุกจุด (header, description, OnInit log, dashboard)

### สิ่งที่ไม่เปลี่ยนแปลง
- `g_maxDD` tracking logic (line 1330-1331) — ยังคำนวณ % เหมือนเดิม
- Order Execution Logic, Trading Strategy Logic, Core Module Logic — ไม่แก้
- DD trigger / Triple-gate / Matching close — ไม่แก้
- OpenDDHedge / binding / generation logic — ไม่แก้
- Balance Guard (v6.33) — ไม่แก้
- Daily Target Profit (v6.32) — ไม่แก้

