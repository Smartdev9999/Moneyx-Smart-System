---
name: Golden2 EA v2.7.8 — Force-Close Opposite Unhedged
description: v2.7.8 closes any leftover main positions on the side NOT covered by an active hedge in the same group, immediately and regardless of P/L, to make the hedge matching clean and unblock advance to the next group.
type: feature
---

# Golden2 EA v2.7.8 — Force-Close Opposite Unhedged Side

ไฟล์: `public/docs/mql5/Golden2_EA.mq5`

## ปัญหาที่แก้
จาก log: `hold G2->G3 ... blkBUY=2 blkSELL=12 hedgeBuy=13 hedgeSell=0 plBUY=+270 plSELL=-13927`
- SELL ติดลบถูก hedge BUY คุม (12 vs 13) → matching OK
- แต่ BUY main 2 ไม้เปิดไว้ก่อน hedge ในกรุ๊ปเดียวกัน — ไม่มี hedge SELL คุม
- กรุ๊ปไม่ "สะอาด" → G3 เปิดไม่ได้

## Logic ใหม่ (`ForceCloseUnhedgedOppositeSide(g)`)
- เรียกใน `TryAdvanceToNextGroup()` หลัง `DeleteLeftoverInitialPendingsAfterHedge(cur)` ก่อนเช็ค safe
- ถ้ามี hedge BUY active (ไม่มี hedge SELL) → ปิด main BUY ทุกไม้ในกรุ๊ปนั้นทิ้ง
- ถ้ามี hedge SELL active (ไม่มี hedge BUY) → ปิด main SELL ทุกไม้
- ถ้ามีทั้งสอง hedge (rare two-way) → ปิดทั้ง main BUY + main SELL ที่เหลือ
- ไม่แตะ hedge positions / ไม่แตะ pendings
- หน่วงเวลาด้วย `g_groupHedgeFirstSeen[g]` + `InpHedge_ForceCloseDelaySec` (default 3s) กัน race

## Inputs ใหม่
- `InpHedge_ForceCloseOppUnhedged` (default `true`)
- `InpHedge_ForceCloseDelaySec` (default `3`)

## Dashboard
- เพิ่มแถว `Force-Close Opp: ON (3s)` ใต้ `Hedge Delay`

## ไม่เปลี่ยน
- ไม่แตะ Order execution path เดิม (ใช้ `trade.PositionClose` ตามมาตรฐาน)
- ไม่แตะ `IsGroupSafeToAdvance` / `CountBlockingMainPositionsForAdvance` / `IsSideEffectivelySafeForAdvance`
- ไม่แตะ Hedge mirror, Grid loss/profit, TP/SL, Triple-Gate, Accumulate, Squeeze v2.7.7
- ไม่แตะ Entry mode (PENDING/SMA/INSTANT)
- ปิด `InpHedge_ForceCloseOppUnhedged=false` = พฤติกรรม v2.7.7 100%
