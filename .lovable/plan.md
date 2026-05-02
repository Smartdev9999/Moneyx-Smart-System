# Gold Miner EA v6.92 — Hero Order Feature

## เจตนา (สรุปจากที่ user อธิบาย)

Hero Order = "เก็บ N order ใหม่สุด ของ generation+side ปัจจุบัน" แยกออกจาก basket ที่ใช้คำนวณ Average เพื่อให้:

1. Avg TP / MaxGrid Trail / Avg SL ปกติ คำนวณจาก order เก่าเท่านั้น (basket = total - N) → ปิด basket ได้เร็วขึ้น
2. Hero N ตัวที่เหลือ ใช้ trailing-per-order ของเดิม (`ManagePerOrderTrailing`) ล็อคกำไรเอง
3. ระหว่างที่ยังมี Hero ค้างอยู่บนฝั่งใด → ห้ามออก INIT/GL/GP ฝั่งนั้น (ฝั่งตรงข้ามทำงานปกติเต็มรูปแบบ)
4. เมื่อฝั่งตรงข้ามถึง TP/Trail แล้วปิด basket → ปิด Hero ฝั่งนี้พร้อมกัน (toggle ได้)
5. เมื่อปิดทุกอย่าง → cycle reset ตามเดิม

## พฤติกรรมตัวอย่าง (ตาม user)

```text
SELL basket gen=0 มี 10 ตัว, InpHero_OrderCount = 2

[Avg/Trail/SL คำนวณจาก SELL 8 ตัวเก่าสุด]
        |
[ราคาย่อลง → 8 ตัวถึง TP/MaxGridTrail] → ปิดเฉพาะ 8 ตัว, เหลือ Hero 2 SELL
        |
[Hero 2 SELL อยู่ในมือ trailing-per-order ดูแล]
        |
[ห้ามออก SELL INIT/GL/GP เพิ่ม] (เฉพาะฝั่ง SELL ที่มี Hero)
[BUY ทำงานปกติ → INIT/GL ตามจังหวะปกติ]
        |
[ราคาดีดขึ้น → BUY basket ถึง TP/Trail]
        |
[ปิด BUY basket + ปิด Hero 2 SELL พร้อมกัน] (ถ้า InpHero_CloseWithOpposite = true)
        |
[Account flat → cycle reset]
```

## ขอบเขต (เฉพาะที่ user สั่ง)

- ไฟล์เดียว: `public/docs/mql5/Gold_Miner_EA.mq5`
- ไม่แตะ Golden2 EA, Asset Miner, Jutlameasu
- ไม่แตะ License / News / Sync / Hedge / TripleGate / Recovery

---

## สิ่งที่ไม่เปลี่ยนแปลง (ยืนยันไม่กระทบ trading logic — ตาม `.lovable/rules.md`)

- ❌ ไม่แตะ `OrderSend` / `trade.Buy/Sell/PositionClose` (ใช้ `trade.PositionClose` เฉพาะตอนปิด Hero พร้อมฝั่งตรงข้าม ซึ่งเป็น close logic ใหม่ที่ user ขอโดยตรง)
- ❌ ไม่แตะ Strategy entry: SMA/INSTANT/ZZ signal, shouldEnterBuy/shouldEnterSell
- ❌ ไม่แตะสูตร Grid Loss/Profit lot, spacing, candle confirm
- ❌ ไม่แตะ Hedge trigger / release / Triple-Gate / Matching / Recovery
- ❌ ไม่แตะ Avg TP / DD% TP / Daily Target / Balance Guard formula (เปลี่ยนแค่ "ชุด orders ที่นำเข้าคำนวณ")
- ❌ ไม่แตะ Per-order trailing (ใช้ของเดิม 100% — Hero ใช้ตัวนี้เลย)
- ❌ ไม่แตะ MaxGrid Trail v6.90/v6.91 logic (เปลี่ยนแค่ basket scope)
- ❌ ไม่แตะ Squeeze Pause Trailing v6.87-89
- ❌ ไม่แตะ Cross-Gen INIT Guard, No-ReHedge Lock, Stuck-TP Scanner
- ❌ ไม่แตะ License / News / Time / Sync / Dashboard core
- ✅ แตะเฉพาะ:
  - Helper ใหม่ `IsHeroTicket()` — ตัดสิน Hero/Non-Hero ของ ticket
  - `CalculateAveragePrice()`, `CalculateFloatingPL()`, `CalcGenAveragePrice()`, `CountGenOrders()` → skip Hero ตาม flag
  - `CloseGenSide()` → skip Hero (เพื่อให้ MaxGrid Trail close basket แต่ไม่แตะ Hero)
  - `OpenOrder()` (ตอนเป็น INIT/GL/GP ฝั่งเดียวกับ Hero) → block
  - Avg TP path → ตอนปิด basket จาก Avg TP/SL: skip Hero
  - หลังจาก basket ฝั่งตรงข้ามปิดสำเร็จ → call `CloseHeroIfRequired(side)` ปิด Hero ฝั่งนี้
  - Dashboard: เพิ่ม row "Hero BUY / Hero SELL" แสดง count + lots + รวม PL

---

## Inputs ใหม่

```cpp
input string ___HeroOrder___           = "===== Hero Order (v6.92) =====";
input bool   InpHero_Enabled           = false;  // master toggle (default OFF — backward compat)
input int    InpHero_OrderCount        = 2;      // จำนวน order ใหม่สุดต่อ gen+side ที่ถือเป็น Hero
input bool   InpHero_CloseWithOpposite = true;   // เมื่อฝั่งตรงข้ามปิด basket → ปิด Hero ฝั่งนี้พร้อมกัน
input bool   InpHero_RequireNetProfit  = false;  // true = ปิด Hero ก็ต่อเมื่อ (กำไรฝั่งตรงข้าม + กำไร/ขาดทุน Hero) >= 0
input bool   InpHero_BlockSameSideGrid = true;   // ฝั่งที่มี Hero → block INIT/GL/GP เพิ่ม
input bool   InpHero_IncludeInMaxOrders= true;   // นับ Hero รวมใน MaxOpenOrders หรือไม่
```

ค่า default ทั้งหมด → backward compatible (Enabled=false ทำให้พฤติกรรมเดิมไม่เปลี่ยนแปลง)

---

## State Variables ใหม่

```cpp
// Cache: ticket → isHero (rebuild ทุก tick เริ่ม OnTick)
ulong  g_heroTickets[100];     // dynamic-ish, MAX 100 (มากพอ — N*2 sides * gens)
int    g_heroTicketCount = 0;
datetime g_heroLastBuildTime = 0;
```

---

## ตำแหน่งแก้ไข (อ้างอิง line numbers ของไฟล์ปัจจุบัน)

### A. เพิ่ม Inputs (~line 120 หลัง MaxOpenOrders)
เพิ่ม input block ตามรายการด้านบน

### B. เพิ่ม Helper Functions (วางก่อน `CalculateAveragePrice` ~line 2200)

```cpp
//+------------------------------------------------------------------+
//| v6.92 Hero Order: Build cache of Hero tickets per (gen, side)     |
//| Hero = N newest tickets (by POSITION_TIME) of current gen+side   |
//| Excludes hedge tickets and bound tickets.                         |
//+------------------------------------------------------------------+
void BuildHeroTicketCache()
{
   g_heroTicketCount = 0;
   if(!InpHero_Enabled || InpHero_OrderCount <= 0) return;
   if(g_heroLastBuildTime == TimeCurrent()) return; // throttle 1/sec
   g_heroLastBuildTime = TimeCurrent();

   // For each (gen, side) collect tickets sorted by open time desc, take top N
   // Use simple bucket: scan 0..maxGen, for each side
   int maxGen = g_maxGridMonitorGen + 5; // safe upper
   for(int gen = 0; gen <= maxGen; gen++)
   {
      for(int s = 0; s < 2; s++)
      {
         ENUM_POSITION_TYPE side = (s == 0) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
         ulong  tk[200]; datetime tt[200]; int n = 0;
         for(int i = PositionsTotal() - 1; i >= 0 && n < 200; i--)
         {
            ulong ticket = PositionGetTicket(i);
            if(ticket == 0) continue;
            if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
            if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != side) continue;
            string c = PositionGetString(POSITION_COMMENT);
            if(IsHedgeComment(c)) continue;
            if(IsTicketBound(ticket)) continue;
            if(ExtractGeneration(c) != gen) continue;
            if(StringFind(c,"_INIT")<0 && StringFind(c,"_GL")<0 && StringFind(c,"_GP")<0) continue;
            tk[n] = ticket;
            tt[n] = (datetime)PositionGetInteger(POSITION_TIME);
            n++;
         }
         // sort desc by tt (insertion sort)
         for(int a = 1; a < n; a++)
            for(int b = a; b > 0 && tt[b] > tt[b-1]; b--)
               { datetime _t=tt[b]; tt[b]=tt[b-1]; tt[b-1]=_t;
                 ulong _k=tk[b]; tk[b]=tk[b-1]; tk[b-1]=_k; }
         int take = MathMin(n, InpHero_OrderCount);
         for(int k = 0; k < take && g_heroTicketCount < 100; k++)
            g_heroTickets[g_heroTicketCount++] = tk[k];
      }
   }
}

bool IsHeroTicket(ulong ticket)
{
   if(!InpHero_Enabled) return false;
   for(int i = 0; i < g_heroTicketCount; i++)
      if(g_heroTickets[i] == ticket) return true;
   return false;
}

int CountHeroOnSide(ENUM_POSITION_TYPE side)
{
   int n = 0;
   for(int i = 0; i < g_heroTicketCount; i++)
   {
      if(!PositionSelectByTicket(g_heroTickets[i])) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == side) n++;
   }
   return n;
}

double SumHeroProfitOnSide(ENUM_POSITION_TYPE side)
{
   double sum = 0;
   for(int i = 0; i < g_heroTicketCount; i++)
   {
      if(!PositionSelectByTicket(g_heroTickets[i])) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != side) continue;
      sum += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
   }
   return sum;
}

void CloseHeroOnSide(ENUM_POSITION_TYPE side, string reason)
{
   for(int i = g_heroTicketCount - 1; i >= 0; i--)
   {
      ulong ticket = g_heroTickets[i];
      if(!PositionSelectByTicket(ticket)) continue;
      if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != side) continue;
      trade.PositionClose(ticket);
      Print("v6.92 Hero CLOSE: ticket=", ticket, " side=", EnumToString(side), " reason=", reason);
   }
   g_heroTicketCount = 0; // force rebuild next tick
}
```

### C. แก้ `CalculateAveragePrice` (line 2207) + `CalculateFloatingPL` (line 2238)

เพิ่มหลังเช็ค `IsTicketBound`:
```cpp
if(IsHeroTicket(ticket)) continue; // v6.92 Hero: exclude from basket avg
```

### D. แก้ `CalcGenAveragePrice` (line 3413) + `CountGenOrders` (line 3448) + `CountGenGridAll` (line 3386)

เพิ่ม guard เดียวกัน — Hero ไม่นับใน basket ของ MaxGrid Trail

### E. แก้ `CloseGenSide` (line 3476)

เพิ่ม guard:
```cpp
if(IsHeroTicket(ticket)) continue; // v6.92 Hero: don't close Hero with basket
```

หลัง loop เสร็จ → call:
```cpp
if(InpHero_Enabled && InpHero_CloseWithOpposite) {
   // Mark side that just closed; opposite-side hero close handled by ManageHeroOppositeClose() in OnTick
   g_heroOppositeJustClosedSide = (side == POSITION_TYPE_BUY) ? POSITION_TYPE_SELL : POSITION_TYPE_BUY;
   g_heroOppositeJustClosedTime = TimeCurrent();
}
```

### F. แก้ Avg TP path (line 2684 / 2758)

หลัง basket close จาก Avg TP/SL → set flag เดียวกับ E เพื่อให้ ManageHeroOppositeClose ทำงาน

### G. เพิ่ม `ManageHeroOppositeClose()` (เรียกใน OnTick หลัง BuildHeroTicketCache)

```cpp
void ManageHeroOppositeClose()
{
   if(!InpHero_Enabled || !InpHero_CloseWithOpposite) return;
   if(g_heroOppositeJustClosedSide == -1) return;
   if(TimeCurrent() - g_heroOppositeJustClosedTime > 5) {
      g_heroOppositeJustClosedSide = -1;
      return;
   }
   ENUM_POSITION_TYPE heroSide = (ENUM_POSITION_TYPE)g_heroOppositeJustClosedSide;
   if(CountHeroOnSide(heroSide) == 0) {
      g_heroOppositeJustClosedSide = -1;
      return;
   }

   if(InpHero_RequireNetProfit) {
      double heroPL = SumHeroProfitOnSide(heroSide);
      // ฝั่งตรงข้ามปิดไปแล้ว — กำไรอยู่ใน history
      // เพื่อความง่าย: ใช้แค่ heroPL >= 0 เป็นเกณฑ์ minimal
      if(heroPL < 0) return;
   }
   CloseHeroOnSide(heroSide, "OppositeBasketClosed");
   g_heroOppositeJustClosedSide = -1;
}
```

state vars:
```cpp
int      g_heroOppositeJustClosedSide = -1;  // POSITION_TYPE_BUY/SELL หรือ -1
datetime g_heroOppositeJustClosedTime = 0;
```

### H. แก้ `OpenOrder` (line 2044) — Block ฝั่งที่มี Hero

ใส่หลัง CrossGen guard (~line 2051):
```cpp
if(InpHero_Enabled && InpHero_BlockSameSideGrid && !IsHedgeComment(comment))
{
   if(StringFind(comment, "_INIT") >= 0 || StringFind(comment, "_GL") >= 0 || StringFind(comment, "_GP") >= 0)
   {
      ENUM_POSITION_TYPE wantSide = (orderType == ORDER_TYPE_BUY || orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_BUY_STOP)
                                    ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
      if(CountHeroOnSide(wantSide) > 0) {
         static datetime lastLog = 0;
         if(TimeCurrent() - lastLog > 30) {
            Print("v6.92 Hero BLOCK: side=", EnumToString(wantSide), " has ", CountHeroOnSide(wantSide), " Hero — skip ", comment);
            lastLog = TimeCurrent();
         }
         return false;
      }
   }
}
```

### I. แก้ `NormalOrderCount` หรือก่อน `MaxOpenOrders` check

ถ้า `InpHero_IncludeInMaxOrders = false` → หัก Hero ออกจาก count (optional, simple bypass).
Default true → ไม่ต้องแก้.

### J. OnTick integration (~line 1540)

วาง 2 บรรทัดก่อน `ManagePerOrderTrailing()`:
```cpp
BuildHeroTicketCache();      // v6.92
ManageHeroOppositeClose();   // v6.92
```

### K. Dashboard (~line 4119 region)

เพิ่ม 2 row ใน panel หลัก เมื่อ `InpHero_Enabled`:
```
Hero BUY  | Count: X | Lots: Y | PL: $Z   (สีเหลือง ถ้า X>0)
Hero SELL | Count: X | Lots: Y | PL: $Z
```

### L. Versioning

- `#property version "6.92"`
- `#property description` เพิ่มบรรทัด: `// v6.92 Hero Order — exclude N newest from basket avg, lock with per-order trail`
- Header comment block update
- Dashboard `headerVersion` ทุก mode (INST/SMA/ZZ) → "v6.92"
- OnInit/OnDeinit log → v6.92

### M. OnInit/OnDeinit reset

```cpp
g_heroTicketCount = 0;
g_heroLastBuildTime = 0;
g_heroOppositeJustClosedSide = -1;
g_heroOppositeJustClosedTime = 0;
```

---

## Edge Cases ที่จัดการ

1. **Hero ตัวเดียวเป็น INIT แล้วปิด** → BuildCache rebuild → Hero set อาจว่าง → grid block ปลด
2. **EA restart ระหว่างมี Hero** → cache rebuild จาก PositionsTotal บน OnInit / first tick → Hero กลับมาเหมือนเดิม (อิง POSITION_TIME ใหม่สุด)
3. **MaxGrid Trail ARM ขณะมี Hero** → avg คำนวณจาก non-Hero, CloseGenSide skip Hero → basket ปิด, Hero ค้าง → trailing-per-order ดูแลต่อ → ถูกต้องตามเจตนา
4. **Squeeze Pause** → ไม่กระทบ Hero (Squeeze pause trailing เดิมยังครอบทุกอย่างเหมือนเดิม)
5. **InpHero_Enabled = false** → ทุก helper return false/0 → เส้นทางเดิม 100%

## ไฟล์ที่แก้

- `public/docs/mql5/Gold_Miner_EA.mq5` (หลัก)
- `.lovable/memory/trading/gold-miner-ea/hero-order-v6-92.md` (ใหม่)
- `.lovable/memory/index.md` (เพิ่ม 1 บรรทัด)

## หลังจาก implement

User สามารถ:
- Default OFF → ทดสอบเทียบ backtest กับ v6.91 ก่อน → ต้องได้ผลเหมือนเดิม 100%
- เปิด `InpHero_Enabled = true`, `InpHero_OrderCount = 2` → ดูพฤติกรรม basket ปิดเร็วขึ้น + Hero ค้าง trail
