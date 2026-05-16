## เป้าหมาย
ทำให้ Backtest ของ Golden2 EA เร็วขึ้นอย่างมีนัยสำคัญ และยังคงความแม่นยำ (หรือเพิ่มขึ้น) — โดย **ไม่แตะ Trading Logic / Order Execution / Strategy** ตามกฎเหล็กของโปรเจกต์

---

## วิเคราะห์จุดที่ทำให้ Backtest ช้า (จากการสำรวจไฟล์)

1. **`Print` / `PrintFormat` จำนวนมาก** เมื่อ `InpVerboseLog=true` — log แต่ละบรรทัดใน Tester ช้ามาก (เรียกหลายร้อยครั้งต่อ session)
2. **`HideAuxiliaryTesterCharts()` + `CleanupChartIndicatorsInTester()` ทุก 60 วินาที** ของ TimeCurrent — ใน Tester นาฬิกาเดินเร็ว ทำให้ trigger บ่อยและเรียก ChartIndicatorDelete ทั้ง chart
3. **Dashboard rendering** — แม้มี throttle 1 วินาทีแล้ว แต่ใน tester non-visual ก็ยังเสีย CPU เปล่า ๆ
4. **`DrawAverageAndTPLinesForGroup(g)`** — วาดเส้นบน chart ทุก tick ทุกกลุ่ม (สูงสุด ~50 กลุ่ม)
5. **License `OnTick()` check** — ส่ง WebRequest ใน Tester ไม่มีประโยชน์ ควร bypass สมบูรณ์
6. **News refresh / Sync account data** — เรียก WebRequest ใน Tester ไร้ความหมาย
7. **`MakeComment`/`ParseComment` ParseString ทุก position ทุก tick** — รวมเป็นต้นทุนใหญ่ แต่เลี่ยงยากโดยไม่แตะ logic
8. **ความแม่นยำ**: ผู้ใช้น่าจะรัน "Every tick" หรือ "Every tick based on real ticks" → ช้ามาก แต่ผลลัพธ์ใกล้จริงสุด

---

## แผนการแก้ไข (v2.9.1 — Backtest Performance Pack)

### A) Tester-Aware Throttles & Bypass (ไม่กระทบสด)
ทุกข้อใช้ guard `g_isTesterMode` เพื่อให้ Live trading ทำงานเหมือนเดิม 100%

1. **Silent log ใน Tester**
   - เพิ่ม input `InpTester_SilenceLogs = true` (default ON)
   - สร้าง macro/helper `LOGF(...)` ที่ในโหมด Tester + flag = ON → return ทันที (ไม่เรียก `PrintFormat`)
   - **ไม่แก้** ข้อความหรือเงื่อนไข log เดิม แค่ wrap call
   - คาดผล: เร็วขึ้น 20-40% บนกราฟที่ verbose

2. **Dashboard OFF อัตโนมัติใน Tester non-visual**
   - เพิ่ม input `InpTester_DisableDashboard = true`
   - ใน `RenderDashboardThrottled` ถ้า `g_isTesterMode && !MQLInfoInteger(MQL_VISUAL_MODE) && InpTester_DisableDashboard` → return
   - คาดผล: เร็วขึ้น 5-15%

3. **ปิด Chart Drawing ใน Tester non-visual**
   - เพิ่ม input `InpTester_DisableChartDraw = true`
   - ใน `DrawAverageAndTPLinesForGroup` guard return เมื่อ tester non-visual
   - คาดผล: เร็วขึ้น 5-10% โดยเฉพาะเมื่อมีหลายกลุ่ม

4. **Skip Aux-Chart Sweep หลังครั้งแรกใน Tester non-visual**
   - ครั้งแรกใน OnInit ยังเรียก เพื่อ strip subwindows
   - ใน OnTick ข้าม sweep 60s ถ้า non-visual (ไม่มีจอแสดงผลให้ทำความสะอาด)
   - คาดผล: เร็วขึ้น 3-8%

5. **Bypass License + News + Sync ใน Tester**
   - License: ใน Tester return `LICENSE_VALID` ทันที (มีอยู่บางส่วนแล้ว — ตรวจให้ครบ)
   - News refresh + Sync account data: skip WebRequest ใน Tester
   - คาดผล: ลดความค้างจาก network timeout

6. **Throttle เพิ่มสำหรับ Tester (เลือกใช้)**
   - `InpTester_TickStrideMs = 0` (default 0 = ทุก tick เหมือนเดิม)
   - ถ้าตั้ง > 0 → ใน Tester ข้าม OnTick ที่ห่างจาก tick ก่อนหน้าน้อยกว่าค่านี้ (มิลลิวินาที model time)
   - ใช้เมื่อยอมแลก accuracy เล็กน้อยเพื่อความเร็ว (default OFF เพื่อรักษาความแม่นยำ)

### B) คำแนะนำการตั้งค่า Tester (ในเอกสาร — ไม่แก้โค้ด)
ใส่ในส่วน comment ด้านบนไฟล์ + ใน `.lovable/memory/...` :

- **Modeling**:
  - ความเร็วสูงสุด: `Open prices only` (เหมาะกับ EA ที่ทำงาน new-bar เป็นหลัก — Golden2 ใช้ ATR snapshot/new-bar trail หลายจุด)
  - สมดุล: `1 minute OHLC` — เร็ว + แม่นยำพอใช้สำหรับ Grid/Hedge
  - แม่นยำสูงสุด: `Every tick based on real ticks` (ช้าที่สุด ใช้เฉพาะ final verification)
- **Optimization**: ใช้ `Math calculation` + Genetic + Forward เพื่อลดจำนวน pass
- ปิด Visual mode เมื่อไม่ debug
- ตั้งค่า `InpVerboseLog=false` เมื่อรัน optimization
- ปิด `InpShowDashboard=false` เมื่อ optimization
- เปิด local agents หลายตัว (Tools → Strategy Tester → Settings → Number of local agents)

### C) สิ่งที่ "เพิ่มความแม่นยำ" โดยไม่ลดความเร็ว
1. ใช้ **Real Tick data** (ดาวน์โหลดจาก History Center) เฉพาะตอน final test
2. ตรวจ **Spread setting** — ใช้ `Current` หรือ custom ตรงกับโบรกเกอร์จริง (default 20 points อาจเพี้ยน)
3. ตั้ง **Initial deposit / Leverage / Commission** ให้ตรงบัญชีจริง
4. ใช้ **Custom Symbol** ที่ import ticks จากโบรกเกอร์เป้าหมาย (แม่นยำสุดสำหรับ XAUUSD)

---

## แผน v2.9.2 — Hedge Advance Bypass + Stale Opposite-Side Pending Cleanup

รวม 2 บั๊กที่ทำให้ระบบหยุดออกออเดอร์/มี pending ค้างผิดกลุ่ม

---

## ปัญหาที่ 1 — ออเดอร์หยุดออกหลัง hedging (จากภาพล่าสุด)

### อาการ
ภาพ Strategy Tester แสดง G1-G4 ทั้งหมด `ACTIVE  Hedge USED/LOCKED  PostAvg:WAITING` ทุก Gate ขึ้น OK (`Cy:Wait Norm Z:OUT OK XXpts`) Win pool > need ($580/$200, $425/$200, $110/$200, $178/$200) แต่ **ไม่มี G5 เปิดเลย** — EA หยุดออกออเดอร์ทั้งระบบ

### Root Cause
`IsPriorGroupSafeForAdvance()` (line ~3164):
```cpp
if(g_groupHedgeUsed[g] && g_groupPostMatchAvgActive[g]){
   reason = 1; return true;
}
```
ต้องการ **ทั้ง 2 เงื่อนไข** พร้อมกัน — แต่ระหว่างที่ Triple-Gate ยังรอ Squeeze TF3 Expansion→Normal latch (Z:OUT แต่ Cy:Wait) จะมี gap ที่ `g_groupHedgeUsed=true` แต่ `g_groupPostMatchAvgActive=false` ทุก prior group → `FindBlockingPriorGroup` คืนค่า > 0 → `TryAdvanceToNextGroup` ค้างชั่วนิรันดร์

ยิ่งถ้าผ่านขั้น recovery แล้วก็ตาม — flag `g_groupRecoveryLevel` อาจเป็น 0 หาก RC ปิดไปแล้วบางส่วน → fail check ทั้งหมด

### Fix v2.9.2 (A) — Hedge-Used Advance Bypass
แก้ใน `IsPriorGroupSafeForAdvance` (line ~3150):
- ลบเงื่อนไข `&& g_groupPostMatchAvgActive[g]` ที่ line 3164
- เปลี่ยนเป็น `if(g_groupHedgeUsed[g]){ reason = 2; return true; }` (`reason=2` = hedge-locked)
- **เหตุผล**: One-Hedge-Per-Group (v2.8.5) ล็อกแล้วว่าจะไม่มี hedge ใหม่ + กลุ่มจะถูก resolve ผ่าน Triple-Gate → Recovery แน่นอน ไม่ต้องรอ PostAvg activate เพื่อปลดล็อก advance queue
- เพิ่ม case `"hedge-locked"` ใน hold-log reason mapping เพื่อ debug

แก้ใน `IsGroupSafeToAdvance` (current group, line ~3118) ด้วยเหตุผลเดียวกัน:
- เพิ่ม early-return: `if(g_groupHedgeUsed[g]) return true;` ที่ต้นฟังก์ชัน

---

## ปัญหาที่ 2 — Pending ค้างใน Group เก่าหลัง hedge สลับฝั่ง (จากภาพก่อนหน้า)

### อาการ
G6 มี main SELL (S_GL#1..#12) + main BUY (B_GL#1..#2) + **hedge BUY filled** (B_HD_GL#3..#12) แต่มี **SELL_STOP pending ค้าง** (G6_S_HD_GL#3..#11) ที่ราคา 3363.47 ทั้งที่ G7 active แล้ว

### Root Cause
**`MirrorLossSideToHedgePendings()` cleanup** (line ~1947-1965) ลบ pending โดยเช็คแค่ tag-match (`lossTags[k] == tag`) ไม่เช็ค side ของ order type:
1. รอบแรก BUY-loss → วาง SELL_STOP hedge pendings (tag=GL#N)
2. ราคาเด้ง SELL-loss → mirror เรียกใหม่ hedgeSide=BUY → วาง BUY_STOP hedge pendings (tag=GL#N เหมือนกัน)
3. cleanup เห็น tag ตรง → "keep" SELL_STOP เก่าผิด → ค้างถาวร

**`ManageGroupHedgeArm()`** (line ~2069) early-return `if(hedgePosExists) return;` ก่อนถึงโค้ดล้าง pending ฝั่งไม่ตรง — เมื่อ BUY hedge filled แล้ว SELL pendings ฝั่งเก่าจะไม่ถูกแตะอีกเลย

**`DeleteLeftoverInitialPendingsAfterHedge()`** กรองเฉพาะ `tag=="IN"` ไม่ครอบคลุม HD_GL pendings

### Fix v2.9.2 (B) — Stale Opposite-Side Pending Sweep

#### B1) `MirrorLossSideToHedgePendings` cleanup loop (line ~1947)
เพิ่มเช็ค order-type ก่อน keep-by-tag:
```cpp
ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
bool isHedgeSideMatch = (hedgeSide==0 && (ot==ORDER_TYPE_BUY_STOP || ot==ORDER_TYPE_BUY_LIMIT))
                     || (hedgeSide==1 && (ot==ORDER_TYPE_SELL_STOP|| ot==ORDER_TYPE_SELL_LIMIT));
if(!isHedgeSideMatch){
   trade.OrderDelete(tk);
   if(g_verboseEffective) PrintFormat("Golden2 v2.9.2: HD stale-opposite-side delete G%d %s", g, c);
   continue;
}
// (เดิม) keep-by-tag logic
```

#### B2) `ManageGroupHedgeArm` — เพิ่ม sweep ก่อน early-return ที่ line ~2069
```cpp
// [v2.9.2] Stale opposite-side hedge pending sweep
if(hedgePosExists){
   int activeHedgeSide = (CountGroupPositions(g, 0, 1) > 0) ? 0
                       : (CountGroupPositions(g, 1, 1) > 0) ? 1 : -1;
   if(activeHedgeSide >= 0){
      // ลบ pending hedge ที่ order-type ไม่ตรงกับฝั่ง hedge ปัจจุบัน
      int total = OrdersTotal();
      for(int i=total-1; i>=0; i--){
         ulong tk = OrderGetTicket(i);
         if(tk==0 || !OrderSelect(tk)) continue;
         if((long)OrderGetInteger(ORDER_MAGIC) != InpMagic) continue;
         if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
         string c = OrderGetString(ORDER_COMMENT);
         int gp; bool hd; string tag;
         if(!ParseComment(c, gp, hd, tag)) continue;
         if(gp != g || !hd) continue;
         ENUM_ORDER_TYPE ot = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         bool isMatch = (activeHedgeSide==0 && (ot==ORDER_TYPE_BUY_STOP || ot==ORDER_TYPE_BUY_LIMIT))
                     || (activeHedgeSide==1 && (ot==ORDER_TYPE_SELL_STOP|| ot==ORDER_TYPE_SELL_LIMIT));
         if(!isMatch){
            trade.OrderDelete(tk);
            if(g_verboseEffective) PrintFormat("Golden2 v2.9.2: G%d post-hedge stale-side sweep %s", g, c);
         }
      }
   }
}
```

#### B3) OnTick group loop — post-match guarantee (หลัง `ManageGroupHedgeArm(g)` line ~4019)
```cpp
// [v2.9.2] เมื่อ post-match active หรือ hedge positions ปิดหมดแล้ว → ไม่ต้องมี hedge pending ใดๆ
if(g_groupHedgeUsed[g] && (g_groupPostMatchAvgActive[g] || CountGroupPositions(g,-1,1)==0)){
   if(CountGroupPendingsByTagPrefix(g, true, "") > 0){
      DeleteGroupPendings(g, 1);
      if(g_verboseEffective) PrintFormat("Golden2 v2.9.2: G%d post-match hedge pending full sweep", g);
   }
}
```

---

## C) Version bump + log + memory
- `#property version "2.92"` + description
- Header banner + dashboard title + init log → `Golden2 EA v2.9.2`
- Init log เพิ่ม: `HedgeUsedAdvanceBypass=ON | StalePendingCleanup=ON`
- สร้าง `.lovable/memory/trading/golden2-ea/v2-9-2-hedge-advance-bypass-and-stale-pending-cleanup.md`
- อัปเดต `.lovable/memory/index.md`

---

## ผลลัพธ์ที่คาดหวัง
1. **คิว advance ไม่ค้าง** — เมื่อ G1-G4 hedge filled แม้ PostAvg ยัง WAITING → G5+ ถูกเปิดต่อทันที (รอเฉพาะ entry signal ปกติ)
2. **Triple-Gate ปิดออเดอร์ตามคิวเดิม** — G1 ปิดก่อน → G2 ปิดถัดไป (ตามที่ user อธิบาย "ทำงานทีละชุด")
3. **Order ปกติ (non-recovery) ออกต่อเนื่อง** — หลัง G4 (กลุ่ม hedge สุดท้าย) → G5/G6 (กลุ่ม normal) ออกได้ทันที ไม่ต้องรอกลุ่มก่อนจบ recovery
4. **Pending ฝั่งเก่าถูกล้างทันที** — เมื่อ hedge สลับฝั่ง → SELL_STOP เก่าถูกลบในรอบ tick เดียวกับที่ BUY_STOP ใหม่ถูกวาง
5. **Post-match group ไม่มี pending ค้าง** — เมื่อ PostAvg active → hedge pending ใดๆ ถูกล้างทั้งหมด

---

## สิ่งที่ไม่เปลี่ยนแปลง (Rules of Steel)
- ❌ `trade.Buy/Sell/PositionClose/OrderSend/OrderModify/BuyStop/SellStop` — ไม่แตะ execution path
- ❌ Entry SMA/INSTANT/PENDING (PlaceInitialMarket / PlaceInitialFrame / Re-Arm / Re-Entry)
- ❌ Grid Loss/Profit lot multiplier / candle confirm / ATR snapshot
- ❌ Hedge arm logic (DD%, Arm/Disarm threshold, delay, BlockNewOrderPercent)
- ❌ One-Hedge-Per-Group (v2.8.5) / Hedge Orphan Offset (v2.8.6) — เสริม cleanup เท่านั้น
- ❌ Triple-Gate (WinPool / MinGain / Reserve-Profit / Squeeze TF3 latch / shred passes)
- ❌ Recovery Grid + Continuation + Seed Lock (v2.8.8/v2.9.0) / Recovery Order Lock (v2.8.9)
- ❌ Post-Match Avg TP/SL (v2.8.4) / SyncPostMatchAvgTPSL formula + timing
- ❌ Backtest Performance Pack (v2.9.1) — guard ใหม่ไม่กระทบ tester path
- ❌ `TryAdvanceToNextGroup` body / `FindBlockingPriorGroup` / `IsSideEffectivelySafeForAdvance` — แก้เฉพาะเงื่อนไข safe-pass
- ❌ ParseComment / MakeComment B_/S_/HD_ format
- ❌ Dashboard layout / DD% calc / License / News / Time / Sync

---

## ไฟล์ที่จะแก้ (เมื่อ approve)
- `public/docs/mql5/Golden2_EA.mq5` (~40 บรรทัด: 2 จุดใน advance safe-pass + 3 จุด stale-pending cleanup + version)
- `.lovable/memory/trading/golden2-ea/v2-9-2-hedge-advance-bypass-and-stale-pending-cleanup.md` (สร้างใหม่)
- `.lovable/memory/index.md` (อัปเดต)

---

## ผลลัพธ์ที่คาดหวัง
- Backtest เร็วขึ้นรวม **30-60%** บน EURUSD/XAUUSD ระยะ 1 ปี (ขึ้นกับ verbose/dashboard เดิม)
- Optimization (Genetic) เร็วขึ้นมากกว่านั้นเพราะแต่ละ pass สั้นลง
- Live trading: ไม่เปลี่ยนแปลงพฤติกรรมใด ๆ
