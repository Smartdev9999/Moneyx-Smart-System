
# Gold Miner EA v6.86 — Grid Refill After Trailing Close

ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

## เป้าหมาย
เมื่อ **Per-Order Trailing Stop / Breakeven** ปิด grid order (GL หรือ GP) ออกไป แล้วราคา **เด้งกลับมาที่จุดเดิม** ระบบจะ **เปิดออเดอร์ใหม่ทดแทน** ที่จุดเดิม ด้วยขนาด lot เท่าเดิม โดยจะออกเฉพาะใน "ช่องว่าง" ที่ออเดอร์เคยอยู่ — ไม่ออกซ้อนกับออเดอร์ที่ยังเปิดค้างอยู่ ถ้าราคาวิ่งเลยออเดอร์ที่มีอยู่ขึ้นไปอีกแล้วเข้าเงื่อนไข grid ปกติ ก็จะเปิดเพิ่มตามปกติ

## Inputs ใหม่ (group "=== Per-Order Trailing Stop ===")
```cpp
input bool   EnableGridRefill        = false; // Enable Grid Refill after trailing close
input bool   GridRefill_GL           = true;  // Refill Grid Loss orders
input bool   GridRefill_GP           = true;  // Refill Grid Profit orders
input int    GridRefill_TolerancePts = 50;    // Price tolerance to consider "back to closed price" (points)
input int    GridRefill_MaxSlots     = 20;    // Max remembered closed slots per side
input int    GridRefill_ExpireMin    = 0;     // Expire slot after N minutes (0=never)
```
ค่า default = `false` → ปิดทุก .set ที่มีอยู่ทำงานเหมือน v6.85 100%

## โครงสร้างข้อมูล (global)
```cpp
struct ClosedSlot {
   double   price;       // ราคาที่ออเดอร์ปิดไป
   double   lots;        // lot ขนาดเดิม
   long     side;        // POSITION_TYPE_BUY / SELL
   string   kind;        // "GL" หรือ "GP"
   int      level;       // grid level เดิม (สำหรับ comment)
   datetime closedAt;
   bool     active;      // ใช้ flag เพื่อ "consume" เมื่อ refill แล้ว
};
ClosedSlot g_closedSlots[];   // dynamic array, cap = GridRefill_MaxSlots*2
```

## จุด hook (5 จุด)
1. **`ManagePerOrderTrailing()`** — ก่อน `trade.PositionModify` ที่ตั้ง trailing SL ใหม่ → เก็บ snapshot ของ ticket (price/lot/comment) ลง buffer ชั่วคราว `g_pendingTrailTickets[]`
2. **`OnTradeTransaction`** (หรือ scan ใน `OnTick` ก่อน grid logic) — ตรวจหา ticket ที่อยู่ใน buffer แต่ไม่อยู่ใน `PositionsTotal()` แล้ว → คัดเฉพาะที่ comment เป็น `_GL#n` หรือ `_GP#n` → push เข้า `g_closedSlots[]` พร้อม side/kind/level/lots/openPrice/datetime
3. **`CheckGridLoss()` / `CheckGridProfit()`** — ก่อน return เพราะ `currentGridCount >= MaxTrades` ให้เรียก `TryRefillGridSlot(side, "GL"/"GP")` ก่อน เพื่อให้ refill ทำงานได้แม้ MaxTrades ครบแล้ว
4. **`TryRefillGridSlot()`** ฟังก์ชันใหม่ — สแกน `g_closedSlots[]` ตาม side+kind:
   - กรอง slot ที่ `active=true` และยังไม่ expire
   - เช็คว่า currentPrice อยู่ในระยะ `±GridRefill_TolerancePts` ของ `slot.price`
   - **กันออเดอร์ซ้อน**: เช็คว่าไม่มีออเดอร์ฝั่งเดียวกันที่ยังเปิดอยู่ในระยะ tolerance รอบ slot.price (สแกน `PositionsTotal` ตาม magic+symbol+side, exclude bound)
   - ถ้าผ่าน → `OpenOrder(...)` ด้วย `slot.lots` และ comment `prefix_GL#level` (reuse level เดิม) → mark `slot.active=false`
5. **Cleanup ใน `OnTick`** — ลบ slot ที่ expired หรือ inactive (compact array) ทุก ~30s

## กฎสำคัญ (กันชน trading logic เดิม)
- ทำงานเฉพาะเมื่อ `EnableGridRefill=true` AND (`EnablePerOrderTrailing=true` OR `InpEnableBreakeven=true`)
- **ไม่แตะ `OpenOrder()`** — เรียกผ่านอินเทอร์เฟซเดิม
- Refill ใช้ลำดับ generation ปัจจุบัน (`GetCommentPrefix()`) เท่านั้น
- เคารพ `g_newOrderBlocked`, `g_squeezeBuyBlocked/Sell`, hedge pause, `NormalOrderCount() < MaxOpenOrders`
- ไม่สนใจ `OnlyNewCandle/CandleConfirm/DontSameCandle` — เพราะ refill ไม่ใช่ grid ใหม่ แต่เป็นการ "เติมช่องว่าง"
- ถ้า side มี hedge active หรือ generation ปิดไปแล้ว → ล้าง slots ทั้งฝั่งนั้นทันที (ผ่าน per-side reset hook ที่ `ResetTrailingStateBuy/Sell` v6.84)

## Dashboard (เพิ่ม 1 แถวเมื่อ EnableGridRefill=true)
```
Refill Slots:  B:2  S:0   (green/yellow)
```

## Versioning
- v6.85 → **v6.86**
- update: `#property version "6.86"`, `#property description "Grid Refill: re-open GL/GP at price levels closed by Per-Order Trailing"`
- header comment block, OnInit/OnDeinit log, Dashboard `headerVersion="v6.86"`

## Memory file ใหม่
`mem://trading/gold-miner-ea/grid-refill-after-trailing-v6-86.md` (type: feature)

---

## ✅ สิ่งที่ไม่เปลี่ยนแปลง (ยืนยันไม่กระทบ trading logic)
- ❌ ไม่แตะ `OrderSend` / `trade.Buy` / `trade.Sell` / `trade.PositionClose` / `trade.PositionModify`
- ❌ ไม่แตะ `ManagePerOrderTrailing` math (BE / Trailing / Step) — แค่ snapshot ticket ก่อน close
- ❌ ไม่แตะ `ManageTrailingStop` (Average Trailing v6.84/v6.85)
- ❌ ไม่แตะ `ApplyTrailingSL` / `SyncBrokerTPSL`
- ❌ ไม่แตะ `CheckGridLoss/Profit` ตรรกะการนับ distance / lot calc / candle filter — แค่เพิ่ม `TryRefillGridSlot()` call ที่หัวฟังก์ชัน
- ❌ ไม่แตะ Hedge / Triple-Gate / DD% / Squeeze / Accumulate / Recovery / Match Close
- ❌ ไม่แตะ License / News / Time filter / Sync
- ❌ ไม่แตะ throttle v6.83 / per-side reset v6.84 / SyncBrokerTPSL guard v6.85
- ✅ default `EnableGridRefill=false` → ทุก .set เดิมพฤติกรรม v6.85 100%
