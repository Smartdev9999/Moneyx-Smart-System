---
name: Kuy3 v1.59 Max Lot + Max DD Close
description: Adds Max Lot per Order cap (post-multiplier) and Max DD Close mode (PERCENT of balance / DOLLAR floating loss) — flattens via CloseAllOurs with Hero opp-close intent
type: feature
---

ไฟล์: `public/docs/mql5/Golden_Kuy3_EA.mq5` (v1.58 → v1.59)

## Inputs (3 ตัวใหม่ใน group `=== Risk Limits (v1.59) ===`)
- `InpMaxLotPerOrder` (double, default 0.0) — 0 = ไม่จำกัด, > 0 = cap lot ต่อ order ใน `CalcGridLot()`
- `ENUM_GK_DD_MODE { GK_DD_OFF, GK_DD_PERCENT, GK_DD_DOLLAR }`
- `InpMaxDDMode` (enum, default GK_DD_OFF)
- `InpMaxDDValue` (double, default 20.0) — % ของ balance หรือ $ floating loss

## Logic

### Max Lot
ใน `CalcGridLot()` หลัง min/max broker clamp:
```cpp
if(InpMaxLotPerOrder > 0.0 && out > InpMaxLotPerOrder) out = InpMaxLotPerOrder;
if(stp>0) out = MathFloor(out/stp)*stp;  // floor to step (ห้ามเกิน cap)
if(out < minL) out = minL;
```

### Max DD Close
`ManageMaxDDClose()` รันใน OnTick ก่อน `ManageTakeProfit()`:
- 30s hardcoded cooldown (`g_maxDD_LastFire`)
- รวม floating ทุก position ของ EA (รวม Hero) เป็น `floating`
- เก็บ `g_maxDD_CurrAbs` / `g_maxDD_CurrPct` สำหรับ dashboard
- Trigger:
  - `GK_DD_PERCENT`: `pct >= InpMaxDDValue`
  - `GK_DD_DOLLAR`: `absDD >= InpMaxDDValue`
- เมื่อยิง: set `g_oppCloseIntent_AvgTP_Buy/Sell = true` (ให้ Hero ปิดตามตามกติกา v1.51/v1.57) แล้วเรียก `CloseAllOurs()`

## Dashboard (1 บรรทัด)
ใน section `=== TAKE PROFIT ===` หลัง Accumulate:
- `Risk Limits  MaxLot:1.00  DD:PCT 20.0% (cur 4.32%)`
- `Risk Limits  MaxLot:OFF  DD:USD $500 (cur $123.45)`
- `Risk Limits  MaxLot:OFF  DD:OFF`

## ไม่กระทบ
- `OrderSend` / `trade.*` ทุกจุด (ใช้ `CloseAllOurs()` เดิม)
- Grid entry / new-candle / lot mode (FIXED/ADD/MULTIPLY) — แค่ clamp ค่าสุดท้าย
- Per-Order BE/Trail, Avg-TP, Avg-Trail strict 2-cross, Accumulate, Cost-Hit
- Hero logic ทั้งหมด (Handoff Reserve, Conditional Lock, Alternation, lock-profit SL, TP-event latch)
- `InpMaxLotPerOrder=0` + `InpMaxDDMode=OFF` → behavior เหมือน v1.58 ทุกประการ
