

## Fix: Order ค้างหลัง Hedge Matching Close + Dashboard PnL (v5.11 → v5.12)

### สิ่งที่แก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. ManageHedgeMatchingClose() — เช็ค bound orders หลัง matching สำเร็จ
- หลัง matching close สำเร็จ เพิ่ม `RefreshBoundTickets()` แล้วเช็คว่ายังมี bound orders เหลือ
- ถ้ายังเหลือ → เข้า Grid Recovery Mode (`gridMode=true`, `hedgeTicket=0`)
- ถ้าหมด → deactivate set ตามปกติ

#### 2. เพิ่มฟังก์ชัน `CalculateRemainingBoundLots()` + `ManageGridRecoveryMode()`
- Recovery mode: ใช้ grid orders สร้างกำไรเพื่อ matching close กับ bound orders ที่เหลือ
- เปิด grid orders ฝั่ง hedge เดิม, ใช้ budget matching กับ bound losses
- ปิด set เมื่อ bound orders หมด

#### 3. ManageHedgeGridMode() — รองรับ hedgeTicket = 0
- เมื่อ main hedge ถูกปิดแล้ว → ส่งต่อให้ ManageGridRecoveryMode()

#### 4. ซ่อน Cycle Details จาก Dashboard หลัก
- ลบ Hedge #1-#16 details, คงแสดงเฉพาะ Cycle label + Set count

#### 5. เพิ่ม PnL ใน Hedge Cycle Monitor
- แต่ละ cell แสดง 2 บรรทัด: info + PnL (สีเขียว/แดง)
- เพิ่ม bound order count (B:x) และ grid mode indicator (*)
- ปรับ rowH จาก 18 → 32 เพื่อรองรับ 2 บรรทัด

#### 6. Version bump: v5.11 → v5.12

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL/Trailing)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Hedge Guards (cycle-aware, squeeze directional block)
- Normal Matching Close logic
