---
name: Golden Kuy3 v1.2 dash flicker fix + grid lot fix + Cost-Hit Restart
description: Dashboard no longer wipes all objects each refresh (high-water row trim); CalcGridLot uses MathCeil + force-step to actually grow; new Cost-Hit Restart re-opens initial-lot when SL/TP closes a ticket, with same-side distance guard
type: feature
---

ไฟล์: `public/docs/mql5/Golden_Kuy3_EA.mq5` (v1.1 → v1.2, `#property version "1.20"`)

## 1) Dashboard flicker fix
- ลบ `DelDash()` ที่ถูกเรียกทุก refresh ใน `DrawDashboard()` (เคยทำให้ทั้งกระดานหายแล้ววาดใหม่ → กระพริบ)
- เพิ่ม `g_dashRowMax` (high-water tracker). หลัง redraw ลบเฉพาะ row ที่เกินจากเฟรมก่อน (`BG_R%d / R%d / C%d / L%d / V%d`)
- Cells อัปเดต in-place ผ่าน `SetRectBg`/`SetCell` (มี `ObjectFind` อยู่แล้ว)
- `OnDeinit` ยังเรียก `DelDash()` ตามปกติ

## 2) Grid Multiplier / Add Lot fix
- ปัญหาเดิม: `NormalizeLot` ใช้ `MathRound` → `0.01 * 1.1 = 0.011` ปัดเหลือ 0.01 (ไม่โต)
- `CalcGridLot()` แก้:
  - ใช้ `MathCeil(raw/step)*step` สำหรับ ADD/MULTIPLY
  - ถ้า out ≤ base → บังคับเป็น `base + step` (รับประกันโตอย่างน้อย 1 step)
  - คง `FIXED` เดิม (round)
- เพิ่ม diagnostic Print `GK CalcGridLot mode=… base=… raw=… out=…`

## 3) Cost-Hit Restart Grid (new)
Inputs ใหม่ในกลุ่ม Grid:
- `InpEnableCostHitRestart` (default false, master)
- `InpCostHitMinSpacingPips` = 100.0
- `InpCostHitCooldownSec`    = 2

กลไก:
- `OnTradeTransaction` (`DEAL_ADD`, `DEAL_ENTRY_OUT/INOUT/OUT_BY`) อ่าน `DEAL_REASON`. ถ้า `DEAL_REASON_SL` หรือ `DEAL_REASON_TP` ของ magic+symbol เรา → ตั้ง `g_costHit_Pending_<side>=true`, จดราคา closing + เวลา. closedSide หาได้จาก `DEAL_TYPE` (sell-deal ปิด BUY-position, vice versa)
- `ManageCostHitRestart()` รันก่อน `ManageInitialEntry`/`ManageGridEntry` ทุก tick:
  - ถ้า cooldown หมด → check `HasNearbyPosition(side, refPx, InpCostHitMinSpacingPips)`. ถ้า OK เปิด `OpenInitial(side)` ทันที (ราคาตลาด, comment `GK_INIT_*` เดิม) แล้ว clear pending
  - ถ้าใกล้เกิน → คงสถานะ pending รอราคาเลื่อนห่าง (re-check ทุก tick)
- `ManageGridEntry()` เพิ่ม distance guard: เมื่อ `InpEnableCostHitRestart=true` และ `HasNearbyPosition(...)` คืน true → skip ยิง grid (ป้องกันออเดอร์ทับกันหลัง restart)

ผล: ออเดอร์ใหม่ (ticket สูงสุด) จะเป็น base ของ multiplier โดยอัตโนมัติเพราะ `CountSide()` คืน "last by highest ticket" → grid chain เริ่มจาก `InitialLot` ใหม่ตามคำขอ

## Dashboard
- Title → `Golden Kuy3 v1.2`
- เพิ่ม row `Cost-Hit Restart  ON/OFF spc=…p cd=…s` ใน MODULES
- เพิ่ม row `Restart Pending  BUY:- SELL:WAIT@1234.56` ใน SYSTEM

## ไม่เปลี่ยน (กฎเหล็ก MQL5)
- ไม่แตะ `OrderSend` / `trade.Buy` / `trade.Sell` / `trade.PositionClose` / `trade.PositionModify` (path เดิม)
- ไม่แตะ Per-Order BE / Trailing / Avg Trailing strict-2-cross / TP modes / EnforceClearTPIfDisabled
- ไม่แตะ Auto Re-Entry / Init Side Mode (Cost-Hit Restart เป็น layer แยก; ถ้า OFF พฤติกรรมเดิม 100%)
- ไม่มี License / News / Sync / Hedge / Hero / Squeeze
