
## แผนแก้ไข v2.3.4: รองรับบัญชี Cent Account (USC) - ฉบับแก้ไข

---

### ปัญหาที่แท้จริง

**หลักการของผู้ใช้:**
- Input ค่า "500" บัญชี Dollar → หมายถึง กำไร 500 USD ต้องสะสม
- Input ค่า "500" บัญชี Cent → หมายถึง กำไร 500 USC ต้องสะสม
- ค่า Input ไม่ต้องแปลง เพราะมันคือหน่วยของแต่ละบัญชี

**ปัญหาจริง:** Auto Scaling คำนวณผิด
```
บัญชี Cent (10,000 USC = $100):
  Scale Factor = 10000 / 100000 = 0.1  ← ผิด! ต้อง 0.001
  Mini Target = 500 × 0.1 = 50 USC     ← ผิด! ต้อง 5 USC (0.05 USD)
```

---

### โซลูชันแก้ไข

#### 1. Auto-Detect Cent Account
- ตรวจจับจาก Currency (USC, USc, EUc, etc.) และ Server name
- เพิ่ม Flag `g_isCentAccount` และ `g_centMultiplier = 100`
- แสดง [CENT] หรือ [STD] ใน Dashboard

#### 2. นำเสนอ Scaled Targets ให้ถูกต้อง
**NOT MULTIPLY** targets by 100
```cpp
// ❌ ผิด
return ConvertTargetToCent(scaledTarget);  // Target * 100

// ✓ ถูก
return ApplyScaleDollar(baseTarget);  // ใช้ Scale Factor ตามปกติ
```

#### 3. แก้ Auto Scaling สำหรับ Cent
```cpp
// GetRealBalanceUSD() - ทำให้ Scale Factor ถูกต้อง
double GetRealBalanceUSD() {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(g_isCentAccount) {
      return balance / 100;  // 10000 USC → 100 USD
   }
   return balance;
}

// GetScaleFactor() - ใช้ Normalized Balance
double GetScaleFactor() {
   double accountSize = GetRealBalanceUSD();  // ← ใช้ normalized balance
   double factor = accountSize / InpBaseAccountSize;
   // 100 / 100000 = 0.001 ✓ ถูก
   return NormalizeDouble(MathMax(InpScaleMin, MathMin(InpScaleMax, factor)), 4);
}

// Target ไม่เปลี่ยน
double GetScaledMiniGroupTarget(int miniIndex) {
   double baseTarget = InpMini1Target;  // 500 USC หรือ 500 USD
   return ApplyScaleDollar(baseTarget);  // ใช้ factor จาก GetScaleFactor()
   // 500 × 0.001 = 0.5 USD (เทียบกับ 50 USC หรือ 0.5 USD) ✓
}
```

---

### การแก้ไขที่ต้องทำ

| ลำดับ | ส่วน | การแก้ไข |
|------|------|---------|
| 1 | Version | อัปเดต 2.34 |
| 2 | Global Variables | เพิ่ม `g_isCentAccount`, `g_centMultiplier` |
| 3 | Inputs | เพิ่ม `InpAutoDetectCent`, `InpManualCentMode` |
| 4 | DetectCentAccount() | เรียกใน OnInit() เพื่อตรวจจับ |
| 5 | GetRealBalanceUSD() | ทำให้ Auto Scaling ถูกต้อง |
| 6 | GetScaleFactor() | ใช้ GetRealBalanceUSD() แทน ACCOUNT_BALANCE |
| 7 | Dashboard | แสดง [CENT] หรือ [STD] |

---

### ตัวอย่างการทำงานที่ถูกต้อง

**บัญชี Cent (USC) - Balance 10,000 USC ($100), Base Size $100,000**

| รายการ | ก่อน | หลัง |
|--------|------|------|
| Detected | ❌ Standard | ✓ CENT |
| Real Balance | 10000 USD ❌ | 100 USD ✓ |
| Scale Factor | 10000/100000 = 0.1 ❌ | 100/100000 = 0.001 ✓ |
| Target 500 | 500 × 0.1 = 50 ❌ | 500 × 0.001 = 0.5 ✓ |
| Profit 50 USC | 50 >= 50 CLOSE ❌ | 50 >= 500 WAIT ✓ |

**บัญชี Dollar - Balance $100, Base Size $100,000**

| รายการ | ก่อน | หลัง |
|--------|------|------|
| Detected | Standard ✓ | STD ✓ |
| Real Balance | 100 USD ✓ | 100 USD ✓ |
| Scale Factor | 100/100000 = 0.001 ✓ | 100/100000 = 0.001 ✓ |
| Target 500 | 500 × 0.001 = 0.5 ✓ | 500 × 0.001 = 0.5 ✓ |

---

### ไฟล์ที่แก้ไข

- `public/docs/mql5/Harmony_Dream_EA.mq5` เท่านั้น

---

### หมายเหตุสำคัญ

1. **ไม่ต้องแปลง Target**: User input 500 = 500 USC (Cent) หรือ 500 USD (Standard)
2. **Scaling ต้องแปลง Balance**: การคำนวณ Scale Factor ต้องนำ Balance มาหารด้วย 100 สำหรับ Cent
3. **Dashboard แสดง Native Unit**: ยังแสดงค่าเป็น USC หรือ USD ตามบัญชี
4. **ไม่กระทบ Profit Comparison**: Profit จาก MT5 เป็น Native unit อยู่แล้ว

