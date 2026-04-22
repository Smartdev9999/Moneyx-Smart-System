

## v6.65 — Netting ทำงานก่อน Triple Gate + Orphan Grid ต่อเนื่องในแท่งเดียว

### ปัญหาที่ user เจอกับ Set#2 (จาก screenshot)

จาก image-930: Gen1 มีแต่ออเดอร์กำไรล้วน
- `GM1_INIT` +347.85
- `GM1_GL#1` +612.43
- `GM1_GL#2` +2,330.10

แต่ `GM_HEDGE_2` (Set#2) ติดลบหนัก -7,058 → -9,179

**ที่ user ต้องการ:** ระบบควรปิดออเดอร์กำไรของ GM1 ทั้ง 3 ตัว (lock $3,290) แล้วเอามา "ซอย" GM_HEDGE_2 ให้เล็กลง + ออก GL grid ต่อเนื่องเพื่อ recover Set#2

**ที่เกิดจริง:** ระบบไม่ปิดอะไรเลย, GL grid ของ Gen1 ออกแค่ตัวเดียว (`GM1_GL#1`) แล้วหยุด

### Root Cause (อ่านโค้ด v6.64)

**บั๊ก #1 — Netting ติด Triple Gate (line 9153-9170):**
```cpp
if(!IsHedgeCloseAllowed(h))
{
   g_hedgeSets[h].matchingDone = false;
   continue;   // ← ออกทันที — netting ที่อยู่บรรทัด 9162 ไม่ได้รัน
}
// v6.64 netting อยู่ตรงนี้ (line 9162)
RunBoundProfitLossNetting(...);
```
Triple Gate (`IsHedgeCloseAllowed`) ใช้สำหรับการ "ปิด hedge" — ต้องรอ Expansion cycle / Price Zone / TP Distance ครบ
แต่ **netting ไม่แตะ hedge เลย** (skip `GM_HEDGE_*` ที่ line 8742) — มันแค่ปิด bound profit/loss ภายใน gen
→ การเอา netting ไปไว้หลัง gate ทำให้ Set#2 ที่รอ gate อยู่ ไม่เคย lock $3,290 ทิ้งทั้งที่ทำได้ปลอดภัย

**บั๊ก #2 — Netting ใน ManageOrphanGrid ไม่ครอบคลุม Set ที่ active:**
- `ManageOrphanGrid()` วน `g_orphanGroups[]` เท่านั้น
- Gen1 ของ Set#2 ยัง active (มี hedge เปิดอยู่) → ไม่ใช่ orphan → loop ข้าม
- Profit-only lock เลยไม่เคยทำงาน

**บั๊ก #3 — `g_lastOrphanGridCandleTime` บล็อก grid layer ถัดไป (line 8881, 8970, 9019):**
```cpp
if(barTime == g_lastOrphanGridCandleTime) return;   // line 8881
...
g_lastOrphanGridCandleTime = iTime(...);            // line 8970/9019 ตั้งหลังเปิด GL
```
หลังเปิด `GM1_GL#1` ในแท่งนั้น → `g_lastOrphanGridCandleTime` = แท่งปัจจุบัน → tick ต่อไปในแท่งเดียวกัน → return ทันที
ถึงแม้ราคาจะเลื่อนไปไกลพอเปิด `GL#2` ได้ก็ต้องรอแท่งใหม่
**กระทบเฉพาะ orphan grid (ไม่ใช่ active set ที่ใช้ ManageHedgeGridMode)**
→ หลัง Set#1 ปิดและ Set#2 ยังไม่เข้า grid mode, การ recover Gen1 ผ่าน orphan path จะออก GL ได้แค่ 1 ตัว/แท่ง

---

## แนวทางแก้ v6.65

### 1) ย้าย Netting มาก่อน Triple Gate ใน `ManageHedgeSets()`
ย้ายบล็อก `RunBoundProfitLossNetting` (line 9162-9170) ขึ้นมา **ก่อน** `if(!IsHedgeCloseAllowed(h))` (line 9153)

เหตุผล:
- Netting ปิดเฉพาะ bound (skip hedge ตาม line 8742) → ไม่ละเมิดเจตนาของ Triple Gate
- ทำให้ Set#2 lock profit GM1 ได้ทันทีโดยไม่ต้องรอ Expansion cycle
- ถ้า profit-only lock ปิด GM1 หมด → Set#2 จะ "ว่าง bound" → matching close ในอนาคตก็ปลอดภัยขึ้น

### 2) เพิ่ม per-tick netting fallback สำหรับทุก active set ของ allowed gen
เพิ่มลูปเล็กๆ ที่ต้น `ManageHedgeSets()` (หลัง `seqAllowedGen` คำนวณ) ที่เรียก `RunBoundProfitLossNetting(seqAllowedGen)` **1 ครั้ง/tick** โดยไม่ขึ้นกับ set ใด — เพื่อให้ Gen1 ที่กระจายอยู่ใน Set#2 + orphan group ถูก scan รวมกัน

หมายเหตุ: `RunBoundProfitLossNetting` scan ทั้ง `PositionsTotal()` อยู่แล้ว ไม่ต้องแยก scope per-set

### 3) ปลดบล็อก one-grid-per-candle เฉพาะ orphan grid
เปลี่ยนเงื่อนไข line 8881:
```cpp
if(GridLoss_OnlyNewCandle)
{
   datetime barTime = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(barTime == g_lastOrphanGridCandleTime) return;
}
```
ให้ใช้ตัวแปร per-(gen,side) แทนตัวแปร global เดียว, หรือเปลี่ยน logic ให้บล็อกเฉพาะเมื่อยังไม่มีการเลื่อนราคาเพิ่มจาก grid ตัวล่าสุด

วิธีที่ปลอดภัยที่สุด: **ลบเช็ค global `g_lastOrphanGridCandleTime`** ออก เพราะ:
- ภายในลูปมีเช็ค `currentPrice <= lastPrice - distance*point` (line 8952) ซึ่งเป็น distance gate ที่ถูกต้องอยู่แล้ว
- ฟังก์ชันยังถูก gate ด้วย `MaxOpenOrders` + `GridLoss_MaxTrades`
- การลบออกทำให้แท่งเดียวเปิดได้หลาย level ถ้าราคาเลื่อนไกลพอ — ตรงตามที่ user ต้องการ ("ออกต่อเนื่อง")

ถ้าต้องการเก็บ `OnlyNewCandle` semantics ไว้สำหรับ "grid ตัวแรก" → เก็บไว้แต่ track ด้วย `lastTime` (มีอยู่แล้วใน `FindLastOrphanOrder`) เปรียบเทียบกับแท่งปัจจุบันแทน

### 4) Dashboard เพิ่ม indicator
แสดง "Netting last tick: GenN scanned" เพื่อ debug ว่า netting ทำงานทุก tick

### 5) Version bump v6.64 → v6.65
- `#property version`
- `#property description`
- header comment
- dashboard label

---

## Technical details

### Order ของการทำงานหลังแก้
```text
OnTick:
1. g_seqAllowedGen = GetSequentialAllowedGeneration()
2. ManageHedgeSets():
   a. RunBoundProfitLossNetting(seqAllowedGen)   ← ใหม่: per-tick, ก่อนลูป set
   b. for each active set:
      - RefreshBoundTickets
      - seqFreeze gate (เดิม)
      - hedge exists check
      - RunBoundProfitLossNetting(boundGen)       ← ย้ายขึ้นมาก่อน Triple Gate
      - RefreshBoundTickets
      - if(!IsHedgeCloseAllowed) continue          ← Triple Gate (เดิม)
      - matching/avgTP/grid (เดิม)
3. ManageOrphanGrid():
   - per-orphan-group:
     - RunBoundProfitLossNetting(gen) (เดิม v6.64)
     - GL expansion (ลบ global candle gate)
```

### พฤติกรรมที่คาดหวัง
**Set#2 (Gen1, hedge ติดลบ -7,058):**
- Tick 1: netting → pCnt=3 lCnt=0 → profit-only lock → ปิด GM1_INIT/GL#1/GL#2 → +$3,290
- Set#2 boundTicketCount → 0
- Triple Gate ผ่าน เมื่อไหร่: matching close (เหลือแค่ hedge → ใช้ partial/avgTP/grid mode)
- ราคาเลื่อนไป → ออก orphan GL ของ Gen1 ต่อเนื่องในแท่งเดียวได้หลาย level

**Set#1 (เดิม) ไม่กระทบ** — เพราะ Set#1 ปิดไปแล้ว และ logic เดิมยังครอบคลุมเคสที่ hedge profitable

**Sequential Release = false** → behavior เดิม 100% (netting skip ที่ line 8724)

---

## ไฟล์ที่แก้ไข
- `public/docs/mql5/Gold_Miner_EA.mq5` → v6.65
- `.lovable/plan.md` → อัปเดตบันทึก
- `mem://trading/gold-miner-ea/netting-pregate-orphan-continuous-v6-65.md` → memory note ใหม่
- `mem://index.md` → เพิ่มอ้างอิง

---

## สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution (`OpenOrder`, `trade.Buy/Sell/PositionClose`) — ไม่แก้
- Trading Strategy / Entry signals / Grid distance / Lot calc — ไม่แก้
- License / News / Time filter / Data sync — ไม่แก้
- `IsHedgeCloseAllowed()` Triple Gate logic — ไม่แก้ (แค่ย้ายตำแหน่งเรียก)
- `RunBoundProfitLossNetting()` core algorithm — ไม่แก้ (แค่ย้ายตำแหน่งเรียกใน ManageHedgeSets)
- Hedge open trigger — ไม่แก้
- BB Filter / Balance Guard — ไม่แก้
- Sequential gate v6.63 (`GetSequentialAllowedGeneration`, `ParseGenerationFromComment`) — ไม่แก้
- Initial entry rule v6.59 — ไม่แก้
- `ManageHedgeMatchingClose` / `ManageHedgeBoundAvgTP` / `ManageHedgePartialClose` — ไม่แก้
- v6.37–v6.64 features — ไม่แก้

---

## ผลลัพธ์ที่คาดหวัง
1. หลัง Set#1 ปิด → Gen1 (Set#2 bound) ถูก lock profit ทันที (~$3,290) แม้ Triple Gate ของ Set#2 ยังไม่ผ่าน
2. Orphan GL grid ของ Gen1 ขยาย level ต่อเนื่องในแท่งเดียวได้ตามระยะราคา → "ซอย" GM_HEDGE_2 ได้จริง
3. Set#3, Set#4… ใช้กลไกเดียวกันเมื่อ allowed เลื่อนถึงคิวตัวเอง
4. ไม่กระทบ Set#1 ที่ทำงานถูกต้องอยู่แล้ว
5. `InpHedge_SequentialRelease = false` → behavior เดิม 100%

