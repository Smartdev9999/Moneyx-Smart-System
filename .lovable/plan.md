

## แผนเพิ่ม Entry Mode: Correlation Only - Harmony Dream EA v1.8.8

### สรุปความต้องการ:

เพิ่มโหมดใหม่ **Correlation Only** ที่ใช้ค่า Correlation + CDC Trend + ADX เป็นเกณฑ์หลักในการเปิด Initial Order แทน Z-Score

---

### 1. Positive Correlation Logic (EURUSD-GBPUSD +67%)

| CDC Trend | Order Direction | รายละเอียด |
|-----------|-----------------|-------------|
| **CDC Up (ทั้งคู่ Bullish)** | Buy EURUSD, Sell GBPUSD | BUY Data |
| **CDC Down (ทั้งคู่ Bearish)** | Sell EURUSD, Buy GBPUSD | SELL Data |

---

### 2. Negative Correlation Logic (AUDUSD-USDCHF -70%)

**ขั้นตอนที่ 1: CDC ต้องเป็น Opposite Trends**
- `Dw/Up` หรือ `Up/Dw` = เข้าเงื่อนไข
- `Up/Up` หรือ `Dw/Dw` = ไม่เข้าเงื่อนไข (BLOCK)

**ขั้นตอนที่ 2: ใช้ ADX ตัดสินฝั่งที่แข็งแกร่งกว่า**

| CDC | ADX Winner | Order Direction |
|-----|------------|-----------------|
| `Dw/Up` | A สูงกว่า (50:20) | Sell A + Sell B |
| `Dw/Up` | B สูงกว่า (20:50) | Buy A + Buy B |
| `Up/Dw` | A สูงกว่า (50:20) | Buy A + Buy B |
| `Up/Dw` | B สูงกว่า (20:50) | Sell A + Sell B |

---

### 3. เงื่อนไขการเปิด Order ใหม่เมื่อ Trend เปลี่ยน

**Initial Order:**
- ฝั่งที่มี Order อยู่แล้ว → **ไม่เปิด Initial Order ใหม่** จนกว่าจะปิดทั้งหมด
- ฝั่งที่ว่าง + Correlation ถึงเกณฑ์ + CDC/ADX เข้าเงื่อนไข → **เปิด Initial Order ได้**

**Grid Orders:**
- ทำงานปกติตามเงื่อนไข Grid (Distance + Corr/CDC Guard)
- ไม่ถูกบล็อกจากเงื่อนไข Initial Order

---

### รายละเอียดทางเทคนิค:

#### 1. เพิ่ม Entry Mode Enum และ Input Parameters

```text
enum ENUM_ENTRY_MODE
{
   ENTRY_MODE_ZSCORE = 0,        // Z-Score Based (Original)
   ENTRY_MODE_CORRELATION_ONLY   // Correlation Only (No Z-Score)
};

input group "=== Entry Mode Settings (v1.8.8) ==="
input ENUM_ENTRY_MODE InpEntryMode = ENTRY_MODE_ZSCORE;
input double InpCorrOnlyPositiveThreshold = 0.60;  // 60%
input double InpCorrOnlyNegativeThreshold = -0.60; // -60%
```

#### 2. ฟังก์ชันใหม่ที่ต้องสร้าง

| ฟังก์ชัน | หน้าที่ |
|----------|---------|
| `CheckCorrelationOnlyEntry()` | เช็คว่า Correlation ถึงเกณฑ์หรือไม่ |
| `DetermineTradeDirectionForCorrOnly()` | กำหนด BUY/SELL Data จาก CDC + ADX |
| `CheckGridTradingAllowedCorrOnly()` | Grid Guard แบบ Corr+CDC (ไม่สน Z-Score) |

#### 3. แก้ไข AnalyzeAllPairs()

เพิ่ม branch สำหรับ `ENTRY_MODE_CORRELATION_ONLY`:
- เช็ค Correlation threshold
- เรียก `DetermineTradeDirectionForCorrOnly()` เพื่อกำหนดทิศทาง
- เช็ค `directionBuy == -1` หรือ `directionSell == -1` (ยังไม่มี Order)
- เปิด Initial Order ตามทิศทางที่กำหนด

#### 4. แก้ไข CheckAllGridLoss() และ CheckAllGridProfit()

เปลี่ยนจาก:
```text
if(!CheckGridTradingAllowed(i, "BUY", pauseReason))
```

เป็น:
```text
bool gridAllowed = false;
if(InpEntryMode == ENTRY_MODE_ZSCORE)
   gridAllowed = CheckGridTradingAllowed(i, "BUY", pauseReason);
else
   gridAllowed = CheckGridTradingAllowedCorrOnly(i, "BUY", pauseReason);
```

---

### สรุปไฟล์ที่ต้องแก้ไข:

| ไฟล์ | การเปลี่ยนแปลง |
|------|----------------|
| `public/docs/mql5/Harmony_Dream_EA.mq5` | เพิ่ม Enum, Inputs, 3 ฟังก์ชันใหม่, แก้ AnalyzeAllPairs(), แก้ Grid functions |

---

### สิ่งที่ไม่เปลี่ยนแปลง:

- Exit Logic (Z-Score Exit, Profit Exit)
- Grid Distance Calculation
- Grid Lot Sizing (CDC Multiplier + ADX)
- RSI Spread Filter
- Group/Total Basket System
- License System

---

### ผลลัพธ์ที่คาดหวัง:

**Positive (EURUSD-GBPUSD +67%, CDC Up/Up):**
```text
[CORR ONLY] Pair 1 OPENED BUY DATA → Buy EURUSD, Sell GBPUSD
Grid Orders ทำงานปกติตาม Corr+CDC Guard
```

**Negative (AUDUSD-USDCHF -70%, CDC Dw/Up, ADX 50:20):**
```text
[CORR ONLY] Pair 21 OPENED SELL DATA → Sell AUDUSD, Sell USDCHF
Grid Orders ทำงานปกติตาม Corr+CDC Guard
```

**เมื่อ Trend เปลี่ยน + Correlation กลับมา:**
- ฝั่ง SELL Data มี Order อยู่ → ไม่เปิด SELL ใหม่
- ฝั่ง BUY Data ว่าง + เข้าเงื่อนไข → เปิด BUY ได้
- Grid Orders ทั้งสองฝั่งทำงานปกติ

