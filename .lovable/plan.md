

## Golden2 EA v2.0 — Accumulate Close + Group-Lock Sequencing + Bold Avg Lines + BuyStop TP/SL Fix

แก้ 4 ปัญหาตามที่ user รายงาน

### ไฟล์ที่จะแก้
- `public/docs/mql5/Golden2_EA.mq5` — bump version → `2.00`

### สิ่งที่ "ไม่เปลี่ยนแปลง"
- ไม่แตะ `OrderSend / trade.Buy / trade.Sell / trade.PositionClose`
- ไม่แตะสูตร Grid Loss / Grid Profit / Frame distance / Hedging mirror / Avg TP-SL / Triple-Gate / Squeeze
- ไม่แตะ License / News / Time filter / Bar-close trail / Immediate GL / ReArm

---

### 1) Accumulate Close — สะสมกำไร "ทั้งบัญชี" (ไม่ทำงาน + ขาดบน Dashboard)

**ปัญหา:** logic เดิมอยู่ใน `CheckAndCloseByAverageTP(g)` (per-group) และถูก guard `IsGroupHedgeMatched(g)` → ถ้ากรุ๊ปเข้า hedge → ไม่นับ

**Fix — ทำเป็น global (ทั้งระบบ):**
- เพิ่ม globals: `g_accumRealizedSinceReset`, `g_accumResetTime`, `g_hadAnyOrderLastTick`
- ฟังก์ชันใหม่ `ManageGlobalAccumulateClose()` เรียกใน `OnTick` ก่อน loop กรุ๊ป:
  1. สแกนทุก position+pending magic เดียวกัน → ถ้าเป็น 0 และ tick ก่อนมี → **RESET** (`realized=0`, `resetTime=now`)
  2. `realized` = สแกน `HistorySelect(g_accumResetTime, TimeCurrent())` วน `HistoryDealGetDouble(DEAL_PROFIT+SWAP+COMMISSION)` filter magic
  3. `floating` = sum `GroupFloatingPL(g,-1,-1)` ทุกกรุ๊ป
  4. `accumNet = realized + floating`
  5. ถ้า `>= InpTP_AccumulateTarget` → `CloseEverythingNow()` ปิดทุก position+ลบทุก pending ของ magic นี้
- **ลบ block เก่า** บรรทัด 1671-1679

**Dashboard panel ซ้าย** (section ใหม่หลัง ACCOUNT):
```
=== ACCUMULATE ===
Status      ON
Target      $1000.00
Realized    $xxx.xx
Floating    $xxx.xx
Accum Net   $xxx.xx   (เขียว/แดง)
Progress    xx.x%
```
ถ้า OFF → 1 บรรทัด `Accumulate: OFF`

---

### 2) Group Sequencing Guard — ห้ามเปิดกรุ๊ปใหม่ถ้ากรุ๊ปเดิมยังมี main "ไม่โดน lock"

**ปัญหา (line 1944-1965):** `GroupHedgeJustActivated(cur)` = "มี hedge ≥1" → จริงทันทีที่ hedge ตัวแรก fill → ไป G2 แม้ G1 ยัง main ค้างฝั่งเดียวที่ไม่ถูก lock

**Fix:** helper ใหม่
```
bool IsGroupSafeToAdvance(int g){
   bool hb = (CountGroupPositions(g,0,0) > 0);
   bool hs = (CountGroupPositions(g,1,0) > 0);
   if(!hb && !hs) return true;                       // main หมดแล้ว
   bool hh = (CountGroupPositions(g,-1,1) > 0);
   if(hh && hb && hs) return true;                   // matched hedge ทั้ง 2 ฝั่ง
   return false;                                     // มี main ฝั่งเดียว/ไม่มี hedge → hold
}
```
ใน `TryAdvanceToNextGroup`: ถ้า `InpGroup_RequireFullLockBeforeNext && !IsGroupSafeToAdvance(cur)` → return (G1 ยังบริหารต่อ Grid Loss/Avg TP/Hedge ตามปกติ)
- เพิ่ม input: `InpGroup_RequireFullLockBeforeNext = true` (ปิดได้กลับ behavior เดิม)
- VerboseLog: `"v2.0: hold G%d→G%d (G%d unlocked main)"`

---

### 3) Average Price Line — เส้นทึบหนาขึ้น

แก้ `DrawHLine` (1769-1779) เพิ่ม optional `style`+`width`:
```
void DrawHLine(string name, double price, color clr,
               ENUM_LINE_STYLE style=STYLE_DOT, int width=1)
```
จุดเรียก average (line 1801) → `STYLE_SOLID, InpTP_AvgLineWidth (3)`. TP/SL คงเดิม dotted width 1.
- Input ใหม่: `InpTP_AvgLineWidth = 3`

---

### 4) Initial BuyStop ไม่มี TP/SL (ปิดเกือบทันที)

**ปัญหา (จากภาพ G4_IN buy stop S/L=0.00 T/P=4604.95 แต่ Sell มีครบ):** `PlaceInitialFrame` คำนวณ TP/SL ก่อนส่ง order แต่อาจ **คำนวณจาก ask/bid แทนราคา open ของ pending** หรือ side BUY ใช้สูตรพลิกผิด → ทำให้ BuyStop ออกมามี TP "ใต้" ราคา open → broker ปิดทันทีเมื่อ fill (TP < open)

**Fix (ไม่แตะสูตร TP จริง — แค่ใช้ราคาฐานที่ถูก):**
- ตรวจ `PlaceInitialFrame`: บังคับใช้ `openPx = buyStopPrice` (สำหรับ BUY) และ `openPx = sellStopPrice` (สำหรับ SELL) เป็นฐานคำนวณ TP/SL
- BUY:  `tp = openPx + InpTP_PointsFromAvg * g_point` (ต้อง > openPx)
       `sl = openPx - InpSL_PointsFromAvg * g_point` (ต้อง < openPx)
- SELL: `tp = openPx - InpTP_PointsFromAvg * g_point`
       `sl = openPx + InpSL_PointsFromAvg * g_point`
- เพิ่ม **sanity guard** ก่อนส่ง:
  ```
  if(side==BUY && (tp<=openPx || sl>=openPx)) { Print("v2.0: invalid BUY tp/sl, set 0"); tp=0; sl=0; }
  if(side==SELL && (tp>=openPx || sl<=openPx)) { Print("v2.0: invalid SELL tp/sl, set 0"); tp=0; sl=0; }
  ```
- เคารพ `SYMBOL_TRADE_STOPS_LEVEL` (ถ้า tp/sl ใกล้ openPx เกิน stops level → ดัน TP ออกให้พ้น stops level)
- ใช้ flow เดียวกับ BarClose Trail modify เพื่อรักษาความสอดคล้อง
- VerboseLog ราคา open/tp/sl ที่ส่งจริง เพื่อ debug รอบหน้า

**กฎ "ห้ามแตะ OrderSend":** เราไม่เปลี่ยน call ส่ง pending — แค่แก้ค่า tp/sl ที่ป้อนเข้า request struct ให้ถูกต้องและเพิ่ม guard

---

### Inputs ใหม่ (สรุป)
```
input bool InpGroup_RequireFullLockBeforeNext = true;
input int  InpTP_AvgLineWidth                 = 3;
```

### Version Bump → 2.00
`#property version`, `#property description`, header, `Print` ใน OnInit, dashboard `L_TITLE` → `Golden2 EA v2.0`

### บันทึก Memory
`mem://trading/golden2-ea/v2-0-accum-grouplock-avgline-buystop-tp.md`

