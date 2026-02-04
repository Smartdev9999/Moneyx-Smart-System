
## แผนแก้ไข: New Cycle Lot Reset Bug (v2.2.5)

---

### สรุปปัญหาที่พบ

| สถานการณ์ | ค่า `lotBuyA` | `NormalizeLot()` | เงื่อนไข `< minReasonableLot` | ผลลัพธ์ |
|-----------|--------------|------------------|------------------------------|---------|
| ก่อน close | 0.05 | 0.05 | 0.05 > 0.005 → skip | ✅ ถูกต้อง |
| **หลัง close** | **0** | **0.01 (minLot)** | **0.01 > 0.005 → skip** | ❌ **ผิด!** |
| **ที่ควรจะเป็น** | **0** | **→ recalculate** | **0.01 < 0.05 → trigger** | ✅ 0.05 |

---

### สาเหตุ

```text
OpenBuySideTrade() (บรรทัด 7497-7560)
├── baseLotA = g_pairs[pairIndex].lotBuyA  // = 0 หลัง close!
├── if(InpGridLotScope == GRID_SCOPE_ALL)
│   └── false (ผู้ใช้ตั้ง "Grid Orders Only")
│
├── else → NormalizeLot(symbolA, 0)  // = 0.01 (minLot)
│
├── minReasonableLot = InpBaseLot * 0.1 = 0.005
│   └── 0.01 < 0.005? → FALSE!  // ไม่ trigger recalculation!
│
└── ใช้ lotA = 0.01 โดยตรง!
```

---

### การแก้ไข

#### Part A: อัปเดต Version

**ไฟล์:** `public/docs/mql5/Harmony_Dream_EA.mq5`  
**บรรทัด:** 7, 10

```cpp
#property version   "2.25"
#property description "v2.2.5: Fix New Cycle Lot - Recalculate Lots Before Opening New Trade"
```

---

#### Part B: แก้ไข OpenBuySideTrade() - เพิ่ม Lot Recalculation

**ปัญหา:** เมื่อ `lotBuyA = 0` (หลัง close), ต้อง recalculate ก่อนใช้งาน

**ไฟล์:** `public/docs/mql5/Harmony_Dream_EA.mq5`  
**ตำแหน่ง:** บรรทัด 7503-7506 (ก่อน get base lots)

**แก้ไขจาก:**
```cpp
   // v3.5.3: Get base lots
   double baseLotA = g_pairs[pairIndex].lotBuyA;
   double baseLotB = g_pairs[pairIndex].lotBuyB;
   double lotA, lotB;
```

**เป็น:**
```cpp
   // v2.2.5: Recalculate lots if they were reset (after close)
   if(g_pairs[pairIndex].lotBuyA == 0 || g_pairs[pairIndex].lotBuyB == 0)
   {
      CalculateDollarNeutralLots(pairIndex);
      PrintFormat("[v2.2.5] Pair %d BUY: Lots were 0 - Recalculated (A=%.2f B=%.2f)", 
                  pairIndex + 1, g_pairs[pairIndex].lotBuyA, g_pairs[pairIndex].lotBuyB);
   }
   
   // v3.5.3: Get base lots (now guaranteed to be non-zero)
   double baseLotA = g_pairs[pairIndex].lotBuyA;
   double baseLotB = g_pairs[pairIndex].lotBuyB;
   double lotA, lotB;
```

---

#### Part C: แก้ไข OpenSellSideTrade() - เพิ่ม Lot Recalculation

**ไฟล์:** `public/docs/mql5/Harmony_Dream_EA.mq5`  
**ตำแหน่ง:** บรรทัด 7693-7697 (ก่อน get base lots)

**แก้ไขจาก:**
```cpp
   // v3.5.3: Get base lots
   double baseLotA = g_pairs[pairIndex].lotSellA;
   double baseLotB = g_pairs[pairIndex].lotSellB;
   double lotA, lotB;
```

**เป็น:**
```cpp
   // v2.2.5: Recalculate lots if they were reset (after close)
   if(g_pairs[pairIndex].lotSellA == 0 || g_pairs[pairIndex].lotSellB == 0)
   {
      CalculateDollarNeutralLots(pairIndex);
      PrintFormat("[v2.2.5] Pair %d SELL: Lots were 0 - Recalculated (A=%.2f B=%.2f)", 
                  pairIndex + 1, g_pairs[pairIndex].lotSellA, g_pairs[pairIndex].lotSellB);
   }
   
   // v3.5.3: Get base lots (now guaranteed to be non-zero)
   double baseLotA = g_pairs[pairIndex].lotSellA;
   double baseLotB = g_pairs[pairIndex].lotSellB;
   double lotA, lotB;
```

---

### สรุปไฟล์ที่แก้ไข

| ไฟล์ | ส่วนที่แก้ไข | บรรทัด | รายละเอียด |
|------|-------------|--------|------------|
| `Harmony_Dream_EA.mq5` | Version | 7, 10 | อัปเดตเป็น v2.25 |
| `Harmony_Dream_EA.mq5` | `OpenBuySideTrade()` | ~7503 | เพิ่ม lot recalculation ก่อน open |
| `Harmony_Dream_EA.mq5` | `OpenSellSideTrade()` | ~7693 | เพิ่ม lot recalculation ก่อน open |

---

### ผลลัพธ์ที่คาดหวัง

| สถานการณ์ | ก่อนแก้ไข | หลังแก้ไข v2.2.5 |
|-----------|----------|------------------|
| เปิด trade ใหม่หลัง close | lot = 0.01 (minLot) | lot = 0.05 (Base Lot) |
| Log output | ไม่มี warning | `[v2.2.5] Pair 7 BUY: Lots were 0 - Recalculated (A=0.05 B=0.05)` |
| Compounding cycle ใหม่ | เริ่มจาก 0.01 | เริ่มจาก 0.05 ถูกต้อง |

---

### Flow หลังแก้ไข

```text
CloseBuySide()
├── lotBuyA = 0
├── lotBuyB = 0
└── directionBuy = -1 (Ready)

[ผ่านไประยะหนึ่ง - Signal ใหม่เข้า]

OpenBuySideTrade()
├── v2.2.5 CHECK: lotBuyA == 0?
│   └── YES → CalculateDollarNeutralLots()
│            → lotBuyA = 0.05
│            → lotBuyB = 0.05 (or hedge ratio adjusted)
│
├── baseLotA = 0.05 (not 0!)
├── if(GRID_SCOPE_ALL) → CalculateTrendBasedLots()
│   else → NormalizeLot(0.05) → 0.05 ✓
│
└── Open trade with 0.05 ✓
```

---

### Technical Notes

- การแก้ไขนี้จะ **recalculate lots ก่อนเปิด trade ใหม่** ถ้าค่า lot เป็น 0
- ใช้ `CalculateDollarNeutralLots()` เพื่อคำนวณ lot ใหม่ตาม hedge ratio และ Base Lot
- ไม่แก้ไขเงื่อนไขการ reset lot ใน `CloseBuySide()` - เพียงแค่ทำให้มันถูก recalculate ก่อนใช้
- ทำงานร่วมกับ v2.2.4 (Grid Lot Recovery) ได้สมบูรณ์
- ทำงานได้กับทั้ง "Grid Orders Only" และ "Both Main & Grid Orders" scope

---

### ข้อสังเกตเพิ่มเติม

จากรูปที่แนบมา ผู้ใช้ตั้ง:
- `Apply to Scope: Grid Orders Only`
- ซึ่งหมายความว่า Main Order ไม่ได้รับการคำนวณ lot จาก `CalculateTrendBasedLots()`
- ดังนั้นมันใช้ `NormalizeLot(baseLotA)` โดยตรง
- เมื่อ `baseLotA = 0` → ได้ 0.01 (minLot)

การแก้ไขนี้ครอบคลุมทั้งสอง scope โดยการ recalculate lot ก่อนที่จะใช้งาน
