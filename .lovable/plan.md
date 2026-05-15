## ปัญหาที่พบ (จากภาพและคำอธิบาย)

1. **Match-Close ทำงาน + วาง Recovery แล้ว แต่ระบบไม่ปิดต่อ** — เพราะหลัง hedge matched ครั้งแรก โค้ด v1.1 ตั้ง `g_stripped[g]=true` แล้ว `SyncSideTPSLToBroker()` `early-return` ทันที ทำให้ออเดอร์ที่เหลือ (residual main + hedge + RC#N ใหม่) **ไม่มี broker TP/SL เลย** — ต้องรอราคาวิ่งแล้วให้ Triple-Gate รอบใหม่ปิดเท่านั้น ซึ่งอาจไม่เกิดขึ้น
2. **Dashboard Hedging panel ยาวเกินไป** — โชว์ `Grid#1..#5 L:.. H:.. N:..` ทุกกลุ่ม กินพื้นที่
3. **ลำดับการปิดยังไม่ครบตามที่ต้องการ** — User ต้องการให้ก่อนวาง Recovery ระบบต้องรวม "ทุก order ที่บวก" ในกรุ๊ป (ไม่ว่าจะ Bound/Hedge/Loss-Bound) มาเป็น pool ปิดออเดอร์ที่ลบให้มากที่สุดก่อน

## แผนแก้ไข v2.8.4 (`public/docs/mql5/Golden2_EA.mq5` เท่านั้น)

### 1) Post-Match Avg Broker TP/SL Manager (ฟีเจอร์ใหม่)

ฟังก์ชันใหม่ `SyncPostMatchAvgTPSL(int g)` — เรียกทุก tick สำหรับกลุ่มที่ `g_stripped[g]==true && GroupHasAnyPositions(g)`:

- คำนวณ **avg price แยกฝั่ง** จาก *ทุก* position ในกรุ๊ป (รวม main+hedge+RC) ตาม side BUY/SELL — ใช้ helper เดิม `GroupAveragePrice(g, side, -1)` (hedge=-1 = ทุกประเภท)
- คำนวณ TP price ต่อฝั่ง: `avgBuy + InpTP_PointsFromAvg*g_point` / `avgSell - InpTP_PointsFromAvg*g_point`  
  SL price (ถ้า `InpSL_Enable && InpSL_UsePointsFromAvg`)
- เคารพ `SYMBOL_TRADE_STOPS_LEVEL` (โค้ดเดิมใน `SyncSideTPSLToBroker` มีอยู่แล้ว — ลอกแบบ)
- วน push TP/SL เดียวกันลงทุก ticket ฝั่งนั้น (รวม hedge ตรงข้าม side ด้วย — แต่ละด้านใช้ avg ของฝั่งตัวเอง)
- Cache `g_postMatchTP[g][side]` + `g_postMatchSL[g][side]` กัน MODIFY ซ้ำเกิน tolerance 1 point
- เคลียร์ cache เมื่อ group flat
- เปิด/ปิดด้วย input ใหม่ `InpPostMatch_AvgBrokerTP = true`

จุดเรียก: ใน OnTick group loop หลัง `TryMatchingCloseForGroup(g)` — ถ้า `IsGroupHedgeMatched(g)` หรือ `g_stripped[g]` → `SyncPostMatchAvgTPSL(g)`

### 2) Pre-Recovery Pool Close (ทำให้สเปคชัดขึ้น)

ก่อนเรียก `PlaceRecoveryGridIfNeeded()` ใน `TryMatchingCloseForGroup`:

- เพิ่มฟังก์ชัน `ShredAllNegativeFromAllProfit(int g)` — สแกนทุก position ในกรุ๊ป (ทุก side, main+hedge), แยก `profitable[]` (P+swap≥0) กับ `losing[]` (P+swap<0), เรียงกำไรมากสุด→น้อยสุด, ขาดทุนน้อยสุด→มากสุด, แล้วใช้ pool กำไรปิดไม้ขาดทุนตราบที่ `pool + p ≥ InpExitMinNetUSD`
- เรียกหลัง `CloseAllGroupSide(winSide)` + `ShredCloseLosingSide(losSide,pool)` (ของเดิม) — เป็น "second pass" ที่กวาดกำไรเหลือไปปิดขาดทุนเพิ่มเติมข้ามฝั่ง
- ถ้ายังเหลือ residual → set `g_groupInRecovery=true` + เรียก `PlaceRecoveryGridIfNeeded` (เหมือนเดิม)

### 3) ลด Dashboard Hedging Panel

ใน DrawRightPanel ส่วน hedge-active groups (รอบ line 3393–3439):
- **ลบ** loop `Grid#N L:.. H:.. N:..` (lines 3393–3430) ออกทั้งหมด
- **ลบ** Recovery row แบบยาว เปลี่ยนเป็น 1 บรรทัดสรุป
- เก็บไว้: `G{n}* ACTIVE  MainL  HdgL  P/L  Pend  DD%`, `Gate ...`, `TripleGrid G:gain/need [RECOV RC#N/Max]`
- เพิ่มบรรทัดเดียว `Avg TP  B:<price>  S:<price>` เมื่อ post-match avg sync ทำงานอยู่ (จาก cache `g_postMatchTP`)
- Drop input `InpDashGridPairsMax` (เก็บไว้เป็น const เพื่อ .set backward-compat)

### 4) Version & Logging

- `#property version "2.84"` + description + dashboard title `Golden2 EA v2.8.4` + init log
- Log เมื่อ post-match sync ทำงานครั้งแรกต่อกรุ๊ป: `G%d POST-MATCH AVG-TP synced BUY tp=... SELL tp=... tickets=N`
- Log pre-recovery cross-side shred: `G%d CROSS-SIDE SHRED pool=... closed=N residual=N`

### 5) Memory

- สร้าง `mem://trading/golden2-ea/v2-8-4-post-match-avg-broker-tp-recovery.md`
- อัปเดต `mem://index.md`

## สิ่งที่ "ห้ามแตะ" (กฎเหล็ก MQL5)

- ❌ Entry SMA/INSTANT/PENDING flow, Squeeze BB/KC/ADX/EMA/ATR
- ❌ Grid Loss/Profit lot/distance/candle confirm
- ❌ Hedge mirror 1:1, pending hedge, arm/disarm, block percent
- ❌ Avg TP/SL ฝั่ง pre-hedge (`SyncSideTPSLToBroker`) — เพิ่มฟังก์ชัน *ใหม่* แยกต่างหาก ไม่แก้อันเดิม
- ❌ Per-order trail / Bar-close trail / Cost-Hit / Accumulate
- ❌ ParseComment / MakeComment B_/S_ tags
- ❌ ATR/ADX TesterHideIndicators (v2.8.1)
- ❌ Sequential Queue / MinGainUSD / Squeeze TF3 latch (v2.8.0/v2.8.1)
- ❌ Prior-group advance guard (v2.8.2)
- ❌ Win-Pool gate + Recovery placement (v2.8.3) — ขยายเพิ่ม ไม่แก้ของเดิม

## ผลลัพธ์ที่คาดหวัง

- หลัง Match-Close ครั้งแรก: ออเดอร์ที่เหลือทั้งกรุ๊ป (main residual + hedge + RC#N) ทุกตัวจะมี broker TP/SL ตามค่าเฉลี่ยฝั่งตัวเอง → broker ปิดให้เองเมื่อราคาแตะ avg+offset แม้ EA ไม่ trigger Match-Close รอบใหม่
- ก่อนวาง Recovery: ระบบจะกวาดกำไรทุกออเดอร์ในกรุ๊ป (รวม hedge ฝั่งกำไร + bound/loss-bound ที่บังเอิญบวก) ไปปิดไม้ขาดทุนให้มากที่สุดก่อน → Recovery ใช้เป็น "ตัวต่อ" จริง ๆ ไม่ใช่ทางรอดเดียว
- Dashboard กระชับ: ต่อกรุ๊ปเหลือ 3–4 บรรทัด (Status/Gate/TripleGrid/AvgTP เมื่อมี) ไม่ยาวล้นจอ
