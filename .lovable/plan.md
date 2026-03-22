

## Fix: Grid Recovery ไม่เปิด Order + Cycle Recycling + Dashboard Styling (v5.12 → v5.13)

### สิ่งที่แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. Grid Recovery — เปิด Order แรกที่ราคาตลาดทันที
- เมื่อ `hedgeTicket == 0` (recovery mode) และไม่มี grid order → เปิด order แรกที่ market price โดยไม่ต้องเช็ค distance
- แก้ปัญหา reference price จาก bound orders ที่อยู่คนละโซนราคา → distance ติดลบ → ไม่มีทางเปิด order ได้

#### 2. Cycle Recycling — `FindLowestFreeCycle()`
- เพิ่มฟังก์ชันใหม่ที่สแกน cycle 0-6 หา slot แรกที่ว่าง (ไม่มี active hedge set หรือ open orders)
- แทนที่ linear increment `g_currentCycleIndex++` ด้วย `FindLowestFreeCycle()` ใน 6 จุด
- ทำให้ cycle กลับไป A/B/C ได้เมื่อ slot เก่าว่างแล้ว

#### 3. Dashboard Styling — สว่างขึ้น + ใหญ่ขึ้น
- `colW`: 68 → 90 (กว้างขึ้น)
- `rowH`: 32 → 36 (สูงขึ้น)
- `fSize` min: 7 → 8 (ตัวอักษรใหญ่ขึ้น)
- สีพื้นหลัง row สว่างขึ้น: `C'55,60,72'` / `C'45,50,62'`
- Header สว่างขึ้น: `C'80,40,120'`
- Group accent colors สว่างขึ้นทั้งหมด

#### 4. Version bump: v5.12 → v5.13

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge Guards (cycle-aware, squeeze directional block)
- Normal Matching Close logic
- Dashboard หลัก (ข้อมูลอื่นๆ)
