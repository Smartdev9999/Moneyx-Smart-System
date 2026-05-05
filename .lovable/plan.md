## Golden Kuy3 EA v1.2 → v1.3 — Hero Order System

ไฟล์: `public/docs/mql5/Golden_Kuy3_EA.mq5`
เอกสารใหม่: `.lovable/memory/trading/golden-kuy3/v1-3-hero-order.md`
อัปเดต: `.lovable/plan.md`, `mem://index.md`
Version: `#property version "1.30"` + dashboard title `Golden Kuy3 v1.3`

---

### แนวคิดสรุป

Hero Order = ออเดอร์ "ใหญ่ที่สุด" (= ใหม่ที่สุด ตาม ticket สูงสุด เพราะ grid โตตาม multiplier) ของฝั่งที่กำลังเป็นภาระ จำนวน N ตัว ที่ระบบจะ **ล็อคไว้** ไม่นำไปคิดในการปิดรวบ และทำหน้าที่เป็น "หน่วยถัว" สำหรับฝั่งตรงข้าม

เมื่อราคาย่อกลับและ Average ของฝั่งตรงข้าม (ไม่นับ initial ชุดล่าสุด N ตัวฝั่งตรงข้าม) ทำกำไรถึงเป้า → ปิดทุกอย่าง **ยกเว้น Hero ฝั่งภาระ และ initial ชุดล่าสุดฝั่งตรงข้าม** → เริ่ม "วงรอบใหม่" โดย Hero ยังถูกล็อคหน้าทุน, ฝั่งตรงข้ามชุดล่าสุดเดินเป็น initial+grid ปกติ

---

### Inputs ใหม่ (กลุ่มใหม่ `=== Hero Order ===`)

| Input | Default | หมายเหตุ |
|---|---|---|
| `InpEnableHero` | `false` | master toggle |
| `InpHero_Count` | `3` | จำนวน order ที่ถูกล็อคเป็น Hero ต่อฝั่ง |
| `InpHero_MinSideOrders` | `5` | ขั้นต่ำของ order ฝั่งเดียวกันก่อนเข้าเงื่อนไข Hero (ต้อง > Count) |
| `InpHero_BE_OffsetPips` | `5.0` | offset SL กันหน้าทุนของ Hero (BUY: open+offset, SELL: open-offset) |
| `InpHero_AvgTP_Points` | `300.0` | TP จาก average ฝั่งตรงข้าม (ไม่นับ Hero ของฝั่งนั้น และไม่นับ "initial ชุดล่าสุด" ฝั่งตรงข้าม) |
| `InpHero_AvgTP_MinOrders` | `2` | จำนวนขั้นต่ำของ "non-Hero" ฝั่งตรงข้ามเพื่อให้ Hero-AvgTP ทำงาน |
| `InpHero_KeepLatestN_Opp` | `3` | จำนวน initial ชุดล่าสุดฝั่งตรงข้ามที่จะ "เหลือไว้" หลังปิด cycle (เป็นเมล็ดวงรอบถัดไป) |
| `InpHero_StripBE_OnSurvivor` | `true` | survivor (ฝั่งตรงข้ามชุดล่าสุดที่เหลือ) จะถูกถอด BE-Lock SL ปล่อยให้กรีดออกตาม multiplier ปกติ |

---

### กฎการเลือก Hero Side

- รันการประเมินทุก tick (cheap):
  - หา "ฝั่งภาระ" = ฝั่งที่ floating ขาดทุนมากกว่า และจำนวน order ฝั่งนั้น `>= InpHero_MinSideOrders`
  - ถ้าผ่าน → ทำเครื่องหมาย Hero = N ออเดอร์ "ticket สูงสุด N ตัว" ของฝั่งนั้น (sorted desc by ticket)
- ถ้าจำนวน order ฝั่งนั้นลดลงต่ำกว่า `InpHero_Count` (เพราะถูกปิด) → ยกเลิก Hero state, `g_hero_Active=false`
- เก็บ state:
  - `g_hero_Active` (bool)
  - `g_hero_Side` (int: BUY/SELL)
  - `g_hero_Tickets[]` (ulong array, refresh ทุก tick จาก top-N ticket ของฝั่งภาระ)

Helper ใหม่:
```cpp
bool  IsHeroTicket(ulong tk);
void  RefreshHeroTickets();             // เลือก top-N ticket ฝั่ง g_hero_Side
double CalcSideAvgPriceExcl(int side, const ulong &exclude[], int &countOut, double &lotsOut);
```

---

### ผลกระทบต่อ Module ที่มีอยู่

ทุกจุดต่อไปนี้เพิ่ม "skip Hero ticket" — ไม่แก้สูตร ไม่แก้ trade.* call:

1. **ManageTakeProfit / Accumulate Close**
   - คำนวณ floating รวมของ "ออเดอร์ที่ไม่ใช่ Hero" เท่านั้น
   - ตอน close: `CloseAllOursExceptHeroAndOppSurvivor()` — ปิดทุก ticket ยกเว้น Hero และยกเว้น "ticket สูงสุด `InpHero_KeepLatestN_Opp` ของฝั่งตรงข้าม Hero"
2. **Average TP (Points mode เดิม)**
   - คำนวณ avg จาก "non-Hero only"; ใช้ภายในฟังก์ชันใหม่ `CalcSideAvgPrice_NonHero(side)`
   - ใช้ helper `CountSide_NonHero(side)` ใน gate `n >= InpAvgTP_MinOrders`
3. **Hero Average TP (ใหม่ ทำงานเฉพาะเมื่อ `g_hero_Active`)**
   - คำนวณ avg ของ "ฝั่งตรงข้าม Hero" โดย exclude:
     - Hero ticket (ของฝั่ง Hero — ไม่อยู่ฝั่งนี้อยู่แล้ว)
     - Top-`InpHero_KeepLatestN_Opp` ticket ของฝั่งตรงข้าม Hero (จะกัน "initial ชุดล่าสุด" ไว้)
   - เมื่อราคาเคลื่อน `>= InpHero_AvgTP_Points * point` ในทิศทำกำไรของฝั่งตรงข้าม Hero → trigger close-cycle
4. **Per-Order BE / Trailing**
   - Hero ticket จะถูกตั้ง SL กันหน้าทุนแบบ "fix once": เมื่อ Hero ถูก tag ใหม่ → คำนวณ SL = open ± `InpHero_BE_OffsetPips` แล้ว `PositionModify` ครั้งเดียว (ไม่เลื่อน)
   - Per-Order Trailing เดิม: skip Hero ticket
   - Survivor (top-N ticket ฝั่งตรงข้ามที่ถูกเก็บไว้): ถ้า `InpHero_StripBE_OnSurvivor=true` → strip SL=0 ครั้งเดียวตอน close-cycle เสร็จ
5. **Average Trailing เดิม**
   - คำนวณ avg จาก non-Hero เท่านั้น (ใช้ `CalcSideAvgPrice_NonHero`)
6. **Cost-Hit Restart (v1.2)**
   - ไม่ trigger restart ถ้า ticket ที่ถูกปิดเป็น Hero (Hero ถูกปิดเพราะ BE-SL ของมันเอง = ตั้งใจ)
7. **Grid Entry**
   - **ไม่เปลี่ยน multiplier chain** — เพราะ `CountSide()` คืน "last by highest ticket" → grid ฝั่งตรงข้ามจะไหลตาม survivor ใหม่อยู่แล้ว
   - ฝั่ง Hero: grid ออกต่อได้ตามปกติ (เงื่อนไขเดิม)

---

### ลำดับเหตุการณ์ตัวอย่าง (BUY = ฝั่งภาระ)

```text
1. มี BUY 10 ตัว (lot โต) + SELL 1 (initial)
   → g_hero_Side = BUY, Hero = ticket BUY #8,#9,#10 (top 3)
   → ตั้ง SL Hero ครั้งเดียว = open + 5pip
2. ราคาย่อลง, SELL ออก grid เรื่อยๆ ตาม multiplier
3. คำนวณ avgSELL จาก "SELL ทั้งหมด ยกเว้น top-3 SELL ticket ล่าสุด"
   เมื่อราคาห่าง avgSELL >= 300pt ในทิศทำกำไร SELL
4. CloseAllOursExceptHeroAndOppSurvivor():
   - ปิด BUY #1..#7 (BUY non-Hero)
   - ปิด SELL ทั้งหมดยกเว้น top-3 SELL ล่าสุด
   - คง Hero BUY #8,#9,#10 (มี SL กันทุน)
   - คง SELL top-3 ล่าสุด = "survivor" (strip SL=0)
5. วงรอบใหม่: SELL survivor 3 ตัว เดินเป็น initial+grid ปกติ,
   Hero BUY ยังถูกล็อค → กลายเป็นฝั่งถัวให้ SELL
   ถ้า SELL กลับมาเป็นฝั่งภาระอีก → re-evaluate Hero (อาจสลับ side)
6. ถ้า Hero BUY ทั้งหมดถูกปิดด้วย SL ของมัน
   → g_hero_Active=false → กลับสู่โหมดปกติ (entry/grid/TP เดิม v1.2 ทั้งหมด)
```

---

### Dashboard (เพิ่ม section ใหม่)

```
=== HERO ORDER ===
Hero Module       ON  cnt=3 minSide=5
Hero Status       ACTIVE BUY  tk=#1234,#1235,#1236
Hero AvgTP        300pt from avgSELL=2456.78  cur dist=210pt
Survivor Strip    ON keepN=3
```

แถวเดิมไม่ลบ; ใช้ `g_dashRowMax` (v1.2) จัดการ trim row เกิน

---

### สิ่งที่ "ไม่เปลี่ยน" (กฎเหล็ก MQL5)

- ไม่แตะ `OrderSend` / `trade.Buy` / `trade.Sell` / `trade.PositionClose` / `trade.PositionModify` (ใช้ pattern เดิม)
- ไม่แตะสูตร Grid distance / lot calc (v1.2 ceil + min-step floor)
- ไม่แตะสูตร Per-Order BE / Trailing / Avg Trailing strict-2-cross / TP modes / EnforceClearTPIfDisabled
- ไม่แตะ Auto Re-Entry / Init Side Mode / Cost-Hit Restart core
- ไม่มี License / News / Sync / Hedge / Squeeze
- ถ้า `InpEnableHero=false` พฤติกรรม EA = v1.2 เป๊ะทุกบรรทัด (ทุก helper Hero return เร็วเมื่อ master OFF)

---

### Memory & Plan
- สร้าง `mem://trading/golden-kuy3/v1-3-hero-order` พร้อม description สั้นชี้พฤติกรรม Hero/Survivor/AvgTP
- อัปเดต `mem://index.md` เพิ่ม entry ใต้ Memories
- อัปเดต `.lovable/plan.md` ให้สะท้อน v1.3
