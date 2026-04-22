
## v6.68 — Generation-Locked Hedge Comments (`GM_HEDGE_<gen+1>`) + MaxActive Cap on Concurrent Sets

### ปัญหา (จาก image-902 + image-903)

หลัง Set#1 (`GM_HEDGE_1`) + Set#2 (`GM_HEDGE_2`) ปิด hedge หลักไปแล้ว แต่ยังมีไม้ค้าง:
- `GM_HEDGE_2` (ตั๋ว 1617, +60) และ `GM_HEDGE_3` (ตั๋ว 1849, +233) ยังลอยอยู่จาก gen เก่า
- เกิด generation ใหม่ `GM4_INIT/GL`, `GM5_INIT/GL` แล้วถูก hedge อีกรอบ
- **ระบบใช้ slot ตาม `FindFreeHedgeSlot()` ที่อิง index ใน array** → comment ใหม่ทับซ้อนกับ `GM_HEDGE_2/GM_HEDGE_3` ที่ยังลอย → matching/binding สับสน → set ใหม่ไม่ปิดแม้ผ่านเงื่อนไข
- Dashboard image-903 แสดง Hedge#2 และ Hedge#3 ที่ลอยตัวเล็กน้อย แต่ชุดใหม่ที่เพิ่งเปิดไม่ถูกจัดการต่อ

### ความต้องการของ user
1. **ผูก hedge ↔ generation แบบตายตัว**: `GM_HEDGE_1↔GM (gen0)`, `GM_HEDGE_2↔GM1`, `GM_HEDGE_3↔GM2`, ...
2. คง `InpHedge_MaxSets` (เช่น 2) ทำหน้าที่ cap **จำนวน hedge sets ที่ active พร้อมกัน** เท่านั้น
3. หาก hedge เก่ายังเคลียร์ไม่หมด แต่ generation เดินไปข้างหน้าแล้ว — ระบบ **ออก hedge สำหรับ gen ใหม่ต่อได้** โดยใช้ comment ตรงกับ gen นั้น (`GM_HEDGE_<gen+1>`) ไม่เอา id เก่ามา reuse

---

## แผนแก้ไข — `public/docs/mql5/Gold_Miner_EA.mq5`

### 1) Version bump → v6.68
อัปเดต `#property version`, `#property description`, header comment, init/deinit log, Dashboard label

### 2) เปลี่ยน Slot Allocation: Generation-Locked

แทน `FindFreeHedgeSlot()` ทั้งฟังก์ชันให้คืน slot ที่ **map 1:1 กับ generation ที่กำลังจะ bind**

```cpp
// v6.68: Generation-locked slot — slot index === bound generation
//        comment === "GM_HEDGE_" + (boundGen + 1)
int FindGenerationHedgeSlot(int bindGen)
{
   if(bindGen < 0 || bindGen >= MAX_HEDGE_SETS) return -1;
   if(g_hedgeSets[bindGen].active)
   {
      // Already a hedge for this generation → block; never overwrite
      Print("v6.68 SLOT: gen=", bindGen, " already has active GM_HEDGE_",
            bindGen + 1, " — skip new hedge for same gen");
      return -1;
   }
   return bindGen;
}
```

จุดเรียก:
- `CheckAndOpenHedge()` (Expansion trigger)
- `CheckAndOpenHedgeByDD()` (DD% trigger)
- `CheckAndOpenHedgeByDollar()` (ถ้ามี)

ทุกจุดส่ง `g_cycleGeneration` (gen ของไม้ที่กำลังจะ bind) เข้าไป → `comment = "GM_HEDGE_" + (slot+1) = "GM_HEDGE_" + (gen+1)`

### 3) MaxActive Cap = จำกัด "active พร้อมกัน" ไม่กระทบ slot id

`activeSetCount` (logic เดิมใน `CheckAndOpenHedge`/`...ByDD`) ยังคงใช้:
```cpp
if(activeSetCount >= InpHedge_MaxSets) { return; }
```
หมายความว่า MaxSets = 2 → มี hedge active ได้สูงสุด 2 ชุดในเวลาใดเวลาหนึ่ง แต่เลข comment ผูกกับ gen เสมอ (เช่น `GM_HEDGE_5` + `GM_HEDGE_6` ก็ได้ ถ้า gen4/gen5 active อยู่)

### 4) Recovery จาก Open Positions

แก้ `RecoverHedgeSetsFromOpenPositions()`:
- Parse ตัวเลขจาก `GM_HEDGE_<N>` → `slot = N - 1` (ไม่ใช่ first-free)
- Bind hedge และ counter-side orders ให้กับ slot นั้นโดยตรง
- ตั้ง `g_hedgeSets[slot].boundGeneration = slot` (สอดคล้อง mapping ใหม่)
- ถ้า slot ซ้ำ (กรณี edge): ใช้ตัวเก่าก่อน + log warning

### 5) Update GlobalVariable Persistence
- `GME_HEDGE_TICKET_<slot>`, `GME_HEDGE_SHRED_<slot>` ใช้ slot ใหม่ (= gen) — backward-compatible เพราะ slot ยังเป็น int
- v6.66 reverse-walk seed / combined-TP / max-grid cap — ไม่แก้ logic ทำงานต่อด้วย slot ใหม่

### 6) Guard ป้องกัน hedge ซ้ำต่อ generation
ถ้า `g_hedgeSets[g_cycleGeneration].active == true` → skip การเปิด hedge รอบใหม่ของ gen นี้ (มีอยู่แล้ว) — log throttled

### 7) Dashboard / Logging
```text
Hedge #5  | BUY 0.05L PnL:+60.25 (Gen4=GM4_*)
Hedge #6  | SELL 0.12L PnL:+233.16 (Gen5=GM5_*)
v6.68 SLOT ASSIGN: gen=4 → slot=4 (comment=GM_HEDGE_5) [active:2/2]
v6.68 GEN-LOCK SKIP: gen=4 already hedged as GM_HEDGE_5
```

### 8) Migration หมายเหตุ
- EA ที่ restart พร้อม hedge เก่า (`GM_HEDGE_1`, `GM_HEDGE_2`) ที่ slot index 0,1 จะยัง map ตรงกับ gen 0, gen 1 (เพราะค่าเดิมก็ใช้ gen ตรง slot บ่อยๆ)
- Edge case: hedge เก่า comment `GM_HEDGE_3` แต่ boundGeneration บันทึกเป็น 2 (gen2) — ใหม่ถือว่าตรงกัน (comment N ↔ gen N-1)

---

## สิ่งที่ไม่เปลี่ยนแปลง

- Order Execution (`OrderSend` / `trade.Buy/Sell/PositionClose/PositionClosePartial`) — ไม่แก้
- Trading Strategy / Signal / Initial Grid / Grid Loss / Grid Profit (basket หลัก) — ไม่แก้
- Hedge open trigger (Expansion / DD% / Dollar) เงื่อนไข — ไม่แก้
- Triple Gate exit (Cycle/Zone/Distance) — ไม่แก้
- Reverse-Walk Seed v6.66 / Combined Avg TP / One-Time Shred / MaxGridTrades cap — ไม่แก้
- Unified Recovery params v6.67 (ใช้ GridLoss_InitLot + factor) — ไม่แก้
- Strict Sequential Matching v6.65 (one matcher per tick) — ไม่แก้
- Sequential Recovery Owner v6.59-v6.60 — ไม่แก้
- BB Filter / candle confirm / Re-hedge guard / Hedge Side Pause — ไม่แก้
- Accumulate Close / Balance Guard / News / License / Time Filter — ไม่แก้
- `InpHedge_MaxSets` input — ความหมายคงเดิม (จำนวน active สูงสุดพร้อมกัน) เพียงแยกออกจาก slot id

## Validation Checklist

1. `MaxActive=2`, gen0 hedged → `GM_HEDGE_1`; gen1 hedged → `GM_HEDGE_2`; gen2 trigger → block (active=2/2)
2. `GM_HEDGE_1` ปิดสมบูรณ์ → activeCount=1 → gen2 trigger → ออก `GM_HEDGE_3` (ไม่ reuse `GM_HEDGE_1`)
3. ขณะที่ `GM_HEDGE_2`, `GM_HEDGE_3` ลอยกำไรเล็กน้อย และเกิด `GM4_INIT/GL` ค้าง → ระบบออก `GM_HEDGE_5` (gen4) ได้เมื่อ active < MaxSets
4. ห้ามมี 2 hedge sets ใช้ comment เดียวกันพร้อมกัน
5. ไม่มี hedge ใหม่ผูก gen ที่มี active hedge อยู่แล้ว
6. Restart EA พร้อมหลาย `GM_HEDGE_N` lurk → recover เข้า slot = N-1 ตรงทุกตัว, boundGeneration ตรงกัน
7. v6.66 features (combined TP, shred lock, max grid cap) ทำงานบน slot ใหม่โดยไม่ regression
8. Dashboard แสดง `Hedge #N` ตรงกับ generation ของไม้ที่ผูก
