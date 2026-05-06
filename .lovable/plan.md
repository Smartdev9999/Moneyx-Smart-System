## ปัญหา (จากภาพ Dashboard v1.59)

- Realized (cycle) = **$11,575.28**
- Floating P/L (รวมทั้งบัญชี) = **$92,352.59**
- Accumulate Target = **$50,000** (ON)
- รวม realized + floating = **~$103,927** → เกิน target ไปไกลมาก แต่ Accumulate Close **ไม่ยิง**

### สาเหตุ
ใน `ManageTakeProfit()` บรรทัด 1563:
```cpp
double floatingAll = CalcSideFloating_NonHero(BUY) + CalcSideFloating_NonHero(SELL);
if((g_realizedCycle + floatingAll) >= InpAccumulateTarget) ...
```
ใช้ **`_NonHero`** → ตัดกำไรของ Hero tickets (5 ตัวบนสุดของ SELL) ออก ซึ่งในเคสนี้ Hero ฝั่ง SELL ถือกำไรก้อนใหญ่ → floating ที่เห็นในสูตรเหลือน้อยกว่า threshold มาก จึงไม่ trigger

ส่วน Gold Miner ใช้ `CalculateTotalFloatingPL()` ซึ่ง**รวมทุก position** → trigger ถูกต้อง ตามที่ผู้ใช้ต้องการ

## v1.60 — แก้ minimal

**ไฟล์:** `public/docs/mql5/Golden_Kuy3_EA.mq5`

### 1. แก้ `ManageTakeProfit()` (line ~1561-1572)
เปลี่ยน Accumulate ให้ใช้ floating **รวม Hero** (เหมือน Gold Miner):
```cpp
double floatingAll = CalcSideFloating(POSITION_TYPE_BUY) + CalcSideFloating(POSITION_TYPE_SELL);
if((g_realizedCycle + floatingAll) >= InpAccumulateTarget){
   ... // intent + CloseAllOurs() เดิม (CloseAllOurs ก็ปิด Hero อยู่แล้ว)
}
```
ส่วน TP Dollar / TP %Bal / TP Points (ต่อฝั่ง) **คงเดิมใช้ `_NonHero`** เพราะเป็น per-side และ Hero ถูกออกแบบให้ไม่ trigger TP รายฝั่ง

### 2. Dashboard
เพิ่มข้อมูลใน row Accumulate ให้เห็นว่ารวมแล้วเท่าไหร่:
- เปลี่ยนจาก `Accumulate  ON  $50000` → `Accumulate  ON  $50000 (cur $103927)`
- สีเขียวเมื่อ cur ≥ target (เกือบทันทีก่อนยิง)

### 3. Version bump v1.59 → v1.60
- `#property version "1.60"`, description, header banner, dashboard title
- log prefix `v1.60 ACCUM CLOSE` แทน `GK ACCUM CLOSE`

### 4. Memory
- create `mem://trading/golden-kuy3/v1-60-accumulate-include-hero-floating`
- update `mem://index.md`

## สิ่งที่ไม่เปลี่ยนแปลง (กฎเหล็ก)
- ไม่แตะ `OrderSend` / `trade.*` / `CloseAllOurs()` / `CloseAllSide()`
- ไม่แตะ Grid / new-candle / lot mode / Max Lot cap (v1.59) / Max DD Close (v1.59)
- ไม่แตะ Per-Order BE/Trail, Avg-TP, Avg-Trail strict 2-cross, Cost-Hit
- ไม่แตะ Hero logic ทั้งชุด (Handoff Reserve, Conditional Lock, Alternation, lock-profit SL, TP-event latch, Dynamic refresh, IsHeroProtectedTicket)
- ไม่แตะ TP Dollar / TP %Bal / TP Points ต่อฝั่ง — ยังใช้ `_NonHero` เหมือนเดิม
- ไม่แตะ `g_realizedCycle` accounting + `TryResetAccumulateCycleIfFlat` (v1.42)
- ถ้า `InpUseAccumulateClose=false` → behavior เหมือน v1.59 ทุกบรรทัด
