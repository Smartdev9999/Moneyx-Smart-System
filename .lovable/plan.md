

## v6.44 — Fix TP ไม่ทำงานใน Live Trading

### หลักการ

1. **Fix Dollar/Percent TP**: ลบ `!EnablePerOrderTrailing` guard ที่ block basket TP → Dollar/Percent TP ทำงานทันที
2. **Extend SyncBrokerTPSL**: แปลง Dollar/Percent TP เป็นราคา broker-level ผ่าน tickValue conversion
3. **Expand Sync Condition**: เรียก SyncBrokerTPSL เมื่อใช้ UseTP_Dollar หรือ UseTP_PercentBalance ด้วย
4. **Debug Print**: เพิ่ม Print log เมื่อ PositionModify สำเร็จ เพื่อยืนยัน broker TP

### ไฟล์: `public/docs/mql5/Gold_Miner_EA.mq5`

#### Changes
- Version bump → v6.44
- ลบ `!EnablePerOrderTrailing` จาก ManageTPSL (BUY/SELL) และ ManageTPSL_TF (BUY/SELL)
- ขยาย SyncBrokerTPSL() → รองรับ Dollar TP และ Percent TP ผ่าน price distance conversion
- ขยาย OnTick condition → ครอบคลุม UseTP_Dollar, UseTP_PercentBalance
- เพิ่ม Print log เมื่อ PositionModify สำเร็จ

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic — ไม่แก้
- Trading Strategy Logic — ไม่แก้
- Core Module Logic — ไม่แก้
- Dollar/Percent/DD% TP — ยังจัดการผ่าน EA เป็น backup
- Per-Order Trailing Stop logic — ไม่แก้ (ยังจัดการ SL per order)
- Accumulate Close / Drawdown Exit — ไม่แก้
- Grid / Hedge / Balance Guard — ไม่แก้
- v6.37-v6.43 features — ไม่แก้
