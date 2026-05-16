---
name: Golden2 v2.9.4 Max Lot Caps + Max DD Close
description: Two independent lot caps (NORMAL orders vs TRIPLE-GATE exit recovery) plus global Max DD Close kill switch (PERCENT-of-balance or USD floating-loss modes)
type: feature
---

ไฟล์: `public/docs/mql5/Golden2_EA.mq5` (v2.9.3 → v2.9.4)

## Inputs ใหม่ (group `=== Risk Limits ===` หลัง Recovery Grid)
- `InpMaxLotPerOrder` (double, default 0.0) — cap lot/order สำหรับ **NORMAL** orders (Initial market/pending entry, Grid loss/profit, Hedge mirror ladder, Continuation). 0 = OFF
- `InpMaxLotTripleGate` (double, default 0.0) — cap lot/order สำหรับ **TRIPLE-GATE EXIT** recovery (`PlaceRecoveryGridIfNeeded` → RC#N). 0 = OFF
- `ENUM_G2_DDMODE { G2_DD_OFF, G2_DD_PERCENT, G2_DD_DOLLAR }`
- `InpMaxDDMode` (enum, default G2_DD_OFF)
- `InpMaxDDValue` (double, default 20.0) — % ของ balance หรือ $ floating loss

## Helpers
```cpp
double CapLotMaxG2(double lot, double cap);     // step-FLOOR (ห้ามเกิน cap), clamp min/max
double CapNormalLotG2(double lot);              // wrap InpMaxLotPerOrder
double CapTripleGateLotG2(double lot);          // wrap InpMaxLotTripleGate
double EntryInitialLotG2();                     // CapNormalLotG2(InpInitialLot)
```

## จุดที่ apply cap
| ตำแหน่ง | Helper | หมายเหตุ |
|---|---|---|
| `LotForLevel` (legacy ladder ใช้โดย hedge stack/continuation) | `CapNormalLotG2` | wrap return |
| `ResolveLot` (CUSTOM/ADD/MULTIPLY mode) | `CapNormalLotG2` | wrap return |
| direct `trade.Buy/Sell/BuyStop/SellStop(InpInitialLot, ...)` × 6 ที่ | `EntryInitialLotG2()` | Initial market + pending + re-arm |
| `PlaceRecoveryGridIfNeeded` (RC#N lot) | `CapTripleGateLotG2` | **เท่านั้น** — ใช้ cap ที่สอง แยกจาก normal |

## Max DD Close logic
`ManageMaxDDClose()` รันทุก tick ก่อน per-group loop (หลัง `RefreshSqueezeStateThrottled`):
- รวม floating PL ของทุก position ของ magic+symbol → `floating`
- `absDD = max(0, -floating)`, `pct = absDD * 100 / balance`
- เก็บ `g_maxDDCurrAbs` / `g_maxDDCurrPct` ให้ Dashboard
- Trigger:
  - `G2_DD_PERCENT`: `pct >= InpMaxDDValue`
  - `G2_DD_DOLLAR`: `absDD >= InpMaxDDValue`
- 30s hardcoded cooldown (`g_maxDDCloseLastFire`)
- เมื่อยิง: ปิด **ทุก position** + ลบ **ทุก pending** ของ magic+symbol (`trade.PositionClose` + `trade.OrderDelete`)

## Dashboard (เพิ่ม 2 บรรทัด หลัง Triple-Gate row)
- `Risk MaxLotN/TG    0.50 / 1.00` (หรือ `OFF / OFF`)
- `Max DD Close       PCT 20.0% (cur 4.32%)` / `USD $500 (cur $123.45)` / `OFF`
- สีเตือน: เหลือง ≥70% ของ threshold, แดง ≥100%

## Init log
`Golden2 EA v2.9.4 initialized | MaxLotPerOrder=0.50 MaxLotTripleGate=1.00 MaxDDMode=PERCENT MaxDDValue=20.00 | DisarmPartialFill=ON | ...`

## สิ่งที่ไม่เปลี่ยน (Rules of Steel)
- ❌ SMA/EMA signals, Grid entry/exit, TP/SL/Trail/BE, Accumulate, DD-exit logic เดิม, Entry conditions
- ❌ Hedge **arm/disarm** logic (DD%, ArmPercent, BlockNewOrderPercent, Disarm Partial-Fill v2.9.3)
- ❌ MirrorLossSideToHedgePendings, PlaceHedgePendingSet
- ❌ One-Hedge-Per-Group (v2.8.5), Stale-side sweep (v2.9.2), Hedge-Used Advance Bypass (v2.9.2)
- ❌ Triple-Gate matching close logic / ShredCloseLosingSide / ShredAllNegativeFromAllProfit (เปลี่ยนเฉพาะ **lot** ของ RC#N เท่านั้น)
- ❌ Recovery Grid logic (seed lock v2.9.0, continuation v2.8.8) — เพิ่ม cap หลัง NormalizeLot
- ❌ License / News / Time / Sync / Dashboard layout เดิม
- ❌ ParseComment / MakeComment

## ผลลัพธ์
- เมื่อ `InpMaxLotPerOrder=0.50` → ทุก entry/grid/hedge mirror ที่จะออก lot > 0.50 ถูก floor ลงเหลือ 0.50
- เมื่อ `InpMaxLotTripleGate=1.00` → RC#N ที่ multiplier ขยายเกิน 1.00 ถูก floor เหลือ 1.00 (ไม่กระทบ normal grid)
- เมื่อ `InpMaxDDMode=PERCENT` + `InpMaxDDValue=20` → floating loss ถึง 20% ของ balance → ปิดทุก position + ลบทุก pending ทันที (30s cooldown)
- `InpMaxLotPerOrder=0`, `InpMaxLotTripleGate=0`, `InpMaxDDMode=OFF` → behavior เหมือน v2.9.3 ทุกประการ
