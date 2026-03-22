

## Fix: Dashboard "Label" Bug + Recovery Grid Blocked During Expansion (v5.15 → v5.16)

### ปัญหา 3 จุด

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

---

### 1. Dashboard แสดง "Label" แทนข้อความว่าง

**สาเหตุ:** MQL5 `OBJ_LABEL` แสดงข้อความ "Label" เป็นค่าเริ่มต้นเมื่อ text = `""` (empty string)

ในโค้ด line 7605-7608: เมื่อ `groupStatus[g] == 0` และ `row > 0` → `cellText = ""` และ `plText = ""` → OBJ_LABEL แสดง "Label"

**แก้ไข:** เปลี่ยน empty string เป็นช่องว่าง `" "` (space) ทุกจุดที่อาจเป็นค่าว่าง:
- Line 7605: `string cellText = " ";` (แทน `""`)
- Line 7606: `string plText = " ";` (แทน `""`)

### 2. Recovery Grid ถูก Block ระหว่าง Expansion

**สาเหตุ:** Line 6262 `if(!isExpansion)` ครอบทั้ง closing + recovery grid opening → ระหว่าง expansion ระบบไม่เปิด recovery grid orders ทำให้ orders ค้างไม่ได้แก้ไข

**แก้ไข:** แยก recovery grid opening ออกจาก expansion guard:

```text
เดิม (line 6261-6284):
  if(!isExpansion)
  {
     // ทั้ง gridMode + matching/partial close
  }

ใหม่:
  // Grid Recovery: อนุญาตให้เปิด grid orders ได้ทุกสถานะ (เปิด order ≠ ปิด order)
  if(g_hedgeSets[h].gridMode && g_hedgeSets[h].hedgeTicket == 0)
  {
     ManageHedgeGridMode(h);     // recovery → เปิด grid + matching close เมื่อ !isExpansion
  }
  else if(g_hedgeSets[h].gridMode && g_hedgeSets[h].hedgeTicket > 0)
  {
     ManageGridRecoveryMode(h);  // stalled → เปิด counter-side grid + partial close เมื่อ !isExpansion
  }
  else if(!isExpansion)
  {
     // Normal close actions: matching/partial close เฉพาะ Normal/Squeeze
     double hedgePnL = ...;
     if(hedgePnL > 0) ManageHedgeMatchingClose(h);
     else ManageHedgePartialClose(h);
  }
```

จากนั้นภายใน `ManageGridRecoveryMode()` และ `ManageHedgeGridMode()` — แยก logic:
- **เปิด grid orders:** ทำได้ทุกสถานะ (ไม่ต้องเช็ค expansion)
- **ปิด orders (matching close):** เพิ่ม expansion guard ภายในฟังก์ชัน → ปิดได้เฉพาะ Normal/Squeeze

เพิ่ม parameter `bool allowClose` หรือเช็ค squeeze state ภายในฟังก์ชัน:
```cpp
// ต้นฟังก์ชัน ManageGridRecoveryMode()
bool isExpansion = false;
for(int sq = 0; sq < 3; sq++)
   if(g_squeeze[sq].state == 2) { isExpansion = true; break; }

// matching close section:
if(!isExpansion && gridProfitCount >= InpHedge_PartialMinProfitOrders)
{
   // ... existing matching close logic
}

// grid opening section → ไม่มี expansion guard → เปิดได้เสมอ
```

### 3. Group Status Logic — รองรับ Non-Sequential Groups

**สาเหตุ:** Line 7553 `else if(groupHasHedge[g - 1])` → STANDBY แสดงก็ต่อเมื่อ group ก่อนหน้ามี hedge → ถ้า A มี hedge แต่ B ไม่มี → C แสดง OFF (ผิด)

**แก้ไข:** Group แสดง STANDBY ถ้ามี **group ใดก็ตาม** ที่มี hedge อยู่ (ไม่ใช่แค่ g-1):
```cpp
for(int g = 1; g < 10; g++)
{
   if(groupHasHedge[g])
      groupStatus[g] = 2;
   else if(g_hedgeSetCount > 0)  // มี hedge ใดๆ active → STANDBY
      groupStatus[g] = 1;
   else
      groupStatus[g] = 0;
}
```

### 4. Version bump: v5.15 → v5.16

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge Guards (cycle-aware, squeeze directional block)
- Normal Matching Close logic
- Grid Recovery lot calculation + direction logic

