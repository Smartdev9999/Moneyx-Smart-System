

## v6.81 — Older-Gen Bound-Side Grid Continuation + Hedge-Grid Filters/AvgTP

รวม 2 หัวข้อในเวอร์ชันเดียว:
- **ส่วน A:** กรีดต่อชุดเก่าที่โดน Hedge-Lock (จากภาพชุดที่ 5/6)
- **ส่วน B:** แก้ Hedge-Grid (`GM_HG#_GL`) ออกรัวๆ + ไม่มี Broker TP avg

### ปัญหาที่จะแก้

**A. Older-Gen ไม่กรีดต่อ**
ภาพแรก (Gen5/Gen6): หลังเปิด `GM_Hedge_D5` ระบบ advance ไป Gen6 → `GM6_INIT` เปิดได้ แต่ `GM5_GL#3` ไม่ออกอีกเลย เพราะ `CheckGridLoss` filter `orderGen != g_cycleGeneration` + ใช้ `GetCommentPrefix()` (= GM6) → Gen5 ไม่มีกรีดเฉลี่ย ปิดยากมาก

**B. Hedge-Grid ออกรัวๆ + ไม่มี Broker TP**
ภาพ `GM_HG2_GL1..GL9` ราคาห่างกันแค่ ~50pts ออก 9 ไม้ติดกัน:
1. `ManageHedgeGridMode()` (line 11811) **ไม่เคารพ** `GridLoss_OnlyNewCandle` / `GridLoss_DontSameCandle` / `GridLoss_CandleConfirm` / `GridLoss_MinGapPoints` — ใช้แค่ `g_lastHedgeGridTime < 5s` cooldown
2. ใช้ `currentGridCount + 1` สำหรับ `GetGridDistance()` แทนที่จะเป็น `nextLevel` (= `gridLevel + currentGridCount`) → distance รีเซ็ตเหมือนเริ่มที่ระดับ 1 ทุกครั้ง → ระยะใกล้เกิน
3. **ไม่มี broker TP** บนไม้ `GM_HG#_GL*` → ไม่ถูกรวมเข้าค่าเฉลี่ย → ราคาวิ่งชน TP รายตัวก็ไม่ปิด ต้องรอ matching close ที่ถี่เกินไป

### ไฟล์ที่จะแก้
- `public/docs/mql5/Gold_Miner_EA.mq5`

---

### ส่วน A — Older-Gen Bound-Side Grid Continuation

**Inputs ใหม่ (หมวด Grid Loss Side)**
- `InpLegacyGen_GridContinue` (bool, default `true`) — กรีดต่อ gen เก่าที่ยังมี hedge bound
- `InpLegacyGen_OnlyBoundSide` (bool, default `true`) — เฉพาะ side ที่ตรงกับ `counterSide` ของ hedge set ที่ active เท่านั้น
- `InpLegacyGen_LogVerbose` (bool, default `true`)

**Helpers ใหม่**
- `CollectActiveBoundGens(int &gens[], int &sides[])` — สแกน `g_hedgeSets[]` เก็บ `(boundGeneration, counterSide)` ที่ active + `boundTicketCount > 0` + ไม่ใช่ current gen
- `CountOrdersByGenSide(gen, side, &glCount, &lastPrice, &lastTime, &initPrice)` — สแกนตาม comment `GM{gen}_INIT` / `GM{gen}_GL#`
- `CheckGridLossLegacy(gen, side)` — copy logic ของ `CheckGridLoss` แต่ใช้ค่าจากพารามิเตอร์ + comment `GM{gen}_GL#{nextLevel}` (`nextLevel = max(maxLvl+1, glCount+1)` คงระบบ v6.71)

**Hook ใน OnTick** (หลัง block `CheckGridLoss` ปกติ):
```
if(InpLegacyGen_GridContinue && !g_newOrderBlocked) {
   int gens[], sides[];
   CollectActiveBoundGens(gens, sides);
   for each → CheckGridLossLegacy(gen, side);
}
```
- เคารพ `NormalOrderCount() < MaxOpenOrders`, `GridLoss_MaxTrades` per-gen, `GridLoss_OnlyNewCandle` (per-set ผ่าน `g_hedgeSets[h].lastLegacyGridCandle` field ใหม่), `GridLoss_DontSameCandle`

**Dashboard:** เพิ่ม `Legacy Grid Continue: ON | Active gens: [5,4]` + ในแถว `Hedge #N` แสดง `Legacy GL: 2`

---

### ส่วน B — Hedge-Grid Filters + Broker TP (Avg Pool)

**Inputs ใหม่ (หมวด === Hedge Grid Filters ===)**
- `InpHedgeGrid_OnlyNewCandle` (bool, default `true`) — บังคับเปิดได้ 1 ไม้ต่อแท่ง (per set)
- `InpHedgeGrid_DontSameCandle` (bool, default `true`) — ห้ามไม้ใหม่อยู่แท่งเดียวกับไม้กรีดล่าสุดของ set
- `InpHedgeGrid_CandleConfirm` (int, default `1`) — ต้องมี N แท่งยืนยันทิศก่อนกรีด (0=off)
- `InpHedgeGrid_MinGapPoints` (int, default `200`) — gap ขั้นต่ำ override `GridLoss_MinGapPoints` ของ hedge grid โดยเฉพาะ
- `InpHedgeGrid_CooldownSec` (int, default `30`) — เพิ่มจาก hard-coded 5s
- `InpHedgeGrid_AvgTP_Enable` (bool, default `true`) — sync broker TP เฉลี่ยรวม hedge + grid
- `InpHedgeGrid_AvgTP_Points` (int, default `300`) — TP distance points จาก avg

**Field ใหม่ใน `HedgeSet`**
- `datetime lastGridCandleTime` — สำหรับ OnlyNewCandle / DontSameCandle per-set
- `double lastBrokerAvgTP` — กัน re-sync ซ้ำเมื่อ avg ไม่เปลี่ยน

**แก้ `ManageHedgeGridMode()` (line 11811-12021) — เพิ่ม guard ก่อน open**
1. ก่อนคำนวณ distance:
   - `if(InpHedgeGrid_OnlyNewCandle && iTime(_Symbol,PERIOD_CURRENT,0) == g_hedgeSets[idx].lastGridCandleTime) return;`
   - `if(InpHedgeGrid_DontSameCandle)` — เช็ค last grid order time vs current bar
   - `if(InpHedgeGrid_CandleConfirm > 0)` — เรียก `HasCandleConfirmation(hedgeSide, PERIOD_CURRENT, InpHedgeGrid_CandleConfirm)`
2. แทนที่ hard-coded `g_lastHedgeGridTime < 5` → `< InpHedgeGrid_CooldownSec`
3. แก้ distance call (line 11958): ใช้ `nextLevel = g_hedgeSets[idx].gridLevel + currentGridCount + 1` แทน `currentGridCount + 1` → distance scale ตามระดับจริง
4. enforce `requiredGap = MathMax(requiredGap, InpHedgeGrid_MinGapPoints)`
5. หลัง `OpenOrder` สำเร็จ → set `lastGridCandleTime = iTime(_Symbol,PERIOD_CURRENT,0)` + เรียก `SyncHedgeSetAvgTP(idx)` ทันที

**Helper ใหม่: `SyncHedgeSetAvgTP(int idx)`**
- รวม weighted avg ของ: main hedge (`hedgeTicket`) + ทุกไม้ `GM_HG{idx+1}*` ที่ side เดียวกับ hedge
- คำนวณ `avgPrice = Σ(price*lots) / Σlots`
- `tpPrice = avgPrice ± InpHedgeGrid_AvgTP_Points * _Point` (ทิศตาม hedgeSide)
- ถ้า `MathAbs(tpPrice - g_hedgeSets[idx].lastBrokerAvgTP) > _Point` → loop เรียก `trade.PositionModify(tk, currentSL, tpPrice)` ทุก ticket ใน pool
- บันทึก `lastBrokerAvgTP = tpPrice`
- เรียกที่:
  - หลัง grid order เปิดสำเร็จ (ใน `ManageHedgeGridMode`)
  - หลัง partial close main hedge สำเร็จ (line 11893)
  - ทุก tick (ภายใน `ManageHedgeGridMode` แต่ throttle ด้วย `basketChanged`-style เหมือน v6.64)

**ข้อสำคัญ — exempt จาก v6.79 Stuck-TP Scanner:**
- v6.79 `ScanAndClearStuckHedgeLockTP` clears TP บน bound tickets ที่อยู่ใน `g_hedgeSets[].boundTickets[]` เท่านั้น → ไม่กระทบ TP บน hedge grid (ไม่ได้อยู่ใน boundTickets) ✓
- v6.72 `EnforceClearTPOnAllBound` ก็เช่นกัน → ไม่กระทบ ✓

**Dashboard:** ในแถว `Hedge #N Grid:Lx` เพิ่ม `| AvgTP:4612.5 | Pool:5(0.45L)`

---

### Version bump → v6.81
- `#property version "6.81"`, `#property description`, header comment, `OnInit` print, dashboard header

### สิ่งที่ "ไม่เปลี่ยนแปลง" (ตามกฎเหล็ก)
- **ไม่แก้** `OrderSend / trade.Buy / trade.Sell / trade.PositionClose` — ใช้ `OpenOrder()` / `trade.PositionModify` เดิม
- **ไม่แก้** logic ของ `CheckGridLoss()` ปัจจุบัน (เพิ่ม `CheckGridLossLegacy()` แยก)
- **ไม่แก้** ตรรกะภายใน `ManageHedgeMatchingClose / ManageHedgeBoundAvgTP / ManageHedgePartialClose / IsHedgeCloseAllowed` — แค่เพิ่ม guard + sync TP
- **ไม่แก้** Triple Gate / Sequential Recovery / FIFO / Owner / Unlock Delay
- **ไม่แก้** Hedge Open Delay (v6.78) / Stuck-TP Scanner (v6.79) / Stuck-Hedge Scanner (v6.80) / Cross-Gen INIT Guard (v6.76) / NoReHedge (v6.74)
- **ไม่แก้** License / News / Time filter / Balance Guard / Daily Target

### ผลลัพธ์ที่คาดหวัง
- **A:** Gen5 ที่โดน lock จะกรีด `GM5_GL#3, #4, ...` ต่อจน max หรือ matching close → ปิดได้แล้วค่อยไป Gen6
- **B1:** `GM_HG2_GL` จะเปิดทีละ 1 ไม้ต่อแท่ง (ไม่ใช่ 9 ไม้ในไม่กี่นาที) + ระยะ gap จริงตามระดับ
- **B2:** ทุกไม้ใน hedge pool (main hedge + grids) มี Broker TP avg ตรงกัน → broker ปิดให้อัตโนมัติเมื่อราคาแตะ avg+TP → ไม่ต้องรอ matching loop

### ความเสี่ยง & Mitigation
- **A Risk:** กรีด legacy เกิน margin → enforce `NormalOrderCount < MaxOpenOrders` + `GridLoss_MaxTrades` per-gen
- **B Risk:** AvgTP บีบจน main hedge ปิดก่อน grids กำไร → default TP=300pts ปรับได้ + ปิดด้วย `InpHedgeGrid_AvgTP_Enable=false`
- **B Risk:** broker reject modify → log + retry รอบถัดไป (basketChanged trigger)
- ทั้งหมดมี toggle ปิดได้ (`InpLegacyGen_GridContinue=false` / `InpHedgeGrid_AvgTP_Enable=false`) → กลับเป็นพฤติกรรม v6.80 ทุกประการ

