# Hero Order v7.01 → v7.02

## บั๊กที่พบจากภาพ + คำอธิบาย

### บั๊กที่ 1 — BE_GUARD แสดงผล แต่ไม่มี SL กันทุนจริงบน ticket
ภาพ MT5 ยืนยันชัด: Hero BUY #254 / #253 / #251 ต่างมี `S/L = 0.00` แม้ dashboard ขึ้น `BE_GUARD`

**Root cause** (`ValidateHeroLockProfitSL` line 2552 ใน `Gold_Miner_EA.mq5`):

```cpp
// SELL → SL ที่ถูกต้องต้อง > ask + stops (เพราะ SELL ปิดที่ ask)
//        แต่โค้ดเช็ค sl < ask - minDist  ← INVERTED
if(posType == POSITION_TYPE_SELL)
   return (sl > 0 && sl < (ask - minDist) && sl < ask);

// BUY → SL ที่ถูกต้องต้อง < bid - stops (เพราะ BUY ปิดที่ bid)
//       แต่โค้ดเช็ค sl > bid + minDist  ← INVERTED
if(posType == POSITION_TYPE_BUY)
   return (sl > 0 && sl > (bid + minDist) && sl > bid);
```

ผลคือ `ValidateHeroLockProfitSL` คืน `false` เกือบทุกครั้ง → `skipped++` → `PositionModify` ไม่ถูกเรียก → SL=0 ตลอด ทั้งที่ phase ขึ้น BE_GUARD แล้ว

### บั๊กที่ 2 — ฝั่งตรงข้ามปิดด้วย Broker TP แล้ว Hero ไม่ปิดตาม
`CloseOppositeHeroOnBasketClose` ถูกเรียกจาก `CloseAllSide` / `CloseGenSide` / `CloseAllSideTF` เท่านั้น แต่เมื่อ basket ฝั่งตรงข้ามปิดด้วย **Broker TP รายตัว** (ไม่ผ่านโค้ด EA) hook นี้ไม่ถูกยิง → Hero ติด BE_GUARD ค้างจนกว่าราคาจะมาแตะ SL กันทุน (ซึ่งบั๊ก 1 ทำให้ SL ไม่มีอยู่จริง วนกัน)

## สิ่งที่จะแก้ใน v7.02

### 1. Fix `ValidateHeroLockProfitSL` — สลับเงื่อนไขให้ถูก
```cpp
// SELL Hero: lock-profit SL อยู่ใต้ openPrice แต่ต้อง > ask + stops
if(posType == POSITION_TYPE_SELL)
   return (sl > 0 && sl > (ask + minDist));

// BUY Hero: lock-profit SL อยู่เหนือ openPrice แต่ต้อง < bid - stops
if(posType == POSITION_TYPE_BUY)
   return (sl > 0 && sl < (bid - minDist));
```

### 2. เพิ่ม tick-based opposite-clear detector
ใน `ManageHeroOppositeClose()` เพิ่มลูป per side หลัง BE_GUARD retry:

```cpp
// v7.02: ตรวจทุก tick ว่าฝั่งตรงข้าม non-Hero basket = 0 แล้วหรือยัง
// ครอบคลุมเคสที่ basket ฝั่งตรงข้ามถูกปิดด้วย Broker TP/SL/SLTP รายตัว
for(int s = 0; s < 2; s++) {
   ENUM_POSITION_TYPE side = (s == 0) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
   ENUM_POSITION_TYPE opp  = (s == 0) ? POSITION_TYPE_SELL : POSITION_TYPE_BUY;
   int phase = (side == POSITION_TYPE_BUY) ? g_heroPhase_Buy : g_heroPhase_Sell;
   if(phase != 3 /*BE_GUARD*/) continue;
   if(CountHeroOnSide(side) <= 0) continue;
   if(CountNonHeroMainOnSide(opp) > 0) continue;          // opposite basket ยังอยู่
   if(CountHeroOnSide(opp) > 0) continue;                  // ปลอดภัย: ห้ามปิดถ้า opp ยังมี Hero
   Print("v7.02 Hero CLOSE (opp basket flat detected): heroSide=", EnumToString(side));
   CloseHeroOnSide(side, "OppositeBasketFlatTick");
}
```

### 3. ลำดับใน `ManageHeroOppositeClose` ป้องกัน Strip ทับ SL ใน tick เดียวกับ BE_GUARD transition
ย้าย `StripBrokerTPSLFromHeroTickets()` ลงไปท้ายลูป หรือเช็คว่า side นั้นกำลัง transition อยู่ใน tick นี้แล้ว skip Strip ของ side นั้น (ป้องกัน race condition ระดับ tick — แม้ฟังก์ชัน Strip จะ skip phase==3 อยู่แล้ว)

### 4. Audit log ชัดขึ้น
- log ทุกครั้งที่ `ValidateHeroLockProfitSL` skip พร้อมเหตุผล (SL value, bid/ask, stopsLevel) เพื่อ debug ในอนาคต
- log `v7.02 Hero CLOSE (opp basket flat detected)` แยกจาก `OppositeBasketClose` เดิม (ที่ผ่าน CloseAllSide hook)

### 5. Version bump 7.01 → 7.02
- `#property version "7.02"`
- `#property description` อธิบายว่า fix lock-profit SL validation + tick-based opp-clear close
- header comment block
- dashboard `headerVersion`
- log prefix

## สิ่งที่ไม่เปลี่ยนแปลง

- ไม่แตะ `OrderSend` / `trade.Buy` / `trade.Sell` / `trade.PositionClose` execution
- ไม่แตะ entry: SMA / EMA / ZigZag / BB / Squeeze / Z-Score
- ไม่แตะ Grid Loss / Grid Profit lot / distance / candle confirm
- ไม่แตะ Hedge / Triple-Gate / Matching Close / Recovery / Auto Recovery
- ไม่แตะสูตร Average TP / Average Trailing
- ไม่แตะ DD% TP / Daily Target / Balance Guard
- ไม่แตะ License / News / Time / Sync
- ไม่แตะ `BuildHeroTicketCache` (Sticky Tag v7.01 ยังเดิม)
- ไม่แตะ `CloseOppositeHeroOnBasketClose` hook ใน `CloseAllSide` / `CloseGenSide` / `CloseAllSideTF` (แค่เพิ่ม path ขนานทาง tick)
- ไม่แตะ `ComputeHeroLockProfitSL` formula (`open ± InpHero_BE_OffsetPoints`)
- ไม่แตะ `IsHeroTicket` exclusion ในทุก trailing/SyncBrokerTPSL

## ผลลัพธ์ที่คาดหวัง

1. หลังเข้า BE_GUARD → Hero ทุกตัวจะมี `S/L` ปรากฏบนตั๋วจริงในตาราง MT5 (lock-profit ใต้/เหนือ open)
2. เมื่อ basket ฝั่งตรงข้ามถูกปิดด้วย Broker TP รายตัว → ภายใน 1 tick ถัดมา Hero ฝั่งนี้จะปิดอัตโนมัติ พร้อม log `OppositeBasketFlatTick`
3. ถ้าราคาย้อนกลับมาชน lock-profit SL ก่อน → Broker จะปิดให้ พร้อม log `v7.00 Hero CLOSED reason=LockProfitSL_HIT`
