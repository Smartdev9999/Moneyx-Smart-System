

## Golden2 EA v1.3 — Initial TP เฉพาะตอน 1 ไม้ + Auto-Switch เป็น Average TP/SL บน Broker

ปรับลอจิก **TP ฝั่ง Pre-Hedge** ให้สลับโหมดอัตโนมัติตามจำนวนไม้ในฝั่งนั้น โดยวาง TP/SL บน Broker ทุกไม้เหมือน Gold Miner

### ไฟล์ที่จะแก้
- `public/docs/mql5/Golden2_EA.mq5` (ไฟล์เดียว)

### Logic ใหม่ (Per Group, Per Side, Pre-Hedge เท่านั้น)

```text
ถ้า count(side) == 1 ไม้ (ยังไม่มี GL/GP เพิ่ม):
   → ใช้ Initial TP/SL เดิมของไม้นั้น (broker TP ติดอยู่จาก PlaceInitialFrame)
   → ไม่แตะอะไร

ถ้า count(side) >= 2 ไม้ (มี GL หรือ GP เพิ่มเข้ามา):
   → คำนวณ Average Price ของฝั่งนั้น
   → คำนวณ Average TP price = avg ± TP_PointsFromAverage × _Point
     (Buy: avg + 500pt, Sell: avg - 500pt)
   → คำนวณ Average SL price (ถ้าเปิดใช้)
   → SyncBrokerTPSL: เรียก PositionModify ทุกไม้ในฝั่งนั้น
     ให้ TP/SL = ราคา avg-TP/SL จุดเดียวกันทุกไม้
   → ไม้ที่ติดลบที่ TP นั้นจะถูกปิดพร้อมกัน → ผลรวมเป็นบวก
```

### การเปลี่ยนแปลง

**1) ฟังก์ชันใหม่: `SyncAverageTPSLToBroker(int g, int side)`**
- เงื่อนไขเข้าทำงาน: `CountGroupSide(g, side, false) >= 2` AND group ยัง **ไม่ถูก hedge match** (ก่อน strip)
- คำนวณ avg จาก positions ทั้งหมดของ (group, side, hedge=false)
- คำนวณ tpPrice / slPrice จาก inputs `TPAvg_PointsFromAvg` / `SLAvg_PointsFromAvg`
- Loop ทุก ticket ในฝั่งนั้น → `trade.PositionModify(tk, slPrice, tpPrice)`
- มี guard: ถ้า broker TP/SL ปัจจุบัน = ค่าใหม่ (within 1 point) → ข้าม (ลด traffic)
- เก็บ state `g_avgTPSyncedPrice[51][2]` เพื่อรู้ว่า sync ไปที่ราคาไหนล่าสุด
- ถ้า avg เปลี่ยน (ไม้ใหม่เพิ่ม) → re-sync ทุกไม้ใหม่อัตโนมัติ

**2) ฟังก์ชันใหม่: `RestoreInitialTPIfSingle(int g, int side)`**
- เงื่อนไข: `count == 1` แต่เคย sync avg ไปแล้ว (ฝั่งหลุดมาเหลือ 1 จาก shred-close)
- คืนค่า TP เดิมจาก `InpInitialTP_Points` (คำนวณจาก entry price ของไม้นั้น)
- หรือถ้า user ปิด initial TP → เคลียร์ TP/SL = 0

**3) เรียกใน `OnTick()` — ต่อจาก v1.1 Average TP/SL Manager**
```cpp
for(int g=1; g<=50; g++){
   if(g_groupActive[g] && !g_stripped[g]){
      SyncAverageTPSLToBroker(g, 0); // Buy
      SyncAverageTPSLToBroker(g, 1); // Sell
      RestoreInitialTPIfSingle(g, 0);
      RestoreInitialTPIfSingle(g, 1);
   }
}
```

**4) Inputs ใหม่ (กลุ่ม `=== Take Profit (Average) ===` ที่มีอยู่แล้ว v1.1)**
- เพิ่ม `TPAvg_AutoSyncToBroker` (bool, default `true`) — เปิด/ปิด auto-sync TP/SL บน broker
- ใช้ `TPAvg_PointsFromAvg` เดิม (default 500) เป็นจุดอ้างอิง
- ใช้ `SLAvg_PointsFromAvg` เดิม (default 0 = off)
- เพิ่ม `TPAvg_MinTicketsToActivate` (int, default 2) — ขั้นต่ำไม้ที่จะ trigger avg mode

**5) ความสัมพันธ์กับระบบเดิม**
- ✅ v1.1 `CheckAndCloseByAverageTP/SL` (modes Fixed Dollar / % Balance / Accumulate / DD%) — ยังทำงานเหมือนเดิม เป็น "soft close" by market
- ✅ v1.3 ใหม่: เพิ่ม "hard TP/SL บน broker" สำหรับ mode Points-from-Average โดยเฉพาะ → ปิดเร็วกว่า ไม่ต้องรอ tick
- ✅ `StripBrokerTPSL_OnHedgeMatch` (v1.1) — ทำงานก่อน v1.3 sync เสมอ (ถ้า stripped → skip sync)
- ✅ HLine display (v1.1) — ใช้ค่าเดียวกัน ไม่ต้องเพิ่ม object

**6) Dashboard เพิ่ม**
- "G[n] Buy TP-Mode: INITIAL(1) / AVG_BROKER(N ไม้) | TP@xxxx.xx"
- "G[n] Sell TP-Mode: ..."

**7) Version Bump → v1.3**
- `#property version "1.30"`
- `#property description` + Header + Dashboard อัปเดต

### สิ่งที่ "ไม่เปลี่ยนแปลง"
- ❌ ไม่แตะ `PlaceInitialFrame` (initial TP บน pending order ยังเหมือนเดิม)
- ❌ ไม่แตะ Order execution ทั้งหมด (`trade.Buy/Sell/BuyStop/SellStop/PositionClose`)
- ❌ ไม่แตะ Grid Loss / Grid Profit / Max Grid Trail (v1.2)
- ❌ ไม่แตะ Hedge logic, Triple-Gate, Strip-on-match (v1.0/v1.1)
- ❌ ไม่แตะ Group lifecycle / sequential queue
- ✅ เพิ่มเฉพาะ "broker TP/SL synchronization layer" — เรียก `PositionModify` เท่านั้น (ไม่ใช่ open/close)

### Technical Detail
- ใช้ `trade.PositionModify(ticket, sl, tp)` — ปลอดภัย ไม่กระทบ execution
- Tolerance check: `MathAbs(currentTP - newTP) > _Point` ถึง modify (กัน spam)
- สำหรับ broker บางเจ้าที่ reject TP ใกล้ราคา: เช็ค `SymbolInfoInteger(SYMBOL_TRADE_STOPS_LEVEL)` แล้วบังคับ TP ห่างขั้นต่ำ
- Re-sync trigger: เก็บ `g_lastSyncedAvg[51][2]`, ถ้า avg ใหม่ ≠ เดิม → modify ใหม่ทุกไม้
- SL=0 case: ถ้า `SLAvg_PointsFromAvg=0` → ส่ง SL=0.0 (no SL)

