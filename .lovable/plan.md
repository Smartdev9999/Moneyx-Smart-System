

## v6.48 — Fix: Broker TP/SL Delay หลังเปิดออเดอร์ใหม่

### สาเหตุที่พบ (2 ปัญหาซ้อน)

**ปัญหาที่ 1: Throttle + Cache ทำให้ต้องรอ**
- `SyncBrokerTPSL()` มี throttle 2 วินาที (line 1372) — ไม่ได้เรียกทุก tick
- หลังเปิดออเดอร์ใหม่ ต้องรอจนกว่า throttle หมด TP ถึงจะถูก set
- แต่ 2 วินาทีก็ไม่ใช่เกือบนาที...

**ปัญหาที่ 2 (ตัวการจริง): Cache update ไม่สนใจว่า Modify สำเร็จหรือไม่**
- Lines 2111-2114: `g_lastBrokerTP_Buy = tpBuy` อัปเดต **ทุกครั้ง** ไม่ว่า `PositionModify` จะสำเร็จหรือล้มเหลว
- Line 2069: `buyChanged = (tpBuy != g_lastBrokerTP_Buy)` — ถ้า cache ถูก set แล้ว → `buyChanged = false` → **ข้ามทั้ง loop**
- ผลคือ: ถ้า PositionModify ล้มเหลวแม้แค่ครั้งเดียว (trade context busy, requote) → TP ไม่ถูก set → cache คิดว่า set แล้ว → **ไม่ retry อีกเลย** จนกว่า avg จะเปลี่ยน (เช่น เปิดออเดอร์ใหม่อีกตัว)
- ถ้าไม่มีออเดอร์ใหม่ TP จะไม่ถูก set เลย = delay ไม่จำกัด

**Flow ที่ผิด:**
1. เปิด grid order ใหม่ → avg เปลี่ยน → tpBuy ใหม่
2. SyncBrokerTPSL รัน → PositionModify ล้มเหลว (busy)
3. Cache ถูก set เป็น tpBuy ใหม่ทั้งที่ broker ยังไม่ได้ modify
4. รอบถัดไป: `buyChanged = false` → ข้ามทั้ง loop
5. TP ไม่ถูก set จนกว่าจะเปิดออเดอร์ใหม่อีกตัว (avg เปลี่ยนอีก)

### แผนแก้ไข — ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Version bump → v6.48

#### 2. Force immediate sync หลังเปิดออเดอร์ใหม่

ใน `OpenOrder()` หลัง `trade.Buy/Sell` สำเร็จ:
```text
// Reset broker sync timer + cache to force immediate TP/SL set on next tick
g_lastBrokerTPSLSync = 0;
g_lastBrokerTP_Buy = -1;
g_lastBrokerTP_Sell = -1;
g_lastBrokerSL_Buy = -1;
g_lastBrokerSL_Sell = -1;
```

#### 3. Fix cache — อัปเดตเฉพาะเมื่อ Modify สำเร็จจริง

```text
// Before (lines 2111-2114):
g_lastBrokerTP_Buy = tpBuy;    // Always update regardless

// After:
// Track success per side
bool buyModifyOK = true, sellModifyOK = true;

// In modify loop:
if(posType == BUY && buyChanged) {
   if(!trade.PositionModify(ticket, slBuy, tpBuy))
      buyModifyOK = false;  // Mark as failed
}

// After loop — only cache if ALL modifies succeeded:
if(buyModifyOK)  { g_lastBrokerTP_Buy = tpBuy; g_lastBrokerSL_Buy = slBuy; }
if(sellModifyOK) { g_lastBrokerTP_Sell = tpSell; g_lastBrokerSL_Sell = slSell; }
```

#### 4. ลบ buyChanged/sellChanged gate — เช็คจาก actual order TP แทน

แทนที่จะใช้ cache เป็นตัวตัดสินว่าต้อง modify หรือไม่ ให้เช็คจาก TP จริงบน order:
```text
// Remove buyChanged/sellChanged variables
// In modify loop, always check actual order values:
if(posType == BUY && avgBuy > 0) {
   if(NormalizeDouble(curTP, digits) != tpBuy || NormalizeDouble(curSL, digits) != slBuy)
      trade.PositionModify(ticket, slBuy, tpBuy);
}
```
วิธีนี้เรียบง่ายกว่า ไม่มี cache bug และ order ที่ TP ยังไม่ตรง จะถูก modify ทุกรอบ

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic — ไม่แก้
- Trading Strategy Logic — ไม่แก้
- Core Module Logic — ไม่แก้
- SyncBrokerTPSL TP/SL calculation — ไม่แก้ (แค่แก้ cache + retry logic)
- ClearBrokerTPSL — ไม่แก้
- HasActiveBoundHedgeSet — ไม่แก้
- Hedge recovery / Triple Gate / Matching Close — ไม่แก้
- Per-Order Trailing / DD trigger — ไม่แก้
- v6.37-v6.47 features — ไม่แก้

### ผลลัพธ์ที่คาดหวัง
- เปิดออเดอร์ใหม่ → tick ถัดไป SyncBrokerTPSL รันทันที (ไม่รอ 2 วินาที)
- PositionModify ล้มเหลว → retry ทุก 2 วินาทีจนกว่าจะสำเร็จ (ไม่ skip อีกต่อไป)
- TP/SL ปรากฏใน order ภายใน 1-2 ticks หลังเปิด

