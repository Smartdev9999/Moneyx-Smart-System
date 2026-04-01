

## v6.21 — แก้ DD Trigger Threshold ให้สอดคล้องกับ Generation-Aware Counting

### ปัญหาที่พบ

ตั้งแต่ v6.18 DD calculation นับเฉพาะ **current generation** เท่านั้น (เช่น GM1 orders เท่านั้น) แต่ **trigger threshold ยังเป็นแบบสะสม** (5% → 10% → 15%):

```text
Line 6667: buyDDPct = MathAbs(buyLoss) / balance * 100.0
                      ↑ นับเฉพาะ GM1        ↑ ใช้ balance เต็ม

Line 6671: if(buyDDPct >= g_nextBuyDDTrigger)  
                          ↑ = 10% (หลัง H1 เปิด)
```

**ผลลัพธ์:** 
- H1 trigger ที่ 5% → ถูกต้อง (GM orders ติดลบ 5% ของ balance)
- H2 ต้อง trigger ที่ **10%** แต่ DD loop นับเฉพาะ **GM1 orders** → GM1 ต้องติดลบ 10% ของ balance **คนเดียว** ถึงจะ trigger
- ทำให้ H2 lot ใหญ่มาก (19.61 lot, -$1098) เพราะต้องรอจนติดลบ 10% ถึง trigger
- Dashboard แสดง "Next SELL DD:15.0%" ซึ่งหมายความว่า GM4 orders ต้องติดลบ 15% คนเดียว — เป็นไปไม่ได้ในทางปฏิบัติ

**หลักการที่ถูกต้อง (ตามที่ user อธิบาย):**
- H1: GM ติดลบ 5% → hedge → equity ~95%
- H2: GM1 ติดลบ 5% → hedge → equity ~90%  
- H3: GM2 ติดลบ 5% → hedge → equity ~85%
- แต่ละ generation ใช้ **threshold เท่ากัน = 5%** เพราะนับ DD แยก gen อยู่แล้ว

### แผนแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. เปลี่ยน threshold เป็น constant per-generation

เนื่องจาก DD นับเฉพาะ current generation แล้ว threshold ไม่ต้องสะสม:

```cpp
// เดิม (line 6671):
if(buyDDPct >= g_nextBuyDDTrigger)  // 5→10→15

// แก้เป็น:
if(buyDDPct >= InpHedge_DDTriggerPct)  // คงที่ 5% ทุก generation
```

เช่นเดียวกับ SELL side (line 6683)

#### 2. ลบการเพิ่ม threshold หลังเปิด hedge

```cpp
// เดิม (line 6675):
g_nextBuyDDTrigger += InpHedge_DDStepPct;  // ลบบรรทัดนี้

// เดิม (line 6687):
g_nextSellDDTrigger += InpHedge_DDStepPct;  // ลบบรรทัดนี้
```

#### 3. ปรับ Dashboard แสดงข้อมูลที่ถูกต้อง

แทนที่จะแสดง "Next BUY DD:10%" (ซึ่งผิด) → แสดง DD ปัจจุบัน + threshold จริง:

```cpp
// แสดง: "BUY DD:2.3%/5.0% | SELL DD:4.1%/5.0%"
// ให้เห็นว่าตอนนี้ DD เท่าไหร่ เทียบกับ trigger ที่ 5%
```

#### 4. ลบ `InpHedge_DDStepPct` input (ไม่จำเป็นแล้ว)

หรือคงไว้แต่ไม่ใช้ — เพื่อ backward compatibility

#### 5. ปรับ Recovery logic ใน `RecoverHedgeSets()` ให้สอดคล้อง

Lines 7076-7082 และ 7670-7677 ที่คำนวณ `g_nextBuyDDTrigger` จาก `ddBuyCount * InpHedge_DDStepPct` → ไม่จำเป็นแล้ว เพราะ threshold คงที่

#### 6. Version bump: v6.20 → v6.21

### Technical details

```text
เดิม (v6.18-v6.20):
  DD scope = current gen only ✓
  Threshold = cumulative (5→10→15) ✗  ← MISMATCH
  
  H1: GM loss 5% of bal → trigger (5% >= 5%) ✓
  H2: GM1 loss needs 10% of bal → ช้าเกิน, lot ใหญ่เกิน ✗
  H3: GM2 loss needs 15% of bal → แทบเป็นไปไม่ได้ ✗

ใหม่ (v6.21):
  DD scope = current gen only ✓
  Threshold = constant per gen (5%) ✓  ← MATCH
  
  H1: GM loss 5% of bal → trigger ✓
  H2: GM1 loss 5% of bal → trigger ✓  
  H3: GM2 loss 5% of bal → trigger ✓
```

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter, Time filter, Data sync)
- Triple-gate close (Expansion + Zone + TP Distance)
- Generation-aware binding/counting (v6.18/v6.19)
- NormalOrderCount() logic (v6.20)
- Expansion hedge trigger — ไม่แก้
- OpenDDHedge() binding logic — ไม่แก้

