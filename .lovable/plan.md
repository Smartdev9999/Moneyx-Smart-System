

## v6.61 — Fix H2 Matching Close: Pool All Profits (Both Sides) Before Releasing to Recovery

### ปัญหาที่เจอจริง (จาก image-883)

H2 มีออเดอร์ใน Set:
- Loss BUY: `GM2_INIT (-63.50)`, `GM2_GL#1 (-69.09)`
- Loss SELL: `GM2_INIT sell (-115.35)`
- **Profit BUY: `GM2_GL#2 (+35.50)`, `GM2_GL#3 (+58.66)`** ← bound recovery orders ที่กลายเป็น +

อาการ: ระบบปิดเฉพาะตัวที่ติดลบ + ปลด hedge แล้วทิ้งตัว + ค้างไว้ → ผิด concept

### Root Cause

ใน `ManageHedgeMatchingClose()` (line 9851–9995):

1. **Line 9856** → `if(hedgeProfit <= 0) return;` — ถ้า hedge ตัวหลักไม่กำไร จะไม่เข้า matching เลย
2. **Line 9891** → `if((POSITION_TYPE) != counterSide) continue;` — กรองเฉพาะ "ฝั่งตรงข้าม hedge" → ออเดอร์ฝั่ง trend ที่เป็น + ไม่ถูกนับเป็น "budget"
3. **Line 9894** → `if(pnl >= 0) continue;` — ตัด profit bound orders ทิ้งทั้งหมด → ไม่เอามาช่วย matching
4. **Line 9933 lossUsed > 0 path** → ปิด hedge อย่างเดียว แล้ว "release" ทุก bound order (ทั้ง + และ -) ไปเป็น recovery — ทำให้ตัว + ลอยค้าง

ผลลัพธ์: ตัว + ฝั่ง bound (เช่น `GM2_GL#2 +35.50`) ไม่เคยถูกใช้เป็น budget และไม่เคยถูกปิด → เหลือลอย

### Concept ที่ User ต้องการ

> "คำนวณออเดอร์ที่บวกและลบ หลังจากนั้นซอยออเดอร์เพื่อปิดให้ได้มากที่สุด แล้วที่เหลือเราจะเพิ่ม Grid recovery ช่วยปิด"

แปลว่า: **Pool ทุกกำไรของ set (hedge + reverse + bound profit ทั้ง 2 ฝั่ง)** เป็น budget → จับคู่ปิด losses ให้ได้มากที่สุด → ที่เหลือค่อยปล่อยเป็น recovery

---

## แผนแก้ไข — `public/docs/mql5/Gold_Miner_EA.mq5`

### 1) Version bump → v6.61
อัปเดต `#property version`, `#property description`, header comment, init log, dashboard label

### 2) แก้ `ManageHedgeMatchingClose()` — Pool Profit Both Sides

แทนที่ logic เดิมด้วย **3 phases**:

**Phase A: รวม Profit Pool (budget)**
- `hedgeProfit` (ของ hedge ticket หลัก) — เก็บไว้แม้ ≤ 0 (จะไม่บวกถ้าติดลบ)
- `reverseProfit` (เฉพาะ reverse hedge ที่ + ) — เหมือนเดิม
- **เพิ่มใหม่**: scan `boundTickets[]` ทั้ง 2 ฝั่ง → เก็บตัวที่ `pnl > 0` เข้า array `boundProfitTickets[]` + `boundProfitValues[]` → รวมเป็น `boundProfit`
- `totalBudgetProfit = max(hedgeProfit,0) + reverseProfit + boundProfit`
- เปลี่ยน guard line 9856 จาก `if(hedgeProfit <= 0) return;` → ตรวจ `if(totalBudgetProfit <= InpHedge_MatchMinProfit) return;` (เลื่อนมาตรวจหลังคำนวณ pool)

**Phase B: รวม Loss Pool (เป้าหมายปิด)**
- scan `boundTickets[]` ทั้ง 2 ฝั่ง (ลบ filter `counterSide`) → เก็บตัวที่ `pnl < 0` เข้า `lossTickets[]` พร้อม `lossValues[]`, `lossTimes[]`
- Sort by **loss magnitude descending** (ปิดตัวที่ขาดทุนมากที่สุดก่อน) — เปลี่ยนจาก oldest first เพราะให้ลด DD จริงเร็วที่สุด
  - หมายเหตุ: ถ้าต้องการคง oldest-first ก็ได้ — แต่จากที่ user ต้องการ "ปิดให้ได้มากที่สุด" → magnitude desc เหมาะกว่า เพราะ greedy fit ดีกว่า

**Phase C: Greedy Match + Execute**
- Loop loss → ถ้า `cumLoss + |loss| ≤ budget` → เพิ่มเข้า close list
- ถ้า `lossUsed > 0`:
  1. ปิด hedge ticket (ถ้า `hedgeProfit > 0`)
  2. ปิด **boundProfitTickets ทั้งหมดที่ใช้เป็น budget** ← **จุดที่แก้สำคัญ**
  3. ปิด **profitableReverseTickets ทั้งหมด**
  4. ปิด **loss bound orders ที่อยู่ใน close list** (ตัว -)
  5. **อัปเดต `boundTickets[]`** → ลบ ticket ที่ปิดไปออก ไม่ clear ทั้ง array
  6. ถ้า `boundTicketCount == 0` หลังลบ → deactivate set + `SetSequentialRecoveryOwner` (ถ้ายังมีบาง gen ค้างใน account)
  7. ถ้ายังมี bound เหลือ (กรณีปิดบางตัว) → **คง set active** ต่อไป → recovery grid จะมาช่วยปิดที่เหลือใน tick ถัดไป
- ถ้า `lossUsed == 0` (no matchable losses) → คง path เดิม: ปิด hedge + release bound ทั้งหมด + claim owner

### 3) เพิ่ม helper `RemoveBoundTicket(int idx, ulong ticket)`

ลบ ticket ออกจาก `g_hedgeSets[idx].boundTickets[]` และลด `boundTicketCount` — สำหรับใช้ใน Phase C ข้อ 5

### 4) Logging v6.61

```cpp
Print("v6.61 MATCH POOL Set#", idx+1,
      ": hedge=$", hedgeProfit,
      " + revProfit=$", reverseProfit,
      " + boundProfit=$", boundProfit,
      " = budget=$", totalBudgetProfit,
      " | losses available=", lossCount,
      " | will close ", lossUsed, " losses ($", cumLoss, ")",
      " | net=$", finalNet);

Print("v6.61 MATCH PARTIAL Set#", idx+1,
      ": closed ", closedProfitCount, " profit + ", closedLossCount, " loss",
      " | bound remaining=", g_hedgeSets[idx].boundTicketCount,
      " (set still ACTIVE — recovery grid continues)");
```

### 5) Dashboard เพิ่ม budget breakdown (เฉพาะ owner set)

```text
Hedge Recovery | LOCKED | Owner Gen2 (Src H2) | 2 order(s) left
Match Pool     | H:+$50 R:+$0 B:+$94 = $144 budget | Losses: -$248
```

### 6) ผลลัพธ์ที่คาดหวังกับ scenario H2 ใน image-883

Budget pool = `0 (hedge ปิดแล้ว) + 0 (no reverse) + 35.50 + 58.66 = $94.16`
Loss pool = `-63.50 + -69.09 + -115.35 = -$247.94`

Greedy fit:
- ปิด `GM2_GL#1 (-69.09)` ก่อน (loss ใหญ่สุดที่ ≤ $94.16) → cum=$69.09
- ปิด `GM2_INIT BUY (-63.50)`? → 69.09+63.50=132.59 > 94.16 → ข้าม
- ลอง next smallest? → ก็ยังไม่พอ

ดังนั้นจะปิด 1 loss + 2 profit (94.16-69.09 = +$25 net) → set ยังมี `GM2_INIT BUY (-63.50)` + `GM2_INIT SELL (-115.35)` เหลือ → set ยัง active → **recovery grid ทำงานต่อ** ค่อยปิดที่เหลือ → ตรงตาม concept user

---

## สิ่งที่ไม่เปลี่ยนแปลง

- Order Execution (`trade.PositionClose`) — ใช้เดิม
- Trading Strategy / Signal / Initial Grid logic — ไม่แก้
- `ManageHedgeBoundAvgTP()` — ไม่แก้ (path AvgTP ไม่ปิดออเดอร์ลอยอยู่แล้ว → release เป็น recovery ตามเดิม)
- `ManageHedgePartialClose()` — ไม่แก้
- Hedge trigger / Triple Gate / DD threshold — ไม่แก้
- Sequential Recovery Owner v6.59-v6.60 — คงทั้งหมด (set ที่ยัง active จะไม่ claim owner — claim เฉพาะตอน boundCount==0)
- Re-hedge Guard v6.58 / BB Filter v6.56 / Recovery Grid v6.57 — ไม่แก้
- Balance Guard / News / License / Time Filter — ไม่แก้
- v6.37–v6.60 features — ไม่แก้

## Validation Checklist

1. H2 ใน image-883: ต้องปิด `GM2_GL#2 (+35.50)` + `GM2_GL#3 (+58.66)` + `GM2_GL#1 (-69.09)` ทั้ง 3 ตัวพร้อมกัน
2. Set H2 ต้อง **ยัง active** (เหลือ -63.50 + -115.35) → recovery grid ออกเพิ่ม
3. Sequential owner ยังไม่ claim จนกว่า boundCount==0
4. ถ้าไม่มี bound profit เลย (เคสปกติ) → behavior เหมือน v6.60

