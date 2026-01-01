# MQL5 License Verification System

## ไฟล์ที่รวมอยู่

1. **LicenseManager.mqh** - ไลบรารี่หลักสำหรับจัดการ License
2. **EA_LicenseExample.mq5** - ตัวอย่าง EA ที่ใช้ระบบ License

## การติดตั้ง

### 1. คัดลอกไฟล์

คัดลอกไฟล์ไปยังโฟลเดอร์ MQL5:
- `LicenseManager.mqh` → `MQL5/Include/` หรือ ในโฟลเดอร์เดียวกับ EA
- `EA_LicenseExample.mq5` → `MQL5/Experts/`

### 2. อนุญาต WebRequest

ใน MetaTrader 5:
1. ไปที่ **Tools → Options → Expert Advisors**
2. ติ๊ก **"Allow WebRequest for listed URL"**
3. เพิ่ม URL: `https://lkbhomsulgycxawwlnfh.supabase.co`
4. คลิก **OK**

### 3. คอมไพล์ EA

1. เปิด MetaEditor
2. เปิดไฟล์ EA
3. กด **F7** หรือ **Compile**

## การใช้งาน

### การใช้งานพื้นฐาน

```mql5
#include "LicenseManager.mqh"

CLicenseManager* g_license = NULL;

int OnInit()
{
   g_license = new CLicenseManager();
   
   // Initialize with server URL
   if(!g_license.Init("https://lkbhomsulgycxawwlnfh.supabase.co", 60, 5))
   {
      Print("License failed!");
      return INIT_FAILED;
   }
   
   return INIT_SUCCEEDED;
}

void OnTick()
{
   // Check license periodically
   if(!g_license.OnTick())
      return; // Don't trade if invalid
   
   // Your trading logic here...
}

void OnDeinit(const int reason)
{
   delete g_license;
}
```

### Parameters

| Parameter | Description |
|-----------|-------------|
| `InpLicenseServer` | URL ของ License Server |
| `InpLicenseCheckMinutes` | ความถี่ในการตรวจสอบ License (นาที) |
| `InpDataSyncMinutes` | ความถี่ในการ Sync ข้อมูลบัญชี (นาที) |

## License Status

| Status | คำอธิบาย |
|--------|----------|
| `LICENSE_VALID` | License ถูกต้องและใช้งานได้ |
| `LICENSE_EXPIRING_SOON` | License จะหมดอายุภายใน 7 วัน |
| `LICENSE_EXPIRED` | License หมดอายุแล้ว |
| `LICENSE_NOT_FOUND` | ไม่พบบัญชีในระบบ |
| `LICENSE_SUSPENDED` | License ถูกระงับ |
| `LICENSE_ERROR` | เกิดข้อผิดพลาดในการเชื่อมต่อ |

## Pop-up Messages

ระบบจะแสดง Pop-up อัตโนมัติเมื่อ:
- ✅ เริ่มต้น EA และ License ถูกต้อง
- ⚠️ License ใกล้หมดอายุ (วันละ 1 ครั้ง)
- ❌ License หมดอายุ/ไม่พบ/ถูกระงับ
- ⚠️ เกิดข้อผิดพลาดในการเชื่อมต่อ

## ฟังก์ชันที่ใช้ได้

```mql5
// ตรวจสอบสถานะ
bool isValid = g_license.IsLicenseValid();
string customerName = g_license.GetCustomerName();
string packageType = g_license.GetPackageType();
datetime expiryDate = g_license.GetExpiryDate();
int daysLeft = g_license.GetDaysRemaining();
bool isLifetime = g_license.IsLifetime();
string lastError = g_license.GetLastError();

// ตรวจสอบ License ด้วยตัวเอง
ENUM_LICENSE_STATUS status = g_license.VerifyLicense();

// Sync ข้อมูลบัญชีด้วยตัวเอง
bool synced = g_license.SyncAccountData();
```

## Troubleshooting

### "WebRequest not allowed"
- ตรวจสอบว่าเพิ่ม URL ใน Expert Advisors options แล้ว
- ตรวจสอบว่าพิมพ์ URL ถูกต้อง

### "Account not registered"
- ตรวจสอบว่าลงทะเบียนหมายเลขบัญชีในระบบ Admin แล้ว
- ตรวจสอบว่าหมายเลขบัญชีตรงกัน

### "Connection failed"
- ตรวจสอบการเชื่อมต่ออินเทอร์เน็ต
- ตรวจสอบว่า Firewall ไม่บล็อก MetaTrader

## Data ที่ Sync ไปยัง Server

ระบบจะส่งข้อมูลบัญชีไปยัง Server ทุก 5 นาที (ค่า default):
- Balance (ยอดเงิน)
- Equity (มูลค่าสุทธิ)
- Margin Level
- Drawdown
- Profit/Loss (กำไร/ขาดทุน)

ข้อมูลเหล่านี้สามารถดูได้ใน Admin Dashboard
