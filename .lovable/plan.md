

## แผนสร้างระบบ EA Strategy Reverse-Engineering (EA Tracker)

---

### ภาพรวมระบบ

ระบบนี้ประกอบด้วย 3 ส่วนหลัก:

1. **EA Tracker (MQL5)** - ติดตั้งบน MT5 เดียวกับ EA ที่ต้องการวิเคราะห์ เก็บข้อมูลทุก Order
2. **Backend (Database + Edge Functions)** - เก็บข้อมูลและวิเคราะห์กลยุทธ์ด้วย AI
3. **Dashboard (Developer Page)** - Tab ใหม่ "Strategy Lab" สำหรับดูข้อมูลและสั่งวิเคราะห์

---

### ส่วนที่ 1: Database Tables

สร้าง 2 ตารางใหม่:

**`tracked_ea_sessions`** - เก็บข้อมูล EA ที่กำลัง track

| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Primary key |
| session_name | text | ชื่อ session (เช่น "Gold EA Test #1") |
| ea_magic_number | integer | Magic Number ของ EA ที่ track |
| broker | text | ชื่อ Broker |
| account_number | text | หมายเลขบัญชี |
| symbols | text[] | Symbols ที่ EA เทรด |
| timeframe | text | Timeframe หลัก |
| start_time | timestamptz | เวลาเริ่ม track |
| end_time | timestamptz | เวลาสิ้นสุด (null = ยังทำงาน) |
| total_orders | integer | จำนวน orders ทั้งหมด |
| strategy_summary | text | สรุปกลยุทธ์ (AI generated) |
| strategy_prompt | text | Prompt สำหรับสร้าง EA (AI generated) |
| generated_ea_code | text | โค้ด EA ที่สร้างแล้ว |
| status | text | 'tracking', 'analyzing', 'summarized', 'prompted', 'generated' |
| notes | text | บันทึกเพิ่มเติม |
| created_at | timestamptz | |

**`tracked_orders`** - เก็บรายละเอียดทุก Order

| Column | Type | Description |
|--------|------|-------------|
| id | uuid | Primary key |
| session_id | uuid | FK -> tracked_ea_sessions |
| ticket | bigint | Order ticket |
| magic_number | integer | Magic Number |
| symbol | text | Symbol |
| order_type | text | 'buy', 'sell', 'buy_limit', etc. |
| volume | numeric | Lot size |
| open_price | numeric | ราคาเปิด |
| close_price | numeric | ราคาปิด |
| sl | numeric | Stop Loss |
| tp | numeric | Take Profit |
| profit | numeric | Profit/Loss |
| swap | numeric | Swap |
| commission | numeric | Commission |
| open_time | timestamptz | เวลาเปิด |
| close_time | timestamptz | เวลาปิด |
| comment | text | Order comment |
| holding_time_seconds | integer | ระยะเวลาถือ |
| market_data | jsonb | ข้อมูลตลาดตอนเปิด/ปิด (spread, ATR, RSI, EMA etc.) |
| event_type | text | 'open', 'close', 'modify' |
| created_at | timestamptz | |

**RLS Policies:**
- Developer/Admin สามารถ CRUD ได้ทั้งหมด

---

### ส่วนที่ 2: EA Tracker (MQL5)

ไฟล์: `public/docs/mql5/EA_Strategy_Tracker.mq5`

EA นี้ทำหน้าที่:
- **ตรวจจับทุก Position** ที่เปิด/ปิดโดย EA เป้าหมาย (filter by Magic Number หรือ All)
- **เก็บข้อมูลตลาด** ณ เวลาที่เปิด/ปิด (Spread, ATR, RSI, EMA, Bollinger, MACD)
- **ส่งข้อมูล** ไปยัง Backend ผ่าน Edge Function ทุกครั้งที่มี Event
- **Track Order Modifications** (SL/TP changes)
- **รองรับ Multiple Magic Numbers** หรือ track ทุก order ที่ไม่ใช่ของตัวเอง

Input Parameters:
```text
=== Tracker Settings ===
- InpTrackMagicNumber: Magic Number ที่จะ track (0 = track ทั้งหมด)
- InpSessionName: ชื่อ Session
- InpSendInterval: ความถี่ในการส่งข้อมูล (วินาที)

=== Market Data Collection ===
- InpCollectRSI: เก็บ RSI (true/false)
- InpCollectEMA: เก็บ EMA (true/false)
- InpCollectATR: เก็บ ATR (true/false)
- InpCollectMACD: เก็บ MACD (true/false)
- InpCollectBollinger: เก็บ Bollinger Bands (true/false)
```

ข้อมูลที่ส่ง per order:
- Ticket, Symbol, Type, Volume, Prices, SL/TP
- Open/Close Time, Holding Duration
- Market snapshot: Spread, ATR(14), RSI(14), EMA(20), EMA(50), MACD, Bollinger

---

### ส่วนที่ 3: Edge Function - `sync-tracked-orders`

ไฟล์: `supabase/functions/sync-tracked-orders/index.ts`

- รับข้อมูลจาก EA Tracker
- Validate API Key (EA_API_SECRET)
- Auto-create session ถ้ายังไม่มี
- Upsert orders (based on session_id + ticket)
- อัปเดต session stats (total_orders, symbols)

---

### ส่วนที่ 4: Edge Function - `analyze-ea-strategy`

ไฟล์: `supabase/functions/analyze-ea-strategy/index.ts`

ใช้ Lovable AI (Gemini) วิเคราะห์กลยุทธ์จากข้อมูลที่เก็บ

**Step 1: สรุปกลยุทธ์** (`action: "summarize"`)
- ดึงข้อมูล orders ทั้งหมดของ session
- วิเคราะห์: Entry patterns, Exit patterns, Position sizing, Time patterns, Market conditions
- สร้างสรุปกลยุทธ์ภาษาไทย + อังกฤษ
- บันทึกลง `strategy_summary`

**Step 2: สร้าง Prompt** (`action: "generate_prompt"`)
- ใช้ strategy_summary เป็นฐาน
- สร้าง detailed prompt สำหรับเขียน EA
- บันทึกลง `strategy_prompt`

**Step 3: สร้าง EA Code** (`action: "generate_ea"`)
- ใช้ strategy_prompt + MQL5 template
- สร้าง compile-ready EA code
- บันทึกลง `generated_ea_code`

---

### ส่วนที่ 5: Dashboard - Tab "Strategy Lab"

เพิ่ม Tab ใหม่ใน Developer page:

**Layout:**

```text
[TabsList]
EA | Indicators | AI Analysis | News | Strategy Lab (ใหม่)

[Strategy Lab Tab Content]

+-- Session List (Left Panel) --+-- Session Detail (Right Panel) --+
|                                |                                   |
| [+ New Session]                | Session: "Gold EA Test #1"        |
|                                | Status: tracking | Magic: 12345   |
| > Gold EA Test #1  (tracking)  | Orders: 156 | Duration: 5 days    |
| > Scalper EA #2    (summarized)|                                   |
| > Grid EA Test     (generated) | [Orders Table]                    |
|                                | Ticket | Symbol | Type | Lot | ...|
|                                | 12345  | XAUUSD | BUY  | 0.1 | ...|
|                                |                                   |
|                                | [Statistics Cards]                |
|                                | Win Rate: 65% | Avg Hold: 2h     |
|                                | Avg TP: 50pts | Avg SL: 30pts    |
|                                |                                   |
|                                | [Action Buttons]                  |
|                                | [1. Summarize] [2. Gen Prompt]    |
|                                | [3. Generate EA] [Download .mq5]  |
|                                |                                   |
|                                | [Strategy Summary] (expandable)   |
|                                | [Generated Prompt] (expandable)   |
|                                | [EA Code Preview] (expandable)    |
+--------------------------------+-----------------------------------+
```

**ปุ่มทำงาน 3 ขั้นตอน:**
1. **"สรุปกลยุทธ์"** - เรียก AI วิเคราะห์ orders -> แสดงสรุป
2. **"สร้าง Prompt"** - สร้าง prompt จากสรุป -> แสดง prompt ที่แก้ไขได้
3. **"สร้าง EA"** - สร้างโค้ด EA เต็มรูปแบบ -> Preview + Download

---

### สรุปไฟล์ที่สร้าง/แก้ไข

| ไฟล์ | การเปลี่ยนแปลง |
|------|----------------|
| SQL Migration | สร้าง `tracked_ea_sessions` + `tracked_orders` + RLS |
| `public/docs/mql5/EA_Strategy_Tracker.mq5` | สร้างใหม่ - EA สำหรับ track orders |
| `supabase/functions/sync-tracked-orders/index.ts` | สร้างใหม่ - รับข้อมูลจาก EA |
| `supabase/functions/analyze-ea-strategy/index.ts` | สร้างใหม่ - AI วิเคราะห์กลยุทธ์ |
| `supabase/config.toml` | เพิ่ม function configs |
| `src/pages/Developer.tsx` | เพิ่ม Tab "Strategy Lab" + UI ทั้งหมด |

---

### ลำดับการพัฒนา

1. สร้าง Database tables + RLS policies
2. สร้าง Edge Functions (sync + analyze)
3. สร้าง EA Tracker (MQL5)
4. สร้าง UI Dashboard (Strategy Lab tab)
5. เชื่อมต่อทุกส่วนเข้าด้วยกัน

