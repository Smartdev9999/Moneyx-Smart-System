## ปัญหา (v1.43)

`StripBrokerTPSLFromHeroTickets()` ตอน Hero ยังเป็น **CANDIDATE / ARMED** (basket ปกติฝั่งเดียวกันยังไม่ปิด) เรียก `trade.PositionModify(ticket, 0, 0)` → **ลบทั้ง TP และ SL** ทำให้ SL ที่ Per-Order BE หรือ trailing ตั้งล็อกหน้าทุนเอาไว้หาย ราคาวิ่งกลับขึ้น/ลงทะลุทุน → กำไรหายฟรี

ตามสเปกของผู้ใช้:
- ระหว่าง **ARMED (candidate)** — ถอดเฉพาะ **TP** เพื่อกัน basket Avg-TP / per-order TP มาปิด candidate ก่อนเวลา
- **คง SL** เดิมไว้ทุกตัว (BE / cost-lock ที่ระบบ Per-Order BE/Trail ทำมาให้) เผื่อราคาวิ่งกลับ
- **คอนเฟิร์มเป็น Hero จริง** ก็ต่อเมื่อ basket ปกติของฝั่งนั้นปิดหมด (TP โดน) → เลื่อน phase = BE_GUARD → ค่อย apply lock-profit SL ใหม่ทับ
- ถ้ายังไม่ถึง BE_GUARD จะไม่ "ล็อก" อะไรเพิ่ม

## สิ่งที่จะทำ — Golden Kuy3 v1.44

### 1. แก้ `StripBrokerTPSLFromHeroTickets()` → strip **TP only**

```text
ตอนนี้:  trade.PositionModify(ticket, 0, 0);          // SL=0, TP=0  ❌
แก้เป็น: ถ้า curTP != 0 → trade.PositionModify(ticket, curSL, 0);   // คง SL เดิม
         (ถ้า curTP == 0 อยู่แล้ว skip ไม่ต้อง modify)
```

- guard `phase == 3 (BE_GUARD)` ยังใช้เดิม (ฝั่งที่ confirm Hero แล้วให้ `ApplyHeroLockProfitSL` จัดการ SL/TP เอง)
- เปลี่ยนชื่อ log/comment เป็น "Strip TP only" เพื่ออ่านง่าย
- เพิ่ม diag log throttled (~30s) บอกว่า "Hero CANDIDATE side=... ticket=... TP stripped, SL kept=..."

### 2. ป้องกัน per-order trailing/SyncBrokerTPSL ไป "เพิ่ม" TP กลับ

ตรวจในไฟล์ — ทุกจุดที่วน position แล้วจะแก้ TP มี `IsHeroTicket(...) continue;` อยู่แล้ว (lines 940, 966, 976, 989, 1003, 1024, 1084, 1170) ดังนั้น TP จะไม่ถูกใส่กลับ — ไม่ต้องแก้

### 3. ไม่แก้ logic อื่น

- BE_GUARD apply path (`ApplyHeroLockProfitSL`) — เหมือนเดิม
- `ManageHeroOppositeClose` flow / opp-basket-flat detector — เหมือนเดิม
- `BuildHeroTicketCache` (v1.43 PRICE_EXTREME + STRICT lock) — เหมือนเดิม
- Phase machine 0 / 2 / 3, owner detection, post-close grace — เหมือนเดิม

### 4. Version + Memory

- `Golden_Kuy3_EA.mq5` v1.43 → **v1.44** (header / `#property version` / `#property description` / OnInit + OnDeinit log / Dashboard header / Hero Cfg row)
- เพิ่ม memory `mem://trading/golden-kuy3/v1-44-hero-candidate-tp-only-strip.md`
- อัปเดต `mem://index.md`
- อัปเดต `.lovable/plan.md`

## ส่วนที่ไม่แก้ไข (กฎเหล็ก MQL5)

- ❌ OrderSend / trade.Buy / trade.Sell / trade.PositionClose
- ❌ OpenInitial / OpenGrid / Manage*Entry
- ❌ CalcGridLot, Per-Order BE/Trail สูตร, Avg-Trail strict-2-cross
- ❌ TP modes (FixedDollar / Points / %Bal)
- ❌ Accumulate Close + cycle-reset v1.42
- ❌ Cost-Hit Restart core
- ❌ ComputeHeroLockProfitSL / ApplyHeroLockProfitSL (BE_GUARD path)
- ❌ BuildHeroTicketCache (v1.43 PRICE_EXTREME + STRICT)
- `InpHero_Enabled = false` → พฤติกรรม = v1.43 ทุกบรรทัด
