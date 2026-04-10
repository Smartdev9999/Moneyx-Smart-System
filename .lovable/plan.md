

## v6.40 — เพิ่ม Grid Loss Candle Confirmation Filter

### หลักการ

เพิ่มเงื่อนไขกรองก่อนเปิด Grid Loss: ต้องมีแท่งเทียนปิดในทิศทางเดียวกับฝั่งที่จะเปิด GL ก่อน N แท่ง (ตามที่กำหนด) ก่อนระบบจะอนุญาตให้เปิด GL

- BUY GL: ต้องมีแท่งเขียว (close > open) ปิดก่อน N แท่ง
- SELL GL: ต้องมีแท่งแดง (close < open) ปิดก่อน N แท่ง
- ตั้งค่า 0 = ปิดฟีเจอร์ (ไม่กรอง)
- เป็นเงื่อนไขเสริม ต้องผ่านเงื่อนไขอื่นๆ (distance, min gap, new candle) ด้วย

### ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Version bump → v6.40

#### 2. เพิ่ม input parameter (ใต้ GridLoss_MinGapPoints)

```cpp
input int GridLoss_CandleConfirm = 0; // v6.40: Require N confirming candles before GL (0=Off)
```

#### 3. เพิ่ม helper function

```cpp
bool HasCandleConfirmation(ENUM_POSITION_TYPE side, ENUM_TIMEFRAMES tf, int requiredCandles)
```

- ตรวจสอบ N แท่งเทียนล่าสุดที่ปิดแล้ว (shift 1 ถึง N) ว่ามีแท่งที่ปิดในทิศทางที่ต้องการครบตามจำนวนหรือไม่
- BUY: นับแท่งที่ close > open (bullish) จากแท่งล่าสุดที่ปิดแล้ว
- SELL: นับแท่งที่ close < open (bearish)
- หากมีครบ N แท่ง (ไม่จำเป็นต้องต่อเนื่อง แต่ต้องเป็นแท่งล่าสุดติดกัน N แท่ง) → return true
- **แก้ไข**: ตรวจ N แท่งล่าสุดที่ปิดแล้ว (shift 1..N) ว่าทั้งหมดเป็นทิศทางเดียวกัน → ถ้าต้องการ "ปิด 1 แท่ง" ก็ตรวจแค่ shift=1 ว่าเป็น bullish/bearish

#### 4. เพิ่ม guard ใน 3 จุด Grid Loss entry

- **SMA mode** `CheckGridLoss()` (~line 2540 หลัง OnlyNewCandle): เพิ่ม check `GridLoss_CandleConfirm`
- **Instant/ZigZag mode** `CheckGridLossTF()` (~line 4123 หลัง OnlyNewCandle): เพิ่ม check
- **Orphan grid** `CheckOrphanGridEntry()` (~line 7762 หลัง OnlyNewCandle): เพิ่ม check

#### 5. Dashboard แสดงค่า CandleConfirm

#### 6. อัปเดต version ทุกจุด

### ตัวอย่าง
- ตั้ง 1: มี BUY INIT → ราคาลง → ถึงระยะ GL → ต้องรอแท่งเขียวปิด 1 แท่งก่อน → ถึงจะเปิด GL BUY
- ตั้ง 2: ต้องมีแท่งเขียวปิดติดกัน 2 แท่งก่อน
- ตั้ง 0: ปิดฟีเจอร์ ทำงานเหมือนเดิม

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic — ไม่แก้
- Trading Strategy Logic — ไม่แก้ (เป็น guard เสริมเท่านั้น)
- Core Module Logic — ไม่แก้
- Grid distance / min gap / new candle / signal filter — ไม่แก้
- DD trigger / Hedge / Balance Guard — ไม่แก้
- Gen Race fix (v6.37), Orphan fix (v6.38), Side Pause (v6.39) — ไม่แก้

