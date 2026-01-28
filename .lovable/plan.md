

## แผนพัฒนา: Light Theme และระบบหลายภาษา (English, ລາວ, ไทย) พร้อม Phetsarath Font

### ภาพรวม

เพิ่ม Light Theme และระบบสลับภาษา 3 ภาษา โดยภาษาลาวจะใช้ฟอนต์ **Phetsarath** แยกต่างหาก

---

### ส่วนที่ 1: Font Configuration

#### 1.1 เพิ่ม Phetsarath Font ใน index.html

| ไฟล์ | การเปลี่ยนแปลง |
|------|----------------|
| `index.html` | เพิ่ม Google Fonts preconnect และ Phetsarath font link |

```html
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Phetsarath:wght@400;700&display=swap" rel="stylesheet">
```

#### 1.2 เพิ่ม Phetsarath CSS Classes ใน index.css

| ไฟล์ | การเปลี่ยนแปลง |
|------|----------------|
| `src/index.css` | เพิ่ม font classes และ lang attribute selector |

```css
/* Phetsarath font for Lao language */
.phetsarath-regular {
  font-family: "Phetsarath", sans-serif;
  font-weight: 400;
  font-style: normal;
}

.phetsarath-bold {
  font-family: "Phetsarath", sans-serif;
  font-weight: 700;
  font-style: normal;
}

/* Auto-apply Phetsarath when language is Lao */
html[lang="lo"] body {
  font-family: "Phetsarath", sans-serif;
}
```

---

### ส่วนที่ 2: Light Theme

#### 2.1 สร้าง ThemeProvider Component

| ไฟล์ | รายละเอียด |
|------|------------|
| `src/components/ThemeProvider.tsx` | Wrapper สำหรับ next-themes |

- ใช้ `next-themes` (ติดตั้งแล้ว)
- defaultTheme: `"dark"`
- attribute: `"class"`
- enableSystem: `true`

#### 2.2 เพิ่ม Light Mode CSS Variables

| ไฟล์ | การเปลี่ยนแปลง |
|------|----------------|
| `src/index.css` | แยก `:root` เป็น Light mode, `.dark` เป็น Dark mode |

**Light Mode Colors:**

| Variable | Dark Mode | Light Mode |
|----------|-----------|------------|
| `--background` | Navy dark (222 47% 8%) | White (0 0% 100%) |
| `--foreground` | Light gray (210 40% 96%) | Dark gray (222 47% 11%) |
| `--card` | Dark navy (222 47% 11%) | White (0 0% 100%) |
| `--muted` | Dark (222 30% 15%) | Light gray (210 40% 96%) |
| `--border` | Dark border (222 30% 20%) | Light border (214 32% 91%) |

#### 2.3 สร้าง Theme Toggle Component

| ไฟล์ | รายละเอียด |
|------|------------|
| `src/components/ThemeToggle.tsx` | Dropdown เลือก Light/Dark/System |

```text
┌─────────────────────────┐
│  ☀️ Light   (checked)   │
│  🌙 Dark                │
│  💻 System              │
└─────────────────────────┘
```

---

### ส่วนที่ 3: ระบบหลายภาษา (i18n)

#### 3.1 ติดตั้ง Dependencies

```text
i18next                         - Core i18n library
react-i18next                   - React bindings
i18next-browser-languagedetector - ตรวจจับภาษาจาก browser
```

#### 3.2 โครงสร้างไฟล์

```text
src/
└── i18n/
    ├── index.ts          # i18n configuration
    └── locales/
        ├── en.json       # English (default font: Inter)
        ├── lo.json       # ພາສາລາວ (font: Phetsarath)
        └── th.json       # ภาษาไทย (font: Inter)
```

#### 3.3 i18n Configuration

| ไฟล์ | รายละเอียด |
|------|------------|
| `src/i18n/index.ts` | Setup i18next พร้อมเปลี่ยน `html[lang]` attribute |

**Key Features:**
- เปลี่ยน `document.documentElement.lang` เมื่อเปลี่ยนภาษา
- เมื่อเลือกภาษาลาว (`lo`) จะ trigger CSS rule `html[lang="lo"] body` ให้ใช้ Phetsarath

#### 3.4 Translation Keys

**หมวดหมู่หลัก:**

| Category | ตัวอย่าง Keys |
|----------|---------------|
| `common` | save, cancel, confirm, delete, loading, success |
| `auth` | login, signup, email, password, logout |
| `admin` | dashboard, customers, accounts, systems, reports |
| `customer` | myAccounts, settings, wallet, portfolio |

**ตัวอย่าง Translations:**

| Key | English | ລາວ | ไทย |
|-----|---------|-----|-----|
| `common.save` | Save | ບັນທຶກ | บันทึก |
| `common.cancel` | Cancel | ຍົກເລີກ | ยกเลิก |
| `admin.dashboard` | Admin Dashboard | ແຜງຄວບຄຸມ | แผงควบคุม |
| `admin.customers` | Customers | ລູກຄ້າ | ลูกค้า |

#### 3.5 Language Switcher Component

| ไฟล์ | รายละเอียด |
|------|------------|
| `src/components/LanguageSwitcher.tsx` | Dropdown เลือกภาษา |

```text
┌────────────────────────────┐
│  🌐 TH ▼                   │
│  ┌────────────────────────┐│
│  │  🇺🇸 English           ││
│  │  🇱🇦 ພາສາລາວ           ││
│  │  🇹🇭 ภาษาไทย  ✓        ││
│  └────────────────────────┘│
└────────────────────────────┘
```

**เมื่อเลือกภาษาลาว:**
1. i18next เปลี่ยน `lng` เป็น `"lo"`
2. `document.documentElement.lang = "lo"`
3. CSS rule `html[lang="lo"] body` ใช้งาน
4. ทั้งหน้าเปลี่ยนไปใช้ Phetsarath font

---

### ส่วนที่ 4: Integration

#### 4.1 Wrap App ด้วย Providers

| ไฟล์ | การเปลี่ยนแปลง |
|------|----------------|
| `src/App.tsx` | เพิ่ม `ThemeProvider` ครอบ app |
| `src/main.tsx` | import i18n configuration |

#### 4.2 เพิ่ม Controls ใน Headers

**Admin Header:**
```text
┌──────────────────────────────────────────────────────────────────────┐
│ [Logo] Moneyx Admin        [🌐 TH ▼] [☀️/🌙] [Super Admin] [Logout] │
└──────────────────────────────────────────────────────────────────────┘
```

**Customer Header:**
```text
┌──────────────────────────────────────────────────────────────────────┐
│ [Logo] Customer Dashboard    [🌐 TH ▼] [☀️/🌙] [Settings] [Logout]  │
└──────────────────────────────────────────────────────────────────────┘
```

#### 4.3 หน้าที่จะแปล (Initial Scope)

| หน้า | Priority |
|------|----------|
| `src/pages/Index.tsx` | High |
| `src/pages/Auth.tsx` | High |
| `src/pages/Admin.tsx` | High |
| `src/pages/Customer.tsx` | High |
| `src/pages/customer/Settings.tsx` | Medium |
| `src/pages/admin/Customers.tsx` | Medium |

---

### สรุปไฟล์ที่ต้องสร้าง/แก้ไข

| ประเภท | ไฟล์ | รายละเอียด |
|--------|------|------------|
| **แก้ไข** | `index.html` | เพิ่ม Phetsarath font link |
| **แก้ไข** | `src/index.css` | เพิ่ม light mode vars + Phetsarath classes |
| **สร้างใหม่** | `src/components/ThemeProvider.tsx` | Theme wrapper |
| **สร้างใหม่** | `src/components/ThemeToggle.tsx` | Theme dropdown |
| **สร้างใหม่** | `src/components/LanguageSwitcher.tsx` | Language dropdown |
| **สร้างใหม่** | `src/i18n/index.ts` | i18n configuration |
| **สร้างใหม่** | `src/i18n/locales/en.json` | English translations |
| **สร้างใหม่** | `src/i18n/locales/lo.json` | Lao translations |
| **สร้างใหม่** | `src/i18n/locales/th.json` | Thai translations |
| **แก้ไข** | `src/main.tsx` | import i18n |
| **แก้ไข** | `src/App.tsx` | เพิ่ม ThemeProvider |
| **แก้ไข** | `src/pages/Admin.tsx` | เพิ่ม controls + translations |
| **แก้ไข** | `src/pages/Customer.tsx` | เพิ่ม controls + translations |
| **แก้ไข** | `src/pages/Auth.tsx` | translations |
| **แก้ไข** | `src/pages/Index.tsx` | translations + controls |

---

### Dependencies ที่ต้องติดตั้ง

```text
i18next
react-i18next
i18next-browser-languagedetector
```

---

### Font Strategy Summary

| ภาษา | Font | ที่มา |
|------|------|-------|
| English | Inter | Google Fonts (มีอยู่แล้ว) |
| ພາສາລາວ | **Phetsarath** | Google Fonts (เพิ่มใหม่) |
| ภาษาไทย | Inter | Google Fonts (มีอยู่แล้ว) |

**Auto-switching Logic:**
- เมื่อ `i18next.changeLanguage('lo')` ถูกเรียก
- `document.documentElement.lang` เปลี่ยนเป็น `"lo"`
- CSS selector `html[lang="lo"] body` ทำให้ทั้ง app ใช้ Phetsarath

---

### ผลลัพธ์ที่คาดหวัง

1. **Light/Dark Theme**: สลับได้ทุกหน้า พร้อม system preference support
2. **3 ภาษา**: English, ພາສາລາວ (Phetsarath font), ภาษาไทย
3. **Auto Font Switch**: เมื่อเลือกภาษาลาว ฟอนต์จะเปลี่ยนเป็น Phetsarath อัตโนมัติ
4. **Persistent Settings**: Theme และ Language ถูกจดจำใน localStorage

