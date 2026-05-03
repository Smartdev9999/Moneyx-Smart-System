# Hero Order v7.02 → v7.03

แก้ 2 บั๊ก/ฟีเจอร์ที่ user รายงาน หลังจากที่ Hero + ฝั่งตรงข้ามปิดรวบกันแล้ว

## บั๊ก/พฤติกรรมที่พบ

### 1. ออเดอร์ "แปลกปลอม" โผล่หลัง Hero ปิดพร้อมฝั่งตรงข้าม
จากภาพ: หลัง Hero ฝั่ง BUY ปิดด้วย `OppositeBasketFlatTick` มีออเดอร์ใหม่โผล่มาโดยถูก lock (ไม่มี TP) เหมือน Hero

**Root cause** อยู่ใน `BuildHeroTicketCache` v7.01 (Sticky Tag) ผสมกับ `ResetHeroStateIfFlat`:

- `CloseHeroOnSide()` สั่งปิด แต่ broker ยังคืนผล async — ใน tick เดียวกันอาจยังเห็น Hero ticket อยู่
- ก่อน `ResetHeroStateIfFlat` จะรันได้สำเร็จ ระบบเข้าเงื่อนไข entry และเปิด INIT/GL ใหม่
- เพราะ `g_heroPhase_Buy == 3 (BE_GUARD)` ยังไม่ reset → v7.01 sticky logic ข้าม threshold gate → re-tag GL ใหม่เป็น Hero ทันที (`take = MathMin(N, nGL)`)
- `StripBrokerTPSLFromHeroTickets()` ลบ TP บนตั๋วใหม่ → ดูเหมือน "Hero ผีๆ"

### 2. ฟีเจอร์ใหม่: per-side generation isolation ขณะมี Hero
สเปกใหม่ของ user:
- ฝั่งที่มี Hero ยังคง Hero ค้างไว้ใน **gen เดิม (gen N)** จนกว่าจะปิดด้วย lock-profit SL หรือพร้อมฝั่งตรงข้ามใน gen เดียวกัน
- เมื่อ basket non-Hero ฝั่ง Hero ปิดไปแล้ว ฝั่ง Hero **เริ่มเทรดใหม่ใน gen N+1** โดย Hero gen N ไม่ยุ่ง
- ฝั่งตรงข้ามที่ยังมี basket ค้าง — ยังเทรดต่อใน gen N เดิมจนปิด
- เมื่อทั้ง Hero gen N + opposite gen N ปิดหมด → ระบบกลับไปเทรดปกติ (gen ปัจจุบันเหลือ N+1 หรือ reset เป็น GM1 ถ้า account flat)

ตอนนี้ `g_cycleGeneration` เป็น **global ตัวเดียว** — เพิ่มเฉพาะตอน hedge เปิด ไม่มี per-side generation tracking

## สิ่งที่จะแก้ใน v7.03

### Fix A — Reset phase ทันทีหลัง CloseHeroOnSide (ใน `ManageHeroOppositeClose`)

หลัง `CloseHeroOnSide(side, "OppositeBasketFlatTick")` (line 2731):

```cpp
// v7.03: hard-reset phase + applied flag immediately so next tick
// won't re-tag newly entering INIT/GL as Hero via Sticky logic.
if(side == POSITION_TYPE_BUY)  { g_heroPhase_Buy  = 0; g_heroBE_Applied_Buy  = false; }
else                            { g_heroPhase_Sell = 0; g_heroBE_Applied_Sell = false; }
g_heroTicketCount = 0;          // clear cache so IsHeroTicket false until next build
```

ทำเหมือนกันใน `CloseOppositeHeroOnBasketClose` hook (close-path เดิมจาก CloseAllSide)

### Fix B — เพิ่ม guard ใน `BuildHeroTicketCache` ป้องกัน Sticky re-tag ขณะ "ปิดอยู่"

เพิ่ม flag pending close per side:

```cpp
datetime g_heroJustClosed_Buy  = 0;
datetime g_heroJustClosed_Sell = 0;
const int InpHero_PostCloseGraceSec = 5;  // input ใหม่
```

ใน `BuildHeroTicketCache` หลังเช็ค sticky:
```cpp
// v7.03: ถ้าเพิ่งสั่งปิด Hero ฝั่งนี้ใน N วินาทีล่าสุด — บังคับ NONE phase
// แม้ broker จะยังคืน position อยู่ ก็จะไม่ re-tag เป็น Hero
datetime jc = (sideId==POSITION_TYPE_BUY) ? g_heroJustClosed_Buy : g_heroJustClosed_Sell;
if(jc > 0 && TimeCurrent() - jc < InpHero_PostCloseGraceSec) {
   // skip tagging this side entirely; force phase NONE
   if(sideId==POSITION_TYPE_BUY) g_heroPhase_Buy=0; else g_heroPhase_Sell=0;
   continue;
}
```

ตั้ง `g_heroJustClosed_*` ใน Fix A

### Fix C — Per-side generation isolation (ฟีเจอร์ใหม่)

เพิ่ม global per-side gen offset:
```cpp
int g_sideGen_Buy  = 0;   // 0 = ใช้ g_cycleGeneration ปกติ, >0 = override gen ฝั่งนี้
int g_sideGen_Sell = 0;
int g_heroOwnedGen_Buy  = 0;  // gen ที่ Hero BUY ค้างอยู่
int g_heroOwnedGen_Sell = 0;
```

แก้ `GetCommentPrefix()` ให้รับ side optional:
```cpp
string GetCommentPrefixForSide(ENUM_POSITION_TYPE side) {
   int sg = (side==POSITION_TYPE_BUY) ? g_sideGen_Buy : g_sideGen_Sell;
   int g = (sg > 0) ? sg : ((g_cycleGeneration < 1) ? 1 : g_cycleGeneration);
   return "GM" + IntegerToString(g);
}
```

ทุกจุดที่สร้าง comment INIT/GL/GP → ใช้ `GetCommentPrefixForSide(side)` แทน `GetCommentPrefix()`
(จุดสำคัญ: entry logic line ~1773-1804, GL/GP placement)

**Trigger generation bump per side** — ใน `ManageHeroOppositeClose` เมื่อ Hero เพิ่งเข้า BE_GUARD (basket non-Hero ฝั่งเดียวกันปิดหมด แต่ Hero ยังอยู่):

```cpp
// v7.03: ฝั่งนี้มี Hero ค้าง + basket non-Hero ปิดหมด → bump side gen ไปอีก 1
//        เพื่อให้ออเดอร์ใหม่ฝั่งนี้เปิดเป็น GM(N+1) แยกจาก Hero (GM N)
if(transitioning_to_BE_GUARD && CountNonHeroMainOnSide(side) == 0) {
   int curGen = (g_cycleGeneration < 1) ? 1 : g_cycleGeneration;
   int sg     = (side==POSITION_TYPE_BUY) ? g_sideGen_Buy : g_sideGen_Sell;
   int newSg  = (sg > 0 ? sg : curGen) + 1;
   if(side==POSITION_TYPE_BUY) { g_sideGen_Buy = newSg; g_heroOwnedGen_Buy = curGen; }
   else                          { g_sideGen_Sell= newSg; g_heroOwnedGen_Sell= curGen; }
   Print("v7.03 SIDE-GEN BUMP: side=", EnumToString(side),
         " heroOwnedGen=GM", curGen, " → newSideGen=GM", newSg);
}
```

**Reset side gen** ใน `ResetHeroStateIfFlat` หรือ `CloseHeroOnSide` เมื่อ Hero ฝั่งนั้นปิดหมด:
```cpp
if(side==POSITION_TYPE_BUY)  { g_sideGen_Buy  = 0; g_heroOwnedGen_Buy  = 0; }
else                          { g_sideGen_Sell = 0; g_heroOwnedGen_Sell = 0; }
```

**ปรับ `CountFreeOlderGenOnSide` / `CrossGen_InitGuard`** ให้ยกเว้น Hero tickets (gen เก่าฝั่ง Hero) เพื่อไม่บล็อก INIT ใหม่ของ side gen ใหม่:
```cpp
// ถ้า ticket นั้นเป็น Hero และอยู่ใน g_heroOwnedGen_<side> → ไม่นับ (ไม่ block)
```

### Fix D — Dashboard
เพิ่มแถวใน HERO Monitor:
- `Side Gen BUY: GM2 (Hero owns GM1)` เมื่อ active
- `Side Gen SELL: GM1` เมื่อ no Hero

### Fix E — Version bump 7.02 → 7.03
- `#property version "7.03"`
- `#property description` → "Post-close phase reset + per-side generation isolation when Hero survives"
- header / dashboard `headerVersion` / log prefix

## สิ่งที่ไม่เปลี่ยนแปลง

- ไม่แตะ `OrderSend` / `trade.Buy` / `trade.Sell` / `trade.PositionClose` execution
- ไม่แตะ entry conditions (SMA/EMA/ZigZag/BB/Squeeze/Z-Score) — แค่เปลี่ยนค่า prefix ใน comment
- ไม่แตะ Grid Loss / Grid Profit lot/distance/candle confirm formulas
- ไม่แตะ Hedge / Triple-Gate / Matching Close / Recovery / Auto Recovery (hedge ยังเพิ่ม `g_cycleGeneration` global ตามเดิม)
- ไม่แตะ Average TP / Trailing / DD% TP / Daily Target / Balance Guard
- ไม่แตะ License / News / Time / Sync
- ไม่แตะ `ComputeHeroLockProfitSL` / `ValidateHeroLockProfitSL` (v7.02 fix ยังเดิม)
- ไม่แตะ `IsHeroTicket` exclusion guards ในทุก trailing/SyncBrokerTPSL
- `g_cycleGeneration` global ยังทำงานเหมือนเดิม — `g_sideGen_*` เป็น override layer เท่านั้น เมื่อทั้งสอง side gen = 0 พฤติกรรม = v7.02

## ผลลัพธ์ที่คาดหวัง

1. หลัง Hero ปิดพร้อม opposite (Broker TP/SL): ภายใน grace 5s จะไม่มีตั๋วใหม่ถูก tag เป็น Hero — ตั๋วใหม่จะมี TP ปกติ
2. ฝั่งที่มี Hero ค้าง: ตั๋วใหม่ออกเป็น `GM(N+1)_INIT` แยกจาก Hero `GM(N)_GL` — เทรดต่อเนื่องโดย Hero ไม่ยุ่ง
3. ฝั่งตรงข้าม (ไม่มี Hero): เทรดต่อใน `GMN` เดิม
4. เมื่อ Hero `GMN` + opposite `GMN` ปิดครบ → `ResetHeroStateIfFlat` reset side gen → ฝั่ง Hero กลับมาใช้ `GMN` ปกติ; account flat → cycle reset → `GM1`
