# Golden2 EA v2.4 — Symmetric Initial Frame Trail

## ที่มาของปัญหา (จากภาพ backtest)

หลัง G2 hedge MATCHED ระบบ advance ไป G3 ตอน 08:44:57 วาง:
- BuyStop #125 @ 4601.01 (TP 4604.01)
- SellStop #126 @ 4591.01 (TP 4588.01)

จากนั้นราคาวิ่ง **ขึ้น** จาก ~4591 → ~4601:
- SellStop #126 ถูก trail ขึ้นตามราคา (4591 → 4597) ✅
- **BuyStop #125 ไม่เคยถูก trail** ❌ → โดนชนที่ 09:04:45 ที่ 4601.04
- กลายเป็น G3_IN BUY orphan position → `IsGroupSafeToAdvance(G3)=false` → G4 ไม่ถูกเปิด
- 09:06:45 TP hit @ 4604.01 → ปิดด้วย opposite (#127) → ดูในตารางเหมือน "BuyStop หาย"

## Root Cause

`ManageInitialTrailOnBarClose` (บรรทัด 789-872) ปัจจุบันออกแบบ trail แบบ **asymmetric**:
- BuyStop: trail เฉพาะเมื่อ `newPx < oldPx` (ราคาลง → ดึง BuyStop ลง)
- SellStop: trail เฉพาะเมื่อ `newPx > oldPx` (ราคาขึ้น → ดึง SellStop ขึ้น)

→ ฝั่งที่ราคา **วิ่งเข้าหา** จะอยู่นิ่งและโดนชน แทนที่จะเลื่อนหนีเพื่อรักษาระยะกรอบ

## เป้าหมาย v2.4

ทำให้กรอบ Initial Frame "เลื่อนตามราคา" (recenter) — ทั้ง BuyStop และ SellStop ขยับพร้อมกันให้ห่างจาก mid market ตามค่า `InpFrameUpperPips` / `InpFrameLowerPips` ตลอดเวลา จนกว่าจะมีฝั่งใดฝั่งหนึ่ง trigger

## การแก้ไข (เฉพาะใน `ManageInitialTrailOnBarClose`)

### 1. Symmetric trail — เลื่อนทั้ง 2 stop ให้ห่าง mid เท่าเดิม
- คำนวณ `mid = (ask+bid)/2` ทุก bar close
- BuyStop ใหม่: `mid + InpFrameUpperPips`
- SellStop ใหม่: `mid - InpFrameLowerPips`
- เลื่อนเมื่อ `|newPx - oldPx| > InpFrameRecenterMinPips * point` (default 50 pip = 0.5$ ของทอง) เพื่อกัน micro-move

### 2. เพิ่ม Input ใหม่
```cpp
input bool InpFrameSymmetricTrail   = true;  // v2.4: trail both pendings to recenter on market
input int  InpFrameRecenterMinPips  = 50;    // v2.4: min mid-shift (in pips) before recentering
```

### 3. รักษา TP/SL เดิม (logic เดียวกับ v2.2)
- ถ้า `InpInitialTPPips > 0` → shift TP/SL ตาม delta (newPx - oldPx)
- ถ้าไม่ใช่ → forward ค่าเดิม

### 4. Diagnostic Log
เพิ่ม log: `Golden2 v2.4: Recenter G%d mid=%.5f BuyStop %.5f->%.5f SellStop %.5f->%.5f`

## สิ่งที่ไม่เปลี่ยนแปลง (ตามกฎเหล็ก)

✅ **ไม่แตะ Order Execution Logic** — ไม่แก้ `trade.BuyStop`, `trade.SellStop`, `trade.OrderSend`
✅ **ไม่แตะ Trading Strategy** — Grid Loss/Profit, Hedging, Triple-Gate, Accumulate Close ไม่เปลี่ยน
✅ **ไม่แตะ Core Modules** — License, News, Time filter ไม่เปลี่ยน
✅ **ไม่แตะ `PlaceInitialFrame`** — สูตร Frame Upper/Lower เดิม
✅ **ไม่แตะ `IsGroupSafeToAdvance` / hedge guard** ของ v2.3
✅ **ไม่แตะ `ManageInitialTrail` (legacy)** — ยังคง freeze หลังมี hedge

## ผลที่คาดหวัง

- BuyStop และ SellStop ของกรอบ Initial เลื่อนพร้อมกันตาม mid market
- ราคาเด้งกลับมา 600+ pip จะไม่ "ชน" pending stop ที่อยู่นิ่ง
- ลด orphan IN position หลัง advance group
- G3, G4, G5 ... จะไม่ค้างเพราะกรอบโดนชนทันทีหลัง place

## Version Bump

อัปเดตเป็น **v2.4** ที่:
- Header comment block
- `#property version "2.40"`
- `#property description`
- Dashboard `L_TITLE` ("Golden2 v2.4")
- `OnInit` log

## ไฟล์ที่แก้

- `public/docs/mql5/Golden2_EA.mq5`
- บันทึก memory `mem://trading/golden2-ea/v2-4-symmetric-frame-trail.md`

ขออนุมัติเพื่อเริ่ม implement ครับ
