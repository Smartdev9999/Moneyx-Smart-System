

## v6.63 — Fix Bound Order Detection หลัง Hedge Released: GL ใหม่ต้องเข้า Avg TP เสมอ

### วินิจฉัยปัญหาจริงจากภาพ (GM4)

ภาพแสดง: GM4 เคยมี hedge (GM_Hedge_D4) ปลดไปแล้ว → มี GL#5/6/7/8 เปิดใหม่ทีหลัง → **GL#6-8 ตัวใหม่ไม่มี Broker TP (T/P=0.00) แม้ว่า GM4_INIT/GL#1-4 ตัวเก่าจะมี TP=4922.07 อยู่** → ราคาเฉลี่ยถูกล็อกค้างไว้ที่ basket เดิม ไม่รวม GL ใหม่

ไล่ source code เจอ **3 บั๊กตามลำดับ** ที่ทำให้เกิดอาการนี้:

---

### บั๊ก #1 — `FindRecoverySetIdx()` คืน `-1` เสมอ (บรรทัด 7734-7737)

```cpp
int FindRecoverySetIdx(int gen) {
   return -1;   // ← ฟังก์ชันถูกตัดทิ้งกลางทาง ไม่เคย iterate g_recoverySets[]
}
```

ผลกระทบลูกโซ่:
- `RegisterRecoverySetTickets()` คิดว่า gen นี้ยังไม่มี → สร้าง entry **ใหม่ทุกครั้ง** ที่ hedge ปลด → tracker ซ้ำซ้อน
- `IsRecoverySetFlat()` → `idx<0` → คืน `true` ทันที → tracker ตัวจริงไม่ถูกตรวจ
- `ClearRecoverySetIfFlat()` no-op → flag `complete` ไม่ถูก set → sequential lock อาจค้าง

### บั๊ก #2 — `IsTicketBound()` ยัง return `true` หลัง hedge ปลด (บรรทัด 7438-7448 + 8195-8208)

ตอน hedge ของ GM4 ปลดด้วย `ManageHedgeAvgTP()` (10199-10211) หรือ `ManageHedgeMatchingClose()` shred-full (10506-10537):
- โค้ด **เซ็ต `active=false` แล้ว reset `boundTicketCount=0`** → ดูเหมือนเคลียร์
- **แต่** `IsTicketBound()` loop ผ่าน `if(!g_hedgeSets[h].active) continue;` ก่อน → ใช้ได้
- **ปัญหาจริง**: GL#5-8 ที่เปิด **ก่อน** hedge ปลด ถูก `bind` เข้า set นี้ตอน `OpenDDHedge()` แล้ว เมื่อ set ปลด → ตัวมันถูกปล่อย เป็น "recovery owner"
- เมื่อระบบเปิด **GL#6-8 ตัวใหม่หลัง hedge ปลด** ในระหว่างที่ `g_sequentialRecoveryActive=true` ของ Gen4 → **ตัวใหม่ไม่ถูก bind** (ถูกต้อง) → `IsTicketBound()=false` → ควรได้รับ Broker TP จาก `SyncBrokerTPSL`
- **แต่** `SyncBrokerTPSL` ใช้ `CalculateAveragePrice()` ที่ skip bound + hedge แล้วคำนวณ avg ของ "ทุก order ที่ไม่ bound" → **ไม่กรองตาม generation** → เมื่อมี GM5/GM6/GM7/GM8/GM9 active พร้อมกัน → คำนวณ avg ของ **ทุก gen รวมกัน** → ตั้ง TP รวมที่จุดเดียว
- อาการตามภาพ: order เก่าของ GM4 (ที่ออกก่อน hedge ปลด) ถูก set TP=4922.07 ไว้แล้ว แต่ **ไม่ถูก re-modify** เพราะ cache `g_lastBrokerTP_Sell` ตรงกับค่าเดิม หรือเพราะ `IsTicketBound()` ของตัวมันยัง true อยู่ (ตกค้างใน slot อื่น)

### บั๊ก #3 — Broker TP ไม่รู้จัก "Recovery Owner Generation" (root cause หลัก)

`SyncBrokerTPSL()` (บรรทัด 2301-2426) ออกแบบมาสำหรับ "หนึ่ง basket ต่อ side" → คำนวณ `avgBuy`/`avgSell` รวม **ทุก generation** ที่ไม่ bound

แต่ระบบ v6.62 มี **multi-generation พร้อมกัน** (GM4 recovery + GM5..GM9 active) → ทุกตัวไหลเข้า avg เดียวกัน → ผลลัพธ์:
- Order GM4 เดิมที่มี TP=4922.07 ค้างอยู่ → ไม่ถูก update เพราะเทียบกับ cache แล้วเหมือนเดิม
- **GL#6-8 ตัวใหม่ของ GM4** เพิ่งเปิดออกมา → `PositionGetDouble(POSITION_TP)=0` ≠ tpSell ที่คำนวณใหม่ → **ควร** PositionModify
- **แต่** `tpSell` ที่คำนวณคือค่าเฉลี่ย "รวม GM4..GM9 ทุก order" — ไม่ใช่ avg เฉพาะ GM4
- ที่แย่กว่า: `ManageRecoveryOwnerAvgTP()` (7659-7729) คำนวณ avg เฉพาะ owner gen ถูกต้องแล้ว → ใช้ "ปิด basket ที่ราคา avg+TP" แต่ **ไม่ได้ตั้ง Broker TP** ลงไปที่ order เลย → ถ้า EA หลุด/restart ระหว่างนั้น → order ไม่มี broker safety net

นี่คือเหตุผลที่ภาพแสดง GL ใหม่ T/P = 0.00

---

### แผนแก้ v6.63 (fix-only — ไม่แตะ trading logic)

**ไฟล์**: `public/docs/mql5/Gold_Miner_EA.mq5`

#### Fix 1: ซ่อม `FindRecoverySetIdx()` (บรรทัด 7734-7737)
```cpp
int FindRecoverySetIdx(int gen) {
   for(int i = 0; i < g_recoverySetCount; i++)
      if(g_recoverySets[i].generation == gen) return i;
   return -1;
}
```

#### Fix 2: เพิ่ม `SyncRecoveryOwnerBrokerTP()` ใน `ManageRecoveryOwnerAvgTP()` (บรรทัด 7659-7729)

หลัง loop คำนวณ avg ของ owner gen แต่ละ side — ถ้า **ยังไม่ถึง TP** → set Broker TP ลงทุก order ใน basket นั้น (รวม seed + GL ใหม่ที่เปิดทีหลัง):

```cpp
// หลัง if(!tpReached) continue; → เพิ่ม:
double tpPrice = (side == POSITION_TYPE_BUY)
   ? NormalizeDouble(avgPrice + tpDist, _Digits)
   : NormalizeDouble(avgPrice - tpDist, _Digits);
for(int b = 0; b < basketCount; b++) {
   if(!PositionSelectByTicket(basketTickets[b])) continue;
   double curTP = PositionGetDouble(POSITION_TP);
   if(NormalizeDouble(curTP, _Digits) != tpPrice)
      trade.PositionModify(basketTickets[b], PositionGetDouble(POSITION_SL), tpPrice);
}
```

→ ทุก tick ที่ recovery active → owner basket ถูก re-sync เสมอ → GL ใหม่ของ GM4 จะได้ TP=4922.x ทันทีที่เปิด

#### Fix 3: บล็อก `SyncBrokerTPSL` ไม่ให้แตะ order ของ "recovery owner generation"

ใน loop modify (บรรทัด 2378-2419) เพิ่ม guard ก่อน modify:
```cpp
// v6.63: skip orders managed by Recovery Owner — has its own avg TP path
if(g_sequentialRecoveryActive) {
   string c = PositionGetString(POSITION_COMMENT);
   int og = ExtractGeneration(c);
   if(og == g_sequentialRecoveryGen) continue;
   if(IsRecoverySeedTicket(ticket) && GetRecoverySeedGen(ticket) == g_sequentialRecoveryGen) continue;
}
```

→ ป้องกันค่า avg ปนเปื้อนระหว่าง gen / ป้องกันการเขียนทับ TP ที่ Fix 2 เพิ่งตั้ง

#### Fix 4: เพิ่ม `Detect Orphan GL` watchdog ทุกtick

เพิ่มฟังก์ชันใหม่ `AuditUnTPedOwnerOrders()` เรียกใน `OnTick()` หลัง `ManageRecoveryOwnerAvgTP()`:
- สแกนทุก order ของ owner gen ที่ `POSITION_TP == 0` และไม่ใช่ hedge/bound
- log warning + force re-sync: `Print("v6.63 ORPHAN: Gen", gen, " #", ticket, " has TP=0 → forcing avg sync")`

→ มี alarm ใน Journal ทันทีถ้า GL ใหม่หลุดออกจากระบบ → ผู้ใช้รู้ตัวก่อนเสียหาย

#### Fix 5: Dashboard เพิ่มบรรทัด `Owner Avg TP: 4922.07 | Untracked: 0`
แสดง avg ปัจจุบันของ recovery owner + จำนวน order ที่ TP=0 (ควรเป็น 0 เสมอ)

#### Fix 6: Version bump → v6.63
- `#property version "6.63"`
- `#property description` เพิ่ม "v6.63 — Recovery Owner Broker TP Sync + Orphan GL Watchdog"
- Header comment block + Dashboard

---

### สิ่งที่ไม่เปลี่ยนแปลง (กฎเหล็ก)

- `trade.Buy / Sell / PositionClose` — ไม่แก้
- Trading strategy / signal / grid entry / TP-SL calc — ไม่แก้
- `IsHedgeCloseAllowed()` Triple Gate — ไม่แก้
- Sequential Recovery v6.59/v6.60 — ไม่แก้ logic, แค่ใช้ flag
- Shred/Match/Partial close v6.61 — ไม่แก้
- Hedge comment scheme v6.62 (GM_Hedge_D{gen}) — ไม่แก้
- BB filter / News / License / Time filter — ไม่แก้
- `OpenHedge()` / `OpenDDHedge()` — ไม่แก้

### ผลลัพธ์ที่คาดหวัง

1. หลัง hedge GM4 ปลด → GM4 เป็น recovery owner → **ทุก order ของ GM4 (เก่า + GL ใหม่ + seed)** ได้รับ Broker TP เดียวกัน คำนวณจาก weighted avg ของทั้ง basket → TP รี-ซิงค์ทุก tick
2. GL#6, GL#7, GL#8 ที่เปิดใหม่จะแสดง T/P ในตาราง MT5 ทันที (ไม่ใช่ 0.00 อีก)
3. ไม่มี order หลุดจากระบบ — `AuditUnTPedOwnerOrders()` log warning ทันทีถ้าเจอ
4. Order ของ GM5..GM9 ที่ยัง active แยกการคำนวณ avg ของตัวเอง ไม่ปนกับ GM4 owner
5. EA ปิด/restart กลางทาง → broker ยังมี TP ตั้งไว้ → ไม่ขาด safety net

