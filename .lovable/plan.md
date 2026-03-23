

## เพิ่ม Comment Generation System แยก Bound Orders จาก New Cycle — Gold Miner SQ EA (v5.8 → v5.9)

### วิเคราะห์ปัญหา

จากรูป: เมื่อ Hedge ถูกปิดบางส่วน → bound orders บางตัวยังค้างอยู่ (GM_GL#7, GM_GL#8, GM_GL#9) → ระบบเปิด cycle ใหม่ → ออก GM_INIT, GM_GL#1, GM_GL#2... comment เหมือนกัน → `RecoverHedgeSets()` ไม่สามารถแยกได้ว่า order ไหนเป็นของเก่า (bound) หรือของใหม่ (independent) → bind ผิด order หรือทิ้ง order ตกหล่น

### แนวคิด: Comment Generation Prefix

เพิ่ม global counter `g_cycleGeneration` เมื่อ hedge เปิด → generation++ → order ชุดใหม่ใช้ prefix ต่างจากชุดเก่า:

```text
Generation 0 (ก่อน hedge): GM_INIT, GM_GL#1, GM_GL#2...
Generation 1 (หลัง hedge): GM1_INIT, GM1_GL#1, GM1_GL#2...
Generation 2 (ถ้า hedge อีกรอบ): GM2_INIT, GM2_GL#1, GM2_GL#2...
```

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. เพิ่ม Global Variables
```cpp
int g_cycleGeneration = 0;  // incremented each time a hedge opens
```

#### 2. เพิ่ม Helper Function `GetCommentPrefix()`
```cpp
string GetCommentPrefix()
{
   if(g_cycleGeneration == 0) return "GM";
   return "GM" + IntegerToString(g_cycleGeneration);
}
```
- Gen 0 → `"GM"` (เหมือนเดิม: GM_INIT, GM_GL#1)
- Gen 1 → `"GM1"` (GM1_INIT, GM1_GL#1)
- Gen 2 → `"GM2"` (GM2_INIT, GM2_GL#1)

#### 3. แก้ทุกจุดที่สร้าง Comment ให้ใช้ `GetCommentPrefix()`

| จุด | เดิม | ใหม่ |
|---|---|---|
| Entry (line 1157, 1178, 1263, 1277) | `"GM_INIT"` | `GetCommentPrefix() + "_INIT"` |
| Grid Loss (line 2225) | `"GM_GL#" + N` | `GetCommentPrefix() + "_GL#" + N` |
| Grid Profit (line ~2270) | `"GM_GP#" + N` | `GetCommentPrefix() + "_GP#" + N` |

#### 4. แก้ `CountPositions()` ให้รู้จัก comment ทุก generation

เปลี่ยนจาก `StringFind(comment, "GM_INIT")` เป็นเช็คว่า comment match pattern `GM*_INIT`:
```cpp
// Match any generation: GM_INIT, GM1_INIT, GM2_INIT...
if(StringFind(comment, "_INIT") >= 0 && StringFind(comment, "GM") == 0) hasInitialBuy = true;
if(StringFind(comment, "_GL") >= 0 && StringFind(comment, "GM") == 0) gridLossBuy++;
if(StringFind(comment, "_GP") >= 0 && StringFind(comment, "GM") == 0) gridProfitBuy++;
```

เช่นเดียวกับ `FindMaxLotOnSide()`, `FindLastOrder()` calls ที่ filter by comment

#### 5. แก้ `CheckAndOpenHedge()` — increment generation เมื่อ hedge เปิด

```cpp
// After hedge opened successfully (line ~6097):
g_cycleGeneration++;
Print("CYCLE GENERATION incremented to ", g_cycleGeneration, " — new orders use prefix: ", GetCommentPrefix());
```

#### 6. แก้ `RecoverHedgeSets()` — bind เฉพาะ order ที่ generation เก่ากว่า

ตอน rebind (line 6171-6193): เช็ค comment ของ order → ถ้าเป็น generation ปัจจุบัน (GetCommentPrefix) → ไม่ bind (เป็น new cycle) → bind เฉพาะ generation เก่า

```cpp
// Step 2: Rebind — only bind orders from OLDER generations
string currentPrefix = GetCommentPrefix();  // e.g. "GM1"
...
string cmt = PositionGetString(POSITION_COMMENT);
// Skip current generation orders — they are new independent cycle
if(StringFind(cmt, currentPrefix + "_") == 0) continue;
// Bind older generation orders
```

#### 7. เก็บ `g_cycleGeneration` ไว้ใน HedgeSet เพื่อ recovery

เพิ่มใน struct `HedgeSet`:
```cpp
int boundGeneration;  // generation at time of binding
```

ตอน `CheckAndOpenHedge()`: `g_hedgeSets[slot].boundGeneration = g_cycleGeneration - 1;` (ชุดที่ถูก bind เป็น gen ก่อนหน้า)

ตอน `RecoverHedgeSets()`: คำนวณ generation จาก comment ของ positions ที่มีอยู่ (หา max generation number)

#### 8. Version bump: v5.8 → v5.9

### Flow สรุป

```text
เริ่มต้น: g_cycleGeneration = 0
  → Orders: GM_INIT, GM_GL#1, GM_GL#2... (10 orders sell)

Hedge เปิด: g_cycleGeneration = 1
  → Bound orders: GM_INIT, GM_GL#1..#9 (gen 0, ถูก bind)
  → New cycle orders: GM1_INIT, GM1_GL#1, GM1_GL#2... (gen 1)

Hedge ปิดบางส่วน:
  → Bound orders เหลือ: GM_GL#7, GM_GL#8, GM_GL#9 (gen 0)
  → New cycle orders: GM1_INIT, GM1_GL#1... (gen 1)
  → ระบบแยกได้ชัดเจน — ไม่ bind ผิด order

RecoverHedgeSets():
  → สแกน comment → GM_GL = gen 0, GM1_GL = gen 1
  → Bind เฉพาะ gen 0 orders → gen 1 เป็น independent cycle
```

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge system logic ทั้งหมด (Matching/Partial/AvgTP/Grid)
- Squeeze filter logic

