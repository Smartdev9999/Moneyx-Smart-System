## สาเหตุที่ยังเห็น Ticket Hero ค้างหลัง v1.53
จากโค้ดตอนนี้ `BuildHeroTicketCache()` ทำ dynamic refresh เฉพาะตอนที่มันถูกเรียกช่วงต้น `OnTick()` เท่านั้น แต่ลำดับ `OnTick()` ปัจจุบันคือ:

```text
BuildHeroTicketCache()
ManageHeroOppositeClose()
ManageCostHitRestart()
ManageInitialEntry()
ManageGridEntry()      <- ออเดอร์ใหม่อาจเกิดตรงนี้
ManagePerOrderTrailing()
ManageTakeProfit()
...
DrawDashboard()        <- dashboard ยังใช้ Hero cache จากก่อนเปิดออเดอร์ใหม่
```

ดังนั้นถ้า Grid เปิด order SELL ใหม่ที่ราคาสูงกว่าใน `ManageGridEntry()` หลังจาก refresh ไปแล้ว รอบ tick เดียวกัน Dashboard จะยังโชว์ชุด Hero เก่า เช่น `#42 #41 #39 #29 #28` และ order ใหม่ยังไม่ถูกนำเข้า pool เพื่อคัด Hero จนกว่าจะ tick ถัดไปหรือจนกว่า `BuildHeroTicketCache()` ถูกเรียกใหม่จริง ๆ

อีกจุดที่ต้องปรับคือ comment/logic ยังอิงคำว่า stable/sticky หลายจุด ทำให้ถึงแม้ default `InpHero_StickySet=false` แล้ว แต่โครงสร้างยังทำงานแบบ cache set เก่าอยู่ในบางจังหวะ

## แผนแก้ v1.54 — Live Hero Refresh After Entries

### 1) เพิ่ม version เป็น v1.54 ทุกจุด
- `#property version` 1.53 → 1.54
- Header description ด้านบนไฟล์
- `#property description`
- Dashboard title `Golden Kuy3 v1.54` และ `HERO ORDER (v1.54)`
- log init/deinit เป็น v1.54

### 2) แก้ `BuildHeroTicketCache()` ให้สื่อชัดว่า default คือ Dynamic ไม่ใช่ Sticky
- เปลี่ยน comment จาก “STICKY stable sets chosen once” เป็น “dynamic price-extreme cache by default”
- Branch active phase (`curPhase != 0`) จะคง logic เดิมของ v1.53: sort pool ใหม่ทุกครั้งตาม open price
  - BUY: เลือก ticket ราคาต่ำสุด N ตัว
  - SELL: เลือก ticket ราคาสูงสุด N ตัว
- ถ้า `InpHero_StickySet=true` ยัง fallback เป็น v1.52 sticky เหมือนเดิม

### 3) เรียก refresh ซ้ำหลัง order-entry modules
เพิ่ม `BuildHeroTicketCache()` รอบที่ 2 หลัง `ManageInitialEntry()` และ `ManageGridEntry()` เพื่อให้ order ที่เพิ่งเปิดใน tick เดียวกันถูกนำมาคัด Hero ทันทีก่อน TP/Trail/Dashboard ทำงาน:

```text
BuildHeroTicketCache();      // pre-pass: ใช้ guard Hero ก่อน logic อื่น
ManageHeroOppositeClose();
ManageCostHitRestart();
ManageInitialEntry();
ManageGridEntry();
BuildHeroTicketCache();      // v1.54 post-entry refresh: จับ order ใหม่ทันที
ManageHeroOppositeClose();   // apply strip/BE guard ให้ Hero set ใหม่ทันที
ManagePerOrderTrailing();
ManageTakeProfit();
ManageAverageTrailing();
...
DrawDashboard();
```

ผลคือ ถ้า SELL ใหม่เปิดสูงกว่า หลัง `ManageGridEntry()` จะถูก refresh เข้า Hero set ทันทีใน tick เดียวกัน ไม่ต้องรอ tick ถัดไป และ Dashboard/TP/Trailing จะเห็นชุด Hero ใหม่ทันที

### 4) เพิ่ม helper ป้องกันการ modify ซ้ำเกินจำเป็นตอน demote restore
ปรับ `RestoreInitialTPOnDemoted()` ให้ตรวจค่าปัจจุบันก่อน `PositionModify()`:
- ถ้า SL เป็น 0 อยู่แล้ว และ TP เท่าค่าเป้าหมายอยู่แล้ว ให้ skip
- ลด log/modify spam เมื่อ dynamic refresh เปลี่ยนชุดบ่อย
- ยังคงหลัก v1.53: ticket ที่หลุดจาก Hero จะถูกล้าง lock-SL และกลับไปเป็น non-Hero basket

### 5) เพิ่ม audit log สำหรับ post-entry refresh
เพิ่ม log แบบ throttle 10–30 วินาทีเมื่อ set เปลี่ยนหลังเปิด order เพื่อให้ตรวจใน Journal ได้ว่า:
```text
v1.54 Hero POST-ENTRY REFRESH side=SELL topN=#...@price ...
```
และ dashboard ยังโชว์ `Tick SELL` จาก stable array ล่าสุด

## ผลลัพธ์ที่คาดหวัง
- ถ้า Hero SELL กำหนด N=5 และมี SELL ใหม่ที่ราคาสูงกว่าเข้ามา ชุด Hero จะเลื่อนเป็น 5 ticket ราคาสูงสุดทันที
- ticket เก่าที่ถูกดันออกจาก Hero จะกลับไปเป็น non-Hero และปิดร่วมกับ Average TP ของฝั่ง SELL ได้
- Dashboard จะไม่ค้างที่ ticket เก่าแบบในภาพ หลัง order ใหม่ถูกเปิดใน tick เดียวกัน
- Alternation Lock ยังเหมือนเดิม: ฝั่งที่เพิ่งปิด Hero ต้องสลับไปอีกฝั่งก่อน หรือรอฝั่งเดิม flat ตามกติกาเดิม

## สิ่งที่ไม่เปลี่ยนแปลง
- ไม่แก้ `trade.Buy`, `trade.Sell`, `trade.PositionClose`, `OrderSend`
- ไม่แก้เงื่อนไขเปิดออเดอร์, grid entry, lot multiplier, grid distance
- ไม่แก้ Per-Order BE/Trail/SL/TP/Cost-Hit calculation
- ไม่แก้ Avg-TP / Avg-Trailing strict-2-cross / Accumulate logic
- ไม่แก้ `ApplyHeroLockProfitSL()` และสูตร lock-profit SL
- ไม่แก้ Side-Alternation v1.46, Single-Side Lock v1.45, Post-close grace
- ไม่แก้ v1.51 Avg-TP intent gate ที่ป้องกัน Hero ปิดจาก Per-Order SL/Trail/Cost-Hit
- `InpHero_Enabled=false` ยัง behavior เดิม
- `InpHero_StickySet=true` ยังใช้ fallback sticky แบบ v1.52