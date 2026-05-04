## Goal
หลังจาก Hero ฝั่งหนึ่งถูกปิดไปแล้ว ฝั่งตรงข้ามที่เข้าเกณฑ์ครบ (เช่น SELL GM1 ในภาพ) ต้องสามารถ **เป็น Hero candidate/owner ได้ทันทีอย่างอิสระ** โดยไม่ต้องรอให้ GM2 basket ของฝั่งเดิม (BUY) ปิดก่อน

## Bug ปัจจุบัน (v7.08)
จากภาพ:
- `Hero BUY: 240/100 GL:0 Hero:0 BE_GUARD` ← Hero ปิดหมดแล้ว (`Hero:0`) แต่ `g_heroPhase_Buy` ยังค้างที่ `3 (BE_GUARD)`
- `Hero Owner: BUY (locked)` ← `GetHeroOwnerSide()` ยังคืนค่า BUY เพราะอ่านจาก `phase==3`
- `Hero SELL: 19/100 ... READY` (เหลือง) ← เข้าเกณฑ์แล้ว แต่ที่ `BuildHeroTicketCache` บรรทัด 2445 (`InpHero_SingleSideLock && curPhase==0 && activeOwner>=0 && sideId!=activeOwner`) ทำให้ SELL โดน force phase=0 ทุก tick → activate ไม่ได้

สาเหตุ: `g_heroPhase_<side>` ถูกรีเซ็ตจาก 3 → 0 **เฉพาะใน `CloseHeroOnSide()` เท่านั้น** ถ้า Hero ticket ปิดผ่านเส้นทางอื่น (Broker TP/SL ที่ stuck-TP scanner ไม่ทัน, manual close, force-close จาก Daily Target ฯลฯ) phase จะค้าง BE_GUARD ไปตลอดกาล → ทำให้ owner lock ติดถาวรและบล็อคฝั่งตรงข้าม

## Fix (v7.09 — Auto-release Hero ownership when no Heroes alive)

### Change 1 — `BuildHeroTicketCache()` (รอบๆ บรรทัด 2480)
เพิ่ม **safety release** ก่อน Phase update: ถ้า `phase == 3 (BE_GUARD)` แต่ `sideTotalActive[s] == 0` หรือไม่มี Hero tickets เหลือ (ไม่ผ่าน activation gate / take==0) → reset phase กลับเป็น 0 และตี grace timer เพื่อกัน re-tag ทันที

```cpp
// v7.09: Auto-release Hero ownership when phase==BE_GUARD but no Hero tickets exist.
// Covers all close paths (Broker TP/SL race, manual close, Daily Target force-close)
// not just CloseHeroOnSide(). Without this, owner lock stays forever and
// blocks opposite side from ever activating its own Hero.
if(g_heroPhase_Buy == 3 && sideHeroTagged[0] == 0) {
   Print("v7.09 Hero AUTO-RELEASE BUY: phase BE_GUARD but Hero=0 (closed via non-EA path) — releasing ownership");
   g_heroPhase_Buy = 0;
   g_heroBE_Applied_Buy = false;
   g_heroJustClosed_Buy = TimeCurrent();
}
if(g_heroPhase_Sell == 3 && sideHeroTagged[1] == 0) {
   Print("v7.09 Hero AUTO-RELEASE SELL: phase BE_GUARD but Hero=0 — releasing ownership");
   g_heroPhase_Sell = 0;
   g_heroBE_Applied_Sell = false;
   g_heroJustClosed_Sell = TimeCurrent();
}

// Phase update per side (existing code) — unchanged
if(g_heroPhase_Buy != 3)  g_heroPhase_Buy  = (sideHeroTagged[0] > 0) ? 2 : 0;
if(g_heroPhase_Sell != 3) g_heroPhase_Sell = (sideHeroTagged[1] > 0) ? 2 : 0;
```

### Change 2 — ยืนยันว่า `MaintainSideGenAfterHeroClose()` (v7.08) ทำงานต่อตามเดิม
- Auto-release ข้างบนตี `g_heroJustClosed_<side>` → ทำให้ post-close grace ของ v7.03 cover การ skip การ re-tag ขณะ broker settling
- `g_sideGen_<side>` / `g_heroOwnedGen_<side>` ยังไม่ถูกล้างใน auto-release — ปล่อยให้ `MaintainSideGenAfterHeroClose()` (v7.08) ล้างเมื่อ `CountNonHeroMainOnSide==0`
- ผลลัพธ์: GM2 basket ของฝั่ง BUY ยังถูกจัดการต่อโดยใช้ `g_sideGen_Buy=GM2` (grid/TP/Avg-trail/Accumulate ทำงานปกติ) **และ** SELL ฝั่งตรงข้ามสามารถสร้าง Hero ของตัวเองได้อิสระ

### Change 3 — Version bump → v7.09
อัปเดต `#property version`, `#property description`, header banner, OnInit/OnDeinit Print, dashboard title

## Resulting Flow

```
ก่อน fix (v7.08):
  BUY ARMED → BE_GUARD (owner) → Hero ปิดผ่าน Broker TP race
  → phase ค้าง 3 → Owner lock ค้าง → SELL READY แต่ activate ไม่ได้
  → GM2 BUY basket ยังเปิดอยู่ → ทุกอย่าง freeze จนกว่า GM2 จะปิด

หลัง fix (v7.09):
  BUY phase==3 แต่ Hero=0 detected ทุก tick
  → AUTO-RELEASE: phase Buy = 0, grace timer stamped
  → GetHeroOwnerSide() returns -1 → Owner lock ปลด
  → SELL ผ่าน activation gate → ARMED → ถ้า basket SELL clear ก่อน → BE_GUARD (owner คนใหม่)
  → GM2 BUY basket ยังถูก manage ต่อจน flat → MaintainSideGenAfterHeroClose ล้าง sideGen Buy = GM1
  → BUY INIT ครั้งถัดไป → GM1_INIT → Hero subsystem re-armable
```

## Dashboard ที่จะเห็น (หลัง fix)
- ทันทีที่ Hero BUY closed: `Hero Owner: NONE` หรือ `NONE (waiting close)` ถ้า SELL ARMED แล้ว
- `Hero BUY: 240/100 ... WAIT/READY` (กลับเป็นสีปกติ ไม่ใช่ BE_GUARD ค้าง)
- `Side Gen BUY: GM2 (Hero owns GM…)` ยังคงอยู่จนกว่า GM2 basket จะปิด (ตามดีไซน์ v7.08)
- `Hero SELL: 19/100 ... ARMED/BE_GUARD` ทำงานอิสระได้เลย

## สิ่งที่ไม่เปลี่ยนแปลง (per project rule)
- ❌ ไม่แตะ Order execution: `OrderSend`, `trade.Buy/Sell/PositionClose`
- ❌ ไม่แตะ Entry strategy (SMA/EMA/Squeeze/BB/ZigZag)
- ❌ ไม่แตะ Grid lot/distance/candle confirm/MaxGrid trailing math
- ❌ ไม่แตะ TP/SL/Trailing/Breakeven/Avg-TP formulae
- ❌ ไม่แตะ Hedge / Triple-Gate / Recovery / DD% TP / Daily Target / Balance Guard
- ❌ ไม่แตะ License / News / Sync modules
- ❌ ไม่แตะ Hero formula: `ComputeHeroLockProfitSL`, `ValidateHeroLockProfitSL`, `ApplyHeroLockProfitSL`, BE_GUARD apply path, OnTradeTransaction audit
- ❌ ไม่แตะ v7.04 `GetActiveGenForSide` filter sites, v7.05 unblock helpers, v7.06 GL-pool gen-lock, v7.07 candidate-vs-owner, v7.08 deferred sideGen revert
- ❌ ไม่แตะ `CloseHeroOnSide` (เส้นทางปิด Hero ปกติ — ทำงานเหมือนเดิม)

ยืนยัน: การแก้ไขเป็นเพียง **safety net** ให้ phase state สอดคล้องกับ Hero ticket count จริง ไม่กระทบ trading logic ใดๆ

## Files
- `public/docs/mql5/Gold_Miner_EA.mq5` — แก้ตามด้านบน
- `.lovable/memory/trading/gold-miner-ea/hero-auto-release-on-zero-tickets-v7-09.md` — memory entry ใหม่
- `mem://index.md` — append entry
