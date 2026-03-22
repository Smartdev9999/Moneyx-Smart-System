

## วิเคราะห์ระบบ Hedge ปัจจุบัน vs. ความต้องการของคุณ

### สิ่งที่ระบบ v5.1 ทำได้แล้ว
- แยก Hedge เป็นหลาย Set (สูงสุด 4 ชุด) ด้วย `boundTickets[]`
- แต่ละ Set แก้ order ของตัวเอง (Partial Close, Matching Close, Grid Mode)
- Order ใหม่หลัง Hedge เป็น cycle ใหม่ (GM_INIT, GM_GL, GM_GP) ไม่ผูกกับ set เดิม

### จุดที่ยังไม่ตรงกับความต้องการ — ต้องแก้ไข 3 จุดหลัก

---

#### จุด 1: การคำนวณ Lot สำหรับ Hedge #2, #3, #4 — **ต้องเปลี่ยน**

**ปัจจุบัน (ผิด):** `CountUnboundOrders(counterSide)` → นับเฉพาะ order ที่ยังไม่ผูก → ไม่รวม order จาก set เดิม, ไม่รวม hedge order, ไม่รวม grid hedge order

**ที่ถูกต้อง:** คำนวณจาก **Net Lot ของทั้ง 2 ฝั่ง**

```text
ตัวอย่างจากที่คุณอธิบาย:

Hedge #1: Buy 10 orders ถูก hedge ด้วย Sell
  → ราคากลับขึ้น → Buy ปิดหมด → เหลือ Hedge Sell + Grid Sell
  → Hedge Sell initial (ซอยเหลือ) + Grid Sell = 2.0 Lot (sell total)

Expansion Buy เกิดขึ้น:
  → ยังมี Buy ค้างจาก Hedge #1 boundTickets = 0.5 Lot
  → Hedge #2 Buy = Sell Total - Buy Total = 2.0 - 0.5 = 1.5 Lot

Hedge #3 (ถ้ากลับตัวอีก):
  → Buy Total 2.0 - Sell Total 1.5 = Hedge #3 Sell 0.5 Lot
```

**แก้ `CheckAndOpenHedge()`:** เปลี่ยนจาก `CountUnboundOrders()` เป็นคำนวณ:
- `totalBuyLots` = รวม Buy ทุก order (ปกติ + hedge + grid hedge) ทุก set
- `totalSellLots` = รวม Sell ทุก order ทั้งหมด
- `hedgeLots = |totalBuyLots - totalSellLots|`
- ทิศทาง hedge = ฝั่งที่น้อยกว่า

---

#### จุด 2: Matching Close / Partial Close ข้าม Set — **ต้องเปลี่ยน**

**ปัจจุบัน:** แต่ละ Set ดูเฉพาะ `boundTickets[]` ของตัวเอง

**ที่ถูกต้อง (ตามที่คุณอธิบาย):** เมื่อ expansion จบ → ใช้กำไรรวมจาก **ทุก order ที่บวก** (ไม่จำแนก set) → ปิด order ที่ **เก่าสุด** ไม่ว่าจะเป็น Hedge order, Grid Hedge, หรือ order เดิม

```text
ตัวอย่าง: Hedge #2 Buy 1.5L กำไร $1,000
  → สแกน order ขาดทุนทั้งหมด (ทุก set) เรียงเก่าสุด
  → ปิดได้กี่ตัวก็ปิดเท่านั้น (budget-based เหมือน normal matching)
```

---

#### จุด 3: Cycle Labeling (ชุด A, B, C...) — **ต้องเพิ่มใหม่**

**ปัจจุบัน:** ทุก cycle ใช้ `GM_INIT`, `GM_GL`, `GM_GP` เหมือนกันหมด → สับสนเมื่อมีหลาย cycle ทำงานพร้อมกัน

**ที่ถูกต้อง:**
- Cycle แรก (ยังไม่มี Hedge): `GM_A_INIT`, `GM_A_GL1`, `GM_A_GP1`
- หลัง Hedge #1 เกิด → cycle ใหม่: `GM_B_INIT`, `GM_B_GL1`, `GM_B_GP1`
- หลัง Hedge #2 → `GM_C_INIT`, `GM_C_GL1`
- เมื่อ order ทั้งหมดปิดหมด → reset กลับเป็น `GM_A_INIT`

**เพิ่ม global:**
```cpp
int g_currentCycleIndex = 0;  // 0=A, 1=B, 2=C, 3=D
string GetCyclePrefix() { return "GM_" + CharToString('A' + g_currentCycleIndex) + "_"; }
```

**ผลกระทบ:** ต้องแก้ทุกจุดที่ใช้ `"GM_INIT"`, `"GM_GL"`, `"GM_GP"` ให้ใช้ `GetCyclePrefix() + "INIT"` แทน — **นี่คือการเปลี่ยนแปลงที่ใหญ่มาก** เพราะมีอ้างอิงกว่า 50+ จุดในไฟล์

---

### Grid Hedging — ยืนยันความเข้าใจ

เมื่อ boundTickets หมด (order ฝั่งตรงข้ามปิดหมด) → Grid Mode:
- คำนวณ Equiv Grid Level จาก lot ที่เหลือ: `initial + GL1 + GL2 + ... ≈ remainingLots` → เริ่มจาก GL ถัดไป
- ใช้ `GridLoss_Points` / `GridProfit_Points` เป็น distance (Fixed distance ที่คุณตั้ง)
- Matching Close ใน Grid Mode ก็ใช้หลักการเดียวกัน: ต้องมี `InpHedge_PartialMinProfitOrders` ขึ้นไปถึงจะเริ่มซอย

**ตรงนี้ทำงานถูกต้องแล้ว ✅** — ไม่ต้องแก้

---

### สรุป: ระบบปัจจุบันยังไม่รองรับ 2 จุดสำคัญ

| หัวข้อ | สถานะ |
|---|---|
| Hedge #2+ Lot = Net(Buy-Sell) ทุก order | ❌ ยังใช้ CountUnboundOrders |
| Matching/Partial Close ข้าม Set (เก่าสุดก่อน) | ❌ ยังแยก set |
| Cycle Labeling (A, B, C...) | ❌ ยังไม่มี |
| Grid Mode + Equiv Level | ✅ ทำงานแล้ว |
| Grid Distance ใช้ Fixed points | ✅ ทำงานแล้ว |
| MinProfitOrders guard | ✅ ทำงานแล้ว |

### ข้อเสนอ

เนื่องจากการเปลี่ยนแปลงนี้ **ใหญ่มาก** (แก้ comment scheme ทั้งไฟล์ + เปลี่ยน logic Hedge lot calculation + Cross-set matching) ผมแนะนำแบ่งเป็น 2 phase:

**Phase 1:** แก้ Hedge Lot Calculation (Net Buy-Sell) + Cross-Set Matching Close
**Phase 2:** เพิ่ม Cycle Labeling (A, B, C...)

ต้องการให้ดำเนินการ Phase ไหนก่อน หรือต้องการปรับแก้อะไรในแผนนี้?

