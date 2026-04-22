

## v6.65 — Fix DD Hedge Lot Inflation: Bind/Count เฉพาะ Generation ปัจจุบันเท่านั้น

### วินิจฉัยปัญหาจากภาพ (image-936)

| Hedge | Lots | Bound orders จริงในตาราง | สัดส่วน |
|---|---|---|---|
| GM_Hedge_D5 | 0.21 | GM_INIT 0.03 | 7x เกิน |
| GM_Hedge_D6 | 0.90 | GM6_INIT+GL#1+GL#2 = 0.13 | **6.9x เกิน** |
| GM_Hedge_D7 | 1.51 | **ไม่มี GM7_*** | ∞ |
| GM_Hedge_D8 | 2.98 | GM8_INIT 0.03 | **99x เกิน** |
| GM_Hedge_D9 | 1.72 | **ไม่มี GM9_*** | ∞ |

→ Hedge เปิดขนาดมหึมาเทียบกับ bound order จริง และบางชุดไม่มี bound order ให้ป้องกันเลย

### Root Cause

ปัจจุบันใน `CountUnboundOrders()` (บรรทัด 8302) และ `OpenDDHedge()` bind loop (บรรทัด 8723):

```cpp
if(orderGen > bindGen) continue;  // v6.38: include all gens <= bindGen (orphan fix)
```

ใช้เงื่อนไข **`<= bindGen`** → DD trigger ของ Gen 6 จะ scoop:
- Orders Gen 6 ปัจจุบัน (ที่ตั้งใจจะ hedge)
- **+ orphan orders จาก Gen 0,1,2,3,4,5** ที่ยังลอยอยู่ (ถูก match-close บางส่วน, hedge เคยปลดไปแล้ว, แต่ไม่ได้อยู่ใน `prevHedgedTickets` แล้วเพราะ ClearPrevHedgedTickets ทำงานเมื่อ flat)

ผลลัพธ์:
1. `counterLots` รวมทุก gen → hedge ใหญ่เกินจริงมาก (เช่น GM8_Hedge_D8 = 2.98 lots ทั้งที่ Gen 8 มีแค่ 0.03)
2. orphan orders ของ gen เก่าถูก bind เข้า hedge set ใหม่ → comment `GM_Hedge_D8` ผูก orders ที่จริงๆเป็น GM3, GM4, GM5 → ผิดความหมาย v6.62
3. กรณี Gen 7, Gen 9 ไม่มี new order → hedge bind orphan ทั้งหมด → ดูเหมือน "hedge ลอย"

นี่คือผลข้างเคียงของ v6.38 "orphan generation recovery" ที่ขัดกับ v6.62 "comment ผูก gen" — รุ่น hedge ควรปกป้องเฉพาะ orders ของ generation ตัวเองเท่านั้น

### แผนแก้ v6.65 (fix-only, ไม่แตะ trade execution)

**ไฟล์**: `public/docs/mql5/Gold_Miner_EA.mq5`

#### Fix 1: `CountUnboundOrders()` — Strict Generation Match (บรรทัด 8302-8329)

```cpp
if(genFilter >= 0)
{
   int orderGen = ExtractGeneration(comment);
   // v6.65: STRICT match — only orders of EXACT generation
   // (เดิม v6.38: <= genFilter → ดูด orphan เก่า → hedge inflated)
   if(orderGen != genFilter) continue;
}
```

#### Fix 2: `OpenDDHedge()` bind loop — Strict Generation (บรรทัด 8709-8729)

```cpp
int orderGen = ExtractGeneration(cmt);
if(orderGen != bindGen) continue;  // v6.65: bind ONLY current gen orders
```

#### Fix 3: `CheckAndOpenHedgeByDD()` loss aggregator (บรรทัด 8568-8570)

```cpp
int orderGen = ExtractGeneration(cmt);
if(orderGen != curGen) continue;  // v6.65: คำนวณ DD เฉพาะ gen ปัจจุบัน
```

#### Fix 4: เพิ่ม Orphan Sanity Check ก่อน open DD hedge

ก่อน `OpenDDHedge()` ในบรรทัด 8590, 8601, 8618, 8629 เพิ่ม guard:
```cpp
double curLots = 0, curPL = 0;
int curCount = CountUnboundOrders(POSITION_TYPE_BUY, curLots, curPL, curGen);
if(curCount == 0 || curLots <= 0)
{
   Print("v6.65 DD HEDGE SKIP: Gen", curGen, " BUY has no current-gen orders to hedge");
   return; // ไม่เปิด hedge ถ้าไม่มี order ของ gen ปัจจุบันให้ป้องกัน
}
```

→ ป้องกันกรณี GM7_Hedge_D7 / GM9_Hedge_D9 (ไม่มี order ของ gen นั้นเลย)

#### Fix 5: Audit Watchdog — `AuditHedgeSetIntegrity()` (ใหม่)

ฟังก์ชันใหม่เรียกใน OnTick ทุก ~30 วินาที:
- Loop `g_hedgeSets[]` ที่ active
- คำนวณ `boundLotsActual` (จาก boundTickets ที่ยังมีอยู่จริง) เทียบกับ `hedgeLots`
- ถ้า `hedgeLots > boundLotsActual * 2.0` (อย่างน้อย 2 เท่า) → log warning:
  ```
  v6.65 HEDGE INTEGRITY WARN: set#X gen=Y hedgeLots=Z >> boundLots=W (2x+)
  ```
- ถ้า `boundTicketCount == 0` และ hedge ยังเปิดอยู่ → log critical warning + (ไม่ปิดออเดอร์อัตโนมัติ — ต้องให้ user ตัดสินใจ)
- Throttle: 1 บรรทัด/set/รอบ (ไม่สแปม)

#### Fix 6: Dashboard เพิ่มแถว "Hedge Integrity"
- Green: ทุก set healthy
- Yellow: มี set ที่ inflated (>2x)
- Red: มี set ที่ no bound orders เลย

#### Fix 7: Version bump → v6.65
- `#property version "6.65"`
- `#property description` += "v6.65 — DD Hedge Strict Generation Bind (fix lot inflation)"
- Header comment + Dashboard

---

### สิ่งที่ไม่เปลี่ยนแปลง (กฎเหล็ก)

- `trade.Buy/Sell/PositionClose` — ไม่แก้
- Trading strategy / signal / grid entry — ไม่แก้
- TP/SL formula — ไม่แก้
- `IsHedgeCloseAllowed()` Triple Gate — ไม่แก้
- Sequential Recovery / Match-Close — ไม่แก้
- v6.62 Hedge comment scheme — ไม่แก้ (ที่จริง fix นี้ทำให้ v6.62 ทำงานถูกต้องตามดีไซน์)
- v6.63/v6.64 Recovery TP sync — ไม่แก้
- BB / News / License / Time filter — ไม่แก้

### ผลลัพธ์ที่คาดหวัง

1. **DD hedge ลอตจะ = sum(lots ของ orders Gen X เท่านั้น)** เช่น Gen 8 มี GM8_INIT 0.03 → hedge = 0.03 (ไม่ใช่ 2.98)
2. **Gen 7, Gen 9 ที่ไม่มี new order → DD hedge จะไม่เปิด** (Fix 4 guard)
3. Orphan orders จาก gen เก่าจัดการโดย `Sequential Recovery` / `Orphan Generation Recovery` (v6.3) ตามดีไซน์เดิม — **ไม่ถูก hedge ปนเปื้อนอีก**
4. Dashboard แสดง integrity status ของทุก hedge set
5. Watchdog log เตือนทันทีถ้า hedge มี mismatch
6. แก้ปัญหาเดิมที่ภาพแสดง: hedge ใหญ่เกินจริง 6-99 เท่า

### ความเสี่ยงและ Mitigation

- **Risk**: v6.38 ใส่ `<= genFilter` เพื่อจัดการ orphan — การถอด อาจทำให้ orphan gen เก่าไม่ได้รับ hedge protection
- **Mitigation**: orphan ของ gen เก่าควรเข้า `Sequential Recovery System` (v6.59) หรือ `Orphan Generation Recovery` (v6.3) อยู่แล้ว — ไม่ใช่หน้าที่ DD hedge ของ gen ใหม่ และ Match-Close pool (v6.61) ก็ pool ทั้งสองข้างอยู่แล้ว
- ถ้าหลัง deploy พบ orphan ค้างนาน → จะเสนอเพิ่ม "Orphan DD Hedge แยกชุด" ใน v6.66 (per-gen DD trigger)

