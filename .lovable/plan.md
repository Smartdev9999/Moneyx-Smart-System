

## v6.50 — Set TP ตอนเปิดออเดอร์ทันที + Immediate Modify หลัง Grid

### สาเหตุที่ยังช้า

แม้ v6.49 จะ defer sync แล้ว แต่ `SyncBrokerTPSL()` ยังมี **2-second throttle** (`TimeCurrent() - g_lastBrokerTPSLSync >= g_brokerTPSLIntervalSec`) และต้องรอ tick ถัดไปถึงจะรัน ทำให้ TP ยังไม่ปรากฏทันทีหลังเปิดออเดอร์

### แผนแก้ไข — ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Version bump → v6.50

#### 2. ใส่ TP ตรงตอน OrderSend เลย (INIT order)

แก้ `OpenOrder()` — คำนวณ TP ก่อนส่งคำสั่ง:
- ถ้าเป็นออเดอร์ตัวแรก (ยังไม่มี position ฝั่งนั้น) → avg = price ของตัวเอง → สามารถคำนวณ TP ได้ทันที
- ใส่ TP เข้าไปใน `trade.Buy(lots, _Symbol, price, sl, tp, comment)` โดยตรง
- ไม่ต้องรอ SyncBrokerTPSL อีกต่อไปสำหรับออเดอร์แรก

```text
// Pre-calculate TP for INIT order (single order = avg is its own price)
double preTP = 0, preSL = 0;
if(!IsHedgeComment(comment))
{
   double existingLots = CalculateTotalLots(side);
   if(existingLots == 0)  // First order — avg = this order's price
   {
      if(UseTP_Points)
         preTP = (side==BUY) ? price + TP_Points*point : price - TP_Points*point;
      else if(UseTP_Dollar && tickValue > 0)
      {
         double dist = TP_DollarAmount / (lots * tickValue / tickSize);
         preTP = (side==BUY) ? price + dist : price - dist;
      }
      // ... PercentBalance mode similarly
   }
}
trade.Buy(lots, _Symbol, price, preSL, preTP, comment);
```

#### 3. Immediate SyncBrokerTPSL หลังเปิด Grid order

สำหรับออเดอร์ Grid (ไม่ใช่ตัวแรก) → avg เปลี่ยน → ต้อง modify ทุกออเดอร์:
- หลัง `trade.Buy/Sell` สำเร็จ → เรียก `SyncBrokerTPSL()` ทันทีใน `OpenOrder()` เลย (ไม่รอ tick ถัดไป)
- ข้าม throttle check เพราะเรียกตรงจาก OpenOrder

```text
// After trade success:
if(!IsHedgeComment(comment))
{
   SyncBrokerTPSL();  // Immediate — recalculate avg and modify ALL orders NOW
}
```

#### 4. สรุป Flow ใหม่

```text
INIT order:  trade.Buy(lots, price, sl, tp) → TP ติดมาตั้งแต่เปิด (0 delay)
Grid order:  trade.Buy(lots, price, 0, 0) → SyncBrokerTPSL() ทันที → modify ทุกตัว (< 100ms)
```

### สิ่งที่ไม่เปลี่ยนแปลง
- Trading Strategy Logic — ไม่แก้
- Grid entry/exit logic — ไม่แก้
- SyncBrokerTPSL calculation logic — ไม่แก้ (ใช้สูตรเดิม แค่เรียกเร็วขึ้น)
- Hedge / Bound / Matching Close — ไม่แก้
- Deferred Data Sync (v6.49) — ยังทำงานเหมือนเดิม
- v6.37-v6.49 features — ไม่แก้

### ผลลัพธ์ที่คาดหวัง
- INIT order: TP ปรากฏทันทีตั้งแต่เปิด (ไม่ต้อง modify)
- Grid order: TP ทุกออเดอร์ถูก modify ทันทีหลังเปิด (ไม่ต้องรอ tick/throttle)
- ไม่มี delay อีกต่อไป

