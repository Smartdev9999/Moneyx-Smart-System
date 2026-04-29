---
name: Gold Miner EA v6.89 — Pause Trailing Strip Broker SL
description: On Squeeze Pause edge (Normal->Pause), strips broker SL from trailing-owned tickets (_INIT/_GL/_GP) and resets g_trailingSL_*/g_maxGridTrailSL_* state. Adds missing guard at ManageTrailingStop(). SyncBrokerTPSL forces SL=0 while paused.
type: feature
---

# Gold Miner EA v6.89

ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

## ปัญหาที่แก้
1. `ManageTrailingStop()` (line 2999, INSTANT/SMA branch) ไม่มี Pause guard → trailing ยังคำนวณและ modify ระหว่าง Expansion
2. v6.87/v6.88 หยุดแค่ modify ใหม่ แต่ broker SL เก่ายังค้างไว้ → user ต้องการให้ "ถอด SL ออก" จริงๆ
3. `SyncBrokerTPSL` (v6.85) มี branch `slBuy==0 && curSL>0 → effectiveSl=curSL` ที่จะใส่ SL กลับทันทีหลัง strip

## เพิ่ม
- Input `InpSqueeze_PauseTrail_StripSL` (default `true`)
- Global `g_squeezePauseTrailingActive` (edge state)
- `StripTrailingBrokerSL()` — `PositionModify(ticket, 0.0, curTP)` เฉพาะ `_INIT`/`_GL`/`_GP` (skip `GM_HEDGE_*`/`GM_HD*`)
- `IsTrailingPausedAndHandleEdge()` — edge-aware: บน Normal→Pause รีเซ็ต `g_trailingActive_Buy/Sell`, `g_trailingSL_Buy/Sell`, `g_maxGridTrailActive_Buy/Sell`, `g_maxGridTrailSL_Buy/Sell` แล้วเรียก `StripTrailingBrokerSL()`

## เปลี่ยน 5 จุดเรียก
- `ManagePerOrderTrailing()` → `IsTrailingPausedAndHandleEdge()`
- `ManageTrailingStop()` → **เพิ่มใหม่** (จุดที่หาย!)
- `ManageMaxGridTrailing()` → `IsTrailingPausedAndHandleEdge()`
- `ManageTrailingStop_TF()` → `IsTrailingPausedAndHandleEdge()`
- `SyncBrokerTPSL()` BUY+SELL branches: เพิ่ม `if(g_squeezePauseTrailingActive && InpSqueeze_PauseTrail_StripSL) effectiveSl = 0;` เป็นเงื่อนไขแรก ป้องกัน re-apply SL เก่า

## พฤติกรรม
- เข้า Pause: ยิง strip ครั้งเดียว, รีเซ็ต state, ทุก trailing manager skip
- ระหว่าง Pause: SyncBrokerTPSL บังคับ SL=0 ทุก tick (TP ยังคงอยู่)
- ออก Pause: log "TRAILING RESUMES", state เริ่มใหม่จากราคาปัจจุบัน

## ไม่เปลี่ยน
- `ApplyTrailingSL`/`ApplyTrailingSL_TF` defense guards (v6.87) ยังใช้ `IsSqueezePausingTrailing()` เดิม
- ไม่แตะ `UpdateSqueezeState`, BB/KC/ATR
- ไม่แตะ Hedge SL/TP (`GM_HEDGE_*`/`GM_HD*`)
- ไม่แตะ Order execution / Strategy / Grid / TP / Accumulate / DD exit
- ไม่แตะ Block New Orders / `g_squeezeBlocked*`
- ไม่แตะ License / News / Time / Sync

## Version
v6.88 → v6.89 (header, `#property version`, `#property description`, OnInit/OnDeinit log, Dashboard headerVersion ทุก mode)
