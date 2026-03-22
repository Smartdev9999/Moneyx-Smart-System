## Fix: Hedge State Restore + Dashboard BD: + Width (v5.20 → v5.21)

### สิ่งที่แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. เพิ่ม `RestoreHedgeSets()` ใน OnInit
- สแกน positions ที่มี `GM_HEDGE_`, `GM_HG` เพื่อ rebuild g_hedgeSets[]
- กู้คืน hedgeTicket, hedgeSide, hedgeLots, gridMode, boundTickets
- กู้คืน cycleIndex จาก comment suffixes (_A, _B, ... _J)
- ใช้ FindLowestFreeCycle() เพื่อ set g_currentCycleIndex ถูกต้อง

#### 2. Dashboard — Side Symbol + BD: + ความกว้าง
- เปลี่ยน "B:" → "BD:" เพื่อไม่สับสนกับ Buy
- เพิ่ม side ทุก mode: `H1:REC(S) BD:5`, `H1:--(B) BD:2`
- เพิ่ม `input int HedgeDashWidth = 500;` ปรับความกว้างได้
- ใช้ HedgeDashWidth แทนค่าคงที่ colW=90

#### 3. อัปเดตกฎเหล็ก — เพิ่มกฎรวมแผน
- เพิ่มกฎข้อ 7: รวมแผนจากหลายข้อความเป็นแผนเดียว

#### 4. Version bump: v5.20 → v5.21

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge/Grid Recovery logic ทั้งหมด
- Normal Matching Close logic
- Dashboard layout/styling (เฉพาะ labels เปลี่ยน)
