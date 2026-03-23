

## Fix: Hedge ไม่ปิดเมื่อ Normal ทั้งที่กำไร — Gold Miner SQ EA (v5.5 → v5.6)

### วิเคราะห์สาเหตุ

จากโค้ดพบ **2 ปัญหา** ที่ทำให้ hedge ไม่ปิดเมื่อสถานะกลับมาเป็น Normal:

**ปัญหา 1: `ManageHedgeBoundAvgTP` แย่งทำงานก่อน Matching Close**

Flow ปัจจุบัน (line 6150):
```text
!isExpansion →
  ManageHedgeBoundAvgTP(h) → ถ้า return true → continue (skip matching close!)
  ManageHedgeMatchingClose(h)
```

ค่า Input: `InpHedge_BoundAvgTPPoints = 300` → 300 × 0.01 = 3.0 points (XAUUSD)

เมื่อราคาลงมาใกล้ avg price ของ sell orders ± 3 points → `tpReached = true` → ฟังก์ชันทำงาน → ปิดเฉพาะ sell ที่เป็นบวก → ซอย hedge → **return true** → `ManageHedgeMatchingClose` ไม่เคยถูกเรียก!

แต่ถ้า sell ที่เป็นบวกมีน้อย/ไม่มี → ฟังก์ชันก็ไม่ทำอะไร → return false → Matching Close ทำงาน → แต่ budget น้อยมาก ($23.18) → ไม่สามารถ match loss ใดได้

**ปัญหา 2: Matching Close "no matchable losses" fallback เข้า Grid Mode ทั้งที่ hedge ถูกปิดแล้ว**

```text
Line 6406-6428:
  trade.PositionClose(hedgeTicket);  ← ปิด hedge
  if(boundTicketCount > 0)
     gridMode = true;               ← เข้า grid mode ทั้งที่ hedge ปิดแล้ว!
```

Grid Mode ออกแบบมาสำหรับ "ซอย hedge ที่ยังเปิดอยู่" แต่ hedge ถูกปิดไปแล้ว → set ค้างเป็น active + gridMode ตลอดไป

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. เปลี่ยนลำดับใน `ManageHedgeSets()` — Matching Close ก่อน Average TP

```text
else if(!isExpansion)
{
   // Grid mode transition
   if(boundTicketCount == 0 && hedgeExists) { gridMode... }
   
   // Matching Close FIRST (hedge is profitable → close + match losses)
   if(hedgePnL > 0) { ManageHedgeMatchingClose(h); continue; }
   
   // Average TP SECOND (hedge is in loss → try avg TP on bounds)
   if(ManageHedgeBoundAvgTP(h)) continue;
   
   // Partial Close LAST
   ManageHedgePartialClose(h);
}
```

เหตุผล: Matching Close ปิดทั้ง hedge + matched losses ในครั้งเดียว (ถ้า hedge กำไร) ควรมีสิทธิ์ก่อน Average TP ที่ทำงานช้ากว่า (ซอยทีละส่วน)

#### 2. แก้ "no matchable losses" fallback ใน `ManageHedgeMatchingClose()`

```text
เดิม (line 6406-6428):
  close hedge → enter grid mode if bounds remain

ใหม่:
  close hedge → RELEASE all bound orders → deactivate set
```

เมื่อ hedge ถูกปิดแล้ว (เอากำไร) → bound orders กลับเป็น order ปกติ → ระบบเทรดปกติดูแลต่อ (TP/SL/Matching Close ปกติ) → ตรงกับพฤติกรรมที่ user ต้องการ: "กลับมาเป็นการเทรดแบบปกติ"

#### 3. Version bump: v5.5 → v5.6

### ผลลัพธ์
- Hedge กำไร + Normal → ปิด hedge ทันที + จับคู่ loss ได้เท่าไหร่ก็ปิด + bound ที่เหลือกลับเป็นปกติ
- Hedge ขาดทุน + Normal → Average TP / Partial Close ทำงานตามเดิม (ซอย hedge)
- ไม่มี set ค้างเป็น grid mode ทั้งที่ hedge ถูกปิดแล้ว

### สิ่งที่ไม่เปลี่ยนแปลง
- Order Execution Logic (trade.Buy/Sell/PositionClose)
- Trading Strategy Logic (SMA/ZigZag/Instant, Grid entry/exit, TP/SL)
- Core Module Logic (License, News filter, Time filter, Data sync)
- ManageHedgePartialClose, ManageHedgeGridMode logic
- ManageHedgeBoundAvgTP logic (เปลี่ยนแค่ลำดับเรียก)
- Bound ticket management, Lot Cap
- Accumulate/Drawdown close logic

