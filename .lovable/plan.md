
## แผนแก้ไข 2 ปัญหา: Fix License Reload + Duplicate Orders (v2.1.8)

---

### ปัญหาที่ 1: License ไม่ Reload เมื่อเปลี่ยน Timeframe

**สาเหตุที่วิเคราะห์ได้:**

จากโค้ดปัจจุบัน `OnInit()` → `VerifyLicense()` → `InitLicense()` → `VerifyLicenseWithServer()` ถูกเรียกทุกครั้งที่เปลี่ยน Timeframe แต่ปัญหาอาจเกิดจาก:

1. **ไม่มี Log แสดงชัดเจนว่า License กำลัง Reload** เมื่อเปลี่ยน TF
2. **Popup ถูกแสดงแต่อาจถูกปิดเร็วเกินไป** หรือ minimize ลงไป
3. **global variables ไม่ได้ถูก reset** ก่อน verify ใหม่

**การแก้ไข:**

#### Part A: เพิ่ม Log ที่ชัดเจนเมื่อ License Reload

```cpp
// OnInit() - เพิ่ม log ก่อน VerifyLicense()
Print("=================================================");
Print("[OnInit] EA Restarted - Reloading License...");
Print("[OnInit] Reason: Timeframe Change / Chart Reload");
Print("=================================================");

// Reset license variables ก่อน verify
g_isLicenseValid = false;
g_licenseStatus = LICENSE_ERROR;
g_lastLicenseCheck = 0;

// Verify license
g_isLicenseValid = VerifyLicense();
```

#### Part B: เพิ่ม Option ให้เลือกแสดง/ซ่อน Popup เมื่อ Reload

```cpp
// Input Parameters (ใหม่)
input bool InpShowPopupOnReload = true;  // Show License Popup on TF Change
```

```cpp
// VerifyLicense() - เพิ่มเงื่อนไข
if(InpShowPopupOnReload || g_isFirstInit)
{
   ShowLicensePopup(g_licenseStatus);
}
```

#### Part C: แสดง License Status บน Dashboard แทน Popup

เพิ่มการแสดง License Status ที่มุมบน Dashboard:
- `LICENSE: OK` (สีเขียว)
- `LICENSE: EXPIRING` (สีเหลือง)
- `LICENSE: ERROR` (สีแดง)

---

### ปัญหาที่ 2: Duplicate Orders เมื่อ Restart EA

**สาเหตุ:** `RestoreOpenPositions()` match symbol โดยไม่ดู pair index จาก comment

**การแก้ไข (จากแผนก่อนหน้า):**

#### Part D: เพิ่มฟังก์ชัน Extract Pair Index จาก Comment

```cpp
int ExtractPairIndexFromComment(string comment)
{
   // Pattern: "_BUY_XX" หรือ "_SELL_XX"
   int buyPos = StringFind(comment, "_BUY_");
   int sellPos = StringFind(comment, "_SELL_");
   
   int sidePos = (buyPos >= 0) ? buyPos : sellPos;
   if(sidePos < 0) return -1;
   
   int numStart = sidePos + ((buyPos >= 0) ? 5 : 6);
   string numStr = "";
   for(int i = numStart; i < StringLen(comment); i++)
   {
      ushort ch = StringGetCharacter(comment, i);
      if(ch >= '0' && ch <= '9')
         numStr += CharToString((uchar)ch);
      else
         break;
   }
   
   if(numStr == "") return -1;
   return (int)StringToInteger(numStr) - 1;  // 0-based index
}
```

#### Part E: แก้ไข RestoreOpenPositions() ให้ตรวจสอบ Pair Index

```cpp
// RestoreOpenPositions() - เพิ่มการตรวจสอบ
int commentPairIndex = ExtractPairIndexFromComment(comment);

for(int i = 0; i < MAX_PAIRS; i++)
{
   if(!g_pairs[i].enabled) continue;
   if(symbol != g_pairs[i].symbolA && symbol != g_pairs[i].symbolB) continue;
   
   // v2.1.8: Verify pair index from comment
   if(commentPairIndex >= 0 && commentPairIndex != i)
      continue;  // Wrong pair - skip
   
   // Also verify prefix for new format
   string expectedPrefix = GetPairCommentPrefix(i);
   if(StringFind(comment, "-") > 0 && StringFind(comment, expectedPrefix) != 0)
      continue;  // Prefix mismatch - skip
   
   // ... rest of restore logic
}
```

---

### สรุปไฟล์และบรรทัดที่แก้ไข

| ไฟล์ | ส่วนที่แก้ไข | บรรทัด (ประมาณ) | รายละเอียด |
|------|-------------|-----------------|------------|
| `Harmony_Dream_EA.mq5` | Version | 7-10 | อัปเดตเป็น v2.18 |
| `Harmony_Dream_EA.mq5` | Input Parameters | 610-612 | เพิ่ม `InpShowPopupOnReload` |
| `Harmony_Dream_EA.mq5` | `OnInit()` | 1168-1180 | เพิ่ม log + reset license vars |
| `Harmony_Dream_EA.mq5` | New Function | 1520-1550 | เพิ่ม `ExtractPairIndexFromComment()` |
| `Harmony_Dream_EA.mq5` | `RestoreOpenPositions()` | 1555-1600 | เพิ่มการตรวจสอบ pair index |
| `Harmony_Dream_EA.mq5` | `VerifyLicense()` | 3685-3690 | เพิ่มเงื่อนไข popup |
| `Harmony_Dream_EA.mq5` | Dashboard | TBD | เพิ่มแสดง License Status |

---

### ผลลัพธ์ที่คาดหวัง

| สถานการณ์ | ก่อนแก้ไข | หลังแก้ไข |
|-----------|----------|----------|
| เปลี่ยน Timeframe | ไม่รู้ว่า License reload หรือไม่ | เห็น Log + Dashboard แสดง status |
| Restart EA + มี order อยู่ | Order ถูก restore ผิด pair | Order restore ถูก pair ตาม comment |
| Duplicate Orders | เกิดขึ้น | ไม่เกิดขึ้น |

---

### Version Update

```cpp
#property version   "2.18"
#property description "v2.1.8: Fix License Reload + Duplicate Orders Prevention"
```
