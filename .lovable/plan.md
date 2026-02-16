

## แผนปรับปรุง Strategy Lab: Connection Status + Real-time Tracking Dashboard

---

### ปัญหาปัจจุบัน

1. EA Tracker ยังไม่ส่งข้อมูลเข้ามา (ไม่มี logs ใน edge function)
2. Dashboard ไม่แสดงสถานะการเชื่อมต่อ - ผู้ใช้ไม่รู้ว่า EA เชื่อมต่อสำเร็จหรือไม่
3. ไม่มีข้อมูลแสดงว่า Tracker กำลังเก็บข้อมูลอะไรบ้าง

---

### สิ่งที่จะเพิ่ม

#### 1. Connection Status Card (ด้านบนของ Session Detail)

แสดงสถานะการเชื่อมต่อระหว่าง EA Tracker กับ Backend:

```text
+-------------------------------------------------------+
| Connection Status                                      |
|                                                        |
| [สถานะ: ยังไม่เชื่อมต่อ / เชื่อมต่อแล้ว / ออฟไลน์]     |
| Last Heartbeat: 2 นาทีที่แล้ว                          |
| Broker: XM  |  Account: #12345  |  Magic: All          |
| EA Tracker Version: 1.0                                |
+-------------------------------------------------------+
```

- **ยังไม่เชื่อมต่อ** (สีเทา): ไม่เคยมีข้อมูลส่งเข้ามา (account_number = null)
- **เชื่อมต่อแล้ว** (สีเขียว): มี account_number + มี orders หรือ last heartbeat ล่าสุด
- **ออฟไลน์** (สีแดง): เคยเชื่อมต่อแต่ไม่มีข้อมูลใหม่เกิน 5 นาที

#### 2. Tracking Info Card

แสดงว่า Tracker กำลังเก็บข้อมูลอะไรบ้าง:

```text
+-------------------------------------------------------+
| Data Collection                                        |
|                                                        |
| [v] Order Events (Open / Close / Modify)               |
| [v] Market Data: RSI, ATR, EMA(20,50), MACD, Bollinger |
| [v] Position Details: SL, TP, Volume, Holding Time     |
| [v] Broker Info: Spread, Commission, Swap              |
|                                                        |
| Tips: ยิ่งมีข้อมูลมากยิ่งวิเคราะห์ได้แม่นยำ            |
| แนะนำเก็บอย่างน้อย 50 orders ก่อนสรุปกลยุทธ์          |
+-------------------------------------------------------+
```

#### 3. Real-time Order Feed

เมื่อมี order ใหม่เข้ามา แสดง live feed:

```text
+-------------------------------------------------------+
| Live Activity Feed                     [Auto-refresh]  |
|                                                        |
| 14:32:05  OPEN  XAUUSD BUY 0.10 @ 2645.50            |
|           RSI: 35.2 | ATR: 12.5 | EMA20 > EMA50      |
|                                                        |
| 14:28:12  CLOSE XAUUSD SELL 0.10 @ 2643.20  +$15.30  |
|           Hold: 45m | SL hit                           |
|                                                        |
| 14:15:00  MODIFY XAUUSD BUY #12345 SL: 2640 -> 2642  |
+-------------------------------------------------------+
```

#### 4. Database: เพิ่ม last_heartbeat column

เพิ่มคอลัมน์ `last_heartbeat` ใน `tracked_ea_sessions` เพื่อบันทึกเวลาล่าสุดที่ EA ส่งข้อมูลมา

#### 5. Edge Function Update: บันทึก heartbeat

อัปเดต `sync-tracked-orders` ให้บันทึก `last_heartbeat` ทุกครั้งที่รับข้อมูล + บันทึก broker/account_number ถ้ายังไม่มี

#### 6. Auto-refresh + Realtime

- ใช้ Supabase Realtime subscription บน `tracked_orders` table
- เมื่อมี order ใหม่ dashboard อัปเดตทันทีโดยไม่ต้อง refresh
- อัปเดต session info ทุก 30 วินาที

---

### ไฟล์ที่แก้ไข

| ไฟล์ | การเปลี่ยนแปลง |
|------|----------------|
| SQL Migration | เพิ่ม `last_heartbeat` column + enable realtime |
| `supabase/functions/sync-tracked-orders/index.ts` | บันทึก heartbeat + broker/account info |
| `src/components/StrategyLab.tsx` | เพิ่ม Connection Status, Tracking Info, Live Feed, Realtime subscription |

---

### ลำดับการพัฒนา

1. เพิ่ม `last_heartbeat` column ใน database
2. อัปเดต edge function ให้บันทึก heartbeat
3. เพิ่ม Connection Status Card + Tracking Info
4. เพิ่ม Live Activity Feed พร้อม market data snapshot
5. เพิ่ม Realtime subscription สำหรับ auto-update

---

### หมายเหตุสำคัญ

จากการตรวจสอบ edge function logs พบว่า **EA Tracker ยังไม่เคยส่งข้อมูลมาถึง backend** กรุณาตรวจสอบ:
1. ตั้งค่า `InpAPIKey` ใน EA Tracker ให้ตรงกับ EA_API_SECRET
2. เพิ่ม URL `https://lkbhomsulgycxawwlnfh.supabase.co/functions/v1/sync-tracked-orders` ใน MT5 > Tools > Options > Expert Advisors > Allow WebRequest
3. ตั้งค่า `InpSessionName` = "Latsamy investment" (ต้องตรงกับชื่อ session ที่สร้างไว้)

