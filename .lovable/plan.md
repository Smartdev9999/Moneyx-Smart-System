

## Fix: Hedge/Reverse เปิดทั้งที่ Expansion TFs ไปคนละทิศทาง (v6.13 → v6.14)

### ปัญหา

โค้ดปัจจุบันใน `CheckAndOpenHedge()` (line 6371-6383) และ `CheckAndOpenReverseHedge()` (line 7442-7453):

```text
expCount = 0, bestDir = 0
scan TF จากสูง→ต่ำ:
  ถ้า state == EXPANSION → expCount++, ถ้า bestDir ยังเป็น 0 ก็เอา direction ของ TF นี้
ถ้า expCount >= MinTFConfirm → เปิด Hedge/Reverse ตาม bestDir
```

**ปัญหา**: ถ้า M30 = EXPANSION SELL, M5 = EXPANSION BUY → `expCount = 2` ≥ `MinTFConfirm(2)` → ระบบเปิด Hedge SELL ตาม bestDir ของ TF ใหญ่สุด **ทั้งที่ expansion ไปคนละทาง**

### กฎที่ถูกต้อง (ตามที่คุณกำหนด)

```text
เปิด Hedge/Reverse ได้เมื่อ:
1. มี TF expansion อย่างน้อย N ตัว (MinTFConfirm)
2. TF ที่เป็น Expansion ทั้งหมดต้องไปทิศทางเดียวกัน (BUY ทั้งหมด หรือ SELL ทั้งหมด)
3. TF ที่ไม่ได้เป็น Expansion ต้องเป็น Normal หรือ Squeeze (ห้ามเป็น Expansion ฝั่งตรงข้าม)
```

ตัวอย่าง:
- M5=EXP BUY, M15=NORMAL, M30=EXP BUY → OK เปิด Hedge BUY ✓
- M5=EXP BUY, M15=EXP BUY, M30=EXP SELL → BLOCK ✗ (ขัดกัน)
- M5=EXP BUY, M15=NORMAL, M30=EXP SELL → BLOCK ✗ (ขัดกัน)

### แผนแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. สร้าง helper: `CountDirectionalExpansion()`

```cpp
// Returns expansion count + unified direction
// direction = 0 if expansions conflict (BUY+SELL mix)
int CountDirectionalExpansion(int &outDir)
{
   int expCount = 0;
   int buyExp = 0, sellExp = 0;
   outDir = 0;
   
   for(int sq = 0; sq < 3; sq++)
   {
      if(g_squeeze[sq].state == 2)  // EXPANSION
      {
         expCount++;
         if(g_squeeze[sq].direction == 1)  buyExp++;
         else if(g_squeeze[sq].direction == -1) sellExp++;
      }
   }
   
   // ถ้ามีทั้ง BUY และ SELL expansion → direction = 0 (conflict)
   if(buyExp > 0 && sellExp > 0) { outDir = 0; return expCount; }
   
   if(buyExp > 0) outDir = 1;
   else if(sellExp > 0) outDir = -1;
   
   return expCount;
}
```

#### 2. แก้ `CheckAndOpenHedge()` (line 6371-6383)

เปลี่ยนจาก scan loop เดิม → ใช้ `CountDirectionalExpansion()`:

```cpp
int bestDir = 0;
int expCount = CountDirectionalExpansion(bestDir);
if(expCount < InpHedge_MinTFConfirm || bestDir == 0) return;
// bestDir == 0 หมายถึง expansion conflict → ไม่เปิด
```

#### 3. แก้ `CheckAndOpenReverseHedge()` (line 7442-7453)

เปลี่ยนเหมือนกัน:

```cpp
int bestDir = 0;
int expCount = CountDirectionalExpansion(bestDir);
if(expCount < InpHedge_ReverseMinTFConfirm || bestDir == 0) return;
```

#### 4. แก้ Squeeze Filter block logic (line 1135-1162)

ใช้ helper เดียวกันเพื่อ directional block ก็ตรงกัน:

```cpp
int bestDir = 0;
int expCount = CountDirectionalExpansion(bestDir);
if(expCount >= InpSqueeze_MinTFExpansion && bestDir != 0) { ... }
// bestDir == 0 (conflict) → ไม่ block ทิศทางใด (เพราะไม่รู้ทิศ)
```

#### 5. Version bump: v6.13 → v6.14

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge matching close / partial close / grid recovery logic
- Reverse Hedge NET calculation / balanced lock
- Orphan Recovery system
- Squeeze state detection (BB/KC) — แค่เปลี่ยนวิธีตีความ direction

