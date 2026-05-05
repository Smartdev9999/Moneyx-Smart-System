
# Golden Kuy3 v1.42 — Accumulate cycle reset (Gold Miner concept)

## ปัญหา (จาก log + screenshot)
```
GK ACCUM CLOSE — realized=20008.26 floating=-6.31 tgt=20000.0
```
ปัจจุบันมีแค่ 2 ออเดอร์ floating รวม -20.80 USD แต่ยังโดนปิด
สาเหตุ: `g_realizedCycle` **ไม่เคยถูกรีเซ็ต** หลังรอบจบ → สะสมข้ามรอบไปจนแตะ target แล้วก็ทริกตลอด

### หลักฐานในโค้ด (line 1446-1452)
```cpp
if(CountSideSimple(BUY)==0 && CountSideSimple(SELL)==0){
   if(MathAbs(g_realizedCycle) > 0.0 && trans.type==TRADE_TRANSACTION_DEAL_ADD){
      // keep g_realizedCycle visible until next entry; reset on next OpenInitial cycle
   }   ← block ว่าง / `OpenInitial` ก็ไม่ได้รีเซ็ต
}
```

## คอนเซ็ปต์ Gold Miner ที่จะ port มา
- ตอน flat (ไม่มี position ใดๆ ของ EA) → **รีเซ็ต** `g_realizedCycle = 0` ทันที
- ครั้งต่อไปเริ่มนับ realized ใหม่จาก 0
- ภาพเดียวกับ Gold Miner v6 ที่ใช้ baseline แบบ recompute

---

## สิ่งที่จะแก้ (เฉพาะ accumulate cycle reset — ไม่แตะอย่างอื่น)

### A. เพิ่มฟังก์ชัน reset
```cpp
void TryResetAccumulateCycleIfFlat()
{
   // เช็คทุก position ของเรา (รวม Hero) — flat = ไม่มีอะไรของ EA
   if(CountSideSimple(POSITION_TYPE_BUY)==0 && CountSideSimple(POSITION_TYPE_SELL)==0){
      if(MathAbs(g_realizedCycle) > 0.0001){
         Print("GK ACCUM CYCLE RESET — flat detected. prev realized=",
               DoubleToString(g_realizedCycle,2));
         g_realizedCycle = 0.0;
      }
   }
}
```

### B. เรียก 2 จุด (เพื่อความชัวร์)
1. **`OnTick()`** — เพิ่มเป็นบรรทัดแรกสุด (ก่อน `BuildHeroTicketCache`):
   ```cpp
   TryResetAccumulateCycleIfFlat();   // v1.42 — Gold Miner cycle reset
   ```
2. **`OnTradeTransaction()`** — แทนที่ block ว่างที่ line 1446-1452:
   ```cpp
   if(trans.type==TRADE_TRANSACTION_DEAL_ADD){
      TryResetAccumulateCycleIfFlat();
   }
   ```
ทั้งสองจุดเรียกฟังก์ชันเดียวกัน → idempotent ปลอดภัย

### C. Dashboard
แถว `Realized (cycle)` (line 1288) ตอนนี้แสดง `g_realizedCycle` อยู่แล้ว → จะกลายเป็น $0.00 ทันทีหลัง flat → ผู้ใช้เห็นชัดว่ารีเซ็ตแล้ว
เพิ่มแถวใหม่ใต้ Accumulate ใน dashboard (แถวเดียว):
```
Accum Pool      $19.50 / $20000     (= realized + floating non-Hero current)
```

### D. ไม่แตะอะไรอีก
- โครง `ManageTakeProfit` เดิม (master gate, AvgTP push, FixedDollar, %Bal) — เก็บไว้ตามเดิมทั้งหมด
- `CalcSideFloating_NonHero` / `CloseAllOurs` skip-Hero — เก็บเดิม (พี่ไม่อนุมัติแผนก่อนหน้า)
- Hero v1.4 ทุกฟังก์ชัน — ไม่แตะ

---

## Version
- `#property version "1.42"`
- `#property description` → "Accumulate cycle auto-reset on flat (Gold Miner concept)"
- Header + Dashboard title → `Golden Kuy3 v1.42`

## ไม่เปลี่ยน (กฎเหล็ก .mq5)
- ไม่แตะ `OrderSend` / `trade.Buy/Sell/PositionClose/PositionModify`
- ไม่แตะ Entry / Grid distance / `CalcGridLot` / Cost-Hit core
- ไม่แตะ Per-Order BE/Trail / Avg-Trail (strict 2-cross)
- ไม่แตะ TP modes (FixedDollar / AvgTP push / %Bal) — ทำงานเหมือนเดิมทุกบรรทัด
- ไม่แตะ Hero v1.4: BuildHeroTicketCache, ManageHeroOppositeClose, BE-Lock SL, Single-Side Lock, sticky tag, Post-Close Grace
- ไม่มี License / News / Sync / Hedge / Squeeze

## ไฟล์ที่จะแก้
- `public/docs/mql5/Golden_Kuy3_EA.mq5` (1531 → ~1545 บรรทัด, v1.41 → v1.42)
- สร้าง `.lovable/memory/trading/golden-kuy3/v1-42-accum-cycle-reset.md`
- อัปเดต `mem://index.md`

ยืนยันแผนนี้ไหมครับ? (สรุป: เพิ่ม `TryResetAccumulateCycleIfFlat()` เรียกทั้ง OnTick + OnTradeTransaction → realized=0 ทันทีตอน flat → Accumulate target นับใหม่ทุกรอบเหมือน Gold Miner)
