# Gold Miner EA v6.85 — Average Trailing SL ออกเป็น Broker SL จริง

## 🐛 Root Cause

จากภาพ ทุก ticket แสดง `S/L = 0.00` แม้ Average Trailing Stop ทำงานอยู่ — ตรวจ code พบว่า:

1. `ApplyTrailingSL()` (line 3108) **push broker SL ถูกต้องอยู่แล้ว** ✅
2. **แต่** `SyncBrokerTPSL()` (line 2380) ทำงานทุก ~2s/ทุก grid order:
   ```cpp
   if(EnableSL && UseSL_Points && !EnablePerOrderTrailing)
      slBuy = NormalizeDouble(avgBuy - SL_Points * point, digits);
   // มิฉะนั้น slBuy = 0
   ```
3. แล้วเรียก `trade.PositionModify(ticket, slBuy=0, tpBuy)` → **ลบ SL ที่ Average Trailing เพิ่ง push ทุกรอบ** 💥

ผล: คำนวณถูก, push ถูก, ถูกเขียนทับด้วย 0 ทันที → S/L = 0.00, ไม่มีเส้น SL บนชาร์ต

---

## ✅ แก้ไข v6.85

ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

### 1. SyncBrokerTPSL — เคารพ Average Trailing SL
ปรับ loop modify (~line 2483-2508):
- BUY ticket: ถ้า `EnableTrailingStop && g_trailingActive_Buy && g_trailingSL_Buy > 0` → ใช้ `g_trailingSL_Buy` แทน slBuy
- SELL ticket: เช่นเดียวกันใช้ `g_trailingSL_Sell`
- ถ้า trailing ยังไม่ activate แต่ ticket มี `curSL > 0` และจะตั้ง `slBuy=0` → preserve `curSL` (กัน Breakeven SL ถูกลบ)

```cpp
double effectiveSlBuy = slBuy;
if(EnableTrailingStop && g_trailingActive_Buy && g_trailingSL_Buy > 0)
   effectiveSlBuy = g_trailingSL_Buy;
else if(slBuy == 0 && curSL > 0)
   effectiveSlBuy = curSL;

if(NormalizeDouble(curTP,digits)!=tpBuy || NormalizeDouble(curSL,digits)!=effectiveSlBuy)
   trade.PositionModify(ticket, effectiveSlBuy, tpBuy);
```

### 2. ApplyTrailingSL — sync cache
หลัง `trade.PositionModify` สำเร็จ → อัปเดต `g_lastBrokerSL_Buy = slPrice` (BUY) หรือ `g_lastBrokerSL_Sell = slPrice` (SELL) กัน SyncBrokerTPSL trigger ซ้ำ

### 3. Mirror fix ใน MTF
`ManageTrailingStop_TF` / `ApplyTrailingSL_TF` (~line 5730/5844) — ใช้แนวเดียวกันถ้ามี SyncBrokerTPSL_TF

### 4. Version & Dashboard
- `#property version "6.85"` + description "Avg Trailing as Broker SL"
- Header changelog v6.85
- Dashboard title "Gold Miner EA v6.85"
- `OnInit` log
- Memory: `.lovable/memory/trading/gold-miner-ea/avg-trailing-broker-sl-v6-85.md`

---

## ✅ สิ่งที่ไม่เปลี่ยนแปลง (Trading Logic ปลอดภัย 100%)

- ❌ ไม่แตะ `OrderSend` / `trade.Buy` / `Sell` / `PositionClose` / `CloseAllSide`
- ❌ ไม่แตะสูตร `newSL`, `TrailingStep`, `TrailingActivation`, Breakeven, avgBuy/avgSell
- ❌ ไม่แตะ Hedge / Triple-Gate / DD% / Squeeze / News / License / Grid Loss/Profit / Accumulate / Recovery
- ❌ ไม่แตะ entry conditions / candle confirm (v6.40/v6.82)
- ❌ ไม่แตะ throttle v6.83 / per-side reset v6.84
- ❌ ไม่แตะ `ClearBrokerTPSL` / `EnforceClearTPOnAllBound` (bound-only path แยกกัน)

## ผลลัพธ์
- คอลัมน์ **S/L บนทุก ticket แสดงราคา trailing SL จริง** แทน 0.00
- เห็น **เส้น broker SL บนชาร์ต** ที่วิ่งตาม trailing
- EA หลุด/disconnect → broker ปิดให้ตาม SL (failsafe จริง)
- ไม่เพิ่มความถี่ modify (throttle v6.83 ยังคุม)