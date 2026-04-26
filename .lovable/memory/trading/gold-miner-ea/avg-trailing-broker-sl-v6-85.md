---
name: Gold Miner EA v6.85 — Avg Trailing as Broker SL
description: v6.85 fixes Average Trailing Stop SL not appearing on tickets/charts because SyncBrokerTPSL was overwriting freshly-pushed trailing SL with 0 every ~2s. SyncBrokerTPSL now respects g_trailingSL_Buy/Sell when trailing is active and preserves any existing broker SL when calculated slBuy/slSell would be 0. ApplyTrailingSL also syncs g_lastBrokerSL_Buy/Sell cache after successful modify.
type: feature
---

# Gold Miner EA v6.85 — Average Trailing as Broker SL

ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

## 🐛 บั๊ก
จากภาพ: ทุก ticket แสดง `S/L = 0.00` ทั้งที่ Average Trailing Stop ทำงาน

**Root cause:** `SyncBrokerTPSL()` ทำงานทุก ~2s/ทุก grid order:
- ถ้า `EnableSL=false` หรือ `UseSL_Points=false` หรือ `EnablePerOrderTrailing=false` → `slBuy = 0`
- เรียก `trade.PositionModify(ticket, slBuy=0, tpBuy)` → ลบ broker SL ที่ `ApplyTrailingSL()` เพิ่ง push

## ✅ แก้ไข
### 1. SyncBrokerTPSL respect Avg Trailing
```cpp
double effectiveSlBuy = slBuy;
if(EnableTrailingStop && g_trailingActive_Buy && g_trailingSL_Buy > 0)
   effectiveSlBuy = g_trailingSL_Buy;          // ใช้ trailing SL
else if(slBuy == 0 && curSL > 0)
   effectiveSlBuy = curSL;                      // preserve breakeven SL
```
ทำเหมือนกันฝั่ง SELL ใช้ `g_trailingSL_Sell` / `g_trailingActive_Sell`

### 2. ApplyTrailingSL sync cache
หลัง modify สำเร็จ → set `g_lastBrokerSL_Buy = slPrice` (BUY) หรือ `g_lastBrokerSL_Sell = slPrice` (SELL)

### 3. MTF
ไม่มี `SyncBrokerTPSL_TF` แยก — MTF ใช้ตัวเดียวกัน ครอบคลุมแล้ว

## ผลลัพธ์
- คอลัมน์ S/L บนทุก ticket แสดงราคา trailing SL จริง
- เห็นเส้น broker SL บนชาร์ต
- EA หลุด → broker ปิดให้ตาม SL (failsafe)
- ไม่เพิ่มความถี่ modify (throttle v6.83 ยังคุม)

## ✅ ไม่กระทบ trading logic
- ไม่แตะ OrderSend / trade.Buy / Sell / PositionClose / CloseAllSide
- ไม่แตะสูตร trailing/breakeven ทุกตัว
- ไม่แตะ Hedge / Triple-Gate / DD% / Squeeze / Grid Loss/Profit / Accumulate / Recovery
- ไม่แตะ throttle v6.83 / per-side reset v6.84
- ไม่แตะ ClearBrokerTPSL (bound-only path)
