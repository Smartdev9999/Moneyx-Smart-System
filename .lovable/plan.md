## ปัญหาที่พบ

จาก screenshot และโค้ดที่อ่าน ระบบ Hero v1.42 มี 2 จุดผิด:

1. **คัด Hero จาก ticket/เวลาใหม่สุด** — `BuildHeroTicketCache()` sort ด้วย `POSITION_TIME_MSC + ticket` ทำให้ฝั่ง BUY ที่มีออเดอร์เก่าราคาต่ำ (#431 @3363, #484 @3361) ไม่ถูกเลือก แต่ไปเลือกตัวที่เปิดทีหลังแทน → Hero BUY ไม่ใช่ตัว “ล่างสุด”
2. **Single-side lock หลวม** — โค้ดยอมให้ทั้ง BUY และ SELL ขึ้น `ARMED` พร้อมกัน แล้วต่างก็ไหลไป `BE_GUARD` ได้ ทำให้ภาพเห็น Hero BUY = BE_GUARD และ Hero SELL = BE_GUARD พร้อมกัน (Owner = NONE) ซึ่งผิดสเปก

## สิ่งที่จะทำ — Golden Kuy3 v1.43

### 1. เปลี่ยนเกณฑ์เลือก Hero เป็น “ราคาเปิด” (price-extreme)

ใน `BuildHeroTicketCache()` แทนที่ sort key เดิม ใช้:

```text
ฝั่ง BUY  → sort ด้วย open price จากต่ำสุดขึ้นไป  (เลือก N ตัว “ล่างสุด”)
ฝั่ง SELL → sort ด้วย open price จากสูงสุดลงมา   (เลือก N ตัว “บนสุด”)
```

ผลกับภาพตัวอย่าง:
- BUY pool [#431 @3363.38, #484 @3361.83] → Hero BUY (N=2) คือ #484 ก่อน แล้ว #431
- SELL pool [#1071 @3327.39, #1109 @3319.37, #1145 @3300.76, #1147 @3306.01] → Hero SELL (N=2) คือ #1071 แล้ว #1109

แทนที่ array `ttMs[]` (POSITION_TIME_MSC) ด้วย `pxOpen[]` (POSITION_PRICE_OPEN) และเปลี่ยนทิศ swap ตามฝั่ง

### 2. Strict Single-Side Lock

เปลี่ยน `GetHeroOwnerSide()` ให้ถือว่า **ฝั่งใดก็ตามที่ phase != NONE คือ owner** (ARMED หรือ BE_GUARD ก็นับ) ไม่ใช่เฉพาะ BE_GUARD เท่านั้น

ผลที่ได้:
- ถ้า BUY ขึ้น ARMED ก่อน → SELL จะถูก block ที่ activation gate ทันที ไปต่อ BE_GUARD ฝั่งเดียวกัน
- จะไม่มีกรณี Hero ทั้ง 2 ฝั่งพร้อมกันอีก
- ปลด lock เมื่อ owner ฝั่งนั้นปิด Hero และผ่าน post-close grace

เพิ่ม guard ในกรณีที่ state ค้างจาก v1.42: ถ้าเจอ phase != 0 ทั้ง 2 ฝั่ง ให้เลือกฝั่งที่มี Hero tickets จริงก่อน อีกฝั่ง force reset เป็น NONE

### 3. ลบ tie-break ที่ไม่จำเป็นออก

เนื่องจากใช้ราคาเปิดแล้ว ตัด POSITION_TIME_MSC ออกจาก sort เลย (ใช้ ticket เป็น tie-break แทนกรณีราคาเท่ากันเป๊ะ)

### 4. Version + Dashboard + Memory

- `Golden_Kuy3_EA.mq5` v1.42 → **v1.43** (header / `#property version` / `#property description` / OnInit + OnDeinit log / Dashboard header)
- Dashboard “Hero Cfg” แสดง mode = `PRICE_EXTREME` และ `Lock=STRICT`
- เพิ่ม log `v1.43 Hero AUDIT` พิมพ์ราคาของแต่ละ Hero ticket เพื่อตรวจสอบได้
- เพิ่ม memory `mem://trading/golden-kuy3/v1-43-hero-price-extreme-strict-lock.md` และอัปเดต `mem://index.md`

## ส่วนที่ไม่แก้ไข (ยืนยันตามกฎ MQL5)

- ไม่แตะ `OrderSend` / `trade.Buy` / `trade.Sell` / `trade.PositionClose` / `trade.PositionModify` (ใช้ pattern เดิม)
- ไม่แตะ `OpenInitial` / `OpenGrid` / `ManageInitialEntry` / `ManageGridEntry`
- ไม่แตะ `CalcGridLot` (v1.2 MathCeil + force-step)
- ไม่แตะ Per-Order BE / Trailing สูตร
- ไม่แตะ Avg Trailing strict-2-cross
- ไม่แตะ TP modes ทั้งหมด (FixedDollar / Points push / %Bal)
- ไม่แตะ Accumulate Close + cycle-reset v1.42
- ไม่แตะ Cost-Hit Restart core
- ไม่มี License / News / Sync / Hedge / Squeeze
- ถ้า `InpHero_Enabled = false` พฤติกรรม = v1.42 ทุกบรรทัด