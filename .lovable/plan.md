

## v6.51 — เพิ่ม Input เปิด/ปิด Hedge Matching Close

### ปัญหา
ฟังก์ชัน `ManageHedgeMatchingClose()` บางครั้งปิดออเดอร์ในจังหวะไม่เหมาะสม ต้องการ input parameter เพื่อเปิด/ปิดฟังก์ชันนี้ได้

### แผนแก้ไข — ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Version bump → v6.51

#### 2. เพิ่ม input parameter ใหม่ในกลุ่ม Hedge Settings
```cpp
input bool InpHedge_UseMatchingClose = true;  // Enable Hedge Matching Close
```

#### 3. เพิ่ม guard check ก่อนเรียก `ManageHedgeMatchingClose()`
ที่ line ~8663 ใน `ManageHedgeSets()`:
```cpp
// เดิม:
if(hedgePnL > 0)
{
   ManageHedgeMatchingClose(h);
   ...
}

// ใหม่:
if(hedgePnL > 0 && InpHedge_UseMatchingClose)
{
   ManageHedgeMatchingClose(h);
   ...
}
```

ถ้าปิด → ข้ามขั้นตอน Matching Close ไปเลย → `matchingDone = true` → ระบบจะไปทำ Grid Recovery หรือฟังก์ชันอื่นแทน

#### 4. สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic — ไม่แก้
- Trading Strategy Logic — ไม่แก้
- Core Module Logic — ไม่แก้
- `ManageHedgeMatchingClose()` function body — ไม่แก้
- Triple Gate logic — ไม่แก้
- Grid Recovery / Bound Avg TP / Partial Close — ไม่แก้
- Deferred Data Sync (v6.49) / InstantTP (v6.50) — ไม่แก้
- v6.37-v6.50 features — ไม่แก้

