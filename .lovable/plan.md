

## แผนปรับปรุง: ลบ API Key ออก - ใช้แค่ URL + ชื่อ Session

### สิ่งที่จะเปลี่ยน

ปรับให้ EA Tracker เชื่อมต่อได้ง่ายขึ้นโดยไม่ต้องใช้ API Key เพียงใส่ **URL** กับ **ชื่อ Session** เท่านั้น

### ข้อดี
- ตั้งค่าง่ายมาก แค่ใส่ URL + ชื่อ
- ไม่ต้องจำหรือหา API Key

### ข้อเสีย (ความปลอดภัย)
- ใครก็ตามที่รู้ URL สามารถส่งข้อมูลปลอมเข้ามาได้
- เนื่องจากระบบ Strategy Lab ใช้ภายในทีม Developer เท่านั้น ความเสี่ยงนี้ยอมรับได้

---

### ไฟล์ที่แก้ไข

| ไฟล์ | การเปลี่ยนแปลง |
|------|----------------|
| `supabase/functions/sync-tracked-orders/index.ts` | ลบ API Key validation ออก ให้รับข้อมูลได้เลย |
| `public/docs/mql5/EA_Strategy_Tracker.mq5` | ลบ InpAPIKey parameter, ลบ header x-api-key ออก |
| `src/components/StrategyLab.tsx` | อัปเดตคำแนะนำการตั้งค่าให้บอกแค่ URL + ชื่อ Session |

---

### รายละเอียดทางเทคนิค

**Edge Function (`sync-tracked-orders`):**
- ลบบล็อก API key validation (บรรทัด 16-30) ออกทั้งหมด
- คงเหลือแค่ validation ว่า `session_name` ต้องมี

**EA Tracker (MQL5):**
- ลบ `input string InpAPIKey`
- ลบ `"x-api-key: "` ออกจาก HTTP headers
- ผู้ใช้ตั้งค่าแค่:
  - `InpServerURL` = URL ของ backend function
  - `InpSessionName` = ชื่อ session

**Dashboard:**
- อัปเดตคำแนะนำการตั้งค่าให้แสดงแค่ 2 ขั้นตอน:
  1. เพิ่ม URL ใน MT5 WebRequest
  2. ใส่ชื่อ Session ให้ตรงกัน

