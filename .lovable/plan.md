# Gold Miner EA v6.89 — Pause Trailing: Strip Broker SL

## ปัญหาที่พบ (จากภาพ user)
แม้ Squeeze เข้า Expansion ครบ 3 TF แล้ว และ v6.88 Pause Trailing ทำงาน แต่:

1. **`ManageTrailingStop()`** (line 2995) — branch ที่ใช้กับ INSTANT/SMA/SQ entry mode — **ไม่มี guard** `IsSqueezePausingTrailing()` ทำให้ trailing ยังคำนวณและยิง `ApplyTrailingSL` ต่อ (เห็นชัดในภาพ: `Avg Trailing: Sell SL:3358.93` ยังขึ้นทั้งที่ทุก TF EXPANSION SELL)

2. User ต้องการให้ตอน Pause **"ถอด broker SL ออกทั้งหมด"** ไม่ใช่แค่หยุด modify (เพื่อไม่ให้ broker shoot SL ที่ค้างไว้ระหว่าง expansion)

## แนวทางแก้

### A) เติม Guard ที่ `ManageTrailingStop()` (จุดที่หาย)
เพิ่มบรรทัดที่ 2997 ก่อน body:
```cpp
if(IsSqueezePausingTrailing()) { ResetTrailingStateOnPause(); return; }
```

### B) เพิ่ม Input ควบคุมการ Strip
```cpp
input bool InpSqueeze_PauseTrail_StripSL = true; // v6.89: Strip broker SL on bound trailing tickets when paused
```
วางใต้ `InpSqueeze_PauseTrail_MinTF`

### C) ฟังก์ชัน Strip ใหม่ `StripTrailingBrokerSL()`
- เรียกครั้งเดียวที่ขอบ "Normal → Pause" (ตรวจ edge ด้วย `g_squeezePauseTrailingActive` static)
- วน `PositionsTotal()` ฝั่ง EA magic เท่านั้น
- กรอง comment: ให้ strip เฉพาะ ticket ที่ trailing เป็นเจ้าของ → `_INIT` / `_GL` / `_GP` (ที่ trailing manager คุม) — **ห้าม** ยุ่งกับ `GM_HEDGE_*` / `GM_HD*` (TP/SL hedge เป็นของ Triple-Gate)
- เรียก `trade.PositionModify(ticket, 0.0, currentTP)` → ลบ SL คง TP เดิมไว้
- log ว่า "SQUEEZE PAUSE: Stripped broker SL from N tickets"

### D) Edge detection + state reset
เพิ่ม global:
```cpp
bool g_squeezePauseTrailingActive = false;
```

ใน `ManagePerOrderTrailing` / `ManageTrailingStop` / `ManageMaxGridTrailing` / `ManageTrailingStop_TF` เริ่มต้นด้วย:
```cpp
bool pausing = IsSqueezePausingTrailing();
if(pausing && !g_squeezePauseTrailingActive)
{
   g_squeezePauseTrailingActive = true;
   if(InpSqueeze_PauseTrail_StripSL) StripTrailingBrokerSL();
   // Reset trailing state so resume starts fresh from current price
   g_trailingSL_Buy = 0; g_trailingSL_Sell = 0;
   g_maxGridTrailActive_Buy = false; g_maxGridTrailActive_Sell = false;
   g_maxGridTrailSL_Buy = 0; g_maxGridTrailSL_Sell = 0;
}
if(!pausing && g_squeezePauseTrailingActive)
{
   g_squeezePauseTrailingActive = false;
   Print("SQUEEZE PAUSE END: Trailing resumes from current price");
}
if(pausing) return;
```

จุดที่ดีกว่า: ห่อ logic นี้ไว้ใน helper `bool IsTrailingPausedAndHandleEdge()` แล้วเรียกที่ทุก trailing manager (4 จุด) เพื่อไม่ซ้ำซ้อน

### E) Dashboard
แถว `Avg Trailing` แสดง `PAUSED (Squeeze Exp)` แทน `Sell SL:xxx` เมื่อ `g_squeezePauseTrailingActive`

### F) Version bump v6.88 → v6.89
- Header / `#property version` / `#property description`
- `OnInit` / `OnDeinit` log
- Dashboard headerVersion 3 mode

## สิ่งที่ไม่เปลี่ยนแปลง (กฎเหล็ก)
- ไม่แตะ Order Execution (`OrderSend`, `trade.Buy/Sell/PositionClose`)
- ไม่แตะ Trading Strategy / Grid Loss / Grid Profit / TP / Hedge / Accumulate / DD exit
- ไม่แตะ `UpdateSqueezeState` / BB / KC / ATR
- ไม่แตะ Block New Orders / `g_squeezeBlocked*` / Hedge Trigger Expansion
- ไม่แตะ broker SL ของ `GM_HEDGE_*` / `GM_HD*` (Triple-Gate hedge tickets) — strip เฉพาะ trailing-owned tickets เท่านั้น
- ไม่แตะ License / News / Time / Sync
- ไม่แตะ v6.86 (avg incl GP) / v6.87 / v6.88

## Memory
- สร้าง `mem://trading/gold-miner-ea/squeeze-pause-strip-sl-v6-89.md`
- Update `mem://index.md`
