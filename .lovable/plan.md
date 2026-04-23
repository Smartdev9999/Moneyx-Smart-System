

## v6.77 — บังคับเคลียร์ Broker TP/SL ของออเดอร์ที่ถูก Bound ทันทีเมื่อเปิด Hedge

### วินิจฉัยจากภาพ image-962
ในภาพออเดอร์ฝั่ง buy (GM1_INIT, GM1_GL#1..#7) **ทุกตัวยังมีค่า TP = 5359.50** ทั้งที่ตอนนี้ระบบเปิด `GM_Hedge_E1` (sell 1.04 lot) เพื่อล็อคแล้ว → ราคามีโอกาสวิ่งขึ้นไปชน TP 5359.50 แล้วโบรกเกอร์จะปิดบางออเดอร์ของฝั่ง buy ออกไปเอง ทำให้การ lock พัง (boundLots ลด แต่ hedgeLots คงเดิม → เกิด lot inflation ตามที่ `AuditHedgeSetIntegrity` คอยเตือน)

### Root Cause

ใน `Gold_Miner_EA.mq5`:

1. ตอน `OpenOrder()` ทุกออเดอร์ปกติ (INIT/GL/GP) ถูกตั้ง **broker TP** ทันทีจาก `preTP` (บรรทัด ~2052–2089) และยิ่งเปิดไม้ใหม่ ทุกตัวจะถูก `SyncBrokerTPSL()` อัปเดตให้ใช้ avg TP เดียวกัน (5359.50 ในภาพ)
2. ตอนเปิด hedge ที่บรรทัด 8688–8711 มีการ bind ตั๋วเก่าทั้งหมดเข้า set → set กลายเป็น active
3. หลังจาก bind **โค้ดไม่ได้สั่ง `PositionModify(ticket, 0, 0)` ทันที** เพื่อเคลียร์ TP/SL ของตั๋วที่เพิ่ง bind
4. การเคลียร์ TP/SL ของ bound จะรอให้ `SyncBrokerTPSL()` รอบถัดไปเรียก `ClearBrokerTPSL()` ซึ่ง:
   - ติด **gate timer 2 วินาที** (`g_brokerTPSLIntervalSec = 2`)
   - ติด **gate โหมด TP**: ถ้า user ไม่ได้เปิด `UseTP_Points/Dollar/PercentBalance` หรือ SL_Points → loop ที่บรรทัด 1514 ไม่ทำงานเลย → **TP เก่าค้างถาวร**
   - แม้จะรัน ก็ยังมีช่วง 0–2 วิที่ราคาอาจวิ่งชน TP เก่าก่อน

### แผนแก้ v6.77 (Fix-only)

ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1) เพิ่ม helper `ClearBrokerTPSLForSet(int slot)`
- รับ slot ของ hedge set
- วน `boundTickets[]` ของ slot นั้น
- สำหรับแต่ละ ticket: ถ้า `POSITION_TP != 0 || POSITION_SL != 0` → `trade.PositionModify(ticket, 0, 0)`
- log: `v6.77 ClearTP-OnBind: set#X ticket #Y TP=A→0 SL=B→0`
- ไม่แตะ hedge ticket, ไม่แตะออเดอร์อื่นนอก set

#### 2) เรียก `ClearBrokerTPSLForSet(slot)` **ทันทีหลัง bind ในจุดที่เปิด hedge**

เรียกเพิ่มที่ทุกจุดที่มี bind loop:
- หลังบรรทัด ~8711 (จุดเปิด DD hedge หลัก) — เรียกก่อน increment generation
- หลังบรรทัด ~8964 (path เปิด hedge อีก path)
- หลังบรรทัด ~9186 (path สามที่ bind)
- หลังบรรทัด ~9864 (path เปิด hedge ผ่าน reverse-binding)

โดยเรียกหลังจาก `boundTicketCount` ถูกเซ็ตเสร็จ และก่อน `g_hedgeSetCount++`

#### 3) เพิ่ม Safety Sweep ใน `OnTick` (ทุก tick)
เพิ่ม helper `EnforceClearTPOnAllBound()`:
- วนทุก hedge set ที่ `active`
- เคลียร์ TP/SL ของ bound ticket ใดก็ตามที่ยังเหลือค่า ≠ 0
- เรียกจาก `OnTick` **ก่อน** `SyncBrokerTPSL()` และ **ไม่มี gate timer / TP-mode**
- ป้องกันกรณีที่ user ปิดทุกโหมด TP/SL → block 2s + missed sync จะไม่ทำให้ TP ค้าง

ตำแหน่งเรียก: ใน `OnTick()` ใกล้บรรทัด ~1513 ก่อน `if(UseTP_Points || ...)` block

#### 4) Reset `g_lastBrokerTP_Buy/Sell` cache หลัง bind
หลังเรียก `ClearBrokerTPSLForSet`:
```cpp
g_lastBrokerTP_Buy = -1;
g_lastBrokerTP_Sell = -1;
g_lastBrokerSL_Buy = -1;
g_lastBrokerSL_Sell = -1;
g_lastBrokerTPSLSync = 0;
```
เพื่อให้ next sync บังคับเช็คใหม่จริง ไม่ใช้ cache เก่า

#### 5) Version bump → v6.77
- `#property version "6.77"`
- `#property description "Gold Miner EA v6.77 - v6.76 + force-clear broker TP/SL on bound tickets immediately at hedge open + per-tick safety sweep"`
- Header comment block
- Dashboard footer

### สิ่งที่ไม่เปลี่ยนแปลง (กฎเหล็ก)
- ไม่แก้ `OpenOrder / OpenOrderTF / trade.Buy / trade.Sell / trade.PositionClose`
- ไม่แก้เงื่อนไขเปิด hedge / DD / Triple Gate / Sequential FIFO / Strict FIFO
- ไม่แก้ `CalculateGridLot / FindMaxLotOnSide / lot sizing`
- ไม่แก้ `ManageRecoveryOwnerAvgTP` (ตั๋ว owner-gen ยัง bypass การเคลียร์ตามเดิมเพราะ `IsTicketBound=false`)
- ไม่แก้เงื่อนไขเปิด GL/GP, BB filter, distance, ATR, candle confirmation
- ไม่แก้ License / News / Time filter
- ไม่แตะ MaxOpenOrders / MaxTrades / Match-Close pool
- การ matching/release/cooldown ของ hedge ยังทำงานเหมือนเดิม

### ผลลัพธ์ที่คาดหวัง
- ทันทีที่ hedge เปิดและ bind ตั๋วเก่า → ทุกตั๋วที่ bound จะถูก `PositionModify(ticket, 0, 0)` ทันใน tick เดียวกัน
- ราคาวิ่งไปชน 5359.50 จะ **ไม่ทำให้โบรกเกอร์ปิดออเดอร์ใดเลย** เพราะ TP=0 แล้ว
- การ lock สมบูรณ์ — `boundLots` ไม่ลดแบบไม่คาดคิด → ไม่มี lot inflation
- Per-tick sweep รับประกันว่าแม้ user ปิดโหมด TP ทุกประเภท หรือ sync 2s plays late → bound ticket TP ก็ยัง = 0 ตลอดเวลา
- เมื่อ hedge set ถูก release/closed ทั้งหมด → `IsTicketBound=false` → `SyncBrokerTPSL` กลับมาตั้ง avg TP ใหม่ตามปกติ

### ความเสี่ยง & Mitigation
- **Risk**: เคลียร์ TP ของ bound แล้ว ถ้า hedge หลุดไปเอง ตั๋วเก่าจะไม่มี TP ทันที
- **Mitigation**: เมื่อ set deactivate → ตั๋วไม่ถูก bound อีก → `SyncBrokerTPSL` รอบถัดไป (สูงสุด 2 วิ) จะตั้ง avg TP คืน — พฤติกรรมเดียวกับ v6.46–v6.76 อยู่แล้ว

- **Risk**: Per-tick sweep อาจเรียก `PositionModify` บ่อย
- **Mitigation**: sweep จะ skip ทุก ticket ที่ TP=0 และ SL=0 อยู่แล้ว → modify ครั้งเดียวต่อตั๋วต่อ bind, ไม่สแปม

- **Risk**: ถ้า broker reject `PositionModify(0,0)`
- **Mitigation**: log error + retry ทุก tick จนสำเร็จ (sweep จะลองซ้ำเอง)

