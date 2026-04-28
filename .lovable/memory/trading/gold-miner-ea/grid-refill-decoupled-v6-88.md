---
name: Gold Miner EA v6.88 — Grid Refill Decoupled
description: v6.88 fixes Grid Refill not firing by adding ManageGridRefill() that runs every tick in OnTick independent of CheckGridLoss/Profit grid gates (MaxTrades, buyCount==0, etc). Preserves original level number on refill so re-opened orders fill the gap with the SAME comment level. Adds verbose throttled logs for every reject reason (MaxOpenOrders, g_newOrderBlocked, overlap, OpenOrder failed).
type: feature
---

# Gold Miner EA v6.88 — Grid Refill Decoupled

ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

## ปัญหา v6.87
Refill ยังไม่ทำงาน เพราะ `TryRefillGridSlot()` ถูกเรียกแค่ใน `CheckGridLoss/Profit()` ซึ่งถูก gate โดย `gridCount<MaxTrades`, `buyCount>0`, ฯลฯ ใน `OnTick` → ถ้ากริดเต็มหรือไม่มีออเดอร์ฝั่งนั้น refill ไม่ถูกเรียก

## การแก้ไข
1. **`ManageGridRefill()`** — ฟังก์ชันใหม่ใน OnTick หลัง `RefillScanAndDetectCloses()` รัน refill โดยตรงโดยไม่ผ่าน gate ของ `CheckGridLoss/Profit`
2. **Preserve original level**: `useLvl = (lvl > 0) ? lvl : maxLvl+1` (ไม่ bump เป็นเลขใหม่ถ้ามี level เดิม) → comment refilled = comment เดิมที่หายไป
3. **Verbose reject logs** (throttled 30s): MaxOpenOrders, g_newOrderBlocked, overlap, OpenOrder failed
4. **Version bump** v6.87 → v6.88 ทุกจุด (header, #property, OnInit/Deinit, Dashboard)

## ไม่กระทบ
- ไม่แตะ Order Execution, BE/Trailing, Grid math, TP/SL, Hedge, Triple-Gate, Recovery, License, News
- Default `EnableGridRefill=false` — backward compatible 100%
