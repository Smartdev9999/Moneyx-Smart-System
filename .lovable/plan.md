

## v6.64 — Fix Recovery TP Sync Spam: Update เฉพาะเมื่อ Basket เปลี่ยน

### วินิจฉัยปัญหาจาก Log

จาก journal log (image-934) เห็น pattern ซ้ำทุก ~2ms:
```
v6.47 ClearTP: Cleared bound order #1396 TP=4881.98->0  ← ClearBrokerTPSL ลบ TP
v6.63 RECOV TP SYNC: Gen3 #1396 TP=4881.98               ← ManageRecoveryOwnerAvgTP set กลับ
v6.47 ClearTP: ...                                       ← ลบอีก
v6.63 RECOV TP SYNC: ...                                 ← set กลับอีก
```

→ **infinite ping-pong loop** กิน CPU + spam broker + log ท่วม

### Root Cause (2 จุด)

**1. `IsTicketBound()` คืน true ผิด** — GM3 orders (#1396, #1383, #1382, #1331, #1398) hedge ปลดแล้ว แต่ ticket ยังค้างใน `g_hedgeSets[].boundTickets[]` ของ slot อื่นที่ยัง active (GM4-GM7 ใน screenshot 2 ยังมี hedge ครบ) → `ClearBrokerTPSL` มองว่ายัง bound → ลบ TP ทุก tick

**2. `ManageRecoveryOwnerAvgTP` ทำงานทุก tick โดยไม่เช็คการเปลี่ยนแปลง** — แม้ basket ไม่มีออเดอร์ใหม่ ก็ยัง re-sync ตลอด → ปะทะกับ ClearTP

### ตามที่ user ต้องการ

> "ควรจะแก้เมื่อมีออเดอร์ที่เป็น Generation เดียวกันเพิ่มขึ้นมาใหม่ ยกตัวอย่างมี GM3_GL_#8 ขึ้นมาเพิ่มถึงจะทำการคำนวณ Average TP อีกรอบ ไม่ใช่จะต้องรีเซ็ตตลอดเวลาแบบนี้"

→ เปลี่ยนจาก "sync ทุก tick" เป็น **"sync เฉพาะเมื่อ basket เปลี่ยน"** (ticket count, lot total, หรือ ticket set ต่างจากครั้งก่อน)

---

### แผนแก้ v6.64 (fix-only)

**ไฟล์**: `public/docs/mql5/Gold_Miner_EA.mq5`

#### Fix 1: `ManageRecoveryOwnerAvgTP()` — Change Detection (บรรทัด 7681-7771)

เพิ่ม static cache per-side เก็บ signature ของ basket ก่อนหน้า:
```cpp
static int    s_lastBasketCount[2]  = {0, 0};
static double s_lastBasketLots[2]   = {0.0, 0.0};
static double s_lastAvgPrice[2]     = {0.0, 0.0};
static int    s_lastGen[2]          = {-1, -1};
```

หลังคำนวณ `basketCount`, `totalLots`, `avgPrice`:
```cpp
bool basketChanged = (basketCount != s_lastBasketCount[sideI])
                  || (MathAbs(totalLots - s_lastBasketLots[sideI]) > 0.001)
                  || (gen != s_lastGen[sideI])
                  || (MathAbs(avgPrice - s_lastAvgPrice[sideI]) > _Point);

// Sync TP เฉพาะเมื่อ basket เปลี่ยน — ไม่ใช่ทุก tick
if(basketChanged) {
    for(int b = 0; b < basketCount; b++) {
        // ... PositionModify เดิม ...
    }
    s_lastBasketCount[sideI] = basketCount;
    s_lastBasketLots[sideI]  = totalLots;
    s_lastAvgPrice[sideI]    = avgPrice;
    s_lastGen[sideI]         = gen;
    Print("v6.64 RECOV TP RECALC: Gen", gen, " basket changed → ",
          basketCount, " orders @ avg=", avgPrice, " TP=", tpPrice);
}

// แต่ tpReached check ยังต้องทำทุก tick (เพื่อปิด basket)
if(!tpReached) continue;
```

→ เปิด GM3_GL#8 ใหม่ → count เปลี่ยน 5→6 → recalc + sync TP **ครั้งเดียว** → จบ

#### Fix 2: `ClearBrokerTPSL()` — Skip Recovery Owner Generation (บรรทัด 2445-2472)

เพิ่ม guard ป้องกันลบ TP ของ recovery owner gen:
```cpp
void ClearBrokerTPSL() {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      // ... existing checks ...
      if(!IsTicketBound(ticket)) continue;
      
      // v6.64: Don't clear TP of recovery owner generation orders —
      // they're managed by ManageRecoveryOwnerAvgTP, not by hedge clear logic
      if(g_sequentialRecoveryActive) {
         string c = PositionGetString(POSITION_COMMENT);
         int og = ExtractGeneration(c);
         if(og == g_sequentialRecoveryGen) continue;
         if(IsRecoverySeedTicket(ticket) && GetRecoverySeedGen(ticket) == g_sequentialRecoveryGen) continue;
      }
      // ... existing PositionModify(0,0) ...
   }
}
```

→ ตัด ping-pong ที่ root: GM3 orders จะไม่ถูก ClearTP อีกเลยขณะเป็น recovery owner

#### Fix 3: ลบ Hedge Set Reference สำหรับ Recovery Gen

เพิ่มฟังก์ชัน `UnbindRecoveryGenFromAllHedgeSets(int gen)` เรียกตอน sequential recovery เริ่ม:
- Loop `g_hedgeSets[]` → ทุก slot active → remove ticket ที่มี comment prefix = `GMx_` ของ gen นั้น ออกจาก `boundTickets[]`
- ลด `boundTicketCount` ตามจริง

→ `IsTicketBound()` คืน false ถูกต้องสำหรับ GM3 → ป้องกันปัญหาอื่น (เช่น CountNormalOrders) ในอนาคต

#### Fix 4: เพิ่ม Throttle log ใน `AuditUnTPedOwnerOrders()`

เปลี่ยนจาก print ทุก orphan → print summary 1 บรรทัด/รอบ:
```cpp
if(orphanCnt > 0)
   Print("v6.64 ORPHAN GL: Gen", gen, " has ", orphanCnt, " orders w/ TP=0 → will sync next basket change");
```

#### Fix 5: Version bump → v6.64
- `#property version "6.64"`
- `#property description` += "v6.64 — Recovery TP Sync Throttling (fix ping-pong w/ ClearBrokerTPSL)"
- Header comment + Dashboard

---

### สิ่งที่ไม่เปลี่ยนแปลง (กฎเหล็ก)

- `trade.Buy/Sell/PositionClose` — ไม่แก้
- Trading strategy / signal / grid entry — ไม่แก้
- TP/SL calculation formula — ไม่แก้ (แค่เปลี่ยน "เมื่อไหร่ sync")
- `IsHedgeCloseAllowed()` Triple Gate — ไม่แก้
- Sequential Recovery / Match-Close (v6.59-6.61) — ไม่แก้
- Hedge comment scheme v6.62 — ไม่แก้
- v6.63 fixes (FindRecoverySetIdx, SyncBrokerTPSL skip) — คงไว้
- BB / News / License / Time filter — ไม่แก้

### ผลลัพธ์ที่คาดหวัง

1. **ไม่มี log spam อีก** — GM3 basket นิ่ง → ไม่มี ClearTP/RECOV TP SYNC สลับกัน
2. **เปิด GM3_GL#8 ใหม่** → basketCount 5→6 → recalc avg + sync TP **1 ครั้ง** → log บรรทัดเดียว
3. **ปิดออเดอร์ใน basket** → count ลด → recalc + re-sync 1 ครั้ง
4. CPU/network load ลดลงมาก
5. Broker TP ของ GM3 stable ไม่ถูกลบสลับกับการตั้งใหม่
6. ราคา avg TP ยังถูกต้อง 100% สำหรับการปิด basket

