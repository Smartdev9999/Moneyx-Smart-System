

## v6.61 — Matching Close ให้ตรง Concept: Shred ทั้ง 2 ทิศ + Recovery Seed จากผลรวม

### สรุปการตรวจสอบ Logic ปัจจุบัน vs Concept ของคุณ

ผมเทียบไฟล์ `public/docs/mql5/Gold_Miner_EA.mq5` กับ concept ที่อธิบายมา พบว่า **โครง sequential queue (v6.59/v6.60) ถูกต้องแล้ว** แต่ **กลไกการปิดออเดอร์จริงยังผิดเพี้ยน 4 จุดหลัก**:

| # | Concept ของคุณ | โค้ดปัจจุบัน | สถานะ |
|---|---|---|---|
| 1 | ฝั่งที่กำไร (Buy 10 ออเดอร์) ใช้กำไรตัวเองมา **ซอยปิด Sell Hedge ทีละส่วน** จนเหลือ Hedge เล็กๆ | `ManageHedgePartialClose()` v6.55 ถูกปิดการทำงาน (`return;` ทันที) → ไม่มีการซอย hedge เลย | ❌ ผิด |
| 2 | Hedge ทำกำไร (Sell ทำกำไร) → ใช้กำไร hedge **ซอยปิด Buy ที่ขาดทุนเก่าสุดให้ได้มากที่สุด** เหลือ Buy ที่ขาดทุนน้อย → ไปต่อด้วย GL ปกติ | `ManageHedgeMatchingClose()` ปิด hedge เต็มจำนวน + **ปล่อย bound losers ทั้งหมด** เป็น recovery (ไม่ปิดเลย) | ❌ ผิด |
| 3 | หลัง shred แล้ว ส่วนที่เหลือจะถูก **ลบ comment hedge** กลายเป็น seed ของ recovery grid ใหม่ | ไม่มี logic strip comment / ไม่มี seed จาก hedge remainder | ❌ ขาด |
| 4 | Recovery grid เริ่มจาก lot ≈ **ผลรวมสะสมของ initial+GL ทั้งชุด** (เช่น 0.05+0.07+...+0.38 ≈ 1.21 → seed ≈ 0.38 ที่ใกล้ 1 ที่สุด) | `ComputeRecoveryGridLot()` ใช้ `FindMaxLotOrphan()` = **lot เดี่ยวที่ใหญ่สุด** (0.38) ซึ่งบังเอิญใกล้เคียงในตัวอย่างนี้ แต่ตรรกะไม่ตรง spec | ⚠️ ใกล้เคียงแต่ผิด |
| 5 | Sequential: ปิด GM ทั้งชุดก่อน → ค่อยทำ GM1 → GM2 | v6.59/v6.60 lock owner ตามรุ่น + นับเฉพาะ order ของรุ่นนั้น | ✅ ถูกแล้ว |
| 6 | Avg TP ของชุดที่เหลือ = ค่าเฉลี่ยถ่วงน้ำหนัก hedge_remainder + recovery_grid + bound losers ที่เหลือ → TP ห่าง 500 จุด | `ManageHedgeBoundAvgTP()` คิด avg เฉพาะ bound side ของรุ่นนั้น แต่ **ไม่รวม hedge remainder ที่ถูก strip comment** | ⚠️ ต้องขยาย |

### แผนแก้ไข `public/docs/mql5/Gold_Miner_EA.mq5` → v6.61

#### 1) Version bump → v6.61 (header / property / dashboard / log)

#### 2) เพิ่ม input parameters ใหม่ (Recovery Shred & Seed)

```cpp
input bool   InpHedge_ShredOnMatch        = true;   // Shred hedge proportionally (not full close)
input double InpHedge_ShredMinNetProfit   = 1.0;    // Min net profit ($) after shred
input double InpRecovery_SeedTargetLots   = 1.0;    // Target cumulative lots for seed selection
input bool   InpRecovery_StripHedgeComment = true;  // Strip GM_HEDGE_* comment on remainder
```

#### 3) เขียน `ManageHedgeMatchingClose()` ใหม่ (Hedge Profit Path) — Shred bound losers
แทนการ "ปล่อย bound ทั้งหมดเป็น recovery":

- คำนวณ `budget = hedgeProfit + reverseProfit - InpHedge_MatchMinProfit`
- สแกน bound ที่ขาดทุน **เก่าสุดก่อน** (มีอยู่แล้ว)
- ปิดเป็นชุดตราบที่ `cumLoss ≤ budget` (มีอยู่แล้ว) — **คงเดิม**
- **เพิ่ม:** หากปิด bound losers ได้บางส่วน แต่ยังเหลือ bound อื่น → เก็บ bound ที่เหลือเป็น recovery กลุ่มใหม่ (ไม่ใช่ปล่อยทั้งหมด)
- ปิด hedge เต็มจำนวน (เหมือนเดิม) + ตั้ง sequential owner = `boundGeneration`

#### 4) เปิดใช้ `ManageHedgePartialClose()` ใหม่ (Bound Profit Path) — Shred hedge

แทน `return;` ของ v6.55 ให้:

- คำนวณ `boundProfit = ผลรวมกำไรของ bound orders ฝั่ง counterSide ทั้งหมดของ set นี้`
- ถ้า `boundProfit > 0` และ `hedgePnL < 0`:
  - คำนวณ `hedgeLossPerLot = |hedgePnL| / hedgeLots`
  - `closeLots = (boundProfit - InpHedge_ShredMinNetProfit) / hedgeLossPerLot` (normalize ตาม lot step)
  - **ปิดบางส่วนของ hedge** ผ่าน `trade.PositionClosePartial(hedgeTicket, closeLots)`
  - ปิด **bound profit-takers เก่าสุดก่อน** จนใช้กำไรหมดตาม budget
  - อัปเดต `g_hedgeSets[idx].hedgeLots -= closeLots`
- ถ้า `closeLots ≥ hedgeLots` → ปิด hedge หมด + release bound เหลือเป็น recovery + ตั้ง owner

#### 5) Strip Comment + Re-bind เป็น Recovery Seed
เพิ่มขั้นตอนหลัง shred:

- หลัง partial close hedge ถ้า remainder lot > 0 → เปลี่ยน comment ของ hedge ticket จาก `GM_HEDGE_n` เป็น `GM[gen]_RECOV_SEED` (ใช้ `trade.PositionModify` ไม่ได้แก้ comment ตรงๆ ใน MT5 → ทำแบบ logical: เก็บใน array `g_recoverySeedTickets[]` แล้ว exclude จาก hedge accounting + include ใน orphan-recovery accounting แทน)
- ในรอบ tick ถัดไป `ScanOrphanGenerations()` จะเห็น recovery seed นี้เป็น order ของรุ่น `gen` → `ManageOrphanGrid()` ใช้เป็น seed สำหรับ GL grid

#### 6) แก้ `ComputeRecoveryGridLot()` ให้ใช้ "Cumulative Sum Seed"
ตามตัวอย่างของคุณ: 0.05+0.07+0.10+0.14+0.196+0.274+0.38 = 1.21 → seed ที่ใกล้ `InpRecovery_SeedTargetLots` (1.0) ที่สุดคือ 0.38

เพิ่ม helper:
```cpp
double FindCumulativeSeedLot(int gen, ENUM_POSITION_TYPE side, double targetLots)
{
   // sum lots ของ order ทุกตัวฝั่งนั้นของ gen นี้ (รวม recovery seed ที่ strip comment แล้ว)
   // ไล่จาก initial → GL#max หา lot ที่ทำให้ cumulative ≤ targetLots ก่อนเกิน
   // คืนค่า lot ของ level ที่ใกล้เคียงเกณฑ์
}
```

ใช้ใน `ManageOrphanGrid()` แทน `FindMaxLotOrphan()` ทั้ง 2 จุด (Buy/Sell side)

#### 7) ขยาย `ManageHedgeBoundAvgTP()` ให้รวม Recovery Seed + Recovery Grid
คำนวณ weighted avg ครอบคลุม:
- Bound losers ที่เหลือ
- Recovery seed (hedge remainder ที่ strip comment)
- Recovery grid orders (`GM[gen]_GL#`)

แล้ว TP = avg ± `InpHedge_BoundAvgTPPoints` → ปิดทุกตัวพร้อมกัน → owner clear → tick ถัดไป H2 ปลด

#### 8) Ticket Tracking Array (Anti-skip Guarantee)
เพิ่ม global:
```cpp
struct RecoverySetTracker {
   int       generation;
   ulong     tickets[];      // all tickets belonging to this recovery set (seed + bound + grid)
   int       sourceHedgeIdx; // origin H#
   bool      complete;
};
RecoverySetTracker g_recoverySets[];
```

หน้าที่: ทุก scenario ที่ปิด/ปลด hedge → push tickets ที่เกี่ยวข้องเข้า `g_recoverySets[gen]` → `IsSequentialRecoveryComplete()` ใช้ track นี้เช็คให้ตรง 100% (ไม่อิง prefix scan อย่างเดียว) → กันออเดอร์ตกหล่น/ข้ามรุ่น

#### 9) Dashboard เพิ่มบรรทัด

```text
Recovery Set | Gen0 | Seed: 0.38 | Bound: 4 | Grid: 2 | AvgTP: 1923.45
Shred Status | Hedge 2.00→0.85 lots | Saved: $87.30
Queue        | GM(active) → GM1(wait) → GM2(wait)
```

#### 10) Log เพิ่มจุดสำคัญ
- `v6.61 SHRED HEDGE: Set#1 closed 1.15/2.00 lots, kept 0.85 as recovery seed`
- `v6.61 SHRED BOUND: Set#1 closed 6/10 bound losers via hedge profit, 4 remain`
- `v6.61 RECOVERY SEED: Gen0 seed=0.38 (cum=1.21 target=1.00)`

---

### สิ่งที่ไม่เปลี่ยนแปลง (ตามกฎเหล็ก)

- `trade.Buy / trade.Sell / trade.PositionClose` core calls — ไม่แก้
- Trading Strategy (SMA/EMA/Squeeze entry) — ไม่แก้
- Hedge **trigger** logic (Expansion / DD% / Dollar) — ไม่แก้
- `IsHedgeCloseAllowed()` Triple Gate — ไม่แก้
- Sequential Owner Lock v6.59/v6.60 — **คงไว้** (กลไกถูกแล้ว)
- `IsPrevHedgedTicket()` v6.58 / BB Filter v6.56 — ไม่แก้
- News / License / Time Filter / Data Sync — ไม่แก้
- Balance Guard / Max DD% — ไม่แก้
- v6.37–v6.60 features นอกเหนือจากที่ระบุ — ไม่แก้

### ผลลัพธ์ที่คาดหวัง

1. **Buy 10 ขาดทุน + Sell Hedge กำไร** → shred Buy เก่าสุด 6-7 ตัว → เหลือ Buy 3-4 ตัวที่ขาดทุนน้อย + ปิด hedge เต็ม → recovery grid ทำต่อด้วย GL#11 ใช้ seed จาก cumulative
2. **Buy 10 กำไร + Sell Hedge ขาดทุน** → shred Sell hedge จาก 2.0 → 0.85 lots → Sell remainder strip comment → กลายเป็น recovery seed → recovery grid เปิด GL ฝั่ง Sell ต่อจาก seed
3. **Avg TP** คำนวณจากทั้งชุด (seed + bound + grid) → ปิดพร้อมกันที่ 500 จุด
4. **Sequential** ทำงาน GM ปิดหมด → GM1 → GM2 ทีละชุดแน่นอน (track ด้วย ticket array)
5. ไม่มีออเดอร์ข้ามรุ่นหรือตกหล่น เพราะมี `g_recoverySets[]` tracker

