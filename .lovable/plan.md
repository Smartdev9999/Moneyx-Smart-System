## ปัญหา
User ตั้ง `InpHedgeDisarmPercent = 70%` คาดว่าเมื่อ DD% ของกลุ่ม hedging target ต่ำกว่า 70 → ระบบต้องลบ pending hedge ทั้งหมด แต่พบว่ายังมี pending ค้าง

## Root Cause (จากการอ่าน `ManageGroupHedgeArm` line 2022-2126)
Disarm block ปัจจุบัน (line 2063-2080) มี guard:
```cpp
if(!hedgePosExists && hedgePendingExists){   // ← จะทำงานเฉพาะตอนยังไม่มี hedge filled เลย
   ...
   if(ddRecovered || noLossSide || noMainPos){ DeleteGroupPendings(g, 1); return; }
}
```
ถ้า hedge ladder ติด **บางส่วน** (เช่น price spike ปลุก HD#1 แล้วเด้งกลับ) → `hedgePosExists=true` → โค้ดข้ามไป stale-side sweep block (line 2085-2109) ซึ่ง **ลบเฉพาะ pending ฝั่งตรงข้าม** เท่านั้น ไม่ลบ pending ฝั่งเดียวกับ hedge ที่เหลือ ทำให้ pending ค้างถึงแม้ DD จะลดต่ำกว่า disarm% แล้ว

นอกจากนี้ยังไม่มี log ให้ debug ว่า pct เท่าไหร่/เข้าเงื่อนไขไหน — user ตรวจสอบไม่ได้

## แผนแก้ v2.9.3 — Partial-Fill Disarm + Diagnostic

### A) ขยาย Disarm ให้ครอบคลุม partial-fill (แก้ `ManageGroupHedgeArm` ~line 2080-2108)
ก่อนเข้า stale-side sweep ของ `hedgePosExists`: เพิ่มเงื่อนไขลบ pending ฝั่ง hedge ที่เหลือเมื่อ DD ต่ำกว่า disarm%
```cpp
if(hedgePosExists){
   bool ddRecovered = (pct < InpHedgeDisarmPercent);
   if(ddRecovered && hedgePendingExists){
      // ลบเฉพาะ pending (ไม่แตะ position ที่ filled แล้ว)
      DeleteGroupPendings(g, 1);
      if(g_verboseEffective)
         PrintFormat("Golden2 v2.9.3: HD DISARM(partial-fill) G%d pct=%.1f<%.1f — kept %d filled HD pos",
                     g, pct, InpHedgeDisarmPercent, CountGroupPositions(g,-1,1));
      // ตกลงไปต่อเพื่อทำ stale-side sweep ตามเดิม
   }
   // (โค้ดเดิม) stale opposite-side sweep ...
   return;
}
```
**ไม่แตะ:** ตำแหน่ง hedge ที่ filled แล้ว, การปิด position, Triple-Gate, Recovery, MirrorLossSideToHedgePendings, PlaceHedgePendingSet

### B) Diagnostic log ของ disarm (verbose)
เพิ่ม PrintFormat ใน disarm path ของ `!hedgePosExists` (line ~2063) เพื่อให้เห็น pct ทุกครั้งที่ผ่าน (ไม่ใช่เฉพาะตอน trigger):
```cpp
if(g_verboseEffective)
   PrintFormat("Golden2 v2.9.3: HD DISARM-CHK G%d pct=%.1f arm=%.1f disarm=%.1f hPend=%d hPos=%d lossSide=%d",
               g, pct, InpHedgeArmPercent, InpHedgeDisarmPercent,
               CountGroupPendingsByTagPrefix(g,true,""), CountGroupPositions(g,-1,1), GroupLossSide(g));
```
ใช้ throttle 10s ต่อกลุ่ม (เพิ่ม `g_lastDisarmChkLog[g]`) เพื่อไม่ท่วม log

### C) Version + memory
- `#property version "2.93"` + description
- Header banner / Dashboard title / Init log → `Golden2 EA v2.9.3`
- Init log เพิ่ม: `DisarmPartialFill=ON`
- สร้าง `.lovable/memory/trading/golden2-ea/v2-9-3-disarm-partial-fill.md`
- อัปเดต `.lovable/memory/index.md`

## สิ่งที่ไม่เปลี่ยน (Rules of Steel)
- ❌ `trade.Buy/Sell/PositionClose/OrderSend/OrderModify/BuyStop/SellStop` (ใช้เฉพาะ `trade.OrderDelete` กับ `DeleteGroupPendings` ที่มีอยู่)
- ❌ Entry / Grid / Hedge **arm** logic (DD%, ArmPercent, BlockNewOrderPercent, delay)
- ❌ MirrorLossSideToHedgePendings, PlaceHedgePendingSet
- ❌ One-Hedge-Per-Group (v2.8.5), Stale-side sweep (v2.9.2), Hedge-Used Advance Bypass (v2.9.2)
- ❌ Triple-Gate / Recovery Grid / Seed Lock / Post-Match Avg TP/SL
- ❌ License / News / Time / Sync / Dashboard layout
- ❌ ParseComment / MakeComment

## ไฟล์ที่จะแก้
- `public/docs/mql5/Golden2_EA.mq5` (~15 บรรทัด: เพิ่ม disarm branch + diagnostic + version)
- `.lovable/memory/trading/golden2-ea/v2-9-3-disarm-partial-fill.md` (สร้างใหม่)
- `.lovable/memory/index.md` (อัปเดต)

## ผลที่คาดหวัง
- เมื่อ hedge ladder ติดบางส่วนแล้ว DD ลดต่ำกว่า 70% → pending ที่เหลือถูกลบทันที (position ที่ filled แล้วยังอยู่ ให้ Triple-Gate/Recovery จัดการ)
- Verbose log แสดง pct vs threshold ทุก 10 วินาที/กลุ่ม ให้ debug ได้ว่าทำไม disarm ไม่ trigger
