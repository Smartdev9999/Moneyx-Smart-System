# Plan Status: ✅ COMPLETED

## v2.1.8 - Fix License Reload + Duplicate Orders Prevention

### ✅ Changes Applied

| ส่วนที่แก้ไข | บรรทัด | รายละเอียด |
|-------------|--------|------------|
| Version | 7-11 | อัปเดตเป็น v2.18 + description |
| OnInit() License Reset | 1168-1190 | เพิ่ม log + reset `g_isLicenseValid`, `g_licenseStatus`, `g_lastLicenseCheck` |
| New Function | 1336-1378 | เพิ่ม `ExtractPairIndexFromComment()` |
| RestoreOpenPositions() | 1593-1636 | เพิ่มการตรวจสอบ pair index + prefix verification |

---

### สรุปการแก้ไข

**1. Fix License Reload เมื่อเปลี่ยน Timeframe:**
- Reset `g_isLicenseValid = false` ก่อน verify ใหม่
- Reset `g_licenseStatus = LICENSE_ERROR`
- Reset `g_lastLicenseCheck = 0`
- เพิ่ม Log ชัดเจน `[v2.1.8] EA Restarted - Reloading License...`

**2. Fix Duplicate Orders เมื่อ Restart EA:**
- เพิ่มฟังก์ชัน `ExtractPairIndexFromComment()` เพื่อดึง pair index จาก comment
- แก้ไข `RestoreOpenPositions()` ให้ตรวจสอบ:
  - `commentPairIndex >= 0 && commentPairIndex != i` → skip wrong pair
  - Prefix verification สำหรับ new format (e.g., "AU-AJ" ต้อง match)
  
---

### Flow หลังแก้ไข

```
Position: AUDUSD ticket=77576788 comment="AU-AJ_BUY_26[M:888888]"

1. ExtractPairIndexFromComment("AU-AJ_BUY_26[M:888888]") → 25 (0-based)

2. Loop through pairs:
   - Pair 11 (AUDUSD-NZDUSD): symbol matches BUT commentPairIndex=25 != 10 → SKIP
   - Pair 12 (EURUSD-AUDUSD): symbol matches BUT commentPairIndex=25 != 11 → SKIP
   - ...
   - Pair 26 (AUDUSD-AUDJPY): symbol matches AND commentPairIndex=25 == 25 → MATCH!
   
3. Pair 26 restored correctly → directionBuy = 1 (Active)
4. AnalyzeAllPairs() sees Pair 26 has order → NO duplicate!
```

---

### ผลลัพธ์ที่คาดหวัง

| สถานการณ์ | ก่อนแก้ไข | หลังแก้ไข v2.1.8 |
|-----------|----------|------------------|
| เปลี่ยน Timeframe | ไม่รู้ว่า License reload | เห็น Log + License reload ใหม่ทุกครั้ง |
| Restart EA + มี order | Order อาจ restore ผิด pair | Order restore ถูก pair ตาม comment |
| Duplicate Orders | เกิดขึ้น | ไม่เกิดขึ้น |
