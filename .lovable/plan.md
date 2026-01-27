
## แผนเพิ่ม Light Mode Theme และ Theme Selector - Harmony Dream EA v1.8.5

### เป้าหมาย:
1. เพิ่ม **Light Mode** theme ใหม่สำหรับ Dashboard
2. สร้าง **Theme Selector** ให้เลือกระหว่าง Light/Dark Mode
3. **ซ่อน Input Parameters สี** ทั้งหมด (ไม่ให้แก้ไขได้)
4. **ย้ายหมวด Theme และ Backtest Settings** ไปไว้ล่างสุดใต้ News Filter
5. ไม่แตะต้อง Trading Logic ใดๆ

---

### 1. เพิ่ม Theme Mode ENUM (บรรทัด ~205)

```text
enum ENUM_THEME_MODE
{
   THEME_DARK = 0,    // Dark Mode (Default)
   THEME_LIGHT        // Light Mode
};
```

---

### 2. แทนที่ Dashboard Colors Input ด้วย Theme Selector (บรรทัด 398-408)

**เปลี่ยนจาก:**
```text
input group "=== Dashboard Colors (v1.8.3 Modern Dark Theme) ==="
input color    InpColorBgDark = C'18,24,38';        // Background Color (Dark Navy)
input color    InpColorRowOdd = C'28,36,52';        // Row Color (Odd)
... (10 color inputs)
```

**เป็น:**
```text
input group "=== Dashboard Theme (v1.8.5) ==="
input ENUM_THEME_MODE InpThemeMode = THEME_DARK;    // Dashboard Theme
```

- ซ่อนตั้งค่าสี 10 ตัวทั้งหมด
- เหลือแค่ Theme Selector ตัวเดียว

---

### 3. ย้ายลำดับ Input Groups

**ลำดับเดิม:**
```text
1. Dashboard Position
2. Dashboard Colors (v1.8.3) ← จะซ่อน/ย้าย
3. Fast Backtest Settings ← จะย้าย
4. Lot Sizing
5. Risk Management
6. Pair Configurations...
7. News Filter
```

**ลำดับใหม่:**
```text
1. Dashboard Position
2. Lot Sizing
3. Risk Management
4. Pair Configurations...
5. News Filter
6. Dashboard Theme (v1.8.5) ← ย้ายมาล่างสุด (ใต้ News Filter)
7. Fast Backtest Settings ← ย้ายมาล่างสุด
```

---

### 4. เพิ่มฟังก์ชัน InitializeThemeColors() (ใหม่)

สร้างฟังก์ชันใหม่เพื่อกำหนดสีตาม Theme ที่เลือก:

```text
void InitializeThemeColors()
{
   if(InpThemeMode == THEME_LIGHT)
   {
      // === LIGHT MODE COLOR PALETTE ===
      COLOR_BG_DARK      = C'245,247,250';      // Light Gray Background
      COLOR_BG_ROW_ODD   = C'255,255,255';      // White
      COLOR_BG_ROW_EVEN  = C'240,242,245';      // Very Light Gray
      COLOR_HEADER_MAIN  = C'80,100,140';       // Muted Blue
      COLOR_HEADER_BUY   = C'30,110,180';       // Professional Blue
      COLOR_HEADER_SELL  = C'180,50,60';        // Professional Red
      COLOR_PROFIT       = C'0,150,80';         // Dark Green
      COLOR_LOSS         = C'200,40,50';        // Dark Red
      COLOR_ON           = C'0,160,100';        // Teal Green
      COLOR_OFF          = C'140,145,155';      // Medium Gray
      
      // Additional Light Mode colors
      COLOR_TEXT         = C'30,35,45';         // Dark Text
      COLOR_GOLD         = C'200,150,0';        // Dark Gold
      COLOR_ACTIVE       = C'30,120,200';       // Blue
      COLOR_BORDER       = C'200,205,215';      // Light Border
      COLOR_HEADER_TXT   = clrWhite;            // Keep white for headers
   }
   else  // THEME_DARK (Default)
   {
      // === DARK MODE COLOR PALETTE (v1.8.3) ===
      COLOR_BG_DARK      = C'18,24,38';         // Dark Navy
      COLOR_BG_ROW_ODD   = C'28,36,52';         // Dark Slate
      COLOR_BG_ROW_EVEN  = C'22,30,46';         // Darker Slate
      COLOR_HEADER_MAIN  = C'45,55,90';         // Muted Indigo
      COLOR_HEADER_BUY   = C'15,75,135';        // Deep Blue
      COLOR_HEADER_SELL  = C'135,45,55';        // Deep Red
      COLOR_PROFIT       = C'50,205,100';       // Bright Green
      COLOR_LOSS         = C'235,70,80';        // Coral Red
      COLOR_ON           = C'0,200,120';        // Teal Green
      COLOR_OFF          = C'90,100,120';       // Cool Gray
      
      // Additional Dark Mode colors
      COLOR_TEXT         = C'200,210,225';      // Light Gray
      COLOR_GOLD         = C'255,200,60';       // Warm Gold
      COLOR_ACTIVE       = C'70,160,250';       // Sky Blue
      COLOR_BORDER       = C'55,65,85';         // Subtle Border
      COLOR_HEADER_TXT   = clrWhite;            // White headers
   }
}
```

---

### 5. อัพเดท Hardcoded Colors ใน CreateDashboard()

จะเปลี่ยน hardcoded colors ให้ใช้ตัวแปร Global เพื่อรองรับ Theme:

| ตำแหน่ง | เดิม | ใหม่ |
|---------|------|------|
| Title Background (7324) | `C'25,45,70'` | สร้างตัวแปร `COLOR_TITLE_BG` |
| Column Header BUY (7396) | `C'20,60,100'` | ใช้ `COLOR_HEADER_BUY` ผสม |
| Column Header CENTER (7397) | `C'35,42,58'` | ใช้ `COLOR_HEADER_MAIN` ผสม |
| Column Header SELL (7398) | `C'100,45,50'` | ใช้ `COLOR_HEADER_SELL` ผสม |
| Group Header (7392) | `C'65,50,95'` | สร้างตัวแปร `COLOR_HEADER_GROUP` |
| Summary Box BG (7558, 7578, 7603, 7634) | `C'28,35,50'` | สร้างตัวแปร `COLOR_BOX_BG` |

---

### 6. Light Mode Color Palette สรุป

```text
=== LIGHT MODE THEME ===

Background Palette:
├── Main BG:     #F5F7FA (C'245,247,250')  - Clean Light Gray
├── Row Odd:     #FFFFFF (C'255,255,255')  - Pure White
├── Row Even:    #F0F2F5 (C'240,242,245')  - Very Light Gray
├── Box BG:      #E8EBF0 (C'232,235,240')  - Subtle Gray
└── Border:      #C8CDD7 (C'200,205,215')  - Light Border

Header Palette:
├── Title BG:    #4A6080 (C'74,96,128')    - Slate Blue
├── Buy Header:  #1E6EB4 (C'30,110,180')   - Professional Blue
├── Sell Header: #B4323C (C'180,50,60')    - Professional Red
├── Main Header: #506480 (C'80,100,140')   - Muted Blue
└── Group Header: #6B5A85 (C'107,90,133')  - Muted Purple

Text Palette:
├── Primary:     #1E232D (C'30,35,45')     - Dark Text
├── Profit:      #009650 (C'0,150,80')     - Dark Green
├── Loss:        #C82832 (C'200,40,50')    - Dark Red
├── Gold:        #C89600 (C'200,150,0')    - Dark Gold
└── Active:      #1E78C8 (C'30,120,200')   - Blue

Status Palette:
├── ON:          #00A064 (C'0,160,100')    - Teal Green
├── OFF:         #8C919B (C'140,145,155')  - Medium Gray
└── Header Text: clrWhite                   - White (keep)
```

---

### 7. เพิ่ม Global Variables สำหรับ Theme Colors ใหม่

เพิ่มตัวแปรใหม่ที่ต้องการสำหรับ Light Mode (บรรทัด ~735):

```text
// v1.8.5: Extended Theme Colors
color COLOR_TITLE_BG;
color COLOR_BOX_BG;
color COLOR_HEADER_GROUP;
color COLOR_COLHDR_BUY;
color COLOR_COLHDR_CENTER;
color COLOR_COLHDR_SELL;
color COLOR_COLHDR_GROUP;
```

---

### 8. อัพเดท OnInit() (บรรทัด 849-859)

**เปลี่ยนจาก:**
```text
// Initialize dashboard colors from inputs
COLOR_BG_DARK = InpColorBgDark;
COLOR_BG_ROW_ODD = InpColorRowOdd;
...
```

**เป็น:**
```text
// v1.8.5: Initialize theme colors
InitializeThemeColors();
```

---

### 9. อัพเดท CreateDashboard() ให้ใช้ตัวแปร Theme

เปลี่ยน hardcoded colors เป็นตัวแปร:

| Line | เดิม | ใหม่ |
|------|------|------|
| 7324 | `C'25,45,70', C'25,45,70'` | `COLOR_TITLE_BG, COLOR_TITLE_BG` |
| 7392 | `C'65,50,95', C'65,50,95'` | `COLOR_HEADER_GROUP, COLOR_HEADER_GROUP` |
| 7396 | `C'20,60,100', C'20,60,100'` | `COLOR_COLHDR_BUY, COLOR_COLHDR_BUY` |
| 7397 | `C'35,42,58', C'35,42,58'` | `COLOR_COLHDR_CENTER, COLOR_COLHDR_CENTER` |
| 7398 | `C'100,45,50', C'100,45,50'` | `COLOR_COLHDR_SELL, COLOR_COLHDR_SELL` |
| 7400 | `C'50,40,70', C'50,40,70'` | `COLOR_COLHDR_GROUP, COLOR_COLHDR_GROUP` |
| 7558 | `C'28,35,50'` | `COLOR_BOX_BG` |
| 7578 | `C'28,35,50'` | `COLOR_BOX_BG` |
| 7603 | `C'28,35,50'` | `COLOR_BOX_BG` |
| 7634 | `C'28,35,50'` | `COLOR_BOX_BG` |

---

### 10. อัพเดท Version

**บรรทัด 7:**
```text
#property version   "1.85"
```

**บรรทัด ~7332 (Dashboard Title):**
```text
"Harmony Dream EA v1.8.5"
```

---

### รายการไฟล์ที่จะแก้ไข:

| ไฟล์ | การเปลี่ยนแปลง |
|------|----------------|
| `public/docs/mql5/Harmony_Dream_EA.mq5` | เพิ่ม ENUM, ย้าย input groups, เพิ่มฟังก์ชัน InitializeThemeColors(), อัพเดท CreateDashboard() |

---

### สิ่งที่ไม่แตะต้อง:

- Trading Logic ทั้งหมด
- ADX / CDC / Correlation Calculation
- Grid Distance และ Lot Calculation
- Order Management
- License System
- News Filter Logic (เฉพาะย้ายตำแหน่ง input เท่านั้น)

---

### ผลลัพธ์ที่คาดหวัง:

**Dark Mode (Default):**
- โทนสีเดิมจาก v1.8.3/v1.8.4
- พื้นหลังน้ำเงินเข้ม, ตัวหนังสือสว่าง

**Light Mode (New):**
- พื้นหลังสีขาว/เทาอ่อน
- ตัวหนังสือสีเข้ม (dark text)
- Headers ยังคงสีสันชัดเจน (น้ำเงิน/แดง)
- Profit/Loss สีเข้มกว่าเพื่อ contrast กับพื้นสว่าง

**Input Parameters:**
- เหลือแค่ Theme Selector (Dark/Light)
- ซ่อนตั้งค่าสี 10 ตัว
- ย้าย Theme + Backtest Settings ไปล่างสุด
