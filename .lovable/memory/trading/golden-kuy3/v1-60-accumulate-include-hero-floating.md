---
name: Kuy3 v1.60 Accumulate Close — count floating incl. Hero
description: ManageTakeProfit Accumulate branch switched from CalcSideFloating_NonHero to CalcSideFloating (Gold Miner concept) so Hero floating profit counts toward realized+floating>=target trigger
type: feature
---

ไฟล์: `public/docs/mql5/Golden_Kuy3_EA.mq5` (v1.59 → v1.60)

## Bug v1.59
Dashboard เห็น Realized=$11,575 + Floating(บัญชี)=$92,352 = $103,927 ≥ Target $50,000 แต่ Accumulate Close ไม่ยิง
สาเหตุ: `ManageTakeProfit()` ใช้ `CalcSideFloating_NonHero(BUY)+_NonHero(SELL)` → ตัด Hero ฝั่ง SELL ที่ถือกำไรก้อนใหญ่ออก
สูตรในใน ManageTakeProfit เลยเหลือน้อยกว่า threshold

## Fix v1.60
ใน `ManageTakeProfit()` (บล็อก Accumulate เท่านั้น):
```cpp
double floatingAll = CalcSideFloating(POSITION_TYPE_BUY) + CalcSideFloating(POSITION_TYPE_SELL);
if((g_realizedCycle + floatingAll) >= InpAccumulateTarget){ ... CloseAllOurs(); }
```
- `CalcSideFloating()` รวมทุก position (รวม Hero) — เหมือน Gold Miner `CalculateTotalFloatingPL()`
- `CloseAllOurs()` ปิดทุกอย่างรวม Hero อยู่แล้ว → ปลอดภัย
- intent flag `g_oppCloseIntent_AvgTP_Buy/Sell=true` ก่อน close → Hero TP-event latch ทำงานปกติ

## Dashboard
Row Accumulate แสดง current sum: `Accumulate  ON  $50000 (cur $103927.45)` สีเขียวเมื่อ cur≥target

## ไม่กระทบ
- TP Dollar / TP %Bal / TP Points (ต่อฝั่ง) ยังใช้ `_NonHero` เหมือน v1.59 (Hero ห้าม trigger TP รายฝั่ง)
- `g_realizedCycle` accounting + `TryResetAccumulateCycleIfFlat` (v1.42)
- Max Lot cap / Max DD Close (v1.59) / Cost-Hit / Per-Order BE+Trail / Avg-TP / Avg-Trail strict 2-cross
- Hero pipeline ทั้งชุด (Handoff Reserve, Conditional Lock, Alternation, lock-profit SL, TP-event latch, Dynamic refresh, IsHeroProtectedTicket)
- ถ้า `InpUseAccumulateClose=false` → behavior = v1.59 ทุกบรรทัด
