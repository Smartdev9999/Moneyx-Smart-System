

## เพิ่มฟีเจอร์: ดึงประวัติการเทรดจาก MT5 ตอนเริ่มต้น

### แนวคิด

เมื่อ EA Tracker เริ่มทำงาน (OnInit) นอกจากสแกนออเดอร์ที่เปิดอยู่แล้ว จะดึงประวัติการเทรดที่ปิดแล้วจาก MT5 ส่งไปเก็บใน database ด้วย เพื่อให้ AI มีข้อมูลย้อนหลังสำหรับวิเคราะห์ strategy ได้แม่นยำขึ้น

### สิ่งที่จะเปลี่ยน

| ไฟล์ | การเปลี่ยนแปลง |
|------|----------------|
| `public/docs/mql5/EA_Strategy_Tracker.mq5` | เพิ่มฟังก์ชัน `SendTradeHistory()` ที่ดึง deal history จาก MT5 แล้วส่งไป backend ตอน OnInit |
| `supabase/functions/sync-tracked-orders/index.ts` | รองรับ event_type "history" สำหรับข้อมูลย้อนหลัง + ป้องกันการส่งซ้ำ |

### รายละเอียดการทำงาน

**EA Tracker (MQL5):**

1. เพิ่ม input parameter:
   - `InpHistoryDays = 30` - จำนวนวันย้อนหลังที่ต้องการดึง (default 30 วัน)
   - `InpSendHistory = true` - เปิด/ปิดการส่งประวัติ

2. เพิ่มฟังก์ชัน `SendTradeHistory()`:
   - ใช้ `HistorySelect(startDate, endDate)` เพื่อดึง deal history
   - กรอง magic number ตามที่ตั้งค่า (เหมือน tracking ปกติ)
   - กรองเฉพาะ `DEAL_ENTRY_OUT` / `DEAL_ENTRY_INOUT` (เฉพาะออเดอร์ที่ปิดแล้ว)
   - แบ่งส่งทีละ batch (50 รายการ) เพื่อไม่ให้ payload ใหญ่เกินไป
   - ส่งเป็น event_type = "history"

3. เรียก `SendTradeHistory()` ใน `OnInit()` หลัง `ScanPositions()`

**Backend (Edge Function):**

1. รองรับ event_type "history" - upsert ด้วย `session_id + ticket + event_type` (unique constraint ที่มีอยู่แล้ว) ป้องกันข้อมูลซ้ำ
2. อัปเดต session stats หลังรับ history

### ตัวอย่างข้อมูลที่ส่ง

```text
{
  "session_name": "Latsamy investment",
  "account_number": "2080636",
  "event": "history",
  "orders": [
    {
      "ticket": 12345,
      "symbol": "XAUUSD",
      "order_type": "buy",
      "volume": 0.01,
      "open_price": 2350.50,
      "close_price": 2355.00,
      "profit": 4.50,
      "swap": -0.12,
      "commission": -0.70,
      "open_time": "2025-01-15T10:30:00Z",
      "close_time": "2025-01-15T14:20:00Z",
      "holding_time_seconds": 13800,
      "event_type": "history",
      "market_data": {}
    }
  ]
}
```

### ข้อดี
- AI จะมีข้อมูลย้อนหลัง 30 วัน (หรือมากกว่า) เพื่อวิเคราะห์ pattern ของ EA
- เปิด EA ครั้งเดียวก็ได้ข้อมูลทั้งหมด ไม่ต้องรอเทรดใหม่
- ป้องกันข้อมูลซ้ำ - ส่งกี่ครั้งก็ไม่มีปัญหา (upsert)

### รายละเอียดทางเทคนิค

**MQL5 - ฟังก์ชัน SendTradeHistory():**
- ใช้ `HistorySelect()` เพื่อโหลด deal history ตามช่วงเวลา
- วนลูป `HistoryDealsTotal()` เพื่ออ่านแต่ละ deal
- จับคู่ deal_in กับ deal_out ผ่าน `DEAL_POSITION_ID` เพื่อหา open_price ของแต่ละเทรด
- แบ่งส่งทีละ 50 deals ต่อ request เพื่อหลีกเลี่ยง timeout ของ WebRequest

**Edge Function:**
- ตรวจสอบ `event_type === "history"` แล้ว upsert เหมือนปกติ
- unique constraint `session_id + ticket + event_type` ทำหน้าที่ป้องกันซ้ำอยู่แล้ว

