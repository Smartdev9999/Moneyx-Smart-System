## วิเคราะห์ปัญหา

### ปัญหา 1 — Hedge pending ค้างหลัง main ปิด TP ก่อนราคาชน
จาก screenshot: G3 มี `G3_B_HD_IN / G3_B_HD_GL#2..#8` (BUY_STOP hedge pendings) ค้างอยู่ 8 ไม้ ทั้งที่ G3 ไม่มี position เลย → ราคาเดิม G3 มี SELL main (ฝั่ง loss) → ระบบ arm BUY hedge pendings ที่ราคา 3290.80 → ราคาเด้งกลับ → SELL main ปิด TP ก่อน → เหลือแต่ BUY_STOP pendings ค้าง

ตรวจ flow:
- `g_groupHedgeUsed[3]` = **false** (hedge ไม่เคย fill เป็น position จริง — เป็นแค่ pending)
- v2.9.2 full-sweep ที่บรรทัด ~4194 ต้องการ `g_groupHedgeUsed[g]==true` → **ไม่ทำงาน**
- Disarm ใน `ManageGroupHedgeArm` ที่บรรทัด 2106 ควรจะลบได้ (noMainPos=true, lossSide=-1, pct=0) แต่ผู้ใช้ยืนยันว่าไม่ลบ
- ผลลัพธ์: G3 มี pending ค้าง → `IsPriorGroupSafeForAdvance(3)` คืน `reason=5 block-pending-only` → freeze advance queue ทั้งระบบ → ไม่มีออเดอร์ใหม่ออก

**Fix**: เพิ่ม unconditional sweep ที่ต้นของ group loop — ถ้า `!hasPos && hedgePendings>0` ลบทันที โดยไม่พึ่ง flag ใดๆ (มาก่อน ManageGroupHedgeArm) เพื่อกัน edge case ที่ flag tracking ผิดพลาดและกัน main pending ไม่ให้ถูกแตะ (filter=1 = hedge only)

### ปัญหา 2 — Max DD Close ไม่ทำงานถึงค่าที่ตั้ง
ตรวจ `ManageMaxDDClose()` (line 4038-4078) — logic ถูกต้อง แต่มี 2 ข้อบกพร่อง:

1. **ถูก gate ด้วย `if(!InpAllowTrade) return;` (บรรทัด 4102)** ก่อนเรียก `ManageMaxDDClose()` (บรรทัด 4104) — ถ้าผู้ใช้ปิด AutoTrading ของ EA หรือ terminal, kill switch จะ**ไม่ทำงาน**ตามไปด้วย ซึ่งขัดแย้งกับเจตนาของ "kill switch" ที่ต้องทำงานตลอดเวลา
2. **ไม่มี diagnostic log** — ผู้ใช้ไม่รู้ว่า EA คำนวณ floating loss ได้เท่าไรเทียบ threshold, ไม่สามารถ debug ว่าทำไมไม่ trigger
3. **POSITION_PROFIT ไม่รวม commission** — บาง broker จะมี commission แยก ทำให้ค่าที่ EA คำนวณต่ำกว่าที่ MT5 แสดงใน toolbar (e.g. ตอน screenshot floating ~-$171k แต่ threshold ตั้งไว้ $2,500,000 → ห่างกันมากจริง — แต่เพื่อให้ผู้ใช้เห็นชัดต้องมี log)

**Fix**:
- ย้าย `ManageMaxDDClose()` ไป**ก่อน** `if(!InpAllowTrade)` guard
- เพิ่ม periodic verbose log ทุก 30s แสดง `cur=$X (%.2f%%) threshold=$Y`
- (ทางเลือก) บวก `AccountInfoDouble(ACCOUNT_PROFIT)` parity check ใน log เพื่อให้ผู้ใช้เห็นทั้ง 2 ค่าและรู้ว่าควรตั้ง threshold เท่าไร

## v2.9.5 — สิ่งที่จะแก้

ไฟล์: `public/docs/mql5/Golden2_EA.mq5` (ทุกที่ตามรายการ Rules of Steel ไม่ถูกแตะ)

### Fix A: Stranded Hedge-Pending Sweep (ปัญหา 1)
ใน `OnTick` group loop หลังคำนวณ `hasPos/hasPend` (ก่อน `if(!hasPos && !hasPend)` flat-branch):

```cpp
// [v2.9.5] Stranded hedge-pending sweep — symmetric safety net
//   ถ้า group ไม่มี position ใดๆ (main + hedge = 0) แต่ยังมี hedge pending
//   ค้างอยู่ → ลบทิ้งทันที โดยไม่พึ่ง g_groupHedgeUsed flag.
//   ครอบคลุม edge case: main TP ก่อนราคาชน hedge pending → pendings ค้าง
//   → IsPriorGroupSafeForAdvance คืน block-pending-only → freeze advance queue
if(!hasPos && hasPend){
   if(CountGroupPendingsByTagPrefix(g, true, "") > 0){
      DeleteGroupPendings(g, 1);
      if(g_verboseEffective)
         PrintFormat("Golden2 v2.9.5: G%d stranded HD-pending sweep (no positions)", g);
   }
}
```

Main pendings (G_IN waiting fill) ไม่ถูกแตะเพราะ `DeleteGroupPendings(g, 1)` กรอง `hedgeFilter==1`.

### Fix B: Max DD Always-On + Diagnostic (ปัญหา 2)

1. ย้าย `ManageMaxDDClose()` ขึ้นไปก่อน `if(!InpAllowTrade)` guard (ให้ทำงานตลอดแม้ AutoTrade ปิด)
2. เพิ่ม global `datetime g_lastMaxDDLog = 0;` และ throttled log:

```cpp
// [v2.9.5] Diagnostic — periodic Max DD status log (every 30s)
if(g_verboseEffective && TimeCurrent() - g_lastMaxDDLog >= 30){
   g_lastMaxDDLog = TimeCurrent();
   double acctFloat = AccountInfoDouble(ACCOUNT_PROFIT);
   PrintFormat("Golden2 v2.9.5: MAX-DD-CHK mode=%s curEA=$%.2f (%.2f%%) threshold=%s%.2f bal=$%.2f acctFloat=$%.2f",
      (InpMaxDDMode==G2_DD_OFF?"OFF":(InpMaxDDMode==G2_DD_PERCENT?"PERCENT":"DOLLAR")),
      absDD, pct,
      (InpMaxDDMode==G2_DD_PERCENT?"%":"$"), InpMaxDDValue,
      bal, acctFloat);
}
```

วาง log นี้**ก่อน** `if(!trig) return;` เพื่อให้รันทุก check รอบ (เห็นทั้ง trig และ no-trig).

### Fix C: Metadata + Documentation
- `#property version "2.95"` + description ใหม่
- Header banner / Dashboard title / Init log → v2.9.5
- Init log เพิ่ม `StrandedHDPendingSweep=ON | MaxDDAlwaysOn=ON`
- สร้าง `.lovable/memory/trading/golden2-ea/v2-9-5-stranded-hd-pending-and-maxdd-always-on.md`
- อัปเดต `.lovable/memory/index.md`

## สิ่งที่ไม่เปลี่ยน (Rules of Steel)
- ❌ `trade.Buy/Sell/PositionClose/OrderSend/OrderModify/BuyStop/SellStop` — ใช้ `DeleteGroupPendings` (มีอยู่แล้ว) และ `trade.PositionClose/OrderDelete` ใน ManageMaxDDClose เดิม
- ❌ Entry SMA/INSTANT/PENDING flow, Grid Loss/Profit, ATR snapshot, candle confirm
- ❌ Hedge **arm** logic (`InpHedgeArmPercent`, BlockNewOrderPercent, delay, ClaimMutex, `PlaceHedgePendingSet`, `MirrorLossSideToHedgePendings`) — เพิ่มเฉพาะ sweep ใหม่ก่อนเข้า ManageGroupHedgeArm
- ❌ One-Hedge-Per-Group (v2.8.5), Hedge Orphan Offset (v2.8.6), Stale-side sweep (v2.9.2), Disarm Partial-Fill (v2.9.3)
- ❌ Triple-Gate (WinPool / MinGain / Reserve-Profit / Squeeze TF3 latch / shred passes)
- ❌ Recovery Grid + Continuation + Seed Lock + Order Lock + Prior Advance Bypass
- ❌ Post-Match Avg TP/SL (v2.8.4), v2.9.1 Backtest Perf Pack
- ❌ Max Lot Caps v2.9.4 (normal + triple-gate)
- ❌ Max DD logic ตัวเอง (เพิ่มเฉพาะตำแหน่งเรียก + log, ไม่แตะสูตร trigger / close loop / 30s cooldown)
- ❌ License / News / Time / Sync / Dashboard layout / ParseComment / MakeComment

## ผลที่คาดหวัง
- G3 ที่มีแต่ hedge pending ค้างจะถูกลบใน tick ถัดไปทันที → `IsPriorGroupSafeForAdvance(3)` เปลี่ยนจาก block-pending-only → safe-flat → advance queue ปลดล็อค → ออกออเดอร์ใหม่ใน G3/G4 ตามปกติ
- Max DD จะ log สถานะทุก 30s ในโหมด verbose ให้ผู้ใช้เห็น `curEA=$X` vs `threshold=$Y` ชัดเจน — แก้ความสับสนเรื่องค่า threshold ที่ตั้งสูงเกิน (เช่น 2,500,000 USD) และตอนนี้ kill switch ยิงได้แม้ AutoTrading ปิด
