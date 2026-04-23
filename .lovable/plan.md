

## v6.73 — Orphan Hedge Auto-Close + Lot Inflation Guard

### วินิจฉัยจากภาพ image-952 + image-953

**ภาพ orders:**
- Set#1 (Buy): `GM1_INIT 0.03` + `GM1_GL#1 0.04` + `GM1_GL#2 0.06` = **0.13 lot**
- Hedge: `GM_Hedge_D1` (sell) **3.19 lot** ← ใหญ่กว่า Buy ที่มันควร hedge **24.5 เท่า**
- ทำให้ floating ติดลบ **-14,648 USD** ทั้งที่ฝั่ง buy แค่ -800 USD

**Log บอกชัด:**
```
v6.65 HEDGE INTEGRITY CRITICAL: set#0 gen=1 hedgeLots=3.19 has NO bound orders 
(orphan hedge — manual review required)
GetHedgeLotCap: skip set#0 boundGen=1 != currentGen=2
```
- ระบบ "รู้" ว่า hedge นี้กำพร้า (bound orders ที่ผูกไว้ปิดไปหมดแล้วจาก SL/TP)
- แต่ **แค่ print เตือน — ไม่ทำอะไร** (`manual review required`)
- Cycle เคลื่อนเป็น Gen2 แล้ว → `GetHedgeLotCap` ก็ skip → ไม่มีกลไกปิด/จัดการ hedge 3.19 lot ที่ค้างอยู่
- ออเดอร์ Buy รุ่นใหม่ (GM1_GL#1..5 ของ gen ใหม่ + GM2_*) เลยลอยอิสระ ไม่ถูก cap → ขนาดดูปกติ แต่ hedge เก่ายังเททับอยู่

### Root Cause

ที่ `AuditHedgeSetIntegrity()` (line 8042–8090):
- Detect orphan hedge ได้ถูกต้อง
- แต่ **action = แค่ Print()** ไม่มี auto-recovery
- ทำให้ hedge ที่ "หลุดสมอ" (bound orders โดน TP/SL ปิดหมดก่อน hedge) ค้างเป็น exposure ขนาดมหึมา

### แผนแก้ (Fix-only — ไม่แตะ trading strategy / order execution)

ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1) เพิ่ม input toggles ใหม่
```cpp
input bool   InpHedge_AutoCloseOrphan       = true;   // v6.73: Auto-close hedge with 0 bound orders
input int    InpHedge_OrphanGraceSec        = 30;     // v6.73: wait this long after detect before close (avoid race with OnTradeTransaction)
input bool   InpHedge_AutoTrimInflated      = true;   // v6.73: Auto partial-close hedge if hedgeLots > boundLots*2
input double InpHedge_TrimToleranceMult     = 1.10;   // v6.73: trim down to boundLots * tolerance (10% buffer)
```

#### 2) ขยาย `AuditHedgeSetIntegrity()` ให้มี action จริง

**Branch A — Orphan (boundCount==0, hedgeLots>0):**
- Log ครั้งแรก → set timestamp `g_hedgeSets[h].orphanDetectedAt = now`
- เมื่อ `now - orphanDetectedAt >= InpHedge_OrphanGraceSec` และ `InpHedge_AutoCloseOrphan == true`:
  - `trade.PositionClose(g_hedgeSets[h].hedgeTicket)` — ปิดเฉพาะตัว hedge
  - Log: `v6.73 ORPHAN HEDGE AUTO-CLOSED: set#h gen=N ticket=T lots=X`
  - Reset slot (`active=false`, ล้างทุกฟิลด์ตามแพทเทิร์นเดิม line 937–945)
- ถ้า `InpHedge_AutoCloseOrphan == false` → คงพฤติกรรมเดิม (แค่เตือน)

**Branch B — Inflated (hedgeLots > boundLots * 2):**
- Log ครั้งแรก → set `g_hedgeSets[h].inflationDetectedAt = now`
- เมื่อ grace ผ่าน และ `InpHedge_AutoTrimInflated == true`:
  - คำนวณ `targetLots = boundLotsActual * InpHedge_TrimToleranceMult`
  - `excessLots = hedgeLots - targetLots` (round ตาม `SYMBOL_VOLUME_STEP`)
  - ถ้า `excessLots >= minLot`: `trade.PositionClosePartial(hedgeTicket, excessLots)`
  - อัปเดต `g_hedgeSets[h].hedgeLots = hedgeLots - excessLots`
  - Log: `v6.73 HEDGE TRIMMED: set#h hedgeLots X→Y (boundLots=Z)`
- ถ้าหลัง trim เหลือ ≤ 0 → ปิดทิ้งทั้งตัว + reset slot

**Reset condition:** ถ้ารอบถัดไปพบว่า bound orders กลับมา (เช่น recovery system bind ใหม่) → clear `orphanDetectedAt / inflationDetectedAt = 0`

#### 3) เพิ่ม struct fields ใน `HedgeSet` (บรรทัด ~562)
```cpp
datetime orphanDetectedAt;     // v6.73
datetime inflationDetectedAt;  // v6.73
```
- ตั้งค่า = 0 ทุกที่ที่ reset slot (3 จุด: line 937, 2271, และ branch close ใหม่)

#### 4) Dashboard เพิ่ม
```
"AutoHealOrphan": "ENABLED" / "DISABLED"
"AutoTrimInflated": "ENABLED" / "DISABLED"
"OrphanCnt": <count>  (ใช้ g_hedgeIntegrityCriticalCount เดิม)
"InflatedCnt": <count> (ใช้ g_hedgeIntegrityWarnCount เดิม)
```

#### 5) Triple Gate exempt
ถ้าฟีเจอร์ Triple Gate gate การปิด hedge → bypass สำหรับ orphan/trim เพราะนี่คือ integrity-recovery ไม่ใช่ matching-close ปกติ
(ตรวจใน `ManageHedgeMatchingClose` — orphan auto-close จะข้าม Triple Gate โดยตรง)

#### 6) Version bump → v6.73
- `#property version "6.73"`
- `#property description` เพิ่ม "v6.73: Auto-heal orphan/inflated hedges"
- Header comment + Dashboard string

### สิ่งที่ไม่เปลี่ยนแปลง
- ไม่แก้ `OpenOrder / trade.Buy / trade.Sell` (ใช้ `trade.PositionClose / PositionClosePartial` ที่มีอยู่แล้ว)
- ไม่แก้ entry condition / grid logic / signal filter
- ไม่แก้ `CalculateGridLot` / `CalculateHedgeLot`
- ไม่แก้ Hedge Matching Close, Reverse Hedge, Bound logic, Recovery System
- ไม่แก้ DD threshold / Generation lifecycle / Triple Gate logic เอง
- ไม่แก้ One-Per-Gen (v6.72), Sequential FIFO (v6.70), Grid Comment Max-Level (v6.71)
- ไม่แก้ License / News / Time / BB filter

### ผลลัพธ์ที่คาดหวัง
1. กรณีเดียวกับภาพ: หลังเริ่ม EA v6.73 ระบบจะ detect orphan hedge `set#0 hedgeLots=3.19, boundCount=0` → รอ 30s → ปิด `GM_Hedge_D1` อัตโนมัติ → exposure -14,648 ลดลงเหลือเท่ากับ buy ฝั่งเดียว
2. ถ้า hedge ใหญ่กว่า bound 2x ขึ้นไป (เช่น bound บางตัว TP ไป 50%) → trim ให้เหลือ ~1.1x ของ bound จริง
3. Slot ที่ถูกปิดกลับเข้า pool ให้ generation ใหม่ใช้ได้
4. มี toggle สลับเปิด/ปิดได้ทันที

### ความเสี่ยง & Mitigation
- **Risk:** Auto-close orphan ขณะ OnTradeTransaction ยังไม่ทัน update `boundTickets`  
  **Mitigation:** Grace period 30s + `RefreshBoundTickets(h)` ก่อนตัดสินใจ + throttle 30s เดิม
- **Risk:** Trim partial close ผิด step volume  
  **Mitigation:** Round ตาม `SYMBOL_VOLUME_STEP` และเช็ค `>= SYMBOL_VOLUME_MIN`
- **Risk:** ปิด hedge แล้ว recovery system งง  
  **Mitigation:** ใช้ flow reset slot เดียวกับ matching-close (line 937–945), `IsPrevHedgedTicket` ไม่กระทบเพราะไม่มี bound ticket อยู่แล้ว
- **Risk:** User ไม่อยากให้ระบบปิดเอง  
  **Mitigation:** `InpHedge_AutoCloseOrphan = false` กลับเป็นพฤติกรรม v6.72

