

## v6.64 — Profit-Loss Netting (ซอย/หักลบ) สำหรับ Allowed Generation

### ปัญหาที่ user เจอ
Set#1 (Gen0) ปิดเรียบร้อย → allowed เลื่อนเป็น Gen1 ✓ แต่:
- ออเดอร์ Gen1 ใน screenshot มี **กำไรล้วน** (GM1_INIT +$569, GM1_GL#1 +$923, GM1_GL#2 +$2,774)
- ระบบไม่ทำอะไร — ไม่ปิดกำไรเอามาหักลบกับ loss orders ของ Gen1 (ถ้ามี) หรือ ไม่ปิด Set ทิ้งทั้งชุด
- เปิด GL grid เพิ่มอย่างเดียวจาก `ManageOrphanGrid()`

### Root Cause (จากการอ่านโค้ด v6.63)

**สาเหตุ 1 — `ManageHedgeMatchingClose()` line 9660-9661:**
```cpp
double hedgeProfit = ...;
if(hedgeProfit <= 0) return;   // ← ออกทันทีถ้า hedge ติดลบ
```
ทำให้ Set ที่ hedge ติดลบ (Set#3 SELL $-1643, Set#6 BUY $-16.50 ตาม screenshot) ไม่เคยพิจารณา bound profit pool ของชุดเลย แม้ bound side มีกำไรมหาศาล

**สาเหตุ 2 — `ManageOrphanGrid()` ไม่มี matching/netting logic:**
- ฟังก์ชันนี้ทำแค่ "เปิด GL grid เพิ่ม" ตามระยะ
- ไม่มีการสแกน profit bounds เอามาหักลบ loss bounds เพื่อ "ซอย" ปิดให้น้อยลง
- เมื่อ Gen1 เป็น orphan (Set#2 ปิดไปแล้ว) → กำไรค้างเฉยๆ ไม่ทำอะไร

**สาเหตุ 3 — Set ที่ active กับ hedge profit/loss mixed:**
ลำดับใน `ManageHedgeSets()` step 1:
1. `hedgePnL > 0` → MatchingClose
2. else → `ManageHedgeBoundAvgTP`
3. else → `ManageHedgePartialClose` (v6.55: skipped)
→ ไม่มี "bound-only netting" เมื่อ hedge ติดลบ

---

## แนวทางแก้ไข v6.64

### 1) เพิ่มฟังก์ชันใหม่ `RunBoundProfitLossNetting(int gen)` 
ฟังก์ชันสำหรับ "ซอย/หักลบ" profit-loss ภายใน generation ที่กำหนด:

```text
สำหรับ generation ที่ส่งเข้ามา:
1. รวบรวม bound orders ทั้ง Buy + Sell ของ gen นั้น
   (ทั้ง Set ที่ active + orphan group ของ gen)
2. แยกเป็น 2 กลุ่ม: profitOrders[] (PnL>0), lossOrders[] (PnL<0)
3. คำนวณ totalProfit = sum(profitOrders.PnL)
4. budget = totalProfit - InpHedge_MatchMinProfit
5. ถ้า budget <= 0 → return (ไม่มีกำไรพอ)
6. เรียง lossOrders by openTime เก่า→ใหม่ (oldest first)
7. greedy match: เลือก loss orders ที่ cumLoss + |loss| <= budget
8. ถ้าได้ matched losses อย่างน้อย 1 ตัว:
   - ปิด profitOrders ทั้งหมดที่ใช้ + matched lossOrders
   - log: "NETTING GenN: closed P profits + L losses, net $X"
9. ถ้าไม่มี loss matched และ มีแต่ profit:
   - ปิด profitOrders ทั้งหมด (lock in profit)
   - log: "NETTING GenN: profit-only close, $X locked"
```

### 2) เรียก netting ก่อน orphan grid expansion ใน `ManageOrphanGrid()`
ต้น loop หลัง gate check, ก่อน "เปิด GL grid":
```cpp
// v6.64: Try profit-loss netting first
RunBoundProfitLossNetting(gen);

// หลัง netting ตรวจซ้ำ — ถ้า flat แล้ว skip grid expansion
CountOrphanPositions(gen, bc, sc, glb, gls, mglb, mgls);
if(bc == 0 && sc == 0) {
   g_orphanGroups[g].active = false;
   g_activeOrphanGroupCount--;
   continue;
}
```

### 3) เรียก netting ใน `ManageHedgeSets()` เมื่อ hedge ติดลบ + bound มีกำไร
หลัง `IsHedgeCloseAllowed()` ผ่าน, ก่อน step 1:
```cpp
// v6.64: Even if hedge is in loss, try to net profit-loss within bound side
if(g_hedgeSets[h].boundGeneration == seqAllowedGen) {
   RunBoundProfitLossNetting(g_hedgeSets[h].boundGeneration);
   RefreshBoundTickets(h);  // refresh after netting
}
```

### 4) Dashboard เพิ่มแถวแสดงผล netting
```text
Netting GenN | Last: closed 3P+2L net $+450
Netting GenN | Pending — no profitable bounds
```

### 5) Version bump → v6.64
- `#property version` "6.64"
- header comment block
- dashboard version label
- OnInit/OnDeinit log

---

## Technical details

### ขอบเขตของ "generation gen"
Bound orders ของ gen หมายถึง position ที่ comment ผ่าน `ParseGenerationFromComment()` คืน gen ตรงกัน — ครอบคลุม:
- `GM` / `GM_INIT` → Gen0
- `GM_GL#1`, `GM_GP#1` → Gen0  
- `GM1_INIT`, `GM1_GL#2` → Gen1
- ฯลฯ

ไม่นับ hedge tickets (`GM_HEDGE_*`, `GM_HEDGE_D*`) — hedge มี logic ของตัวเอง

### ลำดับใน OnTick (ไม่เปลี่ยน)
```text
OnTick → g_seqAllowedGen = GetSequentialAllowedGeneration()
       → ManageHedgeSets()  
            ├─ (ใหม่) RunBoundProfitLossNetting(allowedGen) สำหรับ active sets ของ allowedGen
            └─ matching/avgTP/partial เดิม
       → ManageOrphanGrid()
            ├─ (ใหม่) RunBoundProfitLossNetting(gen) ก่อนเปิด GL  
            └─ orphan GL expansion เดิม
```

### Safety rules
- Netting ทำได้เฉพาะ `gen == g_seqAllowedGen` (อยู่ในคิวปลด)
- `InpHedge_UseMatchingClose = false` → skip netting (เคารพ master toggle)
- ใช้ `InpHedge_MatchMinProfit` เดียวกัน (ไม่เพิ่ม input ใหม่)
- ปิดออเดอร์ผ่าน `trade.PositionClose()` + `Sleep(50)` (pattern เดิม)
- ถ้า netting ปิด profit-only (ไม่มี loss matched) ก็ยังโอเค — เป็นการ lock profit ก่อน expansion

---

## ไฟล์ที่แก้ไข
- `public/docs/mql5/Gold_Miner_EA.mq5` → v6.64
- `.lovable/plan.md` → อัปเดตบันทึกแผน
- `mem://trading/gold-miner-ea/profit-loss-netting-v6-64.md` → memory note ใหม่

---

## สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution (`OpenOrder`, `trade.Buy`, `trade.Sell`) — ไม่แก้
- Trading Strategy / Entry signals / Grid distance / Lot calc — ไม่แก้
- License / News / Time filter / Data sync — ไม่แก้
- Triple Gate (`IsHedgeCloseAllowed`) — ไม่แก้
- Hedge open trigger — ไม่แก้
- BB Filter / Balance Guard — ไม่แก้
- Initial entry rule (v6.59) — ไม่แก้
- `GetSequentialAllowedGeneration()` v6.63 — ไม่แก้
- `ParseGenerationFromComment()` — ไม่แก้
- `ManageHedgeMatchingClose()` ของ profitable hedge (Set#1 ที่ทำงานอยู่แล้ว) — ไม่แก้
- v6.37–v6.63 features — ไม่แก้

---

## ผลลัพธ์ที่คาดหวัง
- Gen1 ใน screenshot (กำไรล้วน +$569 +$923 +$2,774) → ระบบจะ "lock profit" ปิดทั้งหมดทันทีที่ allowed เลื่อนมาถึง
- ถ้ามี loss orders ผสม → "ซอย" ปิด loss orders เก่าสุดเท่าที่ budget ครอบคลุม → ลด exposure ก่อนเปิด GL grid เพิ่ม
- Set#3 (hedge SELL $-1643) ที่มี bound profit → จะ net ภายใน bound side ก่อน (ไม่แตะ hedge)
- Set#2, Set#3, Set#4… จะตามมาเป็นลำดับเหมือน Set#1 — ทุก gen ได้รับ matching ครบ
- `InpHedge_SequentialRelease = false` → behavior เดิม 100% (netting จะไม่ทำงานเพราะ allowed = -1)

