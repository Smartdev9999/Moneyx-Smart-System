

## v6.42 — Broker-Level TP/SL (PositionModify) for Points Mode

### ปัญหาปัจจุบัน

TP/SL แบบ Points ปัจจุบันทำงานโดย EA ตรวจสอบราคาทุก tick แล้วปิดเอง → ถ้า EA ช้า (dashboard หนัก, tick lag) ราคาอาจวิ่งผ่าน TP ไปแล้วก่อนที่ EA จะทันปิด

### แนวทางแก้ไข

เปลี่ยนจาก "EA เช็คราคาแล้วปิดเอง" → **"EA คำนวณราคา TP/SL แล้วเซ็ตลงในออเดอร์ผ่าน `trade.PositionModify()`"** ให้ Broker เป็นคนปิดแทน

**ใช้ได้เฉพาะ Points mode** (`UseTP_Points`, `UseSL_Points`) เท่านั้น เพราะ Dollar/Percent ต้องคำนวณจาก PL/Balance แบบ real-time ซึ่ง broker ทำไม่ได้

### ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Version bump → v6.42

#### 2. เพิ่ม function ใหม่ `SyncBrokerTPSL()`

```text
void SyncBrokerTPSL()
- คำนวณ avgBuy, avgSell
- คำนวณ tpPriceBuy = avgBuy + TP_Points * point
- คำนวณ tpPriceSell = avgSell - TP_Points * point  
- คำนวณ slPriceBuy = avgBuy - SL_Points * point (ถ้าเปิด SL Points)
- คำนวณ slPriceSell = avgSell + SL_Points * point
- Loop ทุก position ของ symbol:
  - ถ้าเป็น BUY → PositionModify(ticket, slPrice, tpPriceBuy)
  - ถ้าเป็น SELL → PositionModify(ticket, slPrice, tpPriceSell)
- เซ็ตเฉพาะเมื่อ TP/SL เปลี่ยนจากค่าเดิม (ป้องกัน modify ซ้ำทุก tick)
```

#### 3. เรียก `SyncBrokerTPSL()` ใน OnTick

- เรียกหลังจากมีการเปิดออเดอร์ใหม่ หรือทุก N วินาที (เช่น ทุก 2 วินาที) เพื่อไม่ให้ modify ทุก tick
- เมื่อ avg เปลี่ยน (เพราะเพิ่ม GL ใหม่) → TP/SL ของทุกออเดอร์จะถูกอัปเดตตาม avg ใหม่อัตโนมัติ

#### 4. แก้ `ManageTPSL()` — ข้าม Points check เมื่อใช้ Broker TP

- เมื่อ `UseTP_Points = true` → **ไม่ต้อง** check `bid >= avgBuy + TP_Points` ใน EA อีกแล้ว เพราะ broker จะปิดให้
- คงเหลือ Dollar / Percent / DD% TP ให้ EA จัดการเหมือนเดิม
- เช่นเดียวกับ SL Points → broker จัดการ, SL Dollar/Percent → EA จัดการ

#### 5. จัดการ Accumulate Close / Trailing

- Average Trailing Stop: เมื่อ trailing ขยับ SL → `SyncBrokerTPSL()` จะ update SL ของทุกออเดอร์ตาม
- Accumulate Close: ยังทำงานผ่าน EA เหมือนเดิม (เพราะเป็น logic ซับซ้อน)
- MaxGrid Trailing: ยังทำงานผ่าน EA เหมือนเดิม

#### 6. Reset TP/SL เมื่อปิดชุด

- เมื่อ `CloseAllSide()` ถูกเรียก → ออเดอร์ถูกปิดหมด → ไม่ต้อง reset
- เมื่อ hedge lock active → clear broker TP/SL (set เป็น 0) เพราะไม่ต้องการให้ broker ปิดระหว่าง hedge

#### 7. Dashboard — เพิ่มแสดง Broker TP/SL price

#### 8. รวม Dashboard Cache fix (v6.42 เดิม) เข้าด้วย

- Cache history functions ทุก 5 วินาที แทนที่จะคำนวณทุก tick

### ตัวอย่าง Flow

1. มี BUY INIT + 5 GL → avg = 2000.00 → TP_Points = 500
2. EA คำนวณ tpPrice = 2000.00 + 500*0.01 = 2005.00
3. EA เรียก `PositionModify()` ให้ทุก 6 ออเดอร์มี TP = 2005.00
4. เปิด GL ใหม่ → avg เปลี่ยนเป็น 1999.50 → tpPrice = 2004.50
5. EA อัปเดต TP ของทุกออเดอร์เป็น 2004.50
6. ราคาวิ่งถึง 2004.50 → **Broker ปิดทุกออเดอร์ทันที** (ไม่ต้องรอ EA)

### สิ่งที่ไม่เปลี่ยนแปลง

- Order Execution Logic — ไม่แก้ (ใช้ PositionModify เพื่อ set TP/SL เท่านั้น ไม่ใช่เปิด/ปิดออเดอร์)
- Trading Strategy Logic — ไม่แก้
- Core Module Logic — ไม่แก้
- Dollar/Percent/DD% TP modes — ยังทำงานผ่าน EA เหมือนเดิม
- Accumulate Close / Drawdown Exit — ไม่แก้
- Grid distance / min gap / new candle / candle confirm — ไม่แก้
- DD trigger / Hedge / Balance Guard — ไม่แก้
- v6.37-v6.41 features — ไม่แก้

