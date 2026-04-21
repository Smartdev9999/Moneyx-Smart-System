

## v6.62 — Strict In-Set Pooling: ลบ Cross-Set, ใช้กำไรเฉพาะใน Set เดียวกัน + ใช้ Hedge/Reverse เป็น Budget ได้แม้ฝั่งสลับ

### ความเข้าใจที่ถูกต้องจาก user (ครั้งนี้ยืนยันชัด)

> "ไม่เอาออเดอร์นอกกรุ๊ปมาเกี่ยวข้อง ยกเว้น Accumulate Close
> Hedge Set#1 ↔ GM0 เท่านั้น
> Hedge Set#2 ↔ GM1 เท่านั้น
> ใช้กำไรในกลุ่มไม่ว่าจะเป็น **bound order หรือ hedge order** มาซอยปิด loss ในกลุ่มเดียวกัน
> เคส: Hedge=SELL, Bound=BUY → ราคาเด้งขึ้น → bound BUY กำไร, hedge SELL ขาดทุน → ใช้กำไร bound BUY ปิด loss → เหลือเท่าไรค่อยส่งต่อ recovery grid"

### สิ่งที่ v6.61 ยังผิด

1. ใช้ `MathMax(hedgeProfit, 0)` → ถ้า hedge ขาดทุน → ไม่นับเข้า budget เลย → แต่ user ต้องการให้ **hedge ก็คือสมาชิกของ set** ที่ถูกพิจารณาเป็น "loss ที่ต้องปิด" หรือ "profit ที่ใช้เป็น budget" ตามสภาพจริงของมัน
2. Trigger gate เดิม `if(hedgeProfit > 0)` block ทุกอย่างถ้า hedge ติดลบ → ทำให้ scenario "hedge SELL ติด, bound BUY บวก" ไม่เคยเข้า matching
3. แผน v6.62 รอบก่อน (cross-set) → **ผิด concept** → ยกเลิก

### v6.61 ที่ทำถูกแล้ว (คงไว้)

- Pool bound profit ทั้ง 2 ฝั่งใน set เดียวกัน ✓
- Greedy fit by loss magnitude ✓
- Partial close + คง set active + recovery grid ทำงานต่อ ✓
- `RemoveBoundTicket()` surgical removal ✓
- Sequential Recovery Owner ไม่ claim จนกว่า boundCount=0 ✓

---

## แผนแก้ไข — `public/docs/mql5/Gold_Miner_EA.mq5`

### 1) Version bump → v6.62
อัปเดต `#property version`, `#property description`, header, init/deinit log, dashboard label

### 2) ปรับ Phase A ใน `ManageHedgeMatchingClose(idx)` — ปฏิบัติต่อ hedge/reverse เหมือน bound

แทนที่ logic แยกประเภท (hedge/reverse/bound) ด้วยมุมมองรวม **"position pool ของ set นี้"**:

**สมาชิกของ set:**
- `hedgeTicket` (hedge หลัก)
- `reverseTickets[]` (reverse hedges)
- `boundTickets[]` (orders ที่ผูกกับ generation นี้)

**Phase A: คัด Profit Pool ภายใน set**
- Loop ทั้ง 3 กลุ่ม → ตัวที่ `pnl > 0` → เก็บเข้า `setProfitTickets[]` + `setProfitValues[]`
- รวมเป็น `totalBudgetProfit`
- **ไม่มี** `MathMax(.., 0)` แยก — ทุกตัวที่บวกถูกเก็บ; ทุกตัวที่ลบไปอยู่ Phase B

**Phase B: คัด Loss Pool ภายใน set**
- Loop ทั้ง 3 กลุ่ม → ตัวที่ `pnl < 0` → เก็บเข้า `setLossTickets[]` + `setLossValues[]`
- Sort by `|loss|` descending (ปิดตัวขาดทุนใหญ่สุดก่อน — greedy ดีสุด)
- **รวม hedge ที่ติดลบเป็น loss candidate** ด้วย → ถ้า budget พอจะปิด hedge ก็ปิดได้
- **รวม bound ที่ติดลบ** ด้วย (เคสปกติ)

**Phase C: Greedy Match + Execute**
- กติกาเดิม: `cumLoss + |loss| ≤ budget` → เพิ่มเข้า close list
- ปิด `setProfitTickets[]` ทั้งหมดที่ใช้เป็น budget
- ปิด `setLossTickets[]` ที่อยู่ใน close list
- หลังปิด:
  - ถ้า hedge ticket ถูกปิด → mark `g_hedgeSets[idx].hedgeActive = false`, `hedgeTicket = 0`
  - ถ้า reverse ticket ถูกปิด → ลบจาก `reverseTickets[]`
  - ถ้า bound ticket ถูกปิด → `RemoveBoundTicket(idx, ticket)`
- เช็ค set fully flat: `hedgeTicket==0 && reverseCount==0 && boundCount==0` → deactivate + claim sequential owner (ถ้า conditions ของ v6.59-v6.60 ผ่าน)
- ถ้ายังเหลือออเดอร์ → set ยัง active → recovery grid ทำงานต่อใน tick ถัดไป

### 3) แก้ Trigger Gate ใน `ManageHedgeSets()` (รอบ matching)

**เดิม:** `if(hedgePnL > 0) ManageHedgeMatchingClose(h);`

**ใหม่ v6.62:**
```cpp
// v6.62: Enter matching if ANY profit exists in set (hedge OR bound OR reverse)
double setProfitProbe = ProbeSetProfit(h);  // quick scan: any single + position?
if(setProfitProbe > InpHedge_MatchMinProfit)
{
   ManageHedgeMatchingClose(h);
   if(g_hedgeSets[h].active)
      g_hedgeSets[h].matchingDone = true;
   continue;
}
```

เพิ่ม helper `ProbeSetProfit(int idx)` → return รวมกำไรจาก hedge+reverse+bound เฉพาะ set นี้ (positive contributions only) — เร็วกว่าเรียก full matching

### 4) ลบ logic cross-set ที่ proposed รอบก่อน

- ไม่เพิ่ม `InpHedge_CrossSetProfitPool`
- ไม่เพิ่ม `CollectExternalProfitPool()`
- ไม่แตะ orphan generations จาก set อื่น
- **Strict isolation:** Set#1 แตะเฉพาะ GM0 / Set#2 แตะเฉพาะ GM1

### 5) Sequential Recovery Owner — ไม่เปลี่ยน

- v6.59-v6.60 logic คงเดิม 100%
- Set ที่ partial close → ยัง active → ยังไม่ claim owner
- Set ที่ flat สมบูรณ์ → claim owner (ถ้ายังมี released orders ของ gen นั้นค้างใน account)
- Block release ของ set อื่นจนกว่า owner gen จะ flat

### 6) Logging v6.62

```cpp
Print("v6.62 IN-SET POOL Set#", idx+1, " Gen", boundGen,
      ": profit pool=$", DoubleToString(totalBudgetProfit,2),
      " from ", profitCount, " positions (hedge/reverse/bound)",
      " | losses=", lossCount, " ($", DoubleToString(lossSum,2), ")");
Print("v6.62 IN-SET CLOSE Set#", idx+1,
      ": closed ", closedProfitCount, "+ ", closedLossCount, "-",
      " | net=$", DoubleToString(netClosed,2),
      " | remaining: hedge=", (hedgeTicket>0?"Y":"N"),
      " rev=", reverseCount, " bound=", boundCount);
```

### 7) Dashboard

```text
Set#2 Gen1 | Hedge:SELL -$45 | Bound BUY:+$94 SELL:-$180
Match Pool | Profit=$94 (in-set) | Losses=$225 | will close $87 of losses
```

---

## ตัวอย่างจริง (scenario user อธิบาย)

Set#2 (GM1):
- Hedge SELL: -$50 (ราคาเด้งขึ้น)
- Bound BUY GM1_INIT: +$70
- Bound BUY GM1_GL#1: +$30
- Bound SELL GM1_INIT: -$25

Phase A profit pool: $70 + $30 = **$100** (ไม่นับ hedge เพราะติดลบ)
Phase B loss pool sorted: -$50 (hedge), -$25 (bound SELL)

Greedy:
- ปิด hedge -$50? cum=$50 ≤ $100 ✓
- ปิด bound SELL -$25? cum=$75 ≤ $100 ✓
- → ปิดทั้ง 2 loss + ทั้ง 2 profit
- net = +$25
- Set#2 → flat → deactivate → claim Gen1 owner ถ้า GM1 ยังมี released orders ค้าง

ถ้า budget ไม่พอ (เช่น profit $30 vs loss $80) → ปิด bound SELL -$25 (ใช้ $25 จาก $30) → set ยังเหลือ hedge -$50 + bound BUY +$5 → recovery grid ออกเพิ่มใน tick ถัดไป

---

## สิ่งที่ไม่เปลี่ยนแปลง

- Order Execution (`trade.PositionClose`) — ใช้เดิม
- Trading Strategy / Signal / Initial Grid / Grid Loss / Grid Profit — ไม่แก้
- `ManageHedgeBoundAvgTP()` / `ManageHedgePartialClose()` — ไม่แก้
- Hedge open trigger / Triple Gate / DD threshold — ไม่แก้
- Reverse hedge trigger logic — ไม่แก้ (แตะเฉพาะการ "ปิด" reverse เมื่อใช้เป็น budget/loss)
- Sequential Recovery Owner v6.59-v6.60 — ไม่เปลี่ยน
- Re-hedge guard v6.58 / BB Filter v6.56 / Recovery Grid v6.57 — ไม่แก้
- Accumulate Close (basket close) — ไม่แก้ — ยังเป็นกลไกเดียวที่ข้าม set ได้ตามที่ user ระบุ
- Balance Guard / News / License / Time Filter — ไม่แก้
- v6.37–v6.61 features — ไม่แก้

## Validation Checklist

1. ปิด Accumulate Close → set#1 (GM0) แก้ออเดอร์ตัวเองอย่างเดียว ไม่ยุ่ง GM1
2. set#2 (GM1) แก้ออเดอร์ตัวเองอย่างเดียว ไม่ยุ่ง GM0
3. Scenario hedge SELL ติดลบ + bound BUY กำไร → matching เข้าทำงาน, ใช้ bound BUY ปิด hedge
4. Scenario hedge BUY กำไร + bound SELL ติดลบ → matching เข้าทำงาน, ใช้ hedge ปิด bound (เคส v6.61 เดิม)
5. Partial close → set ยัง active → recovery grid ออกเพิ่ม
6. Full flat → claim sequential owner (ถ้ามี orphan ของ gen นั้น)
7. ไม่มี cross-set leak: log ต้องไม่แสดง ticket ของ Gen อื่นถูกปิดจาก matching ของ set นี้

