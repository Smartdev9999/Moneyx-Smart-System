## ปัญหาที่พบจริงในภาพ

จาก Hedging Table:
- G1* ACTIVE: MainL=3.67, HdgL=3.43, **P/L = -2981.59**, DD=412.3%
- Gate: `T:SQ Cy:Ready Z:OUT OK 2468pts` (ผ่านหมด)
- TripleGrid: `G:$484.08 / $100.00` (gain ผ่าน MinGain แล้ว)

**แต่ระบบไม่ปิดออเดอร์เลย**

### Root cause (ยืนยันจากโค้ด `TryMatchingCloseForGroup` บรรทัด 2475–2476)

```mql5
double netCheck = plBuyMain + plSellMain + plBuyHedge + plSellHedge; // = -2981.59
if(netCheck < InpExitMinNetUSD) return;   // -2981 < 1.0 → return ทันที
```

`netCheck` คือ **floating P/L รวมทั้งกลุ่ม** ซึ่งติดลบลึก (-$2981) เพราะฝั่งที่แพ้ใหญ่กว่าฝั่งชนะ. การจะให้ "Matching Close" ทำงานก็คือใช้กำไรฝั่งชนะไปหักลบฝั่งแพ้ — ไม่ใช่รอให้ทั้งกลุ่มกลับมาเป็นบวกก่อน. การ์ดบรรทัดนี้คือสาเหตุที่ทำให้ Gate ผ่านหมดแล้วยังไม่มีอะไรเกิดขึ้น.

นอกจากนี้ `InpPostHedge_AllowContinuation = false` (default) ทำให้กลุ่มถูก freeze หลัง hedge — ไม่มี Recovery Grid โผล่มาช่วยเลย.

## แผนแก้ไข v2.8.3 (`public/docs/mql5/Golden2_EA.mq5`)

### 1) แก้ Matching-Close Gate ให้ใช้ฝั่งชนะเป็นเกณฑ์

เปลี่ยนเงื่อนไขใน `TryMatchingCloseForGroup`:

```mql5
// เดิม: ทั้งกลุ่มต้องเป็นบวก (เป็นไปไม่ได้ตอน hedge ลึก)
if(netCheck < InpExitMinNetUSD) return;

// ใหม่: pool ฝั่งชนะต้องพอที่จะเริ่ม shred ฝั่งแพ้
if(winProfit < InpExitMinNetUSD) return;
```

- `winProfit` = `plBuyMain+plBuyHedge` หรือ `plSellMain+plSellHedge` ของฝั่งที่ราคาวิ่งไปทาง avg-mid
- `MinGainUSD` gate (gain since hedge open) คงเดิม — เป็นการกัน choppy
- Pool ใน `ShredCloseLosingSide` ใช้ `winProfit` เป็นทุนตั้งต้น (ของเดิมอยู่แล้ว) เพื่อปิดไม้แพ้ทีละไม้จากกำไรมากสุด

### 2) เปิด Recovery Grid อัตโนมัติหลัง Partial Match-Close

หลัง `CloseAllGroupSide(winSide)` + `ShredCloseLosingSide(losSide, pool)` ถ้ายังเหลือไม้ค้างฝั่งแพ้ → set `g_groupInRecovery[g]=true` (มีอยู่แล้ว) **และ** เปิด Recovery Grid ครั้งเดียวต่อรอบ:

- เพิ่ม input ใหม่:
  - `InpRecovery_Enable = true` — เปิด/ปิดฟีเจอร์
  - `InpRecovery_StartLot = 0.0` — 0 = ใช้ lot ของไม้ล่าสุดฝั่งที่เหลือ
  - `InpRecovery_Multiplier = 1.5`
  - `InpRecovery_DistancePips = 0` — 0 = ใช้ค่าจาก Grid Loss settings เดิม
  - `InpRecovery_MaxLevels = 5`
- เพิ่ม global `int g_groupRecoveryLevel[51]`
- ฟังก์ชันใหม่ `PlaceRecoveryGridIfNeeded(g, losSide)` วาง pending stop ฝั่งแพ้ตาม distance + multiplier; ใช้ comment tag `RC#N` (ไม่ชน `GL#N`)
- เรียกหลัง Match-Close (แทนที่ `PlaceContinuationGridIfNeeded` flow เดิม)
- Recovery Grid มีสิทธิ์ปิดร่วมใน Match-Close รอบถัดไป (เพราะ ParseComment คืน `gp==g` อยู่แล้ว)

### 3) เพิ่ม Triple-Grid Dashboard (สไตล์ Gold Miner)

ใน Right Panel ที่ block ของกลุ่มที่ hedge active เพิ่ม 3 บรรทัดใต้ `TripleGrid`:

```
G1* ACTIVE          MainL HdgL  P/L      Pend DD%
  Gate    T:SQ Cy:Ready Z:OUT OK 2468pts
  TripleGrid  G:$484.08/$100.00
  Grid#1  Loss:-2124  Hedge:+1473  Net:-651      ← per-grid pair
  Grid#2  Loss:-1559  Hedge:+1061  Net:-498
  Recovery RC#1 lot=1.05 dist=120pt Lv=1/5       ← recovery status
```

- ดึงคู่ Loss/Hedge จาก ParseComment โดยจับคู่ `GL#N (main losing side)` ↔ `HD_GL#N (hedge winning side)` แล้วโชว์ floating ต่อคู่
- โชว์สูงสุด N คู่ (default 5) เพื่อกัน panel ล้น
- บรรทัด Recovery โชว์ตอน `g_groupInRecovery[g]==true`

### 4) Version & Logging

- Header / `#property version "2.83"` / `#property description` / dashboard title / init log → v2.8.3
- เพิ่ม log ตอน Match-Close ทำงานจริง: `Golden2 v2.8.3: G%d MATCH-CLOSE win=%s pool=%.2f lossClosed=%d residual=%d`

### 5) Memory

- สร้าง `mem://trading/golden2-ea/v2-8-3-matchclose-winpool-recovery-grid.md`
- อัปเดต index

## สิ่งที่ "ห้ามแตะ" (ตามกฎเหล็ก MQL5)

- ❌ `trade.Buy/Sell/PositionClose/OrderModify/OrderSend/OrderDelete` (เพิ่ม OrderSend ใหม่สำหรับ Recovery Grid เท่านั้น — เป็นฟีเจอร์ใหม่ ไม่แก้ของเดิม)
- ❌ Entry Mode: PENDING / SMA / INSTANT
- ❌ Squeeze BB/KC/ADX/EMA/ATR computation
- ❌ Grid Loss / Grid Profit lot, distance, candle confirm
- ❌ Hedge mirror 1:1, pending hedge, arm/disarm, block percent
- ❌ Average TP/SL, MaxGrid trailing, per-order trailing, accumulate close
- ❌ Force-close opposite unhedged
- ❌ ParseComment / MakeComment B_/S_ side tags (Recovery ใช้ tag `RC#N` ผ่าน MakeComment เดิม)
- ❌ ATR/ADX TesterHideIndicators wiring (v2.8.1)
- ❌ Sequential Queue / MinGainUSD / Squeeze TF3 latch logic (v2.8.0/v2.8.1) — แก้แค่บรรทัด `netCheck` → `winProfit`
- ❌ Prior-group advance guard (v2.8.2)

## ผลลัพธ์ที่คาดหวัง

- ในเคสภาพ: `winProfit ≈ $484 ≥ MinNetUSD($1)` → เริ่ม `CloseAllGroupSide(winSide)` ปิดฝั่งชนะทั้งหมด, ใช้ $484 เป็น pool ไป `ShredCloseLosingSide` ปิดไม้แพ้ใหญ่สุดที่ pool รับไหว
- กลุ่มเหลือไม้แพ้ค้าง → ติดธง Recovery + วาง `RC#1` ฝั่งเดียวกัน
- Match-Close รอบถัดไป จะรวม `RC#N` เข้าคู่กำไรชุดใหม่
- Dashboard โชว์ Grid#N pair + Recovery status ชัดเจนแบบ Gold Miner
