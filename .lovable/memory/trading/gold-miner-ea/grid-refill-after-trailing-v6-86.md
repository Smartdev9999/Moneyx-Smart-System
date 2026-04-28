---
name: Gold Miner EA v6.86 — Grid Refill After Trailing Close
description: v6.86 adds optional Grid Refill that re-opens GL/GP orders at the exact price levels where Per-Order Trailing Stop / Breakeven previously closed grid orders. Records closed-slot snapshots (price, lots, level) per side+kind. Refill fires when price returns within tolerance to a slot, with anti-overlap guard against existing same-side orders. Default OFF (EnableGridRefill=false) — full v6.85 backward compatibility.
type: feature
---

# Gold Miner EA v6.86 — Grid Refill After Per-Order Trailing Close

ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

## เป้าหมาย
เมื่อ Per-Order Trailing / Breakeven ปิด grid order (GL หรือ GP) ออกไป → จดจำ "ช่องว่าง" ที่เกิดขึ้น (ราคา + lot + level) → เมื่อราคาเด้งกลับมาที่จุดเดิม จะออกออเดอร์ทดแทนขนาดเท่าเดิม โดย:
- ออกเฉพาะในช่องว่าง (anti-overlap กับออเดอร์ที่ยังเปิดอยู่)
- ทำงานคู่ขนานกับ grid logic เดิม (ราคาเลยไปอีกแล้ว condition ครบ → grid ปกติยังเปิดเพิ่มได้)

## Inputs ใหม่ (group "=== Per-Order Trailing Stop ===")
```cpp
input bool EnableGridRefill        = false; // master toggle (default OFF)
input bool GridRefill_GL           = true;
input bool GridRefill_GP           = true;
input int  GridRefill_TolerancePts = 50;    // points
input int  GridRefill_MaxSlots     = 20;    // per side cap
input int  GridRefill_ExpireMin    = 0;     // 0 = never expire
```

## Globals
```cpp
struct GridRefillSlot { ulong ticket; double price; double lots;
                        long side; string kind; int level;
                        datetime closedAt; bool active; };
GridRefillSlot g_refillSlots[];
ulong g_trackedTickets[]; double g_trackedPrices[]; double g_trackedLots[];
long  g_trackedSides[];   string g_trackedKinds[];  int g_trackedLevels[];
datetime g_lastRefillCleanup;
```

## Flow
1. **OnTick** → `RefillScanAndDetectCloses()` — สแกน open GL/GP ของ generation ปัจจุบัน, diff กับ tracked buffer ของ tick ก่อน → ที่หายไป = ปิดแล้ว → push เข้า `g_refillSlots[]`
2. **CheckGridLoss/CheckGridProfit** → เรียก `TryRefillGridSlot(side, "GL"/"GP")` ก่อน MaxTrades gate (refill ทำงานได้แม้ grid ครบแล้ว)
3. **TryRefillGridSlot** — กรอง side+kind+active → เช็ค `|curPrice - slot.price| <= tolerance` → anti-overlap (ไม่มีออเดอร์ฝั่งเดียวกันใกล้ slot.price) → `OpenOrder()` ด้วย slot.lots และ comment `prefix_(GL|GP)#level` → mark `slot.active=false`
4. **ResetTrailingStateBuy/Sell (v6.84)** → เรียก `RefillResetSide(side)` เพื่อล้าง slots เมื่อ Avg Trailing ปิดทั้งฝั่ง
5. **Cleanup** ทุก 30s → ลบ inactive/expired slots

## Dashboard
แถวใหม่ "Refill Slots: B:n S:n" (เหลือง=มี / เขียว=ว่าง) แสดงเฉพาะเมื่อ `EnableGridRefill=true`

## ✅ ไม่กระทบ trading logic
- ไม่แตะ `OrderSend / trade.Buy/Sell/PositionClose/PositionModify`
- ไม่แตะ math ของ ManagePerOrderTrailing / ManageTrailingStop / ApplyTrailingSL / SyncBrokerTPSL
- ไม่แตะ CheckGridLoss/Profit logic เดิม (distance / lot calc / candle filter / signal filter)
- ไม่แตะ Hedge / Triple-Gate / DD% / Squeeze / Accumulate / Recovery / Match Close
- ไม่แตะ License / News / Time filter / Sync
- เคารพ `g_newOrderBlocked`, `MaxOpenOrders`, hedge pause (ผ่าน OpenOrder guards)
- Default `EnableGridRefill=false` → พฤติกรรม v6.85 100%

## ✅ ครอบคลุม
- Per-Order Trailing closes (broker SL hit) ✓
- Breakeven closes (broker SL hit at BE) ✓
- Generation ปัจจุบันเท่านั้น (gen เก่า/orphan ไม่ถูก track)
- เฉพาะ single-TF mode (CheckGridLoss/CheckGridProfit) — MTF (CheckGridLossTF/CheckGridProfitTF) ยังไม่ผูก hook (รอ feedback)
