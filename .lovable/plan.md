## แผนแก้ Hero Order v6.97 — Activation Gate ใช้ Side Total (ไม่ใช่ per-gen)

### Root cause (ยืนยันจาก code v6.96 บรรทัด 2280-2351)

**ปัจจุบัน activation gate เช็ค `n < MinActivate` ภายใน gen เดียว** (line 2326)

```cpp
for(int gen = 0; gen <= maxGen; gen++)         // loop ต่อ generation
   for each side:
      n = count of orders ใน "gen นี้" + "side นี้"
      if(n < MinActivate) continue;            // ★ บั๊ก: เช็คภายใน gen
      tag N newest as Hero
```

ในภาพของคุณ: BUY มี active 22 ออเดอร์ — แต่อาจกระจายข้าม gen เช่น
- gen=0 BUY = 5 ออเดอร์ (ค้างจาก hedge cycle เก่า)
- gen=1 BUY = 17 ออเดอร์ (cycle ใหม่)
- รวม **active BUY = 22** (เกิน 20 จริง) แต่แต่ละ gen < 20 → ไม่ tag Hero

หรือแม้ทั้ง 22 ตัวอยู่ gen=1 แต่ถ้าโดน hedge bind แค่บางส่วน, ตัวที่ bound ถูก skip ใน build → จำนวนนับใน gen นั้นต่ำกว่า 20

**สเปกของคุณ:** "20 = active orders ที่ยังเปิดอยู่ของฝั่งนั้น" → ต้อง**นับรวมทุก gen** ของ side นั้น

---

### สิ่งที่ "ถูกอยู่แล้ว" (ห้ามแตะ)

จากที่คุณยืนยันรอบนี้:
- ✅ **Single-side exclusive lock** (`g_heroLockedSide`) — ทำงานถูก ไม่ต้องลบ
- ✅ ฝั่งที่ถึงเกณฑ์ก่อน → lock ได้ → ทำ Hero → ฝั่งตรงข้ามเป็นตัวปิด Hero
- ✅ Lock ปลดเมื่อ Hero side flat สมบูรณ์
- ✅ State machine NONE → ARMED → BE_GUARD
- ✅ Lock-profit BE-SL formula (SELL=open-offset, BUY=open+offset)
- ✅ Opposite-basket close hook ใน `CloseGenSide` / `CloseAllSide`

---

### สิ่งที่จะแก้ (เปลี่ยน "เพียง" activation gate)

#### 1. Rewrite `BuildHeroTicketCache` — นับ side total ก่อน, แล้ว tag N newest ข้าม gen

```cpp
void BuildHeroTicketCache()
{
   if(!InpHero_Enabled || InpHero_OrderCount <= 0) { g_heroTicketCount = 0; return; }
   if(g_heroLastBuildTime == TimeCurrent() && g_heroTicketCount > 0) return;
   g_heroLastBuildTime = TimeCurrent();
   g_heroTicketCount = 0;

   int sideHeroTagged[2] = {0, 0};
   int sideTotalActive[2] = {0, 0};

   // Pass 1: รวบรวม active basket orders ของแต่ละ side ทั้งหมด (ข้าม gen)
   for(int s = 0; s < 2; s++) {
      ENUM_POSITION_TYPE side = (s == 0) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
      ulong tk[200]; datetime tt[200]; int n = 0;

      for(int i = PositionsTotal() - 1; i >= 0 && n < 200; i--) {
         ulong ticket = PositionGetTicket(i);
         if(ticket == 0) continue;
         if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
         if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
         if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != side) continue;
         string c = PositionGetString(POSITION_COMMENT);
         if(IsHedgeComment(c)) continue;
         if(IsTicketBound(ticket)) continue;            // bound = ผูกกับ hedge แล้ว ไม่นับ
         if(StringFind(c,"_INIT")<0 && StringFind(c,"_GL")<0 && StringFind(c,"_GP")<0) continue;
         tk[n] = ticket;
         tt[n] = (datetime)PositionGetInteger(POSITION_TIME);
         n++;
      }
      sideTotalActive[s] = n;

      // sort desc by POSITION_TIME (newest แรก)
      for(int a = 1; a < n; a++)
         for(int b = a; b > 0 && tt[b] > tt[b-1]; b--)
         { datetime _t=tt[b]; tt[b]=tt[b-1]; tt[b-1]=_t;
           ulong _k=tk[b]; tk[b]=tk[b-1]; tk[b-1]=_k; }

      // Activation gate ใหม่: นับ "side total" ไม่ใช่ per-gen
      int activateThreshold = (InpHero_MinOrdersToActivate > 0)
                              ? InpHero_MinOrdersToActivate
                              : (InpHero_OrderCount + 1);
      if(n < activateThreshold) continue;

      // Single-side lock เดิม (เก็บไว้ตามสเปก)
      int sideId = (int)side;
      if(g_heroLockedSide == -1) {
         g_heroLockedSide = sideId;
         Print("v6.97 Hero LOCK acquired: side=", EnumToString(side),
               " activeTotal=", n, " threshold=", activateThreshold);
      }
      if(g_heroLockedSide != sideId) continue;

      // BE_GUARD: freeze ชุด Hero เดิม (basket อาจ = 0 แล้ว)
      int curPhase = (sideId == POSITION_TYPE_BUY) ? g_heroPhase_Buy : g_heroPhase_Sell;
      int take = MathMin(InpHero_OrderCount, n - 1); // basket alive: เหลือ ≥1 non-Hero
      if(curPhase == 3 /*BE_GUARD*/)
         take = MathMin(InpHero_OrderCount, n);

      if(take <= 0) continue;
      for(int k = 0; k < take && g_heroTicketCount < 200; k++)
         g_heroTickets[g_heroTicketCount++] = tk[k];
      sideHeroTagged[s] += take;
   }

   // Phase update — เหมือนเดิม
   if(g_heroPhase_Buy != 3)  g_heroPhase_Buy  = (sideHeroTagged[0] > 0) ? 2 : 0;
   if(g_heroPhase_Sell != 3) g_heroPhase_Sell = (sideHeroTagged[1] > 0) ? 2 : 0;

   // Audit log: log "side total" ให้คุณเห็นชัดทุก 30s
   static datetime lastAudit = 0;
   if(TimeCurrent() - lastAudit >= 30) {
      Print("v6.97 Hero AUDIT: BUY active=", sideTotalActive[0],
            " hero=", sideHeroTagged[0],
            " | SELL active=", sideTotalActive[1],
            " hero=", sideHeroTagged[1],
            " | threshold=", (InpHero_MinOrdersToActivate > 0 ? InpHero_MinOrdersToActivate : InpHero_OrderCount+1),
            " lock=", (g_heroLockedSide == POSITION_TYPE_BUY ? "BUY" : g_heroLockedSide == POSITION_TYPE_SELL ? "SELL" : "NONE"));
      lastAudit = TimeCurrent();
   }
}
```

**สิ่งที่เปลี่ยนเทียบกับ v6.96:**
- ✂️ ลบ outer `for(gen)` loop
- ✂️ ลบ filter `if(ExtractGeneration(c) != gen)` — รวมทุก gen ของ side
- ✅ คงทุกอย่างอื่นไว้: single-side lock, take = min(N, total-1), BE_GUARD freeze, sort by POSITION_TIME desc
- ➕ Audit log ทุก 30s บอก side total active ของทั้ง 2 ฝั่ง + threshold + lock state

#### 2. ไม่แตะส่วนอื่นเลย

`DetectSameSideBasketClearedForHero`, `CloseOppositeHeroOnBasketClose`, `ApplyHeroLockProfitSL`, `ResetHeroStateIfFlat`, `ManageHeroOppositeClose`, hooks ใน `CloseGenSide`/`CloseAllSide`, `SyncBrokerTPSL` skip Hero — **คงเดิมทั้งหมด**

#### 3. Version bump → v6.97

อัปเดตทุกจุด: `#property version "6.97"`, `#property description`, OnInit log, dashboard "Gold Miner EA v6.97"

---

### ตัวอย่าง flow ตามภาพคุณ

`InpHero_MinOrdersToActivate=20`, `InpHero_OrderCount=3`

```text
T1: ราคาดิ่ง → BUY ปั๊ม grid 22 active orders (อาจกระจาย gen=0 = 5, gen=1 = 17)
    v6.96: gen=0 n=5 < 20 skip; gen=1 n=17 < 20 skip → ไม่มี Hero ★ บั๊ก
    v6.97: side BUY total = 22 >= 20 → tag 3 newest BUY เป็น Hero ✅
           Print "v6.97 Hero LOCK acquired: side=POSITION_TYPE_BUY activeTotal=22 threshold=20"

T2: BUY phase=ARMED → strip TP/SL บน 3 newest BUY ทันที (ผ่าน StripBrokerTPSLFromHeroTickets เดิม)

T3: ราคาเด้งกลับขึ้น → BUY basket (19 non-Hero) ชน Avg TP → broker ปิด 19 ตัว
    BUY Hero 3 ตัว TP=0 SL=0 → ไม่ปิด รอด ✅

T4: ManageHeroOppositeClose ตรวจพบ BUY basket=0, BUY Hero=3 → BUY phase=BE_GUARD
    ApplyHeroLockProfitSL(BUY): SL = open + 50pt (เหนือ open)

T5: ราคาขึ้นต่อ → SELL เริ่มเปิด grid (ฝั่งตรงข้าม) → SELL basket ชน Avg TP → ปิด
    Hook CloseOppositeHeroOnBasketClose(SELL) → ปิด BUY Hero ทั้ง 3 ทันที ✅
    BUY Hero ทำกำไรก้อนใหญ่ (ราคาวิ่งขึ้นไกลจาก open)

T6: BUY/SELL flat → unlock g_heroLockedSide
```

---

### สิ่งที่ไม่เปลี่ยน (กฎเหล็ก)

- ❌ OrderSend / trade.Buy/Sell/PositionClose execution
- ❌ Entry / SMA / Squeeze / BB / Z-Score
- ❌ Grid Loss/Profit lot/distance/candle confirm
- ❌ Hedge / Triple-Gate / Matching close / Recovery
- ❌ DD% TP / Daily Target / Balance Guard
- ❌ Trailing-stop value calculation
- ❌ License / News / Time / Sync
- ❌ Squeeze Pause Trailing v6.87–v6.91
- ❌ MaxGrid Strict 2-Cross v6.91
- ❌ `CloseGenSide()` / `CloseAllSide()` body
- ❌ Hero state machine, Single-side lock, Lock-profit BE-SL formula, Opposite-basket close hook
- ❌ ทุก helper อื่นของ Hero (Detect/Apply/Strip/Reset/CloseHeroOnSide/CountHero/IsHeroTicket)

**เปลี่ยนแค่จุดเดียว: activation gate จาก per-gen → per-side total**

---

### Files

`public/docs/mql5/Gold_Miner_EA.mq5`:
- Rewrite `BuildHeroTicketCache()` (line 2280-2376)
- Bump version: `#property version "6.97"` + header + dashboard + log prefix
- เพิ่ม audit log ทุก 30s ใน BuildHeroTicketCache (แสดง side total ทั้ง 2 ฝั่ง)

### Memory updates

- ใหม่: `mem://trading/gold-miner-ea/hero-side-total-activation-v6-97`

---

ขออนุมัติแผนนี้ครับ — แก้จุดเดียว, logic อื่นทั้งหมดคงเดิม
