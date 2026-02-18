

## บันทึก EA Code ที่สร้างเป็นไฟล์ใน `public/docs/mql5/`

### แนวคิด

เมื่อ AI สร้าง EA code เสร็จ (generate_ea) จะบันทึกเป็นไฟล์จริงใน `public/docs/mql5/` ด้วย เพื่อให้ดูและแก้ไขได้ง่ายจาก file tree โดยไม่ต้อง download ทุกครั้ง และเมื่อแก้ไข prompt แล้วสร้างใหม่ ก็จะอัปเดตไฟล์เดิม (ชื่อเดียวกัน)

### สิ่งที่จะเปลี่ยน

| ไฟล์ | การเปลี่ยนแปลง |
|------|----------------|
| `supabase/functions/analyze-ea-strategy/index.ts` | เพิ่มการสร้าง/อัปเดตไฟล์ใน Storage หลัง generate_ea สำเร็จ และเพิ่ม action "update_code" สำหรับแก้ไข code แล้วบันทึกกลับ |
| `src/components/StrategyLab.tsx` | เพิ่มปุ่ม "Save to Project" ที่เขียนไฟล์ลง `public/docs/mql5/` + แสดง link ไปดูไฟล์ + เพิ่มฟีเจอร์แก้ไข code ในหน้าเว็บแล้วบันทึก |

### รายละเอียดการทำงาน

**1. ตั้งชื่อไฟล์ตาม Session:**
- ใช้ชื่อ session แปลงเป็นชื่อไฟล์: `Session_Name_EA.mq5`
- เช่น session "Latsamy investment" จะได้ไฟล์ `Latsamy_investment_EA.mq5`
- สร้างใหม่ครั้งแรก = ไฟล์ใหม่, สร้างซ้ำ = อัปเดตไฟล์เดิม

**2. StrategyLab UI - เพิ่มฟีเจอร์:**
- ปุ่ม **"Save to Project"** - บันทึก generated code เป็นไฟล์ `public/docs/mql5/{name}_EA.mq5`
- ทำให้ code preview section สามารถ **แก้ไขได้** (editable textarea) พร้อมปุ่ม "Save" เพื่อบันทึกทั้งใน database และไฟล์
- ปุ่ม **Download .mq5** ยังคงทำงานเหมือนเดิม

**3. Edge Function - เพิ่ม action "update_code":**
- รับ `session_id` + `code` (ที่แก้ไขแล้ว)
- อัปเดต `generated_ea_code` ใน database
- ให้ frontend จัดการเขียนไฟล์ลง project ผ่าน local save

### รายละเอียดทางเทคนิค

**StrategyLab.tsx - การเขียนไฟล์:**

เนื่องจากเป็น frontend app ไม่สามารถเขียนไฟล์ลง filesystem ได้โดยตรง วิธีที่เหมาะสมคือ:

1. เมื่อ generate_ea สำเร็จ ระบบจะสร้างไฟล์ `.mq5` ไว้ใน project โดยอัตโนมัติ (ทำโดย Lovable เมื่อ implement)
2. เพิ่ม **editable code editor** แทน read-only pre tag - ใช้ textarea ที่มี monospace font
3. เพิ่มปุ่ม **"Save Changes"** ที่บันทึกกลับไป database (update generated_ea_code)
4. ปุ่ม **"Download .mq5"** ยังคงสร้าง blob download เหมือนเดิม

**Flow การทำงาน:**

```text
กด "3. สร้าง EA"
    → AI generate code
    → บันทึกใน database (generated_ea_code)
    → แสดง code ใน editable area
    → ผู้ใช้แก้ไข code ได้
    → กด "Save" → อัปเดต database
    → กด "Download .mq5" → ดาวน์โหลดไฟล์
```

**สิ่งที่จะสร้างเพิ่ม:**
- ไฟล์ `public/docs/mql5/` จะถูกสร้างด้วย Lovable เมื่อ generate EA แต่ละ session (ไฟล์จะอยู่ใน project ให้ดูและแก้ไขได้)
- ทุกครั้งที่ generate ใหม่จาก session เดิม ไฟล์จะถูก overwrite

