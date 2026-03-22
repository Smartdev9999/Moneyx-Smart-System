

## Fix: Hedge Guards ต้องเป็น Cycle-Aware — HedgeC1 ไม่เปิดเพราะ Guards เช็คแบบ Global (v5.8 → v5.9)

### สาเหตุ

Guards 2 จุดใน `CheckAndOpenHedge()` เช็คแบบ **Global** ไม่แยก Cycle → HedgeC1 ถูก block:

1. **Guard 2 (line 6097-6101):** เช็คว่ามี active hedge ทิศเดียวกัน **ทุก set** → ถ้า HedgeA1 เป็น BUY active อยู่ → HedgeC1 BUY ถูก block ทั้งที่เป็นคนละ Cycle

2. **Guard 3 (line 6104):** เช็คว่า `bestDir == g_lastHedgeExpansionDir` แบบ global → ถ้า Hedge ล่าสุด (ของ Cycle A หรือ B) เป็นทิศ BUY → Cycle C ที่ต้อง Hedge BUY เหมือนกันก็ถูก block

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Guard 2 — เปลี่ยนเป็น Cycle-Aware

```text
เดิม (line 6097-6101):
  for(int h = 0; h < MAX_HEDGE_SETS; h++)
     if(g_hedgeSets[h].active && g_hedgeSets[h].hedgeSide == hedgeSide)
        return;

ใหม่:
  for(int h = 0; h < MAX_HEDGE_SETS; h++)
     if(g_hedgeSets[h].active 
        && g_hedgeSets[h].hedgeSide == hedgeSide
        && g_hedgeSets[h].cycleIndex == g_currentCycleIndex)  // ← เช็คเฉพาะ cycle เดียวกัน
        return;
```

**ผล:** HedgeA1 BUY จะไม่ block HedgeC1 BUY เพราะ cycleIndex ต่างกัน (A=0, C=2)

#### 2. Guard 3 — เปลี่ยนเป็นเช็คเฉพาะ Hedge ใน Cycle ปัจจุบัน

```text
เดิม (line 6103-6105):
  if(g_hedgeSetCount > 0 && bestDir == g_lastHedgeExpansionDir)
     return;

ใหม่:
  // เช็คเฉพาะ hedge ใน cycle ปัจจุบัน — H2+ ต้องเปลี่ยนทิศจาก H1
  int lastDirInCycle = 0;
  for(int h = 0; h < MAX_HEDGE_SETS; h++)
     if(g_hedgeSets[h].active && g_hedgeSets[h].cycleIndex == g_currentCycleIndex)
        lastDirInCycle = (g_hedgeSets[h].hedgeSide == POSITION_TYPE_BUY) ? 1 : -1;
  
  if(lastDirInCycle != 0 && bestDir == lastDirInCycle)
     return;  // cycle นี้มี hedge ทิศนี้แล้ว → ต้องเปลี่ยนทิศก่อน (H2)
```

**ผล:** Guard 3 ดูเฉพาะ hedge ใน cycle ปัจจุบัน → HedgeC1 ไม่ถูก block โดย hedge จาก Cycle A/B

#### 3. Version bump: v5.8 → v5.9

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic, Trading Strategy Logic
- Guard 1 (hasCounterOrders) — ยังเช็คแบบ global ถูกต้องแล้ว
- Hedge Partial/Matching/Grid Close logic
- Net Lot / Unbound Counter Lots calculation
- Dashboard / Hedge Cycle Monitor
- Cycle increment logic (g_cycleHedged)

