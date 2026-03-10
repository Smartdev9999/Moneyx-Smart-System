

## แก้ไข License Error 401 ใน Asset Miner EA

### สาเหตุ
ที่ line 3761 ใน `Asset_Miner_EA.mq5` ใช้ header ผิด:
```text
ปัจจุบัน (ผิด): "Apikey: xxx\r\nAuthorization: Bearer xxx"
ที่ถูกต้อง:       "x-api-key: xxx\r\n"
```

Edge function `verify-license` ตรวจสอบ API key จาก header `x-api-key` เท่านั้น ทำให้ Asset Miner ส่ง key ผิด header → ได้ 401 Unauthorized

EA ตัวอื่น (Gold Miner, Harmony Dream, MoneyX Harmony Flow) ใช้ `x-api-key` ถูกต้องทั้งหมด

### การแก้ไข
**ไฟล์:** `public/docs/mql5/Asset_Miner_EA.mq5` line 3761

เปลี่ยนจาก:
```cpp
string headers = "Content-Type: application/json\r\nApikey: " + EA_API_SECRET + "\r\nAuthorization: Bearer " + EA_API_SECRET;
```
เป็น:
```cpp
string headers = "Content-Type: application/json\r\nx-api-key: " + EA_API_SECRET + "\r\n";
```

### สิ่งที่ไม่เปลี่ยนแปลง
- Trading Strategy Logic (SMA, ZigZag, Grid entry/exit)
- Order Execution, TP/SL/Trailing/Breakeven
- License verification logic flow
- Dashboard, Rebate, Drawdown features
- News/Time Filter

