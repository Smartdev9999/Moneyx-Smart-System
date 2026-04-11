

## v6.52 — ปิด Matching Close = ปิดกลไกปิด Hedge ทั้งหมด (เหลือแค่ Balance Guard)

### ปัญหา
v6.51 ปิดแค่ `ManageHedgeMatchingClose()` แต่ระบบยังรัน:
- `ManageHedgeBoundAvgTP()` — ปิด bound orders ด้วย avg TP
- `ManageHedgePartialClose()` — ปิด bound orders บางส่วน  
- `TryEnterCombinedGridMode()` — เข้า grid recovery mode

ผู้ใช้ต้องการ: เมื่อ `InpHedge_UseMatchingClose = false` → **ข้ามทั้งหมด** → ให้ Balance Guard เป็นตัวเดียวที่ปิด hedge ได้

### แผนแก้ไข — ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Version bump → v6.52

#### 2. แก้ `ManageHedgeSets()` (~line 8657-8694)

เพิ่ม guard ครอบทั้ง STEP 1 และ STEP 2:

```cpp
// v6.52: If matching close disabled → skip ALL hedge recovery (only Balance Guard can close)
if(!InpHedge_UseMatchingClose)
   continue;   // Skip matching close, avg TP, partial close, AND grid mode

// STEP 1 — Run matching/close cycle FIRST
if(!g_hedgeSets[h].matchingDone)
{
   // ... existing matching close, avg TP, partial close ...
}

// STEP 2 — After matching done, try entering combined grid mode
TryEnterCombinedGridMode(h);
```

#### 3. ลบ guard เดิมของ v6.51 ที่อยู่ใน line 8665

เนื่องจาก `continue` ข้างบนจะข้ามทั้งหมดแล้ว ไม่จำเป็นต้องเช็คซ้ำที่ matching close

### สิ่งที่ไม่เปลี่ยนแปลง
- Balance Guard — ยังทำงานปกติ (ไม่ได้อยู่ใน loop นี้)
- `ManageHedgeMatchingClose()` function body — ไม่แก้
- Trading Strategy / Order Execution Logic — ไม่แก้
- Grid entry/exit logic — ไม่แก้
- Deferred Data Sync (v6.49) / InstantTP (v6.50) — ไม่แก้
- v6.37-v6.51 features — ไม่แก้

### ผลลัพธ์
- `InpHedge_UseMatchingClose = true` → ทำงานเหมือนเดิมทุกอย่าง
- `InpHedge_UseMatchingClose = false` → Hedge set คงอยู่ไม่มีกลไกปิด → รอ Balance Guard เท่านั้น

