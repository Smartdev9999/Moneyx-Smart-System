## แผนแก้ Golden2 EA v2.8.1

### 1) แก้ ATR/ADX ยังโชว์ใน Backtest แบบถูกจุด
สาเหตุหลักที่เจอ: โค้ดตอนนี้พยายามลบ indicator ด้วย `ChartIndicatorDelete()` หลังสร้าง handle แล้ว แต่เอกสาร MQL5 ระบุว่าต้องใช้ `TesterHideIndicators(true)` **ก่อนสร้าง handle** (`iATR`, `iADX`, `iBands`, `iMA`) เพื่อให้ Strategy Tester ไม่แปะ indicator ลง Visual Chart ตั้งแต่แรก

จะทำดังนี้:
- เพิ่ม `TesterHideIndicators(true)` ใน `OnInit()` ทันทีหลัง detect tester และ **ก่อน** สร้าง indicator handles ทั้งหมด
- คง `CleanupChartIndicatorsInTester()` และ `HideAuxiliaryTesterCharts()` เป็น safety sweep หลังสร้าง handle + ทุก 60 วินาที
- ปรับ cleanup ให้ลบ subwindow indicator ซ้ำได้หลายรอบใน call เดียว เพราะ ATR/ADX อาจอยู่คนละ subwindow และการลบ indicator หนึ่งทำให้จำนวน windows เปลี่ยน
- ไม่เพิ่ม input ใหม่ตามที่สั่ง: เปิดการซ่อนอัตโนมัติใน Strategy Tester เท่านั้น, live trading ไม่กระทบ

### 2) เอา Exit Expansion setting ที่ซ้ำซ้อนออกจาก input panel
ตอนนี้ Golden2 มีชุด Exit Triple Gate แยกเอง:
- `InpExitTF`
- `InpExitBBPeriod`
- `InpExitBBDev`
- `InpExitKeltnerATR`
- `InpExitKeltnerMult`

ซึ่งซ้ำกับ Squeeze Setting และทำให้ผู้ใช้สับสน

จะเปลี่ยนเป็น:
- เลิกใช้ `InpExitTF/BB/Keltner` สำหรับ gate นี้
- เปลี่ยน `IsExpansionToNormal()` ให้ใช้สถานะ Squeeze ปกติ โดยยึด **Timeframe ใหญ่ที่สุดของ Squeeze** = index 2 (`InpSQ_TF3`) เป็น gate ก่อน Matching Close
- ฝังค่า Exit BB/Keltner เดิมเป็น legacy/no-op หรือถอดจาก input ตาม scope ที่อนุมัติ เพื่อไม่ให้โชว์ในหน้า input
- ใช้ threshold และ confirm logic จาก Squeeze Settings เดิมทั้งหมด (`InpSQ_ExpansionThreshold`, ADX, ATR, EMA, BB breakout)

### 3) ทำ Expansion -> Normal gate แบบ per-group ไม่ใช่ snapshot ชั่วคราว
ปัญหาปัจจุบัน: `IsExpansionToNormal()` ดูแค่แท่งล่าสุดว่า “แท่งก่อน expansion / แท่งนี้ normal” ทำให้ถ้าจังหวะไม่ตรง tick matching close จะไม่ทำงาน

จะเพิ่ม state ต่อ group:
- เคยเห็น TF ใหญ่สุดของ Squeeze เป็น Expansion หลัง Hedge เปิดหรือยัง
- TF ใหญ่สุดกลับมา Normal หลังจากนั้นหรือยัง

พฤติกรรมใหม่:
- เมื่อ group มี hedge แล้ว ถ้า `g_sqExpansion[2] == true` → mark ว่าเห็น Expansion
- เมื่อเคยเห็น Expansion แล้ว `g_sqExpansion[2] == false` → mark ว่า Gate พร้อม
- `TryMatchingCloseForGroup()` จะใช้ gate นี้แทน `InpExitTF` เดิม
- ถ้า hedge เปิดตอน TF ใหญ่สุดเป็น Expansion ให้ถือว่าเริ่มนับ Expansion แล้ว เหมือน Gold Miner
- reset state เมื่อ group flat

### 4) เพิ่ม Dashboard ในหมวด Hedging ให้เหมือนตัวอย่าง Gold Miner
ใน Dashboard ฝั่ง Hedging/Right panel จะเพิ่มข้อมูลต่อ group ที่มี Hedge active:

```text
Hedge #1     BUY 1.20L PnL:$-12112.80 B:2
  Gate       T:SQ Cy:Wait Exp/Wait Norm/Ready Z:IN ZONE/OUT OK ... G:xx/need
  TripleGrid RECOVERY/READY/WAIT Seq:Gx ...
```

รายละเอียดที่จะแสดง:
- `Hedge #N`: side, lot, PnL, จำนวน bound/main orders
- `Gate`:
  - `T:SQ` = ใช้ Squeeze Setting ไม่ใช่ Exit BB/Keltner แยก
  - `Cy:Wait Exp / Wait Norm / Ready`
  - `Z:IN ZONE / OUT <dist>/<need>pts / OUT OK <dist>pts`
  - `G:<gain>/<InpExit_MinGainUSD>` สำหรับ Min Gain
- `TripleGrid`:
  - สถานะ matching/recovery ของ group
  - group ไหนรอ sequential queue
  - group ไหนอยู่ recovery/unblock แล้ว

### 5) ปรับ input ให้สอดคล้องกับที่ผู้ใช้ต้องการ
ใน `=== Exit Triple Gate ===` จะเหลือเฉพาะ input ที่ต้องปรับจริง:
- Enable Triple-Gate
- Allow continuation grid after hedge
- Breakout distance from average
- Min net USD profit
- Min hedge-group gain USD
- Close groups sequentially
- Recovery advance unblock

และเอา/ฝัง input ที่เป็น indicator setting ซ้ำซ้อนออกจากส่วนนี้:
- Exit TF
- Exit BB period/dev
- Exit Keltner ATR period/mult

ส่วน Squeeze Setting ยังเป็นที่เดียวที่ใช้ควบคุม Expansion/ADX/ATR/EMA ทั้งระบบ

### 6) อัปเดต Version และเอกสารความจำ
- เพิ่ม version จาก `2.80` เป็น `2.81`
- อัปเดต header comment, `#property description`, init log, Dashboard title เป็น v2.8.1
- เพิ่ม memory ใหม่สำหรับ Golden2 v2.8.1 เพื่อจำกฎว่า Hedging Exit ใช้ Squeeze TF ใหญ่สุด ไม่ใช้ Exit indicator settings ซ้ำ

### สิ่งที่ไม่เปลี่ยนแปลง
ยืนยันว่าจะไม่แตะ logic เหล่านี้:
- ไม่แก้ `trade.Buy`, `trade.Sell`, `trade.PositionClose`, `OrderSend`, `OrderModify`, `OrderDelete`
- ไม่แก้ Entry Mode: PENDING / SMA / INSTANT
- ไม่แก้ Grid Loss / Grid Profit lot, distance, candle confirm, ATR snapshot
- ไม่แก้ Hedge mirror 1:1, pending hedge, arm/disarm, block percent
- ไม่แก้ Average TP/SL, MaxGrid trailing, per-order trailing, accumulate close
- ไม่แก้ Force-close opposite unhedged
- ไม่แก้ ParseComment/MakeComment side-tag format

หลังอนุมัติ ผมจะทำเฉพาะใน `public/docs/mql5/Golden2_EA.mq5` และบันทึก memory ที่เกี่ยวข้องครับ