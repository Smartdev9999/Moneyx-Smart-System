

## v6.53 — Fix: Persist g_cycleGeneration + CalculateTotalLots กรอง bound orders

### สาเหตุ

1. **g_cycleGeneration หายเมื่อ restart**: `RecoverHedgeSets()` สแกน positions → ไม่เจอ hedge order (ผู้ใช้ปิดเอง) → `maxGen = 0` → `g_cycleGeneration = 0` → ออเดอร์ใหม่ใช้ "GM" แทน "GM1"
2. **ผลกระทบ**: ออเดอร์ชุดใหม่ (GM) + ออเดอร์เก่า (GM ที่ถูก release) ถูกรวมเป็น basket เดียว → `SyncBrokerTPSL()` ตั้ง TP กลับให้ออเดอร์เก่าที่เคย clear
3. **`CalculateTotalLots()` ไม่กรอง bound/hedge** → TP คำนวณจาก lots ที่รวม bound → ค่าผิด

### แผนแก้ไข — ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Version bump → v6.53

#### 2. เพิ่ม GlobalVariable persist สำหรับ g_cycleGeneration

```cpp
string GV_CycleGenKey() { return "GM_CycleGen_" + _Symbol + "_" + IntegerToString(MagicNumber); }

void SaveCycleGeneration() { GlobalVariableSet(GV_CycleGenKey(), (double)g_cycleGeneration); }

int LoadCycleGeneration()
{
   string key = GV_CycleGenKey();
   if(GlobalVariableCheck(key))
      return (int)GlobalVariableGet(key);
   return -1;
}
```

#### 3. แก้ OnInit — Load ก่อน RecoverHedgeSets, ใช้ค่าที่สูงกว่า

```cpp
int savedGen = LoadCycleGeneration();
RecoverHedgeSets();  // sets g_cycleGeneration = maxGen from positions

if(savedGen > g_cycleGeneration)
{
   g_cycleGeneration = savedGen;
   Print("v6.53: Restored g_cycleGeneration from GlobalVariable = ", savedGen);
}
```

#### 4. เรียก SaveCycleGeneration() ทุกจุดที่ g_cycleGeneration เปลี่ยน

- หลัง `g_cycleGeneration++` (2 จุด: expansion hedge ~line 7558, DD hedge ~line 7799)
- หลัง `g_cycleGeneration = 0` (2 จุด: TryResetCycleStateIfFlat, Balance Guard)
- หลัง `g_cycleGeneration = maxGen` ใน RecoverHedgeSets (~line 7887)
- ใน OnDeinit — save ก่อน shutdown

#### 5. แก้ `CalculateTotalLots()` — กรอง bound/hedge orders

```cpp
double CalculateTotalLots(ENUM_POSITION_TYPE side)
{
   double totalLots = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_TYPE) != side) continue;
      if(IsHedgeComment(PositionGetString(POSITION_COMMENT))) continue;  // v6.53
      if(IsTicketBound(ticket)) continue;  // v6.53
      totalLots += PositionGetDouble(POSITION_VOLUME);
   }
   return totalLots;
}
```

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic — ไม่แก้
- Trading Strategy Logic — ไม่แก้
- Core Module Logic — ไม่แก้
- Grid entry/exit logic — ไม่แก้
- Hedge Matching Close / Balance Guard — ไม่แก้
- RecoverHedgeSets scanning logic — ไม่แก้ (เพิ่มแค่ compare กับ saved value)
- SyncBrokerTPSL modify loop — ไม่แก้ (มี IsTicketBound guard อยู่แล้ว)
- Deferred Data Sync (v6.49) / InstantTP (v6.50) / UseMatchingClose (v6.52) — ไม่แก้

### ผลลัพธ์ที่คาดหวัง
- Hedge เปิด → gen=1 → **persist ทันที** → restart/ปิด hedge เอง → gen ยังเป็น 1
- ออเดอร์ใหม่ใช้ "GM1" ถูกต้อง → ไม่ผสมกับออเดอร์เก่า
- TP คำนวณจาก lots ที่ถูกต้อง (ไม่รวม bound)
- Account flat → gen=0 → persist 0 → restart ได้ 0 ถูกต้อง

