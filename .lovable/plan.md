

## แผนแก้ไข: P/L Recovery & Z-Score Pending (v1.8.9)

### สรุปปัญหาที่พบ

| ปัญหา | สาเหตุ | บรรทัด |
|-------|--------|--------|
| **P/L แสดง 0** | `IsMainComment()` ใช้แค่ `HrmDream_` ไม่รองรับ format ใหม่ `EU-GU_BUY_1` | 1265-1280 |
| **Z-Score "Pending"** | `g_lastZScoreUpdateDisplay = 0` ตอนเริ่มต้น ไม่มีการ force update ใน OnInit | 805, 1225 |

---

### การแก้ไข (เฉพาะส่วนที่เกี่ยวข้อง)

---

#### 1. แก้ไข `IsMainComment()` - รองรับ Comment Format ใหม่

**ไฟล์:** `public/docs/mql5/Harmony_Dream_EA.mq5`  
**บรรทัด:** 1265-1280

**ก่อนแก้ไข:**
```cpp
bool IsMainComment(string comment, string side, int pairIndex)
{
   string mainPrefix = StringFormat("HrmDream_%s_%d", side, pairIndex + 1);
   if(StringFind(comment, mainPrefix) != 0)
      return false;
   // ... exclude grid markers
   return true;
}
```

**หลังแก้ไข:**
```cpp
bool IsMainComment(string comment, string side, int pairIndex)
{
   // v1.8.9: Support BOTH legacy and new comment format
   
   // Format 1 (Legacy): HrmDream_BUY_1
   string legacyPrefix = StringFormat("HrmDream_%s_%d", side, pairIndex + 1);
   
   // Format 2 (New v1.8.6+): EU-GU_BUY_1
   string newPrefix = GetPairCommentPrefix(pairIndex);
   string newSuffix = StringFormat("_%s_%d", side, pairIndex + 1);
   
   bool matchLegacy = (StringFind(comment, legacyPrefix) == 0);
   bool matchNew = (StringFind(comment, newPrefix) == 0 && 
                    StringFind(comment, newSuffix) >= 0);
   
   if(!matchLegacy && !matchNew)
      return false;
   
   // Must NOT contain grid identifiers
   if(StringFind(comment, "_GL") >= 0) return false;
   if(StringFind(comment, "_GP") >= 0) return false;
   if(StringFind(comment, "_AVG_") >= 0) return false;
   
   return true;
}
```

---

#### 2. แก้ไข `IsGridComment()` - รองรับ Comment Format ใหม่

**บรรทัด:** 1285-1295

**หลังแก้ไข:**
```cpp
bool IsGridComment(string comment, string side, int pairIndex)
{
   // v1.8.9: Support BOTH legacy and new comment format
   string pairStr = IntegerToString(pairIndex + 1);
   string newPrefix = GetPairCommentPrefix(pairIndex);
   
   // Legacy format: HrmDream_GL_BUY_1
   if(StringFind(comment, "HrmDream_GL_" + side + "_" + pairStr) >= 0) return true;
   if(StringFind(comment, "HrmDream_GP_" + side + "_" + pairStr) >= 0) return true;
   if(StringFind(comment, "HrmDream_AVG_" + side + "_" + pairStr) >= 0) return true;
   
   // New format: EU-GU_GL#1_BUY_1 หรือ EU-GU_GP#1_BUY_1
   string sideSuffix = "_" + side + "_" + pairStr;
   if(StringFind(comment, newPrefix + "_GL") >= 0 && 
      StringFind(comment, sideSuffix) >= 0) return true;
   if(StringFind(comment, newPrefix + "_GP") >= 0 && 
      StringFind(comment, sideSuffix) >= 0) return true;
   
   return false;
}
```

---

#### 3. เพิ่ม Force Update ใน `OnInit()` หลัง RestoreOpenPositions

**บรรทัด:** ~1225 (หลัง `RestoreOpenPositions();`)

**เพิ่ม Code:**
```cpp
   // v1.3: Restore open positions from previous session (Magic Number-based)
   RestoreOpenPositions();
   
   // v1.8.9: Force immediate P/L and Z-Score calculation after restore
   // This prevents "Pending" state and ensures P/L displays correctly
   UpdateZScoreData();
   g_lastZScoreUpdateDisplay = TimeCurrent();
   CalculateAllRSIonSpread();
   UpdatePairProfits();
   UpdateGroupProfits();
```

---

#### 4. อัพเดต Version Number

**บรรทัด:** 7

```cpp
#property version   "1.89"
```

**บรรทัด:** 9 (เพิ่ม description)

```cpp
#property description "v1.8.9: Enhanced Comment-Based P/L Recovery + Immediate Z-Score Init"
```

---

### สรุปไฟล์ที่แก้ไข

| ไฟล์ | ฟังก์ชัน | บรรทัด | การเปลี่ยนแปลง |
|------|----------|--------|----------------|
| `Harmony_Dream_EA.mq5` | `IsMainComment()` | 1265-1280 | รองรับ new comment format |
| `Harmony_Dream_EA.mq5` | `IsGridComment()` | 1285-1295 | รองรับ new comment format |
| `Harmony_Dream_EA.mq5` | `OnInit()` | ~1225 | เพิ่ม force update หลัง restore |
| `Harmony_Dream_EA.mq5` | Header | 7, 9 | อัพเดต version เป็น 1.89 |

---

### สิ่งที่ไม่แก้ไข (ตาม request)

- `RestoreOpenPositions()` - ทำงานถูกต้องแล้ว (detect side จาก `_BUY_` / `_SELL_`)
- `UpdatePairProfits()` - ทำงานถูกต้องแล้ว (ใช้ prefix+suffix matching)
- `RecoverMissingTickets()` - จะทำงานได้หลังแก้ `IsMainComment()`
- ส่วนอื่นๆ ทั้งหมด - ไม่มีการแตะต้อง

---

### ผลลัพธ์ที่คาดหวัง

1. **P/L แสดงทันที** - `IsMainComment()` match ทั้ง format เก่าและใหม่ → tickets recover ได้ → P/L คำนวณถูก
2. **Z-Score แสดงทันที** - Force update ใน OnInit → ไม่มี "Pending" อีกต่อไป
3. **Backward Compatible** - ยังรองรับ orders ที่มี comment แบบเก่า `HrmDream_`

