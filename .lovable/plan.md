## ปัญหาที่เจอ

ดูจาก log + โค้ด `ManageHeroOppositeClose()` v7.02 (บรรทัด ~849-862):

```text
// v7.02 Tick-based opposite-clear detector
if(phase != 3) continue;
if(CountHeroOnSide(side) <= 0) continue;
if(CountNonHeroMainOnSide(opp) > 0) continue;  // <<< opp ว่าง = ปิด Hero ทันที
if(CountHeroOnSide(opp) > 0) continue;
CloseHeroOnSide(side, "OppositeBasketFlatTick");
```

เงื่อนไขปิด Hero ตอนนี้คือ "ฝั่งตรงข้าม basket ว่าง" — ไม่ว่าจะปิดด้วย **TP** (กำไร) หรือ **SL** (ขาดทุน / Per-Order Trail / Cost-Hit) ก็ทำให้ Hero ปิดทั้งคู่ทันที

ตามที่ผู้ใช้ต้องการ: **Hero ต้องปิดเฉพาะตอน basket ฝั่งตรงข้ามชน TP เท่านั้น** — ถ้าฝั่งตรงข้ามชน SL/Trail ให้ Hero **ค้างอยู่ต่อ** (ล็อกหน้าทุนด้วย BE-SL ที่ ApplyHeroLockProfitSL ตั้งไว้แล้ว) เพื่อรอรอบ basket ใหม่ฝั่งตรงข้ามวิ่งไปชน TP

## แผนแก้ v1.50 — Hero TP-Only Opposite Close

### 1. เพิ่ม per-side tracker ของเหตุผลที่ basket ฝั่งตรงข้ามปิดล่าสุด

เพิ่ม global state:
```text
double   g_oppLastBasketRealizedProfit_Buy  = 0; // ผลรวมกำไรการปิด basket SELL ครั้งล่าสุด
double   g_oppLastBasketRealizedProfit_Sell = 0; // ผลรวมกำไรการปิด basket BUY ครั้งล่าสุด
datetime g_oppLastBasketCloseTime_Buy       = 0;
datetime g_oppLastBasketCloseTime_Sell      = 0;
```

### 2. ใช้ `OnTradeTransaction` (มีอยู่แล้ว) ดักการปิด deal ฝั่ง basket ปกติ (ไม่ใช่ Hero)

- ถ้า deal ปิดเป็น `DEAL_REASON_TP` หรือกำไรรวม > 0 → mark "ปิดด้วย TP/กำไร"
- ถ้า deal ปิดเป็น `DEAL_REASON_SL`, `DEAL_REASON_SO`, manual close หรือกำไรรวม ≤ 0 → mark "ปิดด้วย SL/ขาดทุน"

เก็บทั้ง realized profit และ timestamp ของการปิด basket ฝั่งนั้นล่าสุด (รีเซ็ต tracker เมื่อ basket ฝั่งนั้น re-arm รอบใหม่ คือมี order ใหม่เปิดหลัง flat)

### 3. แก้ `ManageHeroOppositeClose()` v7.02 detector

เปลี่ยนเงื่อนไขปิด Hero จาก:
```text
"opp basket = 0" → close
```
เป็น:
```text
"opp basket = 0" AND "opp ปิดล่าสุดด้วย TP/กำไร" → close
```

ถ้า opp ว่างแต่ปิดด้วย SL → **ไม่ปิด Hero** ปล่อยให้ Hero รออยู่ phase=BE_GUARD ต่อไป (BE-SL ของ Hero ก็ยังอยู่บน broker เพราะ `ApplyHeroLockProfitSL` ยัง re-apply ทุก tick อยู่แล้ว)

เพิ่ม log:
```text
v1.50 Hero HOLD side=BUY (opp SELL closed by SL/loss=...) — keep Hero locked, wait for opp TP
v1.50 Hero CLOSE (opp TP hit): heroSide=BUY oppSide=SELL oppProfit=+12.34 heroProfit=+5.67
```

### 4. เพิ่ม input toggle (เผื่อยกเลิกพฤติกรรมใหม่)
```text
input bool InpHero_OppCloseRequireTP = true; // v1.50 — true=close Hero only when opposite basket closed by TP (profit), false=v1.49 behavior (any flat)
```
default `true` ตามที่ผู้ใช้ต้องการ

### 5. รีเซ็ต tracker เมื่อ Hero ตัวเองปิดไปแล้ว (ใน `CloseHeroOnSide`)
หลัง CloseHeroOnSide → ล้าง realized profit / time tracker ทั้งสองฝั่ง เพื่อเริ่มรอบใหม่สะอาด

### 6. อัปเดต Version v1.49 → v1.50

อัปเดตทุกจุด:
- Header comment block
- `#property version "1.50"`
- `#property description`
- Dashboard title
- Print logs ที่อ้างอิง v1.49

### 7. เพิ่ม memory file

`mem://trading/golden-kuy3/v1-50-hero-tp-only-opposite-close.md`

## สิ่งที่ไม่เปลี่ยนแปลง (กฎเหล็ก)

- ❌ `trade.Buy / trade.Sell / trade.PositionClose / OrderSend` — ไม่แตะวิธีส่งคำสั่ง
- ❌ Grid entry / lot multiplier / Initial entry / `CalcGridLot`
- ❌ TP/SL/Trailing/Breakeven calculation เดิม
- ❌ Accumulate close / Avg-Trail strict-2-cross / Cost-Hit Restart
- ❌ สูตรเลือก Hero แบบ price-extreme (BUY ต่ำสุด / SELL สูงสุด) v1.48
- ❌ `BuildHeroTicketCache` (Branch A v1.49 take=min(N,nPool), Branch B activation)
- ❌ `IsHeroProtectedTicket` v1.49 / 9 จุด guard
- ❌ Side-Alternation Lock v1.46 / Single-Side Lock v1.45 / Post-close grace
- ❌ `ComputeHeroLockProfitSL / ApplyHeroLockProfitSL / StripBrokerTPSLFromHeroTickets`
- ❌ STEP 1 prune + external-close detect / STEP 2 dual BE_GUARD pre-guard / STEP 5 auto-release
- `InpHero_Enabled = false` → พฤติกรรม = v1.49

## ผลที่คาดหวังหลังแก้

1. BUY Hero locked อยู่ (BE-SL ที่ open + offset) → SELL basket ปกติวิ่งไปชน SL → **Hero ไม่ปิด**, log แสดง `v1.50 Hero HOLD side=BUY ... wait for opp TP`
2. รอบใหม่ SELL เปิด basket → วิ่งลงไปชน TP → ผลรวมกำไร > 0 → tracker mark "TP/profit" → **Hero BUY ปิดพร้อม SELL TP** ตามที่ต้องการ
3. ถ้า BUY Hero ตัวเองโดน BE-SL ปิดเอง (ราคาวิ่งกลับลงทะลุทุน) → STEP 1 prune detect → reset phase + stamp last-closed → ทำงานเหมือน v1.49 เดิม
