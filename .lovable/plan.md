

## v6.15 — Hedge Close Gate: Expansion Cycle + Price Zone + TP Distance (ปรับจาก plan เดิม)

### เงื่อนไขการปิด Hedge Set (ต้องผ่านครบทั้ง 3 ข้อ)

```text
Gate 1: Expansion Cycle (เหมือนเดิม)
  Case A: Hedge ตอน Expansion → รอ Normal
  Case B: Hedge ตอน Normal/Squeeze → รอ Expansion TF ใหญ่ 1 รอบ → กลับ Normal

Gate 2: Price Zone Exit (เหมือนเดิม)
  ราคาต้องออกจากกรอบ (oldest bound order ↔ hedge order)

Gate 3: TP Distance (ใหม่ — เพิ่มเติมจาก plan เดิม)
  หลังราคาออกจากกรอบแล้ว ต้องห่างขั้นต่ำ N points:
  - ถ้าราคาไปทาง Hedge order → ห่างจาก Hedge order ≥ InpHedge_CloseMinPoints
  - ถ้าราคาไปทาง Bound order → ห่างจาก oldest bound order ≥ InpHedge_CloseMinPoints
  → ฝั่งที่ราคาวิ่งไปจะเป็นฝั่งที่กำไร → ห่างพอให้ matching close คุ้ม

ถ้าไม่ผ่านครบ 3 ข้อ → ระบบไม่ทำอะไรเลย (ไม่ matching, ไม่ grid)
```

### ตัวอย่างสถานการณ์

```text
Oldest bound BUY @ 2340.00 | Hedge SELL @ 2350.00
Zone = 2340 - 2350 | InpHedge_CloseMinPoints = 300 (30 pips)

Case 1: Bid = 2345 → IN ZONE → ❌ ไม่ปิด
Case 2: Bid = 2352 → OUT ZONE ทาง hedge → แต่ห่าง hedge แค่ 20 pts → ❌ ไม่ปิด
Case 3: Bid = 2355 → OUT ZONE ทาง hedge → ห่าง 500 pts ≥ 300 → ✅ matching close ได้
Case 4: Bid = 2335 → OUT ZONE ทาง bound → ห่าง bound 500 pts ≥ 300 → ✅ matching close ได้
```

### แผนแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. เพิ่ม Input Parameter

```cpp
input int InpHedge_CloseMinPoints = 300; // Min points from zone edge before matching close
```

#### 2. เพิ่ม Fields ใน HedgeSet struct

```cpp
bool     seenExpansionSinceHedge;
bool     hedgedDuringExpansion;
double   zoneUpperPrice;   // max(oldest bound price, hedge price)
double   zoneLowerPrice;   // min(oldest bound price, hedge price)
double   hedgeOpenPrice;   // ราคาเปิดของ hedge order
double   oldestBoundPrice; // ราคาเปิดของ bound order เก่าสุด
```

#### 3. บันทึกสถานะตอนเปิด Hedge — `CheckAndOpenHedge()`

หลังเปิด hedge สำเร็จ:
- Set `hedgedDuringExpansion` / `seenExpansionSinceHedge` ตาม TF ใหญ่
- คำนวณ `zoneUpperPrice`, `zoneLowerPrice`, `hedgeOpenPrice`, `oldestBoundPrice`

#### 4. สร้าง `IsHedgeCloseAllowed(int h)` — รวม 3 gates

```text
bool IsHedgeCloseAllowed(int h)
{
   // Gate 1: Expansion Cycle
   if(!hedgedDuringExpansion && !seenExpansionSinceHedge) return false;
   if(!IsAllSqueezeTFNormalStrict()) return false;

   // Gate 2: Price Zone
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(bid > zoneLowerPrice && bid < zoneUpperPrice) return false;

   // Gate 3: TP Distance — ราคาออกจากกรอบแล้ว ต้องห่างพอ
   double pts = _Point;
   if(bid >= zoneUpperPrice) {
      // ราคาไปทาง hedge (ถ้า hedge อยู่บน) หรือ bound (ถ้า bound อยู่บน)
      double edgePrice = zoneUpperPrice;
      if((bid - edgePrice) / pts < InpHedge_CloseMinPoints) return false;
   } else {
      double edgePrice = zoneLowerPrice;
      if((edgePrice - bid) / pts < InpHedge_CloseMinPoints) return false;
   }

   return true;
}
```

#### 5. Track Expansion ทุก Tick ใน `ManageHedgeSets()`

```text
if(!g_hedgeSets[h].seenExpansionSinceHedge)
   if(g_squeeze[2].state == 2)
      g_hedgeSets[h].seenExpansionSinceHedge = true;
```

#### 6. แก้ `ManageHedgeSets()` Flow

```text
for each active hedge set h:
  1. RefreshBoundTickets
  2. Track expansion
  3. if(!IsHedgeCloseAllowed(h)) → continue (ไม่ matching, ไม่ grid)
  4. ผ่านแล้ว → matching cycle → grid entry
```

#### 7. ปิด Reverse Hedge ทั้งระบบ (ตาม plan เดิม)

#### 8. Recovery OnInit — recover zone prices + expansion flags จาก order data

#### 9. Dashboard — แสดง "Cycle/Zone/Distance" status per set

#### 10. Version bump: v6.14 → v6.15

### สิ่งที่ไม่เปลี่ยนแปลง

- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Matching Close logic ภายใน (`ManageHedgeMatchingClose`) — เพียงเพิ่ม gate ก่อนเรียก
- Grid Mode logic (`ManageHedgeGridMode`) — เพียงเพิ่ม gate ก่อนรัน
- Accumulate Close — ทำงานรวมเหมือนเดิม ไม่สน gate
- Orphan Recovery — ไม่แก้
- Squeeze state detection (BB/KC) — ไม่แก้

