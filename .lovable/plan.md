

## Fix: Hedge Partial Close ปิดแค่ 1 order ต่อ tick — ปรับเป็น Batch (v4.9 → v5.0)

### วิเคราะห์สาเหตุ

**Line 6193** ใน `ManageHedgePartialClose()` มี `break;` ที่ทำให้ปิดได้แค่ **1 order ต่อ tick**:

```text
วงจรที่เกิด:
1. profitCount = 3 → ผ่าน guard → ปิด 1 buy + partial hedge → break
2. tick ถัดไป: profitCount = 2 → guard fail (< 3) → ไม่ปิด
3. Grid buy ใหม่เปิด → profitable → profitCount = 3 → ปิดอีก 1 → drop เหลือ 2
4. วนซ้ำ → ปิดได้แค่ 1 order ต่อรอบ
```

ผู้ใช้ต้องการ: เมื่อมี ≥ 3 profitable orders → **ใช้กำไรรวมทั้งหมดมาซอย hedge ทีเดียว** (batch) เหมือน ManageHedgeMatchingClose ที่ทำแบบ batch อยู่แล้ว

### การแก้ไข

**ไฟล์:** `public/docs/mql5/Gold_Miner_EA.mq5`

#### 1. แก้ ManageHedgePartialClose() ให้เป็น Batch Mode

**แทนที่ loop 1-per-tick (line 6147-6194) → batch approach:**

```text
เดิม:
  for each profitOrder:
    close 1 profitable order + partial hedge
    break;  ← ปิดแค่ 1

ใหม่:
  1. คำนวณ totalProfit = รวมกำไรทุก profitable orders
  2. closeLots = (totalProfit - InpHedge_PartialMinProfit) / hedgeLossPerLot
  3. ปิด profitable orders ทั้งหมด
  4. Partial close hedge ด้วย closeLots รวม
```

**ผล:** เมื่อมี 3+ profitable orders → ใช้กำไร **ทั้ง 3+** orders รวมกันมาคำนวณ → ซอย hedge ได้ทีละเยอะ → ลด hedge เร็วขึ้นมาก

#### 2. Version bump: v4.9 → v5.0

### สิ่งที่ไม่เปลี่ยนแปลง
- Guard condition `profitCount < InpHedge_PartialMinProfitOrders` ยังคงเป็นกฎเหล็ก
- ManageHedgeMatchingClose (Scenario 1), ManageHedgeGridMode logic
- Normal Matching Close, Trading logic, Grid logic ทั้งหมด
- เมื่อ `InpHedge_PartialMinProfitOrders = 0` → ทำงานเหมือนเดิม

