

## แผนพัฒนา: แก้ไข Customer Account Display และเพิ่ม Password Change

### ปัญหาที่พบ

| ปัญหา | หน้าที่เกี่ยวข้อง | สาเหตุ |
|-------|------------------|--------|
| Admin Dashboard แสดง "ยังไม่มีบัญชี" | `/admin/customers/:id` | Query nested select ไม่ทำงานเพราะไม่มี FK |
| ลูกค้าไม่สามารถเปลี่ยนรหัสผ่านได้ | `/customer/settings` | ไม่มี UI สำหรับเปลี่ยนรหัสผ่าน |

---

### การแก้ไขที่ 1: Admin Dashboard (CustomerDetail.tsx)

**ไฟล์:** `src/pages/admin/CustomerDetail.tsx`

**วิธีแก้ไข:** เปลี่ยน `fetchLinkedUser()` จาก nested select เป็น query แยก 2 ขั้นตอน

**เดิม:**
```typescript
const { data } = await supabase
  .from('customer_users')
  .select(`id, user_id, status, approved_at, profiles:user_id (email, full_name)`)
  .eq('customer_id', id)
```

**แก้ไขเป็น:**
```typescript
// Step 1: Get customer_users record
const { data: cuData } = await supabase
  .from('customer_users')
  .select('id, user_id, status, approved_at')
  .eq('customer_id', id)
  .maybeSingle();

if (cuData) {
  // Step 2: Get profile data separately
  const { data: profileData } = await supabase
    .from('profiles')
    .select('email, full_name')
    .eq('id', cuData.user_id)
    .maybeSingle();
  
  setLinkedUser({
    ...cuData,
    profiles: profileData || null,
  });
}
```

---

### การแก้ไขที่ 2: Customer Settings (Settings.tsx)

**ไฟล์:** `src/pages/customer/Settings.tsx`

**เพิ่ม Card ใหม่:** "บัญชี Login" สำหรับเปลี่ยนรหัสผ่าน

**UI ที่จะเพิ่ม:**

```text
┌──────────────────────────────────────────────────────────────┐
│ 🔐 บัญชี Login                                               │
├──────────────────────────────────────────────────────────────┤
│ เปลี่ยนรหัสผ่านของบัญชี Login ของคุณ                         │
│                                                              │
│ ┌───────────────────────────────────────────┐                │
│ │ รหัสผ่านปัจจุบัน: ••••••••                │                │
│ └───────────────────────────────────────────┘                │
│ ┌───────────────────────────────────────────┐                │
│ │ รหัสผ่านใหม่: ______________________       │                │
│ └───────────────────────────────────────────┘                │
│ ┌───────────────────────────────────────────┐                │
│ │ ยืนยันรหัสผ่านใหม่: ______________________ │                │
│ └───────────────────────────────────────────┘                │
│                                                              │
│                                     [ เปลี่ยนรหัสผ่าน ]      │
└──────────────────────────────────────────────────────────────┘
```

**Logic การเปลี่ยนรหัสผ่าน:**
- ใช้ `supabase.auth.updateUser({ password: newPassword })` (ไม่ต้องสร้าง Edge Function ใหม่)
- Supabase Auth API อนุญาตให้ user ที่ login อยู่เปลี่ยนรหัสผ่านของตัวเองได้
- ต้องใส่รหัสผ่านปัจจุบันเพื่อความปลอดภัย (ใช้ `supabase.auth.signInWithPassword` ตรวจสอบก่อน)

---

### สรุปไฟล์ที่ต้องแก้ไข

| ไฟล์ | การเปลี่ยนแปลง |
|------|----------------|
| `src/pages/admin/CustomerDetail.tsx` | แก้ไข `fetchLinkedUser()` เป็น query แยก 2 ขั้นตอน |
| `src/pages/customer/Settings.tsx` | เพิ่ม Card "บัญชี Login" พร้อมฟอร์มเปลี่ยนรหัสผ่าน |

---

### ผลลัพธ์ที่คาดหวัง

**Admin Dashboard:**
- แสดง email และสถานะ "เชื่อมแล้ว" ของลูกค้าที่มี login account
- ปุ่ม "Reset Password" ทำงานได้

**Customer Settings:**
- ลูกค้าสามารถเปลี่ยนรหัสผ่านได้ด้วยตัวเอง
- ต้องใส่รหัสผ่านปัจจุบันเพื่อยืนยันตัวตน
- แสดงข้อความสำเร็จหรือ error ชัดเจน

---

### ความปลอดภัย

- การเปลี่ยนรหัสผ่านใช้ Supabase Auth API โดยตรง (ไม่ต้องสร้าง Edge Function)
- ต้องยืนยันรหัสผ่านปัจจุบันก่อนเปลี่ยน
- รหัสผ่านใหม่ต้องมีอย่างน้อย 6 ตัวอักษร
- ไม่ต้องเพิ่ม RLS policy ใหม่ (ใช้ auth ของ Supabase ที่มีอยู่)

